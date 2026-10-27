// The same accumulation/work allocation is viewed as uint words only in this kernel.
// Slang lowers the word array to atomic<u32>; other passes use ordinary float4 access.
// This permits queue counters without adding a ninth storage binding. Each workgroup
// reserves one contiguous range per queue, limiting global atomic contention.
import Scene.SceneTypes;
import Scene.SceneBindings;

#ifndef VEACH_SUBGROUP_COMPACTION
#define VEACH_SUBGROUP_COMPACTION 0
#endif
#ifndef VEACH_DENSE_COMPACTION
#define VEACH_DENSE_COMPACTION 0
#endif

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
groupshared uint gInputCount;
#if VEACH_SUBGROUP_COMPACTION
groupshared Atomic<uint> gGroupCount[2];
#endif

uint2 ReserveQueues<let AFTER_SHADE : bool>(uint header, uint2 count)
{
	uint2 offset = uint2(0u);
	if (count.x > 0u)
	{
		offset.x = gWork[header + (AFTER_SHADE ? 0u : 2u)].add(count.x);
		gWork[header + 4u].max((offset.x + count.x + 63u) / 64u);
	}
	if (count.y > 0u)
	{
		offset.y = gWork[header + 1u].add(count.y);
		gWork[header + 8u].max((offset.y + count.y + 63u) / 64u);
	}
	return offset;
}

void CompactImpl<let AFTER_SHADE : bool>(uint3 tid, uint3 local)
{
	uint lane = local.x;
	uint header = gFrame.frame.x * gFrame.frame.y * 12u;
#if VEACH_DENSE_COMPACTION
	uint count = gWavefront.pathCount;
#else
	// Reading one atomic location from every lane can serialize the whole dispatch.
	// The count is immutable in this pass; broadcast a single load per workgroup.
	if (lane == 0u)
	{
		gInputCount = gWork[header + (AFTER_SHADE ? 2u : 0u)].load();
#if VEACH_SUBGROUP_COMPACTION
		gGroupCount[0].store(0u);
		gGroupCount[1].store(0u);
#endif
	}
	GroupMemoryBarrierWithGroupSync();
	uint count = gInputCount;
#endif
	uint queue = header + 12u + gWavefront.capacity * 84u;
	uint queueStride = ((gWavefront.capacity + 3u) / 4u) * 4u;
	uint inputQueue = queue + (AFTER_SHADE ? queueStride : 0u);
	uint outputQueue = queue + (AFTER_SHADE ? 0u : queueStride);
	uint index = 0u;
	uint2 flags = uint2(0u);
	if (tid.x < count)
	{
#if VEACH_DENSE_COMPACTION
		index = tid.x;
#else
		index = gWork[inputQueue + tid.x].load();
#endif
		uint base = header + 12u + index * 4u;
		flags.x = uint(gWork[base + 3u].load() != 0u);
		if (AFTER_SHADE) flags.y = uint(gWork[base + 44u * gWavefront.capacity + 2u].load() != 0u);
	}
#if VEACH_SUBGROUP_COMPACTION
	// Combine subgroup totals in shared memory so global reservations remain one per
	// workgroup. No assumption about subgroup size or local invocation mapping is needed.
	uint2 prefix = WavePrefixSum(flags);
	uint2 total = WaveActiveSum(flags);
	uint2 waveOffset = uint2(0u);
	if (WaveIsFirstLane())
	{
		waveOffset.x = gGroupCount[0].add(total.x);
		waveOffset.y = gGroupCount[1].add(total.y);
	}
	waveOffset = WaveReadLaneFirst(waveOffset);
	GroupMemoryBarrierWithGroupSync();
	if (lane == 0u) gOffsets = ReserveQueues<AFTER_SHADE>(header, uint2(gGroupCount[0].load(), gGroupCount[1].load()));
	GroupMemoryBarrierWithGroupSync();
	uint2 offsets = gOffsets + waveOffset;
#else
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
		gOffsets = ReserveQueues<AFTER_SHADE>(header, gPrefix[63u]);
	}
	GroupMemoryBarrierWithGroupSync();
	uint2 offsets = gOffsets;
	uint2 prefix = gPrefix[lane] - flags;
#endif
	prefix += offsets;
	if (flags.x != 0u) gWork[outputQueue + prefix.x].store(index);
	if (flags.y != 0u) gWork[queue + 2u * queueStride + prefix.y].store(index);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void CompactIntersect(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactImpl<false>(tid, local); }

[shader("compute")]
[numthreads(64, 1, 1)]
void CompactShade(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactImpl<true>(tid, local); }
