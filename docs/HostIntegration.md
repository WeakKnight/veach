# Host renderer integration

The application owns its scene graph, simulation and source assets. Veach owns persistent
render resources, flat instances and GPU-derived data. The core has no Three.js dependency;
`@tianyuliwiwo/veach/three` is an optional adapter, tested with Three.js r186.

## Lifetime and publication

Create a GPU-backed `RenderScene` with `renderer.createScene()`. `new RenderScene()` is useful
for CPU-only tooling/tests; it cannot be rendered by an unrelated renderer.

`beginUpdate()` opens one transaction. Create/update/release geometry, texture, material,
instance and analytic-light handles; `await commit()` publishes the batch. References are
validated against the final state, so removing an instance and its resources in either order
is valid. Releasing a still-referenced resource fails. Handles are opaque, typed and scene
scoped; they never become valid again after release.

Array data and small descriptors are copied when each update method is called. ImageBitmap
inputs are borrowed: keep them open until commit finishes. Veach never closes source images
or disposes Three.js resources. GPU preparation and pipeline compilation finish before
publication. Validation/preparation failures leave the previous CPU/GPU scene available; the
transaction closes and the caller can retry. Device loss requires recreating the renderer.

Only one transaction may be active per scene. `cancel()` closes an uncommitted transaction.
The first empty commit initializes a renderable empty scene; later empty commits do nothing.
`scene.dispose()` is idempotent; `renderer.destroy()` disposes all its scenes. Do not submit
commands captured from old bindings after a commit. Source lifetimes stay with the application.

## Data contract

- Geometry: indexed triangles, Float32 positions and Uint32 indices; optional normals,
  tangents, UV0 and UV1. Missing normals use geometric normals. Groups are ordered,
  nonoverlapping triangle ranges with material slots; omitted/empty groups use the full list
  in slot zero. Each group is one shared BLAS.
- Instances: geometry handle, material handles, invertible affine world matrix, enabled flag.
  Parenting and local transforms stay in the host.
- PBR: linear RGB base/emission, metallic/roughness, IOR/transmission, double-sidedness, unlit,
  opaque/masked alpha, tangent-space normal map, independent texture maps. Bindings select
  UV0/UV1, wrap, offset/scale/rotation and channel. Defaults: roughness G, metallic B, opacity A.
  Blended alpha is not part of the host API.
- Textures: RGBA8 bytes or ImageBitmap, plus srgb/linear interpretation. Content changes use
  `setTexture`; transforms belong to the material. There is no content hash or per-frame scan.
- Lights: existing `LightDesc` conventions (radiant power, point/spot/area). Hosts explicitly
  convert photometric units. Sky, sun and environment are renderer-level settings.
- Views: right-handed perspective matrices, camera looking down -Z, including off-axis views.
  Orthographic, stereo, lens distortion, depth-of-field and near/far ray clipping are not
  implemented in the host path.

## Incremental GPU work

Seven persistent arenas hold nodes, triangles, instances, vertices, indices, material data
and lights. The eighth storage binding remains per-pixel work. Regions keep offsets while
capacity suffices; freed ranges are reused. Buffers grow geometrically and upload live regions
once on growth. Ordinary commits upload dirty regions only and merge adjacent writes. The
high-water GPU allocation is retained until scene disposal.

| Change | GPU / acceleration work |
| --- | --- |
| Camera | Frame uniforms; no scene commit or BVH work |
| Instance matrix / enabled / membership | Changed instance records; TLAS rebuild when bounds/membership change |
| Positions / indices / groups | Changed geometry upload and group BLAS rebuild; TLAS update |
| Normals / tangents / UV | Changed vertex region; unchanged BLAS/TLAS |
| Material values / bindings | That material's compile/upload; affected instance flags/offsets |
| Texture content / dimensions / color space | Affected VT pages and referencing materials |
| Emitting geometry/material/transform or analytic lights | Light records and power CDF |
| Nonemitting instance motion | Unchanged light buffer |

