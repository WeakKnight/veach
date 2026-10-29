// Generated from shaders/Passes/WavefrontMaterialBuckets.slang by scripts/build-shaders.mjs. Do not edit.
struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
    @align(16) tailThreshold_0 : u32,
    @align(4) packetStages_0 : u32,
    @align(8) sortGroupSize_0 : u32,
    @align(4) materialCount_0 : u32,
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
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
@binding(0) @group(1) var<storage, read_write> gWork_0 : array<atomic<u32>>;

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

@binding(3) @group(0) var<storage, read> gInstances_0 : array<Instance_std430_0>;

var<workgroup> gMasks_0 : array<atomic<u32>, i32(512)>;

fn Header_0() -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
}

var<workgroup> gInputCount_0 : u32;

fn QueueA_0() -> u32
{
    return Header_0() + u32(12) + gWavefront_0.capacity_0 * u32(84);
}

fn QueueStride_0() -> u32
{
    return (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
}

fn Metadata_0() -> u32
{
    return QueueA_0() + u32(3) * QueueStride_0();
}

fn MaterialMetadata_0() -> u32
{
    return Metadata_0() + u32(24);
}

var<workgroup> gOffsets_0 : array<u32, i32(256)>;

fn Partition_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var lane_0 : u32 = local_0.x;
    var groups_0 : u32 = gWavefront_0.materialCount_0;
    var i_0 : u32 = lane_0;
    loop
    {
        if((i_0 < (groups_0 * u32(2))))
        {
        }
        else
        {
            break;
        }
        atomicStore(&(gMasks_0[i_0]), u32(0));
        i_0 = i_0 + u32(64);
    }
    if(lane_0 == u32(0))
    {
        var _S1 : u32 = atomicLoad(&(gWork_0[Header_0() + u32(2)]));
        gInputCount_0 = _S1;
    }
    workgroupBarrier();
    var _S2 : u32 = tid_0.x;
    var material_0 : u32;
    var index_0 : u32;
    if((_S2 < gInputCount_0))
    {
        var index_1 : u32 = atomicLoad(&(gWork_0[QueueA_0() + QueueStride_0() + _S2]));
        var base_0 : u32 = Header_0() + u32(12) + index_1 * u32(4);
        var _S3 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        if(_S3 != u32(0))
        {
            var instance_0 : u32 = atomicLoad(&(gWork_0[base_0 + u32(32) * gWavefront_0.capacity_0 + u32(3)]));
            var material_1 : u32 = gInstances_0[instance_0].materialIndex_0;
            var _S4 : u32 = atomicOr(&(gMasks_0[gInstances_0[instance_0].materialIndex_0 * u32(2) + lane_0 / u32(32)]), (u32(1) << (((lane_0 & (u32(31)))))));
            material_0 = material_1;
        }
        else
        {
            material_0 = groups_0;
        }
        index_0 = index_1;
    }
    else
    {
        material_0 = groups_0;
        index_0 = u32(0);
    }
    workgroupBarrier();
    var group_0 : u32 = lane_0;
    loop
    {
        if((group_0 < groups_0))
        {
        }
        else
        {
            break;
        }
        var _S5 : u32 = group_0 * u32(2);
        var _S6 : u32 = atomicLoad(&(gMasks_0[_S5]));
        var _S7 : u32 = countOneBits(_S6);
        var _S8 : u32 = atomicLoad(&(gMasks_0[_S5 + u32(1)]));
        var count_0 : u32 = _S7 + countOneBits(_S8);
        var meta_0 : u32 = MaterialMetadata_0() + group_0 * u32(4);
        if(count_0 != u32(0))
        {
            var _S9 : u32 = atomicLoad(&(gWork_0[meta_0 + u32(1)]));
            var _S10 : u32 = atomicAdd(&(gWork_0[meta_0 + u32(2)]), count_0);
            i_0 = _S9 + _S10;
        }
        else
        {
            i_0 = u32(0);
        }
        gOffsets_0[group_0] = i_0;
        group_0 = group_0 + u32(64);
    }
    workgroupBarrier();
    if((material_0 < groups_0))
    {
        var lowerMask_0 : u32 = ((u32(1) << (((lane_0 & (u32(31))))))) - u32(1);
        var _S11 : u32 = material_0 * u32(2);
        var _S12 : u32 = atomicLoad(&(gMasks_0[_S11 + lane_0 / u32(32)]));
        var rank_0 : u32 = countOneBits((_S12 & (lowerMask_0)));
        var rank_1 : u32;
        if((lane_0 >= u32(32)))
        {
            var _S13 : u32 = atomicLoad(&(gMasks_0[_S11]));
            rank_1 = rank_0 + countOneBits(_S13);
        }
        else
        {
            rank_1 = rank_0;
        }
        atomicStore(&(gWork_0[QueueA_0() + u32(2) * QueueStride_0() + gOffsets_0[material_0] + rank_1]), index_0);
    }
    return;
}

