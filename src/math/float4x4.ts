import { float3 } from './float3';

/**
 * 4x4 矩阵类
 * 用于 3D 变换（模型、视图、投影矩阵）
 * 
 * 存储格式：列主序（column-major），与 WebGPU/WGSL 一致
 * 内存布局：
 * [m0, m1, m2, m3,   <- 第一列 (x轴或第一列向量)
 *  m4, m5, m6, m7,   <- 第二列 (y轴或第二列向量)
 *  m8, m9, m10, m11, <- 第三列 (z轴或第三列向量)
 *  m12, m13, m14, m15] <- 第四列 (平移或第四列向量)
 */
export class float4x4 {
  public elements: number[];

  /**
   * 创建一个单位矩阵
   */
  constructor() {
    this.elements = [
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1
    ];
  }

  /**
   * 设置矩阵元素
   */
  set(
    m0: number, m1: number, m2: number, m3: number,
    m4: number, m5: number, m6: number, m7: number,
    m8: number, m9: number, m10: number, m11: number,
    m12: number, m13: number, m14: number, m15: number
  ): this {
    this.elements = [
      m0, m1, m2, m3,
      m4, m5, m6, m7,
      m8, m9, m10, m11,
      m12, m13, m14, m15
    ];
    return this;
  }

  /**
   * 克隆矩阵
   */
  clone(): float4x4 {
    const result = new float4x4();
    result.elements = [...this.elements];
    return result;
  }

  /**
   * 复制另一个矩阵
   */
  copy(m: float4x4): this {
    this.elements = [...m.elements];
    return this;
  }

  /**
   * 设置为单位矩阵
   */
  identity(): this {
    this.elements = [
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1
    ];
    return this;
  }

  /**
   * 矩阵乘法（左乘）
   * this = this * m
   */
  multiply(m: float4x4): this {
    const result = float4x4.multiply(this, m);
    this.elements = result.elements;
    return this;
  }

  /**
   * 矩阵乘法（右乘）
   * this = m * this
   */
  premultiply(m: float4x4): this {
    const result = float4x4.multiply(m, this);
    this.elements = result.elements;
    return this;
  }

  /**
   * 转置矩阵
   */
  transpose(): this {
    const e = this.elements;
    let temp: number;

    temp = e[1]; e[1] = e[4]; e[4] = temp;
    temp = e[2]; e[2] = e[8]; e[8] = temp;
    temp = e[3]; e[3] = e[12]; e[12] = temp;
    temp = e[6]; e[6] = e[9]; e[9] = temp;
    temp = e[7]; e[7] = e[13]; e[13] = temp;
    temp = e[11]; e[11] = e[14]; e[14] = temp;

    return this;
  }

  /**
   * 转换为数组
   */
  toArray(): number[] {
    return [...this.elements];
  }

  /**
   * 转换为 Float32Array（用于 GPU 上传）
   */
  toFloat32Array(): Float32Array {
    return new Float32Array(this.elements);
  }

  // ========== 静态工厂方法 ==========

  /**
   * 创建单位矩阵
   */
  static identity(): float4x4 {
    return new float4x4();
  }

  /**
   * 创建平移矩阵
   */
  static translation(x: number, y: number, z: number): float4x4 {
    const result = new float4x4();
    result.elements[12] = x;
    result.elements[13] = y;
    result.elements[14] = z;
    return result;
  }

  /**
   * 创建平移矩阵（从向量）
   */
  static translationFromVector(v: float3): float4x4 {
    return float4x4.translation(v.x, v.y, v.z);
  }

  /**
   * 创建缩放矩阵
   */
  static scaling(x: number, y: number, z: number): float4x4 {
    const result = new float4x4();
    result.elements[0] = x;
    result.elements[5] = y;
    result.elements[10] = z;
    return result;
  }

  /**
   * 创建均匀缩放矩阵
   */
  static uniformScaling(s: number): float4x4 {
    return float4x4.scaling(s, s, s);
  }

  /**
   * 创建绕 X 轴旋转的矩阵
   * @param angleRadians 旋转角度（弧度）
   */
  static rotationX(angleRadians: number): float4x4 {
    const c = Math.cos(angleRadians);
    const s = Math.sin(angleRadians);
    const result = new float4x4();
    
    result.elements[5] = c;
    result.elements[6] = s;
    result.elements[9] = -s;
    result.elements[10] = c;
    
    return result;
  }

