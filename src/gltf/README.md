# glTF 导入器

Veach 项目的 glTF 文件导入功能，基于 [glTF-Transform](https://github.com/donmccurdy/glTF-Transform) 库实现。

## 功能特性

- ✅ 支持 glTF 2.0 格式
- ✅ 提取网格数据（顶点、法线、UV坐标、索引）
- ✅ 提取纹理数据（PNG、JPEG、WebP）
- ✅ 与 Veach 的 Mesh 和 Texture 类完美集成
- ✅ 支持 WebGPU 渲染管线
- ✅ 错误处理和验证
- ✅ 统计信息和调试支持

## 文件结构

```
src/gltf/
├── gltf-importer.ts      # 主导入器类
├── gltf-types.ts         # 类型定义
├── gltf-utils.ts         # 工具函数
├── mesh-extractor.ts     # 网格提取器
├── texture-extractor.ts  # 纹理提取器
├── example-usage.ts     # 使用示例
└── README.md            # 说明文档
```

## 快速开始

### 1. 基本使用

```typescript
import { GLTFImporter } from './gltf/gltf-importer';

// 创建导入器
const importer = new GLTFImporter(device, {
  generateMipmaps: true,
  textureFormat: 'rgba8unorm',
  optimizeMeshes: true
});

// 导入 glTF 文件
const result = await importer.importFromFile('assets/model.gltf');

// 使用导入的数据
const meshes = result.meshes;
const textures = result.textures;
```

### 2. 在渲染器中使用

```typescript
import { GLTFExample } from './gltf/example-usage';

const example = new GLTFExample(renderer);
await example.loadGLTFModel('assets/box-textured/BoxTextured.gltf');
```

### 3. 检查文件支持

```typescript
// 检查文件是否支持
const supported = await GLTFImporter.isSupported('assets/model.gltf');

// 获取文件信息
const info = await GLTFImporter.getFileInfo('assets/model.gltf');
console.log('File stats:', info.stats);
```

## API 参考

### GLTFImporter

主要的导入器类，提供以下方法：

#### 构造函数
```typescript
constructor(device: GPUDevice, options?: Partial<GLTFImporterOptions>)
```

#### 导入方法
- `importFromFile(filePath: string): Promise<GLTFImportResult>`
- `importFromBuffer(buffer: ArrayBuffer): Promise<GLTFImportResult>`
- `importFromURL(url: string): Promise<GLTFImportResult>`

#### 工具方法
- `getOptions(): GLTFImporterOptions`
- `updateOptions(newOptions: Partial<GLTFImporterOptions>): void`

### GLTFImportResult

导入结果接口：

```typescript
interface GLTFImportResult {
  meshes: Mesh[];           // 提取的网格数组
  textures: Texture[];      // 提取的纹理数组
  materials?: Material[];   // 材质信息（未来扩展）
  nodes?: Node[];          // 节点信息（未来扩展）
}
```

### GLTFImporterOptions

导入器选项：

```typescript
interface GLTFImporterOptions {
  device: GPUDevice;                    // WebGPU 设备
  generateMipmaps?: boolean;            // 是否生成 mipmap
  textureFormat?: GPUTextureFormat;     // 纹理格式
  optimizeMeshes?: boolean;             // 是否优化网格
  flipTextureY?: boolean;              // 是否翻转纹理Y轴
}
```

## 支持的格式

### 网格数据
- ✅ 顶点位置 (POSITION)
- ✅ 法线 (NORMAL)
- ✅ 纹理坐标 (TEXCOORD_0)
- ✅ 索引数据

### 纹理格式
- ✅ PNG
- ✅ JPEG
- ✅ WebP

### 不支持的格式
- ❌ Draco 压缩（需要额外解码器）
- ❌ Meshopt 压缩（需要额外解码器）
- ❌ Basis Universal 纹理（需要额外解码器）

## 错误处理

导入器提供了完整的错误处理：

```typescript
try {
  const result = await importer.importFromFile('model.gltf');
} catch (error) {
  if (error instanceof GLTFImportError) {
    console.error('glTF import error:', error.message);
    console.error('Cause:', error.cause);
  }
}
```

## 性能优化

### 网格优化
- 自动合并重复顶点
- 优化索引数据
- 内存高效的数据布局

### 纹理优化
- 自动生成 mipmap
- 支持多种纹理格式
- GPU 内存管理

## 调试和统计

导入器提供详细的统计信息：

```typescript
// 获取文档统计
const stats = GLTFUtils.getDocumentStats(document);
console.log('Mesh count:', stats.meshCount);
console.log('Texture count:', stats.textureCount);

// 获取纹理统计
const textureStats = GLTFTextureExtractor.getTextureStats(textures);
console.log('Total texture size:', textureStats.totalSize);
```

## 未来扩展

- 🔄 材质系统支持
- 🔄 节点层次结构
- 🔄 动画支持
- 🔄 更多压缩格式支持

## 注意事项

1. **WebGPU 兼容性**: 确保浏览器支持 WebGPU
2. **文件大小**: 大型 glTF 文件可能需要更多内存
3. **纹理格式**: 某些格式可能需要额外处理
4. **错误处理**: 始终使用 try-catch 处理导入错误

## 示例项目

查看 `example-usage.ts` 文件获取完整的使用示例。
