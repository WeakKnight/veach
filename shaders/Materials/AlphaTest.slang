// Any-hit style alpha testing, evaluated inside BVH traversal for non-opaque instances.
import Common.Random;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.Textures;
import Materials.VirtualTexture;
import Materials.MaterialProgram;

// Returns true when the candidate hit must be ignored.
bool AlphaTestRejects(Instance inst, uint primitiveIndex, float2 barycentrics, float t)
{
	MaterialHeader material = LoadMaterialHeader(inst.materialIndex);
	if (material.AlphaMode() == ALPHA_MODE_OPAQUE)
	{
		return false;
	}

	uint3 tri = LoadTriangleIndices(inst, primitiveIndex);
	Vertex v0 = gVertices[tri.x];
	Vertex v1 = gVertices[tri.y];
	Vertex v2 = gVertices[tri.z];
	float3 w = float3(1.0 - barycentrics.x - barycentrics.y, barycentrics.x, barycentrics.y);
	float2 a0 = VertexUV0(v0), a1 = VertexUV0(v1), a2 = VertexUV0(v2);
	TextureCoords tc = MakeTextureCoords(
		a0 * w.x + a1 * w.y + a2 * w.z,
		v0.uv1.xy * w.x + v1.uv1.xy * w.y + v2.uv1.xy * w.z,
		TransformVector(inst, v1.positionU.xyz - v0.positionU.xyz),
		TransformVector(inst, v2.positionU.xyz - v0.positionU.xyz),
		a1 - a0, a2 - a0, v1.uv1.xy - v0.uv1.xy, v2.uv1.xy - v0.uv1.xy,
		gRayCone.x + gRayCone.y * t, 1.0);
	tc.objectPosition = v0.positionU.xyz * w.x + v1.positionU.xyz * w.y + v2.positionU.xyz * w.z;
	float opacity = EvalOpacity(material, tc);

	if (material.AlphaMode() == ALPHA_MODE_MASK)
	{
		return opacity < material.alphaCutoff;
	}

	// Blend: stochastic transparency, decorrelated per hit and per frame.
	uint h = StrongIntegerHash(primitiveIndex ^ StrongIntegerHash(asuint(t) ^ gFrame.frame.w));
	return opacity < float(h & 0xFFFFFFu) * 5.96046447754e-08;
}
