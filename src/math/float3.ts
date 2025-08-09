import { MathUtils } from './math-utils';
import { float2 } from './float2';

/**
 * HLSL 风格的 float3 类型
 * 提供3D向量操作，兼容HLSL语法风格
 */
export class float3 {
  public x: number;
  public y: number;
  public z: number;

  /**
   * 创建 float3
   * @param x X分量，默认为0
   * @param y Y分量，默认为0
   * @param z Z分量，默认为0
   */
  constructor(x: number = 0, y: number = 0, z: number = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  // HLSL风格的swizzle属性 (2分量)
  get xx(): float2 { return new float2(this.x, this.x); }
  get xy(): float2 { return new float2(this.x, this.y); }
  get xz(): float2 { return new float2(this.x, this.z); }
  get yx(): float2 { return new float2(this.y, this.x); }
  get yy(): float2 { return new float2(this.y, this.y); }
  get yz(): float2 { return new float2(this.y, this.z); }
  get zx(): float2 { return new float2(this.z, this.x); }
  get zy(): float2 { return new float2(this.z, this.y); }
  get zz(): float2 { return new float2(this.z, this.z); }

  // HLSL风格的swizzle属性 (3分量)
  get xxx(): float3 { return new float3(this.x, this.x, this.x); }
  get xxy(): float3 { return new float3(this.x, this.x, this.y); }
  get xxz(): float3 { return new float3(this.x, this.x, this.z); }
  get xyx(): float3 { return new float3(this.x, this.y, this.x); }
  get xyy(): float3 { return new float3(this.x, this.y, this.y); }
  get xyz(): float3 { return new float3(this.x, this.y, this.z); }
  get xzx(): float3 { return new float3(this.x, this.z, this.x); }
  get xzy(): float3 { return new float3(this.x, this.z, this.y); }
  get xzz(): float3 { return new float3(this.x, this.z, this.z); }
  get yxx(): float3 { return new float3(this.y, this.x, this.x); }
  get yxy(): float3 { return new float3(this.y, this.x, this.y); }
  get yxz(): float3 { return new float3(this.y, this.x, this.z); }
  get yyx(): float3 { return new float3(this.y, this.y, this.x); }
  get yyy(): float3 { return new float3(this.y, this.y, this.y); }
  get yyz(): float3 { return new float3(this.y, this.y, this.z); }
  get yzx(): float3 { return new float3(this.y, this.z, this.x); }
  get yzy(): float3 { return new float3(this.y, this.z, this.y); }
  get yzz(): float3 { return new float3(this.y, this.z, this.z); }
  get zxx(): float3 { return new float3(this.z, this.x, this.x); }
  get zxy(): float3 { return new float3(this.z, this.x, this.y); }
  get zxz(): float3 { return new float3(this.z, this.x, this.z); }
  get zyx(): float3 { return new float3(this.z, this.y, this.x); }
  get zyy(): float3 { return new float3(this.z, this.y, this.y); }
  get zyz(): float3 { return new float3(this.z, this.y, this.z); }
  get zzx(): float3 { return new float3(this.z, this.z, this.x); }
  get zzy(): float3 { return new float3(this.z, this.z, this.y); }
  get zzz(): float3 { return new float3(this.z, this.z, this.z); }

  // 颜色通道别名
  get r(): number { return this.x; }
  set r(value: number) { this.x = value; }
  get g(): number { return this.y; }
  set g(value: number) { this.y = value; }
  get b(): number { return this.z; }
  set b(value: number) { this.z = value; }

  get rr(): float2 { return new float2(this.r, this.r); }
  get rg(): float2 { return new float2(this.r, this.g); }
  get rb(): float2 { return new float2(this.r, this.b); }
  get gr(): float2 { return new float2(this.g, this.r); }
  get gg(): float2 { return new float2(this.g, this.g); }
  get gb(): float2 { return new float2(this.g, this.b); }
  get br(): float2 { return new float2(this.b, this.r); }
  get bg(): float2 { return new float2(this.b, this.g); }
  get bb(): float2 { return new float2(this.b, this.b); }

  get rgb(): float3 { return new float3(this.r, this.g, this.b); }
  get rbg(): float3 { return new float3(this.r, this.b, this.g); }
  get grb(): float3 { return new float3(this.g, this.r, this.b); }
  get gbr(): float3 { return new float3(this.g, this.b, this.r); }
  get brg(): float3 { return new float3(this.b, this.r, this.g); }
  get bgr(): float3 { return new float3(this.b, this.g, this.r); }

  /**
   * 设置向量值
   * @param x X分量
   * @param y Y分量
   * @param z Z分量
   * @returns 当前向量引用
   */
  set(x: number, y: number, z: number): this {
    this.x = x;
    this.y = y;
    this.z = z;
    return this;
  }

  /**
   * 克隆向量
   * @returns 新的float3实例
   */
  public clone(): float3 {
    return new float3(this.x, this.y, this.z);
  }

  /**
   * 复制另一个向量
   * @param v 要复制的向量
   * @returns 当前向量引用
   */
  copy(v: float3): this {
    this.x = v.x;
    this.y = v.y;
    this.z = v.z;
    return this;
  }

  /**
   * 向量加法
   * @param v 要相加的向量
   * @returns 当前向量引用
   */
  add(v: float3): this {
    this.x += v.x;
    this.y += v.y;
    this.z += v.z;
    return this;
  }

  /**
   * 向量减法
   * @param v 要相减的向量
   * @returns 当前向量引用
   */
  sub(v: float3): this {
    this.x -= v.x;
    this.y -= v.y;
    this.z -= v.z;
    return this;
  }

  /**
   * 向量乘法（分量相乘）
   * @param v 要相乘的向量
   * @returns 当前向量引用
   */
  mul(v: float3): this {
    this.x *= v.x;
    this.y *= v.y;
    this.z *= v.z;
    return this;
  }

  /**
   * 标量乘法
   * @param s 标量值
   * @returns 当前向量引用
   */
  scale(s: number): this {
    this.x *= s;
    this.y *= s;
    this.z *= s;
    return this;
  }

  /**
   * 向量除法（分量相除）
   * @param v 要相除的向量
   * @returns 当前向量引用
   */
  div(v: float3): this {
    this.x /= v.x;
    this.y /= v.y;
    this.z /= v.z;
    return this;
  }

  /**
   * 标量除法
   * @param s 标量值
   * @returns 当前向量引用
   */
  divScalar(s: number): this {
    const invS = 1 / s;
    this.x *= invS;
    this.y *= invS;
    this.z *= invS;
    return this;
  }

  /**
   * 计算向量长度
   * @returns 向量长度
   */
  length(): number {
    return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z);
  }