BLAS refit is not implemented. Host build quality defaults to `BuildQuality.Fast`; override
with `createScene({ bvhQuality })`. Changed geometry uploads its whole vertex region, not
attribute subranges. Each commit still walks the flat instance list.

`FrameUniforms.envInfo.z` stores an independent TLAS node base. TLAS primitive indices refer
to sparse GPU instance slots. Material headers occupy 32-byte-aligned addresses in the existing
buffer, with absolute program/constants/texture offsets. No new storage binding is needed.
Experimental wavefront material bucketing can reach its ID limit sooner with sparse IDs.

Dynamic textures retain unaffected layouts, chains and physical tiles. Each source/wrap
combination has independent borders and a pinned tail. The default cache is 16×16 tiles;
set `renderer.virtualTextureOptions` before creating scenes. All tails plus one streaming
tile must fit. Reused virtual addresses are guarded by publication epochs that discard old
feedback. RGBA8 resizing uses nearest-neighbor power-of-two resampling; bitmap resizing uses
the existing GPU decode path. Streaming defaults to LRU, 64 uploads / 4 ms per frame, with
speculative fills of unused slots. Texture publication invalidates feedback conservatively.

## Three.js synchronization

After simulation, `await adapter.sync(root, camera)`, then render with `adapter.scene` and
`adapter.view(camera)`. Await each sync; failed commits do not advance detection snapshots.
The adapter updates world matrices without rendering through a Three.js renderer.

| Data | Detection |
| --- | --- |
| BufferAttribute | Identity, backing array, version, count, item size, normalization |
| InterleavedBufferAttribute | Attribute/data identity, data version, stride, offset |
| Index / drawRange / groups | Index identity/version/layout and small value snapshots |
| Material | Supported scalar/color/vector values, version, maps and map transforms |
| Texture source | Texture/source identity/version, image identity, color space, flipY, format/type |
| Object3D / InstancedMesh | World matrices, count and resource bindings |
| Visibility | Ancestors, material visibility and optional camera layers |

Set `attribute.needsUpdate = true` after array edits, or `attribute.data.needsUpdate = true`
for interleaved buffers. Pixel edits require `texture.needsUpdate = true`. No full-array
comparisons are performed; Three.js update ranges are not consumed or cleared. Hidden meshes
retain resources but leave the TLAS. Detached objects release Veach references; host `dispose()`
events alone do not remove objects from the renderer. Host resources are never disposed by the
adapter. `adapter.dispose()` releases its Veach scene.

Single-material meshes ignore groups, matching Three.js. Material arrays use groups/drawRange.
A geometry used in both modes has two renderer representations; instances within each mode
share BLAS. Nonindexed geometry is converted without modifying the source. InstancedMesh
transforms/count are supported, with a persistent handle per instance.

Supported materials: MeshStandardMaterial, the supported MeshPhysicalMaterial subset, and
MeshBasicMaterial (emission). Unsupported active features fail explicitly: custom shader
callbacks/materials, skinning, morph targets, vertex/instance colors, flatShading overrides,
lines/points/sprites/LOD, blended opacity, BackSide, clearcoat, sheen, anisotropy, iridescence,
dispersion, volume thickness/attenuation, specular overrides, wireframe, alpha hashing, clipping
planes, per-material environment maps, bump/displacement/AO/light/transmission maps, object-space normal maps, mixed
material visibility in one mesh, BatchedMesh, scene material overrides, and automatic Three.js light conversion. The legacy glTF
loader retains its broader material capabilities.

Textures support loaded image/canvas/bitmap and RGBA8 DataTexture sources. GPU-only,
render-target, compressed, cube and video sources need a future bridge. Canvas extraction
requires readable same-origin/CORS images. flipY, UV channel, wrap and decomposable affine
transforms are translated; shear (including rotated nonuniform repeat) is rejected. Sampler
min/mag filtering and anisotropy use Veach's policy rather than Three.js emulation.

