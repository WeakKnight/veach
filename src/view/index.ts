/// <reference types="@webgpu/types" preserve="true" />
// `@tianyuliwiwo/veach/view`: importing it registers <veach-view>. The core entry (`@tianyuliwiwo/veach`) has no
// DOM side effects and loads in Node; the element lives here because it extends HTMLElement.
import { defineVeachView } from './VeachViewElement';

export { VeachViewElement, defineVeachView, type VeachViewEventMap, type VeachViewProgress } from './VeachViewElement';
export { attachFileDrop, loadDroppedFiles, type DroppedFiles, type FileDropHandlers } from './fileDrop';
export { DebugConsole, type DebugConsoleOptions } from './DebugConsole';
export { GpuProfilerPanel } from './GpuProfilerPanel';

defineVeachView();
