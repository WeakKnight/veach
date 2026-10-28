# Wavefront implementation and performance experiment

## Investigation scope

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

`--shade-mode unified|split|late|split-late` selects experimental shading entries.
`--shade-sweep --paired --mode wavefront --balanced-order --repeats 5` compares the
general megakernel, unified wavefront and the three candidates in balanced positions.
The sweep uses 64 untimed warmup frames per variant. `split` compiles primary and
continuation shading separately and avoids loading/storing continuation albedo and normal.
`late` loads active/direction/cones first, evaluates the material, then loads the full path
and applies absorption before BSDF construction. `split-late` combines both changes.
Tail entries retain the unified path. The benchmark and correctness harness verify the
actual shading pipeline against the pass bounce and direct/queued dispatch configuration;
reports preserve bound pipeline labels and mode. The correctness harness compares all
three output float4s (HDR and AOVs), including multi-tile and partial-workgroup cases.
These are liveness experiments, not evidence of a particular hardware register count.
Experimental pipelines compile only when requested via `prepareShadeMode`, before the host
publishes the new mode; default preparation retains only the original shading entries.
The split modes add four pipelines (primary/continuation, queued/direct), and late-only adds
two. Prepared groups share concurrent requests and reject publication after destruction.
The expanded WGSL module is shared, so this removes unused pipeline compilation but does not
remove module download/parsing overhead. The library build's wavefront chunk grows from
700.59 kB (81.48 kB gzip) to approximately 742 kB (87 kB gzip).

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
Sorting uses the existing indirect arguments for 64-slot chunks; 256-slot chunks by default
dispatch the bounded tile and guard by actual queue count. Sorting cost is included in
stage timing and total GPU span. `--sort-sweep` compares unsorted plus all four key/size
combinations and is mutually exclusive with other sweeps.
The GPU correctness script accepts these sort options and reads back the queue before/after
every sort in the first sample. It verifies exact per-chunk order against CPU material/program
keys, permutation/bounds, and records how many entries actually moved. These diagnostic
copies are absent from the performance benchmark.

`--ray-sort-size 0|64|256` optionally sorts continuation queue A by direction octant before
intersection, starting at bounce one. Camera rays retain their initial spatial order.
The key uses the three IEEE float sign bits, including negative zero; physical path index
breaks ties and inactive packet slots sort last. This requires queued intersection and
can combine with material/program sorting of queue B. The default is zero (disabled).
`--ray-sort-sweep --paired --mode wavefront` compares unsorted, 64-slot sorting, 256-slot
direct sorting and 256-slot indirect sorting with the megakernel reference. Its five
variants require a multiple of five repeats when `--balanced-order` is used.

`--sort-indirect` enables exact indirect dispatch for active 256-slot sorts. Header word 3
holds ceil(actual main queue count / 256), computed before adaptive compaction expands
its separate 64-slot bound. Only enabled runs add the atomic update, header clear and
four-byte argument copy. The third dispatch record lives at byte offset 32 in a 48-byte
COPY_DST | INDIRECT buffer; its y/z counts are initialized to one. Uniform word 6 selects
this behavior without changing path fields or storage bindings. The default is false.
`--sort-indirect-sweep` compares the fixed 256-slot sort with/without exact dispatch and
the megakernel reference; balanced ordering requires a multiple of three repeats.
The GPU checker verifies actual dispatch methods, argument offsets and xyz values as
well as exact queue permutations for both sorting keys. COPY_SRC on the indirect buffer
is added only by that checker. Performance reports record the actual sort dispatch modes
and bound pipelines without the diagnostic readbacks.

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

`--opaque-sweep --paired --mode wavefront` adds a megakernel with opaque-scene traversal
specialization alongside the general megakernel reference and unchanged wavefront schedule.
The internal `opaqueMegakernel` control defaults to false. Requested specialization is used
only when the bound scene has geometry and no alpha-tested instances; empty and alpha scenes
retain their existing kernels. The separately compiled module and stack-variant data load
only on demand. The six capacities share the general module's binding layout and material
pipeline constants. All ordinary generated shaders remain byte-for-byte unchanged.
Use a multiple of three repeats with `--balanced-order`; the default per-block warmup is 64.
`--opaque-megakernel` enables a standalone benchmark, smoke or GPU correctness run. The
correctness script always retains a general full-stack reference and verifies actually bound
pipeline labels, including alpha fallback. Paired performance requires `--opaque-sweep` so
the general reference cannot silently inherit the requested specialization.

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
Integrator state is stored between kernels in GPU SoA storage (`state.h`) rather than
keeping the entire path live. Shader evaluation and BSDF consumption stay in the same
surface invocation, avoiding a separate persistent closure buffer.

Wavefront does not remove SVM storage. `src/kernel/svm/svm.h::svm_eval_nodes` still declares
`float stack[SVM_STACK_SIZE]` (255 floats in this checkout). Its implementation comment
expects GPU thread-private local memory because the stack is large and dynamically
indexed; this is not shared workgroup memory. Veach retains a scene-sized float4 VM stack in
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

The seven-round, 64-sample follow-up `spatial-queues-scheduled-v2` rotates/reverses variant
order and retains 64 warmup frames per block. All 210 paired HDR comparisons are exact,
the sweep verifier passes, and all five program-256/inherited screenshots were inspected.
Median spans:

| Wavefront variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Unsorted, inherited | 12.277 | 9.580 | 8.318 | 7.849 | 4.536 |
| Unsorted, physical | 12.331 | 9.785 | 8.394 | 7.951 | 4.550 |
| Material-256, inherited | 11.340 | 10.172 | 8.837 | 7.551 | 4.609 |
| Material-256, physical | 11.610 | 9.729 | 8.589 | 7.521 | 4.669 |
| Program-256, inherited | 11.340 | 9.869 | 8.591 | 7.472 | 4.680 |
| Program-256, physical | 11.451 | 9.299 | 8.466 | 7.530 | 4.691 |

