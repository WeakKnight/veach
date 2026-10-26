// Thin-film iridescence (Belcour and Barla 2017) over a dielectric and / or a metal base, with
// complex Fresnel amplitudes so total internal reflection keeps its phase.
import Common.Math;
import Materials.BSDF.BSDFCommon;

typealias Complex = float2; // (real, imaginary)

static const float THIN_FILM_MIN_DENOMINATOR = 1e-9;

Complex ComplexMul(Complex a, Complex b)
{
	return Complex(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

Complex ComplexDiv(Complex a, Complex b, float minMagnitude, Complex fallback)
{
	float denominator = dot(b, b);
	if (denominator < minMagnitude * minMagnitude)
	{
		return fallback;
	}
	float rcpDenominator = 1.0 / denominator;
	return Complex((a.x * b.x + a.y * b.y) * rcpDenominator, (a.y * b.x - a.x * b.y) * rcpDenominator);
}

Complex ComplexSqrt(Complex z)
{
	float r = length(z);
	return Complex(sqrt(max((r + z.x) * 0.5, 0.0)), SignNonZero(z.y) * sqrt(max((r - z.x) * 0.5, 0.0)));
}

Complex ComplexExpI(float theta)
{
	return Complex(cos(theta), sin(theta));
}

struct Polarized
{
	float s;
	float p;
};

struct PolarizedComplex
{
	Complex s;
	Complex p;
};

// Snell's law for a real or complex eta_t; picks the branch with Im(eta_t cos(theta_t)) >= 0.
Complex RefractedCosine(float cosThetaI, float etaI, Complex etaT)
{
	float sinThetaI = sqrt(saturate(1.0 - cosThetaI * cosThetaI));
	Complex sinThetaT = sinThetaI * ComplexDiv(Complex(etaI, 0.0), etaT, THIN_FILM_MIN_DENOMINATOR, Complex(1.0, 0.0));
	Complex cosThetaT = ComplexSqrt(Complex(1.0, 0.0) - ComplexMul(sinThetaT, sinThetaT));
	if (ComplexMul(etaT, cosThetaT).y < 0.0)
	{
		cosThetaT = -cosThetaT;
	}
	return cosThetaT;
}

PolarizedComplex FresnelAmplitudesComplex(float cosThetaI, float etaI, Complex etaT)
{
	Complex cosThetaT = RefractedCosine(cosThetaI, etaI, etaT);
	Complex etaICosI = Complex(etaI * cosThetaI, 0.0);
	Complex etaTCosT = ComplexMul(etaT, cosThetaT);
	Complex etaTCosI = cosThetaI * etaT;
	Complex etaICosT = etaI * cosThetaT;
	PolarizedComplex r;
	r.s = ComplexDiv(etaICosI - etaTCosT, etaICosI + etaTCosT, THIN_FILM_MIN_DENOMINATOR, Complex(1.0, 0.0));
	r.p = ComplexDiv(etaTCosI - etaICosT, etaTCosI + etaICosT, THIN_FILM_MIN_DENOMINATOR, Complex(1.0, 0.0));
	return r;
}

// Real amplitudes for the dielectric exterior-to-film interface; cosThetaT = 0 on total internal reflection.
void FresnelAmplitudesDielectric(float cosThetaI, float etaI, float etaT, out Polarized r, out Polarized t, out float cosThetaT)
{
	float sinThetaI = sqrt(saturate(1.0 - cosThetaI * cosThetaI));
	float sinThetaT = etaI / etaT * sinThetaI;
	if (sinThetaT >= 1.0)
	{
		r.s = 1.0;
		r.p = 1.0;
		t.s = 0.0;
		t.p = 0.0;
		cosThetaT = 0.0;
		return;
	}
	cosThetaT = sqrt(saturate(1.0 - sinThetaT * sinThetaT));

	float etaICosI = etaI * cosThetaI;
	float etaTCosT = etaT * cosThetaT;
	float etaTCosI = etaT * cosThetaI;
	float etaICosT = etaI * cosThetaT;

	float denominatorS = etaICosI + etaTCosT;
	float denominatorP = etaTCosI + etaICosT;
	denominatorS = abs(denominatorS) < THIN_FILM_MIN_DENOMINATOR ? (denominatorS >= 0.0 ? THIN_FILM_MIN_DENOMINATOR : -THIN_FILM_MIN_DENOMINATOR) : denominatorS;
	denominatorP = abs(denominatorP) < THIN_FILM_MIN_DENOMINATOR ? (denominatorP >= 0.0 ? THIN_FILM_MIN_DENOMINATOR : -THIN_FILM_MIN_DENOMINATOR) : denominatorP;
	float rcpS = 1.0 / denominatorS;
	float rcpP = 1.0 / denominatorP;

	r.s = (etaICosI - etaTCosT) * rcpS;
	r.p = (etaTCosI - etaICosT) * rcpP;
	t.s = (2.0 * etaICosI) * rcpS;
	t.p = (2.0 * etaICosI) * rcpP;
}

// Gulbrandsen 2014, "Artist Friendly Metallic Fresnel": complex IOR from reflectivity r and edge tint g.
Complex GulbrandsenIor(float r, float g)
{
	float clampedR = clamp(r, 0.0, 0.99);
	float sqrtR = sqrt(clampedR);
	float nMin = (1.0 - clampedR) / (1.0 + clampedR);
	float nMax = (1.0 + sqrtR) / (1.0 - sqrtR);
	float n = lerp(nMax, nMin, g);
	float k2 = (Square(n + 1.0) * clampedR - Square(n - 1.0)) / (1.0 - clampedR);
	return Complex(n, sqrt(max(k2, 0.0)));
}

// Airy summation for one polarization and wavelength (Belcour and Barla, eq. 3).
float AiryReflectance(float r12, float t12, float r21, float t21, Complex r23, Complex expIPhi)
{
	Complex r23Exp = ComplexMul(r23, expIPhi);
	Complex numerator = (t12 * t21) * r23Exp;
	Complex denominator = Complex(1.0, 0.0) - r21 * r23Exp;
	Complex rTotal = Complex(r12, 0.0) + ComplexDiv(numerator, denominator, THIN_FILM_MIN_DENOMINATOR, Complex(0.0));
	return dot(rTotal, rTotal);
}

float ThinFilmReflectance(Polarized r12, Polarized t12, Polarized r21, Polarized t21, PolarizedComplex r23, float deltaPhi)
{
	Complex expIPhi = ComplexExpI(deltaPhi);
	float rs = AiryReflectance(r12.s, t12.s, r21.s, t21.s, r23.s, expIPhi);
	float rp = AiryReflectance(r12.p, t12.p, r21.p, t21.p, r23.p, expIPhi);
	return 0.5 * (rs + rp);
}

struct ThinFilmResults
{
	float3 dielectric;
	float3 metal;
};

// Reflectance of the film over each enabled base; transmittance is 1 - reflectance.
// cosThetaI >= 0, thickness > 0 (nm), wavelengths in nm.
ThinFilmResults ThinFilmAndBaseReflectance(
	float cosThetaI, float etaExterior, float etaFilm, float3 etaBase, bool dispersion, float3 metalF0, float3 metalF82Tint,
	bool enableDielectric, bool enableMetal, float thickness, float3 wavelengths)
{
	ThinFilmResults results;
	results.dielectric = float3(0.0);
	results.metal = float3(0.0);
	if (!(enableDielectric || enableMetal))
	{
		return results;
	}

	float cosThetaFilm;
	Polarized r12;
	Polarized t12;
	FresnelAmplitudesDielectric(cosThetaI, etaExterior, etaFilm, r12, t12, cosThetaFilm);
	if (cosThetaFilm <= 0.0)
	{
		// total internal reflection above the film
		if (enableDielectric)
		{
			results.dielectric = float3(1.0);
		}
		if (enableMetal)
		{
			results.metal = float3(1.0);
		}
		return results;
	}

	// reverse direction: r21 = -r12 (180 degree phase shift), t21 by reciprocity
	Polarized r21;
	r21.s = -r12.s;
	r21.p = -r12.p;
	Polarized t21;
	float t21Scale = (etaFilm * cosThetaFilm) / (etaExterior * max(cosThetaI, THIN_FILM_MIN_DENOMINATOR));
	t21.s = t12.s * t21Scale;
	t21.p = t12.p * t21Scale;

	float opticalPathDifference = 2.0 * etaFilm * thickness * cosThetaFilm;
	float3 deltaPhi = 2.0 * PI * opticalPathDifference / wavelengths;

	if (enableDielectric)
	{
		PolarizedComplex r23[3];
		for (int c = 0; c < 3; ++c)
		{
			if (dispersion || c == 0)
			{
				r23[c] = FresnelAmplitudesComplex(cosThetaFilm, etaFilm, Complex(etaBase[c], 0.0));
			}
			else
			{
				r23[c] = r23[0];
			}
		}
		for (int c = 0; c < 3; ++c)
		{
			results.dielectric[c] = ThinFilmReflectance(r12, t12, r21, t21, r23[c], deltaPhi[c]);
		}
	}

	if (enableMetal)
	{
		for (int c = 0; c < 3; ++c)
		{
			PolarizedComplex r23 = FresnelAmplitudesComplex(cosThetaFilm, etaFilm, GulbrandsenIor(metalF0[c], metalF82Tint[c]));
			results.metal[c] = ThinFilmReflectance(r12, t12, r21, t21, r23, deltaPhi[c]);
		}
	}
	return results;
}

// Fades out films thinner than 30 nm.
float ThinFilmPresence(float thickness)
{
	return smoothstep(THIN_FILM_MIN_DENOMINATOR, 30.0, thickness);
}
