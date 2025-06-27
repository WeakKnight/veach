/**
 * This file will automatically be loaded by vite and run in the "renderer" context.
 * To learn more about the differences between the "main" and the "renderer" context in
 * Electron, visit:
 *
 * https://electronjs.org/docs/tutorial/process-model
 *
 * By default, Node.js integration in this file is disabled. When enabling Node.js integration
 * in a renderer process, please be aware of potential security implications. You can read
 * more about security risks here:
 *
 * https://electronjs.org/docs/tutorial/security
 *
 * To enable Node.js integration in this file, open up `main.ts` and enable the `nodeIntegration`
 * flag:
 *
 * ```
 *  // Create the browser window.
 *  mainWindow = new BrowserWindow({
 *    width: 800,
 *    height: 600,
 *    webPreferences: {
 *      nodeIntegration: true
 *    }
 *  });
 * ```
 */

import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';
import './index.css';

console.log('👋 This message is being logged by "renderer.ts", included via Vite');

// 等待GPU适配器和设备
const adapter = await navigator.gpu?.requestAdapter();
const device = await adapter?.requestDevice();

// 导入shader代码
import vertexWGSL from "./shaders/vertex.wgsl";
import fragmentWGSL from "./shaders/fragment.wgsl";

// 配置pipeline选项
const pipelineOptions: GraphicsPipelineOptions = {
  vertexShaderCode: vertexWGSL,
  fragmentShaderCode: fragmentWGSL
};

// 创建graphics pipeline
const pipeline = new GraphicsPipeline(device, pipelineOptions);
console.log('Device:', device);
console.log('Pipeline created successfully:', pipeline.getPipeline());