Breakfast's program-256/physical gain survives each paired round (1.10..3.00% against
unsorted, 2.93% comparing overall medians). This is specific to scheduled eight-layer
materials, not a reason to enable physical queues globally. All 245 measured blocks have
telemetry observations: sampled SM clocks are 2745/2760 MHz, memory 10501 MHz, temperature
47..55 C. BMW megakernel still varies 6.437..8.251 ms, so those reference ratios remain
unstable. The telemetry monitor exited normally after the run.

## Experimental SVM operand loading

`--operand-mode 0..7` selects the material operand policy in benchmark, correctness and
smoke scripts. Mode 0 keeps eager loads, mode 1 avoids private-stack reads for constants or
missing operands, mode 2 avoids generic operand preloads for Output, and mode 3 combines them.
`--operand-sweep` compares modes 1/2/3 against mode 0 in both integrators in one paired run, rotating/reversing
block order and warming each variant for 64 frames. It cannot combine with another sweep.
Each block verifies actual pipeline constants and records its selected mode. Capacity-zero
modules are shared, omit ID 2, and were byte-identical in the isolated compiler probe.
The full reference in correctness retains original bytecode, 16 slots, all opcodes and mode 0;
candidates use scheduled bytecode, automatic capacity, scene opcode masks and the selected
operand mode. Shader regeneration, 192 unit tests and typecheck pass. Mode 3 passes the full
46-case GPU suite with exact HDR/AOVs and verified bound constants. The final generated
capacity-zero SHA256 values also match the preceding commit, beyond the isolated probe.
The library build passes (wavefront 487.25 kB, 75.74 kB gzip; shared chunk 1,464.90 kB,
434.82 kB gzip). Wavefront/adaptive mode-3 smoke passes helmet HDR, alpha and transmission;
all three screenshots were inspected. Performance measurements follow.

`operand-original-v1` compares modes 0/1/2/3 on all five original scenes with three paired
32-sample rounds and 64-frame variant warmup. All 105 HDR comparisons are exact, the sweep
verifier passes and all five screenshots were inspected. Median spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 10.134 | 4.326 | 2.660 | 2.847 | 1.547 |
| Megakernel / 1 | 10.171 | 4.365 | 2.621 | 2.842 | 1.556 |
| Megakernel / 2 | 10.249 | 4.254 | 2.637 | 2.831 | 1.552 |
| Megakernel / 3 | 10.282 | 4.295 | 2.701 | 2.864 | 1.552 |
| Wavefront / 0 | 8.562 | 6.079 | 5.366 | 3.699 | 1.738 |
| Wavefront / 1 | 8.589 | 6.020 | 5.459 | 3.869 | 1.733 |
| Wavefront / 2 | 8.569 | 6.048 | 5.362 | 3.705 | 1.738 |
| Wavefront / 3 | 8.520 | 6.107 | 5.365 | 3.703 | 1.745 |

The first two scenes use capacity 1 and establish no clear gain. The final three use capacity
zero: all modes share the identical cached pipeline, so their timing differences are control
variation, not consequences of operand loading. In particular the glass mode-1 wavefront
block is 4.6% slower despite identical code. Small effects require longer paired follow-ups.
The mode-0 baseline remains broadly consistent with the preceding original-scene measurements.

`operand-stress8-v1` repeats the same sweep on uniform eight-layer materials in their
original instruction order (capacity 16 throughout). All 105 paired HDR comparisons are
exact, the verifier passes and all five screenshots were inspected. Median spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 27.212 | 13.839 | 9.226 | 12.019 | 7.039 |
| Megakernel / 1 | 31.533 | 14.954 | 10.019 | 12.553 | 7.176 |
| Megakernel / 2 | 28.515 | 14.241 | 9.330 | 11.993 | 6.910 |
| Megakernel / 3 | 31.894 | 14.925 | 9.943 | 12.630 | 6.944 |
| Wavefront / 0 | 12.068 | 9.153 | 7.725 | 6.608 | 4.250 |
| Wavefront / 1 | 12.213 | 9.338 | 7.737 | 6.696 | 4.330 |
| Wavefront / 2 | 12.665 | 9.543 | 7.748 | 6.818 | 4.395 |
| Wavefront / 3 | 12.695 | 9.614 | 7.763 | 6.878 | 4.329 |

Guarding loads does not improve this workload overall. Classroom Shade grows from a median
6.842 ms/sample in mode 0 to 7.022/7.529/7.584 in modes 1/2/3. Source-level removal of loads
therefore does not establish a lower hardware cost; branch structure and compiler allocation
remain possible explanations, not measured causes. The default stays at mode 0.

`operand-scheduled8-v1` repeats the sweep with the scheduled instruction order and automatic
capacities 8/8/4/4/4. All 105 paired HDR comparisons are exact, the sweep verifier passes,
and all five screenshots were inspected. Median spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 24.523 | 11.880 | 6.250 | 9.850 | 6.193 |
| Megakernel / 1 | 26.657 | 12.607 | 7.986 | 10.066 | 6.220 |
| Megakernel / 2 | 23.515 | 11.779 | 6.291 | 9.872 | 5.694 |
| Megakernel / 3 | 27.089 | 12.533 | 6.811 | 10.479 | 6.036 |
| Wavefront / 0 | 12.510 | 9.531 | 8.269 | 7.858 | 4.513 |
| Wavefront / 1 | 12.289 | 9.554 | 8.373 | 8.006 | 4.581 |
| Wavefront / 2 | 13.123 | 10.034 | 8.371 | 8.267 | 4.723 |
| Wavefront / 3 | 12.962 | 10.053 | 8.425 | 8.422 | 4.788 |

Classroom wavefront mode 1 has a small 1.8% median gain, but it does not extend across the
other scenes or recover original-order performance. Megakernel mode 2 has possible gains
in classroom/MIS, with substantial per-round variation requiring a balanced follow-up.
Neither result justifies a global default change or identifies a hardware register effect.

