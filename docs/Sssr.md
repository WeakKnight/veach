# Realtime reflections: FidelityFX SSSR

Realtime rendering splits lighting between the path tracer and screen space: **diffuse ray traced
lighting and analytic-light specular, plus AMD FidelityFX Stochastic Screen Space Reflections (SSSR 1.5)
for reflections**, each with its own denoiser. Offline (progressive) rendering, OIDN and the megakernel
are unchanged. SSSR is the realtime default (`settings.sssrEnabled = true`): the first realtime frame
(host frames or `settings.renderMode = 'realtime'`) loads its lazy chunk, and until it is ready, or on
devices without `subgroups` / `float32-filterable`, realtime frames keep path-traced reflections
(`sssrStats.reason` reports the error). `setSssr(false)`, viewer `?sssr=0` or `r.SSSR.Enabled 0` turn
it off. It applies to wavefront frames with TAA and takes precedence over `settings.nrdEnabled`.
Reflection rays that miss the screen fall back to the sky / environment map.

```
wavefront trace, diffuse only at the primary vertex (NRD split region)
  -> taa.motion -> nrd.prepare -> REBLUR_DIFFUSE_SH -> nrd.composite: color = bypass + denoised diffuse
  -> sssr: prepare (depth, normals) -> depth hierarchy -> classify tiles -> blue noise -> indirect args
     -> intersect (ray marches the previous frame's linear scene color) -> reproject -> prefilter -> resolve temporal
     -> apply: color + reflections * split-sum BRDF -> linear scene color ping-pong (next frame's ray march input)
  -> taa.resolve -> exposure / presentation
```

`renderer.sssrStats` reports whether SSSR ran, the fallback reason (`disabled`, `taa-*`,
`integrator`, `storage-budget`) and memory (its NRD instance excluded). `settings.sssrDebug`
(presentation only) shows 0 final, 1 reflections only, 2 the color input, 3 the camera reconstruction
error (black when FidelityFX's matrices agree with the path tracer) or 4 the raw intersection output
without the denoiser. `settings.sssrRoughnessThreshold` is FidelityFX's `roughnessThreshold`.

## Realtime path tracer: diffuse only

`FRAME_FLAG_DIFFUSE_ONLY` is set only for SSSR frames. `shaders/Passes/WavefrontRealtime.slang`
holds everything it changes; Wavefront.slang calls it at four points, all no-ops without the flag:

- **Primary NEE** of the environment and emissive triangles keeps the diffuse part of the BSDF; SSSR
  (screen-space hits, environment fallback) provides their reflections. The sun and analytic lights
  (`LightSample.analytic`) keep the full BSDF: they are neither in the environment map nor in the
  screen-space color, so their specular highlights are computed as direct lighting. Only the diffuse
  part takes the MIS weight against the cosine continuation, which cannot sample the specular part
  (weight 1). Shadow flag bit 30 marks these samples; their direct specular goes to the bypass, not NRD.
- **Primary continuation** samples the cosine hemisphere around the shading normal, weighted by the
  diffuse part of `EvalPdf` (`f * |cos|`, coat and fuzz attenuation included). Later bounces keep the
  full BSDF: the diffuse lighting of the primary surface integrates all incident radiance.
- **Transmissive materials** (`transmissionWeight > 0`) keep the full BSDF at the primary vertex:
  neither diffuse lighting nor SSSR provides refraction. Bit 27 of the packed primary fraction marks a
  transmitted sample, whose indirect specular Finalize moves to the bypass; reflected specular is
  dropped as everywhere else.
- **Finalize** writes the NRD split as before; the specular signal holds only what SSSR replaces.

Offline frames are bit-identical to the renderer before this split (`readRadiance` A/B of six
scenes, SHARC off, fixed exposure).

## NRD: REBLUR_DIFFUSE_SH

SSSR owns an NRD instance in mode `diffuse-sh` (`DENOISERS['diffuse-sh'] = [2]`), independent of the
`nrdEnabled` / `nrdMode` selection. Prepare and Composite use their DiffSh variants
(`NRD_PASS_DIFFUSE_ONLY`): no specular inputs, and Composite outputs bypass + denoised diffuse, the
SSSR color input. The planner tests compare the mode with the wasm runtime like the other modes.

## FidelityFX passes

`ThirdParty/FidelityFX` holds the unmodified SDK 1.1.4 subset (MIT, see `VERSION.txt`).
`npm run build:sssr` (`scripts/build-sssr.mjs`) compiles `shaders/Sssr/SssrPasses.slang` to WGSL, one
module per pass (`src/generated/sssr/SssrShaders.ts`), and repacks the 1 spp blue noise sampler tables
(`SssrBlueNoise.bin`, uint8: sobol 256x256, scrambling tile 512x256, uploaded as `r32uint`).

- Each FidelityFX pass defines the `SSSR_BIND_*` / `DENOISER_BIND_*` flags of FidelityFX's DX12 pass
  wrapper (`ThirdParty/FidelityFX/hlsl`) and includes the FidelityFX header with Veach's callbacks,
  `shaders/Sssr/SssrCallbacks.hlsli`, which declares exactly those resources at fixed WebGPU bindings.
  One constant buffer (`SssrConstants`, 512 bytes, `src/render/sssr/SssrConfig.ts`) serves SSSR and
  the denoiser; matrices are column-major (`-matrix-layout-column-major`).
- The callbacks read Veach data directly: roughness from the NRD region and motion from the TAA buffer
  (pixels, `MotionVectorScale = 1 / size`). The ray march reads the **previous frame's linear scene
  color**: Apply writes color + reflections / pre-exposure into a ping-pong pair of `rgba16float`
  textures, and Intersect samples the previous one bilinearly at the hit's reprojected position,
  addressed like TAA history (`pixel + motion + current jitter - previous jitter`), times this frame's
  pre-exposure. Reflections therefore bounce (metals reflecting metals are not black). Without history
  (first frame, resize, suspension) or off screen it falls back to this frame's NRD composite (bypass +
  denoised diffuse). Storage textures use core WebGPU formats (variance, sample count and roughness `r32float`,
  blue noise `rgba8unorm`, average radiance `rgba16float`), all write-only.
