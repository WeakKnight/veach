// Fullscreen resolve of the accumulation buffer: exposure, tone mapping, display encoding
// (ported from Legacy/Source/XPU/Private/PostProcessing.cpp).
import Common.Math;
import Scene.SceneTypes;
import LocalExposureCommon;

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] StructuredBuffer<float4> gAccum;
// ACES 2.0 output transform baked by src/render/aces/ToneLUT.ts; holds display code values.
[[vk::binding(2, 0)]] Texture3D<float4> gToneLUT;
[[vk::binding(3, 0)]] SamplerState gToneLUTSampler;
// Written by AutoExposure.slang; [0].x is the exposure scale for scene-linear radiance.
[[vk::binding(4, 0)]] StructuredBuffer<float4> gExposure;
// Fusion local exposure (LocalExposure.slang): quarter-resolution residual reconstruction and
// pyramid mip 0, and the bracket / inverse lightness tables.
[[vk::binding(5, 0)]] ConstantBuffer<LocalExposureParams> gLocalExposure;
[[vk::binding(6, 0)]] Texture2D<float> gLocalExposureResidual;
[[vk::binding(7, 0)]] Texture2D<float4> gLocalExposurePyramid;
[[vk::binding(8, 0)]] Texture2D<float4> gLocalExposureForwardLut;
[[vk::binding(9, 0)]] Texture2D<float> gLocalExposureInverseLut;

// User LUTs are sampled manually in float32, matching the light-lab trilinear reference.
[[vk::binding(10, 0)]] Texture3D<float4> gUserLUT;
struct DisplayTransformParams
{
	float4 info; // enabled, input primaries (0=709,1=2020), input transfer, output primaries
	float4 encoding; // input gamma, output transfer, output gamma, reserved
	float4 domainMin;
	float4 domainMax;
};
[[vk::binding(11, 0)]] ConstantBuffer<DisplayTransformParams> gDisplayTransform;

float3 DisplayTo2020(float3 c)
{
	return float3(dot(c, float3(0.62740390, 0.32928304, 0.04331307)),
		dot(c, float3(0.06909729, 0.91954040, 0.01136232)), dot(c, float3(0.01639144, 0.08801331, 0.89559525)));
}
float3 DisplayTo709(float3 c)
{
	return float3(dot(c, float3(1.66049100, -0.58764114, -0.07284986)),
		dot(c, float3(-0.12455047, 1.13289990, -0.00834942)), dot(c, float3(-0.01815076, -0.10057890, 1.11872966)));
}
float EncodeDisplayInput(float x, uint transfer, float gamma)
{
	if (transfer == 1u) return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(max(x, 0.0), 1.0 / 2.4) - 0.055;
	if (transfer == 2u) return x < 0.000889 ? 8.799461 * x + 0.092864 : 0.245281 * log10(max(5.555556 * x + 0.064829, 1e-7)) + 0.384316;
	if (transfer == 3u) return pow(max(x, 0.0), rcp(gamma));
	return x;
}
float DecodeDisplayOutput(float x, uint transfer, float gamma)
{
	if (transfer == 1u) return x <= 0.04045 ? x / 12.92 : pow(max((x + 0.055) / 1.055, 0.0), 2.4);
	if (transfer == 3u) return pow(max(x, 0.0), gamma);
	return x;
}
float3 ApplyUserDisplayTransform(float3 color)
{
	if (gDisplayTransform.info.y != 0.0) color = DisplayTo2020(color);
	uint transfer = uint(gDisplayTransform.info.z);
	float gamma = gDisplayTransform.encoding.x;
	float3 encoded = float3(EncodeDisplayInput(color.x, transfer, gamma), EncodeDisplayInput(color.y, transfer, gamma), EncodeDisplayInput(color.z, transfer, gamma));
	uint w, h, d;
	gUserLUT.GetDimensions(w, h, d);
	float3 p = saturate((encoded - gDisplayTransform.domainMin.xyz) / (gDisplayTransform.domainMax.xyz - gDisplayTransform.domainMin.xyz)) * float(w - 1u);
	int3 a = min(int3(floor(p)), int3(int(w) - 2));
	float3 f = p - float3(a);
	float3 c00 = lerp(gUserLUT.Load(int4(a, 0)).rgb, gUserLUT.Load(int4(a + int3(1, 0, 0), 0)).rgb, f.x);
	float3 c10 = lerp(gUserLUT.Load(int4(a + int3(0, 1, 0), 0)).rgb, gUserLUT.Load(int4(a + int3(1, 1, 0), 0)).rgb, f.x);
	float3 c01 = lerp(gUserLUT.Load(int4(a + int3(0, 0, 1), 0)).rgb, gUserLUT.Load(int4(a + int3(1, 0, 1), 0)).rgb, f.x);
	float3 c11 = lerp(gUserLUT.Load(int4(a + int3(0, 1, 1), 0)).rgb, gUserLUT.Load(int4(a + int3(1, 1, 1), 0)).rgb, f.x);
	float3 result = lerp(lerp(c00, c10, f.y), lerp(c01, c11, f.y), f.z);
	transfer = uint(gDisplayTransform.encoding.y);
	gamma = gDisplayTransform.encoding.z;
	result = float3(DecodeDisplayOutput(result.x, transfer, gamma), DecodeDisplayOutput(result.y, transfer, gamma), DecodeDisplayOutput(result.z, transfer, gamma));
	return gDisplayTransform.info.w != 0.0 ? DisplayTo709(result) : result;
}

// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
float3 ACESFilmic(float3 color)
{
	color *= 0.6;
	const float A = 2.51;
	const float B = 0.03;
	const float C = 2.43;
	const float D = 0.59;
	const float E = 0.14;
	return saturate((color * (A * color + B)) / (color * (C * color + D) + E));
}

// SMPTE ST.2084 inverse EOTF, nits in [0, 10000].
float3 LinearToST2084(float3 nits)
{
	const float m1 = 0.1593017578125;
	const float m2 = 78.84375;
	const float c1 = 0.8359375;
	const float c2 = 18.8515625;
	const float c3 = 18.6875;
	float3 Lm = pow(nits / 10000.0, float3(m1));
	return pow((c1 + c2 * Lm) / (1.0 + c3 * Lm), float3(m2));
}

// Same shaper as Unreal's PostProcessCombineLUTs: PQ of scene-linear scaled to nits
// (1.0 = 100 nits), then a half-texel remap so 0 and 1 land on the outer texel centers.
float3 ACES2(float3 linearColor)
{
	float3 encoded = LinearToST2084(clamp(linearColor * 100.0, 0.0, 10000.0));
	uint3 size;
	gToneLUT.GetDimensions(size.x, size.y, size.z);
	float n = float(size.x);
	float3 uvw = encoded * ((n - 1.0) / n) + 0.5 / n;
	return gToneLUT.SampleLevel(gToneLUTSampler, uvw, 0.0).rgb;
}

struct VSOutput
{
	float4 position : SV_Position;
};

[shader("vertex")]
VSOutput vsMain(uint vertexId: SV_VertexID)
{
	float2 uv = float2(float((vertexId << 1u) & 2u), float(vertexId & 2u));
	VSOutput o;
	o.position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
	return o;
}

[shader("fragment")]
float4 fsMain(VSOutput input) : SV_Target
{
	uint2 pixel = min(uint2(input.position.xy), gFrame.frame.xy - 1u);
	float3 color = gAccum[(pixel.y * gFrame.frame.x + pixel.x) * 3u].rgb;
	if (gFrame.temporal.z != 0.0 && gFrame.temporal.w != 0.0) return float4(color, 1.0);
	if (gFrame.settings.y == DEBUG_NONE)
	{
		// the accumulation holds radiance * pre-exposure
		color *= gExposure[0].x * rcp(gFrame.envParams.z);
		// as in Unreal's tonemapper (LOCAL_EXPOSURE_MODE_FUSION): luminance after global exposure
		if (gLocalExposure.info.x != 0u && gDisplayTransform.info.x == 0.0)
		{
			float2 uv = (float2(pixel) + 0.5) / float2(gFrame.frame.xy);
			float localExposure = FusionLocalExposure(gLocalExposure, gLocalExposureForwardLut, gLocalExposureInverseLut,
				EyeAdaptationLuminance(gLocalExposure, color), SampleBilinear(gLocalExposureResidual, uv), SampleBilinear(gLocalExposurePyramid, uv).xy);
			if (gLocalExposure.info.y != 0u)
			{
				// black -6 EV, grey 0 EV, white +6 EV
				return float4(float3(saturate(log2(localExposure) / 12.0 + 0.5)), 1.0);
			}
			color *= localExposure;
		}
		if (gDisplayTransform.info.x != 0.0)
		{
			return float4(LinearToSrgb(saturate(ApplyUserDisplayTransform(color))), 1.0);
		}
		if (gFrame.settings.w == TONEMAP_ACES2)
		{
			return float4(saturate(ACES2(color)), 1.0);
		}
		if (gFrame.settings.w == TONEMAP_ACES_FILMIC)
		{
			color = ACESFilmic(color);
		}
	}
	return float4(LinearToSrgb(saturate(color)), 1.0);
}
