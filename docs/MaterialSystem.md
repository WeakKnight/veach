# Material system: MaterialX graphs compiled to a shader virtual machine

Status: phases 1 to 4 done (spec-gloss loads; smoke cases `spec-gloss`, `anisotropy`, `sheen`,
`iridescence` cover the textures the old struct lacked). The renderer shades every material through the bytecode
(`shaders/Materials/MaterialProgram.slang`); `MaterialDesc`'s legacy fields are no longer read
by the GPU path. Smoke images match the pre-change ones except for two expected differences:
textures are now sampled in program order, which reshuffles the per-pixel stochastic mip
selection (same expectation, visible only at 1 spp), and `clearcoatNormalTexture` is applied
(the old struct had no slot for it, see the ClearCoatTest "Coat normal map" row).

## Current implementation

- Every material is a MaterialX-subset graph (`MaterialDesc.graph`; glTF metal-rough with its
  extensions and `KHR_materials_pbrSpecularGlossiness` in `GLTFMaterial.ts`), lowered to
  `open_pbr_surface` (= `BSDFInputs`), optimized and compiled to bytecode (`src/material`, format
  in `Bytecode.ts`): uint4 instructions over a 16-entry float4 stack.
- GPU pipelines use the smallest capacity in 0/1/2/4/8/16 that fits the scene's maximum
  compiler-reported `stackSize` (conservatively including unused materials). Initialization
  uses a lightweight empty-scene pipeline; geometry pipelines compile when a scene arrives.
  This applies to both megakernel and wavefront;
  the bytecode format, 16-slot compiler limit, and CPU reference are unchanged.
  Capacity zero is a constant-only scene specialization: every compiled surface, opacity
  and emission program must need zero temporary slots. The compiler then emits only
  Output/End instructions with constant operands. This module retains the shared output
  decoding but excludes the SVM stack and arithmetic/procedural opcode cases. Any nonzero
  requirement selects the ordinary interpreter, including unused and fallback materials.
  `build:shaders` compiles all capacities with `VEACH_MATERIAL_STACK_SIZE` and stores lossless
  edits against the common WGSL in `MaterialStackVariants.ts`. Runtime reconstruction checks
  the base fingerprint; tests verify reconstructed output against each compiler output's SHA256.
  Function-local WGSL array sizes cannot be pipeline overrides. Pipelines are compiled lazily,
  cached by capacity per renderer, and prepared before replacing the active scene.
  The generated edit format uses JavaScript string positions, removal lengths and replacement text;
  runtime validates the base fingerprint and edit bounds. The build uses unchanged-line
  anchors when functions are removed, checks exact reconstruction, and records SHA256.
  Tests cover EOF/newline changes and repeated-line edits as well as actual Slang modules.
  `npm run build:shaders -- --material-stack 1` still emits standalone investigation modules
  under `.tools/wavefront/stack-1`. See [Wavefront.md](Wavefront.md) for paired measurements.
- Three programs per material: surface (every input but opacity, run by `EvalMaterial`), opacity
  (alpha tests) and emission (NEE). The last two are restricted to texture coordinates, textures
  and math, so traversal and light sampling get the reduced interpreter (`RunMaterialProgram<0>`).
- `gMaterialData` (binding 6, `uint4`) holds a 2 x uint4 header per material (program offsets or
  `PROGRAM_NONE`, double-sided / alpha mode, texture table and constant bases, alpha cutoff, base
  color texture for debug view 9), then per material `TextureRef`s and constants, then code blocks
  shared by materials with identical code.
- `src/material/Interpreter.ts` is the CPU reference of `shaders/Materials/MaterialProgram.slang`:
  keep opcodes, `OUTPUT_GROUPS` order and texture semantics in sync (a missing texture samples as
  1). The host uses it for emissive power.
- Instance flags (alpha tested, emissive) and virtual texture color spaces come from the compiled
  materials. A material that fails to compile falls back to the default with a warning.
- Object space: `TextureCoords.objectPosition` (alpha tests, surface, emission) and
  `MaterialContext.instanceIndex` (surface only) feed `position` with `space` 1 and `Op.Transform`
  (`veach_world_to_object` / `veach_object_to_world` directions through `gInstances`).
