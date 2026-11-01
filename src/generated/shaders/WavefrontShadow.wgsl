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

@binding(5) @group(0) var<storage, read> gIndices_0 : array<u32>;

@binding(1) @group(0) var<storage, read> gNodes_0 : array<vec4<f32>>;

struct HitRecord_0
{
     t_0 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_0 : u32,
     primitiveIndex_0 : u32,
};

var<private> gTraversalCost_0 : u32;

fn rcp_0( x_0 : f32) -> f32
{
    return 1.0f / x_0;
}

fn IntersectTriangle_0( o_0 : vec3<f32>,  d_0 : vec3<f32>,  v0_0 : vec3<f32>,  e1_0 : vec3<f32>,  e2_0 : vec3<f32>,  tMin_0 : f32,  tMax_0 : f32,  t_1 : ptr<function, f32>,  bary_0 : ptr<function, vec2<f32>>) -> bool
{
    (*t_1) = 0.0f;
    (*bary_0) = vec2<f32>(0.0f);
    var h_0 : vec3<f32> = cross(d_0, e2_0);
    var a_0 : f32 = dot(e1_0, h_0);
    if(a_0 == 0.0f)
    {
        return false;
    }
    var f_0 : f32 = rcp_0(a_0);
    var s_0 : vec3<f32> = o_0 - v0_0;
    var u_0 : f32 = f_0 * dot(s_0, h_0);
    var _S1 : bool;
    if((u_0 < 0.0f))
    {
        _S1 = true;
    }
    else
    {
        _S1 = (u_0 > 1.0f);
    }
    if(_S1)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_0, e1_0);
    var v_0 : f32 = f_0 * dot(d_0, q_0);
    if((v_0 < 0.0f))
    {
        _S1 = true;
    }
    else
    {
        _S1 = ((u_0 + v_0) > 1.0f);
    }
    if(_S1)
    {
        return false;
    }
    (*t_1) = f_0 * dot(e2_0, q_0);
    (*bary_0) = vec2<f32>(u_0, v_0);
    if(((*t_1) > tMin_0))
    {
        _S1 = ((*t_1) < tMax_0);
    }
    else
    {
        _S1 = false;
    }
    return _S1;
}

fn IntersectSlot_0( slot_0 : u32,  instanceIndex_1 : u32,  blasTriOffset_1 : u32,  merged_0 : bool,  alphaTested_0 : bool,  o_1 : vec3<f32>,  d_1 : vec3<f32>,  tMin_1 : f32,  hit_0 : ptr<function, HitRecord_0>) -> bool
{
    gTraversalCost_0 = gTraversalCost_0 + u32(1);
    var base_0 : u32 = (blasTriOffset_1 + slot_0) * u32(3);
    var v0_1 : vec4<f32> = gTris_0[base_0];
    var e1_1 : vec4<f32> = gTris_0[base_0 + u32(1)];
    var t_2 : f32;
    var bary_1 : vec2<f32>;
    var _S2 : bool = IntersectTriangle_0(o_1, d_1, v0_1.xyz, e1_1.xyz, gTris_0[base_0 + u32(2)].xyz, tMin_1, (*hit_0).t_0, &(t_2), &(bary_1));
    if(!_S2)
    {
        return false;
    }
    var primitiveIndex_1 : u32 = (bitcast<u32>((v0_1.w)));
    var _S3 : u32;
    if(merged_0)
    {
        _S3 = (bitcast<u32>((e1_1.w)));
    }
    else
    {
        _S3 = instanceIndex_1;
    }
    (*hit_0).t_0 = t_2;
    (*hit_0).barycentrics_0 = bary_1;
    (*hit_0).instanceIndex_0 = _S3;
    (*hit_0).primitiveIndex_0 = primitiveIndex_1;
    return true;
}

struct Ray_0
{
     origin_0 : vec3<f32>,
     tMin_2 : f32,
     direction_0 : vec3<f32>,
     tMax_1 : f32,
};

fn rcp_1( x_1 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_1;
}

fn SafeRcp_0( d_2 : vec3<f32>) -> vec3<f32>
{
    return rcp_1(select(d_2, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_2 < vec3<f32>(0.0f))), ((abs(d_2)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn firstbithigh_0( value_0 : u32) -> u32
{
    var _S4 : u32 = firstLeadingBit(value_0);
    return _S4;
}

var<private> gTraversalStack_0 : array<vec2<u32>, i32(32)>;

fn SignExtendS8x4_0( i_0 : u32) -> u32
{
    return ((((i_0 >> (u32(7)))) & (u32(16843009)))) * u32(255);
}

fn CwbvhChildHits_0( meta4_0 : u32,  lo_0 : vec3<u32>,  hi_0 : vec3<u32>,  scale_0 : vec3<f32>,  origin_1 : vec3<f32>,  tMin_3 : f32,  tMax_2 : f32,  octinv_0 : u32) -> u32
{
    var _S5 : u32 = (((meta4_0 ^ (((octinv_0 & ((SignExtendS8x4_0((((((meta4_0 & (((meta4_0 << (u32(1))))))) & (u32(269488144)))) << (u32(3))))))))))) & (u32(522133279)));
    var _S6 : u32 = (((meta4_0 >> (u32(5)))) & (u32(117901063)));
    var i_1 : u32 = u32(0);
    var hitmask_0 : u32 = u32(0);
    loop
    {
        if((i_1 < u32(4)))
        {
        }
        else
        {
            break;
        }
        var shift_0 : u32 = i_1 * u32(8);
        var _S7 : vec3<u32> = vec3<u32>(shift_0);
        var _S8 : vec3<u32> = vec3<u32>(u32(255));
        var tNear_0 : vec3<f32> = vec3<f32>((((lo_0 >> (_S7))) & (_S8))) * scale_0 + origin_1;
        var tFar_0 : vec3<f32> = vec3<f32>((((hi_0 >> (_S7))) & (_S8))) * scale_0 + origin_1;
        if(((max(max(max(tNear_0.x, tNear_0.y), tNear_0.z), tMin_3)) <= (min(min(min(tFar_0.x, tFar_0.y), tFar_0.z), tMax_2))))
        {
            hitmask_0 = (hitmask_0 | (((((((_S6 >> (shift_0))) & (u32(255)))) << (((((_S5 >> (shift_0))) & (u32(255)))))))));
        }
        i_1 = i_1 + u32(1);
    }
    return hitmask_0;
}

fn InverseTransformPoint_0( _S9 : u32,  _S10 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S9].worldToObject_0[i32(0)].xyz, _S10) + gInstances_0[_S9].worldToObject_0[i32(0)].w, dot(gInstances_0[_S9].worldToObject_0[i32(1)].xyz, _S10) + gInstances_0[_S9].worldToObject_0[i32(1)].w, dot(gInstances_0[_S9].worldToObject_0[i32(2)].xyz, _S10) + gInstances_0[_S9].worldToObject_0[i32(2)].w);
}

