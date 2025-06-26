import { MathUtils } from './math-utils';

/**
 * HLSL 风格的 float2 类型
 * 提供2D向量操作，兼容HLSL语法风格
 */
export class float2 {
  public x: number;
  public y: number;

  /**
   * 创建 float2
   * @param x X分量，默认为0
   * @param y Y分量，默认为0
   */
  constructor(x: number = 0, y: number = 0) {
    this.x = x;
    this.y = y;
  }

  // HLSL风格的swizzle属性
  get xx(): float2 { return new float2(this.x, this.x); }
  get xy(): float2 { return new float2(this.x, this.y); }
  get yx(): float2 { return new float2(this.y, this.x); }
  get yy(): float2 { return new float2(this.y, this.y); }

  // 颜色通道别名
  get r(): number { return this.x; }
  set r(value: number) { this.x = value; }
  get g(): number { return this.y; }
  set g(value: number) { this.y = value; }

  get rr(): float2 { return new float2(this.r, this.r); }
  get rg(): float2 { return new float2(this.r, this.g); }
  get gr(): float2 { return new float2(this.g, this.r); }
  get gg(): float2 { return new float2(this.g, this.g); }

  // 纹理坐标别名
  get u(): number { return this.x; }
  set u(value: number) { this.x = value; }
  get v(): number { return this.y; }
  set v(value: number) { this.y = value; }

  /**
   * 设置向量值
   * @param x X分量
   * @param y Y分量
   * @returns 当前向量引用
   */
  set(x: number, y: number): this {
    this.x = x;
    this.y = y;
    return this;
  }

  /**
   * 克隆向量
   * @returns 新的float2实例
   */
  clone(): float2 {
    return new float2(this.x, this.y);
  }

  /**
   * 复制另一个向量
   * @param v 要复制的向量
   * @returns 当前向量引用
   */
  copy(v: float2): this {
    this.x = v.x;
    this.y = v.y;
    return this;
  }

  /**
   * 向量加法
   * @param v 要相加的向量
   * @returns 当前向量引用
   */
  add(v: float2): this {
    this.x += v.x;
    this.y += v.y;
    return this;
  }

  /**
   * 向量减法
   * @param v 要相减的向量
   * @returns 当前向量引用
   */
  sub(v: float2): this {
    this.x -= v.x;
    this.y -= v.y;
    return this;
  }

  /**
   * 向量乘法（分量相乘）
   * @param v 要相乘的向量
   * @returns 当前向量引用
   */
  mul(v: float2): this {
    this.x *= v.x;
    this.y *= v.y;
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
    return this;
  }

  /**
   * 向量除法（分量相除）
   * @param v 要相除的向量
   * @returns 当前向量引用
   */
  div(v: float2): this {
    this.x /= v.x;
    this.y /= v.y;
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
    return this;
  }

  /**
   * 计算向量长度
   * @returns 向量长度
   */
  length(): number {
    return Math.sqrt(this.x * this.x + this.y * this.y);
  }

  /**
   * 计算向量长度的平方
   * @returns 向量长度的平方
   */
  lengthSq(): number {
    return this.x * this.x + this.y * this.y;
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
  dot(v: float2): number {
    return this.x * v.x + this.y * v.y;
  }

  /**
   * 计算到另一个点的距离
   * @param v 另一个点
   * @returns 距离
   */
  distance(v: float2): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    return Math.sqrt(dx * dx + dy * dy);
  }

