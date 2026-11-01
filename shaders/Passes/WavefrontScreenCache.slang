// Screen-space L1 radiance cache of realtime SSSR frames (docs/ScreenCache.md): the previous frame's linear scene
// color stands in for the radiance leaving a surface, as NRD-Sample's "L1 cache" does.
// - Screen trace: the primary diffuse continuation first ray marches the previous frame's closest-depth hierarchy;
//   a confident hit takes the previous frame's color and ends the path before any BVH traversal.
// - Hit lookup: a traced hit that the previous frame saw (depth, normal and screen edge tests) takes its color with
//   probability equal to the confidence, instead of NEE and further bounces.
// Diffuse surfaces reflect the same radiance toward the previous camera as toward the path vertex; view-dependent
// surfaces lose confidence. Emissive pixels are never read: their emission is MIS weighted against NEE.
// gScreenCache.info.x is 0 on every frame that is not a realtime SSSR frame, so offline frames never read it.
import Common.Math;

struct ScreenCacheConstants
{
	float4 previous[4]; // rows of the previous frame's world -> clip (SssrConfig.ts sssrMatrices, previous jitter)
	float4 current[4];  // rows of this frame's world -> clip (current jitter)
	uint4 info;         // mode (SCREEN_CACHE_TRACE | SCREEN_CACHE_HITS), render width, height, depth hierarchy mips
	float4 params;      // near plane, thickness (fraction of view depth), max march iterations, history confidence
};
static const uint SCREEN_CACHE_TRACE = 1u;
static const uint SCREEN_CACHE_HITS = 2u;

[[vk::binding(4, 1)]] ConstantBuffer<ScreenCacheConstants> gScreenCache;
// The previous frame's SSSR inputs, untouched until this frame's SSSR runs after the trace.
[[vk::binding(5, 1)]] Texture2D<float> gScreenCacheDepth;   // closest-depth hierarchy: near / viewZ, 0 without a surface
[[vk::binding(6, 1)]] Texture2D<float4> gScreenCacheNormal; // world normal; w: perceptual roughness (+2 metal), -1 emissive
[[vk::binding(7, 1)]] Texture2D<float4> gScreenCacheColor;  // linear scene color, scene-linear (not pre-exposed)

bool ScreenCacheMode(uint bit) { return (gScreenCache.info.x & bit) != 0u; }

float4 ScreenCacheClip(bool previous, float3 p)
{
	float4 h = float4(p, 1.0);
	if (previous) return float4(dot(gScreenCache.previous[0], h), dot(gScreenCache.previous[1], h), dot(gScreenCache.previous[2], h), dot(gScreenCache.previous[3], h));
	return float4(dot(gScreenCache.current[0], h), dot(gScreenCache.current[1], h), dot(gScreenCache.current[2], h), dot(gScreenCache.current[3], h));
}

// FidelityFX screen space: uv with pixel centers at (p + 0.5) / size, inverted depth near / viewZ (clip.w = viewZ).
float3 ScreenCacheScreen(float4 clip)
{
	float2 ndc = clip.xy / clip.w;
	return float3(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5, gScreenCache.params.x / clip.w);
}

float2 ScreenCacheSize() { return float2(gScreenCache.info.yz); }

int2 ScreenCacheTexel(float2 uv) { return clamp(int2(uv * ScreenCacheSize()), int2(0), int2(gScreenCache.info.yz) - 1); }

// NRD's GetSpecMagicCurve: how diffuse-like the lighting leaving a surface of this roughness is.
float ScreenCacheSpecularConfidence(float roughness)
{
	return (1.0 - exp2(-200.0 * roughness * roughness)) * pow(saturate(roughness), 0.25);
}

