// Streaming virtual texture sampling with feedback (after Unreal's VirtualTextureCommon.ush).
//
// Every texture is a power-of-two virtual image of 128^2 pages per mip, down to a single-page
// tail. gVTPageTable holds one entry per virtual page, always naming the finest resident page
// that covers it (valid bit | mapped level << 16 | physical page), so one lookup suffices.
// Each sample stores the page it actually wanted as a feedback request; the host streams it in.
//
// Ray tracing has no screen-space derivatives: the mip level comes from a ray cone
// (Akenine-Moller et al., "Texture Level of Detail Strategies for Real-Time Ray Tracing").
import Common.Math;
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;

static const uint VT_PAGE_SIZE_LOG2 = 7u;
static const float VT_PAGE_SIZE = 128.0;
static const float VT_BORDER = 4.0;
static const float VT_PITCH = 136.0;
static const uint VT_ENTRY_VALID = 0x80000000u;

// ---- feedback: one reservoir-sampled request per invocation ----

static uint gVTRequest = 0u; // page index + 1, 0 = none
static uint gVTRequestCount = 0u;
static uint gVTRandom = 0u;
// mapped / requested level of the most recent sample, for DEBUG_VIRTUAL_TEXTURE
static uint gVTLastMappedLevel = 0u;
static uint gVTLastRequestedLevel = 0u;

void InitVirtualTextureFeedback(uint2 pixel)
{
	gVTRequest = 0u;
	gVTRequestCount = 0u;
	gVTRandom = StrongIntegerHash(pixel.x ^ StrongIntegerHash(pixel.y ^ StrongIntegerHash(gFrame.frame.w)));
}

uint NextVTRandom()
{
	gVTRandom = 1664525u * gVTRandom + 1013904223u;
	return gVTRandom;
}

// Keeps request k with probability 1/k, so every request of the path is equally likely.
void StoreVirtualTextureFeedback(uint pageIndex)
{
	gVTRequestCount++;
	float u = float(NextVTRandom() >> 8u) * (1.0 / 16777216.0);
	if (u * float(gVTRequestCount) < 1.0)
	{
		gVTRequest = pageIndex + 1u;
	}
}

// Only one jittered pixel per feedback tile writes, like Unreal's FinalizeVirtualTextureFeedback.
bool IsFeedbackPixel(uint2 pixel)
{
	uint shift = gFrame.vtInfo.w;
	uint2 jitter = uint2(gFrame.vtInfo.z & 0xFFFFu, gFrame.vtInfo.z >> 16u);
	uint2 tileOrigin = (pixel >> shift) << shift;
	uint2 target = min(tileOrigin + jitter, gFrame.frame.xy - 1u);
	return all(pixel == target);
}

// ---- ray cones ----

// The active cone for traversal-time lookups (alpha testing): x = width at the ray origin,
// y = spread angle. Set by the integrator before each trace.
static float2 gRayCone = float2(0.0);

// log2 of the cone footprint in uv units (per unit texture size) on a triangle.
float UVFootprintLog2(float coneWidth, float worldArea, float uvArea, float cosTheta)
{
	float ratio = uvArea / max(worldArea, 1e-30);
	return log2(max(coneWidth, 1e-20)) - log2(max(abs(cosTheta), 1e-3)) + 0.5 * log2(max(ratio, 1e-30));
}

// ---- sampling ----

uint VTLevels(TextureRef ref) { return (ref.flags >> 12u) & 15u; }
uint VTLog2Width(TextureRef ref) { return (ref.flags >> 16u) & 15u; }
uint VTLog2Height(TextureRef ref) { return (ref.flags >> 20u) & 15u; }

uint2 VTPageCount(uint2 log2Size, uint level)
{
	int2 l = max(int2(log2Size) - int(level) - int(VT_PAGE_SIZE_LOG2), int2(0));
	return uint2(1u << uint(l.x), 1u << uint(l.y));
}

float2 VTLevelSize(uint2 log2Size, uint level)
{
	int2 l = max(int2(log2Size) - int(level), int2(0));
	return float2(float(1u << uint(l.x)), float(1u << uint(l.y)));
}

uint VTLoadEntry(uint index)
{
	uint width = gFrame.vtInfo.y;
	return gVTPageTable.Load(int3(int(index % width), int(index / width), 0));
}

// uv in [0, 1] after wrapping; uvFootprint from UVFootprintLog2 (before texture size).
float4 SampleVirtualTexture(TextureRef ref, float2 uv, float uvFootprint)
{
	uint levels = VTLevels(ref);
	uint2 log2Size = uint2(VTLog2Width(ref), VTLog2Height(ref));

	// stochastic mip selection: floor(lod + noise) averages to trilinear over many samples
	float scale = abs(ref.scaleOffset.x * ref.scaleOffset.y);
	float lod = uvFootprint + 0.5 * (float(log2Size.x + log2Size.y) + log2(max(scale, 1e-20))) + gFrame.vtParams.z;
	float noise = float(NextVTRandom() >> 8u) * (1.0 / 16777216.0);
	uint level = uint(clamp(floor(lod + noise), 0.0, float(levels - 1u)));

	uint index = ref.pageTableOffset;
	for (uint l = 0u; l < level; l++)
	{
		uint2 n = VTPageCount(log2Size, l);
		index += n.x * n.y;
	}
	uint2 pages = VTPageCount(log2Size, level);
	uint2 page = min(uint2(uv * VTLevelSize(log2Size, level)) >> VT_PAGE_SIZE_LOG2, pages - 1u);
	index += page.y * pages.x + page.x;
	StoreVirtualTextureFeedback(index);

	uint entry = VTLoadEntry(index);
	if ((entry & VT_ENTRY_VALID) == 0u)
	{
		return float4(1.0, 0.0, 1.0, 1.0);
	}
	uint mappedLevel = (entry >> 16u) & 15u;
	gVTLastMappedLevel = mappedLevel;
	gVTLastRequestedLevel = level;

	// position inside the mapped (possibly coarser) page; ancestor pages are page >> (level delta)
	float2 texel = uv * VTLevelSize(log2Size, mappedLevel);
	uint2 mappedPage = page >> (mappedLevel - level);
	float2 local = texel - float2(mappedPage) * VT_PAGE_SIZE;

	uint tile = entry & 0xFFFFu;
	uint tilesPerRow = gFrame.vtInfo.x;
	float2 origin = float2(float(tile % tilesPerRow), float(tile / tilesPerRow)) * VT_PITCH + VT_BORDER;
	return gVTPhysical.SampleLevel(gLinearSampler, (origin + local) * gFrame.vtParams.x, 0.0);
}
