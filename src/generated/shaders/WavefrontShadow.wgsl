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
        var node_1 : BVHNode_std430_0 = gNodes_0[nodeRef_1];
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

fn ShadowParallelImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var _S30 : u32 = local_0.y;
    var _S31 : u32 = _S30 * u32(2);
    var _S32 : vec3<f32> = vec3<f32>(0.0f);
    var _S33 : u32 = tid_0.x;
    var _S34 : bool = (_S33 < (gWavefront_0.pathCount_0));
    var _S35 : bool;
    var value_0 : vec3<f32>;
    var mask_0 : u32;
    var base_2 : u32;
    if(_S34)
    {
        var base_3 : u32 = WorkBase_0(_S33);
        var mask_1 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_3, u32(11))].z)));
        if(((mask_1 & (((u32(1) << (_S31)))))) != u32(0))
        {
            var offset_0 : u32 = u32(12) + _S31 * u32(3);
            var origin_1 : vec4<f32> = gAccum_0[Field_0(base_3, offset_0)];
            var direction_1 : vec4<f32> = gAccum_0[Field_0(base_3, offset_0 + u32(1))];
            if((bitcast<u32>((gAccum_0[Field_0(base_3, offset_0 + u32(1))].w))) == u32(0))
            {
                _S35 = true;
            }
            else
            {
                var _S36 : bool = TraceOcclusion_0(Ray_x24init_0(origin_1.xyz, direction_1.xyz, origin_1.w));
                _S35 = !_S36;
            }
            if(_S35)
            {
                value_0 = gAccum_0[Field_0(base_3, offset_0 + u32(2))].xyz;
            }
            else
            {
                value_0 = _S32;
            }
        }
        else
        {
            value_0 = _S32;
        }
        mask_0 = mask_1;
        base_2 = base_3;
    }
    else
    {
        value_0 = _S32;
        mask_0 = u32(0);
        base_2 = u32(0);
    }
    var _S37 : u32 = local_0.x;
    gContributions_0[_S30 * u32(64) + _S37] = value_0;
    workgroupBarrier();
    if(_S31 == u32(0))
    {
        _S35 = _S34;
    }
    else
    {
        _S35 = false;
    }
    if(_S35)
    {
        _S35 = mask_0 != u32(0);
    }
    else
    {
        _S35 = false;
    }
    if(_S35)
    {
        var contribution_0 : vec3<f32> = gAccum_0[Field_0(base_2, u32(10))].xyz * (gContributions_0[_S37] + gContributions_0[u32(64) + _S37]);
        var _S38 : f32 = gAccum_0[Field_0(base_2, u32(10))].w;
        var contribution_1 : vec3<f32>;
        if((_S38 > 0.0f))
        {
            contribution_1 = min(contribution_0, vec3<f32>(_S38));
        }
        else
        {
            contribution_1 = contribution_0;
        }
        var path_0 : vec4<f32> = gAccum_0[base_2];
        var _S39 : vec3<f32> = gAccum_0[base_2].xyz + contribution_1;
        path_0.x = _S39.x;
        path_0.y = _S39.y;
        path_0.z = _S39.z;
        gAccum_0[base_2] = path_0;
        gAccum_0[Field_0(base_2, u32(11))] = vec4<f32>(0.0f);
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

fn QueueIndex_0( base_4 : u32,  index_1 : u32) -> u32
{
    return (bitcast<u32>((gAccum_0[base_4 + index_1 / u32(4)][(index_1 & (u32(3)))])));
}

fn ShadowParallelImpl_1( tid_1 : vec3<u32>,  local_1 : vec3<u32>)
{
    var _S40 : u32 = local_1.y;
    var _S41 : u32 = _S40 * u32(2);
    var _S42 : vec3<f32> = vec3<f32>(0.0f);
    var _S43 : u32 = tid_1.x;
    var _S44 : bool = (_S43 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S45 : bool;
    var value_1 : vec3<f32>;
    var mask_2 : u32;
    var base_5 : u32;
    if(_S44)
    {
        var base_6 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S43));
        var mask_3 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_6, u32(11))].z)));
        if(((mask_3 & (((u32(1) << (_S41)))))) != u32(0))
        {
            var offset_1 : u32 = u32(12) + _S41 * u32(3);
            var origin_2 : vec4<f32> = gAccum_0[Field_0(base_6, offset_1)];
            var direction_2 : vec4<f32> = gAccum_0[Field_0(base_6, offset_1 + u32(1))];
            if((bitcast<u32>((gAccum_0[Field_0(base_6, offset_1 + u32(1))].w))) == u32(0))
            {
                _S45 = true;
            }
            else
            {
                var _S46 : bool = TraceOcclusion_0(Ray_x24init_0(origin_2.xyz, direction_2.xyz, origin_2.w));
                _S45 = !_S46;
            }
            if(_S45)
            {
                value_1 = gAccum_0[Field_0(base_6, offset_1 + u32(2))].xyz;
            }
            else
            {
                value_1 = _S42;
            }
        }
        else
        {
            value_1 = _S42;
        }
        mask_2 = mask_3;
        base_5 = base_6;
    }
    else
    {
        value_1 = _S42;
        mask_2 = u32(0);
        base_5 = u32(0);
    }
    var _S47 : u32 = local_1.x;
    gContributions_0[_S40 * u32(64) + _S47] = value_1;
    workgroupBarrier();
    if(_S41 == u32(0))
    {
        _S45 = _S44;
    }
    else
    {
        _S45 = false;
    }
    if(_S45)
    {
        _S45 = mask_2 != u32(0);
    }
    else
    {
        _S45 = false;
    }
    if(_S45)
    {
        var contribution_2 : vec3<f32> = gAccum_0[Field_0(base_5, u32(10))].xyz * (gContributions_0[_S47] + gContributions_0[u32(64) + _S47]);
        var _S48 : f32 = gAccum_0[Field_0(base_5, u32(10))].w;
        var contribution_3 : vec3<f32>;
        if((_S48 > 0.0f))
        {
            contribution_3 = min(contribution_2, vec3<f32>(_S48));
        }
        else
        {
            contribution_3 = contribution_2;
        }
        var path_1 : vec4<f32> = gAccum_0[base_5];
        var _S49 : vec3<f32> = gAccum_0[base_5].xyz + contribution_3;
        path_1.x = _S49.x;
        path_1.y = _S49.y;
        path_1.z = _S49.z;
        gAccum_0[base_5] = path_1;
        gAccum_0[Field_0(base_5, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_2( tid_2 : vec3<u32>,  local_2 : vec3<u32>)
{
    var _S50 : u32 = local_2.y;
    var _S51 : vec3<f32> = vec3<f32>(0.0f);
    var _S52 : u32 = tid_2.x;
    var _S53 : bool = (_S52 < (gWavefront_0.pathCount_0));
    var _S54 : bool;
    var value_2 : vec3<f32>;
    var mask_4 : u32;
    var base_7 : u32;
    if(_S53)
    {
        var base_8 : u32 = WorkBase_0(_S52);
        var mask_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_8, u32(11))].z)));
        if(((mask_5 & (((u32(1) << (_S50)))))) != u32(0))
        {
            var offset_2 : u32 = u32(12) + _S50 * u32(3);
            var origin_3 : vec4<f32> = gAccum_0[Field_0(base_8, offset_2)];
            var direction_3 : vec4<f32> = gAccum_0[Field_0(base_8, offset_2 + u32(1))];
            if((bitcast<u32>((gAccum_0[Field_0(base_8, offset_2 + u32(1))].w))) == u32(0))
            {
                _S54 = true;
            }
            else
            {
                var _S55 : bool = TraceOcclusion_0(Ray_x24init_0(origin_3.xyz, direction_3.xyz, origin_3.w));
                _S54 = !_S55;
            }
            if(_S54)
            {
                value_2 = gAccum_0[Field_0(base_8, offset_2 + u32(2))].xyz;
            }
            else
            {
                value_2 = _S51;
            }
        }
        else
        {
            value_2 = _S51;
        }
        mask_4 = mask_5;
        base_7 = base_8;
    }
    else
    {
        value_2 = _S51;
        mask_4 = u32(0);
        base_7 = u32(0);
    }
    var _S56 : u32 = local_2.x;
    gContributions_0[_S50 * u32(64) + _S56] = value_2;
    workgroupBarrier();
    if(_S50 == u32(0))
    {
        _S54 = _S53;
    }
    else
    {
        _S54 = false;
    }
    if(_S54)
    {
        _S54 = mask_4 != u32(0);
    }
    else
    {
        _S54 = false;
    }
    if(_S54)
    {
        var contribution_4 : vec3<f32> = gAccum_0[Field_0(base_7, u32(10))].xyz * (gContributions_0[_S56] + gContributions_0[u32(64) + _S56] + gContributions_0[u32(128) + _S56]);
        var _S57 : f32 = gAccum_0[Field_0(base_7, u32(10))].w;
        var contribution_5 : vec3<f32>;
        if((_S57 > 0.0f))
        {
            contribution_5 = min(contribution_4, vec3<f32>(_S57));
        }
        else
        {
            contribution_5 = contribution_4;
        }
        var path_2 : vec4<f32> = gAccum_0[base_7];
        var _S58 : vec3<f32> = gAccum_0[base_7].xyz + contribution_5;
        path_2.x = _S58.x;
        path_2.y = _S58.y;
        path_2.z = _S58.z;
        gAccum_0[base_7] = path_2;
        gAccum_0[Field_0(base_7, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_3( tid_3 : vec3<u32>,  local_3 : vec3<u32>)
{
    var _S59 : u32 = local_3.y;
    var _S60 : vec3<f32> = vec3<f32>(0.0f);
    var _S61 : u32 = tid_3.x;
    var _S62 : bool = (_S61 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S63 : bool;
    var value_3 : vec3<f32>;
    var mask_6 : u32;
    var base_9 : u32;
    if(_S62)
    {
        var base_10 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S61));
        var mask_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_10, u32(11))].z)));
        if(((mask_7 & (((u32(1) << (_S59)))))) != u32(0))
        {
            var offset_3 : u32 = u32(12) + _S59 * u32(3);
            var origin_4 : vec4<f32> = gAccum_0[Field_0(base_10, offset_3)];
            var direction_4 : vec4<f32> = gAccum_0[Field_0(base_10, offset_3 + u32(1))];
            if((bitcast<u32>((gAccum_0[Field_0(base_10, offset_3 + u32(1))].w))) == u32(0))
            {
                _S63 = true;
            }
            else
            {
                var _S64 : bool = TraceOcclusion_0(Ray_x24init_0(origin_4.xyz, direction_4.xyz, origin_4.w));
                _S63 = !_S64;
            }
            if(_S63)
            {
                value_3 = gAccum_0[Field_0(base_10, offset_3 + u32(2))].xyz;
            }
            else
            {
                value_3 = _S60;
            }
        }
        else
        {
            value_3 = _S60;
        }
        mask_6 = mask_7;
        base_9 = base_10;
    }
    else
    {
        value_3 = _S60;
        mask_6 = u32(0);
        base_9 = u32(0);
    }
    var _S65 : u32 = local_3.x;
    gContributions_0[_S59 * u32(64) + _S65] = value_3;
    workgroupBarrier();
    if(_S59 == u32(0))
    {
        _S63 = _S62;
    }
    else
    {
        _S63 = false;
    }
    if(_S63)
    {
        _S63 = mask_6 != u32(0);
    }
    else
    {
        _S63 = false;
    }
    if(_S63)
    {
        var contribution_6 : vec3<f32> = gAccum_0[Field_0(base_9, u32(10))].xyz * (gContributions_0[_S65] + gContributions_0[u32(64) + _S65] + gContributions_0[u32(128) + _S65]);
        var _S66 : f32 = gAccum_0[Field_0(base_9, u32(10))].w;
        var contribution_7 : vec3<f32>;
        if((_S66 > 0.0f))
        {
            contribution_7 = min(contribution_6, vec3<f32>(_S66));
        }
        else
        {
            contribution_7 = contribution_6;
        }
        var path_3 : vec4<f32> = gAccum_0[base_9];
        var _S67 : vec3<f32> = gAccum_0[base_9].xyz + contribution_7;
        path_3.x = _S67.x;
        path_3.y = _S67.y;
        path_3.z = _S67.z;
        gAccum_0[base_9] = path_3;
        gAccum_0[Field_0(base_9, u32(11))] = vec4<f32>(0.0f);
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