// The surface's lighting reaches every direction alike (diffuse) or not (glossy, metals). Emissive: never.
float ScreenCacheSurfaceConfidence(float packed)
{
	if (packed < 0.0) return 0.0;
	bool metal = packed >= 2.0;
	float specular = ScreenCacheSpecularConfidence(saturate(packed - (metal ? 2.0 : 0.0)));
	return (metal ? specular : lerp(1.0, specular, 0.2)) * gScreenCache.params.w;
}

// FidelityFX SSSR's hierarchical ray march (ffx_sssr_intersect.h FFX_SSSR_HierarchicalRaymarch, inverted depth) over
// the previous frame's closest-depth mips. False when the ray leaves the screen, reaches infinity or runs out of
// iterations; otherwise `position` is where it crossed below the depth buffer.
bool ScreenCacheMarch(float3 origin, float3 direction, out float3 position)
{
	float2 size = ScreenCacheSize();
	int maxMip = int(gScreenCache.info.w) - 1;
	float3 invDirection = float3(direction.x != 0.0 ? 1.0 / direction.x : FLT_LARGE, direction.y != 0.0 ? 1.0 / direction.y : FLT_LARGE,
		direction.z != 0.0 ? 1.0 / direction.z : FLT_LARGE);
	float2 floorOffset = float2(direction.x < 0.0 ? 0.0 : 1.0, direction.y < 0.0 ? 0.0 : 1.0);
	float2 uvOffset = 0.005 / size * float2(direction.x < 0.0 ? -1.0 : 1.0, direction.y < 0.0 ? -1.0 : 1.0);
	int mip = 0;
	float2 mipSize = size;
	// Initial advance to the next texel boundary, away from the origin's own texel.
	float2 plane = (floor(mipSize * origin.xy) + floorOffset) / mipSize + uvOffset;
	float2 t2 = (plane - origin.xy) * invDirection.xy;
	float t = min(t2.x, t2.y);
	position = origin + t * direction;
	uint iterations = uint(gScreenCache.params.z);
	for (uint i = 0u; i < iterations; i++)
	{
		if (any(position.xy < 0.0) || any(position.xy > 1.0) || position.z <= 0.0) return false;
		float2 mipPosition = mipSize * position.xy;
		float surface = gScreenCacheDepth.Load(int3(int2(mipPosition), mip));
		plane = (floor(mipPosition) + floorOffset) / mipSize + uvOffset;
		float3 bounds = (float3(plane, surface) - origin) * invDirection;
		// The depth plane only stops rays that move away from the camera (decreasing inverted depth).
		bounds.z = direction.z < 0.0 ? bounds.z : FLT_LARGE;
		float tMin = min(min(bounds.x, bounds.y), bounds.z);
		bool above = surface < position.z;
		bool skipped = asuint(tMin) != asuint(bounds.z) && above;
		t = above ? tMin : t;
		position = origin + t * direction;
		if (skipped && mip < maxMip) { mip++; mipSize *= 0.5; }
		else if (!skipped)
		{
			if (mip == 0) return true;
			mip--; mipSize *= 2.0;
		}
	}
	return false;
}

