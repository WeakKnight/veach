// Generated from shaders/Passes/WavefrontShadow.slang by scripts/build-shaders.mjs. Do not edit.
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
@binding(0) @group(1) var<storage, read_write> gAccum_0 : array<vec4<f32>>;

@binding(2) @group(0) var<storage, read> gTris_0 : array<vec4<f32>>;

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

struct BVHNode_std430_0
{
    @align(16) lmin_0 : vec3<f32>,
    @align(4) left_0 : u32,
    @align(16) lmax_0 : vec3<f32>,
    @align(4) right_0 : u32,
    @align(16) rmin_0 : vec3<f32>,
    @align(4) triCount_1 : u32,
    @align(16) rmax_0 : vec3<f32>,
    @align(4) firstTri_0 : u32,
};

@binding(1) @group(0) var<storage, read> gNodes_0 : array<BVHNode_std430_0>;

struct Ray_0
{
     origin_0 : vec3<f32>,
     tMin_0 : f32,
     direction_0 : vec3<f32>,
     tMax_0 : f32,
};

struct HitRecord_0
{
     t_0 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_0 : u32,
     primitiveIndex_0 : u32,
};

fn rcp_0( x_0 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_0;
}

fn SafeRcp_0( d_0 : vec3<f32>) -> vec3<f32>
{
    return rcp_0(select(d_0, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_0 < vec3<f32>(0.0f))), ((abs(d_0)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn InverseTransformPoint_0( _S1 : u32,  _S2 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S1].worldToObject_0[i32(0)].xyz, _S2) + gInstances_0[_S1].worldToObject_0[i32(0)].w, dot(gInstances_0[_S1].worldToObject_0[i32(1)].xyz, _S2) + gInstances_0[_S1].worldToObject_0[i32(1)].w, dot(gInstances_0[_S1].worldToObject_0[i32(2)].xyz, _S2) + gInstances_0[_S1].worldToObject_0[i32(2)].w);
}

fn InverseTransformVector_0( _S3 : u32,  _S4 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S3].worldToObject_0[i32(0)].xyz, _S4), dot(gInstances_0[_S3].worldToObject_0[i32(1)].xyz, _S4), dot(gInstances_0[_S3].worldToObject_0[i32(2)].xyz, _S4));
}

var<private> gTraversalCost_0 : u32;

fn rcp_1( x_1 : f32) -> f32
{
    return 1.0f / x_1;
}

fn IntersectTriangle_0( o_0 : vec3<f32>,  d_1 : vec3<f32>,  v0_0 : vec3<f32>,  e1_0 : vec3<f32>,  e2_0 : vec3<f32>,  tMin_1 : f32,  tMax_1 : f32,  t_1 : ptr<function, f32>,  bary_0 : ptr<function, vec2<f32>>) -> bool
{
    (*t_1) = 0.0f;
    (*bary_0) = vec2<f32>(0.0f);
    var h_0 : vec3<f32> = cross(d_1, e2_0);
    var a_0 : f32 = dot(e1_0, h_0);
    if(a_0 == 0.0f)
    {
        return false;
    }
    var f_0 : f32 = rcp_1(a_0);
    var s_0 : vec3<f32> = o_0 - v0_0;
    var u_0 : f32 = f_0 * dot(s_0, h_0);
    var _S5 : bool;
    if((u_0 < 0.0f))
    {
        _S5 = true;
    }
    else
    {
        _S5 = (u_0 > 1.0f);
    }
    if(_S5)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_0, e1_0);
    var v_0 : f32 = f_0 * dot(d_1, q_0);
    if((v_0 < 0.0f))
    {
        _S5 = true;
    }
    else
    {
        _S5 = ((u_0 + v_0) > 1.0f);
    }
    if(_S5)
    {
        return false;
    }
    (*t_1) = f_0 * dot(e2_0, q_0);
    (*bary_0) = vec2<f32>(u_0, v_0);
    if(((*t_1) > tMin_1))
    {
        _S5 = ((*t_1) < tMax_1);
    }
    else
    {
        _S5 = false;
    }
    return _S5;
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_1 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_2 : f32,  tMax_2 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_1) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_1) * rD_0;
    var _S6 : vec3<f32> = min(t1_0, t2_0);
    var _S7 : vec3<f32> = max(t1_0, t2_0);
    var _S8 : f32 = max(max(_S6.x, _S6.y), max(_S6.z, tMin_2));
    var _S9 : f32;
    if((_S8 <= (min(min(_S7.x, _S7.y), min(_S7.z, tMax_2)))))
    {
        _S9 = _S8;
    }
    else
    {
        _S9 = 1.00000001504746622e+30f;
    }
    return _S9;
}

