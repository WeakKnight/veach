// The lobes of the base surface and the coat. All normals are face-forwarded (same side as wo).
import Common.Math;
import Materials.BSDF.BSDFCommon;
import Materials.BSDF.EnergyTables;
import Materials.BSDF.Fresnel;
import Materials.BSDF.Microfacet;
import Materials.BSDF.ReflectionCoefficients;

// Below this alpha the energy lost to microfacet multiple scattering is invisible.
static const float MIN_ALPHA_WITH_VISIBLE_ENERGY_LOSS = 0.04 * 0.04;

// GGX reflection with a pluggable coefficient (coat, thin-wall specular transmission).
struct MicrofacetReflectionLobe<C : IReflectionCoefficient> : IFlippableLobe
{
	float3 normal;
	GGXDistribution distribution;
	C coefficient;

	__init(float3 normal, GGXDistribution distribution, C coefficient)
	{
		this.normal = normal;
		this.distribution = distribution;
		this.coefficient = coefficient;
	}

	float3 GetNormal()
	{
		return normal;
	}

	uint LobeType()
	{
		return LOBE_GLOSSY | LOBE_REFLECTION;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		float idotn = dot(normal, wo);
		float odotn = dot(normal, wi);
		if (idotn * odotn <= 0.0)
		{
			return DiffuseSpecular.Zero();
		}
		float3 h = normalize(wo + wi);
		float idoth = dot(wo, h);
		float d = distribution.D(h);
		float otherTerms = 1.0 / (4.0 * idotn);
		float3 f = coefficient.Reflection(abs(idoth));
		float3 dOtherTermsF = d * otherTerms * f;
		float g = distribution.G2(wo, wi);
		return DiffuseSpecular.Specular(g * dOtherTermsF);
	}

	float Pdf(float3 wo, float3 wi)
	{
		float idotn = dot(normal, wo);
		float odotn = dot(normal, wi);
		if (idotn * odotn <= 0.0)
		{
			return 0.0;
		}
		float3 h = normalize(wo + wi);
		float idoth = dot(wo, h);
		float odoth = dot(wi, h);
		if (idoth * odoth < 0.0)
		{
			return 0.0; // half-vector rounding
		}
		float d = distribution.D(h);
		float otherTerms = idoth / (4.0 * odoth * idotn);
		float dOtherTerms = d * otherTerms;
		return distribution.G1(wo) * dOtherTerms;
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		float idotn = dot(wo, normal);
		float3 h = distribution.SampleVisibleNormal(wo, u.xy);
		float idoth = dot(wo, h);
		if (idoth < 0.0)
		{
			return LobeSample.Invalid();
		}
		float3 wi = normalize(-wo + h * 2.0 * idoth);
		float odotn = dot(normal, wi);
		if (idotn * odotn <= 0.0)
		{
			return LobeSample.Invalid();
		}
		float odoth = dot(wi, h);
		float3 f = coefficient.Reflection(idoth);
		float gShadowing = distribution.G1(wi);
		float d = distribution.D(h);
		if (d <= 0.0)
		{
			return LobeSample.Invalid();
		}
		float gMasking = distribution.G1(wo);
		float pdf = d * gMasking * idoth / (4.0 * odoth * idotn);
		return LobeSample.Make(wi, DiffuseSpecular.Specular(f * gShadowing), pdf, LobeType());
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return coefficient.EstimateWeightOnGGX(throughput, dot(wo, normal), distribution.isotropicAlpha);
	}
};

// Mirrors a lobe to the opposite hemisphere: wo is reflected across the inner lobe's (already
// flipped) normal and reflection / transmission swap.
struct FlippedLobe<L : IFlippableLobe> : ILobe
{
	L lobe;

	__init(L lobe)
	{
		this.lobe = lobe;
	}

	uint LobeType()
	{
		return SwapReflectionTransmission(lobe.LobeType());
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		return lobe.Eval(reflect(wo, lobe.GetNormal()), wi);
	}

	float Pdf(float3 wo, float3 wi)
	{
		return lobe.Pdf(reflect(wo, lobe.GetNormal()), wi);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		LobeSample s = lobe.Sample(u, reflect(wo, lobe.GetNormal()));
		s.type = SwapReflectionTransmission(s.type);
		return s;
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return lobe.EstimateContribution(reflect(wo, lobe.GetNormal()), throughput);
	}
};

