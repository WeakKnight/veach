# GPU timing and scoped captures

The viewer and game examples mount `GpuProfilerPanel`. Press **Ctrl + Shift + Comma**
once to capture the next rendered frame and open the timing panel. Repeating/holding the
key does not enqueue captures. The panel freezes the results, not rendering. Use Recapture
or the shortcut again for another frame; Escape closes it. Captures preserve accumulation,
TAA and SHARC history. Game movement/shooting input is blocked while inspecting the panel.

## References

Local Unreal source inspected:

- `E:/UnrealEngine/Engine/Config/BaseInput.ini`: `Comma`, Control + Shift, `PROFILEGPU`.
- `Engine/Source/Runtime/RHI/Public/RHIBreadcrumbs.h`: `FRHIBreadcrumbScope` and
  `RHI_BREADCRUMB_EVENT_STAT`, lexical event scopes.
- `Engine/Source/Runtime/RHI/Private/GPUProfiler.cpp`: hierarchical timing output, sort by
  chronological order or elapsed time, inclusive event timings.
- `Engine/Source/Runtime/RenderCore/Public/ProfilingDebugging/RealtimeGPUProfiler.h`: this
  checkout deprecates legacy `SCOPED_GPU_STAT` in favor of breadcrumb stat events (UE 5.8).

This is an independent WebGPU implementation, not copied Unreal code. WebGPU's optional
[`timestamp-query`](https://www.w3.org/TR/webgpu/#timestamp-query) feature and
[`timestampWrites`](https://gpuweb.github.io/types/interfaces/GPURenderPassTimestampWrites.html)
measure compute/render pass boundaries. Native-style arbitrary timestamps inside shaders
or between dispatches in a single pass are not provided by this implementation.

## API and accounting

`Renderer` requests timestamp-query only when the adapter advertises it. Unsupported devices
still render normally and the panel explicitly reports that GPU timing is unavailable.
`renderer.gpuProfiler.capture()` requests one capture; `status`, `error`, `report` and
`subscribe(listener)` expose its asynchronous state without DOM dependencies.

Internal integration uses synchronous lexical scopes:

```ts
const profiler = renderer.gpuProfiler;
const encoder = profiler.createCommandEncoder({ label: 'example' });
profiler.scope('Lighting', () => {
    const pass = encoder.beginComputePass({ label: 'Direct lighting' });
    // Bind and dispatch normal production work.
    pass.end();
});
```

The renderer owns `beginFrame` / `endFrame`. Extension work must use the profiled encoder
and be submitted inside that interval on the same queue. Scope callbacks must be synchronous.
An encoder-local wrapper attaches timestamp writes to existing passes; global WebGPU
prototypes and shader math are unchanged. Inactive encoders are returned unwrapped.

Captures include each tile's submitted visibility, wavefront traversal, shade,
shadow, compaction and SHARC passes, plus TAA motion/resolve, exposure, local exposure,
presentation, and any sky bake triggered in that frame. Wavefront labels form a hierarchy
under Path tracing and bounce; repeated tiles aggregate counts. Rendering is fixed at 1 spp.
The hotspot list merges identical module/pass names across bounces, preserving e.g.
`sharc.Resolve` versus `taa.resolve`.
Scene loading, pipeline compilation, texture uploads,
copy/clear operations and asynchronous OIDN jobs are not measured as timed passes.

**Pass total** is the sum of valid leaf durations. Parent durations sum descendants; do not
add parents to children. **Frame span** is the interval from first measured start to last
measured end, including intervening copies, gaps and queue starvation while the CPU submits
more work. Neither value is CPU frame time or compositor/display latency. A converged
progressive viewer can capture presentation only and explicitly reports zero path samples.
Timestamp resolution is browser-limited; very short passes may quantize to zero. Profiling
itself can perturb timings; a single capture is a diagnostic, not a performance benchmark.

## Lifetime and limits

Query resources allocate lazily on capture: 2048 timestamps (1024 passes), a 16 KiB resolve
buffer and a 16 KiB readback buffer. Each pass uses unique start/end indices. The final
resolve is submitted after all frame command buffers, then `mapAsync` reads without blocking
the render loop. Only one capture is outstanding; resources are reused after unmapping.
Closing cancels an unstarted request; an already submitted capture completes asynchronously.
Renderer disposal destroys buffers/query sets and ignores late completion. Device loss and
readback errors become explicit status. Existing pass timestamp writes are not overridden.

Excess passes or already-instrumented passes are counted as dropped; invalid/nonmonotonic
timestamps are counted separately. Incomplete reports show a warning and must not be read
as full-frame totals. No ninth path shading storage buffer or shader layout change is needed.

Console commands: `r.ProfileGPU.Capture` queues without waiting (so the console executor can
resume rendering); `r.ProfileGPU.Stats` reads status and the most recent result. Custom host
applications may mount `GpuProfilerPanel` from `@tianyuliwiwo/veach/view` and dispose it on
unmount, or consume `GpuProfiler` from the DOM-free core entry.

## Focused validation

The production game build/typecheck and eight profiler/console tests passed. A single aim
scene exercised the real Ctrl+Shift+Comma shortcut, Escape, repeat capture, console capture,
asynchronous buffer reuse and switching from Performance to Quality. Both captures retain
1 spp; Quality only changes resolution. No dropped or invalid timestamps or GPU/browser
errors were observed. Closing the panel left its capture ID unchanged until the next explicit request.
The panel screenshot was inspected. This is a functionality check, not a performance sweep.
Run `node scripts/gpu-profile-check.mjs` with the game preview on port 4177;
local results are written to `.tools/gpu-profiler/`.
