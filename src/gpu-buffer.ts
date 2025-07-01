/**
 * WebGPU Buffer 封装类
 * 提供便捷的数据设置和读取功能
 */

export interface GPUBufferOptions {
  size: number;
  usage: GPUBufferUsageFlags;
  label?: string;
  mappedAtCreation?: boolean;
}

export class GPUBufferWrapper {
  private device: GPUDevice;
  private buffer: GPUBuffer;
  private size: number;
  private usage: GPUBufferUsageFlags;

  constructor(device: GPUDevice, options: GPUBufferOptions) {
    this.device = device;
    this.size = options.size;
    this.usage = options.usage;
    
    this.buffer = this.device.createBuffer({
      size: options.size,
      usage: options.usage,
      label: options.label,
      mappedAtCreation: options.mappedAtCreation || false,
    });
  }

  /**
   * 获取原始的 GPUBuffer 对象
   */
  getBuffer(): GPUBuffer {
    return this.buffer;
  }

  /**
   * 获取缓冲区大小
   */
  getSize(): number {
    return this.size;
  }

  /**
   * 设置数据到 GPU Buffer
   * @param data 要写入的数据（ArrayBuffer 或 TypedArray）
   * @param offset 写入的偏移量（字节）
   */
  setData(data: BufferSource, offset: number = 0): void {
    this.device.queue.writeBuffer(this.buffer, offset, data);
  }

  /**
   * 从 GPU Buffer 读取数据到主机端
   * @param offset 读取的偏移量（字节）
   * @param size 读取的大小（字节），如果不指定则读取整个缓冲区
   * @returns Promise<ArrayBuffer> 读取到的数据
   */
  async readData(offset: number = 0, size?: number): Promise<ArrayBuffer> {
    const readSize = size || (this.size - offset);
    
    // 创建一个用于读取的临时缓冲区
    const stagingBuffer = this.device.createBuffer({
      size: readSize,
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
      label: 'staging-buffer-for-read'
    });

    // 创建命令编码器来复制数据
    const commandEncoder = this.device.createCommandEncoder();
    commandEncoder.copyBufferToBuffer(
      this.buffer, offset,
      stagingBuffer, 0,
      readSize
    );
    
    // 提交命令
    this.device.queue.submit([commandEncoder.finish()]);

    // 映射缓冲区并读取数据
    await stagingBuffer.mapAsync(GPUMapMode.READ);
    const mappedRange = stagingBuffer.getMappedRange();
    const result = new ArrayBuffer(mappedRange.byteLength);
    new Uint8Array(result).set(new Uint8Array(mappedRange));
    
    // 取消映射并销毁临时缓冲区
    stagingBuffer.unmap();
    stagingBuffer.destroy();
    
    return result;
  }

  /**
   * 从 GPU Buffer 读取数据到指定的 TypedArray
   * @param target 目标 TypedArray
   * @param offset 读取的偏移量（字节）
   */
  async readDataTo<T extends ArrayBufferView>(target: T, offset: number = 0): Promise<void> {
    const data = await this.readData(offset, target.byteLength);
    const sourceView = new (target.constructor as any)(data);
    (target as any).set(sourceView);
  }

  /**
   * 复制数据从另一个 Buffer
   * @param source 源 GPUBuffer 或 GPUBufferWrapper
   * @param sourceOffset 源偏移量
   * @param destinationOffset 目标偏移量
   * @param size 复制大小
   */
  copyFrom(
    source: GPUBuffer | GPUBufferWrapper,
    sourceOffset: number = 0,
    destinationOffset: number = 0,
    size?: number
  ): void {
    const sourceBuffer = source instanceof GPUBufferWrapper ? source.getBuffer() : source;
    const copySize = size || (this.size - destinationOffset);

    const commandEncoder = this.device.createCommandEncoder();
    commandEncoder.copyBufferToBuffer(
      sourceBuffer, sourceOffset,
      this.buffer, destinationOffset,
      copySize
    );
    this.device.queue.submit([commandEncoder.finish()]);
  }

  /**
   * 销毁缓冲区
   */
  destroy(): void {
    this.buffer.destroy();
  }

  /**
   * 创建一个用于存储的缓冲区（可读写）
   */
  static createStorageBuffer(device: GPUDevice, size: number, label?: string): GPUBufferWrapper {
    return new GPUBufferWrapper(device, {
      size,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST,
      label: label || 'storage-buffer'
    });
  }

  /**
   * 创建一个顶点缓冲区
   */
  static createVertexBuffer(device: GPUDevice, size: number, label?: string): GPUBufferWrapper {
    return new GPUBufferWrapper(device, {
      size,
      usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE,
      label: label || 'vertex-buffer'
    });
  }

  /**
   * 创建一个索引缓冲区
   */
  static createIndexBuffer(device: GPUDevice, size: number, label?: string): GPUBufferWrapper {
    return new GPUBufferWrapper(device, {
      size,
      usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST | GPUBufferUsage.STORAGE,
      label: label || 'index-buffer'
    });
  }

  /**
   * 创建一个Uniform缓冲区
   */
  static createUniformBuffer(device: GPUDevice, size: number, label?: string): GPUBufferWrapper {
    return new GPUBufferWrapper(device, {
      size,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      label: label || 'uniform-buffer'
    });
  }
}

/**
 * 辅助函数：创建并填充缓冲区
 */
export function createBufferWithData(
  device: GPUDevice,
  data: BufferSource,
  usage: GPUBufferUsageFlags,
  label?: string
): GPUBufferWrapper {
  const buffer = new GPUBufferWrapper(device, {
    size: data.byteLength,
    usage: usage | GPUBufferUsage.COPY_DST,
    label
  });
  buffer.setData(data);
  return buffer;
} 