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
