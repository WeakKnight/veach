import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Passes.PrimaryCamera;

[[vk::binding(0, 1)]] StructuredBuffer<uint> gVisibilityWork;

struct VisibilityVertex
{
	float4 position : SV_Position;
	nointerpolation uint2 ids : TEXCOORD0;
};

[shader("vertex")]
VisibilityVertex vsMain(uint vertex : SV_VertexID, uint cluster : SV_InstanceID)
{
	VisibilityVertex result;
	result.position = float4(2.0, 2.0, 0.0, 1.0);
	result.ids = uint2(0xffffffffu);
	uint pair = gVisibilityWork[gFrame.primaryVisibility.x + 16u + cluster];
	uint pairBase = gFrame.primaryVisibility.y + pair * 2u;
	uint instanceIndex = gIndices[pairBase], desc = gIndices[pairBase + 1u];
	if (vertex / 3u >= gIndices[desc + 7u]) return result;
	uint primitive = gIndices[gIndices[desc + 3u] + vertex / 3u];
	Instance inst = gInstances[instanceIndex];
	uint index = gIndices[inst.indexOffset + primitive * 3u + vertex % 3u] + inst.vertexOffset;
	float3 q = PrimaryCameraPosition(TransformPoint(inst, gVertices[index].positionU.xyz));
	result.position = float4(q.xy, PRIMARY_NEAR, q.z);
	result.ids = uint2(instanceIndex, primitive);
	return result;
}

[shader("fragment")]
uint2 fsMain(VisibilityVertex input) : SV_Target0 { return input.ids; }
