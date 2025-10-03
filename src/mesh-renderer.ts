import { Mesh } from './mesh';
import { Material } from './material';
import { Texture } from './texture';
import { float4x4 } from './math/float4x4';

/**
 * MeshRenderer 类
 * 封装 Mesh 和 Material 的组合，提供统一的渲染接口
 */
export class MeshRenderer {
  private mesh: Mesh;
  private material: Material;
  private transform: float4x4;
  private enabled: boolean;
  private name: string;

  constructor(
    mesh: Mesh,
    material: Material,
    transform?: float4x4,
    name?: string
  ) {
    this.mesh = mesh;
    this.material = material;
    this.transform = transform || new float4x4();
    this.enabled = true;
    this.name = name || 'MeshRenderer';
  }

  /**
   * 渲染方法
   * 统一处理 material 绑定、mesh 绑定和绘制调用
   * @param renderPass 渲染通道编码器
   * @param viewMatrix 相机视图矩阵
   * @param projectionMatrix 投影矩阵
   */
  render(
    renderPass: GPURenderPassEncoder,
    viewMatrix: float4x4,
    projectionMatrix: float4x4
  ): void {
    if (!this.enabled) {
      return;
    }

    // 计算 MVP 矩阵 = Projection * View * Model
    const mvp = float4x4.multiply(
      float4x4.multiply(projectionMatrix, viewMatrix),
      this.transform
    );

    // 更新材质的 MVP uniform buffer
    const mvpData = mvp.toFloat32Array();
    this.material.updateUniformBuffer('mvp', mvpData);

    // 绑定材质（包括pipeline和资源）
    // 注意：storage buffer 已经在创建时预先设置，无需在每次渲染时重新绑定
    this.material.bind(renderPass);

    // 绑定索引缓冲区
    renderPass.setIndexBuffer(this.mesh.getIndexBuffer().getBuffer(), 'uint32');

    // 执行绘制（使用索引绘制，不需要顶点缓冲区）
    renderPass.drawIndexed(this.mesh.getIndexCount());
  }

  /**
   * 设置新的网格
   */
  setMesh(mesh: Mesh): void {
    this.mesh = mesh;
  }

  /**
   * 设置新的材质
   */
  setMaterial(material: Material): void {
    this.material = material;
  }

  /**
   * 设置变换矩阵
   */
  setTransform(transform: float4x4): void {
    this.transform = transform;
  }

  /**
   * 获取变换矩阵
   */
  getTransform(): float4x4 {
    return this.transform;
  }

  /**
   * 启用/禁用渲染
   */
  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  /**
   * 检查是否启用
   */
  isEnabled(): boolean {
    return this.enabled;
  }

  /**
   * 获取网格
   */
  getMesh(): Mesh {
    return this.mesh;
  }

  /**
   * 获取材质
   */
  getMaterial(): Material {
    return this.material;
  }

  /**
   * 获取名称
   */
  getName(): string {
    return this.name;
  }

  /**
   * 设置名称
   */
  setName(name: string): void {
    this.name = name;
  }

  /**
   * 销毁资源
   */
  destroy(): void {
    // 注意：我们不销毁 mesh 和 material，因为它们可能被其他 MeshRenderer 共享
    // 如果需要销毁，应该由外部代码负责
  }

