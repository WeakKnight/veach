struct VertexOut 
{
    @builtin(position) positionCS: vec4f,
    @location(0) texCoord: vec2f,
    @location(1) normalOS: vec3f
};

// 注意：binding 0 被 uniform buffer 占用，binding 1 被 storage buffer 占用
// 纹理从 binding 2 开始
@group(0) @binding(2) var diffuse_texture: texture_2d<f32>;
@group(0) @binding(3) var diffuse_sampler: sampler;

@fragment 
fn fs_main(in: VertexOut) -> @location(0) vec4f 
{
    let textureColor = textureSample(diffuse_texture, diffuse_sampler, in.texCoord);
    return textureColor;
}
