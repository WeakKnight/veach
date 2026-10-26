// The material BSDF (OpenPBR Surface 1.1, after Adobe's reference implementation): a fuzz layer
// over a dielectric coat over a base of metal, opaque / translucent dielectric with thin film,
// subsurface and diffuse, plus the interior volume and the emission.
//
// Conventions: wo (view) and wi (light) point away from the surface. Eval returns f * |cos(wi)|.
// Sample returns the weight f * |cos| / pdf and the pdf of the whole stack; pdf = 0 means no
// sample. Front / back is decided by the side of wo relative to basis.n, so the shading frame must
// not be flipped toward the viewer; double-sided surfaces without an interior should be thin-walled.
import Common.Math;
import Materials.BSDF.Fresnel;
import Materials.BSDF.Layers;
import Materials.BSDF.Lobes;
import Materials.BSDF.Microfacet;
import Materials.BSDF.ReflectionCoefficients;

__exported import Materials.BSDF.BSDFCommon;
__exported import Materials.BSDF.Volume;

// Texture-resolved inputs, named and defaulted like the OpenPBR parameters.
struct BSDFInputs
{
	float baseWeight;
	float3 baseColor;
	float baseDiffuseRoughness;
	float baseMetalness;

	float subsurfaceWeight;
	float3 subsurfaceColor;
	float subsurfaceRadius;
	float3 subsurfaceRadiusScale;
	float subsurfaceScatterAnisotropy;

	float specularWeight;
	bool specularDielectricOnly; // glTF import semantic; false retains OpenPBR behavior.
	float3 specularColor;
	float specularRoughness;
	float specularRoughnessAnisotropy;
	float specularIor;
	float2 specularAnisotropyRotation; // (cos, sin), need not be unit length; (1, 0) for none

	float coatWeight;
	float3 coatColor;
	float coatRoughness;
	float coatRoughnessAnisotropy;
	float coatIor;
	float coatDarkening;
	float2 coatAnisotropyRotation; // (cos, sin)

	float fuzzWeight;
	float3 fuzzColor;
	float fuzzRoughness;

	float transmissionWeight;
	float3 transmissionColor;
	float transmissionDepth;
	float3 transmissionScatter;
	float transmissionScatterAnisotropy;
	float transmissionDispersionScale;
	float transmissionDispersionAbbeNumber;

	float thinFilmWeight;
	float thinFilmThickness; // micrometers
	float thinFilmIor;

	float emissionLuminance; // nits
	float3 emissionColor;

	float geometryOpacity;
	bool geometryThinWalled;

	Frame basis;	 // shading frame, not face-forwarded
	Frame coatBasis; // shading frame of the coat

	static BSDFInputs Default()
	{
		BSDFInputs i;
		i.baseWeight = 1.0;
		i.baseColor = float3(0.8);
		i.baseDiffuseRoughness = 0.0;
		i.baseMetalness = 0.0;

		i.subsurfaceWeight = 0.0;
		i.subsurfaceColor = float3(0.8);
		i.subsurfaceRadius = 1.0;
		i.subsurfaceRadiusScale = float3(1.0, 0.5, 0.25);
		i.subsurfaceScatterAnisotropy = 0.0;

		i.specularWeight = 1.0;
		i.specularDielectricOnly = false;
		i.specularColor = float3(1.0);
		i.specularRoughness = 0.3;
		i.specularRoughnessAnisotropy = 0.0;
		i.specularIor = 1.5;
		i.specularAnisotropyRotation = float2(1.0, 0.0);

		i.coatWeight = 0.0;
		i.coatColor = float3(1.0);
		i.coatRoughness = 0.0;
		i.coatRoughnessAnisotropy = 0.0;
		i.coatIor = 1.6;
		i.coatDarkening = 1.0;
		i.coatAnisotropyRotation = float2(1.0, 0.0);

		i.fuzzWeight = 0.0;
		i.fuzzColor = float3(1.0);
		i.fuzzRoughness = 0.5;

		i.transmissionWeight = 0.0;
		i.transmissionColor = float3(1.0);
		i.transmissionDepth = 0.0;
		i.transmissionScatter = float3(0.0);
		i.transmissionScatterAnisotropy = 0.0;
		i.transmissionDispersionScale = 0.0;
		i.transmissionDispersionAbbeNumber = 20.0;

		i.thinFilmWeight = 0.0;
		i.thinFilmThickness = 0.5;
		i.thinFilmIor = 1.4;

		i.emissionLuminance = 0.0;
		i.emissionColor = float3(1.0);

		i.geometryOpacity = 1.0;
		i.geometryThinWalled = false;

		i.basis.t = float3(1.0, 0.0, 0.0);
		i.basis.b = float3(0.0, 1.0, 0.0);
		i.basis.n = float3(0.0, 0.0, 1.0);
		i.coatBasis = i.basis;
		return i;
	}

