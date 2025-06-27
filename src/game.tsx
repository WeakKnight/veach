/// <reference types="@webgpu/types" />
/**
 * React renderer entry point for the Electron application
 */

import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';

console.log('👋 This message is being logged by "renderer.tsx", included via Vite');

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

// 获取根元素
const container = document.getElementById('root');
if (!container) {
  throw new Error('Root element not found');
}

const Game: React.FC = () => {
    return (
      <div className="app">
        <main className="app-main">
        </main>
      </div>
    );
  };

  
// 创建React根实例并渲染应用
const root = createRoot(container);
root.render(<Game />); 