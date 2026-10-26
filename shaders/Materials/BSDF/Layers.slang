// The layer stack: fuzz over coat over the base lobes. Sampling picks one lobe and returns the
// weight and pdf of the whole stack (one-sample MIS over all lobes). No lobe is a Dirac delta.
import Common.Math;
import Materials.BSDF.BSDFCommon;
import Materials.BSDF.EnergyTables;
import Materials.BSDF.Lobes;
import Materials.BSDF.ReflectionCoefficients;

static const int BASE_LOBE_SPECULAR = 0;
static const int BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING = 1;
static const int BASE_LOBE_METAL_MULTIPLE_SCATTERING = 2;
static const int BASE_LOBE_DIFFUSE = 3;
static const int BASE_LOBE_THIN_WALL_SPECULAR_TRANSMISSION = 4;
static const int BASE_LOBE_THIN_WALL_DIFFUSE_TRANSMISSION = 5;
static const int BASE_LOBE_COUNT = 6;

bool BaseLobeEnabled(int index)
{
	return (BSDF_ENABLE_TRANSLUCENCY || index != BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING) &&
		   (BSDF_ENABLE_METALLIC || index != BASE_LOBE_METAL_MULTIPLE_SCATTERING);
}

// Lobes are selected by weight, which is zero exactly when their albedo is (up to channels the
// throughput already zeroes); most materials leave several of them inactive.

// The already weighted base lobes side by side, selected by their estimated contributions.
struct BaseLobe : ILayer
{
	SpecularLobe specular;
	DielectricMultipleScatteringLobe dielectricMultipleScattering;
	MetalMultipleScatteringLobe metalMultipleScattering;
	DiffuseLobe diffuse;
	ThinWallSpecularTransmissionLobe thinWallSpecularTransmission;
	ThinWallDiffuseTransmissionLobe thinWallDiffuseTransmission;
	float weights[BASE_LOBE_COUNT];

	[mutating]
	void InitWeights(float3 wo, float3 throughput)
	{
		[ForceUnroll]
		for (int i = 0; i < BASE_LOBE_COUNT; ++i)
		{
			weights[i] = BaseLobeEnabled(i) ? LobeEstimate(i, wo, throughput) : 0.0;
		}
	}

	float LobeEstimate(int index, float3 wo, float3 throughput)
	{
		switch (index)
		{
		case BASE_LOBE_SPECULAR:
			return specular.EstimateContribution(wo, throughput);
		case BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING:
			return dielectricMultipleScattering.EstimateContribution(wo, throughput);
		case BASE_LOBE_METAL_MULTIPLE_SCATTERING:
			return metalMultipleScattering.EstimateContribution(wo, throughput);
		case BASE_LOBE_DIFFUSE:
			return diffuse.EstimateContribution(wo, throughput);
		case BASE_LOBE_THIN_WALL_SPECULAR_TRANSMISSION:
			return thinWallSpecularTransmission.EstimateContribution(wo, throughput);
		default:
			return thinWallDiffuseTransmission.EstimateContribution(wo, throughput);
		}
	}

	// One case per lobe, so each lobe is instantiated once per call site.
	void LobeEvalPdf(int index, float3 wo, float3 wi, out DiffuseSpecular f, out float pdf)
	{
		switch (index)
		{
		case BASE_LOBE_SPECULAR:
			f = specular.Eval(wo, wi);
			pdf = specular.Pdf(wo, wi);
			break;
		case BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING:
			f = dielectricMultipleScattering.Eval(wo, wi);
			pdf = dielectricMultipleScattering.Pdf(wo, wi);
			break;
		case BASE_LOBE_METAL_MULTIPLE_SCATTERING:
			f = metalMultipleScattering.Eval(wo, wi);
			pdf = metalMultipleScattering.Pdf(wo, wi);
			break;
		case BASE_LOBE_DIFFUSE:
			f = diffuse.Eval(wo, wi);
			pdf = diffuse.Pdf(wo, wi);
			break;
		case BASE_LOBE_THIN_WALL_SPECULAR_TRANSMISSION:
			f = thinWallSpecularTransmission.Eval(wo, wi);
			pdf = thinWallSpecularTransmission.Pdf(wo, wi);
			break;
		default:
			f = thinWallDiffuseTransmission.Eval(wo, wi);
			pdf = thinWallDiffuseTransmission.Pdf(wo, wi);
			break;
		}
	}

