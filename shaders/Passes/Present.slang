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
	if (gFrame.settings.y == DEBUG_NONE)
	{
		// the accumulation holds radiance * pre-exposure
		color *= gExposure[0].x * rcp(gFrame.envParams.z);
		// as in Unreal's tonemapper (LOCAL_EXPOSURE_MODE_FUSION): luminance after global exposure
		if (gLocalExposure.info.x != 0u)
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
