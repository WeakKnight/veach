# Lights

All lights share one buffer and one power CDF. Underestimated power is safe.

## Emissive triangles

- Every triangle of an emissive instance is listed in primitive order (`lightOffset + primIdx`),
  so BSDF hits can compute the MIS pdf.
- Selection uses a power CDF.
- `EmissiveTriangle.pad.x` is the instance index, so emission programs can use object-space
  positions.

## Analytic lights

`LightDesc`, Cycles conventions (power in watts):

- Point / spot (spheres, radius 0 = delta) and area (rect / ellipse) lights occupy the first
  `counts.w` entries of the light buffer, share its power CDF and are tagged `LIGHT_ANALYTIC`
  (layout in `SceneTypes.slang`).
- They are not in the BVH: they never occlude, and BSDF and camera rays intersect them separately
  (`IntersectAnalyticLights`) for MIS and camera visibility.

## Deferred NEE in wavefront

With `setSeparateLight(true)`, ShadeSurface samples emitter geometry and computes BSDF/pdf/MIS;
analytic and zero-stack emitters complete immediately. Other emitters save triangle index,
all three barycentric weights and viewer/pdf in two scratch fields. ShadeLight reconstructs
the same texture context, evaluates emission/masked opacity, then completes the contribution
before visibility. It uses the same multiplication order and VT state as inline SampleEmissive.
Light tasks are not material sorted. Surface sorting does not imply light-shader coherence.

Batched alpha shadows collect up to four BVH candidates without SVM, evaluate opacity in a
separate entry, and repeat for four batches. They retain BVH encounter order and source order
(environment, emitter, sun), including texture feedback. Continuations replay traversal and
skip the evaluated prefix; a complete any-hit fallback handles all remaining candidates.
Thus four batches limit dispatch overhead, not transparency depth. This differs from Cycles'
closest-hit distance batches because Veach must preserve its stochastic alpha/VT sequence.
The three surviving source contributions are summed before throughput/clamping, as before.
