import { float4 } from '../src/math/hlsl-types';

describe('float4', () => {
  describe('构造函数', () => {
    test('默认构造函数应该创建正确的向量', () => {
      const v = new float4();
      expect(v.x).toBe(0);
      expect(v.y).toBe(0);
      expect(v.z).toBe(0);
      expect(v.w).toBe(1);
    });

    test('带参数构造函数应该设置正确的值', () => {
      const v = new float4(1, 2, 3, 4);
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
      expect(v.w).toBe(4);
    });
  });

  describe('基本操作', () => {
    test('set方法应该设置向量分量', () => {
      const v = new float4();
      v.set(1, 2, 3, 4);
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
      expect(v.w).toBe(4);
    });

    test('clone方法应该创建副本', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = v1.clone();
      expect(v2.x).toBe(1);
      expect(v2.y).toBe(2);
      expect(v2.z).toBe(3);
      expect(v2.w).toBe(4);
      expect(v2).not.toBe(v1);
    });

    test('copy方法应该复制另一个向量', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(5, 6, 7, 8);
      v1.copy(v2);
      expect(v1.x).toBe(5);
      expect(v1.y).toBe(6);
      expect(v1.z).toBe(7);
      expect(v1.w).toBe(8);
    });
  });

  describe('数学运算', () => {
    test('add方法应该正确相加', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(5, 6, 7, 8);
      v1.add(v2);
      expect(v1.x).toBe(6);
      expect(v1.y).toBe(8);
      expect(v1.z).toBe(10);
      expect(v1.w).toBe(12);
    });

    test('sub方法应该正确相减', () => {
      const v1 = new float4(10, 12, 14, 16);
      const v2 = new float4(2, 3, 4, 5);
      v1.sub(v2);
      expect(v1.x).toBe(8);
      expect(v1.y).toBe(9);
      expect(v1.z).toBe(10);
      expect(v1.w).toBe(11);
    });

    test('scale方法应该正确缩放', () => {
      const v = new float4(1, 2, 3, 4);
      v.scale(2);
      expect(v.x).toBe(2);
      expect(v.y).toBe(4);
      expect(v.z).toBe(6);
      expect(v.w).toBe(8);
    });
  });

  describe('向量长度计算', () => {
    test('length方法应该计算正确的向量长度', () => {
      const v = new float4(1, 2, 2, 0);
      expect(v.length()).toBe(3); // sqrt(1 + 4 + 4 + 0) = sqrt(9) = 3
    });

    test('lengthSq方法应该计算正确的向量长度平方', () => {
      const v = new float4(1, 2, 2, 0);
      expect(v.lengthSq()).toBe(9);
    });

    test('normalize方法应该规范化向量', () => {
      const v = new float4(3, 4, 0, 0);
      v.normalize();
      expect(v.length()).toBeCloseTo(1, 5);
      expect(v.x).toBeCloseTo(0.6, 5);
      expect(v.y).toBeCloseTo(0.8, 5);
      expect(v.z).toBeCloseTo(0, 5);
      expect(v.w).toBeCloseTo(0, 5);
    });
  });

  describe('点积', () => {
    test('dot方法应该计算正确的点积', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(5, 6, 7, 8);
      const result = v1.dot(v2);
      expect(result).toBe(70); // 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
    });
  });

  describe('距离计算', () => {
    test('distance方法应该计算正确的距离', () => {
      const v1 = new float4(0, 0, 0, 0);
      const v2 = new float4(3, 4, 0, 0);
      const distance = v1.distance(v2);
      expect(distance).toBe(5);
    });

    test('distanceSq方法应该计算正确的距离平方', () => {
      const v1 = new float4(0, 0, 0, 0);
      const v2 = new float4(3, 4, 0, 0);
      const distanceSq = v1.distanceSq(v2);
      expect(distanceSq).toBe(25);
    });
  });

  describe('Swizzle操作', () => {
    test('二分量swizzle应该正确工作', () => {
      const v = new float4(1, 2, 3, 4);
      
      const xy = v.xy;
      expect(xy.x).toBe(1);
      expect(xy.y).toBe(2);
      
      const zw = v.zw;
      expect(zw.x).toBe(3);
      expect(zw.y).toBe(4);
    });

    test('三分量swizzle应该正确工作', () => {
      const v = new float4(1, 2, 3, 4);
      
      const xyz = v.xyz;
      expect(xyz.x).toBe(1);
      expect(xyz.y).toBe(2);
      expect(xyz.z).toBe(3);
      
      const yzw = v.yzw;
      expect(yzw.x).toBe(2);
      expect(yzw.y).toBe(3);
      expect(yzw.z).toBe(4);
    });

    test('四分量swizzle应该正确工作', () => {
      const v = new float4(1, 2, 3, 4);
      
      const xyzw = v.xyzw;
      expect(xyzw.x).toBe(1);
      expect(xyzw.y).toBe(2);
      expect(xyzw.z).toBe(3);
      expect(xyzw.w).toBe(4);
      
      const wzyx = v.wzyx;
      expect(wzyx.x).toBe(4);
      expect(wzyx.y).toBe(3);
      expect(wzyx.z).toBe(2);
      expect(wzyx.w).toBe(1);
    });
  });

  describe('颜色通道别名', () => {
    test('RGBA颜色通道别名应该正确工作', () => {
      const v = new float4(0.5, 0.8, 0.2, 0.9);
      
      expect(v.r).toBe(0.5);
      expect(v.g).toBe(0.8);
      expect(v.b).toBe(0.2);
      expect(v.a).toBe(0.9);
      
      v.r = 0.3;
      v.g = 0.6;
      v.b = 0.9;
      v.a = 0.7;
      expect(v.x).toBe(0.3);
      expect(v.y).toBe(0.6);
      expect(v.z).toBe(0.9);
      expect(v.w).toBe(0.7);
      
      const rgba = v.rgba;
      expect(rgba.x).toBe(0.3);
      expect(rgba.y).toBe(0.6);
      expect(rgba.z).toBe(0.9);
      expect(rgba.w).toBe(0.7);
    });
  });

  describe('静态方法', () => {
    test('static add应该正确相加两个向量', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(5, 6, 7, 8);
      const result = float4.add(v1, v2);
      expect(result.x).toBe(6);
      expect(result.y).toBe(8);
      expect(result.z).toBe(10);
      expect(result.w).toBe(12);
    });

    test('static dot应该计算正确的点积', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(5, 6, 7, 8);
      const result = float4.dot(v1, v2);
      expect(result).toBe(70);
    });

    test('static distance应该计算正确的距离', () => {
      const v1 = new float4(0, 0, 0, 0);
      const v2 = new float4(3, 4, 0, 0);
      const result = float4.distance(v1, v2);
      expect(result).toBe(5);
    });

    test('预定义向量应该正确', () => {
      const zero = float4.zero();
      expect(zero.x).toBe(0);
      expect(zero.y).toBe(0);
      expect(zero.z).toBe(0);
      expect(zero.w).toBe(0);
      
      const one = float4.one();
      expect(one.x).toBe(1);
      expect(one.y).toBe(1);
      expect(one.z).toBe(1);
      expect(one.w).toBe(1);
      
      const color = float4.color(1, 0.5, 0, 1);
      expect(color.r).toBe(1);
      expect(color.g).toBe(0.5);
      expect(color.b).toBe(0);
      expect(color.a).toBe(1);
    });
  });

  describe('颜色操作', () => {
    test('颜色插值应该正确工作', () => {
      const red = float4.color(1, 0, 0, 1);
      const blue = float4.color(0, 0, 1, 1);
      const purple = float4.lerp(red, blue, 0.5);
      
      expect(purple.r).toBe(0.5);
      expect(purple.g).toBe(0);
      expect(purple.b).toBe(0.5);
      expect(purple.a).toBe(1);
    });

    test('颜色混合应该保持Alpha通道', () => {
      const semiRed = float4.color(1, 0, 0, 0.5);
      const semiBlue = float4.color(0, 0, 1, 0.8);
      const mixed = float4.lerp(semiRed, semiBlue, 0.5);
      
      expect(mixed.a).toBe(0.65); // (0.5 + 0.8) / 2
    });
  });

  describe('实用方法', () => {
    test('clamp方法应该限制范围', () => {
      const v = new float4(-1, 5, 2, 3);
      const min = new float4(0, 0, 0, 0);
      const max = new float4(3, 3, 3, 1);
      v.clamp(min, max);
      expect(v.x).toBe(0);
      expect(v.y).toBe(3);
      expect(v.z).toBe(2);
      expect(v.w).toBe(1);
    });

    test('equals方法应该正确比较向量', () => {
      const v1 = new float4(1, 2, 3, 4);
      const v2 = new float4(1, 2, 3, 4);
      const v3 = new float4(1.00001, 2, 3, 4);
      
      expect(v1.equals(v2)).toBe(true);
      expect(v1.equals(v3)).toBe(false);
      expect(v1.equals(v3, 0.001)).toBe(true);
    });

    test('toArray应该返回正确的数组', () => {
      const v = new float4(1, 2, 3, 4);
      const array = v.toArray();
      expect(array).toEqual([1, 2, 3, 4]);
    });

    test('toString应该返回正确的字符串', () => {
      const v = new float4(1, 2, 3, 4);
      const str = v.toString();
      expect(str).toBe('float4(1, 2, 3, 4)');
    });
  });
}); 