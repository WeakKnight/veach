// Generated from shaders/Passes/OIDNGuides.slang by scripts/build-shaders.mjs. Do not edit.
struct FrameUniforms_std140_0
{
    @align(16) cameraPosition_0 : vec4<f32>,
    @align(16) cameraRight_0 : vec4<f32>,
    @align(16) cameraUp_0 : vec4<f32>,
    @align(16) cameraForward_0 : vec4<f32>,
    @align(16) frame_0 : vec4<u32>,
    @align(16) settings_0 : vec4<u32>,
    @align(16) counts_0 : vec4<u32>,
    @align(16) envInfo_0 : vec4<u32>,
    @align(16) sunDirection_0 : vec4<f32>,
    @align(16) sunRadiance_0 : vec4<f32>,
    @align(16) envParams_0 : vec4<f32>,
    @align(16) background_0 : vec4<f32>,
    @align(16) vtInfo_0 : vec4<u32>,
    @align(16) vtParams_0 : vec4<f32>,
    @align(16) primaryVisibility_0 : vec4<u32>,
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
@binding(2) @group(0) var<storage, read_write> gColor_0 : array<vec4<f32>>;

@binding(1) @group(0) var<storage, read> gAccum_0 : array<vec4<f32>>;

@binding(3) @group(0) var<storage, read_write> gAlbedo_0 : array<vec4<f32>>;

@binding(4) @group(0) var<storage, read_write> gNormal_0 : array<vec4<f32>>;

@binding(6) @group(0) var<storage, read_write> gPresentation_0 : array<vec4<f32>>;

@binding(5) @group(0) var<storage, read> gDenoised_0 : array<vec4<f32>>;

fn isnan_0( x_0 : f32) -> bool
{
    var _S1 : u32 = (bitcast<u32>((x_0)));
    var _S2 : u32 = (_S1 & (u32(8388607)));
    var _S3 : bool;
    if(((((_S1 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S3 = _S2 != u32(0);
    }
    else
    {
        _S3 = false;
    }
    return _S3;
}

fn isinf_0( x_1 : f32) -> bool
{
    var _S4 : u32 = (bitcast<u32>((x_1)));
    var _S5 : u32 = (_S4 & (u32(8388607)));
    var _S6 : bool;
    if(((((_S4 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S6 = _S5 == u32(0);
    }
    else
    {
        _S6 = false;
    }
    return _S6;
}

fn isfinite_0( x_2 : f32) -> bool
{
    var _S7 : bool;
    if(isinf_0(x_2))
    {
        _S7 = true;
    }
    else
    {
        _S7 = isnan_0(x_2);
    }
    return !_S7;
}

fn FiniteOrZero_0( v_0 : vec3<f32>) -> vec3<f32>
{
    var _S8 : f32 = v_0.x;
    var _S9 : f32;
    if(isfinite_0(_S8))
    {
        _S9 = _S8;
    }
    else
    {
        _S9 = 0.0f;
    }
    var _S10 : f32 = v_0.y;
    var _S11 : f32;
    if(isfinite_0(_S10))
    {
        _S11 = _S10;
    }
    else
    {
        _S11 = 0.0f;
    }
    var _S12 : f32 = v_0.z;
    var _S13 : f32;
    if(isfinite_0(_S12))
    {
        _S13 = _S12;
    }
    else
    {
        _S13 = 0.0f;
    }
    return vec3<f32>(_S9, _S11, _S13);
}

@compute
@workgroup_size(8, 8, 1)
fn Prepare(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    if((any((((tid_0.xy) >= (gFrame_0.frame_0.xy))))))
    {
        return;
    }
    var i_0 : u32 = tid_0.y * gFrame_0.frame_0.x + tid_0.x;
    var _S14 : u32 = i_0 * u32(3);
    gColor_0[i_0] = vec4<f32>(max(FiniteOrZero_0(gAccum_0[_S14].xyz), vec3<f32>(0.0f)), 1.0f);
    gAlbedo_0[i_0] = vec4<f32>(saturate(FiniteOrZero_0(gAccum_0[_S14 + u32(1)].xyz)), 1.0f);
    var _S15 : vec3<f32> = vec3<f32>(0.5f);
    gNormal_0[i_0] = vec4<f32>(saturate(FiniteOrZero_0(gAccum_0[_S14 + u32(2)].xyz) * _S15 + _S15), 1.0f);
    return;
}

@compute
@workgroup_size(8, 8, 1)
fn Compose(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    if((any((((tid_1.xy) >= (gFrame_0.frame_0.xy))))))
    {
        return;
    }
    var i_1 : u32 = tid_1.y * gFrame_0.frame_0.x + tid_1.x;
    var _S16 : u32 = i_1 * u32(3);
    gPresentation_0[_S16] = vec4<f32>(max(FiniteOrZero_0(gDenoised_0[i_1].xyz), vec3<f32>(0.0f)), 1.0f);
    var _S17 : u32 = _S16 + u32(1);
    gPresentation_0[_S17] = gAccum_0[_S17];
    var _S18 : u32 = _S16 + u32(2);
    gPresentation_0[_S18] = gAccum_0[_S18];
    return;
}

