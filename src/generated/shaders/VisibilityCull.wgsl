// Generated from shaders/Passes/VisibilityCull.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(5) @group(0) var<storage, read> gIndices_0 : array<u32>;

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

@binding(0) @group(1) var<storage, read_write> gVisibilityWork_0 : array<atomic<u32>>;

struct Vertex_std430_0
{
    @align(16) positionU_0 : vec4<f32>,
    @align(16) normalV_0 : vec4<f32>,
    @align(16) tangent_0 : vec4<f32>,
    @align(16) uv1_0 : vec4<f32>,
};

@binding(4) @group(0) var<storage, read> gVertices_0 : array<Vertex_std430_0>;

fn rcp_0( x_0 : f32) -> f32
{
    return 1.0f / x_0;
}

fn StrongIntegerHash_0( x_1 : u32) -> u32
{
    var _S1 : u32 = ((x_1 ^ (((x_1 >> (u32(16))))))) * u32(2819806515);
    var _S2 : u32 = ((_S1 ^ (((_S1 >> (u32(15))))))) * u32(2994267309);
    return (_S2 ^ (((_S2 >> (u32(17))))));
}

struct RandomSequence_0
{
     seed_0 : u32,
};

fn RandomSequence_x24init_0( positionSeed_0 : u32,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S3 : RandomSequence_0;
    _S3.seed_0 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_0));
    return _S3;
}

