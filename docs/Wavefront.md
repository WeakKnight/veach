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
0/1/2/4/8/16 forces a capacity for controlled comparisons and rejects undersized choices.
Both integrators use the same capacity. The harness checks submitted WGSL array sizes
and records the selected capacity, generated variant table, and relevant source hashes.
It also records material stack histograms, constant/textured material counts and distinct
bytecode blocks, including fallback and unused materials as in the scene-wide capacity bound.
Capacity zero selects the constant-only interpreter specialization; submitted modules then
contain no SVM stack. `--material-sweep --paired --mode wavefront` interleaves automatic
capacity, forced 1 and forced 16 for both integrators in the same renderer, outside pipeline
compilation time. The one-slot controls reject scenes requiring more than one slot. Reports
record the actual integrator/capacity for every timed block and all compiled capacities.
The auto-capacity megakernel remains the unique reference; forced megakernel variants get
their own HDR comparisons and reports. This sweep cannot combine with other sweep types.
`--variant-warmup` controls untimed frames before each paired block: normally 8, but 64
for material sweeps, where newly compiled capacities showed a longer initial warmup.
Measured trace passes also validate and record the bound compute pipeline's stack label.

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
order each round and warming the selected pipeline for the configured untimed samples before each block.
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

`--sort none|material|program` optionally sorts independent chunks of the shading queue
after intersection compaction. `--sort-size 64|256` chooses the chunk size; defaults are
none and 64. Material keys group identical materials; program keys use the shared surface
bytecode offset, allowing materials with different constants to execute together. A bitonic
sort breaks ties by physical path index and preserves inactive packet slots. It changes
only queue order, not path records, RNG or material data, and adds no storage binding.
Direct shading cannot use this experiment; intersection/shadow may still dispatch directly.
Sorting uses the existing indirect arguments for 64-slot chunks; 256-slot chunks currently
dispatch the bounded tile and guard by actual queue count. Sorting cost is included in
stage timing and total GPU span. `--sort-sweep` compares unsorted plus all four key/size
combinations and is mutually exclusive with other sweeps.
The GPU correctness script accepts these sort options and reads back the queue before/after
every sort in the first sample. It verifies exact per-chunk order against CPU material/program
keys, permutation/bounds, and records how many entries actually moved. These diagnostic
copies are absent from the performance benchmark.

`--shadow serial|parallel|parallel-auto` selects an opaque-shadow experiment. Parallel
uses a 64x3 workgroup: each source traces independently, then a workgroup barrier and
one lane per path sum environment, local lights and sun in their original order before
applying throughput/clamping. Parallel-auto uses 64x2 when the scene contains no local
light entries, evaluating environment and sun only. It otherwise uses 64x3. Both modes
retain the serial kernel for alpha-tested scenes, preserving VT feedback/RNG ordering.
They reuse the same path queues, indirect arguments and storage fields. Direct and packet
dispatch remain supported. The default is serial. `--shadow-sweep` compares all three
within the same scene/residency and cannot combine with other sweeps. GPU correctness
reports record and verify the actual shadow pipeline, including alpha fallback.

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

## Constant-only material specialization

Capacity zero removes the SVM stack and non-output opcode implementations when the entire
scene's compiled programs need no temporary slots. It shares output decoding with the general
interpreter, preserving geometry-dependent defaults, opacity, emission and BSDF inputs.
Mixed scenes still use the ordinary scene-wide capacity; a constant surface does not imply
that the emitters it samples have constant emission programs.

The `material-zero-sweep-v2` paired run tested all five scenes at 640x360, eight bounces,
three rounds and 32 samples, with 64 untimed frames before each variant. All 75 per-round
HDR comparisons were exactly equal, the saved-HDR/source-identity comparator passed, and
all five screenshots were inspected. Each measured block verified its actual bound pipeline
capacity. Median GPU spans in milliseconds:

| Integrator / capacity | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel auto | 10.559 | 4.350 | 2.620 | 2.835 | 1.551 |
| Megakernel 1 | 10.182 | 4.321 | 2.850 | 3.153 | 1.829 |
| Megakernel 16 | 15.212 | 6.861 | 4.184 | 6.526 | 2.402 |
| Wavefront auto | 8.631 | 6.029 | 5.347 | 3.756 | 1.748 |
| Wavefront 1 | 8.666 | 6.034 | 5.453 | 3.923 | 1.831 |
| Wavefront 16 | 8.880 | 6.216 | 5.551 | 4.164 | 2.055 |

