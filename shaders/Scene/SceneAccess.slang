// Instance transforms and mesh fetches.
import Scene.SceneTypes;
import Scene.SceneBindings;

float3 TransformPoint(Instance inst, float3 p)
{
	return float3(
		dot(inst.objectToWorld[0].xyz, p) + inst.objectToWorld[0].w,
		dot(inst.objectToWorld[1].xyz, p) + inst.objectToWorld[1].w,
		dot(inst.objectToWorld[2].xyz, p) + inst.objectToWorld[2].w);
}

float3 TransformVector(Instance inst, float3 v)
{
	return float3(dot(inst.objectToWorld[0].xyz, v), dot(inst.objectToWorld[1].xyz, v), dot(inst.objectToWorld[2].xyz, v));
}

// Inverse transpose, so normals stay perpendicular under non-uniform scale.
float3 TransformNormal(Instance inst, float3 n)
{
	return inst.worldToObject[0].xyz * n.x + inst.worldToObject[1].xyz * n.y + inst.worldToObject[2].xyz * n.z;
}

float3 InverseTransformPoint(Instance inst, float3 p)
{
	return float3(
		dot(inst.worldToObject[0].xyz, p) + inst.worldToObject[0].w,
		dot(inst.worldToObject[1].xyz, p) + inst.worldToObject[1].w,
		dot(inst.worldToObject[2].xyz, p) + inst.worldToObject[2].w);
}

float3 InverseTransformVector(Instance inst, float3 v)
{
	return float3(dot(inst.worldToObject[0].xyz, v), dot(inst.worldToObject[1].xyz, v), dot(inst.worldToObject[2].xyz, v));
}

// Global vertex indices of a triangle.
uint3 LoadTriangleIndices(Instance inst, uint primitiveIndex)
{
	uint base = inst.indexOffset + primitiveIndex * 3u;
	return uint3(gIndices[base], gIndices[base + 1u], gIndices[base + 2u]) + inst.vertexOffset;
}

float2 VertexUV0(Vertex v)
{
	return float2(v.positionU.w, v.normalV.w);
}
