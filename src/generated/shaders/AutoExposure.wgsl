// Generated from shaders/Passes/AutoExposure.slang by scripts/build-shaders.mjs. Do not edit.
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
    @align(16) sharc_0 : vec4<u32>,
    @align(16) sharcParams_0 : vec4<f32>,
    @align(16) sharcControl_0 : vec4<u32>,
    @align(16) temporal_0 : vec4<f32>,
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
@binding(1) @group(0) var<storage, read> gAccum_0 : array<vec4<f32>>;

struct EyeAdaptationParams_std140_0
{
    @align(16) histogram_0 : vec4<f32>,
    @align(16) luminance_0 : vec4<f32>,
    @align(16) adaptation_0 : vec4<f32>,
    @align(16) timing_0 : vec4<f32>,
    @align(16) luminanceWeights_0 : vec4<f32>,
};

@binding(2) @group(0) var<uniform> gParams_0 : EyeAdaptationParams_std140_0;
@binding(3) @group(0) var<storage, read_write> gHistogram_0 : array<atomic<u32>>;

@binding(4) @group(0) var<storage, read_write> gExposure_0 : array<vec4<f32>>;

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

fn rcp_0( x_3 : f32) -> f32
{
    return 1.0f / x_3;
}

var<workgroup> gsHistogram_0 : array<atomic<u32>, i32(64)>;

fn ComputeHistogramPositionFromLuminance_0( luminance_1 : f32) -> f32
{
    return log2(luminance_1) * gParams_0.histogram_0.x + gParams_0.histogram_0.y;
}

@compute
@workgroup_size(16, 16, 1)
fn Histogram(@builtin(global_invocation_id) tid_0 : vec3<u32>, @builtin(local_invocation_index) groupIndex_0 : u32)
{
    var _S8 : bool = (groupIndex_0 < u32(64));
    if(_S8)
    {
        atomicStore(&(gsHistogram_0[groupIndex_0]), u32(0));
    }
    workgroupBarrier();
    var _S9 : u32 = tid_0.x;
    var _S10 : bool;
    if((_S9 < (gFrame_0.frame_0.x)))
    {
        _S10 = ((tid_0.y) < (gFrame_0.frame_0.y));
    }
    else
    {
        _S10 = false;
    }
    if(_S10)
    {
        var bucket_0 : f32 = saturate(ComputeHistogramPositionFromLuminance_0(max(dot(gAccum_0[(tid_0.y * gFrame_0.frame_0.x + _S9) * u32(3)].xyz * vec3<f32>(rcp_0(gFrame_0.envParams_0.z)), gParams_0.luminanceWeights_0.xyz), 9.99999968265522539e-21f))) * 63.0f;
        var bucket0_0 : u32 = u32(bucket_0);
        var _S11 : u32 = min(bucket0_0 + u32(1), u32(63));
        var weight1_0 : f32 = fract(bucket_0);
        var weight0_0 : f32;
        if(bucket0_0 == u32(0))
        {
            weight0_0 = 0.0f;
        }
        else
        {
            weight0_0 = 1.0f - weight1_0;
        }
        var _S12 : u32 = atomicAdd(&(gsHistogram_0[bucket0_0]), u32(weight0_0 * 128.0f + 0.5f));
        var _S13 : u32 = atomicAdd(&(gsHistogram_0[_S11]), u32(weight1_0 * 128.0f + 0.5f));
    }
    workgroupBarrier();
    if(_S8)
    {
        var count_0 : u32 = atomicLoad(&(gsHistogram_0[groupIndex_0]));
        if(count_0 != u32(0))
        {
            var _S14 : u32 = atomicAdd(&(gHistogram_0[groupIndex_0]), count_0);
        }
    }
    return;
}

fn ComputeLogLuminanceFromHistogramPosition_0( position_0 : f32) -> f32
{
    return (position_0 - gParams_0.histogram_0.y) / gParams_0.histogram_0.x;
}