## Frame behavior

Host scenes use the renderer's default adaptive wavefront integrator and scene opcode
specialization. The host GPU validation checks this default explicitly, including material
and alpha-mode changes that prepare different pipeline variants before scene publication.

`renderFrame({ scene, view, frameIndex, samplesPerPixel })` replaces prior radiance every call.
The frame ID varies the random sequence; samplesPerPixel (1–64) averages inside this frame.
No host-frame OIDN runs. Keep frame IDs increasing across commits. Exposure adaptation retains
presentation history, not path-traced radiance. Noise at low sample counts is expected.
[TAA](TemporalAA.md) now runs by default before presentation. It reconstructs camera and
rigid-instance motion from primary hit guides and a GPU snapshot of previous instance
transforms. Ordinary commits (including object add/remove, topology, material, texture and
light edits) preserve history and rely on reprojection and neighborhood clipping.
`cameraCut: true` on a host frame explicitly resets it.
NRD and deforming/skinned-vertex motion remain future work.

The legacy `setScene` / `start` viewer remains progressive for static assets and OIDN. Stop
its loop before using host frames. `start()` cannot run while a host scene is active. `onStats`
is driven by the owned loop; host apps can read scene/VT/exposure getters and
`hostSceneStats(scene)` (counters for the latest nonempty commit) directly.

## Examples and verification

`npm run dev:games` serves `http://127.0.0.1:5176`:

- `?game=aim`: 45-second mouse drill, moving targets, streaks, generated texture changes,
  shared target-geometry deformation, debris insertion/removal and pause/restart.
- `?game=race`: keyboard circuit driving, checkpoints, three laps, timing, barriers, chase
  camera, shared InstancedMesh scenery, pause/restart and R to return to the starting line.

`npm run smoke:games` checks actual GPU radiance for material/texture/geometry edits, no
cross-frame accumulation or stale geometry, shared release and empty scenes. It checks game
inputs and pause/restart, and drives three laps through normal keyboard handlers. Reports and
screenshots go to `.tools/games-smoke/`. `npm run build:games` builds `dist-games/`.

CPU tests cover transactions, allocator reuse/growth, real tinybvh updates, emission CDFs,
texture epochs and adapter detection. `npm run smoke` covers static glTF regressions.
Generated shaders are checked in after shader builds.

### Validation record (2026-10-29)

- `npm run typecheck`, `npm run build`, `npm run build:lib`, `npm run build:games`: passed.
- `npm run build:shaders`: generated the traversal changes and all specialization patches.
  No WASM or BSDF source changed, so their generated binaries were not rebuilt.
- `npm test`: 233 tests passed; the unrelated `.blend` fixture suite was skipped because its
  Blender sample fixtures were absent. Available glTF sample-dependent tests ran.
- `npm run smoke`: all 21 static rendering cases passed; screenshots inspected.
- `npm run smoke:games`: eight GPU-readback scenarios, aim hit/miss and the full 45-second
  session, three race laps using keyboard events, pause/restart and resource counters passed.
  No browser, shader or WebGPU errors were reported; game screenshots inspected.
- Library core and Three adapter imported successfully without a DOM. Package dry-run includes
  the adapter JavaScript, declarations and integration guide. No package was published.

### Main integration validation

Merged with main's adaptive wavefront defaults and opaque-classification/alpha-queue shadow
implementation. Conflicting generated Wavefront WGSL and stack-variant edits were rebuilt
from the combined Slang sources, retaining the persistent TLAS node base.
Typecheck, 234 unit tests, library/game/viewer builds, all 21 default-wavefront smoke cases,
and the complete game smoke passed. Host GPU checks explicitly assert the wavefront default;
pixel updates, alpha changes, empty-scene transitions and no cross-frame accumulation passed.
Game and static-render screenshots were inspected. The unrelated Blender fixture suite remains
skipped for missing sample fixtures.
