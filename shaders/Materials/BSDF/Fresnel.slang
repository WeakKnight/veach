// Fresnel terms, IOR helpers and dispersion. eta is always eta_t / eta_i.
import Common.Math;
import Materials.BSDF.BSDFCommon;

float F0FromIor(float eta)
{
	return Square((eta - 1.0) / (eta + 1.0));
}

float IorFromF0(float f0)
{
	float sqrtF0 = sqrt(f0);
	return (1.0 + sqrtF0) / (1.0 - sqrtF0);
}

// Scales F0 by the specular weight; a weight of 1 is a no-op.
float ApplySpecularWeightToIor(float eta, float specularWeight)
{
	const float MAX_F0 = 0.9999;
	float f0 = min(F0FromIor(eta) * specularWeight, MAX_F0);
	float externalIor = IorFromF0(f0);
	return eta < 1.0 ? 1.0 / externalIor : externalIor;
}

// Unpolarized dielectric reflectance.
float FresnelDielectric(float eta, float cosThetaI)
{
	if (eta == 1.0)
	{
		return 0.0;
	}
	float sin2ThetaI = 1.0 - Square(cosThetaI);
	float sin2ThetaT = sin2ThetaI / Square(eta);
	if (sin2ThetaT >= 1.0)
	{
		return 1.0; // total internal reflection
	}
	float cosThetaT = sqrt(1.0 - sin2ThetaT);
	float etaCosI = eta * cosThetaI;
	float etaCosT = eta * cosThetaT;
	float rs = Square((cosThetaI - etaCosT) / (cosThetaI + etaCosT));
	float rp = Square((cosThetaT - etaCosI) / (cosThetaT + etaCosI));
	return 0.5 * (rs + rp);
}

float3 FresnelDielectric(float3 eta, float cosThetaI)
{
	if (BSDF_ENABLE_DISPERSION)
	{
		return float3(FresnelDielectric(eta.r, cosThetaI), FresnelDielectric(eta.g, cosThetaI), FresnelDielectric(eta.b, cosThetaI));
	}
	return float3(FresnelDielectric(eta.r, cosThetaI));
}

// Cosine-weighted hemispherical average (Kulla and Conty 2017, slide 18).
float AverageFresnel(float eta)
{
	if (eta > 1.0)
	{
		return (eta - 1.0) / (4.08567 + 1.00071 * eta);
	}
	return 0.997118 + 0.1014 * eta - 0.965241 * (eta * eta) - 0.130607 * (eta * eta) * eta;
}

// Front and back reflectance of a thin slab including all internal bounces; transmittance is
// (1 - R) / (1 + R).
float ThinWallFresnel(float eta, float cosThetaI)
{
	float r = FresnelDielectric(eta, cosThetaI);
	return (2.0 * r) / (1.0 + r);
}

// F82-tint metal Fresnel: Hoffman's F82 with the edge tint applied multiplicatively, so a white tint
// reduces to Schlick.
float3 MetalSchlickBFactor(float3 f0, float3 f82Tint)
{
	const float COS_THETA_MAX = 1.0 / 7.0;
	const float ONE_MINUS_COS_MAX = 1.0 - COS_THETA_MAX;
	const float ONE_MINUS_COS_MAX_5 = FifthPower(ONE_MINUS_COS_MAX);
	const float ONE_MINUS_COS_MAX_6 = SixthPower(ONE_MINUS_COS_MAX);
	float3 numerator = (f0 + (1.0 - f0) * ONE_MINUS_COS_MAX_5) * (1.0 - f82Tint);
	const float INV_DENOMINATOR = 1.0 / (COS_THETA_MAX * ONE_MINUS_COS_MAX_6);
	return numerator * INV_DENOMINATOR;
}

float3 FresnelMetalF82(float3 f0, float3 f82Tint, float cosTheta)
{
	float3 b = MetalSchlickBFactor(f0, f82Tint);
	float oneMinusCos = 1.0 - cosTheta;
	float3 offset = ((1.0 - f0) - b * cosTheta * oneMinusCos) * FifthPower(oneMinusCos);
	return saturate(f0 + offset);
}

float3 AverageFresnelMetalF82(float3 f0, float3 f82Tint)
{
	float3 b = MetalSchlickBFactor(f0, f82Tint);
	return saturate(f0 + (1.0 - f0) * (1.0 / 21.0) - b * (1.0 / 126.0));
}

// Refraction about n (wi and n in the same hemisphere); false on total internal reflection.
bool Refract(float3 wi, float3 n, float cosThetaI, float eta, out float3 wt)
{
	float invEta = 1.0 / eta;
	float sin2ThetaI = max(0.0, 1.0 - Square(cosThetaI));
	float sin2ThetaT = Square(invEta) * sin2ThetaI;
	if (sin2ThetaT >= 1.0)
	{
		wt = float3(0.0);
		return false;
	}
	float cosThetaT = sqrt(1.0 - sin2ThetaT);
	wt = normalize(-wi * invEta + n * (invEta * cosThetaI - cosThetaT));
	return true;
}

// Dispersion: the "dispersion" parameter is 20 / Abbe number V_d (0 = none, 1 = the most dispersive
// realistic glass); IORs follow Cauchy's equation with n(d) = the input IOR.
static const float DISPERSION_WAVELENGTH_LONG = 656.3;	// Fraunhofer C
static const float DISPERSION_WAVELENGTH_MEDIUM = 587.6; // Fraunhofer d
static const float DISPERSION_WAVELENGTH_SHORT = 486.1;	// Fraunhofer F

// dispersion > 0, wavelength in nm.
float DispersionAdjustedIor(float ior, float dispersion, float wavelength)
{
	bool belowOne = ior < 1.0;
	float iorAboveOne = belowOne ? 1.0 / ior : ior;
	float abbe = 20.0 / dispersion;
	float b = (iorAboveOne - 1.0) / (abbe * (Square(1.0 / DISPERSION_WAVELENGTH_SHORT) - Square(1.0 / DISPERSION_WAVELENGTH_LONG)));
	float a = iorAboveOne - b * Square(1.0 / DISPERSION_WAVELENGTH_MEDIUM);
	float adjusted = a + b * Square(1.0 / wavelength);
	return belowOne ? 1.0 / adjusted : adjusted;
}
