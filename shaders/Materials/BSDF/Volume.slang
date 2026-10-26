// The homogeneous interior medium of a material, from the transmission and subsurface inputs.
import Common.Math;
import Materials.BSDF.BSDFCommon;

// Clamps keep extreme inputs from overflowing into NaNs.
static const float VOLUME_MIN_COLOR = 1e-3;
static const float VOLUME_MIN_DISTANCE = 1e-3;
static const float VOLUME_MAX_ABS_ANISOTROPY = 0.999;

struct HomogeneousVolume
{
	float3 extinction;
	float3 albedo;	  // single-scattering albedo
	float anisotropy; // Henyey-Greenstein mean cosine

	__init(float3 extinction, float3 albedo, float anisotropy)
	{
		this.extinction = extinction;
		this.albedo = albedo;
		this.anisotropy = anisotropy;
	}

	static HomogeneousVolume Empty()
	{
		return HomogeneousVolume(float3(0.0), float3(0.0), 0.0);
	}

	static HomogeneousVolume FromAbsorptionAndScattering(float3 absorption, float3 scattering, float anisotropy)
	{
		float3 extinction = absorption + scattering;
		float3 albedo;
		if (all(extinction > float3(0.0)))
		{
			albedo = scattering / extinction;
		}
		else
		{
			[ForceUnroll]
			for (int c = 0; c < 3; ++c)
			{
				albedo[c] = extinction[c] > 0.0 ? scattering[c] / extinction[c] : 0.0;
			}
		}
		return HomogeneousVolume(extinction, albedo, anisotropy);
	}

	bool IsEmpty()
	{
		return all(extinction == float3(0.0));
	}

	float3 Absorption()
	{
		return extinction * (1.0 - albedo);
	}

	float3 Scattering()
	{
		return extinction * albedo;
	}

	float3 Transmittance(float distance)
	{
		return exp(extinction * -distance);
	}
};

// Subsurface radius (mean free path per channel) and multiple-scattering color to a volume, with
// the van de Hulst albedo mapping (compensates for the anisotropy; the extinction does not).
HomogeneousVolume CreateSubsurfaceVolume(float radius, float3 radiusScale, float3 color, float anisotropy)
{
	float3 meanFreePath = max(radius * radiusScale, float3(VOLUME_MIN_DISTANCE));
	float3 extinction = float3(1.0) / meanFreePath;
	float g = clamp(anisotropy, -VOLUME_MAX_ABS_ANISOTROPY, VOLUME_MAX_ABS_ANISOTROPY);
	float3 s = float3(4.09712) + float3(4.20863) * color - sqrt(float3(9.59217) + float3(41.6808) * color + float3(17.7126) * Square(color));
	float3 albedo = (float3(1.0) - Square(s)) / (float3(1.0) - g * Square(s));
	return HomogeneousVolume(extinction, saturate(albedo), g);
}

// Transmission color reached at the transmission depth, plus scattering; depth > 0.
HomogeneousVolume CreateTransmissionVolume(float3 color, float depth, float3 scatter, float anisotropy)
{
	if (MinComponent(color) >= 1.0 && MaxComponent(scatter) <= 0.0)
	{
		return HomogeneousVolume.Empty();
	}
	float3 clampedColor = max(color, float3(VOLUME_MIN_COLOR));
	float invDepth = 1.0 / max(depth, VOLUME_MIN_DISTANCE);
	float3 extinction = -log(clampedColor) * invDepth;
	float3 scattering = scatter * invDepth;
	float3 absorption = extinction - scattering;
	// OpenPBR: a negative absorption is shifted up by enough gray
	if (MinComponent(absorption) < 0.0)
	{
		absorption -= MinComponent(absorption);
	}
	return HomogeneousVolume.FromAbsorptionAndScattering(absorption, scattering, clamp(anisotropy, -VOLUME_MAX_ABS_ANISOTROPY, VOLUME_MAX_ABS_ANISOTROPY));
}

HomogeneousVolume AddVolumes(HomogeneousVolume a, HomogeneousVolume b, float weightA, float weightB)
{
	float3 absorption = a.Absorption() * weightA + b.Absorption() * weightB;
	float3 scattering = a.Scattering() * weightA + b.Scattering() * weightB;
	float anisotropy = SafeDivide(a.anisotropy * weightA + b.anisotropy * weightB, weightA + weightB, 0.0);
	return HomogeneousVolume.FromAbsorptionAndScattering(absorption, scattering, anisotropy);
}
