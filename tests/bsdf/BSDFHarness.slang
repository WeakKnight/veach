// Differential test entry: one case per thread, compiled to C++ and run next to the reference
// (Reference.cpp) in tests/generated/bsdf. Case and result layouts are shared with
// Reference.cpp and tests/bsdf/harness.ts.
import Common.Math;
import Materials.BSDF.BSDF;

static const uint CASE_FLOATS = 96;
static const uint RESULT_FLOATS = 32;

[[vk::binding(0, 1)]] StructuredBuffer<float> gCases;
[[vk::binding(1, 1)]] RWStructuredBuffer<float> gResults;

struct CaseReader
{
	uint offset;

	[mutating]
	float Float()
	{
		return gCases[offset++];
	}

	[mutating]
	float2 Float2()
	{
		float x = Float();
		return float2(x, Float());
	}

	[mutating]
	float3 Float3()
	{
		float x = Float();
		float y = Float();
		return float3(x, y, Float());
	}

	[mutating]
	Frame Basis()
	{
		Frame f;
		f.t = Float3();
		f.b = Float3();
		f.n = Float3();
		return f;
	}
};

struct ResultWriter
{
	uint offset;

	[mutating]
	void Float(float v)
	{
		gResults[offset++] = v;
	}

	[mutating]
	void Float3(float3 v)
	{
		Float(v.x);
		Float(v.y);
		Float(v.z);
	}
};

[shader("compute")]
[numthreads(64, 1, 1)]
void Run(uint3 id: SV_DispatchThreadID)
{
	uint count;
	uint stride;
	gCases.GetDimensions(count, stride);
	if ((id.x + 1) * CASE_FLOATS > count)
	{
		return;
	}

	CaseReader r = { id.x * CASE_FLOATS };
	BSDFInputs i;
	i.baseWeight = r.Float();
	i.baseColor = r.Float3();
	i.baseDiffuseRoughness = r.Float();
	i.baseMetalness = r.Float();
	i.subsurfaceWeight = r.Float();
	i.subsurfaceColor = r.Float3();
	i.subsurfaceRadius = r.Float();
	i.subsurfaceRadiusScale = r.Float3();
	i.subsurfaceScatterAnisotropy = r.Float();
	i.specularWeight = r.Float();
	i.specularColor = r.Float3();
	i.specularRoughness = r.Float();
	i.specularRoughnessAnisotropy = r.Float();
	i.specularIor = r.Float();
	i.specularAnisotropyRotation = r.Float2();
	i.coatWeight = r.Float();
	i.coatColor = r.Float3();
	i.coatRoughness = r.Float();
	i.coatRoughnessAnisotropy = r.Float();
	i.coatIor = r.Float();
	i.coatDarkening = r.Float();
	i.coatAnisotropyRotation = r.Float2();
	i.fuzzWeight = r.Float();
	i.fuzzColor = r.Float3();
	i.fuzzRoughness = r.Float();
	i.transmissionWeight = r.Float();
	i.transmissionColor = r.Float3();
	i.transmissionDepth = r.Float();
	i.transmissionScatter = r.Float3();
	i.transmissionScatterAnisotropy = r.Float();
	i.transmissionDispersionScale = r.Float();
	i.transmissionDispersionAbbeNumber = r.Float();
	i.thinFilmWeight = r.Float();
	i.thinFilmThickness = r.Float();
	i.thinFilmIor = r.Float();
	i.emissionLuminance = r.Float();
	i.emissionColor = r.Float3();
	i.geometryOpacity = r.Float();
	i.geometryThinWalled = r.Float() != 0.0;
	i.basis = r.Basis();
	i.coatBasis = r.Basis();
	float3 wo = r.Float3();
	float3 wi = r.Float3();
	float3 u = r.Float3();
	float3 throughput = r.Float3();
	float3 wavelengths = r.Float3();
	float exteriorIor = r.Float();

	BSDF bsdf = BSDF(i, wo, throughput, wavelengths, exteriorIor);
	DiffuseSpecular f = bsdf.Eval(wi);
	float pdf = bsdf.Pdf(wi);
	LobeSample s = bsdf.Sample(u);

	ResultWriter w = { id.x * RESULT_FLOATS };
	w.Float3(f.diffuse);
	w.Float3(f.specular);
	w.Float(pdf);
	w.Float3(s.valid ? s.wi : float3(0.0));
	w.Float3(s.valid ? s.weight.diffuse : float3(0.0));
	w.Float3(s.valid ? s.weight.specular : float3(0.0));
	w.Float(s.valid ? s.pdf : 0.0);
	w.Float(s.valid ? float(s.type) : 0.0);
	w.Float3(bsdf.emission);
	w.Float3(bsdf.volume.extinction);
	w.Float3(bsdf.volume.albedo);
	w.Float(bsdf.volume.anisotropy);
	w.Float(i.NeedsRGBWavelengths() ? 1.0 : 0.0);
	// conditioning of the case: near-delta lobes make sampled values ill-conditioned
	float2 specularAlpha = bsdf.lobes.base.base.specular.distribution.alpha;
	float2 coatAlpha = bsdf.lobes.base.reflection.distribution.alpha;
	w.Float(min(specularAlpha.x, specularAlpha.y));
	w.Float(bsdf.lobes.base.presence > 0.0 ? min(coatAlpha.x, coatAlpha.y) : 1.0);
	for (uint k = 31; k < RESULT_FLOATS; ++k)
	{
		w.Float(0.0);
	}
}
