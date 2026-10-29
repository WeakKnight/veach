// GPU scene layout. Must stay in sync with src/render/GpuLayout.ts.
// Every struct is a sequence of 16-byte groups so the std430 (storage) and std140 (uniform)
// layouts are identical.

// tinybvh BVH_GPU node (Aila & Laine): child bounds are stored in the parent. A child reference
// with the top bit set is a leaf: bits 24..30 hold the primitive count, bits 0..23 the offset.
struct BVHNode
{
	float3 lmin;
	uint left;
	float3 lmax;
	uint right;
	float3 rmin;
	uint triCount;
	float3 rmax;
	uint firstTri;
};

static const uint INSTANCE_FLAG_ALPHA_TESTED = 1u;
static const uint INSTANCE_FLAG_EMISSIVE = 2u;

// One TLAS entry: a mesh primitive (one material) placed in the world.
struct Instance
{
	float4 objectToWorld[3]; // rows of a 3x4 affine matrix
	float4 worldToObject[3];
	uint blasNodeOffset;	 // into gNodes
	uint blasTriOffset;		 // into gTris, in triangles (3 float4 each)
	uint indexOffset;		 // into gIndices
	uint vertexOffset;		 // into gVertices
	uint materialIndex;
	uint flags;
	uint lightOffset;		 // first EmissiveTriangle of this instance (INSTANCE_FLAG_EMISSIVE)
	uint triCount;
};

struct Vertex
{
	float4 positionU;	 // xyz position, w = uv0.x
	float4 normalV;		 // xyz normal, w = uv0.y
	float4 tangent;		 // xyz tangent, w = handedness (0 = no tangent)
	float4 uv1;			 // xy = TEXCOORD_1
};

static const uint TEXTURE_FLAG_VALID = 1u;
static const uint TEXTURE_FLAG_SRGB = 2u;
static const uint TEXTURE_FLAG_TEXCOORD1 = 4u;
// bits 8..9 wrapS, 10..11 wrapT, 12..15 virtual mip levels, 16..19 log2 width, 20..23 log2 height
static const uint WRAP_REPEAT = 0u;
static const uint WRAP_CLAMP = 1u;
static const uint WRAP_MIRROR = 2u;

// A virtual texture (see Materials/VirtualTexture.slang) plus its glTF sampling state.
struct TextureRef
{
	uint flags;
	uint pageTableOffset; // first page table entry (mip 0, page 0)
	uint reserved;
	float rotation;		  // KHR_texture_transform
	float4 scaleOffset;	  // KHR_texture_transform: xy scale, zw offset
};

static const uint ALPHA_MODE_OPAQUE = 0u;
static const uint ALPHA_MODE_MASK = 1u;
static const uint ALPHA_MODE_BLEND = 2u;

static const uint MATERIAL_FLAG_DOUBLE_SIDED = 1u;

// Materials are bytecode in gMaterialData (Materials/MaterialProgram.slang): a 2 x uint4 header per
// material, then texture tables (TextureRef), constant pools and programs.
static const uint PROGRAM_NONE = 0xffffffffu;

// World-space emissive triangle used for next event estimation.
struct EmissiveTriangle
{
	float4 p0;	 // w = area
	float4 p1;	 // w = selection pdf
	float4 p2;	 // w = cdf (inclusive)
	float4 n;	 // xyz unit normal, w = asfloat(materialIndex)
	float4 uvA;	 // v0.uv0, v1.uv0
	float4 uvB;	 // v2.uv0, v0.uv1
	float4 uvC;	 // v1.uv1, v2.uv1
	float4 pad;	 // x = asfloat(instanceIndex), for object-space material inputs
};

// Analytic lights share the light buffer (the first counts.w entries) and its power CDF. They are
// not in the BVH: they never occlude, and BSDF rays test them separately (Lights.slang).
//   p0: xyz position, w = radius (point / spot, 0 = delta) or area (area light)
//   p1: xyz radiance (intensity for delta lights), w = selection pdf
//   p2: xyz emission direction (spot axis, area normal), w = cdf
//   n:  xyz area extent u, w = asfloat(LIGHT_ANALYTIC | flags | type)
//   uvA: xyz area extent v, w = cos(half spot angle)
//   uvB: x = spot smoothstep scale (0 = hard edge)
static const uint LIGHT_ANALYTIC = 0x80000000u;
static const uint LIGHT_HIDDEN_FROM_CAMERA = 0x100u;
static const uint LIGHT_ELLIPSE = 0x200u;
static const uint LIGHT_NO_SHADOW = 0x400u;
static const uint LIGHT_TYPE_MASK = 0xffu;
static const uint LIGHT_TYPE_POINT = 0u;
static const uint LIGHT_TYPE_SPOT = 1u;
static const uint LIGHT_TYPE_AREA = 2u;

static const uint FRAME_FLAG_ENVIRONMENT = 1u;
static const uint FRAME_FLAG_SUN = 2u;
static const uint FRAME_FLAG_ENV_IMPORTANCE = 4u;
static const uint FRAME_FLAG_ENV_VISIBLE = 8u;

static const uint DEBUG_NONE = 0u;
static const uint DEBUG_ALBEDO = 1u;
static const uint DEBUG_SHADING_NORMAL = 2u;
static const uint DEBUG_GEOMETRY_NORMAL = 3u;
static const uint DEBUG_UV = 4u;
static const uint DEBUG_INSTANCE = 5u;
static const uint DEBUG_MATERIAL = 6u;
static const uint DEBUG_TRAVERSAL = 7u;
static const uint DEBUG_EMISSION = 8u;
static const uint DEBUG_VIRTUAL_TEXTURE = 9u; // mapped mip level of the base color texture; red = pending

static const uint TONEMAP_NONE = 0u;
static const uint TONEMAP_ACES_FILMIC = 1u;
static const uint TONEMAP_ACES2 = 2u;

struct FrameUniforms
{
	float4 cameraPosition; // w = lens radius
	float4 cameraRight;	   // scaled by tan(fovY / 2) * aspect, w = focus distance
	float4 cameraUp;	   // scaled by tan(fovY / 2)
	float4 cameraForward;

	uint4 frame;	// width, height, frameIndex, seed
	uint4 settings; // maxBounces, debugMode, flags, tonemapper
	uint4 counts;	// instanceCount, lightCount, tlasPrimOffset, analytic light count
	uint4 envInfo;	// cdf width, cdf height, TLAS node base, unused

	float4 sunDirection; // toward the sun, w = cos(angular radius)
	float4 sunRadiance;	 // rgb radiance, w = solid angle
	float4 envParams;	 // intensity, rotation (radians), pre-exposure, firefly clamp (pre-exposed, 0 = off)
	float4 background;	 // rgb used when the environment is hidden from camera rays

	uint4 vtInfo;	 // physical pages per row, page table width, feedback jitter (x | y << 16), feedback shift
	float4 vtParams; // 1 / physical size, pixel spread angle (radians), mip bias, unused
};
