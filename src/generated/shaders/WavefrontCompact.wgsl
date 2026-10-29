// Generated from shaders/Passes/WavefrontCompact.slang by scripts/build-shaders.mjs. Do not edit.
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

var<workgroup> gInputCount_0 : u32;

var<workgroup> gPrefix_0 : array<vec2<u32>, i32(64)>;

var<workgroup> gOffsets_0 : vec2<u32>;

fn CompactShadowAlphaImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var lane_0 : u32 = local_0.x;
    var header_2 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S15 : bool = lane_0 == u32(0);
    if(_S15)
    {
        gInputCount_0 = gWavefront_0.pathCount_0;
    }
    workgroupBarrier();
    var _S16 : u32 = header_2 + u32(12);
    var queue_0 : u32 = _S16 + gWavefront_0.capacity_0 * u32(84);
    var stride_0 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var _S17 : u32 = tid_0.x;
    var flag_0 : u32;
    var index_0 : u32;
    if((_S17 < gInputCount_0))
    {
        var _S18 : u32 = atomicLoad(&(gWork_0[_S16 + _S17 * u32(4) + u32(44) * gWavefront_0.capacity_0 + u32(3)]));
        flag_0 = select(u32(0), u32(1), _S18 != u32(0));
        index_0 = _S17;
    }
    else
    {
        flag_0 = u32(0);
        index_0 = u32(0);
    }
    gPrefix_0[lane_0] = vec2<u32>(flag_0, u32(0));
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
        var value_0 : u32;
        if((lane_0 >= offset_2))
        {
            value_0 = gPrefix_0[lane_0 - offset_2].x;
        }
        else
        {
            value_0 = u32(0);
        }
        workgroupBarrier();
        gPrefix_0[lane_0][i32(0)] = gPrefix_0[lane_0][i32(0)] + value_0;
        workgroupBarrier();
        offset_2 = offset_2 * u32(2);
    }
    var _S19 : bool;
    if(_S15)
    {
        _S19 = (gPrefix_0[u32(63)].x) != u32(0);
    }
    else
    {
        _S19 = false;
    }
    if(_S19)
    {
        var _S20 : u32 = atomicAdd(&(gWork_0[header_2 + u32(2)]), gPrefix_0[u32(63)].x);
        gOffsets_0[i32(0)] = _S20;
        var _S21 : u32 = atomicMax(&(gWork_0[header_2 + u32(8)]), (gOffsets_0.x + gPrefix_0[u32(63)].x + u32(63)) / u32(64));
    }
    workgroupBarrier();
    if(flag_0 != u32(0))
    {
        atomicStore(&(gWork_0[queue_0 + stride_0 + gOffsets_0.x + gPrefix_0[lane_0].x - u32(1)]), index_0);
    }
    return;
}

