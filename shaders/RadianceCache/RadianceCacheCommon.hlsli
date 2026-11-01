// Veach radiance cache (docs/RadianceCache.md): dense, toroidally addressed world-space probe clipmaps of incoming
// radiance, the fallback of screen-space reflections. Shared by the probe trace (Passes/RadianceCache.slang) and the
// lookups (SSSR callbacks). HLSL-compatible: included, not imported.
//
// Every clipmap cell owns a probe, there is no marking or allocation: world cell w of clipmap c lives in slot
// posmod(w, R) of that clipmap, so scrolling a clipmap only invalidates the slots whose world cell changed. A slot's
// state records the world cell it holds (floordiv(w, R) & 255 per axis), so lookups never read a stale probe.
//
// The includer defines RADIANCE_CACHE_GROUP, RADIANCE_CACHE_BINDING_CONSTANTS and RADIANCE_CACHE_BINDING_PROBES, and
// RADIANCE_CACHE_PROBES_RW for read-write probe storage (the trace).

#define RADIANCE_CACHE_MAX_CLIPMAPS 4
// Probe storage, in 32-bit words: a header [state, sample count, unused, unused], then per octahedral texel two
// words: half2(r, g), half2(b, hit distance). Radiance is scene-linear (not pre-exposed).
#define RADIANCE_CACHE_HEADER_WORDS 4u
#define RADIANCE_CACHE_STATE_VALID (1u << 24u)
#define RADIANCE_CACHE_STATE_INSIDE (1u << 25u)
#define RADIANCE_CACHE_MISS_DISTANCE 65504.0

struct RadianceCacheConstants
{
	float4 clipmaps[RADIANCE_CACHE_MAX_CLIPMAPS]; // world corner of the window (xyz), cell size (w)
	int4 origins[RADIANCE_CACHE_MAX_CLIPMAPS];    // world cell of the window's minimum corner (xyz)
	uint4 grid;   // clipmap resolution R, probe resolution P, clipmap count, words per probe
	float4 params; // normal bias (cells), max radiance, unused, unused
	uint4 frame;  // frame index, probes to update, max bounces, unused
};

[[vk::binding(RADIANCE_CACHE_BINDING_CONSTANTS, RADIANCE_CACHE_GROUP)]] ConstantBuffer<RadianceCacheConstants> gRadianceCache;
#if RADIANCE_CACHE_PROBES_RW
[[vk::binding(RADIANCE_CACHE_BINDING_PROBES, RADIANCE_CACHE_GROUP)]] RWStructuredBuffer<uint> gRadianceCacheProbes;
#else
[[vk::binding(RADIANCE_CACHE_BINDING_PROBES, RADIANCE_CACHE_GROUP)]] StructuredBuffer<uint> gRadianceCacheProbes;
#endif

int RadianceCacheFloorDiv(int a, int b) { return a >= 0 ? a / b : -((-a + b - 1) / b); }
int RadianceCachePosMod(int a, int b) { int m = a % b; return m < 0 ? m + b : m; }

uint RadianceCacheSlot(uint clipmap, int3 cell)
{
	int R = int(gRadianceCache.grid.x);
	int3 s = int3(RadianceCachePosMod(cell.x, R), RadianceCachePosMod(cell.y, R), RadianceCachePosMod(cell.z, R));
	return clipmap * uint(R * R * R) + uint((s.z * R + s.y) * R + s.x);
}

// The state a slot holds for world cell `cell`, valid bit not included.
uint RadianceCacheCellTag(int3 cell)
{
	int R = int(gRadianceCache.grid.x);
	int3 k = int3(RadianceCacheFloorDiv(cell.x, R), RadianceCacheFloorDiv(cell.y, R), RadianceCacheFloorDiv(cell.z, R));
	return uint(k.x & 0xff) | (uint(k.y & 0xff) << 8u) | (uint(k.z & 0xff) << 16u);
}

bool RadianceCacheInWindow(uint clipmap, int3 cell)
{
	int3 o = gRadianceCache.origins[clipmap].xyz;
	int R = int(gRadianceCache.grid.x);
	return all(cell >= o) && all(cell < o + R);
}

float3 RadianceCacheProbePosition(uint clipmap, int3 cell)
{
	return (float3(cell) + 0.5) * gRadianceCache.clipmaps[clipmap].w;
}

