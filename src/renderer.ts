import { Material } from './material';
import { Mesh } from "./mesh";
import { GPUBufferWrapper } from "./gpu-buffer";
import { WgslReflect } from "wgsl_reflect/wgsl_reflect.module.js";
import { GLTFImporter } from './gltf/gltf-importer';
import { MeshRenderer, MeshRendererManager } from './mesh-renderer';
import { float3 } from './math/float3';
import { float4x4 } from './math/float4x4';

export class Renderer {
	public device: GPUDevice | null;
	private webgpuContext: GPUCanvasContext | null;
	private canvas: HTMLCanvasElement | null;
	private gltfImporter: GLTFImporter | null;
	private meshRendererManager: MeshRendererManager;
	private initialized: boolean;
	private vertexShaderCode: string | null;
	private fragmentShaderCode: string | null;
	
	// 相机和旋转状态
	private rotationX: number = 0;
	private rotationY: number = 0;
	private viewMatrix: float4x4 = new float4x4();
	private projectionMatrix: float4x4 = new float4x4();

	public constructor() {
		this.device = null;
		this.webgpuContext = null;
		this.canvas = null;
		this.gltfImporter = null;
		this.meshRendererManager = new MeshRendererManager();
		this.initialized = false;
		this.vertexShaderCode = null;
		this.fragmentShaderCode = null;
	}

