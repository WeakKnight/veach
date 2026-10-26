# Veach public API

Veach has two supported JavaScript entry points. These exports and their generated TypeScript
declarations are shipped in the release package. Applications should not import `src/`,
`dist-lib/types/` or other implementation paths.

| Import | Purpose |
| --- | --- |
| `@tianyuliwiwo/veach` | Renderer, scene loaders, scene data types, camera, settings and advanced utilities |
| `@tianyuliwiwo/veach/view` | `<veach-view>`, typed component events and drag-and-drop helpers |

The core entry can be imported without a DOM in Node / SSR. Creating a renderer requires a
browser with WebGPU and an HTML canvas. Import `@tianyuliwiwo/veach/view` only in the browser: it registers
the custom element. JavaScript applications use the same API; TypeScript adds completion and
type checking without requiring the original sources.

## Embed in your own canvas

```ts
import { Renderer, OrbitController, loadGLTF, loadHDR } from '@tianyuliwiwo/veach';

const canvas = document.createElement('canvas');
canvas.style.cssText = 'width:100%;height:480px;display:block';
document.querySelector('#viewer')!.append(canvas);

const renderer = await Renderer.create(canvas, {
	onProgress: ({ progress, message }) => console.log(progress, message),
});
const controls = new OrbitController(renderer.camera, canvas, () => renderer.resetAccumulation());

await renderer.setScene(await loadGLTF('/models/scene.glb'));
renderer.setEnvironment(await loadHDR('/environments/studio.hdr'));
renderer.sun.enabled = false; // HDR environments normally include their own lighting.
renderer.start();

// Call when unmounting your viewer.
function dispose() {
	controls.dispose();
	renderer.destroy();
	canvas.remove();
}
```

`Renderer.create` resolves after initialization and shader compilation. `setScene` resolves
after uploading the scene and returns `SceneStats`. Call `setScene` again to replace it; await
one scene change before starting the next. The renderer observes canvas size changes.

## Own the scene-loading workflow

| API | Input / result |
| --- | --- |
| `loadGLTF(url, options?)` | Fetch `.glb` / `.gltf` and return `Promise<SceneDesc>` |
| `parseGLTF(buffer, options?)` | Parse an `ArrayBuffer`; use `options.resolveUri` for external resources |
| `loadGLTFFromFiles(main, files, options?)` | Load browser `File` objects, including external buffers and images |
| `renderer.setScene(scene, options?)` | Upload any compatible `SceneDesc`; options: `frameCamera`, `useSceneCamera` |
| `renderer.frameScene()` | Frame the current scene bounds |

For custom authentication, caching or downloads, fetch the bytes yourself:

```ts
import { parseGLTF, type SceneDesc } from '@tianyuliwiwo/veach';

const response = await fetch('/models/scene.glb');
if (!response.ok) throw new Error(`Model request failed: ${response.status}`);
const scene: SceneDesc = await parseGLTF(await response.arrayBuffer());
await renderer.setScene(scene, { useSceneCamera: false });
```

Applications can also construct `SceneDesc` directly using `MeshDesc`, `InstanceDesc`,
`MaterialDesc`, `TextureSource`, `CameraDesc` and `LightDesc`. Geometry uses typed arrays;
instances supply mesh indices and transforms. A mesh material index of `-1` uses the default
material. For custom materials, the `MaterialDesc.graph` is the shading representation;
changing legacy scalar material fields alone does not rebuild that graph.

The standalone development viewer also imports `.blend` files. Its Blender loader is currently
an internal module, not an export of `@tianyuliwiwo/veach`; the public loaders listed above are glTF and HDR.

## Switch environment maps

```ts
import { loadHDR, parseHDR, type HDRImage } from '@tianyuliwiwo/veach';

// Replace the environment at any time.
renderer.setEnvironment(await loadHDR('/environments/outdoor.hdr'));
renderer.sun.enabled = false;

// Or supply decoded HDR data from your own download / cache.
const response = await fetch('/environments/studio.hdr');
if (!response.ok) throw new Error(`HDR request failed: ${response.status}`);
const image: HDRImage = parseHDR(await response.arrayBuffer());
renderer.setEnvironment(image);

// Return to the procedural sky and sun.
renderer.setEnvironment(null);
renderer.sun.enabled = true;
renderer.resetAccumulation();
```