### Constant-index stack experiment and balanced measurement order

Operand bit 4 selects switch reads/writes whose individual array indices are compile-time
constants. The generated cases match the selected capacity (1/2/4/8/16), including masked
source/destination indices. Mode 4 retains eager operands; 5/6/7 additionally select the
existing load guards. Capacity-zero output is unchanged by SHA256. This creates a backend
scalarization opportunity without changing bytecode, arithmetic, RNG, resources or the CPU
interpreter. It may increase register pressure or branch cost, so performance must be measured.
Isolated switch and unrolled-if prototypes both compiled; switch was selected for this
experiment because its WGSL is smaller. This is a code-size choice, not a performance result.

Stage attribution of the preceding mode-zero original-scene run (`operand-original-v1`)
puts Intersect at 44.9/66.4/47.4/52.9/21.3% of measured GPU pass time in fixed scene order;
Shadow contributes another 31.1/17.1/38.4/25.4/39.3%. These are sample means, not the
median spans above, and attribution sums were checked against all recorded pass timings.
The eight-layer workload instead spends 39.1..68.8% in Shade. This motivates treating
traversal coherence and SVM storage as separate experiments rather than assuming that
material register pressure dominates both workloads. An isolated octant-key sorting
prototype compiles for 64/256-path chunks; it has not yet been integrated or GPU-measured.

`--operand-modes 4` selects just that candidate for `--operand-sweep`; the default list stays
1,2,3 for reproducibility. `--balanced-order` requires paired repeats in multiples of the
total variant count (including the megakernel reference). Each complete cycle places every
variant in every measurement position once; alternate cycles reverse direction. Reports
store planned orders and actual positions, and the sweep verifier checks position counts
and round coverage for every scene and variant. This balances position, not every possible
predecessor pair, and does not eliminate GPU timing noise. Six unit tests cover odd/even
variant counts, both cycle directions, permutations and invalid inputs. All 198 unit tests,
shader regeneration and typecheck pass. Mode 4 passes all 46 GPU regression comparisons
with exact HDR and AOVs against the original full-stack reference. The library build passes
(wavefront 690.71 kB / 80.60 kB gzip, shared chunk 1,735.96 kB / 445.03 kB gzip), so the
experiment's larger generated source is also an explicit deployment cost. Mode 7 passes
eight additional alpha/stress comparisons with 256-path program sorting and exact queue
permutation checks. Mode 5 passes eight procedural/stress comparisons with subgroups
disabled and a fixed tail from bounce 2. Mode 6 passes four transmission/clearcoat cases
with direct stages 7. All 66 GPU comparisons are exact. Mode-4 wavefront/adaptive smoke
passes helmet HDR, alpha and transmission with normal streaming; all three screenshots
were inspected. Balanced performance measurements follow.

`static-stack-original-v1` (revision `0ab66d8`) completes four position-balanced paired
32-sample rounds on all five original scenes. All 60 non-reference HDR comparisons are
exact; the sweep verifier confirms measured position balance, all five screenshots were
inspected, and the source identity is unchanged throughout the run. Median GPU spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 10.229 | 4.323 | 2.699 | 2.823 | 1.549 |
| Megakernel / 4 | 10.087 | 4.268 | 2.656 | 2.806 | 1.550 |
| Wavefront / 0 | 8.556 | 6.056 | 5.391 | 3.698 | 1.745 |
| Wavefront / 4 | 8.701 | 6.043 | 5.388 | 3.710 | 1.753 |

The first two scenes use one slot, so dynamic source indices already mask to zero.
The final three use identical capacity-zero pipelines across modes: their small timing
differences are control variation. Classroom wavefront is 1.7% slower with mode 4; no
broad win is established. Larger live-stack workloads remain the relevant scalarization
test, and the default remains mode 0.

`static-stack-stress8-v1` uses the same four-round balanced protocol on eight-layer
original-order materials (capacity 16 throughout). All 60 HDR comparisons are exact,
the verifier passes and all five screenshots were inspected. Median GPU spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 27.765 | 13.299 | 9.332 | 11.686 | 7.001 |
| Megakernel / 4 | 31.782 | 15.238 | 9.925 | 12.745 | 7.443 |
| Wavefront / 0 | 12.180 | 9.221 | 7.635 | 6.627 | 4.181 |
| Wavefront / 4 | 13.150 | 9.838 | 7.876 | 6.975 | 4.529 |

Mode 4 regresses wavefront by 3.1..8.3% and megakernel by 6.3..14.6%. Every paired
round in every scene is slower with the switch variant. This does not identify the
hardware cause (branch cost, scalarization and register allocation remain hypotheses),
but rules out enabling this policy for the measured 16-slot workload. The default stays 0.

`static-stack-scheduled8-v1` uses scheduled eight-layer materials, with capacities
8/8/4/4/4, and the same four-round balanced protocol. All 60 HDR comparisons are exact,
the verifier passes, and all five screenshots were inspected. Median GPU spans:

| Integrator / mode | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel / 0 | 24.448 | 12.538 | 6.306 | 10.162 | 5.923 |
| Megakernel / 4 | 26.369 | 12.626 | 6.617 | 10.025 | 6.293 |
| Wavefront / 0 | 12.190 | 9.599 | 8.298 | 7.832 | 4.542 |
| Wavefront / 4 | 13.135 | 10.085 | 8.268 | 7.822 | 4.443 |

The two capacity-eight wavefront cases regress 7.8% and 5.1%. Capacity-four BMW/glass
are within 0.4%, while MIS shows a possible 2.2% improvement requiring repetition before
adoption. BMW megakernel spans 6.254..8.002 ms in mode 0 and 6.330..7.922 ms in mode 4;
MIS megakernel also varies substantially. These ranges limit conclusions about small
effects. The three complete sweeps establish no broadly beneficial constant-index policy,
so it remains an opt-in experiment. Together they contain 180 exact non-reference HDR
comparisons and fifteen inspected screenshots on the same fixed five scenes.

