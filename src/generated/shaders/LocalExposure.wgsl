// Generated from shaders/Passes/LocalExposure.slang by scripts/build-shaders.mjs. Do not edit.
@binding(11) @group(0) var gPyramidHalfOut_0 : texture_storage_2d<rgba16float, write>;

@binding(2) @group(0) var<storage, read> gExposure_0 : array<vec4<f32>>;

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
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
@binding(1) @group(0) var<storage, read> gAccum_0 : array<vec4<f32>>;

struct LocalExposureParams_std140_0
{
    @align(16) curve_0 : vec4<f32>,
    @align(16) luminanceWeights_0 : vec4<f32>,
    @align(16) info_0 : vec4<u32>,
};

@binding(3) @group(0) var<uniform> gParams_0 : LocalExposureParams_std140_0;
@binding(5) @group(0) var gReducedLut_0 : texture_2d<f32>;

@binding(4) @group(0) var gForwardLut_0 : texture_2d<f32>;

@binding(6) @group(0) var gFine_0 : texture_2d<f32>;

@binding(12) @group(0) var gPyramidFloatOut_0 : texture_storage_2d<rgba32float, write>;

@binding(13) @group(0) var gResultOut_0 : texture_storage_2d<r32float, write>;

@binding(14) @group(0) var<uniform> gLevel_0 : vec4<u32>;
@binding(7) @group(0) var gCoarse_0 : texture_2d<f32>;

@binding(8) @group(0) var gPrevious_0 : texture_2d<f32>;

@binding(9) @group(0) var gMip2_0 : texture_2d<f32>;

@binding(10) @group(0) var gMip3_0 : texture_2d<f32>;

fn rcp_0( x_0 : f32) -> f32
{
    return 1.0f / x_0;
}

fn SampleAccum_0( uv_0 : vec2<f32>) -> vec3<f32>
{
    var size_0 : vec2<u32> = gFrame_0.frame_0.xy;
    var pos_0 : vec2<f32> = uv_0 * vec2<f32>(size_0) - vec2<f32>(0.5f);
    var _S1 : vec2<i32> = vec2<i32>(floor(pos_0));
    var f_0 : vec2<f32> = pos_0 - vec2<f32>(_S1);
    var _S2 : vec2<i32> = vec2<i32>(i32(1));
    var hi_0 : vec2<i32> = vec2<i32>(size_0) - _S2;
    var _S3 : vec2<i32> = vec2<i32>(i32(0));
    var p0_0 : vec2<i32> = clamp(_S1, _S3, hi_0);
    var p1_0 : vec2<i32> = clamp(_S1 + _S2, _S3, hi_0);
    var _S4 : u32 = size_0.x;
    var _S5 : u32 = u32(p0_0.y) * _S4;
    var _S6 : u32 = u32(p0_0.x);
    var _S7 : u32 = u32(p1_0.x);
    var _S8 : vec3<f32> = vec3<f32>(f_0.x);
    var _S9 : u32 = u32(p1_0.y) * _S4;
    return mix(mix(gAccum_0[(_S5 + _S6) * u32(3)].xyz, gAccum_0[(_S5 + _S7) * u32(3)].xyz, _S8), mix(gAccum_0[(_S9 + _S6) * u32(3)].xyz, gAccum_0[(_S9 + _S7) * u32(3)].xyz, _S8), vec3<f32>(f_0.y));
}

fn EyeAdaptationLuminance_0( p_0 : ptr<function, LocalExposureParams_std140_0>,  color_0 : vec3<f32>) -> f32
{
    return max(dot(color_0, (*p_0).luminanceWeights_0.xyz), (*p_0).luminanceWeights_0.w);
}

fn ForwardTablePosition_0( luminance_0 : f32) -> f32
{
    return saturate((log2(max(luminance_0, exp2(-40.0f))) - -40.0f) / 80.0f) * 2047.0f;
}

