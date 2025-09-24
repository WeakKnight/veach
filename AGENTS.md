# Veach 项目 Agent 开发指南

## 📋 项目概览

**Veach** 是一个基于 Electron + WebGPU 的现代游戏引擎/编辑器项目，采用 TypeScript 开发，具有以下核心特性：

- 🎮 **游戏引擎核心**: WebGPU 渲染管线、数学库、网格系统
- 🖥️ **桌面应用**: Electron 框架，支持跨平台部署
- 🎨 **现代UI**: React + Ant Design 组件库
- 🧮 **数学库**: HLSL 风格的向量数学库
- 🔧 **开发工具**: 完整的测试覆盖、构建系统

## 🏗️ 项目架构

### 技术栈
```
┌─────────────────────────────────────────────────────────────┐
│                     Veach 技术栈                            │
├─────────────────────────────────────────────────────────────┤
│ 前端层: React 19 + Ant Design + TypeScript                 │
│ 渲染层: WebGPU + WGSL 着色器 + 自定义渲染管线              │
│ 桌面层: Electron 37 + Node.js 集成                        │
│ 数学层: 自定义 HLSL 风格数学库 (float2/3/4)                │
│ 工具层: Vite + Jest + ESLint + TypeScript                  │
└─────────────────────────────────────────────────────────────┘
```

### 核心模块结构
```
src/
├── main.ts                 # Electron 主进程入口
├── game.tsx                # React 渲染器入口
├── renderer.ts             # WebGPU 渲染器核心
├── graphics-pipeline.ts    # 图形管线管理
├── gpu-buffer.ts          # GPU 缓冲区封装
├── mesh.ts                # 网格数据管理
├── texture.ts             # 纹理管理
├── math/                  # HLSL 风格数学库
│   ├── float2.ts          # 2D 向量
│   ├── float3.ts          # 3D 向量  
│   ├── float4.ts          # 4D 向量
│   ├── math-utils.ts      # 数学工具
│   └── hlsl-types.ts      # 统一导出
├── shaders/               # 着色器文件
│   ├── base-pass.slang    # Slang 着色器
│   └── vertex-factory.slang
└── types/                 # 类型定义
    ├── preload.d.ts       # 预加载类型
    └── wgsl.d.ts          # WGSL 类型
```

## 🎯 核心组件详解

### 1. 渲染系统 (`renderer.ts`)

**职责**: WebGPU 渲染管线的核心管理
```typescript
export class Renderer {
  public device: GPUDevice | null;
  private gbufferPipeline: GraphicsPipeline | null;
  private webgpuContext: GPUCanvasContext | null;
  private mesh: Mesh | null;
  
  // 核心方法
  public async init()           // 初始化 WebGPU 设备
  public render(deltaTime)      // 渲染循环
  public resize()              // 画布尺寸调整
}
```

**关键特性**:
- 自动设备适配和初始化
- 高DPI 显示支持
- 帧率控制和 deltaTime 计算
- 资源管理和清理

### 2. 图形管线 (`graphics-pipeline.ts`)

**职责**: WebGPU 渲染管线的创建和配置
```typescript
export class GraphicsPipeline {
  // 管线配置选项
  interface GraphicsPipelineOptions {
    vertexShaderCode: string;
    fragmentShaderCode: string;
    cullMode?: GPUCullMode;
    depthCompare?: GPUCompareFunction;
    // ... 更多配置
  }
  
  // 静态工厂方法
  static createBasic()          // 基础管线
  static createWithDepth()      // 深度测试管线
  static createTransparent()    // 透明渲染管线
  static createWireframe()     // 线框渲染管线
}
```

**设计模式**: 建造者模式 + 工厂模式
- 灵活的管线配置系统
- 预定义的常用管线类型
- 自动布局管理

### 3. GPU 缓冲区 (`gpu-buffer.ts`)

**职责**: WebGPU 缓冲区的封装和管理
```typescript
export class GPUBufferWrapper {
  // 核心方法
  setData(data: BufferSource, offset?: number)     // 写入数据
  async readData(offset?: number, size?: number)   // 读取数据
  copyFrom(source, sourceOffset?, destOffset?)     // 复制数据
  
  // 静态工厂方法
  static createStorageBuffer()   // 存储缓冲区
  static createVertexBuffer()    // 顶点缓冲区
  static createIndexBuffer()     // 索引缓冲区
  static createUniformBuffer()   // Uniform 缓冲区
}
```

**特性**:
- 类型安全的缓冲区操作
- 自动内存管理
- 异步数据读取支持
- 多种缓冲区类型支持

### 4. 网格系统 (`mesh.ts`)

**职责**: 3D 网格数据的管理和渲染
```typescript
export class Mesh {
  // 顶点数据结构
  interface VertexData {
    position: float3;    // 位置 (3 floats)
    normal: float3;      // 法线 (3 floats)  
    uv0: float2;         // 纹理坐标 (2 floats)
  }
  
  // 核心方法
  updateVertices(vertices: VertexData[])    // 更新顶点
  updateIndices(indices: number[])         // 更新索引
  async readVertices()                     // 读取顶点数据
  async readIndices()                      // 读取索引数据
  
  // 静态工厂方法
  static createQuad(device, size?, label?) // 创建四边形网格
}
```

