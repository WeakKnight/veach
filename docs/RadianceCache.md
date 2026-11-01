# Radiance cache

World-space probes of incoming radiance, the fallback of realtime reflections: where SSSR's screen-space ray misses,
or a surface is too rough for screen-space rays, FidelityFX's environment lookup becomes a radiance cache lookup
(`FFX_SSSR_SampleFallback` in `shaders/Sssr/SssrCallbacks.hlsli`), and only without valid probes the sky. Offline frames
never touch it. Sources: `shaders/RadianceCache/RadianceCacheCommon.hlsli` (layout, lookups),
`shaders/Passes/RadianceCache.slang` (probe trace), `src/render/RadianceCache.ts` (scheduler, GPU host).

## Why no marking

Lumen's and SGI's translucency radiance caches mark the probes a frame's translucent pixels need, then allocate and
trace those. That fits a sparse consumer. Here the consumer is every reflective pixel, and the lookups come from SSSR
at the end of the frame, so marks would arrive a frame late, in exactly the regions that just appeared (disocclusions,
camera turns), where the fallback matters most, and would add a feedback path and an indirection.

So storage is dense: every clipmap cell owns a probe, whether anything looks at it or not. What stays from Lumen is the
clipmap layout around the camera, the octahedral probes and the budgeted, staggered update. The cost is memory and trace
budget spent on cells in empty space or inside walls, bounded by the fixed grid: 4 × 24³ probes, 29 MB.

## Layout

`clipmaps` (4) windows of R³ cells (R = `radianceCacheResolution`, 24), each twice as coarse as the last, centered on the
camera. Clipmap 0 cells are 1/96 of the scene's bounding box diagonal, so clipmap 3 spans about 2 diagonals. World cell w
of clipmap c lives in slot `posmod(w, R)`: scrolling a window keeps every probe still inside it and reuses the slots
of the cells it left. Probes sit at cell centers.

All probes share one storage buffer, so lookups take a single binding. `grid.w` words per probe:

| Words | Content |
| --- | --- |
| 0 | State: `floordiv(w, R) & 255` per axis in bits 0-23, VALID bit 24, INSIDE bit 25 |
| 1 | Traces accumulated |
| 2-3 | Unused |
| 4... | Per octahedral texel (P = 8): half2(r, g), half2(b, first hit distance) |

The state names the world cell a slot holds, so a lookup rejects a slot that still holds a scrolled-out cell. Radiance is
scene-linear, not pre-exposed; lookups multiply by `gSssr.preExposure`.

## Scheduling

`RadianceCacheScheduler` (pure, `tests/radianceCache.test.ts`) picks at most `radianceCacheProbesPerFrame` (1024) slots:

1. Newly covered slots (first frame, scroll, invalidation), nearest the window center first, interleaved over clipmaps.
2. Young slots: traced since their cell became new, but fewer than `RADIANCE_CACHE_YOUNG_TRACES` (4) times, oldest
   first. A probe's first trace is one path per texel: used alone, a texel whose path found nothing bright is black.
   Before this step, probes that scrolled in during camera motion showed as cell-sized black blocks in reflections.
3. The rest: a round robin per clipmap, with shares 0.4 / 0.3 / 0.2 / 0.1.

A slot is traced at most once per frame. The first fill takes 54 frames at the default budget; a full refresh of the
finest clipmap takes about 34.

## Probe trace

`TraceProbes` runs in the trace encoder, after the path tracer, one 8×8 workgroup per slot and one path per texel.
Paths use the megakernel's traversal, materials and next event estimation, with `radianceCacheBounces` (2) bounces, and
each path jitters inside its texel.

- The first segment skips the sun disc and analytic lights: their highlights are direct lighting in realtime frames, and
  seeing them here would count them twice. Later vertices sample and hit them normally.
- History is a running average up to 16 traces, then α = 1/16.
- More than 25% of rays hitting back faces flags the probe INSIDE.

Probes are discarded (`RadianceCache.invalidate`) on a new scene, resolution or lighting setup: sky, sun enable and
diameter, environment intensity, rotation, importance. Other lighting changes and moving geometry settle through the
history, over 16 updates per probe.

