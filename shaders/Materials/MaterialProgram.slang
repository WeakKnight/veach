// Material bytecode interpreter (docs/MaterialSystem.md). Mirrors src/material/Interpreter.ts; the
// encoding is defined in src/material/Bytecode.ts and the gMaterialData layout in
// src/render/GpuLayout.ts (packMaterialData).
import Common.Math;
import Scene.SceneTypes;
import Scene.SceneBindings;
import Scene.SceneAccess;
import Materials.Textures;
import Materials.Procedural;
import Materials.BSDF.BSDF;

// Specialized builds are valid only when every compiled program fits this capacity.
// The production fallback matches MAX_STACK_SIZE in src/material/Bytecode.ts.
#ifndef VEACH_MATERIAL_STACK_SIZE
#define VEACH_MATERIAL_STACK_SIZE 16
#endif
static const uint MATERIAL_STACK_SIZE = VEACH_MATERIAL_STACK_SIZE;
static const uint MATERIAL_MAX_INSTRUCTIONS = 1024u; // a malformed program must not hang the device

static const uint OPERAND_CONSTANT = 0x80000000u;
static const uint OPERAND_NONE = 0xffffffffu;

static const uint OP_END = 0u;
static const uint OP_ADD = 1u;
static const uint OP_SUB = 2u;
static const uint OP_MUL = 3u;
static const uint OP_DIV = 4u;
static const uint OP_MIN = 5u;
static const uint OP_MAX = 6u;
static const uint OP_POW = 7u;
static const uint OP_ATAN2 = 8u;
static const uint OP_SQRT = 9u;
static const uint OP_SIN = 10u;
static const uint OP_COS = 11u;
static const uint OP_ABS = 12u;
static const uint OP_CLAMP = 13u;
static const uint OP_MIX = 14u;
static const uint OP_EXTRACT = 15u;
static const uint OP_WIDEN = 16u;
static const uint OP_COMBINE = 17u;
static const uint OP_DOT = 18u;
static const uint OP_NORMALIZE = 19u;
static const uint OP_GEOMETRY = 20u;
static const uint OP_TEXTURE = 21u;
static const uint OP_NORMAL_MAP = 22u;
static const uint OP_OUTPUT = 23u;
static const uint OP_FLOOR = 24u;
static const uint OP_SIGN = 25u;
static const uint OP_EXP = 26u;
static const uint OP_LOG = 27u;
static const uint OP_MODULO = 28u;
static const uint OP_GREATER = 29u;
static const uint OP_CROSS = 30u;
static const uint OP_TRANSFORM = 31u;
static const uint OP_NOISE = 32u;
static const uint OP_MAGIC = 33u;
static const uint OP_CHECKER = 34u;

static const uint NOISE_NORMALIZE = 1u;
static const uint NOISE_COLOR = 2u;

static const uint GEOMETRY_TEXCOORD0 = 0u;
static const uint GEOMETRY_TEXCOORD1 = 1u;
static const uint GEOMETRY_POSITION = 2u;
static const uint GEOMETRY_NORMAL = 3u;
static const uint GEOMETRY_TANGENT = 4u;
static const uint GEOMETRY_BITANGENT = 5u;
static const uint GEOMETRY_OBJECT_POSITION = 6u;

// uint4s of an Output instruction per OUTPUT_GROUPS entry (4, 5, 2, 7, 5, 8, 3, 3, 2, 3 operands),
// 2 bits each: a switch-free table, since WGSL cannot index constant arrays dynamically everywhere.
static const uint OUTPUT_INSTRUCTION_WORDS = 0x55E9Au;

struct MaterialHeader
{
	uint surface; // absolute program offsets in gMaterialData, PROGRAM_NONE if absent
	uint opacity;
	uint emission;
	uint flags; // bit 0 double-sided, bits 8..9 alpha mode
	uint textureBase;
	uint constantBase;
	float alphaCutoff;
	uint debugTexture; // texture table index of the base color texture, PROGRAM_NONE if none

	uint AlphaMode()
	{
		return (flags >> 8u) & 3u;
	}

	bool DoubleSided()
	{
		return (flags & MATERIAL_FLAG_DOUBLE_SIDED) != 0u;
	}
};

MaterialHeader LoadMaterialHeader(uint materialIndex)
{
	uint4 h0 = gMaterialData[materialIndex * 2u];
	uint4 h1 = gMaterialData[materialIndex * 2u + 1u];
	MaterialHeader h;
	h.surface = h0.x;
	h.opacity = h0.y;
	h.emission = h0.z;
	h.flags = h0.w;
	h.textureBase = h1.x;
	h.constantBase = h1.y;
	h.alphaCutoff = asfloat(h1.z);
	h.debugTexture = h1.w;
	return h;
}