  /**
   * 静态工厂方法：从 GLTF 导入的数据创建 MeshRenderer
   */
  static async createFromGLTF(
    device: GPUDevice,
    meshData: Mesh,
    textureData: Texture[],
    vertexShaderCode: string,
    fragmentShaderCode: string,
    name?: string
  ): Promise<MeshRenderer> {
    // 预先准备所有绑定信息
    const uniforms = new Map();
    const storageBuffers = new Map();
    const textures = new Map();

    // 创建 MVP uniform buffer（64 字节 = 16 个 float32）
    const mvpData = new Float32Array(16);
    // 初始化为单位矩阵
    mvpData[0] = 1; mvpData[5] = 1; mvpData[10] = 1; mvpData[15] = 1;
    
    const mvpBuffer = device.createBuffer({
      label: `${name || 'GLTF'}-mvp-uniform`,
      size: mvpData.byteLength,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
    });
    device.queue.writeBuffer(mvpBuffer, 0, mvpData);

    uniforms.set('mvp', {
      buffer: mvpBuffer,
      binding: 0,
      name: 'mvp',
      size: mvpData.byteLength
    });

    // 设置顶点数据 storage buffer（binding 1）
    const actualBuffer = 'getBuffer' in meshData.getVertexBuffer() 
      ? meshData.getVertexBuffer().getBuffer() 
      : meshData.getVertexBuffer();
    const bufferSize = 'getSize' in meshData.getVertexBuffer() 
      ? meshData.getVertexBuffer().getSize() 
      : 0;

    storageBuffers.set('vertexData', {
      buffer: meshData.getVertexBuffer(),
      binding: 1,
      name: 'vertexData',
      size: bufferSize
    });

    // 如果有纹理数据，设置第一个纹理作为漫反射纹理
    // 注意：纹理从 binding 2 开始
    if (textureData.length > 0) {
      textures.set('diffuse', {
        texture: textureData[0],
        binding: 2,
        name: 'diffuse'
      });
    }

    // 一次性创建材质，包含所有绑定信息
    const material = new Material(device, {
      name: name ? `${name}-material` : 'GLTF-Material',
      vertexShaderCode,
      fragmentShaderCode,
      uniforms,
      storageBuffers,
      textures,
      pipelineOptions: {
        cullMode: 'back',
        frontFace: 'ccw',
        depthCompare: 'less'
        // 注意：移除了 vertexBufferLayouts，因为我们使用 storage buffer + vertex_index
      }
    });

    // 创建 MeshRenderer
    return new MeshRenderer(meshData, material, undefined, name);
  }

  /**
   * 静态工厂方法：批量从 GLTF 导入的数据创建 MeshRenderer 数组
   */
  static async createArrayFromGLTF(
    device: GPUDevice,
    meshes: Mesh[],
    textures: Texture[],
    vertexShaderCode: string,
    fragmentShaderCode: string,
    namePrefix?: string
  ): Promise<MeshRenderer[]> {
    const renderers: MeshRenderer[] = [];

    for (let i = 0; i < meshes.length; i++) {
      const name = namePrefix ? `${namePrefix}-${i}` : `GLTF-Mesh-${i}`;
      const renderer = await MeshRenderer.createFromGLTF(
        device,
        meshes[i],
        textures,
        vertexShaderCode,
        fragmentShaderCode,
        name
      );
      renderers.push(renderer);
    }

    return renderers;
  }

  /**
   * 静态工厂方法：创建简单的 MeshRenderer（用于测试）
   */
  static createSimple(
    device: GPUDevice,
    mesh: Mesh,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    name?: string
  ): MeshRenderer {
    const material = Material.createBasic(
      device,
      vertexShaderCode,
      fragmentShaderCode,
      {
        name: name ? `${name}-material` : 'Simple-Material'
      }
    );

    return new MeshRenderer(mesh, material, undefined, name);
  }
}

/**
 * MeshRenderer 管理器
 * 管理多个 MeshRenderer 的集合
 */
export class MeshRendererManager {
  private renderers: Map<string, MeshRenderer> = new Map();

  /**
   * 添加 MeshRenderer
   */
  addRenderer(name: string, renderer: MeshRenderer): void {
    this.renderers.set(name, renderer);
  }

  /**
   * 获取 MeshRenderer
   */
  getRenderer(name: string): MeshRenderer | undefined {
    return this.renderers.get(name);
  }

  /**
   * 移除 MeshRenderer
   */
  removeRenderer(name: string): boolean {
    return this.renderers.delete(name);
  }

  /**
   * 获取所有 MeshRenderer
   */
  getAllRenderers(): MeshRenderer[] {
    return Array.from(this.renderers.values());
  }

  /**
   * 获取启用的 MeshRenderer
   */
  getEnabledRenderers(): MeshRenderer[] {
    return Array.from(this.renderers.values()).filter(renderer => renderer.isEnabled());
  }

  /**
   * 渲染所有启用的 MeshRenderer
   * @param renderPass 渲染通道编码器
   * @param viewMatrix 相机视图矩阵
   * @param projectionMatrix 投影矩阵
   */
  renderAll(
    renderPass: GPURenderPassEncoder,
    viewMatrix: float4x4,
    projectionMatrix: float4x4
  ): void {
    const enabledRenderers = this.getEnabledRenderers();
    for (const renderer of enabledRenderers) {
      renderer.render(renderPass, viewMatrix, projectionMatrix);
    }
  }

  /**
   * 清空所有 MeshRenderer
   */
  clear(): void {
    this.renderers.clear();
  }

  /**
   * 获取 MeshRenderer 数量
   */
  size(): number {
    return this.renderers.size;
  }

  /**
   * 获取所有 MeshRenderer 名称
   */
  getRendererNames(): string[] {
    return Array.from(this.renderers.keys());
  }
}