## Lookup

`RadianceCacheSample(position, normal, direction)` takes the finest clipmap whose window contains the 8 probes around the
position, biased 0.25 cells along the normal. Invalid, INSIDE and scrolled-out probes are skipped. Each remaining probe's
weight is the product of:

- the trilinear weight;
- the DDGI backface term `((dot(toProbe, n) + 1) / 2)² + 0.05`;
- visibility: the probe's mean hit distance toward the biased point, compared with the point's distance, fading the probe
  out (to 0.02) over a quarter cell once something lies in between. This keeps probes on the far side of a cabinet door or
  inside a wall cavity from leaking in.

Each probe is read parallax corrected. Its mean hit distance t along `direction` places the reflected surface at
`position + direction * t`, and the probe is sampled toward that point rather than along `direction`, so all 8 probes
look at the same surface.

Without visibility and parallax, interpolating probes that see different things showed as blocks and bands with the
12 cm cell period, for example vertical bands on the kitchen's cabinet doors.

Probes also weigh by maturity, their trace count over 8 (plus 0.02), and each clipmap's lookup returns its confidence:
the maturity averaged with the other weights. The next, coarser clipmap takes over:

- over the last 2 cells of a clipmap's window, so the level change has no seam;
- where the clipmap's probes are younger than its own, since a coarser level scrolls less and its probes have more
  traces.

The weights are `inside * max(confidence, 0.05)` for this level and `(1 - inside) + inside * (1 - confidence) *
coarseConfidence` for the next. A total weight ≤ 1e-6 moves on to the next clipmap; with no clipmap left the lookup returns false and the sky takes over. Texels are
bilinear (radiance and mean hit distance), with mirrored octahedral borders. The lookup adds about 0.1 ms to SSSR in
the kitchen (0.35 to 0.45 ms).

## Bindings

Trace: group 1 bindings 2 (constants), 3 (probes, read-write), 4 (update list, 1024 slots in a uniform buffer); group 0
is the scene, so it adds no scene storage buffer. Lookups: SSSR bindings 43 (constants) and 44 (probes), with dummy
buffers while the cache is off. `RadianceCacheConstants` is 176 bytes; `RadianceCache.writeConstants` must match it.

`RadianceCache.wgsl` is a material stack variant program (`MaterialStackVariants.ts`), built by `npm run build:shaders`.
SSSR's callback change is in `npm run build:sssr`, which patches the staged `classify_tiles.h` and `intersect.h`.

## Host

`settings.radianceCacheEnabled` (true), `radianceCacheProbesPerFrame`, `radianceCacheResolution`, `radianceCacheBounces`;
console `r.RadianceCache.Enabled | ProbesPerFrame | Resolution | Bounces | Stats`; `renderer.radianceCacheStats`. It is
created with SSSR and only traces while SSSR is active. The GPU profiler has a `Radiance cache` scope.

## Measurements

Camera motion (dolly test: 40 frames at 0.8% of the distance per frame, the presented frame against the
converged one at the same position): young re-traces and the maturity weight took the share of pixels below 30% of
their converged brightness from 0.65% to 0.16%, and the mean error from 3.7% to 3.05%.

Kitchen, realtime, 896×560 render size: 0.85 ms per frame at 1024 probes, 13.6 ms total. Mean luma error of a 16×8 grid
against a 512 spp offline reference: 6.61 with the cache, 12.05 with the sky fallback.

## Limitations

- Probes are not relocated: one inside a wall stays INSIDE, and thin walls can leak.
- Parallax and visibility use one mean hit distance per texel (8x8): at depth edges the mean blends both sides, and
  thin occluders between texel directions are missed. DDGI's Chebyshev test would need the second moment as well.
- Lookups do not prefilter by roughness: an 8×8 probe is too blurry for near mirrors, and rough lobes get the same
  bilinear read.
- Updates are camera-centered, not view-driven: off-screen probes cost the same as visible ones.
- Lighting changes outside the invalidation key settle over 16 round robin cycles of each clipmap.
