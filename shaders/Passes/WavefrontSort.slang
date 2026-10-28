// Sort independent chunks of a path queue without moving path records or
// allocating another storage binding. The atomic view permits independent uint stores.
import Scene.SceneTypes;
import Scene.SceneBindings;

#ifndef VEACH_SORT_SIZE
#define VEACH_SORT_SIZE 64
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
groupshared uint2 gSort[VEACH_SORT_SIZE];
groupshared uint gCount;

bool Less(uint2 a, uint2 b)
{
	return a.x < b.x || (a.x == b.x && a.y < b.y);
}

// KEY: material 0, surface program 1, continuation direction octant 2.
void SortImpl<let KEY : uint>(uint3 tid, uint3 local)
{
	uint lane = local.x;
	uint header = gFrame.frame.x * gFrame.frame.y * 12u;
	if (lane == 0u) gCount = gWork[header + (KEY == 2u ? 0u : 2u)].load();
	GroupMemoryBarrierWithGroupSync();
	uint queue = header + 12u + gWavefront.capacity * 84u + (KEY == 2u ? 0u : ((gWavefront.capacity + 3u) / 4u) * 4u);
	uint2 item = uint2(0xffffffffu);
	if (tid.x < gCount)
	{
		item.y = gWork[queue + tid.x].load();
		uint base = header + 12u + item.y * 4u;
		// Packet queues retain dead paths. Their hit records may be uninitialized.
		if (gWork[base + 3u].load() != 0u)
		{
			if (KEY == 2u)
			{
				uint direction = base + 12u * gWavefront.capacity;
				item.x = (gWork[direction].load() >> 31u)
					| ((gWork[direction + 1u].load() >> 31u) << 1u)
					| ((gWork[direction + 2u].load() >> 31u) << 2u);
			}
			else
			{
				uint instance = gWork[base + 32u * gWavefront.capacity + 3u].load();
				uint material = gInstances[instance].materialIndex;
				item.x = KEY == 1u ? gMaterialData[material * 2u].x : material;
			}
		}
	}
	gSort[lane] = item;
	GroupMemoryBarrierWithGroupSync();
	// Tie-breaking by physical path index keeps every valid slot before padding,
	// including absent surface programs and inactive packet entries (key UINT_MAX).
	[unroll]
	for (uint width = 2u; width <= VEACH_SORT_SIZE; width *= 2u)
	{
		[unroll]
		for (uint stride = width / 2u; stride > 0u; stride /= 2u)
		{
			uint2 other = gSort[lane ^ stride];
			bool ascending = (lane & width) == 0u;
			bool lower = (lane & stride) == 0u;
			bool takeMin = ascending == lower;
			uint2 next = (takeMin ? Less(other, item) : Less(item, other)) ? other : item;
			GroupMemoryBarrierWithGroupSync();
			item = next;
			gSort[lane] = item;
			GroupMemoryBarrierWithGroupSync();
		}
	}
	if (tid.x < gCount) gWork[queue + tid.x].store(item.y);
}

[shader("compute")]
[numthreads(VEACH_SORT_SIZE, 1, 1)]
void SortMaterial(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ SortImpl<0u>(tid, local); }

[shader("compute")]
[numthreads(VEACH_SORT_SIZE, 1, 1)]
void SortProgram(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ SortImpl<1u>(tid, local); }

[shader("compute")]
[numthreads(VEACH_SORT_SIZE, 1, 1)]
void SortDirection(uint3 tid : SV_DispatchThreadID, uint3 local : SV_GroupThreadID)
{ SortImpl<2u>(tid, local); }
