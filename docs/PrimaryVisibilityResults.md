# Primary visibility results — partial performance run

`auto` now prefers raster primary visibility for eligible views, explicitly enabled by the user on 2026-10-30. Use `await renderer.setPrimaryVisibility('ray-traced')` to opt out. The full performance gate has **not been assessed**: the user requested stopping broad validation during iteration, and the remaining benchmark and queued extra tests were stopped. The default selection is a user decision, not a claim that the partial measurements passed the original gate.

## Completed validation

Shader generation, type checking, library build and 260 unit tests passed. Default and raster smoke runs each passed 21 cases; all 42 current screenshots were inspected. Cold-cache VT streaming settled without GPU/console errors.

48 unique GPU comparisons passed: 16 scene/mode cases, three 513×513 multi-tile cases, 11 persistent-host states and six scenes at 1024 samples with three independent seeds (0, 12345, 987654). Host coverage includes off-axis perspective, scaled-camera world-space near clipping, negative/nonuniform scale, material transparency changes, sparse removal, geometry/attribute updates, buffer growth, resizing and multiple samples. Megakernel/debug fallbacks were also checked.

No unexplained interior ID mismatch occurred. On matching primitives, distance, barycentric, UV0/UV1, interpolated-normal, material-ID, SVM albedo/roughness and shading-normal differences were zero. In the seed-zero 16-sample suite, TransmissionTest had six equal-depth ties and one projected-edge difference; EmissiveStrengthTest had one projected-edge difference. These are recorded coverage/overlap differences, not bit-identical output claims.

The maximum HDR/albedo/normal relative-L2 error over the 18 high-sample comparisons was 0.0953% (the check limit was 0.5%). These comparisons froze the shared VT residency after 24 warmup samples. The harness now additionally waits for settled VT observations and records residency; that extra rerun was queued but stopped at the user’s request.

[Correctness data](benchmarks/primary-visibility-validation.json) contains the individual results. Local screenshots/logs remain under `.tools/visibility`.

## Completed performance measurements

2026-10-30; Windows; NVIDIA GeForce RTX 4090, driver 595.97; Chrome/156.0.8078.73. Classroom and breakfast completed all three resolutions and five alternating rounds. Each variant used 64 warmup and 128 measured samples, 8 bounces, denoising off and fixed resident textures. No other test renders ran concurrently. The interrupted BMW run is excluded from the table; remaining scenes were not measured.

GPU values below are medians of round medians, in milliseconds/sample. Complete time is the trace-sample span including queue/copy gaps; presentation/exposure are outside it. Primary time includes cull-through-raster and all tile resolve-through-fallback spans, including indirect argument copies. The original default uses independent pixel jitter; the shared-jitter reference isolates the visibility change.

| Scene | Resolution | Default RT sample | Shared RT sample | Raster sample | Shared RT primary | Raster primary |
|---|---|---:|---:|---:|---:|---:|
| classroom | 640×360 | 10.357 | 10.034 | 9.939 | 0.227 | 0.152 |
| classroom | 1280×720 | 34.678 | 34.661 | 33.823 | 0.878 | 0.322 |
| classroom | 1920×1080 | 73.596 | 74.097 | 72.482 | 1.859 | 0.578 |
| breakfast | 640×360 | 6.140 | 6.146 | 5.817 | 0.515 | 0.197 |
| breakfast | 1280×720 | 20.997 | 20.927 | 20.076 | 1.175 | 0.404 |
| breakfast | 1920×1080 | 41.218 | 41.217 | 39.816 | 1.816 | 0.632 |

Every measured raster sample used one geometry draw. The JSON also reports visible clusters, useful/padded vertex slots, fallback counts, CPU encoding/submission time, allocation bytes and per-stage timings. Per-stage timings are medians per invocation, not sums across tiles/bounces; complete and primary times are per sample. Buffer totals cover scene and work buffers; visibility attachment bytes are separate, excluding common VT/environment resources.

[Performance data](benchmarks/primary-visibility-performance.json) preserves the completed subset and source fingerprint from before the default switch. The opaque geometric-mean gate and mixed/deep-alpha regression gates require the unfinished matrix; `AUTO_RASTER_PRIMARY` is enabled by the subsequent user decision.

## Iteration policy

For subsequent iterations, run only checks directly relevant to the changed behavior. Broad regression, multi-seed convergence and the complete performance matrix require an explicit user request. The validation/benchmark scripts remain available for that request; they are not scheduled to run automatically.
