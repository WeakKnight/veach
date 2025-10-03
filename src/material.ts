import { Texture, TextureFromURLOptions } from './texture';
import { GraphicsPipeline, GraphicsPipelineOptions } from './graphics-pipeline';

/**
 * 材质纹理槽配置
 */
export interface MaterialTextureSlot {
  /** 纹理对象 */
  texture: Texture;
  /** 采样器描述符 */
  samplerDescriptor?: GPUSamplerDescriptor;
  /** 绑定组中的绑定索引 */
  binding: number;
  /** 纹理类型标识 */
  name: string;
}

/**
 * 材质Uniform缓冲区配置
 */
export interface MaterialUniformBuffer {
  /** 缓冲区对象 */
  buffer: GPUBuffer;
  /** 绑定组中的绑定索引 */
  binding: number;
  /** 缓冲区名称 */
  name: string;
  /** 缓冲区大小 */
  size: number;
}

/**
 * 材质Storage缓冲区配置
 */
export interface MaterialStorageBuffer {
  /** 缓冲区对象（可以是 GPUBuffer 或 GPUBufferWrapper） */
  buffer: GPUBuffer | import('./gpu-buffer').GPUBufferWrapper;
  /** 绑定组中的绑定索引 */
  binding: number;
  /** 缓冲区名称 */
  name: string;
  /** 缓冲区大小 */
  size: number;
}

/**
 * 材质配置选项
 */
export interface MaterialOptions {
  /** 材质名称 */
  name?: string;
  /** 顶点着色器代码 */
  vertexShaderCode: string;
  /** 片元着色器代码 */
  fragmentShaderCode: string;
  /** 纹理槽映射 */
  textures?: Map<string, MaterialTextureSlot>;
  /** Uniform缓冲区映射 */
  uniforms?: Map<string, MaterialUniformBuffer>;
  /** Storage缓冲区映射 */
  storageBuffers?: Map<string, MaterialStorageBuffer>;
  /** 图形管线配置选项 */
  pipelineOptions?: Partial<GraphicsPipelineOptions>;
}

/**
 * 材质类
 * 管理着色器、纹理和Uniform参数的完整材质系统
 */
export class Material {
  private device: GPUDevice;
  private name: string;
  private pipeline: GraphicsPipeline;
  private textures: Map<string, MaterialTextureSlot>;
  private uniforms: Map<string, MaterialUniformBuffer>;
  private storageBuffers: Map<string, MaterialStorageBuffer>;
  private bindGroup: GPUBindGroup | null = null;
  private bindGroupLayout: GPUBindGroupLayout | null = null;

  constructor(device: GPUDevice, options: MaterialOptions) {
    this.device = device;
    this.name = options.name || 'Material';
    this.textures = options.textures || new Map();
    this.uniforms = options.uniforms || new Map();
    this.storageBuffers = options.storageBuffers || new Map();

    // 创建绑定组布局
    this.bindGroupLayout = this.createBindGroupLayout();

    // 创建图形管线
    const pipelineOptions: GraphicsPipelineOptions = {
      ...options.pipelineOptions,
      vertexShaderCode: options.vertexShaderCode,
      fragmentShaderCode: options.fragmentShaderCode,
      bindGroupLayouts: this.bindGroupLayout ? [this.bindGroupLayout] : undefined,
      label: `${this.name}-pipeline`
    };

    this.pipeline = new GraphicsPipeline(device, pipelineOptions);

    // 创建绑定组
    this.bindGroup = this.createBindGroup();
  }

