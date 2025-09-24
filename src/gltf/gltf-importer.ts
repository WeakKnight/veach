import { Document } from '@gltf-transform/core';
import { Mesh } from '../mesh';
import { Texture } from '../texture';
import { GLTFImportResult, GLTFImporterOptions, GLTFImportError, DEFAULT_GLTF_OPTIONS } from './gltf-types';
import { GLTFUtils } from './gltf-utils';
import { GLTFMeshExtractor } from './mesh-extractor';
import { GLTFTextureExtractor } from './texture-extractor';

/**
 * glTF 导入器
 * 负责从 glTF 文件导入网格和纹理数据
 * 
 * 使用示例:
 * ```typescript
 * import { GLTFImporter } from './gltf/gltf-importer';
 * 
 * // 创建导入器
 * const importer = new GLTFImporter(device, {
 *   generateMipmaps: true,
 *   textureFormat: 'rgba8unorm',
 *   optimizeMeshes: true
 * });
 * 
 * // 导入 glTF 文件
 * const result = await importer.importFromFile('assets/model.gltf');
 * 
 * // 使用导入的数据
 * const meshes = result.meshes;
 * const textures = result.textures;
 * 
 * // 在渲染器中使用
 * if (result.meshes.length > 0) {
 *   const mesh = result.meshes[0];
 *   console.log(`网格: ${mesh.getVertexCount()} 顶点, ${mesh.getIndexCount()} 索引`);
 * }
 * 
 * if (result.textures.length > 0) {
 *   const texture = result.textures[0];
 *   console.log(`纹理: ${texture.getWidth()}x${texture.getHeight()}`);
 * }
 * ```
 */
export class GLTFImporter {
  private device: GPUDevice;
  private options: GLTFImporterOptions;

  constructor(device: GPUDevice, options?: Partial<GLTFImporterOptions>) {
    this.device = device;
    this.options = { ...DEFAULT_GLTF_OPTIONS, ...options } as GLTFImporterOptions;
  }

  /**
   * 从文件路径导入 glTF
   */
  async importFromFile(filePath: string): Promise<GLTFImportResult> {
    try {
      console.log(`Importing glTF from file: ${filePath}`);
      
      // 读取文档
      const document = await GLTFUtils.readDocumentFromFile(filePath);
      
      // 验证文档
      if (!GLTFUtils.validateDocument(document)) {
        throw new GLTFImportError('Invalid glTF document');
      }

      // 检查兼容性
      if (!GLTFUtils.isWebGPUCompatible(document)) {
        console.warn('glTF document may not be fully compatible with WebGPU');
      }

      // 打印统计信息
      const stats = GLTFUtils.getDocumentStats(document);
      console.log('glTF document stats:', stats);

      // 提取数据
      return await this.extractData(document);
    } catch (error) {
      throw new GLTFImportError(`Failed to import glTF from file: ${filePath}`, error as Error);
    }
  }

  /**
   * 从 ArrayBuffer 导入 glTF
   */
  async importFromBuffer(buffer: ArrayBuffer): Promise<GLTFImportResult> {
    try {
      console.log('Importing glTF from buffer');
      
      // 读取文档
      const document = await GLTFUtils.readDocumentFromBuffer(buffer);
      
      // 验证文档
      if (!GLTFUtils.validateDocument(document)) {
        throw new GLTFImportError('Invalid glTF document');
      }

      // 检查兼容性
      if (!GLTFUtils.isWebGPUCompatible(document)) {
        console.warn('glTF document may not be fully compatible with WebGPU');
      }

      // 打印统计信息
      const stats = GLTFUtils.getDocumentStats(document);
      console.log('glTF document stats:', stats);

      // 提取数据
      return await this.extractData(document);
    } catch (error) {
      throw new GLTFImportError('Failed to import glTF from buffer', error as Error);
    }
  }

  /**
   * 从 URL 导入 glTF
   */
  async importFromURL(url: string): Promise<GLTFImportResult> {
    try {
      console.log(`Importing glTF from URL: ${url}`);
      
      // 读取文档
      const document = await GLTFUtils.readDocumentFromURL(url);
      
      // 验证文档
      if (!GLTFUtils.validateDocument(document)) {
        throw new GLTFImportError('Invalid glTF document');
      }

      // 检查兼容性
      if (!GLTFUtils.isWebGPUCompatible(document)) {
        console.warn('glTF document may not be fully compatible with WebGPU');
      }

      // 打印统计信息
      const stats = GLTFUtils.getDocumentStats(document);
      console.log('glTF document stats:', stats);

      // 提取数据
      return await this.extractData(document);
    } catch (error) {
      throw new GLTFImportError(`Failed to import glTF from URL: ${url}`, error as Error);
    }
  }

  /**
   * 从文档提取数据
   */
  private async extractData(document: Document): Promise<GLTFImportResult> {
    try {
      console.log('Extracting meshes...');
      const meshes = GLTFMeshExtractor.extractMeshes(document, this.device);
      console.log(`Extracted ${meshes.length} meshes`);

      console.log('Extracting textures...');
      const textures = await GLTFTextureExtractor.extractTextures(document, this.device);
      console.log(`Extracted ${textures.length} textures`);

      // 打印纹理统计信息
      if (textures.length > 0) {
        const textureStats = GLTFTextureExtractor.getTextureStats(textures);
        console.log('Texture stats:', textureStats);
      }

      return {
        meshes,
        textures
      };
    } catch (error) {
      throw new GLTFImportError('Failed to extract data from glTF document', error as Error);
    }
  }

  /**
   * 获取导入器选项
   */
  getOptions(): GLTFImporterOptions {
    return { ...this.options };
  }

  /**
   * 更新导入器选项
   */
  updateOptions(newOptions: Partial<GLTFImporterOptions>): void {
    this.options = { ...this.options, ...newOptions };
  }

  /**
   * 检查是否支持指定的 glTF 文件
   */
  static async isSupported(filePath: string): Promise<boolean> {
    try {
      const document = await GLTFUtils.readDocumentFromFile(filePath);
      return GLTFUtils.validateDocument(document) && GLTFUtils.isWebGPUCompatible(document);
    } catch (error) {
      console.error('Failed to check glTF support:', error);
      return false;
    }
  }

  /**
   * 获取 glTF 文件信息（不导入数据）
   */
  static async getFileInfo(filePath: string): Promise<{
    stats: any;
    supported: boolean;
    warnings: string[];
  }> {
    try {
      const document = await GLTFUtils.readDocumentFromFile(filePath);
      const stats = GLTFUtils.getDocumentStats(document);
      const supported = GLTFUtils.validateDocument(document) && GLTFUtils.isWebGPUCompatible(document);
      
      const warnings: string[] = [];
      if (!GLTFUtils.validateDocument(document)) {
        warnings.push('Invalid glTF document');
      }
      if (!GLTFUtils.isWebGPUCompatible(document)) {
        warnings.push('May not be fully compatible with WebGPU');
      }

      return { stats, supported, warnings };
    } catch (error) {
      throw new GLTFImportError(`Failed to get file info: ${filePath}`, error as Error);
    }
  }
}