fn TraverseBLAS_0( _S10 : u32,  _S11 : u32,  _S12 : vec3<f32>,  _S13 : vec3<f32>,  _S14 : f32,  _S15 : bool,  _S16 : ptr<function, HitRecord_0>) -> bool
{
    var found_0 : bool;
    var _S17 : vec3<f32> = SafeRcp_0(_S13);
    var stack_0 : array<u32, i32(48)>;
    var nodeRef_0 : u32 = u32(0);
    var found_1 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var i_0 : u32;
        if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
        {
            var _S18 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
            var _S19 : u32 = (nodeRef_0 & (u32(16777215)));
            found_0 = found_1;
            i_0 = u32(0);
            loop
            {
                if((i_0 < _S18))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_0 : u32 = (gInstances_0[_S11].blasTriOffset_0 + _S19 + i_0) * u32(3);
                var v0_1 : vec4<f32> = gTris_0[base_0];
                var t_2 : f32;
                var bary_1 : vec2<f32>;
                var _S20 : bool = IntersectTriangle_0(_S12, _S13, v0_1.xyz, gTris_0[base_0 + u32(1)].xyz, gTris_0[base_0 + u32(2)].xyz, _S14, (*_S16).t_0, &(t_2), &(bary_1));
                if(!_S20)
                {
                    i_0 = i_0 + u32(1);
                    continue;
                }
                var primitiveIndex_1 : u32 = (bitcast<u32>((v0_1.w)));
                (*_S16).t_0 = t_2;
                (*_S16).barycentrics_0 = bary_1;
                (*_S16).instanceIndex_0 = _S10;
                (*_S16).primitiveIndex_0 = primitiveIndex_1;
                if(_S15)
                {
                    return true;
                }
                found_0 = true;
                i_0 = i_0 + u32(1);
            }
            if(stackPtr_0 == u32(0))
            {
                break;
            }
            var stackPtr_1 : u32 = stackPtr_0 - u32(1);
            nodeRef_0 = stack_0[stackPtr_1];
            found_1 = found_0;
            stackPtr_0 = stackPtr_1;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_0 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S11].blasNodeOffset_0 + nodeRef_0];
        var dist1_0 : f32 = IntersectBox_0(node_0.lmin_0, node_0.lmax_0, _S12, _S17, _S14, (*_S16).t_0);
        var dist2_0 : f32 = IntersectBox_0(node_0.rmin_0, node_0.rmax_0, _S12, _S17, _S14, (*_S16).t_0);
        var far_0 : u32;
        var dist1_1 : f32;
        var dist2_1 : f32;
        if((dist1_0 > dist2_0))
        {
            dist1_1 = dist2_0;
            i_0 = node_0.right_0;
            dist2_1 = dist1_0;
            far_0 = node_0.left_0;
        }
        else
        {
            dist1_1 = dist1_0;
            i_0 = node_0.left_0;
            dist2_1 = dist2_0;
            far_0 = node_0.right_0;
        }
        if(dist1_1 == 1.00000001504746622e+30f)
        {
            if(stackPtr_0 == u32(0))
            {
                found_0 = found_1;
                break;
            }
            var stackPtr_2 : u32 = stackPtr_0 - u32(1);
            nodeRef_0 = stack_0[stackPtr_2];
            stackPtr_0 = stackPtr_2;
        }
        else
        {
            if(dist2_1 != 1.00000001504746622e+30f)
            {
                found_0 = (stackPtr_0 < u32(48));
            }
            else
            {
                found_0 = false;
            }
            var stackPtr_3 : u32;
            if(found_0)
            {
                var _S21 : u32 = stackPtr_0 + u32(1);
                stack_0[stackPtr_0] = far_0;
                stackPtr_3 = _S21;
            }
            else
            {
                stackPtr_3 = stackPtr_0;
            }
            nodeRef_0 = i_0;
            stackPtr_0 = stackPtr_3;
        }
    }
    return found_0;
}

fn TraceScene_0( ray_0 : Ray_0,  anyHit_0 : bool,  hit_0 : ptr<function, HitRecord_0>) -> bool
{
    var found_2 : bool;
    (*hit_0).t_0 = ray_0.tMax_0;
    (*hit_0).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_0).instanceIndex_0 = u32(4294967295);
    (*hit_0).primitiveIndex_0 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S22 : u32 = gFrame_0.counts_0.z;
    var _S23 : vec3<f32> = SafeRcp_0(ray_0.direction_0);
    var stack_1 : array<u32, i32(32)>;
    var nodeRef_1 : u32 = u32(0);
    var found_3 : bool = false;
    var stackPtr_4 : u32 = u32(0);
    loop
    {
        var i_1 : u32;
        if(((nodeRef_1 & (u32(2147483648)))) != u32(0))
        {
            var _S24 : u32 = (((nodeRef_1 >> (u32(24)))) & (u32(127)));
            var _S25 : u32 = (nodeRef_1 & (u32(16777215)));
            found_2 = found_3;
            i_1 = u32(0);
            loop
            {
                if((i_1 < _S24))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_1 : u32 = gIndices_0[_S22 + _S25 + i_1];
                var _S26 : bool = TraverseBLAS_0(instanceIndex_1, instanceIndex_1, InverseTransformPoint_0(instanceIndex_1, ray_0.origin_0), InverseTransformVector_0(instanceIndex_1, ray_0.direction_0), ray_0.tMin_0, anyHit_0, &((*hit_0)));
                if(_S26)
                {
                    if(anyHit_0)
                    {
                        return true;
                    }
                    found_2 = true;
                }
                i_1 = i_1 + u32(1);
            }
            if(stackPtr_4 == u32(0))
            {
                break;
            }
            var stackPtr_5 : u32 = stackPtr_4 - u32(1);
            nodeRef_1 = stack_1[stackPtr_5];
            found_3 = found_2;
            stackPtr_4 = stackPtr_5;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_1 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_1];
        var dist1_2 : f32 = IntersectBox_0(node_1.lmin_0, node_1.lmax_0, ray_0.origin_0, _S23, ray_0.tMin_0, (*hit_0).t_0);
        var dist2_2 : f32 = IntersectBox_0(node_1.rmin_0, node_1.rmax_0, ray_0.origin_0, _S23, ray_0.tMin_0, (*hit_0).t_0);
        var far_1 : u32;
        var dist1_3 : f32;
        var dist2_3 : f32;
        if((dist1_2 > dist2_2))
        {
            dist1_3 = dist2_2;
            i_1 = node_1.right_0;
            dist2_3 = dist1_2;
            far_1 = node_1.left_0;
        }
        else
        {
            dist1_3 = dist1_2;
            i_1 = node_1.left_0;
            dist2_3 = dist2_2;
            far_1 = node_1.right_0;
        }
        if(dist1_3 == 1.00000001504746622e+30f)
        {
            if(stackPtr_4 == u32(0))
            {
                found_2 = found_3;
                break;
            }
            var stackPtr_6 : u32 = stackPtr_4 - u32(1);
            nodeRef_1 = stack_1[stackPtr_6];
            stackPtr_4 = stackPtr_6;
        }
        else
        {
            if(dist2_3 != 1.00000001504746622e+30f)
            {
                found_2 = (stackPtr_4 < u32(32));
            }
            else
            {
                found_2 = false;
            }
            var stackPtr_7 : u32;
            if(found_2)
            {
                var _S27 : u32 = stackPtr_4 + u32(1);
                stack_1[stackPtr_4] = far_1;
                stackPtr_7 = _S27;
            }
            else
            {
                stackPtr_7 = stackPtr_4;
            }
            nodeRef_1 = i_1;
            stackPtr_4 = stackPtr_7;
        }
    }
    return found_2;
}