The follow-up octant sorter now targets continuation queue A, skips camera rays, and
preserves physical path/RNG records. Exact 256-slot indirect dispatch is a separate opt-in.
The initial combined direction/program256 regression passed all 46 GPU cases with exact
HDR agreement, checking 218 direction-sort passes, 472 indirect256 passes, and 191,097
reordered entries. A packet-mask sweep on alpha/procedural scenes passed another 36 cases
across all eight retention masks. Another 24 exact cases cover subgroup64, legacy direct256,
and a fixed bounce-two tail with subgroups disabled, including 513x513 multiple-tile input.
This totals 106 GPU cases. The shader build, 198 unit tests, typecheck and library build pass.
Helmet HDR, alpha and transmission smoke renders pass with both program256 and direction256
exact dispatch enabled; all three screenshots were inspected. Performance measurements follow.

The follow-up opaque megakernel specializes closest-hit and NEE traversal to `ALPHA=false`:
all five reference workloads currently bind opaque wavefront traversal, while the reference
megakernel retains the general alpha-capable traversal (runtime instance flags skip opacity
evaluation). Its 0/1/2/4/8/16-slot modules all compile. The internal opt-in now selects the
specialization only for geometry without alpha-tested instances, with explicit pipeline-label
checks in the GPU harness. The shader build preserves all pre-existing generated modules
and their stack-variant data byte-for-byte. The 205 unit tests and typecheck pass, including
opaque variant reconstruction and concurrent/cache/fallback ownership checks. The library
build isolates the optional payload in a 647.80 kB (77.13 kB gzip) lazy chunk. All 46 GPU
regression cases pass with exact output: alpha/constant-alpha/transmission/clearcoat select
the general kernel, empty scenes select the empty kernel, and emissive/analytic/procedural/
stress/helmet/specgloss/anisotropy exercise opaque pipelines at capacities 1/4/8. The saved
report records actual bound labels. Helmet HDR, alpha and transmission smoke renders with
the opt-in enabled pass, and all three screenshots were inspected. Performance is still being evaluated. This comparison
can separate a useful scene specialization from gains attributable to stage decomposition.

### Continuation octant sorting, five balanced rounds

`ray-sort-original-v1` (revision `a19ed35`) compares the original five scenes with adaptive
compaction, automatic material capacity, 32 measured samples, 64 warmup samples per block,
and five balanced rounds. All 100 non-reference paired HDR comparisons are exact, the
saved-output/order verifier passes, and all five screenshots were inspected. Median GPU
spans in milliseconds per sample:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Megakernel | 10.041 | 4.350 | 2.673 | 2.810 | 1.548 |
| Wavefront, unsorted | 8.571 | 6.092 | 5.366 | 3.728 | 1.750 |
| Direction64 | 8.856 | 6.049 | 5.477 | 3.870 | 1.822 |
| Direction256, direct | 8.734 | 6.129 | 5.683 | 3.961 | 1.859 |
| Direction256, exact indirect | 8.898 | 6.145 | 5.787 | 3.927 | 1.858 |

The 64-slot sort lowers breakfast-room's paired-round median span by only 0.63%; it is
slower in every paired round on the other four scenes. Direction256 does not establish a
general gain either. Its mean Intersect time falls from 3.846 to 3.761 ms in classroom and
4.030 to 3.941 ms in breakfast-room, but sorting itself costs 0.170/0.120 ms and other stages
also change. BMW, glass and MIS show higher Intersect time after direction256 sorting.
This octant key therefore does not reliably improve traversal coherence enough to pay for
queue reordering. Exact dispatch reduces breakfast-room's mean sorting cost from 0.120 to
0.101 ms, but adds count-generation/copy overhead; classroom's combined compaction time
increases from approximately 0.566 to 0.650 ms. Ray sorting and exact sort dispatch remain
disabled by default. Per-stage times are means and must not be subtracted directly from
the table's median spans. Reports also confirm the actual 64-indirect, 256-direct and
256-indirect dispatch modes rather than inferring them from requested settings.

### Exact program256 dispatch with mixed complex materials

`sort-indirect-mixed8-v1` uses the same revision, fixed scenes and timing settings, with
eight-layer mixed materials, program256 sorting, and six balanced rounds (two cycles with
opposite order). All 60 paired HDR comparisons are exact, the sweep verifier passes, and
all five screenshots were inspected. Median spans:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Program256, full-tile direct | 9.859 | 9.135 | 7.651 | 5.623 | 3.177 |
| Program256, exact indirect | 9.853 | 9.094 | 7.593 | 5.654 | 3.224 |

Paired-round median changes are -0.55/-0.52/-0.21/+0.62/+1.59 percent. Every scene has
both faster and slower rounds, so these data do not establish a stable benefit. Sorting
cost decreases by roughly 0.02 ms/sample, while compaction costs rise by roughly 0.02-0.04
ms/sample. The option remains disabled. BMW's megakernel span varies from 6.826 to 8.474 ms
and glass from 6.513 to 7.801 ms, reinforcing the need to compare the two wavefront variants
within each round rather than crediting changes in the megakernel baseline to this dispatch
optimization. Both sorting investigations include full span timing and preserved HDR output.

### Opaque megakernel reference, original materials

`opaque-original-v1` (revision `f4748dd`) interleaves the general megakernel, adaptive
wavefront, and the opaque megakernel for six balanced rounds, 32 samples/block and 64
warmup frames/block. All five scenes select the opaque pipeline at capacity 1/1/0/0/0.
All 60 non-reference paired HDR comparisons are exact, the saved-output/order verifier
passes, and all five screenshots were inspected. Median GPU spans:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 10.323 | 4.408 | 2.709 | 2.820 | 1.546 |
| Opaque megakernel | 9.757 | 3.745 | 2.585 | 2.761 | 1.501 |
| Adaptive wavefront | 8.579 | 6.096 | 5.357 | 3.698 | 1.739 |

