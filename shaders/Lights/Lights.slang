// Light sampling for next event estimation (ported from Legacy/Source/XPU/Public/Light and
// AtmosphereData.h). Environment: equirect map with a 2D CDF built on the host. Emissive
// triangles: power-proportional selection via a CDF stored in EmissiveTriangle.p2.w. Sun: cone.
import Common.Math;
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.Textures;
import Materials.VirtualTexture;
import Materials.MaterialProgram;

struct LightSample
{
	float3 position;
	float3 normal;
	float3 radiance; // for delta lights: irradiance-producing intensity / distance^2, with solidAnglePdf = selection pdf
	float solidAnglePdf;
	bool delta; // a point light without radius: no MIS
	bool shadow; // false: the shadow ray is skipped
};

// ---- environment ----

bool EnvironmentEnabled()
{
	return (gFrame.settings.z & FRAME_FLAG_ENVIRONMENT) != 0u;
}

float3 EvalEnvironment(float3 dir)
{
	if (!EnvironmentEnabled())
	{
		return float3(0.0);
	}
	float2 uv = DirectionToEquirectUV(RotateY(dir, -gFrame.envParams.y));
	return gEnvMap.SampleLevel(gLinearSampler, uv, 0.0).rgb * gFrame.envParams.x;
}

float EnvCdf(uint x, uint y)
{
	return gEnvCdf.Load(int3(int(x), int(y), 0));
}

// Largest i in [0, count) with cdf(i) <= u, for the row's count + 1 monotonic entries.
uint SearchCdfRow(uint row, uint count, float u)
{
	uint lo = 0u;
	uint hi = count;
	while (hi - lo > 1u)
	{
		uint mid = (lo + hi) >> 1u;
		if (EnvCdf(mid, row) <= u)
		{
			lo = mid;
		}
		else
		{
			hi = mid;
		}
	}
	return lo;
}

float EnvironmentPdf(float3 dir)
{
	if (!EnvironmentEnabled())
	{
		return 0.0;
	}
	if ((gFrame.settings.z & FRAME_FLAG_ENV_IMPORTANCE) == 0u)
	{
		return 1.0 / (4.0 * PI);
	}
	uint W = gFrame.envInfo.x;
	uint H = gFrame.envInfo.y;
	float3 local = RotateY(dir, -gFrame.envParams.y);
	float2 uv = frac(DirectionToEquirectUV(local));
	uint x = min(uint(uv.x * float(W)), W - 1u);
	uint y = min(uint(uv.y * float(H)), H - 1u);
	float pdfY = (EnvCdf(y + 1u, H) - EnvCdf(y, H)) * float(H);
	float pdfX = (EnvCdf(x + 1u, y) - EnvCdf(x, y)) * float(W);
	float cosElevation = sqrt(clamp(1.0 - local.y * local.y, 1e-6, 1.0));
	return pdfX * pdfY / (2.0 * PI * PI * cosElevation);
}

// The sample direction is -normal, matching the legacy convention for distant lights.
LightSample SampleEnvironment(inout RandomSequence rng)
{
	LightSample s;
	s.position = float3(0.0);
	s.delta = false;
	s.shadow = true;
	float2 u = rng.Next2D();
	float3 dir;
	if ((gFrame.settings.z & FRAME_FLAG_ENV_IMPORTANCE) == 0u)
	{
		float z = 1.0 - 2.0 * u.x;
		float r = sqrt(max(0.0, 1.0 - z * z));
		float phi = TWO_PI * u.y;
		dir = float3(r * cos(phi), r * sin(phi), z);
		s.solidAnglePdf = 1.0 / (4.0 * PI);
	}
	else
	{
		uint W = gFrame.envInfo.x;
		uint H = gFrame.envInfo.y;
		uint y = SearchCdfRow(H, H, u.y);
		float cy0 = EnvCdf(y, H);
		float cy1 = EnvCdf(y + 1u, H);
		float dv = cy1 > cy0 ? (u.y - cy0) / (cy1 - cy0) : 0.5;

		uint x = SearchCdfRow(y, W, u.x);
		float cx0 = EnvCdf(x, y);
		float cx1 = EnvCdf(x + 1u, y);
		float du = cx1 > cx0 ? (u.x - cx0) / (cx1 - cx0) : 0.5;

		float pdfUV = (cy1 - cy0) * float(H) * (cx1 - cx0) * float(W);
		float2 uv = float2((float(x) + du) / float(W), (float(y) + dv) / float(H));
		float cosElevation;
		float3 local = EquirectUVToDirection(uv, cosElevation);
		dir = RotateY(local, gFrame.envParams.y);
		s.solidAnglePdf = pdfUV / (2.0 * PI * PI * max(cosElevation, 1e-6));
	}
	s.normal = -dir;
	s.radiance = EvalEnvironment(dir);
	return s;
}