	LobeSample LobeSampleAt(int index, float3 u, float3 wo)
	{
		switch (index)
		{
		case BASE_LOBE_SPECULAR:
			return specular.Sample(u, wo);
		case BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING:
			return dielectricMultipleScattering.Sample(u, wo);
		case BASE_LOBE_METAL_MULTIPLE_SCATTERING:
			return metalMultipleScattering.Sample(u, wo);
		case BASE_LOBE_DIFFUSE:
			return diffuse.Sample(u, wo);
		case BASE_LOBE_THIN_WALL_SPECULAR_TRANSMISSION:
			return thinWallSpecularTransmission.Sample(u, wo);
		default:
			return thinWallDiffuseTransmission.Sample(u, wo);
		}
	}

	bool IsActive(int index)
	{
		return BaseLobeEnabled(index) && weights[index] > 0.0;
	}

	// Largest GGX alpha among the active lobes; 1 if a diffuse or uniform lobe is active.
	float MaxActiveAlpha()
	{
		if (IsActive(BASE_LOBE_DIFFUSE) || IsActive(BASE_LOBE_THIN_WALL_DIFFUSE_TRANSMISSION) ||
			IsActive(BASE_LOBE_DIELECTRIC_MULTIPLE_SCATTERING) || IsActive(BASE_LOBE_METAL_MULTIPLE_SCATTERING))
		{
			return 1.0;
		}
		if (IsActive(BASE_LOBE_SPECULAR) || IsActive(BASE_LOBE_THIN_WALL_SPECULAR_TRANSMISSION))
		{
			return max(specular.distribution.alpha.x, specular.distribution.alpha.y);
		}
		return 0.0;
	}

	float TotalWeight()
	{
		float total = 0.0;
		[ForceUnroll]
		for (int i = 0; i < BASE_LOBE_COUNT; ++i)
		{
			if (BaseLobeEnabled(i))
			{
				total += weights[i];
			}
		}
		return total;
	}

	// Picks a lobe proportionally to its weight and remaps u to [0, 1); -1 if all weights vanish.
	int SelectLobe(inout float u, out float selectedWeight, out float totalWeight)
	{
		totalWeight = TotalWeight();
		// A subnormal total could scale u up to the total itself and select the last lobe wrongly.
		if (totalWeight <= FLOAT_MIN)
		{
			selectedWeight = 0.0;
			return -1;
		}
		u *= totalWeight;
		float weightSoFar = 0.0;
		[ForceUnroll]
		for (int i = 0; i < BASE_LOBE_COUNT - 1; ++i)
		{
			if (!BaseLobeEnabled(i))
			{
				continue;
			}
			selectedWeight = weights[i];
			if (u < weightSoFar + selectedWeight)
			{
				u = ClampRemappedRandom((u - weightSoFar) / selectedWeight);
				return i;
			}
			weightSoFar += selectedWeight;
		}
		selectedWeight = weights[BASE_LOBE_COUNT - 1];
		u = ClampRemappedRandom((u - weightSoFar) / selectedWeight);
		return BASE_LOBE_COUNT - 1;
	}

	uint LobeType()
	{
		uint type = specular.LobeType();
		if (BSDF_ENABLE_TRANSLUCENCY)
		{
			type |= dielectricMultipleScattering.LobeType();
		}
		if (BSDF_ENABLE_METALLIC)
		{
			type |= metalMultipleScattering.LobeType();
		}
		return type | diffuse.LobeType() | thinWallSpecularTransmission.LobeType() | thinWallDiffuseTransmission.LobeType();
	}

	bool SampleLobe(float3 u, float3 wo, out float3 wi, out uint type, out SampledLobe sampled)
	{
		wi = float3(0.0);
		type = LOBE_NONE;
		sampled = SampledLobe.None();
		float ux = u.x;
		float selectedWeight;
		float totalWeight;
		int selected = SelectLobe(ux, selectedWeight, totalWeight);
		if (selected < 0)
		{
			return false;
		}
		LobeSample s = LobeSampleAt(selected, float3(ux, u.y, u.z), wo);
		wi = s.wi;
		type = s.type;
		sampled = SampledLobe.Make(SAMPLED_BASE, selected, s);
		return s.valid;
	}

	// Loops without unrolling: LobeEvalPdf switches on the index, so unrolling would instantiate
	// every lobe once per iteration.
	void EvalPdf(float3 wo, float3 wi, SampledLobe sampled, out DiffuseSpecular f, out float pdf)
	{
		f = DiffuseSpecular.Zero();
		float sum = 0.0;
		float totalWeight = 0.0;
		[loop]
		for (int i = 0; i < BASE_LOBE_COUNT; ++i)
		{
			if (IsActive(i))
			{
				DiffuseSpecular lobeF = sampled.f;
				float lobePdf = sampled.pdf;
				if (sampled.layer != SAMPLED_BASE || sampled.lobe != i)
				{
					LobeEvalPdf(i, wo, wi, lobeF, lobePdf);
				}
				f = f + lobeF;
				sum += weights[i] * lobePdf;
				totalWeight += weights[i];
			}
		}
		pdf = totalWeight > 0.0 ? sum / totalWeight : 0.0;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		return EvalLayer(this, wo, wi);
	}