`HDRImage` contains `width`, `height` and linear RGBA `Float32Array` data.
`setEnvironment` replaces the GPU environment and resets accumulation automatically. The core
renderer leaves `sun.enabled` under application control; the component manages its default
automatically. Rotation and strength are `renderer.settings.environmentRotation` (degrees)
and `environmentIntensity`.

## Settings, camera and lifecycle

| API | Behavior |
| --- | --- |
| `renderer.settings` / `RenderSettings` | Render quality, exposure, tone mapping and environment controls |
| `renderer.sun` / `SunSettings` | Procedural sky / analytic sun controls |
| `renderer.camera` / `Camera` | Position, target, field of view and lens controls |
| `renderer.start()` / `stop()` | Start / pause the owned animation loop |
| `renderer.renderFrame()` | Render from an application-owned loop; do not also call `start()` |
| `renderer.resetAccumulation()` | Restart progressive sampling after manual camera / lighting changes |
| `renderer.onStats` | Frame statistics callback for the owned loop |
| `renderer.readRadiance()` | Read scene-linear RGB pixels and sample count |
| `renderer.destroy()` | Stop rendering and release renderer-owned GPU resources |
| `OrbitController.dispose()` | Detach input listeners |

The core settings and camera are mutable. After changing settings that affect sampling or
lighting, call `resetAccumulation()`. Exposure and tone mapping only affect presentation and
must not reset it. `isPresentationSetting(key)` classifies settings; the component's `settings`
setter handles this distinction automatically. Changing `bvhQuality` requires loading the
scene again to rebuild its acceleration structure.

## Embed the component

```ts
import '@tianyuliwiwo/veach/view';
import { loadGLTF, loadHDR, Tonemapper } from '@tianyuliwiwo/veach';

const view = document.createElement('veach-view');
view.style.height = '480px';
view.addEventListener('veach-ready', event => console.log(event.detail));
view.addEventListener('veach-load', event => console.log(event.detail.triangles));
view.addEventListener('veach-error', event => {
	event.preventDefault();
	console.error(event.detail);
});
document.querySelector('#viewer')!.append(view);

// URLs are fetched by the component.
view.model = '/models/scene.glb';
view.environment = '/environments/studio.hdr';
view.settings = { maxSamples: 1024, tonemapper: Tonemapper.ACES2 };

// Or hand it data loaded by your application.
view.model = await loadGLTF('/models/other.glb');
view.environment = await loadHDR('/environments/outdoor.hdr');
view.environment = null; // procedural sky

// Remove on unmount; the component releases its renderer when disconnected.
// view.remove();
```

Other properties include `paused`, `controls`, `showStats`, `droppable`, `sun`, `progress`,
`fallback` and `useSceneCamera`. `view.renderer` is `null` until initialization completes.
Assigning `model` starts an asynchronous load; observe `veach-load` / `veach-error` for results.
Events are typed through `VeachViewEventMap`: `veach-ready`, `veach-load`, `veach-loadingchange`,
`veach-progress`, `veach-stats`, `veach-drop` and `veach-error`.

`defineVeachView(tag)` registers a custom tag. `attachFileDrop(element, handlers)` and
`loadDroppedFiles(files)` allow an application to provide its own drop surface.

## Extending the API

`src/index.ts` and `src/view/index.ts` are the explicit public export lists. Existing advanced
exports (BVH helpers, vector/matrix helpers, ACES and tone-LUT utilities) remain available.
Add future supported functions and types at these entry points, document their lifecycle and
data contracts here, and verify them against an installed release package. Source layout
changes alone must not require consumers to change imports. Intentionally incompatible public
API changes require a documented version change.
