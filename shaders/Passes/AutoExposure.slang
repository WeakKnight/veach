// Histogram auto exposure (ported from Unreal's PostProcessHistogram.usf and
// PostProcessEyeAdaptation.usf, AEM_Histogram). The histogram reads the pre-exposed accumulation and
// undoes the pre-exposure; EyeAdaptation trims outliers, adapts towards the target over time and
// writes gExposure[0] = (exposure scale, target scale, average luminance, compensation), which the
// present pass applies directly and the host reads back as the next pre-exposure.
import Scene.SceneTypes;

static const uint HISTOGRAM_SIZE = 64;
// Fixed-point bucket weight (u32 atomics): 2^7 per pixel keeps 33M pixels below overflow.
static const float HISTOGRAM_WEIGHT_SCALE = 128.0;

struct EyeAdaptationParams
{
	float4 histogram;  // scale, bias (log2 luminance -> [0, 1]), low percent, high percent (0..1)
	float4 luminance;  // min average luminance, max average luminance, exposure compensation, unused
	float4 adaptation; // speed up, speed down (EV per second), exponential up M, exponential down M
	float4 timing;	   // delta time (s), start distance (EV), force target (0 or 1), unused
	float4 luminanceWeights; // r.AutoExposure.LuminanceMethod weights, shared with local exposure; w unused
};

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] StructuredBuffer<float4> gAccum;
[[vk::binding(2, 0)]] ConstantBuffer<EyeAdaptationParams> gParams;
[[vk::binding(3, 0)]] RWStructuredBuffer<Atomic<uint>> gHistogram;
[[vk::binding(4, 0)]] RWStructuredBuffer<float4> gExposure;

groupshared Atomic<uint> gsHistogram[HISTOGRAM_SIZE];

float ComputeHistogramPositionFromLuminance(float luminance)
{
	return log2(luminance) * gParams.histogram.x + gParams.histogram.y;
}

float ComputeLogLuminanceFromHistogramPosition(float position)
{
	return (position - gParams.histogram.y) / gParams.histogram.x;
}

[shader("compute")]
[numthreads(16, 16, 1)]
void Histogram(uint3 tid: SV_DispatchThreadID, uint groupIndex: SV_GroupIndex)
{
	if (groupIndex < HISTOGRAM_SIZE)
	{
		gsHistogram[groupIndex].store(0u);
	}
	GroupMemoryBarrierWithGroupSync();

	if (tid.x < gFrame.frame.x && tid.y < gFrame.frame.y)
	{
		float3 color = gAccum[(tid.y * gFrame.frame.x + tid.x) * 3u].rgb * rcp(gFrame.envParams.z);
		float position = ComputeHistogramPositionFromLuminance(max(dot(color, gParams.luminanceWeights.xyz), 1e-20));
		float bucket = saturate(position) * float(HISTOGRAM_SIZE - 1u);
		uint bucket0 = uint(bucket);
		uint bucket1 = min(bucket0 + 1u, HISTOGRAM_SIZE - 1u);
		float weight1 = frac(bucket);
		// black pixels (bucket 0) do not count, as with Unreal's default BlackHistogramBucketInfluence
		float weight0 = bucket0 == 0u ? 0.0 : 1.0 - weight1;
		gsHistogram[bucket0].add(uint(weight0 * HISTOGRAM_WEIGHT_SCALE + 0.5));
		gsHistogram[bucket1].add(uint(weight1 * HISTOGRAM_WEIGHT_SCALE + 0.5));
	}
	GroupMemoryBarrierWithGroupSync();

	if (groupIndex < HISTOGRAM_SIZE)
	{
		uint count = gsHistogram[groupIndex].load();
		if (count != 0u)
		{
			gHistogram[groupIndex].add(count);
		}
	}
}

float ComputeAverageLuminanceWithoutOutlier(float minFractionSum, float maxFractionSum)
{
	if (abs(gParams.histogram.z - gParams.histogram.w) < 0.0001)
	{
		return 1.0;
	}
	float2 sumWithoutOutliers = float2(0.0);
	for (uint i = 0u; i < HISTOGRAM_SIZE; i++)
	{
		float value = float(gHistogram[i].load());
		// remove outliers at the lower end
		float sub = min(value, minFractionSum);
		value -= sub;
		minFractionSum -= sub;
		maxFractionSum -= sub;
		// and at the upper end
		value = min(value, maxFractionSum);
		maxFractionSum -= value;

		float logLuminance = ComputeLogLuminanceFromHistogramPosition(float(i) / float(HISTOGRAM_SIZE - 1u));
		sumWithoutOutliers += float2(logLuminance, 1.0) * value;
	}
	if (sumWithoutOutliers.y == 0.0)
	{
		return gParams.luminance.x / 0.18;
	}
	return exp2(sumWithoutOutliers.x / sumWithoutOutliers.y);
}

float ExponentialAdaption(float current, float target, float frameTime, float speed, float m)
{
	float factor = 1.0 - exp2(-frameTime * speed);
	return current + (target - current) * factor * m;
}

float LinearAdaption(float current, float target, float frameTime, float speed)
{
	float offset = frameTime * speed;
	return current < target ? min(target, current + offset) : max(target, current - offset);
}

// Exposure here is the white point luminance; adapts in log space, linearly while far from the
// target and exponentially within the start distance (M matches the slopes at the switch).
float ComputeEyeAdaptation(float oldExposure, float targetExposure, float frameTime)
{
	float logTarget = log2(targetExposure);
	float logOld = log2(oldExposure);
	float logDiff = logTarget - logOld;
	float speed = logDiff > 0.0 ? gParams.adaptation.x : gParams.adaptation.y;
	float m = logDiff > 0.0 ? gParams.adaptation.z : gParams.adaptation.w;
	float exponential = ExponentialAdaption(logOld, logTarget, frameTime, speed, m);
	float linear = LinearAdaption(logOld, logTarget, frameTime, speed);
	float adapted = exp2(abs(logDiff) > gParams.timing.y ? linear : exponential);
	// manual mode and camera cuts jump to the target
	return lerp(adapted, targetExposure, gParams.timing.z);
}

[shader("compute")]
[numthreads(1, 1, 1)]
void EyeAdaptation()
{
	float minAverageLuminance = gParams.luminance.x;
	float maxAverageLuminance = gParams.luminance.y;
	float compensation = gParams.luminance.z;

	float histogramSum = 0.0;
	for (uint i = 0u; i < HISTOGRAM_SIZE; i++)
	{
		histogramSum += float(gHistogram[i].load());
	}
	float averageLuminance = ComputeAverageLuminanceWithoutOutlier(histogramSum * gParams.histogram.z, histogramSum * gParams.histogram.w);

	float targetExposure = clamp(averageLuminance, minAverageLuminance, maxAverageLuminance) / 0.18;
	float oldExposureScale = gExposure[0].x;
	float oldExposure = compensation / (oldExposureScale > 0.0 && isfinite(oldExposureScale) ? oldExposureScale : 1.0);
	float exposure = ComputeEyeAdaptation(oldExposure, targetExposure, gParams.timing.x);
	exposure = clamp(exposure, minAverageLuminance / 0.18, maxAverageLuminance / 0.18);

	gExposure[0] = float4(compensation / max(0.0001, exposure), compensation / max(0.0001, targetExposure), averageLuminance, compensation);
	gExposure[1] = float4(1.0, 0.0, 0.0, 0.0);
}