Auto selects capacity 1 for classroom/breakfast and 0 for BMW/glass/MIS. Against capacity 1,
the constant-only specialization reduces megakernel time by 8.1%/10.1%/15.2% and wavefront
time by 2.0%/4.3%/4.5% on those three scenes. The identical-capacity classroom control varies
by 3.7%, so small differences remain provisional. This is timing evidence, not register or
occupancy measurement. The preceding v1 sweep also passed all 75 HDR comparisons, but its
eight-frame warmup left a large transient slowdown in newly used capacities; it must not be
used to claim that transient as an optimization gain. The v2 first/last eight-sample windows
no longer show that multi-fold cold-start penalty.

Generated variants use lossless line-anchor edits with numeric removal lengths. Reconstructed
modules match independent Slang outputs by SHA256. The additional zero-capacity variants add
about 286 KB raw / 51 KB gzip to the shared library chunk, versus about 1.18 MB raw with the
initial coarse diff encoding. The ordinary capacity-1 shader body remains unchanged.
All 181 unit tests, typecheck and library build passed. The full GPU regression suite passed
34 comparisons, including new constant-only alpha/blend, emissive and transmission materials.
An additional 18 direct-stage-mask and 18 packet-mask comparisons passed with subgroups
disabled; RGB and both AOVs were exactly equal to the full-capacity megakernel reference.
Eight additional comparisons covered fixed-tail bounce 2 with packet mask 5 and an adaptive
tail threshold of 65,536, again with zero error on the constant-alpha scenes.
Adaptive wavefront smoke passed alpha, emissive and transmission; the transmission screenshot
was inspected after the final run.

## Shading queue sorting experiment

The `shading-sort-sweep-v1` run compared both sort keys at chunk sizes 64/256 with the
unsorted adaptive schedule, using all five scenes, three rounds and 32 samples at 640x360.
All 75 per-round HDR comparisons were exact, saved-HDR/source checks passed, and all five
screenshots were inspected. Median GPU spans in milliseconds:

| Shading order | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted | 8.653 | 6.055 | 5.399 | 3.849 | 1.745 |
| Material / 64 | 8.605 | 6.112 | 5.508 | 3.930 | 1.820 |
| Material / 256 | 8.616 | 6.925 | 5.826 | 4.104 | 1.867 |
| Program / 64 | 8.741 | 6.181 | 5.458 | 3.941 | 1.823 |
| Program / 256 | 8.712 | 6.936 | 5.711 | 4.030 | 1.866 |

These scenes do not establish a sorting benefit. Classroom differences are below 1%,
while the other scenes regress. Sorting costs roughly 0.12-0.14 ms per sample; it also
changes the path order seen by subsequent queued compaction/traversal. In classroom,
material/256 changes mean intersection/shadow from 3.892/2.680 to 3.741/2.560 ms, but
shading grows from 1.437 to 1.521 ms. In breakfast, intersection grows to 4.708 ms. Thus
the tradeoff extends beyond the sorting dispatch itself. The option stays disabled by
default. These five scenes predominantly use constant or one-slot materials; this result
does not establish that sorting cannot help more divergent, expensive SVM programs.

GPU validation with subgroups disabled passed the full 34-comparison material/64 adaptive
suite, eight program/256 adaptive comparisons, 12 program/256 packet comparisons, eight
program/64 queued comparisons, and eight material/256 fixed-tail comparisons. Each sort
in the first sample was checked against CPU keys for exact chunk order and permutation,
including 513x513 multi-tile and 7x5 partial-tile cases. Every radiance/albedo/normal
comparison was exact. Typecheck, all 181 unit tests, shader generation and library build
passed. The sort modules add about 16 KB raw / 1.3 KB gzip to the wavefront library chunk.
Material/64 adaptive smoke passed helmet HDR, alpha and transmission; the final transmission
screenshot was inspected. Sorting remains an internal experiment, disabled by default.

## Parallel opaque shadow experiment