// Energy-preserving Fujii Oren-Nayar (Portsmouth, Kutz and Hill 2025), scaled by the energy the
// opaque dielectric specular above it does not reflect.
static const float FON_A = 0.5 - 2.0 / (3.0 * PI);
static const float FON_B = 2.0 / 3.0 - 28.0 / (15.0 * PI);

// FON directional albedo (approximation).
float FONAlbedo(float mu, float roughness)
{
	float mucomp = 1.0 - mu;
	const float G1 = 0.0571085289;
	const float G2 = 0.491881867;
	const float G3 = -0.332181442;
	const float G4 = 0.0714429953;
	float gOverPi = mucomp * (G1 + mucomp * (G2 + mucomp * (G3 + mucomp * G4)));
	return (1.0 + roughness * gOverPi) / (1.0 + FON_A * roughness);
}

// viewLocal / lightLocal in the z-up frame of the normal.
float3 EvalEON(float3 rho, float roughness, float3 viewLocal, float3 lightLocal)
{
	float muI = viewLocal.z;
	float muO = lightLocal.z;
	float s = dot(viewLocal, lightLocal) - muI * muO;
	float sOverT = s > 0.0 ? s / max(muI, muO) : s;
	float aF = 1.0 / (1.0 + FON_A * roughness);
	float3 fSingle = (rho * INV_PI) * aF * (1.0 + roughness * sOverT);
	float eFo = FONAlbedo(muO, roughness);
	float eFi = FONAlbedo(muI, roughness);
	float averageEF = aF * (1.0 + FON_B * roughness);
	float3 rhoMulti = (rho * rho) * averageEF / (float3(1.0) - rho * (1.0 - averageEF));
	const float EPS = 1.0e-7;
	float3 fMulti = (rhoMulti * INV_PI) * max(EPS, 1.0 - eFo) * max(EPS, 1.0 - eFi) / max(EPS, 1.0 - averageEF);
	return fSingle + fMulti;
}

struct DiffuseLobe : IFlippableLobe
{
	float3 normal;
	float3 albedo;
	float roughness;
	float specularAlpha;
	float specularEta;
	float specularCompensation; // (1 - E_spec(wo)) / (1 - E_spec_avg)

	__init(float3 normal, float3 wo, float3 albedo, float roughness, float specularAlpha, float specularEta)
	{
		this.normal = normal;
		this.albedo = albedo;
		this.roughness = roughness;
		this.specularAlpha = specularAlpha;
		this.specularEta = specularEta;
		specularCompensation = 0.0;
		// A black albedo (e.g. metals) contributes nothing, so its lookups are skipped.
		if (any(albedo > float3(0.0)))
		{
			float cosIn = dot(wo, normal);
			float numerator = OpaqueDielectricEnergyComplement(specularEta, specularAlpha, cosIn);
			float denominator = OpaqueDielectricAverageEnergyComplement(specularEta, specularAlpha);
			specularCompensation = numerator / ClampAverageEnergyComplement(denominator);
		}
	}

	float3 GetNormal()
	{
		return normal;
	}

	uint LobeType()
	{
		return LOBE_DIFFUSE | LOBE_REFLECTION;
	}

	float3 BRDFLocal(float3 woLocal, float3 wiLocal)
	{
		float3 brdf = EvalEON(albedo, roughness, woLocal, wiLocal);
		float compensation = specularCompensation * OpaqueDielectricEnergyComplement(specularEta, specularAlpha, wiLocal.z);
		return brdf * compensation;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		float cosOut = dot(wi, normal);
		if (cosOut <= 0.0)
		{
			return DiffuseSpecular.Zero();
		}
		Frame basis = BasisFromNormal(normal);
		return DiffuseSpecular.Diffuse(BRDFLocal(basis.ToLocal(wo), basis.ToLocal(wi)) * cosOut);
	}

	float Pdf(float3 wo, float3 wi)
	{
		return max(dot(wi, normal), 0.0) * INV_PI;
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		float3 wiLocal = SampleCosineHemisphere(u.xy);
		float cosOut = wiLocal.z;
		if (cosOut == 0.0)
		{
			return LobeSample.Invalid();
		}
		Frame basis = BasisFromNormal(normal);
		float3 wi = basis.ToWorld(wiLocal);
		// pdf = cos / pi, so the cosine cancels
		DiffuseSpecular weight = DiffuseSpecular.Diffuse(BRDFLocal(basis.ToLocal(wo), wiLocal) * PI);
		return LobeSample.Make(wi, weight, cosOut * INV_PI, LobeType());
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return ThroughputWeightedMax(throughput, albedo * specularCompensation);
	}
};