- Blender's Noise / Magic / Checker are ops 32–34; `src/material/Procedural.ts` and
  `shaders/Materials/Procedural.slang` must stay in sync (Jenkins hashes, Perlin, fBM). The
  shader keeps one call site per noise function (corners, octaves, channels in loops): the
  interpreter is instantiated several times per path tracer (see BSDF.md, Compile size).

## Goals

- One canonical material representation: a MaterialX node graph (a subset of the MaterialX
  standard library, held in TypeScript). glTF metallic-roughness, `KHR_materials_*`,
  `KHR_materials_pbrSpecularGlossiness`, and later `.mtlx` / USD and an editor all produce it.
- One shading model: the graph always ends in `open_pbr_surface`, i.e. Veach's `BSDFInputs`.
  The BSDF (`shaders/Materials/BSDF`) does not change.
- Materials are data, not code: graphs compile to bytecode executed by the shared interpreter
  (after Cycles' SVM, `cycles/src/kernel/svm/svm.h`). There is no shader table or pipeline per
  material. Changes using an already cached stack capacity require no pipeline compilation;
  a new capacity is compiled once when preparing a scene.
- No visible change for existing glTF scenes: phase 3 must reproduce today's images.

Non-goals (for now): closure graphs (`mix` / `add` / `layer` of pbrlib BSDFs, Cycles' Mix
Shader), OSL, displacement, volumes beyond the OpenPBR interior medium, running the MaterialX C++
library at runtime. An experimental wavefront integrator now evaluates the same bytecode
in a separate shading stage; see [Wavefront.md](Wavefront.md).
Its optional chunk sorter groups shading paths by material index or shared surface-program
offset. Programs with different constant pools can share the latter key because the bytecode
block is deduplicated independently from constants; neither format nor interpreter changes.

## Pipeline

```text
glTF material ─┐
.mtlx (later) ─┼─> MaterialGraph (TS, MaterialX subset) ─> lower ─> optimize ─> codegen ─> gMaterialData
editor (later) ┘        nodes: gltf_pbr, open_pbr_surface,   to open_pbr   fold, CSE,   bytecode +   │
                        veach_gltf_specular_glossiness, ...   inputs        DCE, slice   constants    │
                                                                                                    v
                                     Slang interpreter: surface / opacity / emission programs -> BSDFInputs
                                     TS interpreter (same bytecode): tests, emissive power, static flags
```

## Material IR (`src/material/`)

A `MaterialGraph` is a DAG of nodes. Each node names a MaterialX nodedef (`category` + output
type), has typed inputs that are either a value or a connection to another node's output, and
one or more outputs. Types: `float`, `integer`, `boolean`, `vector2`, `vector3`, `color3`,
`color4`, `filename` (a texture source), plus `surfaceshader` for the terminal node. Names follow
MaterialX (`base_color`, `specular_roughness`, `uaddressmode`, ...) so `.mtlx` import / export
is a serialization of the same structure.

Node set v1 (what glTF needs; grows on demand):

| Group | Nodes |
| --- | --- |
| Surfaces | `open_pbr_surface`, `gltf_pbr`, `veach_gltf_specular_glossiness` (custom nodedef) |
| Textures | `gltf_image`, `gltf_colorimage` (outputs `outcolor`, `outa`), `gltf_normalmap` (strength in `normal_scale`, since `scale` is the uv scale); lowered to `veach_texture` (one sample: uv set, transform, wrap, colorspace) |
| Geometry | `texcoord`, `normal`, `tangent`, `bitangent`, `position` (world space), later `geomcolor` |
| Math | `add`, `subtract`, `multiply`, `divide`, `min`, `max`, `power`, `atan2`, `sqrt`, `sin`, `cos`, `absval`, `clamp`, `mix`, `extract`, `convert`, `combine2/3/4`, `dotproduct`, `normalize` |
| Normals | `normalmap` |

Surface nodes other than `open_pbr_surface` are lowered by TypeScript rewrite rules into math
nodes feeding an `open_pbr_surface` (MaterialX's own translation graphs are the reference where
they exist). After lowering, the graph has exactly one surface node and only primitive nodes.
Specular anisotropy is expressed the OpenPBR way, as a rotated `geometry_tangent`.

Veach-specific semantics that MaterialX does not carry live in node attributes:

- `colorspace` on image `file` inputs (`srgb_texture` or `lin_rec709`). sRGB decoding stays in
  the shader, per texture reference (`TEXTURE_FLAG_SRGB`).
- Alpha mode: `gltf_pbr`'s `alpha_mode` / `alpha_cutoff` are kept on the material, not lowered
  into `geometry_opacity`, because the traversal-time test needs them (see Opacity below).
- Thin-walled: `geometry_thin_walled` on `open_pbr_surface` (glTF: no `KHR_materials_volume`
  thickness).

## glTF mapping

The glTF loader emits a `gltf_pbr` node (metallic-roughness and every supported `KHR_materials_*`
extension) or a `veach_gltf_specular_glossiness` node, with `gltf_image` / `gltf_colorimage`
nodes for textures (`texCoord` and `KHR_texture_transform` become node inputs). `MaterialDesc`
is replaced by the graph; the loader keeps no parallel struct.

`gltf_pbr` lowers exactly as `EvalMaterial` maps glTF today (this is the phase 3 reference):

| OpenPBR input | From |
| --- | --- |
| `base_color` | `base_color` × texture.rgb |
| `base_metalness`, `specular_roughness` | `metallic` × tex.b, `roughness` × tex.g (one sample of the shared texture) |
| `specular_ior`, `specular_weight`, `specular_color` | `ior`, `specular` × tex.a, `specular_color` × tex.rgb |
| `veach_specular_dielectric_only` | true for glTF metallic-roughness; false by default for native OpenPBR |
| `specular_roughness_anisotropy`, `specular_anisotropy_rotation` | `anisotropy_strength`, `anisotropy_rotation` (+ texture) |
| `transmission_weight`, `transmission_color`, `transmission_depth` | `transmission` × tex.r; `attenuation_color` / `attenuation_distance` when not thin-walled, else `base_color` |
| `transmission_dispersion_*` | `dispersion` (Abbe number 20 / dispersion, scale 1) |
| `coat_weight`, `coat_roughness`, `coat_ior` | `clearcoat` × tex.r, `clearcoat_roughness` × tex.g, 1.5 |
| `fuzz_weight`, `fuzz_color`, `fuzz_roughness` | 1 if any `sheen_color` > 0, `sheen_color` × tex.rgb, `sheen_roughness` × tex.a |
| `thin_film_*` | `iridescence`, `iridescence_ior`, `iridescence_thickness` (nm → µm, thickness texture) |
| `emission_color`, `emission_luminance` | `emissive` × strength × tex.rgb, 1 |
| `geometry_normal` | `gltf_normalmap` with `normalTexture.scale` |
| `geometry_coat_normal` | clearcoat normal texture, else `geometry_normal` |

Textures the current `Material` struct cannot hold (specular, specular color, sheen,
iridescence, anisotropy, thickness, clearcoat normal) come for free with the graph.

`KHR_materials_specular` affects only the dielectric BRDF. The import semantic above keeps
the metal weight equal to metalness and its F82 tint white, independently of specular factor,
color and textures. It is applied per lobe, so fractional/textured metalness retains the
original dielectric controls without attenuating the metal contribution. Native OpenPBR
continues to use specular weight/color for both base components. This corrects black metals
when a glTF conductor carries `specularFactor: 0`. The fifth field in output group 1 fits
the existing two uint4 instruction words; no GPU storage buffer or scene layout is added.
`KHR_materials_unlit` lowers to emission = base color, base / specular weight 0.

`KHR_materials_pbrSpecularGlossiness` (`veach_gltf_specular_glossiness`):

```text
diffuse  = diffuseFactor × diffuseTexture        (sRGB; .a × diffuseFactor.a = opacity)
f0       = specularFactor × sgTexture.rgb        (sRGB)
gloss    = glossinessFactor × sgTexture.a
base_color = diffuse, base_metalness = 0, specular_roughness = 1 - gloss
specular_ior = 1.5, specular_weight = max(f0) / 0.04, specular_color = f0 / max(f0)
```

The BSDF scales F0 by `specular_weight` (`ApplySpecularWeightToIor`, F0 capped at 0.9999), so
normal-incidence reflectance is exactly `f0`. What differs from the reference glTF viewer
equations: Fresnel is dielectric rather than Schlick (metals, i.e. black diffuse with high f0,
lose a little grazing tint), and the diffuse is energy-compensated by the specular albedo rather
than multiplied by `1 - max(f0)`.

## Compiler (`src/material/compile/`)

1. **Lower** surface nodes to `open_pbr_surface` + primitive nodes.
2. **Fold constants**, apply identities (`x × 1`, `x + 0`, `mix(a, b, 0)`), and drop OpenPBR
   inputs that equal `BSDFInputs.Default()`.
3. **CSE**: identical nodes merge; in particular one texture with the same uv set and transform is
   sampled once however many channels are read (metallic-roughness, spec-gloss rgb + a). This
   also keeps virtual texture feedback per hit down.
4. **Slice** into three programs, each the dead-code-eliminated cone of some outputs (Cycles'
   surface / volume / displacement jump table):
   - `surface`: every `BSDFInputs` field but the opacity, plus the albedo AOV (`base_color`).
   - `opacity`: `geometry_opacity` only. Runs inside BVH traversal; usually one texture read.
   - `emission`: `emission_luminance` and `emission_color`. Runs in `SampleEmissive` for NEE,
     where the full surface is not needed (after the opacity program when alpha-masked).
5. **Static properties** from the folded programs: opaque (opacity is the constant 1 or alpha
   mode is opaque) drives `INSTANCE_FLAG_ALPHA_TESTED`; emissive (emission not constant 0) drives
   `INSTANCE_FLAG_EMISSIVE`; the set of `(texture source, colorspace, wrap)` uses drives
   `VirtualTextureSystem.create` (today derived from fixed slot names).
6. **Register allocation** over a linear schedule with liveness, onto at most `MAX_STACK_SIZE`
   (16) float4 slots; compilation fails if it does not fit, and `compileSceneMaterials` falls
   back to the default material with a warning.
7. **Codegen** into bytecode + a constant pool + a texture table.

Programs with identical code (same graph shape, different constants) are shared; a material is
then (program, constants, textures). This keeps parameter edits a constant upload and gives a
natural sort key if a wavefront path is ever added.

## GPU layout

All 8 storage buffers per stage are in use, so the bytecode replaces the material buffer:
binding 6 becomes `StructuredBuffer<uint4> gMaterialData` and the 368-byte `Material` struct
goes away. Layout, in uint4 units:

```text
[0, 2 × materialCount)   MaterialHeader per material (2 × uint4)
then, per material       texture table (TextureRef, 2 × uint4 each), constant pool (float4 each)
then                     code blocks, one per distinct bytecode (shared by materials that differ
                         only in constants and textures)
```

```text
MaterialHeader (GpuLayout.packMaterialData, MaterialProgram.LoadMaterialHeader)
  uint4 programs:  surface, opacity, emission (absolute uint4 offsets, PROGRAM_NONE if absent),
                   flags (bit 0 double-sided, alpha mode in bits 8..9)
  uint4 data:      textureTableOffset, constantOffset, asuint(alphaCutoff),
                   debugTexture (texture table entry feeding base_color, PROGRAM_NONE if none)
```

Thin-walled is not a header flag: it is the `geometry_thin_walled` output of the surface program.

The format is defined in `src/material/Bytecode.ts` (phase 2; `Compile.ts` emits it,
`Interpreter.ts` runs it on the CPU). An instruction is one uint4 `(opcode | dst << 8 | imm << 16,
a, b, c)` followed by extension uint4s when it has more than three operands. An operand is a
stack slot, a constant pool index when bit 31 is set, or `0xffffffff` (none). Every value is a
float4 with scalars splatted to all lanes, so component-wise opcodes broadcast scalars for free;
narrowing and scalar-to-vector converts emit nothing. Opcodes:

| Opcode | Meaning |
| --- | --- |
| `End` | end of program |
| `Add Sub Mul Div Min Max Pow Atan2 Sqrt Sin Cos Abs Clamp Mix` | component-wise math |
| `Extract` (imm lane), `Widen` (imm size, pad), `Combine` (imm count), `Dot` / `Normalize` (imm size) | lane manipulation |
| `Geometry` (imm: texcoord 0/1, position, normal, tangent, bitangent) | read the hit (`SurfaceInteraction`) |
| `Texture` (imm: texture table entry) | `SampleTexture` with the entry's uv set, transform, wrap and colorspace (exact ray cone footprint; today's path). Procedural uvs are not supported yet |
| `NormalMap texel, scale` | `ApplyNormalMap` in the hit's tangent frame |
| `Output` (imm: group) | write one group of `BSDFInputs` fields (base, specular, anisotropy, transmission, subsurface, coat, fuzz, thin film, emission, geometry); fields without an operand keep the defaults |