fn InverseTransformVector_0( _S11 : u32,  _S12 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S11].worldToObject_0[i32(0)].xyz, _S12), dot(gInstances_0[_S11].worldToObject_0[i32(1)].xyz, _S12), dot(gInstances_0[_S11].worldToObject_0[i32(2)].xyz, _S12));
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_2 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_4 : f32,  tMax_3 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_2) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_2) * rD_0;
    var _S13 : vec3<f32> = min(t1_0, t2_0);
    var _S14 : vec3<f32> = max(t1_0, t2_0);
    var _S15 : f32 = max(max(_S13.x, _S13.y), max(_S13.z, tMin_4));
    var _S16 : f32;
    if((_S15 <= (min(min(_S14.x, _S14.y), min(_S14.z, tMax_3)))))
    {
        _S16 = _S15;
    }
    else
    {
        _S16 = 1.00000001504746622e+30f;
    }
    return _S16;
}

fn TraceScene_0( ray_0 : Ray_0,  anyHit_0 : bool,  hit_1 : ptr<function, HitRecord_0>) -> bool
{
    (*hit_1).t_0 = ray_0.tMax_1;
    (*hit_1).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_1).instanceIndex_0 = u32(4294967295);
    (*hit_1).primitiveIndex_0 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S17 : u32 = gFrame_0.counts_0.z;
    var worldRD_0 : vec3<f32> = SafeRcp_0(ray_0.direction_0);
    var _S18 : vec2<u32> = vec2<u32>(u32(0));
    var nodeGroup_0 : vec2<u32> = _S18;
    var triGroup_0 : vec2<u32> = _S18;
    var inBlas_0 : bool = false;
    var instanceIndex_2 : u32 = u32(0);
    var blasTriOffset_2 : u32 = u32(0);
    var merged_1 : bool = false;
    var o_3 : vec3<f32> = ray_0.origin_0;
    var d_3 : vec3<f32> = ray_0.direction_0;
    var octinv_1 : u32 = u32(0);
    var blasNodeOffset_1 : u32 = u32(0);
    var rD_1 : vec3<f32> = worldRD_0;
    var nodeRef_0 : u32 = u32(0);
    var found_0 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var pop_0 : bool;
        var inBlas_1 : bool;
        var merged_2 : bool;
        var instanceIndex_3 : u32;
        var blasTriOffset_3 : u32;
        var octinv_2 : u32;
        var blasNodeOffset_2 : u32;
        var nodeRef_1 : u32;
        var stackPtr_1 : u32;
        var o_4 : vec3<f32>;
        var d_4 : vec3<f32>;
        var rD_2 : vec3<f32>;
        var dist1_0 : f32;
        var dist2_0 : f32;
        if(inBlas_0)
        {
            if(((nodeGroup_0.y) > u32(16777215)))
            {
                var hits_0 : u32 = nodeGroup_0.y;
                var childBit_0 : u32 = firstbithigh_0(hits_0);
                nodeGroup_0[i32(1)] = ((nodeGroup_0[i32(1)]) & ((~((u32(1) << (childBit_0))))));
                if(((nodeGroup_0.y) > u32(16777215)))
                {
                    pop_0 = (stackPtr_0 < u32(32));
                }
                else
                {
                    pop_0 = false;
                }
                if(pop_0)
                {
                    var _S19 : u32 = stackPtr_0 + u32(1);
                    gTraversalStack_0[stackPtr_0] = nodeGroup_0;
                    octinv_2 = _S19;
                }
                else
                {
                    octinv_2 = stackPtr_0;
                }
                var node_0 : u32 = blasNodeOffset_1 + (nodeGroup_0.x + countOneBits((hits_0 & ((~((u32(4294967295) << ((((childBit_0 - u32(24)) ^ (((octinv_1 & (u32(255))))))))))))))) * u32(5);
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var n0_0 : vec4<f32> = gNodes_0[node_0];
                var n1_0 : vec4<f32> = gNodes_0[node_0 + u32(1)];
                var n2_0 : vec4<f32> = gNodes_0[node_0 + u32(2)];
                var n3_0 : vec4<f32> = gNodes_0[node_0 + u32(3)];
                var n4_0 : vec4<f32> = gNodes_0[node_0 + u32(4)];
                var e4_0 : u32 = (bitcast<u32>((n0_0.w)));
                var scale_1 : vec3<f32> = vec3<f32>((bitcast<f32>(((((e4_0 & (u32(255)))) << (u32(23)))))), (bitcast<f32>(((((((e4_0 >> (u32(8)))) & (u32(255)))) << (u32(23)))))), (bitcast<f32>(((((((e4_0 >> (u32(16)))) & (u32(255)))) << (u32(23))))))) * rD_1;
                var origin_2 : vec3<f32> = (n0_0.xyz - o_3) * rD_1;
                var negative_0 : vec3<bool> = (rD_1 < vec3<f32>(0.0f));
                var _S20 : bool = negative_0.x;
                if(_S20)
                {
                    dist1_0 = n3_0.z;
                }
                else
                {
                    dist1_0 = n2_0.x;
                }
                var _S21 : u32 = (bitcast<u32>((dist1_0)));
                var _S22 : bool = negative_0.y;
                if(_S22)
                {
                    dist2_0 = n4_0.x;
                }
                else
                {
                    dist2_0 = n2_0.z;
                }
                var _S23 : u32 = (bitcast<u32>((dist2_0)));
                var _S24 : bool = negative_0.z;
                var _S25 : f32;
                if(_S24)
                {
                    _S25 = n4_0.z;
                }
                else
                {
                    _S25 = n3_0.x;
                }
                var lo0_0 : vec3<u32> = vec3<u32>(_S21, _S23, (bitcast<u32>((_S25))));
                var _S26 : f32;
                if(_S20)
                {
                    _S26 = n2_0.x;
                }
                else
                {
                    _S26 = n3_0.z;
                }
                var _S27 : u32 = (bitcast<u32>((_S26)));
                var _S28 : f32;
                if(_S22)
                {
                    _S28 = n2_0.z;
                }
                else
                {
                    _S28 = n4_0.x;
                }
                var _S29 : u32 = (bitcast<u32>((_S28)));
                var _S30 : f32;
                if(_S24)
                {
                    _S30 = n3_0.x;
                }
                else
                {
                    _S30 = n4_0.z;
                }
                var hi0_0 : vec3<u32> = vec3<u32>(_S27, _S29, (bitcast<u32>((_S30))));
                var _S31 : f32;
                if(_S20)
                {
                    _S31 = n3_0.w;
                }
                else
                {
                    _S31 = n2_0.y;
                }
                var _S32 : u32 = (bitcast<u32>((_S31)));
                var _S33 : f32;
                if(_S22)
                {
                    _S33 = n4_0.y;
                }
                else
                {
                    _S33 = n2_0.w;
                }
                var _S34 : u32 = (bitcast<u32>((_S33)));
                var _S35 : f32;
                if(_S24)
                {
                    _S35 = n4_0.w;
                }
                else
                {
                    _S35 = n3_0.y;
                }
                var lo1_0 : vec3<u32> = vec3<u32>(_S32, _S34, (bitcast<u32>((_S35))));
                var _S36 : f32;
                if(_S20)
                {
                    _S36 = n2_0.y;
                }
                else
                {
                    _S36 = n3_0.w;
                }
                var _S37 : u32 = (bitcast<u32>((_S36)));
                var _S38 : f32;
                if(_S22)
                {
                    _S38 = n2_0.w;
                }
                else
                {
                    _S38 = n4_0.y;
                }
                var _S39 : u32 = (bitcast<u32>((_S38)));
                var _S40 : f32;
                if(_S24)
                {
                    _S40 = n3_0.y;
                }
                else
                {
                    _S40 = n4_0.w;
                }
                var hitmask_1 : u32 = ((CwbvhChildHits_0((bitcast<u32>((n1_0.z))), lo0_0, hi0_0, scale_1, origin_2, ray_0.tMin_2, (*hit_1).t_0, octinv_1)) | ((CwbvhChildHits_0((bitcast<u32>((n1_0.w))), lo1_0, vec3<u32>(_S37, _S39, (bitcast<u32>((_S40)))), scale_1, origin_2, ray_0.tMin_2, (*hit_1).t_0, octinv_1))));
                nodeGroup_0 = vec2<u32>((bitcast<u32>((n1_0.x))), (((hitmask_1 & (u32(4278190080)))) | (((e4_0 >> (u32(24)))))));
                triGroup_0 = vec2<u32>((bitcast<u32>((n1_0.y))), (hitmask_1 & (u32(16777215))));
            }
            else
            {
                triGroup_0 = nodeGroup_0;
                nodeGroup_0 = _S18;
                octinv_2 = stackPtr_0;
            }
            pop_0 = found_0;
            loop
            {
                if((triGroup_0.y) != u32(0))
                {
                }
                else
                {
                    break;
                }
                var triangleBit_0 : u32 = firstbithigh_0(triGroup_0.y);
                triGroup_0[i32(1)] = ((triGroup_0[i32(1)]) & ((~((u32(1) << (triangleBit_0))))));
                var _S41 : bool = IntersectSlot_0((((triGroup_0.x) >> (u32(2)))) + triangleBit_0, instanceIndex_2, blasTriOffset_2, merged_1, false, o_3, d_3, ray_0.tMin_2, &((*hit_1)));
                if(_S41)
                {
                    if(anyHit_0)
                    {
                        return true;
                    }
                    pop_0 = true;
                }
            }
            if((triGroup_0.y) == u32(0))
            {
                inBlas_1 = ((nodeGroup_0.y) <= u32(16777215));
            }
            else
            {
                inBlas_1 = false;
            }
            var _S42 : u32 = octinv_2;
            var _S43 : bool = pop_0;
            pop_0 = inBlas_1;
            inBlas_1 = inBlas_0;
            instanceIndex_3 = instanceIndex_2;
            blasTriOffset_3 = blasTriOffset_2;
            merged_2 = merged_1;
            o_4 = o_3;
            d_4 = d_3;
            octinv_2 = octinv_1;
            blasNodeOffset_2 = blasNodeOffset_1;
            rD_2 = rD_1;
            nodeRef_1 = nodeRef_0;
            found_0 = _S43;
            stackPtr_1 = _S42;
        }
        else
        {
            if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
            {
                var count_0 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
                var first_0 : u32 = (nodeRef_0 & (u32(16777215)));
                if(count_0 == u32(0))
                {
                    pop_0 = true;
                    inBlas_1 = inBlas_0;
                    instanceIndex_3 = instanceIndex_2;
                    blasTriOffset_3 = blasTriOffset_2;
                    merged_2 = merged_1;
                    o_4 = o_3;
                    d_4 = d_3;
                    octinv_2 = octinv_1;
                    blasNodeOffset_2 = blasNodeOffset_1;
                    rD_2 = rD_1;
                    nodeRef_1 = stackPtr_0;
                }
                else
                {
                    if((count_0 > u32(1)))
                    {
                        pop_0 = (stackPtr_0 < u32(32));
                    }
                    else
                    {
                        pop_0 = false;
                    }
                    if(pop_0)
                    {
                        var _S44 : u32 = stackPtr_0 + u32(1);
                        gTraversalStack_0[stackPtr_0] = vec2<u32>((((u32(2147483648) | ((((count_0 - u32(1)) << (u32(24))))))) | ((first_0 + u32(1)))), u32(0));
                        octinv_2 = _S44;
                    }
                    else
                    {
                        octinv_2 = stackPtr_0;
                    }
                    var instanceIndex_4 : u32 = gIndices_0[_S17 + first_0];
                    var _S45 : u32 = gInstances_0[instanceIndex_4].blasNodeOffset_0;
                    var _S46 : u32 = gInstances_0[instanceIndex_4].blasTriOffset_0;
                    var _S47 : vec3<f32> = InverseTransformPoint_0(instanceIndex_4, ray_0.origin_0);
                    var _S48 : vec3<f32> = InverseTransformVector_0(instanceIndex_4, ray_0.direction_0);
                    var _S49 : vec3<f32> = SafeRcp_0(_S48);
                    var _S50 : bool = (((gInstances_0[instanceIndex_4].flags_0) & (u32(4)))) != u32(0);
                    if(((_S48.x) < 0.0f))
                    {
                        instanceIndex_3 = u32(4);
                    }
                    else
                    {
                        instanceIndex_3 = u32(0);
                    }
                    if(((_S48.y) < 0.0f))
                    {
                        blasTriOffset_3 = u32(2);
                    }
                    else
                    {
                        blasTriOffset_3 = u32(0);
                    }
                    var _S51 : u32 = (instanceIndex_3 | (blasTriOffset_3));
                    if(((_S48.z) < 0.0f))
                    {
                        blasNodeOffset_2 = u32(1);
                    }
                    else
                    {
                        blasNodeOffset_2 = u32(0);
                    }
                    var _S52 : u32 = (u32(7) - ((_S51 | (blasNodeOffset_2)))) * u32(16843009);
                    nodeGroup_0 = vec2<u32>(u32(0), u32(2147483648));
                    var _S53 : u32 = octinv_2;
                    pop_0 = false;
                    inBlas_1 = true;
                    instanceIndex_3 = instanceIndex_4;
                    blasTriOffset_3 = _S46;
                    merged_2 = _S50;
                    o_4 = _S47;
                    d_4 = _S48;
                    octinv_2 = _S52;
                    blasNodeOffset_2 = _S45;
                    rD_2 = _S49;
                    nodeRef_1 = _S53;
                }
                var _S54 : u32 = nodeRef_1;
                nodeRef_1 = nodeRef_0;
                stackPtr_1 = _S54;
            }
            else
            {
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var node_1 : u32 = gFrame_0.envInfo_0.z + nodeRef_0 * u32(4);
                var left_0 : vec4<f32> = gNodes_0[node_1];
                var leftMax_0 : vec4<f32> = gNodes_0[node_1 + u32(1)];
                var dist1_1 : f32 = IntersectBox_0(left_0.xyz, leftMax_0.xyz, ray_0.origin_0, worldRD_0, ray_0.tMin_2, (*hit_1).t_0);
                var dist2_1 : f32 = IntersectBox_0(gNodes_0[node_1 + u32(2)].xyz, gNodes_0[node_1 + u32(3)].xyz, ray_0.origin_0, worldRD_0, ray_0.tMin_2, (*hit_1).t_0);
                var near_0 : u32 = (bitcast<u32>((left_0.w)));
                var far_0 : u32 = (bitcast<u32>((leftMax_0.w)));
                if((dist1_1 > dist2_1))
                {
                    dist1_0 = dist2_1;
                    instanceIndex_3 = far_0;
                    dist2_0 = dist1_1;
                    blasTriOffset_3 = near_0;
                }
                else
                {
                    dist1_0 = dist1_1;
                    instanceIndex_3 = near_0;
                    dist2_0 = dist2_1;
                    blasTriOffset_3 = far_0;
                }
                if(dist1_0 == 1.00000001504746622e+30f)
                {
                    pop_0 = true;
                    octinv_2 = nodeRef_0;
                    blasNodeOffset_2 = stackPtr_0;
                }
                else
                {
                    if(dist2_0 != 1.00000001504746622e+30f)
                    {
                        pop_0 = (stackPtr_0 < u32(32));
                    }
                    else
                    {
                        pop_0 = false;
                    }
                    if(pop_0)
                    {
                        var _S55 : u32 = stackPtr_0 + u32(1);
                        gTraversalStack_0[stackPtr_0] = vec2<u32>(blasTriOffset_3, u32(0));
                        octinv_2 = _S55;
                    }
                    else
                    {
                        octinv_2 = stackPtr_0;
                    }
                    var _S56 : u32 = octinv_2;
                    pop_0 = false;
                    octinv_2 = instanceIndex_3;
                    blasNodeOffset_2 = _S56;
                }
                var _S57 : u32 = octinv_2;
                var _S58 : u32 = blasNodeOffset_2;
                inBlas_1 = inBlas_0;
                instanceIndex_3 = instanceIndex_2;
                blasTriOffset_3 = blasTriOffset_2;
                merged_2 = merged_1;
                o_4 = o_3;
                d_4 = d_3;
                octinv_2 = octinv_1;
                blasNodeOffset_2 = blasNodeOffset_1;
                rD_2 = rD_1;
                nodeRef_1 = _S57;
                stackPtr_1 = _S58;
            }
        }
        if(pop_0)
        {
            if(stackPtr_1 == u32(0))
            {
                break;
            }
            var stackPtr_2 : u32 = stackPtr_1 - u32(1);
            var entry_0 : vec2<u32> = gTraversalStack_0[stackPtr_2];
            var inBlas_2 : bool;
            var nodeRef_2 : u32;
            if((gTraversalStack_0[stackPtr_2].y) == u32(0))
            {
                var _S59 : u32 = entry_0.x;
                inBlas_2 = false;
                nodeRef_2 = _S59;
            }
            else
            {
                nodeGroup_0 = entry_0;
                inBlas_2 = inBlas_1;
                nodeRef_2 = nodeRef_1;
            }
            inBlas_0 = inBlas_2;
            nodeRef_0 = nodeRef_2;
            stackPtr_0 = stackPtr_2;
        }
        else
        {
            inBlas_0 = inBlas_1;
            nodeRef_0 = nodeRef_1;
            stackPtr_0 = stackPtr_1;
        }
        instanceIndex_2 = instanceIndex_3;
        blasTriOffset_2 = blasTriOffset_3;
        merged_1 = merged_2;
        o_3 = o_4;
        d_3 = d_4;
        octinv_1 = octinv_2;
        blasNodeOffset_1 = blasNodeOffset_2;
        rD_1 = rD_2;
    }
    return found_0;
}

