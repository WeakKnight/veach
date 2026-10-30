// Generated from shaders/Passes/TemporalAA.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(2) @group(0) var<storage, read> gCurrent_0 : array<vec4<f32>>;

struct TemporalParams_std140_0
{
    @align(16) previousPosition_0 : vec4<f32>,
    @align(16) previousInverse_0 : array<vec4<f32>, i32(3)>,
    @align(16) jitter_0 : vec4<f32>,
    @align(16) control_0 : vec4<f32>,
    @align(16) counts_1 : vec4<u32>,
};

@binding(1) @group(0) var<uniform> gTemporal_0 : TemporalParams_std140_0;
struct Instance_std430_0
{
    @align(16) objectToWorld_0 : array<vec4<f32>, i32(3)>,
    @align(16) worldToObject_0 : array<vec4<f32>, i32(3)>,
    @align(16) blasNodeOffset_0 : u32,
    @align(4) blasTriOffset_0 : u32,
    @align(8) indexOffset_0 : u32,
    @align(4) vertexOffset_0 : u32,
    @align(16) materialIndex_0 : u32,
    @align(4) flags_0 : u32,
    @align(8) lightOffset_0 : u32,
    @align(4) triCount_0 : u32,
};

@binding(4) @group(0) var<storage, read> gInstances_0 : array<Instance_std430_0>;

@binding(5) @group(0) var<storage, read> gPreviousInstances_0 : array<Instance_std430_0>;

@binding(8) @group(0) var<storage, read_write> gMotion_0 : array<vec4<f32>>;

@binding(3) @group(0) var<storage, read> gHistory_0 : array<vec4<f32>>;

@binding(6) @group(0) var<storage, read_write> gNextHistory_0 : array<vec4<f32>>;

@binding(7) @group(0) var<storage, read_write> gOutput_0 : array<vec4<f32>>;

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

fn isfinite_1( x_4 : vec2<f32>) -> vec2<bool>
{
    var result_0 : vec2<bool>;
    var i_0 : i32 = i32(0);
    loop
    {
        if((i_0 < i32(2)))
        {
        }
        else
        {
            break;
        }
        result_0[i_0] = isfinite_0(x_4[i_0]);
        i_0 = i_0 + i32(1);
    }
    return result_0;
}