A glTF material with base color, metallic-roughness, normal and emissive textures compiles to a
16-instruction surface program (4 texture reads, 7 math, 4 outputs, end) on 5 stack slots.

The interpreter is a bounded `for` loop around a `switch`, like `svm_eval_nodes`. It is generic
over `SURFACE`: `RunMaterialProgram<1>` is the full interpreter, `RunMaterialProgram<0>` (one
non-inlined copy behind `RunScalarMaterialProgram`) drops geometry reads other than texture
coordinates, normal maps and every output group but emission and geometry, for the programs that
run inside traversal and light sampling. Shader integration:

- `EvalMaterial` runs `surface`, then does what it does today after the mapping: `AlignWithFace`,
  shading frames, `MaterialSample.albedo` / `roughness` from the outputs.
- `AlphaTestRejects` and `EvalOpacity` run `opacity`; mask / blend logic stays as is, keyed on the
  header's alpha mode and cutoff.
- `EmissiveRadiance` runs `emission`.
- Debug view 9 samples the header's debug texture (the one feeding `base_color`).

## Host

- `GpuScene` packs `gMaterialData` and takes instance flags from the static properties.
- A TypeScript interpreter of the same bytecode (with `CpuTexture` sampling) estimates emissive
  triangle power for the light CDF (replacing the emissive-texture-only estimate; underestimating
  stays safe) and backs the tests.