// Uniform hemisphere sample with z = cos(theta) taken from u.
float3 UniformHemisphereDirection(Frame basis, float z, float u)
{
	float horizontal = sqrt(1.0 - Square(z));
	float azimuth = TWO_PI * u;
	float y = sin(azimuth) * horizontal;
	float x = cos(azimuth) * horizontal;
	return basis.ToWorld(float3(x, y, z));
}

// Energy lost by single-scattering rough dielectric reflection and refraction, reintroduced as
// uniform reflection and transmission (Turquin 2019 style energy tables).
struct DielectricMultipleScatteringLobe : ILobe
{
	float3 normal;
	float alpha;
	float eta;
	float3 reflectionScale;
	float3 transmissionScale;
	float reflectionRatio;
	float energyComplementWo;

	__init(float3 normal, float3 wo, float alpha, float eta, float3 reflectionScale, float3 transmissionScale)
	{
		this.normal = normal;
		this.alpha = alpha;
		this.eta = eta;
		this.reflectionScale = reflectionScale;
		this.transmissionScale = transmissionScale;
		reflectionRatio = 0.0;
		energyComplementWo = 0.0;
		// Black scales (e.g. opaque dielectrics) contribute nothing, so their lookups are skipped.
		if (alpha >= MIN_ALPHA_WITH_VISIBLE_ENERGY_LOSS && any(max(reflectionScale, transmissionScale) > float3(0.0)))
		{
			reflectionRatio = IdealDielectricReflectionRatio(eta, alpha);
			energyComplementWo = IdealDielectricEnergyComplement(eta, alpha, dot(wo, normal));
		}
	}

	bool Active()
	{
		return alpha >= MIN_ALPHA_WITH_VISIBLE_ENERGY_LOSS;
	}

	// Clamped to 1 / odotn so weights stay bounded at grazing angles and low roughness.
	float TabulatedFactors(float odotn, bool includeRatio)
	{
		float iorToUse = eta;
		float ratio = reflectionRatio;
		if (odotn <= 0.0)
		{
			odotn = -odotn;
			iorToUse = 1.0 / eta;
			ratio = 1.0 - reflectionRatio;
		}
		float factors = energyComplementWo * IdealDielectricEnergyComplement(iorToUse, alpha, odotn) /
						ClampAverageEnergyComplement(IdealDielectricAverageEnergyComplement(iorToUse, alpha));
		if (includeRatio)
		{
			factors *= ratio;
		}
		return min(factors, SafeDivide(1.0, odotn, 0.0));
	}

	uint LobeType()
	{
		return LOBE_GLOSSY | LOBE_REFLECTION | LOBE_TRANSMISSION;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		if (!Active())
		{
			return DiffuseSpecular.Zero();
		}
		float odotn = dot(wi, normal);
		float unscaled = TabulatedFactors(odotn, true) * INV_PI;
		float unscaledCos = unscaled * abs(odotn);
		return DiffuseSpecular.Specular((odotn > 0.0 ? reflectionScale : transmissionScale) * unscaledCos);
	}

	float Pdf(float3 wo, float3 wi)
	{
		if (!Active())
		{
			return 0.0;
		}
		return INV_TWO_PI * (dot(wi, normal) > 0.0 ? reflectionRatio : 1.0 - reflectionRatio);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		if (!Active())
		{
			return LobeSample.Invalid();
		}
		float ux = u.x;
		float z;
		if (ux < reflectionRatio)
		{
			ux = ClampRemappedRandom(ux / reflectionRatio);
			z = ux;
		}
		else
		{
			ux = ClampRemappedRandom((ux - reflectionRatio) / (1.0 - reflectionRatio));
			z = -ux;
		}
		float3 wi = UniformHemisphereDirection(BasisFromNormal(normal), z, u.y);
		float odotn = dot(wi, normal);
		float unscaledWeight = 2.0 * abs(odotn) * TabulatedFactors(odotn, false);
		if (odotn > 0.0)
		{
			return LobeSample.Make(wi, DiffuseSpecular.Specular(reflectionScale * unscaledWeight), INV_TWO_PI * reflectionRatio, LOBE_GLOSSY | LOBE_REFLECTION);
		}
		return LobeSample.Make(wi, DiffuseSpecular.Specular(transmissionScale * unscaledWeight), INV_TWO_PI * (1.0 - reflectionRatio), LOBE_GLOSSY | LOBE_TRANSMISSION);
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		if (!Active())
		{
			return 0.0;
		}
		float3 averageScale = reflectionScale * reflectionRatio + transmissionScale * (1.0 - reflectionRatio);
		return ThroughputWeightedMax(throughput, averageScale) * energyComplementWo;
	}
};