	float Pdf(float3 wo, float3 wi)
	{
		return PdfLayer(this, wo, wi);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		return SampleLayer(this, u, wo);
	}

	// The selection weights were estimated at init for this wo and throughput.
	float EstimateContribution(float3 wo, float3 throughput)
	{
		return TotalWeight();
	}
};

// A dielectric coat over Base. From the inside the coat only tints transmission.
struct CoatLobe<Base : ILayer> : ILayer
{
	Base base;
	MicrofacetReflectionLobe<DielectricReflection> reflection; // only used from the outside
	float3 normal;
	float3 tint;
	float presence;
	bool inside;
	float inReflected;		  // energy reflected by the coat along wo
	float3 inBaseLayerScale; // transmittance to the base along wo, including the extra darkening

	__init(Base base, MicrofacetReflectionLobe<DielectricReflection> reflection, float3 normal, float3 wo, float3 tint, float presence,
		float3 extraBaseLayerScale, bool inside)
	{
		this.base = base;
		this.reflection = reflection;
		this.normal = normal;
		this.tint = tint;
		this.presence = presence;
		this.inside = inside;
		float idotn = dot(wo, normal);
		inReflected = ProportionReflected(idotn);
		// The extra scale is view-independent, so it is folded in here (and reaches emission too).
		inBaseLayerScale = BaseLayerScaleOneSide(idotn, inReflected) * extraBaseLayerScale;
	}

	// Tint of one passage through the coat. The coat color is the transmittance squared at normal
	// incidence; longer refracted paths absorb more.
	float3 PassageColor(float cosine)
	{
		if (cosine > 0.0 && MinComponent(tint) < 1.0)
		{
			float3 transmissionAtNormalIncidence = sqrt(tint);
			float refractedCosine = sqrt(max(0.0, 1.0 - (1.0 - Square(cosine)) / Square(reflection.coefficient.eta)));
			float distanceScale = 1.0 / refractedCosine;
			float3 transmissionAlongRay = SafePow(transmissionAtNormalIncidence, float3(distanceScale));
			return lerp(float3(1.0), transmissionAlongRay, presence);
		}
		return float3(1.0);
	}

	// Without a coat (most materials) the reflection lobe is skipped entirely.
	bool HasCoat()
	{
		return presence > 0.0;
	}

	float MaxActiveAlpha()
	{
		return inside || !HasCoat() ? 0.0 : max(reflection.distribution.alpha.x, reflection.distribution.alpha.y);
	}

	float ProportionReflected(float cosine)
	{
		if (cosine > 0.0 && HasCoat())
		{
			return DielectricEnergyReflected(reflection.coefficient.eta, reflection.distribution.isotropicAlpha, cosine) * presence;
		}
		return 0.0;
	}

	float3 BaseLayerScaleOneSide(float cosine, float reflectedFromThisSide)
	{
		return PassageColor(cosine) * (1.0 - reflectedFromThisSide);
	}

	float3 BaseLayerScaleComplete(float3 wi)
	{
		float odotn = dot(wi, normal);
		float outReflected = BSDF_RECIPROCAL_COAT_AND_FUZZ ? ProportionReflected(odotn) : 0.0;
		return inBaseLayerScale * BaseLayerScaleOneSide(odotn, outReflected);
	}

	// Assumes an outside hit.
	float ReflectionProbability(float3 wo)
	{
		// TODO (upstream): use the real path throughput.
		float baseContribution = base.EstimateContribution(wo, float3(1.0)) * MaxComponent(inBaseLayerScale);
		return SafeDivide(inReflected, inReflected + baseContribution, 0.5);
	}

	DiffuseSpecular Combine(DiffuseSpecular coatEval, DiffuseSpecular baseEval, float3 wi)
	{
		return coatEval * presence + baseEval * BaseLayerScaleComplete(wi);
	}

	DiffuseSpecular CoatEval(float3 wo, float3 wi)
	{
		return HasCoat() ? reflection.Eval(wo, wi) : DiffuseSpecular.Zero();
	}

	uint LobeType()
	{
		return inside ? base.LobeType() : reflection.LobeType() | base.LobeType();
	}

