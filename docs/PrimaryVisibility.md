# Raster primary visibility

`await renderer.setPrimaryVisibility('rasterized')` selects a GPU-driven visibility
buffer for pinhole wavefront camera rays. `ray-traced` retains the original camera
sampling/traversal; `auto` is the default and prefers raster visibility for eligible
views. The viewer accepts `?primaryVisibility=ray-traced` to opt out. Changing the mode resets
accumulation. This replaces visibility only: material reconstruction, SVM evaluation,
BSDF sampling, NEE, secondary intersections and shadows retain their existing behavior.

## Geometry and resources

Each geometry part is split into clusters of at most 64 triangles, sorted by centroid
Morton code (original primitive ID breaks ties). Original indices, BVH order, material
identities and emissive `lightOffset + primitiveIndex` indexing do not change. A cluster
descriptor is eight uint words: `min.xyz`, absolute primitive-list word offset,
`max.xyz`, triangle count; floats are bitcast. Primitive lists contain original IDs.
Cluster-instance pairs are two words: sparse instance slot and descriptor word offset.
These regions share `gIndices`; geometry descriptors are shared across instances.
Host geometry edits rebuild only changed parts. Transform/material edits retain the
clusters; instance additions/removals update the pair list. Both loaders and persistent
host scenes fall back to ordinary geometry storage if metadata exceeds the index budget.

Visibility scratch occupies a separately reserved tail of `gAccum`, after all existing
wavefront/light scratch. It contains 16 header words and two words per cluster-instance
pair, rounded to 16 bytes. Header words 0/1/2 are visible count/near-risk/near-candidate count; word 3 counts sparse-dispatch fallback pixels; 4..7 hold draw
arguments, 8/9 count total/alpha fallback pixels, and 12..15 hold near-check dispatch
arguments. The visible list starts at word 16; the near-candidate list follows its
full pair-count capacity.
Wavefront capacity calculations subtract this reservation before choosing tile capacity.
Insufficient scratch budget disables raster visibility. No ninth storage binding is added.

Frame uniforms are 240 bytes. The last uint4 is the scratch word offset, pair-list word
offset, pair count and instance slot bound (not the active instance count). Flag 16
selects the shared camera jitter. Wavefront group 1 binding 3 samples the `rg32uint`
visibility texture; inactive modes bind a 1x1 dummy. Independent cull/raster layouts use
the existing frame, instance, vertex, index and accumulation buffers. The existing
indirect buffer grows from 144 to 176 bytes; the last two records hold raster draw and
near-check dispatch arguments.

GPU culling tests transformed cluster boxes against the jittered frustum and appends
visible pairs and near candidates. A separate dispatch writes `{192, visibleCount, 0, 0}`
and the near-check dispatch arguments. Polygon clipping runs only on the near queue in
a separate kernel, keeping its private arrays out of ordinary culling. Triangle-plane
separation cheaply rejects distant walls and floors before clipping. One nonindexed
`drawIndirect` uses vertex pulling with a cluster per draw instance. Padding triangles
are degenerate. Flat vertex outputs carry both IDs, so no optional primitive-index,
multi-draw, nonzero indirect-first-instance, subgroup or mesh shader feature is needed.
The render targets are `rg32uint` (8 bytes/pixel) and `depth32float` (4 bytes/pixel).
All materials share one pipeline, with backface culling disabled and no fragment SVM.

## Camera, resolve and fallback

The camera basis is inverted to obtain the raster projection, including host off-axis
and affine transforms. Each sample hashes its existing seed into a shared 2D jitter.
Camera ray generation still consumes the two original pixel RNG dimensions before
substituting that jitter, preserving subsequent path random dimensions. Rasterization
uses reverse depth, infinite far projection and a near distance of 1e-4 world units
along the image-plane normal, including scaled/sheared host cameras. The near region is guarded by conservative cluster screening followed by triangle
clipping against the small near frustum. A possible clipped hit sets a GPU flag causing
all primary pixels to use the original traversal for that sample. No flag readback is
needed for rendering. Large surfaces crossing the eye plane outside the near frustum do
not by themselves trigger the fallback.

The prepass runs once per sample, outside the path-tile loop. Each tile then executes
Initialize, ResolvePrimaryVisibility, CompactPrimaryFallback, PrimaryFallbackArguments,
PrimaryTraceFallback (dense or sparse), and the existing CompactIntersect/Shade sequence. Resolve fetches original triangle
vertices for opaque IDs and invokes the same object-space ray/triangle intersection
routine to recover t and barycentrics. This is one triangle test, without BVH traversal.
Failed reconstruction and alpha candidates are queued in B; A retains all primary
paths. Fallback retraces from the original camera ray interval, selects a no-SVM opaque
traversal variant when the scene has no alpha, evaluates alpha only inside existing traversal, and has no fixed layer count or replay rounds. CompactIntersect
may reuse B after fallback finishes. Opaque transmission materials use the fast path.
A GPU argument pass selects one-ray workgroups for queues of at most 256 rays, spreading
rare, divergent boundary traces over more SMs; larger queues retain 64-thread workgroups.
Both dispatches are indirect, with zero work for the unselected variant. The sparse
argument record reuses the raster draw record after the draw has finished. This does not
retrace a ray twice or change per-path random state.