  /**
   * 创建绑定组布局
   */
  private createBindGroupLayout(): GPUBindGroupLayout | null {
    const entries: GPUBindGroupLayoutEntry[] = [];

    // 添加纹理绑定
    this.textures.forEach((slot) => {
      // 纹理绑定
      entries.push({
        binding: slot.binding,
        visibility: GPUShaderStage.FRAGMENT,
        texture: {
          sampleType: 'float',
          viewDimension: '2d'
        }
      });

      // 采样器绑定
      entries.push({
        binding: slot.binding + 1,
        visibility: GPUShaderStage.FRAGMENT,
        sampler: {}
      });
    });

    // 添加Uniform缓冲区绑定
    this.uniforms.forEach((uniform) => {
      entries.push({
        binding: uniform.binding,
        visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
        buffer: {
          type: 'uniform'
        }
      });
    });

    // 添加Storage缓冲区绑定
    this.storageBuffers.forEach((storageBuffer) => {
      entries.push({
        binding: storageBuffer.binding,
        visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
        buffer: {
          type: 'read-only-storage'
        }
      });
    });

    if (entries.length === 0) {
      return null;
    }

    return this.device.createBindGroupLayout({
      label: `${this.name}-bind-group-layout`,
      entries
    });
  }

  /**
   * 创建绑定组
   */
  private createBindGroup(): GPUBindGroup | null {
    if (!this.bindGroupLayout) {
      return null;
    }

    const entries: GPUBindGroupEntry[] = [];

    // 添加纹理绑定
    this.textures.forEach((slot) => {
      // 纹理绑定
      entries.push({
        binding: slot.binding,
        resource: slot.texture.getView()
      });

      // 采样器绑定
      let sampler = slot.texture.getSampler();
      if (!sampler) {
        sampler = slot.texture.createSampler(slot.samplerDescriptor);
      }

      entries.push({
        binding: slot.binding + 1,
        resource: sampler
      });
    });

    // 添加Uniform缓冲区绑定
    this.uniforms.forEach((uniform) => {
      entries.push({
        binding: uniform.binding,
        resource: {
          buffer: uniform.buffer
        }
      });
    });

    // 添加Storage缓冲区绑定
    this.storageBuffers.forEach((storageBuffer) => {
      const buffer = 'getBuffer' in storageBuffer.buffer 
        ? storageBuffer.buffer.getBuffer() 
        : storageBuffer.buffer;
      
      entries.push({
        binding: storageBuffer.binding,
        resource: {
          buffer: buffer
        }
      });
    });

    return this.device.createBindGroup({
      label: `${this.name}-bind-group`,
      layout: this.bindGroupLayout,
      entries
    });
  }

  /**
   * 重新创建绑定组（在纹理或Uniform更新后调用）
   */
  private rebuildBindGroup(): void {
    this.bindGroupLayout = this.createBindGroupLayout();
    this.bindGroup = this.createBindGroup();

    // 重新创建管线以使用新的绑定组布局
    const options = this.pipeline.getOptions();
    const newPipelineOptions: GraphicsPipelineOptions = {
      ...options,
      bindGroupLayouts: this.bindGroupLayout ? [this.bindGroupLayout] : undefined
    };

    this.pipeline = new GraphicsPipeline(this.device, newPipelineOptions);
  }

  /**
   * 设置纹理
   */
  setTexture(
    name: string,
    texture: Texture,
    binding: number,
    samplerDescriptor?: GPUSamplerDescriptor
  ): void {
    const slot: MaterialTextureSlot = {
      texture,
      binding,
      name,
      samplerDescriptor
    };

    this.textures.set(name, slot);
    this.rebuildBindGroup();
  }

  /**
   * 从URL加载并设置纹理
   */
  async setTextureFromURL(
    name: string,
    url: string,
    binding: number,
    textureOptions?: TextureFromURLOptions,
    samplerDescriptor?: GPUSamplerDescriptor
  ): Promise<void> {
    const texture = await Texture.fromURL(this.device, url, textureOptions);
    this.setTexture(name, texture, binding, samplerDescriptor);
  }

  /**
   * 设置纯色纹理
   */
  setSolidColorTexture(
    name: string,
    color: [number, number, number, number],
    binding: number,
    size: [number, number] = [1, 1],
    samplerDescriptor?: GPUSamplerDescriptor
  ): void {
    const texture = Texture.createSolidColor(
      this.device,
      color,
      size[0],
      size[1],
      `${this.name}-${name}-texture`
    );
    this.setTexture(name, texture, binding, samplerDescriptor);
  }

