import { GPUBufferWrapper } from './gpu-buffer';

/**
 * 顶点数据结构定义
 * 包含: uv0(2), uv1(2), position(3), normal(3), tangent(4)
 * 总共 14 个 float32 值 = 56 字节
 */
export interface VertexData {
  uv0: [number, number];           // 2 floats - 纹理坐标0
  uv1: [number, number];           // 2 floats - 纹理坐标1
  position: [number, number, number]; // 3 floats - 位置
  normal: [number, number, number];   // 3 floats - 法线
  tangent: [number, number, number, number]; // 4 floats - 切线(xyz + w符号位)
}

/**
 * 顶点属性布局常量
 */
export const VERTEX_LAYOUT = {
  UV0_OFFSET: 0,      // 偏移 0 字节
  UV1_OFFSET: 8,      // 偏移 8 字节
  POSITION_OFFSET: 16, // 偏移 16 字节
  NORMAL_OFFSET: 28,   // 偏移 28 字节
  TANGENT_OFFSET: 40,  // 偏移 40 字节
  STRIDE: 56           // 每个顶点 56 字节
} as const;

/**
 * Mesh 类 - 管理顶点和索引数据
 */
export class Mesh {
  private device: GPUDevice;
  private vertexBuffer: GPUBufferWrapper;
  private indexBuffer: GPUBufferWrapper;
  private vertexCount: number;
  private indexCount: number;

  constructor(
    device: GPUDevice,
    vertices: VertexData[],
    indices: number[],
    label?: string
  ) {
    this.device = device;
    this.vertexCount = vertices.length;
    this.indexCount = indices.length;

    // 创建顶点缓冲区
    const vertexData = this.packVertexData(vertices);
    this.vertexBuffer = GPUBufferWrapper.createVertexBuffer(
      device,
      vertexData.byteLength,
      label ? `${label}-vertices` : 'mesh-vertices'
    );
    this.vertexBuffer.setData(vertexData);

    // 创建索引缓冲区
    const indexData = new Uint32Array(indices);
    this.indexBuffer = GPUBufferWrapper.createIndexBuffer(
      device,
      indexData.byteLength,
      label ? `${label}-indices` : 'mesh-indices'
    );
    this.indexBuffer.setData(indexData);
  }

  /**
   * 将顶点数据打包成 Float32Array
   */
  private packVertexData(vertices: VertexData[]): Float32Array {
    const packedData = new Float32Array(vertices.length * 14); // 每个顶点14个float
    
    for (let i = 0; i < vertices.length; i++) {
      const vertex = vertices[i];
      const offset = i * 14;
      
      // uv0 (2 floats)
      packedData[offset + 0] = vertex.uv0[0];
      packedData[offset + 1] = vertex.uv0[1];
      
      // uv1 (2 floats)
      packedData[offset + 2] = vertex.uv1[0];
      packedData[offset + 3] = vertex.uv1[1];
      
      // position (3 floats)
      packedData[offset + 4] = vertex.position[0];
      packedData[offset + 5] = vertex.position[1];
      packedData[offset + 6] = vertex.position[2];
      
      // normal (3 floats)
      packedData[offset + 7] = vertex.normal[0];
      packedData[offset + 8] = vertex.normal[1];
      packedData[offset + 9] = vertex.normal[2];
      
      // tangent (4 floats)
      packedData[offset + 10] = vertex.tangent[0];
      packedData[offset + 11] = vertex.tangent[1];
      packedData[offset + 12] = vertex.tangent[2];
      packedData[offset + 13] = vertex.tangent[3];
    }
    
    return packedData;
  }

  /**
   * 获取顶点缓冲区
   */
  getVertexBuffer(): GPUBufferWrapper {
    return this.vertexBuffer;
  }

  /**
   * 获取索引缓冲区
   */
  getIndexBuffer(): GPUBufferWrapper {
    return this.indexBuffer;
  }

  /**
   * 获取顶点数量
   */
  getVertexCount(): number {
    return this.vertexCount;
  }

