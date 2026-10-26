// Generated from shaders/Passes/Present.slang by scripts/build-shaders.mjs. Do not edit.
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

@binding(4) @group(0) var<storage, read> gExposure_0 : array<vec4<f32>>;

struct LocalExposureParams_std140_0
{
    @align(16) curve_0 : vec4<f32>,
    @align(16) luminanceWeights_0 : vec4<f32>,
    @align(16) info_0 : vec4<u32>,
};

@binding(5) @group(0) var<uniform> gLocalExposure_0 : LocalExposureParams_std140_0;
@binding(6) @group(0) var gLocalExposureResidual_0 : texture_2d<f32>;

@binding(7) @group(0) var gLocalExposurePyramid_0 : texture_2d<f32>;

@binding(8) @group(0) var gLocalExposureForwardLut_0 : texture_2d<f32>;

@binding(9) @group(0) var gLocalExposureInverseLut_0 : texture_2d<f32>;

@binding(2) @group(0) var gToneLUT_0 : texture_3d<f32>;

@binding(3) @group(0) var gToneLUTSampler_0 : sampler;

fn rcp_0( x_0 : f32) -> f32
{
    return 1.0f / x_0;
}

struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
};

@vertex
fn vsMain(@builtin(vertex_index) vertexId_0 : u32) -> VSOutput_0
{
    var o_0 : VSOutput_0;
    o_0.position_0 = vec4<f32>(vec2<f32>(f32((((vertexId_0 << (u32(1)))) & (u32(2)))), f32((vertexId_0 & (u32(2))))) * vec2<f32>(2.0f, -2.0f) + vec2<f32>(-1.0f, 1.0f), 0.0f, 1.0f);
    return o_0;
}

fn EyeAdaptationLuminance_0( p_0 : ptr<function, LocalExposureParams_std140_0>,  color_0 : vec3<f32>) -> f32
{
    return max(dot(color_0, (*p_0).luminanceWeights_0.xyz), (*p_0).luminanceWeights_0.w);
}

fn SampleBilinear_0( t_0 : texture_2d<f32>,  uv_0 : vec2<f32>) -> f32
{
    var size_0 : vec2<u32>;
    var _S1 : u32 = size_0[i32(0)];
    var _S2 : u32 = size_0[i32(1)];
    {var dim = textureDimensions((t_0));((_S1)) = dim.x;((_S2)) = dim.y;};
    size_0[i32(0)] = _S1;
    size_0[i32(1)] = _S2;
    var pos_0 : vec2<f32> = uv_0 * vec2<f32>(size_0) - vec2<f32>(0.5f);
    var _S3 : vec2<i32> = vec2<i32>(floor(pos_0));
    var f_0 : vec2<f32> = pos_0 - vec2<f32>(_S3);
    var _S4 : vec2<i32> = vec2<i32>(i32(1));
    var hi_0 : vec2<i32> = vec2<i32>(size_0) - _S4;
    var _S5 : vec2<i32> = vec2<i32>(i32(0));
    var p0_0 : vec2<i32> = clamp(_S3, _S5, hi_0);
    var p1_0 : vec2<i32> = clamp(_S3 + _S4, _S5, hi_0);
    var _S6 : i32 = p0_0.x;
    var _S7 : i32 = p0_0.y;
    var _S8 : vec3<i32> = vec3<i32>(_S6, _S7, i32(0));
    var _S9 : i32 = p1_0.x;
    var _S10 : vec3<i32> = vec3<i32>(_S9, _S7, i32(0));
    var _S11 : f32 = f_0.x;
    var _S12 : i32 = p1_0.y;
    var _S13 : vec3<i32> = vec3<i32>(_S6, _S12, i32(0));
    var _S14 : vec3<i32> = vec3<i32>(_S9, _S12, i32(0));
    return mix(mix((textureLoad((t_0), ((_S8)).xy, ((_S8)).z).x), (textureLoad((t_0), ((_S10)).xy, ((_S10)).z).x), _S11), mix((textureLoad((t_0), ((_S13)).xy, ((_S13)).z).x), (textureLoad((t_0), ((_S14)).xy, ((_S14)).z).x), _S11), f_0.y);
}