	bool HasDispersion()
	{
		return BSDF_ENABLE_DISPERSION && transmissionDispersionScale > 0.0 && transmissionDispersionAbbeNumber > 0.0 && baseMetalness < 1.0;
	}

	// Dispersion and thin film need distinct per-channel wavelengths for the path.
	bool NeedsRGBWavelengths()
	{
		return HasDispersion() || (thinFilmWeight > 0.0 && thinFilmThickness * 1000.0 > 0.0);
	}
};

// Wavelengths (nm) of the RGB channels when a path does not need distinct ones.
static const float3 BSDF_RGB_WAVELENGTHS = float3(620.0, 540.0, 450.0);

typealias LayeredLobe = FuzzLobe<CoatLobe<BaseLobe>>;

// Volume-derived state the lobes depend on.
struct VolumeDerived
{
	float3 thinWallSubsurfaceColor;
	float thinWallSubsurfaceAnisotropy;
	float3 transmissionTint; // zero-depth absorption (made view-dependent for thin walls)
};

// Thin walls: transmissionColor is the absorption at normal incidence; refracted paths are longer.
float3 FinalTransmissionTint(float3 tint, bool thinWall, float cosI, float etaForRefraction)
{
	if (!thinWall)
	{
		return tint;
	}
	float sin2I = 1.0 - Square(cosI);
	float sin2T = sin2I / Square(etaForRefraction);
	if (sin2T >= 1.0)
	{
		return float3(0.0);
	}
	float cosT = sqrt(1.0 - sin2T);
	return pow(tint, float3(1.0 / cosT));
}

struct BSDF
{
	HomogeneousVolume volume; // interior medium, for segments inside after a transmission
	float3 emission;		  // nits, attenuated by coat and fuzz; zero from the inside
	LayeredLobe lobes;
	float3 wo;

	// exteriorIor: absolute IOR of the medium wo travels in (1 for air).
	__init(BSDFInputs inputs, float3 wo, float3 throughput, float3 wavelengths, float exteriorIor)
	{
		this.wo = wo;
		VolumeDerived derived;
		volume = PrepareVolume(inputs, derived);
		lobes = PrepareLobes(inputs, derived, wo, throughput, wavelengths, exteriorIor);
		emission = ComputeEmission(inputs, wo, lobes);
	}

	// f * |cos| and the pdf over all lobes in one pass; use it rather than Eval and Pdf when both
	// are needed (each call site instantiates the whole stack).
	void EvalPdf(float3 wi, out DiffuseSpecular f, out float pdf)
	{
		if (BSDF_ENABLE_SHEEN_AND_COAT)
		{
			lobes.EvalPdf(wo, wi, SampledLobe.None(), f, pdf);
		}
		else
		{
			lobes.base.base.EvalPdf(wo, wi, SampledLobe.None(), f, pdf);
		}
	}

	DiffuseSpecular Eval(float3 wi)
	{
		DiffuseSpecular f;
		float pdf;
		EvalPdf(wi, f, pdf);
		return f;
	}

