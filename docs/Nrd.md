# NVIDIA NRD (REBLUR) for real-time frames

Optional NVIDIA NRD 4.18 REBLUR denoising for the real-time path: wavefront integrator, one sample
per pixel, TAA active (host frames or `settings.accumulation = false`). It is off by default.
`renderer.setNrd(true, mode)` (viewer `?nrd=1&nrdMode=sh|radiance`, console `r.NRD.Enabled 1`,
`r.NRD.Mode`) loads a lazy chunk with NRD's dispatch planner (TypeScript) and the generated WGSL.
Progressive accumulation, OIDN and the megakernel are unchanged. Two modes:

- `sh` (default): `REBLUR_DIFFUSE_SH` + `REBLUR_SPECULAR_SH` (14 dispatches). The inputs carry each
  signal's dominant light direction; Composite resolves the SGs (`NRD_SG_ResolveDiffuse/Specular`,
  macro detail) and re-jitters them (`NRD_SG_ReJitter`, micro detail and per-frame film jitter that
  NRD's temporal accumulation removes), so TAA again receives jittered lighting detail.
- `radiance`: `REBLUR_DIFFUSE_SPECULAR` (7 dispatches), radiance and hit distance only.

The combined `REBLUR_DIFFUSE_SPECULAR_SH` is not used: its temporal accumulation writes 9 storage
textures, while WebGPU adapters expose at most 8 per stage. The split diffuse/specular denoisers
(NRD-supported, one instance) need at most 6 storage and 14 sampled textures per pass.

```
wavefront trace (NRD split region) -> taa.motion -> nrd.prepare -> REBLUR
  -> nrd.composite (resolve, re-jitter, remodulate) -> taa.resolve -> exposure / presentation
```

## Build

`npm run build:nrd` compiles the vendored NRD SDK and NVIDIA MathLib in `ThirdParty/NRD` and
`ThirdParty/MathLib` (revisions in their `VERSION.txt`). The NRD copy is upstream reduced to REBLUR: the
unused RELAX, SIGMA and REFERENCE denoisers are stripped (VERSION.txt lists what); updating means replacing
the copied directories and stripping them again. The generated REBLUR WGSL is unaffected by the strip. `NRD_SDK` and `NRD_MATHLIB` override them with other checkouts. Veach is team-internal for now:
the vendored source is meant to be replaced gradually by Veach's own denoiser before any release, which
must then revisit the NVIDIA license. The build also needs emsdk (as `build:wasm`;
`npm run build:nrd -- --skip-wasm` reuses the committed runtime) and a slangc that emits WGSL
`texture-formats-tier1` storage formats. Slang 2026.20 does not: it writes `rgba32float` for them. Until
[shader-slang/slang#13778](https://github.com/shader-slang/slang/pull/13778) ships in a release, the
script uses the committed Windows build in `tools/slang` (master plus that PR; source and rebuild steps
in `tools/slang/README.md`). `SLANGC` overrides it, for example on other platforms. The script checks
this first. The script:

1. Stages `Include/`, `Source/`, `Shaders/` and MathLib into `.tools/nrd/build` and patches the copy:
   - `NRDConfig.hlsli`: `NRD_NORMAL_ENCODING = RGBA16_SNORM` (writable `rgba16float` without
     `texture-formats-tier1`), `NRD_ROUGHNESS_ENCODING = LINEAR`, no quad intrinsics, checkerboard
     and anti-firefly support, no viewport offset / history confidence / threshold mix.
   - `Texture.Load(p, int2 offset)` -> `Texture.Load(p + int3(offset, 0))` (WGSL has no texel offsets).
   - `REBLUR_ClassifyTiles`: groupshared `InterlockedAdd` -> Slang `Atomic<int>` (WGSL atomics).
   - MathLib: Emscripten uses `<nmmintrin.h>` (SSE4.2 on wasm SIMD); `Timer.cpp` accepts Emscripten.
   - An empty `ShaderMake/ShaderBlob.h`: no shader blobs are embedded (`NRD_EMBEDS_*_SHADERS = 0`).
   - `NRD.hlsli` (Slang branch): constants, inputs, outputs and samplers bind explicitly with
     `[[vk::binding(register + shift, space)]]`, using NRD's own SPIR-V shifts (samplers 0+, constants 2,
     storage textures 3+, textures 20+; resources in group 0, constants and samplers in group 1).
     slangc's `-fvk-*-shift` options are not used: they override an explicit `[[vk::binding]]` of
     the same register class. Each output's type comes from a `NRD_STORAGE_<name>` macro (step 3), and
     `shaders/Nrd/WriteOnlyTexture.hlsli` adds subscript stores to `WTexture2D`. The Slang core module
     gives write-only textures no subscript, while NRD writes `gOut[ p ] = value`.
2. Compiles the runtime and `wasm/nrd_wasm.cpp` (C ABI over contexts: create with a denoiser list,
   instance description as JSON, common/REBLUR settings, flattened dispatches of all denoisers) into
   `tests/generated/nrd/nrd.{mjs,wasm}`: the reference the TypeScript planner is tested against (below);
   the renderer does not load it. `-fmacro-prefix-map` replaces the checkout path in the `__FILE__`
   strings of NRD's asserts, so the committed wasm is reproducible from any directory.
3. Loads that module in Node and plans both modes' dispatches with Veach's settings
   (`src/render/denoise/NrdConfig.mjs`, shared with `NrdDenoiser`) over history resets, steady frames
   and a resize. That gives every pipeline's bound storage formats for both pool format sets
   (`texture-formats-tier1` and core). A pipeline can run on several format combinations: `Clear`, for
   example, clears pools of different formats. Pipelines never dispatched with these settings
   (hit distance reconstruction, split screen, validation, post-blur without stabilization) are not
   compiled. Each `shaderIdentifier` (`file|MACRO=value...`) is compiled twice with slangc to WGSL
   (column-major matrices). The first pass, with NRD's `RWTexture2D` outputs, only reports which
   storage textures the shader loads and stores. The second pass declares each used output as
   `[format(...)] WTexture2D` (stored only), `Texture2D` (loaded only, sampled: `gInOut_Mv` in
   temporal stabilization) or `[format(...)] RWTexture2D` (both, r32 formats only). It runs once
   per format combination -> `NrdShaders.ts` (shader -> `nrdVariantKey` -> WGSL). The emitted WGSL
   is not edited. The build verifies each declaration against the expected format and access.
4. Compiles `shaders/Nrd/NrdPasses.slang` (Veach front/back end, includes `NRD.hlsli`) -> `NrdPasses.ts`,
   once per mode (`NRD_PASS_SH=0/1`: `Prepare`, `Composite`, `PrepareSh`, `CompositeSh`). Prepare
   declares its outputs as formatted `WTexture2D` in the user texture formats (`userFormat`).

All outputs are committed generated code. Run `build:nrd` after editing `shaders/Nrd`, `wasm/nrd_wasm.cpp`
or the NRD-dependent parts of `Wavefront.slang` that `NrdPasses.slang` reads (layout below).

## Device requirements

`NrdDenoiser.unsupportedReason` reports `float32-filterable` (REBLUR samples r32float/rg32float pools
with linear filtering), at least 7 storage textures and 15 sampled textures per stage (both modes).
`Renderer.create`
requests `float32-filterable`, `texture-formats-tier1` and up to 8 storage textures when the adapter
offers them. Without tier 1, `r8unorm`/`rg8unorm`/`r16float`/`r16uint`/`rgb10a2unorm` pool textures fall
back to wider formats (`rgba8unorm`, `r32float`, `r32uint`, `rgba16float`). `NrdDenoiser` selects the
generated variant matching the formats a dispatch binds; a missing variant is an error that asks for
`build:nrd`. `node scripts/nrd-check.mjs --core-formats` withholds the tier features to test the
fallback (output in `.tools/nrd/core`).
The eight-storage-buffer budget of the path tracer is unaffected: NRD uses only textures plus the
Prepare/Composite buffers in their own layouts.

## Path tracer split

The noisy inputs are written by the wavefront integrator into a per-pixel region of the accumulation
buffer (five float4, 80 bytes/pixel; both modes), allocated after the work metadata only while NRD is enabled
(`PathTracer.setNrd`, `Wavefront.nrdBytes`; it reduces tile capacity like SHARC). Its float4 offset is
`FrameUniforms.envInfo.w` (formerly unused); zero disables every NRD write.

- Primary shading stores the radiance so far (camera-visible emission, analytic lights) as bypass,
  plus roughness and metalness (`roughness * 0.99 + 2 * round(metalness * 255)`).
- Primary NEE samples carry flags in their shadow record's `direction.w`: bit 0 tests visibility
  (previously the whole word), bit 1 marks a primary vertex, bit 2 sends the sample to the bypass,
  bits 3+ hold three 9-bit diffuse fractions `eval.diffuse / (eval.diffuse + eval.specular)`.
  Shadow resolution (`Shadow`, alpha classification and the parallel opaque kernels) adds visible
  primary direct light to the diffuse/specular accumulators. Primary direct light is never clamped,
  so the split is exact. Primary sun light bypasses NRD: one sample is nearly noise-free (penumbrae
  only), while REBLUR, driven by the indirect hit distance, visibly softened its shadows.
- The primary BSDF sample stores its diffuse fraction `weight.diffuse / (weight.diffuse + weight.specular)`.
  Everything the path gathers afterwards (indirect light, SHARC queries, later emission) is split
  by that fraction. A primary sample is drawn from one lobe mixture, so this attribution is per sample;
  REBLUR's spatial passes average it.
- The first continuation segment's hit distance (or 65504 on a miss) is the REBLUR hit distance.
- Dominant directions (SH mode): visible primary NEE adds `luminance(part) * L` per signal (L is the
  shadow ray direction); the primary BSDF direction is stored octahedrally and weighted by the
  luminance of the indirect part of each signal at Finalize. Dividing by the signal's total luminance
  (luminance is linear, so the weights sum to it) gives a mean direction whose length below one
  encodes angular spread, which `REBLUR_FrontEnd_PackSh` stores and the SG resolve turns into sharpness.
- Finalize rewrites the region pre-exposed as (diffuse, hitT), (specular, roughness/metalness),
  (bypass = radiance - diffuse - specular, surface flag), (diffuse direction, 0), (specular direction, 0).
  Pixels without a surface (sky, invalid primary) are bypass only.

`nrd.prepare` builds NRD inputs from that region and the accumulation guides: `IN_MV` from TAA's
explicit motion (previous minus current, pixels; `motionVectorScale = 1 / size`), `IN_VIEWZ` along
the camera axis from the primary hit distance (sky beyond the denoising range), `IN_NORMAL_ROUGHNESS`
from the shading normal, and `IN_DIFF/SPEC_RADIANCE_HITDIST` demodulated with
`NRD_MaterialFactors(N, V, baseColor * (1 - metalness), lerp(0.04, baseColor, metalness), roughness)`
and packed with `REBLUR_FrontEnd_PackRadianceAndNormHitDist` (radiance) or `REBLUR_FrontEnd_PackSh`
with the mean directions (SH0/SH1 inputs). In SH mode `nrd.composite` unpacks the SGs, resolves them
with the current-frame normal, view and roughness, and multiplies `NRD_SG_ReJitter`'s scale (BRDF of
the center normal over the averaged four-neighbor normal, clamped to [1/2, 2], only where the four
neighbors are depth/normal-continuous; neighbors use the accumulation normals and the same viewZ as
Prepare). It then remodulates with the same factors as Prepare, adds the bypass and writes the
three-float4 layout TAA's resolve reads,
so TAA history, guides and presentation are unchanged. Radiance stays pre-exposed; the exposure only
changes between accumulation resets.