  /**
   * 创建绕 Y 轴旋转的矩阵
   * @param angleRadians 旋转角度（弧度）
   */
  static rotationY(angleRadians: number): float4x4 {
    const c = Math.cos(angleRadians);
    const s = Math.sin(angleRadians);
    const result = new float4x4();
    
    result.elements[0] = c;
    result.elements[2] = -s;
    result.elements[8] = s;
    result.elements[10] = c;
    
    return result;
  }

  /**
   * 创建绕 Z 轴旋转的矩阵
   * @param angleRadians 旋转角度（弧度）
   */
  static rotationZ(angleRadians: number): float4x4 {
    const c = Math.cos(angleRadians);
    const s = Math.sin(angleRadians);
    const result = new float4x4();
    
    result.elements[0] = c;
    result.elements[1] = s;
    result.elements[4] = -s;
    result.elements[5] = c;
    
    return result;
  }

  /**
   * 创建绕任意轴旋转的矩阵
   * @param axis 旋转轴（需要归一化）
   * @param angleRadians 旋转角度（弧度）
   */
  static rotationAxis(axis: float3, angleRadians: number): float4x4 {
    const c = Math.cos(angleRadians);
    const s = Math.sin(angleRadians);
    const t = 1 - c;
    
    const x = axis.x;
    const y = axis.y;
    const z = axis.z;
    
    const result = new float4x4();
    const e = result.elements;
    
    e[0] = t * x * x + c;
    e[1] = t * x * y + s * z;
    e[2] = t * x * z - s * y;
    e[3] = 0;
    
    e[4] = t * x * y - s * z;
    e[5] = t * y * y + c;
    e[6] = t * y * z + s * x;
    e[7] = 0;
    
    e[8] = t * x * z + s * y;
    e[9] = t * y * z - s * x;
    e[10] = t * z * z + c;
    e[11] = 0;
    
    e[12] = 0;
    e[13] = 0;
    e[14] = 0;
    e[15] = 1;
    
    return result;
  }

  /**
   * 创建欧拉角旋转矩阵（XYZ 顺序）
   * @param x 绕 X 轴旋转角度（弧度）
   * @param y 绕 Y 轴旋转角度（弧度）
   * @param z 绕 Z 轴旋转角度（弧度）
   */
  static rotationEulerXYZ(x: number, y: number, z: number): float4x4 {
    const rx = float4x4.rotationX(x);
    const ry = float4x4.rotationY(y);
    const rz = float4x4.rotationZ(z);
    
    // 组合顺序：先 X，然后 Y，最后 Z
    return float4x4.multiply(float4x4.multiply(rz, ry), rx);
  }

  /**
   * 矩阵乘法
   * 返回 a * b
   */
  static multiply(a: float4x4, b: float4x4): float4x4 {
    const ae = a.elements;
    const be = b.elements;
    const result = new float4x4();
    const re = result.elements;

    const a00 = ae[0], a01 = ae[1], a02 = ae[2], a03 = ae[3];
    const a10 = ae[4], a11 = ae[5], a12 = ae[6], a13 = ae[7];
    const a20 = ae[8], a21 = ae[9], a22 = ae[10], a23 = ae[11];
    const a30 = ae[12], a31 = ae[13], a32 = ae[14], a33 = ae[15];

    const b00 = be[0], b01 = be[1], b02 = be[2], b03 = be[3];
    const b10 = be[4], b11 = be[5], b12 = be[6], b13 = be[7];
    const b20 = be[8], b21 = be[9], b22 = be[10], b23 = be[11];
    const b30 = be[12], b31 = be[13], b32 = be[14], b33 = be[15];

    re[0] = a00 * b00 + a10 * b01 + a20 * b02 + a30 * b03;
    re[1] = a01 * b00 + a11 * b01 + a21 * b02 + a31 * b03;
    re[2] = a02 * b00 + a12 * b01 + a22 * b02 + a32 * b03;
    re[3] = a03 * b00 + a13 * b01 + a23 * b02 + a33 * b03;

    re[4] = a00 * b10 + a10 * b11 + a20 * b12 + a30 * b13;
    re[5] = a01 * b10 + a11 * b11 + a21 * b12 + a31 * b13;
    re[6] = a02 * b10 + a12 * b11 + a22 * b12 + a32 * b13;
    re[7] = a03 * b10 + a13 * b11 + a23 * b12 + a33 * b13;

    re[8] = a00 * b20 + a10 * b21 + a20 * b22 + a30 * b23;
    re[9] = a01 * b20 + a11 * b21 + a21 * b22 + a31 * b23;
    re[10] = a02 * b20 + a12 * b21 + a22 * b22 + a32 * b23;
    re[11] = a03 * b20 + a13 * b21 + a23 * b22 + a33 * b23;

    re[12] = a00 * b30 + a10 * b31 + a20 * b32 + a30 * b33;
    re[13] = a01 * b30 + a11 * b31 + a21 * b32 + a31 * b33;
    re[14] = a02 * b30 + a12 * b31 + a22 * b32 + a32 * b33;
    re[15] = a03 * b30 + a13 * b31 + a23 * b32 + a33 * b33;

    return result;
  }

