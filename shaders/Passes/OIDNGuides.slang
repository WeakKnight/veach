// Sample-matched OIDN inputs from the path tracer's running averages.
// A separate pass keeps the scene's eight-storage-buffer layout unchanged.
import Scene.SceneTypes;

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] StructuredBuffer<float4> gAccum;
[[vk::binding(2, 0)]] RWStructuredBuffer<float4> gColor;
[[vk::binding(3, 0)]] RWStructuredBuffer<float4> gAlbedo;
[[vk::binding(4, 0)]] RWStructuredBuffer<float4> gNormal;
[[vk::binding(5, 0)]] StructuredBuffer<float4> gDenoised;
[[vk::binding(6, 0)]] RWStructuredBuffer<float4> gPresentation;

float3 FiniteOrZero(float3 v)
{
	return float3(isfinite(v.x) ? v.x : 0.0, isfinite(v.y) ? v.y : 0.0, isfinite(v.z) ? v.z : 0.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void Prepare(uint3 tid : SV_DispatchThreadID)
{
	if (any(tid.xy >= gFrame.frame.xy)) return;
	uint i = tid.y * gFrame.frame.x + tid.x;
	// Retain the fixed accumulation pre-exposure; do not apply display exposure or a LUT.
	gColor[i] = float4(max(FiniteOrZero(gAccum[i * 3u].rgb), 0.0), 1.0);
	gAlbedo[i] = float4(saturate(FiniteOrZero(gAccum[i * 3u + 1u].rgb)), 1.0);
	// World-space, signed averaged shading normals -> oidn-webgpu's [0,1] convention.
	// Do not renormalize averaged normals: their length retains AA/DOF coverage information.
	// A background miss is (0,0,0), encoded as (0.5,0.5,0.5).
	gNormal[i] = float4(saturate(FiniteOrZero(gAccum[i * 3u + 2u].rgb) * 0.5 + 0.5), 1.0);
}

[shader("compute")]
[numthreads(8, 8, 1)]
void Compose(uint3 tid : SV_DispatchThreadID)
{
	if (any(tid.xy >= gFrame.frame.xy)) return;
	uint i = tid.y * gFrame.frame.x + tid.x;
	gPresentation[i * 3u] = float4(max(FiniteOrZero(gDenoised[i].rgb), 0.0), 1.0);
	gPresentation[i * 3u + 1u] = gAccum[i * 3u + 1u];
	gPresentation[i * 3u + 2u] = gAccum[i * 3u + 2u];
}
