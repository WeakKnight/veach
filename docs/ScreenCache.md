# Screen cache: the previous frame as an L1 radiance cache

Realtime SSSR frames (FRAME_FLAG_DIFFUSE_ONLY, [Sssr.md](Sssr.md)) reuse the previous frame's linear scene color as
the radiance leaving surfaces it saw, as NRD-Sample's "L1 cache" does (`Shaders/TraceOpaque.cs.hlsl`,
`ReprojectIrradiance`). Sources: `shaders/Passes/WavefrontScreenCache.slang` (march, lookups), the `ScreenTrace` /
`ScreenTraceIntersect` entries and the `ShadePath` lookup in `shaders/Passes/Wavefront.slang`, `src/render/ScreenCache.ts`
(constants) and `src/render/Wavefront.ts` (dispatch). Offline frames and the megakernel never use it: its mode is 0
outside SSSR frames, and offline renders stay bit-identical.

It has two parts:

- **Screen trace** (`settings.screenCacheTrace`): before any BVH traversal, the primary diffuse continuation (bounce 1)
  ray marches the previous frame's depth. On a confident hit it takes the previous frame's color there and the path
  ends. NRD-Sample does not have this part; it is closer to Lumen's screen traces.
- **Hit lookup** (`settings.screenCacheHits`): a BVH hit at any later vertex that the previous frame saw takes its color
  with probability equal to the lookup's confidence, instead of NEE and the rest of the path. This is NRD-Sample's L1.

Both mix two estimators of the same radiance (cache with probability c, path tracing otherwise), so a low confidence
costs speed but adds no bias of its own. The bias comes from the cache itself (below).

## Inputs

The previous frame's SSSR inputs (`SssrReflections.history`), which this frame's SSSR overwrites only after the trace:

- the closest-depth hierarchy (`r32float` mips, `near / viewZ`, 0 without a surface);
- normals, whose w Prepare now fills with perceptual roughness (+2 for metals) or -1 for emissive pixels;
- the linear scene color ping-pong: color + SSSR reflections, scene-linear.

The matrices are SSSR's (`sssrMatrices`): the previous frame's from SSSR, this frame's from the TAA camera and jitter.
There is no history on the first SSSR frame, after a resize or SSSR suspension, or on a TAA history reset (scene change,
camera cut); `renderer.screenCacheStats` reports it.

## Screen trace

`ScreenTrace` runs at bounce 1 over the main queue, before intersection. It skips paths whose primary sample crossed the
surface (refraction), SHARC update paths and absorbing paths.

The ray from the primary surface is projected into the previous frame. A straight line in view space stays straight in
(uv, inverted depth), and its end is kept in front of the near plane. `ScreenCacheMarch` is FidelityFX SSSR's
hierarchical march (`FFX_SSSR_HierarchicalRaymarch`, inverted depth), with `screenCacheIterations` (48) steps over the
hierarchy mips. A hit is rejected when:

- the march left the screen, reached infinity or ran out of steps;
- it landed on the background, or within 1.5 pixels of the origin (contact geometry needs the BVH);
- it hit a back face or an emissive pixel.

Confidence is `(1 - smoothstep(0, thickness * viewZ, |rayZ - surfaceZ|))²`, with `screenCacheThickness` 0.03, times a
5% screen border fade and the surface term (below).

Accepted paths add `throughput * color` (firefly clamped like other indirect contributions), set the NRD hit distance and
terminate. `CompactIntersect` then queues the rest into the shade queue, and `ScreenTraceIntersect` traces only those.
The usual `CompactIntersect` follows. This needs queued intersection: no direct dispatch, and no tail at bounce 1.

## Hit lookup

`ScreenCacheLookup` in `ShadePath` runs at non-primary vertices that are not emissive or transmissive, before the SHARC
query, as NRD-Sample's L1 comes before its L2. SHARC update paths skip it, so SHARC trains on complete paths.

The hit is projected into the previous frame, and its confidence is the product of:

- the view depth matching the depth buffer (relative error 2% to 1%);
- a 10% screen edge fade;
- the normals agreeing (0.5 to 0.9);
- the hit lying at least 1 to 3 pixels from the path's own pixel in this frame (NRD-Sample's "too short rays": the pixel
  would read its own result back);
- the surface term.

## Surface term and emission

The cache holds the radiance toward the previous camera; diffuse surfaces send the same radiance to the path vertex.
`ScreenCacheSurfaceConfidence` scales confidence by NRD's `GetSpecMagicCurve(roughness)` for metals and by
`lerp(1, curve, 0.2)` for dielectrics, times a history confidence of 0.95.

Emissive pixels (and pixels showing an analytic light) are never read. Their emission is MIS weighted against the NEE of
the previous vertex, and the cache cannot weight it. Bit 28 of the NRD fraction word (`NRD_EMISSIVE`) marks them while
tracing; Finalize writes it to w of the NRD region's diffuse direction, and SSSR's Prepare to normal w.

## Bindings

Wavefront group 1 binding 4 (`ScreenCacheConstants`, 160 bytes: both matrices as rows, mode, size, mips, near,
thickness, iterations, confidence), bindings 5-7 the three textures (unfilterable float), with 1x1 dummies while unused.
No storage buffer is added.

## Measurements (kitchen, 896x560 render size, SHARC on)

SHARC's GPU counters (`readSharcStats`), independent of GPU contention:

| | Segments / path (incl. primary) | SHARC hits / path |
| --- | ---: | ---: |
| off | 2.49 | 0.59 |
| screen trace | 2.40 | 0.49 |
| hit lookup | 2.37 | 0.44 |
| both | 2.34 | 0.42 |

SHARC already ends most paths at their first secondary hit, so the screen cache mostly takes those terminations over.
It does so with the previous frame's pixel instead of a voxel average, and removes about 10% of the secondary segments.

Frame times: path tracing went from 12.2 ms to about 10.9 ms with both parts on an uncontended GPU. Bounce 1
intersection is about the same with the screen trace (1.26 ms before, 1.18 ms for the survivors plus 0.14 ms for the
march): the rays it resolves are short ones that were cheap to trace anyway.

The luma grid error against the 512 spp offline reference is unchanged (about 6; 1.2 to 1.9 against the cache off,
signed difference within ±0.15).

In this view, most bounce 1 rays leave the screen, and most secondary hits are off screen or behind the camera in the
previous frame. A screen-space cache only covers what the camera saw.

## Limitations

- View-dependent radiance: the color includes SSSR reflections and the analytic-light highlights toward the previous
  camera. The surface term lowers confidence on glossy surfaces but does not remove them.
- One frame of lag, and moving objects reproject with the static camera transform. Lighting changes reach the cache
  only through the frames that show them.
- The cache's feedback (paths reading frames that read earlier frames) adds unbounded bounces, approximately.
- Thin geometry and anything hidden in the previous frame fall back to tracing; the depth buffer cannot tell thickness.
- Rays that leave the screen are traced from their origin again, not from where the march left.
