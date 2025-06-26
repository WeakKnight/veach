/**
 * 纹理创建选项
 */
export interface TextureOptions {
  // 基本属性
  width: number;
  height: number;
  format?: GPUTextureFormat;
  
  // 纹理用途
  usage?: GPUTextureUsageFlags;
  
  // Mipmap 层级
  mipLevelCount?: number;
  
  // 数组层数
  arrayLayerCount?: number;
  
  // 采样数（用于多重采样）
  sampleCount?: number;
  
  // 纹理维度
  dimension?: GPUTextureDimension;
  
  // 标签
  label?: string;
}

/**
 * 从URL加载纹理的选项
 */
export interface TextureFromURLOptions {
  // 是否生成mipmap
  generateMipmaps?: boolean;
  
  // 纹理格式
  format?: GPUTextureFormat;
  
  // 额外的用途标志
  usage?: GPUTextureUsageFlags;
  
  // 是否翻转Y轴
  flipY?: boolean;
  
  // 是否预乘Alpha
  premultiplyAlpha?: boolean;
  
  // 颜色空间
  colorSpace?: PredefinedColorSpace;
  
  // 标签
  label?: string;
}

/**
 * 渲染目标选项
 */
export interface RenderTargetOptions {
  // 基本尺寸
  width: number;
  height: number;
  
  // 颜色格式
  colorFormat?: GPUTextureFormat;
  
  // 深度格式
  depthFormat?: GPUTextureFormat;
  
  // 多重采样
  sampleCount?: number;
  
  // 是否创建深度缓冲
  hasDepth?: boolean;
  
  // Mipmap层级
  mipLevelCount?: number;
  
  // 标签
  label?: string;
}

/**
 * 默认纹理配置
 */
export const DEFAULT_TEXTURE_OPTIONS: Partial<TextureOptions> = {
  format: 'rgba8unorm',
  usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
  mipLevelCount: 1,
  arrayLayerCount: 1,
  sampleCount: 1,
  dimension: '2d'
};

/**
 * 默认从URL加载选项
 */
export const DEFAULT_FROM_URL_OPTIONS: Partial<TextureFromURLOptions> = {
  generateMipmaps: true,
  format: 'rgba8unorm',
  usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
  flipY: false,
  premultiplyAlpha: false,
  colorSpace: 'srgb'
};

/**
 * 默认渲染目标选项
 */
export const DEFAULT_RENDER_TARGET_OPTIONS: Partial<RenderTargetOptions> = {
  colorFormat: 'rgba8unorm',
  depthFormat: 'depth24plus',
  sampleCount: 1,
  hasDepth: true,
  mipLevelCount: 1
};

/**
 * 纹理类
 * 封装 WebGPU 纹理的创建、加载和管理
 */
export class Texture {
  private device: GPUDevice;
  private texture: GPUTexture;
  private view: GPUTextureView;
  private sampler?: GPUSampler;
  private width: number;
  private height: number;
  private format: GPUTextureFormat;
  private mipLevelCount: number;
  private label?: string;

  constructor(device: GPUDevice, texture: GPUTexture, options: TextureOptions) {
    this.device = device;
    this.texture = texture;
    this.width = options.width;
    this.height = options.height;
    this.format = options.format || 'rgba8unorm';
    this.mipLevelCount = options.mipLevelCount || 1;
    this.label = options.label;

    // 创建默认视图
    this.view = this.texture.createView({
      label: this.label ? `${this.label}-view` : 'texture-view'
    });
  }

  /**
   * 创建纹理采样器
   */
  createSampler(descriptor?: GPUSamplerDescriptor): GPUSampler {
    const defaultDescriptor: GPUSamplerDescriptor = {
      label: this.label ? `${this.label}-sampler` : 'texture-sampler',
      magFilter: 'linear',
      minFilter: 'linear',
      mipmapFilter: this.mipLevelCount > 1 ? 'linear' : 'nearest',
      addressModeU: 'repeat',
      addressModeV: 'repeat',
      addressModeW: 'repeat'
    };

    this.sampler = this.device.createSampler({
      ...defaultDescriptor,
      ...descriptor
    });

    return this.sampler;
  }

