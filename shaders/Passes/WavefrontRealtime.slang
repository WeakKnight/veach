// Realtime SSSR frames (docs/Sssr.md): the path tracer provides diffuse lighting only, FidelityFX SSSR all
// specular reflection. FRAME_FLAG_DIFFUSE_ONLY is set only for realtime wavefront frames with SSSR; offline
// (progressive) frames and the megakernel never see it, so these helpers leave them unchanged.
// Only the primary vertex changes: later bounces keep the full BSDF, since the diffuse lighting of the
// primary surface integrates all incident radiance.
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Materials.MaterialSample;
import Materials.BSDF.BSDF;
import Materials.BSDF.BSDFCommon;

bool DiffuseOnlyFrame()
{
	return (gFrame.settings.z & FRAME_FLAG_DIFFUSE_ONLY) != 0u;
}

// Transmissive materials keep the full BSDF at the primary vertex: neither diffuse lighting nor SSSR
// provides refraction. Their reflected specular is still dropped (Finalize).
bool DiffuseOnlyVertex(bool primary, MaterialSample ms)
{
	return primary && DiffuseOnlyFrame() && ms.inputs.transmissionWeight <= 0.0;
}

// Cosine hemisphere around the oriented shading normal n.
float DiffuseOnlyPdf(float3 n, float3 wi)
{
	return max(dot(n, wi), 0.0) * INV_PI;
}

// Next event estimation at a diffuse-only vertex: the diffuse part, with MIS against the cosine
// continuation of SampleDiffuseOnly.
void DiffuseOnlyLight(float3 n, float3 wi, inout DiffuseSpecular f, inout float pdf)
{
	f.specular = float3(0.0);
	pdf = DiffuseOnlyPdf(n, wi);
}

// Continuation of a diffuse-only vertex: cosine hemisphere, weighted by the diffuse part of the BSDF
// (EvalPdf returns f * |cos|, coat and fuzz attenuation included).
LobeSample SampleDiffuseOnly(BSDF bsdf, float3 n, float2 u)
{
	float3 wi = Frame.FromNormal(n).ToWorld(SampleCosineHemisphere(u));
	float pdf = DiffuseOnlyPdf(n, wi);
	if (pdf <= 0.0) return LobeSample.Invalid();
	DiffuseSpecular f; float unused;
	bsdf.EvalPdf(wi, f, unused);
	return LobeSample.Make(wi, DiffuseSpecular(f.diffuse / pdf, float3(0.0)), pdf, LOBE_REFLECTION | LOBE_DIFFUSE);
}
