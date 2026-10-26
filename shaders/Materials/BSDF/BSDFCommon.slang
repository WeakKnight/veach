// Shared types of the layered BSDF: lobe flags, the diffuse / specular split, the lobe interface,
// the basis convention of the lobes and small math helpers.
import Common.Math;

static const float FLOAT_MIN = 1.175494351e-38;
static const float ONE_MINUS_EPSILON = 0.999999940; // largest float below one
static const float INV_FOUR_PI = 0.25 / PI;

// Compile-time feature switches: a disabled feature drops its lobes and branches entirely.
static const bool BSDF_ENABLE_SHEEN_AND_COAT = true;
static const bool BSDF_ENABLE_DISPERSION = true;
static const bool BSDF_ENABLE_TRANSLUCENCY = true;
static const bool BSDF_ENABLE_METALLIC = true;

// Also attenuate the layers below coat and fuzz on the light side. Reciprocal, but it loses energy
// in a fixed-view white furnace; camera-to-light path tracing wants it off.
static const bool BSDF_RECIPROCAL_COAT_AND_FUZZ = false;

static const uint LOBE_NONE = 0u;
static const uint LOBE_REFLECTION = 1u << 0;
static const uint LOBE_TRANSMISSION = 1u << 1;
static const uint LOBE_DIFFUSE = 1u << 2;
static const uint LOBE_GLOSSY = 1u << 3;
static const uint LOBE_SPECULAR = 1u << 4; // Dirac delta
static const uint LOBE_VOLUME = 1u << 5;

uint SwapReflectionTransmission(uint type)
{
	uint swapped = type & ~(LOBE_REFLECTION | LOBE_TRANSMISSION);
	if ((type & LOBE_REFLECTION) != 0u)
	{
		swapped |= LOBE_TRANSMISSION;
	}
	if ((type & LOBE_TRANSMISSION) != 0u)
	{
		swapped |= LOBE_REFLECTION;
	}
	return swapped;
}

bool IsDeltaLobe(uint type)
{
	return (type & LOBE_SPECULAR) != 0u;
}

bool IsTransmissionLobe(uint type)
{
	return (type & LOBE_TRANSMISSION) != 0u;
}

// BSDF values and weights keep their diffuse and specular parts apart (for denoiser guides and
// debug views); most callers only need Sum().
struct DiffuseSpecular
{
	float3 diffuse;
	float3 specular;

	__init(float3 diffuse, float3 specular)
	{
		this.diffuse = diffuse;
		this.specular = specular;
	}

	static DiffuseSpecular Zero()
	{
		return DiffuseSpecular(float3(0.0), float3(0.0));
	}

	static DiffuseSpecular Diffuse(float3 value)
	{
		return DiffuseSpecular(value, float3(0.0));
	}

	static DiffuseSpecular Specular(float3 value)
	{
		return DiffuseSpecular(float3(0.0), value);
	}

	float3 Sum()
	{
		return diffuse + specular;
	}
};

DiffuseSpecular operator+(DiffuseSpecular a, DiffuseSpecular b)
{
	return DiffuseSpecular(a.diffuse + b.diffuse, a.specular + b.specular);
}

DiffuseSpecular operator*(DiffuseSpecular a, float3 scale)
{
	return DiffuseSpecular(a.diffuse * scale, a.specular * scale);
}

DiffuseSpecular operator*(DiffuseSpecular a, float scale)
{
	return DiffuseSpecular(a.diffuse * scale, a.specular * scale);
}

struct LobeSample
{
	float3 wi;
	DiffuseSpecular weight; // f * |cos| / pdf over all lobes
	float pdf;				// solid angle, over all lobes
	uint type;				// the lobe that generated the sample
	bool valid;

	static LobeSample Invalid()
	{
		LobeSample s;
		s.wi = float3(0.0);
		s.weight = DiffuseSpecular.Zero();
		s.pdf = 0.0;
		s.type = LOBE_NONE;
		s.valid = false;
		return s;
	}

	static LobeSample Make(float3 wi, DiffuseSpecular weight, float pdf, uint type)
	{
		LobeSample s;
		s.wi = wi;
		s.weight = weight;
		s.pdf = pdf;
		s.type = type;
		s.valid = true;
		return s;
	}
};

// wo (view) and wi (light) point away from the surface and are in the space of the lobe normals.
// Eval returns f * |cos(wi)|.
interface ILobe
{
	uint LobeType();
	DiffuseSpecular Eval(float3 wo, float3 wi);
	float Pdf(float3 wo, float3 wi);
	LobeSample Sample(float3 u, float3 wo);
	// Rough throughput-weighted albedo, used for lobe selection.
	float EstimateContribution(float3 wo, float3 throughput);
}

static const int SAMPLED_NONE = 0;
static const int SAMPLED_BASE = 1; // a base lobe, by index
static const int SAMPLED_COAT = 2; // the coat reflection

// The lobe a sample came from, with the value and pdf it computed for its own direction. EvalPdf
// uses them for that lobe instead of evaluating it again, like Cycles' skip_sc: a near-specular
// lobe re-evaluated at its own grazing sample can lose its pdf to half-vector rounding but not its
// value. The sheen is always evaluated (its sampler takes Eval and Pdf as they are).
struct SampledLobe
{
	int layer;
	int lobe;
	DiffuseSpecular f; // f * |cos|
	float pdf;