fn RandomSequence_Next_0( this_0 : ptr<function, RandomSequence_0>) -> f32
{
    var _S4 : u32 = (*this_0).seed_0 + u32(1);
    (*this_0).seed_0 = _S4;
    return f32(((StrongIntegerHash_0(_S4)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_1 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_2 : f32 = RandomSequence_Next_0(&((*this_1)));
    var y_0 : f32 = RandomSequence_Next_0(&((*this_1)));
    return vec2<f32>(x_2, y_0);
}

fn PrimaryCameraJitter_0() -> vec2<f32>
{
    var rng_0 : RandomSequence_0 = RandomSequence_x24init_0(u32(1447646018), gFrame_0.frame_0.w);
    var _S5 : vec2<f32> = RandomSequence_Next2D_0(&(rng_0));
    return _S5;
}

fn PrimaryCameraPosition_0( world_0 : vec3<f32>) -> vec3<f32>
{
    var r_0 : vec3<f32> = gFrame_0.cameraRight_0.xyz;
    var u_0 : vec3<f32> = gFrame_0.cameraUp_0.xyz;
    var f_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var p_0 : vec3<f32> = world_0 - gFrame_0.cameraPosition_0.xyz;
    var _S6 : vec3<f32> = cross(u_0, f_0);
    var _S7 : vec3<f32> = cross(r_0, u_0);
    var _S8 : vec3<f32> = vec3<f32>(dot(p_0, _S6), dot(p_0, cross(f_0, r_0)), dot(p_0, _S7)) * vec3<f32>(rcp_0(dot(r_0, _S6)));
    var q_0 : vec3<f32> = _S8;
    var _S9 : vec2<f32> = _S8.xy - (PrimaryCameraJitter_0() - vec2<f32>(0.5f)) * vec2<f32>(2.0f, -2.0f) / vec2<f32>(gFrame_0.frame_0.xy) * vec2<f32>(_S8.z);
    q_0.x = _S9.x;
    q_0.y = _S9.y;
    return q_0 * vec3<f32>((abs(dot(f_0, _S7)) / length(_S7)));
}

fn PrimaryPlane_0( p_1 : vec3<f32>,  plane_0 : u32) -> f32
{
    if(plane_0 == u32(0))
    {
        return p_1.x + p_1.z;
    }
    if(plane_0 == u32(1))
    {
        return p_1.z - p_1.x;
    }
    if(plane_0 == u32(2))
    {
        return p_1.y + p_1.z;
    }
    if(plane_0 == u32(3))
    {
        return p_1.z - p_1.y;
    }
    if(plane_0 == u32(4))
    {
        return p_1.z;
    }
    return 9.9999997473787516e-05f - p_1.z;
}

fn TransformPoint_0( _S10 : u32,  _S11 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S10].objectToWorld_0[i32(0)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S10].objectToWorld_0[i32(1)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S10].objectToWorld_0[i32(2)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(2)].w);
}

@compute
@workgroup_size(64, 1, 1)
fn Cull(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var pair_0 : u32 = tid_0.x + tid_0.y * u32(4194240);
    if((pair_0 >= (gFrame_0.primaryVisibility_0.z)))
    {
        return;
    }
    var pairBase_0 : u32 = gFrame_0.primaryVisibility_0.y + pair_0 * u32(2);
    var _S12 : u32 = gIndices_0[pairBase_0];
    var desc_0 : u32 = gIndices_0[pairBase_0 + u32(1)];
    var _S13 : vec3<f32> = (bitcast<vec3<f32>>((vec3<u32>(gIndices_0[desc_0], gIndices_0[desc_0 + u32(1)], gIndices_0[desc_0 + u32(2)]))));
    var _S14 : vec3<f32> = (bitcast<vec3<f32>>((vec3<u32>(gIndices_0[desc_0 + u32(4)], gIndices_0[desc_0 + u32(5)], gIndices_0[desc_0 + u32(6)]))));
    var maxima_0 : array<f32, i32(6)>;
    var p_2 : u32 = u32(0);
    loop
    {
        if((p_2 < u32(6)))
        {
        }
        else
        {
            break;
        }
        maxima_0[p_2] = -3.4028234663852886e+38f;
        p_2 = p_2 + u32(1);
    }
    var corner_0 : u32 = u32(0);
    loop
    {
        if((corner_0 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var _S15 : f32;
        if(((corner_0 & (u32(1)))) != u32(0))
        {
            _S15 = _S14.x;
        }
        else
        {
            _S15 = _S13.x;
        }
        var _S16 : f32;
        if(((corner_0 & (u32(2)))) != u32(0))
        {
            _S16 = _S14.y;
        }
        else
        {
            _S16 = _S13.y;
        }
        var _S17 : f32;
        if(((corner_0 & (u32(4)))) != u32(0))
        {
            _S17 = _S14.z;
        }
        else
        {
            _S17 = _S13.z;
        }
        var _S18 : vec3<f32> = PrimaryCameraPosition_0(TransformPoint_0(_S12, vec3<f32>(_S15, _S16, _S17)));
        p_2 = u32(0);
        loop
        {
            if((p_2 < u32(6)))
            {
            }
            else
            {
                break;
            }
            maxima_0[p_2] = max(maxima_0[p_2], PrimaryPlane_0(_S18, p_2));
            p_2 = p_2 + u32(1);
        }
        corner_0 = corner_0 + u32(1);
    }
    p_2 = u32(0);
    loop
    {
        if((p_2 < u32(5)))
        {
        }
        else
        {
            break;
        }
        if(((maxima_0[p_2]) < -9.9999997473787516e-06f))
        {
            return;
        }
        p_2 = p_2 + u32(1);
    }
    var base_0 : u32 = gFrame_0.primaryVisibility_0.x;
    var offset_0 : u32 = atomicAdd(&(gVisibilityWork_0[base_0]), u32(1));
    var _S19 : u32 = base_0 + u32(16);
    atomicStore(&(gVisibilityWork_0[_S19 + offset_0]), pair_0);
    if(((maxima_0[i32(5)]) < -9.9999997473787516e-06f))
    {
        return;
    }
    var nearOffset_0 : u32 = atomicAdd(&(gVisibilityWork_0[base_0 + u32(2)]), u32(1));
    atomicStore(&(gVisibilityWork_0[_S19 + gFrame_0.primaryVisibility_0.z + nearOffset_0]), pair_0);
    return;
}

@compute
@workgroup_size(1, 1, 1)
fn DrawArguments(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    var base_1 : u32 = gFrame_0.primaryVisibility_0.x;
    atomicStore(&(gVisibilityWork_0[base_1 + u32(4)]), u32(192));
    var _S20 : u32 = atomicLoad(&(gVisibilityWork_0[base_1]));
    atomicStore(&(gVisibilityWork_0[base_1 + u32(5)]), _S20);
    atomicStore(&(gVisibilityWork_0[base_1 + u32(6)]), u32(0));
    atomicStore(&(gVisibilityWork_0[base_1 + u32(7)]), u32(0));
    var _S21 : u32 = atomicLoad(&(gVisibilityWork_0[base_1 + u32(2)]));
    var groups_0 : u32 = (_S21 + u32(63)) / u32(64);
    atomicStore(&(gVisibilityWork_0[base_1 + u32(12)]), min(groups_0, u32(65535)));
    atomicStore(&(gVisibilityWork_0[base_1 + u32(13)]), max(u32(1), (groups_0 + u32(65534)) / u32(65535)));
    atomicStore(&(gVisibilityWork_0[base_1 + u32(14)]), u32(1));
    atomicStore(&(gVisibilityWork_0[base_1 + u32(15)]), u32(0));
    return;
}

fn NearTriangle_0( a_0 : vec3<f32>,  b_0 : vec3<f32>,  c_0 : vec3<f32>) -> bool
{
    var n_0 : u32;
    var plane_1 : u32 = u32(0);
    loop
    {
        if((plane_1 < u32(6)))
        {
        }
        else
        {
            break;
        }
        if(((max(PrimaryPlane_0(a_0, plane_1), max(PrimaryPlane_0(b_0, plane_1), PrimaryPlane_0(c_0, plane_1)))) < 0.0f))
        {
            return false;
        }
        plane_1 = plane_1 + u32(1);
    }
    var n_1 : vec3<f32> = cross(b_0 - a_0, c_0 - a_0);
    var h_0 : f32 = dot(n_1, a_0);
    var radius_0 : f32 = abs(n_1.x) + abs(n_1.y);
    var _S22 : f32 = n_1.z;
    var _S23 : f32 = max(0.0f, 9.9999997473787516e-05f * (_S22 + radius_0));
    var slack_0 : f32 = 1.99999999495048542e-06f * max(abs(h_0), 9.9999997473787516e-05f * length(n_1));
    var _S24 : bool;
    if((h_0 < (min(0.0f, 9.9999997473787516e-05f * (_S22 - radius_0)) - slack_0)))
    {
        _S24 = true;
    }
    else
    {
        _S24 = (h_0 > (_S23 + slack_0));
    }
    if(_S24)
    {
        return false;
    }
    var next_0 : array<vec3<f32>, i32(12)>;
    var polygon_0 : array<vec3<f32>, i32(12)>;
    polygon_0[i32(0)] = a_0;
    polygon_0[i32(1)] = b_0;
    polygon_0[i32(2)] = c_0;
    var count_0 : u32 = u32(3);
    plane_1 = u32(0);
    loop
    {
        if((plane_1 < u32(6)))
        {
        }
        else
        {
            break;
        }
        var i_0 : u32 = u32(0);
        var n_2 : u32 = u32(0);
        loop
        {
            if((i_0 < count_0))
            {
            }
            else
            {
                break;
            }
            var p_3 : vec3<f32> = polygon_0[i_0];
            var _S25 : u32 = i_0 + u32(1);
            var _S26 : u32 = _S25 % count_0;
            var q_1 : vec3<f32> = polygon_0[_S26];
            var dp_0 : f32 = PrimaryPlane_0(p_3, plane_1);
            var dq_0 : f32 = PrimaryPlane_0(polygon_0[_S26], plane_1);
            var _S27 : bool = (dp_0 >= 0.0f);
            if(_S27)
            {
                _S24 = (n_2 < u32(12));
            }
            else
            {
                _S24 = false;
            }
            if(_S24)
            {
                var _S28 : u32 = n_2 + u32(1);
                next_0[n_2] = p_3;
                n_0 = _S28;
            }
            else
            {
                n_0 = n_2;
            }
            var _S29 : bool;
            if(_S27 != (dq_0 >= 0.0f))
            {
                _S29 = (n_0 < u32(12));
            }
            else
            {
                _S29 = false;
            }
            if(_S29)
            {
                var _S30 : u32 = n_0 + u32(1);
                next_0[n_0] = mix(p_3, q_1, vec3<f32>((dp_0 / (dp_0 - dq_0))));
                n_2 = _S30;
            }
            else
            {
                n_2 = n_0;
            }
            i_0 = _S25;
        }
        if(n_2 == u32(0))
        {
            return false;
        }
        n_0 = u32(0);
        loop
        {
            if((n_0 < n_2))
            {
            }
            else
            {
                break;
            }
            polygon_0[n_0] = next_0[n_0];
            n_0 = n_0 + u32(1);
        }
        var _S31 : u32 = plane_1 + u32(1);
        count_0 = n_2;
        plane_1 = _S31;
    }
    return true;
}

fn LoadTriangleIndices_0( _S32 : u32,  _S33 : u32) -> vec3<u32>
{
    var base_2 : u32 = gInstances_0[_S32].indexOffset_0 + _S33 * u32(3);
    return vec3<u32>(gIndices_0[base_2], gIndices_0[base_2 + u32(1)], gIndices_0[base_2 + u32(2)]) + vec3<u32>(gInstances_0[_S32].vertexOffset_0);
}

@compute
@workgroup_size(64, 1, 1)
fn CheckNear(@builtin(global_invocation_id) tid_2 : vec3<u32>)
{
    var base_3 : u32 = gFrame_0.primaryVisibility_0.x;
    var index_0 : u32 = tid_2.x + tid_2.y * u32(4194240);
    var _S34 : u32 = atomicLoad(&(gVisibilityWork_0[base_3 + u32(2)]));
    if((index_0 >= _S34))
    {
        return;
    }
    var pair_1 : u32 = atomicLoad(&(gVisibilityWork_0[base_3 + u32(16) + gFrame_0.primaryVisibility_0.z + index_0]));
    var pairBase_1 : u32 = gFrame_0.primaryVisibility_0.y + pair_1 * u32(2);
    var _S35 : u32 = gIndices_0[pairBase_1];
    var desc_1 : u32 = gIndices_0[pairBase_1 + u32(1)];
    var _S36 : u32 = gIndices_0[desc_1 + u32(3)];
    var _S37 : u32 = gIndices_0[desc_1 + u32(7)];
    var i_1 : u32 = u32(0);
    loop
    {
        if((i_1 < _S37))
        {
        }
        else
        {
            break;
        }
        var _S38 : vec3<u32> = LoadTriangleIndices_0(_S35, gIndices_0[_S36 + i_1]);
        var _S39 : bool = NearTriangle_0(PrimaryCameraPosition_0(TransformPoint_0(_S35, gVertices_0[_S38.x].positionU_0.xyz)), PrimaryCameraPosition_0(TransformPoint_0(_S35, gVertices_0[_S38.y].positionU_0.xyz)), PrimaryCameraPosition_0(TransformPoint_0(_S35, gVertices_0[_S38.z].positionU_0.xyz)));
        if(_S39)
        {
            atomicStore(&(gVisibilityWork_0[base_3 + u32(1)]), u32(1));
            return;
        }
        i_1 = i_1 + u32(1);
    }
    return;
}

