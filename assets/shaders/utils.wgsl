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