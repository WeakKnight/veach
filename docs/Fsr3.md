# Realtime upscaling: FidelityFX FSR 3

Realtime frames (host frames or `settings.renderMode = 'realtime'`) upscale with **AMD FidelityFX FSR 3.1.4**
by default: the path tracer renders `settings.upscaleRenderScale` (0.7) of the presentation resolution, and FSR 3
replaces TAA's resolve. `settings.upscaler = 'none'` (viewer `?upscaler=none`, console `r.Upscaler.Mode none`) keeps
TAA at full resolution. Offline (progressive) frames, OIDN and debug views are unchanged.

```
wavefront trace at the render size (FSR jitter) -> taa.motion -> [NRD / SSSR] -> fsr3.veachInputs
  -> FidelityFX: prepare inputs, luma pyramid (+ tail), shading change pyramid, shading change, prepare reactivity,
     luma instability, accumulate (+ RCAS) -> fsr3.veachOutput -> exposure / local exposure / presentation
```

The first realtime frame loads a lazy chunk; until it is ready, or on devices without `float32-filterable`,
frames render at full resolution with TAA (`renderer.fsrStats.reason`). FSR runs only when TAA would resolve the
frame: debug views, `taaMotionVectorDebug` and viewer depth of field render at full resolution with their usual
paths. `renderer.fsrStats` reports activity, render and upscale sizes and memory; `r.FSR3.Stats` prints it.
`settings.fsrSharpness` (0.8, AMD's sample default; 0 disables RCAS) is a presentation setting.

## Why

TAA's edges shimmered: with a static camera, presented edge pixels changed by 16 % of their luminance from frame
to frame (`.tools/edge-flicker.mjs`, DamagedHelmet). FSR 3 at a 0.7 render scale changes them by 0.9 %, and flat
regions by 0.12 % instead of 0.25 %, at half the traced pixels.

## Resolution split

`Renderer.resize` keeps the canvas at the presentation size and sizes the path tracer by `upscaleRenderScale` while
`upscaleWanted()` holds (realtime, `upscaler = 'fsr3'`, FSR loaded, TAA enabled, no debug view, motion view or depth
of field); otherwise both match as before. Every render-size consumer (wavefront, NRD, SSSR, TAA motion) is
unchanged. The presentation passes read `PathTracer.presentUniformBuffer`, the frame uniforms with the presentation
size (`frame.xy`), so exposure, local exposure and present run at the upscaled size;
`setPresentationBuffer(buffer, size)` records it, and `readRadiance({ denoised: true })` returns it.

## Jitter and inputs

FSR samples pixel p at `p + 0.5 - jitter` in unjittered pixel space; the path tracer traces `p + film jitter`, so the
film jitter is `0.5 - fsr3JitterOffset(i, fsr3JitterPhaseCount(render, display))` (Halton 2, 3 of
`8 * (display / render)^2` phases). A static-camera comparison against a 256 spp reference confirms the sign (edge
error 0.107 against 0.221 for the opposite sign). `fsr3.veachInputs` converts the TAA input layout and motion:

- color: radiance (pre-exposed, HDR) -> rgba16float;
- depth: inverted infinite `0.01 / viewZ` from the primary hit distance and the jittered ray, 0 without a surface
  (`DEPTH_INVERTED | DEPTH_INFINITE`, near 0.01);
- motion: TAA's previous-minus-current render pixels without jitter, `motionVectorScale = (1, 1)`.

Exposure is FSR's own (`AUTO_EXPOSURE`), the pre-exposure Veach's. There are no reactive or
transparency-and-composition masks.

## FidelityFX passes

`ThirdParty/FidelityFX` holds the unmodified FSR 3.1.4 upscaler GPU headers, SPD, FSR1 (RCAS) and host sources.
`npm run build:fsr3` (`scripts/build-fsr3.mjs`) compiles `shaders/Fsr3/Fsr3Passes.slang` to WGSL, one module per
pass (`src/generated/fsr3/Fsr3Shaders.ts`), with the permutation FidelityFX selects for Veach's context flags on
wave32 hardware: HDR input, low-resolution motion vectors, inverted depth, reference Lanczos reprojection; FP32
(`FFX_HALF = 0`). Each pass defines the bind flags of FidelityFX's DX12 wrapper; `shaders/Fsr3/Fsr3Callbacks.hlsli`
implements the resource callbacks at fixed WebGPU bindings:

- core WebGPU storage formats at least as precise as FidelityFX's (r8 / r16 -> r32float, rg16 -> rg32float); only
  new locks (r32float) is read_write;
- the reconstructed previous nearest depth is a storage buffer of atomics (WGSL has no texture atomics) and
  FrameInfo a one-float4 storage buffer (read before written by the luma pyramid);
- SPD runs without wave operations, and without its single-pass global atomic: the tile part of `SpdDownsample`
  per 64x64 tile, then for the luma pyramid a one-workgroup tail dispatch (mips 6.. and FrameInfo) that reads mip 5
  as a sampled texture. The shading change pyramid stores mips 0..5 only, so it has no tail.

`src/render/fsr3/Fsr3Upscaler.ts` ports `fsr3upscalerCreate` and `fsr3upscalerDispatch` (resources, parity
ping-pong, first-execution, reset and per-frame clears, dispatch order and sizes); `Fsr3Config.ts` ports the
constants (`Fsr3ConstantState`, float32-faithful), jitter, `ffxSpdSetup` and `FsrRcasCon`. Inputs and output are
textures, as in FidelityFX. `src/render/fsr3/Fsr3Pass.ts` is Veach's adapter: input conversion, a context per size,
and the presentation layout (three float4 per pixel) at the upscaled size.

## Validation

`tools/fsr3-reference` checks the WebGPU port against AMD's prebuilt, signed DX12 runtime (SDK 1.1.4,
`amd_fidelityfx_dx12.dll`): `capture.mjs` records FSR's exact inputs, dispatch descriptions and WebGPU outputs from a
live realtime session (fresh context, history reset, orbiting camera); `fsr3_reference.exe` runs the same frames
through ffx-api; `compare.mjs` reports per-frame PSNR and relative errors. On DamagedHelmet, 24 frames,
448x280 -> 640x400 with RCAS: PSNR 69.8 dB minimum, 71.7 dB mean, mean relative luminance error 0.13 %, 99th
percentile 0.6 % (the DX12 runtime uses FP16 permutations on this GPU). Comparing with the next frame instead
gives 44 dB, so the metric resolves a 0.01 radian camera step. `tests/fsr3/config.test.ts` covers the host math.

## Limitations

- No reactive mask: SSSR reflections and transmission are upscaled like opaque surfaces; their motion is the
  primary surface's.
- Transmissive noise (path traced, not denoised) is preserved, as with TAA.
- The game quality presets choose the render scale (50 / 75 / 100 %) at full presentation resolution.