fn WorkBase_0( index_0 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_0;
}

fn Field_0( base_1 : u32,  field_0 : u32) -> u32
{
    return base_1 + field_0 * gWavefront_0.capacity_0;
}

fn Ray_x24init_0( o_2 : vec3<f32>,  d_2 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S28 : Ray_0;
    _S28.origin_0 = o_2;
    _S28.direction_0 = d_2;
    _S28.tMin_0 = 0.0f;
    _S28.tMax_0 = tmax_0;
    return _S28;
}

fn TraceOcclusion_0( ray_1 : Ray_0) -> bool
{
    var hit_1 : HitRecord_0;
    var _S29 : bool = TraceScene_0(ray_1, true, &(hit_1));
    return _S29;
}

var<workgroup> gContributions_0 : array<vec3<f32>, i32(192)>;

fn NrdUnpackFraction_0( v_1 : u32) -> vec3<f32>
{
    return vec3<f32>(f32((v_1 & (u32(511)))), f32((((v_1 >> (u32(9)))) & (u32(511)))), f32((((v_1 >> (u32(18)))) & (u32(511))))) / vec3<f32>(511.0f);
}

fn NrdSplitDirect_0( flags_1 : u32,  contribution_0 : vec3<f32>,  diffuse_0 : ptr<function, vec3<f32>>,  specular_0 : ptr<function, vec3<f32>>,  bypass_0 : ptr<function, vec3<f32>>)
{
    var skip_0 : bool = ((flags_1 & (u32(4)))) != u32(0);
    var _S30 : vec3<f32>;
    if(skip_0)
    {
        _S30 = vec3<f32>(0.0f);
    }
    else
    {
        _S30 = contribution_0 * NrdUnpackFraction_0((flags_1 >> (u32(3))));
    }
    (*diffuse_0) = _S30;
    if(skip_0)
    {
        _S30 = vec3<f32>(0.0f);
    }
    else
    {
        _S30 = contribution_0 - (*diffuse_0);
    }
    (*specular_0) = _S30;
    if(skip_0)
    {
        _S30 = contribution_0;
    }
    else
    {
        _S30 = vec3<f32>(0.0f);
    }
    (*bypass_0) = _S30;
    return;
}

var<workgroup> gNrdDiffuse_0 : array<vec4<f32>, i32(192)>;

var<workgroup> gNrdBypass_0 : array<vec3<f32>, i32(192)>;

var<workgroup> gNrdDiffuseDirection_0 : array<vec3<f32>, i32(192)>;

fn Luminance_0( color_0 : vec3<f32>) -> f32
{
    return dot(color_0, vec3<f32>(0.2125999927520752f, 0.71520000696182251f, 0.072200000286102295f));
}

var<workgroup> gNrdSpecularDirection_0 : array<vec3<f32>, i32(192)>;

fn WorkPixel_0( index_1 : u32) -> vec2<u32>
{
    var work_0 : u32 = gWavefront_0.tileStart_0 + index_1;
    var block_0 : u32 = work_0 / u32(64);
    var lane_0 : u32 = (work_0 & (u32(63)));
    var blocksX_0 : u32 = (gFrame_0.frame_0.x + u32(7)) / u32(8);
    var _S31 : u32 = block_0 % blocksX_0;
    var _S32 : u32 = _S31 * u32(8) + ((lane_0 & (u32(7))));
    var _S33 : u32 = block_0 / blocksX_0;
    return vec2<u32>(_S32, _S33 * u32(8) + lane_0 / u32(8));
}

fn NrdBase_0( base_2 : u32) -> u32
{
    var pixel_0 : vec2<u32> = WorkPixel_0(base_2 - WorkBase_0(u32(0)));
    return gFrame_0.envInfo_0.w + (pixel_0.y * gFrame_0.frame_0.x + pixel_0.x) * u32(5);
}

