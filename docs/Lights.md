# Lights

All lights share one buffer and one power CDF. Underestimated power is safe.

Persistent host scenes rebuild this buffer when analytic lights or emitting draws change.
Moving a nonemitting instance leaves it untouched. Emitting transforms recompute world-space
area (including nonuniform scale), selection weights and CDF; records remain in primitive
order. Shared geometry can have distinct emitting materials per instance. Light material and
instance references use the persistent sparse slots. Host updates to texture-dependent
emission invalidate the referencing compiled material and light estimates. Analytic lights
use the same `LightDesc` units through `SceneUpdate`; Three.js lights require explicit host
conversion in the first adapter version.

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

The legacy `setBatchedShadows` switch now enables no-SVM visibility classification followed
by a compacted alpha queue. The first geometric candidate includes alpha geometry: miss is
visible, opaque is blocked, and alpha is unresolved. Only unresolved source bits are retraced
from their original intervals. Each path retains environment/emitter/sun alpha evaluation
order and VT state; resolved sources are not traced again. The three surviving contributions
are summed in original order before throughput/clamping. There are no fixed rounds, prefix
skips, candidate arrays or transparency-depth limits. Pure opaque scenes use the original
shadow kernel and allocation. The pending queue reuses shading queue B after CompactShade.
