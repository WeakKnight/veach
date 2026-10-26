// GPU sky bake, a port of the TypeScript reference in src/render/Atmosphere.ts (Hillaire 2020; keep
// the two in sync, tests/atmosphere.test.ts covers the reference). Static passes build the
// transmittance and multiple-scattering LUTs; each sun change rebuilds the sky-view LUT (sky rows,
// sky irradiance, ground rows), resamples it into the equirect environment map and rebuilds the
// map's importance-sampling CDF in the layout of buildEnvironmentCdf (src/render/Environment.ts).
// Distances are in megameters, coefficients per megameter.
import Common.Math;

struct AtmosphereUniforms
{
	float4 sunDirection; // unit vector toward the sun in the environment map's frame
	float4 illuminance;	 // rgb outer-space sun illuminance
};

[[vk::binding(0, 0)]] ConstantBuffer<AtmosphereUniforms> gAtmosphere;
[[vk::binding(1, 0)]] Texture2D<float4> gTransmittance;
[[vk::binding(2, 0)]] Texture2D<float4> gMultiScattering;
[[vk::binding(3, 0)]] Texture2D<float4> gSkyView;
[[vk::binding(4, 0)]] Texture2D<float4> gEnvironment;
// [0, 3) sky irradiance on the ground, [4, 4 + height) environment row sums
[[vk::binding(5, 0)]] RWStructuredBuffer<float> gScratch;
[[vk::binding(6, 0)]] [format("rgba32f")] WTexture2D<float4> gLutOut;
[[vk::binding(7, 0)]] [format("rgba16f")] WTexture2D<float4> gEnvironmentOut;
[[vk::binding(8, 0)]] [format("r32f")] WTexture2D<float> gCdfOut;

static const float GROUND_RADIUS = 6.36;
static const float ATMOSPHERE_RADIUS = 6.46;
static const float VIEW_RADIUS = GROUND_RADIUS + 0.0002;
static const float GROUND_ALBEDO = 0.3;

static const float3 RAYLEIGH_SCATTERING = float3(5.802, 13.558, 33.1);
static const float MIE_SCATTERING = 3.996;
static const float MIE_ABSORPTION = 4.4;
static const float3 OZONE_ABSORPTION = float3(0.65, 1.881, 0.085);
static const float MIE_G = 0.8;

static const uint TRANSMITTANCE_STEPS = 40;
static const uint MULTI_SCATTERING_STEPS = 20;
static const uint MULTI_SCATTERING_SQRT_DIRECTIONS = 8;
static const uint SKY_VIEW_STEPS = 32;

static const int2 TRANSMITTANCE_SIZE = int2(256, 64);
static const int2 MULTI_SCATTERING_SIZE = int2(32, 32);
static const int2 SKY_VIEW_SIZE = int2(200, 200);
static const int2 ENVIRONMENT_SIZE = int2(512, 256);

static const float HALF_PI = 0.5 * PI;
static const float ISOTROPIC_PHASE = 0.25 * INV_PI;
static const float HALF_MAX = 65504.0;

float RayleighPhase(float cosTheta)
{
	return 3.0 / (16.0 * PI) * (1.0 + cosTheta * cosTheta);
}

// Cornette-Shanks
float MiePhase(float cosTheta)
{
	float g2 = MIE_G * MIE_G;
	float num = (1.0 - g2) * (1.0 + cosTheta * cosTheta);
	float denom = (2.0 + g2) * pow(1.0 + g2 - 2.0 * MIE_G * cosTheta, 1.5);
	return 3.0 / (8.0 * PI) * num / denom;
}

struct Medium
{
	float3 rayleighScattering;
	float mieScattering;
	float3 extinction;
};

Medium SampleMedium(float r)
{
	float altitudeKm = max(0.0, (r - GROUND_RADIUS) * 1000.0);
	float rayleigh = exp(-altitudeKm / 8.0);
	float mie = exp(-altitudeKm / 1.2);
	float ozone = max(0.0, 1.0 - abs(altitudeKm - 25.0) / 15.0);
	Medium m;
	m.rayleighScattering = RAYLEIGH_SCATTERING * rayleigh;
	m.mieScattering = MIE_SCATTERING * mie;
	m.extinction = m.rayleighScattering + (MIE_SCATTERING + MIE_ABSORPTION) * mie + OZONE_ABSORPTION * ozone;
	return m;
}