fn SampleTable_0( table_0 : texture_2d<f32>,  size_1 : u32,  position_0 : f32) -> vec4<f32>
{
    var x_1 : f32 = clamp(position_0, 0.0f, f32(size_1 - u32(1)));
    var _S10 : u32 = min(u32(x_1), size_1 - u32(2));
    var _S11 : i32 = i32(_S10);
    var _S12 : vec3<i32> = vec3<i32>(_S11, i32(0), i32(0));
    var _S13 : vec3<i32> = vec3<i32>(_S11 + i32(1), i32(0), i32(0));
    return mix((textureLoad((table_0), ((_S12)).xy, ((_S12)).z)), (textureLoad((table_0), ((_S13)).xy, ((_S13)).z)), vec4<f32>((x_1 - f32(_S10))));
}

@compute
@workgroup_size(4, 8, 1)
fn Initialize(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var w_0 : u32;
    var h_0 : u32;
    {var dim = textureDimensions((gPyramidHalfOut_0));((w_0)) = dim.x;((h_0)) = dim.y;};
    var _S14 : bool;
    if(((tid_0.x) >= w_0))
    {
        _S14 = true;
    }
    else
    {
        _S14 = ((tid_0.y) >= h_0);
    }
    if(_S14)
    {
        return;
    }
    var _S15 : f32 = gExposure_0[i32(0)].x * rcp_0(gFrame_0.envParams_0.z);
    var _S16 : vec2<f32> = vec2<f32>(0.0f);
    var y_0 : u32 = u32(0);
    var residual_0 : vec2<f32> = _S16;
    var weights_0 : vec2<f32> = _S16;
    loop
    {
        if((y_0 < u32(2)))
        {
        }
        else
        {
            break;
        }
        var x_2 : u32 = u32(0);
        loop
        {
            if((x_2 < u32(2)))
            {
            }
            else
            {
                break;
            }
            var rgb_0 : vec3<f32> = max(SampleAccum_0((vec2<f32>(tid_0.xy) + (vec2<f32>(f32(x_2), f32(y_0)) + vec2<f32>(0.5f)) / vec2<f32>(2.0f)) / vec2<f32>(f32(w_0), f32(h_0))), vec3<f32>(0.0f)) * vec3<f32>(_S15);
            var _S17 : LocalExposureParams_std140_0 = gParams_0;
            var _S18 : f32 = EyeAdaptationLuminance_0(&(_S17), rgb_0);
            var position_1 : f32 = ForwardTablePosition_0(_S18);
            var residual_1 : vec2<f32> = residual_0 + SampleTable_0(gReducedLut_0, u32(2048), position_1).xy;
            var weights_1 : vec2<f32> = weights_0 + SampleTable_0(gForwardLut_0, u32(2048), position_1).yz;
            x_2 = x_2 + u32(1);
            residual_0 = residual_1;
            weights_0 = weights_1;
        }
        y_0 = y_0 + u32(1);
    }
    var _S19 : vec2<f32> = vec2<f32>(0.25f);
    textureStore((gPyramidHalfOut_0), (tid_0.xy), (vec4<f32>(residual_0 * _S19, weights_0 * _S19 - vec2<f32>(0.5f))));
    return;
}

fn SampleBilinear_0( t_0 : texture_2d<f32>,  uv_1 : vec2<f32>) -> vec4<f32>
{
    var size_2 : vec2<u32>;
    var _S20 : u32 = size_2[i32(0)];
    var _S21 : u32 = size_2[i32(1)];
    {var dim = textureDimensions((t_0));((_S20)) = dim.x;((_S21)) = dim.y;};
    size_2[i32(0)] = _S20;
    size_2[i32(1)] = _S21;
    var pos_1 : vec2<f32> = uv_1 * vec2<f32>(size_2) - vec2<f32>(0.5f);
    var _S22 : vec2<i32> = vec2<i32>(floor(pos_1));
    var f_1 : vec2<f32> = pos_1 - vec2<f32>(_S22);
    var _S23 : vec2<i32> = vec2<i32>(i32(1));
    var hi_1 : vec2<i32> = vec2<i32>(size_2) - _S23;
    var _S24 : vec2<i32> = vec2<i32>(i32(0));
    var p0_1 : vec2<i32> = clamp(_S22, _S24, hi_1);
    var p1_1 : vec2<i32> = clamp(_S22 + _S23, _S24, hi_1);
    var _S25 : i32 = p0_1.x;
    var _S26 : i32 = p0_1.y;
    var _S27 : vec3<i32> = vec3<i32>(_S25, _S26, i32(0));
    var _S28 : i32 = p1_1.x;
    var _S29 : vec3<i32> = vec3<i32>(_S28, _S26, i32(0));
    var _S30 : vec4<f32> = vec4<f32>(f_1.x);
    var _S31 : i32 = p1_1.y;
    var _S32 : vec3<i32> = vec3<i32>(_S25, _S31, i32(0));
    var _S33 : vec3<i32> = vec3<i32>(_S28, _S31, i32(0));
    return mix(mix((textureLoad((t_0), ((_S27)).xy, ((_S27)).z)), (textureLoad((t_0), ((_S29)).xy, ((_S29)).z)), _S30), mix((textureLoad((t_0), ((_S32)).xy, ((_S32)).z)), (textureLoad((t_0), ((_S33)).xy, ((_S33)).z)), _S30), vec4<f32>(f_1.y));
}

