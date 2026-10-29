// Generated from shaders/Passes/WavefrontCompact.slang by scripts/build-shaders.mjs. Do not edit.
enable subgroups;
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

var<workgroup> gInputCount_0 : u32;

var<workgroup> gGroupCount_0 : array<atomic<u32>, i32(2)>;

var<workgroup> gOffsets_0 : vec2<u32>;

fn CompactImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var header_2 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S15 : bool = (local_0.x) == u32(0);
    if(_S15)
    {
        var _S16 : u32 = atomicLoad(&(gWork_0[header_2 + u32(2)]));
        gInputCount_0 = _S16;
        atomicStore(&(gGroupCount_0[i32(0)]), u32(0));
        atomicStore(&(gGroupCount_0[i32(1)]), u32(0));
    }
    workgroupBarrier();
    var _S17 : u32 = header_2 + u32(12);
    var queue_0 : u32 = _S17 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_0 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var inputQueue_0 : u32 = queue_0 + queueStride_0;
    var _S18 : vec2<u32> = vec2<u32>(u32(0));
    var flags_0 : vec2<u32> = _S18;
    var _S19 : u32 = tid_0.x;
    var index_0 : u32;
    if((_S19 < gInputCount_0))
    {
        var _S20 : u32 = atomicLoad(&(gWork_0[inputQueue_0 + _S19]));
        var base_0 : u32 = _S17 + _S20 * u32(4);
        var _S21 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        flags_0[i32(0)] = select(u32(0), u32(1), _S21 != u32(0));
        var _S22 : u32 = atomicLoad(&(gWork_0[base_0 + u32(44) * gWavefront_0.capacity_0 + u32(2)]));
        flags_0[i32(1)] = select(u32(0), u32(1), _S22 != u32(0));
        index_0 = _S20;
    }
    else
    {
        index_0 = u32(0);
    }
    var prefix_0 : vec2<u32> = subgroupExclusiveAdd(flags_0);
    var total_0 : vec2<u32> = subgroupAdd(flags_0);
    var waveOffset_0 : vec2<u32> = _S18;
    var _S23 : bool = subgroupElect();
    if(_S23)
    {
        var _S24 : u32 = atomicAdd(&(gGroupCount_0[i32(0)]), total_0.x);
        waveOffset_0[i32(0)] = _S24;
        var _S25 : u32 = atomicAdd(&(gGroupCount_0[i32(1)]), total_0.y);
        waveOffset_0[i32(1)] = _S25;
    }
    var _S26 : vec2<u32> = subgroupBroadcastFirst(waveOffset_0);
    waveOffset_0 = _S26;
    workgroupBarrier();
    if(_S15)
    {
        var _S27 : u32 = atomicLoad(&(gGroupCount_0[i32(0)]));
        var _S28 : u32 = atomicLoad(&(gGroupCount_0[i32(1)]));
        var _S29 : vec2<u32> = ReserveQueues_0(header_2, vec2<u32>(_S27, _S28));
        gOffsets_0 = _S29;
    }
    workgroupBarrier();
    var prefix_1 : vec2<u32> = prefix_0 + (gOffsets_0 + waveOffset_0);
    if((flags_0.x) != u32(0))
    {
        atomicStore(&(gWork_0[queue_0 + prefix_1.x]), index_0);
    }
    if((flags_0.y) != u32(0))
    {
        atomicStore(&(gWork_0[queue_0 + u32(2) * queueStride_0 + prefix_1.y]), index_0);
    }
    return;
}

fn CompactImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var header_3 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S30 : bool = (local_1.x) == u32(0);
    if(_S30)
    {
        var _S31 : u32 = atomicLoad(&(gWork_0[header_3]));
        gInputCount_0 = _S31;
        atomicStore(&(gGroupCount_0[i32(0)]), u32(0));
        atomicStore(&(gGroupCount_0[i32(1)]), u32(0));
    }
    workgroupBarrier();
    var _S32 : u32 = header_3 + u32(12);
    var queue_1 : u32 = _S32 + gWavefront_0.capacity_0 * u32(84);
    var queueStride_1 : u32 = (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var outputQueue_0 : u32 = queue_1 + queueStride_1;
    var _S33 : vec2<u32> = vec2<u32>(u32(0));
    var flags_1 : vec2<u32> = _S33;
    var _S34 : u32 = tid_1.x;
    var index_1 : u32;
    if((_S34 < gInputCount_0))
    {
        var _S35 : u32 = atomicLoad(&(gWork_0[queue_1 + _S34]));
        var _S36 : u32 = atomicLoad(&(gWork_0[_S32 + _S35 * u32(4) + u32(3)]));
        flags_1[i32(0)] = select(u32(0), u32(1), _S36 != u32(0));
        index_1 = _S35;
    }
    else
    {
        index_1 = u32(0);
    }
    var prefix_2 : vec2<u32> = subgroupExclusiveAdd(flags_1);
    var total_1 : vec2<u32> = subgroupAdd(flags_1);
    var waveOffset_1 : vec2<u32> = _S33;
    var _S37 : bool = subgroupElect();
    if(_S37)
    {
        var _S38 : u32 = atomicAdd(&(gGroupCount_0[i32(0)]), total_1.x);
        waveOffset_1[i32(0)] = _S38;
        var _S39 : u32 = atomicAdd(&(gGroupCount_0[i32(1)]), total_1.y);
        waveOffset_1[i32(1)] = _S39;
    }
    var _S40 : vec2<u32> = subgroupBroadcastFirst(waveOffset_1);
    waveOffset_1 = _S40;
    workgroupBarrier();
    if(_S30)
    {
        var _S41 : u32 = atomicLoad(&(gGroupCount_0[i32(0)]));
        var _S42 : u32 = atomicLoad(&(gGroupCount_0[i32(1)]));
        var _S43 : vec2<u32> = ReserveQueues_1(header_3, vec2<u32>(_S41, _S42));
        gOffsets_0 = _S43;
    }
    workgroupBarrier();
    var prefix_3 : vec2<u32> = prefix_2 + (gOffsets_0 + waveOffset_1);
    if((flags_1.x) != u32(0))
    {
        atomicStore(&(gWork_0[outputQueue_0 + prefix_3.x]), index_1);
    }
    if((flags_1.y) != u32(0))
    {
        atomicStore(&(gWork_0[queue_1 + u32(2) * queueStride_1 + prefix_3.y]), index_1);
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