// Kulla-Conty style multiple scattering for the metal, as uniform hemisphere reflection.
struct MetalMultipleScatteringLobe : ILobe
{
	float3 normal;
	float alpha;
	float3 scale;
	float energyComplementWo;

	__init(float3 normal, float3 wo, float alpha, float3 scale)
	{
		this.normal = normal;
		this.alpha = alpha;
		this.scale = scale;
		energyComplementWo = Active() && any(scale > float3(0.0)) ? IdealMetalEnergyComplement(alpha, dot(wo, normal)) : 0.0;
	}

	bool Active()
	{
		return alpha >= MIN_ALPHA_WITH_VISIBLE_ENERGY_LOSS;
	}

	float TabulatedFactors(float odotn)
	{
		float factors = energyComplementWo * IdealMetalEnergyComplement(alpha, odotn) / ClampAverageEnergyComplement(IdealMetalAverageEnergyComplement(alpha));
		return min(factors, SafeDivide(1.0, odotn, 0.0));
	}

	uint LobeType()
	{
		return LOBE_GLOSSY | LOBE_REFLECTION;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		float odotn = dot(wi, normal);
		if (!Active() || odotn <= 0.0)
		{
			return DiffuseSpecular.Zero();
		}
		float unscaled = TabulatedFactors(odotn) * INV_PI;
		return DiffuseSpecular.Specular(scale * (unscaled * odotn));
	}

	float Pdf(float3 wo, float3 wi)
	{
		return Active() && dot(wi, normal) > 0.0 ? INV_TWO_PI : 0.0;
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		if (!Active())
		{
			return LobeSample.Invalid();
		}
		float3 wi = UniformHemisphereDirection(BasisFromNormal(normal), u.x, u.y);
		float odotn = dot(wi, normal);
		float unscaledWeight = 2.0 * odotn * TabulatedFactors(odotn);
		return LobeSample.Make(wi, DiffuseSpecular.Specular(scale * unscaledWeight), INV_TWO_PI, LobeType());
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return Active() ? ThroughputWeightedMax(throughput, scale) * energyComplementWo : 0.0;
	}
};

// The base specular: GGX reflection and refraction with the full base coefficient. With dispersion
// every channel refracts with its own IOR; the channel is picked by throughput and MIS'ed.
struct SpecularLobe : ILobe
{
	float3 normal;
	GGXDistribution distribution;
	BaseReflectionTransmission coefficient;
	float3 eta; // for refraction, per channel
	float3 throughput;

	__init(float3 normal, GGXDistribution distribution, BaseReflectionTransmission coefficient, float3 eta, float3 throughput)
	{
		this.normal = normal;
		this.distribution = distribution;
		this.coefficient = coefficient;
		this.eta = eta;
		this.throughput = throughput;
	}

	float3 ChannelProbabilities()
	{
		return throughput / Sum(throughput);
	}

	// The half vector of a refraction points into the less dense medium.
	bool ValidTransmissionHalfVector(float3 h)
	{
		return (eta.r >= 1.0 && dot(normal, h) > 0.0) || (eta.r < 1.0 && dot(normal, h) < 0.0);
	}

	uint LobeType()
	{
		return BSDF_ENABLE_TRANSLUCENCY ? LOBE_GLOSSY | LOBE_REFLECTION | LOBE_TRANSMISSION : LOBE_GLOSSY | LOBE_REFLECTION;
	}

	// Refraction for one channel IOR: D, the other terms and the |idoth| the coefficients take.
	bool TransmissionTerms(float3 wo, float3 wi, float idotn, float channelEta, out float d, out float otherTerms, out float absIdoth)
	{
		d = 0.0;
		otherTerms = 0.0;
		absIdoth = 0.0;
		float3 h = -normalize(wo + wi * channelEta);
		if (!ValidTransmissionHalfVector(h))
		{
			return false;
		}
		float idoth = dot(wo, h);
		float odoth = dot(wi, h);
		if (idoth * odoth >= 0.0)
		{
			return false;
		}
		d = distribution.D(h);
		otherTerms = Square(channelEta) * abs(idoth) * abs(odoth) / (Square(idoth + channelEta * odoth) * idotn);
		absIdoth = abs(idoth);
		return true;
	}