	bool SampleLobe(float3 u, float3 wo, out float3 wi, out uint type, out SampledLobe sampled)
	{
		float coatProbability = !inside && HasCoat() ? ReflectionProbability(wo) : 0.0;
		float ux = u.x;
		if (!inside && ux < coatProbability)
		{
			ux = ClampRemappedRandom(ux * (1.0 / coatProbability));
			LobeSample s = reflection.Sample(float3(ux, u.y, u.z), wo);
			wi = s.wi;
			type = s.type;
			sampled = SampledLobe.Make(SAMPLED_COAT, 0, s);
			return s.valid;
		}
		// the base: from inside directly, from outside with u remapped past the coat
		if (!inside)
		{
			ux = ClampRemappedRandom((ux - coatProbability) * (1.0 / (1.0 - coatProbability)));
		}
		return base.SampleLobe(float3(ux, u.y, u.z), wo, wi, type, sampled);
	}

	void EvalPdf(float3 wo, float3 wi, SampledLobe sampled, out DiffuseSpecular f, out float pdf)
	{
		DiffuseSpecular baseF;
		float basePdf;
		base.EvalPdf(wo, wi, sampled, baseF, basePdf);
		if (inside)
		{
			// negated to tint only transmission
			f = baseF * PassageColor(-dot(wi, normal));
			pdf = basePdf;
			return;
		}
		bool coatSampled = sampled.layer == SAMPLED_COAT;
		f = Combine(coatSampled ? sampled.f : CoatEval(wo, wi), baseF, wi);
		pdf = HasCoat() ? lerp(basePdf, coatSampled ? sampled.pdf : reflection.Pdf(wo, wi), ReflectionProbability(wo)) : basePdf;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		return EvalLayer(this, wo, wi);
	}

	float Pdf(float3 wo, float3 wi)
	{
		return PdfLayer(this, wo, wi);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		return SampleLayer(this, u, wo);
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		float baseContribution = base.EstimateContribution(wo, throughput);
		if (inside)
		{
			return baseContribution;
		}
		return MaxComponent(throughput) * inReflected + baseContribution * MaxComponent(inBaseLayerScale);
	}
};

// Rotates v about z so that phi = 0 aligns with woXY (the LTCs are fitted at phi = 0).
float3 SheenRotate(float3 v, float2 woXY)
{
	float r2 = dot(woXY, woXY);
	if (r2 == 0.0)
	{
		return v;
	}
	float invR = 1.0 / sqrt(r2);
	float sinPhi = woXY.y * invR;
	float cosPhi = woXY.x * invR;
	return float3(cosPhi * v.x + sinPhi * -v.y, cosPhi * v.y + sinPhi * v.x, v.z);
}

// The LTC with M^-1 = [[a_inv, 0, b_inv], [0, a_inv, 0], [0, 0, 1]] applied to a cosine lobe.
float SheenEvalLTC(float3 wiLocal, float3 ltc)
{
	float aInv = ltc.x;
	float bInv = ltc.y;
	float3 wiOriginal = float3(aInv * wiLocal.x + bInv * wiLocal.z, aInv * wiLocal.y, wiLocal.z);
	float z = max(0.0, wiLocal.z);
	float lengthSquared = dot(wiOriginal, wiOriginal);
	if (lengthSquared == 0.0 || aInv == 0.0 || z == 0.0)
	{
		return 0.0;
	}
	// factored to keep tiny grazing pdfs representable
	float aInvOverLengthSquared = aInv / lengthSquared;
	return INV_PI * (z * aInvOverLengthSquared) * aInvOverLengthSquared;
}

float3 SheenSampleLTC(float3 ltc, float2 u)
{
	float3 wiOriginal = SampleCosineHemisphere(u);
	float aInv = ltc.x;
	float bInv = ltc.y;
	float a = 1.0 / aInv;
	return normalize(float3(wiOriginal.x * a - wiOriginal.z * bInv * a, wiOriginal.y * a, wiOriginal.z));
}

// Fuzz over Base: the LTC sheen of Zeltner, Burley and Chiang 2022 ("Practical Multiple-Scattering
// Sheen Using Linearly Transformed Cosines"), volume fit.
struct FuzzLobe<Base : ILayer> : ILayer
{
	Base base;
	float alpha; // sheen roughness = sqrt(SGGX sigma)
	float3 tint;
	float presence;
	Frame basis;
	float3 woLocal;
	float viewReflected; // proportion reflected along wo, including the presence

