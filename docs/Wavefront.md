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
`--paired --mode wavefront` alternates integrators within one renderer and scene, reversing
order each round and warming the selected pipeline for eight untimed samples before each block.
It saves separate `megakernel/` and `wavefront/` reports/captures and image errors per round.
The screenshot is placed with whichever integrator ran last. Streaming remains frozen through
presentation, so a late texture upload cannot reset the just-measured accumulation.

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
- `compact-once-v1`: skip compaction between intersection and shading, relying on Shade's
  inactive-path early return. Images remain exact, but timings are mixed: spans
  8.796/6.302/5.470/4.395/2.154 ms. Kept as evidence rather than adopting an uncertain
  small gain that regresses glass/MIS. Restored the prior schedule for subsequent experiments.
- CPU material inspection finds only 0-1 float4 live VM stack slots across the five scenes;
  all BMW/glass/MIS materials need zero. The generic shader still compiles a 16-slot array.
  Scene stack specialization is a separate hypothesis to measure, including on the reference
  megakernel so its benefit is not misattributed to wavefront scheduling.
  `node scripts/wavefront-materials.mjs` reproduces this inspection, excluding unused materials
  from its summary. The five scenes have 44/15/26/7/8 instanced materials but only 6/6/8/4/3
  distinct complete bytecode blocks, respectively. Surface program offsets can group identical
  instruction streams across materials; material IDs may additionally group different BSDF
  branches caused by constants. Both are candidates for a measured sorting experiment.
- Added asynchronous compiler ownership checks: destroying a tracer while stage compilation
  is pending releases the eventual resources, and failed compilation releases resources and
  permits retry. These checks reproduced the original leak/lifecycle issues before the fix.
- `tail-2-v1`: reuse intersection/shading helpers in a fused tail kernel starting at bounce 2,
  doing direct shadow tests immediately. All five 32 spp captures remain bit-identical.
  Total spans roughly 9.30/4.59/3.85/3.62/1.69 ms. This resolves the BMW regression against
  the fresh baseline, but classroom regresses from fully staged wavefront. A fixed bounce
  threshold is therefore not yet the default. Nine GPU correctness cases also pass exactly.
- Testing adaptive tail thresholds with `--tail-start 0 --tail-threshold N`: the tail kernel
  checks the GPU queue count and returns for large queues. When it runs, it terminates all
  queued paths; normal stage liveness checks and compaction reduce later work to zero. No CPU
  queue readback. A 32,768 threshold passes all nine GPU correctness cases, including tail
  execution on small images from bounce zero. Default tuning remains fully staged for now.
- Timing scripts now average the two middle samples for even-sized medians; comparison
  recomputes medians from saved raw timings and reports the range of repeat medians. Earlier
  log entries used the upper middle sample. Interleaved runs reject source/browser changes
  and compare images from every round, not only the aggregate's final capture.
- Adaptive threshold sweep (all five captures exact at every threshold):
  8,192 paths gives spans 8.966/6.090/4.739/4.213/1.938 ms;
  32,768 gives 8.830/4.890/4.003/4.024/1.815 ms;
  65,536 gives 8.940/4.747/4.009/3.722/1.905 ms.
  The larger thresholds retain classroom's gain and avoid BMW's regression, though fixed
  bounce-2 fusion is still faster on several scenes. Adaptive scheduling overhead and threshold
  selection remain optimization targets; these are RTX 4090 measurements, not portable constants.
- Full smoke with adaptive tail (`--tail-start 0 --tail-threshold 65536`): all 21 cases
  pass; alpha and clearcoat screenshots inspected. Unit suite passes 158 tests in 15 files,
  and TypeScript checks pass. Cold wavefront pipeline compilation in the benchmark is about
  7.5 seconds on this machine, versus about 35 ms with the browser's pipeline cache populated.
  Initialization/compilation is recorded separately from tracing throughput.
- Paired harness validation at 65x63 verifies both integrator orders and exact per-round HDR.
  It ran alongside smoke only to validate harness behavior; its timings are not performance
  evidence. The subsequent full-resolution paired run executes alone.

## Experimental tail controls

`wavefront-benchmark.mjs`, `wavefront-correctness.mjs`, and `smoke.mjs --integrator wavefront`
accept `--tail-start N` and `--tail-threshold N`. These are internal investigation controls,
not public renderer settings. Threshold zero uses a fixed bounce switch; a positive threshold
enables the GPU count test. Tail pipelines include alpha-capable and opaque variants.

## Current work allocation

Group 1 binding 0 contains the original image prefix (three float4 per pixel), then
three float4 headers, 21 float4 field arrays at the current tile capacity, then two
packed uint index queues. Each field array is SoA across paths. The tile capacity is
at most 262,144, bounded by the storage binding and allocation limits. Initial indices
map to 8x8 pixel blocks, with explicit padding checks for non-multiple-of-eight images.
The compaction shader aliases the allocation as atomic uints in separate compute passes;
no pass binds overlapping read/write aliases simultaneously. The 32-byte dispatch argument
buffer is COPY_DST | INDIRECT, not a storage buffer. Compaction and copies stay on GPU.
