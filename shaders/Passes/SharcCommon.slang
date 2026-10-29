// WebGPU spatial radiance cache. Independently implemented from the SHaRC
// update/resolve/query design; no RTX SDK headers or 64-bit atomics are required.
import Scene.SceneBindings;
import Common.Random;

static const uint SHARC_READY = 0xffffffffu;
static const uint SHARC_PROBES = 8u;
static const uint SHARC_RECORDS = 4u;
static const uint SHARC_UPDATE_STRIDE = 16u;
static const uint SHARC_SAMPLE_LIMIT = 512u;
static const float SHARC_SCALE = 1024.0;
static const float SHARC_RADIANCE_MAX = 4096.0;

bool SharcEnabled() { return gFrame.sharc.y != 0u; }
uint SharcCellWord(uint slot) { return gFrame.sharc.x + 16u + slot * 16u; }
uint SharcRecordWord(uint record) { return gFrame.sharc.z + record * 16u; }

struct SharcKey { uint4 spatial; uint material; uint instance; };

bool SharcMakeKey(float3 position, float3 normal, float3 view, uint material, uint instance, out SharcKey key, out float size)
{
	float baseSize = gFrame.sharcParams.x;
	uint level = uint(clamp(floor(log2(max(length(position - gFrame.cameraPosition.xyz) / (baseSize * 32.0), 1.0))), 0.0, 16.0));
	size = baseSize * exp2(float(level));
	float3 cell = floor(position / size);
	uint3 n = uint3(clamp(floor((normal * 0.5 + 0.5) * 15.0 + 0.5), 0.0, 15.0));
	uint direction = (view.x >= 0.0 ? 1u : 0u) | (view.y >= 0.0 ? 2u : 0u) | (view.z >= 0.0 ? 4u : 0u);
	key.spatial = uint4(asuint(int3(clamp(cell, -1073741824.0, 1073741824.0))), n.x | (n.y << 4u) | (n.z << 8u) | (direction << 12u) | (level << 15u));
	key.material = material; key.instance = instance;
	return all(isfinite(cell)) && all(abs(cell) < 1073741824.0);
}

uint SharcHash(SharcKey key)
{
	uint h = StrongIntegerHash(key.spatial.x ^ StrongIntegerHash(key.spatial.y) ^ StrongIntegerHash(key.spatial.z));
	return StrongIntegerHash(h ^ key.spatial.w ^ StrongIntegerHash(key.material) ^ StrongIntegerHash(key.instance)) & (gFrame.sharc.y - 1u);
}