  /**
   * 计算到另一个点的距离的平方
   * @param v 另一个点
   * @returns 距离的平方
   */
  distanceSq(v: float2): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    return dx * dx + dy * dy;
  }

  /**
   * 线性插值
   * @param v 目标向量
   * @param t 插值因子(0-1)
   * @returns 当前向量引用
   */
  lerp(v: float2, t: number): this {
    this.x = MathUtils.lerp(this.x, v.x, t);
    this.y = MathUtils.lerp(this.y, v.y, t);
    return this;
  }

  /**
   * 反射向量
   * @param normal 法线向量（需要归一化）
   * @returns 当前向量引用
   */
  reflect(normal: float2): this {
    const dot2 = 2 * this.dot(normal);
    this.x -= dot2 * normal.x;
    this.y -= dot2 * normal.y;
    return this;
  }

  /**
   * 折射向量
   * @param normal 法线向量（需要归一化）
   * @param eta 折射率比值
   * @returns 当前向量引用
   */
  refract(normal: float2, eta: number): this {
    const dotNI = this.dot(normal);
    const k = 1 - eta * eta * (1 - dotNI * dotNI);
    
    if (k < 0) {
      this.set(0, 0);
    } else {
      const factor = eta * dotNI + Math.sqrt(k);
      this.x = eta * this.x - factor * normal.x;
      this.y = eta * this.y - factor * normal.y;
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
    return this;
  }

  /**
   * 向下取整
   * @returns 当前向量引用
   */
  floor(): this {
    this.x = Math.floor(this.x);
    this.y = Math.floor(this.y);
    return this;
  }

  /**
   * 向上取整
   * @returns 当前向量引用
   */
  ceil(): this {
    this.x = Math.ceil(this.x);
    this.y = Math.ceil(this.y);
    return this;
  }

  /**
   * 四舍五入
   * @returns 当前向量引用
   */
  round(): this {
    this.x = Math.round(this.x);
    this.y = Math.round(this.y);
    return this;
  }

  /**
   * 向零取整
   * @returns 当前向量引用
   */
  trunc(): this {
    this.x = Math.trunc(this.x);
    this.y = Math.trunc(this.y);
    return this;
  }

  /**
   * 取小数部分
   * @returns 当前向量引用
   */
  fract(): this {
    this.x = this.x - Math.floor(this.x);
    this.y = this.y - Math.floor(this.y);
    return this;
  }

  /**
   * 限制到范围内
   * @param min 最小值
   * @param max 最大值
   * @returns 当前向量引用
   */
  clamp(min: float2, max: float2): this {
    this.x = MathUtils.clamp(this.x, min.x, max.x);
    this.y = MathUtils.clamp(this.y, min.y, max.y);
    return this;
  }

  /**
   * 比较相等
   * @param v 要比较的向量
   * @param epsilon 容差
   * @returns 是否相等
   */
  equals(v: float2, epsilon: number = MathUtils.EPSILON): boolean {
    return MathUtils.isEqual(this.x, v.x, epsilon) && 
           MathUtils.isEqual(this.y, v.y, epsilon);
  }

  /**
   * 转换为数组
   * @returns [x, y]数组
   */
  toArray(): [number, number] {
    return [this.x, this.y];
  }

  /**
   * 转换为字符串
   * @returns 字符串表示
   */
  toString(): string {
    return `float2(${this.x}, ${this.y})`;
  }

  // 静态方法 - HLSL风格的函数

  /**
   * 静态加法
   */
  static add(a: float2, b: float2): float2 {
    return new float2(a.x + b.x, a.y + b.y);
  }

  /**
   * 静态减法
   */
  static sub(a: float2, b: float2): float2 {
    return new float2(a.x - b.x, a.y - b.y);
  }

  /**
   * 静态乘法
   */
  static mul(a: float2, b: float2): float2 {
    return new float2(a.x * b.x, a.y * b.y);
  }

  /**
   * 静态除法
   */
  static div(a: float2, b: float2): float2 {
    return new float2(a.x / b.x, a.y / b.y);
  }

  /**
   * 静态点积
   */
  static dot(a: float2, b: float2): number {
    return a.x * b.x + a.y * b.y;
  }

  /**
   * 静态距离
   */
  static distance(a: float2, b: float2): number {
    return a.clone().sub(b).length();
  }

  /**
   * 静态归一化
   */
  static normalize(v: float2): float2 {
    return v.clone().normalize();
  }

  /**
   * 静态线性插值
   */
  static lerp(a: float2, b: float2, t: number): float2 {
    return new float2(
      MathUtils.lerp(a.x, b.x, t),
      MathUtils.lerp(a.y, b.y, t)
    );
  }

  /**
   * 静态最小值
   */
  static min(a: float2, b: float2): float2 {
    return new float2(Math.min(a.x, b.x), Math.min(a.y, b.y));
  }

  /**
   * 静态最大值
   */
  static max(a: float2, b: float2): float2 {
    return new float2(Math.max(a.x, b.x), Math.max(a.y, b.y));
  }

  /**
   * 静态限制
   */
  static clamp(v: float2, min: float2, max: float2): float2 {
    return new float2(
      MathUtils.clamp(v.x, min.x, max.x),
      MathUtils.clamp(v.y, min.y, max.y)
    );
  }

  /**
   * 创建零向量
   */
  static zero(): float2 {
    return new float2(0, 0);
  }

  /**
   * 创建单位向量
   */
  static one(): float2 {
    return new float2(1, 1);
  }

  /**
   * 创建X轴单位向量
   */
  static unitX(): float2 {
    return new float2(1, 0);
  }

  /**
   * 创建Y轴单位向量
   */
  static unitY(): float2 {
    return new float2(0, 1);
  }
} 