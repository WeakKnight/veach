/// <reference types="@webgpu/types" />
/**
 * React renderer entry point for the Electron application
 */

import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';
import { Button, DatePicker } from 'antd';
import { Layout } from "antd";
import { Renderer } from './renderer';
console.log('👋 This message is being logged by "renderer.tsx", included via Vite');

// 获取根元素
const container = document.getElementById('root');
if (!container) {
	throw new Error('Root element not found');
}
const { Header, Content, Footer, Sider } = Layout;
const Game: React.FC = () => {
	return (
		<div id="veach-game-editor">
			<Layout className="veach-editor-layout">
				<Sider>
					<Button type="primary">PRESS ME</Button>
					<DatePicker placeholder="select date" />
				</Sider>
				<Content>
					<canvas id="veach-game-view">
					</canvas>
				</Content>
				<Sider>right sidebar</Sider>
			</Layout>
		</div>
	);
};

// 创建React根实例并渲染应用
const root = createRoot(container);
root.render(<Game />);

let renderer = new Renderer();
renderer.init();

let resize = () => {
	// Set up the window/container sizing
	document.body.style.width = window.innerWidth + "px";
	document.body.style.height = window.innerHeight + "px";
	container.style.width = document.body.style.width;
	container.style.height = document.body.style.height;
	
	let editorRoot = document.getElementById("veach-game-editor");
	if (editorRoot !== null) {
		editorRoot.style.width = container.style.width;
		editorRoot.style.height = container.style.height;
	}
	
	// Update renderer canvas resolution
	renderer.resize();
}
resize();
window.addEventListener('resize', resize);

