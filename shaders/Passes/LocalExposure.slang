// Fused fine-residual Fusion local exposure (port of the LocalExposure project's optimized graph:
// fine_residual/initialize, compact/pyramid, compact/tail, fine_residual/reconstruct). Runs at
// quarter resolution after eye adaptation, like Unreal's AddLocalExposureFusionPass: the input is
// the accumulation with the GPU eye adaptation exposure applied. Present.slang restores the fine
// residual and inverts lightness at full resolution.
//
// Pyramid texels pack (darker - base, brighter - base) lightness residuals in xy and the darker /
// brighter weights - 0.5 in zw. Mips 0-2 are rgba16float, coarser mips rgba32float. The
// reconstruction (r32float, every mip) holds the weighted residual relative to the base exposure;
// its mip 0 is the low-resolution residual Present reads. The base lightness itself cancels out
// of the residual, so unlike the reference graph it is not stored.
import Scene.SceneTypes;
import LocalExposureCommon;

[[vk::binding(0, 0)]] ConstantBuffer<FrameUniforms> gFrame;
[[vk::binding(1, 0)]] StructuredBuffer<float4> gAccum;
[[vk::binding(2, 0)]] StructuredBuffer<float4> gExposure;
[[vk::binding(3, 0)]] ConstantBuffer<LocalExposureParams> gParams;
[[vk::binding(4, 0)]] Texture2D<float4> gForwardLut;
[[vk::binding(5, 0)]] Texture2D<float4> gReducedLut;
[[vk::binding(6, 0)]] Texture2D<float4> gFine;	   // pyramid level being processed
[[vk::binding(7, 0)]] Texture2D<float4> gCoarse;   // next coarser pyramid level
[[vk::binding(8, 0)]] Texture2D<float> gPrevious;  // reconstruction of the next coarser level
[[vk::binding(9, 0)]] Texture2D<float4> gMip2;	   // ReconstructFused only
[[vk::binding(10, 0)]] Texture2D<float4> gMip3;
[[vk::binding(11, 0)]] [format("rgba16f")] WTexture2D<float4> gPyramidHalfOut;
[[vk::binding(12, 0)]] [format("rgba32f")] WTexture2D<float4> gPyramidFloatOut;
[[vk::binding(13, 0)]] [format("r32f")] WTexture2D<float> gResultOut;
[[vk::binding(14, 0)]] ConstantBuffer<uint4> gLevel; // is coarsest, tail levels, unused, unused

// Bilinear accumulation fetch at a full-resolution uv (clamp to edge), like a texture sample.
float3 SampleAccum(float2 uv)
{
	uint2 size = gFrame.frame.xy;
	float2 pos = uv * float2(size) - 0.5;
	int2 base = int2(floor(pos));
	float2 f = pos - float2(base);
	int2 hi = int2(size) - 1;
	int2 p0 = clamp(base, int2(0), hi);
	int2 p1 = clamp(base + 1, int2(0), hi);
	float3 a = lerp(gAccum[(p0.y * size.x + p0.x) * 3].rgb, gAccum[(p0.y * size.x + p1.x) * 3].rgb, f.x);
	float3 b = lerp(gAccum[(p1.y * size.x + p0.x) * 3].rgb, gAccum[(p1.y * size.x + p1.x) * 3].rgb, f.x);
	return lerp(a, b, f.y);
}

// Four bilinear source samples per quarter-resolution texel; exposures and weights are evaluated
// on each sample before averaging.
[shader("compute")]
[numthreads(4, 8, 1)]
void Initialize(uint3 tid: SV_DispatchThreadID)
{
	uint w, h;
	gPyramidHalfOut.GetDimensions(w, h);
	if (tid.x >= w || tid.y >= h)
	{
		return;
	}
	// the accumulation holds radiance * pre-exposure; apply the adapted exposure instead
	float exposure = gExposure[0].x * rcp(gFrame.envParams.z);
	float2 residual = float2(0.0);
	float2 weights = float2(0.0);
	for (uint y = 0u; y < 2u; y++)
	{
		for (uint x = 0u; x < 2u; x++)
		{
			float2 uv = (float2(tid.xy) + (float2(x, y) + 0.5) / 2.0) / float2(w, h);
			float3 rgb = max(SampleAccum(uv), 0.0) * exposure;
			float position = ForwardTablePosition(EyeAdaptationLuminance(gParams, rgb));
			residual += SampleTable(gReducedLut, FORWARD_LUT_SIZE, position).xy;
			weights += SampleTable(gForwardLut, FORWARD_LUT_SIZE, position).yz;
		}
	}
	gPyramidHalfOut.Store(tid.xy, float4(residual * 0.25, weights * 0.25 - 0.5));
}