Opaque/general paired-round median changes are -6.62/-14.84/-4.53/-2.88/-2.82 percent.
Breakfast-room and glass improve in every round. Classroom and BMW each have one slightly
slower round; MIS has a first-round 1.966 ms outlier (+27.2%) followed by five rounds at
1.495-1.506 ms. These observations support testing the specialization further, especially
under large material stacks, rather than assuming a uniform improvement from the median.
Classroom's wavefront advantage remains after giving the megakernel opaque traversal;
the other original scenes still favor the megakernel. Hardware register/occupancy changes
remain unmeasured. The internal opaque option is still disabled pending broader results.

### Opaque megakernel reference, eight-layer SVM stress

`opaque-stress8-v1` repeats the same six-round paired test on all five scenes after applying
the eight-layer material stress graph. Every scene selects capacity16 in all three variants,
and the recorded opaque pipeline is `pathTracing.opaque.stack16`. All 60 paired HDR comparisons
are exact, the sweep verifier passes, and all five screenshots were inspected. Median spans:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 27.774 | 13.589 | 9.210 | 11.705 | 6.961 |
| Opaque megakernel | 18.776 | 9.581 | 6.825 | 6.864 | 5.224 |
| Adaptive wavefront | 12.051 | 9.171 | 7.639 | 6.632 | 4.249 |

Opaque specialization improves every paired round on every scene. Paired median reductions
are 32.01/29.95/26.28/41.03/25.62 percent. Timing variation remains: opaque glass ranges from
6.655 to 8.429 ms and MIS from 5.069 to 5.807 ms, but even their slowest paired comparisons
improve on the general reference. Wavefront still leads on classroom and MIS; its smaller
median advantages on breakfast/glass need care given this variation. BMW now favors opaque
megakernel. These data show that the earlier general-reference speedups partly included
traversal specialization; they must not all be attributed to wavefront/register isolation.
The original-material and stress runs together provide 120 exact HDR comparisons, with
source hashes, actual pipeline/capacity checks and two balanced ordering cycles per run.

## Shading-state liveness experiment

The `split`, `late` and `split-late` modes described above are implemented with unchanged
bytecode, estimator arithmetic, RNG sequence and work storage. Generated WGSL confirms
that continuation entries do not load albedo/normal and write only field 5.w for cone spread;
delayed entries call EvalMaterial before LoadPath and absorption multiplication. This is
source-level liveness evidence, not a measured hardware register count.

Validation: shader generation, 208 unit tests, type checking and library build pass.
Three preparation tests cover default exclusion of experimental entries, requested-phase
caching across capacities, concurrent requests, destruction during compilation and retry.
GPU comparisons against the forced-16-slot general megakernel all have maximum error zero
across the full HDR/albedo/normal output buffer:

- `correctness-tail-999-0-adaptive-shade-split-late-operands-0`: 46 cases, including all
  material features, constant-only and empty scenes, clamps, partial workgroups and multiple tiles.
- `correctness-tail-999-0-selected-subgroup-shade-late-operands-0`: 16 cases covering alpha,
  procedural, analytic-light and eight-layer stress materials with the delayed mode alone.
- `correctness-tail-2-0-selected-adaptive-shade-split-operands-0`: the same 16 cases with
  split shading and a fused tail starting at bounce 2.
- `correctness-tail-999-0-selected-adaptive-dispatch-sweep-shade-split-late-operands-0`:
  36 cases spanning all eight direct-stage masks with alpha and procedural materials.
- `correctness-tail-999-0-selected-packet-packet-sweep-shade-split-late-operands-0`:
  36 cases spanning all eight packet-stage masks with analytic and procedural materials.

These 150 comparisons record actual bound phase pipelines. The full 46-case run precedes
the host-only lazy preparation refactor; the other 104 cases exercise the final preparation
path. Shader sources/generated output are identical across those runs. The default remains
unified pending complete paired GPU span measurements.
`npm run smoke -- --integrator wavefront --shade-mode split-late helmet-hdr alpha transmission`
passes all three 64-spp renders without GPU/console errors; all three screenshots were inspected.

### Original-material shading measurements

`shade-original-v1`, revision `3daaa60`, uses adaptive compaction, 32 spp, 64-frame variant
warmup and five balanced rounds (each of the five variants occupies each position once).
All 100 per-round candidate HDR comparisons are exactly equal to the general megakernel;
the sweep verifier passes and all five saved `shade-late` presentation images were inspected.
Median complete GPU spans, milliseconds/sample:

| Variant | Classroom | Breakfast | BMW | Glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 10.126 | 4.294 | 2.686 | 2.805 | 1.551 |
| Unified wavefront | 8.617 | 6.045 | 5.368 | 3.698 | 1.740 |
| Split | 8.464 | 6.026 | 5.399 | 3.811 | 1.770 |
| Late loads | 8.639 | 6.055 | 5.337 | 3.806 | 1.733 |
| Split + late loads | 8.521 | 6.047 | 5.422 | 3.786 | 1.776 |

Paired median percent changes against unified, in the same scene order:
split -1.80/-0.19/-0.02/+1.77/+1.53; late +0.63/+0.12/-0.37/+3.00/-0.35;
combined -1.11/-0.57/+1.37/+2.51/+2.15. Paired ratios need not equal ratios of the
independent medians in the table. Split wins all five classroom rounds (0.29–2.28 percent),
but loses every glass (0.32–3.19 percent) and MIS (1.29–2.27 percent) round. Combined also
wins each classroom round but loses every MIS round. Late-only has mixed faster/slower
rounds in every scene. These data do not justify a general default change.

Average summed Shade time on classroom decreases from 1.464 ms to 1.379 ms for split,
while MIS increases from 0.449 ms to 0.478 ms. Static phase specialization is not uniformly
beneficial even though continuation AOV traffic is removed. First-scene experimental pipeline
groups take approximately 9.4–10.8 seconds of asynchronous preparation each in this run;
requests within a group overlap, so their individual durations must not be summed. They
are outside render timing and default unified preparation does not request these groups.