- WGSL atomics need `atomic<T>` storage: the ray counter is `Atomic<uint>` in the callbacks, and the
  build stages the GPU headers to `.tools/sssr/gpu`, patching classify's groupshared tile counter.
- The build needs slangc with WGSL `WaveActiveCountBits` / `WavePrefixCountBits` (#13649), bool lane
  reads and `-wgsl-diagnostic off:subgroup_uniformity` (#13660): Intersect counts lanes inside its
  divergent raymarch loop. See `tools/slang/README.md`.

## Host

`src/render/sssr/SssrReflections.ts` ports the dispatch logic of `ffx_sssr.cpp` and `ffx_denoiser.cpp`:
resource sizes, the parity ping-pong of radiance, variance, sample count and average radiance
(including FidelityFX's reads of the previous frame's sample count and average radiance in resolve),
the indirect intersection (args offset 0) and denoiser (offset 12) dispatches, and the history copies
(normals, roughness, depth). Textures are created zeroed, so FidelityFX's first-frame clears are not
needed; a resize or suspension recreates them and restarts the history. Requires `subgroups` and
`float32-filterable` (r32float history is sampled linearly).

Veach's own passes:

- **Prepare** writes depth hierarchy mip 0 and normals. The projection is inverted and infinite
  (`depth = near / viewZ`, 0 without a surface, `FFX_SSSR_OPTION_INVERTED_DEPTH`), in NRD's view space
  (X right, Y up, Z forward), and maps FidelityFX's pixel-center UVs to the path tracer's jittered rays.
- **Downsample** builds the closest-depth mips (max for inverted depth, odd sizes include the extra
  row/column) instead of FidelityFX's SPD, whose single-pass global atomic WebGPU cannot synchronize.
  FidelityFX's mip count: `min(7, ceil(log2(max(width, height))))`.
- **EnvironmentDownsample** builds a box-filtered equirect mip chain of the environment for
  FidelityFX's fallback lookups (mip = perceptual roughness * max mip), rebuilt when the environment or
  the procedural sky changes. The sun is an analytic light and not part of it.
- **Apply** writes the TAA input layout: color + reflections * (F0 * A + B), with the split-sum GGX LUT
  (32x32, height-correlated Smith, generated by `brdfLut`) and F0 = lerp(0.04, albedo, metalness) as
  in NrdPasses.slang.

## Parameters

The FidelityFX sample's defaults (`SSSR_DEFAULTS`): temporal stability 0.7, depth buffer thickness
0.015 (view-space units), 128 traversal iterations, minimum occupancy 4, 1 sample per quad, variance
guided tracing. The roughness threshold (squared roughness) defaults to 0.6 instead of 0.2: Veach's
interiors are lit indirectly, and the unoccluded environment fallback leaks there.

## Limitations

- Screen space: reflections of off-screen or occluded geometry fall back to the unoccluded environment,
  which leaks light indoors (e.g. the upper side of a range hood reflecting the ceiling).
- Emissive triangles reflect only through SSSR: off-screen emitters produce no glossy highlights.
  Highlights of the sun and analytic lights are direct lighting; on near-mirror surfaces (no NEE below
  `NEAR_SPECULAR_ALPHA`) they are missing, since the continuation does not sample the specular lobe.
- One GGX lobe per pixel: coat, sheen and specular color are approximated by the base roughness and
  F0 = lerp(0.04, albedo, metalness). Transmission stays path traced and is not denoised by NRD.
- The environment fallback is a box-filtered mip chain, not a GGX-prefiltered cubemap.

## Validation

`tests/sssr/config.test.ts` checks the projection convention (traced rays land on FidelityFX pixel
centers with depth near / viewZ), the constant layout and the BRDF LUT. Live checks render the
kitchen and MetalRoughSpheres scenes with `?sssr=1` (no WebGPU or console errors) and compare against
offline references; debug view 3 verifies the camera reconstruction on the GPU.
