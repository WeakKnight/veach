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
GPU pass timings exclude command dispatch gaps/copies, so wall times are also recorded.

## Design constraints

- Keep at most eight storage buffers per stage. Pack work data into existing bindings.
- Preserve all path state needed for MIS, absorption, ray cones, random sequences and AOVs.
- Preserve VT feedback and streaming, including alpha-tested traversal and emissive sampling.
- Keep material graph evaluation and BSDF sampling together initially; isolate ray traversal.
- Use GPU queue counts/indirect dispatch rather than per-stage CPU readback.
- Explore compaction, shader/program grouping, opaque traversal, and specialization based on measurements.
- Commit generated shader outputs and keep the megakernel available for A/B testing.

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
