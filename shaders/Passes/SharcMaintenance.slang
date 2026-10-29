import Passes.SharcCommon;
import Scene.SceneBindings;

[[vk::binding(0, 1)]] RWStructuredBuffer<Atomic<uint>> gSharcWork;
struct SharcTile { uint tileStart; uint pathCount; uint bounce; uint capacity; uint4 unused; };
[[vk::binding(2, 1)]] ConstantBuffer<SharcTile> gSharcTile;

uint3 EncodeRadiance(uint record)
{
	uint p = SharcRecordWord(record) + 8u;
	float3 value = asfloat(uint3(gSharcWork[p].load(), gSharcWork[p + 1u].load(), gSharcWork[p + 2u].load()));
	return uint3(clamp(value, 0.0, SHARC_RADIANCE_MAX) * SHARC_SCALE + 0.5);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Accumulate(uint3 tid : SV_DispatchThreadID)
{
	uint record = tid.x;
	if (record >= gFrame.sharcControl.w) return;
	uint r = SharcRecordWord(record);
	if (gSharcWork[r + 6u].load() == 0u) return;
	gSharcWork[gFrame.sharc.x + 4u].add(1u);
	SharcKey key;
	key.spatial = uint4(gSharcWork[r].load(), gSharcWork[r + 1u].load(), gSharcWork[r + 2u].load(), gSharcWork[r + 3u].load());
	key.material = gSharcWork[r + 4u].load(); key.instance = gSharcWork[r + 5u].load();
	uint hash = SharcHash(key), empty = SHARC_READY;
	bool pending = false;
	for (uint probe = 0u; probe < SHARC_PROBES; probe++)
	{
		uint slot = (hash + probe) & (gFrame.sharc.y - 1u), p = SharcCellWord(slot);
		uint state = gSharcWork[p].load();
		if (state == 0u) { if (empty == SHARC_READY) empty = slot; continue; }
		if (state != SHARC_READY) { pending = true; continue; }
		if (gSharcWork[p + 1u].load() != key.spatial.x || gSharcWork[p + 2u].load() != key.spatial.y
			|| gSharcWork[p + 3u].load() != key.spatial.z || gSharcWork[p + 4u].load() != key.spatial.w
			|| gSharcWork[p + 5u].load() != key.material || gSharcWork[p + 6u].load() != key.instance) continue;
		uint sample = gSharcWork[p + 11u].add(1u);
		if (sample < SHARC_SAMPLE_LIMIT)
		{
			uint3 rgb = EncodeRadiance(record);
			gSharcWork[p + 8u].add(rgb.x); gSharcWork[p + 9u].add(rgb.y); gSharcWork[p + 10u].add(rgb.z);
			gSharcWork[p + 7u].store(gFrame.sharc.w);
			gSharcWork[gFrame.sharc.x + 9u].add(1u);
		}
		return;
	}
	// Do not read a newly inserted key in this pass. Publishing is a separate
	// dispatch, avoiding device-wide spinlocks and relaxed-atomic publication races.
	if (pending) return;
	if (empty != SHARC_READY && gSharcWork[SharcCellWord(empty)].compareExchange(0u, record + 1u) == 0u)
		gSharcWork[r + 7u].store(empty);
	else gSharcWork[gFrame.sharc.x + 6u].add(1u);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Publish(uint3 tid : SV_DispatchThreadID)
{
	uint record = tid.x;
	if (record >= gFrame.sharcControl.w) return;
	uint r = SharcRecordWord(record);
	if (gSharcWork[r + 6u].load() == 0u) return;
	uint slot = gSharcWork[r + 7u].load();
	if (slot == SHARC_READY) return;
	uint p = SharcCellWord(slot);
	for (uint i = 0u; i < 6u; i++) gSharcWork[p + 1u + i].store(gSharcWork[r + i].load());
	gSharcWork[p + 7u].store(gFrame.sharc.w);
	uint3 rgb = EncodeRadiance(record);
	gSharcWork[p + 8u].store(rgb.x); gSharcWork[p + 9u].store(rgb.y); gSharcWork[p + 10u].store(rgb.z);
	gSharcWork[p + 11u].store(1u);
	for (uint i = 12u; i < 16u; i++) gSharcWork[p + i].store(0u);
	gSharcWork[p].store(SHARC_READY);
	gSharcWork[gFrame.sharc.x + 9u].add(1u);
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Resolve(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= gFrame.sharc.y) return;
	uint p = SharcCellWord(tid.x);
	if (gSharcWork[p].load() != SHARC_READY) return;
	if (gFrame.sharc.w - gSharcWork[p + 7u].load() > gFrame.sharcControl.z)
	{
		for (uint i = 0u; i < 16u; i++) gSharcWork[p + i].store(0u);
		return;
	}
	gSharcWork[gFrame.sharc.x + 5u].add(1u);
	uint count = min(gSharcWork[p + 11u].load(), SHARC_SAMPLE_LIMIT);
	if (count == 0u) return;
	uint history = gSharcWork[p + 15u].load(), frames = history >> 16u;
	float weight = float(min(frames, gFrame.sharcControl.y));
	for (uint c = 0u; c < 3u; c++)
	{
		float fresh = float(gSharcWork[p + 8u + c].load()) / (SHARC_SCALE * float(count));
		float old = asfloat(gSharcWork[p + 12u + c].load());
		gSharcWork[p + 12u + c].store(asuint((old * weight + fresh) / (weight + 1.0)));
		gSharcWork[p + 8u + c].store(0u);
	}
	gSharcWork[p + 11u].store(0u);
	gSharcWork[p + 15u].store((min(frames + 1u, gFrame.sharcControl.y) << 16u) | min((history & 65535u) + count, 65535u));
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Statistics(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= gSharcTile.pathCount) return;
	uint header = gFrame.frame.x * gFrame.frame.y * 12u;
	uint state = gSharcWork[header + 12u + gSharcTile.capacity * 24u + tid.x * 4u + 3u].load();
	if ((state & 255u) == 0u) return;
	uint p = gFrame.sharc.x;
	gSharcWork[p].add(1u); gSharcWork[p + 1u].add(state & 255u);
	gSharcWork[p + 2u].add((state >> 8u) & 1u); gSharcWork[p + 3u].add((state >> 9u) & 1u);
	gSharcWork[p + 8u].add(state >> 16u);
}
