// Fresnel-like coefficients plugged into the microfacet lobes. idoth is the (non-negative) cosine
// between the view and the microfacet normal.
import Common.Math;
import Materials.BSDF.BSDFCommon;
import Materials.BSDF.EnergyTables;
import Materials.BSDF.Fresnel;
import Materials.BSDF.ThinFilm;

interface IReflectionCoefficient
{
	float3 Reflection(float idoth);
	// Lobe selection weight of the coefficient applied to a GGX distribution.
	float EstimateWeightOnGGX(float3 throughput, float idotn, float isotropicAlpha);
}

// A constant color, e.g. the window transmittance of the thin-wall specular transmission.
struct ConstantReflection : IReflectionCoefficient
{
	float3 color;

	__init(float3 color)
	{
		this.color = color;
	}

	float3 Reflection(float idoth)
	{
		return color;
	}

	// No GGX albedo for a constant color; assumes a smooth surface.
	float EstimateWeightOnGGX(float3 throughput, float idotn, float isotropicAlpha)
	{
		return ThroughputWeightedMax(throughput, color);
	}
};

// Dielectric reflection only, e.g. the coat.
struct DielectricReflection : IReflectionCoefficient
{
	float eta;

	__init(float eta)
	{
		this.eta = eta;
	}

	float3 Reflection(float idoth)
	{
		return float3(FresnelDielectric(eta, idoth));
	}

	float EstimateWeightOnGGX(float3 throughput, float idotn, float isotropicAlpha)
	{
		float averageReflectivity = 1.0 - OpaqueDielectricEnergyComplement(eta, isotropicAlpha, idotn);
		return ThroughputWeightedMax(throughput, float3(averageReflectivity));
	}
};

struct ReflectionTransmission
{
	float3 reflection;
	float3 transmission;
	float reflectionProbability;
	float transmissionProbability;
};

// Everything the base specular lobe reflects and transmits: the transparent and opaque dielectric
// parts, the metal, thin-film iridescence over them and the thin-wall window reflection.
struct BaseReflectionTransmission
{
	float3 etaTransparent; // ignoring the thin film
	float3 etaOpaque;	   // ignoring the thin film
	float3 reflectionScaleTransparent;
	float3 reflectionScaleOpaque;
	float3 transmission;
	float3 metalF0;
	float3 metalF82Tint;
	float metalAmount;
	float thinFilmWeight;
	float thinFilmThickness; // nm
	float thinFilmExteriorIor; // absolute, no dispersion (the "exterior" can be the object interior)
	float thinFilmIor;		   // absolute, no dispersion
	float3 thinFilmInteriorIor; // absolute, with dispersion
	float3 wavelengths;			// nm
	float3 thinWallReflection;	// view-independent window reflection albedo

	// Only on the front of a microfacet (the normal is face-forwarded, the microfacet normal is not).
	float ThinFilmPresenceAt(float idoth)
	{
		return idoth >= 0.0 ? thinFilmWeight * ThinFilmPresence(thinFilmThickness) : 0.0;
	}

	bool HasDielectric()
	{
		return (BSDF_ENABLE_TRANSLUCENCY && any(reflectionScaleTransparent > float3(0.0))) || any(reflectionScaleOpaque > float3(0.0));
	}

	bool HasMetal()
	{
		return BSDF_ENABLE_METALLIC && metalAmount > 0.0;
	}

	ThinFilmResults ThinFilm(float idoth, bool enableDielectric, bool enableMetal)
	{
		return ThinFilmAndBaseReflectance(
			idoth, thinFilmExteriorIor, thinFilmIor, thinFilmInteriorIor, BSDF_ENABLE_DISPERSION, metalF0, metalF82Tint, enableDielectric, enableMetal,
			thinFilmThickness, wavelengths);
	}

	float3 Reflection(float idoth)
	{
		float3 standard = float3(0.0);
		float3 thinFilm = float3(0.0);
		float presence = ThinFilmPresenceAt(idoth);
		if (presence < 1.0)
		{
			if (BSDF_ENABLE_TRANSLUCENCY)
			{
				standard += reflectionScaleTransparent * FresnelDielectric(etaTransparent, idoth);
			}
			standard += reflectionScaleOpaque * FresnelDielectric(etaOpaque, idoth);
			if (BSDF_ENABLE_METALLIC)
			{
				standard += metalAmount * FresnelMetalF82(metalF0, metalF82Tint, idoth);
			}
		}
		if (presence > 0.0)
		{
			ThinFilmResults film = ThinFilm(idoth, HasDielectric(), HasMetal());
			if (BSDF_ENABLE_TRANSLUCENCY)
			{
				thinFilm += reflectionScaleTransparent * film.dielectric;
			}
			thinFilm += reflectionScaleOpaque * film.dielectric;
			if (BSDF_ENABLE_METALLIC)
			{
				thinFilm += metalAmount * film.metal;
			}
		}
		return lerp(standard, thinFilm, presence) + thinWallReflection;
	}

