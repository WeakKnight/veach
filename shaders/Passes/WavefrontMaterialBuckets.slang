// Group the full hit queue by material while retaining the global SVM capacity.
// Queue C is scratch; B stays intact for continuation/shadow compaction.
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
	uint materialCount;
};
[[vk::binding(0, 1)]] RWStructuredBuffer<Atomic<uint>> gWork;
[[vk::binding(2, 1)]] ConstantBuffer<WavefrontUniforms> gWavefront;

// Experimental bound checked by the host, including the fallback material.
groupshared Atomic<uint> gMasks[512];
groupshared uint gOffsets[256];
groupshared uint gInputCount;

uint Header() { return gFrame.frame.x * gFrame.frame.y * 12u; }
uint QueueStride() { return ((gWavefront.capacity + 3u) / 4u) * 4u; }
uint QueueA() { return Header() + 12u + gWavefront.capacity * 84u; }
uint Metadata() { return QueueA() + 3u * QueueStride(); }
uint MaterialMetadata() { return Metadata() + 24u; }

void Partition<let SCATTER : bool>(uint3 tid, uint3 local)
{
	uint lane = local.x, groups = gWavefront.materialCount;
	for (uint i = lane; i < groups * 2u; i += 64u) gMasks[i].store(0u);
	if (lane == 0u) gInputCount = gWork[Header() + 2u].load();
	GroupMemoryBarrierWithGroupSync();
	uint index = 0u, material = groups;
	if (tid.x < gInputCount)
	{
		index = gWork[QueueA() + QueueStride() + tid.x].load();
		uint base = Header() + 12u + index * 4u;
		if (gWork[base + 3u].load() != 0u)
		{
			uint instance = gWork[base + 32u * gWavefront.capacity + 3u].load();
			material = gInstances[instance].materialIndex;
			gMasks[material * 2u + lane / 32u].or(1u << (lane & 31u));
		}
	}
	GroupMemoryBarrierWithGroupSync();
	for (uint group = lane; group < groups; group += 64u)
	{
		uint count = countbits(gMasks[group * 2u].load()) + countbits(gMasks[group * 2u + 1u].load());
		uint meta = MaterialMetadata() + group * 4u;
		if (SCATTER)
			gOffsets[group] = count != 0u ? gWork[meta + 1u].load() + gWork[meta + 2u].add(count) : 0u;
		else if (count != 0u) gWork[meta].add(count);
	}
	if (SCATTER)
	{
		GroupMemoryBarrierWithGroupSync();
		if (material < groups)
		{
			uint lowerMask = (1u << (lane & 31u)) - 1u;
			uint rank = countbits(gMasks[material * 2u + lane / 32u].load() & lowerMask);
			if (lane >= 32u) rank += countbits(gMasks[material * 2u].load());
			gWork[QueueA() + 2u * QueueStride() + gOffsets[material] + rank].store(index);
		}
	}
}

[shader("compute")]
[numthreads(64, 1, 1)]
void CountMaterials(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ Partition<false>(tid, local); }

[shader("compute")]
[numthreads(64, 1, 1)]
void PrefixMaterials(uint3 local : SV_GroupThreadID)
{
	uint lane = local.x, base = MaterialMetadata();
	for (uint group = lane; group < gWavefront.materialCount; group += 64u)
	{
		uint offset = 0u;
		for (uint i = 0u; i < group; i++) offset += gWork[base + i * 4u].load();
		gWork[base + group * 4u + 1u].store(offset);
		gWork[base + group * 4u + 2u].store(0u);
	}
	if (lane < 6u)
	{
		uint total = 0u;
		for (uint i = 0u; i < gWavefront.materialCount; i++) total += gWork[base + i * 4u].load();
		// All capacity records describe the same full queue. One existing compact
		// shading entry at the GLOBAL capacity consumes it without a new interpreter.
		gWork[Metadata() + lane * 4u].store(total);
		gWork[Metadata() + lane * 4u + 1u].store(0u);
	}
}

[shader("compute")]
[numthreads(64, 1, 1)]
void ScatterMaterials(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ Partition<true>(tid, local); }
