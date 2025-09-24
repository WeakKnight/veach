import { Document, Texture as GLTFTexture, Image as GLTFImage } from '@gltf-transform/core';
import { Texture } from '../texture';
import { GLTFTextureData } from './gltf-types';
import { GLTFImportError } from './gltf-types';

/**
 * glTF 纹理提取器
 */
export class GLTFTextureExtractor {
  /**
   * 从 glTF 文档提取所有纹理
   */
  static async extractTextures(document: Document, device: GPUDevice): Promise<Texture[]> {
    const gltfTextures = document.getRoot().listTextures();
    const textures: Texture[] = [];

    for (let i = 0; i < gltfTextures.length; i++) {
      const gltfTexture = gltfTextures[i];
      try {
        const texture = await this.extractSingleTexture(gltfTexture, device, i);
        if (texture) {
          textures.push(texture);
        }
      } catch (error) {
        console.error(`Failed to extract texture ${i}:`, error);
        // 继续处理其他纹理
      }
    }

    return textures;
  }

  /**
   * 提取单个纹理
   */
  private static async extractSingleTexture(gltfTexture: GLTFTexture, device: GPUDevice, index: number): Promise<Texture | null> {
    try {
      const image = gltfTexture.getImage();
      if (!image) {
        console.warn(`Texture ${index} has no image data`);
        return null;
      }

      const textureData = await this.extractImageData(image, gltfTexture.getMimeType());
      if (!textureData) {
        console.warn(`Failed to extract image data for texture ${index}`);
        return null;
      }

      return await this.createTextureFromData(textureData, device, gltfTexture.getName() || `texture-${index}`);
    } catch (error) {
      console.error(`Failed to extract texture ${index}:`, error);
      return null;
    }
  }

  /**
   * 从 glTF 图像提取数据
   */
  private static async extractImageData(imageData: Uint8Array, mimeType: string): Promise<GLTFTextureData | null> {
    try {
      // 创建 Blob 并加载为 ImageBitmap
      const blob = new Blob([imageData], { type: mimeType || 'image/png' });
      const imageBitmap = await createImageBitmap(blob);

      return {
        imageData: imageData.buffer,
        width: imageBitmap.width,
        height: imageBitmap.height,
        format: mimeType || 'image/png',
        name: 'texture'
      };
    } catch (error) {
      console.error('Failed to extract image data:', error);
      return null;
    }
  }

  /**
   * 从纹理数据创建 Texture 对象
   */
  private static async createTextureFromData(textureData: GLTFTextureData, device: GPUDevice, name: string): Promise<Texture> {
    try {
      // 创建 Blob 并加载为 ImageBitmap
      const blob = new Blob([textureData.imageData], { type: textureData.format });
      const imageBitmap = await createImageBitmap(blob);

      // 创建 Canvas 并绘制图像
      const canvas = document.createElement('canvas');
      canvas.width = imageBitmap.width;
      canvas.height = imageBitmap.height;
      
      const ctx = canvas.getContext('2d')!;
      ctx.drawImage(imageBitmap, 0, 0);

      // 获取图像数据
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

      // 创建 WebGPU 纹理
      const texture = Texture.create(device, {
        width: textureData.width,
        height: textureData.height,
        format: 'rgba8unorm',
        usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
        mipLevelCount: 1,
        label: name
      });

      // 上传数据到 GPU
      texture.updateData(imageData.data);

      return texture;
    } catch (error) {
      throw new GLTFImportError(`Failed to create texture from data: ${error}`);
    }
  }

  /**
   * 从 URL 加载纹理（用于外部纹理）
   */
  static async loadTextureFromURL(device: GPUDevice, url: string, name?: string): Promise<Texture> {
    try {
      return await Texture.fromURL(device, url, {
        generateMipmaps: true,
        format: 'rgba8unorm',
        label: name || `texture-from-${url.split('/').pop()}`
      });
    } catch (error) {
      throw new GLTFImportError(`Failed to load texture from URL: ${url}`, error as Error);
    }
  }

  /**
   * 创建默认纹理（当纹理加载失败时使用）
   */
  static createDefaultTexture(device: GPUDevice, name?: string): Texture {
    return Texture.createSolidColor(
      device,
      [0.5, 0.5, 0.5, 1.0], // 灰色
      1,
      1,
      name || 'default-texture'
    );
  }

  /**
   * 检查纹理格式是否支持
   */
  static isTextureFormatSupported(format: string): boolean {
    const supportedFormats = [
      'image/png',
      'image/jpeg',
      'image/jpg',
      'image/webp'
    ];
    
    return supportedFormats.includes(format.toLowerCase());
  }

  /**
   * 获取纹理统计信息
   */
  static getTextureStats(textures: Texture[]): {
    count: number;
    totalSize: number;
    formats: { [key: string]: number };
  } {
    const stats = {
      count: textures.length,
      totalSize: 0,
      formats: {} as { [key: string]: number }
    };

    for (const texture of textures) {
      const width = texture.getWidth();
      const height = texture.getHeight();
      const format = texture.getFormat();
      
      // 估算纹理大小（假设每个像素4字节）
      const size = width * height * 4;
      stats.totalSize += size;
      
      // 统计格式
      stats.formats[format] = (stats.formats[format] || 0) + 1;
    }

    return stats;
  }
}
