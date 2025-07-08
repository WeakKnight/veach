import { GPUBufferWrapper } from './gpu-buffer';
import { float2 } from './math/float2';
import { float3 } from './math/float3';
import { float4 } from './math/float4';

/**
 * 顶点数据结构定义
 * 包含: position(3), normal(3), uv0(2)
 * 总共 8 个 float32 值 = 32 字节
 */
export interface VertexData {
	position: float3;      // 3 floats - 位置
	normal: float3;        // 3 floats - 法线
	uv0: float2;           // 2 floats - 纹理坐标0
}

/**
 * 顶点属性布局常量
 */
export const VERTEX_LAYOUT = {
	POSITION_OFFSET: 0,
	NORMAL_OFFSET: 12,
	UV0_OFFSET: 24,
	STRIDE: 32,
	FLOAT_COUNT: 8
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
		const packedData = new Float32Array(vertices.length * VERTEX_LAYOUT.FLOAT_COUNT); // 每个顶点14个float

		for (let i = 0; i < vertices.length; i++) {
			const vertex = vertices[i];
			const offset = i * 8;

			// position (3 floats)
			packedData[offset + 0] = vertex.position.x;
			packedData[offset + 1] = vertex.position.y;
			packedData[offset + 2] = vertex.position.z;

			// normal (3 floats)
			packedData[offset + 3] = vertex.normal.x;
			packedData[offset + 4] = vertex.normal.y;
			packedData[offset + 5] = vertex.normal.z;

			// uv0 (2 floats)
			packedData[offset + 6] = vertex.uv0.x;
			packedData[offset + 7] = vertex.uv0.y;
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
			const floatOffset = i * VERTEX_LAYOUT.FLOAT_COUNT;
			vertices.push({
				position: new float3(floatData[floatOffset + 0], floatData[floatOffset + 1], floatData[floatOffset + 2]),
				normal: new float3(floatData[floatOffset + 3], floatData[floatOffset + 4], floatData[floatOffset + 5]),
				uv0: new float2(floatData[floatOffset + 6], floatData[floatOffset + 7]),
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
				uv0: new float2(0, 1),
				position: new float3(-halfSize, -halfSize, 0),
				normal: new float3(0, 0, 1),
			},
			// 右下
			{
				uv0: new float2(1, 1),
				position: new float3(halfSize, -halfSize, 0),
				normal: new float3(0, 0, 1),
			},
			// 右上
			{
				uv0: new float2(1, 0),
				position: new float3(halfSize, halfSize, 0),
				normal: new float3(0, 0, 1),
			},
			// 左上
			{
				uv0: new float2(0, 0),
				position: new float3(-halfSize, halfSize, 0),
				normal: new float3(0, 0, 1),
			}
		];

		const indices = [
			0, 1, 2,  // 第一个三角形
			0, 2, 3   // 第二个三角形
		];

		return new Mesh(device, vertices, indices, label || 'quad');
	}
} 