## Host

`src/render/denoise/NrdDenoiser.ts` owns the NRD instance and GPU resources:

- One planner (`nrd/Planner.ts`) per mode. Pools from the instance description plus user textures (rgba16float, viewZ
  r32float); at 960x640 with tier 1 formats about 107 MB (radiance) or 144 MB (SH). Resolution changes
  recreate them and restart NRD history. The Renderer keeps every loaded mode, so switching is instant;
  a mode's history restarts when it becomes current again, and its REBLUR pipelines compile on first use.
- Per frame: `SetCommonSettings` (non-jittered matrices from the TAA camera basis in a left-handed view
  space, jitter -0.5..0.5, previous camera, `CLEAR_AND_RESTART` whenever TAA history restarts) and
  `GetComputeDispatches`. Constants for all dispatches go into one uniform buffer at 1 KB offsets
  (dynamic offsets). Bind groups follow NRD's resource ranges; the WGSL declarations determine the
  layouts. Pipelines compile asynchronously on first use; until all are ready NRD output is skipped
  (composite uses the noisy split) and history restarts afterwards.
- `TemporalAA.encode` takes an optional filter between motion generation and resolve; the Renderer
  passes NRD there. NRD runs only while TAA is active with the wavefront integrator and an allocated
  region; otherwise `nrdStats.reason` reports `taa-*`, `integrator` or `storage-budget`.