### Eight-layer shading measurements

`shade-stress8-v1` uses the same revision, five balanced rounds and settings, with eight
procedural layers on every material and actual scene capacity 16. All 100 per-round HDR
comparisons are exact; the verifier passes and all five saved presentation images were
inspected. Median complete GPU spans, milliseconds/sample:

| Variant | Classroom | Breakfast | BMW | Glass | MIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 27.571 | 14.135 | 9.270 | 11.630 | 6.987 |
| Unified wavefront | 12.063 | 9.167 | 7.694 | 6.567 | 4.176 |
| Split | 11.932 | 9.132 | 7.614 | 6.556 | 4.202 |
| Late loads | 12.498 | 9.449 | 7.850 | 6.785 | 4.414 |
| Split + late loads | 12.552 | 9.429 | 7.858 | 6.837 | 4.417 |

Paired median percent changes against unified, in scene order:
split -0.72/-0.72/-0.58/-1.01/+0.74; late +3.92/+2.94/+2.69/+2.63/+5.69;
combined +4.45/+2.13/+2.78/+2.48/+5.76. Split wins every BMW round (0.38–2.05 percent)
but has mixed faster/slower rounds in each other scene. Late-only loses every classroom,
breakfast and MIS round; combined additionally loses every glass round. The source-level
delay of path loads therefore does not produce a useful general optimization here.
Average summed Shade time rises from 6.862 to 7.326 ms on classroom and from 2.881 to
3.059 ms on MIS for late-only. Split's smaller changes do not justify a default change.
Both shading sweeps together provide 200 exact HDR comparisons and ten inspected images.

The next candidate is static SVM-capacity grouping within the shading queue. Current sorting
only groups programs; all lanes still use the scene's maximum compiled capacity. A capacity
group must also cover the scene-wide emission-program requirement because NEE evaluates
other emissive materials. A nonmatching group must return before any path/shadow write,
especially the current shadow-mask clear. Mixed-complexity workloads are the relevant target;
uniform capacity-16 stress remains a useful overhead control. The initial implementation follows.

## Shading capacity groups

`--shade-buckets` now enables an initial scan-based implementation, default off. Each referenced
capacity scans the same shading queue (or direct physical slots), exits before any write when
the material belongs to another group, and uses a statically sized SVM. This is not a compacted
partition: repeated dispatches, queue reads and inactive lanes are explicit costs to measure.
The current implementation requires unified shading; fixed/adaptive tails keep their global
capacity. A single group equal to the global capacity reuses ordinary shading. `prepareBuckets`
compiles only the two queued/direct shading entries per needed capacity, without compiling
traversal/tail kernels at every size.

Independent compiler program maxima are packed through a conservative scene-wide emission
floor, since NEE evaluates other materials. Alpha traversal and shadow opacity remain bounded
by the global stack requirement. Dead slots are checked before reading potentially invalid hit
indices, and nonmatching groups never clear shadow metadata. Even a path terminating after NEE
can have a pending shadow contribution that subsequent groups must preserve.

`--bucket-sweep --paired --mode wavefront --compaction adaptive --balanced-order --repeats 5`
compares general megakernel, unified wavefront, capacity scans, program-sorted wavefront and
program-sorted capacity scans. When the base is already sorted or uses direct shading, only
the capacity candidate is added; choose repeats in multiples of the resulting variant count.
This isolates capacity effects from program coherence. Correctness checks record actual bucket
pipeline capacities and include mixed constant/complex surfaces and cross-material emission
programs, partial groups and multiple tiles. No hardware register counts are inferred.

The scan implementation passes all 54 GPU regression comparisons in adaptive mode,
with exact HDR/AOV agreement against the forced-capacity reference, and 212 unit tests.
The mixed fixture explicitly assigns four material graphs to the sphere asset's five
meshes (the source asset shares just one material). Its optimized shading capacities
are 0/2/4; the cross-material emission fixture uses 2/8, exercising the emission floor
for constant surfaces. Both fixtures cover partial workgroups and more than one tile.
Shader compilation, TypeScript checking and the library build also pass. Performance
measurement remains pending; the option stays off. An additional 36 direct-stage
mask comparisons and 36 packet-mask comparisons cover both new fixtures; 12 further
comparisons combine program sorting, tail fusion from bounce two and disabled
subgroups with alpha and both bucket fixtures. All have zero HDR/AOV error.
Helmet HDR, alpha and transmission smoke runs pass at 64 spp and their screenshots
were inspected (`.tools/wavefront/bucket-smoke`). Thus the complete and extended
regressions total 138 comparisons, excluding the eight preliminary boundary checks.

Three original research scenes (BMW, glass and MIS) have only constant materials
and already select the capacity-zero interpreter. Their bucket option reuses the
ordinary Shade pipeline, providing an unchanged-path control. Classroom and
breakfast-room have a mixture of capacity-zero and capacity-one materials. The
heterogeneous 1..8-layer procedural workload is recorded separately from original
asset measurements; its higher capacity range must not be represented as the
original scenes' material complexity.

### Capacity scans: original scenes

`buckets-original-v1` compares five variants over five balanced rounds, with 64 warmup
frames per variant and 32 measured spp. The full sweep verifier passes; all 100
per-round candidate HDR comparisons have zero error. All five presentation captures
were inspected. Values below are medians of complete GPU spans in ms/sample.

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 10.227 | 4.330 | 2.747 | 2.814 | 1.550 |
| Wavefront | 8.586 | 6.078 | 5.377 | 3.699 | 1.740 |
| Capacity scans | 9.207 | 6.367 | 5.366 | 3.698 | 1.739 |
| Program sort 256 | 8.660 | 6.953 | 5.703 | 3.982 | 1.864 |
| Program sort + scans | 8.857 | 7.070 | 5.729 | 3.947 | 1.860 |