fn DownsampleTap_0( pixel_0 : vec2<u32>,  size_3 : vec2<u32>) -> vec4<f32>
{
    var inputSize_0 : vec2<u32>;
    var _S34 : u32 = inputSize_0[i32(0)];
    var _S35 : u32 = inputSize_0[i32(1)];
    {var dim = textureDimensions((gFine_0));((_S34)) = dim.x;((_S35)) = dim.y;};
    inputSize_0[i32(0)] = _S34;
    inputSize_0[i32(1)] = _S35;
    var uv_2 : vec2<f32> = (vec2<f32>(pixel_0) + vec2<f32>(0.5f)) / vec2<f32>(size_3);
    var texel_0 : vec2<f32> = vec2<f32>(1.0f) / vec2<f32>(inputSize_0);
    return (SampleBilinear_0(gFine_0, uv_2 + texel_0 * vec2<f32>(-1.0f, -1.0f)) + SampleBilinear_0(gFine_0, uv_2 + texel_0 * vec2<f32>(1.0f, -1.0f)) + SampleBilinear_0(gFine_0, uv_2 + texel_0 * vec2<f32>(-1.0f, 1.0f)) + SampleBilinear_0(gFine_0, uv_2 + texel_0)) * vec4<f32>(0.25f);
}

@compute
@workgroup_size(4, 16, 1)
fn DownsampleHalf(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    var w_1 : u32;
    var h_1 : u32;
    {var dim = textureDimensions((gPyramidHalfOut_0));((w_1)) = dim.x;((h_1)) = dim.y;};
    var _S36 : bool;
    if(((tid_1.x) < w_1))
    {
        _S36 = ((tid_1.y) < h_1);
    }
    else
    {
        _S36 = false;
    }
    if(_S36)
    {
        var _S37 : vec2<u32> = tid_1.xy;
        textureStore((gPyramidHalfOut_0), (_S37), (DownsampleTap_0(_S37, vec2<u32>(w_1, h_1))));
    }
    return;
}

@compute
@workgroup_size(4, 16, 1)
fn DownsampleFloat(@builtin(global_invocation_id) tid_2 : vec3<u32>)
{
    var w_2 : u32;
    var h_2 : u32;
    {var dim = textureDimensions((gPyramidFloatOut_0));((w_2)) = dim.x;((h_2)) = dim.y;};
    var _S38 : bool;
    if(((tid_2.x) < w_2))
    {
        _S38 = ((tid_2.y) < h_2);
    }
    else
    {
        _S38 = false;
    }
    if(_S38)
    {
        var _S39 : vec2<u32> = tid_2.xy;
        textureStore((gPyramidFloatOut_0), (_S39), (DownsampleTap_0(_S39, vec2<u32>(w_2, h_2))));
    }
    return;
}

var<workgroup> tailResidual0_0 : array<f32, i32(683)>;

var<workgroup> tailResidual1_0 : array<f32, i32(683)>;

var<workgroup> tailWeights_0 : array<vec2<f32>, i32(683)>;

var<workgroup> tailResult_0 : array<f32, i32(683)>;

struct TailSample_0
{
     residual_2 : vec2<f32>,
     weights_2 : vec2<f32>,
     reconstruction_0 : f32,
};

