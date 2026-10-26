# OIDN denoising

The `oidn-webgpu` 0.6.0 integration uses the renderer's GPUDevice and HDR inference.
New renderers default to OIDN enabled and `maxSamples: 128`. The bundled HDR model loads
asynchronously in a separate lazy chunk, alongside tracing. No model URL is required.
`Renderer.create(canvas, { denoiser: null })` disables model/inference downloads;
`setDenoiser({ type: 'oidn' })` enables the bundled model again. Optional `weights` accepts
an application-hosted URL or TZA bytes. See
[the upstream browser contract](https://github.com/pissang/oidn-webgpu/blob/aee3d609e1d45eb14da7c3010bb9aa4bd9988d6c/docs/web.md).

## Pipeline

1. PathTracing accumulates three float4 values per pixel: pre-exposed linear HDR radiance,
   primary-hit linear base color, and the facing world-space shading normal (including normal maps).
   These guides use the same camera jitter, depth of field, visibility and material sampling as beauty.
2. The independent `OIDNGuides.Prepare` compute pass produces tightly packed RGBA float32
   `color`, `albedo` and `normal` storage buffers. Color is nonnegative, albedo clamps to [0,1],
   and normals use `n * 0.5 + 0.5`, as required by **oidn-webgpu**, rather than OIDN's native
   signed-normal convention. Non-finite guide components become zero before encoding.
3. OIDN runs on these immutable snapshots, in tiles (default output tile edge 256).
4. `OIDNGuides.Compose` copies the denoised color plus original guides into a separate buffer
   with Veach's three-float4 layout. Histogram exposure, local exposure and presentation all
   read this buffer. ACES2 and custom display LUTs operate afterwards, unchanged.

The guiding pass has its own bind group (one uniform, four storage buffers); it does not add
storage buffers to the path tracer's already-full scene layout. There is no GPU-to-CPU image
round trip. Normals are not renormalized after averaging, preserving coverage information.
Misses have albedo zero and signed normal zero, encoded as (0.5,0.5,0.5).

Guides are sampled averages, **not noise-free guides**: use `rt_hdr_alb_nrm.tza` or its
`_small` variant, not `rt_hdr_calb_cnrm` models. The albedo currently represents primary-hit
base color; guides do not trace through mirrors or glass, or estimate a full layered-BSDF
reflectance. This can limit reconstruction behind specular/transmissive surfaces at low spp.

Color keeps the fixed accumulation pre-exposure; inference output has the same scale. It never
includes display exposure, local exposure or tone mapping. `readRadiance()` still returns the
untouched original scene-linear image. `readRadiance({ denoised: true })` reads the current
presentation source and removes pre-exposure; it falls back to the original until ready.

## Scheduling and lifetime

- Enabled + beauty mode + `maxSamples > 0` + converged: run once per accumulation/sample count,
  after pending virtual texture feedback/uploads have settled. Unlimited sampling does not trigger.
  Unmet texture demand is not treated as queued work: a full cache cannot block denoising forever.
- Reset, resize, scene/environment changes or resumed tracing invalidate the result. A changed
  camera must call `resetAccumulation()`, as with normal rendering/OrbitController.
- Snapshot buffers remain alive until in-flight inference settles. Invalidated work may finish
  on the GPU, but cannot replace the new image; no second inference runs concurrently.
- Disabling/replacing a model releases idle resources immediately; in-flight resources retire on
  completion. Destroying the renderer also destroys its device. Pending URL downloads are aborted.
- Exposure/LUT changes keep the same denoised HDR result and sample count.
- Failures retain the raw image and expose an `error` state. No per-frame retry loop: set the
  denoiser again or reset accumulation to retry an inference failure. Load failures require a new
  `setDenoiser` call. Superseded configuration requests resolve `false`.

`renderer.denoising` and `RendererStats.denoising` provide immutable state with status,
progress (0..1), source sample count, duration when complete, and an error string on failure.
Polling/rendering continues via `renderer.start()` or repeated `renderFrame()` calls; completion
also presents once for a manually rendered/paused client. `stop()` pauses tracing, but does not
cancel an already-running denoise; `setDenoiser(null)` disables it and invalidates its result.

The device requests optional `shader-f16` when available. OIDN falls back to fp32 otherwise.
The integration uses HDR/aux/PU models; LDR, lightmap-log and clean-guide models are not supported
by this adapter. Applications may use `createDenoisingInputs()` with their own integration.

## Validation

`npm run smoke:oidn` downloads the pinned, hash-checked 1.84 MB HDR model to ignored
`public/samples/oidn/` for external-model tests. The bundled copy is
`src/render/denoise/weights/rt_hdr_alb_nrm.tza` (same pinned hash). It checks actual GPU guide encoding, background/AA normals, synthetic
noise reduction, unchanged raw accumulation, presentation changes, stale work and model lifetime.
It also verifies that an unconfigured renderer converges at 128 samples and denoises using
the bundled model. The model uses Apache-2.0; see `licenses/oidn-weights-Apache-2.0.txt`.
The library uses MIT.