// ---- sun ----

bool SunEnabled()
{
	return (gFrame.settings.z & FRAME_FLAG_SUN) != 0u;
}

bool HitsSun(float3 dir)
{
	return SunEnabled() && dot(dir, gFrame.sunDirection.xyz) >= gFrame.sunDirection.w;
}

// Returns a direction toward the sun in s.normal's opposite; pdf over the sun's solid angle.
LightSample SampleSun(inout RandomSequence rng)
{
	LightSample s;
	float3 toSun = gFrame.sunDirection.xyz;
	float3 t;
	float3 b;
	BranchlessONB(toSun, t, b);
	float2 disk = SampleDisk(rng.Next2D());
	float sinHalfAngle = sqrt(max(0.0, 1.0 - Square(gFrame.sunDirection.w)));
	float3 dir = normalize(toSun + (t * disk.x + b * disk.y) * sinHalfAngle);
	s.position = float3(0.0);
	s.normal = -dir;
	s.radiance = gFrame.sunRadiance.rgb;
	s.solidAnglePdf = 1.0 / gFrame.sunRadiance.w;
	s.delta = false;
	s.shadow = true;
	return s;
}

// ---- emissive triangles ----

uint LightCount()
{
	return gFrame.counts.y;
}

// First light whose inclusive CDF exceeds u.
uint SelectLight(float u)
{
	uint lo = 0u;
	uint hi = LightCount() - 1u;
	while (lo < hi)
	{
		uint mid = (lo + hi) >> 1u;
		if (gLights[mid].p2.w > u)
		{
			hi = mid;
		}
		else
		{
			lo = mid + 1u;
		}
	}
	return lo;
}

float3 EmissiveRadiance(MaterialHeader material, TextureCoords tc)
{
	if (material.AlphaMode() == ALPHA_MODE_MASK && EvalOpacity(material, tc) < material.alphaCutoff)
	{
		return float3(0.0);
	}
	return EvalEmission(material, tc);
}

// Area pdf -> solid angle pdf, 0 when the viewer is behind a one-sided emitter.
float EmissiveSolidAnglePdf(float area, bool doubleSided, float3 viewer, float3 lightPos, float3 lightNormal)
{
	float3 toLight = lightPos - viewer;
	float distSq = dot(toLight, toLight);
	if (distSq <= 1e-12)
	{
		return 0.0;
	}
	float3 L = toLight * rsqrt(distSq);
	float cosTheta = dot(lightNormal, -L);
	if (doubleSided)
	{
		cosTheta = abs(cosTheta);
	}
	if (cosTheta <= 1e-6)
	{
		return 0.0;
	}
	return distSq / (cosTheta * area);
}

// ---- analytic lights (Cycles conventions: intern/cycles/kernel/light) ----

uint AnalyticLightCount()
{
	return gFrame.counts.w;
}

uint AnalyticFlags(EmissiveTriangle light)
{
	return asuint(light.n.w);
}

