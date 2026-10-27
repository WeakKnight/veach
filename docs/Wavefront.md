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
`--material-stack auto` (default) uses production scene capacity selection; explicit
1/2/4/8/16 forces a capacity for controlled comparisons and rejects undersized choices.
Both integrators use the same capacity. The harness checks submitted WGSL array sizes
and records the selected capacity, generated variant table, and relevant source hashes.
It also records material stack histograms, constant/textured material counts and distinct
bytecode blocks, including fallback and unused materials as in the scene-wide capacity bound.

The harness enables timestamp queries only in its own browser context. It measures
compute passes labelled `pathTracing` or `wavefront.*`, records each stage, and stores
individual sample timings, repeated runs, adapter/browser identity, input hashes,
camera, scene/VT statistics, screenshots, and linear RGB float32 output. Compilation,
scene loading, and texture warmup are separate. Residency is frozen after warmup for
repeatable measurements; ordinary streaming remains covered by smoke tests.
GPU pass timings exclude command dispatch gaps/copies. The harness now also records the
GPU span from the first trace pass to the final trace pass, including inter-stage gaps,
plus CPU/readback wall time. Shader and host source hashes identify uncommitted variants.
`--diagnose` records queue counters and both indirect dispatch bounds after compactions for
the first measured sample, checking them against the tile size and selected compaction mode.
`node scripts/analyze-wavefront-stages.mjs REPORT_DIRECTORY` sums stage and bounce timings
over the recorded samples, checks that attribution equals total GPU pass time, and writes
`stage-analysis.json`. These are arithmetic means, distinct from the comparison's medians.
Screenshot exposure is lifted only after measurement/HDR capture (4/6/2/0/0 stops in
scene-table order); the HDR and all tracing use the same manual exposure setting.
`--paired --mode wavefront` alternates integrators within one renderer and scene, reversing
order each round and warming the selected pipeline for eight untimed samples before each block.
It saves separate `megakernel/` and `wavefront/` reports/captures and image errors per round.
The screenshot is placed with whichever integrator ran last. Streaming remains frozen through
presentation, so a late texture upload cannot reset the just-measured accumulation.
Add `--tail-sweep` to measure multiple schedules within that same renderer/residency: the
requested base schedule, fully staged, fixed fusion at bounces 0/1/2/3, and adaptive fusion
at 8,192/32,768/131,072 active paths. Use base `--tail-start 0 --tail-threshold 65536` to
include that threshold as well. Each round rotates/reverses execution order, checks every
variant against the reference HDR, and saves separate standard reports/captures by variant.
Any paired HDR difference above 1e-5 now fails the benchmark rather than only logging it.
`node scripts/compare-wavefront-sweep.mjs SWEEP_DIRECTORY` validates source/browser identity,
every saved HDR and per-round comparison, then writes a combined timing table and JSON report.
Startup records include submitted material shader capacities and compute pipeline compile
durations. The harness selects wavefront on the empty scene, then scene loading prepares
only the capacity needed by the incoming geometry.