  /**
   * 移除纹理
   */
  removeTexture(name: string): boolean {
    const removed = this.textures.delete(name);
    if (removed) {
      this.rebuildBindGroup();
    }
    return removed;
  }

  /**
   * 获取纹理
   */
  getTexture(name: string): Texture | undefined {
    return this.textures.get(name)?.texture;
  }

  /**
   * 设置Uniform缓冲区
   */
  setUniformBuffer(name: string, buffer: GPUBuffer, binding: number, size: number): void {
    const uniform: MaterialUniformBuffer = {
      buffer,
      binding,
      name,
      size
    };

    this.uniforms.set(name, uniform);
    this.rebuildBindGroup();
  }

  /**
   * 创建并设置Uniform缓冲区
   */
  createUniformBuffer(name: string, data: ArrayBufferView, binding: number): GPUBuffer {
    const buffer = this.device.createBuffer({
      label: `${this.name}-${name}-uniform`,
      size: data.byteLength,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });

    this.device.queue.writeBuffer(buffer, 0, data);
    this.setUniformBuffer(name, buffer, binding, data.byteLength);

    return buffer;
  }

  /**
   * 更新Uniform缓冲区数据
   */
  updateUniformBuffer(name: string, data: ArrayBufferView, offset: number = 0): boolean {
    const uniform = this.uniforms.get(name);
    if (!uniform) {
      return false;
    }

    this.device.queue.writeBuffer(uniform.buffer, offset, data);
    return true;
  }

  /**
   * 移除Uniform缓冲区
   */
  removeUniformBuffer(name: string): boolean {
    const removed = this.uniforms.delete(name);
    if (removed) {
      this.rebuildBindGroup();
    }
    return removed;
  }

  /**
   * 获取Uniform缓冲区
   */
  getUniformBuffer(name: string): GPUBuffer | undefined {
    return this.uniforms.get(name)?.buffer;
  }

  /**
   * 设置Storage缓冲区
   */
  setStorageBuffer(
    name: string, 
    buffer: GPUBuffer | import('./gpu-buffer').GPUBufferWrapper, 
    binding: number
  ): void {
    const actualBuffer = 'getBuffer' in buffer ? buffer.getBuffer() : buffer;
    const size = 'getSize' in buffer ? buffer.getSize() : 0;
    
    const storageBuffer: MaterialStorageBuffer = {
      buffer,
      binding,
      name,
      size
    };

    this.storageBuffers.set(name, storageBuffer);
    this.rebuildBindGroup();
  }

  /**
   * 移除Storage缓冲区
   */
  removeStorageBuffer(name: string): boolean {
    const removed = this.storageBuffers.delete(name);
    if (removed) {
      this.rebuildBindGroup();
    }
    return removed;
  }

  /**
   * 获取Storage缓冲区
   */
  getStorageBuffer(name: string): GPUBuffer | import('./gpu-buffer').GPUBufferWrapper | undefined {
    return this.storageBuffers.get(name)?.buffer;
  }

  /**
   * 获取所有Storage缓冲区名称
   */
  getStorageBufferNames(): string[] {
    return Array.from(this.storageBuffers.keys());
  }

  /**
   * 绑定材质到渲染通道
   */
  bind(renderPass: GPURenderPassEncoder): void {
    // 绑定管线
    this.pipeline.bind(renderPass);

    // 绑定资源
    if (this.bindGroup) {
      renderPass.setBindGroup(0, this.bindGroup);
    }
  }

  /**
   * 获取图形管线
   */
  getPipeline(): GraphicsPipeline {
    return this.pipeline;
  }

  /**
   * 获取绑定组
   */
  getBindGroup(): GPUBindGroup | null {
    return this.bindGroup;
  }

  /**
   * 获取绑定组布局
   */
  getBindGroupLayout(): GPUBindGroupLayout | null {
    return this.bindGroupLayout;
  }

  /**
   * 获取材质名称
   */
  getName(): string {
    return this.name;
  }

  /**
   * 获取所有纹理名称
   */
  getTextureNames(): string[] {
    return Array.from(this.textures.keys());
  }

