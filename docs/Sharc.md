# WebGPU spatial radiance cache

SHARC-style caching is enabled by default for eligible wavefront rendering. Maintenance
pipelines are prepared alongside the first geometry-bearing wavefront scene; empty scenes
keep their lightweight path. Use `Renderer.setSharc(false)` or viewer `?sharc=0` to disable it.
This default was enabled by user choice during iteration, before full performance qualification.
The goal is to replace expensive
path suffixes with reusable world-space radiance, without lowering the configured bounce
budget for training paths. This is an approximate estimator, not a pixel-identical mode.

## Reference and adaptation

The implementation follows the update / resolve / query workflow inspected in the local
DXVK Remix checkout:

- `src/dxvk/shaders/rtx/pass/sharc/sharc_integrator_utilities.slangh`
- `src/dxvk/shaders/rtx/pass/sharc/sharc_resolve.comp.slang`
- `submodules/sharc/docs/Integration.md`

It adopts sparse full-path updates, backward radiance propagation, temporal averaging,
and segment-length / footprint gates before early termination. Veach's code is independently
implemented for WebGPU; NVIDIA SDK headers, binary layouts and 64-bit atomics are not used.
This is not a complete RTXGI SDK port. In particular, sparse updates share the normal
wavefront pass, and queries consume the previous sample's resolved cache.

## Path integration

One hashed, rotating lane out of each 16-path group is an update path. It uses the normal
bounce limit, Russian roulette, SVM, NEE, alpha visibility and terminal environment/light
handling, and never queries the cache. It records up to four secondary vertices (bounces
1 through 4, excluding the final bounce). Each record stores a key, radiance prefix and
incoming throughput. After all deferred shadows have finished, `Finalize` computes
`max(finalRadiance - prefix, 0) / throughput`. Near-zero or nonfinite training targets
are rejected. Update selection does not consume the path RNG.

While SHARC is actually active (`gFrame.sharc.y != 0`), both update and query paths skip
Russian roulette at the primary surface, following Remix's `calculateRussianRouletteOnFirstBounce`
in `algorithm/integrator_direct.slangh`. This sets continuation probability to one: no RR
random draw or probability compensation is applied there. Invalid/zero BSDF samples and
the configured bounce limit still terminate normally. Subsequent bounces keep Veach's
existing RR policy, including update paths; Remix's separate exemption for update paths
at later bounces is not implemented here. Disabling SHARC or using an ineligible mode keeps
the original first-bounce RR behavior. The common `ShadePath` covers all wavefront shading
variants; megakernel has no active SHARC and remains unchanged.

The prefix is saved after local emission MIS, before direct-light sampling. The cache
therefore stores the reflected suffix, including NEE at that vertex and excluding that
vertex's own emission. Query hits add `throughput * cachedRadiance` and terminate before
queuing NEE or sampling another BSDF. This preserves local emission weighting and avoids
counting direct lighting twice. The first hit always follows normal shading.

Training and queries require roughness at least `roughnessThreshold` (default 0.5),
metalness below 0.1, and no transmission, subsurface or coat. Queries additionally require
the segment to exceed the voxel diagonal, the hit ray-cone width to exceed the voxel size,
and cone spread at least 0.05. Glossy, transmission and ineligible surfaces continue tracing.

## Cache keys and GPU synchronization

Keys include full integer world voxel coordinates, distance level, quantized geometric
normal, outgoing direction octant, material ID and instance slot. Exact key comparison
prevents unrelated hash collisions from returning another surface's radiance. The base
voxel size is scene diagonal / 256 unless specified in scene units; distance levels double
cell width at increasing camera distances. Cell coordinates remain anchored in world space.

Each tile runs three maintenance dispatches after path finalization:

1. `Statistics` reduces the per-path counters.
2. `Accumulate` updates existing cells or claims empty slots using 32-bit compare-exchange.
3. `Publish` writes newly claimed keys in a separate dispatch.

No lane spins waiting for another workgroup. Readers never depend on a relaxed atomic
publishing a newly written key within the same dispatch. Pending insertions may drop
updates; eight failed linear probes also drop updates. Such collisions lose training
opportunities rather than substitute another key's value.

After all tiles, `Resolve` averages each cell's new samples, combines with bounded history,
resets sums, and evicts stale cells. Queries during all tiles see the same resolved radiance
from before that sample; newly published cells have zero confidence until resolve.

Radiance sums use unsigned fixed-point (scale 1024), clamp each channel to 4096 and accept
at most 512 samples per cell per epoch, keeping sums within 32 bits. Resolve tracks
confidence separately from temporal weight. A default four accumulated samples are required
before querying; history weight caps at 16 epochs and stale cells expire after 64 epochs.
An epoch advances only when a path-traced sample is submitted, not during presentation.