// Screen trace of a ray leaving `origin` (a surface of this frame) in `direction`. Returns the confidence that the
// previous frame's color at the hit is the radiance arriving along the ray; hitDistance: the hit's distance.
float ScreenCacheTrace(float3 origin, float3 direction, out float3 radiance, out float hitDistance)
{
	radiance = float3(0.0);
	hitDistance = 0.0;
	float near = gScreenCache.params.x;
	float4 o = ScreenCacheClip(true, origin);
	if (o.w <= near) return 0.0;
	// A straight line in view space is a straight line in (uv, inverted depth); its end stays in front of the camera.
	float dz = dot(gScreenCache.previous[3].xyz, direction);
	float rayLength = o.w;
	if (dz < 0.0) rayLength = min(rayLength, 0.5 * (o.w - near) / -dz);
	float4 e = ScreenCacheClip(true, origin + direction * rayLength);
	float3 so = ScreenCacheScreen(o), se = ScreenCacheScreen(e);
	if (any(so.xy < 0.0) || any(so.xy > 1.0)) return 0.0;
	float3 hit;
	if (!ScreenCacheMarch(so, se - so, hit)) return 0.0;
	float2 size = ScreenCacheSize();
	int2 texel = ScreenCacheTexel(hit.xy);
	float surface = gScreenCacheDepth.Load(int3(texel, 0));
	if (surface <= 0.0) return 0.0;
	// Contact geometry within a pixel or two is left to the BVH: the depth buffer cannot resolve it.
	if (all(abs(hit.xy - so.xy) * size < 1.5)) return 0.0;
	float4 normal = gScreenCacheNormal.Load(int3(texel, 0));
	if (normal.w < 0.0 || dot(normal.xyz, direction) >= 0.0) return 0.0;
	// Hits more than `thickness` behind the depth buffer passed behind a surface: occluded, unknown.
	float surfaceZ = near / surface, rayZ = near / max(hit.z, 1e-12);
	float confidence = 1.0 - smoothstep(0.0, gScreenCache.params.y * surfaceZ, abs(rayZ - surfaceZ));
	confidence *= confidence;
	float2 border = smoothstep(0.0, 0.05, hit.xy) * (1.0 - smoothstep(0.95, 1.0, hit.xy));
	confidence *= border.x * border.y * ScreenCacheSurfaceConfidence(normal.w);
	if (confidence <= 0.0) return 0.0;
	// Projective parameterization: screen-space parameter t is at s = t * rayLength * viewZ(s) / viewZ(end) on the ray.
	float2 d = se.xy - so.xy;
	float t = dot(d, d) > 1e-12 ? dot(hit.xy - so.xy, d) / dot(d, d) : (hit.z - so.z) / (se.z - so.z);
	hitDistance = max(t * rayLength * rayZ / e.w, 0.0);
	radiance = gScreenCacheColor.Load(int3(texel, 0)).xyz;
	return all(isfinite(radiance)) ? confidence : 0.0;
}

// Hit lookup (NRD-Sample ReprojectIrradiance): the previous frame's color at a traced hit `position` with oriented
// normal `normal`, reached by the path of `pixel`. Returns the confidence.
float ScreenCacheLookup(float3 position, float3 normal, uint2 pixel, out float3 radiance)
{
	radiance = float3(0.0);
	float near = gScreenCache.params.x;
	float4 c = ScreenCacheClip(true, position);
	if (c.w <= near) return 0.0;
	float3 s = ScreenCacheScreen(c);
	if (any(s.xy <= 0.0) || any(s.xy >= 1.0)) return 0.0;
	int2 texel = ScreenCacheTexel(s.xy);
	float surface = gScreenCacheDepth.Load(int3(texel, 0));
	if (surface <= 0.0) return 0.0;
	// The previous frame saw this point: the same view depth (2% to 1%), the same side.
	float viewZ = near / surface;
	float confidence = saturate((0.02 - abs(c.w - viewZ) / max(c.w, viewZ)) / 0.01);
	float2 edge = saturate(s.xy / 0.1) * saturate((1.0 - s.xy) / 0.1);
	confidence *= edge.x * edge.y;
	float4 n = gScreenCacheNormal.Load(int3(texel, 0));
	confidence *= saturate((dot(n.xyz, normal) - 0.5) / 0.4) * ScreenCacheSurfaceConfidence(n.w);
	// Hits within a few pixels of the path's own pixel would read the pixel's own result back.
	float4 cc = ScreenCacheClip(false, position);
	if (cc.w <= near) return 0.0;
	float2 current = ScreenCacheScreen(cc).xy * ScreenCacheSize();
	confidence *= saturate((distance(current, float2(pixel) + 0.5) - 1.0) / 2.0);
	if (confidence <= 0.0) return 0.0;
	radiance = gScreenCacheColor.Load(int3(texel, 0)).xyz;
	return all(isfinite(radiance)) ? confidence : 0.0;
}