  /**
   * 计算向量长度的平方
   * @returns 向量长度的平方
   */
  lengthSq(): number {
    return this.x * this.x + this.y * this.y + this.z * this.z;
  }

  /**
   * 归一化向量
   * @returns 当前向量引用
   */
  normalize(): this {
    const len = this.length();
    if (len > 0) {
      this.divScalar(len);
    }
    return this;
  }

  /**
   * 计算点积
   * @param v 另一个向量
   * @returns 点积结果
   */
  dot(v: float3): number {
    return this.x * v.x + this.y * v.y + this.z * v.z;
  }

  /**
   * 计算叉积
   * @param v 另一个向量
   * @returns 当前向量引用
   */
  cross(v: float3): this {
    const x = this.y * v.z - this.z * v.y;
    const y = this.z * v.x - this.x * v.z;
    const z = this.x * v.y - this.y * v.x;
    
    this.x = x;
    this.y = y;
    this.z = z;
    return this;
  }

  /**
   * 计算到另一个点的距离
   * @param v 另一个点
   * @returns 距离
   */
  distance(v: float3): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    const dz = this.z - v.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /**
   * 计算到另一个点的距离的平方
   * @param v 另一个点
   * @returns 距离的平方
   */
  distanceSq(v: float3): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    const dz = this.z - v.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /**
   * 线性插值
   * @param v 目标向量
   * @param t 插值因子(0-1)
   * @returns 当前向量引用
   */
  lerp(v: float3, t: number): this {
    this.x = MathUtils.lerp(this.x, v.x, t);
    this.y = MathUtils.lerp(this.y, v.y, t);
    this.z = MathUtils.lerp(this.z, v.z, t);
    return this;
  }

