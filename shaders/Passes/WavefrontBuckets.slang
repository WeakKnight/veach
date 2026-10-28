// Compact SVM-capacity groups. Queue B stays intact for CompactShade;
// queue C is scratch until all shading completes and CompactShade rebuilds shadows.
import Scene.SceneTypes;
import Scene.SceneBindings;

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

// Two words per bucket represent the 64 lanes. Popcount ranks retain input order
// within a workgroup without depending on subgroup support or atomic arrival order.
groupshared Atomic<uint> gMasks[12];
groupshared uint gOffsets[6];
groupshared uint gInputCount;

uint Header() { return gFrame.frame.x * gFrame.frame.y * 12u; }
uint QueueStride() { return ((gWavefront.capacity + 3u) / 4u) * 4u; }
uint QueueA() { return Header() + 12u + gWavefront.capacity * 84u; }
uint Metadata() { return QueueA() + 3u * QueueStride(); }
uint Bucket(uint capacity) { return capacity == 0u ? 0u : countbits(capacity - 1u) + 1u; }

uint Classify(uint index)
{
	uint base = Header() + 12u + index * 4u;
	if (gWork[base + 3u].load() == 0u) return 6u;
	uint instance = gWork[base + 32u * gWavefront.capacity + 3u].load();
	uint material = gInstances[instance].materialIndex;
	return Bucket((gMaterialData[material * 2u].w >> 16u) & 31u);
}

void Partition<let SCATTER : bool>(uint3 tid, uint3 local)
{
	uint lane = local.x;
	if (lane < 12u) gMasks[lane].store(0u);
	if (lane == 0u) gInputCount = gWork[Header() + 2u].load();
	GroupMemoryBarrierWithGroupSync();
	uint index = 0u, bucket = 6u;
	if (tid.x < gInputCount)
	{
		index = gWork[QueueA() + QueueStride() + tid.x].load();
		bucket = Classify(index);
		if (bucket < 6u) gMasks[bucket * 2u + lane / 32u].or(1u << (lane & 31u));
	}
	GroupMemoryBarrierWithGroupSync();
	if (lane < 6u)
	{
		uint count = countbits(gMasks[lane * 2u].load()) + countbits(gMasks[lane * 2u + 1u].load());
		uint meta = Metadata() + lane * 4u;
		if (SCATTER)
			gOffsets[lane] = count != 0u ? gWork[meta + 1u].load() + gWork[meta + 2u].add(count) : 0u;
		else if (count != 0u)
			gWork[meta].add(count);
	}
	if (SCATTER)
	{
		GroupMemoryBarrierWithGroupSync();
		if (bucket < 6u)
		{
			uint lowerMask = (1u << (lane & 31u)) - 1u;
			uint rank = countbits(gMasks[bucket * 2u + lane / 32u].load() & lowerMask);
			if (lane >= 32u) rank += countbits(gMasks[bucket * 2u].load());
			gWork[QueueA() + 2u * QueueStride() + gOffsets[bucket] + rank].store(index);
		}
	}
}

[shader("compute")]
[numthreads(64, 1, 1)]
void CountBuckets(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ Partition<false>(tid, local); }

[shader("compute")]
[numthreads(64, 1, 1)]
void PrefixBuckets(uint3 local : SV_GroupThreadID)
{
	uint lane = local.x;
	if (lane >= 6u) return;
	uint base = Metadata();
	uint count = gWork[base + lane * 4u].load(), offset = 0u;
	for (uint i = 0u; i < lane; i++) offset += gWork[base + i * 4u].load();
	gWork[base + lane * 4u + 1u].store(offset);
	gWork[base + lane * 4u + 2u].store(0u);
	uint args = base + 24u + lane * 4u;
	gWork[args].store((count + 63u) / 64u);
	gWork[args + 1u].store(1u);
	gWork[args + 2u].store(1u);
	gWork[args + 3u].store(0u);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void ScatterBuckets(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ Partition<true>(tid, local); }
