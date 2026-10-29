// Generated from shaders/Passes/SharcMaintenance.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(0) @group(1) var<storage, read_write> gSharcWork_0 : array<atomic<u32>>;

struct SharcTile_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
    @align(16) unused_0 : vec4<u32>,
};

@binding(2) @group(1) var<uniform> gSharcTile_0 : SharcTile_std140_0;
fn SharcRecordWord_0( record_0 : u32) -> u32
{
    return gFrame_0.sharc_0.z + record_0 * u32(16);
}

fn StrongIntegerHash_0( x_0 : u32) -> u32
{
    var _S1 : u32 = ((x_0 ^ (((x_0 >> (u32(16))))))) * u32(2819806515);
    var _S2 : u32 = ((_S1 ^ (((_S1 >> (u32(15))))))) * u32(2994267309);
    return (_S2 ^ (((_S2 >> (u32(17))))));
}

struct SharcKey_0
{
     spatial_0 : vec4<u32>,
     material_0 : u32,
     instance_0 : u32,
};

fn SharcHash_0( key_0 : SharcKey_0) -> u32
{
    return ((StrongIntegerHash_0(((((((StrongIntegerHash_0(((((key_0.spatial_0.x) ^ ((StrongIntegerHash_0(key_0.spatial_0.y))))) ^ ((StrongIntegerHash_0(key_0.spatial_0.z)))))) ^ ((key_0.spatial_0.w)))) ^ ((StrongIntegerHash_0(key_0.material_0))))) ^ ((StrongIntegerHash_0(key_0.instance_0)))))) & ((gFrame_0.sharc_0.y - u32(1))));
}

fn SharcCellWord_0( slot_0 : u32) -> u32
{
    return gFrame_0.sharc_0.x + u32(16) + slot_0 * u32(16);
}

fn EncodeRadiance_0( record_1 : u32) -> vec3<u32>
{
    var p_0 : u32 = SharcRecordWord_0(record_1) + u32(8);
    var _S3 : u32 = atomicLoad(&(gSharcWork_0[p_0]));
    var _S4 : u32 = atomicLoad(&(gSharcWork_0[p_0 + u32(1)]));
    var _S5 : u32 = atomicLoad(&(gSharcWork_0[p_0 + u32(2)]));
    return vec3<u32>(clamp((bitcast<vec3<f32>>((vec3<u32>(_S3, _S4, _S5)))), vec3<f32>(0.0f), vec3<f32>(4096.0f)) * vec3<f32>(1024.0f) + vec3<f32>(0.5f));
}