uint RadianceCacheProbeBase(uint slot) { return slot * gRadianceCache.grid.w; }

// Octahedral mapping (as NrdOctEncode in Wavefront.slang): direction <-> [-1, 1]^2.
float2 RadianceCacheOctEncode(float3 v)
{
	float2 p = v.xy / (abs(v.x) + abs(v.y) + abs(v.z));
	return v.z >= 0.0 ? p : (1.0 - abs(p.yx)) * float2(p.x >= 0.0 ? 1.0 : -1.0, p.y >= 0.0 ? 1.0 : -1.0);
}

float3 RadianceCacheOctDecode(float2 p)
{
	float3 v = float3(p, 1.0 - abs(p.x) - abs(p.y));
	if (v.z < 0.0) v.xy = (1.0 - abs(v.yx)) * float2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0);
	return normalize(v);
}

// Radiance (rgb) and mean first hit distance (w) of a texel.
float4 RadianceCacheLoadTexel(uint base, int2 t)
{
	int P = int(gRadianceCache.grid.y);
	// Octahedral border: a texel beyond an edge is its mirror across that edge's center.
	if (t.x < 0) { t = int2(-1 - t.x, P - 1 - t.y); }
	else if (t.x >= P) { t = int2(2 * P - 1 - t.x, P - 1 - t.y); }
	if (t.y < 0) { t = int2(P - 1 - t.x, -1 - t.y); }
	else if (t.y >= P) { t = int2(P - 1 - t.x, 2 * P - 1 - t.y); }
	uint w = base + RADIANCE_CACHE_HEADER_WORDS + uint(t.y * P + t.x) * 2u;
	uint a = gRadianceCacheProbes[w], b = gRadianceCacheProbes[w + 1u];
	return float4(f16tof32(a & 0xffffu), f16tof32(a >> 16u), f16tof32(b & 0xffffu), f16tof32(b >> 16u));
}

// Bilinear radiance (rgb) and mean hit distance (w) of a probe in direction `direction`.
float4 RadianceCacheSampleProbe(uint slot, float3 direction)
{
	uint base = RadianceCacheProbeBase(slot);
	float P = float(gRadianceCache.grid.y);
	float2 t = (RadianceCacheOctEncode(direction) * 0.5 + 0.5) * P - 0.5;
	int2 i = int2(floor(t));
	float2 f = t - float2(i);
	float4 a = lerp(RadianceCacheLoadTexel(base, i), RadianceCacheLoadTexel(base, i + int2(1, 0)), f.x);
	float4 b = lerp(RadianceCacheLoadTexel(base, i + int2(0, 1)), RadianceCacheLoadTexel(base, i + int2(1, 1)), f.x);
	return lerp(a, b, f.y);
}