	__init(Base base, float3 normal, float3 wo, float roughness, float3 tint, float presence)
	{
		this.base = base;
		alpha = roughness;
		this.tint = tint;
		this.presence = presence;
		basis = BasisFromNormal(normal);
		woLocal = basis.ToLocal(wo);
		viewReflected = 0.0;
		viewReflected = ProportionReflected(woLocal);
	}

	float3 Coefficients(float3 directionLocal)
	{
		return SheenLTCCoefficients(alpha, directionLocal.z);
	}

	// Without fuzz (most materials) the sheen and its table lookups are skipped entirely.
	bool HasFuzz()
	{
		return presence > 0.0;
	}

	// Always below one: the sheen volume has finite density and thickness.
	float ProportionReflected(float3 directionLocal)
	{
		if (directionLocal.z <= 0.0 || !HasFuzz())
		{
			return 0.0;
		}
		return presence * Coefficients(directionLocal).z;
	}

	float BaseLayerScaleIncoming()
	{
		return 1.0 - viewReflected;
	}

	float BaseLayerScaleComplete(float3 wiLocal)
	{
		float outgoing = BSDF_RECIPROCAL_COAT_AND_FUZZ ? 1.0 - ProportionReflected(wiLocal) : 1.0;
		return BaseLayerScaleIncoming() * outgoing;
	}

	float3 SheenEval(float3 wiLocal)
	{
		if (woLocal.z <= 0.0 || wiLocal.z <= 0.0 || !HasFuzz())
		{
			return float3(0.0);
		}
		float3 wiStandard = SheenRotate(wiLocal, float2(woLocal.x, -woLocal.y));
		float3 ltc = Coefficients(woLocal);
		float3 value = float3(SheenEvalLTC(wiStandard, ltc));
		value *= presence * ltc.z * tint;
		return value;
	}

	float SheenPdf(float3 wiLocal)
	{
		if (woLocal.z <= 0.0 || wiLocal.z <= 0.0 || !HasFuzz())
		{
			return 0.0;
		}
		return SheenEvalLTC(SheenRotate(wiLocal, float2(woLocal.x, -woLocal.y)), Coefficients(woLocal));
	}

	float SheenProbability(float3 wo)
	{
		// TODO (upstream): use the real path throughput.
		float sheenContribution = viewReflected * MaxComponent(tint);
		float baseContribution = base.EstimateContribution(wo, float3(1.0)) * BaseLayerScaleIncoming();
		return SafeDivide(sheenContribution, sheenContribution + baseContribution, 0.5);
	}

	uint LobeType()
	{
		return LOBE_GLOSSY | LOBE_REFLECTION | base.LobeType();
	}

	bool SampleLobe(float3 u, float3 wo, out float3 wi, out uint type, out SampledLobe sampled)
	{
		wi = float3(0.0);
		type = LOBE_GLOSSY | LOBE_REFLECTION;
		sampled = SampledLobe.None();
		float sheenProbability = HasFuzz() ? SheenProbability(wo) : 0.0;
		if (u.x < sheenProbability)
		{
			if (woLocal.z <= 0.0)
			{
				return false;
			}
			float3 wiLocal = SheenRotate(SheenSampleLTC(Coefficients(woLocal), u.yz), woLocal.xy);
			if (woLocal.z * wiLocal.z <= 0.0)
			{
				return false;
			}
			// unit length by construction; renormalized against rounding in the basis rotation
			wi = normalize(basis.ToWorld(wiLocal));
			return true;
		}
		float ux = ClampRemappedRandom((u.x - sheenProbability) * (1.0 / (1.0 - sheenProbability)));
		return base.SampleLobe(float3(ux, u.y, u.z), wo, wi, type, sampled);
	}

	void EvalPdf(float3 wo, float3 wi, SampledLobe sampled, out DiffuseSpecular f, out float pdf)
	{
		DiffuseSpecular baseF;
		float basePdf;
		base.EvalPdf(wo, wi, sampled, baseF, basePdf);
		float3 wiLocal = basis.ToLocal(wi);
		f = baseF * BaseLayerScaleComplete(wiLocal) + DiffuseSpecular.Specular(SheenEval(wiLocal));
		pdf = HasFuzz() ? lerp(basePdf, SheenPdf(wiLocal), SheenProbability(wo)) : basePdf;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		return EvalLayer(this, wo, wi);
	}

	float Pdf(float3 wo, float3 wi)
	{
		return PdfLayer(this, wo, wi);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		return SampleLayer(this, u, wo);
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return ThroughputWeightedMax(throughput, viewReflected * tint) + base.EstimateContribution(wo, throughput) * BaseLayerScaleIncoming();
	}
};
