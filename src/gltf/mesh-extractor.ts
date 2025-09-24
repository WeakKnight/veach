import { Document, Mesh as GLTFMesh, Primitive, Accessor } from '@gltf-transform/core';
import { Mesh, VertexData } from '../mesh';
import { float2, float3 } from '../math/hlsl-types';
import { GLTFMeshData, GLTFVertexData } from './gltf-types';
import { GLTFImportError } from './gltf-types';

/**
 * glTF 网格提取器
 */
export class GLTFMeshExtractor {
  /**
   * 从 glTF 文档提取所有网格
   */
  static extractMeshes(document: Document, device: GPUDevice): Mesh[] {
    const gltfMeshes = document.getRoot().listMeshes();
    const meshes: Mesh[] = [];

    for (let i = 0; i < gltfMeshes.length; i++) {
      const gltfMesh = gltfMeshes[i];
      try {
        const mesh = this.extractSingleMesh(gltfMesh, device, i);
        if (mesh) {
          meshes.push(mesh);
        }
      } catch (error) {
        console.error(`Failed to extract mesh ${i}:`, error);
        // 继续处理其他网格
      }
    }

    return meshes;
  }

  /**
   * 提取单个网格
   */
  private static extractSingleMesh(gltfMesh: GLTFMesh, device: GPUDevice, index: number): Mesh | null {
    const primitives = gltfMesh.listPrimitives();
    if (primitives.length === 0) {
      console.warn(`Mesh ${index} has no primitives`);
      return null;
    }

    // 目前只处理第一个 primitive
    const primitive = primitives[0];
    const meshData = this.extractPrimitiveData(primitive);
    
    if (!meshData) {
      console.warn(`Failed to extract data from mesh ${index}`);
      return null;
    }

    // 转换为项目中的 Mesh 类
    return this.createMeshFromData(meshData, device, gltfMesh.getName() || `mesh-${index}`);
  }

  /**
   * 从 primitive 提取数据
   */
  private static extractPrimitiveData(primitive: Primitive): GLTFMeshData | null {
    try {
      // 提取顶点数据
      const vertices = this.extractVertices(primitive);
      if (vertices.length === 0) {
        console.warn('No vertices found in primitive');
        return null;
      }

      // 提取索引数据
      const indices = this.extractIndices(primitive);
      if (indices.length === 0) {
        console.warn('No indices found in primitive');
        return null;
      }

      return {
        vertices,
        indices,
        materialIndex: primitive.getMaterial() ? 0 : undefined, // 简化处理
        name: primitive.getAttribute('POSITION')?.getName()
      };
    } catch (error) {
      console.error('Failed to extract primitive data:', error);
      return null;
    }
  }

  /**
   * 提取顶点数据
   */
  private static extractVertices(primitive: Primitive): GLTFVertexData[] {
    const vertices: GLTFVertexData[] = [];

    // 获取位置数据
    const positionAccessor = primitive.getAttribute('POSITION');
    if (!positionAccessor) {
      throw new GLTFImportError('No POSITION attribute found');
    }

    const positions = this.getAccessorData(positionAccessor, 'vec3');
    if (!positions) {
      throw new GLTFImportError('Failed to read position data');
    }

    // 获取法线数据
    const normalAccessor = primitive.getAttribute('NORMAL');
    const normals = normalAccessor ? this.getAccessorData(normalAccessor, 'vec3') : null;

    // 获取纹理坐标数据
    const texCoordAccessor = primitive.getAttribute('TEXCOORD_0');
    const texCoords = texCoordAccessor ? this.getAccessorData(texCoordAccessor, 'vec2') : null;

    // 组合顶点数据
    const vertexCount = positions.length / 3;
    for (let i = 0; i < vertexCount; i++) {
      const vertex: GLTFVertexData = {
        position: [
          positions[i * 3],
          positions[i * 3 + 1],
          positions[i * 3 + 2]
        ],
        normal: normals ? [
          normals[i * 3],
          normals[i * 3 + 1],
          normals[i * 3 + 2]
        ] : [0, 0, 1], // 默认法线
        texCoord: texCoords ? [
          texCoords[i * 2],
          texCoords[i * 2 + 1]
        ] : [0, 0] // 默认UV
      };
      vertices.push(vertex);
    }

    return vertices;
  }

  /**
   * 提取索引数据
   */
  private static extractIndices(primitive: Primitive): number[] {
    const indexAccessor = primitive.getIndices();
    if (!indexAccessor) {
      // 如果没有索引，生成顺序索引
      const positionAccessor = primitive.getAttribute('POSITION');
      if (!positionAccessor) return [];
      
      const vertexCount = positionAccessor.getCount();
      return Array.from({ length: vertexCount }, (_, i) => i);
    }

    const indices = this.getAccessorData(indexAccessor, 'scalar');
    return indices ? Array.from(indices) : [];
  }

  /**
   * 从 Accessor 获取数据
   */
  private static getAccessorData(accessor: Accessor, type: 'vec2' | 'vec3' | 'vec4' | 'scalar'): Float32Array | null {
    try {
      const array = accessor.getArray();
      if (!array) return null;

      // 如果已经是 Float32Array，直接返回
      if (array instanceof Float32Array) {
        return array;
      }

      // 转换为 Float32Array
      return new Float32Array(array);
    } catch (error) {
      console.error('Failed to get accessor data:', error);
      return null;
    }
  }

  /**
   * 从网格数据创建 Mesh 对象
   */
  private static createMeshFromData(meshData: GLTFMeshData, device: GPUDevice, name: string): Mesh {
    // 转换为项目中的 VertexData 格式
    const vertices: VertexData[] = meshData.vertices.map(vertex => ({
      position: new float3(vertex.position[0], vertex.position[1], vertex.position[2]),
      normal: new float3(vertex.normal[0], vertex.normal[1], vertex.normal[2]),
      uv0: new float2(vertex.texCoord[0], vertex.texCoord[1])
    }));

    return new Mesh(device, vertices, meshData.indices, name);
  }
}