TextureRef LoadTextureRef(MaterialHeader header, uint index)
{
	uint4 a = gMaterialData[header.textureBase + index * 2u];
	TextureRef ref;
	ref.flags = a.x;
	ref.pageTableOffset = a.y;
	ref.reserved = a.z;
	ref.rotation = asfloat(a.w);
	ref.scaleOffset = asfloat(gMaterialData[header.textureBase + index * 2u + 1u]);
	return ref;
}

// The hit as the bytecode sees it. Opacity and emission programs only read tex.
struct MaterialContext
{
	TextureCoords tex;
	float3 position;
	float3 normal; // interpolated, not flipped
	float4 tangent;
	uint instanceIndex;
};

MaterialContext MakeMaterialContext(TextureCoords tex)
{
	MaterialContext ctx;
	ctx.tex = tex;
	ctx.position = float3(0.0);
	ctx.normal = float3(0.0, 0.0, 1.0);
	ctx.tangent = float4(0.0);
	ctx.instanceIndex = 0u;
	return ctx;
}

// open_pbr_surface inputs; the geometry vectors become frames in Materials/MaterialSample.
struct MaterialOutputs
{
	BSDFInputs inputs;
	float3 normal;
	float3 coatNormal;
	float3 tangent;
	float3 coatTangent;

	static MaterialOutputs Default(MaterialContext ctx)
	{
		MaterialOutputs o;
		o.inputs = BSDFInputs.Default();
		o.normal = ctx.normal;
		o.coatNormal = ctx.normal;
		o.tangent = ctx.tangent.xyz;
		o.coatTangent = ctx.tangent.xyz;
		return o;
	}
};

float3 ApplyNormalMap(float4 tangent, float3 n, float3 texel, float scale)
{
	if (tangent.w == 0.0 || dot(tangent.xyz, tangent.xyz) == 0.0)
	{
		return n;
	}
	float3 local;
	local.xy = (texel.xy * 2.0 - 1.0) * scale;
	local.z = texel.z <= 0.0 ? sqrt(saturate(1.0 - dot(local.xy, local.xy))) : abs(texel.z * 2.0 - 1.0);
	if (dot(local, local) == 0.0)
	{
		return n;
	}
	local = normalize(local);
	float3 t = normalize(tangent.xyz - n * dot(tangent.xyz, n));
	float3 b = cross(n, t) * tangent.w;
	return normalize(t * local.x + b * local.y + n * local.z);
}

float3 Bitangent(float4 tangent, float3 n)
{
	if (tangent.w == 0.0 || dot(tangent.xyz, tangent.xyz) == 0.0)
	{
		return float3(0.0);
	}
	return cross(n, normalize(tangent.xyz - n * dot(tangent.xyz, n))) * tangent.w;
}

uint MaterialWord(uint index)
{
	return gMaterialData[index >> 2u][index & 3u];
}

// slot: the stack entry the operand names (ignored for constants).
float4 MaterialOperand(uint operand, float4 slot, uint constantBase)
{
	if (operand == OPERAND_NONE)
	{
		return float4(0.0);
	}
	if ((operand & OPERAND_CONSTANT) != 0u)
	{
		return asfloat(gMaterialData[constantBase + (operand & ~OPERAND_CONSTANT)]);
	}
	return slot;
}

bool4 LanesBelow(uint size)
{
	return uint4(0u, 1u, 2u, 3u) < uint4(size);
}

// Writes field `i` of the current Output instruction: `v` is its value.
#define MATERIAL_OUTPUT(i, assignment) \
	{ \
		uint o = MaterialWord(operands + (i)); \
		if (o != OPERAND_NONE) \
		{ \
			float4 v = MaterialOperand(o, stack[o & (MATERIAL_STACK_SIZE - 1u)], header.constantBase); \
			assignment; \
		} \
	}