  /**
   * 获取纹理
   */
  getTexture(): GPUTexture {
    return this.texture;
  }

  /**
   * 获取纹理视图
   */
  getView(): GPUTextureView {
    return this.view;
  }

  /**
   * 获取采样器
   */
  getSampler(): GPUSampler | undefined {
    return this.sampler;
  }

  /**
   * 创建指定mip级别的视图
   */
  createMipView(baseMipLevel: number, mipLevelCount: number = 1): GPUTextureView {
    return this.texture.createView({
      label: this.label ? `${this.label}-mip-${baseMipLevel}-view` : `texture-mip-${baseMipLevel}-view`,
      baseMipLevel,
      mipLevelCount
    });
  }

  /**
   * 创建指定数组层的视图
   */
  createArrayView(baseArrayLayer: number, arrayLayerCount: number = 1): GPUTextureView {
    return this.texture.createView({
      label: this.label ? `${this.label}-array-${baseArrayLayer}-view` : `texture-array-${baseArrayLayer}-view`,
      baseArrayLayer,
      arrayLayerCount
    });
  }

  /**
   * 更新纹理数据
   */
  updateData(
    data: ArrayBufferView,
    options?: {
      offset?: GPUOrigin3D;
      size?: GPUExtent3D;
      mipLevel?: number;
      bytesPerRow?: number;
      rowsPerImage?: number;
    }
  ): void {
    const writeOptions = {
      texture: this.texture,
      mipLevel: options?.mipLevel || 0,
      origin: options?.offset || [0, 0, 0]
    };

    const dataLayout = {
      bytesPerRow: options?.bytesPerRow || this.width * 4, // 假设 RGBA8
      rowsPerImage: options?.rowsPerImage || this.height
    };

    const size = options?.size || [this.width, this.height, 1];

    this.device.queue.writeTexture(writeOptions, data, dataLayout, size);
  }

  /**
   * 获取纹理属性
   */
  getWidth(): number { return this.width; }
  getHeight(): number { return this.height; }
  getFormat(): GPUTextureFormat { return this.format; }
  getMipLevelCount(): number { return this.mipLevelCount; }
  getLabel(): string | undefined { return this.label; }

  /**
   * 销毁纹理
   */
  destroy(): void {
    this.texture.destroy();
  }

  /**
   * 静态方法：创建自定义纹理
   */
  static create(device: GPUDevice, options: TextureOptions): Texture {
    const finalOptions = { ...DEFAULT_TEXTURE_OPTIONS, ...options };

    const textureDescriptor: GPUTextureDescriptor = {
      label: finalOptions.label || 'custom-texture',
      size: [options.width, options.height, finalOptions.arrayLayerCount!],
      format: finalOptions.format!,
      usage: finalOptions.usage!,
      mipLevelCount: finalOptions.mipLevelCount!,
      sampleCount: finalOptions.sampleCount!,
      dimension: finalOptions.dimension!
    };

    const texture = device.createTexture(textureDescriptor);
    return new Texture(device, texture, finalOptions as TextureOptions);
  }

  /**
   * 静态方法：从URL加载纹理
   */
  static async fromURL(device: GPUDevice, url: string, options?: TextureFromURLOptions): Promise<Texture> {
    const finalOptions = { ...DEFAULT_FROM_URL_OPTIONS, ...options };

    // 加载图片
    const img = new Image();
    img.crossOrigin = 'anonymous';
    
    await new Promise<void>((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(new Error(`Failed to load image from ${url}`));
      img.src = url;
    });

    // 创建canvas并绘制图片
    const canvas = document.createElement('canvas');
    canvas.width = img.width;
    canvas.height = img.height;
    
    const ctx = canvas.getContext('2d')!;
    
    // 如果需要翻转Y轴
    if (finalOptions.flipY) {
      ctx.scale(1, -1);
      ctx.translate(0, -canvas.height);
    }
    
    ctx.drawImage(img, 0, 0);

    // 获取图片数据
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

    // 计算mip级别
    const mipLevelCount = finalOptions.generateMipmaps 
      ? Math.floor(Math.log2(Math.max(img.width, img.height))) + 1 
      : 1;

    // 创建纹理
    const textureOptions: TextureOptions = {
      width: img.width,
      height: img.height,
      format: finalOptions.format!,
      usage: finalOptions.usage!,
      mipLevelCount,
      label: finalOptions.label || `texture-from-${url.split('/').pop()}`
    };

    const texture = Texture.create(device, textureOptions);

    // 上传数据到GPU
    texture.updateData(imageData.data);

    // 生成mipmap（如果需要）
    if (finalOptions.generateMipmaps && mipLevelCount > 1) {
      texture.generateMipmaps();
    }

    return texture;
  }