fn SampleTail_0( offset_0 : u32,  size_4 : vec2<u32>,  uv_3 : vec2<f32>,  readResult_0 : bool) -> TailSample_0
{
    var pos_2 : vec2<f32> = uv_3 * vec2<f32>(size_4) - vec2<f32>(0.5f);
    var _S40 : vec2<i32> = vec2<i32>(floor(pos_2));
    var f_2 : vec2<f32> = pos_2 - vec2<f32>(_S40);
    var _S41 : vec2<i32> = vec2<i32>(i32(0));
    var _S42 : vec2<i32> = vec2<i32>(i32(1));
    var _S43 : vec2<i32> = vec2<i32>(size_4) - _S42;
    var p0_2 : vec2<i32> = clamp(_S40, _S41, _S43);
    var p1_2 : vec2<i32> = clamp(_S40 + _S42, _S41, _S43);
    var _S44 : u32 = size_4.x;
    var _S45 : u32 = offset_0 + u32(p0_2.y) * _S44;
    var _S46 : u32 = u32(p0_2.x);
    var a_0 : u32 = _S45 + _S46;
    var _S47 : u32 = u32(p1_2.x);
    var b_0 : u32 = _S45 + _S47;
    var _S48 : u32 = offset_0 + u32(p1_2.y) * _S44;
    var c_0 : u32 = _S48 + _S46;
    var d_0 : u32 = _S48 + _S47;
    var value_0 : TailSample_0;
    var _S49 : f32 = f_2.x;
    var _S50 : vec2<f32> = vec2<f32>(_S49);
    var _S51 : f32 = f_2.y;
    var _S52 : vec2<f32> = vec2<f32>(_S51);
    value_0.residual_2 = mix(mix(vec2<f32>(tailResidual0_0[a_0], tailResidual1_0[a_0]), vec2<f32>(tailResidual0_0[b_0], tailResidual1_0[b_0]), _S50), mix(vec2<f32>(tailResidual0_0[c_0], tailResidual1_0[c_0]), vec2<f32>(tailResidual0_0[d_0], tailResidual1_0[d_0]), _S50), _S52);
    value_0.weights_2 = mix(mix(tailWeights_0[a_0], tailWeights_0[b_0], _S50), mix(tailWeights_0[c_0], tailWeights_0[d_0], _S50), _S52);
    var _S53 : f32;
    if(readResult_0)
    {
        _S53 = mix(mix(tailResult_0[a_0], tailResult_0[b_0], _S49), mix(tailResult_0[c_0], tailResult_0[d_0], _S49), _S51);
    }
    else
    {
        _S53 = 0.0f;
    }
    value_0.reconstruction_0 = _S53;
    return value_0;
}

fn RoundToHalf_0( v_0 : vec2<f32>) -> vec2<f32>
{
    return vec2<f32>((unpack2x16float(((pack2x16float(vec2f((v_0.x),0.0))))).x), (unpack2x16float(((pack2x16float(vec2f((v_0.y),0.0))))).x));
}

