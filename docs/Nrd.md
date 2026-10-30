# NVIDIA NRD (REBLUR) for real-time frames

Optional NVIDIA NRD 4.18 REBLUR denoising for the real-time path: wavefront integrator, one sample
per pixel, TAA active (host frames or `settings.accumulation = false`). It is off by default.
`renderer.setNrd(true, mode)` (viewer `?nrd=1&nrdMode=sh|radiance`, console `r.NRD.Enabled 1`,
`r.NRD.Mode`) loads a lazy chunk with the NRD runtime (WebAssembly) and the generated WGSL.
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

`npm run build:nrd` needs the NRD SDK and NVIDIA MathLib checkouts (not vendored): set `NRD_SDK`
and `NRD_MATHLIB`, or place them in `.tools/nrd/NRD` and `.tools/nrd/MathLib`. It also needs
emsdk (as `build:wasm`) and slangc (as `build:shaders`). The script:

1. Stages `Include/`, `Source/`, `Shaders/` and MathLib into `.tools/nrd/build` and patches the copy:
   - `NRDConfig.hlsli`: `NRD_NORMAL_ENCODING = RGBA16_SNORM` (writable `rgba16float` without
     `texture-formats-tier1`), `NRD_ROUGHNESS_ENCODING = LINEAR`, no quad intrinsics, checkerboard
     and anti-firefly support, no viewport offset / history confidence / threshold mix.
   - `Texture.Load(p, int2 offset)` -> `Texture.Load(p + int3(offset, 0))` (WGSL has no texel offsets).
   - `REBLUR_ClassifyTiles`: groupshared `InterlockedAdd` -> Slang `Atomic<int>` (WGSL atomics).
   - MathLib: Emscripten uses `<nmmintrin.h>` (SSE4.2 on wasm SIMD); `Timer.cpp` accepts Emscripten.
   - An empty `ShaderMake/ShaderBlob.h`: no shader blobs are embedded (`NRD_EMBEDS_*_SHADERS = 0`).
2. Compiles the runtime and `wasm/nrd_wasm.cpp` (C ABI over contexts: create with a denoiser list,
   instance description as JSON, common/REBLUR settings, flattened dispatches of all denoisers) into
   `src/generated/nrd/nrd.{mjs,wasm}`.
3. Loads that module in Node, asks it for the pipelines of both modes' instances and compiles each
   `shaderIdentifier` (`file|MACRO=value...`) with slangc to WGSL, using NRD's own SPIR-V register
   shifts (samplers 0+, constants 2, storage textures 3+, textures 20+; resources in group 0,
   constants and samplers in group 1) and column-major matrices -> `NrdShaders.ts`.
   Storage textures only loaded become `read`, only stored become `write`; `read_write` remains
   only for r32 formats. The exception is REBLUR's validation overlay, which Veach never enables.
4. Compiles `shaders/Nrd/NrdPasses.slang` (Veach front/back end, includes `NRD.hlsli`) -> `NrdPasses.ts`,
   once per mode (`NRD_PASS_SH=0/1`: `Prepare`, `Composite`, `PrepareSh`, `CompositeSh`).

All outputs are committed generated code. Run `build:nrd` after editing `shaders/Nrd`, `wasm/nrd_wasm.cpp`
or the NRD-dependent parts of `Wavefront.slang` that `NrdPasses.slang` reads (layout below).

## Device requirements

`NrdDenoiser.unsupportedReason` reports `float32-filterable` (REBLUR samples r32float/rg32float pools
with linear filtering), at least 7 storage textures and 15 sampled textures per stage (both modes).
`Renderer.create`
requests `float32-filterable`, `texture-formats-tier1` and up to 8 storage textures when the adapter
offers them. Without tier 1, `r8unorm`/`rg8unorm`/`r16float`/`r16uint`/`rgb10a2unorm` pool textures fall
back to wider formats (`rgba8unorm`, `r32float`, `r32uint`, `rgba16float`); storage formats are
substituted into the WGSL per pipeline from the bound textures, so both paths share one build.
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

- One NRD context per mode. Pools from the instance description plus user textures (rgba16float, viewZ
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
- REBLUR radiance and SH only; no occlusion, RELAX or SIGMA. RELAX's temporal accumulation needs
  20 sampled textures, beyond the WebGPU default of 16.
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