Settings: `nrdEnabled` and `nrdMode` (via `setNrd`), `nrdReJitter` (SH, presentation only) and `nrdDebug`
(presentation only: 0 denoised, 1 noisy split, 2 diffuse, 3 specular, 4 guides, 5 re-jitter scale with
log2 mapped to [0, 1], R diffuse, G specular, gray = unchanged). REBLUR settings are NRD defaults with `maxAccumulatedFrameNum = 30`,
`maxFastAccumulatedFrameNum = 6`, `maxStabilizedFrameNum = 63`, anti-firefly on.

## Dispatch planner

NRD's CPU side (instance description, per-frame dispatches, constant buffers) runs in TypeScript, a port
of the NRD runtime that keeps its behavior. `src/render/denoise/nrd/` ports exactly
what Veach uses: `Instance.ts` (InstanceImpl::Create and the three REBLUR denoiser definitions, in call
order), `Planner.ts` (SetCommonSettings, GetComputeDispatches, Update_Reblur, AddSharedConstants_Reblur,
NRD's wall-clock timer) and `Math32.ts` (the MathLib float32 operations as the wasm build computes them:
Emscripten's exact rcp/rsqrt plus MathLib's Newton-Raphson step, FMA emulated as multiply then add,
`_mm_dp_ps` summation order, signed zeros, every operation rounded with `Math.fround`). Settings Veach
never sets keep NRD's defaults; unported denoisers throw. The DiffuseSh pass names keep upstream's literal
`DENOISER_NAME` prefix (its header does not define the macro).