  /**
   * 获取所有Uniform缓冲区名称
   */
  getUniformNames(): string[] {
    return Array.from(this.uniforms.keys());
  }

  /**
   * 克隆材质（浅拷贝纹理和Uniform）
   */
  clone(newName?: string): Material {
    const clonedTextures = new Map(this.textures);
    const clonedUniforms = new Map(this.uniforms);
    const originalOptions = this.pipeline.getOptions();

    return new Material(this.device, {
      name: newName || `${this.name}-clone`,
      vertexShaderCode: originalOptions.vertexShaderCode,
      fragmentShaderCode: originalOptions.fragmentShaderCode,
      textures: clonedTextures,
      uniforms: clonedUniforms,
      pipelineOptions: originalOptions
    });
  }

  /**
   * 销毁材质资源
   */
  destroy(): void {
    // 销毁纹理
    this.textures.forEach((slot) => {
      slot.texture.destroy();
    });
    this.textures.clear();

    // 销毁Uniform缓冲区
    this.uniforms.forEach((uniform) => {
      uniform.buffer.destroy();
    });
    this.uniforms.clear();

    // 清理管线
    this.pipeline.destroy();

    // 清空引用
    this.bindGroup = null;
    this.bindGroupLayout = null;
  }

  /**
   * 静态方法：创建基础材质
   */
  static createBasic(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<MaterialOptions>
  ): Material {
    return new Material(device, {
      vertexShaderCode,
      fragmentShaderCode,
      ...options
    });
  }

  /**
   * 静态方法：创建带单张纹理的材质
   */
  static async createWithTexture(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    textureUrl: string,
    options?: Partial<MaterialOptions>
  ): Promise<Material> {
    const material = new Material(device, {
      vertexShaderCode,
      fragmentShaderCode,
      ...options
    });

    await material.setTextureFromURL('diffuse', textureUrl, 0);
    return material;
  }

  /**
   * 静态方法：创建标准PBR材质
   */
  static async createPBR(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    texturePaths: {
      albedo?: string;
      normal?: string;
      metallic?: string;
      roughness?: string;
      ao?: string;
    },
    options?: Partial<MaterialOptions>
  ): Promise<Material> {
    const material = new Material(device, {
      vertexShaderCode,
      fragmentShaderCode,
      name: 'PBR-Material',
      ...options
    });

    let binding = 0;

    if (texturePaths.albedo) {
      await material.setTextureFromURL('albedo', texturePaths.albedo, binding);
      binding += 2; // 纹理+采样器占用2个绑定
    }

    if (texturePaths.normal) {
      await material.setTextureFromURL('normal', texturePaths.normal, binding);
      binding += 2;
    }

    if (texturePaths.metallic) {
      await material.setTextureFromURL('metallic', texturePaths.metallic, binding);
      binding += 2;
    }

    if (texturePaths.roughness) {
      await material.setTextureFromURL('roughness', texturePaths.roughness, binding);
      binding += 2;
    }

    if (texturePaths.ao) {
      await material.setTextureFromURL('ao', texturePaths.ao, binding);
      binding += 2;
    }

    return material;
  }
}

/**
 * 材质库类
 * 管理多个材质的集合
 */
export class MaterialLibrary {
  private materials: Map<string, Material> = new Map();

  /**
   * 添加材质
   */
  addMaterial(name: string, material: Material): void {
    this.materials.set(name, material);
  }

  /**
   * 获取材质
   */
  getMaterial(name: string): Material | undefined {
    return this.materials.get(name);
  }

  /**
   * 移除材质
   */
  removeMaterial(name: string): boolean {
    const material = this.materials.get(name);
    if (material) {
      material.destroy();
      return this.materials.delete(name);
    }
    return false;
  }

  /**
   * 获取所有材质名称
   */
  getMaterialNames(): string[] {
    return Array.from(this.materials.keys());
  }

  /**
   * 清空材质库
   */
  clear(): void {
    this.materials.forEach(material => material.destroy());
    this.materials.clear();
  }

  /**
   * 获取材质数量
   */
  size(): number {
    return this.materials.size;
  }
}