  /**
   * 获取索引数量
   */
  getIndexCount(): number {
    return this.indexCount;
  }

  /**
   * 更新顶点数据
   */
  updateVertices(vertices: VertexData[], offset: number = 0): void {
    const vertexData = this.packVertexData(vertices);
    this.vertexBuffer.setData(vertexData, offset * VERTEX_LAYOUT.STRIDE);
  }

  /**
   * 更新索引数据
   */
  updateIndices(indices: number[], offset: number = 0): void {
    const indexData = new Uint32Array(indices);
    this.indexBuffer.setData(indexData, offset * 4); // 每个索引4字节
  }

  /**
   * 读取顶点数据
   */
  async readVertices(offset: number = 0, count?: number): Promise<VertexData[]> {
    const readCount = count || this.vertexCount - offset;
    const byteOffset = offset * VERTEX_LAYOUT.STRIDE;
    const byteSize = readCount * VERTEX_LAYOUT.STRIDE;
    
    const data = await this.vertexBuffer.readData(byteOffset, byteSize);
    const floatData = new Float32Array(data);
    
    const vertices: VertexData[] = [];
    for (let i = 0; i < readCount; i++) {
      const floatOffset = i * 14;
      vertices.push({
        uv0: [floatData[floatOffset + 0], floatData[floatOffset + 1]],
        uv1: [floatData[floatOffset + 2], floatData[floatOffset + 3]],
        position: [floatData[floatOffset + 4], floatData[floatOffset + 5], floatData[floatOffset + 6]],
        normal: [floatData[floatOffset + 7], floatData[floatOffset + 8], floatData[floatOffset + 9]],
        tangent: [floatData[floatOffset + 10], floatData[floatOffset + 11], floatData[floatOffset + 12], floatData[floatOffset + 13]]
      });
    }
    
    return vertices;
  }

  /**
   * 读取索引数据
   */
  async readIndices(offset: number = 0, count?: number): Promise<number[]> {
    const readCount = count || this.indexCount - offset;
    const byteOffset = offset * 4;
    const byteSize = readCount * 4;
    
    const data = await this.indexBuffer.readData(byteOffset, byteSize);
    const indexData = new Uint32Array(data);
    
    return Array.from(indexData);
  }

  /**
   * 获取顶点属性布局描述（用于渲染管线）
   */
  static getVertexBufferLayout(): GPUVertexBufferLayout {
    return {
      arrayStride: VERTEX_LAYOUT.STRIDE,
      stepMode: 'vertex',
      attributes: [
        // uv0
        {
          shaderLocation: 0,
          offset: VERTEX_LAYOUT.UV0_OFFSET,
          format: 'float32x2'
        },
        // uv1
        {
          shaderLocation: 1,
          offset: VERTEX_LAYOUT.UV1_OFFSET,
          format: 'float32x2'
        },
        // position
        {
          shaderLocation: 2,
          offset: VERTEX_LAYOUT.POSITION_OFFSET,
          format: 'float32x3'
        },
        // normal
        {
          shaderLocation: 3,
          offset: VERTEX_LAYOUT.NORMAL_OFFSET,
          format: 'float32x3'
        },
        // tangent
        {
          shaderLocation: 4,
          offset: VERTEX_LAYOUT.TANGENT_OFFSET,
          format: 'float32x4'
        }
      ]
    };
  }

  /**
   * 销毁 Mesh 资源
   */
  destroy(): void {
    this.vertexBuffer.destroy();
    this.indexBuffer.destroy();
  }

