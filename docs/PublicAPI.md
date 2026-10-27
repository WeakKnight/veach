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
after uploading the scene and preparing any required material pipeline variant, and returns
`SceneStats`. Variants are cached per renderer. Call `setScene` again to replace it; await
one scene change before starting the next. The renderer observes canvas size changes.

For experimental GPU A/B comparisons, `await renderer.setIntegrator('wavefront')` lazily
compiles the staged path tracer and resets accumulation. Use `'megakernel'` to return to
the default reference. `renderer.integrator` reports the selected mode. Await each switch
before another; diagnostic views currently use the reference kernel in either mode.

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
| `renderer.readRadiance({ denoised?: boolean })` | Read scene-linear RGB pixels; original by default, current denoised presentation source when requested |
| `renderer.setDenoiser(options \| null)` | Load HDR OIDN and enable automatic denoising at maxSamples; null disables it |
| `renderer.denoising` | Immutable loading / progress / ready / error state, also in RendererStats |
| `renderer.createDenoisingInputs()` | Create caller-owned GPU color/albedo/normal snapshots; call destroy() after use |
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

## Custom display transforms and built-in LUTs

No configuration is required for the existing ACES2 default. The ten bundled looks are listed in
`BUILTIN_LUTS` (immutable `{ id, name }` entries); bytes load only when selected.

```ts
import { BUILTIN_LUTS, parseCubeLUT, parseLUT3D } from '@tianyuliwiwo/veach';

await renderer.setDisplayTransform({ type: 'builtin', preset: 'astia' });
await renderer.setDisplayTransform(null); // restore settings.tonemapper (default ACES2)

const response = await fetch('/looks/my-look.cube');
if (!response.ok) throw new Error(`LUT download failed: ${response.status}`);
const lut = parseCubeLUT(await response.text());
await renderer.setDisplayTransform({
	type: 'lut', lut,
	input: { primaries: 'rec2020', transfer: 'f-log2' },
	output: { primaries: 'rec709', transfer: { type: 'gamma', exponent: 2.2 } },
	interpolation: 'trilinear', outOfDomain: 'clamp', localExposure: 'off',
});
```

Input/output metadata must describe the actual LUT; `.cube` domains do not identify a color space.
The example matches the bundled light-lab LUTs. `parseLUT3D(buffer, { format: 'float32-le', size: 33,
layout: 'rgb-r-fastest', domainMin: [0,0,0], domainMax: [1,1,1] })` reads their headerless binary format.
The binary domains default to [0,1]. Direct `LUT3D` data uses Float32 RGB triplets with red varying
fastest. Sizes 2..128 are accepted; finite values and valid per-axis domains are required. Negative
and HDR output values are preserved until display handling. `.cube` supports `LUT_3D_SIZE`, `TITLE`,
`DOMAIN_MIN/MAX` and comments; 1D/shaper/range directives are rejected explicitly. Input is bounded
to the declared domain at lookup; no extrapolation or full/video-range conversion is implicit.

Primaries: `rec709` / `rec2020`, both D65. Input transfer: `linear`, `srgb`, `f-log2`, or
`{ type: 'gamma', exponent }`. Output transfer: linear/sRGB/gamma. Gamma encoding means
code = linear^(1/exponent), decoding means linear = max(code,0)^exponent. This is an SDR display
transform replacing the built-in tone mapper, not a second look after ACES. F-Gamut/F-Log2 input
uses Rec.2020 primaries and F-Log2 transfer. The built-in gamma-2.2 output is a viewing assumption
from light-lab, not inferred from BT.709 primaries.

`setDisplayTransform()` returns `{ applied, type, preset?, localExposure }`; superseded requests
return `applied: false`. `renderer.displayTransform` exposes the immutable active state. Invalid
data or a failed upload rejects without replacing the active transform. Caller arrays are copied.
Only a successful change affects subsequent presentation; accumulation and `readRadiance()` remain
unchanged. `null` restores saved local exposure as well as the selected built-in tone mapper.
Local exposure is disabled while any LUT is active; optional calibration is not yet supported.
Auto exposure remains controlled by `renderer.settings`; use Manual for reproducible comparisons.