fn WorkBase_0( index_0 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_0;
}

fn Field_0( base_1 : u32,  field_0 : u32) -> u32
{
    return base_1 + field_0 * gWavefront_0.capacity_0;
}

fn Ray_x24init_0( o_5 : vec3<f32>,  d_5 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S60 : Ray_0;
    _S60.origin_0 = o_5;
    _S60.direction_0 = d_5;
    _S60.tMin_2 = 0.0f;
    _S60.tMax_1 = tmax_0;
    return _S60;
}

fn TraceOcclusion_0( ray_1 : Ray_0) -> bool
{
    var hit_2 : HitRecord_0;
    var _S61 : bool = TraceScene_0(ray_1, true, &(hit_2));
    return _S61;
}

var<workgroup> gContributions_0 : array<vec3<f32>, i32(192)>;

fn NrdUnpackFraction_0( v_1 : u32) -> vec3<f32>
{
    return vec3<f32>(f32((v_1 & (u32(511)))), f32((((v_1 >> (u32(9)))) & (u32(511)))), f32((((v_1 >> (u32(18)))) & (u32(511))))) / vec3<f32>(511.0f);
}

fn DiffuseOnlyFrame_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(32)))) != u32(0);
}

fn NrdSplitDirect_0( flags_1 : u32,  contribution_0 : vec3<f32>,  diffuse_0 : ptr<function, vec3<f32>>,  specular_0 : ptr<function, vec3<f32>>,  bypass_0 : ptr<function, vec3<f32>>)
{
    var skip_0 : bool = ((flags_1 & (u32(4)))) != u32(0);
    var _S62 : vec3<f32>;
    if(skip_0)
    {
        _S62 = vec3<f32>(0.0f);
    }
    else
    {
        _S62 = contribution_0 * NrdUnpackFraction_0((flags_1 >> (u32(3))));
    }
    (*diffuse_0) = _S62;
    if(skip_0)
    {
        _S62 = vec3<f32>(0.0f);
    }
    else
    {
        _S62 = contribution_0 - (*diffuse_0);
    }
    (*specular_0) = _S62;
    if(skip_0)
    {
        _S62 = contribution_0;
    }
    else
    {
        _S62 = vec3<f32>(0.0f);
    }
    (*bypass_0) = _S62;
    var _S63 : bool;
    if(DiffuseOnlyFrame_0())
    {
        _S63 = ((flags_1 & (u32(1073741824)))) != u32(0);
    }
    else
    {
        _S63 = false;
    }
    if(_S63)
    {
        (*bypass_0) = (*bypass_0) + (*specular_0);
        (*specular_0) = vec3<f32>(0.0f);
    }
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
    var _S64 : u32 = block_0 % blocksX_0;
    var _S65 : u32 = _S64 * u32(8) + ((lane_0 & (u32(7))));
    var _S66 : u32 = block_0 / blocksX_0;
    return vec2<u32>(_S65, _S66 * u32(8) + lane_0 / u32(8));
}