`--compaction dense|queued|subgroup|adaptive|packet|none` selects the internal queue implementation. Dense is
the conservative default; queued scans only input indices, and subgroup uses the same queued
layout with subgroup arithmetic and one global reservation per workgroup. `--compaction-sweep`
compares the supported modes within one renderer using the requested tail schedule; it is separate from
`--tail-sweep`. Adaptive scans physical slots above half occupancy and the input queue below
that threshold. `--disable-subgroups` tests adapters without that optional device feature,
omitting the subgroup variant from a compaction sweep.
`packet` retains all valid slots in nonempty physical groups, supports fixed tails only,
and is omitted from sweeps with positive adaptive-tail thresholds.
`--packet-stages MASK` controls which queues retain packets: intersection bit 1, shading
bit 2, shadow bit 4. Other queues compact individual live paths using the same physical
scan and prefix sums. The default is 7; mask 0 behaves like dense per-path compaction,
and mask 5 retains traversal packets while packing shading lanes. The mask occupies a
previously unused uint in the existing 32-byte dynamic uniform, with no new resource.
`--packet-sweep` tests all eight masks in the same scene/residency and is mutually exclusive
with other sweeps. The GPU correctness harness supports the same sweep. Diagnostics report
main and shadow count units separately because their retention policies can differ.
`none` uses separate direct-slot entry points for intersection, shading and shadow, with no
compaction passes or indirect-argument copies. It preserves pixel groups and returns early
for inactive slots. This mode supports fully staged execution and fixed tails; sweeps omit
it when an adaptive tail is requested, and its tail sweep includes only fixed schedules.
The initial identity queue remains available to fixed tails; work allocation is unchanged.
`--direct-stages MASK` independently selects direct intersection (bit 1), shading (bit 2),
and shadow (bit 4); other stages use the selected compaction mode. Mask 7 skips compaction
entirely, like `none`, and supports only fixed tails. Partial masks keep queue counts valid
for adaptive tails. `--dispatch-sweep` interleaves all eight masks (seven for adaptive tails)
with the megakernel, separately from tail/compaction sweeps. The correctness harness also
supports this sweep to check every stage combination against the same full-stack reference.

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
`float stack[SVM_STACK_SIZE]`. Veach likewise retains a scene-sized float4 VM stack in
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
- `paired-tail-65536-v1`: five rounds per scene, each 32 samples per integrator in the same
  renderer with alternating order. All 25 paired HDR comparisons are bit-identical. Total-span
  medians (mega/wave) are 15.116/8.790, 6.743/4.813, 4.286/4.104, 6.608/3.764,
  2.405/1.917 ms. Corresponding speedups: 1.72/1.40/1.04/1.76/1.25x. BMW's small gain
  overlaps some reference repeats; retain the raw ranges rather than claiming a robust large win.
  The reference also shows first-block variability despite warmup, motivating longer paired runs.
- A third compiler-lifetime regression test covers disposal between compilation completion and
  promise delivery. It reproduced a remaining leak and now passes. Full suite: 159 tests,
  TypeScript and library build pass after the fix.
- `paired-stack-1-v1`: compile both complete integrators with a one-slot SVM, including
  opacity/emission interpreters, using separately generated investigation modules. The benchmark
  rejects scenes whose compiled stack bound exceeds the selected capacity and hashes the served
  shader variant. All images match the full-stack references exactly. Mega/wave total spans:
  10.283/8.552, 4.343/4.706, 2.929/3.957, 3.100/3.515, 1.822/1.670 ms. The megakernel gains
  1.32-2.13x relative to its 16-slot version and now wins breakfast/BMW/glass. Wavefront gains
  only about 2-15%. The new reference must include this optimization; the earlier wavefront
  speedups cannot be carried over unchanged. Production selection/fallback remains to implement.
- `paired-stack-1-tail-0-v1`: a fused kernel from bounce zero improves over the one-slot
  megakernel by about 4-6% on all five scenes, with exact output in all 25 pairs. This is
  effectively a megakernel with opaque traversal specialization and staged input/output,
  not evidence for wavefront decomposition. The staged version remains better in classroom
  and MIS; fixed tail choices still depend on scene workload. Shader-module interception
  verifies that the actual GPU modules contain one-slot VM arrays in both integrators.
- Capacity sweeps `paired-stack-{2,4,8}-v1` each run three paired rounds on all five scenes;
  every saved HDR comparison remains exact. Megakernel total-span medians at capacity 2:
  11.284/4.499/3.023/3.258/1.968 ms; capacity 4: 11.208/4.578/3.044/3.383/1.987;
  capacity 8: 11.889/5.172/3.208/3.532/2.095. Corresponding wavefront medians are
  9.038/4.758/3.895/3.759/1.701, 8.791/4.737/3.924/3.814/1.713, and
  8.686/4.791/3.904/3.859/1.734. Capacity configurations were not interleaved with each
  other, so small cross-capacity differences are not proof of a monotonic hardware effect.
- Production integration selects a safe scene capacity for both integrators, lazily compiles
  and caches pipelines, and keeps the old scene bound until preparation succeeds. Generated
  variant edits reconstruct exact independently compiled Slang output. Unit coverage includes
  capacity bounds, stale generated data, CRLF checkout handling, shared concurrent compilation,
  failed compilation retry, and disposal during compilation. GPU equivalence and smoke checks
  cover materials requiring up to nine slots.