Median paired scan changes against wavefront are +7.28%/+4.75% for classroom and
breakfast-room; both regress in every round. Their sorted scan variants are also
slower than sorted wavefront in every round (+2.12%/+1.80% median paired change).
The other three scenes execute the same shading path with the scan flag enabled;
their small timing changes are controls, not capacity-specialization gains.

Classroom's mean Shade time is 1.467 ms without scans, versus 1.237 + 0.825 ms for
the capacity-zero/one scans. Program sorting reduces those scan stages to
1.189 + 0.525 ms but adds 0.142 ms of sorting. These stage means identify duplicated
queue scans and partially occupied shading dispatches as costs to address; they
are distinct from complete-span medians.
The next experiment must test compact capacity ranges, rather than interpreting
this scanning result as a rejection of all capacity specialization.

### Capacity scans: heterogeneous procedural materials

`buckets-mixed8-v1` repeats that protocol with 1..8 noise layers distributed across
materials (`--material-layers 8 --material-mixed`). All five scenes, five balanced
rounds and 100 candidate HDR comparisons pass verification with zero error. The five
captures were inspected. Complete GPU span medians, ms/sample:

| Variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| General megakernel | 26.600 | 11.427 | 8.143 | 6.610 | 3.961 |
| Wavefront | 11.014 | 8.561 | 7.368 | 5.723 | 3.096 |
| Capacity scans | 15.963 | 11.610 | 10.244 | 7.099 | 4.393 |
| Program sort 256 | 9.772 | 9.144 | 7.619 | 5.631 | 3.185 |
| Program sort + scans | 13.651 | 11.946 | 10.744 | 6.897 | 4.547 |

Scans regress in every paired round of every scene: median changes against ordinary
wavefront are +45.04%/+35.63%/+39.04%/+24.05%/+42.32%. Sorting does not rescue the
scans: sorted scans are +40.15%/+30.59%/+40.09%/+23.17%/+42.77% slower than sorted
wavefront, again in every round. Sorting alone improves classroom in all rounds
(-10.99% median paired change), while it regresses breakfast and BMW in all rounds;
glass and MIS have mixed round directions. No global sorting default is justified.

Classroom mean Shade increases from 5.832 ms to a sum of 10.762 ms across capacity
2/4/8/16 scans. Program sorting reduces the ordinary Shade to 4.712 ms, while sorted
scans still total 8.509 ms. The scan approach remains a measured negative control;
the compact-range implementation is the next candidate, with explicit queue and
indirect-dispatch validation required before measuring it. The shader/backend
register-allocation mechanism remains unmeasured.

## Compact capacity ranges (experimental)

`--shade-buckets --bucket-mode compact` replaces repeated queue scans with
CountBuckets/PrefixBuckets/ScatterBuckets followed by ShadeBucketCompact entries.
Each workgroup builds two 32-bit lane masks per capacity, then popcounts produce
stable local ranks. Global workgroup reservation order can vary. The shader needs
no subgroup feature. Count and Scatter read B, filter inactive packet slots, and
write grouped indices into queue C, which is free until CompactShade creates new
shadow indices. No queue copy or path-record move is needed. Original B/counts stay
intact for existing compaction modes. Direct shading is rejected; fixed/adaptive
tails retain their global-capacity implementation.

Each capacity has a count, cumulative offset and scatter cursor in appended scratch
storage. Prefix creates exact indirect arguments, including zero-work buckets. The
host copies all six argument records to the indirect buffer and dispatches each
prepared shading capacity at its own offset. A sole bucket matching the global
capacity still uses ordinary Shade and performs no partition work. Preparation is
lazy and completes before the host publishes the new mode.

`--partition-sweep --paired --mode wavefront --compaction adaptive --balanced-order
--repeats 4` compares general megakernel, ordinary wavefront, scans and compact ranges.
The same `--sort program --sort-size 256` option can apply to all wavefront variants.
Correctness diagnostics read GPU queues, material headers, metadata and actual
indirect arguments outside timing. They check an exact active-path permutation,
bucket membership, prefix/cursor/count agreement, local ordering, and dispatch offsets.
The final compact implementation passes 54 full GPU regression comparisons, 20
direct-intersection/shadow combinations (masks 0/1/4/5), and 54 packet-mask comparisons
with program256 sorting, fixed tails from bounce two and subgroups disabled. A further
12 scan-mode controls on the same sources also pass. All 140 HDR/AOV comparisons have
zero error. Full-suite GPU partition diagnostics inspect 134 partitions containing
266,886 active path entries, including 644 empty buckets and 310 shading dispatches.
The queue checks use actual bound GPU material headers and copied indirect arguments;
test-only COPY_SRC usage enables those readbacks without changing production buffers.
All 213 unit tests, shader compilation, TypeScript checking and library build pass.
Helmet HDR, alpha and transmission smoke renders pass at 64 spp and all three captures
were inspected (`.tools/wavefront/compact-bucket-smoke`). The wavefront library chunk
is 757.17 kB (89.05 kB gzip). The complete default `npm run smoke` also passes all
21 cases; every screenshot was inspected, including the debugging and exposure views.

### Compact ranges: paired measurements

Revision `b3860ee` was held fixed for three five-scene sweeps, each with four balanced
rounds, 64 warmup frames per variant and 32 measured spp. All sweep verifiers pass,
all 180 candidate HDR comparisons are exact, and all 15 presentation captures were
inspected. Complete GPU span medians in ms/sample:

| Workload / variant | classroom | breakfast-room | bmw-m6 | glass-of-water | veach-mis |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original / general megakernel | 10.378 | 4.386 | 2.689 | 2.816 | 1.549 |
| Original / wavefront | 8.564 | 6.044 | 5.363 | 3.707 | 1.747 |
| Original / scans | 9.140 | 6.334 | 5.359 | 3.698 | 1.742 |
| Original / compact ranges | 9.109 | 6.486 | 5.422 | 3.826 | 1.743 |
| Mixed 1..8 layers / general megakernel | 26.767 | 11.705 | 8.068 | 6.749 | 3.896 |
| Mixed 1..8 layers / wavefront | 10.961 | 8.588 | 7.370 | 5.735 | 3.100 |
| Mixed 1..8 layers / scans | 15.974 | 11.615 | 10.181 | 7.066 | 4.408 |
| Mixed 1..8 layers / compact ranges | 12.192 | 11.416 | 10.554 | 6.606 | 4.642 |
| Mixed + program256 / general megakernel | 27.345 | 11.384 | 7.508 | 7.601 | 3.888 |
| Mixed + program256 / wavefront | 9.840 | 9.152 | 7.646 | 5.658 | 3.240 |
| Mixed + program256 / scans | 13.753 | 12.141 | 10.645 | 6.932 | 4.552 |
| Mixed + program256 / compact ranges | 12.033 | 12.198 | 10.778 | 6.868 | 4.672 |

The reports are `partitions-original-v1`, `partitions-mixed8-v1`, and
`partitions-mixed8-sorted-v1` under `.tools/wavefront`. The sorted workload applies
program256 to all wavefront candidates; the general megakernel remains unsorted.
Its variation across separate runs must not be credited to a wavefront optimization.

On original classroom/breakfast, compact ranges regress against ordinary wavefront
in every round (+6.05%/+6.86% median paired changes). BMW/glass/MIS all use ordinary
Shade.stack0 even with the bucket flag, so their changes (+0.77%/+2.59%/-0.29%) are
unchanged-path timing controls. In particular, glass ranges from +0.91% to +4.84%
despite identical shading, illustrating the limit of interpreting small differences.

On mixed materials, compact ranges regress in every round of every scene against
wavefront: +11.26/+32.89/+42.96/+15.13/+49.70 percent. They improve on scans for
classroom/breakfast/glass (-23.69/-1.70/-6.68%), but worsen BMW/MIS (+3.66/+5.31%).
Program sorting does not rescue capacity partitioning: sorted compact ranges regress
in every round against sorted wavefront (+22.11/+33.39/+41.17/+21.38/+44.15%).

Original classroom's mean Shade is 1.455 ms; scans total 2.047 ms; compact shading
totals 1.664 ms with 0.316 ms of Count/Prefix/Scatter work. Mixed classroom's mean
Shade is 5.823 ms; scans total 10.833 ms; compact shading totals 6.671 ms plus
0.261 ms of partition work. Merely merging the three partition passes cannot close
the remaining shading gap. Resource allocation and locality remain hypotheses rather
than measured hardware causes. Capacity partitioning stays opt-in. A distinct next
experiment is full-queue material grouping at unchanged global SVM capacity, to test
shader coherence independently of capacity specialization; the existing 64/256 sorts
only group paths inside small chunks.

## Full-queue material grouping (experimental)

`--shade-buckets --bucket-mode material` retains the global SVM capacity and groups all
active hit indices within each bounded tile by exact material identity. It does not group
across tiles. CountMaterials/PrefixMaterials/ScatterMaterials
reuse queue C; original B remains intact for the next compaction. One existing
ShadeBucketCompact entry at the scene capacity consumes C. All six capacity summaries
describe the same full queue, so no new SVM interpreter or shading implementation is needed.
The input indirect dispatch bound is sufficient; shading guards against the active total.
This differs from both capacity grouping and the existing 64/256-slot local sorts.

The experiment currently accepts 1..256 material headers including fallback. `GpuScene`
publishes that count with the scene, and the eighth uniform word passes it to partitioning.
The host rejects out-of-range counts before encoding GPU work. This limit only applies to
the opt-in experiment. Per-workgroup lane masks preserve local input order; global group
reservation order can vary. Packet slots are filtered before hit/material access.

`--bucket-mode material --bucket-sweep --paired --mode wavefront --compaction adaptive
--balanced-order --repeats 5` compares general megakernel, ordinary wavefront, full-queue
material grouping, local program256 sorting, and their combination. GPU diagnostics check
the exact active permutation, material membership, prefix/cursor/counts, local order,
the global-capacity pipeline and the actual indirect offset. A 256-header fixture uses
material IDs 63/64/127/254 and fallback 255 with many empty groups and multiple tiles.
The final implementation passes 58 complete GPU regression comparisons, 20 direct-stage
combinations, and 72 packet-mask combinations with program256 sorting, fixed tails from
bounce two and subgroups disabled. Both older capacity-grouping implementations also
pass 12 control comparisons each on the final sources. All 174 HDR/AOV comparisons have
zero error. Full-suite diagnostics inspect 326 material partitions, 428,869 active path
entries and 7,247 empty groups. The 256-header fixture proves all five boundary IDs are
actually present in the grouped queue, in the full, direct and packet runs.
All 214 unit tests, shader compilation, TypeScript checking and library build pass.
The extra shader module is 9.0 KiB; existing SVM/shading generated modules are unchanged.
The wavefront library chunk is 767.41 kB (90.24 kB gzip). Helmet HDR, alpha and
transmission smoke renders pass at 64 spp; all three captures were inspected and
saved in `.tools/wavefront/material-bucket-smoke`. Performance is pending.

## Work storage layout

Group 1 binding 0 contains the original image prefix (three float4 per pixel), then
three float4 headers, 21 float4 field arrays at the current tile capacity, then three
packed uint index queues (main A, main B, shadow), then 262 float4 scratch records
(4,192 bytes). Capacity grouping uses the first twelve records; material grouping uses
six summaries followed by up to 256 count/offset/cursor records. Header words 0/1/2 store A/shadow/B counts;
word 3 optionally stores the current main queue's exact 256-slot sort bound.
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
no pass binds overlapping read/write aliases simultaneously. The 144-byte dispatch argument
buffer is COPY_DST | INDIRECT, not a storage buffer. Compaction and copies stay on GPU.
