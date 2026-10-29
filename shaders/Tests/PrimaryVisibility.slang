// GPU validation only. Run after primary intersection, before ordinary shading.
// Shadow slots are unused here and will be overwritten by the production shade pass.
import Passes.Wavefront;
import Passes.PathTracing;
import RayTracing.Traversal;
import Scene.SceneBindings;
import Scene.SceneTypes;
import Materials.MaterialSample;

[shader("compute")]
[numthreads(64, 1, 1)]
void InspectPrimarySurface(uint3 tid : SV_DispatchThreadID)
{
	if (tid.x >= gWavefront.pathCount) return;
	uint base = WorkBase(tid.x);
	WavefrontPath s = LoadPath(base);
	for (uint field = 10u; field <= 13u; field++) gAccum[Field(base, field)] = float4(0.0);
	if (s.active == 0u) return;
	float4 data = gAccum[Field(base, 8u)];
	HitRecord hit;
	hit.t = data.x; hit.barycentrics = data.yz; hit.instanceIndex = asuint(data.w);
	hit.primitiveIndex = asuint(gAccum[Field(base, 9u)].x);
	LoadFeedbackState(base);
	SurfaceInteraction si = GetSurfaceInteraction(s.path.direction, hit, s.path.coneWidth + hit.t * s.path.coneSpread);
	MaterialSample ms = EvalMaterial(si, -s.path.direction);
	gAccum[Field(base, 10u)] = float4(si.tex.uv0, si.tex.uv1);
	gAccum[Field(base, 11u)] = float4(si.normal, float(si.materialIndex));
	gAccum[Field(base, 12u)] = float4(ms.albedo, ms.roughness);
	gAccum[Field(base, 13u)] = float4(ms.inputs.basis.n, 0.0);
}
