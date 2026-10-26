// Material bytecode, executed by the Slang interpreter (phase 3) and src/material/Interpreter.ts.
//
// Code is a sequence of uint4. An instruction is a header uint4 (op, a, b, c) followed by
// ceil((operands - 3) / 4) extension uint4s when it has more than three operands:
//   op = opcode | dst << 8 | imm << 16
// An operand is a stack slot, a constant pool index with OPERAND_CONSTANT set, or OPERAND_NONE.
// Every value is a float4: scalars are splatted to all lanes, so component-wise opcodes broadcast
// them for free; lanes past a value's size are undefined.

export enum Op {
	End = 0,
	Add,
	Sub,
	Mul,
	Div,
	Min,
	Max,
	Pow,
	Atan2, // a = y, b = x
	Sqrt,
	Sin,
	Cos,
	Abs,
	Clamp, // a = value, b = low, c = high
	Mix, // a = bg, b = fg, c = t
	Extract, // imm = lane; result splatted
	Widen, // imm = source size | pad << 8: lanes from the source size on are set to pad (0 / 1)
	Combine, // imm = count: lane i = .x of operand i
	Dot, // imm = size; result splatted
	Normalize, // imm = size
	Geometry, // imm = Geometry
	Texture, // imm = texture table index; rgba, colorspace decoded
	NormalMap, // a = texel, b = scale
	Output, // imm = OutputGroup; operands = the group's fields
	Floor,
	Sign,
	Exp,
	Log, // natural
	Modulo, // a - b * floor(a / b)
	Greater, // a > b ? 1 : 0
	Cross,
	Transform, // direction a, imm = 0: world -> object, 1: object -> world (surface programs only)
	Noise, // Blender Noise Texture: a = scaled point, b = (detail, roughness, lacunarity, distortion), imm = NOISE_*; (fac, g, b)
	Magic, // Blender Magic Texture: a = scaled point, b = distortion, imm = depth; (rgb, fac)
	Checker, // Blender Checker Texture factor: a = scaled point
}

export const NOISE_NORMALIZE = 1;
export const NOISE_COLOR = 2;

export enum Geometry {
	Texcoord0 = 0,
	Texcoord1,
	Position,
	Normal,
	Tangent,
	Bitangent,
	ObjectPosition, // also available to opacity and emission programs
}

export const OPERAND_CONSTANT = 0x80000000;
export const OPERAND_NONE = 0xffffffff;
export const MAX_STACK_SIZE = 16; // MATERIAL_STACK_SIZE in shaders/Materials/MaterialProgram.slang

// open_pbr_surface inputs written by one Output instruction, in operand order. Fields without an
// operand keep BSDFInputs' defaults.
export const OUTPUT_GROUPS: readonly (readonly string[])[] = [
	['base_weight', 'base_color', 'base_diffuse_roughness', 'base_metalness'],
	['specular_weight', 'specular_color', 'specular_roughness', 'specular_ior'],
	['specular_roughness_anisotropy', 'geometry_tangent'],
	['transmission_weight', 'transmission_color', 'transmission_depth', 'transmission_scatter', 'transmission_scatter_anisotropy', 'transmission_dispersion_scale', 'transmission_dispersion_abbe_number'],
	['subsurface_weight', 'subsurface_color', 'subsurface_radius', 'subsurface_radius_scale', 'subsurface_scatter_anisotropy'],
	['coat_weight', 'coat_color', 'coat_roughness', 'coat_roughness_anisotropy', 'coat_ior', 'coat_darkening', 'geometry_coat_normal', 'geometry_coat_tangent'],
	['fuzz_weight', 'fuzz_color', 'fuzz_roughness'],
	['thin_film_weight', 'thin_film_thickness', 'thin_film_ior'],
	['emission_luminance', 'emission_color'],
	['geometry_opacity', 'geometry_thin_walled', 'geometry_normal'],
];

export function instructionWords(operands: number): number {
	return 1 + Math.max(0, Math.ceil((operands - 3) / 4));
}
