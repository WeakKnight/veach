// 导入shader代码
import vertexWGSL from "./shaders/vertex.wgsl?raw";
import fragmentWGSL from "./shaders/fragment.wgsl?raw";
import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';
import { Mesh } from "./mesh";

export class Renderer {
    public device: GPUDevice | null;
    private gbufferPipeline: GraphicsPipeline | null;
    private webgpuContext: GPUCanvasContext | null;
    private mesh: Mesh | null;
    private bindingGroup: GPUBindGroup | null;

    public constructor() {
        this.device = null;
        this.gbufferPipeline = null;
        this.webgpuContext = null;
        this.bindingGroup = null;
    }

    public async init() {
        // 等待GPU适配器和设备
        const adapter = await navigator.gpu?.requestAdapter();
        this.device = await adapter?.requestDevice();

        // 配置pipeline选项
        const pipelineOptions: GraphicsPipelineOptions = {
            vertexShaderCode: vertexWGSL,
            fragmentShaderCode: fragmentWGSL,
            cullMode: 'none',
            frontFace: 'ccw',
            depthCompare: 'always'
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

        this.mesh = Mesh.createCube(this.device, 0.3);
        console.log(this.mesh);
        for(let i = 0; i < this.mesh.getVertexCount(); i++) {
            let data = new Float32Array(14);
            let promise = this.mesh.getVertexBuffer().readDataTo(data, i * 56);
            promise.then(() => {
                console.log(data);
            });
        }

        this.bindingGroup = this.device.createBindGroup({
            layout: this.gbufferPipeline.getPipeline().getBindGroupLayout(0),
            entries: [
                { binding: 0, resource: this.mesh.getVertexBuffer().getBuffer() }
                // { binding: 1, resource: this.mesh.getIndexBuffer().getBuffer() }
            ]
        }); 

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
        // renderPassEncoder.setBindGroup(0, this.bindingGroup);
        renderPassEncoder.draw(3);
        renderPassEncoder.end();
        
        let commandBuffer = commandEncoder.finish();
        this.device.queue.submit([commandBuffer]);
    }
}