fn isfinite_2( x_5 : vec3<f32>) -> vec3<bool>
{
    var result_1 : vec3<bool>;
    var i_1 : i32 = i32(0);
    loop
    {
        if((i_1 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_1[i_1] = isfinite_0(x_5[i_1]);
        i_1 = i_1 + i32(1);
    }
    return result_1;
}

fn AffinePoint_0( _S8 : u32,  _S9 : vec3<f32>) -> vec3<f32>
{
    var _S10 : vec4<f32> = vec4<f32>(_S9, 1.0f);
    return vec3<f32>(dot(gInstances_0[_S8].worldToObject_0[i32(0)], _S10), dot(gInstances_0[_S8].worldToObject_0[i32(1)], _S10), dot(gInstances_0[_S8].worldToObject_0[i32(2)], _S10));
}

fn AffinePoint_1( _S11 : u32,  _S12 : vec3<f32>) -> vec3<f32>
{
    var _S13 : vec4<f32> = vec4<f32>(_S12, 1.0f);
    return vec3<f32>(dot(gPreviousInstances_0[_S11].objectToWorld_0[i32(0)], _S13), dot(gPreviousInstances_0[_S11].objectToWorld_0[i32(1)], _S13), dot(gPreviousInstances_0[_S11].objectToWorld_0[i32(2)], _S13));
}

@compute
@workgroup_size(8, 8, 1)
fn GenerateMotion(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var pixel_0 : vec2<u32> = tid_0.xy;
    var size_0 : vec2<u32> = gFrame_0.frame_0.xy;
    if((any(((pixel_0 >= size_0)))))
    {
        return;
    }
    var _S14 : u32 = pixel_0.y * size_0.x + pixel_0.x;
    var base_0 : u32 = _S14 * u32(3);
    var distance_0 : f32 = gCurrent_0[base_0 + u32(1)].w;
    var id_0 : u32 = u32(gCurrent_0[base_0 + u32(2)].w);
    var _S15 : vec2<f32> = vec2<f32>(pixel_0);
    var _S16 : vec2<f32> = vec2<f32>(size_0);
    var ndc_0 : vec2<f32> = (_S15 + gFrame_0.temporal_0.xy) / _S16 * vec2<f32>(2.0f, -2.0f) + vec2<f32>(-1.0f, 1.0f);
    var direction_0 : vec3<f32> = normalize(gFrame_0.cameraForward_0.xyz + vec3<f32>(ndc_0.x) * gFrame_0.cameraRight_0.xyz + vec3<f32>(ndc_0.y) * gFrame_0.cameraUp_0.xyz);
    var _S17 : bool = id_0 == u32(0);
    var world_0 : vec3<f32>;
    if(_S17)
    {
        world_0 = direction_0;
    }
    else
    {
        world_0 = gFrame_0.cameraPosition_0.xyz + direction_0 * vec3<f32>(distance_0);
    }
    var valid_0 : bool;
    if((gTemporal_0.control_0.w) != 0.0f)
    {
        valid_0 = (all((isfinite_2(world_0))));
    }
    else
    {
        valid_0 = false;
    }
    var previous_0 : vec3<f32>;
    if(id_0 != u32(0))
    {
        if(valid_0)
        {
            valid_0 = (id_0 <= (gTemporal_0.counts_1.x));
        }
        else
        {
            valid_0 = false;
        }
        if(valid_0)
        {
            valid_0 = (id_0 <= (gTemporal_0.counts_1.y));
        }
        else
        {
            valid_0 = false;
        }
        if(valid_0)
        {
            valid_0 = (distance_0 > 0.0f);
        }
        else
        {
            valid_0 = false;
        }
        if(valid_0)
        {
            var _S18 : u32 = id_0 - u32(1);
            previous_0 = AffinePoint_1(_S18, AffinePoint_0(_S18, world_0));
        }
        else
        {
            previous_0 = world_0;
        }
    }
    else
    {
        previous_0 = world_0;
    }
    var relative_0 : vec3<f32>;
    if(_S17)
    {
        relative_0 = previous_0;
    }
    else
    {
        relative_0 = previous_0 - gTemporal_0.previousPosition_0.xyz;
    }
    var _S19 : f32 = dot(relative_0, gTemporal_0.previousInverse_0[i32(0)].xyz);
    var _S20 : f32 = dot(relative_0, gTemporal_0.previousInverse_0[i32(1)].xyz);
    var _S21 : f32 = dot(relative_0, gTemporal_0.previousInverse_0[i32(2)].xyz);
    var q_0 : vec3<f32> = vec3<f32>(_S19, _S20, _S21);
    if(valid_0)
    {
        valid_0 = (_S21 > 9.99999997475242708e-07f);
    }
    else
    {
        valid_0 = false;
    }
    if(valid_0)
    {
        valid_0 = (all((isfinite_2(q_0))));
    }
    else
    {
        valid_0 = false;
    }
    var motion_0 : vec2<f32> = (vec2<f32>(_S19, _S20) / vec2<f32>(max(_S21, 9.99999997475242708e-07f)) * vec2<f32>(0.5f, -0.5f) + vec2<f32>(0.5f)) * _S16 - (_S15 + gFrame_0.temporal_0.xy);
    if(valid_0)
    {
        valid_0 = (all((isfinite_1(motion_0))));
    }
    else
    {
        valid_0 = false;
    }
    var index_0 : u32 = _S14 * u32(2);
    var _S22 : vec4<f32>;
    if(valid_0)
    {
        _S22 = vec4<f32>(motion_0, 0.0f, 1.0f);
    }
    else
    {
        _S22 = vec4<f32>(0.0f);
    }
    gMotion_0[index_0] = _S22;
    if(valid_0)
    {
        _S22 = vec4<f32>(previous_0, 0.0f);
    }
    else
    {
        _S22 = vec4<f32>(0.0f);
    }
    gMotion_0[index_0 + u32(1)] = _S22;
    return;
}

fn CurrentColor_0( base_1 : u32) -> vec3<f32>
{
    var c_0 : vec3<f32> = gCurrent_0[base_1].xyz / vec3<f32>(max(gFrame_0.envParams_0.z, 9.99999993922529029e-09f));
    var _S23 : vec3<f32>;
    if((all((isfinite_2(c_0)))))
    {
        _S23 = max(c_0, vec3<f32>(0.0f));
    }
    else
    {
        _S23 = vec3<f32>(0.0f);
    }
    return _S23;
}

fn EncodePQ_0( color_0 : vec3<f32>) -> vec3<f32>
{
    var m_0 : vec3<f32> = pow(max(color_0 / vec3<f32>(gTemporal_0.control_0.z), vec3<f32>(0.0f)), vec3<f32>(0.1593017578125f));
    return saturate(pow((vec3<f32>(0.8359375f) + vec3<f32>(18.8515625f) * m_0) / (vec3<f32>(1.0f) + vec3<f32>(18.6875f) * m_0), vec3<f32>(78.84375f)));
}

fn DecodePQ_0( color_1 : vec3<f32>) -> vec3<f32>
{
    var m_1 : vec3<f32> = pow(saturate(color_1), vec3<f32>(0.012683313339948654f));
    return pow(max(m_1 - vec3<f32>(0.8359375f), vec3<f32>(0.0f)) / max(vec3<f32>(18.8515625f) - vec3<f32>(18.6875f) * m_1, vec3<f32>(9.99999997475242708e-07f)), vec3<f32>(6.2773947715759277f)) * vec3<f32>(gTemporal_0.control_0.z);
}

@compute
@workgroup_size(8, 8, 1)
fn Resolve(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    var pixel_1 : vec2<u32> = tid_1.xy;
    var size_1 : vec2<u32> = gFrame_0.frame_0.xy;
    if((any(((pixel_1 >= size_1)))))
    {
        return;
    }
    var _S24 : u32 = size_1.x;
    var index_1 : u32 = pixel_1.y * _S24 + pixel_1.x;
    var base_2 : u32 = index_1 * u32(3);
    var current_0 : vec3<f32> = CurrentColor_0(base_2);
    var pq_0 : vec3<f32> = EncodePQ_0(current_0);
    var _S25 : u32 = base_2 + u32(1);
    var distance_1 : f32 = gCurrent_0[_S25].w;
    var _S26 : u32 = base_2 + u32(2);
    var id_1 : u32 = u32(gCurrent_0[_S26].w);
    var normal_0 : vec3<f32> = gCurrent_0[_S26].xyz;
    var _S27 : vec2<f32> = vec2<f32>(pixel_1);
    var _S28 : vec2<f32> = vec2<f32>(size_1);
    var ndc_1 : vec2<f32> = (_S27 + gFrame_0.temporal_0.xy) / _S28 * vec2<f32>(2.0f, -2.0f) + vec2<f32>(-1.0f, 1.0f);
    var direction_1 : vec3<f32> = normalize(gFrame_0.cameraForward_0.xyz + vec3<f32>(ndc_1.x) * gFrame_0.cameraRight_0.xyz + vec3<f32>(ndc_1.y) * gFrame_0.cameraUp_0.xyz);
    var _S29 : bool = id_1 == u32(0);
    var world_1 : vec3<f32>;
    if(_S29)
    {
        world_1 = direction_1;
    }
    else
    {
        world_1 = gFrame_0.cameraPosition_0.xyz + direction_1 * vec3<f32>(distance_1);
    }
    var _S30 : u32 = index_1 * u32(2);
    var motion_1 : vec4<f32> = gMotion_0[_S30];
    var previous_1 : vec3<f32> = gMotion_0[_S30 + u32(1)].xyz;
    var relative_1 : vec3<f32>;
    if(_S29)
    {
        relative_1 = previous_1;
    }
    else
    {
        relative_1 = previous_1 - gTemporal_0.previousPosition_0.xyz;
    }
    var valid_1 : bool = (motion_1.w) != 0.0f;
    var _S31 : vec2<f32> = motion_1.xy;
    var source_0 : vec2<f32> = _S27 + _S31 + gFrame_0.temporal_0.xy - gTemporal_0.jitter_0.xy;
    var valid_2 : bool;
    if(valid_1)
    {
        valid_2 = (all(((source_0 >= vec2<f32>(-0.5f)))));
    }
    else
    {
        valid_2 = false;
    }
    if(valid_2)
    {
        valid_2 = (all(((source_0 < (_S28 - vec2<f32>(0.5f))))));
    }
    else
    {
        valid_2 = false;
    }
    var _S32 : vec4<f32> = vec4<f32>(0.0f);
    var y_0 : i32;
    var x_6 : i32;
    var history_0 : vec4<f32>;
    var age_0 : f32;
    var weightSum_0 : f32;
    var count_0 : f32;
    if(valid_2)
    {
        var _S33 : vec2<i32> = vec2<i32>(floor(source_0));
        var _S34 : vec2<f32> = fract(source_0);
        var _S35 : f32 = max(9.9999997473787516e-05f, length(relative_1) * gTemporal_0.jitter_0.z * 2.0f);
        y_0 = i32(0);
        var history_1 : vec4<f32> = _S32;
        age_0 = 0.0f;
        loop
        {
            if((y_0 < i32(2)))
            {
            }
            else
            {
                break;
            }
            x_6 = i32(0);
            history_0 = history_1;
            weightSum_0 = age_0;
            loop
            {
                if((x_6 < i32(2)))
                {
                }
                else
                {
                    break;
                }
                var p_0 : vec2<i32> = _S33 + vec2<i32>(x_6, y_0);
                if((any(((p_0 < vec2<i32>(i32(0)))))))
                {
                    valid_2 = true;
                }
                else
                {
                    valid_2 = (any(((p_0 >= vec2<i32>(size_1)))));
                }
                if(valid_2)
                {
                    x_6 = x_6 + i32(1);
                    continue;
                }
                var b_0 : u32 = (u32(p_0.y) * _S24 + u32(p_0.x)) * u32(3);
                var position_0 : vec4<f32> = gHistory_0[b_0 + u32(1)];
                var _S36 : bool;
                if(u32(position_0.w) != id_1)
                {
                    _S36 = true;
                }
                else
                {
                    _S36 = ((gHistory_0[b_0].w) < 1.0f);
                }
                if(_S36)
                {
                    x_6 = x_6 + i32(1);
                    continue;
                }
                var _S37 : bool;
                if(id_1 != u32(0))
                {
                    if(((length(position_0.xyz - previous_1)) > _S35))
                    {
                        _S37 = true;
                    }
                    else
                    {
                        _S37 = ((dot(normal_0, gHistory_0[b_0 + u32(2)].xyz)) < 0.5f);
                    }
                }
                else
                {
                    _S37 = false;
                }
                if(_S37)
                {
                    x_6 = x_6 + i32(1);
                    continue;
                }
                var _S38 : bool;
                if(_S29)
                {
                    _S38 = ((dot(position_0.xyz, previous_1)) < 0.99000000953674316f);
                }
                else
                {
                    _S38 = false;
                }
                if(_S38)
                {
                    x_6 = x_6 + i32(1);
                    continue;
                }
                if(x_6 == i32(0))
                {
                    count_0 = 1.0f - _S34.x;
                }
                else
                {
                    count_0 = _S34.x;
                }
                var _S39 : f32;
                if(y_0 == i32(0))
                {
                    _S39 = 1.0f - _S34.y;
                }
                else
                {
                    _S39 = _S34.y;
                }
                var w_0 : f32 = count_0 * _S39;
                var weightSum_1 : f32 = weightSum_0 + w_0;
                history_0 = history_0 + gHistory_0[b_0] * vec4<f32>(w_0);
                weightSum_0 = weightSum_1;
                x_6 = x_6 + i32(1);
            }
            y_0 = y_0 + i32(1);
            history_1 = history_0;
            age_0 = weightSum_0;
        }
        weightSum_0 = age_0;
        history_0 = history_1;
    }
    else
    {
        weightSum_0 = 0.0f;
        history_0 = _S32;
    }
    var pq_1 : vec3<f32>;
    var result_2 : vec3<f32>;
    var debug_0 : vec3<f32>;
    if((weightSum_0 > 0.05000000074505806f))
    {
        var history_2 : vec4<f32> = history_0 / vec4<f32>(weightSum_0);
        var _S40 : vec3<f32> = vec3<f32>(0.0f);
        y_0 = i32(-1);
        pq_1 = _S40;
        result_2 = _S40;
        age_0 = 0.0f;
        loop
        {
            if((y_0 <= i32(1)))
            {
            }
            else
            {
                break;
            }
            x_6 = i32(-1);
            debug_0 = pq_1;
            var moment_0 : vec3<f32> = result_2;
            count_0 = age_0;
            loop
            {
                if((x_6 <= i32(1)))
                {
                }
                else
                {
                    break;
                }
                var p_1 : vec2<i32> = vec2<i32>(pixel_1) + vec2<i32>(x_6, y_0);
                if((any(((p_1 < vec2<i32>(i32(0)))))))
                {
                    valid_2 = true;
                }
                else
                {
                    valid_2 = (any(((p_1 >= vec2<i32>(size_1)))));
                }
                if(valid_2)
                {
                    x_6 = x_6 + i32(1);
                    continue;
                }
                var c_1 : vec3<f32> = EncodePQ_0(CurrentColor_0((u32(p_1.y) * _S24 + u32(p_1.x)) * u32(3)));
                var moment_1 : vec3<f32> = moment_0 + c_1 * c_1;
                var count_1 : f32 = count_0 + 1.0f;
                debug_0 = debug_0 + c_1;
                moment_0 = moment_1;
                count_0 = count_1;
                x_6 = x_6 + i32(1);
            }
            y_0 = y_0 + i32(1);
            pq_1 = debug_0;
            result_2 = moment_0;
            age_0 = count_0;
        }
        var mean_0 : vec3<f32> = pq_1 / vec3<f32>(age_0);
        var sigma_0 : vec3<f32> = sqrt(max(result_2 / vec3<f32>(age_0) - mean_0 * mean_0, _S40)) * vec3<f32>(gTemporal_0.control_0.y);
        var _S41 : f32 = history_2.w + 1.0f;
        var pq_2 : vec3<f32> = mix(clamp(history_2.xyz, mean_0 - sigma_0, mean_0 + sigma_0), pq_0, vec3<f32>(max(max(gTemporal_0.control_0.x, rcp_0(_S41)), saturate(length(_S31) / 32.0f) * 0.5f)));
        var _S42 : vec3<f32> = DecodePQ_0(pq_2);
        var _S43 : f32 = min(_S41, 32.0f);
        pq_1 = pq_2;
        age_0 = _S43;
        result_2 = _S42;
    }
    else
    {
        pq_1 = pq_0;
        age_0 = 1.0f;
        result_2 = current_0;
    }
    gNextHistory_0[base_2] = vec4<f32>(pq_1, age_0);
    gNextHistory_0[_S25] = vec4<f32>(world_1, f32(id_1));
    gNextHistory_0[_S26] = vec4<f32>(normal_0, 0.0f);
    gOutput_0[base_2] = vec4<f32>(result_2 * vec3<f32>(gFrame_0.envParams_0.z), 1.0f);
    gOutput_0[_S25] = gCurrent_0[_S25];
    gOutput_0[_S26] = gCurrent_0[_S26];
    if((gFrame_0.temporal_0.w) != 0.0f)
    {
        if(valid_1)
        {
            debug_0 = vec3<f32>(saturate(vec2<f32>(0.5f) + _S31 / vec2<f32>(64.0f)), 0.5f);
        }
        else
        {
            debug_0 = vec3<f32>(1.0f, 0.0f, 1.0f);
        }
        gOutput_0[base_2] = vec4<f32>(debug_0, 1.0f);
    }
    return;
}