  /**
   * 反射向量
   * @param normal 法线向量（需要归一化）
   * @returns 当前向量引用
   */
  reflect(normal: float3): this {
    const dot2 = 2 * this.dot(normal);
    this.x -= dot2 * normal.x;
    this.y -= dot2 * normal.y;
    this.z -= dot2 * normal.z;
    return this;
  }

  /**
   * 折射向量
   * @param normal 法线向量（需要归一化）
   * @param eta 折射率比值
   * @returns 当前向量引用
   */
  refract(normal: float3, eta: number): this {
    const dotNI = this.dot(normal);
    const k = 1 - eta * eta * (1 - dotNI * dotNI);
    
    if (k < 0) {
      this.set(0, 0, 0);
    } else {
      const factor = eta * dotNI + Math.sqrt(k);
      this.x = eta * this.x - factor * normal.x;
      this.y = eta * this.y - factor * normal.y;
      this.z = eta * this.z - factor * normal.z;
    }
    return this;
  }

  /**
   * 取绝对值
   * @returns 当前向量引用
   */
  abs(): this {
    this.x = Math.abs(this.x);
    this.y = Math.abs(this.y);
    this.z = Math.abs(this.z);
    return this;
  }

  /**
   * 向下取整
   * @returns 当前向量引用
   */
  floor(): this {
    this.x = Math.floor(this.x);
    this.y = Math.floor(this.y);
    this.z = Math.floor(this.z);
    return this;
  }

  /**
   * 向上取整
   * @returns 当前向量引用
   */
  ceil(): this {
    this.x = Math.ceil(this.x);
    this.y = Math.ceil(this.y);
    this.z = Math.ceil(this.z);
    return this;
  }

  /**
   * 四舍五入
   * @returns 当前向量引用
   */
  round(): this {
    this.x = Math.round(this.x);
    this.y = Math.round(this.y);
    this.z = Math.round(this.z);
    return this;
  }

  /**
   * 向零取整
   * @returns 当前向量引用
   */
  trunc(): this {
    this.x = Math.trunc(this.x);
    this.y = Math.trunc(this.y);
    this.z = Math.trunc(this.z);
    return this;
  }

  /**
   * 取小数部分
   * @returns 当前向量引用
   */
  fract(): this {
    this.x = this.x - Math.floor(this.x);
    this.y = this.y - Math.floor(this.y);
    this.z = this.z - Math.floor(this.z);
    return this;
  }

  /**
   * 限制到范围内
   * @param min 最小值
   * @param max 最大值
   * @returns 当前向量引用
   */
  clamp(min: float3, max: float3): this {
    this.x = MathUtils.clamp(this.x, min.x, max.x);
    this.y = MathUtils.clamp(this.y, min.y, max.y);
    this.z = MathUtils.clamp(this.z, min.z, max.z);
    return this;
  }

  /**
   * 比较相等
   * @param v 要比较的向量
   * @param epsilon 容差
   * @returns 是否相等
   */
  equals(v: float3, epsilon: number = MathUtils.EPSILON): boolean {
    return MathUtils.isEqual(this.x, v.x, epsilon) && 
           MathUtils.isEqual(this.y, v.y, epsilon) &&
           MathUtils.isEqual(this.z, v.z, epsilon);
  }

  /**
   * 转换为数组
   * @returns [x, y, z]数组
   */
  toArray(): [number, number, number] {
    return [this.x, this.y, this.z];
  }

