// Evaluate opaque shadow sources in parallel within one workgroup,
// keeping source order for the final sum and preserving the existing queue layout.
import Passes.Wavefront;
import Passes.PathTracing;
import RayTracing.Traversal;
import Scene.SceneTypes;
import Common.Math;

groupshared float3 gContributions[192];
groupshared float4 gNrdDiffuse[192]; // primary NRD diffuse part, w = NRD vertex
groupshared float3 gNrdBypass[192];
groupshared float3 gNrdDiffuseDirection[192]; // luminance-weighted light directions
groupshared float3 gNrdSpecularDirection[192];

void ShadowParallelImpl<let DIRECT : bool, let SKY : bool>(uint3 tid, uint3 local)
{
	uint count = DIRECT ? gWavefront.pathCount : asuint(gAccum[HeaderBase()].y);
	uint index = 0u, base = 0u, mask = 0u, flags = 0u;
	float3 lightDirection = float3(0.0);
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
			flags = asuint(direction.w);
			lightDirection = direction.xyz;
			if ((flags & 1u) == 0u || !TraceOcclusion<false>(Ray(origin.xyz, direction.xyz, origin.w)))
				value = gAccum[Field(base, offset + 2u)].xyz;
		}
	}
	gContributions[local.y * 64u + local.x] = value;
	float3 laneDiffuse = float3(0.0), laneSpecular, laneBypass = float3(0.0);
	if ((flags & 2u) != 0u) NrdSplitDirect(flags, value, laneDiffuse, laneSpecular, laneBypass);
	gNrdDiffuse[local.y * 64u + local.x] = float4(laneDiffuse, float((flags & 2u) != 0u));
	gNrdBypass[local.y * 64u + local.x] = laneBypass;
	gNrdDiffuseDirection[local.y * 64u + local.x] = Luminance(laneDiffuse) * lightDirection;
	gNrdSpecularDirection[local.y * 64u + local.x] = (flags & 2u) != 0u ? Luminance(laneSpecular) * lightDirection : float3(0.0);
	GroupMemoryBarrierWithGroupSync();
	if (source == 0u && tid.x < count && mask != 0u)
	{
		float3 sum = gContributions[local.x] + gContributions[64u + local.x];
		if (!SKY) sum += gContributions[128u + local.x];
		float4 throughput = gAccum[Field(base, 10u)];
		float4 diffuse = gNrdDiffuse[local.x] + gNrdDiffuse[64u + local.x];
		float3 bypass = gNrdBypass[local.x] + gNrdBypass[64u + local.x];
		float3 diffuseDirection = gNrdDiffuseDirection[local.x] + gNrdDiffuseDirection[64u + local.x];
		float3 specularDirection = gNrdSpecularDirection[local.x] + gNrdSpecularDirection[64u + local.x];
		if (!SKY)
		{
			diffuse += gNrdDiffuse[128u + local.x]; bypass += gNrdBypass[128u + local.x];
			diffuseDirection += gNrdDiffuseDirection[128u + local.x]; specularDirection += gNrdSpecularDirection[128u + local.x];
		}
		if (diffuse.w > 0.0)
		{
			// Only primary vertices carry the flag, on all their sources; their direct light is unclamped.
			uint r = NrdBase(base);
			gAccum[r].xyz += throughput.xyz * bypass;
			gAccum[r + 1u].xyz += throughput.xyz * diffuse.xyz;
			gAccum[r + 2u].xyz += throughput.xyz * (sum - diffuse.xyz - bypass);
			gAccum[r + 3u].xyz += Luminance(throughput.xyz) * diffuseDirection;
			gAccum[r + 4u].xyz += Luminance(throughput.xyz) * specularDirection;
		}
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
