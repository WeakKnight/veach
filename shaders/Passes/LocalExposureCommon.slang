// Shared by the Fusion local exposure stages (LocalExposure.slang) and Present.slang: parameters,
// float LUT lookups and the full-resolution exposure recovery of the fine-residual graph.
module LocalExposureCommon;

public static const uint INVERSE_LUT_SIZE = 1024;
public static const uint FORWARD_LUT_SIZE = 2048;
public static const float FORWARD_LOG_MIN = -40.0;
public static const float FORWARD_LOG_MAX = 40.0;

public struct LocalExposureParams
{
	public float4 curve;			// Z max input, Z max lightness, inverse warp epsilon, inverse warp span
	public float4 luminanceWeights; // eye adaptation luminance weights, w = luminance min (2^histogram min EV)
	public uint4 info;				// enabled, visualize, unused, unused
};

// Linear interpolation over a width x 1 float table (rgba32float / r32float are not filterable).
public float4 SampleTable(Texture2D<float4> table, uint size, float position)
{
	float x = clamp(position, 0.0, float(size - 1u));
	uint i = min(uint(x), size - 2u);
	return lerp(table.Load(int3(int(i), 0, 0)), table.Load(int3(int(i) + 1, 0, 0)), x - float(i));
}

public float SampleTable(Texture2D<float> table, uint size, float position)
{
	float x = clamp(position, 0.0, float(size - 1u));
	uint i = min(uint(x), size - 2u);
	return lerp(table.Load(int3(int(i), 0, 0)), table.Load(int3(int(i) + 1, 0, 0)), x - float(i));
}

// Hardware-equivalent bilinear filtering with clamp-to-edge, in full float precision.
public float4 SampleBilinear(Texture2D<float4> t, float2 uv)
{
	uint2 size;
	t.GetDimensions(size.x, size.y);
	float2 pos = uv * float2(size) - 0.5;
	int2 base = int2(floor(pos));
	float2 f = pos - float2(base);
	int2 hi = int2(size) - 1;
	int2 p0 = clamp(base, int2(0), hi);
	int2 p1 = clamp(base + 1, int2(0), hi);
	float4 a = lerp(t.Load(int3(p0.x, p0.y, 0)), t.Load(int3(p1.x, p0.y, 0)), f.x);
	float4 b = lerp(t.Load(int3(p0.x, p1.y, 0)), t.Load(int3(p1.x, p1.y, 0)), f.x);
	return lerp(a, b, f.y);
}

public float SampleBilinear(Texture2D<float> t, float2 uv)
{
	uint2 size;
	t.GetDimensions(size.x, size.y);
	float2 pos = uv * float2(size) - 0.5;
	int2 base = int2(floor(pos));
	float2 f = pos - float2(base);
	int2 hi = int2(size) - 1;
	int2 p0 = clamp(base, int2(0), hi);
	int2 p1 = clamp(base + 1, int2(0), hi);
	float a = lerp(t.Load(int3(p0.x, p0.y, 0)), t.Load(int3(p1.x, p0.y, 0)), f.x);
	float b = lerp(t.Load(int3(p0.x, p1.y, 0)), t.Load(int3(p1.x, p1.y, 0)), f.x);
	return lerp(a, b, f.y);
}

// Unreal's CalculateEyeAdaptationLuminance: the auto exposure luminance weights, clamped at the
// histogram minimum, so local exposure meters the same luminance as eye adaptation.
public float EyeAdaptationLuminance(LocalExposureParams p, float3 color)
{
	return max(dot(color, p.luminanceWeights.xyz), p.luminanceWeights.w);
}

// Position of an exposed luminance in the forward tables.
public float ForwardTablePosition(float luminance)
{
	float logL = log2(max(luminance, exp2(FORWARD_LOG_MIN)));
	return saturate((logL - FORWARD_LOG_MIN) / (FORWARD_LOG_MAX - FORWARD_LOG_MIN)) * float(FORWARD_LUT_SIZE - 1u);
}

// Inverse of the fitted lightness response; the LUT stores log2 luminance at logit-spaced lightness.
public float InverseFusionLightness(LocalExposureParams p, Texture2D<float> inverseLut, float lightness)
{
	float maxInput = p.curve.x;
	float maxLightness = p.curve.y;
	float t = saturate(lightness / maxLightness);
	float u = 0.5 + log2((t + p.curve.z) / (1.0 - t + p.curve.z)) / (2.0 * p.curve.w);
	float value = min(exp2(SampleTable(inverseLut, INVERSE_LUT_SIZE, saturate(u) * float(INVERSE_LUT_SIZE - 1u))), maxInput);
	return lightness <= 0.0 ? 0.0 : (lightness >= maxLightness ? maxInput : value);
}

// Full-resolution exposure recovery (fine_residual/apply.slang): restore the fine residual from the
// full-resolution weights, then invert the target lightness. luminance is the exposed luminance;
// residual and lowResidual are the quarter-resolution reconstruction and pyramid mip 0 at this pixel.
public float FusionLocalExposure(LocalExposureParams p, Texture2D<float4> forwardLut, Texture2D<float> inverseLut, float luminance, float residual, float2 lowResidual)
{
	float4 f = SampleTable(forwardLut, FORWARD_LUT_SIZE, ForwardTablePosition(luminance));
	float target = clamp(f.x + residual - dot(lowResidual, f.yz), 0.0, p.curve.y);
	return clamp(InverseFusionLightness(p, inverseLut, target) / max(luminance, 1e-12), exp2(-12.0), exp2(12.0));
}
