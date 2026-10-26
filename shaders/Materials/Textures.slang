// Material texture sampling through the virtual texture system (Materials/VirtualTexture.slang).
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Materials.VirtualTexture;

// Texture coordinates of a surface point plus the ray cone footprint for mip selection.
struct TextureCoords
{
	float2 uv0;
	float2 uv1;
	float footprint0; // UVFootprintLog2 for TEXCOORD_0
	float footprint1; // UVFootprintLog2 for TEXCOORD_1
	float3 objectPosition;
};

bool HasTexture(TextureRef ref)
{
	return (ref.flags & TEXTURE_FLAG_VALID) != 0u;
}

float WrapCoord(float x, uint mode)
{
	if (mode == WRAP_CLAMP)
	{
		return saturate(x);
	}
	if (mode == WRAP_MIRROR)
	{
		float t = x - 2.0 * floor(x * 0.5);
		return t > 1.0 ? 2.0 - t : t;
	}
	return frac(x);
}

// KHR_texture_transform: T * R * S.
float2 TransformUV(TextureRef ref, float2 uv)
{
	float2 s = ref.scaleOffset.xy * uv;
	float c = cos(ref.rotation);
	float r = sin(ref.rotation);
	return float2(c * s.x + r * s.y, -r * s.x + c * s.y) + ref.scaleOffset.zw;
}

float4 SampleTexture(TextureRef ref, TextureCoords tc)
{
	bool useUV1 = (ref.flags & TEXTURE_FLAG_TEXCOORD1) != 0u;
	float2 uv = TransformUV(ref, useUV1 ? tc.uv1 : tc.uv0);
	uv.x = WrapCoord(uv.x, (ref.flags >> 8u) & 3u);
	uv.y = WrapCoord(uv.y, (ref.flags >> 10u) & 3u);

	float4 color = SampleVirtualTexture(ref, uv, useUV1 ? tc.footprint1 : tc.footprint0);
	if ((ref.flags & TEXTURE_FLAG_SRGB) != 0u)
	{
		color.rgb = SrgbToLinear(color.rgb);
	}
	return color;
}

// Ray cone footprint on a triangle for both uv sets.
TextureCoords MakeTextureCoords(float2 uv0, float2 uv1, float3 worldE1, float3 worldE2, float2 uv0E1, float2 uv0E2, float2 uv1E1, float2 uv1E2, float coneWidth, float cosTheta)
{
	TextureCoords tc;
	tc.uv0 = uv0;
	tc.uv1 = uv1;
	tc.objectPosition = float3(0.0);
	float worldArea = length(cross(worldE1, worldE2));
	tc.footprint0 = UVFootprintLog2(coneWidth, worldArea, abs(uv0E1.x * uv0E2.y - uv0E1.y * uv0E2.x), cosTheta);
	tc.footprint1 = UVFootprintLog2(coneWidth, worldArea, abs(uv1E1.x * uv1E2.y - uv1E1.y * uv1E2.x), cosTheta);
	return tc;
}