	public async init() {
		// 等待GPU适配器和设备
		const adapter = await navigator.gpu?.requestAdapter();
		this.device = await adapter?.requestDevice();

		// 读取着色器代码
		this.vertexShaderCode = await window.fs.readTextFile('assets/shaders/vertex.wgsl');
		this.fragmentShaderCode = await window.fs.readTextFile('assets/shaders/fragment.wgsl');

		console.log('Device:', this.device);

		this.canvas = document.getElementById("veach-game-view") as HTMLCanvasElement;
		this.webgpuContext = this.canvas.getContext("webgpu");
		console.log(this.webgpuContext);

		// Set up proper canvas resolution
		this.resizeCanvas();

		this.webgpuContext.configure({ device: this.device, format: 'rgba8unorm' });

		// 初始化 glTF 导入器
		this.gltfImporter = new GLTFImporter(this.device, {
			generateMipmaps: true,
			textureFormat: 'rgba8unorm',
			optimizeMeshes: true
		});

		// 加载并创建 GLTF MeshRenderer
		await this.loadGLTFModel();

		this.initialized = true;

		let lastTime = 0;         // 初始为 0，首帧会被特殊处理
		let tick = (timestamp: number) => {
			// timestamp: requestAnimationFrame 传入的高精度毫秒数
			if (lastTime === 0) lastTime = timestamp;          // 首帧校准

			const deltaTime = (timestamp - lastTime) / 1000;   // 秒；去掉 "/1000" 则是毫秒
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

	public render(deltaTime: number) {
		// 更新旋转角度（自动旋转）
		this.rotationX += deltaTime * 0.5; // 每秒约 28.6 度
		this.rotationY += deltaTime * 0.3; // 每秒约 17.2 度
		
		// 更新相机矩阵
		this.updateCamera();
		
		// 更新所有 MeshRenderer 的 transform（应用旋转）
		this.updateMeshTransforms();
		
		let commandEncoder = this.device.createCommandEncoder({ label: "GBuffer" });

		let backBuffer = this.webgpuContext.getCurrentTexture().createView();

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
		
		// 使用 MeshRendererManager 渲染所有启用的 MeshRenderer
		// 传递相机矩阵
		this.meshRendererManager.renderAll(renderPassEncoder, this.viewMatrix, this.projectionMatrix);
		
		renderPassEncoder.end();

		let commandBuffer = commandEncoder.finish();
		this.device.queue.submit([commandBuffer]);
	}
	
	/**
	 * 更新相机矩阵
	 */
	private updateCamera(): void {
		// 设置相机位置：在 Z 轴正方向，距离原点 3 个单位
		const cameraPosition = new float3(0, 0, 3);
		const targetPosition = new float3(0, 0, 0);
		const upDirection = new float3(0, 1, 0);
		
		// 创建视图矩阵
		this.viewMatrix = float4x4.lookAt(cameraPosition, targetPosition, upDirection);
		
		// 创建投影矩阵
		if (this.canvas) {
			const aspect = this.canvas.width / this.canvas.height;
			this.projectionMatrix = float4x4.perspective(
				Math.PI / 4,  // 45 度视野 (FOV)
				aspect,       // 宽高比
				0.1,          // 近裁剪面
				100.0         // 远裁剪面
			);
		}
	}
	
	/**
	 * 更新所有 MeshRenderer 的变换矩阵
	 */
	private updateMeshTransforms(): void {
		// 创建旋转矩阵：先绕 Y 轴（左右），再绕 X 轴（上下）
		const rotY = float4x4.rotationY(this.rotationY);
		const rotX = float4x4.rotationX(this.rotationX);
		const modelMatrix = float4x4.multiply(rotY, rotX);
		
		// 应用到所有 MeshRenderer
		this.meshRendererManager.getAllRenderers().forEach(renderer => {
			renderer.setTransform(modelMatrix);
		});
	}

	/**
	 * 加载 GLTF 模型并创建 MeshRenderer
	 */
	private async loadGLTFModel(): Promise<void> {
		if (!this.gltfImporter || !this.device || !this.vertexShaderCode || !this.fragmentShaderCode) {
			console.error('Required components not initialized for GLTF loading');
			return;
		}

		try {
			console.log('=== 开始加载 glTF 模型 ===');
			
			// 导入 BoxTextured.gltf
			const result = await this.gltfImporter.importFromFile('assets/box-textured/BoxTextured.gltf');
			
			console.log('=== glTF 导入结果 ===');
			console.log(`网格数量: ${result.meshes.length}`);
			console.log(`纹理数量: ${result.textures.length}`);
			
			// 创建 MeshRenderer 数组
			const meshRenderers = await MeshRenderer.createArrayFromGLTF(
				this.device,
				result.meshes,
				result.textures,
				this.vertexShaderCode,
				this.fragmentShaderCode,
				'BoxTextured'
			);

			// 将 MeshRenderer 添加到管理器中
			meshRenderers.forEach((renderer, index) => {
				this.meshRendererManager.addRenderer(`gltf-mesh-${index}`, renderer);
				console.log(`添加 MeshRenderer: ${renderer.getName()}`);
			});

			console.log(`=== 成功创建 ${meshRenderers.length} 个 MeshRenderer ===`);
			
		} catch (error) {
			console.error('GLTF 模型加载失败:', error);
		}
	}

	/**
	 * 测试 glTF 导入功能（保留用于调试）
	 */
	private async testGLTFImport(): Promise<void> {
		if (!this.gltfImporter) {
			console.error('glTF importer not initialized');
			return;
		}

		try {
			console.log('=== 开始测试 glTF 导入 ===');
			
			// 测试加载 BoxTextured.gltf
			const result = await this.gltfImporter.importFromFile('assets/box-textured/BoxTextured.gltf');
			
			console.log('=== glTF 导入结果 ===');
			console.log(`网格数量: ${result.meshes.length}`);
			console.log(`纹理数量: ${result.textures.length}`);
			
			// 打印网格信息
			result.meshes.forEach((mesh, index) => {
				console.log(`网格 ${index}:`);
				console.log(`  - 顶点数: ${mesh.getVertexCount()}`);
				console.log(`  - 索引数: ${mesh.getIndexCount()}`);
				console.log(`  - 顶点缓冲区大小: ${mesh.getVertexBuffer().getSize()} 字节`);
				console.log(`  - 索引缓冲区大小: ${mesh.getIndexBuffer().getSize()} 字节`);
			});
			
			// 打印纹理信息
			result.textures.forEach((texture, index) => {
				console.log(`纹理 ${index}:`);
				console.log(`  - 尺寸: ${texture.getWidth()}x${texture.getHeight()}`);
				console.log(`  - 格式: ${texture.getFormat()}`);
				console.log(`  - Mip级别: ${texture.getMipLevelCount()}`);
			});
			
			console.log('=== glTF 导入测试完成 ===');
			
		} catch (error) {
			console.error('glTF 导入测试失败:', error);
		}
	}
}
