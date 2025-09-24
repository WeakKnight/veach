import { Document, NodeIO, PlatformIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { GLTFImportError } from './gltf-types';

/**
 * 自定义 IO 类，使用项目的文件系统接口
 */
class CustomIO extends PlatformIO {
  protected async readURI(uri: string, type: 'view'): Promise<Uint8Array>;
  protected async readURI(uri: string, type: 'text'): Promise<string>;
  protected async readURI(uri: string, type: 'view' | 'text'): Promise<Uint8Array | string> {
    if (type === 'view') {
      const data = await window.fs.readBinaryFile(uri);
      return new Uint8Array(data);
    } else {
      return await window.fs.readTextFile(uri);
    }
  }

  protected resolve(base: string, path: string): string {
    // 简单的路径解析，可以根据需要改进
    if (path.startsWith('/') || path.includes('://')) {
      return path;
    }
    return base + '/' + path;
  }

  protected dirname(uri: string): string {
    const lastSlash = uri.lastIndexOf('/');
    return lastSlash >= 0 ? uri.substring(0, lastSlash) : '';
  }
}

/**
 * glTF 工具类
 */
export class GLTFUtils {
  /**
   * 创建配置好的 glTF I/O 实例
   */
  static createIO(): CustomIO {
    return new CustomIO().registerExtensions(ALL_EXTENSIONS);
  }

  /**
   * 从文件路径读取 glTF 文档
   */
  static async readDocumentFromFile(filePath: string): Promise<Document> {
    try {
      const io = this.createIO();
      const document = await io.read(filePath);
      return document;
    } catch (error) {
      throw new GLTFImportError(`Failed to read glTF file: ${filePath}`, error as Error);
    }
  }

  /**
   * 从 ArrayBuffer 读取 glTF 文档
   */
  static async readDocumentFromBuffer(buffer: ArrayBuffer): Promise<Document> {
    try {
      const io = this.createIO();
      // 将 ArrayBuffer 转换为 Uint8Array
      const uint8Array = new Uint8Array(buffer);
      const document = await io.readBinary(uint8Array);
      return document;
    } catch (error) {
      throw new GLTFImportError('Failed to read glTF from buffer', error as Error);
    }
  }

  /**
   * 从 JSON 字符串读取 glTF 文档
   */
  static async readDocumentFromJSON(jsonString: string): Promise<Document> {
    try {
      const io = this.createIO();
      // 解析 JSON 并创建文档
      const gltfData = JSON.parse(jsonString);
      const document = await io.readJSON(gltfData);
      return document;
    } catch (error) {
      throw new GLTFImportError('Failed to read glTF from JSON', error as Error);
    }
  }

  /**
   * 从 URL 读取 glTF 文档
   */
  static async readDocumentFromURL(url: string): Promise<Document> {
    try {
      const io = this.createIO();
      const document = await io.read(url);
      return document;
    } catch (error) {
      throw new GLTFImportError(`Failed to read glTF from URL: ${url}`, error as Error);
    }
  }

  /**
   * 验证 glTF 文档是否有效
   */
  static validateDocument(document: Document): boolean {
    try {
      // 检查是否有网格
      const meshes = document.getRoot().listMeshes();
      if (meshes.length === 0) {
        console.warn('No meshes found in glTF document');
        return false;
      }

      // 检查是否有场景
      const scenes = document.getRoot().listScenes();
      if (scenes.length === 0) {
        console.warn('No scenes found in glTF document');
        return false;
      }

      return true;
    } catch (error) {
      console.error('Failed to validate glTF document:', error);
      return false;
    }
  }

  /**
   * 获取文档中的所有网格
   */
  static getMeshesFromDocument(document: Document) {
    return document.getRoot().listMeshes();
  }

  /**
   * 获取文档中的所有纹理
   */
  static getTexturesFromDocument(document: Document) {
    return document.getRoot().listTextures();
  }

  /**
   * 获取文档中的所有图像
   */
  static getImagesFromDocument(document: Document) {
    return document.getRoot().listTextures();
  }

  /**
   * 获取文档中的所有材质
   */
  static getMaterialsFromDocument(document: Document) {
    return document.getRoot().listMaterials();
  }

  /**
   * 获取文档中的所有节点
   */
  static getNodesFromDocument(document: Document) {
    return document.getRoot().listNodes();
  }

  /**
   * 获取文档中的所有场景
   */
  static getScenesFromDocument(document: Document) {
    return document.getRoot().listScenes();
  }

  /**
   * 检查 glTF 是否支持 WebGPU
   */
  static isWebGPUCompatible(document: Document): boolean {
    try {
      // 检查是否有不兼容的扩展
      const incompatibleExtensions = [
        'KHR_draco_mesh_compression', // 需要解码器
        'EXT_meshopt_compression',    // 需要解码器
        'KHR_texture_basisu'         // 需要解码器
      ];

      // 检查扩展是否被使用
      for (const extName of incompatibleExtensions) {
        const ext = document.getRoot().getExtension(extName);
        if (ext) {
          console.warn(`Extension ${extName} may not be fully supported`);
        }
      }

      return true;
    } catch (error) {
      console.error('Failed to check WebGPU compatibility:', error);
      return false;
    }
  }

  /**
   * 获取文档统计信息
   */
  static getDocumentStats(document: Document) {
    const meshes = this.getMeshesFromDocument(document);
    const textures = this.getTexturesFromDocument(document);
    const images = this.getImagesFromDocument(document);
    const materials = this.getMaterialsFromDocument(document);
    const nodes = this.getNodesFromDocument(document);
    const scenes = this.getScenesFromDocument(document);

    return {
      meshCount: meshes.length,
      textureCount: textures.length,
      imageCount: images.length,
      materialCount: materials.length,
      nodeCount: nodes.length,
      sceneCount: scenes.length
    };
  }
}
