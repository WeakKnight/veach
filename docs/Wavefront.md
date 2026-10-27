# Wavefront implementation and performance experiment

Work started 2026-10-28 02:14 Hong Kong time (2026-10-27 18:14 UTC).
The requested investigation lasts at least eight hours, through 10:14 Hong Kong time,
and includes implementation, repeated measurements, correctness checks, and optimization.
The megakernel remains the reference for image and performance comparisons.

## Fixed research scenes

From `E:/GitHub/gltf-research-scenes/scenes`, use the extended GLBs for:

| Scene | Coverage |
| --- | --- |
| classroom | Interior, many materials, textures, clearcoat |
| breakfast-room | Interior, textured indirect lighting |
| bmw-m6 | Dense geometry, metals, clearcoat, transmission |
| glass-of-water | Transmission and emissive lighting |
| veach-mis | Roughness variation, emitter sizes, direct-light MIS |

Use the first embedded camera, 640x360, eight bounces, no firefly clamp, manual
exposure, no local exposure, and no denoiser. The first three scenes use Veach's
default sky/sun; the last two use their emissive geometry with environment/sun off.
These are controlled renderer comparisons, not reproductions of the original PBRT lighting.
Standard smoke cases additionally cover alpha masking/blending and other BSDF features.

## Measurement

`node scripts/wavefront-benchmark.mjs --out .tools/wavefront/baseline` runs all five.
Optional arguments: `--mode`, `--only` (comma-separated names), `--width`, `--height`,
`--samples`, `--repeats`, `--warmup`, `--bounces`, and `--scenes`.

The harness enables timestamp queries only in its own browser context. It measures
compute passes labelled `pathTracing` or `wavefront.*`, records each stage, and stores
individual sample timings, repeated runs, adapter/browser identity, input hashes,
camera, scene/VT statistics, screenshots, and linear RGB float32 output. Compilation,
scene loading, and texture warmup are separate. Residency is frozen after warmup for
repeatable measurements; ordinary streaming remains covered by smoke tests.
GPU pass timings exclude command dispatch gaps/copies. The harness now also records the
GPU span from the first trace pass to the final trace pass, including inter-stage gaps,
plus CPU/readback wall time. Shader and host source hashes identify uncommitted variants.
`--diagnose` records queue counters after compactions for the first measured sample.
Screenshot exposure is lifted only after measurement/HDR capture (4/6/2/0/0 stops in
scene-table order); the HDR and all tracing use the same manual exposure setting.

## Design constraints

- Keep at most eight storage buffers per stage. Pack work data into existing bindings.
- Preserve all path state needed for MIS, absorption, ray cones, random sequences and AOVs.
- Preserve VT feedback and streaming, including alpha-tested traversal and emissive sampling.
- Keep material graph evaluation and BSDF sampling together initially; isolate ray traversal.
- Use GPU queue counts/indirect dispatch rather than per-stage CPU readback.
- Explore compaction, shader/program grouping, opaque traversal, and specialization based on measurements.
- Commit generated shader outputs and keep the megakernel available for A/B testing.

## Cycles reference and register-pressure hypothesis

The local `E:/GitHub/cycles` implementation uses the same broad decomposition on GPU:
`src/kernel/integrator/shade_surface.h` evaluates surface shaders, samples direct light,
and samples the continuation BSDF in the shading stage; closest-hit and shadow traversal
are separate scheduled kernels. `src/integrator/path_trace_work_gpu.cpp` builds queued
path arrays and groups surface work by shader, with partitioned sorting on supported devices.
Integrator state is stored between kernels rather than keeping the entire path live.

Wavefront does not remove SVM storage. `src/kernel/svm/svm.h::svm_eval_nodes` still declares
`float stack[SVM_STACK_SIZE]`. Veach likewise retains its 16-entry float4 VM stack in
`MaterialProgram.slang`. These source-language local arrays are not proof that every slot
resides in a hardware register: dynamic indexing and compiler decisions may produce private
memory accesses or spills. The intended benefit is smaller live state and independently
compiled resource usage for traversal versus shading. Shader grouping can improve control
flow and locality without necessarily changing the shading kernel's register allocation.

Timestamp improvements below establish performance changes, not measured register counts
or occupancy. WebGPU exposes neither directly in this harness. Queue traffic, compaction,
dispatch boundaries, and underfilled late bounces can outweigh the resource benefit.
Cycles' host/device scheduling cannot be copied directly into a browser loop that reads back
queue counts each bounce; this implementation uses GPU compaction and indirect dispatch.

## Evidence log

- Initial checkout clean; working branch `codex/wavefront-path-tracing`.
- Initial `npm test`: 14 files, 156 tests passed.
- Baseline smoke: all 21 cases passed; alpha/transmission screenshots inspected.
- `.tools/wavefront/baseline-v1`: five scenes, 3 x 32 timed samples, NVIDIA Lovelace,
  Chrome 155. Median-of-repeat GPU ms/sample: classroom 14.673, breakfast-room 6.820,
  bmw-m6 5.097, glass-of-water 6.603, veach-mis 2.407. Some repeats show GPU timing
  variability, so later comparisons must be interleaved and repeated.
