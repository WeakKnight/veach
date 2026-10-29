# Temporal anti-aliasing without progressive accumulation

TAA defaults on for host frames, including the aim/racing examples, and for the viewer when
`settings.accumulation = false`. It is bypassed while progressive cross-frame accumulation
is enabled. Real-time rendering always traces exactly 1 spp; the raw current-frame HDR and
material guides remain available separately from TAA's presentation result. This renderer
does not have a standalone progressive accumulation pass: static cross-frame averaging lives in the
path finalization shaders. TAA adds `taa.motion` followed by `taa.resolve` compute passes.

## Remix reference

The local reference is `E:/GitHub/dxvk-remix/src/dxvk/rtx_render/rtx_taa.cpp` and
`shaders/rtx/pass/temporal_aa/temporal_aa.comp.slang`. Veach independently implements the
same broad approach: perceptual-quantizer (PQ) HDR feedback, 3×3 neighborhood moments,
standard-deviation history clipping, jittered sampling, ping-pong history and a responsive
current-frame weight. No Remix source is copied. This is native-resolution TAA, without
Remix's optional TAA upscaling or Catmull-Rom upscale reconstruction.

Explicit motion follows `shaders/rtx/concept/camera/camera.slangh`'s
`cameraCalcMotionVectorPixel` and `algorithm/geometry_resolver.slangh`: previous minus current
screen position, in render pixels, with X right/Y down and jitter excluded. Misses use camera
rotation/projection only. Veach generates it from existing primary guides in a separate
compute pass instead of extending the eight-buffer path layout. This is an independent
implementation, including rigid instance transforms and off-axis camera projection.

Veach validates each history tap against surface identity and reconstructed position rather
than blindly adopting the longest neighboring motion vector. This avoids borrowing another
surface's motion at an edge. It adds conservative disocclusion rejection appropriate to our
primary-hit data and does not require a ninth path-stage storage binding.

## Frame data and reprojection

`FrameUniforms` is 304 bytes. The final float4 at byte 288 holds the current film jitter
(xy in [0,1]), a guide-enable flag and padding. A 32-frame Halton (bases 2 and 3) sequence
is shared by raster visibility and the single primary ray per pixel in each TAA frame.
Subsequent path RNG dimensions remain unchanged. Without TAA, the
existing per-sample camera jitter behavior is retained.

Primary shading stores ray distance in the albedo float4's w component and numeric instance
slot + 1 in the normal float4's w component. Background uses zero for both. Wavefront and
megakernel finalization preserve these two fields when TAA is active. RGB guides are unchanged.
The slots are in the image prefix, separate from SHARC's reused path work metadata. No
extra primary BVH traversal, material evaluation or path-stage buffer is introduced.

The motion pass reconstructs world position from the actual jittered camera basis and distance.
For an object hit, current world-to-object and previous object-to-world transforms give
the previous world position. The inverse previous camera basis projects that point to the
previous image, including off-axis host projection and jitter compensation. Background uses
direction-only reprojection. Previous instance records are copied on the GPU after resolve,
not after every scene commit, so multiple commits between frames still refer to the last
rendered pose.

The explicit motion buffer uses two float4s (32 bytes) per render pixel. The first contains
`[motionX, motionY, 0, valid]`; the second stores the previous world position (direction for
background), allowing resolve to retain its existing positional checks without repeating
instance transforms. Invalid projections produce finite zero motion with valid=0. Off-screen
but projectable motion is retained; resolve checks its history bounds separately. Resolve
reads this buffer and addresses history at `pixel + motion + currentJitter - previousJitter`.
Static camera/objects therefore produce zero motion even as the Halton jitter advances.
Camera and rigid-instance motion are supported, including rotation/nonuniform scale; no
previous deforming vertices or secondary reflection/transmission motion are available.

Four bilinear history taps are checked individually. Out-of-frame, unmatched instance IDs,
inconsistent world positions (two projected pixel footprints), and strongly differing normals
are rejected. New surfaces therefore start from the current frame. Large rotations may
conservatively reject history because normals are compared in world space. Warmup uses at
least `1/(age+1)` current weight; per-pixel age caps at 32. Motion increases responsiveness,
excluding jitter-only movement. The 3×3 PQ mean ± clamping-factor × standard deviation clips
the accepted history before blending. First/rejected samples retain their current radiance.

## Presentation and lifetime

History is PQ-encoded scene-linear radiance: remove current pre-exposure before filtering,
then reapply it to the result. Auto exposure, local exposure and presentation all read the
TAA result through the existing presentation-buffer switch. Exposure, tone mapping and LUT
changes preserve TAA history. OIDN remains exclusive to converged progressive static scenes.

Ordinary scene updates do not reset TAA: object hits/destruction/spawn, geometry/material/
texture/light edits, page streaming and routine renderer/feedback setting changes retain
history. Existing reprojection, tap validation and PQ neighborhood clipping handle changes,
following Remix's normal feedback approach. No per-object generation or new local invalidation
scheme is used. The automatic translation/rotation/FOV cut heuristic has been removed.