fn Partition_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var lane_1 : u32 = local_1.x;
    var groups_1 : u32 = gWavefront_0.materialCount_0;
    var i_1 : u32 = lane_1;
    loop
    {
        if((i_1 < (groups_1 * u32(2))))
        {
        }
        else
        {
            break;
        }
        atomicStore(&(gMasks_0[i_1]), u32(0));
        i_1 = i_1 + u32(64);
    }
    if(lane_1 == u32(0))
    {
        var _S14 : u32 = atomicLoad(&(gWork_0[Header_0() + u32(2)]));
        gInputCount_0 = _S14;
    }
    workgroupBarrier();
    var _S15 : u32 = tid_1.x;
    if((_S15 < gInputCount_0))
    {
        var index_2 : u32 = atomicLoad(&(gWork_0[QueueA_0() + QueueStride_0() + _S15]));
        var base_1 : u32 = Header_0() + u32(12) + index_2 * u32(4);
        var _S16 : u32 = atomicLoad(&(gWork_0[base_1 + u32(3)]));
        if(_S16 != u32(0))
        {
            var instance_1 : u32 = atomicLoad(&(gWork_0[base_1 + u32(32) * gWavefront_0.capacity_0 + u32(3)]));
            var _S17 : u32 = atomicOr(&(gMasks_0[gInstances_0[instance_1].materialIndex_0 * u32(2) + lane_1 / u32(32)]), (u32(1) << (((lane_1 & (u32(31)))))));
        }
    }
    workgroupBarrier();
    var group_1 : u32 = lane_1;
    loop
    {
        if((group_1 < groups_1))
        {
        }
        else
        {
            break;
        }
        var _S18 : u32 = group_1 * u32(2);
        var _S19 : u32 = atomicLoad(&(gMasks_0[_S18]));
        var _S20 : u32 = countOneBits(_S19);
        var _S21 : u32 = atomicLoad(&(gMasks_0[_S18 + u32(1)]));
        var count_1 : u32 = _S20 + countOneBits(_S21);
        var meta_1 : u32 = MaterialMetadata_0() + group_1 * u32(4);
        if(count_1 != u32(0))
        {
            var _S22 : u32 = atomicAdd(&(gWork_0[meta_1]), count_1);
        }
        group_1 = group_1 + u32(64);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CountMaterials(@builtin(global_invocation_id) tid_2 : vec3<u32>, @builtin(local_invocation_id) local_2 : vec3<u32>)
{
    Partition_1(tid_2, local_2);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn PrefixMaterials(@builtin(local_invocation_id) local_3 : vec3<u32>)
{
    var i_2 : u32;
    var offset_0 : u32;
    var lane_2 : u32 = local_3.x;
    var _S23 : u32 = MaterialMetadata_0();
    var group_2 : u32 = lane_2;
    loop
    {
        if((group_2 < (gWavefront_0.materialCount_0)))
        {
        }
        else
        {
            break;
        }
        i_2 = u32(0);
        offset_0 = u32(0);
        loop
        {
            if((i_2 < group_2))
            {
            }
            else
            {
                break;
            }
            var _S24 : u32 = atomicLoad(&(gWork_0[_S23 + i_2 * u32(4)]));
            var offset_1 : u32 = offset_0 + _S24;
            i_2 = i_2 + u32(1);
            offset_0 = offset_1;
        }
        var _S25 : u32 = _S23 + group_2 * u32(4);
        atomicStore(&(gWork_0[_S25 + u32(1)]), offset_0);
        atomicStore(&(gWork_0[_S25 + u32(2)]), u32(0));
        group_2 = group_2 + u32(64);
    }
    if((lane_2 < u32(6)))
    {
        i_2 = u32(0);
        offset_0 = u32(0);
        loop
        {
            if((i_2 < (gWavefront_0.materialCount_0)))
            {
            }
            else
            {
                break;
            }
            var _S26 : u32 = atomicLoad(&(gWork_0[_S23 + i_2 * u32(4)]));
            var total_0 : u32 = offset_0 + _S26;
            i_2 = i_2 + u32(1);
            offset_0 = total_0;
        }
        var _S27 : u32 = Metadata_0() + lane_2 * u32(4);
        atomicStore(&(gWork_0[_S27]), offset_0);
        atomicStore(&(gWork_0[_S27 + u32(1)]), u32(0));
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ScatterMaterials(@builtin(global_invocation_id) tid_3 : vec3<u32>, @builtin(local_invocation_id) local_4 : vec3<u32>)
{
    Partition_0(tid_3, local_4);
    return;
}

