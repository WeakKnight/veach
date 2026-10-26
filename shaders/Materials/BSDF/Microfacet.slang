// Anisotropic GGX with Smith masking and visible-normal sampling. Local vectors are z-up.
import Common.Math;
import Materials.BSDF.BSDFCommon;

// Delta lobes are not supported, so alphas are clamped above this.
static const float MIN_MICROFACET_ALPHA = 0.001 * 0.001;

// OpenPBR anisotropy mapping: alpha_t = alpha sqrt(2 / (1 + (1 - a)^2)), alpha_b = (1 - a) alpha_t.
float2 AnisotropicAlpha(float isotropicAlpha, float anisotropy)
{
	float2 alpha;
	if (anisotropy > 0.0)
	{
		alpha.x = isotropicAlpha * sqrt(2.0 / (1.0 + Square(1.0 - anisotropy)));
		alpha.y = (1.0 - anisotropy) * alpha.x;
	}
	else
	{
		alpha = float2(isotropicAlpha);
	}
	return max(alpha, float2(MIN_MICROFACET_ALPHA));
}

float EvalGGX(float3 m, float2 alpha)
{
	return 1.0 / (PI * alpha.x * alpha.y * Square(Square(m.x / alpha.x) + Square(m.y / alpha.y) + Square(m.z)));
}

// Dupuy and Benyoub 2023, "Sampling Visible GGX Normals with Spherical Caps". u.y < 1.
float3 SampleGGXVisibleNormal(float2 alpha, float3 wo, float2 u)
{
	float3 toHemisphere = float3(alpha.x, alpha.y, 1.0);
	float3 woHemisphere = normalize(toHemisphere * wo);
	float cosWo = min(woHemisphere.z, 1.0);

	// cap in (-cosWo, 1]; (1 - z^2) as (1 + z)(1 - z) is stable near the poles
	float angle = TWO_PI * u.x;
	float onePlusCos = 1.0 + cosWo;
	float z = (1.0 - u.y) * onePlusCos;
	float oneMinusZ = u.y * onePlusCos;
	float oneMinusCos = 1.0 - cosWo;
	float onePlusZ = z + oneMinusCos;
	float radius = sqrt(onePlusZ * oneMinusZ);

	float3 m = float3(radius * cos(angle) + woHemisphere.x, radius * sin(angle) + woHemisphere.y, z);
	return normalize(toHemisphere * m);
}

// Height-uncorrelated Smith G1; v.z < 0 is allowed for transmission.
float SmithG1(float3 v, float2 alpha)
{
	float vz2 = Square(v.z);
	if (vz2 == 0.0)
	{
		return 0.0;
	}
	return 2.0 / (1.0 + sqrt(1.0 + (Square(alpha.x * v.x) + Square(alpha.y * v.y)) / vz2));
}

struct GGXDistribution
{
	float2 alpha;
	Frame frame;		  // face-forwarded, anisotropy-rotated
	float isotropicAlpha; // roughness^2 before anisotropy, for energy tables and lobe weights

	__init(float2 alpha, Frame frame, float isotropicAlpha)
	{
		this.alpha = alpha;
		this.frame = frame;
		this.isotropicAlpha = isotropicAlpha;
	}

	float D(float3 m)
	{
		return EvalGGX(frame.ToLocal(m), alpha);
	}

	float G1(float3 v)
	{
		return SmithG1(frame.ToLocal(v), alpha);
	}

	float G2(float3 wo, float3 wi)
	{
		return SmithG1(frame.ToLocal(wo), alpha) * SmithG1(frame.ToLocal(wi), alpha);
	}

	float3 SampleVisibleNormal(float3 wo, float2 u)
	{
		return frame.ToWorld(SampleGGXVisibleNormal(alpha, frame.ToLocal(wo), u));
	}
};
