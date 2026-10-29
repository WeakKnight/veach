// Independent WebGPU adaptation of Remix's PQ-space temporal blend and variance clipping.
import Scene.SceneTypes;

struct TemporalParams
{
	float4 previousPosition;
	float4 previousInverse[3]; // Inverse of [right up forward], rows; supports off-axis cameras.
	float4 jitter; // previous jitter xy, pixel footprint scale, unused
	float4 control; // new frame weight, sigma multiplier, maximum radiance, history valid
	uint4 counts; // current/previous instance slot bound, unused
};
[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] ConstantBuffer<TemporalParams> gTemporal;
[[vk::binding(2, 0)]] StructuredBuffer<float4> gCurrent;
[[vk::binding(3, 0)]] StructuredBuffer<float4> gHistory;
[[vk::binding(4, 0)]] StructuredBuffer<Instance> gInstances;
[[vk::binding(5, 0)]] StructuredBuffer<Instance> gPreviousInstances;
[[vk::binding(6, 0)]] RWStructuredBuffer<float4> gNextHistory;
[[vk::binding(7, 0)]] RWStructuredBuffer<float4> gOutput;
// Two float4s/pixel: motion.xy in pixels, reserved, valid; previous world position/direction.
[[vk::binding(8, 0)]] RWStructuredBuffer<float4> gMotion;

float3 EncodePQ(float3 color)
{
	float3 m = pow(max(color / gTemporal.control.z, 0.0), float3(0.1593017578125));
	return saturate(pow((0.8359375 + 18.8515625 * m) / (1.0 + 18.6875 * m), float3(78.84375)));
}
float3 DecodePQ(float3 color)
{
	float3 m = pow(saturate(color), float3(1.0 / 78.84375));
	return pow(max(m - 0.8359375, 0.0) / max(18.8515625 - 18.6875 * m, 1e-6), float3(1.0 / 0.1593017578125)) * gTemporal.control.z;
}
float3 CurrentColor(uint base)
{
	float3 c = gCurrent[base].xyz / max(gFrame.envParams.z, 1e-8);
	return all(isfinite(c)) ? max(c, 0.0) : float3(0.0);
}
float3 AffinePoint(float4 rows[3], float3 p)
{
	return float3(dot(rows[0], float4(p, 1.0)), dot(rows[1], float4(p, 1.0)), dot(rows[2], float4(p, 1.0)));
}