	float Pdf(float3 wi)
	{
		DiffuseSpecular f;
		float pdf;
		EvalPdf(wi, f, pdf);
		return pdf;
	}

	LobeSample Sample(float3 u)
	{
		return BSDF_ENABLE_SHEEN_AND_COAT ? lobes.Sample(u, wo) : lobes.base.base.Sample(u, wo);
	}

	uint LobeType()
	{
		return lobes.LobeType();
	}

	// Largest GGX alpha among the active lobes; 1 if a diffuse, uniform or sheen lobe is active.
	float MaxActiveAlpha()
	{
		float baseAlpha = lobes.base.base.MaxActiveAlpha();
		if (!BSDF_ENABLE_SHEEN_AND_COAT)
		{
			return baseAlpha;
		}
		return lobes.HasFuzz() ? 1.0 : max(baseAlpha, lobes.base.MaxActiveAlpha());
	}
};

HomogeneousVolume PrepareVolume(BSDFInputs inputs, out VolumeDerived derived)
{
	HomogeneousVolume subsurfaceVolume = HomogeneousVolume.Empty();
	derived.thinWallSubsurfaceColor = float3(0.0);
	derived.thinWallSubsurfaceAnisotropy = 0.0;
	if (inputs.subsurfaceWeight > 0.0)
	{
		if (!inputs.geometryThinWalled)
		{
			subsurfaceVolume = CreateSubsurfaceVolume(inputs.subsurfaceRadius, inputs.subsurfaceRadiusScale, inputs.subsurfaceColor, inputs.subsurfaceScatterAnisotropy);
		}
		else
		{
			// thin walls turn subsurface into diffuse reflection and transmission
			derived.thinWallSubsurfaceColor = inputs.subsurfaceColor;
			derived.thinWallSubsurfaceAnisotropy = inputs.subsurfaceScatterAnisotropy;
		}
	}

	// Either an interior volume or a transmission tint, never both (that would tint twice).
	derived.transmissionTint = float3(1.0);
	HomogeneousVolume transmissionVolume = HomogeneousVolume.Empty();
	if (inputs.transmissionWeight > 0.0)
	{
		if (inputs.transmissionDepth == 0.0 || inputs.geometryThinWalled)
		{
			derived.transmissionTint = inputs.transmissionColor;
		}
		else
		{
			transmissionVolume = CreateTransmissionVolume(
				inputs.transmissionColor, inputs.transmissionDepth, inputs.transmissionScatter, inputs.transmissionScatterAnisotropy);
		}
	}

	// Blend by the relative contributions (they sum to one): physically plausible medium thickness.
	float subsurfaceFraction = (1.0 - inputs.transmissionWeight) * inputs.subsurfaceWeight;
	float transmissionFraction = inputs.transmissionWeight;
	float invTotal = SafeDivide(1.0, subsurfaceFraction + transmissionFraction, 0.0);
	return AddVolumes(subsurfaceVolume, transmissionVolume, subsurfaceFraction * invTotal, transmissionFraction * invTotal);
}

