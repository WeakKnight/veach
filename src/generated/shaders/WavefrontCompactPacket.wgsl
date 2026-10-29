// Generated from shaders/Passes/WavefrontCompact.slang by scripts/build-shaders.mjs. Do not edit.
@binding(0) @group(1) var<storage, read_write> gWork_0 : array<atomic<u32>>;

struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
    @align(16) tailThreshold_0 : u32,
    @align(4) packetStages_0 : u32,
    @align(8) sortGroupSize_0 : u32,
};

@binding(2) @group(1) var<uniform> gWavefront_0 : WavefrontUniforms_std140_0;
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
fn ReserveQueues_0( header_0 : u32,  count_0 : vec2<u32>) -> vec2<u32>
{
    var offset_0 : vec2<u32> = vec2<u32>(u32(0));
    var _S1 : u32 = count_0.x;
    if((_S1 > u32(0)))
    {
        var _S2 : u32 = atomicAdd(&(gWork_0[header_0]), _S1);
        offset_0[i32(0)] = _S2;
        var nextCount_0 : u32 = offset_0.x + _S1;
        if((gWavefront_0.sortGroupSize_0) == u32(256))
        {
            var _S3 : u32 = atomicMax(&(gWork_0[header_0 + u32(3)]), (nextCount_0 + u32(255)) / u32(256));
        }
        var _S4 : u32 = atomicMax(&(gWork_0[header_0 + u32(4)]), (nextCount_0 + u32(63)) / u32(64));
    }
    var _S5 : u32 = count_0.y;
    if((_S5 > u32(0)))
    {
        var _S6 : u32 = atomicAdd(&(gWork_0[header_0 + u32(1)]), _S5);
        offset_0[i32(1)] = _S6;
        var _S7 : u32 = atomicMax(&(gWork_0[header_0 + u32(8)]), (offset_0.y + _S5 + u32(63)) / u32(64));
    }
    return offset_0;
}

fn ReserveQueues_1( header_1 : u32,  count_1 : vec2<u32>) -> vec2<u32>
{
    var offset_1 : vec2<u32> = vec2<u32>(u32(0));
    var _S8 : u32 = count_1.x;
    if((_S8 > u32(0)))
    {
        var _S9 : u32 = atomicAdd(&(gWork_0[header_1 + u32(2)]), _S8);
        offset_1[i32(0)] = _S9;
        var nextCount_1 : u32 = offset_1.x + _S8;
        if((gWavefront_0.sortGroupSize_0) == u32(256))
        {
            var _S10 : u32 = atomicMax(&(gWork_0[header_1 + u32(3)]), (nextCount_1 + u32(255)) / u32(256));
        }
        var _S11 : u32 = atomicMax(&(gWork_0[header_1 + u32(4)]), (nextCount_1 + u32(63)) / u32(64));
    }
    var _S12 : u32 = count_1.y;
    if((_S12 > u32(0)))
    {
        var _S13 : u32 = atomicAdd(&(gWork_0[header_1 + u32(1)]), _S12);
        offset_1[i32(1)] = _S13;
        var _S14 : u32 = atomicMax(&(gWork_0[header_1 + u32(8)]), (offset_1.y + _S12 + u32(63)) / u32(64));
    }
    return offset_1;
}

var<workgroup> gPrefix_0 : array<vec2<u32>, i32(64)>;

var<workgroup> gOffsets_0 : vec2<u32>;

