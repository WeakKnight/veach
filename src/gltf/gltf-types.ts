import { Mesh } from '../mesh';
import { Texture } from '../texture';

/**
 * glTF 导入结果
 */
export interface GLTFImportResult {
  /** 提取的网格数组 */
  meshes: Mesh[];
  /** 提取的纹理数组 */
  textures: Texture[];
  /** 材质信息（未来扩展） */
  materials?: GLTFMaterial[];
  /** 节点信息（未来扩展） */
  nodes?: GLTFNode[];
}

/**
 * glTF 导入器选项
 */
export interface GLTFImporterOptions {
  /** WebGPU 设备 */
  device: GPUDevice;
  /** 是否生成 mipmap */
  generateMipmaps?: boolean;
  /** 纹理格式 */
  textureFormat?: GPUTextureFormat;
  /** 是否优化网格 */
  optimizeMeshes?: boolean;
  /** 是否翻转纹理Y轴 */
  flipTextureY?: boolean;
}

/**
 * glTF 网格数据（中间格式）
 */
export interface GLTFMeshData {
  /** 顶点数据 */
  vertices: GLTFVertexData[];
  /** 索引数据 */
  indices: number[];
  /** 材质索引 */
  materialIndex?: number;
  /** 网格名称 */
  name?: string;
}

/**
 * glTF 顶点数据（中间格式）
 */
export interface GLTFVertexData {
  /** 位置 */
  position: [number, number, number];
  /** 法线 */
  normal: [number, number, number];
  /** UV坐标 */
  texCoord: [number, number];
}

/**
 * glTF 纹理数据（中间格式）
 */
export interface GLTFTextureData {
  /** 图像数据 */
  imageData: ArrayBuffer;
  /** 宽度 */
  width: number;
  /** 高度 */
  height: number;
  /** 格式 */
  format: string;
  /** 纹理名称 */
  name?: string;
}

/**
 * glTF 材质信息（未来扩展）
 */
export interface GLTFMaterial {
  /** 材质名称 */
  name?: string;
  /** 基础颜色纹理索引 */
  baseColorTextureIndex?: number;
  /** 法线纹理索引 */
  normalTextureIndex?: number;
  /** 金属粗糙度纹理索引 */
  metallicRoughnessTextureIndex?: number;
  /** 基础颜色 */
  baseColor?: [number, number, number, number];
  /** 金属度 */
  metallic?: number;
  /** 粗糙度 */
  roughness?: number;
}

/**
 * glTF 节点信息（未来扩展）
 */
export interface GLTFNode {
  /** 节点名称 */
  name?: string;
  /** 变换矩阵 */
  matrix?: number[];
  /** 平移 */
  translation?: [number, number, number];
  /** 旋转（四元数） */
  rotation?: [number, number, number, number];
  /** 缩放 */
  scale?: [number, number, number];
  /** 子节点索引 */
  children?: number[];
  /** 网格索引 */
  meshIndex?: number;
}

/**
 * glTF 导入错误类型
 */
export class GLTFImportError extends Error {
  constructor(message: string, public cause?: Error) {
    super(message);
    this.name = 'GLTFImportError';
  }
}

/**
 * 默认导入选项
 */
export const DEFAULT_GLTF_OPTIONS: Partial<GLTFImporterOptions> = {
  generateMipmaps: true,
  textureFormat: 'rgba8unorm',
  optimizeMeshes: true,
  flipTextureY: false
};