- `paired-auto-stack-v1`: production capacity selection chooses one slot for all five scenes.
  Three paired rounds each are exact (15/15); saved outputs also match the earlier 16-slot
  reference exactly. Mega/wave span medians: 10.106/8.572, 4.328/4.717, 2.860/4.058,
  3.260/3.615, 1.831/1.657 ms. Wavefront wins classroom/MIS but loses the other three.
  Classroom/BMW screenshots inspected. This run exposed redundant startup compilation:
  initialization selected 16 slots, then scene loading compiled one slot, adding about 15 s
  to load time. Initialization now selects one slot and prepares larger capacities only when
  needed; startup measurements are being repeated. No tracing shader logic changed.
- Expanded GPU equivalence harness: 24 comparisons against fixed 16-slot megakernel all have
  zero error in radiance/albedo/normal. Includes automatic capacities 1/2/4/8/16, alpha with
  pinned mip selection, transmission, clearcoat, emission, analytic lights, helmet, spec-gloss,
  and anisotropy; empty odd-sized/multitile images and presentation/switching checks remain.
  Full unit suite: 175 tests pass, as does TypeScript checking.
- After selecting one-slot initialization, all 21 megakernel smoke cases pass with ordinary
  texture streaming. Alpha/anisotropy screenshots inspected. Library build and a fresh full
  `build:shaders` succeed; generated reconstruction tests pass against the rebuilt variants.
  Adaptive wavefront smoke and startup measurements are next.
- Stage attribution for `paired-auto-stack-v1` shows tail execution consumes about 48% of
  GPU pass time in breakfast/BMW/glass, versus 12% in classroom. Compaction is about 5-7%
  in these four and 12% in MIS. Empty late-bounce passes alone cannot explain BMW's regression;
  retune tail execution after stack specialization and investigate ray/queue coherence before
  assuming material interpreter or compaction cost is the dominant remaining bottleneck.
- `sweep-harness-check`: two rounds across nine schedules at 65x63, all 18 comparisons exact
  and all ten saved HDR files (including reference) hash-identical. This ran concurrently with
  smoke to validate harness behavior only; its timings are not performance evidence.
- `sweep-harness-check-v2` adds a third rotated round (27 exact comparisons), explicit planned
  scene/completion metadata, and pipeline compilation records. A partial or source-mutated run
  cannot pass the sweep summary. All source files, generated assets, dependency lockfile, Vite
  configuration, and benchmark code are now fingerprinted and checked again before completion.
- All 21 adaptive wavefront smoke cases pass after automatic stack selection; alpha/clearcoat
  screenshots inspected. Repeated Helmet pages take around 40 s because the viewer compiles
  one-slot wavefront before loading an eight-slot material scene. The viewer now loads the
  initial scene before enabling wavefront, matching the updated benchmark initialization order;
  full smoke is being repeated for this change. Full-staged GPU equivalence is also running,
  since the small adaptive correctness cases mostly choose fused execution immediately.
- Fully staged automatic-capacity correctness also passes all 24 comparisons with zero error
  (`correctness-tail-999-0`). The viewer order change alone has not eliminated repeated
  compilation: subsequent Helmet cases still take roughly 35-39 s. An unintegrated empty-scene
  specialization now compiles to 19,134 bytes versus about 273 KiB for the full module, with no
  SVM/BSDF/traversal functions. Its ordinary build remains byte-identical to the existing shader.
  It shares the camera, analytic-light, environment, feedback, and accumulation code; a new
  geometry-free analytic-light regression case will verify that lights remain visible.