[shader("compute")]
[numthreads(8, 8, 1)]
void GenerateMotion(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	uint base = (pixel.y * size.x + pixel.x) * 3u;
	float distance = gCurrent[base + 1u].w;
	uint id = uint(gCurrent[base + 2u].w);
	float2 ndc = (float2(pixel) + gFrame.temporal.xy) / float2(size) * float2(2.0, -2.0) + float2(-1.0, 1.0);
	float3 direction = normalize(gFrame.cameraForward.xyz + ndc.x * gFrame.cameraRight.xyz + ndc.y * gFrame.cameraUp.xyz);
	float3 world = id == 0u ? direction : gFrame.cameraPosition.xyz + direction * distance;
	float3 previous = world;
	bool valid = gTemporal.control.w != 0.0 && all(isfinite(world));
	if (id != 0u)
	{
		valid = valid && id <= gTemporal.counts.x && id <= gTemporal.counts.y && distance > 0.0;
		if (valid)
		{
			float3 local = AffinePoint(gInstances[id - 1u].worldToObject, world);
			previous = AffinePoint(gPreviousInstances[id - 1u].objectToWorld, local);
		}
	}
	float3 relative = id == 0u ? previous : previous - gTemporal.previousPosition.xyz;
	float3 q = float3(dot(relative, gTemporal.previousInverse[0].xyz), dot(relative, gTemporal.previousInverse[1].xyz), dot(relative, gTemporal.previousInverse[2].xyz));
	valid = valid && q.z > 1e-6 && all(isfinite(q));
	// Remix convention: previous minus current, in render pixels, excluding film jitter.
	float2 previousPixel = (q.xy / max(q.z, 1e-6) * float2(0.5, -0.5) + 0.5) * float2(size);
	float2 motion = previousPixel - (float2(pixel) + gFrame.temporal.xy);
	valid = valid && all(isfinite(motion));
	uint index = (pixel.y * size.x + pixel.x) * 2u;
	gMotion[index] = valid ? float4(motion, 0.0, 1.0) : float4(0.0);
	gMotion[index + 1u] = valid ? float4(previous, 0.0) : float4(0.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void Resolve(uint3 tid : SV_DispatchThreadID)
{
	uint2 pixel = tid.xy, size = gFrame.frame.xy;
	if (any(pixel >= size)) return;
	uint index = pixel.y * size.x + pixel.x, base = index * 3u;
	float3 current = CurrentColor(base), pq = EncodePQ(current);
	float distance = gCurrent[base + 1u].w;
	uint id = uint(gCurrent[base + 2u].w);
	float3 normal = gCurrent[base + 2u].xyz;
	float2 ndc = (float2(pixel) + gFrame.temporal.xy) / float2(size) * float2(2.0, -2.0) + float2(-1.0, 1.0);
	float3 direction = normalize(gFrame.cameraForward.xyz + ndc.x * gFrame.cameraRight.xyz + ndc.y * gFrame.cameraUp.xyz);
	float3 world = id == 0u ? direction : gFrame.cameraPosition.xyz + direction * distance;
	float4 motion = gMotion[index * 2u];
	float3 previous = gMotion[index * 2u + 1u].xyz;
	float3 relative = id == 0u ? previous : previous - gTemporal.previousPosition.xyz;
	bool valid = motion.w != 0.0;
	// History is sampled on its previous jittered grid; jitter is not part of stored motion.
	float2 source = float2(pixel) + motion.xy + gFrame.temporal.xy - gTemporal.jitter.xy;
	valid = valid && all(source >= -0.5) && all(source < float2(size) - 0.5);
	float4 history = float4(0.0);
	float weightSum = 0.0;
	if (valid)
	{
		int2 lo = int2(floor(source)); float2 f = frac(source);
		float tolerance = max(1e-4, length(relative) * gTemporal.jitter.z * 2.0);
		for (int y = 0; y < 2; y++) for (int x = 0; x < 2; x++)
		{
			int2 p = lo + int2(x, y);
			if (any(p < 0) || any(p >= int2(size))) continue;
			uint b = (uint(p.y) * size.x + uint(p.x)) * 3u;
			float4 position = gHistory[b + 1u];
			if (uint(position.w) != id || gHistory[b].w < 1.0) continue;
			if (id != 0u && (length(position.xyz - previous) > tolerance || dot(normal, gHistory[b + 2u].xyz) < 0.5)) continue;
			if (id == 0u && dot(position.xyz, previous) < 0.99) continue;
			float w = (x == 0 ? 1.0 - f.x : f.x) * (y == 0 ? 1.0 - f.y : f.y);
			history += gHistory[b] * w; weightSum += w;
		}
	}
	float age = 1.0;
	float3 result = current;
	if (weightSum > 0.05)
	{
		history /= weightSum;
		float3 mean = float3(0.0), moment = float3(0.0); float count = 0.0;
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++)
		{
			int2 p = int2(pixel) + int2(x, y);
			if (any(p < 0) || any(p >= int2(size))) continue;
			float3 c = EncodePQ(CurrentColor((uint(p.y) * size.x + uint(p.x)) * 3u));
			mean += c; moment += c * c; count += 1.0;
		}
		mean /= count;
		float3 sigma = sqrt(max(moment / count - mean * mean, 0.0)) * gTemporal.control.y;
		float3 clipped = clamp(history.xyz, mean - sigma, mean + sigma);
		// Jitter is excluded from motion responsiveness; actual camera/object movement is not.
		float weight = max(gTemporal.control.x, rcp(history.w + 1.0));
		weight = max(weight, saturate(length(motion.xy) / 32.0) * 0.5);
		pq = lerp(clipped, pq, weight);
		result = DecodePQ(pq);
		age = min(history.w + 1.0, 32.0);
	}
	gNextHistory[base] = float4(pq, age);
	gNextHistory[base + 1u] = float4(world, float(id));
	gNextHistory[base + 2u] = float4(normal, 0.0);
	gOutput[base] = float4(result * gFrame.envParams.z, 1.0);
	gOutput[base + 1u] = gCurrent[base + 1u];
	gOutput[base + 2u] = gCurrent[base + 2u];
	if (gFrame.temporal.w != 0.0)
	{
		// Neutral gray is zero; R/G encode signed x/y, +/-32 pixels reaches the limits.
		float3 debug = motion.w != 0.0 ? float3(saturate(0.5 + motion.xy / 64.0), 0.5) : float3(1.0, 0.0, 1.0);
		gOutput[base] = float4(debug, 1.0);
	}
}