The `shadow-parallel-sweep-v1` paired run tested serial, 64x3 parallel and source-count-aware
64x2/64x3 parallel on all five scenes, three rounds and 32 samples at 640x360. All 45
per-round HDR comparisons were exact, saved-HDR/source checks passed, and all five screenshots
were inspected. Median GPU spans in milliseconds:

| Shadow mode | classroom | breakfast | BMW | glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Serial | 8.534 | 6.045 | 5.392 | 3.892 | 1.748 |
| Parallel / three sources | 8.726 | 6.052 | 5.123 | 3.883 | 1.800 |
| Parallel / source count | 8.961 | 6.171 | 4.850 | 3.884 | 1.794 |

BMW improves by 10.1% with the two-source workgroup, but classroom regresses by 5.0%;
other differences range from essentially equal to a small regression. BMW shadow time
improves across bounces 1-7, while classroom's early shadow work slows down. This does
not justify a universal default. The first three scenes contain no local lights; the
last two contain emissive geometry and retain the three-source kernel in both parallel
modes. All 12 selected GPU correctness comparisons passed, verifying actual pipeline
selection for alpha fallback, all three sources, two sources, partial and multi-tile
dispatch. A further 36 comparisons covering all direct-stage masks passed with exact RGB
and AOVs. Typecheck, 181 unit tests, shader generation and library build passed.
Eight packet/fixed-tail comparisons also passed. Parallel-auto smoke passed helmet HDR,
alpha and transmission; the final transmission screenshot was inspected. Serial remains
the default while this stage-dependent tradeoff is investigated.

The material census now records the opcode union across all three programs, including
fallback and unused materials. Classroom and breakfast use only End/Output/Texture;
BMW, glass and MIS use End/Output. This motivates a separate pipeline-constant opcode
specialization experiment rather than assuming the VM's full arithmetic/procedural switch
is required for these workloads.

### Scene opcode specialization experiment

`--opcodes scene` supplies the scene's union of SVM instructions as two uint32 pipeline
constants. `--opcode-sweep` pairs the full-opcode megakernel and wavefront with both
specialized variants, rotates their order and warms each selected variant for 64 frames.
The normal renderer still uses the full opcode set. Capacity zero has no opcode overrides;
the three constant-only research scenes are therefore useful unchanged controls.
Pipeline caches include both capacity and mask. Benchmarks capture the constants of actual
bound pipelines and reject a mismatch, in addition to checking capacity and HDR output.

All 42 GPU regression comparisons passed with identical RGB and guides against the
full-16-stack/full-opcode reference. Coverage includes capacities 0/1/2/4/8/16,
alpha traversal/shadows, transmission, analytic and emissive lights, partial/multiple
tiles, empty-scene transitions, and procedural Transform/Noise/Magic/Checker graphs.
The latter verify both the high uint32 mask and unsigned bit 31 in the low mask.
The CPU tests also check skipping extension operands, including unused/fallback materials,
and separating same-capacity pipelines with different opcode masks. All 185 unit tests,
typecheck, shader generation and library build pass. GPU correctness disables development
hot reload so regenerating outputs cannot navigate away from an active test page;
performance runs still require frozen source hashes throughout the run.

`opcode-sweep-v1` completed all five scenes with 45 exact paired HDR comparisons;
all screenshots were inspected. Classroom wavefront improved 8.592 to 8.305 ms and
breakfast megakernel improved 4.272 to 4.059 ms, motivating a longer repeat.
`opcode-sweep-v2` uses seven paired rounds, 64 samples per block and 64 warmup frames.
All 105 paired HDR comparisons are exact and the sweep verifier passed. Median GPU spans:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel, full opcodes | 10.134 | 4.271 | 2.704 | 2.814 | 1.549 |
| Megakernel, scene opcodes | 9.902 | 4.118 | 2.657 | 2.809 | 1.553 |
| Wavefront, full opcodes | 8.623 | 6.136 | 5.352 | 3.812 | 1.751 |
| Wavefront, scene opcodes | 8.370 | 5.926 | 5.351 | 3.774 | 1.748 |