The migration from the wasm runtime ran in steps: recording the runtime as a test reference, porting
instance creation, porting per-frame planning, rendering with either planner (and with both, checked
against each other every frame on the GPU: no divergence in any `check:nrd` scene or the kitchen scene,
static and orbiting), then the TypeScript default. The runtime now only exists as the reference in
`tests/generated/nrd` (`tests/nrd/wasm.ts` wraps its C ABI). `build:nrd` runs through vite-node and
sweeps storage formats with the TypeScript planner.

Tests (`tests/nrd`) drive scripted frame sequences through NrdDenoiser's reset and frame-index logic
(steady, motion, resets, resize, 1080p, frame index past 2^32) with a fixed time delta, and the timer
path with a scripted clock. The TypeScript description, dispatches and every constant word equal the
wasm runtime's in both modes, bit for bit (the rotator allowance is unused). Invalid common settings are
rejected by both; the wasm build aborts on NRD's asserts, the TypeScript planner throws. When Veach changes
NRD's behavior on purpose, these comparisons give way to snapshots of the TypeScript planner and the
reference can be removed (`ThirdParty/NRD/Source` then serves only as documentation).

## Validation

`npm run check:nrd` (headless Chrome, `.tools/nrd/`): helmet (HDR and low sun), metal/rough spheres,
alpha blend modes and transmission, plus the megakernel fallback. For each it checks both modes' state
(SH 14, radiance 7 REBLUR dispatches per frame), that the noisy split recomposes the raw radiance (max
relative error about 2e-7), finite output and no GPU/console errors, captures a GPU profile, and saves
screenshots: debug views (including the re-jitter scale), then for SH + re-jitter, SH without re-jitter,
radiance and TAA only, from the same camera start, a static image after 60 frames of history (pipelines
compiled before the reset) and the image after a 40-frame orbit.
On the development RTX GPU at 960x640, NRD took about 0.40 ms in SH mode and 0.28 ms in radiance mode,
with path tracing at 3.4-7.5 ms. SH resolve visibly restores specular detail lost in radiance mode (visor
reflections, metal highlights, in motion too); re-jittering adds a smaller sharpening at normal-map
edges and seams, where its scale deviates from one.

## Showcase

`npm run dev:nrd` (http://127.0.0.1:5178/) serves `examples/nrd`: live real-time scenes with NRD SH +
re-jitter, SH without re-jitter, radiance, TAA only (hold C to compare), noisy input and the
diffuse/specular/re-jitter/guide views, auto orbit and GPU timing;
links to the games (`npm run dev:games`, which accept `?nrd=1` and have a denoiser menu); and the
`check:nrd` captures from `.tools/nrd` with a wipe comparison.

## Limitations

- No primary surface replacement: smooth glass/mirror refraction and reflection are denoised as the
  primary surface's specular signal and lose detail. Transmission is a visible example.
- REBLUR radiance and SH only; no occlusion. RELAX, SIGMA and REFERENCE are not vendored (RELAX's temporal
  accumulation also needed 20 sampled textures, beyond the WebGPU default of 16).
- Dominant directions are luminance-weighted means of primary NEE and one BSDF sample, not a full SH
  projection of the gathered light; strongly bimodal lighting resolves toward the mean.
- (De)modulation uses an analytic environment term, not Veach's layered BSDF albedo; coat, sheen,
  thin-film and transmission are not modeled there.
- Secondary-surface motion vectors are not provided (REBLUR uses its own specular tracking).
- The experimental fused tail (`Wavefront.tailStart`) evaluates NEE inline; if it starts at the
  primary bounce, primary direct light is attributed by the sample's diffuse fraction instead.

## License

NRD is under the NVIDIA RTX SDKs License, not MIT; see `THIRD_PARTY_NOTICES.md`. The generated
`src/generated/nrd` files are NVIDIA-derived (source code shaders and a compiled runtime) and end up in the
`NrdDenoiser` chunk of `dist-lib`. Whether that redistribution fits the license terms for the npm
package (object-code requirement, notice, downstream terms) has not been reviewed.