	DiffuseSpecular Eval(float3 wo, float3 wi)
	{
		float idotn = dot(normal, wo);
		float odotn = dot(normal, wi);
		if (idotn * odotn > 0.0)
		{
			float3 h = normalize(wo + wi);
			float idoth = dot(wo, h);
			float d = distribution.D(h);
			float otherTerms = 1.0 / (4.0 * idotn);
			float3 f = coefficient.Reflection(abs(idoth));
			float3 dOtherTermsF = d * otherTerms * f;
			return DiffuseSpecular.Specular(distribution.G2(wo, wi) * dOtherTermsF);
		}
		if (!BSDF_ENABLE_TRANSLUCENCY || idotn * odotn >= 0.0)
		{
			return DiffuseSpecular.Zero();
		}
		float3 dOtherTermsF;
		float d;
		float otherTerms;
		float absIdoth;
		if (BSDF_ENABLE_DISPERSION)
		{
			[loop] // one coefficient evaluation per channel, instantiated once
			for (int c = 0; c < 3; ++c)
			{
				dOtherTermsF[c] = TransmissionTerms(wo, wi, idotn, eta[c], d, otherTerms, absIdoth) ? d * otherTerms * coefficient.Transmission(absIdoth)[c] : 0.0;
			}
		}
		else
		{
			if (!TransmissionTerms(wo, wi, idotn, eta.r, d, otherTerms, absIdoth))
			{
				return DiffuseSpecular.Zero();
			}
			dOtherTermsF = d * otherTerms * coefficient.Transmission(absIdoth);
		}
		return DiffuseSpecular.Specular(distribution.G2(wo, wi) * dOtherTermsF);
	}

	float Pdf(float3 wo, float3 wi)
	{
		float idotn = dot(normal, wo);
		float odotn = dot(normal, wi);
		if (idotn * odotn > 0.0)
		{
			float3 h = normalize(wo + wi);
			float idoth = dot(wo, h);
			float odoth = dot(wi, h);
			if (idoth * odoth < 0.0)
			{
				return 0.0; // half-vector rounding
			}
			float d = distribution.D(h);
			float otherTerms = idoth / (4.0 * odoth * idotn);
			float probability = coefficient.ReflectionProbability(throughput, abs(idoth));
			float probabilityDOtherTerms = probability * d * otherTerms;
			return distribution.G1(wo) * probabilityDOtherTerms;
		}
		if (!BSDF_ENABLE_TRANSLUCENCY || idotn * odotn >= 0.0)
		{
			return 0.0;
		}
		float d;
		float otherTerms;
		float absIdoth;
		if (BSDF_ENABLE_DISPERSION)
		{
			float3 probabilityDOtherTerms;
			[loop]
			for (int c = 0; c < 3; ++c)
			{
				probabilityDOtherTerms[c] = TransmissionTerms(wo, wi, idotn, eta[c], d, otherTerms, absIdoth)
												? coefficient.TransmissionProbability(throughput, absIdoth) * d * otherTerms
												: 0.0;
			}
			return distribution.G1(wo) * dot(probabilityDOtherTerms, ChannelProbabilities());
		}
		if (!TransmissionTerms(wo, wi, idotn, eta.r, d, otherTerms, absIdoth))
		{
			return 0.0;
		}
		return distribution.G1(wo) * (coefficient.TransmissionProbability(throughput, absIdoth) * d * otherTerms);
	}