@compute
@workgroup_size(16, 8, 1)
fn Tail(@builtin(local_invocation_id) local_0 : vec3<u32>)
{
    var x_3 : u32;
    var w_3 : u32;
    var h_3 : u32;
    {var dim = textureDimensions((gResultOut_0));((w_3)) = dim.x;((h_3)) = dim.y;};
    var tailLevels_0 : u32 = gLevel_0.y;
    var _S54 : vec2<u32> = vec2<u32>(w_3, h_3);
    var _S55 : u32 = local_0.y;
    var y_1 : u32 = _S55;
    loop
    {
        if((y_1 < h_3))
        {
        }
        else
        {
            break;
        }
        x_3 = local_0.x;
        loop
        {
            if((x_3 < w_3))
            {
            }
            else
            {
                break;
            }
            var i_0 : u32 = y_1 * w_3 + x_3;
            var _S56 : vec3<i32> = vec3<i32>(i32(x_3), i32(y_1), i32(0));
            var texel_1 : vec4<f32> = (textureLoad((gFine_0), ((_S56)).xy, ((_S56)).z));
            tailResidual0_0[i_0] = texel_1.x;
            tailResidual1_0[i_0] = texel_1.y;
            tailWeights_0[i_0] = texel_1.zw + vec2<f32>(0.5f);
            x_3 = x_3 + u32(16);
        }
        y_1 = y_1 + u32(8);
    }
    workgroupBarrier();
    var currentSize_0 : vec2<u32> = _S54;
    var m_0 : u32 = u32(1);
    var levelOffset_0 : u32 = u32(0);
    loop
    {
        if((m_0 < tailLevels_0))
        {
        }
        else
        {
            break;
        }
        var _S57 : vec2<u32> = currentSize_0 / vec2<u32>(u32(2));
        var _S58 : vec2<u32> = max(_S57, vec2<u32>(u32(1)));
        var levelOffset_1 : u32 = levelOffset_0 + currentSize_0.x * currentSize_0.y;
        y_1 = _S55;
        loop
        {
            if((y_1 < (_S58.y)))
            {
            }
            else
            {
                break;
            }
            x_3 = local_0.x;
            loop
            {
                var _S59 : u32 = _S58.x;
                if((x_3 < _S59))
                {
                }
                else
                {
                    break;
                }
                var index_0 : u32 = levelOffset_1 + y_1 * _S59 + x_3;
                var _S60 : vec2<f32> = vec2<f32>(0.5f);
                var uv_4 : vec2<f32> = (vec2<f32>(f32(x_3), f32(y_1)) + _S60) / vec2<f32>(_S58);
                var texel_2 : vec2<f32> = vec2<f32>(1.0f) / vec2<f32>(currentSize_0);
                var a_1 : TailSample_0 = SampleTail_0(levelOffset_0, currentSize_0, uv_4 + texel_2 * vec2<f32>(-1.0f, -1.0f), false);
                var b_1 : TailSample_0 = SampleTail_0(levelOffset_0, currentSize_0, uv_4 + texel_2 * vec2<f32>(1.0f, -1.0f), false);
                var c_1 : TailSample_0 = SampleTail_0(levelOffset_0, currentSize_0, uv_4 + texel_2 * vec2<f32>(-1.0f, 1.0f), false);
                var d_1 : TailSample_0 = SampleTail_0(levelOffset_0, currentSize_0, uv_4 + texel_2, false);
                var _S61 : vec2<f32> = vec2<f32>(0.25f);
                var residual_3 : vec2<f32> = RoundToHalf_0((a_1.residual_2 + b_1.residual_2 + c_1.residual_2 + d_1.residual_2) * _S61);
                tailResidual0_0[index_0] = residual_3.x;
                tailResidual1_0[index_0] = residual_3.y;
                var _S62 : vec2<f32> = vec2<f32>(65535.0f);
                tailWeights_0[index_0] = floor(saturate((a_1.weights_2 + b_1.weights_2 + c_1.weights_2 + d_1.weights_2) * _S61) * _S62 + _S60) / _S62;
                if(m_0 == (tailLevels_0 - u32(1)))
                {
                    var contribution_0 : vec2<f32> = residual_3 * tailWeights_0[index_0];
                    tailResult_0[index_0] = contribution_0.x + contribution_0.y;
                }
                x_3 = x_3 + u32(16);
            }
            y_1 = y_1 + u32(8);
        }
        workgroupBarrier();
        var _S63 : u32 = m_0 + u32(1);
        currentSize_0 = _S58;
        m_0 = _S63;
        levelOffset_0 = levelOffset_1;
    }
    var firstReverse_0 : i32 = i32(tailLevels_0) - i32(1);
    var firstReverse_1 : i32;
    if((firstReverse_0 > i32(0)))
    {
        var firstReverse_2 : i32 = firstReverse_0 - i32(1);
        var _S64 : vec2<u32> = max((vec2<u32>(w_3, h_3) >> (vec2<u32>(u32(firstReverse_2)))), vec2<u32>(u32(1)));
        var levelOffset_2 : u32 = levelOffset_0 - _S64.x * _S64.y;
        firstReverse_1 = firstReverse_2;
        levelOffset_0 = levelOffset_2;
    }
    else
    {
        firstReverse_1 = firstReverse_0;
    }
    var m_1 : i32 = firstReverse_1;
    loop
    {
        if((m_1 >= i32(0)))
        {
        }
        else
        {
            break;
        }
        var _S65 : vec2<u32> = vec2<u32>(u32(1));
        var _S66 : vec2<u32> = max((vec2<u32>(w_3, h_3) >> (vec2<u32>(u32(m_1)))), _S65);
        var _S67 : vec2<u32> = _S66 / vec2<u32>(u32(2));
        var _S68 : vec2<u32> = max(_S67, _S65);
        var _S69 : u32 = _S66.x;
        var _S70 : u32 = _S66.y;
        var _S71 : u32 = levelOffset_0 + _S69 * _S70;
        var _S72 : bool = m_1 == firstReverse_0;
        y_1 = _S55;
        loop
        {
            if((y_1 < _S70))
            {
            }
            else
            {
                break;
            }
            x_3 = local_0.x;
            loop
            {
                if((x_3 < _S69))
                {
                }
                else
                {
                    break;
                }
                var index_1 : u32 = levelOffset_0 + y_1 * _S69 + x_3;
                var detail_0 : vec2<f32> = vec2<f32>(tailResidual0_0[index_1], tailResidual1_0[index_1]);
                var previousValue_0 : f32;
                var detail_1 : vec2<f32>;
                if(!_S72)
                {
                    var coarse_0 : TailSample_0 = SampleTail_0(_S71, _S68, (vec2<f32>(f32(x_3), f32(y_1)) + vec2<f32>(0.5f)) / vec2<f32>(_S66), true);
                    var detail_2 : vec2<f32> = detail_0 - coarse_0.residual_2;
                    previousValue_0 = coarse_0.reconstruction_0;
                    detail_1 = detail_2;
                }
                else
                {
                    previousValue_0 = 0.0f;
                    detail_1 = detail_0;
                }
                var contribution_1 : vec2<f32> = detail_1 * tailWeights_0[index_1];
                var value_1 : f32 = contribution_1.x + contribution_1.y + previousValue_0;
                if(m_1 == i32(0))
                {
                    textureStore((gResultOut_0), (vec2<u32>(x_3, y_1)), vec4<f32>((value_1), 0, 0, 1));
                }
                else
                {
                    tailResult_0[index_1] = value_1;
                }
                x_3 = x_3 + u32(16);
            }
            y_1 = y_1 + u32(8);
        }
        if((m_1 > i32(0)))
        {
            workgroupBarrier();
            var _S73 : vec2<u32> = max((vec2<u32>(w_3, h_3) >> (vec2<u32>(u32(m_1 - i32(1))))), _S65);
            levelOffset_0 = levelOffset_0 - _S73.x * _S73.y;
        }
        m_1 = m_1 - i32(1);
    }
    return;
}

