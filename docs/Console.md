# Runtime rendering console

The viewer and both game examples mount a rendering console. Press the physical backquote
key (`~` / `` ` ``) to cycle **closed → compact → expanded → closed**; Escape closes directly.
Enter executes, Tab / Shift+Tab cycles matching commands or enum values, and Up/Down recalls
history while preserving the unfinished input. The last 100 commands persist locally;
parameter values are session-only. Opening the console releases pointer lock and captures
game input. In the games, simulation and session time pause while rendering continues;
closing restores the previous playing/paused state and clears held keys.

## Commands

Names and enum labels are case-insensitive. Query with a bare name, set with a space or `=`,
and append `?` for help. `help`, `list [filter]`, `find [filter]` and `clear` are built in.
No JavaScript, shell execution or automatic execution of saved history is supported.

```text
r.PathTracing.MaxBounces
r.PathTracing.MaxBounces 4
r.PathTracing.SamplesPerFrame 1
r.Resolution.Scale 0.5
r.Renderer.Integrator wavefront
r.PrimaryVisibility.Mode ray-traced
r.PrimaryVisibility.Mode auto
r.SHARC.Enabled 0
r.SHARC.Enabled 1
r.SHARC.VoxelSize 0.2
r.SHARC.Stats
r.Accumulation.Enabled 0
r.TAA.Enabled 1
r.TAA.NewFrameWeight 0.1
r.TAA.ColorClampingFactor 2
r.TAA.Stats
r.ProfileGPU.Capture
r.ProfileGPU.Stats
r.TAA.MotionVectors 1
r.TAA.MotionVectors 0
r.Exposure.Method Manual
r.Exposure.Bias 1
r.LocalExposure.Method None
r.Tonemapper.Mode ACES2
r.Sun.Elevation 60
r.Debug.Mode Traversal
r.Debug.Mode None
r.Camera.FOV 70
r.Wavefront.BatchedShadows 1
list SHARC
r.SHARC.Capacity ?
```

Ctrl+Shift+Comma opens the [GPU profiler](GPUProfiling.md) and captures a single frame.
It displays real GPU timestamp timings when supported; it does not reset rendering history.

All `RenderSettings` fields have an explicit binding in `src/debug/RendererConsole.ts`;
the descriptor table is checked against `keyof RenderSettings`. Groups include PathTracing,
Resolution, Debug, Exposure, LocalExposure, Tonemapper, Environment, BVH and Texture.
Additional bindings cover the public integrator, primary visibility, SHARC settings and
reset/statistics commands, separate light evaluation, batched shadows, OIDN, display LUTs,
sun controls, camera projection, the accumulation switch and TAA enable/weight/clamping/
radiance/reset/statistics.
TAA defaults on when progressive accumulation is off; host games always use independent frames.
`r.TAA.MotionVectors` visualizes active TAA's motion without resetting history: gray is zero,
red/green encode signed X/Y (positive right/down, saturation at ±32 render pixels), and magenta
means no previous projection. It bypasses exposure/tone mapping; disable it to restore color.
Actual GPU state and fallback reasons can be queried
with `r.SHARC.Stats`, `r.PrimaryVisibility.Stats` and `r.TAA.Stats` rather than inferred from requested values.

Booleans accept 0/1, false/true and off/on. Enums accept names or their numeric values.
Colors accept `R G B` or `[R,G,B]`. Curves accept `null` or JSON `[[EV,value],...]` with
strictly ascending EV. Invalid types, nonfinite values and invalid paired exposure ranges
are rejected before modifying settings. Commands run serially; async compilation errors
are printed and do not stop later commands. Queries always read current renderer values.

Exposure, local exposure, tone mapping and LUT changes preserve accumulation. Transport
changes reset it through existing renderer APIs. BVH quality applies on the next static
scene build and does not rebuild a loaded scene or override a host's build options. OIDN
only processes converged static scenes, not game host frames. Host games bind FOV to their
Three.js camera and omit renderer-owned lens/focus controls, which cannot affect host rays.
SHARC's existing whole-cache invalidation on scene changes still applies to moving targets.

## Embedding and architecture

```ts
import { createRendererConsole } from '@tianyuliwiwo/veach';
import { DebugConsole } from '@tianyuliwiwo/veach/view';

const commands = createRendererConsole(renderer);
const overlay = new DebugConsole(commands);
await commands.execute('r.Exposure.Bias 1');
// During teardown:
overlay.dispose();
```

`ConsoleRegistry` and renderer bindings are DOM-free; `DebugConsole` is explicitly mounted
from the view entry. The UI uses an isolated shadow root, bounded output/history, text-only
command output, IME-aware keyboard handling, and removable capture listeners. The registry
accepts an executor wrapper for hosts that need to suspend rendering around mutations.
The game wrapper waits for the current ThreeAdapter synchronization and prevents new scene
sync/render submissions until the command finishes. Its FOV callbacks update the host
camera. The main viewer stops its owned loop during commands and then resumes it.

Interaction reference was the local Unreal checkout's
`Engine/Source/Runtime/Core/Private/HAL/ConsoleManager.cpp` (`ProcessUserConsoleInput`) and
`Engine/Source/Runtime/Engine/Private/UserInterface/Console.cpp` (console states, completion
and history). This is an independent TypeScript implementation; no Unreal source is copied.

## Local game deployment

`npm run build:games` creates `dist-games`. Serve it with
`npm run preview:games -- --host 127.0.0.1 --port 4177 --strictPort`, then open
`http://127.0.0.1:4177/?game=aim`. Loopback is suitable for WebGPU's secure-context requirement.
The existing development command remains `npm run dev:games` (port 5176).
`node scripts/console-smoke.mjs` checks this production preview's console and aim input;
`CONSOLE_TEST_URL` can override the URL. It does not run the full game/performance suites.

Iteration verification: production game build (including typecheck), four focused console
unit checks, and one aim-page check passed. The game exposes 58 commands. The page check
changed bounce count, exposure, host FOV, SHARC and primary visibility, rejected NaN,
checked completion/history and console expansion, confirmed paused simulation with ongoing
rendering, then resumed and hit a target. No WebGPU/browser errors were recorded. Captures
and a report are in `.tools/console/`; the full game and performance suites were not run.