- Empty-scene startup is now integrated: the generated module is 18.0 KiB and the full
  default shader remains unchanged. Geometry-free scenes use it in both integrator modes;
  explicit stack overrides retain the full reference for equivalence tests. The viewer selects
  wavefront before scene loading again, but now this defers compilation rather than compiling
  unused stages. Scene loading prepares reference and wavefront pipelines concurrently.
  Benchmark `loadMs` now includes that compilation; `integratorInitMs` measures empty-scene
  mode selection. Compare total startup time or individual pipeline records across versions.
  All eight empty-sky/analytic-light GPU comparisons pass with zero error against the full
  16-slot reference, including 1x1 and 513x513 dimensions. Unit tests: 176 passed; typecheck passed.
  Full staged geometry regressions pass all 28 comparisons with zero error. Eight additional
  adaptive comparisons pass while loading scenes with wavefront selected, covering empty to
  geometry and back without changing the mode during scene replacement. Empty-scene tests
  no longer exercise tiled wavefront dispatch, so the geometry analytic-light case also
  includes 513x513 coverage. All 21 adaptive wavefront smoke cases pass; empty sky, HDR helmet,
  and alpha screenshots inspected. Library build passes. The first smoke pages overlapped
  functional correctness testing, so their wall times are not a controlled startup benchmark.
- A separate compile-only prototype containing Initialize/IntersectOpaque/ShadowOpaque/Finalize
  produces 47,656 bytes. Compiling with stack capacity 1 or 16 produces identical SHA256,
  confirming these stages can share one module/pipeline set across material capacities.
  This prototype is not yet integrated or GPU-tested.

## Next experiments

The automatic-stack tail sweep (`tail-sweep-auto-v1`, revision `5ba074e`) completed all five
scenes, nine wavefront schedules and three paired rounds: all 135 HDR comparisons are exact.
All five screenshots were inspected. Median GPU spans (ms/sample):

| Schedule | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel | 10.392 | 4.337 | 2.882 | 3.217 | 1.819 |
| Fully staged | 8.465 | 6.206 | 5.547 | 3.929 | 1.839 |
| Fixed tail at 0 | 9.564 | 3.974 | 2.824 | 3.095 | 1.713 |
| Fixed tail at 1 | 9.112 | 4.107 | 3.530 | 3.709 | 1.767 |
| Fixed tail at 2 | 8.893 | 4.457 | 3.749 | 3.387 | 1.439 |
| Fixed tail at 3 | 8.437 | 4.592 | 4.072 | 3.309 | 1.380 |
| Adaptive 65,536 | 8.611 | 4.611 | 4.006 | 3.561 | 1.649 |

No single split wins on every scene. Fixed-0 remains effectively fused execution, so its
results do not establish a benefit from stage decomposition. Fully staged traversal and
shadow passes account for 76-84% of GPU time in classroom/BMW/glass and 84% in breakfast;
compaction is 4.5-7% there and 13% in MIS. Queue coherence deserves attention alongside VM cost.
Initialization now takes 302-534 ms in this run; first classroom load includes 8.2 s of tail
pipeline compilation, while later pages benefit from cached pipelines. These are observations
from this browser session, not a controlled cold-cache startup comparison.

- Finish GPU validation of automatic scene stack selection against the full-stack reference,
  including larger surface programs and emission/opacity evaluation. Measure compilation cost.
- Measure the light empty-scene startup pipeline, and consider sharing capacity-independent
  wavefront stages to reduce repeated compilation. Measure a constant-only interpreter path for
  compiler-reported zero-slot scenes without confusing its gains with scheduling changes.
- Compare shader-program/material sorting and avoid assuming it helps already coherent glTF work.
- Reduce the empty dispatch/compaction overhead after an adaptive tail finishes, and test
  thresholds across resolutions and bounce counts rather than hardcoding this GPU's best result.