fn CompactImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var lane_0 : u32 = local_0.x;
    var packetMain_0 : bool = (((gWavefront_0.packetStages_0) & (u32(1)))) != u32(0);
    var packetShadow_0 : bool = (((gWavefront_0.packetStages_0) & (u32(4)))) != u32(0);
    var header_2 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S15 : u32 = header_2 + u32(12);
    var queue_0 : u32 = _S15 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_0 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var _S16 : vec2<u32> = vec2<u32>(u32(0));
    var flags_0 : vec2<u32> = _S16;
    var _S17 : u32 = tid_0.x;
    var _S18 : bool = (_S17 < (gWavefront_0.pathCount_0));
    var index_0 : u32;
    if(_S18)
    {
        var base_0 : u32 = _S15 + _S17 * u32(4);
        var _S19 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        flags_0[i32(0)] = select(u32(0), u32(1), _S19 != u32(0));
        var _S20 : u32 = atomicLoad(&(gWork_0[base_0 + u32(44) * gWavefront_0.capacity_0 + u32(2)]));
        flags_0[i32(1)] = select(u32(0), u32(1), _S20 != u32(0));
        index_0 = _S17;
    }
    else
    {
        index_0 = u32(0);
    }
    gPrefix_0[lane_0] = flags_0;
    workgroupBarrier();
    var offset_2 : u32 = u32(1);
    loop
    {
        if((offset_2 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_0 : vec2<u32>;
        if((lane_0 >= offset_2))
        {
            value_0 = gPrefix_0[lane_0 - offset_2];
        }
        else
        {
            value_0 = _S16;
        }
        workgroupBarrier();
        gPrefix_0[lane_0] = gPrefix_0[lane_0] + value_0;
        workgroupBarrier();
        offset_2 = offset_2 * u32(2);
    }
    if(lane_0 == u32(0))
    {
        var _S21 : u32 = min(u32(64), gWavefront_0.pathCount_0 - (_S17 - lane_0));
        if(packetMain_0)
        {
            if(((gPrefix_0[u32(63)].x) > u32(0)))
            {
                offset_2 = _S21;
            }
            else
            {
                offset_2 = u32(0);
            }
        }
        else
        {
            offset_2 = gPrefix_0[u32(63)].x;
        }
        var _S22 : u32;
        if(packetShadow_0)
        {
            if(((gPrefix_0[u32(63)].y) > u32(0)))
            {
                _S22 = _S21;
            }
            else
            {
                _S22 = u32(0);
            }
        }
        else
        {
            _S22 = gPrefix_0[u32(63)].y;
        }
        var _S23 : vec2<u32> = ReserveQueues_0(header_2, vec2<u32>(offset_2, _S22));
        gOffsets_0 = _S23;
    }
    workgroupBarrier();
    var offsets_0 : vec2<u32> = gOffsets_0;
    var prefix_0 : vec2<u32> = gPrefix_0[lane_0] - flags_0;
    if(_S18)
    {
        var _S24 : bool;
        if(packetMain_0)
        {
            _S24 = ((gPrefix_0[u32(63)].x) > u32(0));
        }
        else
        {
            _S24 = (flags_0.x) != u32(0);
        }
        if(_S24)
        {
            var _S25 : u32 = queue_0 + offsets_0.x;
            if(packetMain_0)
            {
                offset_2 = lane_0;
            }
            else
            {
                offset_2 = prefix_0.x;
            }
            atomicStore(&(gWork_0[_S25 + offset_2]), index_0);
        }
        if(packetShadow_0)
        {
            _S24 = ((gPrefix_0[u32(63)].y) > u32(0));
        }
        else
        {
            _S24 = (flags_0.y) != u32(0);
        }
        if(_S24)
        {
            var _S26 : u32 = queue_0 + u32(2) * queueStride_0 + offsets_0.y;
            if(packetShadow_0)
            {
                offset_2 = lane_0;
            }
            else
            {
                offset_2 = prefix_0.y;
            }
            atomicStore(&(gWork_0[_S26 + offset_2]), index_0);
        }
    }
    return;
}

fn CompactImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var lane_1 : u32 = local_1.x;
    var packetMain_1 : bool = (((gWavefront_0.packetStages_0) & (u32(2)))) != u32(0);
    var packetShadow_1 : bool = (((gWavefront_0.packetStages_0) & (u32(4)))) != u32(0);
    var header_3 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S27 : u32 = header_3 + u32(12);
    var queue_1 : u32 = _S27 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_1 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var outputQueue_0 : u32 = queue_1 + queueStride_1;
    var _S28 : vec2<u32> = vec2<u32>(u32(0));
    var flags_1 : vec2<u32> = _S28;
    var _S29 : u32 = tid_1.x;
    var _S30 : bool = (_S29 < (gWavefront_0.pathCount_0));
    var index_1 : u32;
    if(_S30)
    {
        var _S31 : u32 = atomicLoad(&(gWork_0[_S27 + _S29 * u32(4) + u32(3)]));
        flags_1[i32(0)] = select(u32(0), u32(1), _S31 != u32(0));
        index_1 = _S29;
    }
    else
    {
        index_1 = u32(0);
    }
    gPrefix_0[lane_1] = flags_1;
    workgroupBarrier();
    var offset_3 : u32 = u32(1);
    loop
    {
        if((offset_3 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_1 : vec2<u32>;
        if((lane_1 >= offset_3))
        {
            value_1 = gPrefix_0[lane_1 - offset_3];
        }
        else
        {
            value_1 = _S28;
        }
        workgroupBarrier();
        gPrefix_0[lane_1] = gPrefix_0[lane_1] + value_1;
        workgroupBarrier();
        offset_3 = offset_3 * u32(2);
    }
    if(lane_1 == u32(0))
    {
        var _S32 : u32 = min(u32(64), gWavefront_0.pathCount_0 - (_S29 - lane_1));
        if(packetMain_1)
        {
            if(((gPrefix_0[u32(63)].x) > u32(0)))
            {
                offset_3 = _S32;
            }
            else
            {
                offset_3 = u32(0);
            }
        }
        else
        {
            offset_3 = gPrefix_0[u32(63)].x;
        }
        var _S33 : u32;
        if(packetShadow_1)
        {
            if(((gPrefix_0[u32(63)].y) > u32(0)))
            {
                _S33 = _S32;
            }
            else
            {
                _S33 = u32(0);
            }
        }
        else
        {
            _S33 = gPrefix_0[u32(63)].y;
        }
        var _S34 : vec2<u32> = ReserveQueues_1(header_3, vec2<u32>(offset_3, _S33));
        gOffsets_0 = _S34;
    }
    workgroupBarrier();
    var offsets_1 : vec2<u32> = gOffsets_0;
    var prefix_1 : vec2<u32> = gPrefix_0[lane_1] - flags_1;
    if(_S30)
    {
        var _S35 : bool;
        if(packetMain_1)
        {
            _S35 = ((gPrefix_0[u32(63)].x) > u32(0));
        }
        else
        {
            _S35 = (flags_1.x) != u32(0);
        }
        if(_S35)
        {
            var _S36 : u32 = outputQueue_0 + offsets_1.x;
            if(packetMain_1)
            {
                offset_3 = lane_1;
            }
            else
            {
                offset_3 = prefix_1.x;
            }
            atomicStore(&(gWork_0[_S36 + offset_3]), index_1);
        }
        if(packetShadow_1)
        {
            _S35 = ((gPrefix_0[u32(63)].y) > u32(0));
        }
        else
        {
            _S35 = (flags_1.y) != u32(0);
        }
        if(_S35)
        {
            var _S37 : u32 = queue_1 + u32(2) * queueStride_1 + offsets_1.y;
            if(packetShadow_1)
            {
                offset_3 = lane_1;
            }
            else
            {
                offset_3 = prefix_1.y;
            }
            atomicStore(&(gWork_0[_S37 + offset_3]), index_1);
        }
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactIntersect(@builtin(global_invocation_id) tid_2 : vec3<u32>, @builtin(local_invocation_id) local_2 : vec3<u32>)
{
    CompactImpl_1(tid_2, local_2);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactShade(@builtin(global_invocation_id) tid_3 : vec3<u32>, @builtin(local_invocation_id) local_3 : vec3<u32>)
{
    CompactImpl_0(tid_3, local_3);
    return;
}

