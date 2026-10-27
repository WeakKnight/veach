# Architecture: source layout and GPU data

## Source layout

Renderer initialization compiles `PathTracingEmpty.wgsl`, an empty-scene specialization of
`PathTracing.slang` that retains camera rays, analytic-light visibility, background, and
accumulation. Full material/traversal pipelines are prepared on scene loading, with stack
capacity selected from compiled materials. Capacity zero omits the SVM stack/opcode
implementations when every compiled surface/opacity/emission program is constant-only;
other capacities remain 1/2/4/8/16. Wavefront selection before geometry arrives is deferred;
scene loading prepares its stages alongside the reference kernel. Geometry-free
scenes allocate only the accumulation image prefix, without wavefront scratch.
An experimental scene-derived opcode mask can specialize the material interpreter using
two pipeline constants. Pipeline caches include the mask as well as stack capacity;
the zero-stack module omits these constants. The scene mask includes all three programs,
unused materials and fallback materials, and requires no GPU buffer or binding changes.
An experimental operand-loading mode (pipeline constant ID 2) also participates in material
pipeline cache keys. Modes 1/2/3 guard constant stack reads, skip Output preloads, or combine
both; mode 0 remains the default. Constant-only capacity-zero modules omit this override.
Wavefront compaction optionally uses the adapter's `subgroups` feature, with a separately
compiled workgroup-scan fallback. Both paths keep the same eight-storage-buffer layouts.

Custom display LUTs use `src/render/color/` for validated data, color-space adapters, GPU resources
and lazy built-in presets. Present bindings 10 (unfilterable float32 3D LUT) and 11 (64-byte uniform)
are separate from the compute scene layouts; the eight-storage-buffer budget is unchanged.

Optional OIDN uses `src/render/denoise/` and `Passes/OIDNGuides.slang` (Prepare/Compose).
It snapshots accumulated HDR/albedo/normal into separate GPU inputs at maxSamples and feeds
denoised HDR to all presentation passes without overwriting accumulation. The independent
guiding layout uses four storage buffers; scene bindings remain unchanged. See [Denoising.md](Denoising.md).
`oidn-webgpu` is a pinned, separately installed dependency loaded dynamically. The default HDR
TZA model is bundled in its own lazy JS chunk. New renderers default to 128 samples and OIDN;
passing `denoiser: null` to `Renderer.create` avoids inference/model downloads.

