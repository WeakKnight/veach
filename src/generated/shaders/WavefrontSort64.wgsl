// Generated from shaders/Passes/WavefrontSort.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(0) @group(1) var<storage, read_write> gWork_0 : array<atomic<u32>>;

struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
    @align(16) tailThreshold_0 : u32,
    @align(4) packetStages_0 : u32,
};

@binding(2) @group(1) var<uniform> gWavefront_0 : WavefrontUniforms_std140_0;
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

@binding(6) @group(0) var<storage, read> gMaterialData_0 : array<vec4<u32>>;

var<workgroup> gCount_0 : u32;

var<workgroup> gSort_0 : array<vec2<u32>, i32(64)>;

fn Less_0( a_0 : vec2<u32>,  b_0 : vec2<u32>) -> bool
{
    var _S1 : u32 = a_0.x;
    var _S2 : u32 = b_0.x;
    var _S3 : bool;
    if((_S1 < _S2))
    {
        _S3 = true;
    }
    else
    {
        if(_S1 == _S2)
        {
            _S3 = ((a_0.y) < (b_0.y));
        }
        else
        {
            _S3 = false;
        }
    }
    return _S3;
}

fn SortImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var lane_0 : u32 = local_0.x;
    var header_0 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    if(lane_0 == u32(0))
    {
        var _S4 : u32 = atomicLoad(&(gWork_0[header_0 + u32(2)]));
        gCount_0 = _S4;
    }
    workgroupBarrier();
    var _S5 : u32 = header_0 + u32(12);
    var queue_0 : u32 = _S5 + gWavefront_0.capacity_0 * u32(84) + (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var item_0 : vec2<u32> = vec2<u32>(u32(4294967295));
    var _S6 : u32 = tid_0.x;
    if((_S6 < gCount_0))
    {
        var _S7 : u32 = atomicLoad(&(gWork_0[queue_0 + _S6]));
        item_0[i32(1)] = _S7;
        var base_0 : u32 = _S5 + item_0.y * u32(4);
        var _S8 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        if(_S8 != u32(0))
        {
            var instance_0 : u32 = atomicLoad(&(gWork_0[base_0 + u32(32) * gWavefront_0.capacity_0 + u32(3)]));
            item_0[i32(0)] = gMaterialData_0[gInstances_0[instance_0].materialIndex_0 * u32(2)].x;
        }
    }
    gSort_0[lane_0] = item_0;
    workgroupBarrier();
    var width_0 : u32 = u32(2);
    loop
    {
        if((width_0 <= u32(64)))
        {
        }
        else
        {
            break;
        }
        var stride_0 : u32 = width_0 / u32(2);
        loop
        {
            if((stride_0 > u32(0)))
            {
            }
            else
            {
                break;
            }
            var other_0 : vec2<u32> = gSort_0[(lane_0 ^ (stride_0))];
            var _S9 : bool;
            if((((lane_0 & (width_0))) == u32(0)) == (((lane_0 & (stride_0))) == u32(0)))
            {
                _S9 = Less_0(other_0, item_0);
            }
            else
            {
                _S9 = Less_0(item_0, other_0);
            }
            var next_0 : vec2<u32>;
            if(_S9)
            {
                next_0 = other_0;
            }
            else
            {
                next_0 = item_0;
            }
            workgroupBarrier();
            item_0 = next_0;
            gSort_0[lane_0] = next_0;
            workgroupBarrier();
            stride_0 = stride_0 / u32(2);
        }
        width_0 = width_0 * u32(2);
    }
    if((_S6 < gCount_0))
    {
        atomicStore(&(gWork_0[queue_0 + _S6]), item_0.y);
    }
    return;
}

fn SortImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var lane_1 : u32 = local_1.x;
    var header_1 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    if(lane_1 == u32(0))
    {
        var _S10 : u32 = atomicLoad(&(gWork_0[header_1 + u32(2)]));
        gCount_0 = _S10;
    }
    workgroupBarrier();
    var _S11 : u32 = header_1 + u32(12);
    var queue_1 : u32 = _S11 + gWavefront_0.capacity_0 * u32(84) + (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4);
    var item_1 : vec2<u32> = vec2<u32>(u32(4294967295));
    var _S12 : u32 = tid_1.x;
    if((_S12 < gCount_0))
    {
        var _S13 : u32 = atomicLoad(&(gWork_0[queue_1 + _S12]));
        item_1[i32(1)] = _S13;
        var base_1 : u32 = _S11 + item_1.y * u32(4);
        var _S14 : u32 = atomicLoad(&(gWork_0[base_1 + u32(3)]));
        if(_S14 != u32(0))
        {
            var instance_1 : u32 = atomicLoad(&(gWork_0[base_1 + u32(32) * gWavefront_0.capacity_0 + u32(3)]));
            item_1[i32(0)] = gInstances_0[instance_1].materialIndex_0;
        }
    }
    gSort_0[lane_1] = item_1;
    workgroupBarrier();
    var width_1 : u32 = u32(2);
    loop
    {
        if((width_1 <= u32(64)))
        {
        }
        else
        {
            break;
        }
        var stride_1 : u32 = width_1 / u32(2);
        loop
        {
            if((stride_1 > u32(0)))
            {
            }
            else
            {
                break;
            }
            var other_1 : vec2<u32> = gSort_0[(lane_1 ^ (stride_1))];
            var _S15 : bool;
            if((((lane_1 & (width_1))) == u32(0)) == (((lane_1 & (stride_1))) == u32(0)))
            {
                _S15 = Less_0(other_1, item_1);
            }
            else
            {
                _S15 = Less_0(item_1, other_1);
            }
            var next_1 : vec2<u32>;
            if(_S15)
            {
                next_1 = other_1;
            }
            else
            {
                next_1 = item_1;
            }
            workgroupBarrier();
            item_1 = next_1;
            gSort_0[lane_1] = next_1;
            workgroupBarrier();
            stride_1 = stride_1 / u32(2);
        }
        width_1 = width_1 * u32(2);
    }
    if((_S12 < gCount_0))
    {
        atomicStore(&(gWork_0[queue_1 + _S12]), item_1.y);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn SortMaterial(@builtin(global_invocation_id) tid_2 : vec3<u32>, @builtin(local_invocation_id) local_2 : vec3<u32>)
{
    SortImpl_1(tid_2, local_2);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn SortProgram(@builtin(global_invocation_id) tid_3 : vec3<u32>, @builtin(local_invocation_id) local_3 : vec3<u32>)
{
    SortImpl_0(tid_3, local_3);
    return;
}