	static SampledLobe None()
	{
		SampledLobe s;
		s.layer = SAMPLED_NONE;
		s.lobe = -1;
		s.f = DiffuseSpecular.Zero();
		s.pdf = 0.0;
		return s;
	}

	static SampledLobe Make(int layer, int lobe, LobeSample sample)
	{
		SampledLobe s;
		s.layer = layer;
		s.lobe = lobe;
		s.f = sample.weight * sample.pdf;
		s.pdf = sample.pdf;
		return s;
	}
};

// A layer of the stack. SampleLobe picks a lobe and its direction; EvalPdf evaluates f * |cos| and
// the pdf over all of the layer's lobes in one pass. Sample, Eval and Pdf are built on these, so
// every lobe is instantiated once per call site of EvalPdf (the inlined size sets compile time).
interface ILayer : ILobe
{
	bool SampleLobe(float3 u, float3 wo, out float3 wi, out uint type, out SampledLobe sampled);
	void EvalPdf(float3 wo, float3 wi, SampledLobe sampled, out DiffuseSpecular f, out float pdf);
}

// Sample, Eval and Pdf of a layer from SampleLobe and EvalPdf.
LobeSample SampleLayer<L : ILayer>(L layer, float3 u, float3 wo)
{
	float3 wi;
	uint type;
	SampledLobe sampled;
	if (!layer.SampleLobe(u, wo, wi, type, sampled))
	{
		return LobeSample.Invalid();
	}
	DiffuseSpecular f;
	float pdf;
	layer.EvalPdf(wo, wi, sampled, f, pdf);
	if (!(pdf > 0.0))
	{
		return LobeSample.Invalid();
	}
	return LobeSample.Make(wi, f * (1.0 / pdf), pdf, type);
}

DiffuseSpecular EvalLayer<L : ILayer>(L layer, float3 wo, float3 wi)
{
	DiffuseSpecular f;
	float pdf;
	layer.EvalPdf(wo, wi, SampledLobe.None(), f, pdf);
	return f;
}

float PdfLayer<L : ILayer>(L layer, float3 wo, float3 wi)
{
	DiffuseSpecular f;
	float pdf;
	layer.EvalPdf(wo, wi, SampledLobe.None(), f, pdf);
	return pdf;
}

interface IFlippableLobe : ILobe
{
	float3 GetNormal();
}

// The lobes build their local frames with Duff et al.'s basis, taking the second vector as the
// tangent (left-handed, unlike Frame.FromNormal).
Frame BasisFromNormal(float3 n)
{
	float s = n.z < 0.0 ? -1.0 : 1.0;
	float a = -1.0 / (s + n.z);
	float b = n.x * n.y * a;
	Frame f;
	f.n = n;
	f.t = float3(b, s + n.y * n.y * a, -n.y);
	f.b = float3(1.0 + s * n.x * n.x * a, s * b, -s * n.x);
	return f;
}

Frame BasisFromTangent(float3 n, float3 tangent, float handedness)
{
	Frame f;
	f.n = n;
	f.t = normalize(tangent - dot(tangent, n) * n);
	f.b = cross(n, f.t) * handedness;
	return f;
}

extension Frame
{
	Frame Inverted()
	{
		Frame f;
		f.t = -t;
		f.b = -b;
		f.n = -n;
		return f;
	}

	float Handedness()
	{
		return dot(cross(t, b), n) >= 0.0 ? 1.0 : -1.0;
	}

	// Counterclockwise around the normal; cosSin does not need to be unit length, (0, 0) is no rotation.
	Frame RotatedAroundNormal(float2 cosSin)
	{
		if (all(cosSin == float2(0.0)))
		{
			return this;
		}
		float2 cs = normalize(cosSin);
		float h = Handedness();
		Frame f;
		f.n = n;
		f.t = t * cs.x + h * b * cs.y;
		f.b = b * cs.x - h * t * cs.y;
		return f;
	}
}

float3 Square(float3 v)
{
	return v * v;
}

float FourthPower(float x)
{
	float xx = x * x;
	return xx * xx;
}

float FifthPower(float x)
{
	float xx = x * x;
	return xx * xx * x;
}

float SixthPower(float x)
{
	float xx = x * x;
	return xx * xx * xx;
}

float FourthRoot(float x)
{
	return sqrt(sqrt(x));
}

// min3() requires capabilities WGSL does not have.
float MinComponent(float3 v)
{
	return min(min(v.x, v.y), v.z);
}

float Sum(float3 v)
{
	return v.x + v.y + v.z;
}

float Average(float3 v)
{
	return Sum(v) * (1.0 / 3.0);
}

float SignNonZero(float x)
{
	return x >= 0.0 ? 1.0 : -1.0;
}

float SafeDivide(float numerator, float denominator, float fallback)
{
	return denominator != 0.0 ? numerator / denominator : fallback;
}

float SafePow(float a, float b)
{
	return a > 0.0 ? pow(a, b) : 0.0;
}

float3 SafePow(float3 a, float3 b)
{
	return float3(SafePow(a.x, b.x), SafePow(a.y, b.y), SafePow(a.z, b.z));
}

// Remapped random numbers can round up to one.
float ClampRemappedRandom(float u)
{
	return min(u, ONE_MINUS_EPSILON);
}

float ThroughputWeightedMax(float3 throughput, float3 color)
{
	return MaxComponent(throughput * color);
}
