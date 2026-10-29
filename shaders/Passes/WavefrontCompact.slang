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
#ifndef VEACH_ADAPTIVE_COMPACTION
#define VEACH_ADAPTIVE_COMPACTION 0
#endif
#ifndef VEACH_PACKET_COMPACTION
#define VEACH_PACKET_COMPACTION 0
#endif

struct WavefrontUniforms
{
	uint tileStart;
	uint pathCount;
	uint bounce;
	uint capacity;
	uint tailThreshold;
	uint packetStages;
	uint sortGroupSize;
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
		uint nextCount = offset.x + count.x;
		// Sorting needs the actual queue count, before adaptive scans expand their bound.
		if (gWavefront.sortGroupSize == 256u) gWork[header + 3u].max((nextCount + 255u) / 256u);
#if VEACH_ADAPTIVE_COMPACTION
		// The next compaction scans physical slots while the queue is dense. Its
		// dispatch shares the main-stage arguments; those stages guard by real count.
		// This bound grows monotonically, so workgroup reservation order is irrelevant.
		if (nextCount > gWavefront.pathCount / 2u) nextCount = gWavefront.pathCount;
#endif
		gWork[header + 4u].max((nextCount + 63u) / 64u);
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
#if VEACH_PACKET_COMPACTION
	bool packetMain = (gWavefront.packetStages & (AFTER_SHADE ? 1u : 2u)) != 0u;
	bool packetShadow = (gWavefront.packetStages & 4u) != 0u;
#endif
	uint header = gFrame.frame.x * gFrame.frame.y * 12u;
#if VEACH_DENSE_COMPACTION || VEACH_PACKET_COMPACTION
	bool dense = true;
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
#if VEACH_ADAPTIVE_COMPACTION
	bool dense = gInputCount > gWavefront.pathCount / 2u;
#else
	bool dense = false;
#endif
	uint count = dense ? gWavefront.pathCount : gInputCount;
#endif
	uint queue = header + 12u + gWavefront.capacity * 84u;
	uint queueStride = ((gWavefront.capacity + 3u) / 4u) * 4u;
	uint inputQueue = queue + (AFTER_SHADE ? queueStride : 0u);
	uint outputQueue = queue + (AFTER_SHADE ? 0u : queueStride);
	uint index = 0u;
	uint2 flags = uint2(0u);
	if (tid.x < count)
	{
		index = tid.x;
		if (!dense) index = gWork[inputQueue + tid.x].load();
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
#if VEACH_PACKET_COMPACTION
		// Keep every valid slot in a nonempty physical packet. Queue entries remain
		// ordinary path indices, so existing stage/tail guards handle inactive lanes.
		uint packetSize = min(64u, gWavefront.pathCount - (tid.x - lane));
		uint2 slots = uint2(packetMain ? (gPrefix[63u].x > 0u ? packetSize : 0u) : gPrefix[63u].x,
			packetShadow ? (gPrefix[63u].y > 0u ? packetSize : 0u) : gPrefix[63u].y);
		gOffsets = ReserveQueues<AFTER_SHADE>(header, slots);
#else
		gOffsets = ReserveQueues<AFTER_SHADE>(header, gPrefix[63u]);
#endif
	}
	GroupMemoryBarrierWithGroupSync();
	uint2 offsets = gOffsets;
	uint2 prefix = gPrefix[lane] - flags;
#endif
#if VEACH_PACKET_COMPACTION
	if (tid.x < count)
	{
		if (packetMain ? gPrefix[63u].x > 0u : flags.x != 0u)
			gWork[outputQueue + offsets.x + (packetMain ? lane : prefix.x)].store(index);
		if (packetShadow ? gPrefix[63u].y > 0u : flags.y != 0u)
			gWork[queue + 2u * queueStride + offsets.y + (packetShadow ? lane : prefix.y)].store(index);
	}
#else
	prefix += offsets;
	if (flags.x != 0u) gWork[outputQueue + prefix.x].store(index);
	if (flags.y != 0u) gWork[queue + 2u * queueStride + prefix.y].store(index);
#endif
}

[shader("compute")]
[numthreads(64, 1, 1)]
void CompactIntersect(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactImpl<false>(tid, local); }

[shader("compute")]
[numthreads(64, 1, 1)]
void CompactShade(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactImpl<true>(tid, local); }

// Reuse the finished shading queue for pending alpha paths. Never overwrite the
// main continuation queue/count/dispatch, which the next bounce still consumes.
void CompactShadowAlphaImpl<let DIRECT : bool>(uint3 tid, uint3 local)
{
	uint lane = local.x, header = gFrame.frame.x * gFrame.frame.y * 12u;
	if (lane == 0u) gInputCount = DIRECT ? gWavefront.pathCount : gWork[header + 1u].load();
	GroupMemoryBarrierWithGroupSync();
	uint queue = header + 12u + gWavefront.capacity * 84u;
	uint stride = ((gWavefront.capacity + 3u) / 4u) * 4u;
	uint index = 0u, flag = 0u;
	if (tid.x < gInputCount)
	{
		index = DIRECT ? tid.x : gWork[queue + 2u * stride + tid.x].load();
		flag = uint(gWork[header + 12u + index * 4u + 44u * gWavefront.capacity + 3u].load() != 0u);
	}
	gPrefix[lane] = uint2(flag, 0u);
	GroupMemoryBarrierWithGroupSync();
	[unroll]
	for (uint offset = 1u; offset < 64u; offset *= 2u)
	{
		uint value = lane >= offset ? gPrefix[lane - offset].x : 0u;
		GroupMemoryBarrierWithGroupSync();
		gPrefix[lane].x += value;
		GroupMemoryBarrierWithGroupSync();
	}
	if (lane == 0u && gPrefix[63u].x != 0u)
	{
		gOffsets.x = gWork[header + 2u].add(gPrefix[63u].x);
		gWork[header + 8u].max((gOffsets.x + gPrefix[63u].x + 63u) / 64u);
	}
	GroupMemoryBarrierWithGroupSync();
	if (flag != 0u) gWork[queue + stride + gOffsets.x + gPrefix[lane].x - 1u].store(index);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void CompactShadowAlpha(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactShadowAlphaImpl<false>(tid, local); }
[shader("compute")]
[numthreads(64, 1, 1)]
void CompactShadowAlphaDirect(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ CompactShadowAlphaImpl<true>(tid, local); }
