fn look_at(eye : vec3<f32>, center : vec3<f32>, up : vec3<f32>) -> mat4x4<f32>
{
    let f = normalize(center - eye);
    let s = normalize(cross(f, up));
    let u = cross(s, f);
    return mat4x4<f32>(vec4<f32>(s, 0.0f), vec4<f32>(u, 0.0f), vec4<f32>(-f, 0.0f), vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f));
}

fn perspective(fov : f32, aspect : f32, near : f32, far : f32) -> mat4x4<f32>
{
    let f = 1.0 / tan(fov * 0.5);
    return mat4x4<f32>(f / aspect, 0.0, 0.0, 0.0,
                       0.0, f, 0.0, 0.0,
                       0.0, 0.0, (near + far) / (near - far), -1.0,
                       0.0, 0.0, (2.0 * near * far) / (near - far), 0.0);
}

struct Basis 
{
    right: vec3<f32>,
    up: vec3<f32>,
    forward: vec3<f32>,
};

fn quat_to_mat3(q_in: vec4<f32>) -> mat3x3<f32> 
{
    let inv_len = inverseSqrt(max(dot(q_in, q_in), 1e-20));
    let q = q_in * inv_len;

    let x = q.x;
    let y = q.y;
    let z = q.z;
    let w = q.w;

    let xx = x * x;
    let yy = y * y;
    let zz = z * z;
    let xy = x * y;
    let xz = x * z;
    let yz = y * z;
    let wx = w * x;
    let wy = w * y;
    let wz = w * z;

    // mat3x3<c0, c1, c2>，每个 cN 是一列
    let c0 = vec3<f32>(1.0 - 2.0 * (yy + zz), 2.0 * (xy + wz), 2.0 * (xz - wy));
    let c1 = vec3<f32>(2.0 * (xy - wz), 1.0 - 2.0 * (xx + zz), 2.0 * (yz + wx));
    let c2 = vec3<f32>(2.0 * (xz + wy), 2.0 * (yz - wx), 1.0 - 2.0 * (xx + yy));
    return mat3x3<f32>(c0, c1, c2);
}

fn basis_from_quat_metal(q: vec4<f32>) -> Basis {
    let R = quat_to_mat3(q);
    // Metal 约定：forward=+Z，所以取第三列为 forward
    return Basis(
    R[0], // 第一列 +X
    R[1], // 第二列 +Y
    R[2] // 第三列 +Z
    );
}

fn quat_from_basis(right: vec3<f32>, up: vec3<f32>, forward: vec3<f32>) -> vec4<f32> {
    // 正交化（可按需放宽）
    let r = normalize(right);
    let u1 = up - r * dot(r, up);
    let u = normalize(u1);
    let f = normalize(cross(r, u)); // 右手；如需强制与传入 forward 对齐，可检测 dot(f, forward)<0 则 f = -f, u = -u

    let R00 = r.x; let R01 = u.x; let R02 = f.x;
    let R10 = r.y; let R11 = u.y; let R12 = f.y;
    let R20 = r.z; let R21 = u.z; let R22 = f.z;

    let trace = R00 + R11 + R22;
    var q = vec4<f32>(0.0);

    if (trace > 0.0f) 
    {
        let s = sqrt(trace + 1.0f) * 2.0f;
        q.w = 0.25f * s;
        q.x = (R21 - R12) / s;
        q.y = (R02 - R20) / s;
        q.z = (R10 - R01) / s;
    } 
    else if (R00 > R11 && R00 > R22) {
        let s = sqrt(1.0f + R00 - R11 - R22) * 2.0f;
        q.w = (R21 - R12) / s;
        q.x = 0.25f * s;
        q.y = (R01 + R10) / s;
        q.z = (R02 + R20) / s;
    } 
    else if (R11 > R22) 
    {
        let s = sqrt(1.0f - R00 + R11 - R22) * 2.0f;
        q.w = (R02 - R20) / s;
        q.x = (R01 + R10) / s;
        q.y = 0.25 * s;
        q.z = (R12 + R21) / s;
    } 
    else 
    {
        let s = sqrt(1.0f - R00 - R11 + R22) * 2.0f;
        q.w = (R10 - R01) / s;
        q.x = (R02 + R20) / s;
        q.y = (R12 + R21) / s;
        q.z = 0.25f * s;
    }

    // 归一化
    let inv_len = inverseSqrt(max(dot(q, q), 1e-30f));
    return q * inv_len;
}