fn NrdBase_0( base_2 : u32) -> u32
{
    var pixel_0 : vec2<u32> = WorkPixel_0(base_2 - WorkBase_0(u32(0)));
    return gFrame_0.envInfo_0.w + (pixel_0.y * gFrame_0.frame_0.x + pixel_0.x) * u32(5);
}

fn ShadowParallelImpl_0( tid_0 : vec3<u32>,  local_0 : vec3<u32>)
{
    var _S67 : vec3<f32> = vec3<f32>(0.0f);
    var _S68 : u32 = local_0.y;
    var _S69 : u32 = _S68 * u32(2);
    var _S70 : u32 = tid_0.x;
    var _S71 : bool = (_S70 < (gWavefront_0.pathCount_0));
    var _S72 : bool;
    var value_1 : vec3<f32>;
    var lightDirection_0 : vec3<f32>;
    var flags_2 : u32;
    var mask_0 : u32;
    var base_3 : u32;
    if(_S71)
    {
        var base_4 : u32 = WorkBase_0(_S70);
        var mask_1 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_4, u32(11))].z)));
        if(((mask_1 & (((u32(1) << (_S69)))))) != u32(0))
        {
            var offset_0 : u32 = u32(12) + _S69 * u32(3);
            var origin_3 : vec4<f32> = gAccum_0[Field_0(base_4, offset_0)];
            var flags_3 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_4, offset_0 + u32(1))].w)));
            var _S73 : vec3<f32> = gAccum_0[Field_0(base_4, offset_0 + u32(1))].xyz;
            if(((flags_3 & (u32(1)))) == u32(0))
            {
                _S72 = true;
            }
            else
            {
                var _S74 : bool = TraceOcclusion_0(Ray_x24init_0(origin_3.xyz, _S73, origin_3.w));
                _S72 = !_S74;
            }
            if(_S72)
            {
                value_1 = gAccum_0[Field_0(base_4, offset_0 + u32(2))].xyz;
            }
            else
            {
                value_1 = _S67;
            }
            flags_2 = flags_3;
            lightDirection_0 = _S73;
        }
        else
        {
            value_1 = _S67;
            flags_2 = u32(0);
            lightDirection_0 = _S67;
        }
        mask_0 = mask_1;
        base_3 = base_4;
    }
    else
    {
        value_1 = _S67;
        flags_2 = u32(0);
        lightDirection_0 = _S67;
        mask_0 = u32(0);
        base_3 = u32(0);
    }
    var _S75 : u32 = local_0.x;
    var _S76 : u32 = _S68 * u32(64) + _S75;
    gContributions_0[_S76] = value_1;
    var laneDiffuse_0 : vec3<f32> = _S67;
    var laneSpecular_0 : vec3<f32>;
    var laneBypass_0 : vec3<f32> = _S67;
    var _S77 : bool = ((flags_2 & (u32(2)))) != u32(0);
    if(_S77)
    {
        NrdSplitDirect_0(flags_2, value_1, &(laneDiffuse_0), &(laneSpecular_0), &(laneBypass_0));
    }
    gNrdDiffuse_0[_S76] = vec4<f32>(laneDiffuse_0, f32(_S77));
    gNrdBypass_0[_S76] = laneBypass_0;
    gNrdDiffuseDirection_0[_S76] = vec3<f32>(Luminance_0(laneDiffuse_0)) * lightDirection_0;
    if(_S77)
    {
        value_1 = vec3<f32>(Luminance_0(laneSpecular_0)) * lightDirection_0;
    }
    else
    {
        value_1 = _S67;
    }
    gNrdSpecularDirection_0[_S76] = value_1;
    workgroupBarrier();
    if(_S69 == u32(0))
    {
        _S72 = _S71;
    }
    else
    {
        _S72 = false;
    }
    if(_S72)
    {
        _S72 = mask_0 != u32(0);
    }
    else
    {
        _S72 = false;
    }
    if(_S72)
    {
        var _S78 : u32 = u32(64) + _S75;
        var sum_0 : vec3<f32> = gContributions_0[_S75] + gContributions_0[_S78];
        var throughput_0 : vec4<f32> = gAccum_0[Field_0(base_3, u32(10))];
        var diffuse_1 : vec4<f32> = gNrdDiffuse_0[_S75] + gNrdDiffuse_0[_S78];
        var bypass_1 : vec3<f32> = gNrdBypass_0[_S75] + gNrdBypass_0[_S78];
        var diffuseDirection_0 : vec3<f32> = gNrdDiffuseDirection_0[_S75] + gNrdDiffuseDirection_0[_S78];
        var specularDirection_0 : vec3<f32> = gNrdSpecularDirection_0[_S75] + gNrdSpecularDirection_0[_S78];
        if(((diffuse_1.w) > 0.0f))
        {
            var r_0 : u32 = NrdBase_0(base_3);
            var _S79 : vec3<f32> = throughput_0.xyz;
            var _S80 : vec3<f32> = gAccum_0[r_0].xyz + _S79 * bypass_1;
            gAccum_0[r_0].x = _S80.x;
            gAccum_0[r_0].y = _S80.y;
            gAccum_0[r_0].z = _S80.z;
            var _S81 : u32 = r_0 + u32(1);
            var _S82 : vec3<f32> = diffuse_1.xyz;
            var _S83 : vec3<f32> = gAccum_0[_S81].xyz + _S79 * _S82;
            gAccum_0[_S81].x = _S83.x;
            gAccum_0[_S81].y = _S83.y;
            gAccum_0[_S81].z = _S83.z;
            var _S84 : u32 = r_0 + u32(2);
            var _S85 : vec3<f32> = gAccum_0[_S84].xyz + _S79 * (sum_0 - _S82 - bypass_1);
            gAccum_0[_S84].x = _S85.x;
            gAccum_0[_S84].y = _S85.y;
            gAccum_0[_S84].z = _S85.z;
            var _S86 : u32 = r_0 + u32(3);
            var _S87 : vec3<f32> = vec3<f32>(Luminance_0(_S79));
            var _S88 : vec3<f32> = gAccum_0[_S86].xyz + _S87 * diffuseDirection_0;
            gAccum_0[_S86].x = _S88.x;
            gAccum_0[_S86].y = _S88.y;
            gAccum_0[_S86].z = _S88.z;
            var _S89 : u32 = r_0 + u32(4);
            var _S90 : vec3<f32> = gAccum_0[_S89].xyz + _S87 * specularDirection_0;
            gAccum_0[_S89].x = _S90.x;
            gAccum_0[_S89].y = _S90.y;
            gAccum_0[_S89].z = _S90.z;
        }
        var contribution_1 : vec3<f32> = throughput_0.xyz * sum_0;
        var _S91 : f32 = throughput_0.w;
        var contribution_2 : vec3<f32>;
        if((_S91 > 0.0f))
        {
            contribution_2 = min(contribution_1, vec3<f32>(_S91));
        }
        else
        {
            contribution_2 = contribution_1;
        }
        var path_0 : vec4<f32> = gAccum_0[base_3];
        var _S92 : vec3<f32> = gAccum_0[base_3].xyz + contribution_2;
        path_0.x = _S92.x;
        path_0.y = _S92.y;
        path_0.z = _S92.z;
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
    var _S93 : vec3<f32> = vec3<f32>(0.0f);
    var _S94 : u32 = local_1.y;
    var _S95 : u32 = _S94 * u32(2);
    var _S96 : u32 = tid_1.x;
    var _S97 : bool = (_S96 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S98 : bool;
    var value_2 : vec3<f32>;
    var lightDirection_1 : vec3<f32>;
    var flags_4 : u32;
    var mask_2 : u32;
    var base_6 : u32;
    if(_S97)
    {
        var base_7 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S96));
        var mask_3 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_7, u32(11))].z)));
        if(((mask_3 & (((u32(1) << (_S95)))))) != u32(0))
        {
            var offset_1 : u32 = u32(12) + _S95 * u32(3);
            var origin_4 : vec4<f32> = gAccum_0[Field_0(base_7, offset_1)];
            var flags_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_7, offset_1 + u32(1))].w)));
            var _S99 : vec3<f32> = gAccum_0[Field_0(base_7, offset_1 + u32(1))].xyz;
            if(((flags_5 & (u32(1)))) == u32(0))
            {
                _S98 = true;
            }
            else
            {
                var _S100 : bool = TraceOcclusion_0(Ray_x24init_0(origin_4.xyz, _S99, origin_4.w));
                _S98 = !_S100;
            }
            if(_S98)
            {
                value_2 = gAccum_0[Field_0(base_7, offset_1 + u32(2))].xyz;
            }
            else
            {
                value_2 = _S93;
            }
            flags_4 = flags_5;
            lightDirection_1 = _S99;
        }
        else
        {
            value_2 = _S93;
            flags_4 = u32(0);
            lightDirection_1 = _S93;
        }
        mask_2 = mask_3;
        base_6 = base_7;
    }
    else
    {
        value_2 = _S93;
        flags_4 = u32(0);
        lightDirection_1 = _S93;
        mask_2 = u32(0);
        base_6 = u32(0);
    }
    var _S101 : u32 = local_1.x;
    var _S102 : u32 = _S94 * u32(64) + _S101;
    gContributions_0[_S102] = value_2;
    var laneDiffuse_1 : vec3<f32> = _S93;
    var laneSpecular_1 : vec3<f32>;
    var laneBypass_1 : vec3<f32> = _S93;
    var _S103 : bool = ((flags_4 & (u32(2)))) != u32(0);
    if(_S103)
    {
        NrdSplitDirect_0(flags_4, value_2, &(laneDiffuse_1), &(laneSpecular_1), &(laneBypass_1));
    }
    gNrdDiffuse_0[_S102] = vec4<f32>(laneDiffuse_1, f32(_S103));
    gNrdBypass_0[_S102] = laneBypass_1;
    gNrdDiffuseDirection_0[_S102] = vec3<f32>(Luminance_0(laneDiffuse_1)) * lightDirection_1;
    if(_S103)
    {
        value_2 = vec3<f32>(Luminance_0(laneSpecular_1)) * lightDirection_1;
    }
    else
    {
        value_2 = _S93;
    }
    gNrdSpecularDirection_0[_S102] = value_2;
    workgroupBarrier();
    if(_S95 == u32(0))
    {
        _S98 = _S97;
    }
    else
    {
        _S98 = false;
    }
    if(_S98)
    {
        _S98 = mask_2 != u32(0);
    }
    else
    {
        _S98 = false;
    }
    if(_S98)
    {
        var _S104 : u32 = u32(64) + _S101;
        var sum_1 : vec3<f32> = gContributions_0[_S101] + gContributions_0[_S104];
        var throughput_1 : vec4<f32> = gAccum_0[Field_0(base_6, u32(10))];
        var diffuse_2 : vec4<f32> = gNrdDiffuse_0[_S101] + gNrdDiffuse_0[_S104];
        var bypass_2 : vec3<f32> = gNrdBypass_0[_S101] + gNrdBypass_0[_S104];
        var diffuseDirection_1 : vec3<f32> = gNrdDiffuseDirection_0[_S101] + gNrdDiffuseDirection_0[_S104];
        var specularDirection_1 : vec3<f32> = gNrdSpecularDirection_0[_S101] + gNrdSpecularDirection_0[_S104];
        if(((diffuse_2.w) > 0.0f))
        {
            var r_1 : u32 = NrdBase_0(base_6);
            var _S105 : vec3<f32> = throughput_1.xyz;
            var _S106 : vec3<f32> = gAccum_0[r_1].xyz + _S105 * bypass_2;
            gAccum_0[r_1].x = _S106.x;
            gAccum_0[r_1].y = _S106.y;
            gAccum_0[r_1].z = _S106.z;
            var _S107 : u32 = r_1 + u32(1);
            var _S108 : vec3<f32> = diffuse_2.xyz;
            var _S109 : vec3<f32> = gAccum_0[_S107].xyz + _S105 * _S108;
            gAccum_0[_S107].x = _S109.x;
            gAccum_0[_S107].y = _S109.y;
            gAccum_0[_S107].z = _S109.z;
            var _S110 : u32 = r_1 + u32(2);
            var _S111 : vec3<f32> = gAccum_0[_S110].xyz + _S105 * (sum_1 - _S108 - bypass_2);
            gAccum_0[_S110].x = _S111.x;
            gAccum_0[_S110].y = _S111.y;
            gAccum_0[_S110].z = _S111.z;
            var _S112 : u32 = r_1 + u32(3);
            var _S113 : vec3<f32> = vec3<f32>(Luminance_0(_S105));
            var _S114 : vec3<f32> = gAccum_0[_S112].xyz + _S113 * diffuseDirection_1;
            gAccum_0[_S112].x = _S114.x;
            gAccum_0[_S112].y = _S114.y;
            gAccum_0[_S112].z = _S114.z;
            var _S115 : u32 = r_1 + u32(4);
            var _S116 : vec3<f32> = gAccum_0[_S115].xyz + _S113 * specularDirection_1;
            gAccum_0[_S115].x = _S116.x;
            gAccum_0[_S115].y = _S116.y;
            gAccum_0[_S115].z = _S116.z;
        }
        var contribution_3 : vec3<f32> = throughput_1.xyz * sum_1;
        var _S117 : f32 = throughput_1.w;
        var contribution_4 : vec3<f32>;
        if((_S117 > 0.0f))
        {
            contribution_4 = min(contribution_3, vec3<f32>(_S117));
        }
        else
        {
            contribution_4 = contribution_3;
        }
        var path_1 : vec4<f32> = gAccum_0[base_6];
        var _S118 : vec3<f32> = gAccum_0[base_6].xyz + contribution_4;
        path_1.x = _S118.x;
        path_1.y = _S118.y;
        path_1.z = _S118.z;
        gAccum_0[base_6] = path_1;
        gAccum_0[Field_0(base_6, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_2( tid_2 : vec3<u32>,  local_2 : vec3<u32>)
{
    var _S119 : vec3<f32> = vec3<f32>(0.0f);
    var _S120 : u32 = local_2.y;
    var _S121 : u32 = tid_2.x;
    var _S122 : bool = (_S121 < (gWavefront_0.pathCount_0));
    var _S123 : bool;
    var value_3 : vec3<f32>;
    var lightDirection_2 : vec3<f32>;
    var flags_6 : u32;
    var mask_4 : u32;
    var base_8 : u32;
    if(_S122)
    {
        var base_9 : u32 = WorkBase_0(_S121);
        var mask_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_9, u32(11))].z)));
        if(((mask_5 & (((u32(1) << (_S120)))))) != u32(0))
        {
            var offset_2 : u32 = u32(12) + _S120 * u32(3);
            var origin_5 : vec4<f32> = gAccum_0[Field_0(base_9, offset_2)];
            var flags_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_9, offset_2 + u32(1))].w)));
            var _S124 : vec3<f32> = gAccum_0[Field_0(base_9, offset_2 + u32(1))].xyz;
            if(((flags_7 & (u32(1)))) == u32(0))
            {
                _S123 = true;
            }
            else
            {
                var _S125 : bool = TraceOcclusion_0(Ray_x24init_0(origin_5.xyz, _S124, origin_5.w));
                _S123 = !_S125;
            }
            if(_S123)
            {
                value_3 = gAccum_0[Field_0(base_9, offset_2 + u32(2))].xyz;
            }
            else
            {
                value_3 = _S119;
            }
            flags_6 = flags_7;
            lightDirection_2 = _S124;
        }
        else
        {
            value_3 = _S119;
            flags_6 = u32(0);
            lightDirection_2 = _S119;
        }
        mask_4 = mask_5;
        base_8 = base_9;
    }
    else
    {
        value_3 = _S119;
        flags_6 = u32(0);
        lightDirection_2 = _S119;
        mask_4 = u32(0);
        base_8 = u32(0);
    }
    var _S126 : u32 = local_2.x;
    var _S127 : u32 = _S120 * u32(64) + _S126;
    gContributions_0[_S127] = value_3;
    var laneDiffuse_2 : vec3<f32> = _S119;
    var laneSpecular_2 : vec3<f32>;
    var laneBypass_2 : vec3<f32> = _S119;
    var _S128 : bool = ((flags_6 & (u32(2)))) != u32(0);
    if(_S128)
    {
        NrdSplitDirect_0(flags_6, value_3, &(laneDiffuse_2), &(laneSpecular_2), &(laneBypass_2));
    }
    gNrdDiffuse_0[_S127] = vec4<f32>(laneDiffuse_2, f32(_S128));
    gNrdBypass_0[_S127] = laneBypass_2;
    gNrdDiffuseDirection_0[_S127] = vec3<f32>(Luminance_0(laneDiffuse_2)) * lightDirection_2;
    if(_S128)
    {
        value_3 = vec3<f32>(Luminance_0(laneSpecular_2)) * lightDirection_2;
    }
    else
    {
        value_3 = _S119;
    }
    gNrdSpecularDirection_0[_S127] = value_3;
    workgroupBarrier();
    if(_S120 == u32(0))
    {
        _S123 = _S122;
    }
    else
    {
        _S123 = false;
    }
    if(_S123)
    {
        _S123 = mask_4 != u32(0);
    }
    else
    {
        _S123 = false;
    }
    if(_S123)
    {
        var _S129 : u32 = u32(64) + _S126;
        var _S130 : u32 = u32(128) + _S126;
        var sum_2 : vec3<f32> = gContributions_0[_S126] + gContributions_0[_S129] + gContributions_0[_S130];
        var throughput_2 : vec4<f32> = gAccum_0[Field_0(base_8, u32(10))];
        var diffuse_3 : vec4<f32> = gNrdDiffuse_0[_S126] + gNrdDiffuse_0[_S129] + gNrdDiffuse_0[_S130];
        var bypass_3 : vec3<f32> = gNrdBypass_0[_S126] + gNrdBypass_0[_S129] + gNrdBypass_0[_S130];
        var diffuseDirection_2 : vec3<f32> = gNrdDiffuseDirection_0[_S126] + gNrdDiffuseDirection_0[_S129] + gNrdDiffuseDirection_0[_S130];
        var specularDirection_2 : vec3<f32> = gNrdSpecularDirection_0[_S126] + gNrdSpecularDirection_0[_S129] + gNrdSpecularDirection_0[_S130];
        if(((diffuse_3.w) > 0.0f))
        {
            var r_2 : u32 = NrdBase_0(base_8);
            var _S131 : vec3<f32> = throughput_2.xyz;
            var _S132 : vec3<f32> = gAccum_0[r_2].xyz + _S131 * bypass_3;
            gAccum_0[r_2].x = _S132.x;
            gAccum_0[r_2].y = _S132.y;
            gAccum_0[r_2].z = _S132.z;
            var _S133 : u32 = r_2 + u32(1);
            var _S134 : vec3<f32> = diffuse_3.xyz;
            var _S135 : vec3<f32> = gAccum_0[_S133].xyz + _S131 * _S134;
            gAccum_0[_S133].x = _S135.x;
            gAccum_0[_S133].y = _S135.y;
            gAccum_0[_S133].z = _S135.z;
            var _S136 : u32 = r_2 + u32(2);
            var _S137 : vec3<f32> = gAccum_0[_S136].xyz + _S131 * (sum_2 - _S134 - bypass_3);
            gAccum_0[_S136].x = _S137.x;
            gAccum_0[_S136].y = _S137.y;
            gAccum_0[_S136].z = _S137.z;
            var _S138 : u32 = r_2 + u32(3);
            var _S139 : vec3<f32> = vec3<f32>(Luminance_0(_S131));
            var _S140 : vec3<f32> = gAccum_0[_S138].xyz + _S139 * diffuseDirection_2;
            gAccum_0[_S138].x = _S140.x;
            gAccum_0[_S138].y = _S140.y;
            gAccum_0[_S138].z = _S140.z;
            var _S141 : u32 = r_2 + u32(4);
            var _S142 : vec3<f32> = gAccum_0[_S141].xyz + _S139 * specularDirection_2;
            gAccum_0[_S141].x = _S142.x;
            gAccum_0[_S141].y = _S142.y;
            gAccum_0[_S141].z = _S142.z;
        }
        var contribution_5 : vec3<f32> = throughput_2.xyz * sum_2;
        var _S143 : f32 = throughput_2.w;
        var contribution_6 : vec3<f32>;
        if((_S143 > 0.0f))
        {
            contribution_6 = min(contribution_5, vec3<f32>(_S143));
        }
        else
        {
            contribution_6 = contribution_5;
        }
        var path_2 : vec4<f32> = gAccum_0[base_8];
        var _S144 : vec3<f32> = gAccum_0[base_8].xyz + contribution_6;
        path_2.x = _S144.x;
        path_2.y = _S144.y;
        path_2.z = _S144.z;
        gAccum_0[base_8] = path_2;
        gAccum_0[Field_0(base_8, u32(11))] = vec4<f32>(0.0f);
    }
    return;
}

