// Hit-point reconstruction and material evaluation: material bytecode -> BSDFInputs.
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.Textures;
import Materials.MaterialProgram;
import Materials.BSDF.BSDF;
import RayTracing.Traversal;

struct SurfaceInteraction
{
	float3 position;
	float3 faceNormal; // geometric normal, not flipped
	float3 normal;	   // interpolated normal, not flipped
	float4 tangent;
	TextureCoords tex;
	uint materialIndex;
	uint instanceIndex;
	uint primitiveIndex;
	bool frontFacing;

	float3 ComputeRayOrigin(bool viewSide)
	{
		float3 n = (frontFacing == viewSide) ? faceNormal : -faceNormal;
		return ComputeOffsetOrigin(position, n);
	}
};

// coneWidth: ray cone width at the hit, for texture mip selection.
SurfaceInteraction GetSurfaceInteraction(float3 rayDirection, HitRecord hit, float coneWidth)
{
	Instance inst = gInstances[hit.instanceIndex];
	uint3 tri = LoadTriangleIndices(inst, hit.primitiveIndex);
	Vertex v0 = gVertices[tri.x];
	Vertex v1 = gVertices[tri.y];
	Vertex v2 = gVertices[tri.z];
	float3 w = float3(1.0 - hit.barycentrics.x - hit.barycentrics.y, hit.barycentrics.x, hit.barycentrics.y);

	float3 p0 = v0.positionU.xyz;
	float3 p1 = v1.positionU.xyz;
	float3 p2 = v2.positionU.xyz;

	SurfaceInteraction si;
	si.instanceIndex = hit.instanceIndex;
	si.primitiveIndex = hit.primitiveIndex;
	si.materialIndex = inst.materialIndex;
	si.position = TransformPoint(inst, p0 * w.x + p1 * w.y + p2 * w.z);
	// normalize before the cross product for precision on small triangles
	float3 faceN = cross(normalize(p1 - p0), normalize(p2 - p0));
	si.faceNormal = normalize(TransformNormal(inst, faceN));

	float3 n = v0.normalV.xyz * w.x + v1.normalV.xyz * w.y + v2.normalV.xyz * w.z;
	si.normal = dot(n, n) > 0.0 ? normalize(TransformNormal(inst, n)) : si.faceNormal;

	float2 a0 = VertexUV0(v0), a1 = VertexUV0(v1), a2 = VertexUV0(v2);
	si.tex = MakeTextureCoords(
		a0 * w.x + a1 * w.y + a2 * w.z,
		v0.uv1.xy * w.x + v1.uv1.xy * w.y + v2.uv1.xy * w.z,
		TransformVector(inst, p1 - p0), TransformVector(inst, p2 - p0),
		a1 - a0, a2 - a0, v1.uv1.xy - v0.uv1.xy, v2.uv1.xy - v0.uv1.xy,
		coneWidth, dot(si.faceNormal, rayDirection));
	si.tex.objectPosition = p0 * w.x + p1 * w.y + p2 * w.z;

	si.frontFacing = dot(si.faceNormal, -rayDirection) > 0.0;

	float3 t = v0.tangent.xyz * w.x + v1.tangent.xyz * w.y + v2.tangent.xyz * w.z;
	t = dot(t, t) > 0.0 ? normalize(TransformVector(inst, t)) : float3(0.0);
	si.tangent = float4(t, v0.tangent.w);
	return si;
}

struct MaterialSample
{
	BSDFInputs inputs;
	float3 albedo;	  // base color, for the albedo AOV
	float roughness;  // specular roughness, for ray cone widening
	bool doubleSided;
	bool thinWalled;
};

// The BSDF tells front from back by the shading normal; keep it on the viewer's side of the face
// so that it agrees with the geometry (and with the medium the path is in).
float3 AlignWithFace(float3 n, float3 V, bool frontFacing)
{
	const float MIN_COS = 1e-4;
	float side = frontFacing ? 1.0 : -1.0;
	float cosV = dot(V, n) * side;
	if (cosV >= MIN_COS)
	{
		return n;
	}
	return normalize(n + V * (side * (MIN_COS - cosV)));
}

// Runs the material's surface program (Materials/MaterialProgram) and builds the shading frames.
MaterialSample EvalMaterial(SurfaceInteraction si, float3 V)
{
	MaterialHeader header = LoadMaterialHeader(si.materialIndex);
	MaterialContext ctx;
	ctx.tex = si.tex;
	ctx.position = si.position;
	ctx.normal = si.normal;
	ctx.tangent = si.tangent;
	ctx.instanceIndex = si.instanceIndex;
	MaterialOutputs o = MaterialOutputs.Default(ctx);
	if (header.surface != PROGRAM_NONE)
	{
		RunMaterialProgram<1>(header, header.surface, ctx, o);
	}

	MaterialSample ms;
	ms.inputs = o.inputs;
	ms.albedo = o.inputs.baseColor;
	ms.roughness = o.inputs.specularRoughness;
	ms.doubleSided = header.DoubleSided();
	ms.thinWalled = o.inputs.geometryThinWalled;

	// Meshes without vertex tangents have w = 0; a tangent computed by the program is still valid.
	float handedness = si.tangent.w != 0.0 ? si.tangent.w : 1.0;
	float3 n = AlignWithFace(o.normal, V, si.frontFacing);
	ms.inputs.basis = Frame.FromTangent(float4(o.tangent, handedness), n);
	if (all(o.coatNormal == o.normal) && all(o.coatTangent == o.tangent))
	{
		ms.inputs.coatBasis = ms.inputs.basis;
	}
	else
	{
		float3 coatN = AlignWithFace(o.coatNormal, V, si.frontFacing);
		ms.inputs.coatBasis = Frame.FromTangent(float4(o.coatTangent, handedness), coatN);
	}
	return ms;
}