// SURFACE = 0 builds the reduced interpreter for opacity and emission programs (texture
// coordinates, textures and math only), which runs inside traversal and light sampling.
void RunMaterialProgram<let SURFACE : int>(MaterialHeader header, uint program, MaterialContext ctx, inout MaterialOutputs outputs)
{
	float4 stack[MATERIAL_STACK_SIZE];
	uint pc = program;
	for (uint n = 0u; n < MATERIAL_MAX_INSTRUCTIONS; n++)
	{
		uint4 ins = gMaterialData[pc];
		uint op = ins.x & 0xffu;
		uint dst = (ins.x >> 8u) & (MATERIAL_STACK_SIZE - 1u);
		uint imm = ins.x >> 16u;
		if (op == OP_END)
		{
			return;
		}
		float4 a = MaterialOperand(ins.y, stack[ins.y & (MATERIAL_STACK_SIZE - 1u)], header.constantBase);
		float4 b = MaterialOperand(ins.z, stack[ins.z & (MATERIAL_STACK_SIZE - 1u)], header.constantBase);
		float4 c = MaterialOperand(ins.w, stack[ins.w & (MATERIAL_STACK_SIZE - 1u)], header.constantBase);
		uint operands = pc * 4u + 1u;
		pc += op == OP_OUTPUT ? (OUTPUT_INSTRUCTION_WORDS >> (2u * min(imm, 9u))) & 3u : op == OP_COMBINE ? 1u + imm / 4u : 1u;

		float4 r = float4(0.0);
		bool write = true;
		switch (op)
		{
		case OP_ADD: r = a + b; break;
		case OP_SUB: r = a - b; break;
		case OP_MUL: r = a * b; break;
		case OP_DIV: r = a / b; break;
		case OP_MIN: r = min(a, b); break;
		case OP_MAX: r = max(a, b); break;
		case OP_POW: r = pow(a, b); break;
		case OP_ATAN2: r = atan2(a, b); break;
		case OP_SQRT: r = sqrt(a); break;
		case OP_SIN: r = sin(a); break;
		case OP_COS: r = cos(a); break;
		case OP_ABS: r = abs(a); break;
		case OP_CLAMP: r = min(max(a, b), c); break;
		case OP_MIX: r = lerp(a, b, c); break;
		case OP_EXTRACT: r = float4(a[min(imm, 3u)]); break;
		case OP_WIDEN: r = select(LanesBelow(imm & 0xffu), a, float4(float(imm >> 8u))); break;
		case OP_COMBINE:
			r = float4(a.x, b.x, c.x, 0.0);
			if (imm > 3u)
			{
				uint o = MaterialWord(operands + 3u);
				r.w = MaterialOperand(o, stack[o & (MATERIAL_STACK_SIZE - 1u)], header.constantBase).x;
			}
			break;
		case OP_DOT:
		{
			bool4 lanes = LanesBelow(imm);
			r = float4(dot(select(lanes, a, float4(0.0)), select(lanes, b, float4(0.0))));
			break;
		}
		case OP_NORMALIZE:
		{
			float4 x = select(LanesBelow(imm), a, float4(0.0));
			float len = length(x);
			r = len > 0.0 ? a / len : float4(0.0);
			break;
		}
		case OP_GEOMETRY:
			if (imm == GEOMETRY_TEXCOORD0)
			{
				r = float4(ctx.tex.uv0, 0.0, 0.0);
			}
			else if (imm == GEOMETRY_TEXCOORD1)
			{
				r = float4(ctx.tex.uv1, 0.0, 0.0);
			}
			else if (imm == GEOMETRY_OBJECT_POSITION)
			{
				r = float4(ctx.tex.objectPosition, 0.0);
			}
			else if (SURFACE != 0)
			{
				if (imm == GEOMETRY_POSITION)
				{
					r = float4(ctx.position, 0.0);
				}
				else if (imm == GEOMETRY_NORMAL)
				{
					r = float4(ctx.normal, 0.0);
				}
				else if (imm == GEOMETRY_TANGENT)
				{
					r = ctx.tangent;
				}
				else
				{
					r = float4(Bitangent(ctx.tangent, ctx.normal), 0.0);
				}
			}
			break;
		case OP_TEXTURE:
		{
			TextureRef ref = LoadTextureRef(header, imm);
			r = HasTexture(ref) ? SampleTexture(ref, ctx.tex) : float4(1.0);
			break;
		}
		case OP_NORMAL_MAP:
			if (SURFACE != 0)
			{
				r = float4(ApplyNormalMap(ctx.tangent, ctx.normal, a.xyz, b.x), 0.0);
			}
			break;
		case OP_FLOOR: r = floor(a); break;
		case OP_SIGN: r = sign(a); break;
		case OP_EXP: r = exp(a); break;
		case OP_LOG: r = log(a); break;
		case OP_MODULO: r = a - b * floor(a / b); break;
		case OP_GREATER: r = select(a > b, float4(1.0), float4(0.0)); break;
		case OP_CROSS: r = float4(cross(a.xyz, b.xyz), 0.0); break;
		case OP_TRANSFORM:
			if (SURFACE != 0)
			{
				Instance inst = gInstances[ctx.instanceIndex];
				r = float4(imm == 1u ? TransformVector(inst, a.xyz) : InverseTransformVector(inst, a.xyz), 0.0);
			}
			break;
		case OP_NOISE:
		{
			float3 v = BlenderNoise(a.xyz, b, (imm & NOISE_NORMALIZE) != 0u, (imm & NOISE_COLOR) != 0u);
			r = (imm & NOISE_COLOR) != 0u ? float4(v, 0.0) : float4(v.x);
			break;
		}
		case OP_MAGIC:
		{
			float3 c = BlenderMagic(a.xyz, imm, b.x);
			r = float4(c, (c.x + c.y + c.z) / 3.0);
			break;
		}
		case OP_CHECKER: r = float4(BlenderChecker(a.xyz)); break;
		case OP_OUTPUT:
			switch (imm)
			{
			case 0u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.baseWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.baseColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.baseDiffuseRoughness = v.x);
					MATERIAL_OUTPUT(3u, outputs.inputs.baseMetalness = v.x);
				}
				break;
			case 1u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.specularWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.specularColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.specularRoughness = v.x);
					MATERIAL_OUTPUT(3u, outputs.inputs.specularIor = v.x);
					MATERIAL_OUTPUT(4u, outputs.inputs.specularDielectricOnly = v.x != 0.0);
				}
				break;
			case 2u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.specularRoughnessAnisotropy = v.x);
					MATERIAL_OUTPUT(1u, outputs.tangent = v.xyz);
				}
				break;
			case 3u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.transmissionWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.transmissionColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.transmissionDepth = v.x);
					MATERIAL_OUTPUT(3u, outputs.inputs.transmissionScatter = v.xyz);
					MATERIAL_OUTPUT(4u, outputs.inputs.transmissionScatterAnisotropy = v.x);
					MATERIAL_OUTPUT(5u, outputs.inputs.transmissionDispersionScale = v.x);
					MATERIAL_OUTPUT(6u, outputs.inputs.transmissionDispersionAbbeNumber = v.x);
				}
				break;
			case 4u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.subsurfaceWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.subsurfaceColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.subsurfaceRadius = v.x);
					MATERIAL_OUTPUT(3u, outputs.inputs.subsurfaceRadiusScale = v.xyz);
					MATERIAL_OUTPUT(4u, outputs.inputs.subsurfaceScatterAnisotropy = v.x);
				}
				break;
			case 5u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.coatWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.coatColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.coatRoughness = v.x);
					MATERIAL_OUTPUT(3u, outputs.inputs.coatRoughnessAnisotropy = v.x);
					MATERIAL_OUTPUT(4u, outputs.inputs.coatIor = v.x);
					MATERIAL_OUTPUT(5u, outputs.inputs.coatDarkening = v.x);
					MATERIAL_OUTPUT(6u, outputs.coatNormal = v.xyz);
					MATERIAL_OUTPUT(7u, outputs.coatTangent = v.xyz);
				}
				break;
			case 6u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.fuzzWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.fuzzColor = v.xyz);
					MATERIAL_OUTPUT(2u, outputs.inputs.fuzzRoughness = v.x);
				}
				break;
			case 7u:
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(0u, outputs.inputs.thinFilmWeight = v.x);
					MATERIAL_OUTPUT(1u, outputs.inputs.thinFilmThickness = v.x);
					MATERIAL_OUTPUT(2u, outputs.inputs.thinFilmIor = v.x);
				}
				break;
			case 8u:
				MATERIAL_OUTPUT(0u, outputs.inputs.emissionLuminance = v.x);
				MATERIAL_OUTPUT(1u, outputs.inputs.emissionColor = v.xyz);
				break;
			default:
				MATERIAL_OUTPUT(0u, outputs.inputs.geometryOpacity = v.x);
				MATERIAL_OUTPUT(1u, outputs.inputs.geometryThinWalled = v.x != 0.0);
				if (SURFACE != 0)
				{
					MATERIAL_OUTPUT(2u, outputs.normal = v.xyz);
				}
				break;
			}
			write = false;
			break;
		default:
			break;
		}
		if (write)
		{
			stack[dst] = r;
		}
	}
}

// One copy of the reduced interpreter for both scalar programs.
[noinline]
MaterialOutputs RunScalarMaterialProgram(MaterialHeader header, uint program, TextureCoords tc)
{
	MaterialContext ctx = MakeMaterialContext(tc);
	MaterialOutputs o = MaterialOutputs.Default(ctx);
	RunMaterialProgram<0>(header, program, ctx, o);
	return o;
}

// Opacity of an alpha-tested material (1 without an opacity program).
float EvalOpacity(MaterialHeader header, TextureCoords tc)
{
	if (header.opacity == PROGRAM_NONE)
	{
		return 1.0;
	}
	return RunScalarMaterialProgram(header, header.opacity, tc).inputs.geometryOpacity;
}

// Emitted radiance (luminance times color), 0 without an emission program.
float3 EvalEmission(MaterialHeader header, TextureCoords tc)
{
	if (header.emission == PROGRAM_NONE)
	{
		return float3(0.0);
	}
	MaterialOutputs o = RunScalarMaterialProgram(header, header.emission, tc);
	return o.inputs.emissionColor * o.inputs.emissionLuminance;
}
