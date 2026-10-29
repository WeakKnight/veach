import Passes.PathTracing;
import Passes.SharcCommon;
import Scene.SceneBindings;
import Materials.MaterialSample;
import Common.Random;

bool SharcUpdatePath(uint index, uint tileStart)
{
	uint group = index / SHARC_UPDATE_STRIDE;
	return index % SHARC_UPDATE_STRIDE == (StrongIntegerHash(group + tileStart / SHARC_UPDATE_STRIDE ^ gFrame.sharc.w) & (SHARC_UPDATE_STRIDE - 1u));
}

bool SharcSurface(MaterialSample ms)
{
	return ms.roughness >= gFrame.sharcParams.y && ms.inputs.baseMetalness < 0.1
		&& ms.inputs.transmissionWeight == 0.0 && ms.inputs.subsurfaceWeight == 0.0 && ms.inputs.coatWeight == 0.0;
}

bool SharcQuery(SharcKey key, out float3 radiance)
{
	radiance = float3(0.0);
	uint hash = SharcHash(key);
	for (uint probe = 0u; probe < SHARC_PROBES; probe++)
	{
		uint base = SharcCellWord((hash + probe) & (gFrame.sharc.y - 1u)) / 4u;
		uint4 a = asuint(gAccum[base]), b = asuint(gAccum[base + 1u]);
		uint history = asuint(gAccum[base + 3u].w);
		if (a.x == SHARC_READY && all(a.yzw == key.spatial.xyz) && b.x == key.spatial.w
			&& b.y == key.material && b.z == key.instance && (history & 65535u) >= gFrame.sharcControl.x
			&& gFrame.sharc.w - b.w <= gFrame.sharcControl.z)
		{
			radiance = gAccum[base + 3u].xyz;
			return all(isfinite(radiance));
		}
	}
	return false;
}

void SharcRecord(uint index, uint bounce, SharcKey key, float3 radiance, float3 throughput)
{
	if (bounce == 0u || bounce > SHARC_RECORDS || bounce >= gFrame.settings.x || any(throughput < 1e-4)) return;
	uint base = SharcRecordWord(index / SHARC_UPDATE_STRIDE * SHARC_RECORDS + bounce - 1u) / 4u;
	gAccum[base] = asfloat(key.spatial);
	gAccum[base + 1u] = asfloat(uint4(key.material, key.instance, 1u, SHARC_READY));
	gAccum[base + 2u] = float4(radiance, 0.0);
	gAccum[base + 3u] = float4(throughput, 0.0);
}

void SharcFinishUpdate(uint index, float3 finalRadiance)
{
	for (uint vertex = 0u; vertex < SHARC_RECORDS; vertex++)
	{
		uint base = SharcRecordWord(index / SHARC_UPDATE_STRIDE * SHARC_RECORDS + vertex) / 4u;
		if (asuint(gAccum[base + 1u].z) == 0u) continue;
		// Back-propagate the fully traced suffix, excluding emission already handled
		// locally at the cached vertex. Training paths never terminate on the cache.
		float3 target = max(finalRadiance - gAccum[base + 2u].xyz, 0.0) / gAccum[base + 3u].xyz;
		if (!all(isfinite(target))) gAccum[base + 1u].z = asfloat(0u);
		gAccum[base + 2u] = float4(target, 0.0);
	}
}