## Memory and layouts

All persistent cells and temporary records occupy the existing `gAccum` tail, before the
raster visibility scratch. There is no additional path-stage storage binding:

- 64-byte header, including GPU counters.
- 64 bytes per cell; default 65,536 cells (~4 MiB).
- Four 64-byte records per 16 tile paths (~16 bytes/path, rounded by group).

A cell's sixteen words contain state, xyz voxel coordinates, packed normal/direction/level,
material and instance, last-update epoch, three integer sums, sample count, three resolved
RGB float words, and packed history/confidence. A record's four float4 blocks contain key,
IDs/validity/claim, prefix (later target), and throughput. Tile record storage is cleared and
reused only after that tile's publication has completed. Counters reuse the existing normal
path slot's unused w component.

`FrameUniforms` is 304 bytes. SHARC groups at byte offsets 240/256/272 contain cache offset,
cell count, record offset and epoch; voxel size and roughness threshold; minimum confidence,
history cap, stale age and record count. Offsets are uint-word addresses. CPU allocation
subtracts cache and record reservations before determining wavefront tile capacity.

## Lifetime, controls and limitations

`setSharc(enabled, options)` compiles maintenance pipelines lazily, resizes shared storage
and resets accumulation. Supported options are `voxelSize`, power-of-two `capacity`
(4096–262144), `roughnessThreshold` (0.3–1), `minSamples` (1–512), `historyFrames` (1–64),
and `maxAge` (1–1024). `resetSharc()` clears history and accumulation explicitly.

Scene/geometry/material/light changes, environment replacement or rotation/intensity changes,
sun changes, texture-page arrivals, bounce budget and texture mip bias changes invalidate
history. Camera-only motion and accumulation resets preserve it. Exposure and tone mapping
preserve it. Buffer replacement or changed cache layout invalidates it. Scene updates currently
clear the entire cache, so continuously edited/animated scenes may have little opportunity
to warm up; selective invalidation is not implemented.

`sharcStats` reports the last frame's requested/active state, reason and memory. The cache
falls back to ordinary rendering for megakernel, empty scenes, debug views, bounce budgets
outside 2–128, firefly clamping, fused tails or insufficient buffer budget. Firefly clamping
is excluded because a camera-throughput-dependent clamp would distort the inverted training
target. Disable SHARC to release its work reservation. Camera DOF remains compatible with
SHARC because it uses the existing camera path and only caches secondary surfaces.

`await readSharcStats()` explicitly reads counters: paths, segments, hits, query attempts,
update paths, recorded/accepted updates, occupied cells and insertion failures. Normal rendering
does not read back or wait for these counters. Segment counts include the primary segment,
including raster-resolved primary visibility; they are not a count of BVH kernel invocations.

Spatial averaging, direction octants, finite training depth, mixed remaining bounce budgets,
fixed-point clamping and temporal reuse introduce bias. Sharp lighting boundaries and textured
variation within a cell can blur, and cache confidence alone does not certify low variance.
Reducing voxel size trades hit rate for spatial fidelity. The current implementation does not
include separate depth-conditioned caches, selective dynamic invalidation, query interpolation,
or Remix's full option/debug surface.

## Limited integration check (2026-10-30)

`node scripts/sharc-check.mjs` runs one 128×96 diffuse room, maximum 8 bounces, with default
raster primary visibility and the eight-storage-buffer limit. Cache voxel size is 0.3,
minimum confidence 4, history 8. The reference uses 16 spp; after 49 cache training samples,
accumulation is reset and 16 cached spp are compared. These are iteration checks, not a
convergence or timing benchmark.

| Counter | Cold cache | Warm cache, sample 65 |
| --- | ---: | ---: |
| Paths | 12,288 | 12,288 |
| Segments | 37,936 | 24,256 |
| Mean segments/path (including primary) | 3.087 | 1.974 |
| Cache terminations | 0 | 7,432 |
| Accepted update records | 909 | 1,135 |
| Occupied cells | 909 | 3,802 |

Segment work decreased about 36%; this does not measure total frame speedup. Cache and
record storage used 4,390,976 bytes. The low-sample HDR relative L2 difference was about
2.28%; this includes Monte Carlo noise and is not a convergence guarantee. Output was finite.
Exposure-only change preserved history; lighting change reset to epoch 1 with zero hits;
disabling freed cache storage. Shader build, typecheck and five focused allocation/primary
visibility unit checks passed. Broad smoke, performance sweeps and high-sample comparisons
were intentionally omitted during iteration.
