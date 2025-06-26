import { MathUtils } from '../src/math/hlsl-types';

describe('MathUtils', () => {
  describe('常量', () => {
    test('DEG2RAD应该正确转换度到弧度', () => {
      expect(MathUtils.DEG2RAD).toBeCloseTo(Math.PI / 180, 10);
    });

    test('RAD2DEG应该正确转换弧度到度', () => {
      expect(MathUtils.RAD2DEG).toBeCloseTo(180 / Math.PI, 10);
    });

    test('EPSILON应该是非常小的数', () => {
      expect(MathUtils.EPSILON).toBeLessThan(0.0001);
      expect(MathUtils.EPSILON).toBeGreaterThan(0);
    });

    test('GOLDEN_RATIO应该正确', () => {
      expect(MathUtils.GOLDEN_RATIO).toBeCloseTo((1 + Math.sqrt(5)) / 2, 10);
    });
  });

  describe('角度转换', () => {
    test('degToRad应该正确转换角度到弧度', () => {
      expect(MathUtils.degToRad(180)).toBeCloseTo(Math.PI, 5);
      expect(MathUtils.degToRad(90)).toBeCloseTo(Math.PI / 2, 5);
      expect(MathUtils.degToRad(360)).toBeCloseTo(2 * Math.PI, 5);
      expect(MathUtils.degToRad(0)).toBe(0);
    });

    test('radToDeg应该正确转换弧度到角度', () => {
      expect(MathUtils.radToDeg(Math.PI)).toBeCloseTo(180, 5);
      expect(MathUtils.radToDeg(Math.PI / 2)).toBeCloseTo(90, 5);
      expect(MathUtils.radToDeg(2 * Math.PI)).toBeCloseTo(360, 5);
      expect(MathUtils.radToDeg(0)).toBe(0);
    });

    test('角度转换应该是可逆的', () => {
      const degrees = 45;
      const radians = Math.PI / 4;
      
      expect(MathUtils.radToDeg(MathUtils.degToRad(degrees))).toBeCloseTo(degrees, 5);
      expect(MathUtils.degToRad(MathUtils.radToDeg(radians))).toBeCloseTo(radians, 5);
    });
  });

  describe('数学函数', () => {
    test('clamp应该限制值在范围内', () => {
      expect(MathUtils.clamp(5, 0, 10)).toBe(5);
      expect(MathUtils.clamp(-5, 0, 10)).toBe(0);
      expect(MathUtils.clamp(15, 0, 10)).toBe(10);
      expect(MathUtils.clamp(0, 0, 10)).toBe(0);
      expect(MathUtils.clamp(10, 0, 10)).toBe(10);
    });

    test('lerp应该正确插值', () => {
      expect(MathUtils.lerp(0, 10, 0.5)).toBe(5);
      expect(MathUtils.lerp(0, 10, 0)).toBe(0);
      expect(MathUtils.lerp(0, 10, 1)).toBe(10);
      expect(MathUtils.lerp(-10, 10, 0.5)).toBe(0);
      expect(MathUtils.lerp(5, 15, 0.3)).toBeCloseTo(8, 5);
    });

    test('lerp边界值测试', () => {
      expect(MathUtils.lerp(0, 100, -0.5)).toBe(-50); // 超出范围
      expect(MathUtils.lerp(0, 100, 1.5)).toBe(150);  // 超出范围
    });
  });

  describe('随机数生成', () => {
    test('random应该在指定范围内', () => {
      const min = 5;
      const max = 10;
      
      for (let i = 0; i < 100; i++) {
        const value = MathUtils.random(min, max);
        expect(value).toBeGreaterThanOrEqual(min);
        expect(value).toBeLessThan(max);
      }
    });

    test('random默认参数应该返回0到1之间的数', () => {
      for (let i = 0; i < 100; i++) {
        const value = MathUtils.random();
        expect(value).toBeGreaterThanOrEqual(0);
        expect(value).toBeLessThan(1);
      }
    });

    test('randomInt应该返回整数', () => {
      const min = 1;
      const max = 10;
      
      for (let i = 0; i < 100; i++) {
        const value = MathUtils.randomInt(min, max);
        expect(Number.isInteger(value)).toBe(true);
        expect(value).toBeGreaterThanOrEqual(min);
        expect(value).toBeLessThanOrEqual(max);
      }
    });
  });

  describe('比较函数', () => {
    test('isEqual应该正确比较浮点数', () => {
      expect(MathUtils.isEqual(1.0, 1.0)).toBe(true);
      expect(MathUtils.isEqual(1.0, 1.1)).toBe(false);
      expect(MathUtils.isEqual(1.0, 1.0000001, 0.001)).toBe(true);
      expect(MathUtils.isEqual(1.0, 1.01, 0.001)).toBe(false);
    });

    test('isEqual默认epsilon应该工作', () => {
      const a = 1.0;
      const b = 1.0 + MathUtils.EPSILON * 0.5;
      expect(MathUtils.isEqual(a, b)).toBe(true);
    });

    test('isZero应该正确判断零值', () => {
      expect(MathUtils.isZero(0)).toBe(true);
      expect(MathUtils.isZero(MathUtils.EPSILON * 0.5)).toBe(true);
      expect(MathUtils.isZero(0.1)).toBe(false);
      expect(MathUtils.isZero(-0.1)).toBe(false);
    });
  });
}); 