- Investigate ping-pong main-path index queues. Intersect reads A, its compaction writes B,
  Shade reads B, and its compaction writes A; shadow indices stay separate. Compact can then
  dispatch over the previous active queue instead of scanning every physical path slot.
  Keep separate A/B counts in the existing header so clearing the output count does not
  destroy the input count. Separate input/output arrays avoid in-place compaction races.
  This adds one uint index per slot inside the existing allocation, not a storage binding.
  The first implementation passes 176 unit tests, typecheck, and ten GPU comparisons
  covering alpha, geometry with analytic lights at 513x513, and return to an empty scene.
  A full nine-schedule paired sweep is running. Input queue order is now carried between
  stages, which may change ray coherence; reduced compaction work alone is not sufficient
  evidence that the renderer is faster.
  The completed first sweep (`tail-sweep-pingpong-v1`) keeps all 135 HDR comparisons exact
  but regresses performance. Fully staged classroom rises from 8.465 to 9.759 ms; its
  compaction arithmetic mean rises from 0.520 to 1.698 ms while traversal/shading change
  much less. The generated kernel atomically loads the shared input count in every lane.
  A follow-up now loads that immutable count once per workgroup into shared memory; the
  next paired full-stage run tests whether this removes the contention hypothesis.
  `paired-pingpong-groupcount-v1` confirms the hot-count load was costly: classroom
  compaction falls to 0.539 ms, though overall 8.764 ms still trails the old dense queue's
  8.465 ms in the earlier run. All 15 paired comparisons are exact. Adaptive follow-up
  `paired-pingpong-groupcount-tail-v1` also completes all five scenes; its results are mixed.
  The next variant uses subgroup prefix sums and one reservation per subgroup, without
  assuming subgroup width or mapping from local invocation indices. Devices without the
  optional `subgroups` feature retain the workgroup scan. Both benchmark and correctness
  scripts accept `--disable-subgroups` to explicitly test that fallback.
  Per-subgroup global reservations (`paired-subgroup-v1`) are also slower: classroom
  compaction is 0.763 ms and MIS is 0.323 ms. The next revision aggregates subgroup totals
  through workgroup-local atomics, retaining one global reservation per workgroup with
  three barriers instead of the fallback scan's fifteen. It still avoids subgroup-ID/layout
  assumptions. This is an investigation variant, not a demonstrated speedup yet.
  The grouped subgroup revision also fails to establish a benefit in classroom/MIS. All three
  implementations are now selectable in one renderer for interleaved measurement; dense
  scanning remains the default until a replacement demonstrates a repeatable advantage.
  `compaction-sweep-v1` interleaves all three methods in one renderer and completes all 45
  HDR comparisons exactly. Dense/queued/subgroup GPU spans are 8.595/8.750/8.772 ms for
  classroom, 6.393/6.041/6.040 for breakfast, 5.619/5.495/5.477 for BMW,
  4.004/3.943/3.965 for glass, and 1.873/1.832/1.849 for MIS. Queue-driven scanning helps
  some workloads but no method wins universally, and subgroup adds no clear gain here.
  Keep dense as the default and retain the other modes as explicit experiments for now.
  The grouped subgroup implementation passes all 30 GPU reference comparisons, including
  alpha, transmission, analytic lights, all five stack capacities, padded/multi-tile images,
  and geometry-to-empty transitions. Unit tests (176), typecheck and the library build pass.
  The five `compaction-sweep-v1` screenshots have been inspected; low-sample noise remains,
  with no queue-related missing regions. All 30 explicit no-subgroup fallback comparisons
  also pass exactly; the report confirms the device feature is absent.
  The full 21-case wavefront smoke suite with adaptive tail threshold 65,536 passes.
  Empty sky, HDR helmet and alpha screenshots were inspected after that run.
  Next hypothesis: use physical-slot scanning while the input queue exceeds half the tile,
  then switch to queued scanning as it becomes sparse. The next dispatch must cover the full
  tile in dense mode; generating that bound from the output count avoids CPU readback and
  additional storage bindings, at the expense of extra inactive shading/traversal invocations.
  This is an experiment to measure, not an assumed improvement.
  The density-adaptive implementation passes 30 exact GPU comparisons with subgroups
  disabled, 176 unit tests, typecheck, library build, and smoke renders of HDR helmet,
  alpha and transmission (alpha/transmission screenshots inspected). The first four-mode
  five-scene sweep (`compaction-adaptive-sweep-v1`) completes all 60 HDR comparisons exactly.
  Adaptive versus dense GPU spans are 8.589/8.729 ms (classroom), 6.055/6.358 (breakfast),
  5.572/5.551 (BMW), 3.836/3.973 (glass), and 1.842/1.887 (MIS). These modest improvements
  need repeated and higher-resolution checks before changing the default. BMW still favors
  the purely queued scan (5.422 ms), and full staging remains slower than the reference in
  breakfast/BMW/glass. Queue optimization alone does not close that gap.
  `compaction-adaptive-diagnostics-v1` checks the generated dispatch bounds after every
  queue update in classroom and breakfast. Classroom remains dense through the intersection
  at bounce 3, then switches after shading (104,392 of 230,400 slots); breakfast switches
  after bounce-0 shading (113,149 slots). Both branches are exercised and both HDR comparisons
  remain exact. Diagnostic-copy timings are not used as performance evidence.
  The 1920x1080 follow-up (`compaction-adaptive-1080p-v1`, same five scenes, 32 samples,
  three interleaved rounds) passes all 60 comparisons exactly. Adaptive/dense spans are
  73.458/73.374, 41.247/42.424, 38.058/38.950, 27.943/28.915 and 16.008/16.545 ms.
  Classroom is effectively tied; the other four improve by about 2-3.4%. The screenshot
  checks for classroom and glass show no tile seams or missing regions. Both resolutions
  support retaining the adaptive option, but the conservative default remains dense while
  larger scheduling/coherence experiments continue. GPU register counts remain unmeasured.
  Adaptive compaction with the 65,536-path adaptive tail also passes ten selected exact
  comparisons covering alpha, analytic lights at two sizes, and return to an empty scene.