fn ShadowParallelImpl_3( tid_3 : vec3<u32>,  local_3 : vec3<u32>)
{
    var _S145 : vec3<f32> = vec3<f32>(0.0f);
    var _S146 : u32 = local_3.y;
    var _S147 : u32 = tid_3.x;
    var _S148 : bool = (_S147 < (bitcast<u32>((gAccum_0[HeaderBase_0()].y))));
    var _S149 : bool;
    var value_4 : vec3<f32>;
    var lightDirection_3 : vec3<f32>;
    var flags_8 : u32;
    var mask_6 : u32;
    var base_10 : u32;
    if(_S148)
    {
        var base_11 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S147));
        var mask_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_11, u32(11))].z)));
        if(((mask_7 & (((u32(1) << (_S146)))))) != u32(0))
        {
            var offset_3 : u32 = u32(12) + _S146 * u32(3);
            var origin_6 : vec4<f32> = gAccum_0[Field_0(base_11, offset_3)];
            var flags_9 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_11, offset_3 + u32(1))].w)));
            var _S150 : vec3<f32> = gAccum_0[Field_0(base_11, offset_3 + u32(1))].xyz;
            if(((flags_9 & (u32(1)))) == u32(0))
            {
                _S149 = true;
            }
            else
            {
                var _S151 : bool = TraceOcclusion_0(Ray_x24init_0(origin_6.xyz, _S150, origin_6.w));
                _S149 = !_S151;
            }
            if(_S149)
            {
                value_4 = gAccum_0[Field_0(base_11, offset_3 + u32(2))].xyz;
            }
            else
            {
                value_4 = _S145;
            }
            flags_8 = flags_9;
            lightDirection_3 = _S150;
        }
        else
        {
            value_4 = _S145;
            flags_8 = u32(0);
            lightDirection_3 = _S145;
        }
        mask_6 = mask_7;
        base_10 = base_11;
    }
    else
    {
        value_4 = _S145;
        flags_8 = u32(0);
        lightDirection_3 = _S145;
        mask_6 = u32(0);
        base_10 = u32(0);
    }
    var _S152 : u32 = local_3.x;
    var _S153 : u32 = _S146 * u32(64) + _S152;
    gContributions_0[_S153] = value_4;
    var laneDiffuse_3 : vec3<f32> = _S145;
    var laneSpecular_3 : vec3<f32>;
    var laneBypass_3 : vec3<f32> = _S145;
    var _S154 : bool = ((flags_8 & (u32(2)))) != u32(0);
    if(_S154)
    {
        NrdSplitDirect_0(flags_8, value_4, &(laneDiffuse_3), &(laneSpecular_3), &(laneBypass_3));
    }
    gNrdDiffuse_0[_S153] = vec4<f32>(laneDiffuse_3, f32(_S154));
    gNrdBypass_0[_S153] = laneBypass_3;
    gNrdDiffuseDirection_0[_S153] = vec3<f32>(Luminance_0(laneDiffuse_3)) * lightDirection_3;
    if(_S154)
    {
        value_4 = vec3<f32>(Luminance_0(laneSpecular_3)) * lightDirection_3;
    }
    else
    {
        value_4 = _S145;
    }
    gNrdSpecularDirection_0[_S153] = value_4;
    workgroupBarrier();
    if(_S146 == u32(0))
    {
        _S149 = _S148;
    }
    else
    {
        _S149 = false;
    }
    if(_S149)
    {
        _S149 = mask_6 != u32(0);
    }
    else
    {
        _S149 = false;
    }
    if(_S149)
    {
        var _S155 : u32 = u32(64) + _S152;
        var _S156 : u32 = u32(128) + _S152;
        var sum_3 : vec3<f32> = gContributions_0[_S152] + gContributions_0[_S155] + gContributions_0[_S156];
        var throughput_3 : vec4<f32> = gAccum_0[Field_0(base_10, u32(10))];
        var diffuse_4 : vec4<f32> = gNrdDiffuse_0[_S152] + gNrdDiffuse_0[_S155] + gNrdDiffuse_0[_S156];
        var bypass_4 : vec3<f32> = gNrdBypass_0[_S152] + gNrdBypass_0[_S155] + gNrdBypass_0[_S156];
        var diffuseDirection_3 : vec3<f32> = gNrdDiffuseDirection_0[_S152] + gNrdDiffuseDirection_0[_S155] + gNrdDiffuseDirection_0[_S156];
        var specularDirection_3 : vec3<f32> = gNrdSpecularDirection_0[_S152] + gNrdSpecularDirection_0[_S155] + gNrdSpecularDirection_0[_S156];
        if(((diffuse_4.w) > 0.0f))
        {
            var r_3 : u32 = NrdBase_0(base_10);
            var _S157 : vec3<f32> = throughput_3.xyz;
            var _S158 : vec3<f32> = gAccum_0[r_3].xyz + _S157 * bypass_4;
            gAccum_0[r_3].x = _S158.x;
            gAccum_0[r_3].y = _S158.y;
            gAccum_0[r_3].z = _S158.z;
            var _S159 : u32 = r_3 + u32(1);
            var _S160 : vec3<f32> = diffuse_4.xyz;
            var _S161 : vec3<f32> = gAccum_0[_S159].xyz + _S157 * _S160;
            gAccum_0[_S159].x = _S161.x;
            gAccum_0[_S159].y = _S161.y;
            gAccum_0[_S159].z = _S161.z;
            var _S162 : u32 = r_3 + u32(2);
            var _S163 : vec3<f32> = gAccum_0[_S162].xyz + _S157 * (sum_3 - _S160 - bypass_4);
            gAccum_0[_S162].x = _S163.x;
            gAccum_0[_S162].y = _S163.y;
            gAccum_0[_S162].z = _S163.z;
            var _S164 : u32 = r_3 + u32(3);
            var _S165 : vec3<f32> = vec3<f32>(Luminance_0(_S157));
            var _S166 : vec3<f32> = gAccum_0[_S164].xyz + _S165 * diffuseDirection_3;
            gAccum_0[_S164].x = _S166.x;
            gAccum_0[_S164].y = _S166.y;
            gAccum_0[_S164].z = _S166.z;
            var _S167 : u32 = r_3 + u32(4);
            var _S168 : vec3<f32> = gAccum_0[_S167].xyz + _S165 * specularDirection_3;
            gAccum_0[_S167].x = _S168.x;
            gAccum_0[_S167].y = _S168.y;
            gAccum_0[_S167].z = _S168.z;
        }
        var contribution_7 : vec3<f32> = throughput_3.xyz * sum_3;
        var _S169 : f32 = throughput_3.w;
        var contribution_8 : vec3<f32>;
        if((_S169 > 0.0f))
        {
            contribution_8 = min(contribution_7, vec3<f32>(_S169));
        }
        else
        {
            contribution_8 = contribution_7;
        }
        var path_3 : vec4<f32> = gAccum_0[base_10];
        var _S170 : vec3<f32> = gAccum_0[base_10].xyz + contribution_8;
        path_3.x = _S170.x;
        path_3.y = _S170.y;
        path_3.z = _S170.z;
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