- Initial staged implementation (`staged-v1`): all five linear HDR captures are
  bit-identical to baseline at 32 spp. GPU times: 15.118, 11.269, 9.759, 9.232,
  3.617 ms/sample respectively. This implementation has fixed-size dispatches and
  is slower; it is a correctness checkpoint, not the final optimization.
- Stage measurements show traversal dominates the larger scenes. Next: compact live
  path/shadow queues and use indirect dispatch without adding a storage binding.
- Queue implementation uses a separate compaction shader viewing the same work buffer
  as atomic uint words. Other stages use ordinary float4 accesses. Workgroups prefix-sum
  live flags and reserve queue ranges with one atomic add per workgroup. GPU-generated
  dispatch arguments are copied to an INDIRECT-only buffer; no CPU queue readback.
- `compact-v1`, `compact-opaque-v1`, and `compact-swizzle-v1` remain bit-identical on
  all five scenes. Queue compaction at 65,536 paths/tile regresses most scenes. Opaque
  traversal variants eliminate the opacity SVM for scenes without alpha-tested instances;
  they help modestly. Restoring 8x8 pixel grouping alone does not resolve the slowdown.
- `compact-diagnostic-bmw`: final bounces have only 55-778 paths per tile, yet four
  separate tiles still pay traversal latency. Testing larger batches next.
- `compact-large-v1`: increase tile capacity to 262,144 (still clamped by device limits).
  All five remain exact. Classroom improves to 11.34 ms total GPU span, but three
  other scenes still regress substantially relative to the initial baseline.
- `compact-soa-v1`: change work records from AoS to float4 field arrays (SoA). All five
  still bit-identical at 32 spp. Total GPU spans: 8.910 / 6.450 / 5.630 / 4.298 / 2.022
  ms in scene-table order. This is a material improvement, but BMW still regresses and
  the original baseline had clock variability. Cross-run/interleaved evidence remains needed.
- Benchmark now requests exactly eight storage buffers per stage by default, independently
  of the adapter's larger limit. `--storage-buffers` and `--clamp` permit explicit checks.
- Full wavefront smoke: all 21 cases pass, including alpha, transmission, clearcoat,
  spec-gloss and diagnostic views (the latter intentionally use the megakernel). Alpha,
  transmission and clearcoat screenshots inspected. Unit tests remain 156/156; typecheck passes.
- `edge-mega-v1` / `edge-wave-v1`: 641x359, one bounce, firefly clamp 2, four samples,
  exactly eight storage buffers, BMW and Veach MIS both produce bit-identical HDR.
  Low bounce counts still favor the megakernel; this is not yet a universal replacement.
- `ab-lean-v1`: intersection now writes only radiance/liveness; opaque traversal does
  not load/store VT feedback. Two interleaved rounds reverse integrator order per scene,
  each with 2 x 32 timed samples. Chrome updated to 156, so both modes were remeasured.
  All five captures remain bit-identical. Median-of-repeat total GPU spans, mega/wave:
  classroom 15.131/8.871, breakfast 7.053/6.487, BMW 4.229/5.606,
  glass 6.522/4.295, MIS 2.402/2.116 ms/sample. BMW's fresh reference is faster than
  the original baseline, making its regression about 33%, not the earlier estimate of 10%.
  `scripts/wavefront-ab.mjs` preserves per-round evidence and aggregate comparisons.
- `node scripts/wavefront-correctness.mjs`: nine GPU cases compare radiance plus albedo
  and normal guides, including 1x1, odd dimensions, a 513x513 multi-tile image, zero/one/eight
  bounces, empty scenes, alpha, transmission, clearcoat, emission, analytic lights, and clamping.
  All are bit-identical with exactly eight storage buffers. Integrator switches and presentation
  changes are checked on the same renderer. The test pins mip choice with bias -16 to separate
  stage correctness from stochastic VT request reordering on alpha shadow rays; ordinary
  streaming and mip behavior remain covered by smoke tests rather than an exact-image claim.

## Current work allocation

Group 1 binding 0 contains the original image prefix (three float4 per pixel), then
three float4 headers, 21 float4 field arrays at the current tile capacity, then two
packed uint index queues. Each field array is SoA across paths. The tile capacity is
at most 262,144, bounded by the storage binding and allocation limits. Initial indices
map to 8x8 pixel blocks, with explicit padding checks for non-multiple-of-eight images.
The compaction shader aliases the allocation as atomic uints in separate compute passes;
no pass binds overlapping read/write aliases simultaneously. The 32-byte dispatch argument
buffer is COPY_DST | INDIRECT, not a storage buffer. Compaction and copies stay on GPU.