- Revisit uncompacted stage dispatch after the SoA, spatial grouping, opaque traversal and
  stack-capacity improvements. The original `staged-v1` used AoS and a fixed 16-slot VM, so it
  cannot isolate current compaction/coherence tradeoffs. A direct-slot dispatch variant can
  retain 8x8 pixel groups across stages, with inactive lanes returning immediately. Compare
  that against compacted dispatch using the current kernels and identical stack capacity;
  this tests stage isolation separately from queue packing.
  The direct-slot implementation passes 30 full GPU comparisons and ten additional fixed-tail
  comparisons (tail at bounce 2), all exactly equal to the full-stack megakernel reference.
  The 176 unit tests, typecheck, library build and HDR helmet/alpha/transmission smoke cases
  pass; HDR helmet and transmission screenshots were inspected. The first current-kernel
  five-scene interleaved comparison against all queue modes is now being measured.
  `compaction-direct-sweep-v1` completes all 75 HDR comparisons exactly. Direct/adaptive
  spans are 10.258/8.576, 5.727/6.007, 4.187/5.417, 4.016/3.911 and 1.722/1.841 ms.
  Direct dispatch materially helps BMW, but regresses classroom. Mean stage timings identify
  the next experiment: breakfast intersection falls from 3.98 to 3.15 ms, BMW intersection
  from 2.55 to 1.92 ms and BMW shadow from 2.02 to 1.51 ms. Direct shading is slower in all
  five scenes. Test stage-specific direct dispatch, retaining compacted shading; do not
  assume full direct dispatch is a universally better default.
  The material census reports 45/16/27/8/9 compiled materials (including fallback) and
  7/7/9/5/4 distinct code blocks. Only classroom/breakfast have textures (three materials
  each, requiring one slot); BMW/glass/MIS require zero VM slots. This motivates a future
  constant-output interpreter specialization, applied fairly to both integrators.
  An isolated compile probe under `.tools/wavefront/constant-prototype-v1` removes stack
  accesses and non-output opcodes for a scene-wide zero-slot contract. With the probe disabled,
  both generated shaders match the current stack-1 WGSL exactly. Enabled, PathTracing shrinks
  from 279,647 to 251,746 bytes and Wavefront from 342,610 to 306,644 bytes. This is compile
  evidence only: the prototype is not in production and has not been GPU-validated. Shader
  source size does not establish register usage or runtime speed. Surface-only specialization
  would also need to preserve general emission evaluation for lights with nonconstant programs.
  Stage-selective direct dispatch now passes 135 GPU comparisons: 15 configurations for
  each of the eight masks, plus 15 automatically sized megakernel comparisons. All are exact.
  Unit tests (176), typecheck, library build and three mixed-dispatch smoke cases pass.
  An additional 40 exact comparisons cover seven mixed masks with adaptive tail threshold
  65,536 on alpha, analytic lights (including multiple tiles), and an empty-scene transition.
  `stage-dispatch-sweep-v1` completes all 120 paired HDR comparisons across five scenes.
  Breakfast improves from 6.073 to 5.247 ms with only direct intersection; BMW from 5.453
  to 4.272 ms with direct intersection/shadow, or 4.168 ms with all direct stages. Classroom
  remains fastest with all stages compacted (8.542 ms). Glass and MIS show smaller differences.
  Per-bounce data is informative: at late breakfast/BMW bounces, compacted intersection
  stays near 0.3 ms despite sparse queues, while direct intersection drops toward 0.15 ms.
  In classroom, direct intersection instead gets progressively worse. One hypothesis is
  that packing a sparse path set into very few workgroups leaves too little GPU parallelism;
  retaining spatial packets distributes work more broadly. Occupancy has not been measured.
  Next experiment: compact whole nonempty 8x8 path packets, preserving lanes within each
  packet while removing empty packets. Keep queue addresses/count units explicit, handle
  partial packets, and compare against both per-path compaction and full direct dispatch.