fn SampleBilinear_1( t_1 : texture_2d<f32>,  uv_1 : vec2<f32>) -> vec4<f32>
{
    var size_1 : vec2<u32>;
    var _S15 : u32 = size_1[i32(0)];
    var _S16 : u32 = size_1[i32(1)];
    {var dim = textureDimensions((t_1));((_S15)) = dim.x;((_S16)) = dim.y;};
    size_1[i32(0)] = _S15;
    size_1[i32(1)] = _S16;
    var pos_1 : vec2<f32> = uv_1 * vec2<f32>(size_1) - vec2<f32>(0.5f);
    var _S17 : vec2<i32> = vec2<i32>(floor(pos_1));
    var f_1 : vec2<f32> = pos_1 - vec2<f32>(_S17);
    var _S18 : vec2<i32> = vec2<i32>(i32(1));
    var hi_1 : vec2<i32> = vec2<i32>(size_1) - _S18;
    var _S19 : vec2<i32> = vec2<i32>(i32(0));
    var p0_1 : vec2<i32> = clamp(_S17, _S19, hi_1);
    var p1_1 : vec2<i32> = clamp(_S17 + _S18, _S19, hi_1);
    var _S20 : i32 = p0_1.x;
    var _S21 : i32 = p0_1.y;
    var _S22 : vec3<i32> = vec3<i32>(_S20, _S21, i32(0));
    var _S23 : i32 = p1_1.x;
    var _S24 : vec3<i32> = vec3<i32>(_S23, _S21, i32(0));
    var _S25 : vec4<f32> = vec4<f32>(f_1.x);
    var _S26 : i32 = p1_1.y;
    var _S27 : vec3<i32> = vec3<i32>(_S20, _S26, i32(0));
    var _S28 : vec3<i32> = vec3<i32>(_S23, _S26, i32(0));
    return mix(mix((textureLoad((t_1), ((_S22)).xy, ((_S22)).z)), (textureLoad((t_1), ((_S24)).xy, ((_S24)).z)), _S25), mix((textureLoad((t_1), ((_S27)).xy, ((_S27)).z)), (textureLoad((t_1), ((_S28)).xy, ((_S28)).z)), _S25), vec4<f32>(f_1.y));
}

fn ForwardTablePosition_0( luminance_0 : f32) -> f32
{
    return saturate((log2(max(luminance_0, exp2(-40.0f))) - -40.0f) / 80.0f) * 2047.0f;
}

fn SampleTable_0( table_0 : texture_2d<f32>,  size_2 : u32,  position_1 : f32) -> vec4<f32>
{
    var x_1 : f32 = clamp(position_1, 0.0f, f32(size_2 - u32(1)));
    var _S29 : u32 = min(u32(x_1), size_2 - u32(2));
    var _S30 : i32 = i32(_S29);
    var _S31 : vec3<i32> = vec3<i32>(_S30, i32(0), i32(0));
    var _S32 : vec3<i32> = vec3<i32>(_S30 + i32(1), i32(0), i32(0));
    return mix((textureLoad((table_0), ((_S31)).xy, ((_S31)).z)), (textureLoad((table_0), ((_S32)).xy, ((_S32)).z)), vec4<f32>((x_1 - f32(_S29))));
}

fn SampleTable_1( table_1 : texture_2d<f32>,  size_3 : u32,  position_2 : f32) -> f32
{
    var x_2 : f32 = clamp(position_2, 0.0f, f32(size_3 - u32(1)));
    var _S33 : u32 = min(u32(x_2), size_3 - u32(2));
    var _S34 : i32 = i32(_S33);
    var _S35 : vec3<i32> = vec3<i32>(_S34, i32(0), i32(0));
    var _S36 : vec3<i32> = vec3<i32>(_S34 + i32(1), i32(0), i32(0));
    return mix((textureLoad((table_1), ((_S35)).xy, ((_S35)).z).x), (textureLoad((table_1), ((_S36)).xy, ((_S36)).z).x), x_2 - f32(_S33));
}

fn InverseFusionLightness_0( p_1 : ptr<function, LocalExposureParams_std140_0>,  inverseLut_0 : texture_2d<f32>,  lightness_0 : f32) -> f32
{
    var maxInput_0 : f32 = (*p_1).curve_0.x;
    var maxLightness_0 : f32 = (*p_1).curve_0.y;
    var t_2 : f32 = saturate(lightness_0 / maxLightness_0);
    var _S37 : f32 = (*p_1).curve_0.z;
    var _S38 : f32 = min(exp2(SampleTable_1(inverseLut_0, u32(1024), saturate(0.5f + log2((t_2 + _S37) / (1.0f - t_2 + _S37)) / (2.0f * (*p_1).curve_0.w)) * 1023.0f)), maxInput_0);
    var _S39 : f32;
    if((lightness_0 <= 0.0f))
    {
        _S39 = 0.0f;
    }
    else
    {
        if((lightness_0 >= maxLightness_0))
        {
            _S39 = maxInput_0;
        }
        else
        {
            _S39 = _S38;
        }
    }
    return _S39;
}

fn FusionLocalExposure_0( p_2 : ptr<function, LocalExposureParams_std140_0>,  forwardLut_0 : texture_2d<f32>,  inverseLut_1 : texture_2d<f32>,  luminance_1 : f32,  residual_0 : f32,  lowResidual_0 : vec2<f32>) -> f32
{
    var f_2 : vec4<f32> = SampleTable_0(forwardLut_0, u32(2048), ForwardTablePosition_0(luminance_1));
    var _S40 : f32 = InverseFusionLightness_0(&((*p_2)), inverseLut_1, clamp(f_2.x + residual_0 - dot(lowResidual_0, f_2.yz), 0.0f, (*p_2).curve_0.y));
    return clamp(_S40 / max(luminance_1, 9.999999960041972e-13f), exp2(-12.0f), exp2(12.0f));
}