fn ComputeAverageLuminanceWithoutOutlier_0( minFractionSum_0 : f32,  maxFractionSum_0 : f32) -> f32
{
    if(((abs(gParams_0.histogram_0.z - gParams_0.histogram_0.w)) < 9.9999997473787516e-05f))
    {
        return 1.0f;
    }
    var _S15 : vec2<f32> = vec2<f32>(0.0f);
    var i_0 : u32 = u32(0);
    var _S16 : f32 = minFractionSum_0;
    var _S17 : f32 = maxFractionSum_0;
    var sumWithoutOutliers_0 : vec2<f32> = _S15;
    loop
    {
        if((i_0 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var _S18 : u32 = atomicLoad(&(gHistogram_0[i_0]));
        var value_0 : f32 = f32(_S18);
        var _S19 : f32 = min(value_0, _S16);
        var _S20 : f32 = _S16 - _S19;
        var _S21 : f32 = _S17 - _S19;
        var _S22 : f32 = min(value_0 - _S19, _S21);
        var _S23 : f32 = _S21 - _S22;
        var sumWithoutOutliers_1 : vec2<f32> = sumWithoutOutliers_0 + vec2<f32>(ComputeLogLuminanceFromHistogramPosition_0(f32(i_0) / 63.0f), 1.0f) * vec2<f32>(_S22);
        i_0 = i_0 + u32(1);
        _S16 = _S20;
        _S17 = _S23;
        sumWithoutOutliers_0 = sumWithoutOutliers_1;
    }
    var _S24 : f32 = sumWithoutOutliers_0.y;
    if(_S24 == 0.0f)
    {
        return gParams_0.luminance_0.x / 0.18000000715255737f;
    }
    return exp2(sumWithoutOutliers_0.x / _S24);
}

fn ExponentialAdaption_0( current_0 : f32,  target_0 : f32,  frameTime_0 : f32,  speed_0 : f32,  m_0 : f32) -> f32
{
    return current_0 + (target_0 - current_0) * (1.0f - exp2(- frameTime_0 * speed_0)) * m_0;
}

fn LinearAdaption_0( current_1 : f32,  target_1 : f32,  frameTime_1 : f32,  speed_1 : f32) -> f32
{
    var offset_0 : f32 = frameTime_1 * speed_1;
    var _S25 : f32;
    if((current_1 < target_1))
    {
        _S25 = min(target_1, current_1 + offset_0);
    }
    else
    {
        _S25 = max(target_1, current_1 - offset_0);
    }
    return _S25;
}

fn ComputeEyeAdaptation_0( oldExposure_0 : f32,  targetExposure_0 : f32,  frameTime_2 : f32) -> f32
{
    var logTarget_0 : f32 = log2(targetExposure_0);
    var logOld_0 : f32 = log2(oldExposure_0);
    var logDiff_0 : f32 = logTarget_0 - logOld_0;
    var _S26 : bool = (logDiff_0 > 0.0f);
    var speed_2 : f32;
    if(_S26)
    {
        speed_2 = gParams_0.adaptation_0.x;
    }
    else
    {
        speed_2 = gParams_0.adaptation_0.y;
    }
    var m_1 : f32;
    if(_S26)
    {
        m_1 = gParams_0.adaptation_0.z;
    }
    else
    {
        m_1 = gParams_0.adaptation_0.w;
    }
    var exponential_0 : f32 = ExponentialAdaption_0(logOld_0, logTarget_0, frameTime_2, speed_2, m_1);
    var linear_0 : f32 = LinearAdaption_0(logOld_0, logTarget_0, frameTime_2, speed_2);
    if(((abs(logDiff_0)) > (gParams_0.timing_0.y)))
    {
        speed_2 = linear_0;
    }
    else
    {
        speed_2 = exponential_0;
    }
    return mix(exp2(speed_2), targetExposure_0, gParams_0.timing_0.z);
}

@compute
@workgroup_size(1, 1, 1)
fn EyeAdaptation()
{
    var minAverageLuminance_0 : f32 = gParams_0.luminance_0.x;
    var maxAverageLuminance_0 : f32 = gParams_0.luminance_0.y;
    var compensation_0 : f32 = gParams_0.luminance_0.z;
    var i_1 : u32 = u32(0);
    var histogramSum_0 : f32 = 0.0f;
    loop
    {
        if((i_1 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var _S27 : u32 = atomicLoad(&(gHistogram_0[i_1]));
        var histogramSum_1 : f32 = histogramSum_0 + f32(_S27);
        i_1 = i_1 + u32(1);
        histogramSum_0 = histogramSum_1;
    }
    var averageLuminance_0 : f32 = ComputeAverageLuminanceWithoutOutlier_0(histogramSum_0 * gParams_0.histogram_0.z, histogramSum_0 * gParams_0.histogram_0.w);
    var targetExposure_1 : f32 = clamp(averageLuminance_0, minAverageLuminance_0, maxAverageLuminance_0) / 0.18000000715255737f;
    var oldExposureScale_0 : f32 = gExposure_0[i32(0)].x;
    var _S28 : bool;
    if((oldExposureScale_0 > 0.0f))
    {
        _S28 = isfinite_0(oldExposureScale_0);
    }
    else
    {
        _S28 = false;
    }
    if(_S28)
    {
        histogramSum_0 = oldExposureScale_0;
    }
    else
    {
        histogramSum_0 = 1.0f;
    }
    gExposure_0[i32(0)] = vec4<f32>(compensation_0 / max(9.9999997473787516e-05f, clamp(ComputeEyeAdaptation_0(compensation_0 / histogramSum_0, targetExposure_1, gParams_0.timing_0.x), minAverageLuminance_0 / 0.18000000715255737f, maxAverageLuminance_0 / 0.18000000715255737f)), compensation_0 / max(9.9999997473787516e-05f, targetExposure_1), averageLuminance_0, compensation_0);
    gExposure_0[i32(1)] = vec4<f32>(1.0f, 0.0f, 0.0f, 0.0f);
    return;
}