- Extend beyond pinned-mip exact tests to ordinary stochastic-alpha convergence checks, and
  continue monitoring startup compilation cost and memory at large image sizes.

## Experimental tail controls

`wavefront-benchmark.mjs`, `wavefront-correctness.mjs`, and `smoke.mjs --integrator wavefront`
accept `--tail-start N` and `--tail-threshold N`. These are internal investigation controls,
not public renderer settings. Threshold zero uses a fixed bounce switch; a positive threshold
enables the GPU count test. Tail pipelines include alpha-capable and opaque variants.

## Current work allocation

An experimental `--compaction packet` mode scans physical slots and retains every valid
slot in each nonempty 64-slot packet, independently for the main and shadow queues.
It preserves ordinary path-index queue entries and existing liveness checks, with no
additional bindings or per-path storage. Full packets retain their lane order; the final
partial packet is truncated to the tile boundary, so counters never exceed tile capacity.
When that partial packet reserves before another packet, subsequent packet starts may be
unaligned in the dispatched queue. Packet boundaries correspond to 8x8 pixels when tile
starts are aligned; arbitrary capacity-limited tile starts remain correct.
Counters describe retained slots, including inactive lanes, rather than live paths.
Diagnostics label this unit explicitly. Positive adaptive-tail thresholds are rejected;
fixed tails and independent direct-stage controls remain available. The purpose is to
test spatial coherence and parallelism for sparse queues; speedup is not assumed.
Initial GPU validation passed 30 standard comparisons with subgroups disabled, 10 fixed-tail
comparisons at bounce 2 (alpha, analytic and empty-return), and 36 comparisons covering all
eight direct-stage masks on alpha/analytic cases. All RGB/albedo/normal differences were
exactly zero against the full-stack reference, including the 513x513 tile-boundary case.
All 21 smoke scenes passed; helmet HDR and alpha screenshots were inspected. Typecheck,
176 unit tests, shader regeneration and library build passed.

The `compaction-packet-sweep-v1` paired run completed all five research scenes, six wavefront
modes, three rounds and 32 samples per round at 640x360. All 90 per-round HDR comparisons
were exact, the saved-HDR/source-identity comparator passed, and all five screenshots were
inspected. Median GPU spans in fixed scene order were:

| Mode | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Packet | 11.039 | 6.363 | 4.685 | 4.573 | 2.146 |
| Adaptive per-path | 8.636 | 6.164 | 5.614 | 4.036 | 1.850 |
| Direct slots | 10.273 | 5.804 | 4.156 | 3.898 | 1.730 |