// Distance along a unit ray to a sphere around the planet center: the nearest hit from outside,
// the exit from inside, -1 on a miss.
float IntersectSphere(float3 o, float3 d, float radius)
{
	float b = dot(o, d);
	float c = dot(o, o) - radius * radius;
	if (c > 0.0 && b > 0.0)
		return -1.0;
	float disc = b * b - c;
	if (disc < 0.0)
		return -1.0;
	return disc > b * b ? -b + sqrt(disc) : -b - sqrt(disc);
}

// Quadratic spacing concentrates steps near the start of the ray, where the Mie layer lives.
float MarchEnd(uint s, uint n, float tMax)
{
	float x = float(s + 1u) / float(n);
	return x * x * tMax;
}

// Bilinear with clamp-to-edge on unfilterable rgba32float LUTs.
float3 SampleLut(Texture2D<float4> lut, int2 size, float2 uv)
{
	float2 p = clamp(uv * float2(size) - 0.5, float2(0.0), float2(size - 1));
	int2 p0 = int2(floor(p));
	int2 p1 = min(p0 + 1, size - 1);
	float2 f = p - float2(p0);
	float3 a = lut.Load(int3(p0.x, p0.y, 0)).rgb;
	float3 b = lut.Load(int3(p1.x, p0.y, 0)).rgb;
	float3 c = lut.Load(int3(p0.x, p1.y, 0)).rgb;
	float3 d = lut.Load(int3(p1.x, p1.y, 0)).rgb;
	return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

// (cos sun zenith, sqrt altitude fraction) parameterization shared by both altitude LUTs.
float2 AltitudeLutUV(float r, float cosSunZenith)
{
	return float2(0.5 + 0.5 * cosSunZenith, sqrt(max(0.0, (r - GROUND_RADIUS) / (ATMOSPHERE_RADIUS - GROUND_RADIUS))));
}

void TexelToAltitudeParams(int2 p, int2 size, out float r, out float cosSun)
{
	cosSun = 2.0 * (float(p.x) + 0.5) / float(size.x) - 1.0;
	float v = (float(p.y) + 0.5) / float(size.y);
	r = GROUND_RADIUS + v * v * (ATMOSPHERE_RADIUS - GROUND_RADIUS);
}

float3 TransmittanceToTop(float r, float cosZenith)
{
	float3 o = float3(0.0, r, 0.0);
	float3 d = float3(0.0, cosZenith, -sqrt(max(0.0, 1.0 - cosZenith * cosZenith)));
	if (IntersectSphere(o, d, GROUND_RADIUS) > 0.0)
		return float3(0.0);
	float tMax = IntersectSphere(o, d, ATMOSPHERE_RADIUS);
	float3 depth = float3(0.0);
	float t0 = 0.0;
	for (uint s = 0u; s < TRANSMITTANCE_STEPS; s++)
	{
		float t1 = MarchEnd(s, TRANSMITTANCE_STEPS, tMax);
		float dt = t1 - t0;
		float t = t0 + 0.5 * dt;
		t0 = t1;
		depth += dt * SampleMedium(length(o + t * d)).extinction;
	}
	return exp(-depth);
}

float3 SunTransmittanceAt(float3 p, float3 sun)
{
	float r = length(p);
	return SampleLut(gTransmittance, TRANSMITTANCE_SIZE, AltitudeLutUV(r, dot(p, sun) / r));
}

// Lambertian ground lit by the attenuated sun, per unit sun illuminance.
float3 GroundRadiance(float3 p, float3 sun)
{
	float cosSun = dot(normalize(p), sun);
	if (cosSun <= 0.0)
		return float3(0.0);
	return SampleLut(gTransmittance, TRANSMITTANCE_SIZE, AltitudeLutUV(GROUND_RADIUS, cosSun)) * (GROUND_ALBEDO * INV_PI * cosSun);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void TransmittanceLut(uint3 id: SV_DispatchThreadID)
{
	if (any(id.xy >= uint2(TRANSMITTANCE_SIZE)))
		return;
	float r;
	float cosSun;
	TexelToAltitudeParams(int2(id.xy), TRANSMITTANCE_SIZE, r, cosSun);
	gLutOut.Store(id.xy, float4(TransmittanceToTop(r, cosSun), 1.0));
}

// Psi_ms (paper Eq. 10): second-order luminance with an isotropic phase, divided by 1 - f_ms.
[shader("compute")]
[numthreads(8, 8, 1)]
void MultiScatteringLut(uint3 id: SV_DispatchThreadID)
{
	if (any(id.xy >= uint2(MULTI_SCATTERING_SIZE)))
		return;
	float r;
	float cosSun;
	TexelToAltitudeParams(int2(id.xy), MULTI_SCATTERING_SIZE, r, cosSun);
	float3 o = float3(0.0, r, 0.0);
	float3 sun = float3(0.0, cosSun, -sqrt(max(0.0, 1.0 - cosSun * cosSun)));
	const uint n = MULTI_SCATTERING_SQRT_DIRECTIONS;
	float invDirections = 1.0 / float(n * n);
	float3 lum = float3(0.0);
	float3 fms = float3(0.0);
	// symmetric about the sun plane, so half the azimuths suffice
	for (uint i = 0u; i < n; i++)
	{
		float theta = PI * (float(i) + 0.5) / float(n);
		for (uint j = 0u; j < n; j++)
		{
			float cosPhi = 1.0 - 2.0 * (float(j) + 0.5) / float(n);
			float sinPhi = sqrt(1.0 - cosPhi * cosPhi);
			float3 d = float3(sinPhi * sin(theta), cosPhi, sinPhi * cos(theta));
			float groundDist = IntersectSphere(o, d, GROUND_RADIUS);
			float tMax = groundDist > 0.0 ? groundDist : IntersectSphere(o, d, ATMOSPHERE_RADIUS);
			float3 tr = float3(1.0);
			float t0 = 0.0;
			for (uint s = 0u; s < MULTI_SCATTERING_STEPS; s++)
			{
				float t1 = MarchEnd(s, MULTI_SCATTERING_STEPS, tMax);
				float dt = t1 - t0;
				float t = t0 + 0.5 * dt;
				t0 = t1;
				float3 p = o + t * d;
				Medium m = SampleMedium(length(p));
				float3 segment = exp(-dt * m.extinction);
				float3 scattering = m.rayleighScattering + m.mieScattering;
				float3 integral = (1.0 - segment) / m.extinction;
				fms += tr * scattering * integral * invDirections;
				lum += tr * scattering * ISOTROPIC_PHASE * SunTransmittanceAt(p, sun) * integral * invDirections;
				tr *= segment;
			}
			if (groundDist > 0.0)
				lum += tr * GroundRadiance(o + groundDist * d, sun) * invDirections;
		}
	}
	gLutOut.Store(id.xy, float4(lum / (1.0 - fms), 1.0));
}

// Altitude of the geometric horizon seen from the viewer (slightly below 0).
float HorizonAltitude()
{
	return -acos(GROUND_RADIUS / VIEW_RADIUS);
}

// Sky-view v is quadratic in altitude on either side of the horizon (paper Section 5.3).
float SkyViewVToAltitude(float v)
{
	float horizon = HorizonAltitude();
	if (v >= 0.5)
	{
		float c = 2.0 * v - 1.0;
		return horizon + (HALF_PI - horizon) * c * c;
	}
	float c = 1.0 - 2.0 * v;
	return horizon - (HALF_PI + horizon) * c * c;
}

float AltitudeToSkyViewV(float altitude)
{
	float horizon = HorizonAltitude();
	if (altitude >= horizon)
		return 0.5 + 0.5 * sqrt(min(1.0, (altitude - horizon) / (HALF_PI - horizon)));
	return 0.5 - 0.5 * sqrt(min(1.0, (horizon - altitude) / (HALF_PI + horizon)));
}

// Sky luminance per unit sun illuminance: u is the azimuth relative to the sun (0.5 = toward it),
// v the remapped altitude. Single scattering + Psi_ms; ground rows add the Lambertian ground lit by
// the sun and by the sky irradiance from SkyIrradiance.
void SkyViewTexel(int2 p)
{
	float altitude = SkyViewVToAltitude((float(p.y) + 0.5) / float(SKY_VIEW_SIZE.y));
	float azimuth = ((float(p.x) + 0.5) / float(SKY_VIEW_SIZE.x) - 0.5) * TWO_PI;
	float cosAlt = cos(altitude);
	float3 d = float3(cosAlt * sin(azimuth), sin(altitude), -cosAlt * cos(azimuth));
	float sy = gAtmosphere.sunDirection.y;
	float3 sun = float3(0.0, sy, -sqrt(max(0.0, 1.0 - sy * sy)));
	float cosTheta = dot(d, sun);
	float phaseR = RayleighPhase(cosTheta);
	float phaseM = MiePhase(cosTheta);
	float3 o = float3(0.0, VIEW_RADIUS, 0.0);
	float groundDist = IntersectSphere(o, d, GROUND_RADIUS);
	float tMax = groundDist > 0.0 ? groundDist : IntersectSphere(o, d, ATMOSPHERE_RADIUS);
	float3 lum = float3(0.0);
	float3 tr = float3(1.0);
	float t0 = 0.0;
	for (uint s = 0u; s < SKY_VIEW_STEPS; s++)
	{
		float t1 = MarchEnd(s, SKY_VIEW_STEPS, tMax);
		float dt = t1 - t0;
		float t = t0 + 0.5 * dt;
		t0 = t1;
		float3 pos = o + t * d;
		float r = length(pos);
		float2 uv = AltitudeLutUV(r, dot(pos, sun) / r);
		float3 sunTr = SampleLut(gTransmittance, TRANSMITTANCE_SIZE, uv);
		float3 psi = SampleLut(gMultiScattering, MULTI_SCATTERING_SIZE, uv);
		Medium m = SampleMedium(r);
		float3 segment = exp(-dt * m.extinction);
		float3 inScattering = m.rayleighScattering * (phaseR * sunTr + psi) + m.mieScattering * (phaseM * sunTr + psi);
		lum += tr * inScattering * (1.0 - segment) / m.extinction;
		tr *= segment;
	}
	if (groundDist > 0.0)
	{
		float3 skyIrradiance = float3(gScratch[0], gScratch[1], gScratch[2]);
		lum += tr * (GroundRadiance(o + groundDist * d, sun) + GROUND_ALBEDO * INV_PI * skyIrradiance);
	}
	gLutOut.Store(p, float4(lum, 1.0));
}

// Rows above the horizon (v >= 0.5) never hit the ground.
[shader("compute")]
[numthreads(8, 8, 1)]
void SkyViewSkyRows(uint3 id: SV_DispatchThreadID)
{
	int2 p = int2(id.xy) + int2(0, SKY_VIEW_SIZE.y / 2);
	if (p.x < SKY_VIEW_SIZE.x && p.y < SKY_VIEW_SIZE.y)
		SkyViewTexel(p);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void SkyViewGroundRows(uint3 id: SV_DispatchThreadID)
{
	int2 p = int2(id.xy);
	if (p.x < SKY_VIEW_SIZE.x && p.y < SKY_VIEW_SIZE.y / 2)
		SkyViewTexel(p);
}

static const uint IRRADIANCE_THREADS = 64;
groupshared float3 gsIrradiance[IRRADIANCE_THREADS];

// Cosine-weighted integral of the sky rows over the upper hemisphere; one workgroup.
[shader("compute")]
[numthreads(IRRADIANCE_THREADS, 1, 1)]
void SkyIrradiance(uint3 tid: SV_GroupThreadID)
{
	const int rows = SKY_VIEW_SIZE.y / 2;
	float3 sum = float3(0.0);
	for (int i = int(tid.x); i < SKY_VIEW_SIZE.x * rows; i += int(IRRADIANCE_THREADS))
	{
		int x = i % SKY_VIEW_SIZE.x;
		int y = rows + i / SKY_VIEW_SIZE.x;
		float altitude = SkyViewVToAltitude((float(y) + 0.5) / float(SKY_VIEW_SIZE.y));
		float dAltitude = SkyViewVToAltitude(float(y + 1) / float(SKY_VIEW_SIZE.y)) - SkyViewVToAltitude(float(y) / float(SKY_VIEW_SIZE.y));
		float weight = max(0.0, sin(altitude)) * cos(altitude) * dAltitude * TWO_PI / float(SKY_VIEW_SIZE.x);
		sum += gSkyView.Load(int3(x, y, 0)).rgb * weight;
	}
	gsIrradiance[tid.x] = sum;
	GroupMemoryBarrierWithGroupSync();
	for (uint stride = IRRADIANCE_THREADS / 2u; stride > 0u; stride >>= 1u)
	{
		if (tid.x < stride)
			gsIrradiance[tid.x] += gsIrradiance[tid.x + stride];
		GroupMemoryBarrierWithGroupSync();
	}
	if (tid.x == 0u)
	{
		gScratch[0] = gsIrradiance[0].x;
		gScratch[1] = gsIrradiance[0].y;
		gScratch[2] = gsIrradiance[0].z;
	}
}

float3 SkyViewRadiance(float3 dir, float3 sun)
{
	float altitude = asin(clamp(dir.y, -1.0, 1.0));
	// azimuth relative to the sun's horizontal direction; arbitrary when either is vertical
	float2 f = sun.xz;
	float fLen = length(f);
	f = fLen > 1e-6 ? f / fLen : float2(0.0, -1.0);
	float forward = dir.x * f.x + dir.z * f.y;
	float right = dir.z * f.x - dir.x * f.y;
	float azimuth = forward == 0.0 && right == 0.0 ? 0.0 : atan2(right, forward);
	return SampleLut(gSkyView, SKY_VIEW_SIZE, float2(azimuth * INV_TWO_PI + 0.5, AltitudeToSkyViewV(altitude)));
}

[shader("compute")]
[numthreads(8, 8, 1)]
void BakeEnvironment(uint3 id: SV_DispatchThreadID)
{
	if (any(id.xy >= uint2(ENVIRONMENT_SIZE)))
		return;
	float cosElevation;
	float3 dir = EquirectUVToDirection((float2(id.xy) + 0.5) / float2(ENVIRONMENT_SIZE), cosElevation);
	float3 radiance = SkyViewRadiance(dir, gAtmosphere.sunDirection.xyz) * gAtmosphere.illuminance.rgb;
	gEnvironmentOut.Store(id.xy, float4(min(radiance, float3(HALF_MAX)), 1.0));
}

// Conditional CDF of one environment row (width + 1 entries, uniform when the row is black), and
// the row's cos-weighted luminance sum for the marginal.
[shader("compute")]
[numthreads(64, 1, 1)]
void CdfRows(uint3 id: SV_DispatchThreadID)
{
	const int W = ENVIRONMENT_SIZE.x;
	const int H = ENVIRONMENT_SIZE.y;
	int y = int(id.x);
	if (y >= H)
		return;
	float cosElevation = cos(((float(y) + 0.5) / float(H) - 0.5) * PI);
	float sum = 0.0;
	for (int x = 0; x < W; x++)
		sum += max(Luminance(gEnvironment.Load(int3(x, y, 0)).rgb), 0.0) * cosElevation;
	gScratch[4 + y] = sum;
	gCdfOut.Store(int2(0, y), 0.0);
	float running = 0.0;
	for (int x = 1; x < W; x++)
	{
		running += max(Luminance(gEnvironment.Load(int3(x - 1, y, 0)).rgb), 0.0) * cosElevation;
		gCdfOut.Store(int2(x, y), sum > 0.0 ? running / sum : float(x) / float(W));
	}
	gCdfOut.Store(int2(W, y), 1.0);
}

// Marginal CDF over the rows (height + 1 entries) in row `height`.
[shader("compute")]
[numthreads(1, 1, 1)]
void CdfMarginal()
{
	const int H = ENVIRONMENT_SIZE.y;
	float total = 0.0;
	for (int y = 0; y < H; y++)
		total += gScratch[4 + y];
	gCdfOut.Store(int2(0, H), 0.0);
	float running = 0.0;
	for (int y = 1; y < H; y++)
	{
		running += gScratch[4 + y - 1];
		gCdfOut.Store(int2(y, H), total > 0.0 ? running / total : float(y) / float(H));
	}
	gCdfOut.Store(int2(H, H), 1.0);
}