`loadBuiltinLUT(id)` returns an independent `LUTDisplayTransform` descriptor for inspection or CPU
evaluation. `evaluateDisplayTransform(desc, rgb)` evaluates exposed scene-linear Rec.709 into
display-linear Rec.709 (before final clip/sRGB encode). `sampleLUT3D(lut, encoded)` samples encoded
LUT coordinates, unlike the legacy ACES-specific `sampleToneLUT` and `ToneLUT` helpers.

For the custom element, assign `view.displayTransform` before or after connection; failures emit
`veach-error`. After `veach-ready`, `await view.setDisplayTransform(desc)` confirms application.
Successful changes emit `veach-displaychange`. Initial LUT loading may finish after `veach-ready`.

## OIDN at the sample limit

```ts
renderer.settings.maxSamples = 128;
await renderer.setDenoiser({
  type: 'oidn',
  // weights: '/weights/rt_hdr_alb_nrm.tza', // optional override; URL or ArrayBuffer
  maxTileSize: 256,                     // optional; 32..512, multiple of 16
  precision: 'auto',                    // auto / fp16 / fp32
});
renderer.start();
// renderer.denoising: { status, progress, samples, durationMs?, error? }
// renderer.onStats also receives stats.denoising.

const original = await renderer.readRadiance();
const displayedHDR = await renderer.readRadiance({ denoised: true });
await renderer.setDenoiser(null); // raw presentation; keep accumulated samples
```

New renderers default to **128 samples and OIDN enabled**. `Renderer.create(canvas)` loads the
bundled HDR model asynchronously alongside rendering; no configuration is required. The example
above is only needed to change the defaults. To start without OIDN or its downloads, use
`Renderer.create(canvas, { denoiser: null })`. `setDenoiser({ type: 'oidn' })` re-enables it.
Inference code and bundled model data are separate lazy chunks. To override the model, host the
upstream HDR **noisy albedo + normal** model (`rt_hdr_alb_nrm.tza` or its `_small` variant)
with your app, retaining its Apache-2.0 license. Do not use clean-guide,
LDR or lightmap-log models with this adapter. `setDenoiser` resolves `true` when applied, `false`
when superseded/disposed, and rejects load/configuration errors.

While enabled, one denoise runs when beauty reaches a positive `maxSamples` and texture streaming
settles. `maxSamples = 0` is unlimited and never triggers. Keep `start()` running or continue
calling `renderFrame()` while feedback drains. Resetting accumulation or resuming sampling
invalidates old work; an obsolete in-flight result cannot overwrite a new image. Exposure and
display LUT changes reuse the denoised HDR. A failure keeps the raw image and records an error;
there is no automatic per-frame retry. Call `setDenoiser` again to reload/retry.

For other GPU consumers, `renderer.createDenoisingInputs()` returns caller-owned snapshots:
`{ width, height, samples, preExposure, color, albedo, normal, destroy() }`. All three buffers
are tightly packed RGBA float32, top row first, with STORAGE/COPY_SRC usage on `renderer.device`.
Color is scene-linear Rec.709 multiplied by `preExposure`, albedo is linear [0,1], and normals are
averaged world-space shading normals encoded `n * 0.5 + 0.5`. No display transform is included.
Do not renormalize these averaged normals; background is encoded (0.5,0.5,0.5). Snapshots require
a live beauty accumulation with at least one sample. Call `destroy()` when GPU consumers finish.
These are primary-hit guides, not reflection/transmission-aware guides. The original
accumulation is always retained; `readRadiance({ denoised: true })` falls back to it until ready.

For `<veach-view>`, set `view.denoiser` before connecting or call `await view.setDenoiser(options)`
after `veach-ready`. Initial loading may finish after `veach-ready`; errors use `veach-error`,
and `veach-stats` includes the denoising state.

## Extending the API

`src/index.ts` and `src/view/index.ts` are the explicit public export lists. Existing advanced
exports (BVH helpers, vector/matrix helpers, ACES and tone-LUT utilities) remain available.
Add future supported functions and types at these entry points, document their lifecycle and
data contracts here, and verify them against an installed release package. Source layout
changes alone must not require consumers to change imports. Intentionally incompatible public
API changes require a documented version change.