// Blender spot cone: smoothstep over the blend region, measured from the light toward `dir`.
float SpotAttenuation(EmissiveTriangle light, float3 dir)
{
	if ((AnalyticFlags(light) & LIGHT_TYPE_MASK) != LIGHT_TYPE_SPOT)
	{
		return 1.0;
	}
	float x = dot(dir, light.p2.xyz) - light.uvA.w;
	float scale = light.uvB.x;
	return scale > 0.0 ? smoothstep(0.0, 1.0, x * scale) : (x > 0.0 ? 1.0 : 0.0);
}

// 1 - cos of the half angle the sphere subtends, stable for small spheres; 0 inside it.
float SphereOneMinusCos(float radius, float distSq)
{
	float sinSq = radius * radius / distSq;
	return sinSq < 1.0 ? sinSq / (1.0 + sqrt(1.0 - sinSq)) : 0.0;
}

// Point on the rectangle / ellipse for u in [0, 1)^2.
float3 AreaLightPoint(EmissiveTriangle light, float2 u)
{
	float2 d = (AnalyticFlags(light) & LIGHT_ELLIPSE) != 0u ? SampleDisk(u) * 0.5 : u - 0.5;
	return light.p0.xyz + light.n.xyz * d.x + light.uvA.xyz * d.y;
}

LightSample SampleAnalytic(EmissiveTriangle light, float3 viewer, inout RandomSequence rng)
{
	LightSample s;
	s.delta = false;
	s.shadow = true;
	s.radiance = float3(0.0);
	s.solidAnglePdf = 0.0;
	s.shadow = (AnalyticFlags(light) & LIGHT_NO_SHADOW) == 0u;
	float2 u = rng.Next2D();
	uint type = AnalyticFlags(light) & LIGHT_TYPE_MASK;
	if (type == LIGHT_TYPE_AREA)
	{
		s.position = AreaLightPoint(light, u);
		s.normal = light.p2.xyz;
		float3 toLight = s.position - viewer;
		float distSq = dot(toLight, toLight);
		float cosTheta = -dot(s.normal, toLight) * rsqrt(max(distSq, 1e-20));
		if (cosTheta > 1e-6)
		{
			s.radiance = light.p1.xyz;
			s.solidAnglePdf = light.p1.w * distSq / (cosTheta * light.p0.w);
		}
		return s;
	}

	float3 toCenter = light.p0.xyz - viewer;
	float distSq = dot(toCenter, toCenter);
	float dist = sqrt(distSq);
	float3 w = toCenter / max(dist, 1e-20);
	float radius = light.p0.w;
	if (radius <= 0.0)
	{
		s.position = light.p0.xyz;
		s.normal = -w;
		s.radiance = light.p1.xyz * SpotAttenuation(light, -w) / max(distSq, 1e-20);
		s.solidAnglePdf = light.p1.w;
		s.delta = true;
		return s;
	}
	float oneMinusCosMax = SphereOneMinusCos(radius, distSq);
	if (oneMinusCosMax <= 0.0)
	{
		s.position = light.p0.xyz;
		s.normal = -w;
		return s;
	}
	// uniform direction in the cone the sphere subtends
	float oneMinusCos = u.x * oneMinusCosMax;
	float cosTheta = 1.0 - oneMinusCos;
	float sinTheta = sqrt(max(0.0, oneMinusCos * (2.0 - oneMinusCos)));
	float phi = TWO_PI * u.y;
	float3 t;
	float3 b;
	BranchlessONB(w, t, b);
	float3 dir = (t * cos(phi) + b * sin(phi)) * sinTheta + w * cosTheta;
	float tc = dot(toCenter, dir);
	float hitT = tc - sqrt(max(0.0, radius * radius - (distSq - tc * tc)));
	s.position = viewer + dir * hitT;
	s.normal = normalize(s.position - light.p0.xyz);
	s.radiance = light.p1.xyz * SpotAttenuation(light, -w);
	s.solidAnglePdf = light.p1.w / (TWO_PI * oneMinusCosMax);
	return s;
}