  /**
   * 创建透视投影矩阵
   * @param fov 视野角度（弧度）
   * @param aspect 宽高比
   * @param near 近裁剪面距离
   * @param far 远裁剪面距离
   */
  static perspective(fov: number, aspect: number, near: number, far: number): float4x4 {
    const f = 1.0 / Math.tan(fov / 2);
    const nf = 1 / (near - far);
    
    const result = new float4x4();
    const e = result.elements;
    
    e[0] = f / aspect;
    e[1] = 0;
    e[2] = 0;
    e[3] = 0;
    
    e[4] = 0;
    e[5] = f;
    e[6] = 0;
    e[7] = 0;
    
    e[8] = 0;
    e[9] = 0;
    e[10] = (far + near) * nf;
    e[11] = -1;
    
    e[12] = 0;
    e[13] = 0;
    e[14] = 2 * far * near * nf;
    e[15] = 0;
    
    return result;
  }

  /**
   * 创建正交投影矩阵
   * @param left 左边界
   * @param right 右边界
   * @param bottom 下边界
   * @param top 上边界
   * @param near 近裁剪面
   * @param far 远裁剪面
   */
  static orthographic(
    left: number, right: number,
    bottom: number, top: number,
    near: number, far: number
  ): float4x4 {
    const w = 1.0 / (right - left);
    const h = 1.0 / (top - bottom);
    const d = 1.0 / (far - near);
    
    const result = new float4x4();
    const e = result.elements;
    
    e[0] = 2 * w;
    e[1] = 0;
    e[2] = 0;
    e[3] = 0;
    
    e[4] = 0;
    e[5] = 2 * h;
    e[6] = 0;
    e[7] = 0;
    
    e[8] = 0;
    e[9] = 0;
    e[10] = -2 * d;
    e[11] = 0;
    
    e[12] = -(right + left) * w;
    e[13] = -(top + bottom) * h;
    e[14] = -(far + near) * d;
    e[15] = 1;
    
    return result;
  }

  /**
   * 创建 lookAt 视图矩阵
   * @param eye 相机位置
   * @param target 目标位置
   * @param up 上方向
   */
  static lookAt(eye: float3, target: float3, up: float3): float4x4 {
    // 计算视图方向（z 轴）
    const z = float3.sub(eye, target).normalize();
    
    // 计算右方向（x 轴）
    const x = float3.cross(up.clone(), z).normalize();
    
    // 计算上方向（y 轴）
    const y = float3.cross(z.clone(), x);
    
    const result = new float4x4();
    const e = result.elements;
    
    e[0] = x.x;
    e[1] = y.x;
    e[2] = z.x;
    e[3] = 0;
    
    e[4] = x.y;
    e[5] = y.y;
    e[6] = z.y;
    e[7] = 0;
    
    e[8] = x.z;
    e[9] = y.z;
    e[10] = z.z;
    e[11] = 0;
    
    e[12] = -float3.dot(x, eye);
    e[13] = -float3.dot(y, eye);
    e[14] = -float3.dot(z, eye);
    e[15] = 1;
    
    return result;
  }

  /**
   * 从数组创建矩阵
   */
  static fromArray(array: number[]): float4x4 {
    const result = new float4x4();
    result.elements = [...array];
    return result;
  }

  /**
   * 转换为字符串
   */
  toString(): string {
    const e = this.elements;
    return `float4x4(\n` +
      `  ${e[0].toFixed(3)}, ${e[4].toFixed(3)}, ${e[8].toFixed(3)}, ${e[12].toFixed(3)}\n` +
      `  ${e[1].toFixed(3)}, ${e[5].toFixed(3)}, ${e[9].toFixed(3)}, ${e[13].toFixed(3)}\n` +
      `  ${e[2].toFixed(3)}, ${e[6].toFixed(3)}, ${e[10].toFixed(3)}, ${e[14].toFixed(3)}\n` +
      `  ${e[3].toFixed(3)}, ${e[7].toFixed(3)}, ${e[11].toFixed(3)}, ${e[15].toFixed(3)}\n` +
      `)`;
  }
}
