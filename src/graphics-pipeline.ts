/**
 * 图形渲染管线配置选项
 */
export interface GraphicsPipelineOptions {
  // Shader 相关
  vertexShaderCode: string;
  fragmentShaderCode: string;
  
  // 顶点输入布局
  vertexBufferLayouts?: GPUVertexBufferLayout[];
  
  // 渲染状态
  primitiveTopology?: GPUPrimitiveTopology;
  cullMode?: GPUCullMode;
  frontFace?: GPUFrontFace;
  
  // 深度/模板测试
  depthStencilFormat?: GPUTextureFormat;
  depthWriteEnabled?: boolean;
  depthCompare?: GPUCompareFunction;
  
  // 多重采样
  sampleCount?: number;
  
  // 颜色目标
  colorTargetFormat?: GPUTextureFormat;
  colorBlend?: GPUBlendState;
  colorWriteMask?: GPUColorWriteFlags;
  
  // 绑定组布局
  bindGroupLayouts?: GPUBindGroupLayout[];
  
  // 管线标签
  label?: string;
}

/**
 * 默认的图形渲染管线配置
 */
export const DEFAULT_PIPELINE_OPTIONS: Partial<GraphicsPipelineOptions> = {
  primitiveTopology: 'triangle-list',
  cullMode: 'back',
  frontFace: 'ccw',
  depthWriteEnabled: true,
  depthCompare: 'less',
  sampleCount: 1,
  colorTargetFormat: 'rgba8unorm',
  colorWriteMask: 0xF, // 写入所有颜色通道
};

/**
 * 图形渲染管线类
 * 封装 WebGPU 渲染管线的创建和管理
 */
export class GraphicsPipeline {
  private device: GPUDevice;
  private pipeline: GPURenderPipeline;
  private pipelineLayout: GPUPipelineLayout | 'auto';
  private vertexShader: GPUShaderModule;
  private fragmentShader: GPUShaderModule;
  private options: GraphicsPipelineOptions;

  constructor(device: GPUDevice, options: GraphicsPipelineOptions) {
    this.device = device;
    this.options = { ...DEFAULT_PIPELINE_OPTIONS, ...options };
    
    // 创建 shader 模块
    this.vertexShader = this.createShaderModule(options.vertexShaderCode, 'vertex');
    this.fragmentShader = this.createShaderModule(options.fragmentShaderCode, 'fragment');
    
    // 创建管线布局
    this.pipelineLayout = this.createPipelineLayout();
    
    // 创建渲染管线
    this.pipeline = this.createRenderPipeline();
  }

  /**
   * 创建 Shader 模块
   */
  private createShaderModule(code: string, stage: 'vertex' | 'fragment'): GPUShaderModule {
    return this.device.createShaderModule({
      label: this.options.label ? `${this.options.label}-${stage}-shader` : `${stage}-shader`,
      code: code
    });
  }

  /**
   * 创建管线布局
   */
  private createPipelineLayout(): GPUPipelineLayout | 'auto' {
    // 如果没有提供绑定组布局，使用 auto 布局
    if (!this.options.bindGroupLayouts || this.options.bindGroupLayouts.length === 0) {
      return 'auto';
    }
    
    // 否则创建自定义布局
    return this.device.createPipelineLayout({
      label: this.options.label ? `${this.options.label}-layout` : 'pipeline-layout',
      bindGroupLayouts: this.options.bindGroupLayouts
    });
  }

  /**
   * 创建渲染管线
   */
  private createRenderPipeline(): GPURenderPipeline {
    const pipelineDescriptor: GPURenderPipelineDescriptor = {
      label: this.options.label || 'graphics-pipeline',
      layout: this.pipelineLayout,
      
      // 顶点着色器
      vertex: {
        module: this.vertexShader,
        entryPoint: 'vs_main',
        buffers: this.options.vertexBufferLayouts || []
      },
      
      // 片元着色器
      fragment: {
        module: this.fragmentShader,
        entryPoint: 'fs_main',
        targets: [{
          format: this.options.colorTargetFormat!,
          blend: this.options.colorBlend,
          writeMask: this.options.colorWriteMask
        }]
      },
      
      // 图元装配
      primitive: {
        topology: this.options.primitiveTopology!,
        cullMode: this.options.cullMode!,
        frontFace: this.options.frontFace!
      },
      
      // 多重采样
      multisample: {
        count: this.options.sampleCount!
      }
    };

    // 添加深度/模板配置（如果指定）
    if (this.options.depthStencilFormat) {
      pipelineDescriptor.depthStencil = {
        format: this.options.depthStencilFormat,
        depthWriteEnabled: this.options.depthWriteEnabled!,
        depthCompare: this.options.depthCompare!
      };
    }

    return this.device.createRenderPipeline(pipelineDescriptor);
  }

  /**
   * 获取渲染管线
   */
  getPipeline(): GPURenderPipeline {
    return this.pipeline;
  }

