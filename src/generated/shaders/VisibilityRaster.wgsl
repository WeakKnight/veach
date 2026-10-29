// Generated from shaders/Passes/VisibilityRaster.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(0) @group(1) var<storage, read> gVisibilityWork_0 : array<u32>;

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
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        return gFrame_0.temporal_0.xy;
    }
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

struct VisibilityVertex_0
{
    @builtin(position) position_0 : vec4<f32>,
    @interpolate(flat) @location(0) ids_0 : vec2<u32>,
};

fn TransformPoint_0( _S10 : u32,  _S11 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S10].objectToWorld_0[i32(0)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S10].objectToWorld_0[i32(1)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S10].objectToWorld_0[i32(2)].xyz, _S11) + gInstances_0[_S10].objectToWorld_0[i32(2)].w);
}

@vertex
fn vsMain(@builtin(vertex_index) vertex_0 : u32, @builtin(instance_index) cluster_0 : u32) -> VisibilityVertex_0
{
    var result_0 : VisibilityVertex_0;
    result_0.position_0 = vec4<f32>(2.0f, 2.0f, 0.0f, 1.0f);
    result_0.ids_0 = vec2<u32>(u32(4294967295));
    var pairBase_0 : u32 = gFrame_0.primaryVisibility_0.y + gVisibilityWork_0[gFrame_0.primaryVisibility_0.x + u32(16) + cluster_0] * u32(2);
    var instanceIndex_0 : u32 = gIndices_0[pairBase_0];
    var desc_0 : u32 = gIndices_0[pairBase_0 + u32(1)];
    if(((vertex_0 / u32(3)) >= gIndices_0[desc_0 + u32(7)]))
    {
        return result_0;
    }
    var primitive_0 : u32 = gIndices_0[gIndices_0[desc_0 + u32(3)] + vertex_0 / u32(3)];
    var q_1 : vec3<f32> = PrimaryCameraPosition_0(TransformPoint_0(instanceIndex_0, gVertices_0[gIndices_0[gInstances_0[instanceIndex_0].indexOffset_0 + primitive_0 * u32(3) + vertex_0 % u32(3)] + gInstances_0[instanceIndex_0].vertexOffset_0].positionU_0.xyz));
    result_0.position_0 = vec4<f32>(q_1.xy, 9.9999997473787516e-05f, q_1.z);
    result_0.ids_0 = vec2<u32>(instanceIndex_0, primitive_0);
    return result_0;
}

struct pixelOutput_0
{
    @location(0) output_0 : vec2<u32>,
};

struct pixelInput_0
{
    @interpolate(flat) @location(0) ids_1 : vec2<u32>,
};

@fragment
fn fsMain( _S12 : pixelInput_0, @builtin(position) position_1 : vec4<f32>) -> pixelOutput_0
{
    var _S13 : pixelOutput_0 = pixelOutput_0( _S12.ids_1 );
    return _S13;
}

