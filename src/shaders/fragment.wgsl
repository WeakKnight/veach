struct VertexOut 
{
    @builtin(position) pos: vec4f,
    @location(0) texCoord: vec2f
};

// @group(0) @binding(0) var _sampler: sampler;
// @group(0) @binding(1) var _texture: texture_2d<f32>;

@fragment 
fn fs_main(in: VertexOut) -> @location(0) vec4f 
{
    return vec4f(0.5, 0.6, 0.3, 1); // textureSample(_texture, _sampler, in.texCoord);
}