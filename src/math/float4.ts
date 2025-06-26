import { MathUtils } from './math-utils';
import { float2 } from './float2';
import { float3 } from './float3';

/**
 * HLSL 风格的 float4 类型
 * 提供4D向量操作，兼容HLSL语法风格
 */
export class float4 {
  public x: number;
  public y: number;
  public z: number;
  public w: number;

  /**
   * 创建 float4
   * @param x X分量，默认为0
   * @param y Y分量，默认为0
   * @param z Z分量，默认为0
   * @param w W分量，默认为1
   */
  constructor(x: number = 0, y: number = 0, z: number = 0, w: number = 1) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
  }

  // HLSL风格的swizzle属性 (2分量)
  get xx(): float2 { return new float2(this.x, this.x); }
  get xy(): float2 { return new float2(this.x, this.y); }
  get xz(): float2 { return new float2(this.x, this.z); }
  get xw(): float2 { return new float2(this.x, this.w); }
  get yx(): float2 { return new float2(this.y, this.x); }
  get yy(): float2 { return new float2(this.y, this.y); }
  get yz(): float2 { return new float2(this.y, this.z); }
  get yw(): float2 { return new float2(this.y, this.w); }
  get zx(): float2 { return new float2(this.z, this.x); }
  get zy(): float2 { return new float2(this.z, this.y); }
  get zz(): float2 { return new float2(this.z, this.z); }
  get zw(): float2 { return new float2(this.z, this.w); }
  get wx(): float2 { return new float2(this.w, this.x); }
  get wy(): float2 { return new float2(this.w, this.y); }
  get wz(): float2 { return new float2(this.w, this.z); }
  get ww(): float2 { return new float2(this.w, this.w); }

  // HLSL风格的swizzle属性 (3分量)
  get xxx(): float3 { return new float3(this.x, this.x, this.x); }
  get xxy(): float3 { return new float3(this.x, this.x, this.y); }
  get xxz(): float3 { return new float3(this.x, this.x, this.z); }
  get xxw(): float3 { return new float3(this.x, this.x, this.w); }
  get xyx(): float3 { return new float3(this.x, this.y, this.x); }
  get xyy(): float3 { return new float3(this.x, this.y, this.y); }
  get xyz(): float3 { return new float3(this.x, this.y, this.z); }
  get xyw(): float3 { return new float3(this.x, this.y, this.w); }
  get xzx(): float3 { return new float3(this.x, this.z, this.x); }
  get xzy(): float3 { return new float3(this.x, this.z, this.y); }
  get xzz(): float3 { return new float3(this.x, this.z, this.z); }
  get xzw(): float3 { return new float3(this.x, this.z, this.w); }
  get xwx(): float3 { return new float3(this.x, this.w, this.x); }
  get xwy(): float3 { return new float3(this.x, this.w, this.y); }
  get xwz(): float3 { return new float3(this.x, this.w, this.z); }
  get xww(): float3 { return new float3(this.x, this.w, this.w); }
  
  get yxx(): float3 { return new float3(this.y, this.x, this.x); }
  get yxy(): float3 { return new float3(this.y, this.x, this.y); }
  get yxz(): float3 { return new float3(this.y, this.x, this.z); }
  get yxw(): float3 { return new float3(this.y, this.x, this.w); }
  get yyx(): float3 { return new float3(this.y, this.y, this.x); }
  get yyy(): float3 { return new float3(this.y, this.y, this.y); }
  get yyz(): float3 { return new float3(this.y, this.y, this.z); }
  get yyw(): float3 { return new float3(this.y, this.y, this.w); }
  get yzx(): float3 { return new float3(this.y, this.z, this.x); }
  get yzy(): float3 { return new float3(this.y, this.z, this.y); }
  get yzz(): float3 { return new float3(this.y, this.z, this.z); }
  get yzw(): float3 { return new float3(this.y, this.z, this.w); }
  get ywx(): float3 { return new float3(this.y, this.w, this.x); }
  get ywy(): float3 { return new float3(this.y, this.w, this.y); }
  get ywz(): float3 { return new float3(this.y, this.w, this.z); }
  get yww(): float3 { return new float3(this.y, this.w, this.w); }

  get zxx(): float3 { return new float3(this.z, this.x, this.x); }
  get zxy(): float3 { return new float3(this.z, this.x, this.y); }
  get zxz(): float3 { return new float3(this.z, this.x, this.z); }
  get zxw(): float3 { return new float3(this.z, this.x, this.w); }
  get zyx(): float3 { return new float3(this.z, this.y, this.x); }
  get zyy(): float3 { return new float3(this.z, this.y, this.y); }
  get zyz(): float3 { return new float3(this.z, this.y, this.z); }
  get zyw(): float3 { return new float3(this.z, this.y, this.w); }
  get zzx(): float3 { return new float3(this.z, this.z, this.x); }
  get zzy(): float3 { return new float3(this.z, this.z, this.y); }
  get zzz(): float3 { return new float3(this.z, this.z, this.z); }
  get zzw(): float3 { return new float3(this.z, this.z, this.w); }
  get zwx(): float3 { return new float3(this.z, this.w, this.x); }
  get zwy(): float3 { return new float3(this.z, this.w, this.y); }
  get zwz(): float3 { return new float3(this.z, this.w, this.z); }
  get zww(): float3 { return new float3(this.z, this.w, this.w); }

  get wxx(): float3 { return new float3(this.w, this.x, this.x); }
  get wxy(): float3 { return new float3(this.w, this.x, this.y); }
  get wxz(): float3 { return new float3(this.w, this.x, this.z); }
  get wxw(): float3 { return new float3(this.w, this.x, this.w); }
  get wyx(): float3 { return new float3(this.w, this.y, this.x); }
  get wyy(): float3 { return new float3(this.w, this.y, this.y); }
  get wyz(): float3 { return new float3(this.w, this.y, this.z); }
  get wyw(): float3 { return new float3(this.w, this.y, this.w); }
  get wzx(): float3 { return new float3(this.w, this.z, this.x); }
  get wzy(): float3 { return new float3(this.w, this.z, this.y); }
  get wzz(): float3 { return new float3(this.w, this.z, this.z); }
  get wzw(): float3 { return new float3(this.w, this.z, this.w); }
  get wwx(): float3 { return new float3(this.w, this.w, this.x); }
  get wwy(): float3 { return new float3(this.w, this.w, this.y); }
  get wwz(): float3 { return new float3(this.w, this.w, this.z); }
  get www(): float3 { return new float3(this.w, this.w, this.w); }

  // HLSL风格的swizzle属性 (4分量，常用的)
  get xyzw(): float4 { return new float4(this.x, this.y, this.z, this.w); }
  get xywz(): float4 { return new float4(this.x, this.y, this.w, this.z); }
  get xzyw(): float4 { return new float4(this.x, this.z, this.y, this.w); }
  get xzwy(): float4 { return new float4(this.x, this.z, this.w, this.y); }
  get xwyz(): float4 { return new float4(this.x, this.w, this.y, this.z); }
  get xwzy(): float4 { return new float4(this.x, this.w, this.z, this.y); }
  get yxzw(): float4 { return new float4(this.y, this.x, this.z, this.w); }
  get yxwz(): float4 { return new float4(this.y, this.x, this.w, this.z); }
  get yzxw(): float4 { return new float4(this.y, this.z, this.x, this.w); }
  get yzwx(): float4 { return new float4(this.y, this.z, this.w, this.x); }
  get ywxz(): float4 { return new float4(this.y, this.w, this.x, this.z); }
  get ywzx(): float4 { return new float4(this.y, this.w, this.z, this.x); }
  get zxyw(): float4 { return new float4(this.z, this.x, this.y, this.w); }
  get zxwy(): float4 { return new float4(this.z, this.x, this.w, this.y); }
  get zyxw(): float4 { return new float4(this.z, this.y, this.x, this.w); }
  get zywx(): float4 { return new float4(this.z, this.y, this.w, this.x); }
  get zwxy(): float4 { return new float4(this.z, this.w, this.x, this.y); }
  get zwyx(): float4 { return new float4(this.z, this.w, this.y, this.x); }
  get wxyz(): float4 { return new float4(this.w, this.x, this.y, this.z); }
  get wxzy(): float4 { return new float4(this.w, this.x, this.z, this.y); }
  get wyxz(): float4 { return new float4(this.w, this.y, this.x, this.z); }
  get wyzx(): float4 { return new float4(this.w, this.y, this.z, this.x); }
  get wzxy(): float4 { return new float4(this.w, this.z, this.x, this.y); }
  get wzyx(): float4 { return new float4(this.w, this.z, this.y, this.x); }

  // 颜色通道别名（RGBA）
  get r(): number { return this.x; }
  set r(value: number) { this.x = value; }
  get g(): number { return this.y; }
  set g(value: number) { this.y = value; }
  get b(): number { return this.z; }
  set b(value: number) { this.z = value; }
  get a(): number { return this.w; }
  set a(value: number) { this.w = value; }

  get rr(): float2 { return new float2(this.r, this.r); }
  get rg(): float2 { return new float2(this.r, this.g); }
  get rb(): float2 { return new float2(this.r, this.b); }
  get ra(): float2 { return new float2(this.r, this.a); }
  get gr(): float2 { return new float2(this.g, this.r); }
  get gg(): float2 { return new float2(this.g, this.g); }
  get gb(): float2 { return new float2(this.g, this.b); }
  get ga(): float2 { return new float2(this.g, this.a); }
  get br(): float2 { return new float2(this.b, this.r); }
  get bg(): float2 { return new float2(this.b, this.g); }
  get bb(): float2 { return new float2(this.b, this.b); }
  get ba(): float2 { return new float2(this.b, this.a); }
  get ar(): float2 { return new float2(this.a, this.r); }
  get ag(): float2 { return new float2(this.a, this.g); }
  get ab(): float2 { return new float2(this.a, this.b); }
  get aa(): float2 { return new float2(this.a, this.a); }

  get rgb(): float3 { return new float3(this.r, this.g, this.b); }
  get rga(): float3 { return new float3(this.r, this.g, this.a); }
  get rbg(): float3 { return new float3(this.r, this.b, this.g); }
  get rba(): float3 { return new float3(this.r, this.b, this.a); }
  get rag(): float3 { return new float3(this.r, this.a, this.g); }
  get rab(): float3 { return new float3(this.r, this.a, this.b); }
  get grb(): float3 { return new float3(this.g, this.r, this.b); }
  get gra(): float3 { return new float3(this.g, this.r, this.a); }
  get gbr(): float3 { return new float3(this.g, this.b, this.r); }
  get gba(): float3 { return new float3(this.g, this.b, this.a); }
  get gar(): float3 { return new float3(this.g, this.a, this.r); }
  get gab(): float3 { return new float3(this.g, this.a, this.b); }
  get brg(): float3 { return new float3(this.b, this.r, this.g); }
  get bra(): float3 { return new float3(this.b, this.r, this.a); }
  get bgr(): float3 { return new float3(this.b, this.g, this.r); }
  get bga(): float3 { return new float3(this.b, this.g, this.a); }
  get bar(): float3 { return new float3(this.b, this.a, this.r); }
  get bag(): float3 { return new float3(this.b, this.a, this.g); }
  get arg(): float3 { return new float3(this.a, this.r, this.g); }
  get arb(): float3 { return new float3(this.a, this.r, this.b); }
  get agr(): float3 { return new float3(this.a, this.g, this.r); }
  get agb(): float3 { return new float3(this.a, this.g, this.b); }
  get abr(): float3 { return new float3(this.a, this.b, this.r); }
  get abg(): float3 { return new float3(this.a, this.b, this.g); }

  get rgba(): float4 { return new float4(this.r, this.g, this.b, this.a); }
  get rgab(): float4 { return new float4(this.r, this.g, this.a, this.b); }
  get rbga(): float4 { return new float4(this.r, this.b, this.g, this.a); }
  get rbag(): float4 { return new float4(this.r, this.b, this.a, this.g); }
  get ragb(): float4 { return new float4(this.r, this.a, this.g, this.b); }
  get rabg(): float4 { return new float4(this.r, this.a, this.b, this.g); }
  get grba(): float4 { return new float4(this.g, this.r, this.b, this.a); }
  get grab(): float4 { return new float4(this.g, this.r, this.a, this.b); }
  get gbra(): float4 { return new float4(this.g, this.b, this.r, this.a); }
  get gbar(): float4 { return new float4(this.g, this.b, this.a, this.r); }
  get garb(): float4 { return new float4(this.g, this.a, this.r, this.b); }
  get gabr(): float4 { return new float4(this.g, this.a, this.b, this.r); }
  get brga(): float4 { return new float4(this.b, this.r, this.g, this.a); }
  get brag(): float4 { return new float4(this.b, this.r, this.a, this.g); }
  get bgra(): float4 { return new float4(this.b, this.g, this.r, this.a); }
  get bgar(): float4 { return new float4(this.b, this.g, this.a, this.r); }
  get barg(): float4 { return new float4(this.b, this.a, this.r, this.g); }
  get bagr(): float4 { return new float4(this.b, this.a, this.g, this.r); }
  get argb(): float4 { return new float4(this.a, this.r, this.g, this.b); }
  get arbg(): float4 { return new float4(this.a, this.r, this.b, this.g); }
  get agrb(): float4 { return new float4(this.a, this.g, this.r, this.b); }
  get agbr(): float4 { return new float4(this.a, this.g, this.b, this.r); }
  get abrg(): float4 { return new float4(this.a, this.b, this.r, this.g); }
  get abgr(): float4 { return new float4(this.a, this.b, this.g, this.r); }

  /**
   * 设置向量值
   * @param x X分量
   * @param y Y分量
   * @param z Z分量
   * @param w W分量
   * @returns 当前向量引用
   */
  set(x: number, y: number, z: number, w: number): this {
    this.x = x;
    this.y = y;
    this.z = z;
    this.w = w;
    return this;
  }

  /**
   * 克隆向量
   * @returns 新的float4实例
   */
  clone(): float4 {
    return new float4(this.x, this.y, this.z, this.w);
  }

  /**
   * 复制另一个向量
   * @param v 要复制的向量
   * @returns 当前向量引用
   */
  copy(v: float4): this {
    this.x = v.x;
    this.y = v.y;
    this.z = v.z;
    this.w = v.w;
    return this;
  }

  /**
   * 从float3复制，保持当前w值
   * @param v 要复制的向量
   * @returns 当前向量引用
   */
  copyFromFloat3(v: float3): this {
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
  add(v: float4): this {
    this.x += v.x;
    this.y += v.y;
    this.z += v.z;
    this.w += v.w;
    return this;
  }

  /**
   * 向量减法
   * @param v 要相减的向量
   * @returns 当前向量引用
   */
  sub(v: float4): this {
    this.x -= v.x;
    this.y -= v.y;
    this.z -= v.z;
    this.w -= v.w;
    return this;
  }

  /**
   * 向量乘法（分量相乘）
   * @param v 要相乘的向量
   * @returns 当前向量引用
   */
  mul(v: float4): this {
    this.x *= v.x;
    this.y *= v.y;
    this.z *= v.z;
    this.w *= v.w;
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
    this.w *= s;
    return this;
  }

  /**
   * 向量除法（分量相除）
   * @param v 要相除的向量
   * @returns 当前向量引用
   */
  div(v: float4): this {
    this.x /= v.x;
    this.y /= v.y;
    this.z /= v.z;
    this.w /= v.w;
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
    this.w *= invS;
    return this;
  }

  /**
   * 计算向量长度
   * @returns 向量长度
   */
  length(): number {
    return Math.sqrt(this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w);
  }

  /**
   * 计算向量长度的平方
   * @returns 向量长度的平方
   */
  lengthSq(): number {
    return this.x * this.x + this.y * this.y + this.z * this.z + this.w * this.w;
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
  dot(v: float4): number {
    return this.x * v.x + this.y * v.y + this.z * v.z + this.w * v.w;
  }

  /**
   * 计算到另一个点的距离
   * @param v 另一个点
   * @returns 距离
   */
  distance(v: float4): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    const dz = this.z - v.z;
    const dw = this.w - v.w;
    return Math.sqrt(dx * dx + dy * dy + dz * dz + dw * dw);
  }

  /**
   * 计算到另一个点的距离的平方
   * @param v 另一个点
   * @returns 距离的平方
   */
  distanceSq(v: float4): number {
    const dx = this.x - v.x;
    const dy = this.y - v.y;
    const dz = this.z - v.z;
    const dw = this.w - v.w;
    return dx * dx + dy * dy + dz * dz + dw * dw;
  }

  /**
   * 线性插值
   * @param v 目标向量
   * @param t 插值因子(0-1)
   * @returns 当前向量引用
   */
  lerp(v: float4, t: number): this {
    this.x = MathUtils.lerp(this.x, v.x, t);
    this.y = MathUtils.lerp(this.y, v.y, t);
    this.z = MathUtils.lerp(this.z, v.z, t);
    this.w = MathUtils.lerp(this.w, v.w, t);
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
    this.w = Math.abs(this.w);
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
    this.w = Math.floor(this.w);
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
    this.w = Math.ceil(this.w);
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
    this.w = Math.round(this.w);
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
    this.w = Math.trunc(this.w);
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
    this.w = this.w - Math.floor(this.w);
    return this;
  }

  /**
   * 限制到范围内
   * @param min 最小值
   * @param max 最大值
   * @returns 当前向量引用
   */
  clamp(min: float4, max: float4): this {
    this.x = MathUtils.clamp(this.x, min.x, max.x);
    this.y = MathUtils.clamp(this.y, min.y, max.y);
    this.z = MathUtils.clamp(this.z, min.z, max.z);
    this.w = MathUtils.clamp(this.w, min.w, max.w);
    return this;
  }

  /**
   * 比较相等
   * @param v 要比较的向量
   * @param epsilon 容差
   * @returns 是否相等
   */
  equals(v: float4, epsilon: number = MathUtils.EPSILON): boolean {
    return MathUtils.isEqual(this.x, v.x, epsilon) && 
           MathUtils.isEqual(this.y, v.y, epsilon) &&
           MathUtils.isEqual(this.z, v.z, epsilon) &&
           MathUtils.isEqual(this.w, v.w, epsilon);
  }

  /**
   * 转换为数组
   * @returns [x, y, z, w]数组
   */
  toArray(): [number, number, number, number] {
    return [this.x, this.y, this.z, this.w];
  }

  /**
   * 转换为字符串
   * @returns 字符串表示
   */
  toString(): string {
    return `float4(${this.x}, ${this.y}, ${this.z}, ${this.w})`;
  }

  // 静态方法 - HLSL风格的函数

  /**
   * 静态加法
   */
  static add(a: float4, b: float4): float4 {
    return new float4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
  }

  /**
   * 静态减法
   */
  static sub(a: float4, b: float4): float4 {
    return new float4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w);
  }

  /**
   * 静态乘法
   */
  static mul(a: float4, b: float4): float4 {
    return new float4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
  }

  /**
   * 静态除法
   */
  static div(a: float4, b: float4): float4 {
    return new float4(a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w);
  }

  /**
   * 静态点积
   */
  static dot(a: float4, b: float4): number {
    return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
  }

  /**
   * 静态距离
   */
  static distance(a: float4, b: float4): number {
    return a.clone().sub(b).length();
  }

  /**
   * 静态归一化
   */
  static normalize(v: float4): float4 {
    return v.clone().normalize();
  }

  /**
   * 静态线性插值
   */
  static lerp(a: float4, b: float4, t: number): float4 {
    return new float4(
      MathUtils.lerp(a.x, b.x, t),
      MathUtils.lerp(a.y, b.y, t),
      MathUtils.lerp(a.z, b.z, t),
      MathUtils.lerp(a.w, b.w, t)
    );
  }

  /**
   * 静态最小值
   */
  static min(a: float4, b: float4): float4 {
    return new float4(
      Math.min(a.x, b.x), 
      Math.min(a.y, b.y), 
      Math.min(a.z, b.z), 
      Math.min(a.w, b.w)
    );
  }

  /**
   * 静态最大值
   */
  static max(a: float4, b: float4): float4 {
    return new float4(
      Math.max(a.x, b.x), 
      Math.max(a.y, b.y), 
      Math.max(a.z, b.z), 
      Math.max(a.w, b.w)
    );
  }

  /**
   * 静态限制
   */
  static clamp(v: float4, min: float4, max: float4): float4 {
    return new float4(
      MathUtils.clamp(v.x, min.x, max.x),
      MathUtils.clamp(v.y, min.y, max.y),
      MathUtils.clamp(v.z, min.z, max.z),
      MathUtils.clamp(v.w, min.w, max.w)
    );
  }

  /**
   * 创建零向量
   */
  static zero(): float4 {
    return new float4(0, 0, 0, 0);
  }

  /**
   * 创建单位向量
   */
  static one(): float4 {
    return new float4(1, 1, 1, 1);
  }

  /**
   * 创建X轴单位向量
   */
  static unitX(): float4 {
    return new float4(1, 0, 0, 0);
  }

  /**
   * 创建Y轴单位向量
   */
  static unitY(): float4 {
    return new float4(0, 1, 0, 0);
  }

  /**
   * 创建Z轴单位向量
   */
  static unitZ(): float4 {
    return new float4(0, 0, 1, 0);
  }

  /**
   * 创建W轴单位向量
   */
  static unitW(): float4 {
    return new float4(0, 0, 0, 1);
  }

  /**
   * 从float3创建（w设为1）
   */
  static fromFloat3(v: float3, w: number = 1): float4 {
    return new float4(v.x, v.y, v.z, w);
  }

  /**
   * 创建位置向量（w=1）
   */
  static position(x: number, y: number, z: number): float4 {
    return new float4(x, y, z, 1);
  }

  /**
   * 创建方向向量（w=0）
   */
  static direction(x: number, y: number, z: number): float4 {
    return new float4(x, y, z, 0);
  }

  /**
   * 创建颜色向量
   */
  static color(r: number, g: number, b: number, a: number = 1): float4 {
    return new float4(r, g, b, a);
  }

  /**
   * 从RGB创建颜色（alpha=1）
   */
  static rgb(r: number, g: number, b: number): float4 {
    return new float4(r, g, b, 1);
  }

  /**
   * 从16进制颜色创建
   * @param hex 16进制颜色值 (例如: 0xFF0000 为红色)
   * @param includeAlpha 是否包含alpha通道
   */
  static fromHex(hex: number, includeAlpha: boolean = false): float4 {
    if (includeAlpha) {
      const r = ((hex >> 24) & 0xFF) / 255;
      const g = ((hex >> 16) & 0xFF) / 255;
      const b = ((hex >> 8) & 0xFF) / 255;
      const a = (hex & 0xFF) / 255;
      return new float4(r, g, b, a);
    } else {
      const r = ((hex >> 16) & 0xFF) / 255;
      const g = ((hex >> 8) & 0xFF) / 255;
      const b = (hex & 0xFF) / 255;
      return new float4(r, g, b, 1);
    }
  }
} 