LayeredLobe PrepareLobes(BSDFInputs inputs, VolumeDerived derived, float3 wo, float3 throughput, float3 wavelengths, float exteriorIor)
{
	// Front / back from the shading normal (not the IORs); thin walls are always hit from outside.
	float cosTheta = dot(wo, inputs.basis.n);
	bool backFacing = cosTheta < 0.0;
	bool inside = backFacing && !inputs.geometryThinWalled;

	Frame specularBasis = inputs.basis.RotatedAroundNormal(inputs.specularAnisotropyRotation);
	if (backFacing)
	{
		specularBasis = specularBasis.Inverted();
	}
	float3 normal = specularBasis.n;

	Frame coatBasis = inputs.coatBasis.RotatedAroundNormal(inputs.coatAnisotropyRotation);
	if (dot(wo, inputs.coatBasis.n) < 0.0)
	{
		coatBasis = coatBasis.Inverted();
	}
	float3 coatNormal = coatBasis.n;

	// IORs are absolute unless marked relative. The base sits under the coat only when entering a
	// coated surface; a partial coat lerps the coat IOR. specularWeight = 0 index-matches the base to
	// the medium around it (the coat, or the exterior medium, which need not be 1).
	bool enterCoat = inputs.coatWeight > 0.0 && !inside;
	float weightedCoatIor = enterCoat ? lerp(exteriorIor, inputs.coatIor, inputs.coatWeight) : exteriorIor;
	float weightedSpecularIor = weightedCoatIor * ApplySpecularWeightToIor(inputs.specularIor / weightedCoatIor, inputs.specularWeight);

	float etaRefraction;
	float etaTransReflection;
	float etaOpaqueReflection;
	float etaCoat = 1.0;
	if (inside)
	{
		etaRefraction = exteriorIor / weightedSpecularIor;
		etaTransReflection = etaRefraction;
		etaOpaqueReflection = weightedSpecularIor / exteriorIor; // the opaque part reflects as if from outside
	}
	else
	{
		etaRefraction = weightedSpecularIor / exteriorIor;
		if (enterCoat)
		{
			// The coat does not bend rays here, so a base IOR below the coat IOR would produce
			// unphysical total internal reflection; keep it external.
			if (weightedCoatIor > weightedSpecularIor && weightedSpecularIor >= exteriorIor)
			{
				etaTransReflection = weightedCoatIor / weightedSpecularIor;
			}
			else
			{
				etaTransReflection = weightedSpecularIor / weightedCoatIor;
			}
			// unweighted: the coat lobe applies the weight
			etaCoat = inputs.coatIor / exteriorIor;
		}
		else
		{
			etaTransReflection = etaRefraction;
		}
		etaOpaqueReflection = etaTransReflection;
	}

	const float MIN_REFRACTION_IOR_ABOVE_ONE = 1.0001;
	etaRefraction = etaRefraction >= 1.0 ? max(etaRefraction, MIN_REFRACTION_IOR_ABOVE_ONE) : min(etaRefraction, 1.0 / MIN_REFRACTION_IOR_ABOVE_ONE);

	// Fuzz slightly roughens the coat (empirical).
	const float FUZZ_EFFECT_ON_UNDERLYING_ROUGHNESS = 0.005;
	float fuzzAdjustment = Average(inputs.fuzzColor) * inputs.fuzzRoughness * FUZZ_EFFECT_ON_UNDERLYING_ROUGHNESS;
	float coatRoughness = lerp(inputs.coatRoughness,
		FourthRoot(min(1.0, FourthPower(inputs.coatRoughness) + fuzzAdjustment * FourthPower(inputs.fuzzRoughness))), inputs.fuzzWeight);

	// The coat roughens the base less than the spec suggests: low-IOR coats barely bend light.
	float coatAdjustment = lerp(1.0, 0.0, etaCoat >= 1.0 ? 1.0 / etaCoat : etaCoat);
	float specularRoughness = lerp(inputs.specularRoughness,
		FourthRoot(min(1.0, FourthPower(inputs.specularRoughness) + coatAdjustment * FourthPower(coatRoughness))), inputs.coatWeight);

	float specularAlpha = Square(specularRoughness);
	float2 anisotropicSpecularAlpha = AnisotropicAlpha(specularAlpha, inputs.specularRoughnessAnisotropy);
	float coatAlpha = Square(coatRoughness);
	float2 anisotropicCoatAlpha = AnisotropicAlpha(coatAlpha, inputs.coatRoughnessAnisotropy);

	// Barycentric base weights: metal supersedes dielectric, transmission supersedes subsurface.
	float nonTrans = 1.0 - inputs.transmissionWeight;
	float nonSss = 1.0 - inputs.subsurfaceWeight;
	float dielectric = 1.0 - inputs.baseMetalness;
	float opaqueDielectric = nonTrans * nonSss * dielectric;
	float trans = dielectric * inputs.transmissionWeight;
	float sss = nonTrans * dielectric * inputs.subsurfaceWeight;

	float darkenedMetal = inputs.baseMetalness * (inputs.specularDielectricOnly ? 1.0 : inputs.specularWeight);
	float3 metalF82Tint = inputs.specularDielectricOnly ? float3(1.0) : inputs.specularColor;
	float3 weightedBaseColor = inputs.baseColor * inputs.baseWeight;
	float3 metalAverageFresnel = float3(1.0);
	if (BSDF_ENABLE_METALLIC)
	{
		metalAverageFresnel = AverageFresnelMetalF82(weightedBaseColor, metalF82Tint);
	}

	// Coat darkening from internal reflections (OpenPBR 1.1.1): K_s / K_r are the internal diffuse
	// reflection coefficients for smooth / rough bases, blended by the effective base roughness.
	float kSmooth = AverageFresnel(etaCoat);
	float kRough = 1.0 - (1.0 - AverageFresnel(etaCoat)) / Square(etaCoat);
	float specularityOpaqueDielectric = AverageFresnel(etaOpaqueReflection);
	float specularitySssTrans = AverageFresnel(etaTransReflection);
	float specularityDielectric = opaqueDielectric * specularityOpaqueDielectric + (sss + trans) * specularitySssTrans;
	float specularityBase = specularityDielectric + inputs.baseMetalness;
	float effectiveBaseRoughness = lerp(1.0, specularRoughness, specularityBase);
	float k = lerp(kSmooth, kRough, effectiveBaseRoughness);

	float3 albedoMetal = darkenedMetal * metalAverageFresnel;
	float3 albedoOpaqueDielectric = opaqueDielectric * lerp(weightedBaseColor, float3(1.0), specularityOpaqueDielectric);
	float3 albedoSss = sss * inputs.subsurfaceColor;
	float3 albedoTrans = float3(trans);
	float3 baseAlbedo = albedoMetal + albedoOpaqueDielectric + albedoSss + albedoTrans;
	// The coat color is applied view-dependently by the coat lobe, not here.
	float3 delta = float3(1.0 - k) / (float3(1.0) - baseAlbedo * k);
	float3 coatDarkening = lerp(float3(1.0), delta, inputs.coatWeight * inputs.coatDarkening);

	GGXDistribution distribution = GGXDistribution(anisotropicSpecularAlpha, specularBasis, specularAlpha);

	float transIncludingSss = trans + sss;
	float3 scaleTransReflection;
	float3 thinWallAwareScaleTransReflection;
	float3 thinWallSpecularTransmissionAlbedoScale;
	float3 scaleOpaqueReflection = inputs.specularColor * opaqueDielectric;
	if (inside)
	{
		// the specular color does not tint internal reflection
		scaleTransReflection = float3(transIncludingSss);
		thinWallAwareScaleTransReflection = scaleTransReflection;
		thinWallSpecularTransmissionAlbedoScale = float3(0.0);
	}
	else
	{
		scaleTransReflection = inputs.specularColor * transIncludingSss;
		if (inputs.geometryThinWalled)
		{
			// the window formula below covers the transmission part's reflection
			thinWallAwareScaleTransReflection = inputs.specularColor * sss;
			thinWallSpecularTransmissionAlbedoScale = inputs.specularColor * trans;
		}
		else
		{
			thinWallAwareScaleTransReflection = scaleTransReflection;
			thinWallSpecularTransmissionAlbedoScale = float3(0.0);
		}
	}

	float dispersion = 0.0;
	float3 etaRefractionRGB = float3(etaRefraction);
	float3 etaTransReflectionRGB = float3(etaTransReflection);
	float3 etaOpaqueReflectionRGB = float3(etaOpaqueReflection);
	if (inputs.HasDispersion())
	{
		dispersion = SafeDivide(20.0, SafeDivide(inputs.transmissionDispersionAbbeNumber, inputs.transmissionDispersionScale, 0.0), 0.0);
		[ForceUnroll]
		for (int c = 0; c < 3; ++c)
		{
			float wavelength = wavelengths[c];
			etaRefractionRGB[c] = DispersionAdjustedIor(etaRefraction, dispersion, wavelength);
			etaTransReflectionRGB[c] =
				etaTransReflection == etaRefraction ? etaRefractionRGB[c] : DispersionAdjustedIor(etaTransReflection, dispersion, wavelength);
			etaOpaqueReflectionRGB[c] =
				etaOpaqueReflection == etaTransReflection ? etaTransReflectionRGB[c] : DispersionAdjustedIor(etaOpaqueReflection, dispersion, wavelength);
		}
	}

	float nonThinWallWeight = inputs.geometryThinWalled ? 0.0 : 1.0;
	// A thin wall has no interior: either side is the front.
	float thinWallAwareCosTheta = inputs.geometryThinWalled ? abs(cosTheta) : cosTheta;
	float3 finalTransmissionTint = FinalTransmissionTint(derived.transmissionTint, inputs.geometryThinWalled, thinWallAwareCosTheta, etaRefraction);
	float3 tintedTrans = trans * finalTransmissionTint;
	float3 tintedTransIncludingSss = tintedTrans + float3(sss);
	float3 thinWallAwareTintedTransIncludingSss = nonThinWallWeight * tintedTransIncludingSss;

	// Thin film on either side; combined with coat or dispersion it is approximate.
	float thinFilmExteriorIor;
	float3 thinFilmInteriorIor;
	if (inside)
	{
		thinFilmExteriorIor = weightedSpecularIor;
		thinFilmInteriorIor = float3(weightedCoatIor);
	}
	else
	{
		thinFilmExteriorIor = weightedCoatIor;
		thinFilmInteriorIor = float3(weightedSpecularIor);
		if (dispersion > 0.0)
		{
			[ForceUnroll]
			for (int c = 0; c < 3; ++c)
			{
				thinFilmInteriorIor[c] = DispersionAdjustedIor(thinFilmInteriorIor[c], dispersion, wavelengths[c]);
			}
		}
	}

	// Thin-wall specular: window reflectance / transmittance over all internal bounces (exact when smooth).
	float3 thinWallSpecularReflectionAlbedo = float3(0.0);
	float3 thinWallSpecularTransmissionAlbedo = float3(0.0);
	if (inputs.geometryThinWalled)
	{
		float windowReflectance = ThinWallFresnel(etaTransReflection, thinWallAwareCosTheta);
		float windowTransmittance = 1.0 - ThinWallFresnel(etaRefraction, thinWallAwareCosTheta);
		thinWallSpecularReflectionAlbedo = thinWallSpecularTransmissionAlbedoScale * windowReflectance;
		thinWallSpecularTransmissionAlbedo = tintedTrans * windowTransmittance;
	}

	// Thin-wall subsurface: diffuse reflection and transmission split by the anisotropy.
	float3 thinWallSubsurfaceTransmissionAlbedo = float3(0.0);
	float3 thinWallSubsurfaceReflectionAlbedo = float3(0.0);
	if (inputs.geometryThinWalled)
	{
		float transmissionProportion = (derived.thinWallSubsurfaceAnisotropy + 1.0) * 0.5;
		float reflectionProportion = 1.0 - transmissionProportion;
		float3 subsurfaceAlbedo = sss * derived.thinWallSubsurfaceColor;
		thinWallSubsurfaceTransmissionAlbedo = subsurfaceAlbedo * transmissionProportion;
		thinWallSubsurfaceReflectionAlbedo = subsurfaceAlbedo * reflectionProportion;
	}

	BaseReflectionTransmission coefficient;
	coefficient.etaTransparent = etaTransReflectionRGB;
	coefficient.etaOpaque = etaOpaqueReflectionRGB;
	coefficient.reflectionScaleTransparent = thinWallAwareScaleTransReflection;
	coefficient.reflectionScaleOpaque = scaleOpaqueReflection;
	coefficient.transmission = thinWallAwareTintedTransIncludingSss;
	coefficient.metalF0 = weightedBaseColor;
	coefficient.metalF82Tint = metalF82Tint;
	coefficient.metalAmount = darkenedMetal;
	coefficient.thinFilmWeight = inputs.thinFilmWeight;
	coefficient.thinFilmThickness = inputs.thinFilmThickness * 1000.0;
	coefficient.thinFilmExteriorIor = thinFilmExteriorIor;
	coefficient.thinFilmIor = inputs.thinFilmIor;
	coefficient.thinFilmInteriorIor = thinFilmInteriorIor;
	coefficient.wavelengths = wavelengths;
	coefficient.thinWallReflection = thinWallSpecularReflectionAlbedo;

	// The multiple-scattering and diffuse lobes use the isotropic alpha: they conserve energy by
	// alpha but do not support anisotropy.
	BaseLobe base;
	base.specular = SpecularLobe(normal, distribution, coefficient, etaRefractionRGB, throughput);
	base.dielectricMultipleScattering = DielectricMultipleScatteringLobe(normal, wo, specularAlpha, etaRefraction, scaleTransReflection, tintedTransIncludingSss);
	// The color is squared for at least one more absorption at the second microfacet bounce.
	base.metalMultipleScattering = MetalMultipleScatteringLobe(normal, wo, specularAlpha, Square(metalAverageFresnel) * darkenedMetal);
	base.diffuse = DiffuseLobe(normal, wo, weightedBaseColor * opaqueDielectric + thinWallSubsurfaceReflectionAlbedo, inputs.baseDiffuseRoughness, specularAlpha,
		etaOpaqueReflection);
	base.thinWallSpecularTransmission = MakeThinWallSpecularTransmissionLobe(normal, distribution, thinWallSpecularTransmissionAlbedo);
	base.thinWallDiffuseTransmission = MakeThinWallDiffuseTransmissionLobe(
		normal, wo, thinWallSubsurfaceTransmissionAlbedo, inputs.baseDiffuseRoughness, specularAlpha, etaOpaqueReflection);
	base.InitWeights(wo, throughput);

	// The coat sits on the outside: from the inside it only tints.
	GGXDistribution coatDistribution = GGXDistribution(anisotropicCoatAlpha, coatBasis, coatAlpha);
	MicrofacetReflectionLobe<DielectricReflection> coatReflection = MicrofacetReflectionLobe<DielectricReflection>(coatNormal, coatDistribution, DielectricReflection(etaCoat));
	CoatLobe<BaseLobe> coat = CoatLobe<BaseLobe>(base, coatReflection, coatNormal, wo, inputs.coatColor, inputs.coatWeight, coatDarkening, inside);

	// The fuzz normal blends toward the coat normal by the coat presence; no fuzz from the inside.
	float3 fuzzNormal = normalize(lerp(normal, coatNormal, inputs.coatWeight));
	return LayeredLobe(coat, fuzzNormal, wo, inputs.fuzzRoughness, inputs.fuzzColor, inside ? 0.0 : inputs.fuzzWeight);
}

float3 ComputeEmission(BSDFInputs inputs, float3 wo, LayeredLobe lobes)
{
	if (inputs.emissionLuminance == 0.0 || all(inputs.emissionColor == float3(0.0)))
	{
		return float3(0.0);
	}
	bool inside = dot(wo, inputs.basis.n) < 0.0 && !inputs.geometryThinWalled;
	if (inside)
	{
		return float3(0.0);
	}
	float3 result = inputs.emissionLuminance * inputs.emissionColor;
	if (BSDF_ENABLE_SHEEN_AND_COAT)
	{
		if (inputs.coatWeight > 0.0)
		{
			result *= lobes.base.inBaseLayerScale;
		}
		if (inputs.fuzzWeight > 0.0)
		{
			result *= float3(lobes.BaseLayerScaleIncoming());
		}
	}
	return result;
}