// Nearest analytic light along a ray (before tMax) that BSDF sampling could hit. Returns its
// radiance and the pdf light sampling would have chosen that direction with.
bool IntersectAnalyticLights(float3 origin, float3 dir, float tMax, bool cameraRay, out float3 radiance, out float pdf)
{
	radiance = float3(0.0);
	pdf = 0.0;
	float nearest = tMax;
	bool found = false;
	for (uint i = 0u; i < AnalyticLightCount(); i++)
	{
		EmissiveTriangle light = gLights[i];
		uint flags = AnalyticFlags(light);
		if (cameraRay && (flags & LIGHT_HIDDEN_FROM_CAMERA) != 0u)
		{
			continue;
		}
		uint type = flags & LIGHT_TYPE_MASK;
		if (type == LIGHT_TYPE_AREA)
		{
			float3 n = light.p2.xyz;
			float cosTheta = -dot(n, dir);
			if (cosTheta <= 1e-6)
			{
				continue;
			}
			float t = dot(light.p0.xyz - origin, n) / -cosTheta;
			if (t <= 0.0 || t >= nearest)
			{
				continue;
			}
			float3 local = origin + dir * t - light.p0.xyz;
			float2 d = float2(dot(local, light.n.xyz) / dot(light.n.xyz, light.n.xyz), dot(local, light.uvA.xyz) / dot(light.uvA.xyz, light.uvA.xyz));
			bool inside = (flags & LIGHT_ELLIPSE) != 0u ? dot(d, d) <= 0.25 : all(abs(d) <= 0.5);
			if (!inside)
			{
				continue;
			}
			nearest = t;
			found = true;
			radiance = light.p1.xyz;
			pdf = light.p1.w * t * t / (cosTheta * light.p0.w);
		}
		else
		{
			float radius = light.p0.w;
			if (radius <= 0.0)
			{
				continue;
			}
			float3 toCenter = light.p0.xyz - origin;
			float distSq = dot(toCenter, toCenter);
			float tc = dot(toCenter, dir);
			float h = radius * radius - (distSq - tc * tc);
			if (h < 0.0 || distSq <= radius * radius)
			{
				continue;
			}
			float t = tc - sqrt(h);
			if (t <= 0.0 || t >= nearest)
			{
				continue;
			}
			nearest = t;
			found = true;
			radiance = light.p1.xyz * SpotAttenuation(light, -toCenter * rsqrt(distSq));
			pdf = light.p1.w / (TWO_PI * SphereOneMinusCos(radius, distSq));
		}
	}
	return found;
}

// solidAnglePdf includes the selection probability. cone: ray cone (width, spread) at the viewer.
LightSample SampleEmissive(float3 viewer, float2 cone, inout RandomSequence rng)
{
	LightSample s;
	s.delta = false;
	s.shadow = true;
	uint index = SelectLight(rng.Next());
	EmissiveTriangle light = gLights[index];
	if ((AnalyticFlags(light) & LIGHT_ANALYTIC) != 0u)
	{
		return SampleAnalytic(light, viewer, rng);
	}
	float3 bary = SampleTriangle(rng.Next2D());
	s.position = light.p0.xyz * bary.x + light.p1.xyz * bary.y + light.p2.xyz * bary.z;
	s.normal = light.n.xyz;

	MaterialHeader material = LoadMaterialHeader(asuint(light.n.w));
	bool doubleSided = material.DoubleSided();
	float3 toLight = s.position - viewer;
	float dist = length(toLight);
	TextureCoords tc = MakeTextureCoords(
		light.uvA.xy * bary.x + light.uvA.zw * bary.y + light.uvB.xy * bary.z,
		light.uvB.zw * bary.x + light.uvC.xy * bary.y + light.uvC.zw * bary.z,
		light.p1.xyz - light.p0.xyz, light.p2.xyz - light.p0.xyz,
		light.uvA.zw - light.uvA.xy, light.uvB.xy - light.uvA.xy,
		light.uvC.xy - light.uvB.zw, light.uvC.zw - light.uvB.zw,
		cone.x + cone.y * dist, dist > 0.0 ? dot(s.normal, toLight) / dist : 1.0);
	tc.objectPosition = InverseTransformPoint(gInstances[asuint(light.pad.x)], s.position);
	s.radiance = EmissiveRadiance(material, tc);
	s.solidAnglePdf = light.p1.w * EmissiveSolidAnglePdf(light.p0.w, doubleSided, viewer, s.position, s.normal);
	if (doubleSided && dot(s.normal, viewer - s.position) < 0.0)
	{
		s.normal = -s.normal;
	}
	return s;
}