@compute
@workgroup_size(64, 1, 1)
fn Accumulate(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var record_2 : u32 = tid_0.x;
    if((record_2 >= (gFrame_0.sharcControl_0.w)))
    {
        return;
    }
    var r_0 : u32 = SharcRecordWord_0(record_2);
    var _S6 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(6)]));
    if(_S6 == u32(0))
    {
        return;
    }
    var _S7 : u32 = atomicAdd(&(gSharcWork_0[gFrame_0.sharc_0.x + u32(4)]), u32(1));
    var key_1 : SharcKey_0;
    var _S8 : u32 = atomicLoad(&(gSharcWork_0[r_0]));
    var _S9 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(1)]));
    var _S10 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(2)]));
    var _S11 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(3)]));
    key_1.spatial_0 = vec4<u32>(_S8, _S9, _S10, _S11);
    var _S12 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(4)]));
    key_1.material_0 = _S12;
    var _S13 : u32 = atomicLoad(&(gSharcWork_0[r_0 + u32(5)]));
    key_1.instance_0 = _S13;
    var _S14 : u32 = SharcHash_0(key_1);
    var empty_0 : u32 = u32(4294967295);
    var pending_0 : bool = false;
    var probe_0 : u32 = u32(0);
    loop
    {
        if((probe_0 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var slot_1 : u32 = ((_S14 + probe_0) & ((gFrame_0.sharc_0.y - u32(1))));
        var p_1 : u32 = SharcCellWord_0(slot_1);
        var state_0 : u32 = atomicLoad(&(gSharcWork_0[p_1]));
        if(state_0 == u32(0))
        {
            var empty_1 : u32;
            if(empty_0 == u32(4294967295))
            {
                empty_1 = slot_1;
            }
            else
            {
                empty_1 = empty_0;
            }
            empty_0 = empty_1;
            probe_0 = probe_0 + u32(1);
            continue;
        }
        if(state_0 != u32(4294967295))
        {
            pending_0 = true;
            probe_0 = probe_0 + u32(1);
            continue;
        }
        var _S15 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(1)]));
        var _S16 : bool;
        if(_S15 != (key_1.spatial_0.x))
        {
            _S16 = true;
        }
        else
        {
            var _S17 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(2)]));
            _S16 = _S17 != (key_1.spatial_0.y);
        }
        var _S18 : bool;
        if(_S16)
        {
            _S18 = true;
        }
        else
        {
            var _S19 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(3)]));
            _S18 = _S19 != (key_1.spatial_0.z);
        }
        var _S20 : bool;
        if(_S18)
        {
            _S20 = true;
        }
        else
        {
            var _S21 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(4)]));
            _S20 = _S21 != (key_1.spatial_0.w);
        }
        var _S22 : bool;
        if(_S20)
        {
            _S22 = true;
        }
        else
        {
            var _S23 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(5)]));
            _S22 = _S23 != (key_1.material_0);
        }
        var _S24 : bool;
        if(_S22)
        {
            _S24 = true;
        }
        else
        {
            var _S25 : u32 = atomicLoad(&(gSharcWork_0[p_1 + u32(6)]));
            _S24 = _S25 != (key_1.instance_0);
        }
        if(_S24)
        {
            probe_0 = probe_0 + u32(1);
            continue;
        }
        var sample_0 : u32 = atomicAdd(&(gSharcWork_0[p_1 + u32(11)]), u32(1));
        if((sample_0 < u32(512)))
        {
            var rgb_0 : vec3<u32> = EncodeRadiance_0(record_2);
            var _S26 : u32 = atomicAdd(&(gSharcWork_0[p_1 + u32(8)]), rgb_0.x);
            var _S27 : u32 = atomicAdd(&(gSharcWork_0[p_1 + u32(9)]), rgb_0.y);
            var _S28 : u32 = atomicAdd(&(gSharcWork_0[p_1 + u32(10)]), rgb_0.z);
            atomicStore(&(gSharcWork_0[p_1 + u32(7)]), gFrame_0.sharc_0.w);
            var _S29 : u32 = atomicAdd(&(gSharcWork_0[gFrame_0.sharc_0.x + u32(9)]), u32(1));
        }
        return;
    }
    if(pending_0)
    {
        return;
    }
    if(empty_0 != u32(4294967295))
    {
        var _S30 : u32 = atomicCompareExchangeWeak(&(gSharcWork_0[SharcCellWord_0(empty_0)]), u32(0), record_2 + u32(1)).old_value;
        pending_0 = _S30 == u32(0);
    }
    else
    {
        pending_0 = false;
    }
    if(pending_0)
    {
        atomicStore(&(gSharcWork_0[r_0 + u32(7)]), empty_0);
    }
    else
    {
        var _S31 : u32 = atomicAdd(&(gSharcWork_0[gFrame_0.sharc_0.x + u32(6)]), u32(1));
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Publish(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    var record_3 : u32 = tid_1.x;
    if((record_3 >= (gFrame_0.sharcControl_0.w)))
    {
        return;
    }
    var r_1 : u32 = SharcRecordWord_0(record_3);
    var _S32 : u32 = atomicLoad(&(gSharcWork_0[r_1 + u32(6)]));
    if(_S32 == u32(0))
    {
        return;
    }
    var slot_2 : u32 = atomicLoad(&(gSharcWork_0[r_1 + u32(7)]));
    if(slot_2 == u32(4294967295))
    {
        return;
    }
    var p_2 : u32 = SharcCellWord_0(slot_2);
    var i_0 : u32 = u32(0);
    loop
    {
        if((i_0 < u32(6)))
        {
        }
        else
        {
            break;
        }
        var _S33 : u32 = atomicLoad(&(gSharcWork_0[r_1 + i_0]));
        atomicStore(&(gSharcWork_0[p_2 + u32(1) + i_0]), _S33);
        i_0 = i_0 + u32(1);
    }
    atomicStore(&(gSharcWork_0[p_2 + u32(7)]), gFrame_0.sharc_0.w);
    var rgb_1 : vec3<u32> = EncodeRadiance_0(record_3);
    atomicStore(&(gSharcWork_0[p_2 + u32(8)]), rgb_1.x);
    atomicStore(&(gSharcWork_0[p_2 + u32(9)]), rgb_1.y);
    atomicStore(&(gSharcWork_0[p_2 + u32(10)]), rgb_1.z);
    atomicStore(&(gSharcWork_0[p_2 + u32(11)]), u32(1));
    i_0 = u32(12);
    loop
    {
        if((i_0 < u32(16)))
        {
        }
        else
        {
            break;
        }
        atomicStore(&(gSharcWork_0[p_2 + i_0]), u32(0));
        i_0 = i_0 + u32(1);
    }
    atomicStore(&(gSharcWork_0[p_2]), u32(4294967295));
    var _S34 : u32 = atomicAdd(&(gSharcWork_0[gFrame_0.sharc_0.x + u32(9)]), u32(1));
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Resolve(@builtin(global_invocation_id) tid_2 : vec3<u32>)
{
    var _S35 : u32 = tid_2.x;
    if((_S35 >= (gFrame_0.sharc_0.y)))
    {
        return;
    }
    var p_3 : u32 = SharcCellWord_0(_S35);
    var _S36 : u32 = atomicLoad(&(gSharcWork_0[p_3]));
    if(_S36 != u32(4294967295))
    {
        return;
    }
    var _S37 : u32 = gFrame_0.sharc_0.w;
    var _S38 : u32 = atomicLoad(&(gSharcWork_0[p_3 + u32(7)]));
    var i_1 : u32;
    if(((_S37 - _S38) > (gFrame_0.sharcControl_0.z)))
    {
        i_1 = u32(0);
        loop
        {
            if((i_1 < u32(16)))
            {
            }
            else
            {
                break;
            }
            atomicStore(&(gSharcWork_0[p_3 + i_1]), u32(0));
            i_1 = i_1 + u32(1);
        }
        return;
    }
    var _S39 : u32 = atomicAdd(&(gSharcWork_0[gFrame_0.sharc_0.x + u32(5)]), u32(1));
    var _S40 : u32 = p_3 + u32(11);
    var _S41 : u32 = atomicLoad(&(gSharcWork_0[_S40]));
    var _S42 : u32 = min(_S41, u32(512));
    if(_S42 == u32(0))
    {
        return;
    }
    var _S43 : u32 = p_3 + u32(15);
    var history_0 : u32 = atomicLoad(&(gSharcWork_0[_S43]));
    var frames_0 : u32 = (history_0 >> (u32(16)));
    var _S44 : f32 = f32(min(frames_0, gFrame_0.sharcControl_0.y));
    i_1 = u32(0);
    loop
    {
        if((i_1 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var _S45 : u32 = p_3 + u32(8) + i_1;
        var _S46 : u32 = atomicLoad(&(gSharcWork_0[_S45]));
        var fresh_0 : f32 = f32(_S46) / (1024.0f * f32(_S42));
        var _S47 : u32 = p_3 + u32(12) + i_1;
        var _S48 : u32 = atomicLoad(&(gSharcWork_0[_S47]));
        atomicStore(&(gSharcWork_0[_S47]), (bitcast<u32>((((bitcast<f32>((_S48))) * _S44 + fresh_0) / (_S44 + 1.0f)))));
        atomicStore(&(gSharcWork_0[_S45]), u32(0));
        i_1 = i_1 + u32(1);
    }
    atomicStore(&(gSharcWork_0[_S40]), u32(0));
    atomicStore(&(gSharcWork_0[_S43]), ((((min(frames_0 + u32(1), gFrame_0.sharcControl_0.y)) << (u32(16)))) | ((min(((history_0 & (u32(65535)))) + _S42, u32(65535))))));
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Statistics(@builtin(global_invocation_id) tid_3 : vec3<u32>)
{
    var _S49 : u32 = tid_3.x;
    if((_S49 >= (gSharcTile_0.pathCount_0)))
    {
        return;
    }
    var state_1 : u32 = atomicLoad(&(gSharcWork_0[gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(12) + u32(12) + gSharcTile_0.capacity_0 * u32(24) + _S49 * u32(4) + u32(3)]));
    var _S50 : u32 = (state_1 & (u32(255)));
    if(_S50 == u32(0))
    {
        return;
    }
    var p_4 : u32 = gFrame_0.sharc_0.x;
    var _S51 : u32 = atomicAdd(&(gSharcWork_0[p_4]), u32(1));
    var _S52 : u32 = atomicAdd(&(gSharcWork_0[p_4 + u32(1)]), _S50);
    var _S53 : u32 = atomicAdd(&(gSharcWork_0[p_4 + u32(2)]), (((state_1 >> (u32(8)))) & (u32(1))));
    var _S54 : u32 = atomicAdd(&(gSharcWork_0[p_4 + u32(3)]), (((state_1 >> (u32(9)))) & (u32(1))));
    var _S55 : u32 = atomicAdd(&(gSharcWork_0[p_4 + u32(8)]), (state_1 >> (u32(16))));
    return;
}