Only the first two scenes change shaders. Their wavefront variants improve in every
paired round, by 2.9% and 3.4% at the median. Shade stage totals fall from 1.4702 to
1.2865 ms for classroom and 0.6817 to 0.5566 ms for breakfast (medians of per-round
stage sums divided by sample count). Other stage variations and constant-only controls
show timing noise; the apparent BMW megakernel gain is not an opcode optimization.
This is evidence for runtime specialization, not a hardware register/occupancy measurement.
The experiment stays opt-in while broader material performance and compilation overhead
are evaluated. Fewer enabled instructions do not establish that every backend or scene wins.
All five v2 screenshots were inspected. Another 36 exact comparisons cover every direct-stage
mask with alpha and procedural materials; ten exact comparisons cover packet queues,
fixed tail start 2, disabled subgroups, and capacities 4/16. Together with the full suite
this gives 88 GPU regression comparisons for the opcode change.
Specialized wavefront smoke also passes helmet HDR, alpha and transmission; all three
screenshots were inspected. Regenerated shader reconstruction, opcode and lifecycle tests
were rerun after the final shader build (26 passing tests).

### Optional procedural material stress

`--material-layers N` (1..12) derives an additional workload from each of the same five
scene assets. It layers normalized three-octave color Noise in object space, reuses the
bands for color and roughness, and modulates those two existing surface inputs. All other
surface inputs, alpha mode, opacity and emission remain unchanged; source GLBs are never
edited. `--material-mixed` cycles material layer counts from 1 through N to create divergent
program lengths for sorting experiments. The default of zero leaves original materials
untouched. These are supplemental workloads, not interchangeable with original-scene timings.

The helper is `scripts/wavefront-material-stress.ts`, included in benchmark source hashes.
Compilation errors fail the experiment rather than silently substituting default materials.
Reports include each material's layer count and required stack, and HDR comparison rejects
different stress settings. CPU tests preserve other evaluated material inputs and verify
real Noise instructions and stack usage. An eight-layer GPU regression compares the full
interpreter with specialized megakernel and wavefront on partial workgroups and an ordinary
image; all four comparisons pass exactly. The five-scene CPU census needs 8..10 temporary
slots at eight layers, selecting capacity 16 in every scene, versus 0..1 slots originally.

Example: `node scripts/wavefront-benchmark.mjs --paired --mode wavefront --compaction adaptive
--material-layers 8 --opcode-sweep --variant-warmup 64 --out .tools/wavefront/material-stress-8-opcodes-v1`.

The eight-layer run completed all five scenes with 45 exact paired HDR comparisons;
the sweep verifier and screenshot inspection passed. Three rounds of 32 samples,
64-frame per-variant warmup, otherwise the fixed benchmark settings:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel, full opcodes | 27.404 | 13.740 | 9.205 | 11.793 | 6.976 |
| Megakernel, scene opcodes | 28.685 | 13.784 | 8.242 | 10.574 | 6.729 |
| Wavefront, full opcodes | 12.151 | 9.277 | 7.689 | 6.715 | 4.300 |
| Wavefront, scene opcodes | 12.924 | 9.739 | 7.862 | 6.927 | 4.593 |

Staging wins in every derived scene, by 1.20x..2.26x against its same-workload megakernel.
Opcode pruning regresses wavefront in every case (2.2%..6.8%), despite improving two of
the original simple-material scenes. This is why the universal opcode specialization
remains experimental; reduced enabled instruction count alone does not predict runtime.
The stress workload is deliberately more expensive than the original materials and does
not establish a universal wavefront advantage on ordinary assets.

`material-stress-mixed-sort-v1` cycles 1..8 layers across materials, uses the full opcode
set and compares unsorted shading against material/program sorting in 64/256-path chunks.
All 75 paired HDR comparisons are exact; the verifier and all five screenshot inspections
pass. Median spans with the same three-round/32-sample/64-warmup settings:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel | 26.540 | 12.136 | 7.580 | 6.578 | 3.968 |
| Wavefront, unsorted | 11.119 | 8.652 | 7.416 | 5.841 | 3.103 |
| Material, 64 | 11.034 | 8.682 | 7.434 | 5.822 | 3.205 |
| Material, 256 | 9.769 | 9.105 | 7.770 | 5.639 | 3.186 |
| Program, 64 | 11.027 | 8.714 | 7.461 | 5.704 | 3.203 |
| Program, 256 | 9.838 | 9.221 | 7.609 | 5.624 | 3.199 |

