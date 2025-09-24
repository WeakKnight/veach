import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';
import { Mesh } from "./mesh";
import { GPUBufferWrapper } from "./gpu-buffer";
import { WgslReflect } from "wgsl_reflect/wgsl_reflect.module.js";

export class Renderer {
	public device: GPUDevice | null;
	private gbufferPipeline: GraphicsPipeline | null;
	private webgpuContext: GPUCanvasContext | null;
	private mesh: Mesh | null;
	private canvas: HTMLCanvasElement | null;

	// private dummyVertexBuffer: GPUBufferWrapper | null;
	// private dummyIndexBuffer: GPUBufferWrapper | null;

	private bindingGroup: GPUBindGroup | null;
	private initialized: boolean;

	public constructor() {
		this.device = null;
		this.gbufferPipeline = null;
		this.webgpuContext = null;
		this.canvas = null;
		this.bindingGroup = null;
		// this.dummyVertexBuffer = null;
		this.initialized = false;
	}

	public async init() {
		// 等待GPU适配器和设备
		const adapter = await navigator.gpu?.requestAdapter();
		this.device = await adapter?.requestDevice();

		let vertexWGSL = await window.fs.readTextFile('assets/shaders/vertex.wgsl');
		let fragmentWGSL = await window.fs.readTextFile('assets/shaders/fragment.wgsl');

		// 配置pipeline选项
		const pipelineOptions: GraphicsPipelineOptions = {
			vertexShaderCode: vertexWGSL,
			fragmentShaderCode: fragmentWGSL,
			cullMode: 'none',
			frontFace: 'ccw',
			depthCompare: 'always'
		};

		// console.log(vertexWGSL);
		// const vertexReflect = new WgslReflect(vertexWGSL);
		// console.log(vertexReflect);
		// console.log(fragmentWGSL);
		// const fragmentReflect = new WgslReflect(fragmentWGSL);
		// console.log(fragmentReflect);
		// 创建graphics pipeline
		this.gbufferPipeline = new GraphicsPipeline(this.device, pipelineOptions);
		console.log('Device:', this.device);
		console.log('Pipeline created successfully:', this.gbufferPipeline.getPipeline());

		this.canvas = document.getElementById("veach-game-view") as HTMLCanvasElement;
		this.webgpuContext = this.canvas.getContext("webgpu");
		console.log(this.webgpuContext);
		
		// Set up proper canvas resolution
		this.resizeCanvas();
		
		this.webgpuContext.configure({ device: this.device, format: 'rgba8unorm' });

		this.mesh = Mesh.createQuad(this.device, 0.3);
		// console.log(this.mesh);
		// for(let i = 0; i < this.mesh.getVertexCount(); i++) {
		//     let data = new Float32Array(14);
		//     let promise = this.mesh.getVertexBuffer().readDataTo(data, i * 56);
		//     promise.then(() => {
		//         console.log(data);
		//     });
		// }

		// this.dummyVertexBuffer = new GPUBufferWrapper(this.device, { size: 1024, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE });
		// this.dummyVertexBuffer.setData(new Float32Array([-1, 1,
		// -1, -1,
		// 	1, -1,
		// 	1, 1]), 0);

		// this.dummyIndexBuffer = new GPUBufferWrapper(this.device, { size: 1024, usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST | GPUBufferUsage.COPY_SRC | GPUBufferUsage.STORAGE });
		// this.dummyIndexBuffer.setData(new Uint32Array([0, 1, 2, 2, 3, 0]), 0);

		console.log(this.gbufferPipeline.getPipeline().getBindGroupLayout(0));

		this.bindingGroup = this.device.createBindGroup({
			layout: this.gbufferPipeline.getPipeline().getBindGroupLayout(0),
			entries: [
				{ binding: 0, resource: this.mesh.getVertexBuffer().getBuffer() },
				{ binding: 1, resource: this.mesh.getIndexBuffer().getBuffer() }
			]
		});

		this.initialized = true;

		let lastTime = 0;         // 初始为 0，首帧会被特殊处理
		let tick = (timestamp) => {
			// timestamp: requestAnimationFrame 传入的高精度毫秒数
			if (lastTime === 0) lastTime = timestamp;          // 首帧校准

			const deltaTime = (timestamp - lastTime) / 1000;   // 秒；去掉 “/1000” 则是毫秒
			lastTime = timestamp;

			this.render(deltaTime);

			requestAnimationFrame(tick); // 继续下一帧
		}
		requestAnimationFrame(tick);
	}

	public resize() {
		this.resizeCanvas();
	}

	private resizeCanvas() {
		if (!this.canvas || !this.initialized) return;
		
		// Get the display size (CSS size) of the canvas
		const displayWidth = this.canvas.clientWidth;
		const displayHeight = this.canvas.clientHeight;
		
		// Get device pixel ratio for high-DPI displays
		const devicePixelRatio = window.devicePixelRatio || 1;
		
		// Calculate the actual canvas resolution
		const canvasWidth = Math.floor(displayWidth * devicePixelRatio);
		const canvasHeight = Math.floor(displayHeight * devicePixelRatio);
		
		// Only resize if the size has changed
		if (this.canvas.width !== canvasWidth || this.canvas.height !== canvasHeight) {
			this.canvas.width = canvasWidth;
			this.canvas.height = canvasHeight;
			
			console.log(`Canvas resized to ${canvasWidth}x${canvasHeight} (display: ${displayWidth}x${displayHeight}, ratio: ${devicePixelRatio})`);
		}
	}

	public render(deltaTime) {
		let commandEncoder = this.device.createCommandEncoder({ label: "GBuffer" });
		// console.log(commandEncoder);

		let backBuffer = this.webgpuContext.getCurrentTexture().createView();
		// console.log(deltaTime);

		let renderPassDesc: GPURenderPassDescriptor = {
			label: "GBuffer",
			colorAttachments: [{
				clearValue: [0.55, 0.60, 0.52, 1.0],
				loadOp: "clear",
				storeOp: "store",
				view: backBuffer
			}]
		};
		let attachment0: GPURenderPassColorAttachment = renderPassDesc.colorAttachments[0];
		attachment0.view = backBuffer;

		let renderPassEncoder = commandEncoder.beginRenderPass(renderPassDesc);
		renderPassEncoder.setPipeline(this.gbufferPipeline.getPipeline());
		renderPassEncoder.setBindGroup(0, this.bindingGroup);
		renderPassEncoder.draw(this.mesh.getIndexCount());
		renderPassEncoder.end();

		let commandBuffer = commandEncoder.finish();
		this.device.queue.submit([commandBuffer]);
	}
}