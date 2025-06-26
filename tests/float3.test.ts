import { float3 } from '../src/math/hlsl-types';

describe('float3', () => {
  describe('构造函数', () => {
    test('默认构造函数应该创建零向量', () => {
      const v = new float3();
      expect(v.x).toBe(0);
      expect(v.y).toBe(0);
      expect(v.z).toBe(0);
    });

    test('带参数构造函数应该设置正确的值', () => {
      const v = new float3(1, 2, 3);
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
    });
  });

  describe('基本操作', () => {
    test('set方法应该设置向量分量', () => {
      const v = new float3();
      v.set(1, 2, 3);
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
    });

    test('clone方法应该创建副本', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = v1.clone();
      expect(v2.x).toBe(1);
      expect(v2.y).toBe(2);
      expect(v2.z).toBe(3);
      expect(v2).not.toBe(v1);
    });

    test('copy方法应该复制另一个向量', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(4, 5, 6);
      v1.copy(v2);
      expect(v1.x).toBe(4);
      expect(v1.y).toBe(5);
      expect(v1.z).toBe(6);
    });
  });

  describe('数学运算', () => {
    test('add方法应该正确相加', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(4, 5, 6);
      v1.add(v2);
      expect(v1.x).toBe(5);
      expect(v1.y).toBe(7);
      expect(v1.z).toBe(9);
    });

    test('sub方法应该正确相减', () => {
      const v1 = new float3(5, 7, 9);
      const v2 = new float3(2, 3, 4);
      v1.sub(v2);
      expect(v1.x).toBe(3);
      expect(v1.y).toBe(4);
      expect(v1.z).toBe(5);
    });

    test('scale方法应该正确缩放', () => {
      const v = new float3(1, 2, 3);
      v.scale(2);
      expect(v.x).toBe(2);
      expect(v.y).toBe(4);
      expect(v.z).toBe(6);
    });
  });

  describe('向量长度计算', () => {
    test('length方法应该计算正确的向量长度', () => {
      const v = new float3(2, 3, 6);
      expect(v.length()).toBe(7); // sqrt(4 + 9 + 36) = sqrt(49) = 7
    });

    test('lengthSq方法应该计算正确的向量长度平方', () => {
      const v = new float3(2, 3, 6);
      expect(v.lengthSq()).toBe(49);
    });

    test('normalize方法应该规范化向量', () => {
      const v = new float3(3, 4, 0);
      v.normalize();
      expect(v.length()).toBeCloseTo(1, 5);
      expect(v.x).toBeCloseTo(0.6, 5);
      expect(v.y).toBeCloseTo(0.8, 5);
      expect(v.z).toBeCloseTo(0, 5);
    });
  });

  describe('点积和叉积', () => {
    test('dot方法应该计算正确的点积', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(4, 5, 6);
      const result = v1.dot(v2);
      expect(result).toBe(32); // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    });

    test('cross方法应该计算正确的叉积', () => {
      const v1 = new float3(1, 0, 0);
      const v2 = new float3(0, 1, 0);
      v1.cross(v2);
      expect(v1.x).toBe(0);
      expect(v1.y).toBe(0);
      expect(v1.z).toBe(1);
    });

    test('叉积与右手法则一致', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(4, 5, 6);
      const result = v1.clone().cross(v2);
      // 叉积公式：(a2*b3 - a3*b2, a3*b1 - a1*b3, a1*b2 - a2*b1)
      expect(result.x).toBe(2*6 - 3*5); // 12 - 15 = -3
      expect(result.y).toBe(3*4 - 1*6); // 12 - 6 = 6
      expect(result.z).toBe(1*5 - 2*4); // 5 - 8 = -3
    });
  });

  describe('距离计算', () => {
    test('distance方法应该计算正确的距离', () => {
      const v1 = new float3(0, 0, 0);
      const v2 = new float3(3, 4, 0);
      const distance = v1.distance(v2);
      expect(distance).toBe(5);
    });

    test('distanceSq方法应该计算正确的距离平方', () => {
      const v1 = new float3(0, 0, 0);
      const v2 = new float3(3, 4, 0);
      const distanceSq = v1.distanceSq(v2);
      expect(distanceSq).toBe(25);
    });
  });

  describe('Swizzle操作', () => {
    test('二分量swizzle应该正确工作', () => {
      const v = new float3(1, 2, 3);
      
      const xy = v.xy;
      expect(xy.x).toBe(1);
      expect(xy.y).toBe(2);
      
      const xz = v.xz;
      expect(xz.x).toBe(1);
      expect(xz.y).toBe(3);
      
      const yz = v.yz;
      expect(yz.x).toBe(2);
      expect(yz.y).toBe(3);
    });

    test('三分量swizzle应该正确工作', () => {
      const v = new float3(1, 2, 3);
      
      const xyz = v.xyz;
      expect(xyz.x).toBe(1);
      expect(xyz.y).toBe(2);
      expect(xyz.z).toBe(3);
      
      const zyx = v.zyx;
      expect(zyx.x).toBe(3);
      expect(zyx.y).toBe(2);
      expect(zyx.z).toBe(1);
    });
  });

  describe('颜色通道别名', () => {
    test('RGB颜色通道别名应该正确工作', () => {
      const v = new float3(0.5, 0.8, 0.2);
      
      expect(v.r).toBe(0.5);
      expect(v.g).toBe(0.8);
      expect(v.b).toBe(0.2);
      
      v.r = 0.3;
      v.g = 0.6;
      v.b = 0.9;
      expect(v.x).toBe(0.3);
      expect(v.y).toBe(0.6);
      expect(v.z).toBe(0.9);
      
      const rgb = v.rgb;
      expect(rgb.x).toBe(0.3);
      expect(rgb.y).toBe(0.6);
      expect(rgb.z).toBe(0.9);
    });
  });

  describe('静态方法', () => {
    test('static cross应该计算正确的叉积', () => {
      const v1 = new float3(1, 0, 0);
      const v2 = new float3(0, 1, 0);
      const result = float3.cross(v1, v2);
      expect(result.x).toBe(0);
      expect(result.y).toBe(0);
      expect(result.z).toBe(1);
    });

    test('static dot应该计算正确的点积', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(4, 5, 6);
      const result = float3.dot(v1, v2);
      expect(result).toBe(32);
    });

    test('static distance应该计算正确的距离', () => {
      const v1 = new float3(0, 0, 0);
      const v2 = new float3(3, 4, 0);
      const result = float3.distance(v1, v2);
      expect(result).toBe(5);
    });

    test('预定义方向向量应该正确', () => {
      const zero = float3.zero();
      expect(zero.x).toBe(0);
      expect(zero.y).toBe(0);
      expect(zero.z).toBe(0);
      
      const one = float3.one();
      expect(one.x).toBe(1);
      expect(one.y).toBe(1);
      expect(one.z).toBe(1);
      
      const up = float3.up();
      expect(up.x).toBe(0);
      expect(up.y).toBe(1);
      expect(up.z).toBe(0);
      
      const forward = float3.forward();
      expect(forward.x).toBe(0);
      expect(forward.y).toBe(0);
      expect(forward.z).toBe(-1);
      
      const right = float3.right();
      expect(right.x).toBe(1);
      expect(right.y).toBe(0);
      expect(right.z).toBe(0);
    });
  });

  describe('反射和折射', () => {
    test('reflect方法应该正确反射向量', () => {
      const incident = new float3(1, -1, 0).normalize();
      const normal = new float3(0, 1, 0);
      const reflected = incident.clone().reflect(normal);
      
      // 入射角等于反射角
      expect(reflected.y).toBeCloseTo(1 / Math.sqrt(2), 5);
      expect(reflected.x).toBeCloseTo(1 / Math.sqrt(2), 5);
      expect(reflected.z).toBeCloseTo(0, 5);
    });

    test('refract方法应该正确折射向量', () => {
      const incident = new float3(1, -1, 0).normalize();
      const normal = new float3(0, 1, 0);
      const eta = 1.0 / 1.33; // 空气到水
      const refracted = incident.clone().refract(normal, eta);
      
      // 折射向量应该偏向法向量
      expect(refracted.y).toBeLessThan(0);
      expect(Math.abs(refracted.x)).toBeLessThan(Math.abs(incident.x));
    });
  });

  describe('链式操作', () => {
    test('方法链应该正确工作', () => {
      const v = new float3(1, 2, 3);
      const result = v.clone()
        .add(new float3(1, 1, 1))
        .scale(2)
        .normalize();
      
      expect(result.length()).toBeCloseTo(1, 5);
      // 原向量应该保持不变
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
    });
  });

  describe('实用方法', () => {
    test('abs方法应该计算绝对值', () => {
      const v = new float3(-1, -2, -3);
      v.abs();
      expect(v.x).toBe(1);
      expect(v.y).toBe(2);
      expect(v.z).toBe(3);
    });

    test('clamp方法应该限制范围', () => {
      const v = new float3(-1, 5, 2);
      const min = new float3(0, 0, 0);
      const max = new float3(3, 3, 3);
      v.clamp(min, max);
      expect(v.x).toBe(0);
      expect(v.y).toBe(3);
      expect(v.z).toBe(2);
    });

    test('equals方法应该正确比较向量', () => {
      const v1 = new float3(1, 2, 3);
      const v2 = new float3(1, 2, 3);
      const v3 = new float3(1.00001, 2, 3);
      
      expect(v1.equals(v2)).toBe(true);
      expect(v1.equals(v3)).toBe(false);
      expect(v1.equals(v3, 0.001)).toBe(true);
    });
  });
}); 