// Unreal Fusion four-tap downsampling of residuals and weights together.
float4 DownsampleTap(uint2 pixel, uint2 size)
{
	uint2 inputSize;
	gFine.GetDimensions(inputSize.x, inputSize.y);
	float2 uv = (float2(pixel) + 0.5) / float2(size);
	float2 texel = 1.0 / float2(inputSize);
	float4 a = SampleBilinear(gFine, uv + texel * float2(-1.0, -1.0));
	a += SampleBilinear(gFine, uv + texel * float2(1.0, -1.0));
	a += SampleBilinear(gFine, uv + texel * float2(-1.0, 1.0));
	a += SampleBilinear(gFine, uv + texel * float2(1.0, 1.0));
	return a * 0.25;
}

[shader("compute")]
[numthreads(4, 16, 1)]
void DownsampleHalf(uint3 tid: SV_DispatchThreadID)
{
	uint w, h;
	gPyramidHalfOut.GetDimensions(w, h);
	if (tid.x < w && tid.y < h)
	{
		gPyramidHalfOut.Store(tid.xy, DownsampleTap(tid.xy, uint2(w, h)));
	}
}

[shader("compute")]
[numthreads(4, 16, 1)]
void DownsampleFloat(uint3 tid: SV_DispatchThreadID)
{
	uint w, h;
	gPyramidFloatOut.GetDimensions(w, h);
	if (tid.x < w && tid.y < h)
	{
		gPyramidFloatOut.Store(tid.xy, DownsampleTap(tid.xy, uint2(w, h)));
	}
}

// Small pyramid tail (base at most 16x8) reduced and reconstructed within one workgroup. The
// arrays keep the original 32x16 capacity. Shared-memory bilinear replaces texture filtering.
groupshared float tailResidual0[683];
groupshared float tailResidual1[683];
groupshared float2 tailWeights[683];
groupshared float tailResult[683];

// half rounding without the WGSL f16 extension
float2 RoundToHalf(float2 v)
{
	return float2(f16tof32(f32tof16(v.x)), f16tof32(f32tof16(v.y)));
}

struct TailSample
{
	float2 residual;
	float2 weights;
	float reconstruction;
};

TailSample SampleTail(uint offset, uint2 size, float2 uv, bool readResult)
{
	float2 pos = uv * float2(size) - 0.5;
	int2 base = int2(floor(pos));
	float2 f = pos - float2(base);
	int2 p0 = clamp(base, int2(0), int2(size) - 1);
	int2 p1 = clamp(base + 1, int2(0), int2(size) - 1);
	uint a = offset + p0.y * size.x + p0.x;
	uint b = offset + p0.y * size.x + p1.x;
	uint c = offset + p1.y * size.x + p0.x;
	uint d = offset + p1.y * size.x + p1.x;
	TailSample value;
	float2 ra = float2(tailResidual0[a], tailResidual1[a]);
	float2 rb = float2(tailResidual0[b], tailResidual1[b]);
	float2 rc = float2(tailResidual0[c], tailResidual1[c]);
	float2 rd = float2(tailResidual0[d], tailResidual1[d]);
	value.residual = lerp(lerp(ra, rb, f.x), lerp(rc, rd, f.x), f.y);
	value.weights = lerp(lerp(tailWeights[a], tailWeights[b], f.x), lerp(tailWeights[c], tailWeights[d], f.x), f.y);
	value.reconstruction = readResult ? lerp(lerp(tailResult[a], tailResult[b], f.x), lerp(tailResult[c], tailResult[d], f.x), f.y) : 0.0;
	return value;
}