	float3 Transmission(float idoth)
	{
		float3 standard = float3(0.0);
		float3 thinFilm = float3(0.0);
		float presence = ThinFilmPresenceAt(idoth);
		if (presence < 1.0 && BSDF_ENABLE_TRANSLUCENCY)
		{
			standard += transmission * (float3(1.0) - FresnelDielectric(etaTransparent, idoth));
		}
		if (presence > 0.0)
		{
			ThinFilmResults film = ThinFilm(idoth, BSDF_ENABLE_TRANSLUCENCY && any(reflectionScaleTransparent > float3(0.0)), false);
			if (BSDF_ENABLE_TRANSLUCENCY)
			{
				thinFilm += transmission * (float3(1.0) - film.dielectric);
			}
		}
		return lerp(standard, thinFilm, presence);
	}

	// Reflection and transmission together; probabilities are left at zero.
	ReflectionTransmission Coefficients(float idoth)
	{
		float3 standardReflection = float3(0.0);
		float3 standardTransmission = float3(0.0);
		float3 thinFilmReflection = float3(0.0);
		float3 thinFilmTransmission = float3(0.0);
		float presence = ThinFilmPresenceAt(idoth);
		if (presence < 1.0)
		{
			if (BSDF_ENABLE_TRANSLUCENCY)
			{
				float3 fresnel = FresnelDielectric(etaTransparent, idoth);
				standardReflection += reflectionScaleTransparent * fresnel;
				standardTransmission += transmission * (float3(1.0) - fresnel);
			}
			standardReflection += reflectionScaleOpaque * FresnelDielectric(etaOpaque, idoth);
			if (BSDF_ENABLE_METALLIC)
			{
				standardReflection += metalAmount * FresnelMetalF82(metalF0, metalF82Tint, idoth);
			}
		}
		if (presence > 0.0)
		{
			ThinFilmResults film = ThinFilm(idoth, HasDielectric(), HasMetal());
			if (BSDF_ENABLE_TRANSLUCENCY)
			{
				thinFilmReflection += reflectionScaleTransparent * film.dielectric;
				thinFilmTransmission += transmission * (float3(1.0) - film.dielectric);
			}
			thinFilmReflection += reflectionScaleOpaque * film.dielectric;
			if (BSDF_ENABLE_METALLIC)
			{
				thinFilmReflection += metalAmount * film.metal;
			}
		}
		ReflectionTransmission result;
		result.reflection = lerp(standardReflection, thinFilmReflection, presence) + thinWallReflection;
		result.transmission = lerp(standardTransmission, thinFilmTransmission, presence);
		result.reflectionProbability = 0.0;
		result.transmissionProbability = 0.0;
		return result;
	}

	// Probabilities proportional to the throughput-weighted coefficients (0 if both are black).
	ReflectionTransmission CoefficientsAndProbabilities(float3 throughput, float idoth)
	{
		ReflectionTransmission result = Coefficients(idoth);
		float reflectionMax = ThroughputWeightedMax(throughput, result.reflection);
		float transmissionMax = ThroughputWeightedMax(throughput, result.transmission);
		float sum = reflectionMax + transmissionMax;
		result.reflectionProbability = BSDF_ENABLE_TRANSLUCENCY ? SafeDivide(reflectionMax, sum, 0.0) : 1.0;
		result.transmissionProbability = BSDF_ENABLE_TRANSLUCENCY ? SafeDivide(transmissionMax, sum, 0.0) : 0.0;
		return result;
	}

	float ReflectionProbability(float3 throughput, float idoth)
	{
		return CoefficientsAndProbabilities(throughput, idoth).reflectionProbability;
	}

	float TransmissionProbability(float3 throughput, float idoth)
	{
		return CoefficientsAndProbabilities(throughput, idoth).transmissionProbability;
	}

	// No GGX albedo for this coefficient; assumes a smooth surface.
	float EstimateWeight(float3 throughput, float idotn)
	{
		ReflectionTransmission c = Coefficients(idotn);
		return ThroughputWeightedMax(throughput, c.reflection + c.transmission);
	}
};
