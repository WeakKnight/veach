// Shared math helpers (ported from Legacy/Source/Math and Legacy/Source/XPU).

// Prefer Slang built-ins (lerp, saturate, rcp, rsqrt, reflect, refract, isfinite, ...); only
// helpers without a built-in usable on the WGSL target live here.
static const float PI = float.getPi();
static const float TWO_PI = 2.0 * PI;
static const float INV_PI = 1.0 / PI;
static const float INV_TWO_PI = 0.5 / PI;
static const float FLT_LARGE = 1e30;

float Square(float x)
{
	return x * x;
}

// max3() requires capabilities WGSL does not have.
float MaxComponent(float3 v)
{
	return max(v.x, max(v.y, v.z));
}

float Luminance(float3 color)
{
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Duff et al. 2017, "Building an Orthonormal Basis, Revisited".
void BranchlessONB(float3 n, out float3 b1, out float3 b2)
{
	float s = n.z >= 0.0 ? 1.0 : -1.0;
	float a = -1.0 / (s + n.z);
	float b = n.x * n.y * a;
	b1 = float3(1.0 + s * n.x * n.x * a, s * b, -s * n.x);
	b2 = float3(b, s + n.y * n.y * a, -n.y);
}

// Orthonormal shading frame: t x b = n.
struct Frame
{
	float3 t;
	float3 b;
	float3 n;

	static Frame FromNormal(float3 n)
	{
		Frame f;
		f.n = n;
		BranchlessONB(n, f.t, f.b);
		return f;
	}

	// Uses the mesh tangent when it is present, non-degenerate and not parallel to the normal.
	static Frame FromTangent(float4 tangent, float3 n)
	{
		float NdotT = dot(tangent.xyz, n);
		bool valid = tangent.w != 0.0 && dot(tangent.xyz, tangent.xyz) > 0.0 && abs(NdotT) < 0.9999;
		if (!valid)
		{
			return FromNormal(n);
		}
		Frame f;
		f.n = n;
		f.t = normalize(tangent.xyz - n * NdotT);
		f.b = cross(n, f.t) * tangent.w;
		return f;
	}

	float3 ToLocal(float3 v)
	{
		return float3(dot(v, t), dot(v, b), dot(v, n));
	}

	float3 ToWorld(float3 v)
	{
		return v.x * t + v.y * b + v.z * n;
	}
};

// pdf = cos(theta) / PI
float3 SampleCosineHemisphere(float2 u)
{
	float phi = TWO_PI * u.x;
	float cosTheta = sqrt(u.y);
	float sinTheta = sqrt(1.0 - u.y);
	return float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
}

float2 SampleDisk(float2 u)
{
	float angle = TWO_PI * u.x;
	return float2(cos(angle), sin(angle)) * sqrt(u.y);
}

// Uniform barycentrics on a triangle.
float3 SampleTriangle(float2 u)
{
	float su = sqrt(u.x);
	return float3(1.0 - su, su * (1.0 - u.y), su * u.y);
}

// Power heuristic, robust against 0 and +inf inputs; w(a, b) + w(b, a) == 1.
float EvalMISRobust(float pdf, float otherPdf)
{
	if (pdf == otherPdf)
	{
		return 0.5;
	}
	if (otherPdf < pdf)
	{
		float x = otherPdf / pdf;
		return 1.0 / (1.0 + x * x);
	}
	float x = pdf / otherPdf;
	return 1.0 - 1.0 / (1.0 + x * x);
}

// Area measure -> solid angle measure.
float PdfAtoW(float pdfA, float dist, float cosTheta)
{
	return pdfA * dist * dist / cosTheta;
}

// Ray Tracing Gems ch. 6, "A Fast and Robust Method for Avoiding Self-Intersection".
float3 ComputeOffsetOrigin(float3 pos, float3 normal)
{
	const float origin = 1.0 / 16.0;
	const float fScale = 3.0 / 65536.0;
	const float iScale = 3.0 * 256.0;

	int3 iOff = int3(normal * iScale);
	int3 iPos = asint(pos) + int3(pos.x < 0.0 ? -iOff.x : iOff.x, pos.y < 0.0 ? -iOff.y : iOff.y, pos.z < 0.0 ? -iOff.z : iOff.z);
	float3 pI = asfloat(iPos);
	float3 fOff = normal * fScale;
	return float3(
		abs(pos.x) < origin ? pos.x + fOff.x : pI.x,
		abs(pos.y) < origin ? pos.y + fOff.y : pI.y,
		abs(pos.z) < origin ? pos.z + fOff.z : pI.z);
}

// Equirectangular mapping, +Y up.
float2 DirectionToEquirectUV(float3 dir)
{
	float elevation = asin(clamp(dir.y, -1.0, 1.0));
	float azimuth = abs(dir.y) < 1.0 ? atan2(dir.z, dir.x) : 0.0;
	return float2(azimuth * INV_TWO_PI - 0.25, 0.5 - elevation * INV_PI);
}

float3 EquirectUVToDirection(float2 uv, out float cosElevation)
{
	float azimuth = (uv.x + 0.25) * TWO_PI;
	float elevation = (0.5 - uv.y) * PI;
	cosElevation = cos(elevation);
	return float3(cos(azimuth) * cosElevation, sin(elevation), sin(azimuth) * cosElevation);
}

float3 RotateY(float3 v, float angle)
{
	float s = sin(angle);
	float c = cos(angle);
	return float3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

float3 SrgbToLinear(float3 c)
{
	float3 lo = c / 12.92;
	float3 hi = pow((c + 0.055) / 1.055, float3(2.4));
	return select(c <= 0.04045, lo, hi);
}

float3 LinearToSrgb(float3 c)
{
	float3 lo = c * 12.92;
	float3 hi = 1.055 * pow(max(c, float3(0.0)), float3(1.0 / 2.4)) - 0.055;
	return select(c <= 0.0031308, lo, hi);
}