[shader("compute")]
[numthreads(16, 8, 1)]
void Tail(uint3 local: SV_GroupThreadID)
{
	uint w, h;
	gResultOut.GetDimensions(w, h);
	uint tailLevels = gLevel.y;
	uint levelOffset = 0u;
	uint2 currentSize = uint2(w, h);
	for (uint y = local.y; y < h; y += 8u)
	{
		for (uint x = local.x; x < w; x += 16u)
		{
			uint i = y * w + x;
			float4 texel = gFine.Load(int3(int(x), int(y), 0));
			tailResidual0[i] = texel.x;
			tailResidual1[i] = texel.y;
			tailWeights[i] = texel.zw + 0.5;
		}
	}
	GroupMemoryBarrierWithGroupSync();
	for (uint m = 1u; m < tailLevels; m++)
	{
		uint2 previous = currentSize;
		uint previousOffset = levelOffset;
		currentSize = max(previous / 2u, uint2(1u));
		levelOffset += previous.x * previous.y;
		uint2 size = currentSize;
		for (uint y = local.y; y < size.y; y += 8u)
		{
			for (uint x = local.x; x < size.x; x += 16u)
			{
				uint index = levelOffset + y * size.x + x;
				float2 uv = (float2(x, y) + 0.5) / float2(size);
				float2 texel = 1.0 / float2(previous);
				TailSample a = SampleTail(previousOffset, previous, uv + texel * float2(-1.0, -1.0), false);
				TailSample b = SampleTail(previousOffset, previous, uv + texel * float2(1.0, -1.0), false);
				TailSample c = SampleTail(previousOffset, previous, uv + texel * float2(-1.0, 1.0), false);
				TailSample d = SampleTail(previousOffset, previous, uv + texel * float2(1.0, 1.0), false);
				// keep the reference pyramid's per-level half residual / unorm16 weight rounding
				float2 residual = RoundToHalf((((a.residual + b.residual) + c.residual) + d.residual) * 0.25);
				tailResidual0[index] = residual.x;
				tailResidual1[index] = residual.y;
				float2 weights = (((a.weights + b.weights) + c.weights) + d.weights) * 0.25;
				tailWeights[index] = floor(saturate(weights) * 65535.0 + 0.5) / 65535.0;
				// the coarsest level is a weighted base, evaluated here with the stored values
				if (m == tailLevels - 1u)
				{
					float2 contribution = residual * tailWeights[index];
					tailResult[index] = contribution.x + contribution.y;
				}
			}
		}
		GroupMemoryBarrierWithGroupSync();
	}
	int firstReverse = int(tailLevels) - 1;
	if (firstReverse > 0)
	{
		firstReverse--;
		uint2 size = max(uint2(w, h) >> uint(firstReverse), uint2(1u));
		levelOffset -= size.x * size.y;
	}
	for (int m = firstReverse; m >= 0; m--)
	{
		uint2 size = max(uint2(w, h) >> uint(m), uint2(1u));
		uint2 coarseSize = max(size / 2u, uint2(1u));
		uint coarseOffset = levelOffset + size.x * size.y;
		bool coarsest = m == int(tailLevels) - 1;
		for (uint y = local.y; y < size.y; y += 8u)
		{
			for (uint x = local.x; x < size.x; x += 16u)
			{
				uint index = levelOffset + y * size.x + x;
				float2 detail = float2(tailResidual0[index], tailResidual1[index]);
				float previousValue = 0.0;
				if (!coarsest)
				{
					TailSample coarse = SampleTail(coarseOffset, coarseSize, (float2(x, y) + 0.5) / float2(size), true);
					detail -= coarse.residual;
					previousValue = coarse.reconstruction;
				}
				float2 contribution = detail * tailWeights[index];
				float value = (contribution.x + contribution.y) + previousValue;
				if (m == 0)
				{
					gResultOut.Store(uint2(x, y), value);
				}
				else
				{
					tailResult[index] = value;
				}
			}
		}
		if (m > 0)
		{
			GroupMemoryBarrierWithGroupSync();
			uint2 finer = max(uint2(w, h) >> uint(m - 1), uint2(1u));
			levelOffset -= finer.x * finer.y;
		}
	}
}