**顶点布局**:
- 每个顶点 8 个 float32 (32 字节)
- 位置: 0-11 字节
- 法线: 12-23 字节  
- UV: 24-31 字节

### 5. 数学库 (`math/`)

**职责**: HLSL 风格的数学运算库

#### float3 核心特性
```typescript
export class float3 {
  // 基本属性
  x: number; y: number; z: number;
  
  // Swizzle 操作 (HLSL 风格)
  get xy(): float2;     // 获取 2D 向量
  get xyz(): float3;    // 获取 3D 向量
  get rgb(): float3;    // 颜色通道别名
  
  // 数学运算
  add(v: float3): this;           // 向量加法
  sub(v: float3): this;           // 向量减法
  scale(s: number): this;         // 标量乘法
  dot(v: float3): number;         // 点积
  cross(v: float3): this;         // 叉积
  normalize(): this;              // 归一化
  distance(v: float3): number;    // 距离计算
  lerp(v: float3, t: number): this; // 线性插值
  
  // 静态方法
  static add(a: float3, b: float3): float3;
  static cross(a: float3, b: float3): float3;
  static distance(a: float3, b: float3): number;
  static up(): float3;            // 预定义方向向量
  static forward(): float3;
  static right(): float3;
}
```

**测试覆盖**: 109 个测试用例，100% 通过率

## 🚀 开发工作流

### 环境设置
```bash
# 安装依赖
npm install

# 预处理着色器
npm run preprocess:shaders

# 启动开发服务器
npm start

# 运行测试
npm test

# 代码检查
npm run lint
```

### 构建和打包
```bash
# 构建项目
npm run package

# 创建可执行文件
npm run make

# 发布
npm run publish
```

## 🎨 着色器系统

### WGSL 着色器
项目支持两种着色器格式：

#### 1. WGSL (WebGPU Shading Language)
```wgsl
// vertex.wgsl
struct VertexOut {
    @builtin(position) pos: vec4f,
    @location(0) texCoord: vec2f
};

@vertex 
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> VertexOut {
    // 顶点着色器逻辑
}
```

#### 2. Slang (实验性)
```hlsl
// base-pass.slang
[shader("vertex")]
VertexStageOutput vertexMain(uint vertexIndex: SV_VertexID) : SV_Position {
    // 顶点着色器逻辑
}
```

### 着色器预处理
- 自动 WGSL 文件预处理
- 支持条件编译
- 着色器反射支持

## 🧪 测试系统

### 测试结构
```
tests/
├── float2.test.ts      # 2D 向量测试
├── float3.test.ts      # 3D 向量测试  
├── float4.test.ts      # 4D 向量测试
└── math-utils.test.ts  # 数学工具测试
```

### 测试覆盖率
- **总测试用例**: 109 个
- **通过率**: 100% ✅
- **覆盖范围**: 所有数学库功能

### 运行测试
```bash
# 运行所有测试
npm test

# 监视模式
npm run test:watch

# 生成覆盖率报告
npm run test:coverage
```

## 🔧 开发最佳实践

### 1. 代码组织
```typescript
// ✅ 推荐: 使用命名空间和模块化
import { float3, float4, MathUtils } from './math/hlsl-types';

// ✅ 推荐: 链式调用
const result = position
  .add(velocity.scale(deltaTime))
  .normalize();
```

### 2. WebGPU 资源管理
```typescript
// ✅ 推荐: 使用封装类管理资源
const buffer = GPUBufferWrapper.createVertexBuffer(device, size);
buffer.setData(vertexData);
// 自动清理: buffer.destroy()
```

### 3. 错误处理
```typescript
// ✅ 推荐: 检查 WebGPU 支持
if (!navigator.gpu) {
  throw new Error('WebGPU not supported');
}

const adapter = await navigator.gpu.requestAdapter();
if (!adapter) {
  throw new Error('No WebGPU adapter found');
}
```

### 4. 性能优化
```typescript
// ✅ 推荐: 批量操作
const commandEncoder = device.createCommandEncoder();
// ... 多个操作
device.queue.submit([commandEncoder.finish()]);

// ✅ 推荐: 重用缓冲区
const stagingBuffer = device.createBuffer({
  usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
});
```

## 📚 API 参考

### 核心类 API

#### Renderer 类
```typescript
class Renderer {
  // 初始化渲染器
  async init(): Promise<void>
  
  // 渲染循环
  render(deltaTime: number): void
  
  // 调整画布尺寸
  resize(): void
}
```

#### GraphicsPipeline 类
```typescript
class GraphicsPipeline {
  // 创建基础管线
  static createBasic(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline
  
  // 创建带深度测试的管线
  static createWithDepth(
    device: GPUDevice,
    vertexShaderCode: string,
    fragmentShaderCode: string,
    depthFormat?: GPUTextureFormat,
    options?: Partial<GraphicsPipelineOptions>
  ): GraphicsPipeline
}
```

