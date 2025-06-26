import { float2 } from '../src/math/hlsl-types';

describe('float2', () => {
  describe('构造函数', () => {
    test('默认构造函数应该创建零向量', () => {
      const v = new float2();
      expect(v.x).toBe(0);
      expect(v.y).toBe(0);
    });

    test('带参数构造函数应该设置正确的值', () => {
      const v = new float2(3, 4);
      expect(v.x).toBe(3);
      expect(v.y).toBe(4);
    });
  });

  describe('基本操作', () => {
    test('set方法应该设置向量分量', () => {
      const v = new float2();
      v.set(1, 2);
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
    });

    test('clone方法应该创建副本', () => {
      const v1 = new float2(3, 4);
      const v2 = v1.clone();
      expect(v2.x).toBe(3);
      expect(v2.y).toBe(4);
      expect(v2).not.toBe(v1); // 不同的实例
    });

    test('copy方法应该复制另一个向量', () => {
      const v1 = new float2(1, 2);
      const v2 = new float2(3, 4);
      v1.copy(v2);
      expect(v1.x).toBe(3);
      expect(v1.y).toBe(4);
    });
  });

  describe('数学运算', () => {
    test('add方法应该正确相加', () => {
      const v1 = new float2(1, 2);
      const v2 = new float2(3, 4);
      v1.add(v2);
      expect(v1.x).toBe(4);
      expect(v1.y).toBe(6);
    });

    test('sub方法应该正确相减', () => {
      const v1 = new float2(5, 7);
      const v2 = new float2(2, 3);
      v1.sub(v2);
      expect(v1.x).toBe(3);
      expect(v1.y).toBe(4);
    });

    test('mul方法应该正确相乘', () => {
      const v1 = new float2(2, 3);
      const v2 = new float2(4, 5);
      v1.mul(v2);
      expect(v1.x).toBe(8);
      expect(v1.y).toBe(15);
    });

    test('scale方法应该正确缩放', () => {
      const v = new float2(2, 3);
      v.scale(2);
      expect(v.x).toBe(4);
      expect(v.y).toBe(6);
    });

    test('div方法应该正确除法', () => {
      const v1 = new float2(8, 12);
      const v2 = new float2(2, 3);
      v1.div(v2);
      expect(v1.x).toBe(4);
      expect(v1.y).toBe(4);
    });

    test('divScalar方法应该正确标量除法', () => {
      const v = new float2(6, 8);
      v.divScalar(2);
      expect(v.x).toBe(3);
      expect(v.y).toBe(4);
    });
  });

  describe('向量长度计算', () => {
    test('length方法应该计算正确的向量长度', () => {
      const v = new float2(3, 4);
      expect(v.length()).toBe(5);
    });

    test('lengthSq方法应该计算正确的向量长度平方', () => {
      const v = new float2(3, 4);
      expect(v.lengthSq()).toBe(25);
    });

    test('normalize方法应该规范化向量', () => {
      const v = new float2(3, 4);
      v.normalize();
      expect(v.length()).toBeCloseTo(1, 5);
      expect(v.x).toBeCloseTo(0.6, 5);
      expect(v.y).toBeCloseTo(0.8, 5);
    });
  });

  describe('点积', () => {
    test('dot方法应该计算正确的点积', () => {
      const v1 = new float2(2, 3);
      const v2 = new float2(4, 5);
      const result = v1.dot(v2);
      expect(result).toBe(23); // 2*4 + 3*5 = 8 + 15 = 23
    });
  });

  describe('距离计算', () => {
    test('distance方法应该计算正确的距离', () => {
      const v1 = new float2(0, 0);
      const v2 = new float2(3, 4);
      const distance = v1.distance(v2);
      expect(distance).toBe(5);
    });

    test('distanceSq方法应该计算正确的距离平方', () => {
      const v1 = new float2(0, 0);
      const v2 = new float2(3, 4);
      const distanceSq = v1.distanceSq(v2);
      expect(distanceSq).toBe(25);
    });
  });

  describe('线性插值', () => {
    test('lerp方法应该正确插值', () => {
      const v1 = new float2(0, 0);
      const v2 = new float2(10, 20);
      v1.lerp(v2, 0.5);
      expect(v1.x).toBe(5);
      expect(v1.y).toBe(10);
    });

    test('lerp边界值测试', () => {
      const v1 = new float2(1, 2);
      const v2 = new float2(3, 4);
      
      // t = 0 应该保持原值
      const v1Copy = v1.clone();
      v1Copy.lerp(v2, 0);
      expect(v1Copy.x).toBe(1);
      expect(v1Copy.y).toBe(2);
      
      // t = 1 应该变为目标值
      const v1Copy2 = v1.clone();
      v1Copy2.lerp(v2, 1);
      expect(v1Copy2.x).toBe(3);
      expect(v1Copy2.y).toBe(4);
    });
  });

  describe('Swizzle操作', () => {
    test('二分量swizzle应该正确工作', () => {
      const v = new float2(1, 2);
      
      const xx = v.xx;
      expect(xx.x).toBe(1);
      expect(xx.y).toBe(1);
      
      const xy = v.xy;
      expect(xy.x).toBe(1);
      expect(xy.y).toBe(2);
      
      const yx = v.yx;
      expect(yx.x).toBe(2);
      expect(yx.y).toBe(1);
      
      const yy = v.yy;
      expect(yy.x).toBe(2);
      expect(yy.y).toBe(2);
    });
  });

  describe('颜色通道别名', () => {
    test('颜色通道别名应该正确工作', () => {
      const v = new float2(0.5, 0.8);
      
      expect(v.r).toBe(0.5);
      expect(v.g).toBe(0.8);
      
      v.r = 0.3;
      v.g = 0.6;
      expect(v.x).toBe(0.3);
      expect(v.y).toBe(0.6);
      
      const rg = v.rg;
      expect(rg.x).toBe(0.3);
      expect(rg.y).toBe(0.6);
    });
  });

  describe('相等性检查', () => {
    test('equals方法应该正确比较向量', () => {
      const v1 = new float2(1, 2);
      const v2 = new float2(1, 2);
      const v3 = new float2(1.00001, 2);
      
      expect(v1.equals(v2)).toBe(true);
      expect(v1.equals(v3)).toBe(false);
      expect(v1.equals(v3, 0.001)).toBe(true);
    });
  });

  describe('静态方法', () => {
    test('static add应该正确相加两个向量', () => {
      const v1 = new float2(1, 2);
      const v2 = new float2(3, 4);
      const result = float2.add(v1, v2);
      expect(result.x).toBe(4);
      expect(result.y).toBe(6);
    });

    test('static sub应该正确相减两个向量', () => {
      const v1 = new float2(5, 7);
      const v2 = new float2(2, 3);
      const result = float2.sub(v1, v2);
      expect(result.x).toBe(3);
      expect(result.y).toBe(4);
    });

    test('static dot应该计算正确的点积', () => {
      const v1 = new float2(2, 3);
      const v2 = new float2(4, 5);
      const result = float2.dot(v1, v2);
      expect(result).toBe(23);
    });

    test('static distance应该计算正确的距离', () => {
      const v1 = new float2(0, 0);
      const v2 = new float2(3, 4);
      const result = float2.distance(v1, v2);
      expect(result).toBe(5);
    });

    test('static normalize应该规范化向量', () => {
      const v = new float2(3, 4);
      const result = float2.normalize(v);
      expect(result.length()).toBeCloseTo(1, 5);
    });

    test('static lerp应该正确插值', () => {
      const v1 = new float2(0, 0);
      const v2 = new float2(10, 20);
      const result = float2.lerp(v1, v2, 0.5);
      expect(result.x).toBe(5);
      expect(result.y).toBe(10);
    });

    test('预定义向量应该正确', () => {
      const zero = float2.zero();
      expect(zero.x).toBe(0);
      expect(zero.y).toBe(0);
      
      const one = float2.one();
      expect(one.x).toBe(1);
      expect(one.y).toBe(1);
      
      const unitX = float2.unitX();
      expect(unitX.x).toBe(1);
      expect(unitX.y).toBe(0);
      
      const unitY = float2.unitY();
      expect(unitY.x).toBe(0);
      expect(unitY.y).toBe(1);
    });
  });

  describe('转换方法', () => {
    test('toArray应该返回正确的数组', () => {
      const v = new float2(1, 2);
      const array = v.toArray();
      expect(array).toEqual([1, 2]);
    });

    test('toString应该返回正确的字符串', () => {
      const v = new float2(1, 2);
      const str = v.toString();
      expect(str).toBe('float2(1, 2)');
    });
  });

  describe('实用方法', () => {
    test('abs方法应该计算绝对值', () => {
      const v = new float2(-3, -4);
      v.abs();
      expect(v.x).toBe(3);
      expect(v.y).toBe(4);
    });

    test('floor方法应该向下取整', () => {
      const v = new float2(3.7, 4.2);
      v.floor();
      expect(v.x).toBe(3);
      expect(v.y).toBe(4);
    });

    test('ceil方法应该向上取整', () => {
      const v = new float2(3.2, 4.7);
      v.ceil();
      expect(v.x).toBe(4);
      expect(v.y).toBe(5);
    });

    test('round方法应该四舍五入', () => {
      const v = new float2(3.4, 4.6);
      v.round();
      expect(v.x).toBe(3);
      expect(v.y).toBe(5);
    });

    test('clamp方法应该限制范围', () => {
      const v = new float2(-1, 5);
      const min = new float2(0, 0);
      const max = new float2(3, 3);
      v.clamp(min, max);
      expect(v.x).toBe(0);
      expect(v.y).toBe(3);
    });
  });
}); 