// Weighted Laplacian residual of one level plus the upsampled coarser reconstruction.
[shader("compute")]
[numthreads(8, 8, 1)]
void Reconstruct(uint3 tid: SV_DispatchThreadID)
{
	uint w, h;
	gResultOut.GetDimensions(w, h);
	if (tid.x >= w || tid.y >= h)
	{
		return;
	}
	bool coarsest = gLevel.x != 0u;
	float2 uv = (float2(tid.xy) + 0.5) / float2(w, h);
	float4 fine = gFine.Load(int3(int2(tid.xy), 0));
	float2 detail = fine.xy;
	float value = 0.0;
	if (!coarsest)
	{
		detail -= SampleBilinear(gCoarse, uv).xy;
		value = SampleBilinear(gPrevious, uv);
	}
	float2 contribution = detail * (fine.zw + 0.5);
	gResultOut.Store(tid.xy, contribution.x + contribution.y + value);
}

// Fuses reconstruction levels 2 -> 1 -> 0 (given the reconstructed mip 3). A 16x16 output tile
// needs a 10x10 mip-1 and a 7x7 mip-2 halo; overlapping halos are recomputed instead of two
// global round trips and dispatch barriers.
groupshared float mip2Result[49];
groupshared float mip1Result[100];

[shader("compute")]
[numthreads(16, 16, 1)]
void ReconstructFused(uint3 tid: SV_DispatchThreadID, uint3 local: SV_GroupThreadID, uint3 group: SV_GroupID)
{
	uint w, h, pw, ph, gw, gh;
	gResultOut.GetDimensions(w, h);
	gCoarse.GetDimensions(pw, ph);
	gMip2.GetDimensions(gw, gh);
	int2 origin = int2(group.xy * 16u);
	int2 mip1Origin = int2(floor((float2(origin) + 0.5) * float2(pw, ph) / float2(w, h) - 0.5));
	int2 mip2Origin = int2(floor((float2(mip1Origin) + 0.5) * float2(gw, gh) / float2(pw, ph) - 0.5));
	uint lane = local.y * 16u + local.x;
	if (lane < 49u)
	{
		int2 p = clamp(mip2Origin + int2(int(lane % 7u), int(lane / 7u)), int2(0), int2(int(gw) - 1, int(gh) - 1));
		float2 uv = (float2(p) + 0.5) / float2(gw, gh);
		float4 texel = gMip2.Load(int3(p, 0));
		float2 contribution = (texel.xy - SampleBilinear(gMip3, uv).xy) * (texel.zw + 0.5);
		mip2Result[lane] = contribution.x + contribution.y + SampleBilinear(gPrevious, uv);
	}
	GroupMemoryBarrierWithGroupSync();
	if (lane < 100u)
	{
		int2 p = clamp(mip1Origin + int2(int(lane % 10u), int(lane / 10u)), int2(0), int2(int(pw) - 1, int(ph) - 1));
		float2 uv = (float2(p) + 0.5) / float2(pw, ph);
		float4 texel = gCoarse.Load(int3(p, 0));
		float2 contribution = (texel.xy - SampleBilinear(gMip2, uv).xy) * (texel.zw + 0.5);
		float2 pos = uv * float2(gw, gh) - 0.5;
		int2 ip = int2(floor(pos)) - mip2Origin;
		float2 f = frac(pos);
		uint index = uint(ip.y * 7 + ip.x);
		float previous = lerp(lerp(mip2Result[index], mip2Result[index + 1u], f.x), lerp(mip2Result[index + 7u], mip2Result[index + 8u], f.x), f.y);
		mip1Result[lane] = contribution.x + contribution.y + previous;
	}
	GroupMemoryBarrierWithGroupSync();
	if (tid.x >= w || tid.y >= h)
	{
		return;
	}
	float2 uv = (float2(tid.xy) + 0.5) / float2(w, h);
	float2 pos = uv * float2(pw, ph) - 0.5;
	int2 ip = int2(floor(pos)) - mip1Origin;
	float2 f = frac(pos);
	uint index = uint(ip.y * 10 + ip.x);
	float previous = lerp(lerp(mip1Result[index], mip1Result[index + 1u], f.x), lerp(mip1Result[index + 10u], mip1Result[index + 11u], f.x), f.y);
	float4 texel = gFine.Load(int3(int2(tid.xy), 0));
	float2 contribution = (texel.xy - SampleBilinear(gCoarse, uv).xy) * (texel.zw + 0.5);
	gResultOut.Store(tid.xy, contribution.x + contribution.y + previous);
}
