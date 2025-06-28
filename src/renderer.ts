// 导入shader代码
import vertexWGSL from "./shaders/vertex.wgsl?raw";
import fragmentWGSL from "./shaders/fragment.wgsl?raw";
import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';

export class Renderer {
    public device: GPUDevice | null;
    private gbufferPipeline: GraphicsPipeline | null;
    private webgpuContext: GPUCanvasContext | null;
    public constructor() {
        this.device = null;
        this.gbufferPipeline = null;
        this.webgpuContext = null;
    }

    public async init() {
        // 等待GPU适配器和设备
        const adapter = await navigator.gpu?.requestAdapter();
        this.device = await adapter?.requestDevice();

        // 配置pipeline选项
        const pipelineOptions: GraphicsPipelineOptions = {
            vertexShaderCode: vertexWGSL,
            fragmentShaderCode: fragmentWGSL
        };

        console.log(vertexWGSL);

        console.log(fragmentWGSL);

        // 创建graphics pipeline
        this.gbufferPipeline = new GraphicsPipeline(this.device, pipelineOptions);
        console.log('Device:', this.device);
        console.log('Pipeline created successfully:', this.gbufferPipeline.getPipeline());

        let canvas = document.getElementById("veach-game-view") as HTMLCanvasElement;
        this.webgpuContext = canvas.getContext("webgpu");
        console.log(this.webgpuContext);
        this.webgpuContext.configure({ device: this.device, format: 'rgba8unorm' });

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

    public resize(){
    }

    public render(deltaTime) {
        let commandEncoder = this.device.createCommandEncoder({ label: "GBuffer" });
        // console.log(commandEncoder);

        let backBuffer = this.webgpuContext.getCurrentTexture().createView();
        // console.log(deltaTime);
        
        let renderPassDesc : GPURenderPassDescriptor = {
            label: "GBuffer",
            colorAttachments: [{
                clearValue: [0.55, 0.60, 0.52, 1.0],
                loadOp: "clear",
                storeOp: "store",
                view: backBuffer
            }]
        };
        let attachment0:GPURenderPassColorAttachment = renderPassDesc.colorAttachments[0];
        attachment0.view = backBuffer;
        
        let renderPassEncoder = commandEncoder.beginRenderPass(renderPassDesc);
        renderPassEncoder.setPipeline(this.gbufferPipeline.getPipeline());
        renderPassEncoder.draw(6);
        renderPassEncoder.end();
        
        let commandBuffer = commandEncoder.finish();
        this.device.queue.submit([commandBuffer]);
    }
}