	LobeSample Sample(float3 u, float3 wo)
	{
		float idotn = dot(wo, normal);
		float3 h = distribution.SampleVisibleNormal(wo, u.xy);
		float idoth = dot(wo, h);
		if (idoth < 0.0)
		{
			return LobeSample.Invalid();
		}
		ReflectionTransmission c = coefficient.CoefficientsAndProbabilities(throughput, idoth);
		if (c.reflectionProbability + c.transmissionProbability == 0.0)
		{
			return LobeSample.Invalid();
		}

		if (!BSDF_ENABLE_TRANSLUCENCY || u.z < c.reflectionProbability)
		{
			float3 wi = normalize(-wo + h * 2.0 * idoth);
			float odotn = dot(normal, wi);
			if (idotn * odotn <= 0.0)
			{
				return LobeSample.Invalid();
			}
			float odoth = dot(wi, h);
			DiffuseSpecular weight = DiffuseSpecular.Specular((c.reflection * (1.0 / c.reflectionProbability)) * distribution.G1(wi));
			float d = distribution.D(h);
			if (d <= 0.0)
			{
				return LobeSample.Invalid();
			}
			float pdf = c.reflectionProbability * d * distribution.G1(wo) * idoth / (4.0 * odoth * idotn);
			return LobeSample.Make(wi, weight, pdf, LOBE_GLOSSY | LOBE_REFLECTION);
		}

		if (BSDF_ENABLE_DISPERSION)
		{
			float remapped = (u.z - c.reflectionProbability) / c.transmissionProbability;
			float3 channelProbabilities = ChannelProbabilities();
			int channel = 2;
			if (remapped < channelProbabilities[0])
			{
				channel = 0;
			}
			else if (remapped < channelProbabilities[0] + channelProbabilities[1])
			{
				channel = 1;
			}
			float3 wi;
			if (!Refract(wo, h, idoth, eta[channel], wi))
			{
				return LobeSample.Invalid();
			}
			if (idotn * dot(wi, normal) >= 0.0)
			{
				return LobeSample.Invalid();
			}
			float pdf = Pdf(wo, wi);
			if (pdf == 0.0)
			{
				return LobeSample.Invalid();
			}
			return LobeSample.Make(wi, Eval(wo, wi) * (1.0 / pdf), pdf, LOBE_GLOSSY | LOBE_TRANSMISSION);
		}

		float3 wi;
		if (!Refract(wo, h, idoth, eta.r, wi))
		{
			return LobeSample.Invalid();
		}
		float odotn = dot(wi, normal);
		if (idotn * odotn >= 0.0)
		{
			return LobeSample.Invalid();
		}
		float odoth = dot(wi, h);
		DiffuseSpecular weight = DiffuseSpecular.Specular((c.transmission * (1.0 / c.transmissionProbability)) * distribution.G1(wi));
		float d = distribution.D(h);
		if (d <= 0.0)
		{
			return LobeSample.Invalid();
		}
		float pdf = c.transmissionProbability * d * distribution.G1(wo) * Square(eta.r) * abs(idoth) * abs(odoth) / (Square(idoth + eta.r * odoth) * idotn);
		return LobeSample.Make(wi, weight, pdf, LOBE_GLOSSY | LOBE_TRANSMISSION);
	}

	float EstimateContribution(float3 wo, float3 throughput)
	{
		return coefficient.EstimateWeight(throughput, dot(wo, normal));
	}
};

// Thin-wall specular transmission: GGX "reflection" mirrored through the surface, unrefracted,
// with the window transmittance as a constant coefficient.
typealias ThinWallSpecularTransmissionLobe = FlippedLobe<MicrofacetReflectionLobe<ConstantReflection>>;

ThinWallSpecularTransmissionLobe MakeThinWallSpecularTransmissionLobe(float3 normal, GGXDistribution distribution, float3 transmissionColor)
{
	GGXDistribution flipped = distribution;
	flipped.frame.n = -flipped.frame.n; // only the normal needs to flip
	return ThinWallSpecularTransmissionLobe(MicrofacetReflectionLobe<ConstantReflection>(-normal, flipped, ConstantReflection(transmissionColor)));
}

// Thin-wall diffuse transmission: the diffuse lobe mirrored through the surface.
typealias ThinWallDiffuseTransmissionLobe = FlippedLobe<DiffuseLobe>;

ThinWallDiffuseTransmissionLobe MakeThinWallDiffuseTransmissionLobe(
	float3 normal, float3 wo, float3 albedo, float roughness, float specularAlpha, float specularEta)
{
	float3 flippedNormal = -normal;
	float3 reflectedWo = reflect(wo, normal);
	// Near-grazing views can round to the wrong side of the surface.
	if (dot(reflectedWo, flippedNormal) < 0.0)
	{
		reflectedWo = -reflectedWo;
	}
	return ThinWallDiffuseTransmissionLobe(DiffuseLobe(flippedNormal, reflectedWo, albedo, roughness, specularAlpha, specularEta));
}