Classroom benefits from 256-path sorting: material sorting improves the span by 12.1%,
and Shade stage totals fall from 6.003 to 4.708 ms/sample. Other scenes have small gains or
regressions; BMW megakernel varies from 8.230 to 6.844 ms across rounds, so near-equal
comparisons there do not establish a winner. Sorting remains opt-in. Four more GPU
regressions with program-256 sorting pass, including exact queue permutation/order checks
on 2,554 entries, 2,429 moved. Typecheck, all 186 unit tests, and wavefront helmet-HDR smoke
pass; the smoke screenshot was inspected. No production shader or default changed in this
benchmark extension.

### Material instruction scheduling

The compiler can shorten live ranges before assigning SVM slots while preserving every
arithmetic operation and the relative texture sampling order. It uses a deterministic
dependency-ready heuristic and adopts the result only if a simulated peak is strictly
smaller. See [MaterialSystem.md](MaterialSystem.md). The bytecode format and shader
interpreter are unchanged; existing capacity selection consumes the smaller compiler bound.

`--schedule-sweep` compares original-order megakernel/wavefront with optimized-order
megakernel/wavefront in the same renderer. `--material-schedule original|optimized` selects
one order; default is original. A fixture prepares two material buffers and their
stack/opcode bounds, retaining the same geometry, light distribution and frozen VT residency.
It checks unchanged alpha/emission/texture metadata; CPU tests compare all evaluated inputs
and texture call sequences. Timed blocks verify the actual bound material buffer, pipeline
capacity and opcode constants. The schedule sweep uses 64-frame per-variant warmup.

The complete 46-case GPU suite compares original-order/full-16/full-opcode reference outputs
with optimized-order production pipelines and passes exactly. The stress sphere scene drops
from 12 to 7 required slots; the ordinary anisotropy sample drops from 9 to 8, selecting
capacity 8 instead of 16. The simpler standalone four/eight/twelve-layer graphs drop from
5/9/13 to 4 slots. These are virtual stack bounds, not hardware register measurements.
All 190 unit tests, typecheck (including the GPU buffer fixture) and library build pass.

`material-schedule-stress8-v1` applies eight procedural layers to the five fixed scenes.
Three paired rounds of 32 samples with 64 warmup frames give 45 exact HDR comparisons;
the sweep verifier and all five screenshot inspections pass. Original stack bounds
10/10/9/9/9 become 5/5/4/4/4, selecting capacities 8/8/4/4/4 instead of 16 throughout.

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel, original order | 27.158 | 13.528 | 9.061 | 11.709 | 6.980 |
| Megakernel, scheduled | 23.720 | 12.339 | 7.720 | 10.129 | 6.311 |
| Wavefront, original order | 12.100 | 9.230 | 7.658 | 6.659 | 4.294 |
| Wavefront, scheduled | 12.256 | 9.593 | 8.262 | 7.863 | 4.482 |

Shorter virtual live ranges improve megakernel here but regress wavefront, by up to 18.1%.
This is not evidence of reduced hardware register pressure or a universal optimization.
`material-schedule-capacity-v1` keeps the scheduled bytecode and compares automatic capacity
with forced 8/16. All 75 paired HDR comparisons are exact, the verifier passes, and all five
screenshots were inspected. Wavefront spans are:

| Capacity | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Automatic | 12.330 | 9.548 | 8.268 | 7.955 | 4.548 |
| 8 | 12.408 | 9.531 | 8.531 | 7.988 | 4.487 |
| 16 | 12.421 | 9.662 | 8.458 | 8.113 | 4.739 |

Restoring the larger capacity does not restore original-order performance. Instruction
ordering, operand access and execution coherence remain possible causes, requiring separate
experiments; these timings do not identify a hardware mechanism by themselves.

`material-schedule-sort-v1` adds the existing material/program sorter to scheduled
eight-layer bytecode. All 75 paired HDR comparisons are exact; the sweep verifier and
five screenshot inspections pass. Median spans:

| Wavefront variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted | 12.238 | 9.580 | 8.267 | 7.930 | 4.535 |
| Material, 64 | 12.210 | 9.636 | 8.527 | 7.752 | 4.698 |
| Material, 256 | 11.319 | 10.118 | 8.810 | 7.709 | 4.667 |
| Program, 64 | 12.380 | 9.667 | 8.450 | 7.759 | 4.660 |
| Program, 256 | 11.334 | 9.913 | 8.600 | 7.599 | 4.610 |