fn CompactShadowAlphaImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var lane_1 : u32 = local_1.x;
    var header_3 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S22 : bool = lane_1 == u32(0);
    if(_S22)
    {
        var _S23 : u32 = atomicLoad(&(gWork_0[header_3 + u32(1)]));
        gInputCount_0 = _S23;
    }
    workgroupBarrier();
    var _S24 : u32 = header_3 + u32(12);
    var queue_1 : u32 = _S24 + gWavefront_0.capacity_0 * u32(84);
    var stride_1 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var _S25 : u32 = tid_1.x;
    var flag_1 : u32;
    var index_1 : u32;
    if((_S25 < gInputCount_0))
    {
        var _S26 : u32 = atomicLoad(&(gWork_0[queue_1 + u32(2) * stride_1 + _S25]));
        var _S27 : u32 = atomicLoad(&(gWork_0[_S24 + _S26 * u32(4) + u32(44) * gWavefront_0.capacity_0 + u32(3)]));
        flag_1 = select(u32(0), u32(1), _S27 != u32(0));
        index_1 = _S26;
    }
    else
    {
        flag_1 = u32(0);
        index_1 = u32(0);
    }
    gPrefix_0[lane_1] = vec2<u32>(flag_1, u32(0));
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
        var value_1 : u32;
        if((lane_1 >= offset_3))
        {
            value_1 = gPrefix_0[lane_1 - offset_3].x;
        }
        else
        {
            value_1 = u32(0);
        }
        workgroupBarrier();
        gPrefix_0[lane_1][i32(0)] = gPrefix_0[lane_1][i32(0)] + value_1;
        workgroupBarrier();
        offset_3 = offset_3 * u32(2);
    }
    var _S28 : bool;
    if(_S22)
    {
        _S28 = (gPrefix_0[u32(63)].x) != u32(0);
    }
    else
    {
        _S28 = false;
    }
    if(_S28)
    {
        var _S29 : u32 = atomicAdd(&(gWork_0[header_3 + u32(2)]), gPrefix_0[u32(63)].x);
        gOffsets_0[i32(0)] = _S29;
        var _S30 : u32 = atomicMax(&(gWork_0[header_3 + u32(8)]), (gOffsets_0.x + gPrefix_0[u32(63)].x + u32(63)) / u32(64));
    }
    workgroupBarrier();
    if(flag_1 != u32(0))
    {
        atomicStore(&(gWork_0[queue_1 + stride_1 + gOffsets_0.x + gPrefix_0[lane_1].x - u32(1)]), index_1);
    }
    return;
}