## Performance

The megakernel diverges on material at every bounce; an interpreter makes that worse than the
current fixed mapping, mainly through the dispatch loop and stack traffic (private arrays live
in scratch memory). Mitigations, in order:

1. Fused opcodes (`TEX_GLTF`, `NORMAL_MAP`, `OUT_*` groups) so a typical glTF material is about
   10 to 15 instructions, and different glTF materials run the same opcode sequence, so the
   switch stays mostly coherent even when the constants differ.
2. Small float4 stack sized by the compiler's maximum; constants read directly from the buffer.
3. If needed, specialize the interpreter per scene by dropping unused opcodes (Cycles' Metal
   function constants; Slang specialization constants or WGSL `override`).
4. Only if measurements demand it: a wavefront path with material sorting, built on indirect
   dispatch (the host cannot read queue counts back every iteration as Cycles does).

Measure with `npm run smoke` timings and debug view 7 before and after phase 3.

## Testing

- Loader → graph: snapshot tests of lowered graphs for the Khronos samples in `public/samples`.
- Graph evaluator vs bytecode interpreter (TS): random inputs per program.
- Phase 3 regression: the TS interpreter on lowered `gltf_pbr` graphs must produce the
  `BSDFInputs` that a TS port of today's `EvalMaterial` produces; smoke screenshots compared with
  the pre-change images.