Sorting helps classroom and glass, but does not generally recover the original-order
performance. Program-256 reduces classroom Shade from 7.081 to 6.095 ms/sample and
glass Shade from 4.685 to 4.122 ms/sample. This supports a coherence contribution in
those workloads, without identifying it as the sole cause of the scheduling regression.

`material-schedule-original-scenes-v1` also completes the unmodified five scenes with
45 exact comparisons, a passing verifier and inspected screenshots. Original/scheduled
wavefront spans are 8.551/8.678, 6.022/6.087, 5.350/5.315, 3.689/3.742 and 1.739/1.744 ms.
These simple materials do not establish a scheduling gain. Scheduling therefore remains
explicitly opt-in in both the compiler and benchmark; production keeps the original order.
The earlier scheduled-bytecode experiments explicitly recorded their chosen order and are
still valid. Reproducing them now requires `--material-schedule optimized` (schedule sweeps
already select both orders automatically).

After restoring the original-order default, all 190 unit tests and typecheck pass again.
The full 46-case GPU suite and six additional program-256/adaptive comparisons pass exactly
with the final buffer-selection fixture. The latter verifies actual sorted queue permutation
and program order on procedural and anisotropic materials. Program keys are compiled using
the explicitly scheduled order, independently of the production default. Wavefront smoke
passes helmet HDR, alpha, transmission and anisotropy; all four screenshots were inspected.

## Work storage

The experimental `Wavefront.spatialQueues` option (default false, adaptive compaction only)
collects continuation and shadow paths from physical slots after shading. This restores
local 8x8 pixel neighborhoods even when material sorting rearranges the shading queue.
Workgroup reservations remain atomic, so this does not promise a globally sorted queue.
It scans the full tile, trading extra sparse-tail work for spatially coherent traversal.
`WavefrontCompactSpatial` combines the existing dense-scan and adaptive-output-bound
compile flags. Its main indirect bound still expands to the full tile above half occupancy,
which is required by the following adaptive intersection compaction. The host dispatches
this physical scan directly; other stages retain their existing indirect arguments.
No work-storage layout, material bytecode, or bind group changes are required.

Benchmark/correctness scripts accept `--spatial-queues`. A paired `--spatial-sweep` with
an adaptive, unsorted base compares unsorted, material-256 and program-256 shading with
inherited or physical continuation queues. Each measured variant verifies its actual
CompactShade pipeline; the correctness script records those pipeline labels as well as
checking HDR/AOV results and sorted queue permutations. Performance results are below.
Shader regeneration, all 190 unit tests and typecheck pass. The spatial option passes the
complete 46-case GPU suite plus ten program-256/adaptive comparisons covering alpha,
procedural stress and anisotropy. Those runs validate the actual `CompactShadeSpatial`
pipeline and retain exact HDR/AOV results, including partial workgroups and multiple tiles.

`spatial-queues-original-v1` completes all five original scenes, with 90 exact paired HDR
comparisons and a passing sweep verifier. The program-256/physical screenshots were inspected.
Three rounds of 32 samples and 64-frame variant warmup give these median spans:

| Wavefront variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted, inherited | 8.627 | 6.043 | 5.341 | 3.781 | 1.744 |
| Unsorted, physical | 8.644 | 6.385 | 5.457 | 3.897 | 1.782 |
| Material-256, inherited | 8.682 | 6.868 | 5.808 | 4.038 | 1.867 |
| Material-256, physical | 8.785 | 6.407 | 5.583 | 4.045 | 1.910 |
| Program-256, inherited | 8.689 | 6.871 | 5.689 | 3.854 | 1.872 |
| Program-256, physical | 8.826 | 6.464 | 5.571 | 3.887 | 1.918 |

Restoring physical queues recovers some sorting overhead in breakfast and BMW, but the
unsorted baseline remains faster. Breakfast material-256 Intersect falls from 4.640 to
4.181 ms/sample; CompactShade grows from 0.159 to 0.233 ms/sample. This demonstrates a
traversal-order tradeoff rather than a general justification for physical scanning.

The mixed 1..8-layer workload (`spatial-queues-mixed-v1`) also passes all 90 paired HDR
comparisons, the verifier and five screenshot inspections. Its median spans are:

