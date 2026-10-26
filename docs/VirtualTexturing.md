# Virtual texturing

There is no bindless: every texture is a streaming virtual texture, after Unreal SVT
(`src/render/vt`, `shaders/Materials/VirtualTexture.slang`).

## Layout

- Textures are resampled to power-of-two sizes and split into 128-texel pages with a 4-texel
  border (136² tiles) in one `rgba8unorm` physical cache.
- The `r32uint` page table has one entry per virtual page of every mip (linear index =
  `pageTableOffset` + level offset + row-major page). Each entry always points at the finest
  resident ancestor (`VALID | level << 16 | tile`), so the shader does a single lookup.
- The mip tail (one page) is pinned.
- `TextureRef` packs wrap modes, levels and log2 size into `flags`; sRGB decoding happens in the
  shader.

## Sampling and feedback

- Mip selection uses ray cones (`gRayCone` for traversal-time alpha tests).
- Every sample reservoir-samples a page request; one jittered pixel per 4x4 tile writes
  `index + 1` to the feedback texture.
- The host reads the feedback back asynchronously and turns it into time-budgeted uploads
  (8 ms/frame) with LRU eviction.
- LRU ages advance only when feedback arrives. Requested pages are protected for a full
  16-frame feedback jitter cycle; speculative pages remain immediately evictable.

## Cache and streaming

- The cache is sized to the scene's virtual page count (16x16 to 40x40 pages).
- Coarse mips are prefetched at load; leftover budget speculatively fills free tiles coarse to
  fine (never evicting).
- Accumulation resets only when newly requested pages cover enough of the feedback
  (`streamingResetCoverage`, scaled by spp / 32) and a full 16-frame feedback cycle has no
  uploads or pending requests; smaller updates blend in. Low-spp accumulation also waits
  for this quiet cycle. At the sample limit, outstanding readbacks are drained instead,
  since tracing no longer produces new feedback.
- `pendingRequests = 0` means the latest feedback batch was serviced, not that streaming
  has settled. A working set larger than the cache can keep uploading and evicting with
  pending zero. During this churn, keep accumulating instead of resetting every frame or
  on a timeout; texture updates blend into the running average without reducing mip detail.

To reproduce cache-pressure accumulation with a local asset, run
`npm run smoke -- custom-model --model "path/to/model.glb"`. This renders at 1793x1100
and checks that accumulation passes 128 spp even if streaming continues; its screenshot
is saved to `.tools/smoke/custom-model.png`. Omit `custom-model` to also run the standard suite.