fn LinearToST2084_0( nits_0 : vec3<f32>) -> vec3<f32>
{
    var Lm_0 : vec3<f32> = pow(nits_0 / vec3<f32>(10000.0f), vec3<f32>(0.1593017578125f));
    return pow((vec3<f32>(0.8359375f) + vec3<f32>(18.8515625f) * Lm_0) / (vec3<f32>(1.0f) + vec3<f32>(18.6875f) * Lm_0), vec3<f32>(78.84375f));
}

fn ACES2_0( linearColor_0 : vec3<f32>) -> vec3<f32>
{
    var encoded_0 : vec3<f32> = LinearToST2084_0(clamp(linearColor_0 * vec3<f32>(100.0f), vec3<f32>(0.0f), vec3<f32>(10000.0f)));
    var size_4 : vec3<u32>;
    var _S41 : u32 = size_4[i32(0)];
    var _S42 : u32 = size_4[i32(1)];
    var _S43 : u32 = size_4[i32(2)];
    {var dim = textureDimensions((gToneLUT_0));((_S41)) = dim.x;((_S42)) = dim.y;((_S43)) = dim.z;};
    size_4[i32(0)] = _S41;
    size_4[i32(1)] = _S42;
    size_4[i32(2)] = _S43;
    var n_0 : f32 = f32(size_4.x);
    return (textureSampleLevel((gToneLUT_0), (gToneLUTSampler_0), (encoded_0 * vec3<f32>(((n_0 - 1.0f) / n_0)) + vec3<f32>((0.5f / n_0))), (0.0f))).xyz;
}

fn ACESFilmic_0( color_1 : vec3<f32>) -> vec3<f32>
{
    var _S44 : vec3<f32> = color_1 * vec3<f32>(0.60000002384185791f);
    return saturate(_S44 * (vec3<f32>(2.5099999904632568f) * _S44 + vec3<f32>(0.029999999329447746f)) / (_S44 * (vec3<f32>(2.4300000667572021f) * _S44 + vec3<f32>(0.5899999737739563f)) + vec3<f32>(0.14000000059604645f)));
}

fn LinearToSrgb_0( c_0 : vec3<f32>) -> vec3<f32>
{
    return select(vec3<f32>(1.0549999475479126f) * pow(max(c_0, vec3<f32>(0.0f)), vec3<f32>(0.4166666567325592f)) - vec3<f32>(0.054999999701976776f), c_0 * vec3<f32>(12.920000076293945f), (c_0 <= vec3<f32>(0.0031308000907301903f)));
}

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

@fragment
fn fsMain(@builtin(position) position_3 : vec4<f32>) -> pixelOutput_0
{
    var _S45 : vec2<u32> = min(vec2<u32>(position_3.xy), gFrame_0.frame_0.xy - vec2<u32>(u32(1)));
    var color_2 : vec3<f32> = gAccum_0[(_S45.y * gFrame_0.frame_0.x + _S45.x) * u32(3)].xyz;
    var color_3 : vec3<f32>;
    if((gFrame_0.settings_0.y) == u32(0))
    {
        var color_4 : vec3<f32> = color_2 * vec3<f32>((gExposure_0[i32(0)].x * rcp_0(gFrame_0.envParams_0.z)));
        if((gLocalExposure_0.info_0.x) != u32(0))
        {
            var uv_2 : vec2<f32> = (vec2<f32>(_S45) + vec2<f32>(0.5f)) / vec2<f32>(gFrame_0.frame_0.xy);
            var _S46 : LocalExposureParams_std140_0 = gLocalExposure_0;
            var _S47 : f32 = EyeAdaptationLuminance_0(&(_S46), color_4);
            var _S48 : f32 = FusionLocalExposure_0(&(_S46), gLocalExposureForwardLut_0, gLocalExposureInverseLut_0, _S47, SampleBilinear_0(gLocalExposureResidual_0, uv_2), SampleBilinear_1(gLocalExposurePyramid_0, uv_2).xy);
            if((gLocalExposure_0.info_0.y) != u32(0))
            {
                var _S49 : pixelOutput_0 = pixelOutput_0( vec4<f32>(vec3<f32>(saturate(log2(_S48) / 12.0f + 0.5f)), 1.0f) );
                return _S49;
            }
            color_3 = color_4 * vec3<f32>(_S48);
        }
        else
        {
            color_3 = color_4;
        }
        if((gFrame_0.settings_0.w) == u32(2))
        {
            var _S50 : pixelOutput_0 = pixelOutput_0( vec4<f32>(saturate(ACES2_0(color_3)), 1.0f) );
            return _S50;
        }
        if((gFrame_0.settings_0.w) == u32(1))
        {
            color_3 = ACESFilmic_0(color_3);
        }
    }
    else
    {
        color_3 = color_2;
    }
    var _S51 : pixelOutput_0 = pixelOutput_0( vec4<f32>(LinearToSrgb_0(saturate(color_3)), 1.0f) );
    return _S51;
}