| Wavefront variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted, inherited | 11.094 | 8.670 | 7.447 | 5.711 | 3.094 |
| Unsorted, physical | 11.293 | 8.886 | 7.480 | 5.819 | 3.150 |
| Material-256, inherited | 9.842 | 9.191 | 7.749 | 5.603 | 3.205 |
| Material-256, physical | 10.093 | 8.747 | 7.591 | 5.715 | 3.236 |
| Program-256, inherited | 9.863 | 9.110 | 7.683 | 5.617 | 3.196 |
| Program-256, physical | 10.083 | 8.768 | 7.531 | 5.589 | 3.235 |

Classroom still benefits from sorting without the physical rescan. Breakfast/BMW regain
some traversal efficiency after sorting but remain slower than their unsorted baselines.
Glass has a small gain from program sorting; the other changes do not establish a broad
win. Megakernel BMW varies 6.701..8.035 ms and glass 6.572..8.020 ms across the three rounds,
so speedup ratios against those unstable references need caution. The spatial option stays
disabled by default.

Measured blocks now record `measurementStartedAt`/`measurementFinishedAt` as Unix milliseconds,
after warmup and before the HDR readback, for correlation with external telemetry. The
scheduled-eight-layer follow-up records NVIDIA timestamp, P-state, SM/memory clocks,
temperature, power and utilization at approximately 100 ms intervals via `nvidia-smi`.
Its CSV uses this machine's local time (UTC+08:00); only samples within timed blocks should
be used to discuss measured clock behavior, since scene loading/compilation includes idle
periods. This monitoring does not set GPU clocks or power limits.
`node scripts/analyze-gpu-telemetry.mjs .tools/wavefront/spatial-queues-scheduled-v1 +08:00`
correlates the completed reports with the CSV and writes `telemetry-summary.json`. Blocks
without a telemetry sample are explicitly unobserved, rather than assigned nearby clocks.

`spatial-queues-scheduled-v1` uses uniform eight-layer materials with instruction scheduling
enabled. All 90 HDR comparisons are exact, the verifier passes and all five screenshots
were inspected. Median spans:

| Wavefront variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted, inherited | 12.496 | 9.558 | 8.281 | 7.812 | 4.495 |
| Unsorted, physical | 12.484 | 9.779 | 8.369 | 7.981 | 4.521 |
| Material-256, inherited | 11.414 | 10.097 | 8.777 | 7.536 | 4.622 |
| Material-256, physical | 11.667 | 9.764 | 8.595 | 7.516 | 4.635 |
| Program-256, inherited | 11.446 | 9.926 | 8.648 | 7.411 | 4.533 |
| Program-256, physical | 11.553 | 9.321 | 8.477 | 7.593 | 4.678 |

Breakfast's program-256/physical combination improves on its scheduled unsorted baseline
by 2.5%, and on program sorting with inherited queues by 6.1%. Classroom and glass prefer
sorting with inherited queues; BMW and MIS prefer the unsorted baseline in this run.
This does not establish an overall win over original-order materials, which are a different
experiment. Default settings remain unchanged.

All 105 measurement blocks contain telemetry observations. Observed SM clocks stay at
2745 MHz for classroom and 2760 MHz for the other scenes; memory stays at 10501 MHz.
Observed temperatures span 48..57 C. BMW megakernel spans 6.402..6.706 ms and glass
9.878..10.095 ms in this run, while MIS still varies 5.627..6.221 ms at the same observed
clocks. Thus clock samples do not explain every timing variation and cannot retroactively
identify the cause of older unmonitored outliers. The monitor process exited after timing.
The three spatial v1 sweeps alternated forward/reverse block order across three rounds.
The spatial sweep now also rotates the first variant, matching other sweeps, so a longer
repeat can check whether the small breakfast gain survives different block positions.
Another 24 exact GPU comparisons cover fixed tail start 2 without subgroups, direct-stage
mask 5, and adaptive tail threshold 4096. This brings spatial regression coverage to
80 comparisons. Program-256/physical smoke passes helmet HDR, alpha and transmission;
all three screenshots were inspected. The library build passes; the wavefront chunk is
452.70 kB (74.50 kB gzip), about 0.30 kB gzip above the preceding build.

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