fn SampleBilinear_1( t_1 : texture_2d<f32>,  uv_5 : vec2<f32>) -> f32
{
    var size_5 : vec2<u32>;
    var _S74 : u32 = size_5[i32(0)];
    var _S75 : u32 = size_5[i32(1)];
    {var dim = textureDimensions((t_1));((_S74)) = dim.x;((_S75)) = dim.y;};
    size_5[i32(0)] = _S74;
    size_5[i32(1)] = _S75;
    var pos_3 : vec2<f32> = uv_5 * vec2<f32>(size_5) - vec2<f32>(0.5f);
    var _S76 : vec2<i32> = vec2<i32>(floor(pos_3));
    var f_3 : vec2<f32> = pos_3 - vec2<f32>(_S76);
    var _S77 : vec2<i32> = vec2<i32>(i32(1));
    var hi_2 : vec2<i32> = vec2<i32>(size_5) - _S77;
    var _S78 : vec2<i32> = vec2<i32>(i32(0));
    var p0_3 : vec2<i32> = clamp(_S76, _S78, hi_2);
    var p1_3 : vec2<i32> = clamp(_S76 + _S77, _S78, hi_2);
    var _S79 : i32 = p0_3.x;
    var _S80 : i32 = p0_3.y;
    var _S81 : vec3<i32> = vec3<i32>(_S79, _S80, i32(0));
    var _S82 : i32 = p1_3.x;
    var _S83 : vec3<i32> = vec3<i32>(_S82, _S80, i32(0));
    var _S84 : f32 = f_3.x;
    var _S85 : i32 = p1_3.y;
    var _S86 : vec3<i32> = vec3<i32>(_S79, _S85, i32(0));
    var _S87 : vec3<i32> = vec3<i32>(_S82, _S85, i32(0));
    return mix(mix((textureLoad((t_1), ((_S81)).xy, ((_S81)).z).x), (textureLoad((t_1), ((_S83)).xy, ((_S83)).z).x), _S84), mix((textureLoad((t_1), ((_S86)).xy, ((_S86)).z).x), (textureLoad((t_1), ((_S87)).xy, ((_S87)).z).x), _S84), f_3.y);
}