  /**
   * 静态方法：创建一个简单的四边形网格
   */
  static createQuad(device: GPUDevice, size: number = 1.0, label?: string): Mesh {
    const halfSize = size * 0.5;
    
    const vertices: VertexData[] = [
      // 左下
      {
        uv0: [0, 1],
        uv1: [0, 1],
        position: [-halfSize, -halfSize, 0],
        normal: [0, 0, 1],
        tangent: [1, 0, 0, 1]
      },
      // 右下
      {
        uv0: [1, 1],
        uv1: [1, 1],
        position: [halfSize, -halfSize, 0],
        normal: [0, 0, 1],
        tangent: [1, 0, 0, 1]
      },
      // 右上
      {
        uv0: [1, 0],
        uv1: [1, 0],
        position: [halfSize, halfSize, 0],
        normal: [0, 0, 1],
        tangent: [1, 0, 0, 1]
      },
      // 左上
      {
        uv0: [0, 0],
        uv1: [0, 0],
        position: [-halfSize, halfSize, 0],
        normal: [0, 0, 1],
        tangent: [1, 0, 0, 1]
      }
    ];

    const indices = [
      0, 1, 2,  // 第一个三角形
      0, 2, 3   // 第二个三角形
    ];

    return new Mesh(device, vertices, indices, label || 'quad');
  }

  /**
   * 静态方法：创建一个立方体网格
   */
  static createCube(device: GPUDevice, size: number = 1.0, label?: string): Mesh {
    const halfSize = size * 0.5;
    
    // 创建立方体的24个顶点（每个面4个顶点）
    const vertices: VertexData[] = [];
    const indices: number[] = [];

    // 定义立方体的6个面
    const faces = [
      // 前面 (Z+)
      { normal: [0, 0, 1], tangent: [1, 0, 0, 1], positions: [
        [-halfSize, -halfSize, halfSize], [halfSize, -halfSize, halfSize],
        [halfSize, halfSize, halfSize], [-halfSize, halfSize, halfSize]
      ]},
      // 后面 (Z-)
      { normal: [0, 0, -1], tangent: [-1, 0, 0, 1], positions: [
        [halfSize, -halfSize, -halfSize], [-halfSize, -halfSize, -halfSize],
        [-halfSize, halfSize, -halfSize], [halfSize, halfSize, -halfSize]
      ]},
      // 右面 (X+)
      { normal: [1, 0, 0], tangent: [0, 0, -1, 1], positions: [
        [halfSize, -halfSize, halfSize], [halfSize, -halfSize, -halfSize],
        [halfSize, halfSize, -halfSize], [halfSize, halfSize, halfSize]
      ]},
      // 左面 (X-)
      { normal: [-1, 0, 0], tangent: [0, 0, 1, 1], positions: [
        [-halfSize, -halfSize, -halfSize], [-halfSize, -halfSize, halfSize],
        [-halfSize, halfSize, halfSize], [-halfSize, halfSize, -halfSize]
      ]},
      // 上面 (Y+)
      { normal: [0, 1, 0], tangent: [1, 0, 0, 1], positions: [
        [-halfSize, halfSize, halfSize], [halfSize, halfSize, halfSize],
        [halfSize, halfSize, -halfSize], [-halfSize, halfSize, -halfSize]
      ]},
      // 下面 (Y-)
      { normal: [0, -1, 0], tangent: [1, 0, 0, 1], positions: [
        [-halfSize, -halfSize, -halfSize], [halfSize, -halfSize, -halfSize],
        [halfSize, -halfSize, halfSize], [-halfSize, -halfSize, halfSize]
      ]}
    ];

    const uvs = [[0, 1], [1, 1], [1, 0], [0, 0]];

    faces.forEach((face, faceIndex) => {
      const startIndex = vertices.length;
      
      // 为每个面添加4个顶点
      face.positions.forEach((pos, vertIndex) => {
        vertices.push({
          uv0: uvs[vertIndex] as [number, number],
          uv1: uvs[vertIndex] as [number, number],
          position: pos as [number, number, number],
          normal: face.normal as [number, number, number],
          tangent: face.tangent as [number, number, number, number]
        });
      });

      // 为每个面添加2个三角形的索引
      indices.push(
        startIndex, startIndex + 1, startIndex + 2,
        startIndex, startIndex + 2, startIndex + 3
      );
    });

    return new Mesh(device, vertices, indices, label || 'cube');
  }
} 