#### GPUBufferWrapper 类
```typescript
class GPUBufferWrapper {
  // 设置数据
  setData(data: BufferSource, offset?: number): void
  
  // 读取数据
  async readData(offset?: number, size?: number): Promise<ArrayBuffer>
  
  // 复制数据
  copyFrom(source: GPUBuffer | GPUBufferWrapper, ...): void
}
```

#### Mesh 类
```typescript
class Mesh {
  // 创建四边形网格
  static createQuad(
    device: GPUDevice, 
    size?: number, 
    label?: string
  ): Mesh
  
  // 更新顶点数据
  updateVertices(vertices: VertexData[], offset?: number): void
  
  // 读取顶点数据
  async readVertices(offset?: number, count?: number): Promise<VertexData[]>
}
```

### 数学库 API

#### float3 类
```typescript
class float3 {
  // 构造函数
  constructor(x?: number, y?: number, z?: number)
  
  // 基本运算
  add(v: float3): this
  sub(v: float3): this
  scale(s: number): this
  dot(v: float3): number
  cross(v: float3): this
  
  // 向量操作
  length(): number
  normalize(): this
  distance(v: float3): number
  lerp(v: float3, t: number): this
  
  // Swizzle 操作
  get xy(): float2
  get xyz(): float3
  get rgb(): float3
  
  // 静态方法
  static add(a: float3, b: float3): float3
  static cross(a: float3, b: float3): float3
  static up(): float3
  static forward(): float3
  static right(): float3
}
```

## 🐛 常见问题和解决方案

### 1. WebGPU 初始化失败
```typescript
// 问题: WebGPU 不支持
// 解决: 检查浏览器支持
if (!navigator.gpu) {
  console.error('WebGPU not supported in this browser');
  return;
}
```

### 2. 着色器编译错误
```typescript
// 问题: WGSL 语法错误
// 解决: 检查着色器代码和绑定
const shaderModule = device.createShaderModule({
  code: shaderCode,
  label: 'vertex-shader'
});
```

### 3. 缓冲区大小不匹配
```typescript
// 问题: 顶点数据大小错误
// 解决: 检查顶点布局
const VERTEX_LAYOUT = {
  STRIDE: 32,        // 8 floats * 4 bytes
  FLOAT_COUNT: 8      // position(3) + normal(3) + uv(2)
};
```

### 4. 内存泄漏
```typescript
// 问题: GPU 资源未释放
// 解决: 实现资源清理
class ResourceManager {
  private resources: GPUBuffer[] = [];
  
  addResource(buffer: GPUBuffer) {
    this.resources.push(buffer);
  }
  
  cleanup() {
    this.resources.forEach(buffer => buffer.destroy());
    this.resources = [];
  }
}
```

## 🔮 扩展开发指南

### 添加新的渲染管线
```typescript
// 1. 定义新的管线选项
interface CustomPipelineOptions extends GraphicsPipelineOptions {
  customProperty: string;
}

// 2. 创建管线类
class CustomPipeline extends GraphicsPipeline {
  constructor(device: GPUDevice, options: CustomPipelineOptions) {
    super(device, options);
    // 自定义初始化逻辑
  }
}
```

### 添加新的数学类型
```typescript
// 1. 创建新的数学类型
export class float2x2 {
  // 实现 2x2 矩阵运算
}

// 2. 添加到统一导出
export { float2x2 } from './float2x2';
```

### 添加新的网格类型
```typescript
// 1. 创建网格工厂方法
class Mesh {
  static createSphere(device: GPUDevice, radius: number): Mesh {
    // 生成球体顶点和索引
  }
  
  static createCube(device: GPUDevice, size: number): Mesh {
    // 生成立方体顶点和索引
  }
}
```

## 📖 学习资源

### WebGPU 相关
- [WebGPU 规范](https://www.w3.org/TR/webgpu/)
- [WGSL 规范](https://www.w3.org/TR/WGSL/)
- [WebGPU 示例](https://webgpufundamentals.org/)

### 数学库参考
- [HLSL 数学函数](https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-intrinsic-functions)
- [3D 数学基础](https://www.3dgep.com/learning-directx-12-1/)

### 项目特定
- 查看 `MATH_LIBRARY_README.md` 了解数学库详细文档
- 运行 `npm run test:coverage` 查看测试覆盖率
- 查看 `tests/` 目录了解测试用例

---

## 🎯 快速开始检查清单

- [ ] 确认 Node.js 版本 >= 16
- [ ] 安装项目依赖: `npm install`
- [ ] 运行测试确保环境正常: `npm test`
- [ ] 启动开发服务器: `npm start`
- [ ] 检查 WebGPU 支持 (Chrome 113+)
- [ ] 熟悉项目结构和核心类
- [ ] 阅读数学库文档和示例
- [ ] 查看测试用例了解 API 用法

---

*此文档为 Veach 项目的 Agent 开发指南，旨在帮助 AI Agent 快速理解项目结构和开发模式。*