@compute
@workgroup_size(8, 8, 1)
fn Reconstruct(@builtin(global_invocation_id) tid_3 : vec3<u32>)
{
    var w_4 : u32;
    var h_4 : u32;
    {var dim = textureDimensions((gResultOut_0));((w_4)) = dim.x;((h_4)) = dim.y;};
    var _S88 : bool;
    if(((tid_3.x) >= w_4))
    {
        _S88 = true;
    }
    else
    {
        _S88 = ((tid_3.y) >= h_4);
    }
    if(_S88)
    {
        return;
    }
    var _S89 : vec2<u32> = tid_3.xy;
    var _S90 : vec2<f32> = vec2<f32>(0.5f);
    var uv_6 : vec2<f32> = (vec2<f32>(_S89) + _S90) / vec2<f32>(f32(w_4), f32(h_4));
    var _S91 : vec3<i32> = vec3<i32>(vec2<i32>(_S89), i32(0));
    var fine_0 : vec4<f32> = (textureLoad((gFine_0), ((_S91)).xy, ((_S91)).z));
    var detail_3 : vec2<f32> = fine_0.xy;
    var value_2 : f32;
    var detail_4 : vec2<f32>;
    if(!((gLevel_0.x) != u32(0)))
    {
        var detail_5 : vec2<f32> = detail_3 - SampleBilinear_0(gCoarse_0, uv_6).xy;
        value_2 = SampleBilinear_1(gPrevious_0, uv_6);
        detail_4 = detail_5;
    }
    else
    {
        value_2 = 0.0f;
        detail_4 = detail_3;
    }
    var contribution_2 : vec2<f32> = detail_4 * (fine_0.zw + _S90);
    textureStore((gResultOut_0), (_S89), vec4<f32>((contribution_2.x + contribution_2.y + value_2), 0, 0, 1));
    return;
}

var<workgroup> mip2Result_0 : array<f32, i32(49)>;

var<workgroup> mip1Result_0 : array<f32, i32(100)>;

