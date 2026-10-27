// Generated from shaders/Passes/Wavefront.slang by scripts/build-shaders.mjs. Do not edit.
struct WavefrontUniforms_std140_0
{
    @align(16) tileStart_0 : u32,
    @align(4) pathCount_0 : u32,
    @align(8) bounce_0 : u32,
    @align(4) capacity_0 : u32,
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

@binding(6) @group(0) var<storage, read> gMaterialData_0 : array<vec4<u32>>;

@binding(5) @group(0) var<storage, read> gIndices_0 : array<u32>;

struct Vertex_std430_0
{
    @align(16) positionU_0 : vec4<f32>,
    @align(16) normalV_0 : vec4<f32>,
    @align(16) tangent_0 : vec4<f32>,
    @align(16) uv1_0 : vec4<f32>,
};

@binding(4) @group(0) var<storage, read> gVertices_0 : array<Vertex_std430_0>;

@binding(12) @group(0) var gVTPageTable_0 : texture_2d<u32>;

@binding(11) @group(0) var gVTPhysical_0 : texture_2d<f32>;

@binding(8) @group(0) var gLinearSampler_0 : sampler;

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

struct EmissiveTriangle_std430_0
{
    @align(16) p0_0 : vec4<f32>,
    @align(16) p1_0 : vec4<f32>,
    @align(16) p2_0 : vec4<f32>,
    @align(16) n_0 : vec4<f32>,
    @align(16) uvA_0 : vec4<f32>,
    @align(16) uvB_0 : vec4<f32>,
    @align(16) uvC_0 : vec4<f32>,
    @align(16) pad_0 : vec4<f32>,
};

@binding(7) @group(0) var<storage, read> gLights_0 : array<EmissiveTriangle_std430_0>;

@binding(9) @group(0) var gEnvMap_0 : texture_2d<f32>;

@binding(10) @group(0) var gEnvCdf_0 : texture_2d<f32>;

@binding(13) @group(0) var gBSDFTables_0 : texture_3d<f32>;

@binding(1) @group(1) var gVTFeedback_0 : texture_storage_2d<r32uint, write>;

fn isnan_0( x_0 : f32) -> bool
{
    var _S1 : u32 = (bitcast<u32>((x_0)));
    var _S2 : u32 = (_S1 & (u32(8388607)));
    var _S3 : bool;
    if(((((_S1 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S3 = _S2 != u32(0);
    }
    else
    {
        _S3 = false;
    }
    return _S3;
}

fn isinf_0( x_1 : f32) -> bool
{
    var _S4 : u32 = (bitcast<u32>((x_1)));
    var _S5 : u32 = (_S4 & (u32(8388607)));
    var _S6 : bool;
    if(((((_S4 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S6 = _S5 == u32(0);
    }
    else
    {
        _S6 = false;
    }
    return _S6;
}

fn isfinite_0( x_2 : f32) -> bool
{
    var _S7 : bool;
    if(isinf_0(x_2))
    {
        _S7 = true;
    }
    else
    {
        _S7 = isnan_0(x_2);
    }
    return !_S7;
}

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

fn rcp_0( x_3 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_3;
}

fn SafeRcp_0( d_0 : vec3<f32>) -> vec3<f32>
{
    return rcp_0(select(d_0, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_0 < vec3<f32>(0.0f))), ((abs(d_0)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn InverseTransformPoint_0( _S8 : u32,  _S9 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S8].worldToObject_0[i32(0)].xyz, _S9) + gInstances_0[_S8].worldToObject_0[i32(0)].w, dot(gInstances_0[_S8].worldToObject_0[i32(1)].xyz, _S9) + gInstances_0[_S8].worldToObject_0[i32(1)].w, dot(gInstances_0[_S8].worldToObject_0[i32(2)].xyz, _S9) + gInstances_0[_S8].worldToObject_0[i32(2)].w);
}

fn InverseTransformVector_0( _S10 : u32,  _S11 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S10].worldToObject_0[i32(0)].xyz, _S11), dot(gInstances_0[_S10].worldToObject_0[i32(1)].xyz, _S11), dot(gInstances_0[_S10].worldToObject_0[i32(2)].xyz, _S11));
}

var<private> gTraversalCost_0 : u32;

fn rcp_1( x_4 : f32) -> f32
{
    return 1.0f / x_4;
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
    var _S12 : bool;
    if((u_0 < 0.0f))
    {
        _S12 = true;
    }
    else
    {
        _S12 = (u_0 > 1.0f);
    }
    if(_S12)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_0, e1_0);
    var v_0 : f32 = f_0 * dot(d_1, q_0);
    if((v_0 < 0.0f))
    {
        _S12 = true;
    }
    else
    {
        _S12 = ((u_0 + v_0) > 1.0f);
    }
    if(_S12)
    {
        return false;
    }
    (*t_1) = f_0 * dot(e2_0, q_0);
    (*bary_0) = vec2<f32>(u_0, v_0);
    if(((*t_1) > tMin_1))
    {
        _S12 = ((*t_1) < tMax_1);
    }
    else
    {
        _S12 = false;
    }
    return _S12;
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_1 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_2 : f32,  tMax_2 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_1) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_1) * rD_0;
    var _S13 : vec3<f32> = min(t1_0, t2_0);
    var _S14 : vec3<f32> = max(t1_0, t2_0);
    var _S15 : f32 = max(max(_S13.x, _S13.y), max(_S13.z, tMin_2));
    var _S16 : f32;
    if((_S15 <= (min(min(_S14.x, _S14.y), min(_S14.z, tMax_2)))))
    {
        _S16 = _S15;
    }
    else
    {
        _S16 = 1.00000001504746622e+30f;
    }
    return _S16;
}

fn TraverseBLAS_0( _S17 : u32,  _S18 : u32,  _S19 : vec3<f32>,  _S20 : vec3<f32>,  _S21 : f32,  _S22 : bool,  _S23 : ptr<function, HitRecord_0>) -> bool
{
    var found_0 : bool;
    var _S24 : vec3<f32> = SafeRcp_0(_S20);
    var stack_0 : array<u32, i32(48)>;
    var nodeRef_0 : u32 = u32(0);
    var found_1 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var i_0 : u32;
        if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
        {
            var _S25 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
            var _S26 : u32 = (nodeRef_0 & (u32(16777215)));
            found_0 = found_1;
            i_0 = u32(0);
            loop
            {
                if((i_0 < _S25))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_0 : u32 = (gInstances_0[_S18].blasTriOffset_0 + _S26 + i_0) * u32(3);
                var v0_1 : vec4<f32> = gTris_0[base_0];
                var t_2 : f32;
                var bary_1 : vec2<f32>;
                var _S27 : bool = IntersectTriangle_0(_S19, _S20, v0_1.xyz, gTris_0[base_0 + u32(1)].xyz, gTris_0[base_0 + u32(2)].xyz, _S21, (*_S23).t_0, &(t_2), &(bary_1));
                if(!_S27)
                {
                    i_0 = i_0 + u32(1);
                    continue;
                }
                var primitiveIndex_1 : u32 = (bitcast<u32>((v0_1.w)));
                (*_S23).t_0 = t_2;
                (*_S23).barycentrics_0 = bary_1;
                (*_S23).instanceIndex_0 = _S17;
                (*_S23).primitiveIndex_0 = primitiveIndex_1;
                if(_S22)
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
        var node_0 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S18].blasNodeOffset_0 + nodeRef_0];
        var dist1_0 : f32 = IntersectBox_0(node_0.lmin_0, node_0.lmax_0, _S19, _S24, _S21, (*_S23).t_0);
        var dist2_0 : f32 = IntersectBox_0(node_0.rmin_0, node_0.rmax_0, _S19, _S24, _S21, (*_S23).t_0);
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
                var _S28 : u32 = stackPtr_0 + u32(1);
                stack_0[stackPtr_0] = far_0;
                stackPtr_3 = _S28;
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
    var _S29 : u32 = gFrame_0.counts_0.z;
    var _S30 : vec3<f32> = SafeRcp_0(ray_0.direction_0);
    var stack_1 : array<u32, i32(32)>;
    var nodeRef_1 : u32 = u32(0);
    var found_3 : bool = false;
    var stackPtr_4 : u32 = u32(0);
    loop
    {
        var i_1 : u32;
        if(((nodeRef_1 & (u32(2147483648)))) != u32(0))
        {
            var _S31 : u32 = (((nodeRef_1 >> (u32(24)))) & (u32(127)));
            var _S32 : u32 = (nodeRef_1 & (u32(16777215)));
            found_2 = found_3;
            i_1 = u32(0);
            loop
            {
                if((i_1 < _S31))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_1 : u32 = gIndices_0[_S29 + _S32 + i_1];
                var _S33 : bool = TraverseBLAS_0(instanceIndex_1, instanceIndex_1, InverseTransformPoint_0(instanceIndex_1, ray_0.origin_0), InverseTransformVector_0(instanceIndex_1, ray_0.direction_0), ray_0.tMin_0, anyHit_0, &((*hit_0)));
                if(_S33)
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
        var dist1_2 : f32 = IntersectBox_0(node_1.lmin_0, node_1.lmax_0, ray_0.origin_0, _S30, ray_0.tMin_0, (*hit_0).t_0);
        var dist2_2 : f32 = IntersectBox_0(node_1.rmin_0, node_1.rmax_0, ray_0.origin_0, _S30, ray_0.tMin_0, (*hit_0).t_0);
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
                var _S34 : u32 = stackPtr_4 + u32(1);
                stack_1[stackPtr_4] = far_1;
                stackPtr_7 = _S34;
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

fn TraceOcclusion_0( ray_1 : Ray_0) -> bool
{
    var hit_1 : HitRecord_0;
    var _S35 : bool = TraceScene_0(ray_1, true, &(hit_1));
    return _S35;
}

struct MaterialHeader_0
{
     surface_0 : u32,
     opacity_0 : u32,
     emission_0 : u32,
     flags_1 : u32,
     textureBase_0 : u32,
     constantBase_0 : u32,
     alphaCutoff_0 : f32,
     debugTexture_0 : u32,
};

fn LoadMaterialHeader_0( materialIndex_1 : u32) -> MaterialHeader_0
{
    var _S36 : u32 = materialIndex_1 * u32(2);
    var h0_0 : vec4<u32> = gMaterialData_0[_S36];
    var h1_0 : vec4<u32> = gMaterialData_0[_S36 + u32(1)];
    var h_1 : MaterialHeader_0;
    h_1.surface_0 = h0_0.x;
    h_1.opacity_0 = h0_0.y;
    h_1.emission_0 = h0_0.z;
    h_1.flags_1 = h0_0.w;
    h_1.textureBase_0 = h1_0.x;
    h_1.constantBase_0 = h1_0.y;
    h_1.alphaCutoff_0 = (bitcast<f32>((h1_0.z)));
    h_1.debugTexture_0 = h1_0.w;
    return h_1;
}

fn MaterialHeader_AlphaMode_0( this_0 : MaterialHeader_0) -> u32
{
    return ((((this_0.flags_1) >> (u32(8)))) & (u32(3)));
}

fn LoadTriangleIndices_0( _S37 : u32,  _S38 : u32) -> vec3<u32>
{
    var base_1 : u32 = gInstances_0[_S37].indexOffset_0 + _S38 * u32(3);
    return vec3<u32>(gIndices_0[base_1], gIndices_0[base_1 + u32(1)], gIndices_0[base_1 + u32(2)]) + vec3<u32>(gInstances_0[_S37].vertexOffset_0);
}

fn VertexUV0_0( v_1 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_1).positionU_0.w, (*v_1).normalV_0.w);
}

fn TransformVector_0( _S39 : u32,  _S40 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S39].objectToWorld_0[i32(0)].xyz, _S40), dot(gInstances_0[_S39].objectToWorld_0[i32(1)].xyz, _S40), dot(gInstances_0[_S39].objectToWorld_0[i32(2)].xyz, _S40));
}

var<private> gRayCone_0 : vec2<f32>;

struct TextureCoords_0
{
     uv0_0 : vec2<f32>,
     uv1_1 : vec2<f32>,
     footprint0_0 : f32,
     footprint1_0 : f32,
     objectPosition_0 : vec3<f32>,
};

fn UVFootprintLog2_0( coneWidth_0 : f32,  worldArea_0 : f32,  uvArea_0 : f32,  cosTheta_0 : f32) -> f32
{
    return log2(max(coneWidth_0, 9.99999968265522539e-21f)) - log2(max(abs(cosTheta_0), 0.0010000000474974513f)) + 0.5f * log2(max(uvArea_0 / max(worldArea_0, 1.00000000317107685e-30f), 1.00000000317107685e-30f));
}

fn MakeTextureCoords_0( uv0_1 : vec2<f32>,  uv1_2 : vec2<f32>,  worldE1_0 : vec3<f32>,  worldE2_0 : vec3<f32>,  uv0E1_0 : vec2<f32>,  uv0E2_0 : vec2<f32>,  uv1E1_0 : vec2<f32>,  uv1E2_0 : vec2<f32>,  coneWidth_1 : f32,  cosTheta_1 : f32) -> TextureCoords_0
{
    var tc_0 : TextureCoords_0;
    tc_0.uv0_0 = uv0_1;
    tc_0.uv1_1 = uv1_2;
    tc_0.objectPosition_0 = vec3<f32>(0.0f);
    var worldArea_1 : f32 = length(cross(worldE1_0, worldE2_0));
    tc_0.footprint0_0 = UVFootprintLog2_0(coneWidth_1, worldArea_1, abs(uv0E1_0.x * uv0E2_0.y - uv0E1_0.y * uv0E2_0.x), cosTheta_1);
    tc_0.footprint1_0 = UVFootprintLog2_0(coneWidth_1, worldArea_1, abs(uv1E1_0.x * uv1E2_0.y - uv1E1_0.y * uv1E2_0.x), cosTheta_1);
    return tc_0;
}

struct Frame_0
{
     t_3 : vec3<f32>,
     b_0 : vec3<f32>,
     n_1 : vec3<f32>,
};

struct BSDFInputs_0
{
     baseWeight_0 : f32,
     baseColor_0 : vec3<f32>,
     baseDiffuseRoughness_0 : f32,
     baseMetalness_0 : f32,
     subsurfaceWeight_0 : f32,
     subsurfaceColor_0 : vec3<f32>,
     subsurfaceRadius_0 : f32,
     subsurfaceRadiusScale_0 : vec3<f32>,
     subsurfaceScatterAnisotropy_0 : f32,
     specularWeight_0 : f32,
     specularDielectricOnly_0 : bool,
     specularColor_0 : vec3<f32>,
     specularRoughness_0 : f32,
     specularRoughnessAnisotropy_0 : f32,
     specularIor_0 : f32,
     specularAnisotropyRotation_0 : vec2<f32>,
     coatWeight_0 : f32,
     coatColor_0 : vec3<f32>,
     coatRoughness_0 : f32,
     coatRoughnessAnisotropy_0 : f32,
     coatIor_0 : f32,
     coatDarkening_0 : f32,
     coatAnisotropyRotation_0 : vec2<f32>,
     fuzzWeight_0 : f32,
     fuzzColor_0 : vec3<f32>,
     fuzzRoughness_0 : f32,
     transmissionWeight_0 : f32,
     transmissionColor_0 : vec3<f32>,
     transmissionDepth_0 : f32,
     transmissionScatter_0 : vec3<f32>,
     transmissionScatterAnisotropy_0 : f32,
     transmissionDispersionScale_0 : f32,
     transmissionDispersionAbbeNumber_0 : f32,
     thinFilmWeight_0 : f32,
     thinFilmThickness_0 : f32,
     thinFilmIor_0 : f32,
     emissionLuminance_0 : f32,
     emissionColor_0 : vec3<f32>,
     geometryOpacity_0 : f32,
     geometryThinWalled_0 : bool,
     basis_0 : Frame_0,
     coatBasis_0 : Frame_0,
};

struct MaterialOutputs_0
{
     inputs_0 : BSDFInputs_0,
     normal_0 : vec3<f32>,
     coatNormal_0 : vec3<f32>,
     tangent_1 : vec3<f32>,
     coatTangent_0 : vec3<f32>,
};

struct MaterialContext_0
{
     tex_0 : TextureCoords_0,
     position_0 : vec3<f32>,
     normal_1 : vec3<f32>,
     tangent_2 : vec4<f32>,
     instanceIndex_2 : u32,
};

fn MakeMaterialContext_0( tex_1 : TextureCoords_0) -> MaterialContext_0
{
    var ctx_0 : MaterialContext_0;
    ctx_0.tex_0 = tex_1;
    ctx_0.position_0 = vec3<f32>(0.0f);
    ctx_0.normal_1 = vec3<f32>(0.0f, 0.0f, 1.0f);
    ctx_0.tangent_2 = vec4<f32>(0.0f);
    ctx_0.instanceIndex_2 = u32(0);
    return ctx_0;
}

fn BSDFInputs_Default_0() -> BSDFInputs_0
{
    var i_2 : BSDFInputs_0;
    i_2.baseWeight_0 = 1.0f;
    var _S41 : vec3<f32> = vec3<f32>(0.80000001192092896f);
    i_2.baseColor_0 = _S41;
    i_2.baseDiffuseRoughness_0 = 0.0f;
    i_2.baseMetalness_0 = 0.0f;
    i_2.subsurfaceWeight_0 = 0.0f;
    i_2.subsurfaceColor_0 = _S41;
    i_2.subsurfaceRadius_0 = 1.0f;
    i_2.subsurfaceRadiusScale_0 = vec3<f32>(1.0f, 0.5f, 0.25f);
    i_2.subsurfaceScatterAnisotropy_0 = 0.0f;
    i_2.specularWeight_0 = 1.0f;
    i_2.specularDielectricOnly_0 = false;
    var _S42 : vec3<f32> = vec3<f32>(1.0f);
    i_2.specularColor_0 = _S42;
    i_2.specularRoughness_0 = 0.30000001192092896f;
    i_2.specularRoughnessAnisotropy_0 = 0.0f;
    i_2.specularIor_0 = 1.5f;
    const _S43 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    i_2.specularAnisotropyRotation_0 = _S43;
    i_2.coatWeight_0 = 0.0f;
    i_2.coatColor_0 = _S42;
    i_2.coatRoughness_0 = 0.0f;
    i_2.coatRoughnessAnisotropy_0 = 0.0f;
    i_2.coatIor_0 = 1.6000000238418579f;
    i_2.coatDarkening_0 = 1.0f;
    i_2.coatAnisotropyRotation_0 = _S43;
    i_2.fuzzWeight_0 = 0.0f;
    i_2.fuzzColor_0 = _S42;
    i_2.fuzzRoughness_0 = 0.5f;
    i_2.transmissionWeight_0 = 0.0f;
    i_2.transmissionColor_0 = _S42;
    i_2.transmissionDepth_0 = 0.0f;
    i_2.transmissionScatter_0 = vec3<f32>(0.0f);
    i_2.transmissionScatterAnisotropy_0 = 0.0f;
    i_2.transmissionDispersionScale_0 = 0.0f;
    i_2.transmissionDispersionAbbeNumber_0 = 20.0f;
    i_2.thinFilmWeight_0 = 0.0f;
    i_2.thinFilmThickness_0 = 0.5f;
    i_2.thinFilmIor_0 = 1.3999999761581421f;
    i_2.emissionLuminance_0 = 0.0f;
    i_2.emissionColor_0 = _S42;
    i_2.geometryOpacity_0 = 1.0f;
    i_2.geometryThinWalled_0 = false;
    i_2.basis_0.t_3 = vec3<f32>(1.0f, 0.0f, 0.0f);
    i_2.basis_0.b_0 = vec3<f32>(0.0f, 1.0f, 0.0f);
    i_2.basis_0.n_1 = vec3<f32>(0.0f, 0.0f, 1.0f);
    i_2.coatBasis_0 = i_2.basis_0;
    return i_2;
}

fn MaterialOutputs_Default_0( ctx_1 : MaterialContext_0) -> MaterialOutputs_0
{
    var o_2 : MaterialOutputs_0;
    o_2.inputs_0 = BSDFInputs_Default_0();
    o_2.normal_0 = ctx_1.normal_1;
    o_2.coatNormal_0 = ctx_1.normal_1;
    var _S44 : vec3<f32> = ctx_1.tangent_2.xyz;
    o_2.tangent_1 = _S44;
    o_2.coatTangent_0 = _S44;
    return o_2;
}

fn MaterialOperand_0( operand_0 : u32,  slot_0 : vec4<f32>,  constantBase_1 : u32) -> vec4<f32>
{
    if(operand_0 == u32(4294967295))
    {
        return vec4<f32>(0.0f);
    }
    if(((operand_0 & (u32(2147483648)))) != u32(0))
    {
        return (bitcast<vec4<f32>>((gMaterialData_0[constantBase_1 + ((operand_0 & (u32(2147483647))))])));
    }
    return slot_0;
}

fn LanesBelow_0( size_0 : u32) -> vec4<bool>
{
    return (vec4<u32>(u32(0), u32(1), u32(2), u32(3)) < vec4<u32>(size_0));
}

fn MaterialWord_0( index_0 : u32) -> u32
{
    return gMaterialData_0[(index_0 >> (u32(2)))][(index_0 & (u32(3)))];
}

struct TextureRef_0
{
     flags_2 : u32,
     pageTableOffset_0 : u32,
     reserved_0 : u32,
     rotation_0 : f32,
     scaleOffset_0 : vec4<f32>,
};

fn LoadTextureRef_0( header_0 : MaterialHeader_0,  index_1 : u32) -> TextureRef_0
{
    var _S45 : u32 = header_0.textureBase_0 + index_1 * u32(2);
    var a_1 : vec4<u32> = gMaterialData_0[_S45];
    var ref_0 : TextureRef_0;
    ref_0.flags_2 = a_1.x;
    ref_0.pageTableOffset_0 = a_1.y;
    ref_0.reserved_0 = a_1.z;
    ref_0.rotation_0 = (bitcast<f32>((a_1.w)));
    ref_0.scaleOffset_0 = (bitcast<vec4<f32>>((gMaterialData_0[_S45 + u32(1)])));
    return ref_0;
}

fn HasTexture_0( ref_1 : TextureRef_0) -> bool
{
    return (((ref_1.flags_2) & (u32(1)))) != u32(0);
}

fn TransformUV_0( ref_2 : TextureRef_0,  uv_0 : vec2<f32>) -> vec2<f32>
{
    var s_1 : vec2<f32> = ref_2.scaleOffset_0.xy * uv_0;
    var c_0 : f32 = cos(ref_2.rotation_0);
    var r_0 : f32 = sin(ref_2.rotation_0);
    var _S46 : f32 = s_1.x;
    var _S47 : f32 = s_1.y;
    return vec2<f32>(c_0 * _S46 + r_0 * _S47, - r_0 * _S46 + c_0 * _S47) + ref_2.scaleOffset_0.zw;
}

fn WrapCoord_0( x_5 : f32,  mode_0 : u32) -> f32
{
    if(mode_0 == u32(1))
    {
        return saturate(x_5);
    }
    if(mode_0 == u32(2))
    {
        var t_4 : f32 = x_5 - 2.0f * floor(x_5 * 0.5f);
        var _S48 : f32;
        if((t_4 > 1.0f))
        {
            _S48 = 2.0f - t_4;
        }
        else
        {
            _S48 = t_4;
        }
        return _S48;
    }
    return fract(x_5);
}

fn VTLevels_0( ref_3 : TextureRef_0) -> u32
{
    return ((((ref_3.flags_2) >> (u32(12)))) & (u32(15)));
}

fn VTLog2Width_0( ref_4 : TextureRef_0) -> u32
{
    return ((((ref_4.flags_2) >> (u32(16)))) & (u32(15)));
}

fn VTLog2Height_0( ref_5 : TextureRef_0) -> u32
{
    return ((((ref_5.flags_2) >> (u32(20)))) & (u32(15)));
}

var<private> gVTRandom_0 : u32;

fn NextVTRandom_0() -> u32
{
    var _S49 : u32 = u32(1664525) * gVTRandom_0 + u32(1013904223);
    gVTRandom_0 = _S49;
    return _S49;
}

fn VTPageCount_0( log2Size_0 : vec2<u32>,  level_0 : u32) -> vec2<u32>
{
    var _S50 : vec2<i32> = max(vec2<i32>(log2Size_0) - vec2<i32>(i32(level_0)) - vec2<i32>(i32(7)), vec2<i32>(i32(0)));
    return vec2<u32>((u32(1) << (u32(_S50.x))), (u32(1) << (u32(_S50.y))));
}

fn VTLevelSize_0( log2Size_1 : vec2<u32>,  level_1 : u32) -> vec2<f32>
{
    var _S51 : vec2<i32> = max(vec2<i32>(log2Size_1) - vec2<i32>(i32(level_1)), vec2<i32>(i32(0)));
    return vec2<f32>(f32((u32(1) << (u32(_S51.x)))), f32((u32(1) << (u32(_S51.y)))));
}

var<private> gVTRequestCount_0 : u32;

var<private> gVTRequest_0 : u32;

fn StoreVirtualTextureFeedback_0( pageIndex_0 : u32)
{
    gVTRequestCount_0 = gVTRequestCount_0 + u32(1);
    var _S52 : u32 = NextVTRandom_0();
    if(((f32((_S52 >> (u32(8)))) * 5.9604644775390625e-08f * f32(gVTRequestCount_0)) < 1.0f))
    {
        gVTRequest_0 = pageIndex_0 + u32(1);
    }
    return;
}

fn VTLoadEntry_0( index_2 : u32) -> u32
{
    var width_0 : u32 = gFrame_0.vtInfo_0.y;
    var _S53 : u32 = index_2 % width_0;
    var _S54 : i32 = i32(_S53);
    var _S55 : u32 = index_2 / width_0;
    var _S56 : vec3<i32> = vec3<i32>(_S54, i32(_S55), i32(0));
    return (textureLoad((gVTPageTable_0), ((_S56)).xy, ((_S56)).z).x);
}

var<private> gVTLastMappedLevel_0 : u32;

var<private> gVTLastRequestedLevel_0 : u32;

fn SampleVirtualTexture_0( ref_6 : TextureRef_0,  uv_1 : vec2<f32>,  uvFootprint_0 : f32) -> vec4<f32>
{
    var levels_0 : u32 = VTLevels_0(ref_6);
    var _S57 : u32 = VTLog2Width_0(ref_6);
    var _S58 : u32 = VTLog2Height_0(ref_6);
    var log2Size_2 : vec2<u32> = vec2<u32>(_S57, _S58);
    var lod_0 : f32 = uvFootprint_0 + 0.5f * (f32(_S57 + _S58) + log2(max(abs(ref_6.scaleOffset_0.x * ref_6.scaleOffset_0.y), 9.99999968265522539e-21f))) + gFrame_0.vtParams_0.z;
    var _S59 : u32 = NextVTRandom_0();
    var level_2 : u32 = u32(clamp(floor(lod_0 + f32((_S59 >> (u32(8)))) * 5.9604644775390625e-08f), 0.0f, f32(levels_0 - u32(1))));
    var l_0 : u32 = u32(0);
    var index_3 : u32 = ref_6.pageTableOffset_0;
    loop
    {
        if((l_0 < level_2))
        {
        }
        else
        {
            break;
        }
        var n_2 : vec2<u32> = VTPageCount_0(log2Size_2, l_0);
        var index_4 : u32 = index_3 + n_2.x * n_2.y;
        l_0 = l_0 + u32(1);
        index_3 = index_4;
    }
    var pages_0 : vec2<u32> = VTPageCount_0(log2Size_2, level_2);
    var _S60 : vec2<u32> = min((vec2<u32>(uv_1 * VTLevelSize_0(log2Size_2, level_2)) >> (vec2<u32>(u32(7)))), pages_0 - vec2<u32>(u32(1)));
    var index_5 : u32 = index_3 + (_S60.y * pages_0.x + _S60.x);
    StoreVirtualTextureFeedback_0(index_5);
    var entry_0 : u32 = VTLoadEntry_0(index_5);
    if(((entry_0 & (u32(2147483648)))) == u32(0))
    {
        return vec4<f32>(1.0f, 0.0f, 1.0f, 1.0f);
    }
    var mappedLevel_0 : u32 = (((entry_0 >> (u32(16)))) & (u32(15)));
    gVTLastMappedLevel_0 = mappedLevel_0;
    gVTLastRequestedLevel_0 = level_2;
    var local_0 : vec2<f32> = uv_1 * VTLevelSize_0(log2Size_2, mappedLevel_0) - vec2<f32>((_S60 >> (vec2<u32>((mappedLevel_0 - level_2))))) * vec2<f32>(128.0f);
    var tile_0 : u32 = (entry_0 & (u32(65535)));
    var tilesPerRow_0 : u32 = gFrame_0.vtInfo_0.x;
    var _S61 : u32 = tile_0 % tilesPerRow_0;
    var _S62 : f32 = f32(_S61);
    var _S63 : u32 = tile_0 / tilesPerRow_0;
    return (textureSampleLevel((gVTPhysical_0), (gLinearSampler_0), ((vec2<f32>(_S62, f32(_S63)) * vec2<f32>(136.0f) + vec2<f32>(4.0f) + local_0) * vec2<f32>(gFrame_0.vtParams_0.x)), (0.0f)));
}

fn SrgbToLinear_0( c_1 : vec3<f32>) -> vec3<f32>
{
    return select(pow((c_1 + vec3<f32>(0.054999999701976776f)) / vec3<f32>(1.0549999475479126f), vec3<f32>(2.4000000953674316f)), c_1 / vec3<f32>(12.920000076293945f), (c_1 <= vec3<f32>(0.040449999272823334f)));
}

fn SampleTexture_0( ref_7 : TextureRef_0,  tc_1 : TextureCoords_0) -> vec4<f32>
{
    var useUV1_0 : bool = (((ref_7.flags_2) & (u32(4)))) != u32(0);
    var uv_2 : vec2<f32>;
    var _S64 : vec2<f32>;
    if(useUV1_0)
    {
        _S64 = tc_1.uv1_1;
    }
    else
    {
        _S64 = tc_1.uv0_0;
    }
    var _S65 : vec2<f32> = TransformUV_0(ref_7, _S64);
    uv_2 = _S65;
    uv_2[i32(0)] = WrapCoord_0(_S65.x, ((((ref_7.flags_2) >> (u32(8)))) & (u32(3))));
    uv_2[i32(1)] = WrapCoord_0(uv_2.y, ((((ref_7.flags_2) >> (u32(10)))) & (u32(3))));
    var color_0 : vec4<f32>;
    var _S66 : vec2<f32> = uv_2;
    var _S67 : f32;
    if(useUV1_0)
    {
        _S67 = tc_1.footprint1_0;
    }
    else
    {
        _S67 = tc_1.footprint0_0;
    }
    var _S68 : vec4<f32> = SampleVirtualTexture_0(ref_7, _S66, _S67);
    color_0 = _S68;
    if((((ref_7.flags_2) & (u32(2)))) != u32(0))
    {
        var _S69 : vec3<f32> = SrgbToLinear_0(color_0.xyz);
        color_0.x = _S69.x;
        color_0.y = _S69.y;
        color_0.z = _S69.z;
    }
    return color_0;
}

fn HashRotate_0( x_6 : u32,  k_0 : u32) -> u32
{
    return (((x_6 << (k_0))) | (((x_6 >> ((u32(32) - k_0))))));
}

fn HashFinal_0( a_2 : u32,  b_1 : u32,  c_2 : u32) -> u32
{
    var _S70 : u32 = ((c_2 ^ (b_1))) - HashRotate_0(b_1, u32(14));
    var _S71 : u32 = ((a_2 ^ (_S70))) - HashRotate_0(_S70, u32(11));
    var _S72 : u32 = ((b_1 ^ (_S71))) - HashRotate_0(_S71, u32(25));
    var _S73 : u32 = ((_S70 ^ (_S72))) - HashRotate_0(_S72, u32(16));
    var _S74 : u32 = ((_S71 ^ (_S73))) - HashRotate_0(_S73, u32(4));
    var _S75 : u32 = ((_S72 ^ (_S74))) - HashRotate_0(_S74, u32(14));
    return ((_S73 ^ (_S75))) - HashRotate_0(_S75, u32(24));
}

fn HashUint2_0( kx_0 : u32,  ky_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928580) + kx_0, u32(3735928580) + ky_0, u32(3735928580));
}

fn RandomOffset3_0( seed_0 : f32) -> vec3<f32>
{
    var _S76 : u32 = (bitcast<u32>((seed_0)));
    return vec3<f32>(100.0f) + vec3<f32>(f32(HashUint2_0(_S76, (bitcast<u32>((0.0f))))), f32(HashUint2_0(_S76, (bitcast<u32>((1.0f))))), f32(HashUint2_0(_S76, (bitcast<u32>((2.0f)))))) * vec3<f32>(2.32830643653869629e-08f);
}

fn FMod_0( x_7 : f32,  y_0 : f32) -> f32
{
    return x_7 - trunc(x_7 / y_0) * y_0;
}

fn NoiseFade_0( t_5 : f32) -> f32
{
    return t_5 * t_5 * t_5 * (t_5 * (t_5 * 6.0f - 15.0f) + 10.0f);
}

fn HashUint3_0( kx_1 : u32,  ky_1 : u32,  kz_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928584) + kx_1, u32(3735928584) + ky_1, u32(3735928584) + kz_0);
}

fn NoiseGrad3_0( hash_0 : u32,  x_8 : f32,  y_1 : f32,  z_0 : f32) -> f32
{
    var h_2 : u32 = (hash_0 & (u32(15)));
    var u_1 : f32;
    if((h_2 < u32(8)))
    {
        u_1 = x_8;
    }
    else
    {
        u_1 = y_1;
    }
    var v_2 : f32;
    if((h_2 < u32(4)))
    {
        v_2 = y_1;
    }
    else
    {
        var _S77 : bool;
        if(h_2 == u32(12))
        {
            _S77 = true;
        }
        else
        {
            _S77 = h_2 == u32(14);
        }
        if(_S77)
        {
            v_2 = x_8;
        }
        else
        {
            v_2 = z_0;
        }
    }
    if(((h_2 & (u32(1)))) != u32(0))
    {
        u_1 = - u_1;
    }
    if(((h_2 & (u32(2)))) != u32(0))
    {
        v_2 = - v_2;
    }
    return u_1 + v_2;
}

fn Perlin3_0( p_0 : vec3<f32>) -> f32
{
    var i_3 : vec3<f32> = floor(p_0);
    var f_1 : vec3<f32> = p_0 - i_3;
    var _S78 : u32 = (bitcast<u32>((i32(i_3.x))));
    var _S79 : u32 = (bitcast<u32>((i32(i_3.y))));
    var _S80 : u32 = (bitcast<u32>((i32(i_3.z))));
    var _S81 : f32 = f_1.x;
    var u_2 : f32 = NoiseFade_0(_S81);
    var _S82 : f32 = f_1.y;
    var v_3 : f32 = NoiseFade_0(_S82);
    var _S83 : f32 = f_1.z;
    var w_0 : f32 = NoiseFade_0(_S83);
    var g_0 : array<f32, i32(8)>;
    var c_3 : u32 = u32(0);
    loop
    {
        if((c_3 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var _S84 : u32 = (c_3 & (u32(1)));
        var _S85 : u32 = (((c_3 >> (u32(1)))) & (u32(1)));
        var _S86 : u32 = (c_3 >> (u32(2)));
        g_0[c_3] = NoiseGrad3_0(HashUint3_0(_S78 + _S84, _S79 + _S85, _S80 + _S86), _S81 - f32(_S84), _S82 - f32(_S85), _S83 - f32(_S86));
        c_3 = c_3 + u32(1);
    }
    return mix(mix(mix(g_0[i32(0)], g_0[i32(1)], u_2), mix(g_0[i32(2)], g_0[i32(3)], u_2), v_3), mix(mix(g_0[i32(4)], g_0[i32(5)], u_2), mix(g_0[i32(6)], g_0[i32(7)], u_2), v_3), w_0);
}

fn SNoise3_0( p_1 : vec3<f32>) -> f32
{
    return 0.98199999332427979f * Perlin3_0(vec3<f32>(FMod_0(p_1.x, 1.0e+05f), FMod_0(p_1.y, 1.0e+05f), FMod_0(p_1.z, 1.0e+05f)) + select(vec3<f32>(0.0f), vec3<f32>(0.5f), ((abs(p_1)) >= vec3<f32>(1.0e+06f))));
}

fn NoiseFbm_0( p_2 : vec3<f32>,  detail_0 : f32,  roughness_0 : f32,  lacunarity_0 : f32,  normalize_0 : bool) -> f32
{
    var sum2_0 : f32;
    var octaves_0 : i32 = i32(detail_0);
    var rmd_0 : f32 = detail_0 - floor(detail_0);
    var _S87 : bool = rmd_0 != 0.0f;
    var _S88 : i32;
    if(_S87)
    {
        _S88 = octaves_0 + i32(1);
    }
    else
    {
        _S88 = octaves_0;
    }
    var i_4 : i32 = i32(0);
    var fscale_0 : f32 = 1.0f;
    var sum_0 : f32 = 0.0f;
    var amp_0 : f32 = 1.0f;
    var maxamp_0 : f32 = 0.0f;
    loop
    {
        if((i_4 <= _S88))
        {
        }
        else
        {
            sum2_0 = 0.0f;
            break;
        }
        var n_3 : f32 = SNoise3_0(vec3<f32>(fscale_0) * p_2);
        if((i_4 > octaves_0))
        {
            sum2_0 = sum_0 + n_3 * amp_0;
            break;
        }
        var sum_1 : f32 = sum_0 + n_3 * amp_0;
        var maxamp_1 : f32 = maxamp_0 + amp_0;
        var amp_1 : f32 = amp_0 * roughness_0;
        var fscale_1 : f32 = fscale_0 * lacunarity_0;
        i_4 = i_4 + i32(1);
        fscale_0 = fscale_1;
        sum_0 = sum_1;
        amp_0 = amp_1;
        maxamp_0 = maxamp_1;
    }
    if(_S87)
    {
        var a_3 : f32;
        if(normalize_0)
        {
            a_3 = 0.5f * sum_0 / maxamp_0 + 0.5f;
        }
        else
        {
            a_3 = sum_0;
        }
        var b_2 : f32;
        if(normalize_0)
        {
            b_2 = 0.5f * sum2_0 / (maxamp_0 + amp_0) + 0.5f;
        }
        else
        {
            b_2 = sum2_0;
        }
        return mix(a_3, b_2, rmd_0);
    }
    if(normalize_0)
    {
        fscale_0 = 0.5f * sum_0 / maxamp_0 + 0.5f;
    }
    else
    {
        fscale_0 = sum_0;
    }
    return fscale_0;
}

fn BlenderNoise_0( co_0 : vec3<f32>,  params_0 : vec4<f32>,  normalize_1 : bool,  color_1 : bool) -> vec3<f32>
{
    var _S89 : f32 = clamp(params_0.x, 0.0f, 15.0f);
    var _S90 : f32 = max(params_0.y, 0.0f);
    var _S91 : f32 = params_0.z;
    var distortion_0 : f32 = params_0.w;
    var k_1 : u32;
    var p_3 : vec3<f32>;
    if(distortion_0 != 0.0f)
    {
        var offset_0 : vec3<f32>;
        k_1 = u32(0);
        loop
        {
            if((k_1 < u32(3)))
            {
            }
            else
            {
                break;
            }
            offset_0[k_1] = SNoise3_0(co_0 + RandomOffset3_0(f32(k_1)));
            k_1 = k_1 + u32(1);
        }
        p_3 = co_0 + offset_0 * vec3<f32>(distortion_0);
    }
    else
    {
        p_3 = co_0;
    }
    var result_0 : vec3<f32>;
    k_1 = u32(0);
    loop
    {
        var _S92 : u32;
        if(color_1)
        {
            _S92 = u32(3);
        }
        else
        {
            _S92 = u32(1);
        }
        if((k_1 < _S92))
        {
        }
        else
        {
            break;
        }
        var _S93 : vec3<f32>;
        if(k_1 == u32(0))
        {
            _S93 = p_3;
        }
        else
        {
            _S93 = p_3 + RandomOffset3_0(f32(k_1 + u32(2)));
        }
        result_0[k_1] = NoiseFbm_0(_S93, _S89, _S90, _S91, normalize_1);
        k_1 = k_1 + u32(1);
    }
    if(color_1)
    {
        p_3 = result_0;
    }
    else
    {
        p_3 = vec3<f32>(result_0.x);
    }
    return p_3;
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn BlenderMagic_0( p_4 : vec3<f32>,  depth_0 : u32,  d_2 : f32) -> vec3<f32>
{
    var TWO_PI_0 : f32 = 2.0f * float_getPi_0();
    var px_0 : f32 = FMod_0(p_4.x, TWO_PI_0);
    var py_0 : f32 = FMod_0(p_4.y, TWO_PI_0);
    var pz_0 : f32 = FMod_0(p_4.z, TWO_PI_0);
    var x_9 : f32 = sin((px_0 + py_0 + pz_0) * 5.0f);
    var _S94 : f32 = - px_0;
    var y_2 : f32 = cos((_S94 + py_0 - pz_0) * 5.0f);
    var z_1 : f32 = - cos((_S94 - py_0 + pz_0) * 5.0f);
    var x_10 : f32;
    var z_2 : f32;
    var y_3 : f32;
    if((depth_0 > u32(0)))
    {
        var x_11 : f32 = x_9 * d_2;
        var z_3 : f32 = z_1 * d_2;
        var y_4 : f32 = - cos(x_11 - y_2 * d_2 + z_3) * d_2;
        if((depth_0 > u32(1)))
        {
            x_10 = cos(x_11 - y_4 - z_3) * d_2;
        }
        else
        {
            x_10 = x_11;
        }
        if((depth_0 > u32(2)))
        {
            z_2 = sin(- x_10 - y_4 - z_3) * d_2;
        }
        else
        {
            z_2 = z_3;
        }
        if((depth_0 > u32(3)))
        {
            x_10 = - cos(- x_10 + y_4 - z_2) * d_2;
        }
        if((depth_0 > u32(4)))
        {
            y_3 = - sin(- x_10 + y_4 + z_2) * d_2;
        }
        else
        {
            y_3 = y_4;
        }
        if((depth_0 > u32(5)))
        {
            y_3 = - cos(- x_10 + y_3 + z_2) * d_2;
        }
        if((depth_0 > u32(6)))
        {
            x_10 = cos(x_10 + y_3 + z_2) * d_2;
        }
        if((depth_0 > u32(7)))
        {
            z_2 = sin(x_10 + y_3 - z_2) * d_2;
        }
        if((depth_0 > u32(8)))
        {
            x_10 = - cos(- x_10 - y_3 + z_2) * d_2;
        }
        if((depth_0 > u32(9)))
        {
            y_3 = - sin(x_10 - y_3 + z_2) * d_2;
        }
    }
    else
    {
        x_10 = x_9;
        y_3 = y_2;
        z_2 = z_1;
    }
    if(d_2 != 0.0f)
    {
        var _S95 : f32 = 2.0f * d_2;
        var y_5 : f32 = y_3 / _S95;
        var z_4 : f32 = z_2 / _S95;
        x_10 = x_10 / _S95;
        y_3 = y_5;
        z_2 = z_4;
    }
    return vec3<f32>(0.5f - x_10, 0.5f - y_3, 0.5f - z_2);
}

fn BlenderChecker_0( p_5 : vec3<f32>) -> f32
{
    var i_5 : vec3<i32> = abs(vec3<i32>(floor((p_5 + vec3<f32>(9.99999997475242708e-07f)) * vec3<f32>(0.99999898672103882f))));
    var _S96 : f32;
    if(((((i_5.x) & (i32(1)))) == (((i_5.y) & (i32(1))))) == ((((i_5.z) & (i32(1)))) == i32(1)))
    {
        _S96 = 1.0f;
    }
    else
    {
        _S96 = 0.0f;
    }
    return _S96;
}

fn RunMaterialProgram_0( header_1 : MaterialHeader_0,  program_0 : u32,  ctx_2 : MaterialContext_0,  outputs_0 : ptr<function, MaterialOutputs_0>)
{
    var stack_2 : array<vec4<f32>, i32(16)>;
    var n_4 : u32 = u32(0);
    var pc_0 : u32 = program_0;
    loop
    {
        if((n_4 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var ins_0 : vec4<u32> = gMaterialData_0[pc_0];
        var _S97 : u32 = ins_0.x;
        var op_0 : u32 = (_S97 & (u32(255)));
        var dst_0 : u32 = (((_S97 >> (u32(8)))) & (u32(15)));
        var imm_0 : u32 = (_S97 >> (u32(16)));
        if(op_0 == u32(0))
        {
            return;
        }
        var _S98 : u32 = ins_0.y;
        var a_4 : vec4<f32> = MaterialOperand_0(_S98, stack_2[(_S98 & (u32(15)))], header_1.constantBase_0);
        var _S99 : u32 = ins_0.z;
        var b_3 : vec4<f32> = MaterialOperand_0(_S99, stack_2[(_S99 & (u32(15)))], header_1.constantBase_0);
        var _S100 : u32 = ins_0.w;
        var c_4 : vec4<f32> = MaterialOperand_0(_S100, stack_2[(_S100 & (u32(15)))], header_1.constantBase_0);
        var operands_0 : u32 = pc_0 * u32(4) + u32(1);
        var _S101 : u32;
        if(op_0 == u32(23))
        {
            _S101 = (((u32(351898) >> ((u32(2) * min(imm_0, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_0 == u32(17))
            {
                _S101 = u32(1) + imm_0 / u32(4);
            }
            else
            {
                _S101 = u32(1);
            }
        }
        var pc_1 : u32 = pc_0 + _S101;
        var _S102 : vec4<f32> = vec4<f32>(0.0f);
        var r_1 : vec4<f32> = _S102;
        var _S103 : vec4<f32>;
        var write_0 : bool;
        switch(op_0)
        {
        case u32(1):
            {
                r_1 = a_4 + b_3;
                write_0 = true;
            }
        case u32(2):
            {
                r_1 = a_4 - b_3;
                write_0 = true;
            }
        case u32(3):
            {
                r_1 = a_4 * b_3;
                write_0 = true;
            }
        case u32(4):
            {
                r_1 = a_4 / b_3;
                write_0 = true;
            }
        case u32(5):
            {
                r_1 = min(a_4, b_3);
                write_0 = true;
            }
        case u32(6):
            {
                r_1 = max(a_4, b_3);
                write_0 = true;
            }
        case u32(7):
            {
                r_1 = pow(a_4, b_3);
                write_0 = true;
            }
        case u32(8):
            {
                r_1 = atan2(a_4, b_3);
                write_0 = true;
            }
        case u32(9):
            {
                r_1 = sqrt(a_4);
                write_0 = true;
            }
        case u32(10):
            {
                r_1 = sin(a_4);
                write_0 = true;
            }
        case u32(11):
            {
                r_1 = cos(a_4);
                write_0 = true;
            }
        case u32(12):
            {
                r_1 = abs(a_4);
                write_0 = true;
            }
        case u32(13):
            {
                r_1 = min(max(a_4, b_3), c_4);
                write_0 = true;
            }
        case u32(14):
            {
                r_1 = mix(a_4, b_3, c_4);
                write_0 = true;
            }
        case u32(15):
            {
                r_1 = vec4<f32>(a_4[min(imm_0, u32(3))]);
                write_0 = true;
            }
        case u32(16):
            {
                r_1 = select(vec4<f32>(f32((imm_0 >> (u32(8))))), a_4, LanesBelow_0((imm_0 & (u32(255)))));
                write_0 = true;
            }
        case u32(17):
            {
                r_1 = vec4<f32>(a_4.x, b_3.x, c_4.x, 0.0f);
                if((imm_0 > u32(3)))
                {
                    var o_3 : u32 = MaterialWord_0(operands_0 + u32(3));
                    r_1[i32(3)] = MaterialOperand_0(o_3, stack_2[(o_3 & (u32(15)))], header_1.constantBase_0).x;
                }
                write_0 = true;
            }
        case u32(18):
            {
                var lanes_0 : vec4<bool> = LanesBelow_0(imm_0);
                r_1 = vec4<f32>(dot(select(_S102, a_4, lanes_0), select(_S102, b_3, lanes_0)));
                write_0 = true;
            }
        case u32(19):
            {
                var len_0 : f32 = length(select(_S102, a_4, LanesBelow_0(imm_0)));
                if((len_0 > 0.0f))
                {
                    _S103 = a_4 / vec4<f32>(len_0);
                }
                else
                {
                    _S103 = _S102;
                }
                r_1 = _S103;
                write_0 = true;
            }
        case u32(20):
            {
                if(imm_0 == u32(0))
                {
                    r_1 = vec4<f32>(ctx_2.tex_0.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_0 == u32(1))
                    {
                        r_1 = vec4<f32>(ctx_2.tex_0.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_0 == u32(6))
                        {
                            r_1 = vec4<f32>(ctx_2.tex_0.objectPosition_0, 0.0f);
                        }
                    }
                }
                write_0 = true;
            }
        case u32(21):
            {
                var ref_8 : TextureRef_0 = LoadTextureRef_0(header_1, imm_0);
                if(HasTexture_0(ref_8))
                {
                    var _S104 : vec4<f32> = SampleTexture_0(ref_8, ctx_2.tex_0);
                    _S103 = _S104;
                }
                else
                {
                    _S103 = vec4<f32>(1.0f);
                }
                r_1 = _S103;
                write_0 = true;
            }
        case u32(22):
            {
                write_0 = true;
            }
        case u32(24):
            {
                r_1 = floor(a_4);
                write_0 = true;
            }
        case u32(25):
            {
                r_1 = vec4<f32>((vec4<i32>(sign((a_4)))));
                write_0 = true;
            }
        case u32(26):
            {
                r_1 = exp(a_4);
                write_0 = true;
            }
        case u32(27):
            {
                r_1 = log(a_4);
                write_0 = true;
            }
        case u32(28):
            {
                r_1 = a_4 - b_3 * floor(a_4 / b_3);
                write_0 = true;
            }
        case u32(29):
            {
                r_1 = select(_S102, vec4<f32>(1.0f), (a_4 > b_3));
                write_0 = true;
            }
        case u32(30):
            {
                r_1 = vec4<f32>(cross(a_4.xyz, b_3.xyz), 0.0f);
                write_0 = true;
            }
        case u32(31):
            {
                write_0 = true;
            }
        case u32(32):
            {
                var _S105 : bool = ((imm_0 & (u32(2)))) != u32(0);
                var v_4 : vec3<f32> = BlenderNoise_0(a_4.xyz, b_3, ((imm_0 & (u32(1)))) != u32(0), _S105);
                if(_S105)
                {
                    _S103 = vec4<f32>(v_4, 0.0f);
                }
                else
                {
                    _S103 = vec4<f32>(v_4.x);
                }
                r_1 = _S103;
                write_0 = true;
            }
        case u32(33):
            {
                var c_5 : vec3<f32> = BlenderMagic_0(a_4.xyz, imm_0, b_3.x);
                r_1 = vec4<f32>(c_5, (c_5.x + c_5.y + c_5.z) / 3.0f);
                write_0 = true;
            }
        case u32(34):
            {
                r_1 = vec4<f32>(BlenderChecker_0(a_4.xyz));
                write_0 = true;
            }
        case u32(23):
            {
                switch(imm_0)
                {
                case u32(0):
                    {
                    }
                case u32(1):
                    {
                    }
                case u32(2):
                    {
                    }
                case u32(3):
                    {
                    }
                case u32(4):
                    {
                    }
                case u32(5):
                    {
                    }
                case u32(6):
                    {
                    }
                case u32(7):
                    {
                    }
                case u32(8):
                    {
                        var o_4 : u32 = MaterialWord_0(operands_0);
                        if(o_4 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_4, stack_2[(o_4 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_5 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_5 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.emissionColor_0 = MaterialOperand_0(o_5, stack_2[(o_5 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_6 : u32 = MaterialWord_0(operands_0);
                        if(o_6 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_6, stack_2[(o_6 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_7 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_7 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_7, stack_2[(o_7 & (u32(15)))], header_1.constantBase_0).x) != 0.0f;
                        }
                    }
                }
                write_0 = false;
            }
        default :
            {
                write_0 = true;
            }
        }
        if(write_0)
        {
            stack_2[dst_0] = r_1;
        }
        n_4 = n_4 + u32(1);
        pc_0 = pc_1;
    }
    return;
}

fn RunScalarMaterialProgram_0( header_2 : MaterialHeader_0,  program_1 : u32,  tc_2 : TextureCoords_0) -> MaterialOutputs_0
{
    var ctx_3 : MaterialContext_0 = MakeMaterialContext_0(tc_2);
    var o_8 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_3);
    RunMaterialProgram_0(header_2, program_1, ctx_3, &(o_8));
    return o_8;
}

fn EvalOpacity_0( header_3 : MaterialHeader_0,  tc_3 : TextureCoords_0) -> f32
{
    if((header_3.opacity_0) == u32(4294967295))
    {
        return 1.0f;
    }
    var _S106 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_3, header_3.opacity_0, tc_3);
    return _S106.inputs_0.geometryOpacity_0;
}

fn StrongIntegerHash_0( x_12 : u32) -> u32
{
    var _S107 : u32 = ((x_12 ^ (((x_12 >> (u32(16))))))) * u32(2819806515);
    var _S108 : u32 = ((_S107 ^ (((_S107 >> (u32(15))))))) * u32(2994267309);
    return (_S108 ^ (((_S108 >> (u32(17))))));
}

fn AlphaTestRejects_0( _S109 : u32,  _S110 : u32,  _S111 : vec2<f32>,  _S112 : f32) -> bool
{
    var material_0 : MaterialHeader_0 = LoadMaterialHeader_0(gInstances_0[_S109].materialIndex_0);
    var _S113 : u32 = MaterialHeader_AlphaMode_0(material_0);
    if(_S113 == u32(0))
    {
        return false;
    }
    var _S114 : vec3<u32> = LoadTriangleIndices_0(_S109, _S110);
    var _S115 : Vertex_std430_0 = gVertices_0[_S114.x];
    var _S116 : Vertex_std430_0 = gVertices_0[_S114.y];
    var _S117 : Vertex_std430_0 = gVertices_0[_S114.z];
    var _S118 : f32 = _S111.x;
    var _S119 : f32 = _S111.y;
    var _S120 : f32 = 1.0f - _S118 - _S119;
    var _S121 : vec2<f32> = VertexUV0_0(&(_S115));
    var _S122 : vec2<f32> = VertexUV0_0(&(_S116));
    var _S123 : vec2<f32> = VertexUV0_0(&(_S117));
    var _S124 : vec2<f32> = vec2<f32>(_S120);
    var _S125 : vec2<f32> = vec2<f32>(_S118);
    var _S126 : vec2<f32> = vec2<f32>(_S119);
    var _S127 : vec2<f32> = _S115.uv1_0.xy;
    var _S128 : vec2<f32> = _S116.uv1_0.xy;
    var _S129 : vec2<f32> = _S117.uv1_0.xy;
    var _S130 : vec3<f32> = _S116.positionU_0.xyz;
    var _S131 : vec3<f32> = _S115.positionU_0.xyz;
    var _S132 : vec3<f32> = _S117.positionU_0.xyz;
    var tc_4 : TextureCoords_0 = MakeTextureCoords_0(_S121 * _S124 + _S122 * _S125 + _S123 * _S126, _S127 * _S124 + _S128 * _S125 + _S129 * _S126, TransformVector_0(_S109, _S130 - _S131), TransformVector_0(_S109, _S132 - _S131), _S122 - _S121, _S123 - _S121, _S128 - _S127, _S129 - _S127, gRayCone_0.x + gRayCone_0.y * _S112, 1.0f);
    tc_4.objectPosition_0 = _S131 * vec3<f32>(_S120) + _S130 * vec3<f32>(_S118) + _S132 * vec3<f32>(_S119);
    var opacity_1 : f32 = EvalOpacity_0(material_0, tc_4);
    if(_S113 == u32(1))
    {
        return (opacity_1 < (material_0.alphaCutoff_0));
    }
    return (opacity_1 < (f32(((StrongIntegerHash_0((_S110 ^ ((StrongIntegerHash_0(((bitcast<u32>((_S112))) ^ ((gFrame_0.frame_0.w))))))))) & (u32(16777215)))) * 5.9604644775390625e-08f));
}

fn TraverseBLAS_1( _S133 : u32,  _S134 : u32,  _S135 : vec3<f32>,  _S136 : vec3<f32>,  _S137 : f32,  _S138 : bool,  _S139 : ptr<function, HitRecord_0>) -> bool
{
    var found_4 : bool;
    var _S140 : vec3<f32> = SafeRcp_0(_S136);
    var _S141 : bool = (((gInstances_0[_S134].flags_0) & (u32(1)))) != u32(0);
    var stack_3 : array<u32, i32(48)>;
    var nodeRef_2 : u32 = u32(0);
    var found_5 : bool = false;
    var stackPtr_8 : u32 = u32(0);
    loop
    {
        var i_6 : u32;
        if(((nodeRef_2 & (u32(2147483648)))) != u32(0))
        {
            var _S142 : u32 = (((nodeRef_2 >> (u32(24)))) & (u32(127)));
            var _S143 : u32 = (nodeRef_2 & (u32(16777215)));
            found_4 = found_5;
            i_6 = u32(0);
            loop
            {
                if((i_6 < _S142))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_2 : u32 = (gInstances_0[_S134].blasTriOffset_0 + _S143 + i_6) * u32(3);
                var v0_2 : vec4<f32> = gTris_0[base_2];
                var t_6 : f32;
                var bary_2 : vec2<f32>;
                var _S144 : bool = IntersectTriangle_0(_S135, _S136, v0_2.xyz, gTris_0[base_2 + u32(1)].xyz, gTris_0[base_2 + u32(2)].xyz, _S137, (*_S139).t_0, &(t_6), &(bary_2));
                if(!_S144)
                {
                    i_6 = i_6 + u32(1);
                    continue;
                }
                var primitiveIndex_2 : u32 = (bitcast<u32>((v0_2.w)));
                var _S145 : bool;
                if(_S141)
                {
                    var _S146 : bool = AlphaTestRejects_0(_S134, primitiveIndex_2, bary_2, t_6);
                    _S145 = _S146;
                }
                else
                {
                    _S145 = false;
                }
                if(_S145)
                {
                    i_6 = i_6 + u32(1);
                    continue;
                }
                (*_S139).t_0 = t_6;
                (*_S139).barycentrics_0 = bary_2;
                (*_S139).instanceIndex_0 = _S133;
                (*_S139).primitiveIndex_0 = primitiveIndex_2;
                if(_S138)
                {
                    return true;
                }
                found_4 = true;
                i_6 = i_6 + u32(1);
            }
            if(stackPtr_8 == u32(0))
            {
                break;
            }
            var stackPtr_9 : u32 = stackPtr_8 - u32(1);
            nodeRef_2 = stack_3[stackPtr_9];
            found_5 = found_4;
            stackPtr_8 = stackPtr_9;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_2 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S134].blasNodeOffset_0 + nodeRef_2];
        var dist1_4 : f32 = IntersectBox_0(node_2.lmin_0, node_2.lmax_0, _S135, _S140, _S137, (*_S139).t_0);
        var dist2_4 : f32 = IntersectBox_0(node_2.rmin_0, node_2.rmax_0, _S135, _S140, _S137, (*_S139).t_0);
        var far_2 : u32;
        var dist1_5 : f32;
        var dist2_5 : f32;
        if((dist1_4 > dist2_4))
        {
            dist1_5 = dist2_4;
            i_6 = node_2.right_0;
            dist2_5 = dist1_4;
            far_2 = node_2.left_0;
        }
        else
        {
            dist1_5 = dist1_4;
            i_6 = node_2.left_0;
            dist2_5 = dist2_4;
            far_2 = node_2.right_0;
        }
        if(dist1_5 == 1.00000001504746622e+30f)
        {
            if(stackPtr_8 == u32(0))
            {
                found_4 = found_5;
                break;
            }
            var stackPtr_10 : u32 = stackPtr_8 - u32(1);
            nodeRef_2 = stack_3[stackPtr_10];
            stackPtr_8 = stackPtr_10;
        }
        else
        {
            if(dist2_5 != 1.00000001504746622e+30f)
            {
                found_4 = (stackPtr_8 < u32(48));
            }
            else
            {
                found_4 = false;
            }
            var stackPtr_11 : u32;
            if(found_4)
            {
                var _S147 : u32 = stackPtr_8 + u32(1);
                stack_3[stackPtr_8] = far_2;
                stackPtr_11 = _S147;
            }
            else
            {
                stackPtr_11 = stackPtr_8;
            }
            nodeRef_2 = i_6;
            stackPtr_8 = stackPtr_11;
        }
    }
    return found_4;
}

fn TraceScene_1( ray_2 : Ray_0,  anyHit_1 : bool,  hit_2 : ptr<function, HitRecord_0>) -> bool
{
    var found_6 : bool;
    (*hit_2).t_0 = ray_2.tMax_0;
    (*hit_2).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_2).instanceIndex_0 = u32(4294967295);
    (*hit_2).primitiveIndex_0 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S148 : u32 = gFrame_0.counts_0.z;
    var _S149 : vec3<f32> = SafeRcp_0(ray_2.direction_0);
    var stack_4 : array<u32, i32(32)>;
    var nodeRef_3 : u32 = u32(0);
    var found_7 : bool = false;
    var stackPtr_12 : u32 = u32(0);
    loop
    {
        var i_7 : u32;
        if(((nodeRef_3 & (u32(2147483648)))) != u32(0))
        {
            var _S150 : u32 = (((nodeRef_3 >> (u32(24)))) & (u32(127)));
            var _S151 : u32 = (nodeRef_3 & (u32(16777215)));
            found_6 = found_7;
            i_7 = u32(0);
            loop
            {
                if((i_7 < _S150))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_3 : u32 = gIndices_0[_S148 + _S151 + i_7];
                var _S152 : bool = TraverseBLAS_1(instanceIndex_3, instanceIndex_3, InverseTransformPoint_0(instanceIndex_3, ray_2.origin_0), InverseTransformVector_0(instanceIndex_3, ray_2.direction_0), ray_2.tMin_0, anyHit_1, &((*hit_2)));
                if(_S152)
                {
                    if(anyHit_1)
                    {
                        return true;
                    }
                    found_6 = true;
                }
                i_7 = i_7 + u32(1);
            }
            if(stackPtr_12 == u32(0))
            {
                break;
            }
            var stackPtr_13 : u32 = stackPtr_12 - u32(1);
            nodeRef_3 = stack_4[stackPtr_13];
            found_7 = found_6;
            stackPtr_12 = stackPtr_13;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_3 : BVHNode_std430_0 = gNodes_0[nodeRef_3];
        var dist1_6 : f32 = IntersectBox_0(node_3.lmin_0, node_3.lmax_0, ray_2.origin_0, _S149, ray_2.tMin_0, (*hit_2).t_0);
        var dist2_6 : f32 = IntersectBox_0(node_3.rmin_0, node_3.rmax_0, ray_2.origin_0, _S149, ray_2.tMin_0, (*hit_2).t_0);
        var far_3 : u32;
        var dist1_7 : f32;
        var dist2_7 : f32;
        if((dist1_6 > dist2_6))
        {
            dist1_7 = dist2_6;
            i_7 = node_3.right_0;
            dist2_7 = dist1_6;
            far_3 = node_3.left_0;
        }
        else
        {
            dist1_7 = dist1_6;
            i_7 = node_3.left_0;
            dist2_7 = dist2_6;
            far_3 = node_3.right_0;
        }
        if(dist1_7 == 1.00000001504746622e+30f)
        {
            if(stackPtr_12 == u32(0))
            {
                found_6 = found_7;
                break;
            }
            var stackPtr_14 : u32 = stackPtr_12 - u32(1);
            nodeRef_3 = stack_4[stackPtr_14];
            stackPtr_12 = stackPtr_14;
        }
        else
        {
            if(dist2_7 != 1.00000001504746622e+30f)
            {
                found_6 = (stackPtr_12 < u32(32));
            }
            else
            {
                found_6 = false;
            }
            var stackPtr_15 : u32;
            if(found_6)
            {
                var _S153 : u32 = stackPtr_12 + u32(1);
                stack_4[stackPtr_12] = far_3;
                stackPtr_15 = _S153;
            }
            else
            {
                stackPtr_15 = stackPtr_12;
            }
            nodeRef_3 = i_7;
            stackPtr_12 = stackPtr_15;
        }
    }
    return found_6;
}

fn TraceOcclusion_1( ray_3 : Ray_0) -> bool
{
    var hit_3 : HitRecord_0;
    var _S154 : bool = TraceScene_1(ray_3, true, &(hit_3));
    return _S154;
}

struct GGXDistribution_0
{
     alpha_0 : vec2<f32>,
     frame_1 : Frame_0,
     isotropicAlpha_0 : f32,
};

struct BaseReflectionTransmission_0
{
     etaTransparent_0 : vec3<f32>,
     etaOpaque_0 : vec3<f32>,
     reflectionScaleTransparent_0 : vec3<f32>,
     reflectionScaleOpaque_0 : vec3<f32>,
     transmission_0 : vec3<f32>,
     metalF0_0 : vec3<f32>,
     metalF82Tint_0 : vec3<f32>,
     metalAmount_0 : f32,
     thinFilmWeight_1 : f32,
     thinFilmThickness_1 : f32,
     thinFilmExteriorIor_0 : f32,
     thinFilmIor_1 : f32,
     thinFilmInteriorIor_0 : vec3<f32>,
     wavelengths_0 : vec3<f32>,
     thinWallReflection_0 : vec3<f32>,
};

struct SpecularLobe_0
{
     normal_2 : vec3<f32>,
     distribution_0 : GGXDistribution_0,
     coefficient_0 : BaseReflectionTransmission_0,
     eta_0 : vec3<f32>,
     throughput_0 : vec3<f32>,
};

struct DielectricMultipleScatteringLobe_0
{
     normal_3 : vec3<f32>,
     alpha_1 : f32,
     eta_1 : f32,
     reflectionScale_0 : vec3<f32>,
     transmissionScale_0 : vec3<f32>,
     reflectionRatio_0 : f32,
     energyComplementWo_0 : f32,
};

struct MetalMultipleScatteringLobe_0
{
     normal_4 : vec3<f32>,
     alpha_2 : f32,
     scale_0 : vec3<f32>,
     energyComplementWo_1 : f32,
};

struct DiffuseLobe_0
{
     normal_5 : vec3<f32>,
     albedo_0 : vec3<f32>,
     roughness_1 : f32,
     specularAlpha_0 : f32,
     specularEta_0 : f32,
     specularCompensation_0 : f32,
};

struct ConstantReflection_0
{
     color_2 : vec3<f32>,
};

struct MicrofacetReflectionLobe_0
{
     normal_6 : vec3<f32>,
     distribution_1 : GGXDistribution_0,
     coefficient_1 : ConstantReflection_0,
};

struct FlippedLobe_0
{
     lobe_0 : MicrofacetReflectionLobe_0,
};

struct FlippedLobe_1
{
     lobe_0 : DiffuseLobe_0,
};

struct BaseLobe_0
{
     specular_0 : SpecularLobe_0,
     dielectricMultipleScattering_0 : DielectricMultipleScatteringLobe_0,
     metalMultipleScattering_0 : MetalMultipleScatteringLobe_0,
     diffuse_0 : DiffuseLobe_0,
     thinWallSpecularTransmission_0 : FlippedLobe_0,
     thinWallDiffuseTransmission_0 : FlippedLobe_1,
     weights_0 : array<f32, i32(6)>,
};

struct DielectricReflection_0
{
     eta_2 : f32,
};

struct MicrofacetReflectionLobe_1
{
     normal_6 : vec3<f32>,
     distribution_1 : GGXDistribution_0,
     coefficient_1 : DielectricReflection_0,
};

struct CoatLobe_0
{
     base_3 : BaseLobe_0,
     reflection_0 : MicrofacetReflectionLobe_1,
     normal_7 : vec3<f32>,
     tint_0 : vec3<f32>,
     presence_0 : f32,
     inside_0 : bool,
     inReflected_0 : f32,
     inBaseLayerScale_0 : vec3<f32>,
};

struct FuzzLobe_0
{
     base_4 : CoatLobe_0,
     alpha_3 : f32,
     tint_1 : vec3<f32>,
     presence_1 : f32,
     basis_1 : Frame_0,
     woLocal_0 : vec3<f32>,
     viewReflected_0 : f32,
};

struct DiffuseSpecular_0
{
     diffuse_1 : vec3<f32>,
     specular_1 : vec3<f32>,
};

struct SampledLobe_0
{
     layer_0 : i32,
     lobe_1 : i32,
     f_2 : DiffuseSpecular_0,
     pdf_0 : f32,
};

fn DiffuseSpecular_x24init_0( diffuse_2 : vec3<f32>,  specular_2 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S155 : DiffuseSpecular_0;
    _S155.diffuse_1 = diffuse_2;
    _S155.specular_1 = specular_2;
    return _S155;
}

fn DiffuseSpecular_Zero_0() -> DiffuseSpecular_0
{
    var _S156 : vec3<f32> = vec3<f32>(0.0f);
    return DiffuseSpecular_x24init_0(_S156, _S156);
}

fn SampledLobe_None_0() -> SampledLobe_0
{
    var s_2 : SampledLobe_0;
    s_2.layer_0 = i32(0);
    s_2.lobe_1 = i32(-1);
    s_2.f_2 = DiffuseSpecular_Zero_0();
    s_2.pdf_0 = 0.0f;
    return s_2;
}

fn FuzzLobe_HasFuzz_0( this_1 : FuzzLobe_0) -> bool
{
    return ((this_1.presence_1) > 0.0f);
}

fn MaxComponent_0( v_5 : vec3<f32>) -> f32
{
    return max(v_5.x, max(v_5.y, v_5.z));
}

fn BaseLobeEnabled_0( index_6 : i32) -> bool
{
    return true;
}

fn BaseLobe_TotalWeight_0( this_2 : BaseLobe_0) -> f32
{
    var total_0 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        total_0 = this_2.weights_0[i32(0)];
    }
    else
    {
        total_0 = 0.0f;
    }
    if(BaseLobeEnabled_0(i32(1)))
    {
        total_0 = total_0 + this_2.weights_0[i32(1)];
    }
    if(BaseLobeEnabled_0(i32(2)))
    {
        total_0 = total_0 + this_2.weights_0[i32(2)];
    }
    if(BaseLobeEnabled_0(i32(3)))
    {
        total_0 = total_0 + this_2.weights_0[i32(3)];
    }
    if(BaseLobeEnabled_0(i32(4)))
    {
        total_0 = total_0 + this_2.weights_0[i32(4)];
    }
    if(BaseLobeEnabled_0(i32(5)))
    {
        total_0 = total_0 + this_2.weights_0[i32(5)];
    }
    return total_0;
}

fn BaseLobe_EstimateContribution_0( this_3 : BaseLobe_0,  wo_0 : vec3<f32>,  throughput_1 : vec3<f32>) -> f32
{
    return BaseLobe_TotalWeight_0(this_3);
}

fn CoatLobe_EstimateContribution_0( this_4 : CoatLobe_0,  wo_1 : vec3<f32>,  throughput_2 : vec3<f32>) -> f32
{
    var baseContribution_0 : f32 = BaseLobe_EstimateContribution_0(this_4.base_3, wo_1, throughput_2);
    if(this_4.inside_0)
    {
        return baseContribution_0;
    }
    return MaxComponent_0(throughput_2) * this_4.inReflected_0 + baseContribution_0 * MaxComponent_0(this_4.inBaseLayerScale_0);
}

fn FuzzLobe_BaseLayerScaleIncoming_0( this_5 : FuzzLobe_0) -> f32
{
    return 1.0f - this_5.viewReflected_0;
}

fn SafeDivide_0( numerator_0 : f32,  denominator_0 : f32,  fallback_0 : f32) -> f32
{
    var _S157 : f32;
    if(denominator_0 != 0.0f)
    {
        _S157 = numerator_0 / denominator_0;
    }
    else
    {
        _S157 = fallback_0;
    }
    return _S157;
}

fn FuzzLobe_SheenProbability_0( this_6 : FuzzLobe_0,  wo_2 : vec3<f32>) -> f32
{
    var sheenContribution_0 : f32 = this_6.viewReflected_0 * MaxComponent_0(this_6.tint_1);
    return SafeDivide_0(sheenContribution_0, sheenContribution_0 + CoatLobe_EstimateContribution_0(this_6.base_4, wo_2, vec3<f32>(1.0f)) * FuzzLobe_BaseLayerScaleIncoming_0(this_6), 0.5f);
}

fn FetchTable_0( x_13 : i32,  y_6 : i32,  slice_0 : i32) -> f32
{
    var _S158 : vec4<i32> = vec4<i32>(x_13, y_6, slice_0, i32(0));
    return (textureLoad((gBSDFTables_0), ((_S158)).xyz, ((_S158)).w).x);
}

fn FetchLTC_0( row_0 : i32,  col_0 : i32) -> vec3<f32>
{
    return vec3<f32>(FetchTable_0(col_0, row_0, i32(69)), FetchTable_0(col_0, row_0, i32(70)), FetchTable_0(col_0, row_0, i32(71)));
}

fn SheenLTCCoefficients_0( alpha_4 : f32,  cosTheta_2 : f32) -> vec3<f32>
{
    var row_1 : f32 = max(0.0f, min(alpha_4, 0.99999994039535522f)) * 31.0f;
    var col_1 : f32 = max(0.0f, min(cosTheta_2, 0.99999994039535522f)) * 31.0f;
    var r_2 : f32 = floor(row_1);
    var c_6 : f32 = floor(col_1);
    var ri_0 : i32 = i32(r_2);
    var ci_0 : i32 = i32(c_6);
    var _S159 : i32 = ci_0 + i32(1);
    var _S160 : vec3<f32> = vec3<f32>((col_1 - c_6));
    var _S161 : i32 = ri_0 + i32(1);
    return mix(mix(FetchLTC_0(ri_0, ci_0), FetchLTC_0(ri_0, _S159), _S160), mix(FetchLTC_0(_S161, ci_0), FetchLTC_0(_S161, _S159), _S160), vec3<f32>((row_1 - r_2)));
}

fn FuzzLobe_Coefficients_0( this_7 : FuzzLobe_0,  directionLocal_0 : vec3<f32>) -> vec3<f32>
{
    return SheenLTCCoefficients_0(this_7.alpha_3, directionLocal_0.z);
}

fn SampleCosineHemisphere_0( u_3 : vec2<f32>) -> vec3<f32>
{
    var phi_0 : f32 = 2.0f * float_getPi_0() * u_3.x;
    var _S162 : f32 = u_3.y;
    var sinTheta_0 : f32 = sqrt(1.0f - _S162);
    return vec3<f32>(sinTheta_0 * cos(phi_0), sinTheta_0 * sin(phi_0), sqrt(_S162));
}

fn SheenSampleLTC_0( ltc_0 : vec3<f32>,  u_4 : vec2<f32>) -> vec3<f32>
{
    var wiOriginal_0 : vec3<f32> = SampleCosineHemisphere_0(u_4);
    var a_5 : f32 = 1.0f / ltc_0.x;
    var _S163 : f32 = wiOriginal_0.z;
    return normalize(vec3<f32>(wiOriginal_0.x * a_5 - _S163 * ltc_0.y * a_5, wiOriginal_0.y * a_5, _S163));
}

fn SheenRotate_0( v_6 : vec3<f32>,  woXY_0 : vec2<f32>) -> vec3<f32>
{
    var r2_0 : f32 = dot(woXY_0, woXY_0);
    if(r2_0 == 0.0f)
    {
        return v_6;
    }
    var invR_0 : f32 = 1.0f / sqrt(r2_0);
    var sinPhi_0 : f32 = woXY_0.y * invR_0;
    var cosPhi_0 : f32 = woXY_0.x * invR_0;
    var _S164 : f32 = v_6.x;
    var _S165 : f32 = v_6.y;
    return vec3<f32>(cosPhi_0 * _S164 + sinPhi_0 * - _S165, cosPhi_0 * _S165 + sinPhi_0 * _S164, v_6.z);
}

fn Frame_ToWorld_0( this_8 : Frame_0,  v_7 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(v_7.x) * this_8.t_3 + vec3<f32>(v_7.y) * this_8.b_0 + vec3<f32>(v_7.z) * this_8.n_1;
}

fn ClampRemappedRandom_0( u_5 : f32) -> f32
{
    return min(u_5, 0.99999994039535522f);
}

fn CoatLobe_HasCoat_0( this_9 : CoatLobe_0) -> bool
{
    return ((this_9.presence_0) > 0.0f);
}

fn CoatLobe_ReflectionProbability_0( this_10 : CoatLobe_0,  wo_3 : vec3<f32>) -> f32
{
    return SafeDivide_0(this_10.inReflected_0, this_10.inReflected_0 + BaseLobe_EstimateContribution_0(this_10.base_3, wo_3, vec3<f32>(1.0f)) * MaxComponent_0(this_10.inBaseLayerScale_0), 0.5f);
}

struct LobeSample_0
{
     wi_0 : vec3<f32>,
     weight_0 : DiffuseSpecular_0,
     pdf_1 : f32,
     type_0 : u32,
     valid_0 : bool,
};

fn Frame_ToLocal_0( this_11 : Frame_0,  v_8 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(v_8, this_11.t_3), dot(v_8, this_11.b_0), dot(v_8, this_11.n_1));
}

fn SampleGGXVisibleNormal_0( alpha_5 : vec2<f32>,  wo_4 : vec3<f32>,  u_6 : vec2<f32>) -> vec3<f32>
{
    var toHemisphere_0 : vec3<f32> = vec3<f32>(alpha_5.x, alpha_5.y, 1.0f);
    var woHemisphere_0 : vec3<f32> = normalize(toHemisphere_0 * wo_4);
    var _S166 : f32 = min(woHemisphere_0.z, 1.0f);
    var angle_0 : f32 = 2.0f * float_getPi_0() * u_6.x;
    var onePlusCos_0 : f32 = 1.0f + _S166;
    var _S167 : f32 = u_6.y;
    var z_5 : f32 = (1.0f - _S167) * onePlusCos_0;
    var radius_0 : f32 = sqrt((z_5 + (1.0f - _S166)) * (_S167 * onePlusCos_0));
    return normalize(toHemisphere_0 * vec3<f32>(radius_0 * cos(angle_0) + woHemisphere_0.x, radius_0 * sin(angle_0) + woHemisphere_0.y, z_5));
}

fn GGXDistribution_SampleVisibleNormal_0( this_12 : GGXDistribution_0,  wo_5 : vec3<f32>,  u_7 : vec2<f32>) -> vec3<f32>
{
    return Frame_ToWorld_0(this_12.frame_1, SampleGGXVisibleNormal_0(this_12.alpha_0, Frame_ToLocal_0(this_12.frame_1, wo_5), u_7));
}

fn LobeSample_Invalid_0() -> LobeSample_0
{
    var s_3 : LobeSample_0;
    s_3.wi_0 = vec3<f32>(0.0f);
    s_3.weight_0 = DiffuseSpecular_Zero_0();
    s_3.pdf_1 = 0.0f;
    s_3.type_0 = u32(0);
    s_3.valid_0 = false;
    return s_3;
}

fn Square_0( x_14 : f32) -> f32
{
    return x_14 * x_14;
}

fn FresnelDielectric_0( eta_3 : f32,  cosThetaI_0 : f32) -> f32
{
    if(eta_3 == 1.0f)
    {
        return 0.0f;
    }
    var sin2ThetaT_0 : f32 = (1.0f - Square_0(cosThetaI_0)) / Square_0(eta_3);
    if((sin2ThetaT_0 >= 1.0f))
    {
        return 1.0f;
    }
    var cosThetaT_0 : f32 = sqrt(1.0f - sin2ThetaT_0);
    var etaCosI_0 : f32 = eta_3 * cosThetaI_0;
    var etaCosT_0 : f32 = eta_3 * cosThetaT_0;
    return 0.5f * (Square_0((cosThetaI_0 - etaCosT_0) / (cosThetaI_0 + etaCosT_0)) + Square_0((cosThetaT_0 - etaCosI_0) / (cosThetaT_0 + etaCosI_0)));
}

fn DielectricReflection_Reflection_0( this_13 : DielectricReflection_0,  idoth_0 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(this_13.eta_2, idoth_0));
}

fn SmithG1_0( v_9 : vec3<f32>,  alpha_6 : vec2<f32>) -> f32
{
    var vz2_0 : f32 = Square_0(v_9.z);
    if(vz2_0 == 0.0f)
    {
        return 0.0f;
    }
    return 2.0f / (1.0f + sqrt(1.0f + (Square_0(alpha_6.x * v_9.x) + Square_0(alpha_6.y * v_9.y)) / vz2_0));
}

fn GGXDistribution_G1_0( this_14 : GGXDistribution_0,  v_10 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_14.frame_1, v_10), this_14.alpha_0);
}

fn EvalGGX_0( m_0 : vec3<f32>,  alpha_7 : vec2<f32>) -> f32
{
    var _S168 : f32 = alpha_7.x;
    var _S169 : f32 = alpha_7.y;
    return 1.0f / (float_getPi_0() * _S168 * _S169 * Square_0(Square_0(m_0.x / _S168) + Square_0(m_0.y / _S169) + Square_0(m_0.z)));
}

fn GGXDistribution_D_0( this_15 : GGXDistribution_0,  m_1 : vec3<f32>) -> f32
{
    return EvalGGX_0(Frame_ToLocal_0(this_15.frame_1, m_1), this_15.alpha_0);
}

fn DiffuseSpecular_Specular_0( value_0 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(vec3<f32>(0.0f), value_0);
}

fn MicrofacetReflectionLobe_LobeType_0( this_16 : MicrofacetReflectionLobe_1) -> u32
{
    return u32(9);
}

fn LobeSample_Make_0( wi_1 : vec3<f32>,  weight_1 : DiffuseSpecular_0,  pdf_2 : f32,  type_1 : u32) -> LobeSample_0
{
    var s_4 : LobeSample_0;
    s_4.wi_0 = wi_1;
    s_4.weight_0 = weight_1;
    s_4.pdf_1 = pdf_2;
    s_4.type_0 = type_1;
    s_4.valid_0 = true;
    return s_4;
}

fn MicrofacetReflectionLobe_Sample_0( this_17 : MicrofacetReflectionLobe_1,  u_8 : vec3<f32>,  wo_6 : vec3<f32>) -> LobeSample_0
{
    var idotn_0 : f32 = dot(wo_6, this_17.normal_6);
    var h_3 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_17.distribution_1, wo_6, u_8.xy);
    var idoth_1 : f32 = dot(wo_6, h_3);
    if((idoth_1 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_2 : vec3<f32> = normalize((vec3<f32>(0) - wo_6) + h_3 * vec3<f32>(2.0f) * vec3<f32>(idoth_1));
    if(((idotn_0 * dot(this_17.normal_6, wi_2)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_0 : f32 = dot(wi_2, h_3);
    var f_3 : vec3<f32> = DielectricReflection_Reflection_0(this_17.coefficient_1, idoth_1);
    var gShadowing_0 : f32 = GGXDistribution_G1_0(this_17.distribution_1, wi_2);
    var d_3 : f32 = GGXDistribution_D_0(this_17.distribution_1, h_3);
    if((d_3 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_2, DiffuseSpecular_Specular_0(f_3 * vec3<f32>(gShadowing_0)), d_3 * GGXDistribution_G1_0(this_17.distribution_1, wo_6) * idoth_1 / (4.0f * odoth_0 * idotn_0), MicrofacetReflectionLobe_LobeType_0(this_17));
}

fn x2A_0( a_6 : DiffuseSpecular_0,  scale_1 : f32) -> DiffuseSpecular_0
{
    var _S170 : vec3<f32> = vec3<f32>(scale_1);
    return DiffuseSpecular_x24init_0(a_6.diffuse_1 * _S170, a_6.specular_1 * _S170);
}

fn SampledLobe_Make_0( layer_1 : i32,  lobe_2 : i32,  sample_0 : LobeSample_0) -> SampledLobe_0
{
    var s_5 : SampledLobe_0;
    s_5.layer_0 = layer_1;
    s_5.lobe_1 = lobe_2;
    s_5.f_2 = x2A_0(sample_0.weight_0, sample_0.pdf_1);
    s_5.pdf_0 = sample_0.pdf_1;
    return s_5;
}

fn BaseLobe_SelectLobe_0( this_18 : BaseLobe_0,  u_9 : ptr<function, f32>,  selectedWeight_0 : ptr<function, f32>,  totalWeight_0 : ptr<function, f32>) -> i32
{
    var weightSoFar_0 : f32;
    var _S171 : f32 = BaseLobe_TotalWeight_0(this_18);
    (*totalWeight_0) = _S171;
    if((_S171 <= 1.17549435082228751e-38f))
    {
        (*selectedWeight_0) = 0.0f;
        return i32(-1);
    }
    (*u_9) = (*u_9) * (*totalWeight_0);
    loop
    {
        loop
        {
            loop
            {
                if(!BaseLobeEnabled_0(i32(0)))
                {
                    weightSoFar_0 = 0.0f;
                    break;
                }
                (*selectedWeight_0) = this_18.weights_0[i32(0)];
                if(((*u_9) < (this_18.weights_0[i32(0)])))
                {
                    (*u_9) = ClampRemappedRandom_0((*u_9) / (*selectedWeight_0));
                    return i32(0);
                }
                weightSoFar_0 = (*selectedWeight_0);
                break;
            }
            break;
        }
        loop
        {
            loop
            {
                if(!BaseLobeEnabled_0(i32(1)))
                {
                    break;
                }
                (*selectedWeight_0) = this_18.weights_0[i32(1)];
                if(((*u_9) < (weightSoFar_0 + this_18.weights_0[i32(1)])))
                {
                    (*u_9) = ClampRemappedRandom_0(((*u_9) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(1);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        loop
        {
            loop
            {
                if(!BaseLobeEnabled_0(i32(2)))
                {
                    break;
                }
                (*selectedWeight_0) = this_18.weights_0[i32(2)];
                if(((*u_9) < (weightSoFar_0 + this_18.weights_0[i32(2)])))
                {
                    (*u_9) = ClampRemappedRandom_0(((*u_9) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(2);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        loop
        {
            loop
            {
                if(!BaseLobeEnabled_0(i32(3)))
                {
                    break;
                }
                (*selectedWeight_0) = this_18.weights_0[i32(3)];
                if(((*u_9) < (weightSoFar_0 + this_18.weights_0[i32(3)])))
                {
                    (*u_9) = ClampRemappedRandom_0(((*u_9) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(3);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        loop
        {
            loop
            {
                if(!BaseLobeEnabled_0(i32(4)))
                {
                    break;
                }
                (*selectedWeight_0) = this_18.weights_0[i32(4)];
                if(((*u_9) < (weightSoFar_0 + this_18.weights_0[i32(4)])))
                {
                    (*u_9) = ClampRemappedRandom_0(((*u_9) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(4);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        break;
    }
    (*selectedWeight_0) = this_18.weights_0[i32(5)];
    (*u_9) = ClampRemappedRandom_0(((*u_9) - weightSoFar_0) / this_18.weights_0[i32(5)]);
    return i32(5);
}

struct ReflectionTransmission_0
{
     reflection_1 : vec3<f32>,
     transmission_1 : vec3<f32>,
     reflectionProbability_0 : f32,
     transmissionProbability_0 : f32,
};

fn ThinFilmPresence_0( thickness_0 : f32) -> f32
{
    return smoothstep(9.99999971718068537e-10f, 30.0f, thickness_0);
}

fn BaseReflectionTransmission_ThinFilmPresenceAt_0( this_19 : BaseReflectionTransmission_0,  idoth_2 : f32) -> f32
{
    var _S172 : f32;
    if((idoth_2 >= 0.0f))
    {
        _S172 = this_19.thinFilmWeight_1 * ThinFilmPresence_0(this_19.thinFilmThickness_1);
    }
    else
    {
        _S172 = 0.0f;
    }
    return _S172;
}

fn FresnelDielectric_1( eta_4 : vec3<f32>,  cosThetaI_1 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(eta_4.x, cosThetaI_1), FresnelDielectric_0(eta_4.y, cosThetaI_1), FresnelDielectric_0(eta_4.z, cosThetaI_1));
}

fn FifthPower_0( x_15 : f32) -> f32
{
    var xx_0 : f32 = x_15 * x_15;
    return xx_0 * xx_0 * x_15;
}

fn SixthPower_0( x_16 : f32) -> f32
{
    var xx_1 : f32 = x_16 * x_16;
    return xx_1 * xx_1 * xx_1;
}

fn MetalSchlickBFactor_0( f0_0 : vec3<f32>,  f82Tint_0 : vec3<f32>) -> vec3<f32>
{
    var _S173 : vec3<f32> = vec3<f32>(1.0f);
    return (f0_0 + (_S173 - f0_0) * vec3<f32>(FifthPower_0(0.8571428656578064f))) * (_S173 - f82Tint_0) * vec3<f32>((1.0f / (0.1428571492433548f * SixthPower_0(0.8571428656578064f))));
}

fn FresnelMetalF82_0( f0_1 : vec3<f32>,  f82Tint_1 : vec3<f32>,  cosTheta_3 : f32) -> vec3<f32>
{
    var oneMinusCos_0 : f32 = 1.0f - cosTheta_3;
    return saturate(f0_1 + (vec3<f32>(1.0f) - f0_1 - MetalSchlickBFactor_0(f0_1, f82Tint_1) * vec3<f32>(cosTheta_3) * vec3<f32>(oneMinusCos_0)) * vec3<f32>(FifthPower_0(oneMinusCos_0)));
}

fn BaseReflectionTransmission_HasDielectric_0( this_20 : BaseReflectionTransmission_0) -> bool
{
    var _S174 : vec3<f32> = vec3<f32>(0.0f);
    var _S175 : bool;
    if((any((((this_20.reflectionScaleTransparent_0) > _S174)))))
    {
        _S175 = true;
    }
    else
    {
        _S175 = (any((((this_20.reflectionScaleOpaque_0) > _S174))));
    }
    return _S175;
}

fn BaseReflectionTransmission_HasMetal_0( this_21 : BaseReflectionTransmission_0) -> bool
{
    return ((this_21.metalAmount_0) > 0.0f);
}

struct ThinFilmResults_0
{
     dielectric_0 : vec3<f32>,
     metal_0 : vec3<f32>,
};

struct Polarized_0
{
     s_6 : f32,
     p_6 : f32,
};

fn FresnelAmplitudesDielectric_0( cosThetaI_2 : f32,  etaI_0 : f32,  etaT_0 : f32,  r_3 : ptr<function, Polarized_0>,  t_7 : ptr<function, Polarized_0>,  cosThetaT_1 : ptr<function, f32>)
{
    var sinThetaT_0 : f32 = etaI_0 / etaT_0 * sqrt(saturate(1.0f - cosThetaI_2 * cosThetaI_2));
    if((sinThetaT_0 >= 1.0f))
    {
        (*r_3).s_6 = 1.0f;
        (*r_3).p_6 = 1.0f;
        (*t_7).s_6 = 0.0f;
        (*t_7).p_6 = 0.0f;
        (*cosThetaT_1) = 0.0f;
        return;
    }
    var _S176 : f32 = sqrt(saturate(1.0f - sinThetaT_0 * sinThetaT_0));
    (*cosThetaT_1) = _S176;
    var etaICosI_0 : f32 = etaI_0 * cosThetaI_2;
    var etaTCosT_0 : f32 = etaT_0 * _S176;
    var etaTCosI_0 : f32 = etaT_0 * cosThetaI_2;
    var etaICosT_0 : f32 = etaI_0 * _S176;
    var denominatorS_0 : f32 = etaICosI_0 + etaTCosT_0;
    var denominatorP_0 : f32 = etaTCosI_0 + etaICosT_0;
    var denominatorS_1 : f32;
    if(((abs(denominatorS_0)) < 9.99999971718068537e-10f))
    {
        if((denominatorS_0 >= 0.0f))
        {
            denominatorS_1 = 9.99999971718068537e-10f;
        }
        else
        {
            denominatorS_1 = -9.99999971718068537e-10f;
        }
    }
    else
    {
        denominatorS_1 = denominatorS_0;
    }
    var denominatorP_1 : f32;
    if(((abs(denominatorP_0)) < 9.99999971718068537e-10f))
    {
        if((denominatorP_0 >= 0.0f))
        {
            denominatorP_1 = 9.99999971718068537e-10f;
        }
        else
        {
            denominatorP_1 = -9.99999971718068537e-10f;
        }
    }
    else
    {
        denominatorP_1 = denominatorP_0;
    }
    var rcpS_0 : f32 = 1.0f / denominatorS_1;
    var rcpP_0 : f32 = 1.0f / denominatorP_1;
    (*r_3).s_6 = (etaICosI_0 - etaTCosT_0) * rcpS_0;
    (*r_3).p_6 = (etaTCosI_0 - etaICosT_0) * rcpP_0;
    var _S177 : f32 = 2.0f * etaICosI_0;
    (*t_7).s_6 = _S177 * rcpS_0;
    (*t_7).p_6 = _S177 * rcpP_0;
    return;
}

struct PolarizedComplex_0
{
     s_7 : vec2<f32>,
     p_7 : vec2<f32>,
};

fn ComplexDiv_0( a_7 : vec2<f32>,  b_4 : vec2<f32>,  minMagnitude_0 : f32,  fallback_1 : vec2<f32>) -> vec2<f32>
{
    var denominator_1 : f32 = dot(b_4, b_4);
    if((denominator_1 < (minMagnitude_0 * minMagnitude_0)))
    {
        return fallback_1;
    }
    var rcpDenominator_0 : f32 = 1.0f / denominator_1;
    var _S178 : f32 = a_7.x;
    var _S179 : f32 = b_4.x;
    var _S180 : f32 = a_7.y;
    var _S181 : f32 = b_4.y;
    return vec2<f32>((_S178 * _S179 + _S180 * _S181) * rcpDenominator_0, (_S180 * _S179 - _S178 * _S181) * rcpDenominator_0);
}

fn ComplexMul_0( a_8 : vec2<f32>,  b_5 : vec2<f32>) -> vec2<f32>
{
    var _S182 : f32 = a_8.x;
    var _S183 : f32 = b_5.x;
    var _S184 : f32 = a_8.y;
    var _S185 : f32 = b_5.y;
    return vec2<f32>(_S182 * _S183 - _S184 * _S185, _S182 * _S185 + _S184 * _S183);
}

fn SignNonZero_0( x_17 : f32) -> f32
{
    var _S186 : f32;
    if((x_17 >= 0.0f))
    {
        _S186 = 1.0f;
    }
    else
    {
        _S186 = -1.0f;
    }
    return _S186;
}

fn ComplexSqrt_0( z_6 : vec2<f32>) -> vec2<f32>
{
    var r_4 : f32 = length(z_6);
    var _S187 : f32 = z_6.x;
    return vec2<f32>(sqrt(max((r_4 + _S187) * 0.5f, 0.0f)), SignNonZero_0(z_6.y) * sqrt(max((r_4 - _S187) * 0.5f, 0.0f)));
}

fn RefractedCosine_0( cosThetaI_3 : f32,  etaI_1 : f32,  etaT_1 : vec2<f32>) -> vec2<f32>
{
    const _S188 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var sinThetaT_1 : vec2<f32> = vec2<f32>(sqrt(saturate(1.0f - cosThetaI_3 * cosThetaI_3))) * ComplexDiv_0(vec2<f32>(etaI_1, 0.0f), etaT_1, 9.99999971718068537e-10f, _S188);
    var cosThetaT_2 : vec2<f32> = ComplexSqrt_0(_S188 - ComplexMul_0(sinThetaT_1, sinThetaT_1));
    var cosThetaT_3 : vec2<f32>;
    if(((ComplexMul_0(etaT_1, cosThetaT_2).y) < 0.0f))
    {
        cosThetaT_3 = (vec2<f32>(0) - cosThetaT_2);
    }
    else
    {
        cosThetaT_3 = cosThetaT_2;
    }
    return cosThetaT_3;
}

fn FresnelAmplitudesComplex_0( cosThetaI_4 : f32,  etaI_2 : f32,  etaT_2 : vec2<f32>) -> PolarizedComplex_0
{
    var cosThetaT_4 : vec2<f32> = RefractedCosine_0(cosThetaI_4, etaI_2, etaT_2);
    var etaICosI_1 : vec2<f32> = vec2<f32>(etaI_2 * cosThetaI_4, 0.0f);
    var etaTCosT_1 : vec2<f32> = ComplexMul_0(etaT_2, cosThetaT_4);
    var etaTCosI_1 : vec2<f32> = vec2<f32>(cosThetaI_4) * etaT_2;
    var etaICosT_1 : vec2<f32> = vec2<f32>(etaI_2) * cosThetaT_4;
    var r_5 : PolarizedComplex_0;
    const _S189 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    r_5.s_7 = ComplexDiv_0(etaICosI_1 - etaTCosT_1, etaICosI_1 + etaTCosT_1, 9.99999971718068537e-10f, _S189);
    r_5.p_7 = ComplexDiv_0(etaTCosI_1 - etaICosT_1, etaTCosI_1 + etaICosT_1, 9.99999971718068537e-10f, _S189);
    return r_5;
}

fn ComplexExpI_0( theta_0 : f32) -> vec2<f32>
{
    return vec2<f32>(cos(theta_0), sin(theta_0));
}

fn AiryReflectance_0( r12_0 : f32,  t12_0 : f32,  r21_0 : f32,  t21_0 : f32,  r23_0 : vec2<f32>,  expIPhi_0 : vec2<f32>) -> f32
{
    var r23Exp_0 : vec2<f32> = ComplexMul_0(r23_0, expIPhi_0);
    var rTotal_0 : vec2<f32> = vec2<f32>(r12_0, 0.0f) + ComplexDiv_0(vec2<f32>((t12_0 * t21_0)) * r23Exp_0, vec2<f32>(1.0f, 0.0f) - vec2<f32>(r21_0) * r23Exp_0, 9.99999971718068537e-10f, vec2<f32>(0.0f));
    return dot(rTotal_0, rTotal_0);
}

fn ThinFilmReflectance_0( r12_1 : Polarized_0,  t12_1 : Polarized_0,  r21_1 : Polarized_0,  t21_1 : Polarized_0,  r23_1 : PolarizedComplex_0,  deltaPhi_0 : f32) -> f32
{
    var expIPhi_1 : vec2<f32> = ComplexExpI_0(deltaPhi_0);
    return 0.5f * (AiryReflectance_0(r12_1.s_6, t12_1.s_6, r21_1.s_6, t21_1.s_6, r23_1.s_7, expIPhi_1) + AiryReflectance_0(r12_1.p_6, t12_1.p_6, r21_1.p_6, t21_1.p_6, r23_1.p_7, expIPhi_1));
}

fn GulbrandsenIor_0( r_6 : f32,  g_1 : f32) -> vec2<f32>
{
    var clampedR_0 : f32 = clamp(r_6, 0.0f, 0.99000000953674316f);
    var sqrtR_0 : f32 = sqrt(clampedR_0);
    var _S190 : f32 = 1.0f - clampedR_0;
    var n_5 : f32 = mix((1.0f + sqrtR_0) / (1.0f - sqrtR_0), _S190 / (1.0f + clampedR_0), g_1);
    return vec2<f32>(n_5, sqrt(max((Square_0(n_5 + 1.0f) * clampedR_0 - Square_0(n_5 - 1.0f)) / _S190, 0.0f)));
}

fn ThinFilmAndBaseReflectance_0( cosThetaI_5 : f32,  etaExterior_0 : f32,  etaFilm_0 : f32,  etaBase_0 : vec3<f32>,  dispersion_0 : bool,  metalF0_1 : vec3<f32>,  metalF82Tint_1 : vec3<f32>,  enableDielectric_0 : bool,  enableMetal_0 : bool,  thickness_1 : f32,  wavelengths_1 : vec3<f32>) -> ThinFilmResults_0
{
    var results_0 : ThinFilmResults_0;
    var _S191 : vec3<f32> = vec3<f32>(0.0f);
    results_0.dielectric_0 = _S191;
    results_0.metal_0 = _S191;
    var _S192 : bool;
    if(enableDielectric_0)
    {
        _S192 = true;
    }
    else
    {
        _S192 = enableMetal_0;
    }
    if(!_S192)
    {
        return results_0;
    }
    var cosThetaFilm_0 : f32;
    var r12_2 : Polarized_0;
    var t12_2 : Polarized_0;
    FresnelAmplitudesDielectric_0(cosThetaI_5, etaExterior_0, etaFilm_0, &(r12_2), &(t12_2), &(cosThetaFilm_0));
    if((cosThetaFilm_0 <= 0.0f))
    {
        if(enableDielectric_0)
        {
            results_0.dielectric_0 = vec3<f32>(1.0f);
        }
        if(enableMetal_0)
        {
            results_0.metal_0 = vec3<f32>(1.0f);
        }
        return results_0;
    }
    var r21_2 : Polarized_0;
    r21_2.s_6 = - r12_2.s_6;
    r21_2.p_6 = - r12_2.p_6;
    var t21Scale_0 : f32 = etaFilm_0 * cosThetaFilm_0 / (etaExterior_0 * max(cosThetaI_5, 9.99999971718068537e-10f));
    var t21_2 : Polarized_0;
    t21_2.s_6 = t12_2.s_6 * t21Scale_0;
    t21_2.p_6 = t12_2.p_6 * t21Scale_0;
    var _S193 : vec3<f32> = vec3<f32>((2.0f * float_getPi_0() * (2.0f * etaFilm_0 * thickness_1 * cosThetaFilm_0))) / wavelengths_1;
    var c_7 : i32;
    if(enableDielectric_0)
    {
        var r23_2 : array<PolarizedComplex_0, i32(3)>;
        c_7 = i32(0);
        loop
        {
            if((c_7 < i32(3)))
            {
            }
            else
            {
                break;
            }
            if(dispersion_0)
            {
                _S192 = true;
            }
            else
            {
                _S192 = c_7 == i32(0);
            }
            if(_S192)
            {
                r23_2[c_7] = FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, vec2<f32>(etaBase_0[c_7], 0.0f));
            }
            else
            {
                r23_2[c_7] = r23_2[i32(0)];
            }
            c_7 = c_7 + i32(1);
        }
        c_7 = i32(0);
        loop
        {
            if((c_7 < i32(3)))
            {
            }
            else
            {
                break;
            }
            results_0.dielectric_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, r23_2[c_7], _S193[c_7]);
            c_7 = c_7 + i32(1);
        }
    }
    if(enableMetal_0)
    {
        c_7 = i32(0);
        loop
        {
            if((c_7 < i32(3)))
            {
            }
            else
            {
                break;
            }
            results_0.metal_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, GulbrandsenIor_0(metalF0_1[c_7], metalF82Tint_1[c_7])), _S193[c_7]);
            c_7 = c_7 + i32(1);
        }
    }
    return results_0;
}

fn BaseReflectionTransmission_ThinFilm_0( this_22 : BaseReflectionTransmission_0,  idoth_3 : f32,  enableDielectric_1 : bool,  enableMetal_1 : bool) -> ThinFilmResults_0
{
    return ThinFilmAndBaseReflectance_0(idoth_3, this_22.thinFilmExteriorIor_0, this_22.thinFilmIor_1, this_22.thinFilmInteriorIor_0, true, this_22.metalF0_0, this_22.metalF82Tint_0, enableDielectric_1, enableMetal_1, this_22.thinFilmThickness_1, this_22.wavelengths_0);
}

fn BaseReflectionTransmission_Coefficients_0( this_23 : BaseReflectionTransmission_0,  idoth_4 : f32) -> ReflectionTransmission_0
{
    var standardReflection_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_2 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_23, idoth_4);
    var standardReflection_1 : vec3<f32>;
    var standardTransmission_0 : vec3<f32>;
    if((presence_2 < 1.0f))
    {
        var fresnel_0 : vec3<f32> = FresnelDielectric_1(this_23.etaTransparent_0, idoth_4);
        var _S194 : vec3<f32> = this_23.transmission_0 * (vec3<f32>(1.0f) - fresnel_0);
        standardReflection_1 = this_23.reflectionScaleTransparent_0 * fresnel_0 + this_23.reflectionScaleOpaque_0 * FresnelDielectric_1(this_23.etaOpaque_0, idoth_4) + vec3<f32>(this_23.metalAmount_0) * FresnelMetalF82_0(this_23.metalF0_0, this_23.metalF82Tint_0, idoth_4);
        standardTransmission_0 = _S194;
    }
    else
    {
        standardReflection_1 = standardReflection_0;
        standardTransmission_0 = standardReflection_0;
    }
    var thinFilmReflection_0 : vec3<f32>;
    var thinFilmTransmission_0 : vec3<f32>;
    if((presence_2 > 0.0f))
    {
        var film_0 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_23, idoth_4, BaseReflectionTransmission_HasDielectric_0(this_23), BaseReflectionTransmission_HasMetal_0(this_23));
        var _S195 : vec3<f32> = this_23.transmission_0 * (vec3<f32>(1.0f) - film_0.dielectric_0);
        thinFilmReflection_0 = this_23.reflectionScaleTransparent_0 * film_0.dielectric_0 + this_23.reflectionScaleOpaque_0 * film_0.dielectric_0 + vec3<f32>(this_23.metalAmount_0) * film_0.metal_0;
        thinFilmTransmission_0 = _S195;
    }
    else
    {
        thinFilmReflection_0 = standardReflection_0;
        thinFilmTransmission_0 = standardReflection_0;
    }
    var result_1 : ReflectionTransmission_0;
    var _S196 : vec3<f32> = vec3<f32>(presence_2);
    result_1.reflection_1 = mix(standardReflection_1, thinFilmReflection_0, _S196) + this_23.thinWallReflection_0;
    result_1.transmission_1 = mix(standardTransmission_0, thinFilmTransmission_0, _S196);
    result_1.reflectionProbability_0 = 0.0f;
    result_1.transmissionProbability_0 = 0.0f;
    return result_1;
}

fn ThroughputWeightedMax_0( throughput_3 : vec3<f32>,  color_3 : vec3<f32>) -> f32
{
    return MaxComponent_0(throughput_3 * color_3);
}

fn BaseReflectionTransmission_CoefficientsAndProbabilities_0( this_24 : BaseReflectionTransmission_0,  throughput_4 : vec3<f32>,  idoth_5 : f32) -> ReflectionTransmission_0
{
    var result_2 : ReflectionTransmission_0 = BaseReflectionTransmission_Coefficients_0(this_24, idoth_5);
    var reflectionMax_0 : f32 = ThroughputWeightedMax_0(throughput_4, result_2.reflection_1);
    var transmissionMax_0 : f32 = ThroughputWeightedMax_0(throughput_4, result_2.transmission_1);
    var sum_2 : f32 = reflectionMax_0 + transmissionMax_0;
    result_2.reflectionProbability_0 = SafeDivide_0(reflectionMax_0, sum_2, 0.0f);
    result_2.transmissionProbability_0 = SafeDivide_0(transmissionMax_0, sum_2, 0.0f);
    return result_2;
}

fn Sum_0( v_11 : vec3<f32>) -> f32
{
    return v_11.x + v_11.y + v_11.z;
}

fn SpecularLobe_ChannelProbabilities_0( this_25 : SpecularLobe_0) -> vec3<f32>
{
    return this_25.throughput_0 / vec3<f32>(Sum_0(this_25.throughput_0));
}

fn Refract_0( wi_3 : vec3<f32>,  n_6 : vec3<f32>,  cosThetaI_6 : f32,  eta_5 : f32,  wt_0 : ptr<function, vec3<f32>>) -> bool
{
    var invEta_0 : f32 = 1.0f / eta_5;
    var sin2ThetaT_1 : f32 = Square_0(invEta_0) * max(0.0f, 1.0f - Square_0(cosThetaI_6));
    if((sin2ThetaT_1 >= 1.0f))
    {
        (*wt_0) = vec3<f32>(0.0f);
        return false;
    }
    (*wt_0) = normalize((vec3<f32>(0) - wi_3) * vec3<f32>(invEta_0) + n_6 * vec3<f32>((invEta_0 * cosThetaI_6 - sqrt(1.0f - sin2ThetaT_1))));
    return true;
}

fn BaseReflectionTransmission_ReflectionProbability_0( this_26 : BaseReflectionTransmission_0,  throughput_5 : vec3<f32>,  idoth_6 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_26, throughput_5, idoth_6).reflectionProbability_0;
}

fn SpecularLobe_ValidTransmissionHalfVector_0( this_27 : SpecularLobe_0,  h_4 : vec3<f32>) -> bool
{
    var _S197 : f32 = this_27.eta_0.x;
    var _S198 : bool;
    if((_S197 >= 1.0f))
    {
        _S198 = ((dot(this_27.normal_2, h_4)) > 0.0f);
    }
    else
    {
        _S198 = false;
    }
    if(_S198)
    {
        _S198 = true;
    }
    else
    {
        if((_S197 < 1.0f))
        {
            _S198 = ((dot(this_27.normal_2, h_4)) < 0.0f);
        }
        else
        {
            _S198 = false;
        }
    }
    return _S198;
}

fn SpecularLobe_TransmissionTerms_0( this_28 : SpecularLobe_0,  wo_7 : vec3<f32>,  wi_4 : vec3<f32>,  idotn_1 : f32,  channelEta_0 : f32,  d_4 : ptr<function, f32>,  otherTerms_0 : ptr<function, f32>,  absIdoth_0 : ptr<function, f32>) -> bool
{
    (*d_4) = 0.0f;
    (*otherTerms_0) = 0.0f;
    (*absIdoth_0) = 0.0f;
    var h_5 : vec3<f32> = (vec3<f32>(0) - normalize(wo_7 + wi_4 * vec3<f32>(channelEta_0)));
    if(!SpecularLobe_ValidTransmissionHalfVector_0(this_28, h_5))
    {
        return false;
    }
    var idoth_7 : f32 = dot(wo_7, h_5);
    var odoth_1 : f32 = dot(wi_4, h_5);
    if(((idoth_7 * odoth_1) >= 0.0f))
    {
        return false;
    }
    (*d_4) = GGXDistribution_D_0(this_28.distribution_0, h_5);
    var _S199 : f32 = abs(idoth_7);
    (*otherTerms_0) = Square_0(channelEta_0) * _S199 * abs(odoth_1) / (Square_0(idoth_7 + channelEta_0 * odoth_1) * idotn_1);
    (*absIdoth_0) = _S199;
    return true;
}

fn BaseReflectionTransmission_TransmissionProbability_0( this_29 : BaseReflectionTransmission_0,  throughput_6 : vec3<f32>,  idoth_8 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_29, throughput_6, idoth_8).transmissionProbability_0;
}

fn SpecularLobe_Pdf_0( this_30 : SpecularLobe_0,  wo_8 : vec3<f32>,  wi_5 : vec3<f32>) -> f32
{
    var idotn_2 : f32 = dot(this_30.normal_2, wo_8);
    var _S200 : f32 = idotn_2 * dot(this_30.normal_2, wi_5);
    if((_S200 > 0.0f))
    {
        var h_6 : vec3<f32> = normalize(wo_8 + wi_5);
        var idoth_9 : f32 = dot(wo_8, h_6);
        var odoth_2 : f32 = dot(wi_5, h_6);
        if(((idoth_9 * odoth_2) < 0.0f))
        {
            return 0.0f;
        }
        return GGXDistribution_G1_0(this_30.distribution_0, wo_8) * (BaseReflectionTransmission_ReflectionProbability_0(this_30.coefficient_0, this_30.throughput_0, abs(idoth_9)) * GGXDistribution_D_0(this_30.distribution_0, h_6) * (idoth_9 / (4.0f * odoth_2 * idotn_2)));
    }
    if((_S200 >= 0.0f))
    {
        return 0.0f;
    }
    var d_5 : f32;
    var otherTerms_1 : f32;
    var absIdoth_1 : f32;
    var probabilityDOtherTerms_0 : vec3<f32>;
    var c_8 : i32 = i32(0);
    loop
    {
        if((c_8 < i32(3)))
        {
        }
        else
        {
            break;
        }
        var _S201 : bool = SpecularLobe_TransmissionTerms_0(this_30, wo_8, wi_5, idotn_2, this_30.eta_0[c_8], &(d_5), &(otherTerms_1), &(absIdoth_1));
        var _S202 : f32;
        if(_S201)
        {
            _S202 = BaseReflectionTransmission_TransmissionProbability_0(this_30.coefficient_0, this_30.throughput_0, absIdoth_1) * d_5 * otherTerms_1;
        }
        else
        {
            _S202 = 0.0f;
        }
        probabilityDOtherTerms_0[c_8] = _S202;
        c_8 = c_8 + i32(1);
    }
    return GGXDistribution_G1_0(this_30.distribution_0, wo_8) * dot(probabilityDOtherTerms_0, SpecularLobe_ChannelProbabilities_0(this_30));
}

fn BaseReflectionTransmission_Reflection_0( this_31 : BaseReflectionTransmission_0,  idoth_10 : f32) -> vec3<f32>
{
    var standard_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_3 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_31, idoth_10);
    var standard_1 : vec3<f32>;
    if((presence_3 < 1.0f))
    {
        standard_1 = this_31.reflectionScaleTransparent_0 * FresnelDielectric_1(this_31.etaTransparent_0, idoth_10) + this_31.reflectionScaleOpaque_0 * FresnelDielectric_1(this_31.etaOpaque_0, idoth_10) + vec3<f32>(this_31.metalAmount_0) * FresnelMetalF82_0(this_31.metalF0_0, this_31.metalF82Tint_0, idoth_10);
    }
    else
    {
        standard_1 = standard_0;
    }
    var thinFilm_0 : vec3<f32>;
    if((presence_3 > 0.0f))
    {
        var film_1 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_31, idoth_10, BaseReflectionTransmission_HasDielectric_0(this_31), BaseReflectionTransmission_HasMetal_0(this_31));
        thinFilm_0 = this_31.reflectionScaleTransparent_0 * film_1.dielectric_0 + this_31.reflectionScaleOpaque_0 * film_1.dielectric_0 + vec3<f32>(this_31.metalAmount_0) * film_1.metal_0;
    }
    else
    {
        thinFilm_0 = standard_0;
    }
    return mix(standard_1, thinFilm_0, vec3<f32>(presence_3)) + this_31.thinWallReflection_0;
}

fn GGXDistribution_G2_0( this_32 : GGXDistribution_0,  wo_9 : vec3<f32>,  wi_6 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_32.frame_1, wo_9), this_32.alpha_0) * SmithG1_0(Frame_ToLocal_0(this_32.frame_1, wi_6), this_32.alpha_0);
}

fn BaseReflectionTransmission_Transmission_0( this_33 : BaseReflectionTransmission_0,  idoth_11 : f32) -> vec3<f32>
{
    var standard_2 : vec3<f32> = vec3<f32>(0.0f);
    var presence_4 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_33, idoth_11);
    var standard_3 : vec3<f32>;
    if((presence_4 < 1.0f))
    {
        standard_3 = this_33.transmission_0 * (vec3<f32>(1.0f) - FresnelDielectric_1(this_33.etaTransparent_0, idoth_11));
    }
    else
    {
        standard_3 = standard_2;
    }
    var thinFilm_1 : vec3<f32>;
    if((presence_4 > 0.0f))
    {
        thinFilm_1 = this_33.transmission_0 * (vec3<f32>(1.0f) - BaseReflectionTransmission_ThinFilm_0(this_33, idoth_11, (any((((this_33.reflectionScaleTransparent_0) > standard_2)))), false).dielectric_0);
    }
    else
    {
        thinFilm_1 = standard_2;
    }
    return mix(standard_3, thinFilm_1, vec3<f32>(presence_4));
}

fn SpecularLobe_Eval_0( this_34 : SpecularLobe_0,  wo_10 : vec3<f32>,  wi_7 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_3 : f32 = dot(this_34.normal_2, wo_10);
    var _S203 : f32 = idotn_3 * dot(this_34.normal_2, wi_7);
    if((_S203 > 0.0f))
    {
        var h_7 : vec3<f32> = normalize(wo_10 + wi_7);
        return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_34.distribution_0, wo_10, wi_7)) * (vec3<f32>((GGXDistribution_D_0(this_34.distribution_0, h_7) * (1.0f / (4.0f * idotn_3)))) * BaseReflectionTransmission_Reflection_0(this_34.coefficient_0, abs(dot(wo_10, h_7)))));
    }
    if((_S203 >= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var dOtherTermsF_0 : vec3<f32>;
    var d_6 : f32;
    var otherTerms_2 : f32;
    var absIdoth_2 : f32;
    var c_9 : i32 = i32(0);
    loop
    {
        if((c_9 < i32(3)))
        {
        }
        else
        {
            break;
        }
        var _S204 : bool = SpecularLobe_TransmissionTerms_0(this_34, wo_10, wi_7, idotn_3, this_34.eta_0[c_9], &(d_6), &(otherTerms_2), &(absIdoth_2));
        var _S205 : f32;
        if(_S204)
        {
            _S205 = d_6 * otherTerms_2 * BaseReflectionTransmission_Transmission_0(this_34.coefficient_0, absIdoth_2)[c_9];
        }
        else
        {
            _S205 = 0.0f;
        }
        dOtherTermsF_0[c_9] = _S205;
        c_9 = c_9 + i32(1);
    }
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_34.distribution_0, wo_10, wi_7)) * dOtherTermsF_0);
}

fn SpecularLobe_Sample_0( this_35 : SpecularLobe_0,  u_10 : vec3<f32>,  wo_11 : vec3<f32>) -> LobeSample_0
{
    var idotn_4 : f32 = dot(wo_11, this_35.normal_2);
    var h_8 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_35.distribution_0, wo_11, u_10.xy);
    var idoth_12 : f32 = dot(wo_11, h_8);
    if((idoth_12 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var c_10 : ReflectionTransmission_0 = BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_35.coefficient_0, this_35.throughput_0, idoth_12);
    if((c_10.reflectionProbability_0 + c_10.transmissionProbability_0) == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var _S206 : f32 = u_10.z;
    if((_S206 < (c_10.reflectionProbability_0)))
    {
        var wi_8 : vec3<f32> = normalize((vec3<f32>(0) - wo_11) + h_8 * vec3<f32>(2.0f) * vec3<f32>(idoth_12));
        if(((idotn_4 * dot(this_35.normal_2, wi_8)) <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        var odoth_3 : f32 = dot(wi_8, h_8);
        var weight_2 : DiffuseSpecular_0 = DiffuseSpecular_Specular_0(c_10.reflection_1 * vec3<f32>((1.0f / c_10.reflectionProbability_0)) * vec3<f32>(GGXDistribution_G1_0(this_35.distribution_0, wi_8)));
        var d_7 : f32 = GGXDistribution_D_0(this_35.distribution_0, h_8);
        if((d_7 <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        return LobeSample_Make_0(wi_8, weight_2, c_10.reflectionProbability_0 * d_7 * GGXDistribution_G1_0(this_35.distribution_0, wo_11) * idoth_12 / (4.0f * odoth_3 * idotn_4), u32(9));
    }
    var remapped_0 : f32 = (_S206 - c_10.reflectionProbability_0) / c_10.transmissionProbability_0;
    var channelProbabilities_0 : vec3<f32> = SpecularLobe_ChannelProbabilities_0(this_35);
    var channel_0 : i32;
    if((remapped_0 < (channelProbabilities_0[i32(0)])))
    {
        channel_0 = i32(0);
    }
    else
    {
        if((remapped_0 < (channelProbabilities_0[i32(0)] + channelProbabilities_0[i32(1)])))
        {
            channel_0 = i32(1);
        }
        else
        {
            channel_0 = i32(2);
        }
    }
    var wi_9 : vec3<f32>;
    var _S207 : bool = Refract_0(wo_11, h_8, idoth_12, this_35.eta_0[channel_0], &(wi_9));
    if(!_S207)
    {
        return LobeSample_Invalid_0();
    }
    if(((idotn_4 * dot(wi_9, this_35.normal_2)) >= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var pdf_3 : f32 = SpecularLobe_Pdf_0(this_35, wo_11, wi_9);
    if(pdf_3 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_9, x2A_0(SpecularLobe_Eval_0(this_35, wo_11, wi_9), 1.0f / pdf_3), pdf_3, u32(10));
}

fn DielectricMultipleScatteringLobe_Active_0( this_36 : DielectricMultipleScatteringLobe_0) -> bool
{
    return ((this_36.alpha_1) >= 0.0015999999595806003f);
}

fn BasisFromNormal_0( n_7 : vec3<f32>) -> Frame_0
{
    var _S208 : f32 = n_7.z;
    var s_8 : f32;
    if((_S208 < 0.0f))
    {
        s_8 = -1.0f;
    }
    else
    {
        s_8 = 1.0f;
    }
    var a_9 : f32 = -1.0f / (s_8 + _S208);
    var _S209 : f32 = n_7.x;
    var _S210 : f32 = n_7.y;
    var b_6 : f32 = _S209 * _S210 * a_9;
    var f_4 : Frame_0;
    f_4.n_1 = n_7;
    f_4.t_3 = vec3<f32>(b_6, s_8 + _S210 * _S210 * a_9, - _S210);
    f_4.b_0 = vec3<f32>(1.0f + s_8 * _S209 * _S209 * a_9, s_8 * b_6, - s_8 * _S209);
    return f_4;
}

fn UniformHemisphereDirection_0( basis_2 : Frame_0,  z_7 : f32,  u_11 : f32) -> vec3<f32>
{
    var horizontal_0 : f32 = sqrt(1.0f - Square_0(z_7));
    var azimuth_0 : f32 = 2.0f * float_getPi_0() * u_11;
    return Frame_ToWorld_0(basis_2, vec3<f32>(cos(azimuth_0) * horizontal_0, sin(azimuth_0) * horizontal_0, z_7));
}

fn IorToExactIndex_0( ior_0 : f32) -> f32
{
    if((ior_0 < 1.0f))
    {
        return 15.0f - (1.0f / ior_0 - 1.0f) * 0.66666668653488159f * 15.0f;
    }
    return 16.0f + (ior_0 - 1.0f) * 0.66666668653488159f * 15.0f;
}

fn AlphaToExactIndex_0( alpha_8 : f32) -> f32
{
    return sqrt(alpha_8) * 31.0f;
}

fn CosToExactIndex_0( cosTheta_4 : f32) -> f32
{
    return cosTheta_4 * 31.0f;
}

fn ClampExactIndex_0( index_7 : f32) -> f32
{
    return clamp(index_7, 0.0f, 31.0f);
}

fn FetchEnergy_0( x_18 : i32,  y_7 : i32,  slice_1 : i32) -> f32
{
    return FetchTable_0(x_18, y_7, slice_1) * 1.5259021893143654e-05f;
}

fn LookUpTrilinear_0( firstSlice_0 : i32,  exactX_0 : f32,  exactY_0 : f32,  exactZ_0 : f32) -> f32
{
    var x_19 : f32 = ClampExactIndex_0(exactX_0);
    var y_8 : f32 = ClampExactIndex_0(exactY_0);
    var z_8 : f32 = ClampExactIndex_0(exactZ_0);
    var ix0_0 : i32 = i32(floor(x_19));
    var iy0_0 : i32 = i32(floor(y_8));
    var iz0_0 : i32 = i32(floor(z_8));
    var _S211 : i32 = min(iy0_0 + i32(1), i32(31));
    var _S212 : i32 = min(iz0_0 + i32(1), i32(31));
    var tx_0 : f32 = x_19 - f32(ix0_0);
    var ty_0 : f32 = y_8 - f32(iy0_0);
    var _S213 : i32 = firstSlice_0 + ix0_0;
    var _S214 : i32 = firstSlice_0 + min(ix0_0 + i32(1), i32(31));
    return mix(mix(mix(FetchEnergy_0(iz0_0, iy0_0, _S213), FetchEnergy_0(iz0_0, iy0_0, _S214), tx_0), mix(FetchEnergy_0(iz0_0, _S211, _S213), FetchEnergy_0(iz0_0, _S211, _S214), tx_0), ty_0), mix(mix(FetchEnergy_0(_S212, iy0_0, _S213), FetchEnergy_0(_S212, iy0_0, _S214), tx_0), mix(FetchEnergy_0(_S212, _S211, _S213), FetchEnergy_0(_S212, _S211, _S214), tx_0), ty_0), z_8 - f32(iz0_0));
}

fn IdealDielectricEnergyComplement_0( ior_1 : f32,  alpha_9 : f32,  cosTheta_5 : f32) -> f32
{
    return LookUpTrilinear_0(i32(0), IorToExactIndex_0(ior_1), AlphaToExactIndex_0(alpha_9), CosToExactIndex_0(cosTheta_5));
}

fn LookUpBilinear_0( slice_2 : i32,  exactX_1 : f32,  exactY_1 : f32) -> f32
{
    var x_20 : f32 = ClampExactIndex_0(exactX_1);
    var y_9 : f32 = ClampExactIndex_0(exactY_1);
    var ix0_1 : i32 = i32(floor(x_20));
    var iy0_1 : i32 = i32(floor(y_9));
    var _S215 : i32 = min(ix0_1 + i32(1), i32(31));
    var _S216 : i32 = min(iy0_1 + i32(1), i32(31));
    var tx_1 : f32 = x_20 - f32(ix0_1);
    return mix(mix(FetchEnergy_0(iy0_1, ix0_1, slice_2), FetchEnergy_0(iy0_1, _S215, slice_2), tx_1), mix(FetchEnergy_0(_S216, ix0_1, slice_2), FetchEnergy_0(_S216, _S215, slice_2), tx_1), y_9 - f32(iy0_1));
}

fn IdealDielectricAverageEnergyComplement_0( ior_2 : f32,  alpha_10 : f32) -> f32
{
    return LookUpBilinear_0(i32(64), IorToExactIndex_0(ior_2), AlphaToExactIndex_0(alpha_10));
}

fn ClampAverageEnergyComplement_0( value_1 : f32) -> f32
{
    return max(value_1, 9.999999960041972e-13f);
}

fn DielectricMultipleScatteringLobe_TabulatedFactors_0( this_37 : DielectricMultipleScatteringLobe_0,  odotn_0 : f32,  includeRatio_0 : bool) -> f32
{
    var iorToUse_0 : f32;
    var _S217 : f32;
    var ratio_0 : f32;
    if((odotn_0 <= 0.0f))
    {
        var _S218 : f32 = - odotn_0;
        var _S219 : f32 = 1.0f - this_37.reflectionRatio_0;
        iorToUse_0 = 1.0f / this_37.eta_1;
        _S217 = _S218;
        ratio_0 = _S219;
    }
    else
    {
        iorToUse_0 = this_37.eta_1;
        _S217 = odotn_0;
        ratio_0 = this_37.reflectionRatio_0;
    }
    var factors_0 : f32 = this_37.energyComplementWo_0 * IdealDielectricEnergyComplement_0(iorToUse_0, this_37.alpha_1, _S217) / ClampAverageEnergyComplement_0(IdealDielectricAverageEnergyComplement_0(iorToUse_0, this_37.alpha_1));
    var factors_1 : f32;
    if(includeRatio_0)
    {
        factors_1 = factors_0 * ratio_0;
    }
    else
    {
        factors_1 = factors_0;
    }
    return min(factors_1, SafeDivide_0(1.0f, _S217, 0.0f));
}

fn DielectricMultipleScatteringLobe_Sample_0( this_38 : DielectricMultipleScatteringLobe_0,  u_12 : vec3<f32>,  wo_12 : vec3<f32>) -> LobeSample_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_38))
    {
        return LobeSample_Invalid_0();
    }
    var ux_0 : f32 = u_12.x;
    var z_9 : f32;
    if((ux_0 < (this_38.reflectionRatio_0)))
    {
        z_9 = ClampRemappedRandom_0(ux_0 / this_38.reflectionRatio_0);
    }
    else
    {
        z_9 = - ClampRemappedRandom_0((ux_0 - this_38.reflectionRatio_0) / (1.0f - this_38.reflectionRatio_0));
    }
    var wi_10 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_38.normal_3), z_9, u_12.y);
    var odotn_1 : f32 = dot(wi_10, this_38.normal_3);
    var unscaledWeight_0 : f32 = 2.0f * abs(odotn_1) * DielectricMultipleScatteringLobe_TabulatedFactors_0(this_38, odotn_1, false);
    if((odotn_1 > 0.0f))
    {
        return LobeSample_Make_0(wi_10, DiffuseSpecular_Specular_0(this_38.reflectionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * this_38.reflectionRatio_0, u32(9));
    }
    return LobeSample_Make_0(wi_10, DiffuseSpecular_Specular_0(this_38.transmissionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * (1.0f - this_38.reflectionRatio_0), u32(10));
}

fn MetalMultipleScatteringLobe_Active_0( this_39 : MetalMultipleScatteringLobe_0) -> bool
{
    return ((this_39.alpha_2) >= 0.0015999999595806003f);
}

fn IdealMetalEnergyComplement_0( alpha_11 : f32,  cosTheta_6 : f32) -> f32
{
    return LookUpBilinear_0(i32(67), AlphaToExactIndex_0(alpha_11), CosToExactIndex_0(cosTheta_6));
}

fn LookUpLinear_0( slice_3 : i32,  exactX_2 : f32) -> f32
{
    var x_21 : f32 = ClampExactIndex_0(exactX_2);
    var i0_0 : i32 = i32(floor(x_21));
    return mix(FetchEnergy_0(i0_0, i32(0), slice_3), FetchEnergy_0(min(i0_0 + i32(1), i32(31)), i32(0), slice_3), x_21 - f32(i0_0));
}

fn IdealMetalAverageEnergyComplement_0( alpha_12 : f32) -> f32
{
    return LookUpLinear_0(i32(68), AlphaToExactIndex_0(alpha_12));
}

fn MetalMultipleScatteringLobe_TabulatedFactors_0( this_40 : MetalMultipleScatteringLobe_0,  odotn_2 : f32) -> f32
{
    return min(this_40.energyComplementWo_1 * IdealMetalEnergyComplement_0(this_40.alpha_2, odotn_2) / ClampAverageEnergyComplement_0(IdealMetalAverageEnergyComplement_0(this_40.alpha_2)), SafeDivide_0(1.0f, odotn_2, 0.0f));
}

fn MetalMultipleScatteringLobe_LobeType_0( this_41 : MetalMultipleScatteringLobe_0) -> u32
{
    return u32(9);
}

fn MetalMultipleScatteringLobe_Sample_0( this_42 : MetalMultipleScatteringLobe_0,  u_13 : vec3<f32>,  wo_13 : vec3<f32>) -> LobeSample_0
{
    if(!MetalMultipleScatteringLobe_Active_0(this_42))
    {
        return LobeSample_Invalid_0();
    }
    var wi_11 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_42.normal_4), u_13.x, u_13.y);
    var odotn_3 : f32 = dot(wi_11, this_42.normal_4);
    return LobeSample_Make_0(wi_11, DiffuseSpecular_Specular_0(this_42.scale_0 * vec3<f32>((2.0f * odotn_3 * MetalMultipleScatteringLobe_TabulatedFactors_0(this_42, odotn_3)))), 0.5f / float_getPi_0(), MetalMultipleScatteringLobe_LobeType_0(this_42));
}

fn FONAlbedo_0( mu_0 : f32,  roughness_2 : f32) -> f32
{
    var mucomp_0 : f32 = 1.0f - mu_0;
    return (1.0f + roughness_2 * (mucomp_0 * (0.057108528912067413f + mucomp_0 * (0.49188187718391418f + mucomp_0 * (-0.33218145370483398f + mucomp_0 * 0.071442998945713043f))))) / (1.0f + (0.5f - 2.0f / (3.0f * float_getPi_0())) * roughness_2);
}

fn EvalEON_0( rho_0 : vec3<f32>,  roughness_3 : f32,  viewLocal_0 : vec3<f32>,  lightLocal_0 : vec3<f32>) -> vec3<f32>
{
    var muI_0 : f32 = viewLocal_0.z;
    var muO_0 : f32 = lightLocal_0.z;
    var s_9 : f32 = dot(viewLocal_0, lightLocal_0) - muI_0 * muO_0;
    var sOverT_0 : f32;
    if((s_9 > 0.0f))
    {
        sOverT_0 = s_9 / max(muI_0, muO_0);
    }
    else
    {
        sOverT_0 = s_9;
    }
    var PI_0 : f32 = float_getPi_0();
    var aF_0 : f32 = 1.0f / (1.0f + (0.5f - 2.0f / (3.0f * PI_0)) * roughness_3);
    var averageEF_0 : f32 = aF_0 * (1.0f + (0.66666668653488159f - 28.0f / (15.0f * PI_0)) * roughness_3);
    var _S220 : f32 = 1.0f - averageEF_0;
    return rho_0 * vec3<f32>((1.0f / PI_0)) * vec3<f32>(aF_0) * vec3<f32>((1.0f + roughness_3 * sOverT_0)) + rho_0 * rho_0 * vec3<f32>(averageEF_0) / (vec3<f32>(1.0f) - rho_0 * vec3<f32>(_S220)) * vec3<f32>((1.0f / PI_0)) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muO_0, roughness_3))) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muI_0, roughness_3))) / vec3<f32>(max(1.00000001168609742e-07f, _S220));
}

fn F0FromIor_0( eta_6 : f32) -> f32
{
    return Square_0((eta_6 - 1.0f) / (eta_6 + 1.0f));
}

fn ExtrapolateBeyondIorMax_0( tableValue_0 : f32,  ior_3 : f32) -> f32
{
    var _S221 : bool;
    if((ior_3 > 2.5f))
    {
        _S221 = true;
    }
    else
    {
        _S221 = (ior_3 < 0.40000000596046448f);
    }
    if(_S221)
    {
        var F0_MAX_0 : f32 = F0FromIor_0(2.5f);
        return (1.0f - (F0FromIor_0(ior_3) - F0_MAX_0) * (1.0f / (1.0f - F0_MAX_0))) * tableValue_0;
    }
    return tableValue_0;
}

fn OpaqueDielectricEnergyComplement_0( ior_4 : f32,  alpha_13 : f32,  cosTheta_7 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpTrilinear_0(i32(32), IorToExactIndex_0(ior_4), AlphaToExactIndex_0(alpha_13), CosToExactIndex_0(cosTheta_7)), ior_4);
}

fn DiffuseLobe_BRDFLocal_0( this_43 : DiffuseLobe_0,  woLocal_1 : vec3<f32>,  wiLocal_0 : vec3<f32>) -> vec3<f32>
{
    return EvalEON_0(this_43.albedo_0, this_43.roughness_1, woLocal_1, wiLocal_0) * vec3<f32>((this_43.specularCompensation_0 * OpaqueDielectricEnergyComplement_0(this_43.specularEta_0, this_43.specularAlpha_0, wiLocal_0.z)));
}

fn DiffuseSpecular_Diffuse_0( value_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(value_2, vec3<f32>(0.0f));
}

fn DiffuseLobe_LobeType_0( this_44 : DiffuseLobe_0) -> u32
{
    return u32(5);
}

fn DiffuseLobe_Sample_0( this_45 : DiffuseLobe_0,  u_14 : vec3<f32>,  wo_14 : vec3<f32>) -> LobeSample_0
{
    var wiLocal_1 : vec3<f32> = SampleCosineHemisphere_0(u_14.xy);
    var cosOut_0 : f32 = wiLocal_1.z;
    if(cosOut_0 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var basis_3 : Frame_0 = BasisFromNormal_0(this_45.normal_5);
    var PI_1 : f32 = float_getPi_0();
    return LobeSample_Make_0(Frame_ToWorld_0(basis_3, wiLocal_1), DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_45, Frame_ToLocal_0(basis_3, wo_14), wiLocal_1) * vec3<f32>(PI_1)), cosOut_0 * (1.0f / PI_1), DiffuseLobe_LobeType_0(this_45));
}

fn MicrofacetReflectionLobe_GetNormal_0( this_46 : MicrofacetReflectionLobe_0) -> vec3<f32>
{
    return this_46.normal_6;
}

fn ConstantReflection_Reflection_0( this_47 : ConstantReflection_0,  idoth_13 : f32) -> vec3<f32>
{
    return this_47.color_2;
}

fn MicrofacetReflectionLobe_LobeType_1( this_48 : MicrofacetReflectionLobe_0) -> u32
{
    return u32(9);
}

fn MicrofacetReflectionLobe_Sample_1( this_49 : MicrofacetReflectionLobe_0,  u_15 : vec3<f32>,  wo_15 : vec3<f32>) -> LobeSample_0
{
    var idotn_5 : f32 = dot(wo_15, this_49.normal_6);
    var h_9 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_49.distribution_1, wo_15, u_15.xy);
    var idoth_14 : f32 = dot(wo_15, h_9);
    if((idoth_14 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_12 : vec3<f32> = normalize((vec3<f32>(0) - wo_15) + h_9 * vec3<f32>(2.0f) * vec3<f32>(idoth_14));
    if(((idotn_5 * dot(this_49.normal_6, wi_12)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_4 : f32 = dot(wi_12, h_9);
    var f_5 : vec3<f32> = ConstantReflection_Reflection_0(this_49.coefficient_1, idoth_14);
    var gShadowing_1 : f32 = GGXDistribution_G1_0(this_49.distribution_1, wi_12);
    var d_8 : f32 = GGXDistribution_D_0(this_49.distribution_1, h_9);
    if((d_8 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_12, DiffuseSpecular_Specular_0(f_5 * vec3<f32>(gShadowing_1)), d_8 * GGXDistribution_G1_0(this_49.distribution_1, wo_15) * idoth_14 / (4.0f * odoth_4 * idotn_5), MicrofacetReflectionLobe_LobeType_1(this_49));
}

fn SwapReflectionTransmission_0( type_2 : u32) -> u32
{
    var swapped_0 : u32 = (type_2 & (u32(4294967292)));
    var swapped_1 : u32;
    if(((type_2 & (u32(1)))) != u32(0))
    {
        swapped_1 = (swapped_0 | (u32(2)));
    }
    else
    {
        swapped_1 = swapped_0;
    }
    if(((type_2 & (u32(2)))) != u32(0))
    {
        swapped_1 = (swapped_1 | (u32(1)));
    }
    return swapped_1;
}

fn FlippedLobe_Sample_0( this_50 : FlippedLobe_0,  u_16 : vec3<f32>,  wo_16 : vec3<f32>) -> LobeSample_0
{
    var s_10 : LobeSample_0 = MicrofacetReflectionLobe_Sample_1(this_50.lobe_0, u_16, reflect(wo_16, MicrofacetReflectionLobe_GetNormal_0(this_50.lobe_0)));
    s_10.type_0 = SwapReflectionTransmission_0(s_10.type_0);
    return s_10;
}

fn DiffuseLobe_GetNormal_0( this_51 : DiffuseLobe_0) -> vec3<f32>
{
    return this_51.normal_5;
}

fn FlippedLobe_Sample_1( this_52 : FlippedLobe_1,  u_17 : vec3<f32>,  wo_17 : vec3<f32>) -> LobeSample_0
{
    var s_11 : LobeSample_0 = DiffuseLobe_Sample_0(this_52.lobe_0, u_17, reflect(wo_17, DiffuseLobe_GetNormal_0(this_52.lobe_0)));
    s_11.type_0 = SwapReflectionTransmission_0(s_11.type_0);
    return s_11;
}

fn BaseLobe_LobeSampleAt_0( this_53 : BaseLobe_0,  index_8 : i32,  u_18 : vec3<f32>,  wo_18 : vec3<f32>) -> LobeSample_0
{
    switch(index_8)
    {
    case i32(0):
        {
            return SpecularLobe_Sample_0(this_53.specular_0, u_18, wo_18);
        }
    case i32(1):
        {
            return DielectricMultipleScatteringLobe_Sample_0(this_53.dielectricMultipleScattering_0, u_18, wo_18);
        }
    case i32(2):
        {
            return MetalMultipleScatteringLobe_Sample_0(this_53.metalMultipleScattering_0, u_18, wo_18);
        }
    case i32(3):
        {
            return DiffuseLobe_Sample_0(this_53.diffuse_0, u_18, wo_18);
        }
    case i32(4):
        {
            return FlippedLobe_Sample_0(this_53.thinWallSpecularTransmission_0, u_18, wo_18);
        }
    default :
        {
            return FlippedLobe_Sample_1(this_53.thinWallDiffuseTransmission_0, u_18, wo_18);
        }
    }
}

fn BaseLobe_SampleLobe_0( this_54 : BaseLobe_0,  u_19 : vec3<f32>,  wo_19 : vec3<f32>,  wi_13 : ptr<function, vec3<f32>>,  type_3 : ptr<function, u32>,  sampled_0 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_13) = vec3<f32>(0.0f);
    (*type_3) = u32(0);
    (*sampled_0) = SampledLobe_None_0();
    var ux_1 : f32 = u_19.x;
    var selectedWeight_1 : f32;
    var totalWeight_1 : f32;
    var selected_0 : i32 = BaseLobe_SelectLobe_0(this_54, &(ux_1), &(selectedWeight_1), &(totalWeight_1));
    if((selected_0 < i32(0)))
    {
        return false;
    }
    var s_12 : LobeSample_0 = BaseLobe_LobeSampleAt_0(this_54, selected_0, vec3<f32>(ux_1, u_19.y, u_19.z), wo_19);
    (*wi_13) = s_12.wi_0;
    (*type_3) = s_12.type_0;
    (*sampled_0) = SampledLobe_Make_0(i32(1), selected_0, s_12);
    return s_12.valid_0;
}

fn CoatLobe_SampleLobe_0( this_55 : CoatLobe_0,  u_20 : vec3<f32>,  wo_20 : vec3<f32>,  wi_14 : ptr<function, vec3<f32>>,  type_4 : ptr<function, u32>,  sampled_1 : ptr<function, SampledLobe_0>) -> bool
{
    var _S222 : bool = !this_55.inside_0;
    var _S223 : bool;
    if(_S222)
    {
        _S223 = CoatLobe_HasCoat_0(this_55);
    }
    else
    {
        _S223 = false;
    }
    var coatProbability_0 : f32;
    if(_S223)
    {
        coatProbability_0 = CoatLobe_ReflectionProbability_0(this_55, wo_20);
    }
    else
    {
        coatProbability_0 = 0.0f;
    }
    var ux_2 : f32 = u_20.x;
    if(_S222)
    {
        _S223 = (ux_2 < coatProbability_0);
    }
    else
    {
        _S223 = false;
    }
    if(_S223)
    {
        var s_13 : LobeSample_0 = MicrofacetReflectionLobe_Sample_0(this_55.reflection_0, vec3<f32>(ClampRemappedRandom_0(ux_2 * (1.0f / coatProbability_0)), u_20.y, u_20.z), wo_20);
        (*wi_14) = s_13.wi_0;
        (*type_4) = s_13.type_0;
        (*sampled_1) = SampledLobe_Make_0(i32(2), i32(0), s_13);
        return s_13.valid_0;
    }
    var ux_3 : f32;
    if(_S222)
    {
        ux_3 = ClampRemappedRandom_0((ux_2 - coatProbability_0) * (1.0f / (1.0f - coatProbability_0)));
    }
    else
    {
        ux_3 = ux_2;
    }
    var _S224 : bool = BaseLobe_SampleLobe_0(this_55.base_3, vec3<f32>(ux_3, u_20.y, u_20.z), wo_20, &((*wi_14)), &((*type_4)), &((*sampled_1)));
    return _S224;
}

fn FuzzLobe_SampleLobe_0( this_56 : FuzzLobe_0,  u_21 : vec3<f32>,  wo_21 : vec3<f32>,  wi_15 : ptr<function, vec3<f32>>,  type_5 : ptr<function, u32>,  sampled_2 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_15) = vec3<f32>(0.0f);
    (*type_5) = u32(9);
    (*sampled_2) = SampledLobe_None_0();
    var sheenProbability_0 : f32;
    if(FuzzLobe_HasFuzz_0(this_56))
    {
        sheenProbability_0 = FuzzLobe_SheenProbability_0(this_56, wo_21);
    }
    else
    {
        sheenProbability_0 = 0.0f;
    }
    var _S225 : f32 = u_21.x;
    if((_S225 < sheenProbability_0))
    {
        var _S226 : f32 = this_56.woLocal_0.z;
        if((_S226 <= 0.0f))
        {
            return false;
        }
        var wiLocal_2 : vec3<f32> = SheenRotate_0(SheenSampleLTC_0(FuzzLobe_Coefficients_0(this_56, this_56.woLocal_0), u_21.yz), this_56.woLocal_0.xy);
        if(((_S226 * wiLocal_2.z) <= 0.0f))
        {
            return false;
        }
        (*wi_15) = normalize(Frame_ToWorld_0(this_56.basis_1, wiLocal_2));
        return true;
    }
    var _S227 : bool = CoatLobe_SampleLobe_0(this_56.base_4, vec3<f32>(ClampRemappedRandom_0((_S225 - sheenProbability_0) * (1.0f / (1.0f - sheenProbability_0))), u_21.y, u_21.z), wo_21, &((*wi_15)), &((*type_5)), &((*sampled_2)));
    return _S227;
}

fn BaseLobe_IsActive_0( this_57 : BaseLobe_0,  index_9 : i32) -> bool
{
    var _S228 : bool;
    if(BaseLobeEnabled_0(index_9))
    {
        _S228 = ((this_57.weights_0[index_9]) > 0.0f);
    }
    else
    {
        _S228 = false;
    }
    return _S228;
}

fn DielectricMultipleScatteringLobe_Eval_0( this_58 : DielectricMultipleScatteringLobe_0,  wo_22 : vec3<f32>,  wi_16 : vec3<f32>) -> DiffuseSpecular_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_58))
    {
        return DiffuseSpecular_Zero_0();
    }
    var odotn_4 : f32 = dot(wi_16, this_58.normal_3);
    var unscaledCos_0 : f32 = DielectricMultipleScatteringLobe_TabulatedFactors_0(this_58, odotn_4, true) * (1.0f / float_getPi_0()) * abs(odotn_4);
    var _S229 : vec3<f32>;
    if((odotn_4 > 0.0f))
    {
        _S229 = this_58.reflectionScale_0;
    }
    else
    {
        _S229 = this_58.transmissionScale_0;
    }
    return DiffuseSpecular_Specular_0(_S229 * vec3<f32>(unscaledCos_0));
}

fn DielectricMultipleScatteringLobe_Pdf_0( this_59 : DielectricMultipleScatteringLobe_0,  wo_23 : vec3<f32>,  wi_17 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_59))
    {
        return 0.0f;
    }
    var _S230 : f32;
    if(((dot(wi_17, this_59.normal_3)) > 0.0f))
    {
        _S230 = this_59.reflectionRatio_0;
    }
    else
    {
        _S230 = 1.0f - this_59.reflectionRatio_0;
    }
    return 0.5f / float_getPi_0() * _S230;
}

fn MetalMultipleScatteringLobe_Eval_0( this_60 : MetalMultipleScatteringLobe_0,  wo_24 : vec3<f32>,  wi_18 : vec3<f32>) -> DiffuseSpecular_0
{
    var odotn_5 : f32 = dot(wi_18, this_60.normal_4);
    var _S231 : bool;
    if(!MetalMultipleScatteringLobe_Active_0(this_60))
    {
        _S231 = true;
    }
    else
    {
        _S231 = (odotn_5 <= 0.0f);
    }
    if(_S231)
    {
        return DiffuseSpecular_Zero_0();
    }
    return DiffuseSpecular_Specular_0(this_60.scale_0 * vec3<f32>((MetalMultipleScatteringLobe_TabulatedFactors_0(this_60, odotn_5) * (1.0f / float_getPi_0()) * odotn_5)));
}

fn MetalMultipleScatteringLobe_Pdf_0( this_61 : MetalMultipleScatteringLobe_0,  wo_25 : vec3<f32>,  wi_19 : vec3<f32>) -> f32
{
    var _S232 : bool;
    if(MetalMultipleScatteringLobe_Active_0(this_61))
    {
        _S232 = ((dot(wi_19, this_61.normal_4)) > 0.0f);
    }
    else
    {
        _S232 = false;
    }
    var _S233 : f32;
    if(_S232)
    {
        _S233 = 0.5f / float_getPi_0();
    }
    else
    {
        _S233 = 0.0f;
    }
    return _S233;
}

fn DiffuseLobe_Eval_0( this_62 : DiffuseLobe_0,  wo_26 : vec3<f32>,  wi_20 : vec3<f32>) -> DiffuseSpecular_0
{
    var cosOut_1 : f32 = dot(wi_20, this_62.normal_5);
    if((cosOut_1 <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var basis_4 : Frame_0 = BasisFromNormal_0(this_62.normal_5);
    return DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_62, Frame_ToLocal_0(basis_4, wo_26), Frame_ToLocal_0(basis_4, wi_20)) * vec3<f32>(cosOut_1));
}

fn DiffuseLobe_Pdf_0( this_63 : DiffuseLobe_0,  wo_27 : vec3<f32>,  wi_21 : vec3<f32>) -> f32
{
    return max(dot(wi_21, this_63.normal_5), 0.0f) * (1.0f / float_getPi_0());
}

fn MicrofacetReflectionLobe_Eval_0( this_64 : MicrofacetReflectionLobe_0,  wo_28 : vec3<f32>,  wi_22 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_6 : f32 = dot(this_64.normal_6, wo_28);
    if(((idotn_6 * dot(this_64.normal_6, wi_22)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_10 : vec3<f32> = normalize(wo_28 + wi_22);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_64.distribution_1, wo_28, wi_22)) * (vec3<f32>((GGXDistribution_D_0(this_64.distribution_1, h_10) * (1.0f / (4.0f * idotn_6)))) * ConstantReflection_Reflection_0(this_64.coefficient_1, abs(dot(wo_28, h_10)))));
}

fn FlippedLobe_Eval_0( this_65 : FlippedLobe_0,  wo_29 : vec3<f32>,  wi_23 : vec3<f32>) -> DiffuseSpecular_0
{
    return MicrofacetReflectionLobe_Eval_0(this_65.lobe_0, reflect(wo_29, MicrofacetReflectionLobe_GetNormal_0(this_65.lobe_0)), wi_23);
}

fn MicrofacetReflectionLobe_Pdf_0( this_66 : MicrofacetReflectionLobe_0,  wo_30 : vec3<f32>,  wi_24 : vec3<f32>) -> f32
{
    var idotn_7 : f32 = dot(this_66.normal_6, wo_30);
    if(((idotn_7 * dot(this_66.normal_6, wi_24)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_11 : vec3<f32> = normalize(wo_30 + wi_24);
    var idoth_15 : f32 = dot(wo_30, h_11);
    var odoth_5 : f32 = dot(wi_24, h_11);
    if(((idoth_15 * odoth_5) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_66.distribution_1, wo_30) * (GGXDistribution_D_0(this_66.distribution_1, h_11) * (idoth_15 / (4.0f * odoth_5 * idotn_7)));
}

fn FlippedLobe_Pdf_0( this_67 : FlippedLobe_0,  wo_31 : vec3<f32>,  wi_25 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_Pdf_0(this_67.lobe_0, reflect(wo_31, MicrofacetReflectionLobe_GetNormal_0(this_67.lobe_0)), wi_25);
}

fn FlippedLobe_Eval_1( this_68 : FlippedLobe_1,  wo_32 : vec3<f32>,  wi_26 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseLobe_Eval_0(this_68.lobe_0, reflect(wo_32, DiffuseLobe_GetNormal_0(this_68.lobe_0)), wi_26);
}

fn FlippedLobe_Pdf_1( this_69 : FlippedLobe_1,  wo_33 : vec3<f32>,  wi_27 : vec3<f32>) -> f32
{
    return DiffuseLobe_Pdf_0(this_69.lobe_0, reflect(wo_33, DiffuseLobe_GetNormal_0(this_69.lobe_0)), wi_27);
}

fn BaseLobe_LobeEvalPdf_0( this_70 : BaseLobe_0,  index_10 : i32,  wo_34 : vec3<f32>,  wi_28 : vec3<f32>,  f_6 : ptr<function, DiffuseSpecular_0>,  pdf_4 : ptr<function, f32>)
{
    switch(index_10)
    {
    case i32(0):
        {
            (*f_6) = SpecularLobe_Eval_0(this_70.specular_0, wo_34, wi_28);
            (*pdf_4) = SpecularLobe_Pdf_0(this_70.specular_0, wo_34, wi_28);
        }
    case i32(1):
        {
            (*f_6) = DielectricMultipleScatteringLobe_Eval_0(this_70.dielectricMultipleScattering_0, wo_34, wi_28);
            (*pdf_4) = DielectricMultipleScatteringLobe_Pdf_0(this_70.dielectricMultipleScattering_0, wo_34, wi_28);
        }
    case i32(2):
        {
            (*f_6) = MetalMultipleScatteringLobe_Eval_0(this_70.metalMultipleScattering_0, wo_34, wi_28);
            (*pdf_4) = MetalMultipleScatteringLobe_Pdf_0(this_70.metalMultipleScattering_0, wo_34, wi_28);
        }
    case i32(3):
        {
            (*f_6) = DiffuseLobe_Eval_0(this_70.diffuse_0, wo_34, wi_28);
            (*pdf_4) = DiffuseLobe_Pdf_0(this_70.diffuse_0, wo_34, wi_28);
        }
    case i32(4):
        {
            (*f_6) = FlippedLobe_Eval_0(this_70.thinWallSpecularTransmission_0, wo_34, wi_28);
            (*pdf_4) = FlippedLobe_Pdf_0(this_70.thinWallSpecularTransmission_0, wo_34, wi_28);
        }
    default :
        {
            (*f_6) = FlippedLobe_Eval_1(this_70.thinWallDiffuseTransmission_0, wo_34, wi_28);
            (*pdf_4) = FlippedLobe_Pdf_1(this_70.thinWallDiffuseTransmission_0, wo_34, wi_28);
        }
    }
    return;
}

fn x2B_0( a_10 : DiffuseSpecular_0,  b_7 : DiffuseSpecular_0) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_10.diffuse_1 + b_7.diffuse_1, a_10.specular_1 + b_7.specular_1);
}

fn BaseLobe_EvalPdf_0( this_71 : BaseLobe_0,  wo_35 : vec3<f32>,  wi_29 : vec3<f32>,  sampled_3 : SampledLobe_0,  f_7 : ptr<function, DiffuseSpecular_0>,  pdf_5 : ptr<function, f32>)
{
    (*f_7) = DiffuseSpecular_Zero_0();
    var i_8 : i32 = i32(0);
    var sum_3 : f32 = 0.0f;
    var totalWeight_2 : f32 = 0.0f;
    loop
    {
        if((i_8 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_71, i_8))
        {
            var lobeF_0 : DiffuseSpecular_0 = sampled_3.f_2;
            var lobePdf_0 : f32 = sampled_3.pdf_0;
            var _S234 : bool;
            if((sampled_3.layer_0) != i32(1))
            {
                _S234 = true;
            }
            else
            {
                _S234 = (sampled_3.lobe_1) != i_8;
            }
            if(_S234)
            {
                BaseLobe_LobeEvalPdf_0(this_71, i_8, wo_35, wi_29, &(lobeF_0), &(lobePdf_0));
            }
            (*f_7) = x2B_0((*f_7), lobeF_0);
            var totalWeight_3 : f32 = totalWeight_2 + this_71.weights_0[i_8];
            sum_3 = sum_3 + this_71.weights_0[i_8] * lobePdf_0;
            totalWeight_2 = totalWeight_3;
        }
        i_8 = i_8 + i32(1);
    }
    if((totalWeight_2 > 0.0f))
    {
        sum_3 = sum_3 / totalWeight_2;
    }
    else
    {
        sum_3 = 0.0f;
    }
    (*pdf_5) = sum_3;
    return;
}

fn MinComponent_0( v_12 : vec3<f32>) -> f32
{
    return min(min(v_12.x, v_12.y), v_12.z);
}

fn SafePow_0( a_11 : f32,  b_8 : f32) -> f32
{
    var _S235 : f32;
    if((a_11 > 0.0f))
    {
        _S235 = pow(a_11, b_8);
    }
    else
    {
        _S235 = 0.0f;
    }
    return _S235;
}

fn SafePow_1( a_12 : vec3<f32>,  b_9 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(SafePow_0(a_12.x, b_9.x), SafePow_0(a_12.y, b_9.y), SafePow_0(a_12.z, b_9.z));
}

fn CoatLobe_PassageColor_0( this_72 : CoatLobe_0,  cosine_0 : f32) -> vec3<f32>
{
    var _S236 : bool;
    if((cosine_0 > 0.0f))
    {
        _S236 = ((MinComponent_0(this_72.tint_0)) < 1.0f);
    }
    else
    {
        _S236 = false;
    }
    if(_S236)
    {
        return mix(vec3<f32>(1.0f), SafePow_1(sqrt(this_72.tint_0), vec3<f32>((1.0f / sqrt(max(0.0f, 1.0f - (1.0f - Square_0(cosine_0)) / Square_0(this_72.reflection_0.coefficient_1.eta_2)))))), vec3<f32>(this_72.presence_0));
    }
    return vec3<f32>(1.0f);
}

fn x2A_1( a_13 : DiffuseSpecular_0,  scale_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_13.diffuse_1 * scale_2, a_13.specular_1 * scale_2);
}

fn MicrofacetReflectionLobe_Eval_1( this_73 : MicrofacetReflectionLobe_1,  wo_36 : vec3<f32>,  wi_30 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_8 : f32 = dot(this_73.normal_6, wo_36);
    if(((idotn_8 * dot(this_73.normal_6, wi_30)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_12 : vec3<f32> = normalize(wo_36 + wi_30);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_73.distribution_1, wo_36, wi_30)) * (vec3<f32>((GGXDistribution_D_0(this_73.distribution_1, h_12) * (1.0f / (4.0f * idotn_8)))) * DielectricReflection_Reflection_0(this_73.coefficient_1, abs(dot(wo_36, h_12)))));
}

fn CoatLobe_CoatEval_0( this_74 : CoatLobe_0,  wo_37 : vec3<f32>,  wi_31 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S237 : DiffuseSpecular_0;
    if(CoatLobe_HasCoat_0(this_74))
    {
        _S237 = MicrofacetReflectionLobe_Eval_1(this_74.reflection_0, wo_37, wi_31);
    }
    else
    {
        _S237 = DiffuseSpecular_Zero_0();
    }
    return _S237;
}

fn CoatLobe_BaseLayerScaleOneSide_0( this_75 : CoatLobe_0,  cosine_1 : f32,  reflectedFromThisSide_0 : f32) -> vec3<f32>
{
    return CoatLobe_PassageColor_0(this_75, cosine_1) * vec3<f32>((1.0f - reflectedFromThisSide_0));
}

fn CoatLobe_BaseLayerScaleComplete_0( this_76 : CoatLobe_0,  wi_32 : vec3<f32>) -> vec3<f32>
{
    return this_76.inBaseLayerScale_0 * CoatLobe_BaseLayerScaleOneSide_0(this_76, dot(wi_32, this_76.normal_7), 0.0f);
}

fn CoatLobe_Combine_0( this_77 : CoatLobe_0,  coatEval_0 : DiffuseSpecular_0,  baseEval_0 : DiffuseSpecular_0,  wi_33 : vec3<f32>) -> DiffuseSpecular_0
{
    return x2B_0(x2A_0(coatEval_0, this_77.presence_0), x2A_1(baseEval_0, CoatLobe_BaseLayerScaleComplete_0(this_77, wi_33)));
}

fn MicrofacetReflectionLobe_Pdf_1( this_78 : MicrofacetReflectionLobe_1,  wo_38 : vec3<f32>,  wi_34 : vec3<f32>) -> f32
{
    var idotn_9 : f32 = dot(this_78.normal_6, wo_38);
    if(((idotn_9 * dot(this_78.normal_6, wi_34)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_13 : vec3<f32> = normalize(wo_38 + wi_34);
    var idoth_16 : f32 = dot(wo_38, h_13);
    var odoth_6 : f32 = dot(wi_34, h_13);
    if(((idoth_16 * odoth_6) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_78.distribution_1, wo_38) * (GGXDistribution_D_0(this_78.distribution_1, h_13) * (idoth_16 / (4.0f * odoth_6 * idotn_9)));
}

fn CoatLobe_EvalPdf_0( this_79 : CoatLobe_0,  wo_39 : vec3<f32>,  wi_35 : vec3<f32>,  sampled_4 : SampledLobe_0,  f_8 : ptr<function, DiffuseSpecular_0>,  pdf_6 : ptr<function, f32>)
{
    var baseF_0 : DiffuseSpecular_0;
    var basePdf_0 : f32;
    BaseLobe_EvalPdf_0(this_79.base_3, wo_39, wi_35, sampled_4, &(baseF_0), &(basePdf_0));
    if(this_79.inside_0)
    {
        (*f_8) = x2A_1(baseF_0, CoatLobe_PassageColor_0(this_79, - dot(wi_35, this_79.normal_7)));
        (*pdf_6) = basePdf_0;
        return;
    }
    var coatSampled_0 : bool = (sampled_4.layer_0) == i32(2);
    var _S238 : DiffuseSpecular_0;
    if(coatSampled_0)
    {
        _S238 = sampled_4.f_2;
    }
    else
    {
        _S238 = CoatLobe_CoatEval_0(this_79, wo_39, wi_35);
    }
    (*f_8) = CoatLobe_Combine_0(this_79, _S238, baseF_0, wi_35);
    var _S239 : f32;
    if(CoatLobe_HasCoat_0(this_79))
    {
        var _S240 : f32 = basePdf_0;
        if(coatSampled_0)
        {
            _S239 = sampled_4.pdf_0;
        }
        else
        {
            _S239 = MicrofacetReflectionLobe_Pdf_1(this_79.reflection_0, wo_39, wi_35);
        }
        _S239 = mix(_S240, _S239, CoatLobe_ReflectionProbability_0(this_79, wo_39));
    }
    else
    {
        _S239 = basePdf_0;
    }
    (*pdf_6) = _S239;
    return;
}

fn FuzzLobe_BaseLayerScaleComplete_0( this_80 : FuzzLobe_0,  wiLocal_3 : vec3<f32>) -> f32
{
    return FuzzLobe_BaseLayerScaleIncoming_0(this_80);
}

fn SheenEvalLTC_0( wiLocal_4 : vec3<f32>,  ltc_1 : vec3<f32>) -> f32
{
    var aInv_0 : f32 = ltc_1.x;
    var _S241 : f32 = wiLocal_4.z;
    var wiOriginal_1 : vec3<f32> = vec3<f32>(aInv_0 * wiLocal_4.x + ltc_1.y * _S241, aInv_0 * wiLocal_4.y, _S241);
    var _S242 : f32 = max(0.0f, _S241);
    var lengthSquared_0 : f32 = dot(wiOriginal_1, wiOriginal_1);
    var _S243 : bool;
    if(lengthSquared_0 == 0.0f)
    {
        _S243 = true;
    }
    else
    {
        _S243 = aInv_0 == 0.0f;
    }
    if(_S243)
    {
        _S243 = true;
    }
    else
    {
        _S243 = _S242 == 0.0f;
    }
    if(_S243)
    {
        return 0.0f;
    }
    var aInvOverLengthSquared_0 : f32 = aInv_0 / lengthSquared_0;
    return 1.0f / float_getPi_0() * (_S242 * aInvOverLengthSquared_0) * aInvOverLengthSquared_0;
}

fn FuzzLobe_SheenEval_0( this_81 : FuzzLobe_0,  wiLocal_5 : vec3<f32>) -> vec3<f32>
{
    var _S244 : bool;
    if(((this_81.woLocal_0.z) <= 0.0f))
    {
        _S244 = true;
    }
    else
    {
        _S244 = ((wiLocal_5.z) <= 0.0f);
    }
    if(_S244)
    {
        _S244 = true;
    }
    else
    {
        _S244 = !FuzzLobe_HasFuzz_0(this_81);
    }
    if(_S244)
    {
        return vec3<f32>(0.0f);
    }
    var ltc_2 : vec3<f32> = FuzzLobe_Coefficients_0(this_81, this_81.woLocal_0);
    return vec3<f32>(SheenEvalLTC_0(SheenRotate_0(wiLocal_5, vec2<f32>(this_81.woLocal_0.x, - this_81.woLocal_0.y)), ltc_2)) * (vec3<f32>((this_81.presence_1 * ltc_2.z)) * this_81.tint_1);
}

fn FuzzLobe_SheenPdf_0( this_82 : FuzzLobe_0,  wiLocal_6 : vec3<f32>) -> f32
{
    var _S245 : bool;
    if(((this_82.woLocal_0.z) <= 0.0f))
    {
        _S245 = true;
    }
    else
    {
        _S245 = ((wiLocal_6.z) <= 0.0f);
    }
    if(_S245)
    {
        _S245 = true;
    }
    else
    {
        _S245 = !FuzzLobe_HasFuzz_0(this_82);
    }
    if(_S245)
    {
        return 0.0f;
    }
    return SheenEvalLTC_0(SheenRotate_0(wiLocal_6, vec2<f32>(this_82.woLocal_0.x, - this_82.woLocal_0.y)), FuzzLobe_Coefficients_0(this_82, this_82.woLocal_0));
}

fn FuzzLobe_EvalPdf_0( this_83 : FuzzLobe_0,  wo_40 : vec3<f32>,  wi_36 : vec3<f32>,  sampled_5 : SampledLobe_0,  f_9 : ptr<function, DiffuseSpecular_0>,  pdf_7 : ptr<function, f32>)
{
    var baseF_1 : DiffuseSpecular_0;
    var basePdf_1 : f32;
    CoatLobe_EvalPdf_0(this_83.base_4, wo_40, wi_36, sampled_5, &(baseF_1), &(basePdf_1));
    var wiLocal_7 : vec3<f32> = Frame_ToLocal_0(this_83.basis_1, wi_36);
    (*f_9) = x2B_0(x2A_0(baseF_1, FuzzLobe_BaseLayerScaleComplete_0(this_83, wiLocal_7)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_83, wiLocal_7)));
    var _S246 : f32;
    if(FuzzLobe_HasFuzz_0(this_83))
    {
        _S246 = mix(basePdf_1, FuzzLobe_SheenPdf_0(this_83, wiLocal_7), FuzzLobe_SheenProbability_0(this_83, wo_40));
    }
    else
    {
        _S246 = basePdf_1;
    }
    (*pdf_7) = _S246;
    return;
}

fn SampleLayer_0( layer_2 : FuzzLobe_0,  u_22 : vec3<f32>,  wo_41 : vec3<f32>) -> LobeSample_0
{
    var wi_37 : vec3<f32>;
    var type_6 : u32;
    var sampled_6 : SampledLobe_0;
    var _S247 : bool = FuzzLobe_SampleLobe_0(layer_2, u_22, wo_41, &(wi_37), &(type_6), &(sampled_6));
    if(!_S247)
    {
        return LobeSample_Invalid_0();
    }
    var f_10 : DiffuseSpecular_0;
    var pdf_8 : f32;
    FuzzLobe_EvalPdf_0(layer_2, wo_41, wi_37, sampled_6, &(f_10), &(pdf_8));
    if(!(pdf_8 > 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_37, x2A_0(f_10, 1.0f / pdf_8), pdf_8, type_6);
}

fn FuzzLobe_ProportionReflected_0( this_84 : FuzzLobe_0,  directionLocal_1 : vec3<f32>) -> f32
{
    var _S248 : bool;
    if(((directionLocal_1.z) <= 0.0f))
    {
        _S248 = true;
    }
    else
    {
        _S248 = !FuzzLobe_HasFuzz_0(this_84);
    }
    if(_S248)
    {
        return 0.0f;
    }
    return this_84.presence_1 * FuzzLobe_Coefficients_0(this_84, directionLocal_1).z;
}

fn DielectricEnergyReflected_0( ior_5 : f32,  alpha_14 : f32,  cosTheta_8 : f32) -> f32
{
    if(alpha_14 == 0.0f)
    {
        return FresnelDielectric_0(ior_5, cosTheta_8);
    }
    return 1.0f - OpaqueDielectricEnergyComplement_0(ior_5, alpha_14, cosTheta_8);
}

fn CoatLobe_ProportionReflected_0( this_85 : CoatLobe_0,  cosine_2 : f32) -> f32
{
    var _S249 : bool;
    if((cosine_2 > 0.0f))
    {
        _S249 = CoatLobe_HasCoat_0(this_85);
    }
    else
    {
        _S249 = false;
    }
    if(_S249)
    {
        return DielectricEnergyReflected_0(this_85.reflection_0.coefficient_1.eta_2, this_85.reflection_0.distribution_1.isotropicAlpha_0, cosine_2) * this_85.presence_0;
    }
    return 0.0f;
}

fn BaseLobe_LobeEvalPdf_1( this_86 : BaseLobe_0,  index_11 : i32,  wo_42 : vec3<f32>,  wi_38 : vec3<f32>,  f_11 : ptr<function, DiffuseSpecular_0>,  pdf_9 : ptr<function, f32>)
{
    switch(index_11)
    {
    case i32(0):
        {
            (*f_11) = SpecularLobe_Eval_0(this_86.specular_0, wo_42, wi_38);
            (*pdf_9) = SpecularLobe_Pdf_0(this_86.specular_0, wo_42, wi_38);
        }
    case i32(1):
        {
            (*f_11) = DielectricMultipleScatteringLobe_Eval_0(this_86.dielectricMultipleScattering_0, wo_42, wi_38);
            (*pdf_9) = DielectricMultipleScatteringLobe_Pdf_0(this_86.dielectricMultipleScattering_0, wo_42, wi_38);
        }
    case i32(2):
        {
            (*f_11) = MetalMultipleScatteringLobe_Eval_0(this_86.metalMultipleScattering_0, wo_42, wi_38);
            (*pdf_9) = MetalMultipleScatteringLobe_Pdf_0(this_86.metalMultipleScattering_0, wo_42, wi_38);
        }
    case i32(3):
        {
            (*f_11) = DiffuseLobe_Eval_0(this_86.diffuse_0, wo_42, wi_38);
            (*pdf_9) = DiffuseLobe_Pdf_0(this_86.diffuse_0, wo_42, wi_38);
        }
    case i32(4):
        {
            (*f_11) = FlippedLobe_Eval_0(this_86.thinWallSpecularTransmission_0, wo_42, wi_38);
            (*pdf_9) = FlippedLobe_Pdf_0(this_86.thinWallSpecularTransmission_0, wo_42, wi_38);
        }
    default :
        {
            (*f_11) = FlippedLobe_Eval_1(this_86.thinWallDiffuseTransmission_0, wo_42, wi_38);
            (*pdf_9) = FlippedLobe_Pdf_1(this_86.thinWallDiffuseTransmission_0, wo_42, wi_38);
        }
    }
    return;
}

fn BaseLobe_EvalPdf_1( this_87 : BaseLobe_0,  wo_43 : vec3<f32>,  wi_39 : vec3<f32>,  sampled_7 : SampledLobe_0,  f_12 : ptr<function, DiffuseSpecular_0>,  pdf_10 : ptr<function, f32>)
{
    (*f_12) = DiffuseSpecular_Zero_0();
    var i_9 : i32 = i32(0);
    var sum_4 : f32 = 0.0f;
    var totalWeight_4 : f32 = 0.0f;
    loop
    {
        if((i_9 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_87, i_9))
        {
            var lobeF_1 : DiffuseSpecular_0 = sampled_7.f_2;
            var lobePdf_1 : f32 = sampled_7.pdf_0;
            var _S250 : bool;
            if((sampled_7.layer_0) != i32(1))
            {
                _S250 = true;
            }
            else
            {
                _S250 = (sampled_7.lobe_1) != i_9;
            }
            if(_S250)
            {
                BaseLobe_LobeEvalPdf_1(this_87, i_9, wo_43, wi_39, &(lobeF_1), &(lobePdf_1));
            }
            (*f_12) = x2B_0((*f_12), lobeF_1);
            var totalWeight_5 : f32 = totalWeight_4 + this_87.weights_0[i_9];
            sum_4 = sum_4 + this_87.weights_0[i_9] * lobePdf_1;
            totalWeight_4 = totalWeight_5;
        }
        i_9 = i_9 + i32(1);
    }
    if((totalWeight_4 > 0.0f))
    {
        sum_4 = sum_4 / totalWeight_4;
    }
    else
    {
        sum_4 = 0.0f;
    }
    (*pdf_10) = sum_4;
    return;
}

fn CoatLobe_EvalPdf_1( this_88 : CoatLobe_0,  wo_44 : vec3<f32>,  wi_40 : vec3<f32>,  sampled_8 : SampledLobe_0,  f_13 : ptr<function, DiffuseSpecular_0>,  pdf_11 : ptr<function, f32>)
{
    var baseF_2 : DiffuseSpecular_0;
    var basePdf_2 : f32;
    BaseLobe_EvalPdf_1(this_88.base_3, wo_44, wi_40, sampled_8, &(baseF_2), &(basePdf_2));
    if(this_88.inside_0)
    {
        (*f_13) = x2A_1(baseF_2, CoatLobe_PassageColor_0(this_88, - dot(wi_40, this_88.normal_7)));
        (*pdf_11) = basePdf_2;
        return;
    }
    var coatSampled_1 : bool = (sampled_8.layer_0) == i32(2);
    var _S251 : DiffuseSpecular_0;
    if(coatSampled_1)
    {
        _S251 = sampled_8.f_2;
    }
    else
    {
        _S251 = CoatLobe_CoatEval_0(this_88, wo_44, wi_40);
    }
    (*f_13) = CoatLobe_Combine_0(this_88, _S251, baseF_2, wi_40);
    var _S252 : f32;
    if(CoatLobe_HasCoat_0(this_88))
    {
        var _S253 : f32 = basePdf_2;
        if(coatSampled_1)
        {
            _S252 = sampled_8.pdf_0;
        }
        else
        {
            _S252 = MicrofacetReflectionLobe_Pdf_1(this_88.reflection_0, wo_44, wi_40);
        }
        _S252 = mix(_S253, _S252, CoatLobe_ReflectionProbability_0(this_88, wo_44));
    }
    else
    {
        _S252 = basePdf_2;
    }
    (*pdf_11) = _S252;
    return;
}

fn ConstantReflection_EstimateWeightOnGGX_0( this_89 : ConstantReflection_0,  throughput_7 : vec3<f32>,  idotn_10 : f32,  isotropicAlpha_1 : f32) -> f32
{
    return ThroughputWeightedMax_0(throughput_7, this_89.color_2);
}

fn MicrofacetReflectionLobe_EstimateContribution_0( this_90 : MicrofacetReflectionLobe_0,  wo_45 : vec3<f32>,  throughput_8 : vec3<f32>) -> f32
{
    return ConstantReflection_EstimateWeightOnGGX_0(this_90.coefficient_1, throughput_8, dot(wo_45, this_90.normal_6), this_90.distribution_1.isotropicAlpha_0);
}

fn TraceClosest_0( ray_4 : Ray_0) -> HitRecord_0
{
    var hit_4 : HitRecord_0;
    var _S254 : bool = TraceScene_0(ray_4, false, &(hit_4));
    return hit_4;
}

fn TraceClosest_1( ray_5 : Ray_0) -> HitRecord_0
{
    var hit_5 : HitRecord_0;
    var _S255 : bool = TraceScene_1(ray_5, false, &(hit_5));
    return hit_5;
}

fn isfinite_1( x_22 : vec3<f32>) -> vec3<bool>
{
    var result_3 : vec3<bool>;
    var i_10 : i32 = i32(0);
    loop
    {
        if((i_10 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_3[i_10] = isfinite_0(x_22[i_10]);
        i_10 = i_10 + i32(1);
    }
    return result_3;
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
    return MainQueueBase_0() + (gWavefront_0.capacity_0 + u32(3)) / u32(4);
}

fn QueueIndex_0( base_5 : u32,  index_12 : u32) -> u32
{
    return (bitcast<u32>((gAccum_0[base_5 + index_12 / u32(4)][(index_12 & (u32(3)))])));
}

fn WorkBase_0( index_13 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_13;
}

fn Field_0( base_6 : u32,  field_0 : u32) -> u32
{
    return base_6 + field_0 * gWavefront_0.capacity_0;
}

fn Ray_x24init_0( o_9 : vec3<f32>,  d_9 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S256 : Ray_0;
    _S256.origin_0 = o_9;
    _S256.direction_0 = d_9;
    _S256.tMin_0 = 0.0f;
    _S256.tMax_0 = tmax_0;
    return _S256;
}

fn ShadowImpl_0( tid_0 : vec3<u32>)
{
    var sum_5 : vec3<f32>;
    var _S257 : u32 = tid_0.x;
    if((_S257 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_7 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S257));
    var _S258 : u32 = Field_0(base_7, u32(11));
    var info_0 : vec4<f32> = gAccum_0[_S258];
    var mask_0 : u32 = (bitcast<u32>((gAccum_0[_S258].z)));
    if(mask_0 == u32(0))
    {
        return;
    }
    gRayCone_0 = info_0.xy;
    var _S259 : vec3<f32> = vec3<f32>(0.0f);
    var source_0 : u32 = u32(0);
    var sum_6 : vec3<f32> = _S259;
    loop
    {
        if((source_0 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_0 & (((u32(1) << (source_0)))))) == u32(0))
        {
            source_0 = source_0 + u32(1);
            continue;
        }
        var offset_1 : u32 = u32(12) + source_0 * u32(3);
        var origin_1 : vec4<f32> = gAccum_0[Field_0(base_7, offset_1)];
        var direction_1 : vec4<f32> = gAccum_0[Field_0(base_7, offset_1 + u32(1))];
        var _S260 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_7, offset_1 + u32(1))].w))) == u32(0))
        {
            _S260 = true;
        }
        else
        {
            var _S261 : bool = TraceOcclusion_0(Ray_x24init_0(origin_1.xyz, direction_1.xyz, origin_1.w));
            _S260 = !_S261;
        }
        if(_S260)
        {
            sum_5 = sum_6 + gAccum_0[Field_0(base_7, offset_1 + u32(2))].xyz;
        }
        else
        {
            sum_5 = sum_6;
        }
        sum_6 = sum_5;
        source_0 = source_0 + u32(1);
    }
    var contribution_0 : vec3<f32> = gAccum_0[Field_0(base_7, u32(10))].xyz * sum_6;
    var _S262 : f32 = gAccum_0[Field_0(base_7, u32(10))].w;
    if((_S262 > 0.0f))
    {
        sum_5 = min(contribution_0, vec3<f32>(_S262));
    }
    else
    {
        sum_5 = contribution_0;
    }
    var path_0 : vec4<f32> = gAccum_0[base_7];
    var _S263 : vec3<f32> = gAccum_0[base_7].xyz + sum_5;
    path_0.x = _S263.x;
    path_0.y = _S263.y;
    path_0.z = _S263.z;
    gAccum_0[base_7] = path_0;
    gAccum_0[_S258] = vec4<f32>(0.0f);
    return;
}

fn LoadFeedbackState_0( base_8 : u32)
{
    var state_0 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(base_8, u32(7))])));
    gVTRequest_0 = state_0.x;
    gVTRequestCount_0 = state_0.y;
    gVTRandom_0 = state_0.z;
    return;
}

fn StoreFeedbackState_0( base_9 : u32)
{
    gAccum_0[Field_0(base_9, u32(7))] = (bitcast<vec4<f32>>((vec4<u32>(gVTRequest_0, gVTRequestCount_0, gVTRandom_0, u32(0)))));
    return;
}

fn ShadowImpl_1( tid_1 : vec3<u32>)
{
    var sum_7 : vec3<f32>;
    var _S264 : u32 = tid_1.x;
    if((_S264 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_10 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S264));
    var _S265 : u32 = Field_0(base_10, u32(11));
    var info_1 : vec4<f32> = gAccum_0[_S265];
    var mask_1 : u32 = (bitcast<u32>((gAccum_0[_S265].z)));
    if(mask_1 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_10);
    gRayCone_0 = info_1.xy;
    var _S266 : vec3<f32> = vec3<f32>(0.0f);
    var source_1 : u32 = u32(0);
    var sum_8 : vec3<f32> = _S266;
    loop
    {
        if((source_1 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_1 & (((u32(1) << (source_1)))))) == u32(0))
        {
            source_1 = source_1 + u32(1);
            continue;
        }
        var offset_2 : u32 = u32(12) + source_1 * u32(3);
        var origin_2 : vec4<f32> = gAccum_0[Field_0(base_10, offset_2)];
        var direction_2 : vec4<f32> = gAccum_0[Field_0(base_10, offset_2 + u32(1))];
        var _S267 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_10, offset_2 + u32(1))].w))) == u32(0))
        {
            _S267 = true;
        }
        else
        {
            var _S268 : bool = TraceOcclusion_1(Ray_x24init_0(origin_2.xyz, direction_2.xyz, origin_2.w));
            _S267 = !_S268;
        }
        if(_S267)
        {
            sum_7 = sum_8 + gAccum_0[Field_0(base_10, offset_2 + u32(2))].xyz;
        }
        else
        {
            sum_7 = sum_8;
        }
        sum_8 = sum_7;
        source_1 = source_1 + u32(1);
    }
    var contribution_1 : vec3<f32> = gAccum_0[Field_0(base_10, u32(10))].xyz * sum_8;
    var _S269 : f32 = gAccum_0[Field_0(base_10, u32(10))].w;
    if((_S269 > 0.0f))
    {
        sum_7 = min(contribution_1, vec3<f32>(_S269));
    }
    else
    {
        sum_7 = contribution_1;
    }
    var path_1 : vec4<f32> = gAccum_0[base_10];
    var _S270 : vec3<f32> = gAccum_0[base_10].xyz + sum_7;
    path_1.x = _S270.x;
    path_1.y = _S270.y;
    path_1.z = _S270.z;
    gAccum_0[base_10] = path_1;
    gAccum_0[_S265] = vec4<f32>(0.0f);
    StoreFeedbackState_0(base_10);
    return;
}

fn FuzzLobe_Sample_0( this_91 : FuzzLobe_0,  u_23 : vec3<f32>,  wo_46 : vec3<f32>) -> LobeSample_0
{
    return SampleLayer_0(this_91, u_23, wo_46);
}

fn FuzzLobe_EvalPdf_1( this_92 : FuzzLobe_0,  wo_47 : vec3<f32>,  wi_41 : vec3<f32>,  sampled_9 : SampledLobe_0,  f_14 : ptr<function, DiffuseSpecular_0>,  pdf_12 : ptr<function, f32>)
{
    var baseF_3 : DiffuseSpecular_0;
    var basePdf_3 : f32;
    CoatLobe_EvalPdf_1(this_92.base_4, wo_47, wi_41, sampled_9, &(baseF_3), &(basePdf_3));
    var wiLocal_8 : vec3<f32> = Frame_ToLocal_0(this_92.basis_1, wi_41);
    (*f_14) = x2B_0(x2A_0(baseF_3, FuzzLobe_BaseLayerScaleComplete_0(this_92, wiLocal_8)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_92, wiLocal_8)));
    var _S271 : f32;
    if(FuzzLobe_HasFuzz_0(this_92))
    {
        _S271 = mix(basePdf_3, FuzzLobe_SheenPdf_0(this_92, wiLocal_8), FuzzLobe_SheenProbability_0(this_92, wo_47));
    }
    else
    {
        _S271 = basePdf_3;
    }
    (*pdf_12) = _S271;
    return;
}

fn CoatLobe_MaxActiveAlpha_0( this_93 : CoatLobe_0) -> f32
{
    var _S272 : bool;
    if(this_93.inside_0)
    {
        _S272 = true;
    }
    else
    {
        _S272 = !CoatLobe_HasCoat_0(this_93);
    }
    var _S273 : f32;
    if(_S272)
    {
        _S273 = 0.0f;
    }
    else
    {
        _S273 = max(this_93.reflection_0.distribution_1.alpha_0.x, this_93.reflection_0.distribution_1.alpha_0.y);
    }
    return _S273;
}

fn FuzzLobe_x24init_0( base_11 : CoatLobe_0,  normal_8 : vec3<f32>,  wo_48 : vec3<f32>,  roughness_4 : f32,  tint_2 : vec3<f32>,  presence_5 : f32) -> FuzzLobe_0
{
    var _S274 : FuzzLobe_0;
    _S274.base_4 = base_11;
    _S274.alpha_3 = roughness_4;
    _S274.tint_1 = tint_2;
    _S274.presence_1 = presence_5;
    var _S275 : Frame_0 = BasisFromNormal_0(normal_8);
    _S274.basis_1 = _S275;
    var _S276 : vec3<f32> = Frame_ToLocal_0(_S275, wo_48);
    _S274.woLocal_0 = _S276;
    _S274.viewReflected_0 = 0.0f;
    _S274.viewReflected_0 = FuzzLobe_ProportionReflected_0(_S274, _S276);
    return _S274;
}

fn CoatLobe_x24init_0( base_12 : BaseLobe_0,  reflection_2 : MicrofacetReflectionLobe_1,  normal_9 : vec3<f32>,  wo_49 : vec3<f32>,  tint_3 : vec3<f32>,  presence_6 : f32,  extraBaseLayerScale_0 : vec3<f32>,  inside_1 : bool) -> CoatLobe_0
{
    var _S277 : CoatLobe_0;
    _S277.base_3 = base_12;
    _S277.reflection_0 = reflection_2;
    _S277.normal_7 = normal_9;
    _S277.tint_0 = tint_3;
    _S277.presence_0 = presence_6;
    _S277.inside_0 = inside_1;
    var idotn_11 : f32 = dot(wo_49, normal_9);
    var _S278 : f32 = CoatLobe_ProportionReflected_0(_S277, idotn_11);
    _S277.inReflected_0 = _S278;
    _S277.inBaseLayerScale_0 = CoatLobe_BaseLayerScaleOneSide_0(_S277, idotn_11, _S278) * extraBaseLayerScale_0;
    return _S277;
}

fn MicrofacetReflectionLobe_x24init_0( normal_10 : vec3<f32>,  distribution_2 : GGXDistribution_0,  coefficient_2 : DielectricReflection_0) -> MicrofacetReflectionLobe_1
{
    var _S279 : MicrofacetReflectionLobe_1;
    _S279.normal_6 = normal_10;
    _S279.distribution_1 = distribution_2;
    _S279.coefficient_1 = coefficient_2;
    return _S279;
}

fn DiffuseLobe_EstimateContribution_0( this_94 : DiffuseLobe_0,  wo_50 : vec3<f32>,  throughput_9 : vec3<f32>) -> f32
{
    return ThroughputWeightedMax_0(throughput_9, this_94.albedo_0 * vec3<f32>(this_94.specularCompensation_0));
}

fn FlippedLobe_EstimateContribution_0( this_95 : FlippedLobe_1,  wo_51 : vec3<f32>,  throughput_10 : vec3<f32>) -> f32
{
    return DiffuseLobe_EstimateContribution_0(this_95.lobe_0, reflect(wo_51, DiffuseLobe_GetNormal_0(this_95.lobe_0)), throughput_10);
}

fn FlippedLobe_EstimateContribution_1( this_96 : FlippedLobe_0,  wo_52 : vec3<f32>,  throughput_11 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_EstimateContribution_0(this_96.lobe_0, reflect(wo_52, MicrofacetReflectionLobe_GetNormal_0(this_96.lobe_0)), throughput_11);
}

fn FlippedLobe_x24init_0( lobe_3 : DiffuseLobe_0) -> FlippedLobe_1
{
    var _S280 : FlippedLobe_1;
    _S280.lobe_0 = lobe_3;
    return _S280;
}

fn FlippedLobe_x24init_1( lobe_4 : MicrofacetReflectionLobe_0) -> FlippedLobe_0
{
    var _S281 : FlippedLobe_0;
    _S281.lobe_0 = lobe_4;
    return _S281;
}

fn MicrofacetReflectionLobe_x24init_1( normal_11 : vec3<f32>,  distribution_3 : GGXDistribution_0,  coefficient_3 : ConstantReflection_0) -> MicrofacetReflectionLobe_0
{
    var _S282 : MicrofacetReflectionLobe_0;
    _S282.normal_6 = normal_11;
    _S282.distribution_1 = distribution_3;
    _S282.coefficient_1 = coefficient_3;
    return _S282;
}

fn Bitangent_0( tangent_3 : vec4<f32>,  n_8 : vec3<f32>) -> vec3<f32>
{
    var _S283 : f32 = tangent_3.w;
    var _S284 : bool;
    if(_S283 == 0.0f)
    {
        _S284 = true;
    }
    else
    {
        var _S285 : vec3<f32> = tangent_3.xyz;
        _S284 = (dot(_S285, _S285)) == 0.0f;
    }
    if(_S284)
    {
        return vec3<f32>(0.0f);
    }
    var _S286 : vec3<f32> = tangent_3.xyz;
    return cross(n_8, normalize(_S286 - n_8 * vec3<f32>(dot(_S286, n_8)))) * vec3<f32>(_S283);
}

fn ApplyNormalMap_0( tangent_4 : vec4<f32>,  n_9 : vec3<f32>,  texel_0 : vec3<f32>,  scale_3 : f32) -> vec3<f32>
{
    var _S287 : f32 = tangent_4.w;
    var _S288 : bool;
    if(_S287 == 0.0f)
    {
        _S288 = true;
    }
    else
    {
        var _S289 : vec3<f32> = tangent_4.xyz;
        _S288 = (dot(_S289, _S289)) == 0.0f;
    }
    if(_S288)
    {
        return n_9;
    }
    var _S290 : vec2<f32> = (texel_0.xy * vec2<f32>(2.0f) - vec2<f32>(1.0f)) * vec2<f32>(scale_3);
    var local_1 : vec3<f32>;
    local_1.x = _S290.x;
    local_1.y = _S290.y;
    var _S291 : f32 = texel_0.z;
    var _S292 : f32;
    if((_S291 <= 0.0f))
    {
        _S292 = sqrt(saturate(1.0f - dot(local_1.xy, local_1.xy)));
    }
    else
    {
        _S292 = abs(_S291 * 2.0f - 1.0f);
    }
    local_1[i32(2)] = _S292;
    if((dot(local_1, local_1)) == 0.0f)
    {
        return n_9;
    }
    var _S293 : vec3<f32> = normalize(local_1);
    local_1 = _S293;
    var _S294 : vec3<f32> = tangent_4.xyz;
    var t_8 : vec3<f32> = normalize(_S294 - n_9 * vec3<f32>(dot(_S294, n_9)));
    return normalize(t_8 * vec3<f32>(_S293.x) + cross(n_9, t_8) * vec3<f32>(_S287) * vec3<f32>(_S293.y) + n_9 * vec3<f32>(_S293.z));
}

fn RunMaterialProgram_1( header_4 : MaterialHeader_0,  program_2 : u32,  ctx_4 : MaterialContext_0,  outputs_1 : ptr<function, MaterialOutputs_0>)
{
    var stack_5 : array<vec4<f32>, i32(16)>;
    var n_10 : u32 = u32(0);
    var pc_2 : u32 = program_2;
    loop
    {
        if((n_10 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var ins_1 : vec4<u32> = gMaterialData_0[pc_2];
        var _S295 : u32 = ins_1.x;
        var op_1 : u32 = (_S295 & (u32(255)));
        var dst_1 : u32 = (((_S295 >> (u32(8)))) & (u32(15)));
        var imm_1 : u32 = (_S295 >> (u32(16)));
        if(op_1 == u32(0))
        {
            return;
        }
        var _S296 : u32 = ins_1.y;
        var a_14 : vec4<f32> = MaterialOperand_0(_S296, stack_5[(_S296 & (u32(15)))], header_4.constantBase_0);
        var _S297 : u32 = ins_1.z;
        var b_10 : vec4<f32> = MaterialOperand_0(_S297, stack_5[(_S297 & (u32(15)))], header_4.constantBase_0);
        var _S298 : u32 = ins_1.w;
        var c_11 : vec4<f32> = MaterialOperand_0(_S298, stack_5[(_S298 & (u32(15)))], header_4.constantBase_0);
        var operands_1 : u32 = pc_2 * u32(4) + u32(1);
        var _S299 : u32;
        if(op_1 == u32(23))
        {
            _S299 = (((u32(351898) >> ((u32(2) * min(imm_1, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_1 == u32(17))
            {
                _S299 = u32(1) + imm_1 / u32(4);
            }
            else
            {
                _S299 = u32(1);
            }
        }
        var pc_3 : u32 = pc_2 + _S299;
        var _S300 : vec4<f32> = vec4<f32>(0.0f);
        var r_7 : vec4<f32> = _S300;
        var _S301 : vec4<f32>;
        var write_1 : bool;
        switch(op_1)
        {
        case u32(1):
            {
                r_7 = a_14 + b_10;
                write_1 = true;
            }
        case u32(2):
            {
                r_7 = a_14 - b_10;
                write_1 = true;
            }
        case u32(3):
            {
                r_7 = a_14 * b_10;
                write_1 = true;
            }
        case u32(4):
            {
                r_7 = a_14 / b_10;
                write_1 = true;
            }
        case u32(5):
            {
                r_7 = min(a_14, b_10);
                write_1 = true;
            }
        case u32(6):
            {
                r_7 = max(a_14, b_10);
                write_1 = true;
            }
        case u32(7):
            {
                r_7 = pow(a_14, b_10);
                write_1 = true;
            }
        case u32(8):
            {
                r_7 = atan2(a_14, b_10);
                write_1 = true;
            }
        case u32(9):
            {
                r_7 = sqrt(a_14);
                write_1 = true;
            }
        case u32(10):
            {
                r_7 = sin(a_14);
                write_1 = true;
            }
        case u32(11):
            {
                r_7 = cos(a_14);
                write_1 = true;
            }
        case u32(12):
            {
                r_7 = abs(a_14);
                write_1 = true;
            }
        case u32(13):
            {
                r_7 = min(max(a_14, b_10), c_11);
                write_1 = true;
            }
        case u32(14):
            {
                r_7 = mix(a_14, b_10, c_11);
                write_1 = true;
            }
        case u32(15):
            {
                r_7 = vec4<f32>(a_14[min(imm_1, u32(3))]);
                write_1 = true;
            }
        case u32(16):
            {
                r_7 = select(vec4<f32>(f32((imm_1 >> (u32(8))))), a_14, LanesBelow_0((imm_1 & (u32(255)))));
                write_1 = true;
            }
        case u32(17):
            {
                r_7 = vec4<f32>(a_14.x, b_10.x, c_11.x, 0.0f);
                if((imm_1 > u32(3)))
                {
                    var o_10 : u32 = MaterialWord_0(operands_1 + u32(3));
                    r_7[i32(3)] = MaterialOperand_0(o_10, stack_5[(o_10 & (u32(15)))], header_4.constantBase_0).x;
                }
                write_1 = true;
            }
        case u32(18):
            {
                var lanes_1 : vec4<bool> = LanesBelow_0(imm_1);
                r_7 = vec4<f32>(dot(select(_S300, a_14, lanes_1), select(_S300, b_10, lanes_1)));
                write_1 = true;
            }
        case u32(19):
            {
                var len_1 : f32 = length(select(_S300, a_14, LanesBelow_0(imm_1)));
                if((len_1 > 0.0f))
                {
                    _S301 = a_14 / vec4<f32>(len_1);
                }
                else
                {
                    _S301 = _S300;
                }
                r_7 = _S301;
                write_1 = true;
            }
        case u32(20):
            {
                if(imm_1 == u32(0))
                {
                    r_7 = vec4<f32>(ctx_4.tex_0.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_1 == u32(1))
                    {
                        r_7 = vec4<f32>(ctx_4.tex_0.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_1 == u32(6))
                        {
                            r_7 = vec4<f32>(ctx_4.tex_0.objectPosition_0, 0.0f);
                        }
                        else
                        {
                            if(imm_1 == u32(2))
                            {
                                r_7 = vec4<f32>(ctx_4.position_0, 0.0f);
                            }
                            else
                            {
                                if(imm_1 == u32(3))
                                {
                                    r_7 = vec4<f32>(ctx_4.normal_1, 0.0f);
                                }
                                else
                                {
                                    if(imm_1 == u32(4))
                                    {
                                        r_7 = ctx_4.tangent_2;
                                    }
                                    else
                                    {
                                        r_7 = vec4<f32>(Bitangent_0(ctx_4.tangent_2, ctx_4.normal_1), 0.0f);
                                    }
                                }
                            }
                        }
                    }
                }
                write_1 = true;
            }
        case u32(21):
            {
                var ref_9 : TextureRef_0 = LoadTextureRef_0(header_4, imm_1);
                if(HasTexture_0(ref_9))
                {
                    var _S302 : vec4<f32> = SampleTexture_0(ref_9, ctx_4.tex_0);
                    _S301 = _S302;
                }
                else
                {
                    _S301 = vec4<f32>(1.0f);
                }
                r_7 = _S301;
                write_1 = true;
            }
        case u32(22):
            {
                r_7 = vec4<f32>(ApplyNormalMap_0(ctx_4.tangent_2, ctx_4.normal_1, a_14.xyz, b_10.x), 0.0f);
                write_1 = true;
            }
        case u32(24):
            {
                r_7 = floor(a_14);
                write_1 = true;
            }
        case u32(25):
            {
                r_7 = vec4<f32>((vec4<i32>(sign((a_14)))));
                write_1 = true;
            }
        case u32(26):
            {
                r_7 = exp(a_14);
                write_1 = true;
            }
        case u32(27):
            {
                r_7 = log(a_14);
                write_1 = true;
            }
        case u32(28):
            {
                r_7 = a_14 - b_10 * floor(a_14 / b_10);
                write_1 = true;
            }
        case u32(29):
            {
                r_7 = select(_S300, vec4<f32>(1.0f), (a_14 > b_10));
                write_1 = true;
            }
        case u32(30):
            {
                r_7 = vec4<f32>(cross(a_14.xyz, b_10.xyz), 0.0f);
                write_1 = true;
            }
        case u32(31):
            {
                var _S303 : vec3<f32>;
                if(imm_1 == u32(1))
                {
                    _S303 = TransformVector_0(ctx_4.instanceIndex_2, a_14.xyz);
                }
                else
                {
                    _S303 = InverseTransformVector_0(ctx_4.instanceIndex_2, a_14.xyz);
                }
                r_7 = vec4<f32>(_S303, 0.0f);
                write_1 = true;
            }
        case u32(32):
            {
                var _S304 : bool = ((imm_1 & (u32(2)))) != u32(0);
                var v_13 : vec3<f32> = BlenderNoise_0(a_14.xyz, b_10, ((imm_1 & (u32(1)))) != u32(0), _S304);
                if(_S304)
                {
                    _S301 = vec4<f32>(v_13, 0.0f);
                }
                else
                {
                    _S301 = vec4<f32>(v_13.x);
                }
                r_7 = _S301;
                write_1 = true;
            }
        case u32(33):
            {
                var c_12 : vec3<f32> = BlenderMagic_0(a_14.xyz, imm_1, b_10.x);
                r_7 = vec4<f32>(c_12, (c_12.x + c_12.y + c_12.z) / 3.0f);
                write_1 = true;
            }
        case u32(34):
            {
                r_7 = vec4<f32>(BlenderChecker_0(a_14.xyz));
                write_1 = true;
            }
        case u32(23):
            {
                switch(imm_1)
                {
                case u32(0):
                    {
                        var o_11 : u32 = MaterialWord_0(operands_1);
                        if(o_11 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.baseWeight_0 = MaterialOperand_0(o_11, stack_5[(o_11 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_12 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_12 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.baseColor_0 = MaterialOperand_0(o_12, stack_5[(o_12 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_13 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_13 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.baseDiffuseRoughness_0 = MaterialOperand_0(o_13, stack_5[(o_13 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_14 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_14 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.baseMetalness_0 = MaterialOperand_0(o_14, stack_5[(o_14 & (u32(15)))], header_4.constantBase_0).x;
                        }
                    }
                case u32(1):
                    {
                        var o_15 : u32 = MaterialWord_0(operands_1);
                        if(o_15 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularWeight_0 = MaterialOperand_0(o_15, stack_5[(o_15 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_16 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_16 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularColor_0 = MaterialOperand_0(o_16, stack_5[(o_16 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_17 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_17 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularRoughness_0 = MaterialOperand_0(o_17, stack_5[(o_17 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_18 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_18 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularIor_0 = MaterialOperand_0(o_18, stack_5[(o_18 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_19 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_19 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularDielectricOnly_0 = (MaterialOperand_0(o_19, stack_5[(o_19 & (u32(15)))], header_4.constantBase_0).x) != 0.0f;
                        }
                    }
                case u32(2):
                    {
                        var o_20 : u32 = MaterialWord_0(operands_1);
                        if(o_20 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.specularRoughnessAnisotropy_0 = MaterialOperand_0(o_20, stack_5[(o_20 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_21 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_21 != u32(4294967295))
                        {
                            (*outputs_1).tangent_1 = MaterialOperand_0(o_21, stack_5[(o_21 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                    }
                case u32(3):
                    {
                        var o_22 : u32 = MaterialWord_0(operands_1);
                        if(o_22 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionWeight_0 = MaterialOperand_0(o_22, stack_5[(o_22 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_23 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_23 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionColor_0 = MaterialOperand_0(o_23, stack_5[(o_23 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_24 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_24 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionDepth_0 = MaterialOperand_0(o_24, stack_5[(o_24 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_25 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_25 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionScatter_0 = MaterialOperand_0(o_25, stack_5[(o_25 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_26 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_26 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionScatterAnisotropy_0 = MaterialOperand_0(o_26, stack_5[(o_26 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_27 : u32 = MaterialWord_0(operands_1 + u32(5));
                        if(o_27 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionDispersionScale_0 = MaterialOperand_0(o_27, stack_5[(o_27 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_28 : u32 = MaterialWord_0(operands_1 + u32(6));
                        if(o_28 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.transmissionDispersionAbbeNumber_0 = MaterialOperand_0(o_28, stack_5[(o_28 & (u32(15)))], header_4.constantBase_0).x;
                        }
                    }
                case u32(4):
                    {
                        var o_29 : u32 = MaterialWord_0(operands_1);
                        if(o_29 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.subsurfaceWeight_0 = MaterialOperand_0(o_29, stack_5[(o_29 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_30 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_30 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.subsurfaceColor_0 = MaterialOperand_0(o_30, stack_5[(o_30 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_31 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_31 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.subsurfaceRadius_0 = MaterialOperand_0(o_31, stack_5[(o_31 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_32 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_32 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.subsurfaceRadiusScale_0 = MaterialOperand_0(o_32, stack_5[(o_32 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_33 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_33 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.subsurfaceScatterAnisotropy_0 = MaterialOperand_0(o_33, stack_5[(o_33 & (u32(15)))], header_4.constantBase_0).x;
                        }
                    }
                case u32(5):
                    {
                        var o_34 : u32 = MaterialWord_0(operands_1);
                        if(o_34 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatWeight_0 = MaterialOperand_0(o_34, stack_5[(o_34 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_35 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_35 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatColor_0 = MaterialOperand_0(o_35, stack_5[(o_35 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_36 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_36 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatRoughness_0 = MaterialOperand_0(o_36, stack_5[(o_36 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_37 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_37 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatRoughnessAnisotropy_0 = MaterialOperand_0(o_37, stack_5[(o_37 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_38 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_38 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatIor_0 = MaterialOperand_0(o_38, stack_5[(o_38 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_39 : u32 = MaterialWord_0(operands_1 + u32(5));
                        if(o_39 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.coatDarkening_0 = MaterialOperand_0(o_39, stack_5[(o_39 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_40 : u32 = MaterialWord_0(operands_1 + u32(6));
                        if(o_40 != u32(4294967295))
                        {
                            (*outputs_1).coatNormal_0 = MaterialOperand_0(o_40, stack_5[(o_40 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_41 : u32 = MaterialWord_0(operands_1 + u32(7));
                        if(o_41 != u32(4294967295))
                        {
                            (*outputs_1).coatTangent_0 = MaterialOperand_0(o_41, stack_5[(o_41 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                    }
                case u32(6):
                    {
                        var o_42 : u32 = MaterialWord_0(operands_1);
                        if(o_42 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.fuzzWeight_0 = MaterialOperand_0(o_42, stack_5[(o_42 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_43 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_43 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.fuzzColor_0 = MaterialOperand_0(o_43, stack_5[(o_43 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                        var o_44 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_44 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.fuzzRoughness_0 = MaterialOperand_0(o_44, stack_5[(o_44 & (u32(15)))], header_4.constantBase_0).x;
                        }
                    }
                case u32(7):
                    {
                        var o_45 : u32 = MaterialWord_0(operands_1);
                        if(o_45 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.thinFilmWeight_0 = MaterialOperand_0(o_45, stack_5[(o_45 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_46 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_46 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.thinFilmThickness_0 = MaterialOperand_0(o_46, stack_5[(o_46 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_47 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_47 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.thinFilmIor_0 = MaterialOperand_0(o_47, stack_5[(o_47 & (u32(15)))], header_4.constantBase_0).x;
                        }
                    }
                case u32(8):
                    {
                        var o_48 : u32 = MaterialWord_0(operands_1);
                        if(o_48 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_48, stack_5[(o_48 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_49 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_49 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.emissionColor_0 = MaterialOperand_0(o_49, stack_5[(o_49 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_50 : u32 = MaterialWord_0(operands_1);
                        if(o_50 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_50, stack_5[(o_50 & (u32(15)))], header_4.constantBase_0).x;
                        }
                        var o_51 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_51 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_51, stack_5[(o_51 & (u32(15)))], header_4.constantBase_0).x) != 0.0f;
                        }
                        var o_52 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_52 != u32(4294967295))
                        {
                            (*outputs_1).normal_0 = MaterialOperand_0(o_52, stack_5[(o_52 & (u32(15)))], header_4.constantBase_0).xyz;
                        }
                    }
                }
                write_1 = false;
            }
        default :
            {
                write_1 = true;
            }
        }
        if(write_1)
        {
            stack_5[dst_1] = r_7;
        }
        n_10 = n_10 + u32(1);
        pc_2 = pc_3;
    }
    return;
}

struct PathState_0
{
     radiance_0 : vec3<f32>,
     throughput_12 : vec3<f32>,
     origin_3 : vec3<f32>,
     direction_3 : vec3<f32>,
     scatterPdf_0 : f32,
     lobe_5 : u32,
     coneWidth_2 : f32,
     coneSpread_0 : f32,
     absorption_0 : vec3<f32>,
     lightsSampled_0 : bool,
};

struct WavefrontPath_0
{
     path_2 : PathState_0,
     active_0 : u32,
     randomSeed_0 : u32,
     albedo_1 : vec3<f32>,
     normal_12 : vec3<f32>,
};

fn LoadPath_0( base_13 : u32) -> WavefrontPath_0
{
    var s_14 : WavefrontPath_0;
    s_14.path_2.radiance_0 = gAccum_0[base_13].xyz;
    s_14.active_0 = (bitcast<u32>((gAccum_0[base_13].w)));
    s_14.path_2.throughput_12 = gAccum_0[Field_0(base_13, u32(1))].xyz;
    s_14.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_13, u32(1))].w)));
    s_14.path_2.origin_3 = gAccum_0[Field_0(base_13, u32(2))].xyz;
    s_14.path_2.scatterPdf_0 = gAccum_0[Field_0(base_13, u32(2))].w;
    s_14.path_2.direction_3 = gAccum_0[Field_0(base_13, u32(3))].xyz;
    s_14.path_2.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_13, u32(3))].w))) != u32(0);
    s_14.path_2.absorption_0 = gAccum_0[Field_0(base_13, u32(4))].xyz;
    s_14.path_2.coneWidth_2 = gAccum_0[Field_0(base_13, u32(4))].w;
    s_14.albedo_1 = gAccum_0[Field_0(base_13, u32(5))].xyz;
    s_14.path_2.coneSpread_0 = gAccum_0[Field_0(base_13, u32(5))].w;
    s_14.normal_12 = gAccum_0[Field_0(base_13, u32(6))].xyz;
    s_14.path_2.lobe_5 = u32(0);
    return s_14;
}

fn AnalyticLightCount_0() -> u32
{
    return gFrame_0.counts_0.w;
}

fn HitRecord_IsHit_0( this_97 : HitRecord_0) -> bool
{
    return (this_97.instanceIndex_0) != u32(4294967295);
}

fn AnalyticFlags_0( light_0 : ptr<function, EmissiveTriangle_std430_0>) -> u32
{
    return (bitcast<u32>(((*light_0).n_0.w)));
}

fn rsqrt_0( x_23 : f32) -> f32
{
    return 1.0f / sqrt(x_23);
}

fn SpotAttenuation_0( light_1 : ptr<function, EmissiveTriangle_std430_0>,  dir_0 : vec3<f32>) -> f32
{
    var _S305 : u32 = AnalyticFlags_0(&((*light_1)));
    if(((_S305 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_24 : f32 = dot(dir_0, (*light_1).p2_0.xyz) - (*light_1).uvA_0.w;
    var scale_4 : f32 = (*light_1).uvB_0.x;
    var _S306 : f32;
    if((scale_4 > 0.0f))
    {
        _S306 = smoothstep(0.0f, 1.0f, x_24 * scale_4);
    }
    else
    {
        if((x_24 > 0.0f))
        {
            _S306 = 1.0f;
        }
        else
        {
            _S306 = 0.0f;
        }
    }
    return _S306;
}

fn SphereOneMinusCos_0( radius_1 : f32,  distSq_0 : f32) -> f32
{
    var sinSq_0 : f32 = radius_1 * radius_1 / distSq_0;
    var _S307 : f32;
    if((sinSq_0 < 1.0f))
    {
        _S307 = sinSq_0 / (1.0f + sqrt(1.0f - sinSq_0));
    }
    else
    {
        _S307 = 0.0f;
    }
    return _S307;
}

fn IntersectAnalyticLights_0( origin_4 : vec3<f32>,  dir_1 : vec3<f32>,  tMax_3 : f32,  cameraRay_0 : bool,  radiance_1 : ptr<function, vec3<f32>>,  pdf_13 : ptr<function, f32>) -> bool
{
    (*radiance_1) = vec3<f32>(0.0f);
    (*pdf_13) = 0.0f;
    var nearest_0 : f32 = tMax_3;
    var found_8 : bool = false;
    var i_11 : u32 = u32(0);
    loop
    {
        if((i_11 < (AnalyticLightCount_0())))
        {
        }
        else
        {
            break;
        }
        var _S308 : EmissiveTriangle_std430_0 = gLights_0[i_11];
        var _S309 : u32 = AnalyticFlags_0(&(_S308));
        var _S310 : bool;
        if(cameraRay_0)
        {
            _S310 = ((_S309 & (u32(256)))) != u32(0);
        }
        else
        {
            _S310 = false;
        }
        if(_S310)
        {
            i_11 = i_11 + u32(1);
            continue;
        }
        var nearest_1 : f32;
        var _S311 : bool;
        var inside_2 : bool;
        if(((_S309 & (u32(255)))) == u32(2))
        {
            var n_11 : vec3<f32> = _S308.p2_0.xyz;
            var cosTheta_9 : f32 = - dot(n_11, dir_1);
            if((cosTheta_9 <= 9.99999997475242708e-07f))
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            var _S312 : vec4<f32> = _S308.p0_0;
            var _S313 : vec3<f32> = _S308.p0_0.xyz;
            var t_9 : f32 = dot(_S313 - origin_4, n_11) / - cosTheta_9;
            if((t_9 <= 0.0f))
            {
                _S311 = true;
            }
            else
            {
                _S311 = (t_9 >= nearest_0);
            }
            if(_S311)
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            var local_2 : vec3<f32> = origin_4 + dir_1 * vec3<f32>(t_9) - _S313;
            var _S314 : vec3<f32> = _S308.n_0.xyz;
            var _S315 : vec3<f32> = _S308.uvA_0.xyz;
            var d_10 : vec2<f32> = vec2<f32>(dot(local_2, _S314) / dot(_S314, _S314), dot(local_2, _S315) / dot(_S315, _S315));
            if(((_S309 & (u32(512)))) != u32(0))
            {
                inside_2 = ((dot(d_10, d_10)) <= 0.25f);
            }
            else
            {
                inside_2 = (all((((abs(d_10)) <= vec2<f32>(0.5f)))));
            }
            if(!inside_2)
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            (*radiance_1) = _S308.p1_0.xyz;
            (*pdf_13) = _S308.p1_0.w * t_9 * t_9 / (cosTheta_9 * _S312.w);
            nearest_1 = t_9;
        }
        else
        {
            var _S316 : vec4<f32> = _S308.p0_0;
            var radius_2 : f32 = _S308.p0_0.w;
            if((radius_2 <= 0.0f))
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            var toCenter_0 : vec3<f32> = _S316.xyz - origin_4;
            var distSq_1 : f32 = dot(toCenter_0, toCenter_0);
            var tc_5 : f32 = dot(toCenter_0, dir_1);
            var _S317 : f32 = radius_2 * radius_2;
            var h_14 : f32 = _S317 - (distSq_1 - tc_5 * tc_5);
            if((h_14 < 0.0f))
            {
                _S311 = true;
            }
            else
            {
                _S311 = (distSq_1 <= _S317);
            }
            if(_S311)
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            var t_10 : f32 = tc_5 - sqrt(h_14);
            if((t_10 <= 0.0f))
            {
                inside_2 = true;
            }
            else
            {
                inside_2 = (t_10 >= nearest_0);
            }
            if(inside_2)
            {
                i_11 = i_11 + u32(1);
                continue;
            }
            var _S318 : vec4<f32> = _S308.p1_0;
            var _S319 : vec3<f32> = _S308.p1_0.xyz;
            var _S320 : f32 = SpotAttenuation_0(&(_S308), (vec3<f32>(0) - toCenter_0) * vec3<f32>(rsqrt_0(distSq_1)));
            (*radiance_1) = _S319 * vec3<f32>(_S320);
            (*pdf_13) = _S318.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_2, distSq_1));
            nearest_1 = t_10;
        }
        nearest_0 = nearest_1;
        found_8 = true;
        i_11 = i_11 + u32(1);
    }
    return found_8;
}

fn EvalMISRobust_0( pdf_14 : f32,  otherPdf_0 : f32) -> f32
{
    if(pdf_14 == otherPdf_0)
    {
        return 0.5f;
    }
    if((otherPdf_0 < pdf_14))
    {
        var x_25 : f32 = otherPdf_0 / pdf_14;
        return 1.0f / (1.0f + x_25 * x_25);
    }
    var x_26 : f32 = pdf_14 / otherPdf_0;
    return 1.0f - 1.0f / (1.0f + x_26 * x_26);
}

fn EnvironmentEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(1)))) != u32(0);
}

fn RotateY_0( v_14 : vec3<f32>,  angle_1 : f32) -> vec3<f32>
{
    var s_15 : f32 = sin(angle_1);
    var c_13 : f32 = cos(angle_1);
    var _S321 : f32 = v_14.x;
    var _S322 : f32 = v_14.z;
    return vec3<f32>(c_13 * _S321 + s_15 * _S322, v_14.y, - s_15 * _S321 + c_13 * _S322);
}

fn DirectionToEquirectUV_0( dir_2 : vec3<f32>) -> vec2<f32>
{
    var _S323 : f32 = dir_2.y;
    var elevation_0 : f32 = asin(clamp(_S323, -1.0f, 1.0f));
    var azimuth_1 : f32;
    if(((abs(_S323)) < 1.0f))
    {
        azimuth_1 = atan2(dir_2.z, dir_2.x);
    }
    else
    {
        azimuth_1 = 0.0f;
    }
    var PI_2 : f32 = float_getPi_0();
    return vec2<f32>(azimuth_1 * (0.5f / PI_2) - 0.25f, 0.5f - elevation_0 * (1.0f / PI_2));
}

fn EvalEnvironment_0( dir_3 : vec3<f32>) -> vec3<f32>
{
    if(!EnvironmentEnabled_0())
    {
        return vec3<f32>(0.0f);
    }
    return (textureSampleLevel((gEnvMap_0), (gLinearSampler_0), (DirectionToEquirectUV_0(RotateY_0(dir_3, - gFrame_0.envParams_0.y))), (0.0f))).xyz * vec3<f32>(gFrame_0.envParams_0.x);
}

fn SunEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(2)))) != u32(0);
}

fn HitsSun_0( dir_4 : vec3<f32>) -> bool
{
    var _S324 : bool;
    if(SunEnabled_0())
    {
        _S324 = ((dot(dir_4, gFrame_0.sunDirection_0.xyz)) >= (gFrame_0.sunDirection_0.w));
    }
    else
    {
        _S324 = false;
    }
    return _S324;
}

fn EnvCdf_0( x_27 : u32,  y_10 : u32) -> f32
{
    var _S325 : vec3<i32> = vec3<i32>(i32(x_27), i32(y_10), i32(0));
    return (textureLoad((gEnvCdf_0), ((_S325)).xy, ((_S325)).z).x);
}

fn EnvironmentPdf_0( dir_5 : vec3<f32>) -> f32
{
    if(!EnvironmentEnabled_0())
    {
        return 0.0f;
    }
    if((((gFrame_0.settings_0.z) & (u32(4)))) == u32(0))
    {
        return 1.0f / (4.0f * float_getPi_0());
    }
    var W_0 : u32 = gFrame_0.envInfo_0.x;
    var H_0 : u32 = gFrame_0.envInfo_0.y;
    var local_3 : vec3<f32> = RotateY_0(dir_5, - gFrame_0.envParams_0.y);
    var uv_3 : vec2<f32> = fract(DirectionToEquirectUV_0(local_3));
    var _S326 : f32 = f32(W_0);
    var _S327 : u32 = min(u32(uv_3.x * _S326), W_0 - u32(1));
    var _S328 : f32 = f32(H_0);
    var _S329 : u32 = min(u32(uv_3.y * _S328), H_0 - u32(1));
    var _S330 : f32 = local_3.y;
    var PI_3 : f32 = float_getPi_0();
    return (EnvCdf_0(_S327 + u32(1), _S329) - EnvCdf_0(_S327, _S329)) * _S326 * ((EnvCdf_0(_S329 + u32(1), H_0) - EnvCdf_0(_S329, H_0)) * _S328) / (2.0f * PI_3 * PI_3 * sqrt(clamp(1.0f - _S330 * _S330, 9.99999997475242708e-07f, 1.0f)));
}

fn IntersectImpl_0( tid_2 : vec3<u32>)
{
    var _S331 : u32 = tid_2.x;
    if((_S331 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_14 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S331));
    var s_16 : WavefrontPath_0 = LoadPath_0(base_14);
    if((s_16.active_0) == u32(0))
    {
        return;
    }
    gRayCone_0 = vec2<f32>(s_16.path_2.coneWidth_2, s_16.path_2.coneSpread_0);
    var ray_6 : Ray_0 = Ray_x24init_0(s_16.path_2.origin_3, s_16.path_2.direction_3, 1.00000001504746622e+30f);
    var hit_6 : HitRecord_0 = TraceClosest_0(ray_6);
    var clampValue_0 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var bounce_1 : u32 = gWavefront_0.bounce_0;
    var mis_0 : f32;
    var _S332 : bool;
    var contribution_2 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_2 : vec3<f32>;
        var pdf_15 : f32;
        if(HitRecord_IsHit_0(hit_6))
        {
            mis_0 = hit_6.t_0;
        }
        else
        {
            mis_0 = 1.00000001504746622e+30f;
        }
        var _S333 : bool = IntersectAnalyticLights_0(ray_6.origin_0, ray_6.direction_0, mis_0, bounce_1 == u32(0), &(radiance_2), &(pdf_15));
        if(_S333)
        {
            var _S334 : bool = (bounce_1 > u32(0));
            if(_S334)
            {
                _S332 = s_16.path_2.lightsSampled_0;
            }
            else
            {
                _S332 = false;
            }
            if(_S332)
            {
                mis_0 = EvalMISRobust_0(s_16.path_2.scatterPdf_0, pdf_15);
            }
            else
            {
                mis_0 = 1.0f;
            }
            var contribution_3 : vec3<f32> = s_16.path_2.throughput_12 * vec3<f32>(mis_0) * radiance_2;
            if((clampValue_0 > 0.0f))
            {
                _S332 = _S334;
            }
            else
            {
                _S332 = false;
            }
            if(_S332)
            {
                contribution_2 = min(contribution_3, vec3<f32>(clampValue_0));
            }
            else
            {
                contribution_2 = contribution_3;
            }
            s_16.path_2.radiance_0 = s_16.path_2.radiance_0 + contribution_2;
        }
    }
    if(!HitRecord_IsHit_0(hit_6))
    {
        if(bounce_1 == u32(0))
        {
            var visible_0 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_0)
            {
                contribution_2 = EvalEnvironment_0(ray_6.direction_0);
            }
            else
            {
                contribution_2 = gFrame_0.background_0.xyz;
            }
            s_16.path_2.radiance_0 = s_16.path_2.radiance_0 + contribution_2;
            if(visible_0)
            {
                _S332 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S332 = false;
            }
            if(_S332)
            {
                s_16.path_2.radiance_0 = s_16.path_2.radiance_0 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if(s_16.path_2.lightsSampled_0)
            {
                mis_0 = EvalMISRobust_0(s_16.path_2.scatterPdf_0, EnvironmentPdf_0(ray_6.direction_0));
            }
            else
            {
                mis_0 = 1.0f;
            }
            var contribution_4 : vec3<f32> = s_16.path_2.throughput_12 * vec3<f32>(mis_0) * EvalEnvironment_0(ray_6.direction_0);
            if(!s_16.path_2.lightsSampled_0)
            {
                _S332 = SunEnabled_0();
            }
            else
            {
                _S332 = false;
            }
            if(_S332)
            {
                _S332 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S332 = false;
            }
            if(_S332)
            {
                contribution_2 = contribution_4 + s_16.path_2.throughput_12 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_2 = contribution_4;
            }
            if((clampValue_0 > 0.0f))
            {
                contribution_2 = min(contribution_2, vec3<f32>(clampValue_0));
            }
            s_16.path_2.radiance_0 = s_16.path_2.radiance_0 + contribution_2;
        }
        s_16.active_0 = u32(0);
    }
    else
    {
        gAccum_0[Field_0(base_14, u32(8))] = vec4<f32>(hit_6.t_0, hit_6.barycentrics_0, (bitcast<f32>((hit_6.instanceIndex_0))));
        gAccum_0[Field_0(base_14, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_6.primitiveIndex_0, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_14] = vec4<f32>(s_16.path_2.radiance_0, (bitcast<f32>((s_16.active_0))));
    return;
}

fn IntersectImpl_1( tid_3 : vec3<u32>)
{
    var _S335 : u32 = tid_3.x;
    if((_S335 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_15 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S335));
    var s_17 : WavefrontPath_0 = LoadPath_0(base_15);
    if((s_17.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_15);
    gRayCone_0 = vec2<f32>(s_17.path_2.coneWidth_2, s_17.path_2.coneSpread_0);
    var ray_7 : Ray_0 = Ray_x24init_0(s_17.path_2.origin_3, s_17.path_2.direction_3, 1.00000001504746622e+30f);
    var hit_7 : HitRecord_0 = TraceClosest_1(ray_7);
    var clampValue_1 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var bounce_2 : u32 = gWavefront_0.bounce_0;
    var mis_1 : f32;
    var _S336 : bool;
    var contribution_5 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_3 : vec3<f32>;
        var pdf_16 : f32;
        if(HitRecord_IsHit_0(hit_7))
        {
            mis_1 = hit_7.t_0;
        }
        else
        {
            mis_1 = 1.00000001504746622e+30f;
        }
        var _S337 : bool = IntersectAnalyticLights_0(ray_7.origin_0, ray_7.direction_0, mis_1, bounce_2 == u32(0), &(radiance_3), &(pdf_16));
        if(_S337)
        {
            var _S338 : bool = (bounce_2 > u32(0));
            if(_S338)
            {
                _S336 = s_17.path_2.lightsSampled_0;
            }
            else
            {
                _S336 = false;
            }
            if(_S336)
            {
                mis_1 = EvalMISRobust_0(s_17.path_2.scatterPdf_0, pdf_16);
            }
            else
            {
                mis_1 = 1.0f;
            }
            var contribution_6 : vec3<f32> = s_17.path_2.throughput_12 * vec3<f32>(mis_1) * radiance_3;
            if((clampValue_1 > 0.0f))
            {
                _S336 = _S338;
            }
            else
            {
                _S336 = false;
            }
            if(_S336)
            {
                contribution_5 = min(contribution_6, vec3<f32>(clampValue_1));
            }
            else
            {
                contribution_5 = contribution_6;
            }
            s_17.path_2.radiance_0 = s_17.path_2.radiance_0 + contribution_5;
        }
    }
    if(!HitRecord_IsHit_0(hit_7))
    {
        if(bounce_2 == u32(0))
        {
            var visible_1 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_1)
            {
                contribution_5 = EvalEnvironment_0(ray_7.direction_0);
            }
            else
            {
                contribution_5 = gFrame_0.background_0.xyz;
            }
            s_17.path_2.radiance_0 = s_17.path_2.radiance_0 + contribution_5;
            if(visible_1)
            {
                _S336 = HitsSun_0(ray_7.direction_0);
            }
            else
            {
                _S336 = false;
            }
            if(_S336)
            {
                s_17.path_2.radiance_0 = s_17.path_2.radiance_0 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if(s_17.path_2.lightsSampled_0)
            {
                mis_1 = EvalMISRobust_0(s_17.path_2.scatterPdf_0, EnvironmentPdf_0(ray_7.direction_0));
            }
            else
            {
                mis_1 = 1.0f;
            }
            var contribution_7 : vec3<f32> = s_17.path_2.throughput_12 * vec3<f32>(mis_1) * EvalEnvironment_0(ray_7.direction_0);
            if(!s_17.path_2.lightsSampled_0)
            {
                _S336 = SunEnabled_0();
            }
            else
            {
                _S336 = false;
            }
            if(_S336)
            {
                _S336 = HitsSun_0(ray_7.direction_0);
            }
            else
            {
                _S336 = false;
            }
            if(_S336)
            {
                contribution_5 = contribution_7 + s_17.path_2.throughput_12 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_5 = contribution_7;
            }
            if((clampValue_1 > 0.0f))
            {
                contribution_5 = min(contribution_5, vec3<f32>(clampValue_1));
            }
            s_17.path_2.radiance_0 = s_17.path_2.radiance_0 + contribution_5;
        }
        s_17.active_0 = u32(0);
    }
    else
    {
        gAccum_0[Field_0(base_15, u32(8))] = vec4<f32>(hit_7.t_0, hit_7.barycentrics_0, (bitcast<f32>((hit_7.instanceIndex_0))));
        gAccum_0[Field_0(base_15, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_7.primitiveIndex_0, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_15] = vec4<f32>(s_17.path_2.radiance_0, (bitcast<f32>((s_17.active_0))));
    StoreFeedbackState_0(base_15);
    return;
}

fn WorkPixel_0( index_14 : u32) -> vec2<u32>
{
    var work_0 : u32 = gWavefront_0.tileStart_0 + index_14;
    var block_0 : u32 = work_0 / u32(64);
    var lane_0 : u32 = (work_0 & (u32(63)));
    var blocksX_0 : u32 = (gFrame_0.frame_0.x + u32(7)) / u32(8);
    var _S339 : u32 = block_0 % blocksX_0;
    var _S340 : u32 = _S339 * u32(8) + ((lane_0 & (u32(7))));
    var _S341 : u32 = block_0 / blocksX_0;
    return vec2<u32>(_S340, _S341 * u32(8) + lane_0 / u32(8));
}

struct RandomSequence_0
{
     seed_1 : u32,
};

fn RandomSequence_x24init_0( pixel_0 : vec2<u32>,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S342 : RandomSequence_0;
    _S342.seed_1 = StrongIntegerHash_0(pixel_0.x + pixel_0.y * u32(65536) + StrongIntegerHash_0(timeSeed_0));
    return _S342;
}

fn RandomSequence_Next_0( this_98 : ptr<function, RandomSequence_0>) -> f32
{
    var _S343 : u32 = (*this_98).seed_1 + u32(1);
    (*this_98).seed_1 = _S343;
    return f32(((StrongIntegerHash_0(_S343)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next_1( this_99 : ptr<function, RandomSequence_0>) -> f32
{
    var _S344 : u32 = (*this_99).seed_1 + u32(1);
    (*this_99).seed_1 = _S344;
    return f32(((StrongIntegerHash_0(_S344)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_100 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_28 : f32 = RandomSequence_Next_1(&((*this_100)));
    var y_11 : f32 = RandomSequence_Next_1(&((*this_100)));
    return vec2<f32>(x_28, y_11);
}

fn SampleDisk_0( u_24 : vec2<f32>) -> vec2<f32>
{
    var angle_2 : f32 = 2.0f * float_getPi_0() * u_24.x;
    return vec2<f32>(cos(angle_2), sin(angle_2)) * vec2<f32>(sqrt(u_24.y));
}

fn GenerateCameraRay_0( pixel_1 : vec2<u32>,  rng_0 : ptr<function, RandomSequence_0>) -> Ray_0
{
    var _S345 : vec2<f32> = vec2<f32>(gFrame_0.frame_0.xy);
    var _S346 : vec2<f32> = vec2<f32>(pixel_1);
    var _S347 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_0)));
    var film_2 : vec2<f32> = (_S346 + _S347) / _S345;
    var forward_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var dir_6 : vec3<f32> = normalize(forward_0 + gFrame_0.cameraRight_0.xyz * vec3<f32>((film_2.x * 2.0f - 1.0f)) + gFrame_0.cameraUp_0.xyz * vec3<f32>((1.0f - film_2.y * 2.0f)));
    var origin_5 : vec3<f32> = gFrame_0.cameraPosition_0.xyz;
    var lensRadius_0 : f32 = gFrame_0.cameraPosition_0.w;
    var dir_7 : vec3<f32>;
    var origin_6 : vec3<f32>;
    if((lensRadius_0 > 0.0f))
    {
        var focusPoint_0 : vec3<f32> = origin_5 + dir_6 * vec3<f32>((gFrame_0.cameraRight_0.w / dot(dir_6, forward_0)));
        var _S348 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_0)));
        var lens_0 : vec2<f32> = SampleDisk_0(_S348) * vec2<f32>(lensRadius_0);
        var origin_7 : vec3<f32> = origin_5 + (normalize(gFrame_0.cameraRight_0.xyz) * vec3<f32>(lens_0.x) + normalize(gFrame_0.cameraUp_0.xyz) * vec3<f32>(lens_0.y));
        dir_7 = normalize(focusPoint_0 - origin_7);
        origin_6 = origin_7;
    }
    else
    {
        dir_7 = dir_6;
        origin_6 = origin_5;
    }
    return Ray_x24init_0(origin_6, dir_7, 1.00000001504746622e+30f);
}

fn StorePath_0( base_16 : u32,  s_18 : WavefrontPath_0)
{
    gAccum_0[base_16] = vec4<f32>(s_18.path_2.radiance_0, (bitcast<f32>((s_18.active_0))));
    gAccum_0[Field_0(base_16, u32(1))] = vec4<f32>(s_18.path_2.throughput_12, (bitcast<f32>((s_18.randomSeed_0))));
    gAccum_0[Field_0(base_16, u32(2))] = vec4<f32>(s_18.path_2.origin_3, s_18.path_2.scatterPdf_0);
    gAccum_0[Field_0(base_16, u32(3))] = vec4<f32>(s_18.path_2.direction_3, (bitcast<f32>((select(u32(0), u32(1), s_18.path_2.lightsSampled_0)))));
    gAccum_0[Field_0(base_16, u32(4))] = vec4<f32>(s_18.path_2.absorption_0, s_18.path_2.coneWidth_2);
    gAccum_0[Field_0(base_16, u32(5))] = vec4<f32>(s_18.albedo_1, s_18.path_2.coneSpread_0);
    gAccum_0[Field_0(base_16, u32(6))] = vec4<f32>(s_18.normal_12, 0.0f);
    return;
}

fn InitVirtualTextureFeedback_0( pixel_2 : vec2<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = StrongIntegerHash_0(((pixel_2.x) ^ ((StrongIntegerHash_0(((pixel_2.y) ^ ((StrongIntegerHash_0(gFrame_0.frame_0.w)))))))));
    return;
}

fn _S349() -> vec2<f32>
{
    return vec2<f32>(0.0f);
}

@compute
@workgroup_size(64, 1, 1)
fn Initialize(@builtin(global_invocation_id) tid_4 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_15 : u32 = tid_4.x;
    if((index_15 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var pixel_3 : vec2<u32> = WorkPixel_0(index_15);
    var rng_1 : RandomSequence_0 = RandomSequence_x24init_0(pixel_3, gFrame_0.frame_0.w);
    var ray_8 : Ray_0 = GenerateCameraRay_0(pixel_3, &(rng_1));
    var s_19 : WavefrontPath_0;
    var _S350 : vec3<f32> = vec3<f32>(0.0f);
    s_19.path_2.radiance_0 = _S350;
    s_19.path_2.throughput_12 = vec3<f32>(1.0f);
    s_19.path_2.origin_3 = ray_8.origin_0;
    s_19.path_2.direction_3 = ray_8.direction_0;
    s_19.path_2.scatterPdf_0 = 1.0f;
    s_19.path_2.lobe_5 = u32(0);
    s_19.path_2.coneWidth_2 = 0.0f;
    s_19.path_2.coneSpread_0 = gFrame_0.vtParams_0.y;
    s_19.path_2.absorption_0 = _S350;
    s_19.path_2.lightsSampled_0 = false;
    s_19.active_0 = select(u32(0), u32(1), (all(((pixel_3 < (gFrame_0.frame_0.xy))))));
    s_19.randomSeed_0 = rng_1.seed_1;
    s_19.albedo_1 = _S350;
    s_19.normal_12 = _S350;
    var base_17 : u32 = WorkBase_0(index_15);
    StorePath_0(base_17, s_19);
    gAccum_0[Field_0(base_17, u32(11))] = vec4<f32>(0.0f);
    if(((index_15 & (u32(3)))) == u32(0))
    {
        gAccum_0[MainQueueBase_0() + index_15 / u32(4)] = (bitcast<vec4<f32>>((vec4<u32>(index_15, index_15 + u32(1), index_15 + u32(2), index_15 + u32(3)))));
    }
    if(index_15 == u32(0))
    {
        var _S351 : u32 = HeaderBase_0();
        gAccum_0[_S351] = (bitcast<vec4<f32>>((vec4<u32>(gWavefront_0.pathCount_0, u32(0), u32(0), u32(0)))));
        gAccum_0[_S351 + u32(1)] = (bitcast<vec4<f32>>((vec4<u32>((gWavefront_0.pathCount_0 + u32(63)) / u32(64), u32(1), u32(1), u32(0)))));
        gAccum_0[_S351 + u32(2)] = (bitcast<vec4<f32>>((vec4<u32>(u32(0), u32(1), u32(1), u32(0)))));
    }
    InitVirtualTextureFeedback_0(pixel_3);
    StoreFeedbackState_0(base_17);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Intersect(@builtin(global_invocation_id) tid_5 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_1(tid_5);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectOpaque(@builtin(global_invocation_id) tid_6 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_0(tid_6);
    return;
}

struct SurfaceInteraction_0
{
     position_1 : vec3<f32>,
     faceNormal_0 : vec3<f32>,
     normal_13 : vec3<f32>,
     tangent_5 : vec4<f32>,
     tex_2 : TextureCoords_0,
     materialIndex_2 : u32,
     instanceIndex_4 : u32,
     primitiveIndex_3 : u32,
     frontFacing_0 : bool,
};

fn TransformPoint_0( _S352 : u32,  _S353 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S352].objectToWorld_0[i32(0)].xyz, _S353) + gInstances_0[_S352].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S352].objectToWorld_0[i32(1)].xyz, _S353) + gInstances_0[_S352].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S352].objectToWorld_0[i32(2)].xyz, _S353) + gInstances_0[_S352].objectToWorld_0[i32(2)].w);
}

fn TransformNormal_0( _S354 : u32,  _S355 : vec3<f32>) -> vec3<f32>
{
    return gInstances_0[_S354].worldToObject_0[i32(0)].xyz * vec3<f32>(_S355.x) + gInstances_0[_S354].worldToObject_0[i32(1)].xyz * vec3<f32>(_S355.y) + gInstances_0[_S354].worldToObject_0[i32(2)].xyz * vec3<f32>(_S355.z);
}

fn GetSurfaceInteraction_0( rayDirection_0 : vec3<f32>,  hit_8 : HitRecord_0,  coneWidth_3 : f32) -> SurfaceInteraction_0
{
    var _S356 : vec3<u32> = LoadTriangleIndices_0(hit_8.instanceIndex_0, hit_8.primitiveIndex_0);
    var _S357 : Vertex_std430_0 = gVertices_0[_S356.x];
    var _S358 : Vertex_std430_0 = gVertices_0[_S356.y];
    var _S359 : Vertex_std430_0 = gVertices_0[_S356.z];
    var _S360 : f32 = hit_8.barycentrics_0.x;
    var _S361 : f32 = hit_8.barycentrics_0.y;
    var _S362 : f32 = 1.0f - _S360 - _S361;
    var p0_1 : vec3<f32> = _S357.positionU_0.xyz;
    var p1_1 : vec3<f32> = _S358.positionU_0.xyz;
    var p2_1 : vec3<f32> = _S359.positionU_0.xyz;
    var si_0 : SurfaceInteraction_0;
    si_0.instanceIndex_4 = hit_8.instanceIndex_0;
    si_0.primitiveIndex_3 = hit_8.primitiveIndex_0;
    si_0.materialIndex_2 = gInstances_0[hit_8.instanceIndex_0].materialIndex_0;
    var _S363 : vec3<f32> = vec3<f32>(_S362);
    var _S364 : vec3<f32> = vec3<f32>(_S360);
    var _S365 : vec3<f32> = vec3<f32>(_S361);
    var _S366 : vec3<f32> = p0_1 * _S363 + p1_1 * _S364 + p2_1 * _S365;
    si_0.position_1 = TransformPoint_0(hit_8.instanceIndex_0, _S366);
    var _S367 : vec3<f32> = p1_1 - p0_1;
    var _S368 : vec3<f32> = p2_1 - p0_1;
    si_0.faceNormal_0 = normalize(TransformNormal_0(hit_8.instanceIndex_0, cross(normalize(_S367), normalize(_S368))));
    var n_12 : vec3<f32> = _S357.normalV_0.xyz * _S363 + _S358.normalV_0.xyz * _S364 + _S359.normalV_0.xyz * _S365;
    var t_11 : vec3<f32>;
    if(((dot(n_12, n_12)) > 0.0f))
    {
        t_11 = normalize(TransformNormal_0(hit_8.instanceIndex_0, n_12));
    }
    else
    {
        t_11 = si_0.faceNormal_0;
    }
    si_0.normal_13 = t_11;
    var _S369 : vec2<f32> = VertexUV0_0(&(_S357));
    var _S370 : vec2<f32> = VertexUV0_0(&(_S358));
    var _S371 : vec2<f32> = VertexUV0_0(&(_S359));
    var _S372 : vec2<f32> = vec2<f32>(_S362);
    var _S373 : vec2<f32> = vec2<f32>(_S360);
    var _S374 : vec2<f32> = vec2<f32>(_S361);
    var _S375 : vec2<f32> = _S357.uv1_0.xy;
    var _S376 : vec2<f32> = _S358.uv1_0.xy;
    var _S377 : vec2<f32> = _S359.uv1_0.xy;
    si_0.tex_2 = MakeTextureCoords_0(_S369 * _S372 + _S370 * _S373 + _S371 * _S374, _S375 * _S372 + _S376 * _S373 + _S377 * _S374, TransformVector_0(hit_8.instanceIndex_0, _S367), TransformVector_0(hit_8.instanceIndex_0, _S368), _S370 - _S369, _S371 - _S369, _S376 - _S375, _S377 - _S375, coneWidth_3, dot(si_0.faceNormal_0, rayDirection_0));
    si_0.tex_2.objectPosition_0 = _S366;
    si_0.frontFacing_0 = ((dot(si_0.faceNormal_0, (vec3<f32>(0) - rayDirection_0))) > 0.0f);
    var _S378 : vec4<f32> = _S357.tangent_0;
    var t_12 : vec3<f32> = _S357.tangent_0.xyz * _S363 + _S358.tangent_0.xyz * _S364 + _S359.tangent_0.xyz * _S365;
    if(((dot(t_12, t_12)) > 0.0f))
    {
        t_11 = normalize(TransformVector_0(hit_8.instanceIndex_0, t_12));
    }
    else
    {
        t_11 = vec3<f32>(0.0f);
    }
    si_0.tangent_5 = vec4<f32>(t_11, _S378.w);
    return si_0;
}

fn MaterialHeader_DoubleSided_0( this_101 : MaterialHeader_0) -> bool
{
    return (((this_101.flags_1) & (u32(1)))) != u32(0);
}

fn AlignWithFace_0( n_13 : vec3<f32>,  V_0 : vec3<f32>,  frontFacing_1 : bool) -> vec3<f32>
{
    var side_0 : f32;
    if(frontFacing_1)
    {
        side_0 = 1.0f;
    }
    else
    {
        side_0 = -1.0f;
    }
    var cosV_0 : f32 = dot(V_0, n_13) * side_0;
    if((cosV_0 >= 9.9999997473787516e-05f))
    {
        return n_13;
    }
    return normalize(n_13 + V_0 * vec3<f32>((side_0 * (9.9999997473787516e-05f - cosV_0))));
}

fn BranchlessONB_0( n_14 : vec3<f32>,  b1_0 : ptr<function, vec3<f32>>,  b2_0 : ptr<function, vec3<f32>>)
{
    var _S379 : f32 = n_14.z;
    var s_20 : f32;
    if((_S379 >= 0.0f))
    {
        s_20 = 1.0f;
    }
    else
    {
        s_20 = -1.0f;
    }
    var a_15 : f32 = -1.0f / (s_20 + _S379);
    var _S380 : f32 = n_14.x;
    var _S381 : f32 = n_14.y;
    var b_11 : f32 = _S380 * _S381 * a_15;
    (*b1_0) = vec3<f32>(1.0f + s_20 * _S380 * _S380 * a_15, s_20 * b_11, - s_20 * _S380);
    (*b2_0) = vec3<f32>(b_11, s_20 + _S381 * _S381 * a_15, - _S381);
    return;
}

fn BranchlessONB_1( n_15 : vec3<f32>,  b1_1 : ptr<function, vec3<f32>>,  b2_1 : ptr<function, vec3<f32>>)
{
    var _S382 : f32 = n_15.z;
    var s_21 : f32;
    if((_S382 >= 0.0f))
    {
        s_21 = 1.0f;
    }
    else
    {
        s_21 = -1.0f;
    }
    var a_16 : f32 = -1.0f / (s_21 + _S382);
    var _S383 : f32 = n_15.x;
    var _S384 : f32 = n_15.y;
    var b_12 : f32 = _S383 * _S384 * a_16;
    (*b1_1) = vec3<f32>(1.0f + s_21 * _S383 * _S383 * a_16, s_21 * b_12, - s_21 * _S383);
    (*b2_1) = vec3<f32>(b_12, s_21 + _S384 * _S384 * a_16, - _S384);
    return;
}

fn Frame_FromNormal_0( n_16 : vec3<f32>) -> Frame_0
{
    var f_15 : Frame_0;
    f_15.n_1 = n_16;
    var _S385 : vec3<f32> = f_15.t_3;
    var _S386 : vec3<f32> = f_15.b_0;
    BranchlessONB_0(n_16, &(_S385), &(_S386));
    f_15.t_3 = _S385;
    f_15.b_0 = _S386;
    return f_15;
}

fn Frame_FromTangent_0( tangent_6 : vec4<f32>,  n_17 : vec3<f32>) -> Frame_0
{
    var _S387 : vec3<f32> = tangent_6.xyz;
    var NdotT_0 : f32 = dot(_S387, n_17);
    var _S388 : f32 = tangent_6.w;
    var valid_1 : bool;
    if(_S388 != 0.0f)
    {
        valid_1 = ((dot(_S387, _S387)) > 0.0f);
    }
    else
    {
        valid_1 = false;
    }
    if(valid_1)
    {
        valid_1 = ((abs(NdotT_0)) < 0.99989998340606689f);
    }
    else
    {
        valid_1 = false;
    }
    if(!valid_1)
    {
        return Frame_FromNormal_0(n_17);
    }
    var f_16 : Frame_0;
    f_16.n_1 = n_17;
    var _S389 : vec3<f32> = normalize(_S387 - n_17 * vec3<f32>(NdotT_0));
    f_16.t_3 = _S389;
    f_16.b_0 = cross(n_17, _S389) * vec3<f32>(_S388);
    return f_16;
}

struct MaterialSample_0
{
     inputs_1 : BSDFInputs_0,
     albedo_2 : vec3<f32>,
     roughness_5 : f32,
     doubleSided_0 : bool,
     thinWalled_0 : bool,
};

fn EvalMaterial_0( si_1 : SurfaceInteraction_0,  V_1 : vec3<f32>) -> MaterialSample_0
{
    var header_5 : MaterialHeader_0 = LoadMaterialHeader_0(si_1.materialIndex_2);
    var ctx_5 : MaterialContext_0;
    ctx_5.tex_0 = si_1.tex_2;
    ctx_5.position_0 = si_1.position_1;
    ctx_5.normal_1 = si_1.normal_13;
    ctx_5.tangent_2 = si_1.tangent_5;
    ctx_5.instanceIndex_2 = si_1.instanceIndex_4;
    var o_53 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_5);
    if((header_5.surface_0) != u32(4294967295))
    {
        RunMaterialProgram_1(header_5, header_5.surface_0, ctx_5, &(o_53));
    }
    var ms_0 : MaterialSample_0;
    ms_0.inputs_1 = o_53.inputs_0;
    ms_0.albedo_2 = o_53.inputs_0.baseColor_0;
    ms_0.roughness_5 = o_53.inputs_0.specularRoughness_0;
    ms_0.doubleSided_0 = MaterialHeader_DoubleSided_0(header_5);
    ms_0.thinWalled_0 = o_53.inputs_0.geometryThinWalled_0;
    var _S390 : f32 = si_1.tangent_5.w;
    var handedness_0 : f32;
    if(_S390 != 0.0f)
    {
        handedness_0 = _S390;
    }
    else
    {
        handedness_0 = 1.0f;
    }
    ms_0.inputs_1.basis_0 = Frame_FromTangent_0(vec4<f32>(o_53.tangent_1, handedness_0), AlignWithFace_0(o_53.normal_0, V_1, si_1.frontFacing_0));
    var _S391 : bool;
    if((all(((o_53.coatNormal_0) == (o_53.normal_0)))))
    {
        _S391 = (all(((o_53.coatTangent_0) == (o_53.tangent_1))));
    }
    else
    {
        _S391 = false;
    }
    if(_S391)
    {
        ms_0.inputs_1.coatBasis_0 = ms_0.inputs_1.basis_0;
    }
    else
    {
        ms_0.inputs_1.coatBasis_0 = Frame_FromTangent_0(vec4<f32>(o_53.coatTangent_0, handedness_0), AlignWithFace_0(o_53.coatNormal_0, V_1, si_1.frontFacing_0));
    }
    return ms_0;
}

struct HomogeneousVolume_0
{
     extinction_0 : vec3<f32>,
     albedo_3 : vec3<f32>,
     anisotropy_0 : f32,
};

fn HomogeneousVolume_x24init_0( extinction_1 : vec3<f32>,  albedo_4 : vec3<f32>,  anisotropy_1 : f32) -> HomogeneousVolume_0
{
    var _S392 : HomogeneousVolume_0;
    _S392.extinction_0 = extinction_1;
    _S392.albedo_3 = albedo_4;
    _S392.anisotropy_0 = anisotropy_1;
    return _S392;
}

fn HomogeneousVolume_Empty_0() -> HomogeneousVolume_0
{
    var _S393 : vec3<f32> = vec3<f32>(0.0f);
    return HomogeneousVolume_x24init_0(_S393, _S393, 0.0f);
}

fn Square_1( v_15 : vec3<f32>) -> vec3<f32>
{
    return v_15 * v_15;
}

fn CreateSubsurfaceVolume_0( radius_3 : f32,  radiusScale_0 : vec3<f32>,  color_4 : vec3<f32>,  anisotropy_2 : f32) -> HomogeneousVolume_0
{
    var _S394 : vec3<f32> = vec3<f32>(1.0f);
    var g_2 : f32 = clamp(anisotropy_2, -0.99900001287460327f, 0.99900001287460327f);
    var _S395 : vec3<f32> = Square_1(vec3<f32>(4.0971198081970215f) + vec3<f32>(4.2086300849914551f) * color_4 - sqrt(vec3<f32>(9.5921697616577148f) + vec3<f32>(41.680801391601562f) * color_4 + vec3<f32>(17.712600708007812f) * Square_1(color_4)));
    return HomogeneousVolume_x24init_0(_S394 / max(vec3<f32>(radius_3) * radiusScale_0, vec3<f32>(0.0010000000474974513f)), saturate((_S394 - _S395) / (_S394 - vec3<f32>(g_2) * _S395)), g_2);
}

fn HomogeneousVolume_FromAbsorptionAndScattering_0( absorption_1 : vec3<f32>,  scattering_0 : vec3<f32>,  anisotropy_3 : f32) -> HomogeneousVolume_0
{
    var extinction_2 : vec3<f32> = absorption_1 + scattering_0;
    var albedo_5 : vec3<f32>;
    if((all(((extinction_2 > vec3<f32>(0.0f))))))
    {
        albedo_5 = scattering_0 / extinction_2;
    }
    else
    {
        var _S396 : f32;
        if(((extinction_2[i32(0)]) > 0.0f))
        {
            _S396 = scattering_0[i32(0)] / extinction_2[i32(0)];
        }
        else
        {
            _S396 = 0.0f;
        }
        albedo_5[i32(0)] = _S396;
        if(((extinction_2[i32(1)]) > 0.0f))
        {
            _S396 = scattering_0[i32(1)] / extinction_2[i32(1)];
        }
        else
        {
            _S396 = 0.0f;
        }
        albedo_5[i32(1)] = _S396;
        if(((extinction_2[i32(2)]) > 0.0f))
        {
            _S396 = scattering_0[i32(2)] / extinction_2[i32(2)];
        }
        else
        {
            _S396 = 0.0f;
        }
        albedo_5[i32(2)] = _S396;
    }
    return HomogeneousVolume_x24init_0(extinction_2, albedo_5, anisotropy_3);
}

fn CreateTransmissionVolume_0( color_5 : vec3<f32>,  depth_1 : f32,  scatter_0 : vec3<f32>,  anisotropy_4 : f32) -> HomogeneousVolume_0
{
    var _S397 : bool;
    if(((MinComponent_0(color_5)) >= 1.0f))
    {
        _S397 = ((MaxComponent_0(scatter_0)) <= 0.0f);
    }
    else
    {
        _S397 = false;
    }
    if(_S397)
    {
        return HomogeneousVolume_Empty_0();
    }
    var _S398 : vec3<f32> = vec3<f32>((1.0f / max(depth_1, 0.0010000000474974513f)));
    var scattering_1 : vec3<f32> = scatter_0 * _S398;
    var absorption_2 : vec3<f32> = (vec3<f32>(0) - log(max(color_5, vec3<f32>(0.0010000000474974513f)))) * _S398 - scattering_1;
    var _S399 : f32 = MinComponent_0(absorption_2);
    var absorption_3 : vec3<f32>;
    if((_S399 < 0.0f))
    {
        absorption_3 = absorption_2 - vec3<f32>(_S399);
    }
    else
    {
        absorption_3 = absorption_2;
    }
    return HomogeneousVolume_FromAbsorptionAndScattering_0(absorption_3, scattering_1, clamp(anisotropy_4, -0.99900001287460327f, 0.99900001287460327f));
}

fn HomogeneousVolume_Absorption_0( this_102 : HomogeneousVolume_0) -> vec3<f32>
{
    return this_102.extinction_0 * (vec3<f32>(1.0f) - this_102.albedo_3);
}

fn HomogeneousVolume_Scattering_0( this_103 : HomogeneousVolume_0) -> vec3<f32>
{
    return this_103.extinction_0 * this_103.albedo_3;
}

fn AddVolumes_0( a_17 : HomogeneousVolume_0,  b_13 : HomogeneousVolume_0,  weightA_0 : f32,  weightB_0 : f32) -> HomogeneousVolume_0
{
    var _S400 : vec3<f32> = vec3<f32>(weightA_0);
    var _S401 : vec3<f32> = vec3<f32>(weightB_0);
    return HomogeneousVolume_FromAbsorptionAndScattering_0(HomogeneousVolume_Absorption_0(a_17) * _S400 + HomogeneousVolume_Absorption_0(b_13) * _S401, HomogeneousVolume_Scattering_0(a_17) * _S400 + HomogeneousVolume_Scattering_0(b_13) * _S401, SafeDivide_0(a_17.anisotropy_0 * weightA_0 + b_13.anisotropy_0 * weightB_0, weightA_0 + weightB_0, 0.0f));
}

struct VolumeDerived_0
{
     thinWallSubsurfaceColor_0 : vec3<f32>,
     thinWallSubsurfaceAnisotropy_0 : f32,
     transmissionTint_0 : vec3<f32>,
};

fn PrepareVolume_0( inputs_2 : BSDFInputs_0,  derived_0 : ptr<function, VolumeDerived_0>) -> HomogeneousVolume_0
{
    var _S402 : HomogeneousVolume_0 = HomogeneousVolume_Empty_0();
    (*derived_0).thinWallSubsurfaceColor_0 = vec3<f32>(0.0f);
    (*derived_0).thinWallSubsurfaceAnisotropy_0 = 0.0f;
    var subsurfaceVolume_0 : HomogeneousVolume_0;
    if(((inputs_2.subsurfaceWeight_0) > 0.0f))
    {
        if(!inputs_2.geometryThinWalled_0)
        {
            subsurfaceVolume_0 = CreateSubsurfaceVolume_0(inputs_2.subsurfaceRadius_0, inputs_2.subsurfaceRadiusScale_0, inputs_2.subsurfaceColor_0, inputs_2.subsurfaceScatterAnisotropy_0);
        }
        else
        {
            (*derived_0).thinWallSubsurfaceColor_0 = inputs_2.subsurfaceColor_0;
            (*derived_0).thinWallSubsurfaceAnisotropy_0 = inputs_2.subsurfaceScatterAnisotropy_0;
            subsurfaceVolume_0 = _S402;
        }
    }
    else
    {
        subsurfaceVolume_0 = _S402;
    }
    (*derived_0).transmissionTint_0 = vec3<f32>(1.0f);
    var transmissionVolume_0 : HomogeneousVolume_0;
    if(((inputs_2.transmissionWeight_0) > 0.0f))
    {
        var _S403 : bool;
        if((inputs_2.transmissionDepth_0) == 0.0f)
        {
            _S403 = true;
        }
        else
        {
            _S403 = inputs_2.geometryThinWalled_0;
        }
        if(_S403)
        {
            (*derived_0).transmissionTint_0 = inputs_2.transmissionColor_0;
            transmissionVolume_0 = _S402;
        }
        else
        {
            transmissionVolume_0 = CreateTransmissionVolume_0(inputs_2.transmissionColor_0, inputs_2.transmissionDepth_0, inputs_2.transmissionScatter_0, inputs_2.transmissionScatterAnisotropy_0);
        }
    }
    else
    {
        transmissionVolume_0 = _S402;
    }
    var subsurfaceFraction_0 : f32 = (1.0f - inputs_2.transmissionWeight_0) * inputs_2.subsurfaceWeight_0;
    var invTotal_0 : f32 = SafeDivide_0(1.0f, subsurfaceFraction_0 + inputs_2.transmissionWeight_0, 0.0f);
    return AddVolumes_0(subsurfaceVolume_0, transmissionVolume_0, subsurfaceFraction_0 * invTotal_0, inputs_2.transmissionWeight_0 * invTotal_0);
}

fn Frame_Handedness_0( this_104 : Frame_0) -> f32
{
    var _S404 : f32;
    if(((dot(cross(this_104.t_3, this_104.b_0), this_104.n_1)) >= 0.0f))
    {
        _S404 = 1.0f;
    }
    else
    {
        _S404 = -1.0f;
    }
    return _S404;
}

fn Frame_RotatedAroundNormal_0( this_105 : Frame_0,  cosSin_0 : vec2<f32>) -> Frame_0
{
    if((all((cosSin_0 == vec2<f32>(0.0f)))))
    {
        return this_105;
    }
    var cs_0 : vec2<f32> = normalize(cosSin_0);
    var h_15 : f32 = Frame_Handedness_0(this_105);
    var f_17 : Frame_0;
    f_17.n_1 = this_105.n_1;
    var _S405 : vec3<f32> = vec3<f32>(cs_0.x);
    var _S406 : vec3<f32> = vec3<f32>(h_15);
    var _S407 : vec3<f32> = vec3<f32>(cs_0.y);
    f_17.t_3 = this_105.t_3 * _S405 + _S406 * this_105.b_0 * _S407;
    f_17.b_0 = this_105.b_0 * _S405 - _S406 * this_105.t_3 * _S407;
    return f_17;
}

fn Frame_Inverted_0( this_106 : Frame_0) -> Frame_0
{
    var f_18 : Frame_0;
    f_18.t_3 = (vec3<f32>(0) - this_106.t_3);
    f_18.b_0 = (vec3<f32>(0) - this_106.b_0);
    f_18.n_1 = (vec3<f32>(0) - this_106.n_1);
    return f_18;
}

fn IorFromF0_0( f0_2 : f32) -> f32
{
    var sqrtF0_0 : f32 = sqrt(f0_2);
    return (1.0f + sqrtF0_0) / (1.0f - sqrtF0_0);
}

fn ApplySpecularWeightToIor_0( eta_7 : f32,  specularWeight_1 : f32) -> f32
{
    var externalIor_0 : f32 = IorFromF0_0(min(F0FromIor_0(eta_7) * specularWeight_1, 0.99989998340606689f));
    var _S408 : f32;
    if((eta_7 < 1.0f))
    {
        _S408 = 1.0f / externalIor_0;
    }
    else
    {
        _S408 = externalIor_0;
    }
    return _S408;
}

fn Average_0( v_16 : vec3<f32>) -> f32
{
    return Sum_0(v_16) * 0.3333333432674408f;
}

fn FourthPower_0( x_29 : f32) -> f32
{
    var xx_2 : f32 = x_29 * x_29;
    return xx_2 * xx_2;
}

fn FourthRoot_0( x_30 : f32) -> f32
{
    return sqrt(sqrt(x_30));
}

fn AnisotropicAlpha_0( isotropicAlpha_2 : f32,  anisotropy_5 : f32) -> vec2<f32>
{
    var alpha_15 : vec2<f32>;
    if((anisotropy_5 > 0.0f))
    {
        var _S409 : f32 = 1.0f - anisotropy_5;
        alpha_15[i32(0)] = isotropicAlpha_2 * sqrt(2.0f / (1.0f + Square_0(_S409)));
        alpha_15[i32(1)] = _S409 * alpha_15.x;
    }
    else
    {
        alpha_15 = vec2<f32>(isotropicAlpha_2);
    }
    return max(alpha_15, vec2<f32>(1.00000011116208043e-06f));
}

fn AverageFresnelMetalF82_0( f0_3 : vec3<f32>,  f82Tint_2 : vec3<f32>) -> vec3<f32>
{
    return saturate(f0_3 + (vec3<f32>(1.0f) - f0_3) * vec3<f32>(0.0476190485060215f) - MetalSchlickBFactor_0(f0_3, f82Tint_2) * vec3<f32>(0.0079365083947777748f));
}

fn AverageFresnel_0( eta_8 : f32) -> f32
{
    if((eta_8 > 1.0f))
    {
        return (eta_8 - 1.0f) / (4.085669994354248f + 1.0007100105285645f * eta_8);
    }
    var _S410 : f32 = eta_8 * eta_8;
    return 0.99711799621582031f + 0.10140000283718109f * eta_8 - 0.96524101495742798f * _S410 - 0.1306069940328598f * _S410 * eta_8;
}

fn GGXDistribution_x24init_0( alpha_16 : vec2<f32>,  frame_2 : Frame_0,  isotropicAlpha_3 : f32) -> GGXDistribution_0
{
    var _S411 : GGXDistribution_0;
    _S411.alpha_0 = alpha_16;
    _S411.frame_1 = frame_2;
    _S411.isotropicAlpha_0 = isotropicAlpha_3;
    return _S411;
}

fn BSDFInputs_HasDispersion_0( this_107 : BSDFInputs_0) -> bool
{
    var _S412 : bool;
    if(((this_107.transmissionDispersionScale_0) > 0.0f))
    {
        _S412 = ((this_107.transmissionDispersionAbbeNumber_0) > 0.0f);
    }
    else
    {
        _S412 = false;
    }
    if(_S412)
    {
        _S412 = ((this_107.baseMetalness_0) < 1.0f);
    }
    else
    {
        _S412 = false;
    }
    return _S412;
}

fn DispersionAdjustedIor_0( ior_6 : f32,  dispersion_1 : f32,  wavelength_0 : f32) -> f32
{
    var belowOne_0 : bool = (ior_6 < 1.0f);
    var iorAboveOne_0 : f32;
    if(belowOne_0)
    {
        iorAboveOne_0 = 1.0f / ior_6;
    }
    else
    {
        iorAboveOne_0 = ior_6;
    }
    var b_14 : f32 = (iorAboveOne_0 - 1.0f) / (20.0f / dispersion_1 * (Square_0(0.0020571898203343153f) - Square_0(0.001523693441413343f)));
    var adjusted_0 : f32 = iorAboveOne_0 - b_14 * Square_0(0.0017018381040543318f) + b_14 * Square_0(1.0f / wavelength_0);
    if(belowOne_0)
    {
        iorAboveOne_0 = 1.0f / adjusted_0;
    }
    else
    {
        iorAboveOne_0 = adjusted_0;
    }
    return iorAboveOne_0;
}

fn FinalTransmissionTint_0( tint_4 : vec3<f32>,  thinWall_0 : bool,  cosI_0 : f32,  etaForRefraction_0 : f32) -> vec3<f32>
{
    if(!thinWall_0)
    {
        return tint_4;
    }
    var sin2T_0 : f32 = (1.0f - Square_0(cosI_0)) / Square_0(etaForRefraction_0);
    if((sin2T_0 >= 1.0f))
    {
        return vec3<f32>(0.0f);
    }
    return pow(tint_4, vec3<f32>((1.0f / sqrt(1.0f - sin2T_0))));
}

fn ThinWallFresnel_0( eta_9 : f32,  cosThetaI_7 : f32) -> f32
{
    var r_8 : f32 = FresnelDielectric_0(eta_9, cosThetaI_7);
    return 2.0f * r_8 / (1.0f + r_8);
}

fn SpecularLobe_x24init_0( normal_14 : vec3<f32>,  distribution_4 : GGXDistribution_0,  coefficient_4 : BaseReflectionTransmission_0,  eta_10 : vec3<f32>,  throughput_13 : vec3<f32>) -> SpecularLobe_0
{
    var _S413 : SpecularLobe_0;
    _S413.normal_2 = normal_14;
    _S413.distribution_0 = distribution_4;
    _S413.coefficient_0 = coefficient_4;
    _S413.eta_0 = eta_10;
    _S413.throughput_0 = throughput_13;
    return _S413;
}

fn IdealDielectricReflectionRatio_0( ior_7 : f32,  alpha_17 : f32) -> f32
{
    return LookUpBilinear_0(i32(65), IorToExactIndex_0(ior_7), AlphaToExactIndex_0(alpha_17));
}

fn DielectricMultipleScatteringLobe_x24init_0( normal_15 : vec3<f32>,  wo_53 : vec3<f32>,  alpha_18 : f32,  eta_11 : f32,  reflectionScale_1 : vec3<f32>,  transmissionScale_1 : vec3<f32>) -> DielectricMultipleScatteringLobe_0
{
    var _S414 : DielectricMultipleScatteringLobe_0;
    _S414.normal_3 = normal_15;
    _S414.alpha_1 = alpha_18;
    _S414.eta_1 = eta_11;
    _S414.reflectionScale_0 = reflectionScale_1;
    _S414.transmissionScale_0 = transmissionScale_1;
    _S414.reflectionRatio_0 = 0.0f;
    _S414.energyComplementWo_0 = 0.0f;
    var _S415 : bool;
    if((alpha_18 >= 0.0015999999595806003f))
    {
        _S415 = (any((((max(reflectionScale_1, transmissionScale_1)) > vec3<f32>(0.0f)))));
    }
    else
    {
        _S415 = false;
    }
    if(_S415)
    {
        _S414.reflectionRatio_0 = IdealDielectricReflectionRatio_0(eta_11, alpha_18);
        _S414.energyComplementWo_0 = IdealDielectricEnergyComplement_0(eta_11, alpha_18, dot(wo_53, normal_15));
    }
    return _S414;
}

fn MetalMultipleScatteringLobe_x24init_0( normal_16 : vec3<f32>,  wo_54 : vec3<f32>,  alpha_19 : f32,  scale_5 : vec3<f32>) -> MetalMultipleScatteringLobe_0
{
    var _S416 : MetalMultipleScatteringLobe_0;
    _S416.normal_4 = normal_16;
    _S416.alpha_2 = alpha_19;
    _S416.scale_0 = scale_5;
    var _S417 : bool;
    if(MetalMultipleScatteringLobe_Active_0(_S416))
    {
        _S417 = (any(((scale_5 > vec3<f32>(0.0f)))));
    }
    else
    {
        _S417 = false;
    }
    var _S418 : f32;
    if(_S417)
    {
        _S418 = IdealMetalEnergyComplement_0(alpha_19, dot(wo_54, normal_16));
    }
    else
    {
        _S418 = 0.0f;
    }
    _S416.energyComplementWo_1 = _S418;
    return _S416;
}

fn OpaqueDielectricAverageEnergyComplement_0( ior_8 : f32,  alpha_20 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpBilinear_0(i32(66), IorToExactIndex_0(ior_8), AlphaToExactIndex_0(alpha_20)), ior_8);
}

fn DiffuseLobe_x24init_0( normal_17 : vec3<f32>,  wo_55 : vec3<f32>,  albedo_6 : vec3<f32>,  roughness_6 : f32,  specularAlpha_1 : f32,  specularEta_1 : f32) -> DiffuseLobe_0
{
    var _S419 : DiffuseLobe_0;
    _S419.normal_5 = normal_17;
    _S419.albedo_0 = albedo_6;
    _S419.roughness_1 = roughness_6;
    _S419.specularAlpha_0 = specularAlpha_1;
    _S419.specularEta_0 = specularEta_1;
    _S419.specularCompensation_0 = 0.0f;
    if((any(((albedo_6 > vec3<f32>(0.0f))))))
    {
        _S419.specularCompensation_0 = OpaqueDielectricEnergyComplement_0(specularEta_1, specularAlpha_1, dot(wo_55, normal_17)) / ClampAverageEnergyComplement_0(OpaqueDielectricAverageEnergyComplement_0(specularEta_1, specularAlpha_1));
    }
    return _S419;
}

fn ConstantReflection_x24init_0( color_6 : vec3<f32>) -> ConstantReflection_0
{
    var _S420 : ConstantReflection_0;
    _S420.color_2 = color_6;
    return _S420;
}

fn MakeThinWallSpecularTransmissionLobe_0( normal_18 : vec3<f32>,  distribution_5 : GGXDistribution_0,  transmissionColor_1 : vec3<f32>) -> FlippedLobe_0
{
    var flipped_0 : GGXDistribution_0 = distribution_5;
    flipped_0.frame_1.n_1 = (vec3<f32>(0) - flipped_0.frame_1.n_1);
    return FlippedLobe_x24init_1(MicrofacetReflectionLobe_x24init_1((vec3<f32>(0) - normal_18), flipped_0, ConstantReflection_x24init_0(transmissionColor_1)));
}

fn MakeThinWallDiffuseTransmissionLobe_0( normal_19 : vec3<f32>,  wo_56 : vec3<f32>,  albedo_7 : vec3<f32>,  roughness_7 : f32,  specularAlpha_2 : f32,  specularEta_2 : f32) -> FlippedLobe_1
{
    var flippedNormal_0 : vec3<f32> = (vec3<f32>(0) - normal_19);
    var reflectedWo_0 : vec3<f32> = reflect(wo_56, normal_19);
    var reflectedWo_1 : vec3<f32>;
    if(((dot(reflectedWo_0, flippedNormal_0)) < 0.0f))
    {
        reflectedWo_1 = (vec3<f32>(0) - reflectedWo_0);
    }
    else
    {
        reflectedWo_1 = reflectedWo_0;
    }
    return FlippedLobe_x24init_0(DiffuseLobe_x24init_0(flippedNormal_0, reflectedWo_1, albedo_7, roughness_7, specularAlpha_2, specularEta_2));
}

fn BaseReflectionTransmission_EstimateWeight_0( this_108 : BaseReflectionTransmission_0,  throughput_14 : vec3<f32>,  idotn_12 : f32) -> f32
{
    var c_14 : ReflectionTransmission_0 = BaseReflectionTransmission_Coefficients_0(this_108, idotn_12);
    return ThroughputWeightedMax_0(throughput_14, c_14.reflection_1 + c_14.transmission_1);
}

fn SpecularLobe_EstimateContribution_0( this_109 : SpecularLobe_0,  wo_57 : vec3<f32>,  throughput_15 : vec3<f32>) -> f32
{
    return BaseReflectionTransmission_EstimateWeight_0(this_109.coefficient_0, throughput_15, dot(wo_57, this_109.normal_2));
}

fn DielectricMultipleScatteringLobe_EstimateContribution_0( this_110 : DielectricMultipleScatteringLobe_0,  wo_58 : vec3<f32>,  throughput_16 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_110))
    {
        return 0.0f;
    }
    return ThroughputWeightedMax_0(throughput_16, this_110.reflectionScale_0 * vec3<f32>(this_110.reflectionRatio_0) + this_110.transmissionScale_0 * vec3<f32>((1.0f - this_110.reflectionRatio_0))) * this_110.energyComplementWo_0;
}

fn MetalMultipleScatteringLobe_EstimateContribution_0( this_111 : MetalMultipleScatteringLobe_0,  wo_59 : vec3<f32>,  throughput_17 : vec3<f32>) -> f32
{
    var _S421 : f32;
    if(MetalMultipleScatteringLobe_Active_0(this_111))
    {
        _S421 = ThroughputWeightedMax_0(throughput_17, this_111.scale_0) * this_111.energyComplementWo_1;
    }
    else
    {
        _S421 = 0.0f;
    }
    return _S421;
}

fn BaseLobe_LobeEstimate_0( this_112 : BaseLobe_0,  index_16 : i32,  wo_60 : vec3<f32>,  throughput_18 : vec3<f32>) -> f32
{
    switch(index_16)
    {
    case i32(0):
        {
            return SpecularLobe_EstimateContribution_0(this_112.specular_0, wo_60, throughput_18);
        }
    case i32(1):
        {
            return DielectricMultipleScatteringLobe_EstimateContribution_0(this_112.dielectricMultipleScattering_0, wo_60, throughput_18);
        }
    case i32(2):
        {
            return MetalMultipleScatteringLobe_EstimateContribution_0(this_112.metalMultipleScattering_0, wo_60, throughput_18);
        }
    case i32(3):
        {
            return DiffuseLobe_EstimateContribution_0(this_112.diffuse_0, wo_60, throughput_18);
        }
    case i32(4):
        {
            return FlippedLobe_EstimateContribution_1(this_112.thinWallSpecularTransmission_0, wo_60, throughput_18);
        }
    default :
        {
            return FlippedLobe_EstimateContribution_0(this_112.thinWallDiffuseTransmission_0, wo_60, throughput_18);
        }
    }
}

fn BaseLobe_InitWeights_0( this_113 : ptr<function, BaseLobe_0>,  wo_61 : vec3<f32>,  throughput_19 : vec3<f32>)
{
    var _S422 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(0), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(0)] = _S422;
    if(BaseLobeEnabled_0(i32(1)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(1), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(1)] = _S422;
    if(BaseLobeEnabled_0(i32(2)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(2), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(2)] = _S422;
    if(BaseLobeEnabled_0(i32(3)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(3), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(3)] = _S422;
    if(BaseLobeEnabled_0(i32(4)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(4), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(4)] = _S422;
    if(BaseLobeEnabled_0(i32(5)))
    {
        _S422 = BaseLobe_LobeEstimate_0((*this_113), i32(5), wo_61, throughput_19);
    }
    else
    {
        _S422 = 0.0f;
    }
    (*this_113).weights_0[i32(5)] = _S422;
    return;
}

fn DielectricReflection_x24init_0( eta_12 : f32) -> DielectricReflection_0
{
    var _S423 : DielectricReflection_0;
    _S423.eta_2 = eta_12;
    return _S423;
}

fn PrepareLobes_0( inputs_3 : BSDFInputs_0,  derived_1 : VolumeDerived_0,  wo_62 : vec3<f32>,  throughput_20 : vec3<f32>,  wavelengths_2 : vec3<f32>,  exteriorIor_0 : f32) -> FuzzLobe_0
{
    var cosTheta_10 : f32 = dot(wo_62, inputs_3.basis_0.n_1);
    var backFacing_0 : bool = (cosTheta_10 < 0.0f);
    var inside_3 : bool;
    if(backFacing_0)
    {
        inside_3 = !inputs_3.geometryThinWalled_0;
    }
    else
    {
        inside_3 = false;
    }
    var specularBasis_0 : Frame_0 = Frame_RotatedAroundNormal_0(inputs_3.basis_0, inputs_3.specularAnisotropyRotation_0);
    var specularBasis_1 : Frame_0;
    if(backFacing_0)
    {
        specularBasis_1 = Frame_Inverted_0(specularBasis_0);
    }
    else
    {
        specularBasis_1 = specularBasis_0;
    }
    var _S424 : Frame_0 = specularBasis_1;
    var coatBasis_1 : Frame_0 = Frame_RotatedAroundNormal_0(inputs_3.coatBasis_0, inputs_3.coatAnisotropyRotation_0);
    var coatBasis_2 : Frame_0;
    if(((dot(wo_62, inputs_3.coatBasis_0.n_1)) < 0.0f))
    {
        coatBasis_2 = Frame_Inverted_0(coatBasis_1);
    }
    else
    {
        coatBasis_2 = coatBasis_1;
    }
    var _S425 : Frame_0 = coatBasis_2;
    var enterCoat_0 : bool;
    if(((inputs_3.coatWeight_0) > 0.0f))
    {
        enterCoat_0 = !inside_3;
    }
    else
    {
        enterCoat_0 = false;
    }
    var weightedCoatIor_0 : f32;
    if(enterCoat_0)
    {
        weightedCoatIor_0 = mix(exteriorIor_0, inputs_3.coatIor_0, inputs_3.coatWeight_0);
    }
    else
    {
        weightedCoatIor_0 = exteriorIor_0;
    }
    var weightedSpecularIor_0 : f32 = weightedCoatIor_0 * ApplySpecularWeightToIor_0(inputs_3.specularIor_0 / weightedCoatIor_0, inputs_3.specularWeight_0);
    var etaRefraction_0 : f32;
    var etaCoat_0 : f32;
    var etaOpaqueReflection_0 : f32;
    var etaTransReflection_0 : f32;
    if(inside_3)
    {
        var etaRefraction_1 : f32 = exteriorIor_0 / weightedSpecularIor_0;
        var _S426 : f32 = weightedSpecularIor_0 / exteriorIor_0;
        etaRefraction_0 = etaRefraction_1;
        etaCoat_0 = 1.0f;
        etaOpaqueReflection_0 = _S426;
        etaTransReflection_0 = etaRefraction_1;
    }
    else
    {
        var etaRefraction_2 : f32 = weightedSpecularIor_0 / exteriorIor_0;
        if(enterCoat_0)
        {
            if((weightedCoatIor_0 > weightedSpecularIor_0))
            {
                enterCoat_0 = (weightedSpecularIor_0 >= exteriorIor_0);
            }
            else
            {
                enterCoat_0 = false;
            }
            if(enterCoat_0)
            {
                etaRefraction_0 = weightedCoatIor_0 / weightedSpecularIor_0;
            }
            else
            {
                etaRefraction_0 = weightedSpecularIor_0 / weightedCoatIor_0;
            }
            etaCoat_0 = inputs_3.coatIor_0 / exteriorIor_0;
        }
        else
        {
            etaRefraction_0 = etaRefraction_2;
            etaCoat_0 = 1.0f;
        }
        var _S427 : f32 = etaRefraction_0;
        var _S428 : f32 = etaRefraction_0;
        etaRefraction_0 = etaRefraction_2;
        etaOpaqueReflection_0 = _S428;
        etaTransReflection_0 = _S427;
    }
    if((etaRefraction_0 >= 1.0f))
    {
        etaRefraction_0 = max(etaRefraction_0, 1.0001000165939331f);
    }
    else
    {
        etaRefraction_0 = min(etaRefraction_0, 0.99989998340606689f);
    }
    var coatRoughness_1 : f32 = mix(inputs_3.coatRoughness_0, FourthRoot_0(min(1.0f, FourthPower_0(inputs_3.coatRoughness_0) + Average_0(inputs_3.fuzzColor_0) * inputs_3.fuzzRoughness_0 * 0.004999999888241291f * FourthPower_0(inputs_3.fuzzRoughness_0))), inputs_3.fuzzWeight_0);
    var dispersion_2 : f32;
    if((etaCoat_0 >= 1.0f))
    {
        dispersion_2 = 1.0f / etaCoat_0;
    }
    else
    {
        dispersion_2 = etaCoat_0;
    }
    var specularRoughness_1 : f32 = mix(inputs_3.specularRoughness_0, FourthRoot_0(min(1.0f, FourthPower_0(inputs_3.specularRoughness_0) + mix(1.0f, 0.0f, dispersion_2) * FourthPower_0(coatRoughness_1))), inputs_3.coatWeight_0);
    var specularAlpha_3 : f32 = Square_0(specularRoughness_1);
    var anisotropicSpecularAlpha_0 : vec2<f32> = AnisotropicAlpha_0(specularAlpha_3, inputs_3.specularRoughnessAnisotropy_0);
    var coatAlpha_0 : f32 = Square_0(coatRoughness_1);
    var anisotropicCoatAlpha_0 : vec2<f32> = AnisotropicAlpha_0(coatAlpha_0, inputs_3.coatRoughnessAnisotropy_0);
    var nonTrans_0 : f32 = 1.0f - inputs_3.transmissionWeight_0;
    var dielectric_1 : f32 = 1.0f - inputs_3.baseMetalness_0;
    var opaqueDielectric_0 : f32 = nonTrans_0 * (1.0f - inputs_3.subsurfaceWeight_0) * dielectric_1;
    var trans_0 : f32 = dielectric_1 * inputs_3.transmissionWeight_0;
    var sss_0 : f32 = nonTrans_0 * dielectric_1 * inputs_3.subsurfaceWeight_0;
    if(inputs_3.specularDielectricOnly_0)
    {
        dispersion_2 = 1.0f;
    }
    else
    {
        dispersion_2 = inputs_3.specularWeight_0;
    }
    var darkenedMetal_0 : f32 = inputs_3.baseMetalness_0 * dispersion_2;
    var metalF82Tint_2 : vec3<f32>;
    if(inputs_3.specularDielectricOnly_0)
    {
        metalF82Tint_2 = vec3<f32>(1.0f);
    }
    else
    {
        metalF82Tint_2 = inputs_3.specularColor_0;
    }
    var weightedBaseColor_0 : vec3<f32> = inputs_3.baseColor_0 * vec3<f32>(inputs_3.baseWeight_0);
    var _S429 : vec3<f32> = AverageFresnelMetalF82_0(weightedBaseColor_0, metalF82Tint_2);
    var kSmooth_0 : f32 = AverageFresnel_0(etaCoat_0);
    var specularityOpaqueDielectric_0 : f32 = AverageFresnel_0(etaOpaqueReflection_0);
    var k_2 : f32 = mix(kSmooth_0, 1.0f - (1.0f - kSmooth_0) / Square_0(etaCoat_0), mix(1.0f, specularRoughness_1, opaqueDielectric_0 * specularityOpaqueDielectric_0 + (sss_0 + trans_0) * AverageFresnel_0(etaTransReflection_0) + inputs_3.baseMetalness_0));
    var _S430 : vec3<f32> = vec3<f32>(darkenedMetal_0);
    var _S431 : vec3<f32> = vec3<f32>(1.0f);
    var _S432 : vec3<f32> = vec3<f32>(opaqueDielectric_0);
    var _S433 : vec3<f32> = vec3<f32>(sss_0);
    var albedoTrans_0 : vec3<f32> = vec3<f32>(trans_0);
    var coatDarkening_1 : vec3<f32> = mix(_S431, vec3<f32>((1.0f - k_2)) / (_S431 - (_S430 * _S429 + _S432 * mix(weightedBaseColor_0, _S431, vec3<f32>(specularityOpaqueDielectric_0)) + _S433 * inputs_3.subsurfaceColor_0 + albedoTrans_0) * vec3<f32>(k_2)), vec3<f32>((inputs_3.coatWeight_0 * inputs_3.coatDarkening_0)));
    var distribution_6 : GGXDistribution_0 = GGXDistribution_x24init_0(anisotropicSpecularAlpha_0, specularBasis_1, specularAlpha_3);
    var transIncludingSss_0 : f32 = trans_0 + sss_0;
    var scaleOpaqueReflection_0 : vec3<f32> = inputs_3.specularColor_0 * _S432;
    var thinWallSpecularTransmissionAlbedoScale_0 : vec3<f32>;
    var thinWallAwareScaleTransReflection_0 : vec3<f32>;
    var scaleTransReflection_0 : vec3<f32>;
    if(inside_3)
    {
        var scaleTransReflection_1 : vec3<f32> = vec3<f32>(transIncludingSss_0);
        thinWallSpecularTransmissionAlbedoScale_0 = vec3<f32>(0.0f);
        thinWallAwareScaleTransReflection_0 = scaleTransReflection_1;
        scaleTransReflection_0 = scaleTransReflection_1;
    }
    else
    {
        var scaleTransReflection_2 : vec3<f32> = inputs_3.specularColor_0 * vec3<f32>(transIncludingSss_0);
        if(inputs_3.geometryThinWalled_0)
        {
            var _S434 : vec3<f32> = inputs_3.specularColor_0 * _S433;
            thinWallSpecularTransmissionAlbedoScale_0 = inputs_3.specularColor_0 * albedoTrans_0;
            thinWallAwareScaleTransReflection_0 = _S434;
        }
        else
        {
            thinWallSpecularTransmissionAlbedoScale_0 = vec3<f32>(0.0f);
            thinWallAwareScaleTransReflection_0 = scaleTransReflection_2;
        }
        scaleTransReflection_0 = scaleTransReflection_2;
    }
    var etaRefractionRGB_0 : vec3<f32> = vec3<f32>(etaRefraction_0);
    var etaTransReflectionRGB_0 : vec3<f32> = vec3<f32>(etaTransReflection_0);
    var etaOpaqueReflectionRGB_0 : vec3<f32> = vec3<f32>(etaOpaqueReflection_0);
    if(BSDFInputs_HasDispersion_0(inputs_3))
    {
        var _S435 : f32 = SafeDivide_0(20.0f, SafeDivide_0(inputs_3.transmissionDispersionAbbeNumber_0, inputs_3.transmissionDispersionScale_0, 0.0f), 0.0f);
        etaRefractionRGB_0[i32(0)] = DispersionAdjustedIor_0(etaRefraction_0, _S435, wavelengths_2[i32(0)]);
        var _S436 : bool = etaTransReflection_0 == etaRefraction_0;
        if(_S436)
        {
            dispersion_2 = etaRefractionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S435, wavelengths_2[i32(0)]);
        }
        etaTransReflectionRGB_0[i32(0)] = dispersion_2;
        var _S437 : bool = etaOpaqueReflection_0 == etaTransReflection_0;
        if(_S437)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S435, wavelengths_2[i32(0)]);
        }
        etaOpaqueReflectionRGB_0[i32(0)] = dispersion_2;
        etaRefractionRGB_0[i32(1)] = DispersionAdjustedIor_0(etaRefraction_0, _S435, wavelengths_2[i32(1)]);
        if(_S436)
        {
            dispersion_2 = etaRefractionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S435, wavelengths_2[i32(1)]);
        }
        etaTransReflectionRGB_0[i32(1)] = dispersion_2;
        if(_S437)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S435, wavelengths_2[i32(1)]);
        }
        etaOpaqueReflectionRGB_0[i32(1)] = dispersion_2;
        etaRefractionRGB_0[i32(2)] = DispersionAdjustedIor_0(etaRefraction_0, _S435, wavelengths_2[i32(2)]);
        if(_S436)
        {
            dispersion_2 = etaRefractionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S435, wavelengths_2[i32(2)]);
        }
        etaTransReflectionRGB_0[i32(2)] = dispersion_2;
        if(_S437)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S435, wavelengths_2[i32(2)]);
        }
        etaOpaqueReflectionRGB_0[i32(2)] = dispersion_2;
        dispersion_2 = _S435;
    }
    else
    {
        dispersion_2 = 0.0f;
    }
    var nonThinWallWeight_0 : f32;
    if(inputs_3.geometryThinWalled_0)
    {
        nonThinWallWeight_0 = 0.0f;
    }
    else
    {
        nonThinWallWeight_0 = 1.0f;
    }
    var thinWallAwareCosTheta_0 : f32;
    if(inputs_3.geometryThinWalled_0)
    {
        thinWallAwareCosTheta_0 = abs(cosTheta_10);
    }
    else
    {
        thinWallAwareCosTheta_0 = cosTheta_10;
    }
    var tintedTrans_0 : vec3<f32> = albedoTrans_0 * FinalTransmissionTint_0(derived_1.transmissionTint_0, inputs_3.geometryThinWalled_0, thinWallAwareCosTheta_0, etaRefraction_0);
    var tintedTransIncludingSss_0 : vec3<f32> = tintedTrans_0 + _S433;
    var thinWallAwareTintedTransIncludingSss_0 : vec3<f32> = vec3<f32>(nonThinWallWeight_0) * tintedTransIncludingSss_0;
    var thinFilmInteriorIor_1 : vec3<f32>;
    var thinFilmExteriorIor_1 : f32;
    if(inside_3)
    {
        thinFilmInteriorIor_1 = vec3<f32>(weightedCoatIor_0);
        thinFilmExteriorIor_1 = weightedSpecularIor_0;
    }
    else
    {
        thinFilmInteriorIor_1 = vec3<f32>(weightedSpecularIor_0);
        if((dispersion_2 > 0.0f))
        {
            thinFilmInteriorIor_1[i32(0)] = DispersionAdjustedIor_0(thinFilmInteriorIor_1[i32(0)], dispersion_2, wavelengths_2[i32(0)]);
            thinFilmInteriorIor_1[i32(1)] = DispersionAdjustedIor_0(thinFilmInteriorIor_1[i32(1)], dispersion_2, wavelengths_2[i32(1)]);
            thinFilmInteriorIor_1[i32(2)] = DispersionAdjustedIor_0(thinFilmInteriorIor_1[i32(2)], dispersion_2, wavelengths_2[i32(2)]);
        }
        thinFilmExteriorIor_1 = weightedCoatIor_0;
    }
    var _S438 : vec3<f32> = vec3<f32>(0.0f);
    var thinWallSpecularReflectionAlbedo_0 : vec3<f32>;
    var thinWallSpecularTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var _S439 : vec3<f32> = tintedTrans_0 * vec3<f32>((1.0f - ThinWallFresnel_0(etaRefraction_0, thinWallAwareCosTheta_0)));
        thinWallSpecularReflectionAlbedo_0 = thinWallSpecularTransmissionAlbedoScale_0 * vec3<f32>(ThinWallFresnel_0(etaTransReflection_0, thinWallAwareCosTheta_0));
        thinWallSpecularTransmissionAlbedo_0 = _S439;
    }
    else
    {
        thinWallSpecularReflectionAlbedo_0 = _S438;
        thinWallSpecularTransmissionAlbedo_0 = _S438;
    }
    var thinWallSubsurfaceReflectionAlbedo_0 : vec3<f32>;
    var thinWallSubsurfaceTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var transmissionProportion_0 : f32 = (derived_1.thinWallSubsurfaceAnisotropy_0 + 1.0f) * 0.5f;
        var subsurfaceAlbedo_0 : vec3<f32> = _S433 * derived_1.thinWallSubsurfaceColor_0;
        var _S440 : vec3<f32> = subsurfaceAlbedo_0 * vec3<f32>(transmissionProportion_0);
        thinWallSubsurfaceReflectionAlbedo_0 = subsurfaceAlbedo_0 * vec3<f32>((1.0f - transmissionProportion_0));
        thinWallSubsurfaceTransmissionAlbedo_0 = _S440;
    }
    else
    {
        thinWallSubsurfaceReflectionAlbedo_0 = _S438;
        thinWallSubsurfaceTransmissionAlbedo_0 = _S438;
    }
    var coefficient_5 : BaseReflectionTransmission_0;
    coefficient_5.etaTransparent_0 = etaTransReflectionRGB_0;
    coefficient_5.etaOpaque_0 = etaOpaqueReflectionRGB_0;
    coefficient_5.reflectionScaleTransparent_0 = thinWallAwareScaleTransReflection_0;
    coefficient_5.reflectionScaleOpaque_0 = scaleOpaqueReflection_0;
    coefficient_5.transmission_0 = thinWallAwareTintedTransIncludingSss_0;
    coefficient_5.metalF0_0 = weightedBaseColor_0;
    coefficient_5.metalF82Tint_0 = metalF82Tint_2;
    coefficient_5.metalAmount_0 = darkenedMetal_0;
    coefficient_5.thinFilmWeight_1 = inputs_3.thinFilmWeight_0;
    coefficient_5.thinFilmThickness_1 = inputs_3.thinFilmThickness_0 * 1000.0f;
    coefficient_5.thinFilmExteriorIor_0 = thinFilmExteriorIor_1;
    coefficient_5.thinFilmIor_1 = inputs_3.thinFilmIor_0;
    coefficient_5.thinFilmInteriorIor_0 = thinFilmInteriorIor_1;
    coefficient_5.wavelengths_0 = wavelengths_2;
    coefficient_5.thinWallReflection_0 = thinWallSpecularReflectionAlbedo_0;
    var base_18 : BaseLobe_0;
    base_18.specular_0 = SpecularLobe_x24init_0(_S424.n_1, distribution_6, coefficient_5, etaRefractionRGB_0, throughput_20);
    base_18.dielectricMultipleScattering_0 = DielectricMultipleScatteringLobe_x24init_0(_S424.n_1, wo_62, specularAlpha_3, etaRefraction_0, scaleTransReflection_0, tintedTransIncludingSss_0);
    base_18.metalMultipleScattering_0 = MetalMultipleScatteringLobe_x24init_0(_S424.n_1, wo_62, specularAlpha_3, Square_1(_S429) * _S430);
    base_18.diffuse_0 = DiffuseLobe_x24init_0(_S424.n_1, wo_62, weightedBaseColor_0 * _S432 + thinWallSubsurfaceReflectionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    base_18.thinWallSpecularTransmission_0 = MakeThinWallSpecularTransmissionLobe_0(_S424.n_1, distribution_6, thinWallSpecularTransmissionAlbedo_0);
    base_18.thinWallDiffuseTransmission_0 = MakeThinWallDiffuseTransmissionLobe_0(_S424.n_1, wo_62, thinWallSubsurfaceTransmissionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    BaseLobe_InitWeights_0(&(base_18), wo_62, throughput_20);
    var coat_0 : CoatLobe_0 = CoatLobe_x24init_0(base_18, MicrofacetReflectionLobe_x24init_0(_S425.n_1, GGXDistribution_x24init_0(anisotropicCoatAlpha_0, coatBasis_2, coatAlpha_0), DielectricReflection_x24init_0(etaCoat_0)), _S425.n_1, wo_62, inputs_3.coatColor_0, inputs_3.coatWeight_0, coatDarkening_1, inside_3);
    var fuzzNormal_0 : vec3<f32> = normalize(mix(_S424.n_1, _S425.n_1, vec3<f32>(inputs_3.coatWeight_0)));
    if(inside_3)
    {
        weightedCoatIor_0 = 0.0f;
    }
    else
    {
        weightedCoatIor_0 = inputs_3.fuzzWeight_0;
    }
    return FuzzLobe_x24init_0(coat_0, fuzzNormal_0, wo_62, inputs_3.fuzzRoughness_0, inputs_3.fuzzColor_0, weightedCoatIor_0);
}

fn ComputeEmission_0( inputs_4 : BSDFInputs_0,  wo_63 : vec3<f32>,  lobes_0 : FuzzLobe_0) -> vec3<f32>
{
    var inside_4 : bool;
    if((inputs_4.emissionLuminance_0) == 0.0f)
    {
        inside_4 = true;
    }
    else
    {
        inside_4 = (all(((inputs_4.emissionColor_0) == vec3<f32>(0.0f))));
    }
    if(inside_4)
    {
        return vec3<f32>(0.0f);
    }
    if(((dot(wo_63, inputs_4.basis_0.n_1)) < 0.0f))
    {
        inside_4 = !inputs_4.geometryThinWalled_0;
    }
    else
    {
        inside_4 = false;
    }
    if(inside_4)
    {
        return vec3<f32>(0.0f);
    }
    var result_4 : vec3<f32> = vec3<f32>(inputs_4.emissionLuminance_0) * inputs_4.emissionColor_0;
    var result_5 : vec3<f32>;
    if(((inputs_4.coatWeight_0) > 0.0f))
    {
        result_5 = result_4 * lobes_0.base_4.inBaseLayerScale_0;
    }
    else
    {
        result_5 = result_4;
    }
    if(((inputs_4.fuzzWeight_0) > 0.0f))
    {
        result_5 = result_5 * vec3<f32>(FuzzLobe_BaseLayerScaleIncoming_0(lobes_0));
    }
    return result_5;
}

struct BSDF_0
{
     volume_0 : HomogeneousVolume_0,
     emission_1 : vec3<f32>,
     lobes_1 : FuzzLobe_0,
     wo_64 : vec3<f32>,
};

fn BSDF_x24init_0( inputs_5 : BSDFInputs_0,  wo_65 : vec3<f32>,  throughput_21 : vec3<f32>,  wavelengths_3 : vec3<f32>,  exteriorIor_1 : f32) -> BSDF_0
{
    var _S441 : BSDF_0;
    _S441.wo_64 = wo_65;
    var derived_2 : VolumeDerived_0;
    var _S442 : HomogeneousVolume_0 = PrepareVolume_0(inputs_5, &(derived_2));
    _S441.volume_0 = _S442;
    var _S443 : FuzzLobe_0 = PrepareLobes_0(inputs_5, derived_2, wo_65, throughput_21, wavelengths_3, exteriorIor_1);
    _S441.lobes_1 = _S443;
    _S441.emission_1 = ComputeEmission_0(inputs_5, wo_65, _S443);
    return _S441;
}

fn EmissiveSolidAnglePdf_0( area_0 : f32,  doubleSided_1 : bool,  viewer_0 : vec3<f32>,  lightPos_0 : vec3<f32>,  lightNormal_0 : vec3<f32>) -> f32
{
    var toLight_0 : vec3<f32> = lightPos_0 - viewer_0;
    var distSq_2 : f32 = dot(toLight_0, toLight_0);
    if((distSq_2 <= 9.999999960041972e-13f))
    {
        return 0.0f;
    }
    var cosTheta_11 : f32 = dot(lightNormal_0, (vec3<f32>(0) - toLight_0 * vec3<f32>(rsqrt_0(distSq_2))));
    var cosTheta_12 : f32;
    if(doubleSided_1)
    {
        cosTheta_12 = abs(cosTheta_11);
    }
    else
    {
        cosTheta_12 = cosTheta_11;
    }
    if((cosTheta_12 <= 9.99999997475242708e-07f))
    {
        return 0.0f;
    }
    return distSq_2 / (cosTheta_12 * area_0);
}

fn RandomSequence_x24init_1( positionSeed_0 : u32,  timeSeed_1 : u32) -> RandomSequence_0
{
    var _S444 : RandomSequence_0;
    _S444.seed_1 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_1));
    return _S444;
}

fn BaseLobe_MaxActiveAlpha_0( this_114 : BaseLobe_0) -> f32
{
    var _S445 : bool;
    if(BaseLobe_IsActive_0(this_114, i32(3)))
    {
        _S445 = true;
    }
    else
    {
        _S445 = BaseLobe_IsActive_0(this_114, i32(5));
    }
    if(_S445)
    {
        _S445 = true;
    }
    else
    {
        _S445 = BaseLobe_IsActive_0(this_114, i32(1));
    }
    if(_S445)
    {
        _S445 = true;
    }
    else
    {
        _S445 = BaseLobe_IsActive_0(this_114, i32(2));
    }
    if(_S445)
    {
        return 1.0f;
    }
    if(BaseLobe_IsActive_0(this_114, i32(0)))
    {
        _S445 = true;
    }
    else
    {
        _S445 = BaseLobe_IsActive_0(this_114, i32(4));
    }
    if(_S445)
    {
        return max(this_114.specular_0.distribution_0.alpha_0.x, this_114.specular_0.distribution_0.alpha_0.y);
    }
    return 0.0f;
}

fn BSDF_MaxActiveAlpha_0( this_115 : BSDF_0) -> f32
{
    var baseAlpha_0 : f32 = BaseLobe_MaxActiveAlpha_0(this_115.lobes_1.base_4.base_3);
    var _S446 : f32;
    if(FuzzLobe_HasFuzz_0(this_115.lobes_1))
    {
        _S446 = 1.0f;
    }
    else
    {
        _S446 = max(baseAlpha_0, CoatLobe_MaxActiveAlpha_0(this_115.lobes_1.base_4));
    }
    return _S446;
}

fn SearchCdfRow_0( row_2 : u32,  count_0 : u32,  u_25 : f32) -> u32
{
    var hi_0 : u32 = count_0;
    var lo_0 : u32 = u32(0);
    loop
    {
        if(((hi_0 - lo_0) > u32(1)))
        {
        }
        else
        {
            break;
        }
        var mid_0 : u32 = ((lo_0 + hi_0) >> (u32(1)));
        if(((EnvCdf_0(mid_0, row_2)) <= u_25))
        {
            lo_0 = mid_0;
        }
        else
        {
            hi_0 = mid_0;
        }
    }
    return lo_0;
}

fn EquirectUVToDirection_0( uv_4 : vec2<f32>,  cosElevation_0 : ptr<function, f32>) -> vec3<f32>
{
    var PI_4 : f32 = float_getPi_0();
    var azimuth_2 : f32 = (uv_4.x + 0.25f) * (2.0f * PI_4);
    var elevation_1 : f32 = (0.5f - uv_4.y) * PI_4;
    var _S447 : f32 = cos(elevation_1);
    (*cosElevation_0) = _S447;
    return vec3<f32>(cos(azimuth_2) * _S447, sin(elevation_1), sin(azimuth_2) * _S447);
}

struct LightSample_0
{
     position_2 : vec3<f32>,
     normal_20 : vec3<f32>,
     radiance_4 : vec3<f32>,
     solidAnglePdf_0 : f32,
     delta_0 : bool,
     shadow_0 : bool,
};

fn SampleEnvironment_0( rng_2 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_22 : LightSample_0;
    s_22.position_2 = vec3<f32>(0.0f);
    s_22.delta_0 = false;
    s_22.shadow_0 = true;
    var u_26 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_2)));
    var dir_8 : vec3<f32>;
    if((((gFrame_0.settings_0.z) & (u32(4)))) == u32(0))
    {
        var z_10 : f32 = 1.0f - 2.0f * u_26.x;
        var r_9 : f32 = sqrt(max(0.0f, 1.0f - z_10 * z_10));
        var PI_5 : f32 = float_getPi_0();
        var phi_1 : f32 = 2.0f * PI_5 * u_26.y;
        var _S448 : vec3<f32> = vec3<f32>(r_9 * cos(phi_1), r_9 * sin(phi_1), z_10);
        s_22.solidAnglePdf_0 = 1.0f / (4.0f * PI_5);
        dir_8 = _S448;
    }
    else
    {
        var W_1 : u32 = gFrame_0.envInfo_0.x;
        var H_1 : u32 = gFrame_0.envInfo_0.y;
        var _S449 : f32 = u_26.y;
        var y_12 : u32 = SearchCdfRow_0(H_1, H_1, _S449);
        var cy0_0 : f32 = EnvCdf_0(y_12, H_1);
        var cy1_0 : f32 = EnvCdf_0(y_12 + u32(1), H_1);
        var dv_0 : f32;
        if((cy1_0 > cy0_0))
        {
            dv_0 = (_S449 - cy0_0) / (cy1_0 - cy0_0);
        }
        else
        {
            dv_0 = 0.5f;
        }
        var _S450 : f32 = u_26.x;
        var x_31 : u32 = SearchCdfRow_0(y_12, W_1, _S450);
        var cx0_0 : f32 = EnvCdf_0(x_31, y_12);
        var cx1_0 : f32 = EnvCdf_0(x_31 + u32(1), y_12);
        var du_0 : f32;
        if((cx1_0 > cx0_0))
        {
            du_0 = (_S450 - cx0_0) / (cx1_0 - cx0_0);
        }
        else
        {
            du_0 = 0.5f;
        }
        var _S451 : f32 = f32(H_1);
        var _S452 : f32 = f32(W_1);
        var pdfUV_0 : f32 = (cy1_0 - cy0_0) * _S451 * (cx1_0 - cx0_0) * _S452;
        var cosElevation_1 : f32;
        var local_4 : vec3<f32> = EquirectUVToDirection_0(vec2<f32>((f32(x_31) + du_0) / _S452, (f32(y_12) + dv_0) / _S451), &(cosElevation_1));
        var _S453 : vec3<f32> = RotateY_0(local_4, gFrame_0.envParams_0.y);
        var PI_6 : f32 = float_getPi_0();
        s_22.solidAnglePdf_0 = pdfUV_0 / (2.0f * PI_6 * PI_6 * max(cosElevation_1, 9.99999997475242708e-07f));
        dir_8 = _S453;
    }
    s_22.normal_20 = (vec3<f32>(0) - dir_8);
    s_22.radiance_4 = EvalEnvironment_0(dir_8);
    return s_22;
}

fn ComputeOffsetOrigin_0( pos_0 : vec3<f32>,  normal_21 : vec3<f32>) -> vec3<f32>
{
    var _S454 : vec3<i32> = vec3<i32>(normal_21 * vec3<f32>(768.0f));
    var _S455 : vec3<i32> = (bitcast<vec3<i32>>((pos_0)));
    var _S456 : f32 = pos_0.x;
    var _S457 : i32;
    if((_S456 < 0.0f))
    {
        _S457 = - _S454.x;
    }
    else
    {
        _S457 = _S454.x;
    }
    var _S458 : f32 = pos_0.y;
    var _S459 : i32;
    if((_S458 < 0.0f))
    {
        _S459 = - _S454.y;
    }
    else
    {
        _S459 = _S454.y;
    }
    var _S460 : f32 = pos_0.z;
    var _S461 : i32;
    if((_S460 < 0.0f))
    {
        _S461 = - _S454.z;
    }
    else
    {
        _S461 = _S454.z;
    }
    var pI_0 : vec3<f32> = (bitcast<vec3<f32>>((_S455 + vec3<i32>(_S457, _S459, _S461))));
    var fOff_0 : vec3<f32> = normal_21 * vec3<f32>(4.57763671875e-05f);
    var _S462 : f32;
    if(((abs(_S456)) < 0.0625f))
    {
        _S462 = _S456 + fOff_0.x;
    }
    else
    {
        _S462 = pI_0.x;
    }
    var _S463 : f32;
    if(((abs(_S458)) < 0.0625f))
    {
        _S463 = _S458 + fOff_0.y;
    }
    else
    {
        _S463 = pI_0.y;
    }
    var _S464 : f32;
    if(((abs(_S460)) < 0.0625f))
    {
        _S464 = _S460 + fOff_0.z;
    }
    else
    {
        _S464 = pI_0.z;
    }
    return vec3<f32>(_S462, _S463, _S464);
}

fn ShadowOrigin_0( si_2 : SurfaceInteraction_0,  dir_9 : vec3<f32>) -> vec3<f32>
{
    var _S465 : vec3<f32>;
    if(((dot(si_2.faceNormal_0, dir_9)) >= 0.0f))
    {
        _S465 = si_2.faceNormal_0;
    }
    else
    {
        _S465 = (vec3<f32>(0) - si_2.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(si_2.position_1, _S465);
}

fn LightCount_0() -> u32
{
    return gFrame_0.counts_0.y;
}

fn SelectLight_0( u_27 : f32) -> u32
{
    var _S466 : u32 = LightCount_0() - u32(1);
    var lo_1 : u32 = u32(0);
    var hi_1 : u32 = _S466;
    loop
    {
        if((lo_1 < hi_1))
        {
        }
        else
        {
            break;
        }
        var mid_1 : u32 = ((lo_1 + hi_1) >> (u32(1)));
        if(((gLights_0[mid_1].p2_0.w) > u_27))
        {
            hi_1 = mid_1;
        }
        else
        {
            lo_1 = mid_1 + u32(1);
        }
    }
    return lo_1;
}

fn AreaLightPoint_0( light_2 : ptr<function, EmissiveTriangle_std430_0>,  u_28 : vec2<f32>) -> vec3<f32>
{
    var _S467 : u32 = AnalyticFlags_0(&((*light_2)));
    var d_11 : vec2<f32>;
    if(((_S467 & (u32(512)))) != u32(0))
    {
        d_11 = SampleDisk_0(u_28) * vec2<f32>(0.5f);
    }
    else
    {
        d_11 = u_28 - vec2<f32>(0.5f);
    }
    return (*light_2).p0_0.xyz + (*light_2).n_0.xyz * vec3<f32>(d_11.x) + (*light_2).uvA_0.xyz * vec3<f32>(d_11.y);
}

fn SampleAnalytic_0( light_3 : ptr<function, EmissiveTriangle_std430_0>,  viewer_1 : vec3<f32>,  rng_3 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_23 : LightSample_0;
    s_23.delta_0 = false;
    s_23.radiance_4 = vec3<f32>(0.0f);
    s_23.solidAnglePdf_0 = 0.0f;
    var _S468 : u32 = AnalyticFlags_0(&((*light_3)));
    s_23.shadow_0 = ((_S468 & (u32(1024)))) == u32(0);
    var u_29 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_3)));
    if(((_S468 & (u32(255)))) == u32(2))
    {
        var _S469 : vec3<f32> = AreaLightPoint_0(&((*light_3)), u_29);
        s_23.position_2 = _S469;
        var _S470 : vec3<f32> = (*light_3).p2_0.xyz;
        s_23.normal_20 = _S470;
        var toLight_1 : vec3<f32> = _S469 - viewer_1;
        var distSq_3 : f32 = dot(toLight_1, toLight_1);
        var cosTheta_13 : f32 = - dot(_S470, toLight_1) * rsqrt_0(max(distSq_3, 9.99999968265522539e-21f));
        if((cosTheta_13 > 9.99999997475242708e-07f))
        {
            s_23.radiance_4 = (*light_3).p1_0.xyz;
            s_23.solidAnglePdf_0 = (*light_3).p1_0.w * distSq_3 / (cosTheta_13 * (*light_3).p0_0.w);
        }
        return s_23;
    }
    var _S471 : vec3<f32> = (*light_3).p0_0.xyz;
    var toCenter_1 : vec3<f32> = _S471 - viewer_1;
    var distSq_4 : f32 = dot(toCenter_1, toCenter_1);
    var w_1 : vec3<f32> = toCenter_1 / vec3<f32>(max(sqrt(distSq_4), 9.99999968265522539e-21f));
    var radius_4 : f32 = (*light_3).p0_0.w;
    if((radius_4 <= 0.0f))
    {
        s_23.position_2 = _S471;
        var _S472 : vec3<f32> = (vec3<f32>(0) - w_1);
        s_23.normal_20 = _S472;
        var _S473 : vec4<f32> = (*light_3).p1_0;
        var _S474 : vec3<f32> = (*light_3).p1_0.xyz;
        var _S475 : f32 = SpotAttenuation_0(&((*light_3)), _S472);
        s_23.radiance_4 = _S474 * vec3<f32>(_S475) / vec3<f32>(max(distSq_4, 9.99999968265522539e-21f));
        s_23.solidAnglePdf_0 = _S473.w;
        s_23.delta_0 = true;
        return s_23;
    }
    var oneMinusCosMax_0 : f32 = SphereOneMinusCos_0(radius_4, distSq_4);
    if((oneMinusCosMax_0 <= 0.0f))
    {
        s_23.position_2 = _S471;
        s_23.normal_20 = (vec3<f32>(0) - w_1);
        return s_23;
    }
    var oneMinusCos_1 : f32 = u_29.x * oneMinusCosMax_0;
    var cosTheta_14 : f32 = 1.0f - oneMinusCos_1;
    var sinTheta_1 : f32 = sqrt(max(0.0f, oneMinusCos_1 * (2.0f - oneMinusCos_1)));
    var TWO_PI_1 : f32 = 2.0f * float_getPi_0();
    var phi_2 : f32 = TWO_PI_1 * u_29.y;
    var t_13 : vec3<f32>;
    var b_15 : vec3<f32>;
    BranchlessONB_1(w_1, &(t_13), &(b_15));
    var dir_10 : vec3<f32> = (t_13 * vec3<f32>(cos(phi_2)) + b_15 * vec3<f32>(sin(phi_2))) * vec3<f32>(sinTheta_1) + w_1 * vec3<f32>(cosTheta_14);
    var tc_6 : f32 = dot(toCenter_1, dir_10);
    var _S476 : vec3<f32> = viewer_1 + dir_10 * vec3<f32>((tc_6 - sqrt(max(0.0f, radius_4 * radius_4 - (distSq_4 - tc_6 * tc_6)))));
    s_23.position_2 = _S476;
    s_23.normal_20 = normalize(_S476 - _S471);
    var _S477 : vec4<f32> = (*light_3).p1_0;
    var _S478 : vec3<f32> = (*light_3).p1_0.xyz;
    var _S479 : f32 = SpotAttenuation_0(&((*light_3)), (vec3<f32>(0) - w_1));
    s_23.radiance_4 = _S478 * vec3<f32>(_S479);
    s_23.solidAnglePdf_0 = _S477.w / (TWO_PI_1 * oneMinusCosMax_0);
    return s_23;
}

fn SampleTriangle_0( u_30 : vec2<f32>) -> vec3<f32>
{
    var su_0 : f32 = sqrt(u_30.x);
    var _S480 : f32 = u_30.y;
    return vec3<f32>(1.0f - su_0, su_0 * (1.0f - _S480), su_0 * _S480);
}

fn EvalEmission_0( header_6 : MaterialHeader_0,  tc_7 : TextureCoords_0) -> vec3<f32>
{
    if((header_6.emission_0) == u32(4294967295))
    {
        return vec3<f32>(0.0f);
    }
    var o_54 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_6, header_6.emission_0, tc_7);
    return o_54.inputs_0.emissionColor_0 * vec3<f32>(o_54.inputs_0.emissionLuminance_0);
}

fn EmissiveRadiance_0( material_1 : MaterialHeader_0,  tc_8 : TextureCoords_0) -> vec3<f32>
{
    var _S481 : bool;
    if((MaterialHeader_AlphaMode_0(material_1)) == u32(1))
    {
        var _S482 : f32 = EvalOpacity_0(material_1, tc_8);
        _S481 = (_S482 < (material_1.alphaCutoff_0));
    }
    else
    {
        _S481 = false;
    }
    if(_S481)
    {
        return vec3<f32>(0.0f);
    }
    var _S483 : vec3<f32> = EvalEmission_0(material_1, tc_8);
    return _S483;
}

fn SampleEmissive_0( viewer_2 : vec3<f32>,  cone_0 : vec2<f32>,  rng_4 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_24 : LightSample_0;
    s_24.delta_0 = false;
    s_24.shadow_0 = true;
    var _S484 : f32 = RandomSequence_Next_0(&((*rng_4)));
    var _S485 : EmissiveTriangle_std430_0 = gLights_0[SelectLight_0(_S484)];
    var _S486 : u32 = AnalyticFlags_0(&(_S485));
    if(((_S486 & (u32(2147483648)))) != u32(0))
    {
        var _S487 : LightSample_0 = SampleAnalytic_0(&(_S485), viewer_2, &((*rng_4)));
        return _S487;
    }
    var _S488 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_4)));
    var bary_3 : vec3<f32> = SampleTriangle_0(_S488);
    var _S489 : vec4<f32> = _S485.p0_0;
    var _S490 : vec3<f32> = _S485.p0_0.xyz;
    var _S491 : f32 = bary_3.x;
    var _S492 : vec4<f32> = _S485.p1_0;
    var _S493 : vec3<f32> = _S485.p1_0.xyz;
    var _S494 : f32 = bary_3.y;
    var _S495 : vec3<f32> = _S485.p2_0.xyz;
    var _S496 : f32 = bary_3.z;
    var _S497 : vec3<f32> = _S490 * vec3<f32>(_S491) + _S493 * vec3<f32>(_S494) + _S495 * vec3<f32>(_S496);
    s_24.position_2 = _S497;
    s_24.normal_20 = _S485.n_0.xyz;
    var material_2 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S485.n_0.w))));
    var doubleSided_2 : bool = MaterialHeader_DoubleSided_0(material_2);
    var toLight_2 : vec3<f32> = _S497 - viewer_2;
    var dist_0 : f32 = length(toLight_2);
    var tc_9 : TextureCoords_0;
    var _S498 : vec2<f32> = _S485.uvA_0.xy;
    var _S499 : vec2<f32> = vec2<f32>(_S491);
    var _S500 : vec2<f32> = _S485.uvA_0.zw;
    var _S501 : vec2<f32> = vec2<f32>(_S494);
    var _S502 : vec2<f32> = _S485.uvB_0.xy;
    var _S503 : vec2<f32> = vec2<f32>(_S496);
    var _S504 : vec2<f32> = _S498 * _S499 + _S500 * _S501 + _S502 * _S503;
    var _S505 : vec2<f32> = _S485.uvB_0.zw;
    var _S506 : vec2<f32> = _S485.uvC_0.xy;
    var _S507 : vec2<f32> = _S485.uvC_0.zw;
    var _S508 : vec2<f32> = _S505 * _S499 + _S506 * _S501 + _S507 * _S503;
    var _S509 : vec3<f32> = _S493 - _S490;
    var _S510 : vec3<f32> = _S495 - _S490;
    var _S511 : vec2<f32> = _S500 - _S498;
    var _S512 : vec2<f32> = _S502 - _S498;
    var _S513 : vec2<f32> = _S506 - _S505;
    var _S514 : vec2<f32> = _S507 - _S505;
    var _S515 : f32 = cone_0.x + cone_0.y * dist_0;
    var _S516 : f32;
    if((dist_0 > 0.0f))
    {
        _S516 = dot(s_24.normal_20, toLight_2) / dist_0;
    }
    else
    {
        _S516 = 1.0f;
    }
    tc_9 = MakeTextureCoords_0(_S504, _S508, _S509, _S510, _S511, _S512, _S513, _S514, _S515, _S516);
    tc_9.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((_S485.pad_0.x))), s_24.position_2);
    var _S517 : vec3<f32> = EmissiveRadiance_0(material_2, tc_9);
    s_24.radiance_4 = _S517;
    s_24.solidAnglePdf_0 = _S492.w * EmissiveSolidAnglePdf_0(_S489.w, doubleSided_2, viewer_2, s_24.position_2, s_24.normal_20);
    var _S518 : bool;
    if(doubleSided_2)
    {
        _S518 = ((dot(s_24.normal_20, viewer_2 - s_24.position_2)) < 0.0f);
    }
    else
    {
        _S518 = false;
    }
    if(_S518)
    {
        s_24.normal_20 = (vec3<f32>(0) - s_24.normal_20);
    }
    return s_24;
}

fn SampleSun_0( rng_5 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var toSun_0 : vec3<f32> = gFrame_0.sunDirection_0.xyz;
    var t_14 : vec3<f32>;
    var b_16 : vec3<f32>;
    BranchlessONB_1(toSun_0, &(t_14), &(b_16));
    var _S519 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_5)));
    var disk_0 : vec2<f32> = SampleDisk_0(_S519);
    var dir_11 : vec3<f32> = normalize(toSun_0 + (t_14 * vec3<f32>(disk_0.x) + b_16 * vec3<f32>(disk_0.y)) * vec3<f32>(sqrt(max(0.0f, 1.0f - Square_0(gFrame_0.sunDirection_0.w)))));
    var s_25 : LightSample_0;
    s_25.position_2 = vec3<f32>(0.0f);
    s_25.normal_20 = (vec3<f32>(0) - dir_11);
    s_25.radiance_4 = gFrame_0.sunRadiance_0.xyz;
    s_25.solidAnglePdf_0 = 1.0f / gFrame_0.sunRadiance_0.w;
    s_25.delta_0 = false;
    s_25.shadow_0 = true;
    return s_25;
}

fn BSDF_EvalPdf_0( this_116 : BSDF_0,  wi_42 : vec3<f32>,  f_19 : ptr<function, DiffuseSpecular_0>,  pdf_17 : ptr<function, f32>)
{
    FuzzLobe_EvalPdf_1(this_116.lobes_1, this_116.wo_64, wi_42, SampledLobe_None_0(), &((*f_19)), &((*pdf_17)));
    return;
}

fn QueueDirectLighting_0( base_19 : u32,  si_3 : SurfaceInteraction_0,  bsdf_0 : BSDF_0,  cone_1 : vec2<f32>,  throughput_22 : vec3<f32>,  rng_6 : ptr<function, RandomSequence_0>)
{
    var maxDistance_0 : f32;
    gRayCone_0 = cone_1;
    var source_2 : u32 = u32(0);
    var mask_2 : u32 = u32(0);
    loop
    {
        if((source_2 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var mis_2 : bool;
        var shadow_1 : bool;
        var ls_0 : LightSample_0;
        var origin_8 : vec3<f32>;
        var dir_12 : vec3<f32>;
        if(source_2 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                source_2 = source_2 + u32(1);
                continue;
            }
            var ls_1 : LightSample_0 = SampleEnvironment_0(&((*rng_6)));
            if((any((((ls_1.radiance_4) > vec3<f32>(0.0f))))))
            {
                mis_2 = ((ls_1.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                mis_2 = false;
            }
            if(!mis_2)
            {
                source_2 = source_2 + u32(1);
                continue;
            }
            var dir_13 : vec3<f32> = (vec3<f32>(0) - ls_1.normal_20);
            var _S520 : vec3<f32> = ShadowOrigin_0(si_3, dir_13);
            mis_2 = true;
            ls_0 = ls_1;
            origin_8 = _S520;
            maxDistance_0 = 1.00000001504746622e+30f;
            shadow_1 = true;
            dir_12 = dir_13;
        }
        else
        {
            if(source_2 == u32(1))
            {
                if((LightCount_0()) == u32(0))
                {
                    source_2 = source_2 + u32(1);
                    continue;
                }
                var ls_2 : LightSample_0 = SampleEmissive_0(si_3.position_1, cone_1, &((*rng_6)));
                if((any((((ls_2.radiance_4) > vec3<f32>(0.0f))))))
                {
                    mis_2 = ((ls_2.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    mis_2 = false;
                }
                if(!mis_2)
                {
                    source_2 = source_2 + u32(1);
                    continue;
                }
                var lightPos_1 : vec3<f32> = ComputeOffsetOrigin_0(ls_2.position_2, ls_2.normal_20);
                var origin_9 : vec3<f32> = ShadowOrigin_0(si_3, lightPos_1 - si_3.position_1);
                var dir_14 : vec3<f32> = lightPos_1 - origin_9;
                var maxDistance_1 : f32 = length(dir_14);
                var dir_15 : vec3<f32> = dir_14 / vec3<f32>(maxDistance_1);
                mis_2 = !ls_2.delta_0;
                ls_0 = ls_2;
                origin_8 = origin_9;
                maxDistance_0 = maxDistance_1;
                shadow_1 = ls_2.shadow_0;
                dir_12 = dir_15;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    source_2 = source_2 + u32(1);
                    continue;
                }
                var ls_3 : LightSample_0 = SampleSun_0(&((*rng_6)));
                var dir_16 : vec3<f32> = (vec3<f32>(0) - ls_3.normal_20);
                var _S521 : vec3<f32> = ShadowOrigin_0(si_3, dir_16);
                mis_2 = false;
                ls_0 = ls_3;
                origin_8 = _S521;
                maxDistance_0 = 1.00000001504746622e+30f;
                shadow_1 = true;
                dir_12 = dir_16;
            }
        }
        var eval_0 : DiffuseSpecular_0;
        var pdf_18 : f32;
        BSDF_EvalPdf_0(bsdf_0, dir_12, &(eval_0), &(pdf_18));
        var f_20 : vec3<f32> = eval_0.diffuse_1 + eval_0.specular_1;
        var mask_3 : u32;
        if((any(((f_20 > vec3<f32>(0.0f))))))
        {
            var weight_3 : f32;
            if(mis_2)
            {
                weight_3 = EvalMISRobust_0(ls_0.solidAnglePdf_0, pdf_18);
            }
            else
            {
                weight_3 = 1.0f;
            }
            var offset_3 : u32 = u32(12) + source_2 * u32(3);
            gAccum_0[Field_0(base_19, offset_3)] = vec4<f32>(origin_8, maxDistance_0);
            gAccum_0[Field_0(base_19, offset_3 + u32(1))] = vec4<f32>(dir_12, (bitcast<f32>((select(u32(0), u32(1), shadow_1)))));
            gAccum_0[Field_0(base_19, offset_3 + u32(2))] = vec4<f32>(vec3<f32>(weight_3) * ls_0.radiance_4 * f_20 / vec3<f32>(ls_0.solidAnglePdf_0), 0.0f);
            mask_3 = (mask_2 | (((u32(1) << (source_2)))));
        }
        else
        {
            mask_3 = mask_2;
        }
        mask_2 = mask_3;
        source_2 = source_2 + u32(1);
    }
    if(((gWavefront_0.bounce_0) > u32(0)))
    {
        maxDistance_0 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    else
    {
        maxDistance_0 = 0.0f;
    }
    gAccum_0[Field_0(base_19, u32(10))] = vec4<f32>(throughput_22, maxDistance_0);
    gAccum_0[Field_0(base_19, u32(11))] = vec4<f32>(cone_1, (bitcast<f32>((mask_2))), 0.0f);
    return;
}

fn BSDF_Sample_0( this_117 : BSDF_0,  u_31 : vec3<f32>) -> LobeSample_0
{
    return FuzzLobe_Sample_0(this_117.lobes_1, u_31, this_117.wo_64);
}

fn SurfaceInteraction_ComputeRayOrigin_0( this_118 : SurfaceInteraction_0,  viewSide_0 : bool) -> vec3<f32>
{
    var n_18 : vec3<f32>;
    if((this_118.frontFacing_0) == viewSide_0)
    {
        n_18 = this_118.faceNormal_0;
    }
    else
    {
        n_18 = (vec3<f32>(0) - this_118.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(this_118.position_1, n_18);
}

fn ScatterConeSpread_0( lobe_6 : u32,  roughness_8 : f32) -> f32
{
    if(((lobe_6 & (u32(4)))) != u32(0))
    {
        return 0.5f;
    }
    return 0.5f * roughness_8 * roughness_8;
}

fn EmissiveHitPdf_0( _S522 : u32,  _S523 : u32,  _S524 : vec3<f32>,  _S525 : vec3<f32>) -> f32
{
    if((((gInstances_0[_S522].flags_0) & (u32(2)))) == u32(0))
    {
        return 0.0f;
    }
    var light_4 : EmissiveTriangle_std430_0 = gLights_0[gInstances_0[_S522].lightOffset_0 + _S523];
    return light_4.p1_0.w * EmissiveSolidAnglePdf_0(light_4.p0_0.w, MaterialHeader_DoubleSided_0(LoadMaterialHeader_0((bitcast<u32>((light_4.n_0.w))))), _S524, _S525, light_4.n_0.xyz);
}

fn ShadePath_0( base_20 : u32,  s_26 : ptr<function, WavefrontPath_0>)
{
    var hit_9 : HitRecord_0;
    hit_9.t_0 = gAccum_0[Field_0(base_20, u32(8))].x;
    hit_9.barycentrics_0 = gAccum_0[Field_0(base_20, u32(8))].yz;
    hit_9.instanceIndex_0 = (bitcast<u32>((gAccum_0[Field_0(base_20, u32(8))].w)));
    hit_9.primitiveIndex_0 = (bitcast<u32>((gAccum_0[Field_0(base_20, u32(9))].x)));
    var _S526 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_26).path_2.absorption_0) > _S526)))))
    {
        (*s_26).path_2.throughput_12 = (*s_26).path_2.throughput_12 * exp((*s_26).path_2.absorption_0 * vec3<f32>(- hit_9.t_0));
    }
    var hitConeWidth_0 : f32 = (*s_26).path_2.coneWidth_2 + (*s_26).path_2.coneSpread_0 * hit_9.t_0;
    var si_4 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_26).path_2.direction_3, hit_9, hitConeWidth_0);
    var V_2 : vec3<f32> = (vec3<f32>(0) - (*s_26).path_2.direction_3);
    var ms_1 : MaterialSample_0 = EvalMaterial_0(si_4, V_2);
    var bsdf_1 : BSDF_0 = BSDF_x24init_0(ms_1.inputs_1, V_2, (*s_26).path_2.throughput_12, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var bounce_3 : u32 = gWavefront_0.bounce_0;
    var throughput_23 : vec3<f32>;
    if((gWavefront_0.bounce_0) == u32(0))
    {
        (*s_26).albedo_1 = ms_1.albedo_2;
        if(si_4.frontFacing_0)
        {
            throughput_23 = ms_1.inputs_1.basis_0.n_1;
        }
        else
        {
            throughput_23 = (vec3<f32>(0) - ms_1.inputs_1.basis_0.n_1);
        }
        (*s_26).normal_12 = throughput_23;
    }
    (*s_26).active_0 = u32(0);
    var _S527 : bool;
    if(!si_4.frontFacing_0)
    {
        _S527 = !ms_1.doubleSided_0;
    }
    else
    {
        _S527 = false;
    }
    if(_S527)
    {
        _S527 = ((ms_1.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S527 = false;
    }
    if(_S527)
    {
        return;
    }
    if((any((((bsdf_1.emission_1) > _S526)))))
    {
        var _S528 : bool = (bounce_3 > u32(0));
        if(_S528)
        {
            _S527 = (*s_26).path_2.lightsSampled_0;
        }
        else
        {
            _S527 = false;
        }
        var mis_3 : f32;
        if(_S527)
        {
            mis_3 = EvalMISRobust_0((*s_26).path_2.scatterPdf_0, EmissiveHitPdf_0(si_4.instanceIndex_4, si_4.primitiveIndex_3, (*s_26).path_2.origin_3, si_4.position_1));
        }
        else
        {
            mis_3 = 1.0f;
        }
        var contribution_8 : vec3<f32> = (*s_26).path_2.throughput_12 * vec3<f32>(mis_3) * bsdf_1.emission_1;
        var clampValue_2 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_2 > 0.0f))
        {
            _S527 = _S528;
        }
        else
        {
            _S527 = false;
        }
        if(_S527)
        {
            throughput_23 = min(contribution_8, vec3<f32>(clampValue_2));
        }
        else
        {
            throughput_23 = contribution_8;
        }
        (*s_26).path_2.radiance_0 = (*s_26).path_2.radiance_0 + throughput_23;
    }
    if(bounce_3 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_7 : RandomSequence_0 = RandomSequence_x24init_1(u32(0), u32(0));
    rng_7.seed_1 = (*s_26).randomSeed_0;
    var _S529 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_1)) >= 0.0010000000474974513f);
    (*s_26).path_2.lightsSampled_0 = _S529;
    if(_S529)
    {
        QueueDirectLighting_0(base_20, si_4, bsdf_1, vec2<f32>(hitConeWidth_0, (*s_26).path_2.coneSpread_0), (*s_26).path_2.throughput_12, &(rng_7));
    }
    var u_32 : vec2<f32> = RandomSequence_Next2D_0(&(rng_7));
    var _S530 : f32 = RandomSequence_Next_0(&(rng_7));
    var bs_0 : LobeSample_0 = BSDF_Sample_0(bsdf_1, vec3<f32>(u_32, _S530));
    var weight_4 : vec3<f32> = bs_0.weight_0.diffuse_1 + bs_0.weight_0.specular_1;
    if(!bs_0.valid_0)
    {
        _S527 = true;
    }
    else
    {
        _S527 = ((bs_0.pdf_1) <= 0.0f);
    }
    if(_S527)
    {
        _S527 = true;
    }
    else
    {
        _S527 = (all(((weight_4 <= _S526))));
    }
    if(_S527)
    {
        return;
    }
    var throughput_24 : vec3<f32> = (*s_26).path_2.throughput_12 * weight_4;
    var continuation_0 : f32 = sqrt(saturate(MaxComponent_0(throughput_24) / max(MaxComponent_0((*s_26).path_2.throughput_12), 9.999999960041972e-13f)));
    if((continuation_0 < 1.0f))
    {
        var _S531 : f32 = RandomSequence_Next_0(&(rng_7));
        if((_S531 >= continuation_0))
        {
            return;
        }
        throughput_23 = throughput_24 / vec3<f32>(continuation_0);
    }
    else
    {
        throughput_23 = throughput_24;
    }
    (*s_26).path_2.throughput_12 = throughput_23;
    (*s_26).path_2.direction_3 = bs_0.wi_0;
    (*s_26).path_2.scatterPdf_0 = bs_0.pdf_1;
    var crossesSurface_0 : bool = ((dot(bs_0.wi_0, si_4.faceNormal_0)) > 0.0f) != (si_4.frontFacing_0);
    (*s_26).path_2.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_4, !crossesSurface_0);
    if(crossesSurface_0)
    {
        _S527 = !ms_1.thinWalled_0;
    }
    else
    {
        _S527 = false;
    }
    if(_S527)
    {
        if(si_4.frontFacing_0)
        {
            throughput_23 = HomogeneousVolume_Absorption_0(bsdf_1.volume_0);
        }
        else
        {
            throughput_23 = vec3<f32>(0.0f);
        }
        (*s_26).path_2.absorption_0 = throughput_23;
    }
    (*s_26).path_2.coneWidth_2 = hitConeWidth_0;
    (*s_26).path_2.coneSpread_0 = (*s_26).path_2.coneSpread_0 + ScatterConeSpread_0(bs_0.type_0, ms_1.roughness_5);
    (*s_26).randomSeed_0 = rng_7.seed_1;
    (*s_26).active_0 = u32(1);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shade(@builtin(global_invocation_id) tid_7 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var _S532 : u32 = tid_7.x;
    if((_S532 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_21 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S532));
    gAccum_0[Field_0(base_21, u32(11))] = vec4<f32>(0.0f);
    var s_27 : WavefrontPath_0 = LoadPath_0(base_21);
    if((s_27.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_21);
    ShadePath_0(base_21, &(s_27));
    StorePath_0(base_21, s_27);
    StoreFeedbackState_0(base_21);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shadow(@builtin(global_invocation_id) tid_8 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_1(tid_8);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowOpaque(@builtin(global_invocation_id) tid_9 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_0(tid_9);
    return;
}

fn IsFeedbackPixel_0( pixel_4 : vec2<u32>) -> bool
{
    var _S533 : vec2<u32> = vec2<u32>(gFrame_0.vtInfo_0.w);
    return (all((pixel_4 == (min(((((pixel_4 >> (_S533))) << (_S533))) + vec2<u32>(((gFrame_0.vtInfo_0.z) & (u32(65535))), ((gFrame_0.vtInfo_0.z) >> (u32(16)))), gFrame_0.frame_0.xy - vec2<u32>(u32(1)))))));
}

@compute
@workgroup_size(64, 1, 1)
fn Finalize(@builtin(global_invocation_id) tid_10 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S349();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_17 : u32 = tid_10.x;
    if((index_17 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_22 : u32 = WorkBase_0(index_17);
    var s_28 : WavefrontPath_0 = LoadPath_0(base_22);
    var pixel_5 : vec2<u32> = WorkPixel_0(index_17);
    if((any(((pixel_5 >= (gFrame_0.frame_0.xy))))))
    {
        return;
    }
    LoadFeedbackState_0(base_22);
    if(IsFeedbackPixel_0(pixel_5))
    {
        textureStore((gVTFeedback_0), ((pixel_5 >> (vec2<u32>(gFrame_0.vtInfo_0.w)))), vec4<u32>((gVTRequest_0), 0, 0, 1));
    }
    var radiance_5 : vec3<f32> = s_28.path_2.radiance_0 * vec3<f32>(gFrame_0.envParams_0.z);
    var radiance_6 : vec3<f32>;
    if(!(all((isfinite_1(radiance_5)))))
    {
        radiance_6 = vec3<f32>(0.0f);
    }
    else
    {
        radiance_6 = radiance_5;
    }
    var output_0 : u32 = (pixel_5.y * gFrame_0.frame_0.x + pixel_5.x) * u32(3);
    if((gFrame_0.frame_0.z) == u32(0))
    {
        gAccum_0[output_0] = vec4<f32>(radiance_6, 1.0f);
        gAccum_0[output_0 + u32(1)] = vec4<f32>(s_28.albedo_1, 1.0f);
        gAccum_0[output_0 + u32(2)] = vec4<f32>(s_28.normal_12, 1.0f);
    }
    else
    {
        var _S534 : vec3<f32> = vec3<f32>((1.0f / f32(gFrame_0.frame_0.z + u32(1))));
        gAccum_0[output_0] = vec4<f32>(mix(gAccum_0[output_0].xyz, radiance_6, _S534), 1.0f);
        var _S535 : u32 = output_0 + u32(1);
        gAccum_0[_S535] = vec4<f32>(mix(gAccum_0[_S535].xyz, s_28.albedo_1, _S534), 1.0f);
        var _S536 : u32 = output_0 + u32(2);
        gAccum_0[_S536] = vec4<f32>(mix(gAccum_0[_S536].xyz, s_28.normal_12, _S534), 1.0f);
    }
    return;
}

