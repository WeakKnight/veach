import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Passes.PrimaryCamera;

[[vk::binding(0, 1)]] RWStructuredBuffer<Atomic<uint>> gVisibilityWork;

bool NearTriangle(float3 a, float3 b, float3 c)
{
	// Cheap separating planes reject room walls/floors before polygon clipping.
	for (uint plane = 0u; plane < 6u; plane++)
		if (max(PrimaryPlane(a, plane), max(PrimaryPlane(b, plane), PrimaryPlane(c, plane))) < 0.0) return false;
	float3 n = cross(b - a, c - a);
	float h = dot(n, a), radius = abs(n.x) + abs(n.y);
	float low = min(0.0, PRIMARY_NEAR * (n.z - radius));
	float high = max(0.0, PRIMARY_NEAR * (n.z + radius));
	float slack = 2e-6 * max(abs(h), PRIMARY_NEAR * length(n));
	if (h < low - slack || h > high + slack) return false;
	// Clip against the tiny near frustum, not an infinite near plane. Large floors
	// and walls crossing the eye plane must not disable rasterization unnecessarily.
	float3 polygon[12]; float3 next[12];
	polygon[0] = a; polygon[1] = b; polygon[2] = c;
	uint count = 3u;
	for (uint plane = 0u; plane < 6u; plane++)
	{
		uint n = 0u;
		for (uint i = 0u; i < count; i++)
		{
			float3 p = polygon[i], q = polygon[(i + 1u) % count];
			float dp = PrimaryPlane(p, plane), dq = PrimaryPlane(q, plane);
			if (dp >= 0.0 && n < 12u) next[n++] = p;
			if ((dp >= 0.0) != (dq >= 0.0) && n < 12u) next[n++] = lerp(p, q, dp / (dp - dq));
		}
		if (n == 0u) return false;
		count = n;
		for (uint j = 0u; j < count; j++) polygon[j] = next[j];
	}
	return true;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void Cull(uint3 tid : SV_DispatchThreadID)
{
	uint pair = tid.x + tid.y * (65535u * 64u);
	if (pair >= gFrame.primaryVisibility.z) return;
	uint pairBase = gFrame.primaryVisibility.y + pair * 2u;
	Instance inst = gInstances[gIndices[pairBase]];
	uint desc = gIndices[pairBase + 1u];
	float3 lo = asfloat(uint3(gIndices[desc], gIndices[desc + 1u], gIndices[desc + 2u]));
	float3 hi = asfloat(uint3(gIndices[desc + 4u], gIndices[desc + 5u], gIndices[desc + 6u]));
	float maxima[6];
	for (uint p = 0u; p < 6u; p++) maxima[p] = -3.402823466e+38;
	for (uint corner = 0u; corner < 8u; corner++)
	{
		float3 v = float3((corner & 1u) != 0u ? hi.x : lo.x, (corner & 2u) != 0u ? hi.y : lo.y, (corner & 4u) != 0u ? hi.z : lo.z);
		float3 q = PrimaryCameraPosition(TransformPoint(inst, v));
		for (uint p = 0u; p < 6u; p++) maxima[p] = max(maxima[p], PrimaryPlane(q, p));
	}
	// Conservative floating point slack for boxes on frustum boundaries.
	for (uint p = 0u; p < 5u; p++) if (maxima[p] < -1e-5) return;
	uint base = gFrame.primaryVisibility.x;
	uint offset = gVisibilityWork[base].add(1u);
	gVisibilityWork[base + 16u + offset].store(pair);
	if (maxima[5] < -1e-5) return;
	uint nearOffset = gVisibilityWork[base + 2u].add(1u);
	gVisibilityWork[base + 16u + gFrame.primaryVisibility.z + nearOffset].store(pair);
}

// Keep polygon scratch and triangle traversal out of the ordinary culling kernel.
[shader("compute")]
[numthreads(64, 1, 1)]
void CheckNear(uint3 tid : SV_DispatchThreadID)
{
	uint base = gFrame.primaryVisibility.x, index = tid.x + tid.y * (65535u * 64u);
	if (index >= gVisibilityWork[base + 2u].load()) return;
	uint pair = gVisibilityWork[base + 16u + gFrame.primaryVisibility.z + index].load();
	uint pairBase = gFrame.primaryVisibility.y + pair * 2u;
	Instance inst = gInstances[gIndices[pairBase]];
	uint desc = gIndices[pairBase + 1u];
	uint begin = gIndices[desc + 3u], count = gIndices[desc + 7u];
	for (uint i = 0u; i < count; i++)
	{
		uint3 tri = LoadTriangleIndices(inst, gIndices[begin + i]);
		float3 a = PrimaryCameraPosition(TransformPoint(inst, gVertices[tri.x].positionU.xyz));
		float3 b = PrimaryCameraPosition(TransformPoint(inst, gVertices[tri.y].positionU.xyz));
		float3 c = PrimaryCameraPosition(TransformPoint(inst, gVertices[tri.z].positionU.xyz));
		if (NearTriangle(a, b, c)) { gVisibilityWork[base + 1u].store(1u); return; }
	}
}

[shader("compute")]
[numthreads(1, 1, 1)]
void DrawArguments(uint3 tid : SV_DispatchThreadID)
{
	uint base = gFrame.primaryVisibility.x;
	gVisibilityWork[base + 4u].store(192u);
	gVisibilityWork[base + 5u].store(gVisibilityWork[base].load());
	gVisibilityWork[base + 6u].store(0u);
	gVisibilityWork[base + 7u].store(0u);
	uint groups = (gVisibilityWork[base + 2u].load() + 63u) / 64u;
	gVisibilityWork[base + 12u].store(min(groups, 65535u));
	gVisibilityWork[base + 13u].store(max(1u, (groups + 65534u) / 65535u));
	gVisibilityWork[base + 14u].store(1u);
	gVisibilityWork[base + 15u].store(0u);
}