@compute
@workgroup_size(16, 16, 1)
fn ReconstructFused(@builtin(global_invocation_id) tid_4 : vec3<u32>, @builtin(local_invocation_id) local_1 : vec3<u32>, @builtin(workgroup_id) group_0 : vec3<u32>)
{
    var w_5 : u32;
    var h_5 : u32;
    {var dim = textureDimensions((gResultOut_0));((w_5)) = dim.x;((h_5)) = dim.y;};
    var pw_0 : u32;
    var ph_0 : u32;
    {var dim = textureDimensions((gCoarse_0));((pw_0)) = dim.x;((ph_0)) = dim.y;};
    var gw_0 : u32;
    var gh_0 : u32;
    {var dim = textureDimensions((gMip2_0));((gw_0)) = dim.x;((gh_0)) = dim.y;};
    var _S92 : vec2<f32> = vec2<f32>(0.5f);
    var _S93 : vec2<i32> = vec2<i32>(floor((vec2<f32>(vec2<i32>(group_0.xy * vec2<u32>(u32(16)))) + _S92) * vec2<f32>(f32(pw_0), f32(ph_0)) / vec2<f32>(f32(w_5), f32(h_5)) - _S92));
    var _S94 : vec2<i32> = vec2<i32>(floor((vec2<f32>(_S93) + _S92) * vec2<f32>(f32(gw_0), f32(gh_0)) / vec2<f32>(f32(pw_0), f32(ph_0)) - _S92));
    var lane_0 : u32 = local_1.y * u32(16) + local_1.x;
    if((lane_0 < u32(49)))
    {
        var p_1 : vec2<i32> = clamp(_S94 + vec2<i32>(i32(lane_0 % u32(7)), i32(lane_0 / u32(7))), vec2<i32>(i32(0)), vec2<i32>(i32(gw_0) - i32(1), i32(gh_0) - i32(1)));
        var uv_7 : vec2<f32> = (vec2<f32>(p_1) + _S92) / vec2<f32>(f32(gw_0), f32(gh_0));
        var _S95 : vec3<i32> = vec3<i32>(p_1, i32(0));
        var texel_3 : vec4<f32> = (textureLoad((gMip2_0), ((_S95)).xy, ((_S95)).z));
        var contribution_3 : vec2<f32> = (texel_3.xy - SampleBilinear_0(gMip3_0, uv_7).xy) * (texel_3.zw + _S92);
        mip2Result_0[lane_0] = contribution_3.x + contribution_3.y + SampleBilinear_1(gPrevious_0, uv_7);
    }
    workgroupBarrier();
    if((lane_0 < u32(100)))
    {
        var p_2 : vec2<i32> = clamp(_S93 + vec2<i32>(i32(lane_0 % u32(10)), i32(lane_0 / u32(10))), vec2<i32>(i32(0)), vec2<i32>(i32(pw_0) - i32(1), i32(ph_0) - i32(1)));
        var uv_8 : vec2<f32> = (vec2<f32>(p_2) + _S92) / vec2<f32>(f32(pw_0), f32(ph_0));
        var _S96 : vec3<i32> = vec3<i32>(p_2, i32(0));
        var texel_4 : vec4<f32> = (textureLoad((gCoarse_0), ((_S96)).xy, ((_S96)).z));
        var contribution_4 : vec2<f32> = (texel_4.xy - SampleBilinear_0(gMip2_0, uv_8).xy) * (texel_4.zw + _S92);
        var pos_4 : vec2<f32> = uv_8 * vec2<f32>(f32(gw_0), f32(gh_0)) - _S92;
        var ip_0 : vec2<i32> = vec2<i32>(floor(pos_4)) - _S94;
        var f_4 : vec2<f32> = fract(pos_4);
        var index_2 : u32 = u32(ip_0.y * i32(7) + ip_0.x);
        var _S97 : f32 = f_4.x;
        mip1Result_0[lane_0] = contribution_4.x + contribution_4.y + mix(mix(mip2Result_0[index_2], mip2Result_0[index_2 + u32(1)], _S97), mix(mip2Result_0[index_2 + u32(7)], mip2Result_0[index_2 + u32(8)], _S97), f_4.y);
    }
    workgroupBarrier();
    var _S98 : bool;
    if(((tid_4.x) >= w_5))
    {
        _S98 = true;
    }
    else
    {
        _S98 = ((tid_4.y) >= h_5);
    }
    if(_S98)
    {
        return;
    }
    var _S99 : vec2<u32> = tid_4.xy;
    var uv_9 : vec2<f32> = (vec2<f32>(_S99) + _S92) / vec2<f32>(f32(w_5), f32(h_5));
    var pos_5 : vec2<f32> = uv_9 * vec2<f32>(f32(pw_0), f32(ph_0)) - _S92;
    var ip_1 : vec2<i32> = vec2<i32>(floor(pos_5)) - _S93;
    var f_5 : vec2<f32> = fract(pos_5);
    var index_3 : u32 = u32(ip_1.y * i32(10) + ip_1.x);
    var _S100 : f32 = f_5.x;
    var _S101 : vec3<i32> = vec3<i32>(vec2<i32>(_S99), i32(0));
    var texel_5 : vec4<f32> = (textureLoad((gFine_0), ((_S101)).xy, ((_S101)).z));
    var contribution_5 : vec2<f32> = (texel_5.xy - SampleBilinear_0(gCoarse_0, uv_9).xy) * (texel_5.zw + _S92);
    textureStore((gResultOut_0), (_S99), vec4<f32>((contribution_5.x + contribution_5.y + mix(mix(mip1Result_0[index_3], mip1Result_0[index_3 + u32(1)], _S100), mix(mip1Result_0[index_3 + u32(10)], mip1Result_0[index_3 + u32(11)], _S100), f_5.y)), 0, 0, 1));
    return;
}

