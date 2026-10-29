# Veach

A physically based path tracer for the web: **WebGPU** compute, **tinybvh** (compiled to WebAssembly) for BVH construction, and BVH traversal / shading written in **Slang** and compiled to WGSL. Renders glTF 2.0 assets.

## Features

- Persistent engine-independent host scenes with resource handles, batched updates, shared BLAS
  and incremental GPU uploads; optional Three.js adapter and single-frame rendering

- Megakernel unidirectional path tracer with multiple importance sampling between BSDF sampling and next event estimation (environment map, emissive triangles, analytic sun)
- Disney principled BSDF (diffuse, retro-reflection, sheen, specular, clearcoat, rough and smooth glass), alpha mask / stochastic blend, Russian roulette
- Two-level acceleration structure: one tinybvh BLAS per mesh (SBVH by default) and a TLAS over instances, traversed by a hand-written stack traversal in Slang
- glTF 2.0 (`.gltf` / `.glb`): node hierarchy, all accessor types (normalized, sparse), triangle strips / fans, cameras, PBR metallic-roughness, `KHR_materials_emissive_strength`, `_ior`, `_transmission`, `_clearcoat`, `_specular`, `_sheen`, `_anisotropy`, `_unlit`, `KHR_texture_transform`, `KHR_mesh_quantization`
- Equirectangular `.hdr` environments with importance sampling, or a procedural sky + sun
- Streaming virtual textures with GPU feedback (no bindless in WebGPU): ray-cone mip selection, page requests from every texture sample at a ray hit, asynchronous readback, budgeted uploads into a shared page cache with LRU eviction
- [ACES 2.0](https://github.com/aces-aswf/aces-core) Output Transform (SDR 100 nit sRGB), ported from the reference CTL, validated against OpenColorIO and applied as a PQ-shaped 64³ 3D LUT (after Unreal's combine-LUT pass); the ACES 1.x filmic fit remains as an option
- Progressive accumulation, exposure, debug views (albedo, normals, UV, instance, material, traversal cost, emission, virtual texture mip)
- OIDN WebGPU HDR denoising with albedo/normal guides, enabled by default after 128 samples; the default model is included and loaded separately
- Ten built-in display LUTs plus external 3D `.cube` / float32 LUTs, with explicit color-space metadata; ACES2 remains the default display transform

Wavefront is the default integrator, with adaptive GPU queues and scene-specialized material
programs. Use `renderer.setIntegrator('megakernel')` or the demo URL parameter
`integrator=megakernel` to select the reference renderer.

## Quick start

```sh
npm install
npm run fetch-samples   # optional: Khronos sample models + an HDR into public/samples
npm run dev
```

Open the printed URL in a WebGPU-capable browser (Chrome / Edge 113+). Drop a `.glb`, a `.gltf` together with its files, or an `.hdr` onto the page, or use URL parameters:

```
http://localhost:5173/?model=/samples/DamagedHelmet.glb&env=/samples/studio_small_09_1k.hdr
```

Other parameters: `spp=<n>` stops after n samples, `debug=<0..9>` selects a debug view, `tonemap=<0..2>` selects None / ACES filmic fit / ACES 2.0. Keys: `0`–`9` debug view, `[` / `]` exposure, `B` / `N` bounces, `T` cycle tonemapper, `E` environment visibility, `S` sun, `F` frame scene, `H` help.

## npm package

### Three.js game examples

```sh
npm run dev:games
```

Open `http://127.0.0.1:5176/?game=aim` for a 45-second mouse aim drill or
`http://127.0.0.1:5176/?game=race` for a three-lap keyboard racing game (W/S, A/D, R reset).
Both use procedural geometry, Three.js simulation and Veach rendering.
Press `~` for the [rendering console](docs/Console.md): `r.SHARC.Enabled 0`,
`r.PathTracing.MaxBounces 4`, `r.Exposure.Bias 1`, `help`; Tab completes commands.
The console pauses game time while leaving the rendered view live.
Press **Ctrl + Shift + ,** for a single-frame [GPU timing breakdown](docs/GPUProfiling.md),
including per-bounce costs and a hotspot list (requires optional WebGPU timestamp queries).
Performance/Balanced/Quality select resolution only; real-time rendering is always 1 spp. The games
default to TAA without progressive cross-frame accumulation; OIDN is disabled. Use
`r.TAA.Enabled 0` / `1` to compare, or `r.TAA.Stats` for history status.
`npm run smoke:games` verifies GPU updates and
game interactions. See [host integration](docs/HostIntegration.md) for the supported subset.

### Install

```sh
npm install @tianyuliwiwo/veach
```

The package is ES modules with TypeScript declarations; shaders, the tinybvh wasm and the BSDF tables are inlined, so it needs no asset configuration in any bundler. `@tianyuliwiwo/veach` is the renderer and loaders (no DOM side effects, imports in Node); `@tianyuliwiwo/veach/view` adds the `<veach-view>` custom element. `@tianyuliwiwo/veach/three` adds `ThreeAdapter`, with Three.js r186 as an optional peer dependency.

See the [public API guide](docs/PublicAPI.md) for custom canvas integration, application-owned
scene loading, environment switching, component embedding and resource cleanup.

Release packages contain the optimized JavaScript entries, generated TypeScript declarations,
public API guide, license notices, README and package metadata. WGSL, tinybvh WASM and BSDF tables are embedded in
the JavaScript. The development viewer's `.blend` dependency `fzstd` is not installed by consumers
of the current public entries. Source maps, original
TypeScript / Slang / C++ sources, tests, samples and build tools are excluded. Type declarations
preserve editor completion; `@webgpu/types` supplies their WebGPU API types. Compiled JavaScript
and WGSL remain readable; this packaging does not encrypt or hide the runtime implementation.

### `<veach-view>`

```html
<script type="module">
	import '@tianyuliwiwo/veach/view'; // registers <veach-view>
</script>

<veach-view model="/model.glb" environment="/env.hdr" show-stats droppable style="height: 600px"></veach-view>
```

```ts
import '@tianyuliwiwo/veach/view';
import { Tonemapper } from '@tianyuliwiwo/veach';

const view = document.querySelector('veach-view')!;
view.settings = { maxBounces: 8, maxSamples: 1024, tonemapper: Tonemapper.ACES2 }; // partial RenderSettings
view.sun = { elevation: 30 };
view.addEventListener('veach-load', (e) => console.log(e.detail.triangles));
view.addEventListener('veach-error', (e) => {
	e.preventDefault(); // handled here (otherwise logged)
	showMessage(e.detail.message);
});
```

Until the shaders have compiled (seconds on a first visit, cached by the browser afterwards) and the first scene has loaded, the view shows a progress bar; a model URL given up front is fetched while the shaders compile.

- Attributes: `model` / `environment` (URLs; no environment = procedural sky + sun), `show-stats`, `paused`, `droppable` (loads dropped `.glb` / `.gltf` + files / `.hdr`), and `controls`, `use-scene-camera`, `progress` (on unless `="false"`).
- Properties: the same, plus `model` / `environment` as a loaded `SceneDesc` / `HDRImage`, `settings`, `sun`, `progress` (a function for custom content), `fallback` (content without WebGPU) and the read-only `renderer`. Methods: `frameScene()`, `resetAccumulation()`.
- Events (`CustomEvent`): `veach-ready` (renderer), `veach-progress` (`InitProgress`), `veach-load` (`SceneStats`), `veach-loadingchange`, `veach-stats` (every frame), `veach-drop`, `veach-error`.
- Styling: 360 px high by default (size it with CSS); `::part(canvas | stats | progress | dropzone | fallback)`; children are overlays on top of the canvas.
- `attachFileDrop(element, handlers)` / `loadDroppedFiles(files)` provide the drag & drop loading for other drop targets; `defineVeachView(tag)` registers under another tag name.

Each view owns its own WebGPU device.

### Renderer

```ts
import { Renderer, loadGLTF, loadHDR, OrbitController } from '@tianyuliwiwo/veach';

const renderer = await Renderer.create(canvas, { onProgress: (p) => console.log(p.message, p.progress) });
new OrbitController(renderer.camera, canvas, () => renderer.resetAccumulation());
await renderer.setScene(await loadGLTF('/model.glb'));
renderer.setEnvironment(await loadHDR('/env.hdr'));
renderer.start();
```

`Renderer.create` compiles every pipeline asynchronously and resolves once they are ready.
The default sample limit is 128, with OIDN enabled. Its bundled HDR model loads asynchronously
alongside rendering; no model URL is required. Use `Renderer.create(canvas, { denoiser: null })`
to disable denoising and its downloads, or `renderer.settings.maxSamples = 0` for unlimited sampling.
`renderer.setDisplayTransform({ type: 'builtin', preset: 'astia' })` selects a bundled LUT;
passing `null` restores the default tone mapper. See the public API guide for external LUTs,
denoising progress, custom models and GPU guiding-buffer access.

### Development

- `npm run dev:view`: demo app in `examples/view` (http://localhost:5174)
- `npm run build:view` then `npm run preview:view`: production build of the demo (http://localhost:4174)
- `npm run build:lib`: ES modules and type declarations in `dist-lib/` (also run by `npm pack` / `npm publish`)

## Layout

| Path | Contents |
|---|---|
| `shaders/` | Slang sources: `Common/`, `Scene/` (GPU struct layout and bindings), `RayTracing/Traversal.slang`, `Materials/`, `Lights/`, `Passes/` |
| `src/accel/` | TypeScript wrapper over the tinybvh WASM module |
| `src/loaders/` | glTF and HDR loaders |
| `src/render/` | WebGPU host: scene flattening, virtual textures (`vt/`), ACES 2.0 + tone LUT (`aces/`, ported from aces-core, Apache-2.0, Copyright Contributors to the ACES Project), environment, pipelines, renderer, camera |
| `src/generated/` | Committed build outputs: WGSL from Slang, tinybvh `.mjs` + `.wasm` |
| `wasm/` | C ABI over tinybvh compiled with Emscripten |
| `ThirdParty/tinybvh/` | Vendored tinybvh headers |
| `scripts/` | Shader / WASM builds, sample download, headless smoke test |
| `tests/` | vitest: BVH layout vs. brute force, loaders, environment CDF, virtual textures, ACES 2.0 vs. OpenColorIO (`python scripts/aces2-reference.py` regenerates the fixture) |

## Rebuilding generated code

Generated WGSL and WASM are committed, so `npm run dev` works without extra toolchains.

- `npm run build:shaders`: compiles `shaders/` with `slangc` (from `$SLANGC`, `.tools/slang`, or `PATH`; downloaded into `.tools/slang` if missing).
- `npm run build:wasm`: compiles `wasm/tinybvh_wasm.cpp` with Emscripten (`$EMSDK` or `.tools/emsdk`). Pass `-- --debug` for a build with symbols and assertions in `.tools/tinybvh-debug`.

## Testing

```sh
npm test            # unit tests (Node)
npm run typecheck
npm run smoke       # headless Chrome WebGPU renders -> .tools/smoke/*.png
```

## License

Veach's original code is available under the [MIT License](LICENSE), allowing commercial
use, modification and redistribution subject to its copyright and license notice requirements.
Third-party components and derived portions retain their own licenses; see
[Third-party notices](THIRD_PARTY_NOTICES.md) and the full texts in `licenses/`.
These notices ship with the npm package alongside the compiled runtime and public API.