fn ShadowParallelImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var _S34 : vec3<f32> = vec3<f32>(0.0f);
    var _S35 : u32 = local_0.y;
    var _S36 : u32 = _S35 * u32(2);
    var _S37 : u32 = tid_0.x;
    var _S38 : bool = (_S37 < (gWavefront_0.pathCount_0));
    var _S39 : bool;
    var value_0 : vec3<f32>;
    var lightDirection_0 : vec3<f32>;
    var flags_2 : u32;
    var mask_0 : u32;
    var base_3 : u32;
    if(_S38)
    {
        var base_4 : u32 = WorkBase_0(_S37);
        var mask_1 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_4, u32(11))].z)));
        if(((mask_1 & (((u32(1) << (_S36)))))) != u32(0))
        {
            var offset_0 : u32 = u32(12) + _S36 * u32(3);
            var origin_1 : vec4<f32> = gAccum_0[Field_0(base_4, offset_0)];
            var flags_3 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_4, offset_0 + u32(1))].w)));
            var _S40 : vec3<f32> = gAccum_0[Field_0(base_4, offset_0 + u32(1))].xyz;
            if(((flags_3 & (u32(1)))) == u32(0))
            {
                _S39 = true;
            }
            else
            {
                var _S41 : bool = TraceOcclusion_0(Ray_x24init_0(origin_1.xyz, _S40, origin_1.w));
                _S39 = !_S41;
            }
            if(_S39)
            {
                value_0 = gAccum_0[Field_0(base_4, offset_0 + u32(2))].xyz;
            }
            else
            {
                value_0 = _S34;
            }
            flags_2 = flags_3;
            lightDirection_0 = _S40;
        }
        else
        {
            value_0 = _S34;
            flags_2 = u32(0);
            lightDirection_0 = _S34;
        }
        mask_0 = mask_1;
        base_3 = base_4;
    }
    else
    {
        value_0 = _S34;
        flags_2 = u32(0);
        lightDirection_0 = _S34;
        mask_0 = u32(0);
        base_3 = u32(0);
    }
    var _S42 : u32 = local_0.x;
    var _S43 : u32 = _S35 * u32(64) + _S42;
    gContributions_0[_S43] = value_0;
    var laneDiffuse_0 : vec3<f32> = _S34;
    var laneSpecular_0 : vec3<f32>;
    var laneBypass_0 : vec3<f32> = _S34;
    var _S44 : bool = ((flags_2 & (u32(2)))) != u32(0);
    if(_S44)
    {
        NrdSplitDirect_0(flags_2, value_0, &(laneDiffuse_0), &(laneSpecular_0), &(laneBypass_0));
    }
    gNrdDiffuse_0[_S43] = vec4<f32>(laneDiffuse_0, f32(_S44));
    gNrdBypass_0[_S43] = laneBypass_0;
    gNrdDiffuseDirection_0[_S43] = vec3<f32>(Luminance_0(laneDiffuse_0)) * lightDirection_0;
    if(_S44)
    {
        value_0 = vec3<f32>(Luminance_0(laneSpecular_0)) * lightDirection_0;
    }
    else
    {
        value_0 = _S34;
    }
    gNrdSpecularDirection_0[_S43] = value_0;
    workgroupBarrier();
    if(_S36 == u32(0))
    {
        _S39 = _S38;
    }
    else
    {
        _S39 = false;
    }
    if(_S39)
    {
        _S39 = mask_0 != u32(0);
    }
    else
    {
        _S39 = false;
    }
    if(_S39)
    {
        var _S45 : u32 = u32(64) + _S42;
        var sum_0 : vec3<f32> = gContributions_0[_S42] + gContributions_0[_S45];
        var throughput_0 : vec4<f32> = gAccum_0[Field_0(base_3, u32(10))];
        var diffuse_1 : vec4<f32> = gNrdDiffuse_0[_S42] + gNrdDiffuse_0[_S45];
        var bypass_1 : vec3<f32> = gNrdBypass_0[_S42] + gNrdBypass_0[_S45];
        var diffuseDirection_0 : vec3<f32> = gNrdDiffuseDirection_0[_S42] + gNrdDiffuseDirection_0[_S45];
        var specularDirection_0 : vec3<f32> = gNrdSpecularDirection_0[_S42] + gNrdSpecularDirection_0[_S45];
        if(((diffuse_1.w) > 0.0f))
        {
            var r_0 : u32 = NrdBase_0(base_3);
            var _S46 : vec3<f32> = throughput_0.xyz;
            var _S47 : vec3<f32> = gAccum_0[r_0].xyz + _S46 * bypass_1;
            gAccum_0[r_0].x = _S47.x;
            gAccum_0[r_0].y = _S47.y;
            gAccum_0[r_0].z = _S47.z;
            var _S48 : u32 = r_0 + u32(1);
            var _S49 : vec3<f32> = diffuse_1.xyz;
            var _S50 : vec3<f32> = gAccum_0[_S48].xyz + _S46 * _S49;
            gAccum_0[_S48].x = _S50.x;
            gAccum_0[_S48].y = _S50.y;
            gAccum_0[_S48].z = _S50.z;
            var _S51 : u32 = r_0 + u32(2);
            var _S52 : vec3<f32> = gAccum_0[_S51].xyz + _S46 * (sum_0 - _S49 - bypass_1);
            gAccum_0[_S51].x = _S52.x;
            gAccum_0[_S51].y = _S52.y;
            gAccum_0[_S51].z = _S52.z;
            var _S53 : u32 = r_0 + u32(3);
            var _S54 : vec3<f32> = vec3<f32>(Luminance_0(_S46));
            var _S55 : vec3<f32> = gAccum_0[_S53].xyz + _S54 * diffuseDirection_0;
            gAccum_0[_S53].x = _S55.x;
            gAccum_0[_S53].y = _S55.y;
            gAccum_0[_S53].z = _S55.z;
            var _S56 : u32 = r_0 + u32(4);
            var _S57 : vec3<f32> = gAccum_0[_S56].xyz + _S54 * specularDirection_0;
            gAccum_0[_S56].x = _S57.x;
            gAccum_0[_S56].y = _S57.y;
            gAccum_0[_S56].z = _S57.z;
        }
        var contribution_1 : vec3<f32> = throughput_0.xyz * sum_0;
        var _S58 : f32 = throughput_0.w;
        var contribution_2 : vec3<f32>;
        if((_S58 > 0.0f))
        {
            contribution_2 = min(contribution_1, vec3<f32>(_S58));
        }
        else
        {
            contribution_2 = contribution_1;
        }
        var path_0 : vec4<f32> = gAccum_0[base_3];
        var _S59 : vec3<f32> = gAccum_0[base_3].xyz + contribution_2;
        path_0.x = _S59.x;
        path_0.y = _S59.y;
        path_0.z = _S59.z;
        gAccum_0[base_3] = path_0;
        gAccum_0[Field_0(base_3, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn HeaderBase_0() -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3);
}

fn MainQueueBase_0() -> u32
{
    return HeaderBase_0() + u32(3) + gWavefront_0.capacity_0 * u32(21);
}

fn ShadowQueueBase_0() -> u32
{
    return MainQueueBase_0() + u32(2) * ((gWavefront_0.capacity_0 + u32(3)) / u32(4));
}

fn QueueIndex_0( base_5 : u32,  index_2 : u32) -> u32
{
    return (bitcast<u32>((gAccum_0[base_5 + index_2 / u32(4)][(index_2 & (u32(3)))])));
}

fn ShadowParallelImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var _S60 : vec3<f32> = vec3<f32>(0.0f);
    var _S61 : u32 = local_1.y;
    var _S62 : u32 = _S61 * u32(2);
    var _S63 : u32 = tid_1.x;
    var _S64 : bool = (_S63 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S65 : bool;
    var value_1 : vec3<f32>;
    var lightDirection_1 : vec3<f32>;
    var flags_4 : u32;
    var mask_2 : u32;
    var base_6 : u32;
    if(_S64)
    {
        var base_7 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S63));
        var mask_3 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_7, u32(11))].z)));
        if(((mask_3 & (((u32(1) << (_S62)))))) != u32(0))
        {
            var offset_1 : u32 = u32(12) + _S62 * u32(3);
            var origin_2 : vec4<f32> = gAccum_0[Field_0(base_7, offset_1)];
            var flags_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_7, offset_1 + u32(1))].w)));
            var _S66 : vec3<f32> = gAccum_0[Field_0(base_7, offset_1 + u32(1))].xyz;
            if(((flags_5 & (u32(1)))) == u32(0))
            {
                _S65 = true;
            }
            else
            {
                var _S67 : bool = TraceOcclusion_0(Ray_x24init_0(origin_2.xyz, _S66, origin_2.w));
                _S65 = !_S67;
            }
            if(_S65)
            {
                value_1 = gAccum_0[Field_0(base_7, offset_1 + u32(2))].xyz;
            }
            else
            {
                value_1 = _S60;
            }
            flags_4 = flags_5;
            lightDirection_1 = _S66;
        }
        else
        {
            value_1 = _S60;
            flags_4 = u32(0);
            lightDirection_1 = _S60;
        }
        mask_2 = mask_3;
        base_6 = base_7;
    }
    else
    {
        value_1 = _S60;
        flags_4 = u32(0);
        lightDirection_1 = _S60;
        mask_2 = u32(0);
        base_6 = u32(0);
    }
    var _S68 : u32 = local_1.x;
    var _S69 : u32 = _S61 * u32(64) + _S68;
    gContributions_0[_S69] = value_1;
    var laneDiffuse_1 : vec3<f32> = _S60;
    var laneSpecular_1 : vec3<f32>;
    var laneBypass_1 : vec3<f32> = _S60;
    var _S70 : bool = ((flags_4 & (u32(2)))) != u32(0);
    if(_S70)
    {
        NrdSplitDirect_0(flags_4, value_1, &(laneDiffuse_1), &(laneSpecular_1), &(laneBypass_1));
    }
    gNrdDiffuse_0[_S69] = vec4<f32>(laneDiffuse_1, f32(_S70));
    gNrdBypass_0[_S69] = laneBypass_1;
    gNrdDiffuseDirection_0[_S69] = vec3<f32>(Luminance_0(laneDiffuse_1)) * lightDirection_1;
    if(_S70)
    {
        value_1 = vec3<f32>(Luminance_0(laneSpecular_1)) * lightDirection_1;
    }
    else
    {
        value_1 = _S60;
    }
    gNrdSpecularDirection_0[_S69] = value_1;
    workgroupBarrier();
    if(_S62 == u32(0))
    {
        _S65 = _S64;
    }
    else
    {
        _S65 = false;
    }
    if(_S65)
    {
        _S65 = mask_2 != u32(0);
    }
    else
    {
        _S65 = false;
    }
    if(_S65)
    {
        var _S71 : u32 = u32(64) + _S68;
        var sum_1 : vec3<f32> = gContributions_0[_S68] + gContributions_0[_S71];
        var throughput_1 : vec4<f32> = gAccum_0[Field_0(base_6, u32(10))];
        var diffuse_2 : vec4<f32> = gNrdDiffuse_0[_S68] + gNrdDiffuse_0[_S71];
        var bypass_2 : vec3<f32> = gNrdBypass_0[_S68] + gNrdBypass_0[_S71];
        var diffuseDirection_1 : vec3<f32> = gNrdDiffuseDirection_0[_S68] + gNrdDiffuseDirection_0[_S71];
        var specularDirection_1 : vec3<f32> = gNrdSpecularDirection_0[_S68] + gNrdSpecularDirection_0[_S71];
        if(((diffuse_2.w) > 0.0f))
        {
            var r_1 : u32 = NrdBase_0(base_6);
            var _S72 : vec3<f32> = throughput_1.xyz;
            var _S73 : vec3<f32> = gAccum_0[r_1].xyz + _S72 * bypass_2;
            gAccum_0[r_1].x = _S73.x;
            gAccum_0[r_1].y = _S73.y;
            gAccum_0[r_1].z = _S73.z;
            var _S74 : u32 = r_1 + u32(1);
            var _S75 : vec3<f32> = diffuse_2.xyz;
            var _S76 : vec3<f32> = gAccum_0[_S74].xyz + _S72 * _S75;
            gAccum_0[_S74].x = _S76.x;
            gAccum_0[_S74].y = _S76.y;
            gAccum_0[_S74].z = _S76.z;
            var _S77 : u32 = r_1 + u32(2);
            var _S78 : vec3<f32> = gAccum_0[_S77].xyz + _S72 * (sum_1 - _S75 - bypass_2);
            gAccum_0[_S77].x = _S78.x;
            gAccum_0[_S77].y = _S78.y;
            gAccum_0[_S77].z = _S78.z;
            var _S79 : u32 = r_1 + u32(3);
            var _S80 : vec3<f32> = vec3<f32>(Luminance_0(_S72));
            var _S81 : vec3<f32> = gAccum_0[_S79].xyz + _S80 * diffuseDirection_1;
            gAccum_0[_S79].x = _S81.x;
            gAccum_0[_S79].y = _S81.y;
            gAccum_0[_S79].z = _S81.z;
            var _S82 : u32 = r_1 + u32(4);
            var _S83 : vec3<f32> = gAccum_0[_S82].xyz + _S80 * specularDirection_1;
            gAccum_0[_S82].x = _S83.x;
            gAccum_0[_S82].y = _S83.y;
            gAccum_0[_S82].z = _S83.z;
        }
        var contribution_3 : vec3<f32> = throughput_1.xyz * sum_1;
        var _S84 : f32 = throughput_1.w;
        var contribution_4 : vec3<f32>;
        if((_S84 > 0.0f))
        {
            contribution_4 = min(contribution_3, vec3<f32>(_S84));
        }
        else
        {
            contribution_4 = contribution_3;
        }
        var path_1 : vec4<f32> = gAccum_0[base_6];
        var _S85 : vec3<f32> = gAccum_0[base_6].xyz + contribution_4;
        path_1.x = _S85.x;
        path_1.y = _S85.y;
        path_1.z = _S85.z;
        gAccum_0[base_6] = path_1;
        gAccum_0[Field_0(base_6, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_2( tid_2 : vec3<u32>,  local_2 : vec3<u32>)
{
    var _S86 : vec3<f32> = vec3<f32>(0.0f);
    var _S87 : u32 = local_2.y;
    var _S88 : u32 = tid_2.x;
    var _S89 : bool = (_S88 < (gWavefront_0.pathCount_0));
    var _S90 : bool;
    var value_2 : vec3<f32>;
    var lightDirection_2 : vec3<f32>;
    var flags_6 : u32;
    var mask_4 : u32;
    var base_8 : u32;
    if(_S89)
    {
        var base_9 : u32 = WorkBase_0(_S88);
        var mask_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_9, u32(11))].z)));
        if(((mask_5 & (((u32(1) << (_S87)))))) != u32(0))
        {
            var offset_2 : u32 = u32(12) + _S87 * u32(3);
            var origin_3 : vec4<f32> = gAccum_0[Field_0(base_9, offset_2)];
            var flags_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_9, offset_2 + u32(1))].w)));
            var _S91 : vec3<f32> = gAccum_0[Field_0(base_9, offset_2 + u32(1))].xyz;
            if(((flags_7 & (u32(1)))) == u32(0))
            {
                _S90 = true;
            }
            else
            {
                var _S92 : bool = TraceOcclusion_0(Ray_x24init_0(origin_3.xyz, _S91, origin_3.w));
                _S90 = !_S92;
            }
            if(_S90)
            {
                value_2 = gAccum_0[Field_0(base_9, offset_2 + u32(2))].xyz;
            }
            else
            {
                value_2 = _S86;
            }
            flags_6 = flags_7;
            lightDirection_2 = _S91;
        }
        else
        {
            value_2 = _S86;
            flags_6 = u32(0);
            lightDirection_2 = _S86;
        }
        mask_4 = mask_5;
        base_8 = base_9;
    }
    else
    {
        value_2 = _S86;
        flags_6 = u32(0);
        lightDirection_2 = _S86;
        mask_4 = u32(0);
        base_8 = u32(0);
    }
    var _S93 : u32 = local_2.x;
    var _S94 : u32 = _S87 * u32(64) + _S93;
    gContributions_0[_S94] = value_2;
    var laneDiffuse_2 : vec3<f32> = _S86;
    var laneSpecular_2 : vec3<f32>;
    var laneBypass_2 : vec3<f32> = _S86;
    var _S95 : bool = ((flags_6 & (u32(2)))) != u32(0);
    if(_S95)
    {
        NrdSplitDirect_0(flags_6, value_2, &(laneDiffuse_2), &(laneSpecular_2), &(laneBypass_2));
    }
    gNrdDiffuse_0[_S94] = vec4<f32>(laneDiffuse_2, f32(_S95));
    gNrdBypass_0[_S94] = laneBypass_2;
    gNrdDiffuseDirection_0[_S94] = vec3<f32>(Luminance_0(laneDiffuse_2)) * lightDirection_2;
    if(_S95)
    {
        value_2 = vec3<f32>(Luminance_0(laneSpecular_2)) * lightDirection_2;
    }
    else
    {
        value_2 = _S86;
    }
    gNrdSpecularDirection_0[_S94] = value_2;
    workgroupBarrier();
    if(_S87 == u32(0))
    {
        _S90 = _S89;
    }
    else
    {
        _S90 = false;
    }
    if(_S90)
    {
        _S90 = mask_4 != u32(0);
    }
    else
    {
        _S90 = false;
    }
    if(_S90)
    {
        var _S96 : u32 = u32(64) + _S93;
        var _S97 : u32 = u32(128) + _S93;
        var sum_2 : vec3<f32> = gContributions_0[_S93] + gContributions_0[_S96] + gContributions_0[_S97];
        var throughput_2 : vec4<f32> = gAccum_0[Field_0(base_8, u32(10))];
        var diffuse_3 : vec4<f32> = gNrdDiffuse_0[_S93] + gNrdDiffuse_0[_S96] + gNrdDiffuse_0[_S97];
        var bypass_3 : vec3<f32> = gNrdBypass_0[_S93] + gNrdBypass_0[_S96] + gNrdBypass_0[_S97];
        var diffuseDirection_2 : vec3<f32> = gNrdDiffuseDirection_0[_S93] + gNrdDiffuseDirection_0[_S96] + gNrdDiffuseDirection_0[_S97];
        var specularDirection_2 : vec3<f32> = gNrdSpecularDirection_0[_S93] + gNrdSpecularDirection_0[_S96] + gNrdSpecularDirection_0[_S97];
        if(((diffuse_3.w) > 0.0f))
        {
            var r_2 : u32 = NrdBase_0(base_8);
            var _S98 : vec3<f32> = throughput_2.xyz;
            var _S99 : vec3<f32> = gAccum_0[r_2].xyz + _S98 * bypass_3;
            gAccum_0[r_2].x = _S99.x;
            gAccum_0[r_2].y = _S99.y;
            gAccum_0[r_2].z = _S99.z;
            var _S100 : u32 = r_2 + u32(1);
            var _S101 : vec3<f32> = diffuse_3.xyz;
            var _S102 : vec3<f32> = gAccum_0[_S100].xyz + _S98 * _S101;
            gAccum_0[_S100].x = _S102.x;
            gAccum_0[_S100].y = _S102.y;
            gAccum_0[_S100].z = _S102.z;
            var _S103 : u32 = r_2 + u32(2);
            var _S104 : vec3<f32> = gAccum_0[_S103].xyz + _S98 * (sum_2 - _S101 - bypass_3);
            gAccum_0[_S103].x = _S104.x;
            gAccum_0[_S103].y = _S104.y;
            gAccum_0[_S103].z = _S104.z;
            var _S105 : u32 = r_2 + u32(3);
            var _S106 : vec3<f32> = vec3<f32>(Luminance_0(_S98));
            var _S107 : vec3<f32> = gAccum_0[_S105].xyz + _S106 * diffuseDirection_2;
            gAccum_0[_S105].x = _S107.x;
            gAccum_0[_S105].y = _S107.y;
            gAccum_0[_S105].z = _S107.z;
            var _S108 : u32 = r_2 + u32(4);
            var _S109 : vec3<f32> = gAccum_0[_S108].xyz + _S106 * specularDirection_2;
            gAccum_0[_S108].x = _S109.x;
            gAccum_0[_S108].y = _S109.y;
            gAccum_0[_S108].z = _S109.z;
        }
        var contribution_5 : vec3<f32> = throughput_2.xyz * sum_2;
        var _S110 : f32 = throughput_2.w;
        var contribution_6 : vec3<f32>;
        if((_S110 > 0.0f))
        {
            contribution_6 = min(contribution_5, vec3<f32>(_S110));
        }
        else
        {
            contribution_6 = contribution_5;
        }
        var path_2 : vec4<f32> = gAccum_0[base_8];
        var _S111 : vec3<f32> = gAccum_0[base_8].xyz + contribution_6;
        path_2.x = _S111.x;
        path_2.y = _S111.y;
        path_2.z = _S111.z;
        gAccum_0[base_8] = path_2;
        gAccum_0[Field_0(base_8, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_3( tid_3 : vec3<u32>,  local_3 : vec3<u32>)
{
    var _S112 : vec3<f32> = vec3<f32>(0.0f);
    var _S113 : u32 = local_3.y;
    var _S114 : u32 = tid_3.x;
    var _S115 : bool = (_S114 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S116 : bool;
    var value_3 : vec3<f32>;
    var lightDirection_3 : vec3<f32>;
    var flags_8 : u32;
    var mask_6 : u32;
    var base_10 : u32;
    if(_S115)
    {
        var base_11 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S114));
        var mask_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_11, u32(11))].z)));
        if(((mask_7 & (((u32(1) << (_S113)))))) != u32(0))
        {
            var offset_3 : u32 = u32(12) + _S113 * u32(3);
            var origin_4 : vec4<f32> = gAccum_0[Field_0(base_11, offset_3)];
            var flags_9 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_11, offset_3 + u32(1))].w)));
            var _S117 : vec3<f32> = gAccum_0[Field_0(base_11, offset_3 + u32(1))].xyz;
            if(((flags_9 & (u32(1)))) == u32(0))
            {
                _S116 = true;
            }
            else
            {
                var _S118 : bool = TraceOcclusion_0(Ray_x24init_0(origin_4.xyz, _S117, origin_4.w));
                _S116 = !_S118;
            }
            if(_S116)
            {
                value_3 = gAccum_0[Field_0(base_11, offset_3 + u32(2))].xyz;
            }
            else
            {
                value_3 = _S112;
            }
            flags_8 = flags_9;
            lightDirection_3 = _S117;
        }
        else
        {
            value_3 = _S112;
            flags_8 = u32(0);
            lightDirection_3 = _S112;
        }
        mask_6 = mask_7;
        base_10 = base_11;
    }
    else
    {
        value_3 = _S112;
        flags_8 = u32(0);
        lightDirection_3 = _S112;
        mask_6 = u32(0);
        base_10 = u32(0);
    }
    var _S119 : u32 = local_3.x;
    var _S120 : u32 = _S113 * u32(64) + _S119;
    gContributions_0[_S120] = value_3;
    var laneDiffuse_3 : vec3<f32> = _S112;
    var laneSpecular_3 : vec3<f32>;
    var laneBypass_3 : vec3<f32> = _S112;
    var _S121 : bool = ((flags_8 & (u32(2)))) != u32(0);
    if(_S121)
    {
        NrdSplitDirect_0(flags_8, value_3, &(laneDiffuse_3), &(laneSpecular_3), &(laneBypass_3));
    }
    gNrdDiffuse_0[_S120] = vec4<f32>(laneDiffuse_3, f32(_S121));
    gNrdBypass_0[_S120] = laneBypass_3;
    gNrdDiffuseDirection_0[_S120] = vec3<f32>(Luminance_0(laneDiffuse_3)) * lightDirection_3;
    if(_S121)
    {
        value_3 = vec3<f32>(Luminance_0(laneSpecular_3)) * lightDirection_3;
    }
    else
    {
        value_3 = _S112;
    }
    gNrdSpecularDirection_0[_S120] = value_3;
    workgroupBarrier();
    if(_S113 == u32(0))
    {
        _S116 = _S115;
    }
    else
    {
        _S116 = false;
    }
    if(_S116)
    {
        _S116 = mask_6 != u32(0);
    }
    else
    {
        _S116 = false;
    }
    if(_S116)
    {
        var _S122 : u32 = u32(64) + _S119;
        var _S123 : u32 = u32(128) + _S119;
        var sum_3 : vec3<f32> = gContributions_0[_S119] + gContributions_0[_S122] + gContributions_0[_S123];
        var throughput_3 : vec4<f32> = gAccum_0[Field_0(base_10, u32(10))];
        var diffuse_4 : vec4<f32> = gNrdDiffuse_0[_S119] + gNrdDiffuse_0[_S122] + gNrdDiffuse_0[_S123];
        var bypass_4 : vec3<f32> = gNrdBypass_0[_S119] + gNrdBypass_0[_S122] + gNrdBypass_0[_S123];
        var diffuseDirection_3 : vec3<f32> = gNrdDiffuseDirection_0[_S119] + gNrdDiffuseDirection_0[_S122] + gNrdDiffuseDirection_0[_S123];
        var specularDirection_3 : vec3<f32> = gNrdSpecularDirection_0[_S119] + gNrdSpecularDirection_0[_S122] + gNrdSpecularDirection_0[_S123];
        if(((diffuse_4.w) > 0.0f))
        {
            var r_3 : u32 = NrdBase_0(base_10);
            var _S124 : vec3<f32> = throughput_3.xyz;
            var _S125 : vec3<f32> = gAccum_0[r_3].xyz + _S124 * bypass_4;
            gAccum_0[r_3].x = _S125.x;
            gAccum_0[r_3].y = _S125.y;
            gAccum_0[r_3].z = _S125.z;
            var _S126 : u32 = r_3 + u32(1);
            var _S127 : vec3<f32> = diffuse_4.xyz;
            var _S128 : vec3<f32> = gAccum_0[_S126].xyz + _S124 * _S127;
            gAccum_0[_S126].x = _S128.x;
            gAccum_0[_S126].y = _S128.y;
            gAccum_0[_S126].z = _S128.z;
            var _S129 : u32 = r_3 + u32(2);
            var _S130 : vec3<f32> = gAccum_0[_S129].xyz + _S124 * (sum_3 - _S127 - bypass_4);
            gAccum_0[_S129].x = _S130.x;
            gAccum_0[_S129].y = _S130.y;
            gAccum_0[_S129].z = _S130.z;
            var _S131 : u32 = r_3 + u32(3);
            var _S132 : vec3<f32> = vec3<f32>(Luminance_0(_S124));
            var _S133 : vec3<f32> = gAccum_0[_S131].xyz + _S132 * diffuseDirection_3;
            gAccum_0[_S131].x = _S133.x;
            gAccum_0[_S131].y = _S133.y;
            gAccum_0[_S131].z = _S133.z;
            var _S134 : u32 = r_3 + u32(4);
            var _S135 : vec3<f32> = gAccum_0[_S134].xyz + _S132 * specularDirection_3;
            gAccum_0[_S134].x = _S135.x;
            gAccum_0[_S134].y = _S135.y;
            gAccum_0[_S134].z = _S135.z;
        }
        var contribution_7 : vec3<f32> = throughput_3.xyz * sum_3;
        var _S136 : f32 = throughput_3.w;
        var contribution_8 : vec3<f32>;
        if((_S136 > 0.0f))
        {
            contribution_8 = min(contribution_7, vec3<f32>(_S136));
        }
        else
        {
            contribution_8 = contribution_7;
        }
        var path_3 : vec4<f32> = gAccum_0[base_10];
        var _S137 : vec3<f32> = gAccum_0[base_10].xyz + contribution_8;
        path_3.x = _S137.x;
        path_3.y = _S137.y;
        path_3.z = _S137.z;
        gAccum_0[base_10] = path_3;
        gAccum_0[Field_0(base_10, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

@compute
@workgroup_size(64, 3, 1)
fn ShadowOpaqueParallel(@builtin(global_invocation_id) tid_4 : vec3<u32>, @builtin(local_invocation_id) local_4 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    ShadowParallelImpl_3(tid_4, local_4);
    return;
}

@compute
@workgroup_size(64, 3, 1)
fn ShadowOpaqueParallelDirect(@builtin(global_invocation_id) tid_5 : vec3<u32>, @builtin(local_invocation_id) local_5 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    ShadowParallelImpl_2(tid_5, local_5);
    return;
}

@compute
@workgroup_size(64, 2, 1)
fn ShadowOpaqueParallelSky(@builtin(global_invocation_id) tid_6 : vec3<u32>, @builtin(local_invocation_id) local_6 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    ShadowParallelImpl_1(tid_6, local_6);
    return;
}

@compute
@workgroup_size(64, 2, 1)
fn ShadowOpaqueParallelSkyDirect(@builtin(global_invocation_id) tid_7 : vec3<u32>, @builtin(local_invocation_id) local_7 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    ShadowParallelImpl_0(tid_7, local_7);
    return;
}

