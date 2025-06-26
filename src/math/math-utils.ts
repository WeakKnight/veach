/**
 * 数学工具类
 * 提供常用的数学常量和函数
 */
export class MathUtils {
  /** 角度转弧度的转换常数 */
  static readonly DEG2RAD = Math.PI / 180;
  
  /** 弧度转角度的转换常数 */
  static readonly RAD2DEG = 180 / Math.PI;
  
  /** 非常小的数值，用于浮点数比较 */
  static readonly EPSILON = 2.220446049250313e-16;
  
  /** 黄金比例 */
  static readonly GOLDEN_RATIO = (1 + Math.sqrt(5)) / 2;

  /**
   * 将值限制在指定范围内
   * @param value 要限制的值
   * @param min 最小值
   * @param max 最大值
   * @returns 限制后的值
   */
  static clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  /**
   * 线性插值
   * @param a 起始值
   * @param b 结束值
   * @param t 插值因子 (0-1)
   * @returns 插值结果
   */
  static lerp(a: number, b: number, t: number): number {
    return a + (b - a) * t;
  }

  /**
   * 角度转弧度
   * @param degrees 角度
   * @returns 弧度
   */
  static degToRad(degrees: number): number {
    return degrees * MathUtils.DEG2RAD;
  }

  /**
   * 弧度转角度
   * @param radians 弧度
   * @returns 角度
   */
  static radToDeg(radians: number): number {
    return radians * MathUtils.RAD2DEG;
  }

  /**
   * 检查两个数是否近似相等
   * @param a 第一个数
   * @param b 第二个数
   * @param epsilon 容差，默认使用 EPSILON
   * @returns 是否近似相等
   */
  static isEqual(a: number, b: number, epsilon: number = MathUtils.EPSILON): boolean {
    return Math.abs(a - b) < epsilon;
  }

  /**
   * 检查数值是否为零
   * @param value 要检查的值
   * @param epsilon 容差，默认使用 EPSILON
   * @returns 是否为零
   */
  static isZero(value: number, epsilon: number = MathUtils.EPSILON): boolean {
    return Math.abs(value) < epsilon;
  }

  /**
   * 获取两数之间的随机数
   * @param min 最小值
   * @param max 最大值
   * @returns 随机数
   */
  static random(min: number = 0, max: number = 1): number {
    return min + Math.random() * (max - min);
  }

  /**
   * 获取两整数之间的随机整数
   * @param min 最小整数
   * @param max 最大整数
   * @returns 随机整数
   */
  static randomInt(min: number, max: number): number {
    return Math.floor(MathUtils.random(min, max + 1));
  }
} 