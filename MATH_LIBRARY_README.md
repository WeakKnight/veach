# HLSL-Style 数学库

这是一个为Veach项目创建的HLSL风格数学库，提供了兼容HLSL语法的向量类型和数学工具。

## 功能特性

### 📊 向量类型
- `float2` - 二维向量 (x, y)
- `float3` - 三维向量 (x, y, z)  
- `float4` - 四维向量 (x, y, z, w)

### ⚙️ 核心功能
- **Swizzle 操作** - 支持HLSL风格的分量访问 (如 `vec.xy`, `vec.xyz`)
- **颜色通道别名** - RGB/RGBA 别名支持 (`r`, `g`, `b`, `a`)
- **向量运算** - 加、减、乘、除、缩放、点积、叉积等
- **距离计算** - 欧几里得距离和距离平方
- **插值函数** - 线性插值 (lerp)
- **反射/折射** - 向量反射和折射计算
- **规范化** - 向量单位化
- **实用方法** - 绝对值、取整、约束等

### 🔧 数学工具类 (MathUtils)
- **常量** - DEG2RAD, RAD2DEG, EPSILON, GOLDEN_RATIO
- **角度转换** - 度数与弧度互转
- **数学函数** - clamp, lerp 
- **随机数生成** - 浮点数和整数随机数
- **比较函数** - 浮点数相等性检查

## 📁 文件结构

```
src/math/
├── float2.ts          # 二维向量类
├── float3.ts          # 三维向量类  
├── float4.ts          # 四维向量类
├── math-utils.ts      # 数学工具类
└── hlsl-types.ts      # 统一导出文件

tests/
├── float2.test.ts     # float2 测试用例
├── float3.test.ts     # float3 测试用例
├── float4.test.ts     # float4 测试用例
└── math-utils.test.ts # MathUtils 测试用例
```

## 🚀 使用示例

```typescript
import { float2, float3, float4, MathUtils } from './src/math/hlsl-types';

// 创建向量
const vec2 = new float2(3, 4);
const vec3 = new float3(1, 2, 3);
const vec4 = new float4(1, 0, 0, 1); // 红色

// Swizzle操作
const xy = vec3.xy;        // 获取 float2(1, 2)
const bgr = vec4.bgr;      // 获取 float3(0, 0, 1)
const xxxy = vec3.xxxy;    // 获取 float4(1, 1, 1, 2)

// 向量运算
const sum = vec2.add(new float2(1, 1));     // (4, 5)
const scaled = vec3.scale(2);               // (2, 4, 6)
const normalized = vec3.normalize();        // 单位向量

// 距离和点积
const distance = vec2.distance(new float2(0, 0)); // 5.0
const dot = vec3.dot(new float3(1, 0, 0));         // 1.0

// 线性插值
const midpoint = vec2.lerp(new float2(7, 8), 0.5); // (5, 6)

// 数学工具
const angle = MathUtils.degToRad(90);        // π/2
const random = MathUtils.random(0, 10);      // 0-10随机数
const clamped = MathUtils.clamp(15, 0, 10);  // 10
```

## 🧪 测试覆盖

### 测试统计
- **总测试用例**: 109个
- **通过率**: 100% ✅
- **测试套件**: 4个 (float2, float3, float4, MathUtils)

### 测试范围
- ✅ 构造函数和默认值
- ✅ 基本数学运算 (+, -, *, /, scale)
- ✅ 向量长度计算和规范化
- ✅ 点积和叉积 (float3)
- ✅ 距离计算
- ✅ Swizzle 操作的完整覆盖
- ✅ 颜色通道别名
- ✅ 静态方法
- ✅ 链式操作
- ✅ 边界条件和错误处理
- ✅ 数学工具类的所有功能

### 运行测试

```bash
# 运行所有测试
npm test

# 运行测试并查看覆盖率
npm run test:coverage

# 监视模式运行测试
npm run test:watch
```

## 🎯 API 兼容性

这个库的设计目标是提供接近HLSL的API体验：

### HLSL 风格的 Swizzle
```typescript
// HLSL: float3 pos = transform.xyz;
const pos = transform.xyz;

// HLSL: float2 texCoord = vertex.xy;
const texCoord = vertex.xy;
```

### 颜色通道访问
```typescript
// HLSL: float3 rgb = color.rgb;
const rgb = color.rgb;

// HLSL: float alpha = color.a;
const alpha = color.a;
```

### 向量运算
```typescript
// HLSL风格的方法调用
const result = vec1.add(vec2).normalize();
const distance = pos1.distance(pos2);
```

## 📊 性能特性

- **零拷贝Swizzle**: Swizzle操作创建新的向量实例，保持数据不可变性
- **链式调用**: 支持方法链，提高代码可读性
- **内存效率**: 所有向量类型都是纯JavaScript对象，内存占用最小
- **类型安全**: 完整的TypeScript类型定义

## 🔮 未来扩展

可能的扩展方向：
- **矩阵类型** - float2x2, float3x3, float4x4
- **四元数** - quaternion 类型  
- **几何函数** - 更多几何计算工具
- **性能优化** - SIMD支持和内存池
- **GPU集成** - WebGL/WebGPU 缓冲区互操作

---

这个数学库为Veach项目提供了坚实的数学基础，具有良好的测试覆盖率和HLSL兼容的API设计。 