// Generated from shaders/Passes/WavefrontCompact.slang by scripts/build-shaders.mjs. Do not edit.
@binding(0) @group(1) var<storage, read_write> gWork_0 : array<atomic<u32>>;

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
struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
    @align(16) tailThreshold_0 : u32,
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
        var _S3 : u32 = atomicMax(&(gWork_0[header_0 + u32(4)]), (offset_0.x + _S1 + u32(63)) / u32(64));
    }
    var _S4 : u32 = count_0.y;
    if((_S4 > u32(0)))
    {
        var _S5 : u32 = atomicAdd(&(gWork_0[header_0 + u32(1)]), _S4);
        offset_0[i32(1)] = _S5;
        var _S6 : u32 = atomicMax(&(gWork_0[header_0 + u32(8)]), (offset_0.y + _S4 + u32(63)) / u32(64));
    }
    return offset_0;
}

fn ReserveQueues_1( header_1 : u32,  count_1 : vec2<u32>) -> vec2<u32>
{
    var offset_1 : vec2<u32> = vec2<u32>(u32(0));
    var _S7 : u32 = count_1.x;
    if((_S7 > u32(0)))
    {
        var _S8 : u32 = atomicAdd(&(gWork_0[header_1 + u32(2)]), _S7);
        offset_1[i32(0)] = _S8;
        var _S9 : u32 = atomicMax(&(gWork_0[header_1 + u32(4)]), (offset_1.x + _S7 + u32(63)) / u32(64));
    }
    var _S10 : u32 = count_1.y;
    if((_S10 > u32(0)))
    {
        var _S11 : u32 = atomicAdd(&(gWork_0[header_1 + u32(1)]), _S10);
        offset_1[i32(1)] = _S11;
        var _S12 : u32 = atomicMax(&(gWork_0[header_1 + u32(8)]), (offset_1.y + _S10 + u32(63)) / u32(64));
    }
    return offset_1;
}

var<workgroup> gPrefix_0 : array<vec2<u32>, i32(64)>;

var<workgroup> gOffsets_0 : vec2<u32>;

fn CompactImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var lane_0 : u32 = local_0.x;
    var header_2 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S13 : u32 = header_2 + u32(12);
    var queue_0 : u32 = _S13 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_0 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var _S14 : vec2<u32> = vec2<u32>(u32(0));
    var flags_0 : vec2<u32> = _S14;
    var _S15 : u32 = tid_0.x;
    var _S16 : bool = (_S15 < (gWavefront_0.pathCount_0));
    var index_0 : u32;
    if(_S16)
    {
        var base_0 : u32 = _S13 + _S15 * u32(4);
        var _S17 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        flags_0[i32(0)] = select(u32(0), u32(1), _S17 != u32(0));
        var _S18 : u32 = atomicLoad(&(gWork_0[base_0 + u32(44) * gWavefront_0.capacity_0 + u32(2)]));
        flags_0[i32(1)] = select(u32(0), u32(1), _S18 != u32(0));
        index_0 = _S15;
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
            value_0 = _S14;
        }
        workgroupBarrier();
        gPrefix_0[lane_0] = gPrefix_0[lane_0] + value_0;
        workgroupBarrier();
        offset_2 = offset_2 * u32(2);
    }
    if(lane_0 == u32(0))
    {
        var _S19 : u32 = min(u32(64), gWavefront_0.pathCount_0 - (_S15 - lane_0));
        if(((gPrefix_0[u32(63)].x) > u32(0)))
        {
            offset_2 = _S19;
        }
        else
        {
            offset_2 = u32(0);
        }
        var _S20 : u32;
        if(((gPrefix_0[u32(63)].y) > u32(0)))
        {
            _S20 = _S19;
        }
        else
        {
            _S20 = u32(0);
        }
        var _S21 : vec2<u32> = ReserveQueues_0(header_2, vec2<u32>(offset_2, _S20));
        gOffsets_0 = _S21;
    }
    workgroupBarrier();
    var offsets_0 : vec2<u32> = gOffsets_0;
    if(_S16)
    {
        if(((gPrefix_0[u32(63)].x) > u32(0)))
        {
            atomicStore(&(gWork_0[queue_0 + offsets_0.x + lane_0]), index_0);
        }
        if(((gPrefix_0[u32(63)].y) > u32(0)))
        {
            atomicStore(&(gWork_0[queue_0 + u32(2) * queueStride_0 + offsets_0.y + lane_0]), index_0);
        }
    }
    return;
}

fn CompactImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var lane_1 : u32 = local_1.x;
    var header_3 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S22 : u32 = header_3 + u32(12);
    var queue_1 : u32 = _S22 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_1 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var outputQueue_0 : u32 = queue_1 + queueStride_1;
    var _S23 : vec2<u32> = vec2<u32>(u32(0));
    var flags_1 : vec2<u32> = _S23;
    var _S24 : u32 = tid_1.x;
    var _S25 : bool = (_S24 < (gWavefront_0.pathCount_0));
    var index_1 : u32;
    if(_S25)
    {
        var _S26 : u32 = atomicLoad(&(gWork_0[_S22 + _S24 * u32(4) + u32(3)]));
        flags_1[i32(0)] = select(u32(0), u32(1), _S26 != u32(0));
        index_1 = _S24;
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
            value_1 = _S23;
        }
        workgroupBarrier();
        gPrefix_0[lane_1] = gPrefix_0[lane_1] + value_1;
        workgroupBarrier();
        offset_3 = offset_3 * u32(2);
    }
    if(lane_1 == u32(0))
    {
        var _S27 : u32 = min(u32(64), gWavefront_0.pathCount_0 - (_S24 - lane_1));
        if(((gPrefix_0[u32(63)].x) > u32(0)))
        {
            offset_3 = _S27;
        }
        else
        {
            offset_3 = u32(0);
        }
        var _S28 : u32;
        if(((gPrefix_0[u32(63)].y) > u32(0)))
        {
            _S28 = _S27;
        }
        else
        {
            _S28 = u32(0);
        }
        var _S29 : vec2<u32> = ReserveQueues_1(header_3, vec2<u32>(offset_3, _S28));
        gOffsets_0 = _S29;
    }
    workgroupBarrier();
    var offsets_1 : vec2<u32> = gOffsets_0;
    if(_S25)
    {
        if(((gPrefix_0[u32(63)].x) > u32(0)))
        {
            atomicStore(&(gWork_0[outputQueue_0 + offsets_1.x + lane_1]), index_1);
        }
        if(((gPrefix_0[u32(63)].y) > u32(0)))
        {
            atomicStore(&(gWork_0[queue_1 + u32(2) * queueStride_1 + offsets_1.y + lane_1]), index_1);
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