Full resets are reserved for resolution changes, switching to a different scene, temporal
mode transitions, explicit `HostFrame.cameraCut` / `resetTaa()`, and maximum-radiance changes
that change PQ history encoding. Growing instance storage retains the old transform snapshot
through the current resolve; a larger buffer then records the next-frame pose. The old buffer
is retired after submission. Instance add/remove and slot reuse do not trigger a global reset.
Without previous deforming vertices or generation IDs, deformation/slot reuse may still
produce transient history artifacts; clipping is the existing mitigation.

History/output resources allocate lazily. Two 48-byte-per-pixel history buffers store PQ/age,
position/instance and normal; another 48-byte-per-pixel buffer is the presentation result.
The previous-instance snapshot adds one instance-buffer allocation. These buffers belong to
the independent TAA layout, plus the 32-byte/pixel motion/previous-position buffer (seven
storage bindings total), within WebGPU's eight-buffer guarantee.
Disabling TAA stops its work and switches presentation back to raw current color, retaining
the allocation for toggling; resize and renderer destruction release resources. Debug views,
progressive accumulation and viewer depth of field bypass TAA. Memory size is checked against
the device's per-buffer limits. This is not a total VRAM-budget estimator.

## Runtime controls

```text
r.Accumulation.Enabled 0
r.TAA.Enabled 1
r.TAA.NewFrameWeight 0.1
r.TAA.ColorClampingFactor 2
r.TAA.MaximumRadiance 100
r.TAA.Stats
r.TAA.MotionVectors 1
r.TAA.MotionVectors 0
r.TAA.Reset
```

The accumulation switch controls the static viewer. Host frames remain independent regardless
of that preference, and the game explicitly selects false. `taaStats` reports actual mode,
history-frame count, last reset reason and allocated bytes. The frame count is not a claim
that every pixel accepted history. TAA reduces temporal edge noise but is not an indirect-light
denoiser. Reflection/transmission motion uses the visible primary surface; variance clipping
limits mismatch but cannot provide secondary-surface motion. PQ's maximum-radiance setting
limits feedback range, so very bright content may need a larger value.

`taaMotionVectorDebug` / `r.TAA.MotionVectors` is a presentation-only visualization, active
when TAA runs. Gray means zero motion; R/G encode signed X/Y with ±32 pixels at the limits;
magenta means no previous projection. History continues storing ordinary PQ radiance and
is not reset by the toggle. Exposure adaptation is held while viewing motion and the display
bypasses tone mapping/LUTs. `renderer.motionVectorBuffer` exposes the borrowed buffer for
GPU consumers/readback; it is null when TAA is inactive, overwritten each frame and replaced
on resize. This does not enable motion generation while progressive accumulation or DOF
bypasses TAA.

## Iteration validation

Shader build, TypeScript/game production build and five focused console/camera-math checks
passed. `node scripts/taa-smoke.mjs` exercises one production aim scene, checks GPU history
reuse on the moving target, finite output, separate raw/presentation buffers, exposure changes,
off/on switching and explicit reset. Captures and counters are stored in `.tools/taa/`.
The target also retained history after a deliberate 1.5-world-unit translation, larger than
the positional rejection tolerance. In the 480×320 internal-resolution run, TAA allocated
22,122,608 bytes; 150,549 / 153,600 pixels accepted history in the sampled frame after that
translation, and the target's center retained age 32. These are correctness/usage counters,
not a frame-time benchmark or an image-quality score.

The reset-policy regression (`scripts/taa-hit-check.mjs`) fired three real target hits and
waited for debris removal/target respawn. TAA history advanced continuously from 18 to 137
across 120 checked frames, including instance snapshot growth from 4096 to 8192 bytes.
The production game build/typecheck passed and no GPU/browser errors were recorded.
No full scene matrix, convergence campaign or performance sweep was run. The test does not
establish that all reflection/alpha/disocclusion cases are free of ghosting.

Explicit motion validation (`node scripts/motion-check.mjs`) uses one production aim scene
and independent Three.js projection as the reference. Stationary geometry across changing
jitter had maximum residual motion 0.000126 pixels. A target translation/rotation/nonuniform
scale yielded motion (-18.258362, 0.104736) versus reference (-18.258351, 0.104753).
Camera translation/rotation/off-axis projection checked 3174 pixels, including 1274 sky
pixels, with maximum error 0.000086 pixels. All motion/output values were finite; debug
output matched its encoding and history frames advanced 12 through 17 without resets.
The shader build, game production build/typecheck and five existing focused tests passed;
the motion screenshot was inspected. Report/capture: `.tools/motion/`. This adds no broad
scene/performance sweep and does not validate deforming or secondary-surface motion.