  /**
   * 静态方法：创建渲染目标
   */
  static createRenderTarget(device: GPUDevice, options: RenderTargetOptions): {
    colorTexture: Texture;
    depthTexture?: Texture;
  } {
    const finalOptions = { ...DEFAULT_RENDER_TARGET_OPTIONS, ...options };

    // 创建颜色纹理
    const colorTextureOptions: TextureOptions = {
      width: options.width,
      height: options.height,
      format: finalOptions.colorFormat!,
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
      mipLevelCount: finalOptions.mipLevelCount!,
      sampleCount: finalOptions.sampleCount!,
      label: finalOptions.label ? `${finalOptions.label}-color` : 'render-target-color'
    };

    const colorTexture = Texture.create(device, colorTextureOptions);

    let depthTexture: Texture | undefined;

    // 创建深度纹理（如果需要）
    if (finalOptions.hasDepth) {
      const depthTextureOptions: TextureOptions = {
        width: options.width,
        height: options.height,
        format: finalOptions.depthFormat!,
        usage: GPUTextureUsage.RENDER_ATTACHMENT,
        mipLevelCount: 1, // 深度纹理通常不需要mipmap
        sampleCount: finalOptions.sampleCount!,
        label: finalOptions.label ? `${finalOptions.label}-depth` : 'render-target-depth'
      };

      depthTexture = Texture.create(device, depthTextureOptions);
    }

    return { colorTexture, depthTexture };
  }

  /**
   * 静态方法：创建深度纹理
   */
  static createDepthTexture(
    device: GPUDevice, 
    width: number, 
    height: number, 
    format: GPUTextureFormat = 'depth24plus',
    sampleCount: number = 1,
    label?: string
  ): Texture {
    const options: TextureOptions = {
      width,
      height,
      format,
      usage: GPUTextureUsage.RENDER_ATTACHMENT,
      mipLevelCount: 1,
      sampleCount,
      label: label || 'depth-texture'
    };

    return Texture.create(device, options);
  }

  /**
   * 静态方法：创建立方体贴图
   */
  static createCubeMap(
    device: GPUDevice,
    size: number,
    format: GPUTextureFormat = 'rgba8unorm',
    usage?: GPUTextureUsageFlags,
    label?: string
  ): Texture {
    const options: TextureOptions = {
      width: size,
      height: size,
      format,
      usage: usage || (GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST),
      arrayLayerCount: 6, // 立方体贴图有6个面
      dimension: '2d',
      label: label || 'cubemap-texture'
    };

    return Texture.create(device, options);
  }

  /**
   * 生成mipmap（简化实现，实际项目中可能需要更复杂的算法）
   */
  private generateMipmaps(): void {
    // 这里需要实现mipmap生成逻辑
    // 可以使用计算着色器或复制操作来生成
    console.warn('Mipmap generation not implemented yet');
  }

  /**
   * 静态方法：创建纯色纹理
   */
  static createSolidColor(
    device: GPUDevice,
    color: [number, number, number, number],
    width: number = 1,
    height: number = 1,
    label?: string
  ): Texture {
    const texture = Texture.create(device, {
      width,
      height,
      format: 'rgba8unorm',
      usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
      label: label || 'solid-color-texture'
    });

    // 创建颜色数据
    const data = new Uint8Array(width * height * 4);
    for (let i = 0; i < width * height; i++) {
      const offset = i * 4;
      data[offset] = Math.floor(color[0] * 255);     // R
      data[offset + 1] = Math.floor(color[1] * 255); // G
      data[offset + 2] = Math.floor(color[2] * 255); // B
      data[offset + 3] = Math.floor(color[3] * 255); // A
    }

    texture.updateData(data);
    return texture;
  }
} 