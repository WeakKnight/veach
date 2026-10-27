// Evaluate opaque shadow sources in parallel within one workgroup,
// keeping source order for the final sum and preserving the existing queue layout.
import Passes.Wavefront;
import Passes.PathTracing;
import RayTracing.Traversal;
import Scene.SceneTypes;

groupshared float3 gContributions[192];

void ShadowParallelImpl<let DIRECT : bool, let SKY : bool>(uint3 tid, uint3 local)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].y);
	uint index = 0u, base = 0u, mask = 0u;
	uint source = SKY ? local.y * 2u : local.y;
	float3 value = float3(0.0);
	if (tid.x < count)
	{
		index = DIRECT ? tid.x : QueueIndex(ShadowQueueBase(), tid.x);
		base = WorkBase(index);
		mask = asuint(gAccum[Field(base, 11u)].z);
		if ((mask & (1u << source)) != 0u)
		{
			uint offset = 12u + source * 3u;
			float4 origin = gAccum[Field(base, offset)], direction = gAccum[Field(base, offset + 1u)];
			if (asuint(direction.w) == 0u || !TraceOcclusion<false>(Ray(origin.xyz, direction.xyz, origin.w)))
				value = gAccum[Field(base, offset + 2u)].xyz;
		}
	}
	gContributions[local.y * 64u + local.x] = value;
	GroupMemoryBarrierWithGroupSync();
	if (source == 0u && tid.x < count && mask != 0u)
	{
		float3 sum = gContributions[local.x] + gContributions[64u + local.x];
		if (!SKY) sum += gContributions[128u + local.x];
		float4 throughput = gAccum[Field(base, 10u)];
		float3 contribution = throughput.xyz * sum;
		if (throughput.w > 0.0) contribution = min(contribution, float3(throughput.w));
		float4 path = gAccum[base];
		path.xyz += contribution;
		gAccum[base] = path;
		gAccum[Field(base, 11u)] = float4(0.0);
	}
}

[shader("compute")]
[numthreads(64, 3, 1)]
void ShadowOpaqueParallel(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ ShadowParallelImpl<false, false>(tid, local); }

[shader("compute")]
[numthreads(64, 3, 1)]
void ShadowOpaqueParallelDirect(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ ShadowParallelImpl<true, false>(tid, local); }

// The host selects these only when the scene has no emissive/analytic light entries.
[shader("compute")]
[numthreads(64, 2, 1)]
void ShadowOpaqueParallelSky(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ ShadowParallelImpl<false, true>(tid, local); }

[shader("compute")]
[numthreads(64, 2, 1)]
void ShadowOpaqueParallelSkyDirect(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ ShadowParallelImpl<true, true>(tid, local); }
