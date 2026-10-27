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
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
};

@binding(2) @group(1) var<uniform> gWavefront_0 : WavefrontUniforms_std140_0;
@binding(0) @group(1) var<storage, read_write> gWork_0 : array<atomic<u32>>;

var<workgroup> gPrefix_0 : array<vec2<u32>, i32(64)>;

var<workgroup> gOffsets_0 : vec2<u32>;

@compute
@workgroup_size(64, 1, 1)
fn Compact(@builtin(global_invocation_id) tid_0 : vec3<u32>, @builtin(local_invocation_id) local_0 : vec3<u32>)
{
    var index_0 : u32 = tid_0.x;
    var lane_0 : u32 = local_0.x;
    var header_0 : u32 = gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12);
    var _S1 : u32 = header_0 + u32(12);
    var base_0 : u32 = _S1 + index_0 * u32(4);
    var _S2 : vec2<u32> = vec2<u32>(u32(0));
    var flags_0 : vec2<u32> = _S2;
    if((index_0 < (gWavefront_0.pathCount_0)))
    {
        var _S3 : u32 = atomicLoad(&(gWork_0[base_0 + u32(3)]));
        flags_0[i32(0)] = select(u32(0), u32(1), _S3 != u32(0));
        var _S4 : u32 = atomicLoad(&(gWork_0[base_0 + u32(44) * gWavefront_0.capacity_0 + u32(2)]));
        flags_0[i32(1)] = select(u32(0), u32(1), _S4 != u32(0));
    }
    gPrefix_0[lane_0] = flags_0;
    workgroupBarrier();
    var offset_0 : u32 = u32(1);
    loop
    {
        if((offset_0 < u32(64)))
        {
        }
        else
        {
            break;
        }
        var value_0 : vec2<u32>;
        if((lane_0 >= offset_0))
        {
            value_0 = gPrefix_0[lane_0 - offset_0];
        }
        else
        {
            value_0 = _S2;
        }
        workgroupBarrier();
        gPrefix_0[lane_0] = gPrefix_0[lane_0] + value_0;
        workgroupBarrier();
        offset_0 = offset_0 * u32(2);
    }
    if(lane_0 == u32(0))
    {
        var count_0 : vec2<u32> = gPrefix_0[u32(63)];
        var _S5 : u32 = gPrefix_0[u32(63)].x;
        var x_0 : u32;
        if((_S5 > u32(0)))
        {
            var x_1 : u32 = atomicAdd(&(gWork_0[header_0]), _S5);
            var _S6 : u32 = atomicMax(&(gWork_0[header_0 + u32(4)]), (x_1 + _S5 + u32(63)) / u32(64));
            x_0 = x_1;
        }
        else
        {
            x_0 = u32(0);
        }
        var _S7 : u32 = count_0.y;
        var y_0 : u32;
        if((_S7 > u32(0)))
        {
            var y_1 : u32 = atomicAdd(&(gWork_0[header_0 + u32(1)]), _S7);
            var _S8 : u32 = atomicMax(&(gWork_0[header_0 + u32(8)]), (y_1 + _S7 + u32(63)) / u32(64));
            y_0 = y_1;
        }
        else
        {
            y_0 = u32(0);
        }
        gOffsets_0 = vec2<u32>(x_0, y_0);
    }
    workgroupBarrier();
    var queue_0 : u32 = _S1 + gWavefront_0.capacity_0 * u32(84);
    var prefix_0 : vec2<u32> = gOffsets_0 + gPrefix_0[lane_0] - flags_0;
    if((flags_0.x) != u32(0))
    {
        atomicStore(&(gWork_0[queue_0 + prefix_0.x]), index_0);
    }
    if((flags_0.y) != u32(0))
    {
        atomicStore(&(gWork_0[queue_0 + (gWavefront_0.capacity_0 + u32(3)) / u32(4) * u32(4) + prefix_0.y]), index_0);
    }
    return;
}