  /**
   * 转换为字符串
   * @returns 字符串表示
   */
  toString(): string {
    return `float3(${this.x}, ${this.y}, ${this.z})`;
  }

  // 静态方法 - HLSL风格的函数

  /**
   * 静态加法
   */
  static add(a: float3, b: float3): float3 {
    return new float3(a.x + b.x, a.y + b.y, a.z + b.z);
  }

  /**
   * 静态减法
   */
  static sub(a: float3, b: float3): float3 {
    return new float3(a.x - b.x, a.y - b.y, a.z - b.z);
  }

  /**
   * 静态乘法
   */
  static mul(a: float3, b: float3): float3 {
    return new float3(a.x * b.x, a.y * b.y, a.z * b.z);
  }

  static scale(a: float3, b: number): float3 {
    return new float3(a.x * b, a.y * b, a.z * b);
  }

  /**
   * 静态除法
   */
  static div(a: float3, b: float3): float3 {
    return new float3(a.x / b.x, a.y / b.y, a.z / b.z);
  }

  /**
   * 静态点积
   */
  static dot(a: float3, b: float3): number {
    return a.x * b.x + a.y * b.y + a.z * b.z;
  }

  /**
   * 静态叉积
   */
  static cross(a: float3, b: float3): float3 {
    return new float3(
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x
    );
  }

  /**
   * 静态距离
   */
  static distance(a: float3, b: float3): number {
    return a.clone().sub(b).length();
  }

  /**
   * 静态归一化
   */
  static normalize(v: float3): float3 {
    return v.clone().normalize();
  }

  /**
   * 静态线性插值
   */
  static lerp(a: float3, b: float3, t: number): float3 {
    return new float3(
      MathUtils.lerp(a.x, b.x, t),
      MathUtils.lerp(a.y, b.y, t),
      MathUtils.lerp(a.z, b.z, t)
    );
  }

  /**
   * 静态最小值
   */
  static min(a: float3, b: float3): float3 {
    return new float3(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.min(a.z, b.z));
  }

  /**
   * 静态最大值
   */
  static max(a: float3, b: float3): float3 {
    return new float3(Math.max(a.x, b.x), Math.max(a.y, b.y), Math.max(a.z, b.z));
  }

  /**
   * 静态限制
   */
  static clamp(v: float3, min: float3, max: float3): float3 {
    return new float3(
      MathUtils.clamp(v.x, min.x, max.x),
      MathUtils.clamp(v.y, min.y, max.y),
      MathUtils.clamp(v.z, min.z, max.z)
    );
  }

  /**
   * 创建零向量
   */
  static zero(): float3 {
    return new float3(0, 0, 0);
  }

  /**
   * 创建单位向量
   */
  static one(): float3 {
    return new float3(1, 1, 1);
  }

  /**
   * 创建X轴单位向量
   */
  static unitX(): float3 {
    return new float3(1, 0, 0);
  }

  /**
   * 创建Y轴单位向量
   */
  static unitY(): float3 {
    return new float3(0, 1, 0);
  }

  /**
   * 创建Z轴单位向量
   */
  static unitZ(): float3 {
    return new float3(0, 0, 1);
  }

  /**
   * 创建向上向量
   */
  static up(): float3 {
    return new float3(0, 1, 0);
  }

  /**
   * 创建向下向量
   */
  static down(): float3 {
    return new float3(0, -1, 0);
  }

  /**
   * 创建向左向量
   */
  static left(): float3 {
    return new float3(-1, 0, 0);
  }

  /**
   * 创建向右向量
   */
  static right(): float3 {
    return new float3(1, 0, 0);
  }

  /**
   * 创建向前向量
   */
  static forward(): float3 {
    return new float3(0, 0, -1);
  }

  /**
   * 创建向后向量
   */
  static back(): float3 {
    return new float3(0, 0, 1);
  }
} 