#if !RADIANCE_CACHE_PROBES_RW
// Incoming radiance at `position` from the probes of clipmap `c`: trilinear over the 8 probes around the normal-biased
// position; probes behind the surface, inside geometry or occluded from the position get little or no weight. Each
// probe is read parallax corrected: in the direction of the point the ray from `position` reaches at the probe's own
// hit distance along `direction`, so all 8 probes look at the same surface. Young probes (few traces of one path per
// texel, just scrolled in) weigh less; `confidence` is the weighted maturity of the probes used, `edge` how far inside
// the window the position is, in cells (0 at the outermost usable cell). False without valid probes.
#define RADIANCE_CACHE_MATURE_SAMPLES 8.0
bool RadianceCacheSampleClipmap(uint c, float3 position, float3 normal, float3 direction, out float3 radiance, out float confidence, out float edge)
{
	radiance = float3(0.0, 0.0, 0.0);
	confidence = 0.0;
	edge = 0.0;
	float cellSize = gRadianceCache.clipmaps[c].w;
	float3 p = position + normal * (gRadianceCache.params.x * cellSize);
	float3 f = p / cellSize - 0.5;
	int3 cell0 = int3(floor(f));
	float3 alpha = f - float3(cell0);
	if (!RadianceCacheInWindow(c, cell0) || !RadianceCacheInWindow(c, cell0 + 1)) return false;
	float3 sum = float3(0.0, 0.0, 0.0);
	float weightSum = 0.0, baseSum = 0.0, maturitySum = 0.0;
	for (uint i = 0u; i < 8u; i++)
	{
		int3 offset = int3(int(i & 1u), int((i >> 1u) & 1u), int(i >> 2u));
		int3 cell = cell0 + offset;
		uint slot = RadianceCacheSlot(c, cell);
		uint state = gRadianceCacheProbes[RadianceCacheProbeBase(slot)];
		if ((state & (RADIANCE_CACHE_STATE_VALID | RADIANCE_CACHE_STATE_INSIDE)) != RADIANCE_CACHE_STATE_VALID || (state & 0xffffffu) != RadianceCacheCellTag(cell)) continue;
		float3 trilinear = lerp(1.0 - alpha, alpha, float3(offset));
		float3 probe = RadianceCacheProbePosition(c, cell);
		// DDGI-style backface weight: probes behind the surface see the wrong side.
		float facing = (dot(normalize(probe - position), normal) + 1.0) * 0.5;
		float weight = trilinear.x * trilinear.y * trilinear.z * (facing * facing + 0.05);
		// Visibility: a probe whose mean hit distance toward the biased point is shorter than the point's distance
		// sees geometry in between (a cabinet door, a wall); fade it out over a quarter cell. Without it, probes on
		// the far side of nearby occluders leak in and out with the cell period.
		float3 toPoint = p - probe;
		float pointDistance = length(toPoint);
		if (pointDistance > 1e-4)
		{
			float seen = RadianceCacheSampleProbe(slot, toPoint / pointDistance).w;
			weight *= max(saturate(1.0 - (pointDistance - seen) / (0.25 * cellSize)), 0.02);
		}
		// Parallax: read the probe toward the point the ray from `position` reaches at the probe's hit distance.
		float3 target = position + direction * RadianceCacheSampleProbe(slot, direction).w - probe;
		float3 corrected = dot(target, target) > 1e-12 ? normalize(target) : direction;
		float maturity = saturate(float(gRadianceCacheProbes[RadianceCacheProbeBase(slot) + 1u]) / RADIANCE_CACHE_MATURE_SAMPLES);
		baseSum += weight;
		maturitySum += weight * maturity;
		weight *= maturity + 0.02;
		sum += RadianceCacheSampleProbe(slot, corrected).xyz * weight;
		weightSum += weight;
	}
	if (weightSum <= 1e-6) return false;
	radiance = sum / weightSum;
	confidence = maturitySum / baseSum;
	float3 inside = min(f - float3(gRadianceCache.origins[c].xyz), float3(gRadianceCache.origins[c].xyz + int(gRadianceCache.grid.x) - 1) - f);
	edge = min(min(inside.x, inside.y), inside.z);
	return true;
}

// Incoming radiance at `position` (surface with normal `normal`) from `direction`, scene-linear: the finest clipmap
// with valid probes, cross-faded into the next one over the last RADIANCE_CACHE_BLEND_CELLS cells of its window (no
// seam at the level change) and where its probes are young (the coarser level scrolls less and has more traces).
// Returns false when no clipmap covers the position with valid probes.
#define RADIANCE_CACHE_BLEND_CELLS 2.0
bool RadianceCacheSample(float3 position, float3 normal, float3 direction, out float3 radiance)
{
	radiance = float3(0.0, 0.0, 0.0);
	for (uint c = 0u; c < gRadianceCache.grid.z; c++)
	{
		float confidence, edge;
		if (!RadianceCacheSampleClipmap(c, position, normal, direction, radiance, confidence, edge)) continue;
		float inside = saturate(edge / RADIANCE_CACHE_BLEND_CELLS);
		float3 coarse;
		float coarseConfidence, unused;
		if ((inside < 1.0 || confidence < 1.0) && c + 1u < gRadianceCache.grid.z
			&& RadianceCacheSampleClipmap(c + 1u, position, normal, direction, coarse, coarseConfidence, unused))
		{
			// The coarser level takes over at the window edge, and where this level is younger than it.
			float fine = inside * max(confidence, 0.05);
			float coarser = (1.0 - inside) + inside * (1.0 - confidence) * coarseConfidence;
			radiance = (radiance * fine + coarse * coarser) / (fine + coarser);
		}
		return true;
	}
	return false;
}
#endif