fn CompactImpl_0( tid_2 : vec3<u32>,  local_2 : vec3<u32>)
{
    var lane_2 : u32 = local_2.x;
    var header_4 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S31 : bool = lane_2 == u32(0);
    if(_S31)
    {
        var _S32 : u32 = atomicLoad(&(gWork_0[header_4 + u32(2)]));
        gInputCount_0 = _S32;
    }
    workgroupBarrier();
    var _S33 : u32 = header_4 + u32(12);
    var queue_2 : u32 = _S33 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_0 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var inputQueue_0 : u32 = queue_2 + queueStride_0;
    var _S34 : vec2<u32> = vec2<u32>(u32(0));
    var flags_0 : vec2<u32> = _S34;
    var _S35 : u32 = tid_2.x;
    var index_2 : u32;
    if((_S35 < gInputCount_0))
    {
        var _S36 : u32 = atomicLoad(&(gWork_0[inputQueue_0 + _S35]));
        var base_0 : u32 = _S33 + _S36 * u32(4);
        var _S37 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        flags_0[i32(0)] = select(u32(0), u32(1), _S37 != u32(0));
        var _S38 : u32 = atomicLoad(&(gWork_0[base_0 + u32(44) * gWavefront_0.capacity_0 + u32(2)]));
        flags_0[i32(1)] = select(u32(0), u32(1), _S38 != u32(0));
        index_2 = _S36;
    }
    else
    {
        index_2 = u32(0);
    }
    gPrefix_0[lane_2] = flags_0;
    workgroupBarrier();
    var offset_4 : u32 = u32(1);
    loop
    {
        if((offset_4 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_2 : vec2<u32>;
        if((lane_2 >= offset_4))
        {
            value_2 = gPrefix_0[lane_2 - offset_4];
        }
        else
        {
            value_2 = _S34;
        }
        workgroupBarrier();
        gPrefix_0[lane_2] = gPrefix_0[lane_2] + value_2;
        workgroupBarrier();
        offset_4 = offset_4 * u32(2);
    }
    if(_S31)
    {
        var _S39 : vec2<u32> = ReserveQueues_0(header_4, gPrefix_0[u32(63)]);
        gOffsets_0 = _S39;
    }
    workgroupBarrier();
    var prefix_0 : vec2<u32> = gPrefix_0[lane_2] - flags_0 + gOffsets_0;
    if((flags_0.x) != u32(0))
    {
        atomicStore(&(gWork_0[queue_2 + prefix_0.x]), index_2);
    }
    if((flags_0.y) != u32(0))
    {
        atomicStore(&(gWork_0[queue_2 + u32(2) * queueStride_0 + prefix_0.y]), index_2);
    }
    return;
}

fn CompactImpl_1( tid_3 : vec3<u32>,  local_3 : vec3<u32>)
{
    var lane_3 : u32 = local_3.x;
    var header_5 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S40 : bool = lane_3 == u32(0);
    if(_S40)
    {
        var _S41 : u32 = atomicLoad(&(gWork_0[header_5]));
        gInputCount_0 = _S41;
    }
    workgroupBarrier();
    var _S42 : u32 = header_5 + u32(12);
    var queue_3 : u32 = _S42 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_1 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var outputQueue_0 : u32 = queue_3 + queueStride_1;
    var _S43 : vec2<u32> = vec2<u32>(u32(0));
    var flags_1 : vec2<u32> = _S43;
    var _S44 : u32 = tid_3.x;
    var index_3 : u32;
    if((_S44 < gInputCount_0))
    {
        var _S45 : u32 = atomicLoad(&(gWork_0[queue_3 + _S44]));
        var _S46 : u32 = atomicLoad(&(gWork_0[_S42 + _S45 * u32(4) + u32(3)]));
        flags_1[i32(0)] = select(u32(0), u32(1), _S46 != u32(0));
        index_3 = _S45;
    }
    else
    {
        index_3 = u32(0);
    }
    gPrefix_0[lane_3] = flags_1;
    workgroupBarrier();
    var offset_5 : u32 = u32(1);
    loop
    {
        if((offset_5 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_3 : vec2<u32>;
        if((lane_3 >= offset_5))
        {
            value_3 = gPrefix_0[lane_3 - offset_5];
        }
        else
        {
            value_3 = _S43;
        }
        workgroupBarrier();
        gPrefix_0[lane_3] = gPrefix_0[lane_3] + value_3;
        workgroupBarrier();
        offset_5 = offset_5 * u32(2);
    }
    if(_S40)
    {
        var _S47 : vec2<u32> = ReserveQueues_1(header_5, gPrefix_0[u32(63)]);
        gOffsets_0 = _S47;
    }
    workgroupBarrier();
    var prefix_1 : vec2<u32> = gPrefix_0[lane_3] - flags_1 + gOffsets_0;
    if((flags_1.x) != u32(0))
    {
        atomicStore(&(gWork_0[outputQueue_0 + prefix_1.x]), index_3);
    }
    if((flags_1.y) != u32(0))
    {
        atomicStore(&(gWork_0[queue_3 + u32(2) * queueStride_1 + prefix_1.y]), index_3);
    }
    return;
}

@compute
@workgroup_size(1, 1, 1)
fn PrimaryFallbackArguments(@builtin(global_invocation_id) tid_4 : vec3<u32>)
{
    var header_6 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var count_2 : u32 = atomicLoad(&(gWork_0[header_6 + u32(1)]));
    var sparse_0 : bool = (count_2 <= u32(256));
    var _S48 : u32;
    if(sparse_0)
    {
        _S48 = u32(0);
    }
    else
    {
        _S48 = (count_2 + u32(63)) / u32(64);
    }
    atomicStore(&(gWork_0[header_6 + u32(8)]), _S48);
    var base_1 : u32 = gFrame_0.primaryVisibility_0.x;
    if(sparse_0)
    {
        _S48 = count_2;
    }
    else
    {
        _S48 = u32(0);
    }
    atomicStore(&(gWork_0[base_1 + u32(4)]), _S48);
    atomicStore(&(gWork_0[base_1 + u32(5)]), u32(1));
    atomicStore(&(gWork_0[base_1 + u32(6)]), u32(1));
    atomicStore(&(gWork_0[base_1 + u32(7)]), u32(0));
    if(sparse_0)
    {
        var _S49 : u32 = atomicAdd(&(gWork_0[base_1 + u32(3)]), count_2);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactPrimaryFallback(@builtin(global_invocation_id) tid_5 : vec3<u32>, @builtin(local_invocation_id) local_4 : vec3<u32>)
{
    var lane_4 : u32 = local_4.x;
    var header_7 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S50 : u32 = tid_5.x;
    var reason_0 : u32;
    if((_S50 < (gWavefront_0.pathCount_0)))
    {
        var _S51 : u32 = atomicLoad(&(gWork_0[header_7 + u32(12) + _S50 * u32(4) + u32(36) * gWavefront_0.capacity_0 + u32(1)]));
        reason_0 = _S51;
    }
    else
    {
        reason_0 = u32(0);
    }
    var _S52 : bool = reason_0 != u32(0);
    var offset_6 : u32;
    if(_S52)
    {
        offset_6 = u32(1);
    }
    else
    {
        offset_6 = u32(0);
    }
    if(reason_0 == u32(1))
    {
        reason_0 = u32(1);
    }
    else
    {
        reason_0 = u32(0);
    }
    gPrefix_0[lane_4] = vec2<u32>(offset_6, reason_0);
    workgroupBarrier();
    offset_6 = u32(1);
    loop
    {
        if((offset_6 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_4 : vec2<u32>;
        if((lane_4 >= offset_6))
        {
            value_4 = gPrefix_0[lane_4 - offset_6];
        }
        else
        {
            value_4 = vec2<u32>(u32(0));
        }
        workgroupBarrier();
        gPrefix_0[lane_4] = gPrefix_0[lane_4] + value_4;
        workgroupBarrier();
        offset_6 = offset_6 * u32(2);
    }
    var _S53 : bool;
    if(lane_4 == u32(0))
    {
        _S53 = ((gPrefix_0[u32(63)].x) > u32(0));
    }
    else
    {
        _S53 = false;
    }
    if(_S53)
    {
        var _S54 : u32 = atomicAdd(&(gWork_0[header_7 + u32(1)]), gPrefix_0[u32(63)].x);
        gOffsets_0[i32(0)] = _S54;
        var _S55 : u32 = atomicMax(&(gWork_0[header_7 + u32(8)]), (gOffsets_0.x + gPrefix_0[u32(63)].x + u32(63)) / u32(64));
        var _S56 : u32 = atomicAdd(&(gWork_0[gFrame_0.primaryVisibility_0.x + u32(8)]), gPrefix_0[u32(63)].x);
        var _S57 : u32 = atomicAdd(&(gWork_0[gFrame_0.primaryVisibility_0.x + u32(9)]), gPrefix_0[u32(63)].y);
    }
    workgroupBarrier();
    if(_S52)
    {
        atomicStore(&(gWork_0[header_7 + u32(12) + gWavefront_0.capacity_0 * u32(84) + (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4) + gOffsets_0.x + gPrefix_0[lane_4].x - u32(1)]), _S50);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactIntersect(@builtin(global_invocation_id) tid_6 : vec3<u32>, @builtin(local_invocation_id) local_5 : vec3<u32>)
{
    CompactImpl_1(tid_6, local_5);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactShade(@builtin(global_invocation_id) tid_7 : vec3<u32>, @builtin(local_invocation_id) local_6 : vec3<u32>)
{
    CompactImpl_0(tid_7, local_6);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactShadowAlpha(@builtin(global_invocation_id) tid_8 : vec3<u32>, @builtin(local_invocation_id) local_7 : vec3<u32>)
{
    CompactShadowAlphaImpl_1(tid_8, local_7);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CompactShadowAlphaDirect(@builtin(global_invocation_id) tid_9 : vec3<u32>, @builtin(local_invocation_id) local_8 : vec3<u32>)
{
    CompactShadowAlphaImpl_0(tid_9, local_8);
    return;
}