Packet mode improves BMW relative to per-path compaction but loses to direct slots on all
five scenes. Stage arithmetic means explain the tradeoff: breakfast intersection improves
from 3.959 to 3.131 ms versus adaptive, but shading grows from 0.680 to 1.115 ms and shadow
from 1.109 to 1.538 ms. BMW intersection/shadow improve from 2.511/2.151 to 1.994/1.599 ms,
while shading grows from 0.612 to 0.736 ms. These are timing observations, not measured
occupancy or register counts. The next experiment should retain packets independently by
stage, especially keeping shading tightly compacted while preserving traversal packets.

The follow-up `packet-stage-sweep-v1` tested all eight packet masks with the same five
scenes, three rounds and 32 samples at 640x360. All 120 per-round HDR comparisons and saved
HDR captures were exact, with matching source/browser identity. All 135 GPU correctness
comparisons (15 configurations per mask plus the reference auto-capacity variant) passed
with subgroups disabled. Mask 5 smoke passed helmet HDR, alpha and transmission; the
transmission screenshot was inspected. Typecheck, 176 unit tests and library build passed.
An additional 45 comparisons covered all packet masks with fixed-tail fusion at bounce 2
on alpha/analytic/empty-return, and 36 covered every direct-stage mask with packet mask 5
on alpha/analytic. Both suites completed with zero error, including partial tiles.
The useful masks show the expected stage-dependent tradeoff (median GPU span, ms):

| Packet mask | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0: no packets | 8.771 | 6.377 | 5.521 | 3.919 | 1.888 |
| 1: intersection | 10.025 | 5.411 | 4.955 | 4.315 | 1.996 |
| 4: shadow | 9.358 | 6.840 | 4.993 | 3.886 | 1.843 |
| 5: intersection + shadow | 10.554 | 5.945 | 4.366 | 4.158 | 1.898 |
| 7: all stages | 11.075 | 6.309 | 4.571 | 4.482 | 2.149 |

Compared with retaining packets everywhere, selecting stages improves breakfast by about
14% and BMW by 4.5%. It does not establish a new best result over the earlier direct-stage
sweep, nor justify a universal default. Queue diagnostics from `compaction-packet-diagnostics-v1`
passed dispatch bounds on breakfast/BMW; breakfast retains 75,904 slots after bounce 7,
versus 1,701 live paths in the matching adaptive diagnostic. These diagnostic runs include
GPU copies and are not performance evidence. Further work should now examine constant-only
material specialization and material grouping, while retaining these schedules as controls.

Group 1 binding 0 contains the original image prefix (three float4 per pixel), then
three float4 headers, 21 float4 field arrays at the current tile capacity, then three
packed uint index queues (main A, main B, shadow). Header words 0/1/2 store A/shadow/B counts.
Intersect reads A, CompactIntersect scans A and writes B, Shade reads B, and CompactShade
scans B and writes A plus shadow indices. Compact dispatch sizes come from the input queue's
indirect arguments; clearing the output count preserves the input count. An empty queue thus
dispatches no further compaction work. This applies to queued/subgroup modes. The default
dense mode scans physical path slots and writes the same alternating output queues, preserving
the earlier traversal ordering behavior and avoiding input-index loads.
Compaction has five separately compiled modules: dense, queued, adaptive and packet
shared-memory scans, and an optional subgroup scan. Adaptive compaction generates a full-tile main dispatch bound
when its output exceeds half the tile, otherwise an exact queue-sized bound. Main stages
still guard using their actual queue count; this trades a few inactive invocations for
GPU-only scan selection. No additional work storage or bind group entry is required.
The renderer requests `subgroups` only if the adapter supports it;
no subgroup operation appears in either portable module. The subgroup implementation uses
prefix sums, subgroup totals and broadcast-first for local reservations, then one global
reservation per workgroup. Three barriers publish the input count, local totals and global offsets.
Each field array is SoA across paths. The tile capacity is
at most 262,144, bounded by the storage binding and allocation limits. Initial indices
map to 8x8 pixel blocks, with explicit padding checks for non-multiple-of-eight images.
The compaction shader aliases the allocation as atomic uints in separate compute passes;
no pass binds overlapping read/write aliases simultaneously. The 32-byte dispatch argument
buffer is COPY_DST | INDIRECT, not a storage buffer. Compaction and copies stay on GPU.