The working tree contains the web renderer and its current `<veach-view>` demo. The former
`Legacy/` C++ tree and its submodule are absent; their source remains in the
[upstream Mozi repository's history](https://github.com/Mozi-Renderer/Mozi), not this repository's history.
The obsolete `dist-react-demo/` build output is also removed; the current demo builds to
the ignored `dist-view-demo/` directory.

```
shaders/            Slang sources (compiled by scripts/build-shaders.mjs)
  Common/           Math.slang (constants, frames, sampling, equirect), Random.slang
  Scene/            SceneTypes.slang (GPU structs), SceneBindings.slang (group 0), SceneAccess.slang
  RayTracing/       Traversal.slang: TLAS + BLAS stack traversal over tinybvh BVH_GPU nodes
  Materials/        MaterialProgram (bytecode interpreter -> BSDFInputs), MaterialSample (hit reconstruction, shading frames),
                    BSDF/ (layered BSDF: BSDF, Layers, Lobes, EnergyTables, ...), Textures, VirtualTexture, AlphaTest,
                    Procedural.slang (Blender Noise (fBM), Magic, Checker; mirrors src/material/Procedural.ts)
  Lights/           Lights.slang: environment CDF, sun cone, emissive triangles and analytic lights (power CDF)
  Passes/           PathTracing.slang (megakernel, accumulation), Present.slang (exposure, tone LUT, encoding),
                    AutoExposure.slang (histogram, eye adaptation), LocalExposure.slang + LocalExposureCommon.slang (Fusion local exposure),
                    Atmosphere.slang (sky LUTs, environment bake + CDF)
src/
  accel/TinyBVH.ts  WASM wrapper: buildBLAS / buildTLAS -> node, triangle and index arrays
  loaders/          GLTFLoader, HDRLoader, Tangents, blend/ (BlendFile: .blend reader with SDNA reflection; BlendLoader: objects, meshes,
                    cameras, lamps; BlendNodes: Cycles node trees -> material graphs, world)
  app/              main.ts (minimal viewer: drag & drop, URL params, keys), BlendSettings.ts (applies a .blend world
                    (constant / Nishita sky), view transform and exposure to the Renderer)
  view/             <veach-view> custom element (VeachViewElement: renderer lifetime, scene / environment loads, progress, stats,
                    events) and fileDrop (drag & drop loading). The `@tianyuliwiwo/veach/view` entry; index.ts is the core entry
  index.ts          `@tianyuliwiwo/veach` entry: renderer and loaders, no DOM side effects (tests/package.test.ts)
  scene/Scene.ts    Backend-independent SceneDesc (meshes, materials, textures, instances, cameras)
  material/         MaterialX-subset graphs (MaterialSystem.md): Graph, NodeDefs, GLTFMaterial (glTF -> graph), Lower (-> open_pbr_surface),
                    Optimize, Evaluate (graph reference), Bytecode + Compile (-> programs), Interpreter (CPU reference of MaterialProgram.slang)
  render/           GpuLayout (struct packers, gMaterialData), GpuScene (buffer flattening, lights), SceneMaterials (compile, texture usage, emission),
                    vt/ (virtual texturing), BSDFTables (energy / LTC table texture), Environment (env map, CDF, sun),
                    AtmosphereBaker (GPU sky bake), Atmosphere (CPU reference), AutoExposure (eye adaptation, readback),
                    LocalExposure (fusion pyramid host), LocalExposureCurve (Z-curve fit, bracket tables), PathTracer (pipelines), PipelineCompiler (async
                    pipeline creation and progress: Renderer.create resolves once all have compiled), Renderer, Camera,
                    aces/ (ACES 2.0 output transform port + 3D LUT baker)
  generated/        Committed outputs: shaders/*.wgsl, tinybvh/tinybvh.{mjs,wasm}, bsdf/BSDFTables.bin
wasm/               tinybvh_wasm.cpp: C ABI compiled with Emscripten (scripts/build-wasm.mjs)
ThirdParty/tinybvh/ Vendored tinybvh headers (see VERSION.txt)
ThirdParty/openpbr-bsdf/ Vendored reference BSDF (C++/GLM) and its data tables, for tables and tests only (see VERSION.txt)
tests/              vitest (Node): BVH vs brute force, loaders, environment CDF, atmosphere, auto exposure parameters, VT layout / page table,
                    ACES 2.0 vs OCIO, material graphs / bytecode vs a port of the pre-graph glTF mapping, .blend loading (needs public/samples/blender),
                    BSDF vs reference (tests/bsdf: harness sources, generated/bsdf: committed wasm harness)
scripts/            build-shaders, build-wasm, build-bsdf-tables, build-bsdf-harness, emsdk (shared lookup), fetch-samples, smoke (headless Chrome),
                    aces2-reference.py (OCIO fixture)
```

## npm release layout

`npm pack` and `npm publish` run `prepack`, which rebuilds `dist-lib/` from scratch.
`vite.lib.config.ts` emits optimized ES modules without source maps. `tsconfig.build.json`
emits declarations starting from the two public entry points and their dependencies.
The package file allowlist includes `dist-lib/*.js`, `dist-lib/types/**/*.d.ts` and the public
API guide, `LICENSE`, `THIRD_PARTY_NOTICES.md` and `licenses/*.txt`, along with npm's standard
README / package metadata. License notices cover the embedded third-party runtime and data.
This also excludes stray maps or
development files if they are accidentally left in the build directory.

WGSL strings, tinybvh WASM and BSDF lookup tables remain inlined; consumers need no runtime
asset paths. `fzstd` is a development dependency for the `.blend` viewer and tests, and is not
reachable from the current public entries. `@webgpu/types` remains an installed dependency for
the public declarations. No Slang, WASM or BSDF rebuild
is needed for packaging-only changes: their committed generated outputs are consumed as-is.

The explicit exports in `src/index.ts` (`@tianyuliwiwo/veach`) and `src/view/index.ts` (`@tianyuliwiwo/veach/view`) are the
public API layer. Package `exports` blocks deep imports into implementation modules. Generated
declarations and [PublicAPI.md](PublicAPI.md) ship with the release, so trimming source files
does not remove supported APIs. Future API additions belong in these entry points with their
types and documentation; preserve existing exports unless making an intentional breaking release.

## Struct layout

`shaders/Scene/SceneTypes.slang` and `src/render/GpuLayout.ts` must match byte for byte. Every
struct is built from 16-byte groups, so std430 and std140 agree. Sizes: Instance 128, Vertex 64,
EmissiveTriangle 128, FrameUniforms 224. Materials are bytecode in `gMaterialData`, not a struct
(see [MaterialSystem.md](MaterialSystem.md)).

## Bindings

The experimental wavefront integrator is described in [Wavefront.md](Wavefront.md).
It appends bounded tile work storage to the accumulation buffer (group 1 binding 0),
retaining the eight-storage-buffer limit. Its group 1 adds a dynamic uniform at binding 2
for tile origin, path count, bounce, capacity, and experimental tail threshold (32-byte binding).
Presentation reads only the image prefix.
GPU compaction views that allocation as atomic uints in its own pass; dispatch arguments
are copied into a small INDIRECT-only buffer. Opaque traversal variants omit the opacity
interpreter when `GpuScene.hasAlphaTested` is false (derived from instanced materials).
An experimental opaque-shadow module can evaluate light sources concurrently within a
workgroup and reduce their contributions in source order; it reuses the same bindings
and is selected only for scenes without alpha-tested instances. The scene light count
also permits an environment/sun-only workgroup when no local lights are present.
An experimental direct-slot dispatch uses the same work allocation and shading helpers,
but omits compaction/indirect copies and keeps the original pixel groups between stages.
It supports fully staged execution and fixed-bounce tails; adaptive tails need queue counts.
Stages can also opt into direct dispatch individually while retaining queue updates;
these mixed schedules keep valid active counts for adaptive tails.

Bind group layouts are explicit in `PathTracer.ts`.

Both integrators cache material stack pipeline variants at capacities 0/1/2/4/8/16.
`GpuScene.materialStackSize` conservatively bounds all compiled material programs.
`Renderer.setScene` prepares the required pipelines before replacing the old scene;
failed compilation or disposal releases the newly allocated scene and virtual textures.
The generated `MaterialStackVariants.ts` reconstructs exact Slang outputs from shared WGSL
without duplicating whole modules. This changes neither bindings nor bytecode layout.

- Group 0, the scene: uniform, 7 read-only storage buffers, sampler, env map, env CDF
  (`unfilterable-float`), VT physical cache (float), VT page table (uint), BSDF tables
  (binding 13, `gBSDFTables`, 3d `unfilterable-float`).
- Group 1: the accumulation buffer and the VT feedback storage texture (`r32uint`).
- Present: uniform, accumulation, tone LUT (3d float), sampler, exposure buffer, local exposure
  params, residual (`r32float`), pyramid mip 0, forward LUT, inverse LUT (all unfilterable,
  sampled manually).

WebGPU guarantees only 8 storage buffers per stage, so do not add buffers; pack into existing ones.

## BVH format

tinybvh `BVH_GPU` 64-byte nodes. A child reference with bit 31 set is a leaf: count in bits
24–30, offset in bits 0–23. Triangles are 3 float4 per primitive reference:
`v0 | asfloat(primIdx)`, `e1`, `e2`. The node buffer is `[TLAS][BLAS...]`; TLAS leaf offsets
index the TLAS prim indices, which are appended to `gIndices` at `counts.z`.