Both visibility sources use CompleteIntersection for camera-visible analytic lights,
environment, sun and background, exactly once. Existing surface reconstruction retains
normals, object position, UV0/UV1, tangents, ray cones and texture-footprint conventions.
Depth of field, debug views, megakernel and empty scenes use their existing paths.
An experimental tail starting at bounce zero also retains full ray tracing.

`primaryVisibilityStats` reports requested/effective CPU-selected mode, reason, draw
count and allocation sizes. `await readPrimaryVisibilityStats()` explicitly reads GPU
visible-cluster, useful/padded vertex-slot and fallback counts; ordinary rendering performs no such readback.
`nearClipFallback` indicates that the raster candidate pass fell back for the whole sample.
The explicit readback then reports actual `ray-traced` mode with reason `near-clip`,
while retaining the candidate draw/allocation counts. The synchronous getter cannot
observe that GPU flag and reports the selected candidate path.

## Correctness boundaries

The raster mode changes per-pixel independent jitter to shared sample jitter; individual
samples need not match the original mode. The validation harness enables the same shared
jitter in the ray-traced reference. On nonboundary, noncoincident surfaces, IDs must match
and t-relative/barycentric-absolute errors must not exceed 2e-5.

Hardware subpixel coverage can choose another surface at silhouettes or shared edges;
equal-depth overlapping surfaces can also choose another primitive than BVH traversal.
The GPU checker separately records projected-edge differences within 1/128 pixel and
depth ties within 2e-6 relative distance. It does not waive arbitrary internal pixel
mismatches. These cases are not promised bit-identical. At higher sample counts compare
HDR and AOV convergence in addition to first-hit data.

Virtual texture feedback has its own sequential RNG. Skipping alpha candidates behind
an opaque hit may change stochastic mip/feedback ordering. Keep resident-texture image
checks separate from cold-cache streaming tests; feedback sequences need not match.

## Validation and rollout

`node scripts/primary-visibility-check.mjs` performs matched-jitter GPU checks and writes
reports/screenshots to `.tools/visibility/check`. Options include `--only`, `--width`,
`--height`, `--samples`, `--seed` and `--max-relative-error` (optional HDR/AOV relative-L2 gate).
The validation-only `PrimaryVisibilityCheck.wgsl` reconstructs UV0/UV1, interpolated
normal, material ID, SVM albedo/roughness and shading normal from both hit sources.
It uses idle shadow scratch before ordinary shading and is never loaded by the renderer.
Matched primitives require attribute errors no greater than 2e-5. HDR, albedo and normal
convergence errors are reported separately; high-sample runs use three independent seeds.
`node scripts/primary-visibility-host-check.mjs` checks off-axis views, sparse instances,
geometry/material updates, buffer growth, resizing, multiple tiles and fallback modes.
`npm run smoke -- --primary-visibility rasterized`
checks the public viewer route, including debug/empty fallback. Unit coverage includes
cluster identity/bounds and persistent sparse-instance updates.

`node scripts/primary-visibility-benchmark.mjs` compares default wavefront, shared-jitter
ray tracing and raster visibility at 360p/720p/1080p, five alternating rounds, 64 warmup
and 128 measured samples per variant. GPU timestamps include raster passes; complete
span includes queue/copy gaps. Primary cost sums the prepass span and each tile's
resolve-through-fallback span, including their parameter copies and scheduling gaps.
Kernel-only sums and per-stage medians are reported separately. CPU encoding/presentation submission time, allocation sizes, visible vertex
slots and fallback counts accompany the GPU numbers. Readback/warmup are not counted as
render time. Reports are stored under `.tools/visibility/benchmark`.

The original performance targets were a 20% opaque primary-cost reduction, a 5%
complete-sample reduction, and mixed/deep-alpha regressions below max(5% of reference
time, 0.1 ms/sample). The complete matrix was stopped at the user's request during
iteration. On 2026-10-30 the user explicitly chose to enable `AUTO_RASTER_PRIMARY`;
this default selection does not claim those targets were measured or passed.
Correctness fallbacks and the explicit `ray-traced` override remain available.

Recorded validation, timings and the rollout decision are in
[PrimaryVisibilityResults.md](PrimaryVisibilityResults.md).