- Slang interpreter vs TS interpreter: compile the interpreter to C++ through the existing
  `tests/bsdf` harness path (slangc `-target cpp` + em++) and run the same programs.
- Spec-gloss: `SpecGlossVsMetalRough` sample from Khronos glTF-Sample-Assets in the smoke set.

## Phases

1. IR, glTF → graph (metal-rough and all current extensions), lowering, constant folding, graph
   evaluator in TS. No GPU change.
2. Compiler and TS bytecode interpreter.
3. GPU: `gMaterialData`, Slang interpreter, replace `EvalMaterial` / `EvalOpacity` /
   `EmissiveRadiance`, static flags, VT usage, emissive power. Images unchanged. Update
   `AGENTS.md` invariants (Material struct size, binding 6).
4. `KHR_materials_pbrSpecularGlossiness` in the loader's supported extensions, with a smoke case.
   (The glTF textures the old struct lacked already render since phase 3; add smoke cases.)
5. `.mtlx` import / export for the node subset; `open_pbr_surface` and `standard_surface` assets.
6. Optional: per-scene interpreter specialization; wavefront with material sorting.

## Open questions

- Ray cone footprint for procedural uvs (`TEX_UV`): use the source uv set's footprint scaled by
  an estimated Jacobian, or require uvs to be affine in a uv set?
- Opacity programs inside traversal: cap their length (or allow only texture × constant) to bound
  any-hit cost?
- Vertex colors (`COLOR_0`) need a vertex attribute; the 64-byte `Vertex` has no room left.