// Geometry-only NEE sampling for the staged integrator. No nonconstant material
// evaluation is reachable here; the sampled emitter is evaluated by ShadeLight.
LightSample SampleEmissiveGeometry(float3 viewer, inout RandomSequence rng, out uint index, out float3 bary)
{
	index = SelectLight(rng.Next());
	bary = float3(0.0);
	EmissiveTriangle light = gLights[index];
	if ((AnalyticFlags(light) & LIGHT_ANALYTIC) != 0u) return SampleAnalytic(light, viewer, rng);
	bary = SampleTriangle(rng.Next2D());
	LightSample s;
	s.delta = false; s.shadow = true;
	s.position = light.p0.xyz * bary.x + light.p1.xyz * bary.y + light.p2.xyz * bary.z;
	s.normal = light.n.xyz;
	MaterialHeader material = LoadMaterialHeader(asuint(light.n.w));
	s.radiance = ((material.flags >> 26u) & 31u) == 0u ? ConstantEmissiveRadiance(material) : float3(1.0);
	s.solidAnglePdf = light.p1.w * EmissiveSolidAnglePdf(light.p0.w, material.DoubleSided(), viewer, s.position, s.normal);
	if (material.DoubleSided() && dot(s.normal, viewer - s.position) < 0.0) s.normal = -s.normal;
	return s;
}

float3 EvalSampledEmission(uint index, float3 bary, float3 viewer, float2 cone)
{
	EmissiveTriangle light = gLights[index];
	float3 position = light.p0.xyz * bary.x + light.p1.xyz * bary.y + light.p2.xyz * bary.z;
	float3 toLight = position - viewer;
	float dist = length(toLight);
	TextureCoords tc = MakeTextureCoords(
		light.uvA.xy * bary.x + light.uvA.zw * bary.y + light.uvB.xy * bary.z,
		light.uvB.zw * bary.x + light.uvC.xy * bary.y + light.uvC.zw * bary.z,
		light.p1.xyz - light.p0.xyz, light.p2.xyz - light.p0.xyz,
		light.uvA.zw - light.uvA.xy, light.uvB.xy - light.uvA.xy,
		light.uvC.xy - light.uvB.zw, light.uvC.zw - light.uvB.zw,
		cone.x + cone.y * dist, dist > 0.0 ? dot(light.n.xyz, toLight) / dist : 1.0);
	tc.objectPosition = InverseTransformPoint(gInstances[asuint(light.pad.x)], position);
	return EmissiveRadiance(LoadMaterialHeader(asuint(light.n.w)), tc);
}

// Pdf with which SampleEmissive would have produced a BSDF-sampled hit on an emitter.
float EmissiveHitPdf(Instance inst, uint primitiveIndex, float3 viewer, float3 hitPos)
{
	if ((inst.flags & INSTANCE_FLAG_EMISSIVE) == 0u)
	{
		return 0.0;
	}
	EmissiveTriangle light = gLights[inst.lightOffset + primitiveIndex];
	bool doubleSided = LoadMaterialHeader(asuint(light.n.w)).DoubleSided();
	return light.p1.w * EmissiveSolidAnglePdf(light.p0.w, doubleSided, viewer, hitPos, light.n.xyz);
}
