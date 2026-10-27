// The same accumulation/work allocation is viewed as uint words only in this kernel.
// Slang lowers the word array to atomic<u32>; other passes use ordinary float4 access.
// This permits queue counters without adding a ninth storage binding. Each workgroup
// reserves one contiguous range per queue, limiting global atomic contention.
import Scene.SceneTypes;
import Scene.SceneBindings;

struct WavefrontUniforms
{
	uint tileStart;
	uint pathCount;
	uint bounce;
	uint capacity;
	uint tailThreshold;
};
[[vk::binding(0, 1)]] RWStructuredBuffer<Atomic<uint>> gWork;
[[vk::binding(2, 1)]] ConstantBuffer<WavefrontUniforms> gWavefront;

groupshared uint2 gPrefix[64];
groupshared uint2 gOffsets;

[shader("compute")]
[numthreads(64, 1, 1)]
void Compact(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{
	uint index = tid.x, lane = local.x;
	uint header = gFrame.frame.x * gFrame.frame.y * 12u;
	uint base = header + 12u + index * 4u;
	uint2 flags = uint2(0u);
	if (index < gWavefront.pathCount)
	{
		flags.x = uint(gWork[base + 3u].load() != 0u);
		flags.y = uint(gWork[base + 44u * gWavefront.capacity + 2u].load() != 0u);
	}
	gPrefix[lane] = flags;
	GroupMemoryBarrierWithGroupSync();
	[unroll]
	for (uint offset = 1u; offset < 64u; offset *= 2u)
	{
		uint2 value = lane >= offset ? gPrefix[lane - offset] : uint2(0u);
		GroupMemoryBarrierWithGroupSync();
		gPrefix[lane] += value;
		GroupMemoryBarrierWithGroupSync();
	}
	if (lane == 0u)
	{
		uint2 count = gPrefix[63u];
		uint x = 0u, y = 0u;
		if (count.x > 0u)
		{
			x = gWork[header].add(count.x);
			gWork[header + 4u].max((x + count.x + 63u) / 64u);
		}
		if (count.y > 0u)
		{
			y = gWork[header + 1u].add(count.y);
			gWork[header + 8u].max((y + count.y + 63u) / 64u);
		}
		gOffsets = uint2(x, y);
	}
	GroupMemoryBarrierWithGroupSync();
	uint queue = header + 12u + gWavefront.capacity * 84u;
	uint2 prefix = gOffsets + gPrefix[lane] - flags;
	if (flags.x != 0u) gWork[queue + prefix.x].store(index);
	if (flags.y != 0u) gWork[queue + ((gWavefront.capacity + 3u) / 4u) * 4u + prefix.y].store(index);
}
