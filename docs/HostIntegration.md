# Host renderer integration

Implementation target: a host owns its scene graph, simulation and source assets. Veach owns
only render resources, flat instances and GPU-derived data. The first host is Three.js; the
core package must neither import Three.js nor depend on its object model.

## Contract

- Scene-scoped, typed handles remain stable across updates. Resources are persistent, not
  re-created every frame or deduplicated by hashing their contents.
- A batch creates, updates and releases geometries, textures, materials, lights and instances.
  References are validated against the final batch. Only one batch per scene is active.
  Failed preparation leaves the last committed CPU scene intact. GPU publication must match.
- Source data is application-owned. Small values are snapshotted; array data is snapshotted
  for a commit before asynchronous preparation. Veach never disposes host objects/images.
- Geometry is independent of material. Instances bind material slots and world transforms.
- New host rendering is single-frame path tracing: samples within a frame may be averaged,
  but radiance from previous frames is never accumulated. TAA and NRD are future consumers.
  Their eventual histories advance on rendered frames, not on scene commits.
- Existing loader/viewer exports remain supported. Host integration uses an explicit render
  path so existing static-render regression fixtures can continue to compare the old API.

## GPU plan

Retain the seven scene storage bindings. Allocate persistent buffer regions and fixed instance
slots; merge writes to dirty regions. Keep unchanged BLAS data. Initially rebuild only changed
geometries and rebuild the TLAS when instance bounds/membership change. A camera/material-only
change does not rebuild acceleration structures. Refit is not required in the first version;
the current high-quality spatial-split BVHs are not refittable.

Keep material compilation, instance alpha/emission flags, emissive triangle records and light
CDF changes consistent in the same publication. Keep texture registration and streaming state
across transform-only commits. Handle texture revisions and stale asynchronous uploads.

## Adapter plan

Track host object identity to handles. Inspect each unique resource once per sync. Geometry
changes use attribute identity/version/layout plus groups/draw ranges. Material changes use
snapshots of supported values and texture references, not only Material.version. Texture
changes distinguish source data from UV/sampling state. Unsupported skinning, morph targets,
custom shader deformation and GPU-only textures must produce actionable diagnostics.

## Acceptance

- CPU tests: transactional references, rollback, ownership, shared resources, updates/releases.
- GPU tests: transform-only commits preserve BLAS and geometry uploads; topology changes rebuild
  only affected BLAS; material/texture changes render correctly; no stale handles or GPU errors.
- Three.js tests: shared objects, attribute versions/replacement, scalar material changes,
  texture versions/UV transforms, removal and disposal.
- Two playable simple-geometry demos: aim trainer and racing, both rendered by Veach, with
  input, scoring/progression, restart and teardown. Exercise resource creation, sharing,
  movement, parameter edits, geometry/texture updates and removal.
- Typecheck, unit suite, library and examples builds, generated shaders as applicable,
  existing smoke suite, dedicated browser interaction checks and screenshot inspection.

## Work log

- Isolated worktree created from `595ff67`, branch `codex/host-renderer-games`.
- Original checkout contains concurrent Wavefront work and is not modified by this task.
- Three.js development dependencies installed in this worktree only.
- Added CPU `RenderScene` / `SceneUpdate` foundation with typed scene-scoped handles,
  persistent resource maps, snapshots, final-reference validation, serialized commits,
  rollback on sink failure, explicit cancellation and disposal. Not exported publicly yet;
  the GPU sink and adapter are still pending.
- Baseline: 193 tests passed, 6 skipped (sample-dependent or explicitly skipped cases).
  New scene tests: 9 passed. Typecheck passed after adding the foundation.
- Next: persistent GPU buffer regions and BLAS caching, scene-to-material conversion and
  renderer commit sink, single-frame rendering path, Three adapter and package entry,
  demos, GPU/browser validation, public documentation and final review.
- Implementation and verification are in progress; the contract above is the target, not a
  claim that all features are already implemented.