  /**
   * 获取管线布局
   */
  getPipelineLayout(): GPUPipelineLayout | 'auto' {
    return this.pipelineLayout;
  }

  /**
   * 获取顶点着色器模块
   */
  getVertexShader(): GPUShaderModule {
    return this.vertexShader;
  }

  /**
   * 获取片元着色器模块
   */
  getFragmentShader(): GPUShaderModule {
    return this.fragmentShader;
  }

  /**
   * 获取管线配置选项
   */
  getOptions(): GraphicsPipelineOptions {
    return { ...this.options };
  }

  /**
   * 绑定管线到渲染通道
   */
  bind(renderPass: GPURenderPassEncoder): void {
    renderPass.setPipeline(this.pipeline);
  }

  /**
   * 销毁管线资源
   */
  destroy(): void {
    // WebGPU 资源会自动清理，但我们可以清除引用
    // 注意：实际的 GPU 资源销毁由浏览器管理
  }

  /**
   * 静态方法：创建基础的顶点-片元着色器管线
   */
  static createBasic(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline {
    return new GraphicsPipeline(device, {
      vertexShaderCode,
      fragmentShaderCode,
      ...options
    });
  }

  /**
   * 静态方法：创建带深度测试的管线
   */
  static createWithDepth(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    depthFormat: GPUTextureFormat = 'depth24plus',
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline {
    return new GraphicsPipeline(device, {
      vertexShaderCode,
      fragmentShaderCode,
      depthStencilFormat: depthFormat,
      depthWriteEnabled: true,
      depthCompare: 'less',
      ...options
    });
  }

  /**
   * 静态方法：创建透明物体渲染管线
   */
  static createTransparent(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline {
    const alphaBlend: GPUBlendState = {
      color: {
        srcFactor: 'src-alpha',
        dstFactor: 'one-minus-src-alpha',
        operation: 'add'
      },
      alpha: {
        srcFactor: 'one',
        dstFactor: 'one-minus-src-alpha',
        operation: 'add'
      }
    };

    return new GraphicsPipeline(device, {
      vertexShaderCode,
      fragmentShaderCode,
      colorBlend: alphaBlend,
      cullMode: 'none', // 透明物体通常不剔除背面
      ...options
    });
  }

  /**
   * 静态方法：创建线框渲染管线
   */
  static createWireframe(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline {
    return new GraphicsPipeline(device, {
      vertexShaderCode,
      fragmentShaderCode,
      primitiveTopology: 'line-list',
      cullMode: 'none',
      ...options
    });
  }

  /**
   * 静态方法：创建点精灵渲染管线
   */
  static createPointSprites(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline {
    return new GraphicsPipeline(device, {
      vertexShaderCode,
      fragmentShaderCode,
      primitiveTopology: 'point-list',
      cullMode: 'none',
      ...options
    });
  }
}

/**
 * 管线状态工具类
 * 提供常用的渲染状态配置
 */
export class PipelineState {
  /**
   * 获取标准的深度/模板状态
   */
  static getDepthStencilState(
    format: GPUTextureFormat = 'depth24plus',
    depthWrite: boolean = true,
    depthCompare: GPUCompareFunction = 'less'
  ): GPUDepthStencilState {
    return {
      format,
      depthWriteEnabled: depthWrite,
      depthCompare
    };
  }

  /**
   * 获取 Alpha 混合状态
   */
  static getAlphaBlendState(): GPUBlendState {
    return {
      color: {
        srcFactor: 'src-alpha',
        dstFactor: 'one-minus-src-alpha',
        operation: 'add'
      },
      alpha: {
        srcFactor: 'one',
        dstFactor: 'one-minus-src-alpha',
        operation: 'add'
      }
    };
  }

  /**
   * 获取加法混合状态
   */
  static getAdditiveBlendState(): GPUBlendState {
    return {
      color: {
        srcFactor: 'src-alpha',
        dstFactor: 'one',
        operation: 'add'
      },
      alpha: {
        srcFactor: 'zero',
        dstFactor: 'one',
        operation: 'add'
      }
    };
  }

  /**
   * 获取不透明渲染的光栅化状态
   */
  static getOpaqueRasterState(): GPUPrimitiveState {
    return {
      topology: 'triangle-list',
      cullMode: 'back',
      frontFace: 'ccw'
    };
  }

  /**
   * 获取透明渲染的光栅化状态
   */
  static getTransparentRasterState(): GPUPrimitiveState {
    return {
      topology: 'triangle-list',
      cullMode: 'none',
      frontFace: 'ccw'
    };
  }

  /**
   * 获取线框渲染的光栅化状态
   */
  static getWireframeRasterState(): GPUPrimitiveState {
    return {
      topology: 'line-list',
      cullMode: 'none',
      frontFace: 'ccw'
    };
  }
} 