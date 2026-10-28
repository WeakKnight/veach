// Generated from shaders/Passes/Wavefront.slang by scripts/build-shaders.mjs. Do not edit.
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

fn WorkBase_0( index_0 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_0;
}

fn Field_0( base_0 : u32,  field_0 : u32) -> u32
{
    return base_0 + field_0 * gWavefront_0.capacity_0;
}

fn ShadowBatchIndex_0( slot_0 : u32,  index_1 : ptr<function, u32>) -> bool
{
    var _S1 : u32 = gWavefront_0.pathCount_0;
    (*index_1) = u32(0);
    if((slot_0 >= _S1))
    {
        return false;
    }
    (*index_1) = slot_0;
    return (bitcast<u32>((gAccum_0[Field_0(WorkBase_0(slot_0), u32(11))].z))) != u32(0);
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

fn QueueIndex_0( base_1 : u32,  index_2 : u32) -> u32
{
    return (bitcast<u32>((gAccum_0[base_1 + index_2 / u32(4)][(index_2 & (u32(3)))])));
}

fn ShadowBatchIndex_1( slot_1 : u32,  index_3 : ptr<function, u32>) -> bool
{
    var _S2 : u32 = (bitcast<u32>((gAccum_0[HeaderBase_0()].y)));
    (*index_3) = u32(0);
    if((slot_1 >= _S2))
    {
        return false;
    }
    var _S3 : u32 = QueueIndex_0(ShadowQueueBase_0(), slot_1);
    (*index_3) = _S3;
    return (bitcast<u32>((gAccum_0[Field_0(WorkBase_0(_S3), u32(11))].z))) != u32(0);
}

fn isnan_0( x_0 : f32) -> bool
{
    var _S4 : u32 = (bitcast<u32>((x_0)));
    var _S5 : u32 = (_S4 & (u32(8388607)));
    var _S6 : bool;
    if(((((_S4 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S6 = _S5 != u32(0);
    }
    else
    {
        _S6 = false;
    }
    return _S6;
}

fn isinf_0( x_1 : f32) -> bool
{
    var _S7 : u32 = (bitcast<u32>((x_1)));
    var _S8 : u32 = (_S7 & (u32(8388607)));
    var _S9 : bool;
    if(((((_S7 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S9 = _S8 == u32(0);
    }
    else
    {
        _S9 = false;
    }
    return _S9;
}

fn isfinite_0( x_2 : f32) -> bool
{
    var _S10 : bool;
    if(isinf_0(x_2))
    {
        _S10 = true;
    }
    else
    {
        _S10 = isnan_0(x_2);
    }
    return !_S10;
}

struct TextureCoords_0
{
     uv0_0 : vec2<f32>,
     uv1_1 : vec2<f32>,
     footprint0_0 : f32,
     footprint1_0 : f32,
     objectPosition_0 : vec3<f32>,
};

struct SurfaceInteraction_0
{
     position_0 : vec3<f32>,
     faceNormal_0 : vec3<f32>,
     normal_0 : vec3<f32>,
     tangent_1 : vec4<f32>,
     tex_0 : TextureCoords_0,
     materialIndex_1 : u32,
     instanceIndex_0 : u32,
     primitiveIndex_0 : u32,
     frontFacing_0 : bool,
};

struct HomogeneousVolume_0
{
     extinction_0 : vec3<f32>,
     albedo_0 : vec3<f32>,
     anisotropy_0 : f32,
};

struct Frame_0
{
     t_0 : vec3<f32>,
     b_0 : vec3<f32>,
     n_1 : vec3<f32>,
};

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
     thinFilmWeight_0 : f32,
     thinFilmThickness_0 : f32,
     thinFilmExteriorIor_0 : f32,
     thinFilmIor_0 : f32,
     thinFilmInteriorIor_0 : vec3<f32>,
     wavelengths_0 : vec3<f32>,
     thinWallReflection_0 : vec3<f32>,
};

struct SpecularLobe_0
{
     normal_1 : vec3<f32>,
     distribution_0 : GGXDistribution_0,
     coefficient_0 : BaseReflectionTransmission_0,
     eta_0 : vec3<f32>,
     throughput_0 : vec3<f32>,
};

struct DielectricMultipleScatteringLobe_0
{
     normal_2 : vec3<f32>,
     alpha_1 : f32,
     eta_1 : f32,
     reflectionScale_0 : vec3<f32>,
     transmissionScale_0 : vec3<f32>,
     reflectionRatio_0 : f32,
     energyComplementWo_0 : f32,
};

struct MetalMultipleScatteringLobe_0
{
     normal_3 : vec3<f32>,
     alpha_2 : f32,
     scale_0 : vec3<f32>,
     energyComplementWo_1 : f32,
};

struct DiffuseLobe_0
{
     normal_4 : vec3<f32>,
     albedo_1 : vec3<f32>,
     roughness_0 : f32,
     specularAlpha_0 : f32,
     specularEta_0 : f32,
     specularCompensation_0 : f32,
};

struct ConstantReflection_0
{
     color_0 : vec3<f32>,
};

struct MicrofacetReflectionLobe_0
{
     normal_5 : vec3<f32>,
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
     normal_5 : vec3<f32>,
     distribution_1 : GGXDistribution_0,
     coefficient_1 : DielectricReflection_0,
};

struct CoatLobe_0
{
     base_2 : BaseLobe_0,
     reflection_0 : MicrofacetReflectionLobe_1,
     normal_6 : vec3<f32>,
     tint_0 : vec3<f32>,
     presence_0 : f32,
     inside_0 : bool,
     inReflected_0 : f32,
     inBaseLayerScale_0 : vec3<f32>,
};

struct FuzzLobe_0
{
     base_3 : CoatLobe_0,
     alpha_3 : f32,
     tint_1 : vec3<f32>,
     presence_1 : f32,
     basis_0 : Frame_0,
     woLocal_0 : vec3<f32>,
     viewReflected_0 : f32,
};

struct BSDF_0
{
     volume_0 : HomogeneousVolume_0,
     emission_0 : vec3<f32>,
     lobes_0 : FuzzLobe_0,
     wo_0 : vec3<f32>,
};

struct RandomSequence_0
{
     seed_0 : u32,
};

var<private> gRayCone_0 : vec2<f32>;

struct LightSample_0
{
     position_1 : vec3<f32>,
     normal_7 : vec3<f32>,
     radiance_0 : vec3<f32>,
     solidAnglePdf_0 : f32,
     delta_0 : bool,
     shadow_0 : bool,
};

fn EnvironmentEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(1)))) != u32(0);
}

fn StrongIntegerHash_0( x_3 : u32) -> u32
{
    var _S11 : u32 = ((x_3 ^ (((x_3 >> (u32(16))))))) * u32(2819806515);
    var _S12 : u32 = ((_S11 ^ (((_S11 >> (u32(15))))))) * u32(2994267309);
    return (_S12 ^ (((_S12 >> (u32(17))))));
}

fn RandomSequence_Next_0( this_0 : ptr<function, RandomSequence_0>) -> f32
{
    var _S13 : u32 = (*this_0).seed_0 + u32(1);
    (*this_0).seed_0 = _S13;
    return f32(((StrongIntegerHash_0(_S13)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_1 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_4 : f32 = RandomSequence_Next_0(&((*this_1)));
    var y_0 : f32 = RandomSequence_Next_0(&((*this_1)));
    return vec2<f32>(x_4, y_0);
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn EnvCdf_0( x_5 : u32,  y_1 : u32) -> f32
{
    var _S14 : vec3<i32> = vec3<i32>(i32(x_5), i32(y_1), i32(0));
    return (textureLoad((gEnvCdf_0), ((_S14)).xy, ((_S14)).z).x);
}

fn SearchCdfRow_0( row_0 : u32,  count_0 : u32,  u_0 : f32) -> u32
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
        if(((EnvCdf_0(mid_0, row_0)) <= u_0))
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

fn EquirectUVToDirection_0( uv_0 : vec2<f32>,  cosElevation_0 : ptr<function, f32>) -> vec3<f32>
{
    var PI_0 : f32 = float_getPi_0();
    var azimuth_0 : f32 = (uv_0.x + 0.25f) * (2.0f * PI_0);
    var elevation_0 : f32 = (0.5f - uv_0.y) * PI_0;
    var _S15 : f32 = cos(elevation_0);
    (*cosElevation_0) = _S15;
    return vec3<f32>(cos(azimuth_0) * _S15, sin(elevation_0), sin(azimuth_0) * _S15);
}

fn RotateY_0( v_0 : vec3<f32>,  angle_0 : f32) -> vec3<f32>
{
    var s_0 : f32 = sin(angle_0);
    var c_0 : f32 = cos(angle_0);
    var _S16 : f32 = v_0.x;
    var _S17 : f32 = v_0.z;
    return vec3<f32>(c_0 * _S16 + s_0 * _S17, v_0.y, - s_0 * _S16 + c_0 * _S17);
}

fn DirectionToEquirectUV_0( dir_0 : vec3<f32>) -> vec2<f32>
{
    var _S18 : f32 = dir_0.y;
    var elevation_1 : f32 = asin(clamp(_S18, -1.0f, 1.0f));
    var azimuth_1 : f32;
    if(((abs(_S18)) < 1.0f))
    {
        azimuth_1 = atan2(dir_0.z, dir_0.x);
    }
    else
    {
        azimuth_1 = 0.0f;
    }
    var PI_1 : f32 = float_getPi_0();
    return vec2<f32>(azimuth_1 * (0.5f / PI_1) - 0.25f, 0.5f - elevation_1 * (1.0f / PI_1));
}

fn EvalEnvironment_0( dir_1 : vec3<f32>) -> vec3<f32>
{
    if(!EnvironmentEnabled_0())
    {
        return vec3<f32>(0.0f);
    }
    return (textureSampleLevel((gEnvMap_0), (gLinearSampler_0), (DirectionToEquirectUV_0(RotateY_0(dir_1, - gFrame_0.envParams_0.y))), (0.0f))).xyz * vec3<f32>(gFrame_0.envParams_0.x);
}

fn SampleEnvironment_0( rng_0 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_1 : LightSample_0;
    s_1.position_1 = vec3<f32>(0.0f);
    s_1.delta_0 = false;
    s_1.shadow_0 = true;
    var u_1 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_0)));
    var dir_2 : vec3<f32>;
    if((((gFrame_0.settings_0.z) & (u32(4)))) == u32(0))
    {
        var z_0 : f32 = 1.0f - 2.0f * u_1.x;
        var r_0 : f32 = sqrt(max(0.0f, 1.0f - z_0 * z_0));
        var PI_2 : f32 = float_getPi_0();
        var phi_0 : f32 = 2.0f * PI_2 * u_1.y;
        var _S19 : vec3<f32> = vec3<f32>(r_0 * cos(phi_0), r_0 * sin(phi_0), z_0);
        s_1.solidAnglePdf_0 = 1.0f / (4.0f * PI_2);
        dir_2 = _S19;
    }
    else
    {
        var W_0 : u32 = gFrame_0.envInfo_0.x;
        var H_0 : u32 = gFrame_0.envInfo_0.y;
        var _S20 : f32 = u_1.y;
        var y_2 : u32 = SearchCdfRow_0(H_0, H_0, _S20);
        var cy0_0 : f32 = EnvCdf_0(y_2, H_0);
        var cy1_0 : f32 = EnvCdf_0(y_2 + u32(1), H_0);
        var dv_0 : f32;
        if((cy1_0 > cy0_0))
        {
            dv_0 = (_S20 - cy0_0) / (cy1_0 - cy0_0);
        }
        else
        {
            dv_0 = 0.5f;
        }
        var _S21 : f32 = u_1.x;
        var x_6 : u32 = SearchCdfRow_0(y_2, W_0, _S21);
        var cx0_0 : f32 = EnvCdf_0(x_6, y_2);
        var cx1_0 : f32 = EnvCdf_0(x_6 + u32(1), y_2);
        var du_0 : f32;
        if((cx1_0 > cx0_0))
        {
            du_0 = (_S21 - cx0_0) / (cx1_0 - cx0_0);
        }
        else
        {
            du_0 = 0.5f;
        }
        var _S22 : f32 = f32(H_0);
        var _S23 : f32 = f32(W_0);
        var pdfUV_0 : f32 = (cy1_0 - cy0_0) * _S22 * (cx1_0 - cx0_0) * _S23;
        var cosElevation_1 : f32;
        var local_0 : vec3<f32> = EquirectUVToDirection_0(vec2<f32>((f32(x_6) + du_0) / _S23, (f32(y_2) + dv_0) / _S22), &(cosElevation_1));
        var _S24 : vec3<f32> = RotateY_0(local_0, gFrame_0.envParams_0.y);
        var PI_3 : f32 = float_getPi_0();
        s_1.solidAnglePdf_0 = pdfUV_0 / (2.0f * PI_3 * PI_3 * max(cosElevation_1, 9.99999997475242708e-07f));
        dir_2 = _S24;
    }
    s_1.normal_7 = (vec3<f32>(0) - dir_2);
    s_1.radiance_0 = EvalEnvironment_0(dir_2);
    return s_1;
}

fn ComputeOffsetOrigin_0( pos_0 : vec3<f32>,  normal_8 : vec3<f32>) -> vec3<f32>
{
    var _S25 : vec3<i32> = vec3<i32>(normal_8 * vec3<f32>(768.0f));
    var _S26 : vec3<i32> = (bitcast<vec3<i32>>((pos_0)));
    var _S27 : f32 = pos_0.x;
    var _S28 : i32;
    if((_S27 < 0.0f))
    {
        _S28 = - _S25.x;
    }
    else
    {
        _S28 = _S25.x;
    }
    var _S29 : f32 = pos_0.y;
    var _S30 : i32;
    if((_S29 < 0.0f))
    {
        _S30 = - _S25.y;
    }
    else
    {
        _S30 = _S25.y;
    }
    var _S31 : f32 = pos_0.z;
    var _S32 : i32;
    if((_S31 < 0.0f))
    {
        _S32 = - _S25.z;
    }
    else
    {
        _S32 = _S25.z;
    }
    var pI_0 : vec3<f32> = (bitcast<vec3<f32>>((_S26 + vec3<i32>(_S28, _S30, _S32))));
    var fOff_0 : vec3<f32> = normal_8 * vec3<f32>(4.57763671875e-05f);
    var _S33 : f32;
    if(((abs(_S27)) < 0.0625f))
    {
        _S33 = _S27 + fOff_0.x;
    }
    else
    {
        _S33 = pI_0.x;
    }
    var _S34 : f32;
    if(((abs(_S29)) < 0.0625f))
    {
        _S34 = _S29 + fOff_0.y;
    }
    else
    {
        _S34 = pI_0.y;
    }
    var _S35 : f32;
    if(((abs(_S31)) < 0.0625f))
    {
        _S35 = _S31 + fOff_0.z;
    }
    else
    {
        _S35 = pI_0.z;
    }
    return vec3<f32>(_S33, _S34, _S35);
}

fn ShadowOrigin_0( si_0 : SurfaceInteraction_0,  dir_3 : vec3<f32>) -> vec3<f32>
{
    var _S36 : vec3<f32>;
    if(((dot(si_0.faceNormal_0, dir_3)) >= 0.0f))
    {
        _S36 = si_0.faceNormal_0;
    }
    else
    {
        _S36 = (vec3<f32>(0) - si_0.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(si_0.position_0, _S36);
}

fn LightCount_0() -> u32
{
    return gFrame_0.counts_0.y;
}

fn RandomSequence_Next_1( this_2 : ptr<function, RandomSequence_0>) -> f32
{
    var _S37 : u32 = (*this_2).seed_0 + u32(1);
    (*this_2).seed_0 = _S37;
    return f32(((StrongIntegerHash_0(_S37)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn SelectLight_0( u_2 : f32) -> u32
{
    var _S38 : u32 = LightCount_0() - u32(1);
    var lo_1 : u32 = u32(0);
    var hi_1 : u32 = _S38;
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
        if(((gLights_0[mid_1].p2_0.w) > u_2))
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

fn AnalyticFlags_0( light_0 : ptr<function, EmissiveTriangle_std430_0>) -> u32
{
    return (bitcast<u32>(((*light_0).n_0.w)));
}

fn SampleDisk_0( u_3 : vec2<f32>) -> vec2<f32>
{
    var angle_1 : f32 = 2.0f * float_getPi_0() * u_3.x;
    return vec2<f32>(cos(angle_1), sin(angle_1)) * vec2<f32>(sqrt(u_3.y));
}

fn AreaLightPoint_0( light_1 : ptr<function, EmissiveTriangle_std430_0>,  u_4 : vec2<f32>) -> vec3<f32>
{
    var _S39 : u32 = AnalyticFlags_0(&((*light_1)));
    var d_0 : vec2<f32>;
    if(((_S39 & (u32(512)))) != u32(0))
    {
        d_0 = SampleDisk_0(u_4) * vec2<f32>(0.5f);
    }
    else
    {
        d_0 = u_4 - vec2<f32>(0.5f);
    }
    return (*light_1).p0_0.xyz + (*light_1).n_0.xyz * vec3<f32>(d_0.x) + (*light_1).uvA_0.xyz * vec3<f32>(d_0.y);
}

fn rsqrt_0( x_7 : f32) -> f32
{
    return 1.0f / sqrt(x_7);
}

fn SpotAttenuation_0( light_2 : ptr<function, EmissiveTriangle_std430_0>,  dir_4 : vec3<f32>) -> f32
{
    var _S40 : u32 = AnalyticFlags_0(&((*light_2)));
    if(((_S40 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_8 : f32 = dot(dir_4, (*light_2).p2_0.xyz) - (*light_2).uvA_0.w;
    var scale_1 : f32 = (*light_2).uvB_0.x;
    var _S41 : f32;
    if((scale_1 > 0.0f))
    {
        _S41 = smoothstep(0.0f, 1.0f, x_8 * scale_1);
    }
    else
    {
        if((x_8 > 0.0f))
        {
            _S41 = 1.0f;
        }
        else
        {
            _S41 = 0.0f;
        }
    }
    return _S41;
}

fn SphereOneMinusCos_0( radius_0 : f32,  distSq_0 : f32) -> f32
{
    var sinSq_0 : f32 = radius_0 * radius_0 / distSq_0;
    var _S42 : f32;
    if((sinSq_0 < 1.0f))
    {
        _S42 = sinSq_0 / (1.0f + sqrt(1.0f - sinSq_0));
    }
    else
    {
        _S42 = 0.0f;
    }
    return _S42;
}

fn BranchlessONB_0( n_2 : vec3<f32>,  b1_0 : ptr<function, vec3<f32>>,  b2_0 : ptr<function, vec3<f32>>)
{
    var _S43 : f32 = n_2.z;
    var s_2 : f32;
    if((_S43 >= 0.0f))
    {
        s_2 = 1.0f;
    }
    else
    {
        s_2 = -1.0f;
    }
    var a_0 : f32 = -1.0f / (s_2 + _S43);
    var _S44 : f32 = n_2.x;
    var _S45 : f32 = n_2.y;
    var b_1 : f32 = _S44 * _S45 * a_0;
    (*b1_0) = vec3<f32>(1.0f + s_2 * _S44 * _S44 * a_0, s_2 * b_1, - s_2 * _S44);
    (*b2_0) = vec3<f32>(b_1, s_2 + _S45 * _S45 * a_0, - _S45);
    return;
}

fn SampleAnalytic_0( light_3 : ptr<function, EmissiveTriangle_std430_0>,  viewer_0 : vec3<f32>,  rng_1 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_3 : LightSample_0;
    s_3.delta_0 = false;
    s_3.radiance_0 = vec3<f32>(0.0f);
    s_3.solidAnglePdf_0 = 0.0f;
    var _S46 : u32 = AnalyticFlags_0(&((*light_3)));
    s_3.shadow_0 = ((_S46 & (u32(1024)))) == u32(0);
    var u_5 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_1)));
    if(((_S46 & (u32(255)))) == u32(2))
    {
        var _S47 : vec3<f32> = AreaLightPoint_0(&((*light_3)), u_5);
        s_3.position_1 = _S47;
        var _S48 : vec3<f32> = (*light_3).p2_0.xyz;
        s_3.normal_7 = _S48;
        var toLight_0 : vec3<f32> = _S47 - viewer_0;
        var distSq_1 : f32 = dot(toLight_0, toLight_0);
        var cosTheta_0 : f32 = - dot(_S48, toLight_0) * rsqrt_0(max(distSq_1, 9.99999968265522539e-21f));
        if((cosTheta_0 > 9.99999997475242708e-07f))
        {
            s_3.radiance_0 = (*light_3).p1_0.xyz;
            s_3.solidAnglePdf_0 = (*light_3).p1_0.w * distSq_1 / (cosTheta_0 * (*light_3).p0_0.w);
        }
        return s_3;
    }
    var _S49 : vec3<f32> = (*light_3).p0_0.xyz;
    var toCenter_0 : vec3<f32> = _S49 - viewer_0;
    var distSq_2 : f32 = dot(toCenter_0, toCenter_0);
    var w_0 : vec3<f32> = toCenter_0 / vec3<f32>(max(sqrt(distSq_2), 9.99999968265522539e-21f));
    var radius_1 : f32 = (*light_3).p0_0.w;
    if((radius_1 <= 0.0f))
    {
        s_3.position_1 = _S49;
        var _S50 : vec3<f32> = (vec3<f32>(0) - w_0);
        s_3.normal_7 = _S50;
        var _S51 : vec4<f32> = (*light_3).p1_0;
        var _S52 : vec3<f32> = (*light_3).p1_0.xyz;
        var _S53 : f32 = SpotAttenuation_0(&((*light_3)), _S50);
        s_3.radiance_0 = _S52 * vec3<f32>(_S53) / vec3<f32>(max(distSq_2, 9.99999968265522539e-21f));
        s_3.solidAnglePdf_0 = _S51.w;
        s_3.delta_0 = true;
        return s_3;
    }
    var oneMinusCosMax_0 : f32 = SphereOneMinusCos_0(radius_1, distSq_2);
    if((oneMinusCosMax_0 <= 0.0f))
    {
        s_3.position_1 = _S49;
        s_3.normal_7 = (vec3<f32>(0) - w_0);
        return s_3;
    }
    var oneMinusCos_0 : f32 = u_5.x * oneMinusCosMax_0;
    var cosTheta_1 : f32 = 1.0f - oneMinusCos_0;
    var sinTheta_0 : f32 = sqrt(max(0.0f, oneMinusCos_0 * (2.0f - oneMinusCos_0)));
    var TWO_PI_0 : f32 = 2.0f * float_getPi_0();
    var phi_1 : f32 = TWO_PI_0 * u_5.y;
    var t_1 : vec3<f32>;
    var b_2 : vec3<f32>;
    BranchlessONB_0(w_0, &(t_1), &(b_2));
    var dir_5 : vec3<f32> = (t_1 * vec3<f32>(cos(phi_1)) + b_2 * vec3<f32>(sin(phi_1))) * vec3<f32>(sinTheta_0) + w_0 * vec3<f32>(cosTheta_1);
    var tc_0 : f32 = dot(toCenter_0, dir_5);
    var _S54 : vec3<f32> = viewer_0 + dir_5 * vec3<f32>((tc_0 - sqrt(max(0.0f, radius_1 * radius_1 - (distSq_2 - tc_0 * tc_0)))));
    s_3.position_1 = _S54;
    s_3.normal_7 = normalize(_S54 - _S49);
    var _S55 : vec4<f32> = (*light_3).p1_0;
    var _S56 : vec3<f32> = (*light_3).p1_0.xyz;
    var _S57 : f32 = SpotAttenuation_0(&((*light_3)), (vec3<f32>(0) - w_0));
    s_3.radiance_0 = _S56 * vec3<f32>(_S57);
    s_3.solidAnglePdf_0 = _S55.w / (TWO_PI_0 * oneMinusCosMax_0);
    return s_3;
}

fn SampleTriangle_0( u_6 : vec2<f32>) -> vec3<f32>
{
    var su_0 : f32 = sqrt(u_6.x);
    var _S58 : f32 = u_6.y;
    return vec3<f32>(1.0f - su_0, su_0 * (1.0f - _S58), su_0 * _S58);
}

struct MaterialHeader_0
{
     surface_0 : u32,
     opacity_0 : u32,
     emission_1 : u32,
     flags_1 : u32,
     textureBase_0 : u32,
     constantBase_0 : u32,
     alphaCutoff_0 : f32,
     debugTexture_0 : u32,
};

fn LoadMaterialHeader_0( materialIndex_2 : u32) -> MaterialHeader_0
{
    var _S59 : u32 = materialIndex_2 * u32(2);
    var h0_0 : vec4<u32> = gMaterialData_0[_S59];
    var h1_0 : vec4<u32> = gMaterialData_0[_S59 + u32(1)];
    var h_0 : MaterialHeader_0;
    h_0.surface_0 = h0_0.x;
    h_0.opacity_0 = h0_0.y;
    h_0.emission_1 = h0_0.z;
    h_0.flags_1 = h0_0.w;
    h_0.textureBase_0 = h1_0.x;
    h_0.constantBase_0 = h1_0.y;
    h_0.alphaCutoff_0 = (bitcast<f32>((h1_0.z)));
    h_0.debugTexture_0 = h1_0.w;
    return h_0;
}

fn MaterialHeader_DoubleSided_0( this_3 : MaterialHeader_0) -> bool
{
    return (((this_3.flags_1) & (u32(1)))) != u32(0);
}

fn UVFootprintLog2_0( coneWidth_0 : f32,  worldArea_0 : f32,  uvArea_0 : f32,  cosTheta_2 : f32) -> f32
{
    return log2(max(coneWidth_0, 9.99999968265522539e-21f)) - log2(max(abs(cosTheta_2), 0.0010000000474974513f)) + 0.5f * log2(max(uvArea_0 / max(worldArea_0, 1.00000000317107685e-30f), 1.00000000317107685e-30f));
}

fn MakeTextureCoords_0( uv0_1 : vec2<f32>,  uv1_2 : vec2<f32>,  worldE1_0 : vec3<f32>,  worldE2_0 : vec3<f32>,  uv0E1_0 : vec2<f32>,  uv0E2_0 : vec2<f32>,  uv1E1_0 : vec2<f32>,  uv1E2_0 : vec2<f32>,  coneWidth_1 : f32,  cosTheta_3 : f32) -> TextureCoords_0
{
    var tc_1 : TextureCoords_0;
    tc_1.uv0_0 = uv0_1;
    tc_1.uv1_1 = uv1_2;
    tc_1.objectPosition_0 = vec3<f32>(0.0f);
    var worldArea_1 : f32 = length(cross(worldE1_0, worldE2_0));
    tc_1.footprint0_0 = UVFootprintLog2_0(coneWidth_1, worldArea_1, abs(uv0E1_0.x * uv0E2_0.y - uv0E1_0.y * uv0E2_0.x), cosTheta_3);
    tc_1.footprint1_0 = UVFootprintLog2_0(coneWidth_1, worldArea_1, abs(uv1E1_0.x * uv1E2_0.y - uv1E1_0.y * uv1E2_0.x), cosTheta_3);
    return tc_1;
}

fn InverseTransformPoint_0( _S60 : u32,  _S61 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S60].worldToObject_0[i32(0)].xyz, _S61) + gInstances_0[_S60].worldToObject_0[i32(0)].w, dot(gInstances_0[_S60].worldToObject_0[i32(1)].xyz, _S61) + gInstances_0[_S60].worldToObject_0[i32(1)].w, dot(gInstances_0[_S60].worldToObject_0[i32(2)].xyz, _S61) + gInstances_0[_S60].worldToObject_0[i32(2)].w);
}

fn MaterialHeader_AlphaMode_0( this_4 : MaterialHeader_0) -> u32
{
    return ((((this_4.flags_1) >> (u32(8)))) & (u32(3)));
}

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
     thinFilmWeight_1 : f32,
     thinFilmThickness_1 : f32,
     thinFilmIor_1 : f32,
     emissionLuminance_0 : f32,
     emissionColor_0 : vec3<f32>,
     geometryOpacity_0 : f32,
     geometryThinWalled_0 : bool,
     basis_1 : Frame_0,
     coatBasis_0 : Frame_0,
};

struct MaterialOutputs_0
{
     inputs_0 : BSDFInputs_0,
     normal_9 : vec3<f32>,
     coatNormal_0 : vec3<f32>,
     tangent_2 : vec3<f32>,
     coatTangent_0 : vec3<f32>,
};

struct MaterialContext_0
{
     tex_1 : TextureCoords_0,
     position_2 : vec3<f32>,
     normal_10 : vec3<f32>,
     tangent_3 : vec4<f32>,
     instanceIndex_1 : u32,
};

fn MakeMaterialContext_0( tex_2 : TextureCoords_0) -> MaterialContext_0
{
    var ctx_0 : MaterialContext_0;
    ctx_0.tex_1 = tex_2;
    ctx_0.position_2 = vec3<f32>(0.0f);
    ctx_0.normal_10 = vec3<f32>(0.0f, 0.0f, 1.0f);
    ctx_0.tangent_3 = vec4<f32>(0.0f);
    ctx_0.instanceIndex_1 = u32(0);
    return ctx_0;
}

fn BSDFInputs_Default_0() -> BSDFInputs_0
{
    var i_0 : BSDFInputs_0;
    i_0.baseWeight_0 = 1.0f;
    var _S62 : vec3<f32> = vec3<f32>(0.80000001192092896f);
    i_0.baseColor_0 = _S62;
    i_0.baseDiffuseRoughness_0 = 0.0f;
    i_0.baseMetalness_0 = 0.0f;
    i_0.subsurfaceWeight_0 = 0.0f;
    i_0.subsurfaceColor_0 = _S62;
    i_0.subsurfaceRadius_0 = 1.0f;
    i_0.subsurfaceRadiusScale_0 = vec3<f32>(1.0f, 0.5f, 0.25f);
    i_0.subsurfaceScatterAnisotropy_0 = 0.0f;
    i_0.specularWeight_0 = 1.0f;
    i_0.specularDielectricOnly_0 = false;
    var _S63 : vec3<f32> = vec3<f32>(1.0f);
    i_0.specularColor_0 = _S63;
    i_0.specularRoughness_0 = 0.30000001192092896f;
    i_0.specularRoughnessAnisotropy_0 = 0.0f;
    i_0.specularIor_0 = 1.5f;
    const _S64 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    i_0.specularAnisotropyRotation_0 = _S64;
    i_0.coatWeight_0 = 0.0f;
    i_0.coatColor_0 = _S63;
    i_0.coatRoughness_0 = 0.0f;
    i_0.coatRoughnessAnisotropy_0 = 0.0f;
    i_0.coatIor_0 = 1.6000000238418579f;
    i_0.coatDarkening_0 = 1.0f;
    i_0.coatAnisotropyRotation_0 = _S64;
    i_0.fuzzWeight_0 = 0.0f;
    i_0.fuzzColor_0 = _S63;
    i_0.fuzzRoughness_0 = 0.5f;
    i_0.transmissionWeight_0 = 0.0f;
    i_0.transmissionColor_0 = _S63;
    i_0.transmissionDepth_0 = 0.0f;
    i_0.transmissionScatter_0 = vec3<f32>(0.0f);
    i_0.transmissionScatterAnisotropy_0 = 0.0f;
    i_0.transmissionDispersionScale_0 = 0.0f;
    i_0.transmissionDispersionAbbeNumber_0 = 20.0f;
    i_0.thinFilmWeight_1 = 0.0f;
    i_0.thinFilmThickness_1 = 0.5f;
    i_0.thinFilmIor_1 = 1.3999999761581421f;
    i_0.emissionLuminance_0 = 0.0f;
    i_0.emissionColor_0 = _S63;
    i_0.geometryOpacity_0 = 1.0f;
    i_0.geometryThinWalled_0 = false;
    i_0.basis_1.t_0 = vec3<f32>(1.0f, 0.0f, 0.0f);
    i_0.basis_1.b_0 = vec3<f32>(0.0f, 1.0f, 0.0f);
    i_0.basis_1.n_1 = vec3<f32>(0.0f, 0.0f, 1.0f);
    i_0.coatBasis_0 = i_0.basis_1;
    return i_0;
}

fn MaterialOutputs_Default_0( ctx_1 : MaterialContext_0) -> MaterialOutputs_0
{
    var o_0 : MaterialOutputs_0;
    o_0.inputs_0 = BSDFInputs_Default_0();
    o_0.normal_9 = ctx_1.normal_10;
    o_0.coatNormal_0 = ctx_1.normal_10;
    var _S65 : vec3<f32> = ctx_1.tangent_3.xyz;
    o_0.tangent_2 = _S65;
    o_0.coatTangent_0 = _S65;
    return o_0;
}

@id(2) override gMaterialOperandMode_0 : u32 = u32(0);

fn MaterialOperand_0( operand_0 : u32,  slot_2 : vec4<f32>,  constantBase_1 : u32) -> vec4<f32>
{
    if(operand_0 == u32(4294967295))
    {
        return vec4<f32>(0.0f);
    }
    if(((operand_0 & (u32(2147483648)))) != u32(0))
    {
        return (bitcast<vec4<f32>>((gMaterialData_0[constantBase_1 + ((operand_0 & (u32(2147483647))))])));
    }
    return slot_2;
}

@id(0) override gMaterialOpcodesLow_0 : u32 = u32(4294967295);

fn LanesBelow_0( size_0 : u32) -> vec4<bool>
{
    return (vec4<u32>(u32(0), u32(1), u32(2), u32(3)) < vec4<u32>(size_0));
}

fn MaterialWord_0( index_4 : u32) -> u32
{
    return gMaterialData_0[(index_4 >> (u32(2)))][(index_4 & (u32(3)))];
}

struct TextureRef_0
{
     flags_2 : u32,
     pageTableOffset_0 : u32,
     reserved_0 : u32,
     rotation_0 : f32,
     scaleOffset_0 : vec4<f32>,
};

fn LoadTextureRef_0( header_0 : MaterialHeader_0,  index_5 : u32) -> TextureRef_0
{
    var _S66 : u32 = header_0.textureBase_0 + index_5 * u32(2);
    var a_1 : vec4<u32> = gMaterialData_0[_S66];
    var ref_0 : TextureRef_0;
    ref_0.flags_2 = a_1.x;
    ref_0.pageTableOffset_0 = a_1.y;
    ref_0.reserved_0 = a_1.z;
    ref_0.rotation_0 = (bitcast<f32>((a_1.w)));
    ref_0.scaleOffset_0 = (bitcast<vec4<f32>>((gMaterialData_0[_S66 + u32(1)])));
    return ref_0;
}

fn HasTexture_0( ref_1 : TextureRef_0) -> bool
{
    return (((ref_1.flags_2) & (u32(1)))) != u32(0);
}

fn TransformUV_0( ref_2 : TextureRef_0,  uv_1 : vec2<f32>) -> vec2<f32>
{
    var s_4 : vec2<f32> = ref_2.scaleOffset_0.xy * uv_1;
    var c_1 : f32 = cos(ref_2.rotation_0);
    var r_1 : f32 = sin(ref_2.rotation_0);
    var _S67 : f32 = s_4.x;
    var _S68 : f32 = s_4.y;
    return vec2<f32>(c_1 * _S67 + r_1 * _S68, - r_1 * _S67 + c_1 * _S68) + ref_2.scaleOffset_0.zw;
}

fn WrapCoord_0( x_9 : f32,  mode_0 : u32) -> f32
{
    if(mode_0 == u32(1))
    {
        return saturate(x_9);
    }
    if(mode_0 == u32(2))
    {
        var t_2 : f32 = x_9 - 2.0f * floor(x_9 * 0.5f);
        var _S69 : f32;
        if((t_2 > 1.0f))
        {
            _S69 = 2.0f - t_2;
        }
        else
        {
            _S69 = t_2;
        }
        return _S69;
    }
    return fract(x_9);
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
    var _S70 : u32 = u32(1664525) * gVTRandom_0 + u32(1013904223);
    gVTRandom_0 = _S70;
    return _S70;
}

fn VTPageCount_0( log2Size_0 : vec2<u32>,  level_0 : u32) -> vec2<u32>
{
    var _S71 : vec2<i32> = max(vec2<i32>(log2Size_0) - vec2<i32>(i32(level_0)) - vec2<i32>(i32(7)), vec2<i32>(i32(0)));
    return vec2<u32>((u32(1) << (u32(_S71.x))), (u32(1) << (u32(_S71.y))));
}

fn VTLevelSize_0( log2Size_1 : vec2<u32>,  level_1 : u32) -> vec2<f32>
{
    var _S72 : vec2<i32> = max(vec2<i32>(log2Size_1) - vec2<i32>(i32(level_1)), vec2<i32>(i32(0)));
    return vec2<f32>(f32((u32(1) << (u32(_S72.x)))), f32((u32(1) << (u32(_S72.y)))));
}

var<private> gVTRequestCount_0 : u32;

var<private> gVTRequest_0 : u32;

fn StoreVirtualTextureFeedback_0( pageIndex_0 : u32)
{
    gVTRequestCount_0 = gVTRequestCount_0 + u32(1);
    var _S73 : u32 = NextVTRandom_0();
    if(((f32((_S73 >> (u32(8)))) * 5.9604644775390625e-08f * f32(gVTRequestCount_0)) < 1.0f))
    {
        gVTRequest_0 = pageIndex_0 + u32(1);
    }
    return;
}

fn VTLoadEntry_0( index_6 : u32) -> u32
{
    var width_0 : u32 = gFrame_0.vtInfo_0.y;
    var _S74 : u32 = index_6 % width_0;
    var _S75 : i32 = i32(_S74);
    var _S76 : u32 = index_6 / width_0;
    var _S77 : vec3<i32> = vec3<i32>(_S75, i32(_S76), i32(0));
    return (textureLoad((gVTPageTable_0), ((_S77)).xy, ((_S77)).z).x);
}

var<private> gVTLastMappedLevel_0 : u32;

var<private> gVTLastRequestedLevel_0 : u32;

fn SampleVirtualTexture_0( ref_6 : TextureRef_0,  uv_2 : vec2<f32>,  uvFootprint_0 : f32) -> vec4<f32>
{
    var levels_0 : u32 = VTLevels_0(ref_6);
    var _S78 : u32 = VTLog2Width_0(ref_6);
    var _S79 : u32 = VTLog2Height_0(ref_6);
    var log2Size_2 : vec2<u32> = vec2<u32>(_S78, _S79);
    var lod_0 : f32 = uvFootprint_0 + 0.5f * (f32(_S78 + _S79) + log2(max(abs(ref_6.scaleOffset_0.x * ref_6.scaleOffset_0.y), 9.99999968265522539e-21f))) + gFrame_0.vtParams_0.z;
    var _S80 : u32 = NextVTRandom_0();
    var level_2 : u32 = u32(clamp(floor(lod_0 + f32((_S80 >> (u32(8)))) * 5.9604644775390625e-08f), 0.0f, f32(levels_0 - u32(1))));
    var l_0 : u32 = u32(0);
    var index_7 : u32 = ref_6.pageTableOffset_0;
    loop
    {
        if((l_0 < level_2))
        {
        }
        else
        {
            break;
        }
        var n_3 : vec2<u32> = VTPageCount_0(log2Size_2, l_0);
        var index_8 : u32 = index_7 + n_3.x * n_3.y;
        l_0 = l_0 + u32(1);
        index_7 = index_8;
    }
    var pages_0 : vec2<u32> = VTPageCount_0(log2Size_2, level_2);
    var _S81 : vec2<u32> = min((vec2<u32>(uv_2 * VTLevelSize_0(log2Size_2, level_2)) >> (vec2<u32>(u32(7)))), pages_0 - vec2<u32>(u32(1)));
    var index_9 : u32 = index_7 + (_S81.y * pages_0.x + _S81.x);
    StoreVirtualTextureFeedback_0(index_9);
    var entry_0 : u32 = VTLoadEntry_0(index_9);
    if(((entry_0 & (u32(2147483648)))) == u32(0))
    {
        return vec4<f32>(1.0f, 0.0f, 1.0f, 1.0f);
    }
    var mappedLevel_0 : u32 = (((entry_0 >> (u32(16)))) & (u32(15)));
    gVTLastMappedLevel_0 = mappedLevel_0;
    gVTLastRequestedLevel_0 = level_2;
    var local_1 : vec2<f32> = uv_2 * VTLevelSize_0(log2Size_2, mappedLevel_0) - vec2<f32>((_S81 >> (vec2<u32>((mappedLevel_0 - level_2))))) * vec2<f32>(128.0f);
    var tile_0 : u32 = (entry_0 & (u32(65535)));
    var tilesPerRow_0 : u32 = gFrame_0.vtInfo_0.x;
    var _S82 : u32 = tile_0 % tilesPerRow_0;
    var _S83 : f32 = f32(_S82);
    var _S84 : u32 = tile_0 / tilesPerRow_0;
    return (textureSampleLevel((gVTPhysical_0), (gLinearSampler_0), ((vec2<f32>(_S83, f32(_S84)) * vec2<f32>(136.0f) + vec2<f32>(4.0f) + local_1) * vec2<f32>(gFrame_0.vtParams_0.x)), (0.0f)));
}

fn SrgbToLinear_0( c_2 : vec3<f32>) -> vec3<f32>
{
    return select(pow((c_2 + vec3<f32>(0.054999999701976776f)) / vec3<f32>(1.0549999475479126f), vec3<f32>(2.4000000953674316f)), c_2 / vec3<f32>(12.920000076293945f), (c_2 <= vec3<f32>(0.040449999272823334f)));
}

fn SampleTexture_0( ref_7 : TextureRef_0,  tc_2 : TextureCoords_0) -> vec4<f32>
{
    var useUV1_0 : bool = (((ref_7.flags_2) & (u32(4)))) != u32(0);
    var uv_3 : vec2<f32>;
    var _S85 : vec2<f32>;
    if(useUV1_0)
    {
        _S85 = tc_2.uv1_1;
    }
    else
    {
        _S85 = tc_2.uv0_0;
    }
    var _S86 : vec2<f32> = TransformUV_0(ref_7, _S85);
    uv_3 = _S86;
    uv_3[i32(0)] = WrapCoord_0(_S86.x, ((((ref_7.flags_2) >> (u32(8)))) & (u32(3))));
    uv_3[i32(1)] = WrapCoord_0(uv_3.y, ((((ref_7.flags_2) >> (u32(10)))) & (u32(3))));
    var color_1 : vec4<f32>;
    var _S87 : vec2<f32> = uv_3;
    var _S88 : f32;
    if(useUV1_0)
    {
        _S88 = tc_2.footprint1_0;
    }
    else
    {
        _S88 = tc_2.footprint0_0;
    }
    var _S89 : vec4<f32> = SampleVirtualTexture_0(ref_7, _S87, _S88);
    color_1 = _S89;
    if((((ref_7.flags_2) & (u32(2)))) != u32(0))
    {
        var _S90 : vec3<f32> = SrgbToLinear_0(color_1.xyz);
        color_1.x = _S90.x;
        color_1.y = _S90.y;
        color_1.z = _S90.z;
    }
    return color_1;
}

@id(1) override gMaterialOpcodesHigh_0 : u32 = u32(4294967295);

fn HashRotate_0( x_10 : u32,  k_0 : u32) -> u32
{
    return (((x_10 << (k_0))) | (((x_10 >> ((u32(32) - k_0))))));
}

fn HashFinal_0( a_2 : u32,  b_3 : u32,  c_3 : u32) -> u32
{
    var _S91 : u32 = ((c_3 ^ (b_3))) - HashRotate_0(b_3, u32(14));
    var _S92 : u32 = ((a_2 ^ (_S91))) - HashRotate_0(_S91, u32(11));
    var _S93 : u32 = ((b_3 ^ (_S92))) - HashRotate_0(_S92, u32(25));
    var _S94 : u32 = ((_S91 ^ (_S93))) - HashRotate_0(_S93, u32(16));
    var _S95 : u32 = ((_S92 ^ (_S94))) - HashRotate_0(_S94, u32(4));
    var _S96 : u32 = ((_S93 ^ (_S95))) - HashRotate_0(_S95, u32(14));
    return ((_S94 ^ (_S96))) - HashRotate_0(_S96, u32(24));
}

fn HashUint2_0( kx_0 : u32,  ky_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928580) + kx_0, u32(3735928580) + ky_0, u32(3735928580));
}

fn RandomOffset3_0( seed_1 : f32) -> vec3<f32>
{
    var _S97 : u32 = (bitcast<u32>((seed_1)));
    return vec3<f32>(100.0f) + vec3<f32>(f32(HashUint2_0(_S97, (bitcast<u32>((0.0f))))), f32(HashUint2_0(_S97, (bitcast<u32>((1.0f))))), f32(HashUint2_0(_S97, (bitcast<u32>((2.0f)))))) * vec3<f32>(2.32830643653869629e-08f);
}

fn FMod_0( x_11 : f32,  y_3 : f32) -> f32
{
    return x_11 - trunc(x_11 / y_3) * y_3;
}

fn NoiseFade_0( t_3 : f32) -> f32
{
    return t_3 * t_3 * t_3 * (t_3 * (t_3 * 6.0f - 15.0f) + 10.0f);
}

fn HashUint3_0( kx_1 : u32,  ky_1 : u32,  kz_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928584) + kx_1, u32(3735928584) + ky_1, u32(3735928584) + kz_0);
}

fn NoiseGrad3_0( hash_0 : u32,  x_12 : f32,  y_4 : f32,  z_1 : f32) -> f32
{
    var h_1 : u32 = (hash_0 & (u32(15)));
    var u_7 : f32;
    if((h_1 < u32(8)))
    {
        u_7 = x_12;
    }
    else
    {
        u_7 = y_4;
    }
    var v_1 : f32;
    if((h_1 < u32(4)))
    {
        v_1 = y_4;
    }
    else
    {
        var _S98 : bool;
        if(h_1 == u32(12))
        {
            _S98 = true;
        }
        else
        {
            _S98 = h_1 == u32(14);
        }
        if(_S98)
        {
            v_1 = x_12;
        }
        else
        {
            v_1 = z_1;
        }
    }
    if(((h_1 & (u32(1)))) != u32(0))
    {
        u_7 = - u_7;
    }
    if(((h_1 & (u32(2)))) != u32(0))
    {
        v_1 = - v_1;
    }
    return u_7 + v_1;
}

fn Perlin3_0( p_0 : vec3<f32>) -> f32
{
    var i_1 : vec3<f32> = floor(p_0);
    var f_0 : vec3<f32> = p_0 - i_1;
    var _S99 : u32 = (bitcast<u32>((i32(i_1.x))));
    var _S100 : u32 = (bitcast<u32>((i32(i_1.y))));
    var _S101 : u32 = (bitcast<u32>((i32(i_1.z))));
    var _S102 : f32 = f_0.x;
    var u_8 : f32 = NoiseFade_0(_S102);
    var _S103 : f32 = f_0.y;
    var v_2 : f32 = NoiseFade_0(_S103);
    var _S104 : f32 = f_0.z;
    var w_1 : f32 = NoiseFade_0(_S104);
    var g_0 : array<f32, i32(8)>;
    var c_4 : u32 = u32(0);
    loop
    {
        if((c_4 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var _S105 : u32 = (c_4 & (u32(1)));
        var _S106 : u32 = (((c_4 >> (u32(1)))) & (u32(1)));
        var _S107 : u32 = (c_4 >> (u32(2)));
        g_0[c_4] = NoiseGrad3_0(HashUint3_0(_S99 + _S105, _S100 + _S106, _S101 + _S107), _S102 - f32(_S105), _S103 - f32(_S106), _S104 - f32(_S107));
        c_4 = c_4 + u32(1);
    }
    return mix(mix(mix(g_0[i32(0)], g_0[i32(1)], u_8), mix(g_0[i32(2)], g_0[i32(3)], u_8), v_2), mix(mix(g_0[i32(4)], g_0[i32(5)], u_8), mix(g_0[i32(6)], g_0[i32(7)], u_8), v_2), w_1);
}

fn SNoise3_0( p_1 : vec3<f32>) -> f32
{
    return 0.98199999332427979f * Perlin3_0(vec3<f32>(FMod_0(p_1.x, 1.0e+05f), FMod_0(p_1.y, 1.0e+05f), FMod_0(p_1.z, 1.0e+05f)) + select(vec3<f32>(0.0f), vec3<f32>(0.5f), ((abs(p_1)) >= vec3<f32>(1.0e+06f))));
}

fn NoiseFbm_0( p_2 : vec3<f32>,  detail_0 : f32,  roughness_1 : f32,  lacunarity_0 : f32,  normalize_0 : bool) -> f32
{
    var sum2_0 : f32;
    var octaves_0 : i32 = i32(detail_0);
    var rmd_0 : f32 = detail_0 - floor(detail_0);
    var _S108 : bool = rmd_0 != 0.0f;
    var _S109 : i32;
    if(_S108)
    {
        _S109 = octaves_0 + i32(1);
    }
    else
    {
        _S109 = octaves_0;
    }
    var i_2 : i32 = i32(0);
    var fscale_0 : f32 = 1.0f;
    var sum_0 : f32 = 0.0f;
    var amp_0 : f32 = 1.0f;
    var maxamp_0 : f32 = 0.0f;
    loop
    {
        if((i_2 <= _S109))
        {
        }
        else
        {
            sum2_0 = 0.0f;
            break;
        }
        var n_4 : f32 = SNoise3_0(vec3<f32>(fscale_0) * p_2);
        if((i_2 > octaves_0))
        {
            sum2_0 = sum_0 + n_4 * amp_0;
            break;
        }
        var sum_1 : f32 = sum_0 + n_4 * amp_0;
        var maxamp_1 : f32 = maxamp_0 + amp_0;
        var amp_1 : f32 = amp_0 * roughness_1;
        var fscale_1 : f32 = fscale_0 * lacunarity_0;
        i_2 = i_2 + i32(1);
        fscale_0 = fscale_1;
        sum_0 = sum_1;
        amp_0 = amp_1;
        maxamp_0 = maxamp_1;
    }
    if(_S108)
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
        var b_4 : f32;
        if(normalize_0)
        {
            b_4 = 0.5f * sum2_0 / (maxamp_0 + amp_0) + 0.5f;
        }
        else
        {
            b_4 = sum2_0;
        }
        return mix(a_3, b_4, rmd_0);
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

fn BlenderNoise_0( co_0 : vec3<f32>,  params_0 : vec4<f32>,  normalize_1 : bool,  color_2 : bool) -> vec3<f32>
{
    var _S110 : f32 = clamp(params_0.x, 0.0f, 15.0f);
    var _S111 : f32 = max(params_0.y, 0.0f);
    var _S112 : f32 = params_0.z;
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
        var _S113 : u32;
        if(color_2)
        {
            _S113 = u32(3);
        }
        else
        {
            _S113 = u32(1);
        }
        if((k_1 < _S113))
        {
        }
        else
        {
            break;
        }
        var _S114 : vec3<f32>;
        if(k_1 == u32(0))
        {
            _S114 = p_3;
        }
        else
        {
            _S114 = p_3 + RandomOffset3_0(f32(k_1 + u32(2)));
        }
        result_0[k_1] = NoiseFbm_0(_S114, _S110, _S111, _S112, normalize_1);
        k_1 = k_1 + u32(1);
    }
    if(color_2)
    {
        p_3 = result_0;
    }
    else
    {
        p_3 = vec3<f32>(result_0.x);
    }
    return p_3;
}

fn BlenderMagic_0( p_4 : vec3<f32>,  depth_0 : u32,  d_1 : f32) -> vec3<f32>
{
    var TWO_PI_1 : f32 = 2.0f * float_getPi_0();
    var px_0 : f32 = FMod_0(p_4.x, TWO_PI_1);
    var py_0 : f32 = FMod_0(p_4.y, TWO_PI_1);
    var pz_0 : f32 = FMod_0(p_4.z, TWO_PI_1);
    var x_13 : f32 = sin((px_0 + py_0 + pz_0) * 5.0f);
    var _S115 : f32 = - px_0;
    var y_5 : f32 = cos((_S115 + py_0 - pz_0) * 5.0f);
    var z_2 : f32 = - cos((_S115 - py_0 + pz_0) * 5.0f);
    var x_14 : f32;
    var z_3 : f32;
    var y_6 : f32;
    if((depth_0 > u32(0)))
    {
        var x_15 : f32 = x_13 * d_1;
        var z_4 : f32 = z_2 * d_1;
        var y_7 : f32 = - cos(x_15 - y_5 * d_1 + z_4) * d_1;
        if((depth_0 > u32(1)))
        {
            x_14 = cos(x_15 - y_7 - z_4) * d_1;
        }
        else
        {
            x_14 = x_15;
        }
        if((depth_0 > u32(2)))
        {
            z_3 = sin(- x_14 - y_7 - z_4) * d_1;
        }
        else
        {
            z_3 = z_4;
        }
        if((depth_0 > u32(3)))
        {
            x_14 = - cos(- x_14 + y_7 - z_3) * d_1;
        }
        if((depth_0 > u32(4)))
        {
            y_6 = - sin(- x_14 + y_7 + z_3) * d_1;
        }
        else
        {
            y_6 = y_7;
        }
        if((depth_0 > u32(5)))
        {
            y_6 = - cos(- x_14 + y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(6)))
        {
            x_14 = cos(x_14 + y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(7)))
        {
            z_3 = sin(x_14 + y_6 - z_3) * d_1;
        }
        if((depth_0 > u32(8)))
        {
            x_14 = - cos(- x_14 - y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(9)))
        {
            y_6 = - sin(x_14 - y_6 + z_3) * d_1;
        }
    }
    else
    {
        x_14 = x_13;
        y_6 = y_5;
        z_3 = z_2;
    }
    if(d_1 != 0.0f)
    {
        var _S116 : f32 = 2.0f * d_1;
        var y_8 : f32 = y_6 / _S116;
        var z_5 : f32 = z_3 / _S116;
        x_14 = x_14 / _S116;
        y_6 = y_8;
        z_3 = z_5;
    }
    return vec3<f32>(0.5f - x_14, 0.5f - y_6, 0.5f - z_3);
}

fn BlenderChecker_0( p_5 : vec3<f32>) -> f32
{
    var i_3 : vec3<i32> = abs(vec3<i32>(floor((p_5 + vec3<f32>(9.99999997475242708e-07f)) * vec3<f32>(0.99999898672103882f))));
    var _S117 : f32;
    if(((((i_3.x) & (i32(1)))) == (((i_3.y) & (i32(1))))) == ((((i_3.z) & (i32(1)))) == i32(1)))
    {
        _S117 = 1.0f;
    }
    else
    {
        _S117 = 0.0f;
    }
    return _S117;
}

fn RunMaterialProgram_0( header_1 : MaterialHeader_0,  program_0 : u32,  ctx_2 : MaterialContext_0,  outputs_0 : ptr<function, MaterialOutputs_0>)
{
    var stack_0 : array<vec4<f32>, i32(16)>;
    var n_5 : u32 = u32(0);
    var pc_0 : u32 = program_0;
    loop
    {
        if((n_5 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var ins_0 : vec4<u32> = gMaterialData_0[pc_0];
        var _S118 : u32 = ins_0.x;
        var op_0 : u32 = (_S118 & (u32(255)));
        var dst_0 : u32 = (((_S118 >> (u32(8)))) & (u32(15)));
        var imm_0 : u32 = (_S118 >> (u32(16)));
        if(op_0 == u32(0))
        {
            return;
        }
        var _S119 : vec4<f32> = vec4<f32>(0.0f);
        var _S120 : bool;
        if(((gMaterialOperandMode_0 & (u32(2)))) == u32(0))
        {
            _S120 = true;
        }
        else
        {
            _S120 = op_0 != u32(23);
        }
        var write_0 : bool;
        var a_4 : vec4<f32>;
        var b_5 : vec4<f32>;
        var c_5 : vec4<f32>;
        if(_S120)
        {
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                write_0 = true;
            }
            else
            {
                write_0 = (((ins_0.y) & (u32(2147483648)))) == u32(0);
            }
            if(write_0)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    a_4 = stack_0[((ins_0.y) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.y) & (u32(15))))
                    {
                    case u32(0):
                        {
                            a_4 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            a_4 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            a_4 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            a_4 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            a_4 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            a_4 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            a_4 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            a_4 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            a_4 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            a_4 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            a_4 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            a_4 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            a_4 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            a_4 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            a_4 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            a_4 = stack_0[i32(15)];
                        }
                    default :
                        {
                            a_4 = _S119;
                        }
                    }
                }
            }
            else
            {
                a_4 = _S119;
            }
            var _S121 : vec4<f32> = MaterialOperand_0(ins_0.y, a_4, header_1.constantBase_0);
            var _S122 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S122 = true;
            }
            else
            {
                _S122 = (((ins_0.z) & (u32(2147483648)))) == u32(0);
            }
            if(_S122)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    b_5 = stack_0[((ins_0.z) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.z) & (u32(15))))
                    {
                    case u32(0):
                        {
                            b_5 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            b_5 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            b_5 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            b_5 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            b_5 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            b_5 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            b_5 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            b_5 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            b_5 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            b_5 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            b_5 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            b_5 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            b_5 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            b_5 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            b_5 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            b_5 = stack_0[i32(15)];
                        }
                    default :
                        {
                            b_5 = _S119;
                        }
                    }
                }
            }
            else
            {
                b_5 = _S119;
            }
            var _S123 : vec4<f32> = MaterialOperand_0(ins_0.z, b_5, header_1.constantBase_0);
            var _S124 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S124 = true;
            }
            else
            {
                _S124 = (((ins_0.w) & (u32(2147483648)))) == u32(0);
            }
            if(_S124)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    c_5 = stack_0[((ins_0.w) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.w) & (u32(15))))
                    {
                    case u32(0):
                        {
                            c_5 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            c_5 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            c_5 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            c_5 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            c_5 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            c_5 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            c_5 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            c_5 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            c_5 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            c_5 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            c_5 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            c_5 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            c_5 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            c_5 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            c_5 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            c_5 = stack_0[i32(15)];
                        }
                    default :
                        {
                            c_5 = _S119;
                        }
                    }
                }
            }
            else
            {
                c_5 = _S119;
            }
            var _S125 : vec4<f32> = MaterialOperand_0(ins_0.w, c_5, header_1.constantBase_0);
            a_4 = _S121;
            b_5 = _S123;
            c_5 = _S125;
        }
        else
        {
            a_4 = _S119;
            b_5 = _S119;
            c_5 = _S119;
        }
        var operands_0 : u32 = pc_0 * u32(4) + u32(1);
        var _S126 : u32;
        if(op_0 == u32(23))
        {
            _S126 = (((u32(351898) >> ((u32(2) * min(imm_0, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_0 == u32(17))
            {
                _S126 = u32(1) + imm_0 / u32(4);
            }
            else
            {
                _S126 = u32(1);
            }
        }
        var pc_1 : u32 = pc_0 + _S126;
        var r_2 : vec4<f32> = _S119;
        var slot_3 : vec4<f32>;
        switch(op_0)
        {
        case u32(1):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(1)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = a_4 + b_5;
                write_0 = true;
            }
        case u32(2):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = a_4 - b_5;
                write_0 = true;
            }
        case u32(3):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(3)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = a_4 * b_5;
                write_0 = true;
            }
        case u32(4):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(4)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = a_4 / b_5;
                write_0 = true;
            }
        case u32(5):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(5)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = min(a_4, b_5);
                write_0 = true;
            }
        case u32(6):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(6)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = max(a_4, b_5);
                write_0 = true;
            }
        case u32(7):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(7)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = pow(a_4, b_5);
                write_0 = true;
            }
        case u32(8):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(8)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = atan2(a_4, b_5);
                write_0 = true;
            }
        case u32(9):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(9)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = sqrt(a_4);
                write_0 = true;
            }
        case u32(10):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(10)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = sin(a_4);
                write_0 = true;
            }
        case u32(11):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(11)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = cos(a_4);
                write_0 = true;
            }
        case u32(12):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(12)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = abs(a_4);
                write_0 = true;
            }
        case u32(13):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(13)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = min(max(a_4, b_5), c_5);
                write_0 = true;
            }
        case u32(14):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(14)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = mix(a_4, b_5, c_5);
                write_0 = true;
            }
        case u32(15):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(15)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = vec4<f32>(a_4[min(imm_0, u32(3))]);
                write_0 = true;
            }
        case u32(16):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(16)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = select(vec4<f32>(f32((imm_0 >> (u32(8))))), a_4, LanesBelow_0((imm_0 & (u32(255)))));
                write_0 = true;
            }
        case u32(17):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(17)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = vec4<f32>(a_4.x, b_5.x, c_5.x, 0.0f);
                if((imm_0 > u32(3)))
                {
                    var o_1 : u32 = MaterialWord_0(operands_0 + u32(3));
                    if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                    {
                        write_0 = true;
                    }
                    else
                    {
                        write_0 = ((o_1 & (u32(2147483648)))) == u32(0);
                    }
                    if(write_0)
                    {
                        if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                        {
                            slot_3 = stack_0[(o_1 & (u32(15)))];
                        }
                        else
                        {
                            switch((o_1 & (u32(15))))
                            {
                            case u32(0):
                                {
                                    slot_3 = stack_0[i32(0)];
                                }
                            case u32(1):
                                {
                                    slot_3 = stack_0[i32(1)];
                                }
                            case u32(2):
                                {
                                    slot_3 = stack_0[i32(2)];
                                }
                            case u32(3):
                                {
                                    slot_3 = stack_0[i32(3)];
                                }
                            case u32(4):
                                {
                                    slot_3 = stack_0[i32(4)];
                                }
                            case u32(5):
                                {
                                    slot_3 = stack_0[i32(5)];
                                }
                            case u32(6):
                                {
                                    slot_3 = stack_0[i32(6)];
                                }
                            case u32(7):
                                {
                                    slot_3 = stack_0[i32(7)];
                                }
                            case u32(8):
                                {
                                    slot_3 = stack_0[i32(8)];
                                }
                            case u32(9):
                                {
                                    slot_3 = stack_0[i32(9)];
                                }
                            case u32(10):
                                {
                                    slot_3 = stack_0[i32(10)];
                                }
                            case u32(11):
                                {
                                    slot_3 = stack_0[i32(11)];
                                }
                            case u32(12):
                                {
                                    slot_3 = stack_0[i32(12)];
                                }
                            case u32(13):
                                {
                                    slot_3 = stack_0[i32(13)];
                                }
                            case u32(14):
                                {
                                    slot_3 = stack_0[i32(14)];
                                }
                            case u32(15):
                                {
                                    slot_3 = stack_0[i32(15)];
                                }
                            default :
                                {
                                    slot_3 = _S119;
                                }
                            }
                        }
                    }
                    else
                    {
                        slot_3 = _S119;
                    }
                    r_2[i32(3)] = MaterialOperand_0(o_1, slot_3, header_1.constantBase_0).x;
                }
                write_0 = true;
            }
        case u32(18):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(18)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var lanes_0 : vec4<bool> = LanesBelow_0(imm_0);
                r_2 = vec4<f32>(dot(select(_S119, a_4, lanes_0), select(_S119, b_5, lanes_0)));
                write_0 = true;
            }
        case u32(19):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(19)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var len_0 : f32 = length(select(_S119, a_4, LanesBelow_0(imm_0)));
                if((len_0 > 0.0f))
                {
                    slot_3 = a_4 / vec4<f32>(len_0);
                }
                else
                {
                    slot_3 = _S119;
                }
                r_2 = slot_3;
                write_0 = true;
            }
        case u32(20):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(20)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                if(imm_0 == u32(0))
                {
                    r_2 = vec4<f32>(ctx_2.tex_1.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_0 == u32(1))
                    {
                        r_2 = vec4<f32>(ctx_2.tex_1.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_0 == u32(6))
                        {
                            r_2 = vec4<f32>(ctx_2.tex_1.objectPosition_0, 0.0f);
                        }
                    }
                }
                write_0 = true;
            }
        case u32(21):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(21)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var ref_8 : TextureRef_0 = LoadTextureRef_0(header_1, imm_0);
                if(HasTexture_0(ref_8))
                {
                    var _S127 : vec4<f32> = SampleTexture_0(ref_8, ctx_2.tex_1);
                    slot_3 = _S127;
                }
                else
                {
                    slot_3 = vec4<f32>(1.0f);
                }
                r_2 = slot_3;
                write_0 = true;
            }
        case u32(22):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(22)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                write_0 = true;
            }
        case u32(24):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(24)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = floor(a_4);
                write_0 = true;
            }
        case u32(25):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(25)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = vec4<f32>((vec4<i32>(sign((a_4)))));
                write_0 = true;
            }
        case u32(26):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(26)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = exp(a_4);
                write_0 = true;
            }
        case u32(27):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(27)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = log(a_4);
                write_0 = true;
            }
        case u32(28):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(28)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = a_4 - b_5 * floor(a_4 / b_5);
                write_0 = true;
            }
        case u32(29):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(29)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = select(_S119, vec4<f32>(1.0f), (a_4 > b_5));
                write_0 = true;
            }
        case u32(30):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(30)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = vec4<f32>(cross(a_4.xyz, b_5.xyz), 0.0f);
                write_0 = true;
            }
        case u32(31):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(31)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                write_0 = true;
            }
        case u32(32):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(0)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var _S128 : bool = ((imm_0 & (u32(2)))) != u32(0);
                var v_3 : vec3<f32> = BlenderNoise_0(a_4.xyz, b_5, ((imm_0 & (u32(1)))) != u32(0), _S128);
                if(_S128)
                {
                    slot_3 = vec4<f32>(v_3, 0.0f);
                }
                else
                {
                    slot_3 = vec4<f32>(v_3.x);
                }
                r_2 = slot_3;
                write_0 = true;
            }
        case u32(33):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(1)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var c_6 : vec3<f32> = BlenderMagic_0(a_4.xyz, imm_0, b_5.x);
                r_2 = vec4<f32>(c_6, (c_6.x + c_6.y + c_6.z) / 3.0f);
                write_0 = true;
            }
        case u32(34):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_2 = vec4<f32>(BlenderChecker_0(a_4.xyz));
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
                        var o_2 : u32 = MaterialWord_0(operands_0);
                        if(o_2 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_2 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_3 = stack_0[(o_2 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_2 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_3 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_3 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_3 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_3 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_3 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_3 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_3 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_3 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_3 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_3 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_3 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_3 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_3 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_3 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_3 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_3 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_3 = _S119;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_3 = _S119;
                            }
                            (*outputs_0).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_2, slot_3, header_1.constantBase_0).x;
                        }
                        var o_3 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_3 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_3 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_3 = stack_0[(o_3 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_3 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_3 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_3 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_3 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_3 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_3 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_3 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_3 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_3 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_3 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_3 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_3 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_3 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_3 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_3 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_3 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_3 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_3 = _S119;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_3 = _S119;
                            }
                            (*outputs_0).inputs_0.emissionColor_0 = MaterialOperand_0(o_3, slot_3, header_1.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_4 : u32 = MaterialWord_0(operands_0);
                        if(o_4 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_4 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_3 = stack_0[(o_4 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_4 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_3 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_3 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_3 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_3 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_3 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_3 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_3 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_3 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_3 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_3 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_3 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_3 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_3 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_3 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_3 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_3 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_3 = _S119;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_3 = _S119;
                            }
                            (*outputs_0).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_4, slot_3, header_1.constantBase_0).x;
                        }
                        var o_5 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_5 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_5 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_3 = stack_0[(o_5 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_5 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_3 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_3 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_3 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_3 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_3 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_3 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_3 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_3 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_3 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_3 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_3 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_3 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_3 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_3 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_3 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_3 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_3 = _S119;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_3 = _S119;
                            }
                            (*outputs_0).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_5, slot_3, header_1.constantBase_0).x) != 0.0f;
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
            if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
            {
                stack_0[dst_0] = r_2;
            }
            else
            {
                switch(dst_0)
                {
                case u32(0):
                    {
                        stack_0[i32(0)] = r_2;
                    }
                case u32(1):
                    {
                        stack_0[i32(1)] = r_2;
                    }
                case u32(2):
                    {
                        stack_0[i32(2)] = r_2;
                    }
                case u32(3):
                    {
                        stack_0[i32(3)] = r_2;
                    }
                case u32(4):
                    {
                        stack_0[i32(4)] = r_2;
                    }
                case u32(5):
                    {
                        stack_0[i32(5)] = r_2;
                    }
                case u32(6):
                    {
                        stack_0[i32(6)] = r_2;
                    }
                case u32(7):
                    {
                        stack_0[i32(7)] = r_2;
                    }
                case u32(8):
                    {
                        stack_0[i32(8)] = r_2;
                    }
                case u32(9):
                    {
                        stack_0[i32(9)] = r_2;
                    }
                case u32(10):
                    {
                        stack_0[i32(10)] = r_2;
                    }
                case u32(11):
                    {
                        stack_0[i32(11)] = r_2;
                    }
                case u32(12):
                    {
                        stack_0[i32(12)] = r_2;
                    }
                case u32(13):
                    {
                        stack_0[i32(13)] = r_2;
                    }
                case u32(14):
                    {
                        stack_0[i32(14)] = r_2;
                    }
                case u32(15):
                    {
                        stack_0[i32(15)] = r_2;
                    }
                default :
                    {
                    }
                }
            }
        }
        n_5 = n_5 + u32(1);
        pc_0 = pc_1;
    }
    return;
}

fn RunScalarMaterialProgram_0( header_2 : MaterialHeader_0,  program_1 : u32,  tc_3 : TextureCoords_0) -> MaterialOutputs_0
{
    var ctx_3 : MaterialContext_0 = MakeMaterialContext_0(tc_3);
    var o_6 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_3);
    RunMaterialProgram_0(header_2, program_1, ctx_3, &(o_6));
    return o_6;
}

fn EvalOpacity_0( header_3 : MaterialHeader_0,  tc_4 : TextureCoords_0) -> f32
{
    if((header_3.opacity_0) == u32(4294967295))
    {
        return 1.0f;
    }
    var _S129 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_3, header_3.opacity_0, tc_4);
    return _S129.inputs_0.geometryOpacity_0;
}

fn EvalEmission_0( header_4 : MaterialHeader_0,  tc_5 : TextureCoords_0) -> vec3<f32>
{
    if((header_4.emission_1) == u32(4294967295))
    {
        return vec3<f32>(0.0f);
    }
    var o_7 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_4, header_4.emission_1, tc_5);
    return o_7.inputs_0.emissionColor_0 * vec3<f32>(o_7.inputs_0.emissionLuminance_0);
}

fn EmissiveRadiance_0( material_0 : MaterialHeader_0,  tc_6 : TextureCoords_0) -> vec3<f32>
{
    var _S130 : bool;
    if((MaterialHeader_AlphaMode_0(material_0)) == u32(1))
    {
        var _S131 : f32 = EvalOpacity_0(material_0, tc_6);
        _S130 = (_S131 < (material_0.alphaCutoff_0));
    }
    else
    {
        _S130 = false;
    }
    if(_S130)
    {
        return vec3<f32>(0.0f);
    }
    var _S132 : vec3<f32> = EvalEmission_0(material_0, tc_6);
    return _S132;
}

fn EmissiveSolidAnglePdf_0( area_0 : f32,  doubleSided_0 : bool,  viewer_1 : vec3<f32>,  lightPos_0 : vec3<f32>,  lightNormal_0 : vec3<f32>) -> f32
{
    var toLight_1 : vec3<f32> = lightPos_0 - viewer_1;
    var distSq_3 : f32 = dot(toLight_1, toLight_1);
    if((distSq_3 <= 9.999999960041972e-13f))
    {
        return 0.0f;
    }
    var cosTheta_4 : f32 = dot(lightNormal_0, (vec3<f32>(0) - toLight_1 * vec3<f32>(rsqrt_0(distSq_3))));
    var cosTheta_5 : f32;
    if(doubleSided_0)
    {
        cosTheta_5 = abs(cosTheta_4);
    }
    else
    {
        cosTheta_5 = cosTheta_4;
    }
    if((cosTheta_5 <= 9.99999997475242708e-07f))
    {
        return 0.0f;
    }
    return distSq_3 / (cosTheta_5 * area_0);
}

fn SampleEmissive_0( viewer_2 : vec3<f32>,  cone_0 : vec2<f32>,  rng_2 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_5 : LightSample_0;
    s_5.delta_0 = false;
    s_5.shadow_0 = true;
    var _S133 : f32 = RandomSequence_Next_1(&((*rng_2)));
    var _S134 : EmissiveTriangle_std430_0 = gLights_0[SelectLight_0(_S133)];
    var _S135 : u32 = AnalyticFlags_0(&(_S134));
    if(((_S135 & (u32(2147483648)))) != u32(0))
    {
        var _S136 : LightSample_0 = SampleAnalytic_0(&(_S134), viewer_2, &((*rng_2)));
        return _S136;
    }
    var _S137 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_2)));
    var bary_0 : vec3<f32> = SampleTriangle_0(_S137);
    var _S138 : vec4<f32> = _S134.p0_0;
    var _S139 : vec3<f32> = _S134.p0_0.xyz;
    var _S140 : f32 = bary_0.x;
    var _S141 : vec4<f32> = _S134.p1_0;
    var _S142 : vec3<f32> = _S134.p1_0.xyz;
    var _S143 : f32 = bary_0.y;
    var _S144 : vec3<f32> = _S134.p2_0.xyz;
    var _S145 : f32 = bary_0.z;
    var _S146 : vec3<f32> = _S139 * vec3<f32>(_S140) + _S142 * vec3<f32>(_S143) + _S144 * vec3<f32>(_S145);
    s_5.position_1 = _S146;
    s_5.normal_7 = _S134.n_0.xyz;
    var material_1 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S134.n_0.w))));
    var doubleSided_1 : bool = MaterialHeader_DoubleSided_0(material_1);
    var toLight_2 : vec3<f32> = _S146 - viewer_2;
    var dist_0 : f32 = length(toLight_2);
    var tc_7 : TextureCoords_0;
    var _S147 : vec2<f32> = _S134.uvA_0.xy;
    var _S148 : vec2<f32> = vec2<f32>(_S140);
    var _S149 : vec2<f32> = _S134.uvA_0.zw;
    var _S150 : vec2<f32> = vec2<f32>(_S143);
    var _S151 : vec2<f32> = _S134.uvB_0.xy;
    var _S152 : vec2<f32> = vec2<f32>(_S145);
    var _S153 : vec2<f32> = _S147 * _S148 + _S149 * _S150 + _S151 * _S152;
    var _S154 : vec2<f32> = _S134.uvB_0.zw;
    var _S155 : vec2<f32> = _S134.uvC_0.xy;
    var _S156 : vec2<f32> = _S134.uvC_0.zw;
    var _S157 : vec2<f32> = _S154 * _S148 + _S155 * _S150 + _S156 * _S152;
    var _S158 : vec3<f32> = _S142 - _S139;
    var _S159 : vec3<f32> = _S144 - _S139;
    var _S160 : vec2<f32> = _S149 - _S147;
    var _S161 : vec2<f32> = _S151 - _S147;
    var _S162 : vec2<f32> = _S155 - _S154;
    var _S163 : vec2<f32> = _S156 - _S154;
    var _S164 : f32 = cone_0.x + cone_0.y * dist_0;
    var _S165 : f32;
    if((dist_0 > 0.0f))
    {
        _S165 = dot(s_5.normal_7, toLight_2) / dist_0;
    }
    else
    {
        _S165 = 1.0f;
    }
    tc_7 = MakeTextureCoords_0(_S153, _S157, _S158, _S159, _S160, _S161, _S162, _S163, _S164, _S165);
    tc_7.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((_S134.pad_0.x))), s_5.position_1);
    var _S166 : vec3<f32> = EmissiveRadiance_0(material_1, tc_7);
    s_5.radiance_0 = _S166;
    s_5.solidAnglePdf_0 = _S141.w * EmissiveSolidAnglePdf_0(_S138.w, doubleSided_1, viewer_2, s_5.position_1, s_5.normal_7);
    var _S167 : bool;
    if(doubleSided_1)
    {
        _S167 = ((dot(s_5.normal_7, viewer_2 - s_5.position_1)) < 0.0f);
    }
    else
    {
        _S167 = false;
    }
    if(_S167)
    {
        s_5.normal_7 = (vec3<f32>(0) - s_5.normal_7);
    }
    return s_5;
}

fn SunEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(2)))) != u32(0);
}

fn Square_0( x_16 : f32) -> f32
{
    return x_16 * x_16;
}

fn SampleSun_0( rng_3 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var toSun_0 : vec3<f32> = gFrame_0.sunDirection_0.xyz;
    var t_4 : vec3<f32>;
    var b_6 : vec3<f32>;
    BranchlessONB_0(toSun_0, &(t_4), &(b_6));
    var _S168 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_3)));
    var disk_0 : vec2<f32> = SampleDisk_0(_S168);
    var dir_6 : vec3<f32> = normalize(toSun_0 + (t_4 * vec3<f32>(disk_0.x) + b_6 * vec3<f32>(disk_0.y)) * vec3<f32>(sqrt(max(0.0f, 1.0f - Square_0(gFrame_0.sunDirection_0.w)))));
    var s_6 : LightSample_0;
    s_6.position_1 = vec3<f32>(0.0f);
    s_6.normal_7 = (vec3<f32>(0) - dir_6);
    s_6.radiance_0 = gFrame_0.sunRadiance_0.xyz;
    s_6.solidAnglePdf_0 = 1.0f / gFrame_0.sunRadiance_0.w;
    s_6.delta_0 = false;
    s_6.shadow_0 = true;
    return s_6;
}

struct DiffuseSpecular_0
{
     diffuse_1 : vec3<f32>,
     specular_1 : vec3<f32>,
};

struct SampledLobe_0
{
     layer_0 : i32,
     lobe_1 : i32,
     f_1 : DiffuseSpecular_0,
     pdf_0 : f32,
};

fn DiffuseSpecular_x24init_0( diffuse_2 : vec3<f32>,  specular_2 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S169 : DiffuseSpecular_0;
    _S169.diffuse_1 = diffuse_2;
    _S169.specular_1 = specular_2;
    return _S169;
}

fn DiffuseSpecular_Zero_0() -> DiffuseSpecular_0
{
    var _S170 : vec3<f32> = vec3<f32>(0.0f);
    return DiffuseSpecular_x24init_0(_S170, _S170);
}

fn SampledLobe_None_0() -> SampledLobe_0
{
    var s_7 : SampledLobe_0;
    s_7.layer_0 = i32(0);
    s_7.lobe_1 = i32(-1);
    s_7.f_1 = DiffuseSpecular_Zero_0();
    s_7.pdf_0 = 0.0f;
    return s_7;
}

fn BaseLobeEnabled_0( index_10 : i32) -> bool
{
    return true;
}

fn BaseLobe_IsActive_0( this_5 : BaseLobe_0,  index_11 : i32) -> bool
{
    var _S171 : bool;
    if(BaseLobeEnabled_0(index_11))
    {
        _S171 = ((this_5.weights_0[index_11]) > 0.0f);
    }
    else
    {
        _S171 = false;
    }
    return _S171;
}

fn Frame_ToLocal_0( this_6 : Frame_0,  v_4 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(v_4, this_6.t_0), dot(v_4, this_6.b_0), dot(v_4, this_6.n_1));
}

fn EvalGGX_0( m_0 : vec3<f32>,  alpha_4 : vec2<f32>) -> f32
{
    var _S172 : f32 = alpha_4.x;
    var _S173 : f32 = alpha_4.y;
    return 1.0f / (float_getPi_0() * _S172 * _S173 * Square_0(Square_0(m_0.x / _S172) + Square_0(m_0.y / _S173) + Square_0(m_0.z)));
}

fn GGXDistribution_D_0( this_7 : GGXDistribution_0,  m_1 : vec3<f32>) -> f32
{
    return EvalGGX_0(Frame_ToLocal_0(this_7.frame_1, m_1), this_7.alpha_0);
}

fn ThinFilmPresence_0( thickness_0 : f32) -> f32
{
    return smoothstep(9.99999971718068537e-10f, 30.0f, thickness_0);
}

fn BaseReflectionTransmission_ThinFilmPresenceAt_0( this_8 : BaseReflectionTransmission_0,  idoth_0 : f32) -> f32
{
    var _S174 : f32;
    if((idoth_0 >= 0.0f))
    {
        _S174 = this_8.thinFilmWeight_0 * ThinFilmPresence_0(this_8.thinFilmThickness_0);
    }
    else
    {
        _S174 = 0.0f;
    }
    return _S174;
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

fn FresnelDielectric_1( eta_4 : vec3<f32>,  cosThetaI_1 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(eta_4.x, cosThetaI_1), FresnelDielectric_0(eta_4.y, cosThetaI_1), FresnelDielectric_0(eta_4.z, cosThetaI_1));
}

fn FifthPower_0( x_17 : f32) -> f32
{
    var xx_0 : f32 = x_17 * x_17;
    return xx_0 * xx_0 * x_17;
}

fn SixthPower_0( x_18 : f32) -> f32
{
    var xx_1 : f32 = x_18 * x_18;
    return xx_1 * xx_1 * xx_1;
}

fn MetalSchlickBFactor_0( f0_0 : vec3<f32>,  f82Tint_0 : vec3<f32>) -> vec3<f32>
{
    var _S175 : vec3<f32> = vec3<f32>(1.0f);
    return (f0_0 + (_S175 - f0_0) * vec3<f32>(FifthPower_0(0.8571428656578064f))) * (_S175 - f82Tint_0) * vec3<f32>((1.0f / (0.1428571492433548f * SixthPower_0(0.8571428656578064f))));
}

fn FresnelMetalF82_0( f0_1 : vec3<f32>,  f82Tint_1 : vec3<f32>,  cosTheta_6 : f32) -> vec3<f32>
{
    var oneMinusCos_1 : f32 = 1.0f - cosTheta_6;
    return saturate(f0_1 + (vec3<f32>(1.0f) - f0_1 - MetalSchlickBFactor_0(f0_1, f82Tint_1) * vec3<f32>(cosTheta_6) * vec3<f32>(oneMinusCos_1)) * vec3<f32>(FifthPower_0(oneMinusCos_1)));
}

fn BaseReflectionTransmission_HasDielectric_0( this_9 : BaseReflectionTransmission_0) -> bool
{
    var _S176 : vec3<f32> = vec3<f32>(0.0f);
    var _S177 : bool;
    if((any((((this_9.reflectionScaleTransparent_0) > _S176)))))
    {
        _S177 = true;
    }
    else
    {
        _S177 = (any((((this_9.reflectionScaleOpaque_0) > _S176))));
    }
    return _S177;
}

fn BaseReflectionTransmission_HasMetal_0( this_10 : BaseReflectionTransmission_0) -> bool
{
    return ((this_10.metalAmount_0) > 0.0f);
}

struct ThinFilmResults_0
{
     dielectric_0 : vec3<f32>,
     metal_0 : vec3<f32>,
};

struct Polarized_0
{
     s_8 : f32,
     p_6 : f32,
};

fn FresnelAmplitudesDielectric_0( cosThetaI_2 : f32,  etaI_0 : f32,  etaT_0 : f32,  r_3 : ptr<function, Polarized_0>,  t_5 : ptr<function, Polarized_0>,  cosThetaT_1 : ptr<function, f32>)
{
    var sinThetaT_0 : f32 = etaI_0 / etaT_0 * sqrt(saturate(1.0f - cosThetaI_2 * cosThetaI_2));
    if((sinThetaT_0 >= 1.0f))
    {
        (*r_3).s_8 = 1.0f;
        (*r_3).p_6 = 1.0f;
        (*t_5).s_8 = 0.0f;
        (*t_5).p_6 = 0.0f;
        (*cosThetaT_1) = 0.0f;
        return;
    }
    var _S178 : f32 = sqrt(saturate(1.0f - sinThetaT_0 * sinThetaT_0));
    (*cosThetaT_1) = _S178;
    var etaICosI_0 : f32 = etaI_0 * cosThetaI_2;
    var etaTCosT_0 : f32 = etaT_0 * _S178;
    var etaTCosI_0 : f32 = etaT_0 * cosThetaI_2;
    var etaICosT_0 : f32 = etaI_0 * _S178;
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
    (*r_3).s_8 = (etaICosI_0 - etaTCosT_0) * rcpS_0;
    (*r_3).p_6 = (etaTCosI_0 - etaICosT_0) * rcpP_0;
    var _S179 : f32 = 2.0f * etaICosI_0;
    (*t_5).s_8 = _S179 * rcpS_0;
    (*t_5).p_6 = _S179 * rcpP_0;
    return;
}

struct PolarizedComplex_0
{
     s_9 : vec2<f32>,
     p_7 : vec2<f32>,
};

fn ComplexDiv_0( a_5 : vec2<f32>,  b_7 : vec2<f32>,  minMagnitude_0 : f32,  fallback_0 : vec2<f32>) -> vec2<f32>
{
    var denominator_0 : f32 = dot(b_7, b_7);
    if((denominator_0 < (minMagnitude_0 * minMagnitude_0)))
    {
        return fallback_0;
    }
    var rcpDenominator_0 : f32 = 1.0f / denominator_0;
    var _S180 : f32 = a_5.x;
    var _S181 : f32 = b_7.x;
    var _S182 : f32 = a_5.y;
    var _S183 : f32 = b_7.y;
    return vec2<f32>((_S180 * _S181 + _S182 * _S183) * rcpDenominator_0, (_S182 * _S181 - _S180 * _S183) * rcpDenominator_0);
}

fn ComplexMul_0( a_6 : vec2<f32>,  b_8 : vec2<f32>) -> vec2<f32>
{
    var _S184 : f32 = a_6.x;
    var _S185 : f32 = b_8.x;
    var _S186 : f32 = a_6.y;
    var _S187 : f32 = b_8.y;
    return vec2<f32>(_S184 * _S185 - _S186 * _S187, _S184 * _S187 + _S186 * _S185);
}

fn SignNonZero_0( x_19 : f32) -> f32
{
    var _S188 : f32;
    if((x_19 >= 0.0f))
    {
        _S188 = 1.0f;
    }
    else
    {
        _S188 = -1.0f;
    }
    return _S188;
}

fn ComplexSqrt_0( z_6 : vec2<f32>) -> vec2<f32>
{
    var r_4 : f32 = length(z_6);
    var _S189 : f32 = z_6.x;
    return vec2<f32>(sqrt(max((r_4 + _S189) * 0.5f, 0.0f)), SignNonZero_0(z_6.y) * sqrt(max((r_4 - _S189) * 0.5f, 0.0f)));
}

fn RefractedCosine_0( cosThetaI_3 : f32,  etaI_1 : f32,  etaT_1 : vec2<f32>) -> vec2<f32>
{
    const _S190 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var sinThetaT_1 : vec2<f32> = vec2<f32>(sqrt(saturate(1.0f - cosThetaI_3 * cosThetaI_3))) * ComplexDiv_0(vec2<f32>(etaI_1, 0.0f), etaT_1, 9.99999971718068537e-10f, _S190);
    var cosThetaT_2 : vec2<f32> = ComplexSqrt_0(_S190 - ComplexMul_0(sinThetaT_1, sinThetaT_1));
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
    const _S191 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    r_5.s_9 = ComplexDiv_0(etaICosI_1 - etaTCosT_1, etaICosI_1 + etaTCosT_1, 9.99999971718068537e-10f, _S191);
    r_5.p_7 = ComplexDiv_0(etaTCosI_1 - etaICosT_1, etaTCosI_1 + etaICosT_1, 9.99999971718068537e-10f, _S191);
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
    return 0.5f * (AiryReflectance_0(r12_1.s_8, t12_1.s_8, r21_1.s_8, t21_1.s_8, r23_1.s_9, expIPhi_1) + AiryReflectance_0(r12_1.p_6, t12_1.p_6, r21_1.p_6, t21_1.p_6, r23_1.p_7, expIPhi_1));
}

fn GulbrandsenIor_0( r_6 : f32,  g_1 : f32) -> vec2<f32>
{
    var clampedR_0 : f32 = clamp(r_6, 0.0f, 0.99000000953674316f);
    var sqrtR_0 : f32 = sqrt(clampedR_0);
    var _S192 : f32 = 1.0f - clampedR_0;
    var n_6 : f32 = mix((1.0f + sqrtR_0) / (1.0f - sqrtR_0), _S192 / (1.0f + clampedR_0), g_1);
    return vec2<f32>(n_6, sqrt(max((Square_0(n_6 + 1.0f) * clampedR_0 - Square_0(n_6 - 1.0f)) / _S192, 0.0f)));
}

fn ThinFilmAndBaseReflectance_0( cosThetaI_5 : f32,  etaExterior_0 : f32,  etaFilm_0 : f32,  etaBase_0 : vec3<f32>,  dispersion_0 : bool,  metalF0_1 : vec3<f32>,  metalF82Tint_1 : vec3<f32>,  enableDielectric_0 : bool,  enableMetal_0 : bool,  thickness_1 : f32,  wavelengths_1 : vec3<f32>) -> ThinFilmResults_0
{
    var results_0 : ThinFilmResults_0;
    var _S193 : vec3<f32> = vec3<f32>(0.0f);
    results_0.dielectric_0 = _S193;
    results_0.metal_0 = _S193;
    var _S194 : bool;
    if(enableDielectric_0)
    {
        _S194 = true;
    }
    else
    {
        _S194 = enableMetal_0;
    }
    if(!_S194)
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
    r21_2.s_8 = - r12_2.s_8;
    r21_2.p_6 = - r12_2.p_6;
    var t21Scale_0 : f32 = etaFilm_0 * cosThetaFilm_0 / (etaExterior_0 * max(cosThetaI_5, 9.99999971718068537e-10f));
    var t21_2 : Polarized_0;
    t21_2.s_8 = t12_2.s_8 * t21Scale_0;
    t21_2.p_6 = t12_2.p_6 * t21Scale_0;
    var _S195 : vec3<f32> = vec3<f32>((2.0f * float_getPi_0() * (2.0f * etaFilm_0 * thickness_1 * cosThetaFilm_0))) / wavelengths_1;
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
                _S194 = true;
            }
            else
            {
                _S194 = c_7 == i32(0);
            }
            if(_S194)
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
            results_0.dielectric_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, r23_2[c_7], _S195[c_7]);
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
            results_0.metal_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, GulbrandsenIor_0(metalF0_1[c_7], metalF82Tint_1[c_7])), _S195[c_7]);
            c_7 = c_7 + i32(1);
        }
    }
    return results_0;
}

fn BaseReflectionTransmission_ThinFilm_0( this_11 : BaseReflectionTransmission_0,  idoth_1 : f32,  enableDielectric_1 : bool,  enableMetal_1 : bool) -> ThinFilmResults_0
{
    return ThinFilmAndBaseReflectance_0(idoth_1, this_11.thinFilmExteriorIor_0, this_11.thinFilmIor_0, this_11.thinFilmInteriorIor_0, true, this_11.metalF0_0, this_11.metalF82Tint_0, enableDielectric_1, enableMetal_1, this_11.thinFilmThickness_0, this_11.wavelengths_0);
}

fn BaseReflectionTransmission_Reflection_0( this_12 : BaseReflectionTransmission_0,  idoth_2 : f32) -> vec3<f32>
{
    var standard_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_2 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_12, idoth_2);
    var standard_1 : vec3<f32>;
    if((presence_2 < 1.0f))
    {
        standard_1 = this_12.reflectionScaleTransparent_0 * FresnelDielectric_1(this_12.etaTransparent_0, idoth_2) + this_12.reflectionScaleOpaque_0 * FresnelDielectric_1(this_12.etaOpaque_0, idoth_2) + vec3<f32>(this_12.metalAmount_0) * FresnelMetalF82_0(this_12.metalF0_0, this_12.metalF82Tint_0, idoth_2);
    }
    else
    {
        standard_1 = standard_0;
    }
    var thinFilm_0 : vec3<f32>;
    if((presence_2 > 0.0f))
    {
        var film_0 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_12, idoth_2, BaseReflectionTransmission_HasDielectric_0(this_12), BaseReflectionTransmission_HasMetal_0(this_12));
        thinFilm_0 = this_12.reflectionScaleTransparent_0 * film_0.dielectric_0 + this_12.reflectionScaleOpaque_0 * film_0.dielectric_0 + vec3<f32>(this_12.metalAmount_0) * film_0.metal_0;
    }
    else
    {
        thinFilm_0 = standard_0;
    }
    return mix(standard_1, thinFilm_0, vec3<f32>(presence_2)) + this_12.thinWallReflection_0;
}

fn SmithG1_0( v_5 : vec3<f32>,  alpha_5 : vec2<f32>) -> f32
{
    var vz2_0 : f32 = Square_0(v_5.z);
    if(vz2_0 == 0.0f)
    {
        return 0.0f;
    }
    return 2.0f / (1.0f + sqrt(1.0f + (Square_0(alpha_5.x * v_5.x) + Square_0(alpha_5.y * v_5.y)) / vz2_0));
}

fn GGXDistribution_G2_0( this_13 : GGXDistribution_0,  wo_1 : vec3<f32>,  wi_0 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_13.frame_1, wo_1), this_13.alpha_0) * SmithG1_0(Frame_ToLocal_0(this_13.frame_1, wi_0), this_13.alpha_0);
}

fn DiffuseSpecular_Specular_0( value_0 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(vec3<f32>(0.0f), value_0);
}

fn SpecularLobe_ValidTransmissionHalfVector_0( this_14 : SpecularLobe_0,  h_2 : vec3<f32>) -> bool
{
    var _S196 : f32 = this_14.eta_0.x;
    var _S197 : bool;
    if((_S196 >= 1.0f))
    {
        _S197 = ((dot(this_14.normal_1, h_2)) > 0.0f);
    }
    else
    {
        _S197 = false;
    }
    if(_S197)
    {
        _S197 = true;
    }
    else
    {
        if((_S196 < 1.0f))
        {
            _S197 = ((dot(this_14.normal_1, h_2)) < 0.0f);
        }
        else
        {
            _S197 = false;
        }
    }
    return _S197;
}

fn SpecularLobe_TransmissionTerms_0( this_15 : SpecularLobe_0,  wo_2 : vec3<f32>,  wi_1 : vec3<f32>,  idotn_0 : f32,  channelEta_0 : f32,  d_2 : ptr<function, f32>,  otherTerms_0 : ptr<function, f32>,  absIdoth_0 : ptr<function, f32>) -> bool
{
    (*d_2) = 0.0f;
    (*otherTerms_0) = 0.0f;
    (*absIdoth_0) = 0.0f;
    var h_3 : vec3<f32> = (vec3<f32>(0) - normalize(wo_2 + wi_1 * vec3<f32>(channelEta_0)));
    if(!SpecularLobe_ValidTransmissionHalfVector_0(this_15, h_3))
    {
        return false;
    }
    var idoth_3 : f32 = dot(wo_2, h_3);
    var odoth_0 : f32 = dot(wi_1, h_3);
    if(((idoth_3 * odoth_0) >= 0.0f))
    {
        return false;
    }
    (*d_2) = GGXDistribution_D_0(this_15.distribution_0, h_3);
    var _S198 : f32 = abs(idoth_3);
    (*otherTerms_0) = Square_0(channelEta_0) * _S198 * abs(odoth_0) / (Square_0(idoth_3 + channelEta_0 * odoth_0) * idotn_0);
    (*absIdoth_0) = _S198;
    return true;
}

fn BaseReflectionTransmission_Transmission_0( this_16 : BaseReflectionTransmission_0,  idoth_4 : f32) -> vec3<f32>
{
    var standard_2 : vec3<f32> = vec3<f32>(0.0f);
    var presence_3 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_16, idoth_4);
    var standard_3 : vec3<f32>;
    if((presence_3 < 1.0f))
    {
        standard_3 = this_16.transmission_0 * (vec3<f32>(1.0f) - FresnelDielectric_1(this_16.etaTransparent_0, idoth_4));
    }
    else
    {
        standard_3 = standard_2;
    }
    var thinFilm_1 : vec3<f32>;
    if((presence_3 > 0.0f))
    {
        thinFilm_1 = this_16.transmission_0 * (vec3<f32>(1.0f) - BaseReflectionTransmission_ThinFilm_0(this_16, idoth_4, (any((((this_16.reflectionScaleTransparent_0) > standard_2)))), false).dielectric_0);
    }
    else
    {
        thinFilm_1 = standard_2;
    }
    return mix(standard_3, thinFilm_1, vec3<f32>(presence_3));
}

fn SpecularLobe_Eval_0( this_17 : SpecularLobe_0,  wo_3 : vec3<f32>,  wi_2 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_1 : f32 = dot(this_17.normal_1, wo_3);
    var _S199 : f32 = idotn_1 * dot(this_17.normal_1, wi_2);
    if((_S199 > 0.0f))
    {
        var h_4 : vec3<f32> = normalize(wo_3 + wi_2);
        return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_17.distribution_0, wo_3, wi_2)) * (vec3<f32>((GGXDistribution_D_0(this_17.distribution_0, h_4) * (1.0f / (4.0f * idotn_1)))) * BaseReflectionTransmission_Reflection_0(this_17.coefficient_0, abs(dot(wo_3, h_4)))));
    }
    if((_S199 >= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var dOtherTermsF_0 : vec3<f32>;
    var d_3 : f32;
    var otherTerms_1 : f32;
    var absIdoth_1 : f32;
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
        var _S200 : bool = SpecularLobe_TransmissionTerms_0(this_17, wo_3, wi_2, idotn_1, this_17.eta_0[c_8], &(d_3), &(otherTerms_1), &(absIdoth_1));
        var _S201 : f32;
        if(_S200)
        {
            _S201 = d_3 * otherTerms_1 * BaseReflectionTransmission_Transmission_0(this_17.coefficient_0, absIdoth_1)[c_8];
        }
        else
        {
            _S201 = 0.0f;
        }
        dOtherTermsF_0[c_8] = _S201;
        c_8 = c_8 + i32(1);
    }
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_17.distribution_0, wo_3, wi_2)) * dOtherTermsF_0);
}

struct ReflectionTransmission_0
{
     reflection_1 : vec3<f32>,
     transmission_1 : vec3<f32>,
     reflectionProbability_0 : f32,
     transmissionProbability_0 : f32,
};

fn BaseReflectionTransmission_Coefficients_0( this_18 : BaseReflectionTransmission_0,  idoth_5 : f32) -> ReflectionTransmission_0
{
    var standardReflection_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_4 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_18, idoth_5);
    var standardReflection_1 : vec3<f32>;
    var standardTransmission_0 : vec3<f32>;
    if((presence_4 < 1.0f))
    {
        var fresnel_0 : vec3<f32> = FresnelDielectric_1(this_18.etaTransparent_0, idoth_5);
        var _S202 : vec3<f32> = this_18.transmission_0 * (vec3<f32>(1.0f) - fresnel_0);
        standardReflection_1 = this_18.reflectionScaleTransparent_0 * fresnel_0 + this_18.reflectionScaleOpaque_0 * FresnelDielectric_1(this_18.etaOpaque_0, idoth_5) + vec3<f32>(this_18.metalAmount_0) * FresnelMetalF82_0(this_18.metalF0_0, this_18.metalF82Tint_0, idoth_5);
        standardTransmission_0 = _S202;
    }
    else
    {
        standardReflection_1 = standardReflection_0;
        standardTransmission_0 = standardReflection_0;
    }
    var thinFilmReflection_0 : vec3<f32>;
    var thinFilmTransmission_0 : vec3<f32>;
    if((presence_4 > 0.0f))
    {
        var film_1 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_18, idoth_5, BaseReflectionTransmission_HasDielectric_0(this_18), BaseReflectionTransmission_HasMetal_0(this_18));
        var _S203 : vec3<f32> = this_18.transmission_0 * (vec3<f32>(1.0f) - film_1.dielectric_0);
        thinFilmReflection_0 = this_18.reflectionScaleTransparent_0 * film_1.dielectric_0 + this_18.reflectionScaleOpaque_0 * film_1.dielectric_0 + vec3<f32>(this_18.metalAmount_0) * film_1.metal_0;
        thinFilmTransmission_0 = _S203;
    }
    else
    {
        thinFilmReflection_0 = standardReflection_0;
        thinFilmTransmission_0 = standardReflection_0;
    }
    var result_1 : ReflectionTransmission_0;
    var _S204 : vec3<f32> = vec3<f32>(presence_4);
    result_1.reflection_1 = mix(standardReflection_1, thinFilmReflection_0, _S204) + this_18.thinWallReflection_0;
    result_1.transmission_1 = mix(standardTransmission_0, thinFilmTransmission_0, _S204);
    result_1.reflectionProbability_0 = 0.0f;
    result_1.transmissionProbability_0 = 0.0f;
    return result_1;
}

fn MaxComponent_0( v_6 : vec3<f32>) -> f32
{
    return max(v_6.x, max(v_6.y, v_6.z));
}

fn ThroughputWeightedMax_0( throughput_1 : vec3<f32>,  color_3 : vec3<f32>) -> f32
{
    return MaxComponent_0(throughput_1 * color_3);
}

fn SafeDivide_0( numerator_0 : f32,  denominator_1 : f32,  fallback_1 : f32) -> f32
{
    var _S205 : f32;
    if(denominator_1 != 0.0f)
    {
        _S205 = numerator_0 / denominator_1;
    }
    else
    {
        _S205 = fallback_1;
    }
    return _S205;
}

fn BaseReflectionTransmission_CoefficientsAndProbabilities_0( this_19 : BaseReflectionTransmission_0,  throughput_2 : vec3<f32>,  idoth_6 : f32) -> ReflectionTransmission_0
{
    var result_2 : ReflectionTransmission_0 = BaseReflectionTransmission_Coefficients_0(this_19, idoth_6);
    var reflectionMax_0 : f32 = ThroughputWeightedMax_0(throughput_2, result_2.reflection_1);
    var transmissionMax_0 : f32 = ThroughputWeightedMax_0(throughput_2, result_2.transmission_1);
    var sum_2 : f32 = reflectionMax_0 + transmissionMax_0;
    result_2.reflectionProbability_0 = SafeDivide_0(reflectionMax_0, sum_2, 0.0f);
    result_2.transmissionProbability_0 = SafeDivide_0(transmissionMax_0, sum_2, 0.0f);
    return result_2;
}

fn BaseReflectionTransmission_ReflectionProbability_0( this_20 : BaseReflectionTransmission_0,  throughput_3 : vec3<f32>,  idoth_7 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_20, throughput_3, idoth_7).reflectionProbability_0;
}

fn GGXDistribution_G1_0( this_21 : GGXDistribution_0,  v_7 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_21.frame_1, v_7), this_21.alpha_0);
}

fn BaseReflectionTransmission_TransmissionProbability_0( this_22 : BaseReflectionTransmission_0,  throughput_4 : vec3<f32>,  idoth_8 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_22, throughput_4, idoth_8).transmissionProbability_0;
}

fn Sum_0( v_8 : vec3<f32>) -> f32
{
    return v_8.x + v_8.y + v_8.z;
}

fn SpecularLobe_ChannelProbabilities_0( this_23 : SpecularLobe_0) -> vec3<f32>
{
    return this_23.throughput_0 / vec3<f32>(Sum_0(this_23.throughput_0));
}

fn SpecularLobe_Pdf_0( this_24 : SpecularLobe_0,  wo_4 : vec3<f32>,  wi_3 : vec3<f32>) -> f32
{
    var idotn_2 : f32 = dot(this_24.normal_1, wo_4);
    var _S206 : f32 = idotn_2 * dot(this_24.normal_1, wi_3);
    if((_S206 > 0.0f))
    {
        var h_5 : vec3<f32> = normalize(wo_4 + wi_3);
        var idoth_9 : f32 = dot(wo_4, h_5);
        var odoth_1 : f32 = dot(wi_3, h_5);
        if(((idoth_9 * odoth_1) < 0.0f))
        {
            return 0.0f;
        }
        return GGXDistribution_G1_0(this_24.distribution_0, wo_4) * (BaseReflectionTransmission_ReflectionProbability_0(this_24.coefficient_0, this_24.throughput_0, abs(idoth_9)) * GGXDistribution_D_0(this_24.distribution_0, h_5) * (idoth_9 / (4.0f * odoth_1 * idotn_2)));
    }
    if((_S206 >= 0.0f))
    {
        return 0.0f;
    }
    var d_4 : f32;
    var otherTerms_2 : f32;
    var absIdoth_2 : f32;
    var probabilityDOtherTerms_0 : vec3<f32>;
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
        var _S207 : bool = SpecularLobe_TransmissionTerms_0(this_24, wo_4, wi_3, idotn_2, this_24.eta_0[c_9], &(d_4), &(otherTerms_2), &(absIdoth_2));
        var _S208 : f32;
        if(_S207)
        {
            _S208 = BaseReflectionTransmission_TransmissionProbability_0(this_24.coefficient_0, this_24.throughput_0, absIdoth_2) * d_4 * otherTerms_2;
        }
        else
        {
            _S208 = 0.0f;
        }
        probabilityDOtherTerms_0[c_9] = _S208;
        c_9 = c_9 + i32(1);
    }
    return GGXDistribution_G1_0(this_24.distribution_0, wo_4) * dot(probabilityDOtherTerms_0, SpecularLobe_ChannelProbabilities_0(this_24));
}

fn DielectricMultipleScatteringLobe_Active_0( this_25 : DielectricMultipleScatteringLobe_0) -> bool
{
    return ((this_25.alpha_1) >= 0.0015999999595806003f);
}

fn IorToExactIndex_0( ior_0 : f32) -> f32
{
    if((ior_0 < 1.0f))
    {
        return 15.0f - (1.0f / ior_0 - 1.0f) * 0.66666668653488159f * 15.0f;
    }
    return 16.0f + (ior_0 - 1.0f) * 0.66666668653488159f * 15.0f;
}

fn AlphaToExactIndex_0( alpha_6 : f32) -> f32
{
    return sqrt(alpha_6) * 31.0f;
}

fn CosToExactIndex_0( cosTheta_7 : f32) -> f32
{
    return cosTheta_7 * 31.0f;
}

fn ClampExactIndex_0( index_12 : f32) -> f32
{
    return clamp(index_12, 0.0f, 31.0f);
}

fn FetchTable_0( x_20 : i32,  y_9 : i32,  slice_0 : i32) -> f32
{
    var _S209 : vec4<i32> = vec4<i32>(x_20, y_9, slice_0, i32(0));
    return (textureLoad((gBSDFTables_0), ((_S209)).xyz, ((_S209)).w).x);
}

fn FetchEnergy_0( x_21 : i32,  y_10 : i32,  slice_1 : i32) -> f32
{
    return FetchTable_0(x_21, y_10, slice_1) * 1.5259021893143654e-05f;
}

fn LookUpTrilinear_0( firstSlice_0 : i32,  exactX_0 : f32,  exactY_0 : f32,  exactZ_0 : f32) -> f32
{
    var x_22 : f32 = ClampExactIndex_0(exactX_0);
    var y_11 : f32 = ClampExactIndex_0(exactY_0);
    var z_7 : f32 = ClampExactIndex_0(exactZ_0);
    var ix0_0 : i32 = i32(floor(x_22));
    var iy0_0 : i32 = i32(floor(y_11));
    var iz0_0 : i32 = i32(floor(z_7));
    var _S210 : i32 = min(iy0_0 + i32(1), i32(31));
    var _S211 : i32 = min(iz0_0 + i32(1), i32(31));
    var tx_0 : f32 = x_22 - f32(ix0_0);
    var ty_0 : f32 = y_11 - f32(iy0_0);
    var _S212 : i32 = firstSlice_0 + ix0_0;
    var _S213 : i32 = firstSlice_0 + min(ix0_0 + i32(1), i32(31));
    return mix(mix(mix(FetchEnergy_0(iz0_0, iy0_0, _S212), FetchEnergy_0(iz0_0, iy0_0, _S213), tx_0), mix(FetchEnergy_0(iz0_0, _S210, _S212), FetchEnergy_0(iz0_0, _S210, _S213), tx_0), ty_0), mix(mix(FetchEnergy_0(_S211, iy0_0, _S212), FetchEnergy_0(_S211, iy0_0, _S213), tx_0), mix(FetchEnergy_0(_S211, _S210, _S212), FetchEnergy_0(_S211, _S210, _S213), tx_0), ty_0), z_7 - f32(iz0_0));
}

fn IdealDielectricEnergyComplement_0( ior_1 : f32,  alpha_7 : f32,  cosTheta_8 : f32) -> f32
{
    return LookUpTrilinear_0(i32(0), IorToExactIndex_0(ior_1), AlphaToExactIndex_0(alpha_7), CosToExactIndex_0(cosTheta_8));
}

fn LookUpBilinear_0( slice_2 : i32,  exactX_1 : f32,  exactY_1 : f32) -> f32
{
    var x_23 : f32 = ClampExactIndex_0(exactX_1);
    var y_12 : f32 = ClampExactIndex_0(exactY_1);
    var ix0_1 : i32 = i32(floor(x_23));
    var iy0_1 : i32 = i32(floor(y_12));
    var _S214 : i32 = min(ix0_1 + i32(1), i32(31));
    var _S215 : i32 = min(iy0_1 + i32(1), i32(31));
    var tx_1 : f32 = x_23 - f32(ix0_1);
    return mix(mix(FetchEnergy_0(iy0_1, ix0_1, slice_2), FetchEnergy_0(iy0_1, _S214, slice_2), tx_1), mix(FetchEnergy_0(_S215, ix0_1, slice_2), FetchEnergy_0(_S215, _S214, slice_2), tx_1), y_12 - f32(iy0_1));
}

fn IdealDielectricAverageEnergyComplement_0( ior_2 : f32,  alpha_8 : f32) -> f32
{
    return LookUpBilinear_0(i32(64), IorToExactIndex_0(ior_2), AlphaToExactIndex_0(alpha_8));
}

fn ClampAverageEnergyComplement_0( value_1 : f32) -> f32
{
    return max(value_1, 9.999999960041972e-13f);
}

fn DielectricMultipleScatteringLobe_TabulatedFactors_0( this_26 : DielectricMultipleScatteringLobe_0,  odotn_0 : f32,  includeRatio_0 : bool) -> f32
{
    var iorToUse_0 : f32;
    var _S216 : f32;
    var ratio_0 : f32;
    if((odotn_0 <= 0.0f))
    {
        var _S217 : f32 = - odotn_0;
        var _S218 : f32 = 1.0f - this_26.reflectionRatio_0;
        iorToUse_0 = 1.0f / this_26.eta_1;
        _S216 = _S217;
        ratio_0 = _S218;
    }
    else
    {
        iorToUse_0 = this_26.eta_1;
        _S216 = odotn_0;
        ratio_0 = this_26.reflectionRatio_0;
    }
    var factors_0 : f32 = this_26.energyComplementWo_0 * IdealDielectricEnergyComplement_0(iorToUse_0, this_26.alpha_1, _S216) / ClampAverageEnergyComplement_0(IdealDielectricAverageEnergyComplement_0(iorToUse_0, this_26.alpha_1));
    var factors_1 : f32;
    if(includeRatio_0)
    {
        factors_1 = factors_0 * ratio_0;
    }
    else
    {
        factors_1 = factors_0;
    }
    return min(factors_1, SafeDivide_0(1.0f, _S216, 0.0f));
}

fn DielectricMultipleScatteringLobe_Eval_0( this_27 : DielectricMultipleScatteringLobe_0,  wo_5 : vec3<f32>,  wi_4 : vec3<f32>) -> DiffuseSpecular_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_27))
    {
        return DiffuseSpecular_Zero_0();
    }
    var odotn_1 : f32 = dot(wi_4, this_27.normal_2);
    var unscaledCos_0 : f32 = DielectricMultipleScatteringLobe_TabulatedFactors_0(this_27, odotn_1, true) * (1.0f / float_getPi_0()) * abs(odotn_1);
    var _S219 : vec3<f32>;
    if((odotn_1 > 0.0f))
    {
        _S219 = this_27.reflectionScale_0;
    }
    else
    {
        _S219 = this_27.transmissionScale_0;
    }
    return DiffuseSpecular_Specular_0(_S219 * vec3<f32>(unscaledCos_0));
}

fn DielectricMultipleScatteringLobe_Pdf_0( this_28 : DielectricMultipleScatteringLobe_0,  wo_6 : vec3<f32>,  wi_5 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_28))
    {
        return 0.0f;
    }
    var _S220 : f32;
    if(((dot(wi_5, this_28.normal_2)) > 0.0f))
    {
        _S220 = this_28.reflectionRatio_0;
    }
    else
    {
        _S220 = 1.0f - this_28.reflectionRatio_0;
    }
    return 0.5f / float_getPi_0() * _S220;
}

fn MetalMultipleScatteringLobe_Active_0( this_29 : MetalMultipleScatteringLobe_0) -> bool
{
    return ((this_29.alpha_2) >= 0.0015999999595806003f);
}

fn IdealMetalEnergyComplement_0( alpha_9 : f32,  cosTheta_9 : f32) -> f32
{
    return LookUpBilinear_0(i32(67), AlphaToExactIndex_0(alpha_9), CosToExactIndex_0(cosTheta_9));
}

fn LookUpLinear_0( slice_3 : i32,  exactX_2 : f32) -> f32
{
    var x_24 : f32 = ClampExactIndex_0(exactX_2);
    var i0_0 : i32 = i32(floor(x_24));
    return mix(FetchEnergy_0(i0_0, i32(0), slice_3), FetchEnergy_0(min(i0_0 + i32(1), i32(31)), i32(0), slice_3), x_24 - f32(i0_0));
}

fn IdealMetalAverageEnergyComplement_0( alpha_10 : f32) -> f32
{
    return LookUpLinear_0(i32(68), AlphaToExactIndex_0(alpha_10));
}

fn MetalMultipleScatteringLobe_TabulatedFactors_0( this_30 : MetalMultipleScatteringLobe_0,  odotn_2 : f32) -> f32
{
    return min(this_30.energyComplementWo_1 * IdealMetalEnergyComplement_0(this_30.alpha_2, odotn_2) / ClampAverageEnergyComplement_0(IdealMetalAverageEnergyComplement_0(this_30.alpha_2)), SafeDivide_0(1.0f, odotn_2, 0.0f));
}

fn MetalMultipleScatteringLobe_Eval_0( this_31 : MetalMultipleScatteringLobe_0,  wo_7 : vec3<f32>,  wi_6 : vec3<f32>) -> DiffuseSpecular_0
{
    var odotn_3 : f32 = dot(wi_6, this_31.normal_3);
    var _S221 : bool;
    if(!MetalMultipleScatteringLobe_Active_0(this_31))
    {
        _S221 = true;
    }
    else
    {
        _S221 = (odotn_3 <= 0.0f);
    }
    if(_S221)
    {
        return DiffuseSpecular_Zero_0();
    }
    return DiffuseSpecular_Specular_0(this_31.scale_0 * vec3<f32>((MetalMultipleScatteringLobe_TabulatedFactors_0(this_31, odotn_3) * (1.0f / float_getPi_0()) * odotn_3)));
}

fn MetalMultipleScatteringLobe_Pdf_0( this_32 : MetalMultipleScatteringLobe_0,  wo_8 : vec3<f32>,  wi_7 : vec3<f32>) -> f32
{
    var _S222 : bool;
    if(MetalMultipleScatteringLobe_Active_0(this_32))
    {
        _S222 = ((dot(wi_7, this_32.normal_3)) > 0.0f);
    }
    else
    {
        _S222 = false;
    }
    var _S223 : f32;
    if(_S222)
    {
        _S223 = 0.5f / float_getPi_0();
    }
    else
    {
        _S223 = 0.0f;
    }
    return _S223;
}

fn BasisFromNormal_0( n_7 : vec3<f32>) -> Frame_0
{
    var _S224 : f32 = n_7.z;
    var s_10 : f32;
    if((_S224 < 0.0f))
    {
        s_10 = -1.0f;
    }
    else
    {
        s_10 = 1.0f;
    }
    var a_7 : f32 = -1.0f / (s_10 + _S224);
    var _S225 : f32 = n_7.x;
    var _S226 : f32 = n_7.y;
    var b_9 : f32 = _S225 * _S226 * a_7;
    var f_2 : Frame_0;
    f_2.n_1 = n_7;
    f_2.t_0 = vec3<f32>(b_9, s_10 + _S226 * _S226 * a_7, - _S226);
    f_2.b_0 = vec3<f32>(1.0f + s_10 * _S225 * _S225 * a_7, s_10 * b_9, - s_10 * _S225);
    return f_2;
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
    var s_11 : f32 = dot(viewLocal_0, lightLocal_0) - muI_0 * muO_0;
    var sOverT_0 : f32;
    if((s_11 > 0.0f))
    {
        sOverT_0 = s_11 / max(muI_0, muO_0);
    }
    else
    {
        sOverT_0 = s_11;
    }
    var PI_4 : f32 = float_getPi_0();
    var aF_0 : f32 = 1.0f / (1.0f + (0.5f - 2.0f / (3.0f * PI_4)) * roughness_3);
    var averageEF_0 : f32 = aF_0 * (1.0f + (0.66666668653488159f - 28.0f / (15.0f * PI_4)) * roughness_3);
    var _S227 : f32 = 1.0f - averageEF_0;
    return rho_0 * vec3<f32>((1.0f / PI_4)) * vec3<f32>(aF_0) * vec3<f32>((1.0f + roughness_3 * sOverT_0)) + rho_0 * rho_0 * vec3<f32>(averageEF_0) / (vec3<f32>(1.0f) - rho_0 * vec3<f32>(_S227)) * vec3<f32>((1.0f / PI_4)) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muO_0, roughness_3))) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muI_0, roughness_3))) / vec3<f32>(max(1.00000001168609742e-07f, _S227));
}

fn F0FromIor_0( eta_5 : f32) -> f32
{
    return Square_0((eta_5 - 1.0f) / (eta_5 + 1.0f));
}

fn ExtrapolateBeyondIorMax_0( tableValue_0 : f32,  ior_3 : f32) -> f32
{
    var _S228 : bool;
    if((ior_3 > 2.5f))
    {
        _S228 = true;
    }
    else
    {
        _S228 = (ior_3 < 0.40000000596046448f);
    }
    if(_S228)
    {
        var F0_MAX_0 : f32 = F0FromIor_0(2.5f);
        return (1.0f - (F0FromIor_0(ior_3) - F0_MAX_0) * (1.0f / (1.0f - F0_MAX_0))) * tableValue_0;
    }
    return tableValue_0;
}

fn OpaqueDielectricEnergyComplement_0( ior_4 : f32,  alpha_11 : f32,  cosTheta_10 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpTrilinear_0(i32(32), IorToExactIndex_0(ior_4), AlphaToExactIndex_0(alpha_11), CosToExactIndex_0(cosTheta_10)), ior_4);
}

fn DiffuseLobe_BRDFLocal_0( this_33 : DiffuseLobe_0,  woLocal_1 : vec3<f32>,  wiLocal_0 : vec3<f32>) -> vec3<f32>
{
    return EvalEON_0(this_33.albedo_1, this_33.roughness_0, woLocal_1, wiLocal_0) * vec3<f32>((this_33.specularCompensation_0 * OpaqueDielectricEnergyComplement_0(this_33.specularEta_0, this_33.specularAlpha_0, wiLocal_0.z)));
}

fn DiffuseSpecular_Diffuse_0( value_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(value_2, vec3<f32>(0.0f));
}

fn DiffuseLobe_Eval_0( this_34 : DiffuseLobe_0,  wo_9 : vec3<f32>,  wi_8 : vec3<f32>) -> DiffuseSpecular_0
{
    var cosOut_0 : f32 = dot(wi_8, this_34.normal_4);
    if((cosOut_0 <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var basis_2 : Frame_0 = BasisFromNormal_0(this_34.normal_4);
    return DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_34, Frame_ToLocal_0(basis_2, wo_9), Frame_ToLocal_0(basis_2, wi_8)) * vec3<f32>(cosOut_0));
}

fn DiffuseLobe_Pdf_0( this_35 : DiffuseLobe_0,  wo_10 : vec3<f32>,  wi_9 : vec3<f32>) -> f32
{
    return max(dot(wi_9, this_35.normal_4), 0.0f) * (1.0f / float_getPi_0());
}

fn MicrofacetReflectionLobe_GetNormal_0( this_36 : MicrofacetReflectionLobe_0) -> vec3<f32>
{
    return this_36.normal_5;
}

fn ConstantReflection_Reflection_0( this_37 : ConstantReflection_0,  idoth_10 : f32) -> vec3<f32>
{
    return this_37.color_0;
}

fn MicrofacetReflectionLobe_Eval_0( this_38 : MicrofacetReflectionLobe_0,  wo_11 : vec3<f32>,  wi_10 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_3 : f32 = dot(this_38.normal_5, wo_11);
    if(((idotn_3 * dot(this_38.normal_5, wi_10)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_6 : vec3<f32> = normalize(wo_11 + wi_10);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_38.distribution_1, wo_11, wi_10)) * (vec3<f32>((GGXDistribution_D_0(this_38.distribution_1, h_6) * (1.0f / (4.0f * idotn_3)))) * ConstantReflection_Reflection_0(this_38.coefficient_1, abs(dot(wo_11, h_6)))));
}

fn FlippedLobe_Eval_0( this_39 : FlippedLobe_0,  wo_12 : vec3<f32>,  wi_11 : vec3<f32>) -> DiffuseSpecular_0
{
    return MicrofacetReflectionLobe_Eval_0(this_39.lobe_0, reflect(wo_12, MicrofacetReflectionLobe_GetNormal_0(this_39.lobe_0)), wi_11);
}

fn MicrofacetReflectionLobe_Pdf_0( this_40 : MicrofacetReflectionLobe_0,  wo_13 : vec3<f32>,  wi_12 : vec3<f32>) -> f32
{
    var idotn_4 : f32 = dot(this_40.normal_5, wo_13);
    if(((idotn_4 * dot(this_40.normal_5, wi_12)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_7 : vec3<f32> = normalize(wo_13 + wi_12);
    var idoth_11 : f32 = dot(wo_13, h_7);
    var odoth_2 : f32 = dot(wi_12, h_7);
    if(((idoth_11 * odoth_2) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_40.distribution_1, wo_13) * (GGXDistribution_D_0(this_40.distribution_1, h_7) * (idoth_11 / (4.0f * odoth_2 * idotn_4)));
}

fn FlippedLobe_Pdf_0( this_41 : FlippedLobe_0,  wo_14 : vec3<f32>,  wi_13 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_Pdf_0(this_41.lobe_0, reflect(wo_14, MicrofacetReflectionLobe_GetNormal_0(this_41.lobe_0)), wi_13);
}

fn DiffuseLobe_GetNormal_0( this_42 : DiffuseLobe_0) -> vec3<f32>
{
    return this_42.normal_4;
}

fn FlippedLobe_Eval_1( this_43 : FlippedLobe_1,  wo_15 : vec3<f32>,  wi_14 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseLobe_Eval_0(this_43.lobe_0, reflect(wo_15, DiffuseLobe_GetNormal_0(this_43.lobe_0)), wi_14);
}

fn FlippedLobe_Pdf_1( this_44 : FlippedLobe_1,  wo_16 : vec3<f32>,  wi_15 : vec3<f32>) -> f32
{
    return DiffuseLobe_Pdf_0(this_44.lobe_0, reflect(wo_16, DiffuseLobe_GetNormal_0(this_44.lobe_0)), wi_15);
}

fn BaseLobe_LobeEvalPdf_0( this_45 : BaseLobe_0,  index_13 : i32,  wo_17 : vec3<f32>,  wi_16 : vec3<f32>,  f_3 : ptr<function, DiffuseSpecular_0>,  pdf_1 : ptr<function, f32>)
{
    switch(index_13)
    {
    case i32(0):
        {
            (*f_3) = SpecularLobe_Eval_0(this_45.specular_0, wo_17, wi_16);
            (*pdf_1) = SpecularLobe_Pdf_0(this_45.specular_0, wo_17, wi_16);
        }
    case i32(1):
        {
            (*f_3) = DielectricMultipleScatteringLobe_Eval_0(this_45.dielectricMultipleScattering_0, wo_17, wi_16);
            (*pdf_1) = DielectricMultipleScatteringLobe_Pdf_0(this_45.dielectricMultipleScattering_0, wo_17, wi_16);
        }
    case i32(2):
        {
            (*f_3) = MetalMultipleScatteringLobe_Eval_0(this_45.metalMultipleScattering_0, wo_17, wi_16);
            (*pdf_1) = MetalMultipleScatteringLobe_Pdf_0(this_45.metalMultipleScattering_0, wo_17, wi_16);
        }
    case i32(3):
        {
            (*f_3) = DiffuseLobe_Eval_0(this_45.diffuse_0, wo_17, wi_16);
            (*pdf_1) = DiffuseLobe_Pdf_0(this_45.diffuse_0, wo_17, wi_16);
        }
    case i32(4):
        {
            (*f_3) = FlippedLobe_Eval_0(this_45.thinWallSpecularTransmission_0, wo_17, wi_16);
            (*pdf_1) = FlippedLobe_Pdf_0(this_45.thinWallSpecularTransmission_0, wo_17, wi_16);
        }
    default :
        {
            (*f_3) = FlippedLobe_Eval_1(this_45.thinWallDiffuseTransmission_0, wo_17, wi_16);
            (*pdf_1) = FlippedLobe_Pdf_1(this_45.thinWallDiffuseTransmission_0, wo_17, wi_16);
        }
    }
    return;
}

fn x2B_0( a_8 : DiffuseSpecular_0,  b_10 : DiffuseSpecular_0) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_8.diffuse_1 + b_10.diffuse_1, a_8.specular_1 + b_10.specular_1);
}

fn BaseLobe_EvalPdf_0( this_46 : BaseLobe_0,  wo_18 : vec3<f32>,  wi_17 : vec3<f32>,  sampled_0 : SampledLobe_0,  f_4 : ptr<function, DiffuseSpecular_0>,  pdf_2 : ptr<function, f32>)
{
    (*f_4) = DiffuseSpecular_Zero_0();
    var i_4 : i32 = i32(0);
    var sum_3 : f32 = 0.0f;
    var totalWeight_0 : f32 = 0.0f;
    loop
    {
        if((i_4 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_46, i_4))
        {
            var lobeF_0 : DiffuseSpecular_0 = sampled_0.f_1;
            var lobePdf_0 : f32 = sampled_0.pdf_0;
            var _S229 : bool;
            if((sampled_0.layer_0) != i32(1))
            {
                _S229 = true;
            }
            else
            {
                _S229 = (sampled_0.lobe_1) != i_4;
            }
            if(_S229)
            {
                BaseLobe_LobeEvalPdf_0(this_46, i_4, wo_18, wi_17, &(lobeF_0), &(lobePdf_0));
            }
            (*f_4) = x2B_0((*f_4), lobeF_0);
            var totalWeight_1 : f32 = totalWeight_0 + this_46.weights_0[i_4];
            sum_3 = sum_3 + this_46.weights_0[i_4] * lobePdf_0;
            totalWeight_0 = totalWeight_1;
        }
        i_4 = i_4 + i32(1);
    }
    if((totalWeight_0 > 0.0f))
    {
        sum_3 = sum_3 / totalWeight_0;
    }
    else
    {
        sum_3 = 0.0f;
    }
    (*pdf_2) = sum_3;
    return;
}

fn MinComponent_0( v_9 : vec3<f32>) -> f32
{
    return min(min(v_9.x, v_9.y), v_9.z);
}

fn SafePow_0( a_9 : f32,  b_11 : f32) -> f32
{
    var _S230 : f32;
    if((a_9 > 0.0f))
    {
        _S230 = pow(a_9, b_11);
    }
    else
    {
        _S230 = 0.0f;
    }
    return _S230;
}

fn SafePow_1( a_10 : vec3<f32>,  b_12 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(SafePow_0(a_10.x, b_12.x), SafePow_0(a_10.y, b_12.y), SafePow_0(a_10.z, b_12.z));
}

fn CoatLobe_PassageColor_0( this_47 : CoatLobe_0,  cosine_0 : f32) -> vec3<f32>
{
    var _S231 : bool;
    if((cosine_0 > 0.0f))
    {
        _S231 = ((MinComponent_0(this_47.tint_0)) < 1.0f);
    }
    else
    {
        _S231 = false;
    }
    if(_S231)
    {
        return mix(vec3<f32>(1.0f), SafePow_1(sqrt(this_47.tint_0), vec3<f32>((1.0f / sqrt(max(0.0f, 1.0f - (1.0f - Square_0(cosine_0)) / Square_0(this_47.reflection_0.coefficient_1.eta_2)))))), vec3<f32>(this_47.presence_0));
    }
    return vec3<f32>(1.0f);
}

fn x2A_0( a_11 : DiffuseSpecular_0,  scale_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_11.diffuse_1 * scale_2, a_11.specular_1 * scale_2);
}

fn CoatLobe_HasCoat_0( this_48 : CoatLobe_0) -> bool
{
    return ((this_48.presence_0) > 0.0f);
}

fn DielectricReflection_Reflection_0( this_49 : DielectricReflection_0,  idoth_12 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(this_49.eta_2, idoth_12));
}

fn MicrofacetReflectionLobe_Eval_1( this_50 : MicrofacetReflectionLobe_1,  wo_19 : vec3<f32>,  wi_18 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_5 : f32 = dot(this_50.normal_5, wo_19);
    if(((idotn_5 * dot(this_50.normal_5, wi_18)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_8 : vec3<f32> = normalize(wo_19 + wi_18);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_50.distribution_1, wo_19, wi_18)) * (vec3<f32>((GGXDistribution_D_0(this_50.distribution_1, h_8) * (1.0f / (4.0f * idotn_5)))) * DielectricReflection_Reflection_0(this_50.coefficient_1, abs(dot(wo_19, h_8)))));
}

fn CoatLobe_CoatEval_0( this_51 : CoatLobe_0,  wo_20 : vec3<f32>,  wi_19 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S232 : DiffuseSpecular_0;
    if(CoatLobe_HasCoat_0(this_51))
    {
        _S232 = MicrofacetReflectionLobe_Eval_1(this_51.reflection_0, wo_20, wi_19);
    }
    else
    {
        _S232 = DiffuseSpecular_Zero_0();
    }
    return _S232;
}

fn x2A_1( a_12 : DiffuseSpecular_0,  scale_3 : f32) -> DiffuseSpecular_0
{
    var _S233 : vec3<f32> = vec3<f32>(scale_3);
    return DiffuseSpecular_x24init_0(a_12.diffuse_1 * _S233, a_12.specular_1 * _S233);
}

fn CoatLobe_BaseLayerScaleOneSide_0( this_52 : CoatLobe_0,  cosine_1 : f32,  reflectedFromThisSide_0 : f32) -> vec3<f32>
{
    return CoatLobe_PassageColor_0(this_52, cosine_1) * vec3<f32>((1.0f - reflectedFromThisSide_0));
}

fn CoatLobe_BaseLayerScaleComplete_0( this_53 : CoatLobe_0,  wi_20 : vec3<f32>) -> vec3<f32>
{
    return this_53.inBaseLayerScale_0 * CoatLobe_BaseLayerScaleOneSide_0(this_53, dot(wi_20, this_53.normal_6), 0.0f);
}

fn CoatLobe_Combine_0( this_54 : CoatLobe_0,  coatEval_0 : DiffuseSpecular_0,  baseEval_0 : DiffuseSpecular_0,  wi_21 : vec3<f32>) -> DiffuseSpecular_0
{
    return x2B_0(x2A_1(coatEval_0, this_54.presence_0), x2A_0(baseEval_0, CoatLobe_BaseLayerScaleComplete_0(this_54, wi_21)));
}

fn MicrofacetReflectionLobe_Pdf_1( this_55 : MicrofacetReflectionLobe_1,  wo_21 : vec3<f32>,  wi_22 : vec3<f32>) -> f32
{
    var idotn_6 : f32 = dot(this_55.normal_5, wo_21);
    if(((idotn_6 * dot(this_55.normal_5, wi_22)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_9 : vec3<f32> = normalize(wo_21 + wi_22);
    var idoth_13 : f32 = dot(wo_21, h_9);
    var odoth_3 : f32 = dot(wi_22, h_9);
    if(((idoth_13 * odoth_3) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_55.distribution_1, wo_21) * (GGXDistribution_D_0(this_55.distribution_1, h_9) * (idoth_13 / (4.0f * odoth_3 * idotn_6)));
}

fn BaseLobe_TotalWeight_0( this_56 : BaseLobe_0) -> f32
{
    var total_0 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        total_0 = this_56.weights_0[i32(0)];
    }
    else
    {
        total_0 = 0.0f;
    }
    if(BaseLobeEnabled_0(i32(1)))
    {
        total_0 = total_0 + this_56.weights_0[i32(1)];
    }
    if(BaseLobeEnabled_0(i32(2)))
    {
        total_0 = total_0 + this_56.weights_0[i32(2)];
    }
    if(BaseLobeEnabled_0(i32(3)))
    {
        total_0 = total_0 + this_56.weights_0[i32(3)];
    }
    if(BaseLobeEnabled_0(i32(4)))
    {
        total_0 = total_0 + this_56.weights_0[i32(4)];
    }
    if(BaseLobeEnabled_0(i32(5)))
    {
        total_0 = total_0 + this_56.weights_0[i32(5)];
    }
    return total_0;
}

fn BaseLobe_EstimateContribution_0( this_57 : BaseLobe_0,  wo_22 : vec3<f32>,  throughput_5 : vec3<f32>) -> f32
{
    return BaseLobe_TotalWeight_0(this_57);
}

fn CoatLobe_ReflectionProbability_0( this_58 : CoatLobe_0,  wo_23 : vec3<f32>) -> f32
{
    return SafeDivide_0(this_58.inReflected_0, this_58.inReflected_0 + BaseLobe_EstimateContribution_0(this_58.base_2, wo_23, vec3<f32>(1.0f)) * MaxComponent_0(this_58.inBaseLayerScale_0), 0.5f);
}

fn CoatLobe_EvalPdf_0( this_59 : CoatLobe_0,  wo_24 : vec3<f32>,  wi_23 : vec3<f32>,  sampled_1 : SampledLobe_0,  f_5 : ptr<function, DiffuseSpecular_0>,  pdf_3 : ptr<function, f32>)
{
    var baseF_0 : DiffuseSpecular_0;
    var basePdf_0 : f32;
    BaseLobe_EvalPdf_0(this_59.base_2, wo_24, wi_23, sampled_1, &(baseF_0), &(basePdf_0));
    if(this_59.inside_0)
    {
        (*f_5) = x2A_0(baseF_0, CoatLobe_PassageColor_0(this_59, - dot(wi_23, this_59.normal_6)));
        (*pdf_3) = basePdf_0;
        return;
    }
    var coatSampled_0 : bool = (sampled_1.layer_0) == i32(2);
    var _S234 : DiffuseSpecular_0;
    if(coatSampled_0)
    {
        _S234 = sampled_1.f_1;
    }
    else
    {
        _S234 = CoatLobe_CoatEval_0(this_59, wo_24, wi_23);
    }
    (*f_5) = CoatLobe_Combine_0(this_59, _S234, baseF_0, wi_23);
    var _S235 : f32;
    if(CoatLobe_HasCoat_0(this_59))
    {
        var _S236 : f32 = basePdf_0;
        if(coatSampled_0)
        {
            _S235 = sampled_1.pdf_0;
        }
        else
        {
            _S235 = MicrofacetReflectionLobe_Pdf_1(this_59.reflection_0, wo_24, wi_23);
        }
        _S235 = mix(_S236, _S235, CoatLobe_ReflectionProbability_0(this_59, wo_24));
    }
    else
    {
        _S235 = basePdf_0;
    }
    (*pdf_3) = _S235;
    return;
}

fn FuzzLobe_BaseLayerScaleIncoming_0( this_60 : FuzzLobe_0) -> f32
{
    return 1.0f - this_60.viewReflected_0;
}

fn FuzzLobe_BaseLayerScaleComplete_0( this_61 : FuzzLobe_0,  wiLocal_1 : vec3<f32>) -> f32
{
    return FuzzLobe_BaseLayerScaleIncoming_0(this_61);
}

fn FuzzLobe_HasFuzz_0( this_62 : FuzzLobe_0) -> bool
{
    return ((this_62.presence_1) > 0.0f);
}

fn SheenRotate_0( v_10 : vec3<f32>,  woXY_0 : vec2<f32>) -> vec3<f32>
{
    var r2_0 : f32 = dot(woXY_0, woXY_0);
    if(r2_0 == 0.0f)
    {
        return v_10;
    }
    var invR_0 : f32 = 1.0f / sqrt(r2_0);
    var sinPhi_0 : f32 = woXY_0.y * invR_0;
    var cosPhi_0 : f32 = woXY_0.x * invR_0;
    var _S237 : f32 = v_10.x;
    var _S238 : f32 = v_10.y;
    return vec3<f32>(cosPhi_0 * _S237 + sinPhi_0 * - _S238, cosPhi_0 * _S238 + sinPhi_0 * _S237, v_10.z);
}

fn FetchLTC_0( row_1 : i32,  col_0 : i32) -> vec3<f32>
{
    return vec3<f32>(FetchTable_0(col_0, row_1, i32(69)), FetchTable_0(col_0, row_1, i32(70)), FetchTable_0(col_0, row_1, i32(71)));
}

fn SheenLTCCoefficients_0( alpha_12 : f32,  cosTheta_11 : f32) -> vec3<f32>
{
    var row_2 : f32 = max(0.0f, min(alpha_12, 0.99999994039535522f)) * 31.0f;
    var col_1 : f32 = max(0.0f, min(cosTheta_11, 0.99999994039535522f)) * 31.0f;
    var r_7 : f32 = floor(row_2);
    var c_10 : f32 = floor(col_1);
    var ri_0 : i32 = i32(r_7);
    var ci_0 : i32 = i32(c_10);
    var _S239 : i32 = ci_0 + i32(1);
    var _S240 : vec3<f32> = vec3<f32>((col_1 - c_10));
    var _S241 : i32 = ri_0 + i32(1);
    return mix(mix(FetchLTC_0(ri_0, ci_0), FetchLTC_0(ri_0, _S239), _S240), mix(FetchLTC_0(_S241, ci_0), FetchLTC_0(_S241, _S239), _S240), vec3<f32>((row_2 - r_7)));
}

fn FuzzLobe_Coefficients_0( this_63 : FuzzLobe_0,  directionLocal_0 : vec3<f32>) -> vec3<f32>
{
    return SheenLTCCoefficients_0(this_63.alpha_3, directionLocal_0.z);
}

fn SheenEvalLTC_0( wiLocal_2 : vec3<f32>,  ltc_0 : vec3<f32>) -> f32
{
    var aInv_0 : f32 = ltc_0.x;
    var _S242 : f32 = wiLocal_2.z;
    var wiOriginal_0 : vec3<f32> = vec3<f32>(aInv_0 * wiLocal_2.x + ltc_0.y * _S242, aInv_0 * wiLocal_2.y, _S242);
    var _S243 : f32 = max(0.0f, _S242);
    var lengthSquared_0 : f32 = dot(wiOriginal_0, wiOriginal_0);
    var _S244 : bool;
    if(lengthSquared_0 == 0.0f)
    {
        _S244 = true;
    }
    else
    {
        _S244 = aInv_0 == 0.0f;
    }
    if(_S244)
    {
        _S244 = true;
    }
    else
    {
        _S244 = _S243 == 0.0f;
    }
    if(_S244)
    {
        return 0.0f;
    }
    var aInvOverLengthSquared_0 : f32 = aInv_0 / lengthSquared_0;
    return 1.0f / float_getPi_0() * (_S243 * aInvOverLengthSquared_0) * aInvOverLengthSquared_0;
}

fn FuzzLobe_SheenEval_0( this_64 : FuzzLobe_0,  wiLocal_3 : vec3<f32>) -> vec3<f32>
{
    var _S245 : bool;
    if(((this_64.woLocal_0.z) <= 0.0f))
    {
        _S245 = true;
    }
    else
    {
        _S245 = ((wiLocal_3.z) <= 0.0f);
    }
    if(_S245)
    {
        _S245 = true;
    }
    else
    {
        _S245 = !FuzzLobe_HasFuzz_0(this_64);
    }
    if(_S245)
    {
        return vec3<f32>(0.0f);
    }
    var ltc_1 : vec3<f32> = FuzzLobe_Coefficients_0(this_64, this_64.woLocal_0);
    return vec3<f32>(SheenEvalLTC_0(SheenRotate_0(wiLocal_3, vec2<f32>(this_64.woLocal_0.x, - this_64.woLocal_0.y)), ltc_1)) * (vec3<f32>((this_64.presence_1 * ltc_1.z)) * this_64.tint_1);
}

fn FuzzLobe_SheenPdf_0( this_65 : FuzzLobe_0,  wiLocal_4 : vec3<f32>) -> f32
{
    var _S246 : bool;
    if(((this_65.woLocal_0.z) <= 0.0f))
    {
        _S246 = true;
    }
    else
    {
        _S246 = ((wiLocal_4.z) <= 0.0f);
    }
    if(_S246)
    {
        _S246 = true;
    }
    else
    {
        _S246 = !FuzzLobe_HasFuzz_0(this_65);
    }
    if(_S246)
    {
        return 0.0f;
    }
    return SheenEvalLTC_0(SheenRotate_0(wiLocal_4, vec2<f32>(this_65.woLocal_0.x, - this_65.woLocal_0.y)), FuzzLobe_Coefficients_0(this_65, this_65.woLocal_0));
}

fn CoatLobe_EstimateContribution_0( this_66 : CoatLobe_0,  wo_25 : vec3<f32>,  throughput_6 : vec3<f32>) -> f32
{
    var baseContribution_0 : f32 = BaseLobe_EstimateContribution_0(this_66.base_2, wo_25, throughput_6);
    if(this_66.inside_0)
    {
        return baseContribution_0;
    }
    return MaxComponent_0(throughput_6) * this_66.inReflected_0 + baseContribution_0 * MaxComponent_0(this_66.inBaseLayerScale_0);
}

fn FuzzLobe_SheenProbability_0( this_67 : FuzzLobe_0,  wo_26 : vec3<f32>) -> f32
{
    var sheenContribution_0 : f32 = this_67.viewReflected_0 * MaxComponent_0(this_67.tint_1);
    return SafeDivide_0(sheenContribution_0, sheenContribution_0 + CoatLobe_EstimateContribution_0(this_67.base_3, wo_26, vec3<f32>(1.0f)) * FuzzLobe_BaseLayerScaleIncoming_0(this_67), 0.5f);
}

fn FuzzLobe_EvalPdf_0( this_68 : FuzzLobe_0,  wo_27 : vec3<f32>,  wi_24 : vec3<f32>,  sampled_2 : SampledLobe_0,  f_6 : ptr<function, DiffuseSpecular_0>,  pdf_4 : ptr<function, f32>)
{
    var baseF_1 : DiffuseSpecular_0;
    var basePdf_1 : f32;
    CoatLobe_EvalPdf_0(this_68.base_3, wo_27, wi_24, sampled_2, &(baseF_1), &(basePdf_1));
    var wiLocal_5 : vec3<f32> = Frame_ToLocal_0(this_68.basis_0, wi_24);
    (*f_6) = x2B_0(x2A_1(baseF_1, FuzzLobe_BaseLayerScaleComplete_0(this_68, wiLocal_5)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_68, wiLocal_5)));
    var _S247 : f32;
    if(FuzzLobe_HasFuzz_0(this_68))
    {
        _S247 = mix(basePdf_1, FuzzLobe_SheenPdf_0(this_68, wiLocal_5), FuzzLobe_SheenProbability_0(this_68, wo_27));
    }
    else
    {
        _S247 = basePdf_1;
    }
    (*pdf_4) = _S247;
    return;
}

fn BSDF_EvalPdf_0( this_69 : BSDF_0,  wi_25 : vec3<f32>,  f_7 : ptr<function, DiffuseSpecular_0>,  pdf_5 : ptr<function, f32>)
{
    FuzzLobe_EvalPdf_0(this_69.lobes_0, this_69.wo_0, wi_25, SampledLobe_None_0(), &((*f_7)), &((*pdf_5)));
    return;
}

struct Ray_0
{
     origin_0 : vec3<f32>,
     tMin_0 : f32,
     direction_0 : vec3<f32>,
     tMax_0 : f32,
};

fn Ray_x24init_0( o_8 : vec3<f32>,  d_5 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S248 : Ray_0;
    _S248.origin_0 = o_8;
    _S248.direction_0 = d_5;
    _S248.tMin_0 = 0.0f;
    _S248.tMax_0 = tmax_0;
    return _S248;
}

struct HitRecord_0
{
     t_6 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_2 : u32,
     primitiveIndex_1 : u32,
};

fn rcp_0( x_25 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_25;
}

fn SafeRcp_0( d_6 : vec3<f32>) -> vec3<f32>
{
    return rcp_0(select(d_6, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_6 < vec3<f32>(0.0f))), ((abs(d_6)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn InverseTransformVector_0( _S249 : u32,  _S250 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S249].worldToObject_0[i32(0)].xyz, _S250), dot(gInstances_0[_S249].worldToObject_0[i32(1)].xyz, _S250), dot(gInstances_0[_S249].worldToObject_0[i32(2)].xyz, _S250));
}

var<private> gTraversalCost_0 : u32;

fn rcp_1( x_26 : f32) -> f32
{
    return 1.0f / x_26;
}

fn IntersectTriangle_0( o_9 : vec3<f32>,  d_7 : vec3<f32>,  v0_0 : vec3<f32>,  e1_0 : vec3<f32>,  e2_0 : vec3<f32>,  tMin_1 : f32,  tMax_1 : f32,  t_7 : ptr<function, f32>,  bary_1 : ptr<function, vec2<f32>>) -> bool
{
    (*t_7) = 0.0f;
    (*bary_1) = vec2<f32>(0.0f);
    var h_10 : vec3<f32> = cross(d_7, e2_0);
    var a_13 : f32 = dot(e1_0, h_10);
    if(a_13 == 0.0f)
    {
        return false;
    }
    var f_8 : f32 = rcp_1(a_13);
    var s_12 : vec3<f32> = o_9 - v0_0;
    var u_9 : f32 = f_8 * dot(s_12, h_10);
    var _S251 : bool;
    if((u_9 < 0.0f))
    {
        _S251 = true;
    }
    else
    {
        _S251 = (u_9 > 1.0f);
    }
    if(_S251)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_12, e1_0);
    var v_11 : f32 = f_8 * dot(d_7, q_0);
    if((v_11 < 0.0f))
    {
        _S251 = true;
    }
    else
    {
        _S251 = ((u_9 + v_11) > 1.0f);
    }
    if(_S251)
    {
        return false;
    }
    (*t_7) = f_8 * dot(e2_0, q_0);
    (*bary_1) = vec2<f32>(u_9, v_11);
    if(((*t_7) > tMin_1))
    {
        _S251 = ((*t_7) < tMax_1);
    }
    else
    {
        _S251 = false;
    }
    return _S251;
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_10 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_2 : f32,  tMax_2 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_10) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_10) * rD_0;
    var _S252 : vec3<f32> = min(t1_0, t2_0);
    var _S253 : vec3<f32> = max(t1_0, t2_0);
    var _S254 : f32 = max(max(_S252.x, _S252.y), max(_S252.z, tMin_2));
    var _S255 : f32;
    if((_S254 <= (min(min(_S253.x, _S253.y), min(_S253.z, tMax_2)))))
    {
        _S255 = _S254;
    }
    else
    {
        _S255 = 1.00000001504746622e+30f;
    }
    return _S255;
}

fn TraverseBLAS_0( _S256 : u32,  _S257 : u32,  _S258 : vec3<f32>,  _S259 : vec3<f32>,  _S260 : f32,  _S261 : bool,  _S262 : ptr<function, HitRecord_0>) -> bool
{
    var found_0 : bool;
    var _S263 : vec3<f32> = SafeRcp_0(_S259);
    var stack_1 : array<u32, i32(48)>;
    var nodeRef_0 : u32 = u32(0);
    var found_1 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var i_5 : u32;
        if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
        {
            var _S264 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
            var _S265 : u32 = (nodeRef_0 & (u32(16777215)));
            found_0 = found_1;
            i_5 = u32(0);
            loop
            {
                if((i_5 < _S264))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_4 : u32 = (gInstances_0[_S257].blasTriOffset_0 + _S265 + i_5) * u32(3);
                var v0_1 : vec4<f32> = gTris_0[base_4];
                var t_8 : f32;
                var bary_2 : vec2<f32>;
                var _S266 : bool = IntersectTriangle_0(_S258, _S259, v0_1.xyz, gTris_0[base_4 + u32(1)].xyz, gTris_0[base_4 + u32(2)].xyz, _S260, (*_S262).t_6, &(t_8), &(bary_2));
                if(!_S266)
                {
                    i_5 = i_5 + u32(1);
                    continue;
                }
                var primitiveIndex_2 : u32 = (bitcast<u32>((v0_1.w)));
                (*_S262).t_6 = t_8;
                (*_S262).barycentrics_0 = bary_2;
                (*_S262).instanceIndex_2 = _S256;
                (*_S262).primitiveIndex_1 = primitiveIndex_2;
                if(_S261)
                {
                    return true;
                }
                found_0 = true;
                i_5 = i_5 + u32(1);
            }
            if(stackPtr_0 == u32(0))
            {
                break;
            }
            var stackPtr_1 : u32 = stackPtr_0 - u32(1);
            nodeRef_0 = stack_1[stackPtr_1];
            found_1 = found_0;
            stackPtr_0 = stackPtr_1;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_0 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S257].blasNodeOffset_0 + nodeRef_0];
        var dist1_0 : f32 = IntersectBox_0(node_0.lmin_0, node_0.lmax_0, _S258, _S263, _S260, (*_S262).t_6);
        var dist2_0 : f32 = IntersectBox_0(node_0.rmin_0, node_0.rmax_0, _S258, _S263, _S260, (*_S262).t_6);
        var far_0 : u32;
        var dist1_1 : f32;
        var dist2_1 : f32;
        if((dist1_0 > dist2_0))
        {
            dist1_1 = dist2_0;
            i_5 = node_0.right_0;
            dist2_1 = dist1_0;
            far_0 = node_0.left_0;
        }
        else
        {
            dist1_1 = dist1_0;
            i_5 = node_0.left_0;
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
            nodeRef_0 = stack_1[stackPtr_2];
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
                var _S267 : u32 = stackPtr_0 + u32(1);
                stack_1[stackPtr_0] = far_0;
                stackPtr_3 = _S267;
            }
            else
            {
                stackPtr_3 = stackPtr_0;
            }
            nodeRef_0 = i_5;
            stackPtr_0 = stackPtr_3;
        }
    }
    return found_0;
}

fn TraceScene_0( ray_0 : Ray_0,  anyHit_0 : bool,  hit_0 : ptr<function, HitRecord_0>) -> bool
{
    var found_2 : bool;
    (*hit_0).t_6 = ray_0.tMax_0;
    (*hit_0).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_0).instanceIndex_2 = u32(4294967295);
    (*hit_0).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S268 : u32 = gFrame_0.counts_0.z;
    var _S269 : vec3<f32> = SafeRcp_0(ray_0.direction_0);
    var stack_2 : array<u32, i32(32)>;
    var nodeRef_1 : u32 = u32(0);
    var found_3 : bool = false;
    var stackPtr_4 : u32 = u32(0);
    loop
    {
        var i_6 : u32;
        if(((nodeRef_1 & (u32(2147483648)))) != u32(0))
        {
            var _S270 : u32 = (((nodeRef_1 >> (u32(24)))) & (u32(127)));
            var _S271 : u32 = (nodeRef_1 & (u32(16777215)));
            found_2 = found_3;
            i_6 = u32(0);
            loop
            {
                if((i_6 < _S270))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_3 : u32 = gIndices_0[_S268 + _S271 + i_6];
                var _S272 : bool = TraverseBLAS_0(instanceIndex_3, instanceIndex_3, InverseTransformPoint_0(instanceIndex_3, ray_0.origin_0), InverseTransformVector_0(instanceIndex_3, ray_0.direction_0), ray_0.tMin_0, anyHit_0, &((*hit_0)));
                if(_S272)
                {
                    if(anyHit_0)
                    {
                        return true;
                    }
                    found_2 = true;
                }
                i_6 = i_6 + u32(1);
            }
            if(stackPtr_4 == u32(0))
            {
                break;
            }
            var stackPtr_5 : u32 = stackPtr_4 - u32(1);
            nodeRef_1 = stack_2[stackPtr_5];
            found_3 = found_2;
            stackPtr_4 = stackPtr_5;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_1 : BVHNode_std430_0 = gNodes_0[nodeRef_1];
        var dist1_2 : f32 = IntersectBox_0(node_1.lmin_0, node_1.lmax_0, ray_0.origin_0, _S269, ray_0.tMin_0, (*hit_0).t_6);
        var dist2_2 : f32 = IntersectBox_0(node_1.rmin_0, node_1.rmax_0, ray_0.origin_0, _S269, ray_0.tMin_0, (*hit_0).t_6);
        var far_1 : u32;
        var dist1_3 : f32;
        var dist2_3 : f32;
        if((dist1_2 > dist2_2))
        {
            dist1_3 = dist2_2;
            i_6 = node_1.right_0;
            dist2_3 = dist1_2;
            far_1 = node_1.left_0;
        }
        else
        {
            dist1_3 = dist1_2;
            i_6 = node_1.left_0;
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
            nodeRef_1 = stack_2[stackPtr_6];
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
                var _S273 : u32 = stackPtr_4 + u32(1);
                stack_2[stackPtr_4] = far_1;
                stackPtr_7 = _S273;
            }
            else
            {
                stackPtr_7 = stackPtr_4;
            }
            nodeRef_1 = i_6;
            stackPtr_4 = stackPtr_7;
        }
    }
    return found_2;
}

fn TraceOcclusion_0( ray_1 : Ray_0) -> bool
{
    var hit_1 : HitRecord_0;
    var _S274 : bool = TraceScene_0(ray_1, true, &(hit_1));
    return _S274;
}

fn EvalMISRobust_0( pdf_6 : f32,  otherPdf_0 : f32) -> f32
{
    if(pdf_6 == otherPdf_0)
    {
        return 0.5f;
    }
    if((otherPdf_0 < pdf_6))
    {
        var x_27 : f32 = otherPdf_0 / pdf_6;
        return 1.0f / (1.0f + x_27 * x_27);
    }
    var x_28 : f32 = pdf_6 / otherPdf_0;
    return 1.0f - 1.0f / (1.0f + x_28 * x_28);
}

fn NextEventEstimation_0( si_1 : SurfaceInteraction_0,  bsdf_0 : BSDF_0,  cone_1 : vec2<f32>,  rng_4 : ptr<function, RandomSequence_0>) -> vec3<f32>
{
    var _S275 : vec3<f32> = vec3<f32>(0.0f);
    gRayCone_0 = cone_1;
    var source_0 : u32 = u32(0);
    var result_3 : vec3<f32> = _S275;
    loop
    {
        if((source_0 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var origin_1 : vec3<f32>;
        var dir_7 : vec3<f32>;
        var shadow_1 : bool;
        var mis_0 : bool;
        var maxDistance_0 : f32;
        var ls_0 : LightSample_0;
        if(source_0 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                source_0 = source_0 + u32(1);
                continue;
            }
            var ls_1 : LightSample_0 = SampleEnvironment_0(&((*rng_4)));
            if((any((((ls_1.radiance_0) > vec3<f32>(0.0f))))))
            {
                shadow_1 = ((ls_1.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                shadow_1 = false;
            }
            if(!shadow_1)
            {
                source_0 = source_0 + u32(1);
                continue;
            }
            var dir_8 : vec3<f32> = (vec3<f32>(0) - ls_1.normal_7);
            var _S276 : vec3<f32> = ShadowOrigin_0(si_1, dir_8);
            shadow_1 = true;
            origin_1 = _S276;
            maxDistance_0 = 1.00000001504746622e+30f;
            mis_0 = true;
            ls_0 = ls_1;
            dir_7 = dir_8;
        }
        else
        {
            if(source_0 == u32(1))
            {
                if((LightCount_0()) == u32(0))
                {
                    source_0 = source_0 + u32(1);
                    continue;
                }
                var ls_2 : LightSample_0 = SampleEmissive_0(si_1.position_0, cone_1, &((*rng_4)));
                if((any((((ls_2.radiance_0) > vec3<f32>(0.0f))))))
                {
                    shadow_1 = ((ls_2.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    shadow_1 = false;
                }
                if(!shadow_1)
                {
                    source_0 = source_0 + u32(1);
                    continue;
                }
                var lightPos_1 : vec3<f32> = ComputeOffsetOrigin_0(ls_2.position_1, ls_2.normal_7);
                var origin_2 : vec3<f32> = ShadowOrigin_0(si_1, lightPos_1 - si_1.position_0);
                var dir_9 : vec3<f32> = lightPos_1 - origin_2;
                var maxDistance_1 : f32 = length(dir_9);
                var dir_10 : vec3<f32> = dir_9 / vec3<f32>(maxDistance_1);
                var _S277 : bool = !ls_2.delta_0;
                shadow_1 = ls_2.shadow_0;
                origin_1 = origin_2;
                maxDistance_0 = maxDistance_1;
                mis_0 = _S277;
                ls_0 = ls_2;
                dir_7 = dir_10;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    source_0 = source_0 + u32(1);
                    continue;
                }
                var ls_3 : LightSample_0 = SampleSun_0(&((*rng_4)));
                var dir_11 : vec3<f32> = (vec3<f32>(0) - ls_3.normal_7);
                var _S278 : vec3<f32> = ShadowOrigin_0(si_1, dir_11);
                shadow_1 = true;
                origin_1 = _S278;
                maxDistance_0 = 1.00000001504746622e+30f;
                mis_0 = false;
                ls_0 = ls_3;
                dir_7 = dir_11;
            }
        }
        var eval_0 : DiffuseSpecular_0;
        var bsdfPdf_0 : f32;
        BSDF_EvalPdf_0(bsdf_0, dir_7, &(eval_0), &(bsdfPdf_0));
        var f_9 : vec3<f32> = eval_0.diffuse_1 + eval_0.specular_1;
        var _S279 : bool;
        if((any(((f_9 > vec3<f32>(0.0f))))))
        {
            if(!shadow_1)
            {
                _S279 = true;
            }
            else
            {
                var _S280 : bool = TraceOcclusion_0(Ray_x24init_0(origin_1, dir_7, maxDistance_0));
                _S279 = !_S280;
            }
        }
        else
        {
            _S279 = false;
        }
        var result_4 : vec3<f32>;
        if(_S279)
        {
            var weight_0 : f32;
            if(mis_0)
            {
                weight_0 = EvalMISRobust_0(ls_0.solidAnglePdf_0, bsdfPdf_0);
            }
            else
            {
                weight_0 = 1.0f;
            }
            result_4 = result_3 + vec3<f32>(weight_0) * ls_0.radiance_0 * f_9 / vec3<f32>(ls_0.solidAnglePdf_0);
        }
        else
        {
            result_4 = result_3;
        }
        result_3 = result_4;
        source_0 = source_0 + u32(1);
    }
    return result_3;
}

struct PathState_0
{
     radiance_1 : vec3<f32>,
     throughput_7 : vec3<f32>,
     origin_3 : vec3<f32>,
     direction_1 : vec3<f32>,
     scatterPdf_0 : f32,
     lobe_2 : u32,
     coneWidth_2 : f32,
     coneSpread_0 : f32,
     absorption_0 : vec3<f32>,
     lightsSampled_0 : bool,
};

struct WavefrontPath_0
{
     path_0 : PathState_0,
     active_0 : u32,
     randomSeed_0 : u32,
     albedo_2 : vec3<f32>,
     normal_11 : vec3<f32>,
};

fn LoadTriangleIndices_0( _S281 : u32,  _S282 : u32) -> vec3<u32>
{
    var base_5 : u32 = gInstances_0[_S281].indexOffset_0 + _S282 * u32(3);
    return vec3<u32>(gIndices_0[base_5], gIndices_0[base_5 + u32(1)], gIndices_0[base_5 + u32(2)]) + vec3<u32>(gInstances_0[_S281].vertexOffset_0);
}

fn TransformPoint_0( _S283 : u32,  _S284 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S283].objectToWorld_0[i32(0)].xyz, _S284) + gInstances_0[_S283].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S283].objectToWorld_0[i32(1)].xyz, _S284) + gInstances_0[_S283].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S283].objectToWorld_0[i32(2)].xyz, _S284) + gInstances_0[_S283].objectToWorld_0[i32(2)].w);
}

fn TransformNormal_0( _S285 : u32,  _S286 : vec3<f32>) -> vec3<f32>
{
    return gInstances_0[_S285].worldToObject_0[i32(0)].xyz * vec3<f32>(_S286.x) + gInstances_0[_S285].worldToObject_0[i32(1)].xyz * vec3<f32>(_S286.y) + gInstances_0[_S285].worldToObject_0[i32(2)].xyz * vec3<f32>(_S286.z);
}

fn VertexUV0_0( v_12 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_12).positionU_0.w, (*v_12).normalV_0.w);
}

fn TransformVector_0( _S287 : u32,  _S288 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S287].objectToWorld_0[i32(0)].xyz, _S288), dot(gInstances_0[_S287].objectToWorld_0[i32(1)].xyz, _S288), dot(gInstances_0[_S287].objectToWorld_0[i32(2)].xyz, _S288));
}

fn GetSurfaceInteraction_0( rayDirection_0 : vec3<f32>,  hit_2 : HitRecord_0,  coneWidth_3 : f32) -> SurfaceInteraction_0
{
    var _S289 : vec3<u32> = LoadTriangleIndices_0(hit_2.instanceIndex_2, hit_2.primitiveIndex_1);
    var _S290 : Vertex_std430_0 = gVertices_0[_S289.x];
    var _S291 : Vertex_std430_0 = gVertices_0[_S289.y];
    var _S292 : Vertex_std430_0 = gVertices_0[_S289.z];
    var _S293 : f32 = hit_2.barycentrics_0.x;
    var _S294 : f32 = hit_2.barycentrics_0.y;
    var _S295 : f32 = 1.0f - _S293 - _S294;
    var p0_1 : vec3<f32> = _S290.positionU_0.xyz;
    var p1_1 : vec3<f32> = _S291.positionU_0.xyz;
    var p2_1 : vec3<f32> = _S292.positionU_0.xyz;
    var si_2 : SurfaceInteraction_0;
    si_2.instanceIndex_0 = hit_2.instanceIndex_2;
    si_2.primitiveIndex_0 = hit_2.primitiveIndex_1;
    si_2.materialIndex_1 = gInstances_0[hit_2.instanceIndex_2].materialIndex_0;
    var _S296 : vec3<f32> = vec3<f32>(_S295);
    var _S297 : vec3<f32> = vec3<f32>(_S293);
    var _S298 : vec3<f32> = vec3<f32>(_S294);
    var _S299 : vec3<f32> = p0_1 * _S296 + p1_1 * _S297 + p2_1 * _S298;
    si_2.position_0 = TransformPoint_0(hit_2.instanceIndex_2, _S299);
    var _S300 : vec3<f32> = p1_1 - p0_1;
    var _S301 : vec3<f32> = p2_1 - p0_1;
    si_2.faceNormal_0 = normalize(TransformNormal_0(hit_2.instanceIndex_2, cross(normalize(_S300), normalize(_S301))));
    var n_8 : vec3<f32> = _S290.normalV_0.xyz * _S296 + _S291.normalV_0.xyz * _S297 + _S292.normalV_0.xyz * _S298;
    var t_9 : vec3<f32>;
    if(((dot(n_8, n_8)) > 0.0f))
    {
        t_9 = normalize(TransformNormal_0(hit_2.instanceIndex_2, n_8));
    }
    else
    {
        t_9 = si_2.faceNormal_0;
    }
    si_2.normal_0 = t_9;
    var _S302 : vec2<f32> = VertexUV0_0(&(_S290));
    var _S303 : vec2<f32> = VertexUV0_0(&(_S291));
    var _S304 : vec2<f32> = VertexUV0_0(&(_S292));
    var _S305 : vec2<f32> = vec2<f32>(_S295);
    var _S306 : vec2<f32> = vec2<f32>(_S293);
    var _S307 : vec2<f32> = vec2<f32>(_S294);
    var _S308 : vec2<f32> = _S290.uv1_0.xy;
    var _S309 : vec2<f32> = _S291.uv1_0.xy;
    var _S310 : vec2<f32> = _S292.uv1_0.xy;
    si_2.tex_0 = MakeTextureCoords_0(_S302 * _S305 + _S303 * _S306 + _S304 * _S307, _S308 * _S305 + _S309 * _S306 + _S310 * _S307, TransformVector_0(hit_2.instanceIndex_2, _S300), TransformVector_0(hit_2.instanceIndex_2, _S301), _S303 - _S302, _S304 - _S302, _S309 - _S308, _S310 - _S308, coneWidth_3, dot(si_2.faceNormal_0, rayDirection_0));
    si_2.tex_0.objectPosition_0 = _S299;
    si_2.frontFacing_0 = ((dot(si_2.faceNormal_0, (vec3<f32>(0) - rayDirection_0))) > 0.0f);
    var _S311 : vec4<f32> = _S290.tangent_0;
    var t_10 : vec3<f32> = _S290.tangent_0.xyz * _S296 + _S291.tangent_0.xyz * _S297 + _S292.tangent_0.xyz * _S298;
    if(((dot(t_10, t_10)) > 0.0f))
    {
        t_9 = normalize(TransformVector_0(hit_2.instanceIndex_2, t_10));
    }
    else
    {
        t_9 = vec3<f32>(0.0f);
    }
    si_2.tangent_1 = vec4<f32>(t_9, _S311.w);
    return si_2;
}

struct MaterialSample_0
{
     inputs_1 : BSDFInputs_0,
     albedo_3 : vec3<f32>,
     roughness_4 : f32,
     doubleSided_2 : bool,
     thinWalled_0 : bool,
};

fn Bitangent_0( tangent_4 : vec4<f32>,  n_9 : vec3<f32>) -> vec3<f32>
{
    var _S312 : f32 = tangent_4.w;
    var _S313 : bool;
    if(_S312 == 0.0f)
    {
        _S313 = true;
    }
    else
    {
        var _S314 : vec3<f32> = tangent_4.xyz;
        _S313 = (dot(_S314, _S314)) == 0.0f;
    }
    if(_S313)
    {
        return vec3<f32>(0.0f);
    }
    var _S315 : vec3<f32> = tangent_4.xyz;
    return cross(n_9, normalize(_S315 - n_9 * vec3<f32>(dot(_S315, n_9)))) * vec3<f32>(_S312);
}

fn ApplyNormalMap_0( tangent_5 : vec4<f32>,  n_10 : vec3<f32>,  texel_0 : vec3<f32>,  scale_4 : f32) -> vec3<f32>
{
    var _S316 : f32 = tangent_5.w;
    var _S317 : bool;
    if(_S316 == 0.0f)
    {
        _S317 = true;
    }
    else
    {
        var _S318 : vec3<f32> = tangent_5.xyz;
        _S317 = (dot(_S318, _S318)) == 0.0f;
    }
    if(_S317)
    {
        return n_10;
    }
    var _S319 : vec2<f32> = (texel_0.xy * vec2<f32>(2.0f) - vec2<f32>(1.0f)) * vec2<f32>(scale_4);
    var local_2 : vec3<f32>;
    local_2.x = _S319.x;
    local_2.y = _S319.y;
    var _S320 : f32 = texel_0.z;
    var _S321 : f32;
    if((_S320 <= 0.0f))
    {
        _S321 = sqrt(saturate(1.0f - dot(local_2.xy, local_2.xy)));
    }
    else
    {
        _S321 = abs(_S320 * 2.0f - 1.0f);
    }
    local_2[i32(2)] = _S321;
    if((dot(local_2, local_2)) == 0.0f)
    {
        return n_10;
    }
    var _S322 : vec3<f32> = normalize(local_2);
    local_2 = _S322;
    var _S323 : vec3<f32> = tangent_5.xyz;
    var t_11 : vec3<f32> = normalize(_S323 - n_10 * vec3<f32>(dot(_S323, n_10)));
    return normalize(t_11 * vec3<f32>(_S322.x) + cross(n_10, t_11) * vec3<f32>(_S316) * vec3<f32>(_S322.y) + n_10 * vec3<f32>(_S322.z));
}

fn RunMaterialProgram_1( header_5 : MaterialHeader_0,  program_2 : u32,  ctx_4 : MaterialContext_0,  outputs_1 : ptr<function, MaterialOutputs_0>)
{
    var stack_3 : array<vec4<f32>, i32(16)>;
    var n_11 : u32 = u32(0);
    var pc_2 : u32 = program_2;
    loop
    {
        if((n_11 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var ins_1 : vec4<u32> = gMaterialData_0[pc_2];
        var _S324 : u32 = ins_1.x;
        var op_1 : u32 = (_S324 & (u32(255)));
        var dst_1 : u32 = (((_S324 >> (u32(8)))) & (u32(15)));
        var imm_1 : u32 = (_S324 >> (u32(16)));
        if(op_1 == u32(0))
        {
            return;
        }
        var _S325 : vec4<f32> = vec4<f32>(0.0f);
        var _S326 : bool;
        if(((gMaterialOperandMode_0 & (u32(2)))) == u32(0))
        {
            _S326 = true;
        }
        else
        {
            _S326 = op_1 != u32(23);
        }
        var write_1 : bool;
        var a_14 : vec4<f32>;
        var b_13 : vec4<f32>;
        var c_11 : vec4<f32>;
        if(_S326)
        {
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                write_1 = true;
            }
            else
            {
                write_1 = (((ins_1.y) & (u32(2147483648)))) == u32(0);
            }
            if(write_1)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    a_14 = stack_3[((ins_1.y) & (u32(15)))];
                }
                else
                {
                    switch(((ins_1.y) & (u32(15))))
                    {
                    case u32(0):
                        {
                            a_14 = stack_3[i32(0)];
                        }
                    case u32(1):
                        {
                            a_14 = stack_3[i32(1)];
                        }
                    case u32(2):
                        {
                            a_14 = stack_3[i32(2)];
                        }
                    case u32(3):
                        {
                            a_14 = stack_3[i32(3)];
                        }
                    case u32(4):
                        {
                            a_14 = stack_3[i32(4)];
                        }
                    case u32(5):
                        {
                            a_14 = stack_3[i32(5)];
                        }
                    case u32(6):
                        {
                            a_14 = stack_3[i32(6)];
                        }
                    case u32(7):
                        {
                            a_14 = stack_3[i32(7)];
                        }
                    case u32(8):
                        {
                            a_14 = stack_3[i32(8)];
                        }
                    case u32(9):
                        {
                            a_14 = stack_3[i32(9)];
                        }
                    case u32(10):
                        {
                            a_14 = stack_3[i32(10)];
                        }
                    case u32(11):
                        {
                            a_14 = stack_3[i32(11)];
                        }
                    case u32(12):
                        {
                            a_14 = stack_3[i32(12)];
                        }
                    case u32(13):
                        {
                            a_14 = stack_3[i32(13)];
                        }
                    case u32(14):
                        {
                            a_14 = stack_3[i32(14)];
                        }
                    case u32(15):
                        {
                            a_14 = stack_3[i32(15)];
                        }
                    default :
                        {
                            a_14 = _S325;
                        }
                    }
                }
            }
            else
            {
                a_14 = _S325;
            }
            var _S327 : vec4<f32> = MaterialOperand_0(ins_1.y, a_14, header_5.constantBase_0);
            var _S328 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S328 = true;
            }
            else
            {
                _S328 = (((ins_1.z) & (u32(2147483648)))) == u32(0);
            }
            if(_S328)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    b_13 = stack_3[((ins_1.z) & (u32(15)))];
                }
                else
                {
                    switch(((ins_1.z) & (u32(15))))
                    {
                    case u32(0):
                        {
                            b_13 = stack_3[i32(0)];
                        }
                    case u32(1):
                        {
                            b_13 = stack_3[i32(1)];
                        }
                    case u32(2):
                        {
                            b_13 = stack_3[i32(2)];
                        }
                    case u32(3):
                        {
                            b_13 = stack_3[i32(3)];
                        }
                    case u32(4):
                        {
                            b_13 = stack_3[i32(4)];
                        }
                    case u32(5):
                        {
                            b_13 = stack_3[i32(5)];
                        }
                    case u32(6):
                        {
                            b_13 = stack_3[i32(6)];
                        }
                    case u32(7):
                        {
                            b_13 = stack_3[i32(7)];
                        }
                    case u32(8):
                        {
                            b_13 = stack_3[i32(8)];
                        }
                    case u32(9):
                        {
                            b_13 = stack_3[i32(9)];
                        }
                    case u32(10):
                        {
                            b_13 = stack_3[i32(10)];
                        }
                    case u32(11):
                        {
                            b_13 = stack_3[i32(11)];
                        }
                    case u32(12):
                        {
                            b_13 = stack_3[i32(12)];
                        }
                    case u32(13):
                        {
                            b_13 = stack_3[i32(13)];
                        }
                    case u32(14):
                        {
                            b_13 = stack_3[i32(14)];
                        }
                    case u32(15):
                        {
                            b_13 = stack_3[i32(15)];
                        }
                    default :
                        {
                            b_13 = _S325;
                        }
                    }
                }
            }
            else
            {
                b_13 = _S325;
            }
            var _S329 : vec4<f32> = MaterialOperand_0(ins_1.z, b_13, header_5.constantBase_0);
            var _S330 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S330 = true;
            }
            else
            {
                _S330 = (((ins_1.w) & (u32(2147483648)))) == u32(0);
            }
            if(_S330)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    c_11 = stack_3[((ins_1.w) & (u32(15)))];
                }
                else
                {
                    switch(((ins_1.w) & (u32(15))))
                    {
                    case u32(0):
                        {
                            c_11 = stack_3[i32(0)];
                        }
                    case u32(1):
                        {
                            c_11 = stack_3[i32(1)];
                        }
                    case u32(2):
                        {
                            c_11 = stack_3[i32(2)];
                        }
                    case u32(3):
                        {
                            c_11 = stack_3[i32(3)];
                        }
                    case u32(4):
                        {
                            c_11 = stack_3[i32(4)];
                        }
                    case u32(5):
                        {
                            c_11 = stack_3[i32(5)];
                        }
                    case u32(6):
                        {
                            c_11 = stack_3[i32(6)];
                        }
                    case u32(7):
                        {
                            c_11 = stack_3[i32(7)];
                        }
                    case u32(8):
                        {
                            c_11 = stack_3[i32(8)];
                        }
                    case u32(9):
                        {
                            c_11 = stack_3[i32(9)];
                        }
                    case u32(10):
                        {
                            c_11 = stack_3[i32(10)];
                        }
                    case u32(11):
                        {
                            c_11 = stack_3[i32(11)];
                        }
                    case u32(12):
                        {
                            c_11 = stack_3[i32(12)];
                        }
                    case u32(13):
                        {
                            c_11 = stack_3[i32(13)];
                        }
                    case u32(14):
                        {
                            c_11 = stack_3[i32(14)];
                        }
                    case u32(15):
                        {
                            c_11 = stack_3[i32(15)];
                        }
                    default :
                        {
                            c_11 = _S325;
                        }
                    }
                }
            }
            else
            {
                c_11 = _S325;
            }
            var _S331 : vec4<f32> = MaterialOperand_0(ins_1.w, c_11, header_5.constantBase_0);
            a_14 = _S327;
            b_13 = _S329;
            c_11 = _S331;
        }
        else
        {
            a_14 = _S325;
            b_13 = _S325;
            c_11 = _S325;
        }
        var operands_1 : u32 = pc_2 * u32(4) + u32(1);
        var _S332 : u32;
        if(op_1 == u32(23))
        {
            _S332 = (((u32(351898) >> ((u32(2) * min(imm_1, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_1 == u32(17))
            {
                _S332 = u32(1) + imm_1 / u32(4);
            }
            else
            {
                _S332 = u32(1);
            }
        }
        var pc_3 : u32 = pc_2 + _S332;
        var r_8 : vec4<f32> = _S325;
        var slot_4 : vec4<f32>;
        switch(op_1)
        {
        case u32(1):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(1)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = a_14 + b_13;
                write_1 = true;
            }
        case u32(2):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = a_14 - b_13;
                write_1 = true;
            }
        case u32(3):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(3)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = a_14 * b_13;
                write_1 = true;
            }
        case u32(4):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(4)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = a_14 / b_13;
                write_1 = true;
            }
        case u32(5):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(5)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = min(a_14, b_13);
                write_1 = true;
            }
        case u32(6):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(6)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = max(a_14, b_13);
                write_1 = true;
            }
        case u32(7):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(7)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = pow(a_14, b_13);
                write_1 = true;
            }
        case u32(8):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(8)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = atan2(a_14, b_13);
                write_1 = true;
            }
        case u32(9):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(9)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = sqrt(a_14);
                write_1 = true;
            }
        case u32(10):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(10)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = sin(a_14);
                write_1 = true;
            }
        case u32(11):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(11)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = cos(a_14);
                write_1 = true;
            }
        case u32(12):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(12)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = abs(a_14);
                write_1 = true;
            }
        case u32(13):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(13)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = min(max(a_14, b_13), c_11);
                write_1 = true;
            }
        case u32(14):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(14)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = mix(a_14, b_13, c_11);
                write_1 = true;
            }
        case u32(15):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(15)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>(a_14[min(imm_1, u32(3))]);
                write_1 = true;
            }
        case u32(16):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(16)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = select(vec4<f32>(f32((imm_1 >> (u32(8))))), a_14, LanesBelow_0((imm_1 & (u32(255)))));
                write_1 = true;
            }
        case u32(17):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(17)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>(a_14.x, b_13.x, c_11.x, 0.0f);
                if((imm_1 > u32(3)))
                {
                    var o_11 : u32 = MaterialWord_0(operands_1 + u32(3));
                    if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                    {
                        write_1 = true;
                    }
                    else
                    {
                        write_1 = ((o_11 & (u32(2147483648)))) == u32(0);
                    }
                    if(write_1)
                    {
                        if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                        {
                            slot_4 = stack_3[(o_11 & (u32(15)))];
                        }
                        else
                        {
                            switch((o_11 & (u32(15))))
                            {
                            case u32(0):
                                {
                                    slot_4 = stack_3[i32(0)];
                                }
                            case u32(1):
                                {
                                    slot_4 = stack_3[i32(1)];
                                }
                            case u32(2):
                                {
                                    slot_4 = stack_3[i32(2)];
                                }
                            case u32(3):
                                {
                                    slot_4 = stack_3[i32(3)];
                                }
                            case u32(4):
                                {
                                    slot_4 = stack_3[i32(4)];
                                }
                            case u32(5):
                                {
                                    slot_4 = stack_3[i32(5)];
                                }
                            case u32(6):
                                {
                                    slot_4 = stack_3[i32(6)];
                                }
                            case u32(7):
                                {
                                    slot_4 = stack_3[i32(7)];
                                }
                            case u32(8):
                                {
                                    slot_4 = stack_3[i32(8)];
                                }
                            case u32(9):
                                {
                                    slot_4 = stack_3[i32(9)];
                                }
                            case u32(10):
                                {
                                    slot_4 = stack_3[i32(10)];
                                }
                            case u32(11):
                                {
                                    slot_4 = stack_3[i32(11)];
                                }
                            case u32(12):
                                {
                                    slot_4 = stack_3[i32(12)];
                                }
                            case u32(13):
                                {
                                    slot_4 = stack_3[i32(13)];
                                }
                            case u32(14):
                                {
                                    slot_4 = stack_3[i32(14)];
                                }
                            case u32(15):
                                {
                                    slot_4 = stack_3[i32(15)];
                                }
                            default :
                                {
                                    slot_4 = _S325;
                                }
                            }
                        }
                    }
                    else
                    {
                        slot_4 = _S325;
                    }
                    r_8[i32(3)] = MaterialOperand_0(o_11, slot_4, header_5.constantBase_0).x;
                }
                write_1 = true;
            }
        case u32(18):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(18)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var lanes_1 : vec4<bool> = LanesBelow_0(imm_1);
                r_8 = vec4<f32>(dot(select(_S325, a_14, lanes_1), select(_S325, b_13, lanes_1)));
                write_1 = true;
            }
        case u32(19):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(19)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var len_1 : f32 = length(select(_S325, a_14, LanesBelow_0(imm_1)));
                if((len_1 > 0.0f))
                {
                    slot_4 = a_14 / vec4<f32>(len_1);
                }
                else
                {
                    slot_4 = _S325;
                }
                r_8 = slot_4;
                write_1 = true;
            }
        case u32(20):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(20)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                if(imm_1 == u32(0))
                {
                    r_8 = vec4<f32>(ctx_4.tex_1.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_1 == u32(1))
                    {
                        r_8 = vec4<f32>(ctx_4.tex_1.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_1 == u32(6))
                        {
                            r_8 = vec4<f32>(ctx_4.tex_1.objectPosition_0, 0.0f);
                        }
                        else
                        {
                            if(imm_1 == u32(2))
                            {
                                r_8 = vec4<f32>(ctx_4.position_2, 0.0f);
                            }
                            else
                            {
                                if(imm_1 == u32(3))
                                {
                                    r_8 = vec4<f32>(ctx_4.normal_10, 0.0f);
                                }
                                else
                                {
                                    if(imm_1 == u32(4))
                                    {
                                        r_8 = ctx_4.tangent_3;
                                    }
                                    else
                                    {
                                        r_8 = vec4<f32>(Bitangent_0(ctx_4.tangent_3, ctx_4.normal_10), 0.0f);
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
                if(((((gMaterialOpcodesLow_0 >> (u32(21)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var ref_9 : TextureRef_0 = LoadTextureRef_0(header_5, imm_1);
                if(HasTexture_0(ref_9))
                {
                    var _S333 : vec4<f32> = SampleTexture_0(ref_9, ctx_4.tex_1);
                    slot_4 = _S333;
                }
                else
                {
                    slot_4 = vec4<f32>(1.0f);
                }
                r_8 = slot_4;
                write_1 = true;
            }
        case u32(22):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(22)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>(ApplyNormalMap_0(ctx_4.tangent_3, ctx_4.normal_10, a_14.xyz, b_13.x), 0.0f);
                write_1 = true;
            }
        case u32(24):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(24)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = floor(a_14);
                write_1 = true;
            }
        case u32(25):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(25)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>((vec4<i32>(sign((a_14)))));
                write_1 = true;
            }
        case u32(26):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(26)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = exp(a_14);
                write_1 = true;
            }
        case u32(27):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(27)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = log(a_14);
                write_1 = true;
            }
        case u32(28):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(28)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = a_14 - b_13 * floor(a_14 / b_13);
                write_1 = true;
            }
        case u32(29):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(29)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = select(_S325, vec4<f32>(1.0f), (a_14 > b_13));
                write_1 = true;
            }
        case u32(30):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(30)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>(cross(a_14.xyz, b_13.xyz), 0.0f);
                write_1 = true;
            }
        case u32(31):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(31)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var _S334 : vec3<f32>;
                if(imm_1 == u32(1))
                {
                    _S334 = TransformVector_0(ctx_4.instanceIndex_1, a_14.xyz);
                }
                else
                {
                    _S334 = InverseTransformVector_0(ctx_4.instanceIndex_1, a_14.xyz);
                }
                r_8 = vec4<f32>(_S334, 0.0f);
                write_1 = true;
            }
        case u32(32):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(0)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var _S335 : bool = ((imm_1 & (u32(2)))) != u32(0);
                var v_13 : vec3<f32> = BlenderNoise_0(a_14.xyz, b_13, ((imm_1 & (u32(1)))) != u32(0), _S335);
                if(_S335)
                {
                    slot_4 = vec4<f32>(v_13, 0.0f);
                }
                else
                {
                    slot_4 = vec4<f32>(v_13.x);
                }
                r_8 = slot_4;
                write_1 = true;
            }
        case u32(33):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(1)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var c_12 : vec3<f32> = BlenderMagic_0(a_14.xyz, imm_1, b_13.x);
                r_8 = vec4<f32>(c_12, (c_12.x + c_12.y + c_12.z) / 3.0f);
                write_1 = true;
            }
        case u32(34):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                r_8 = vec4<f32>(BlenderChecker_0(a_14.xyz));
                write_1 = true;
            }
        case u32(23):
            {
                switch(imm_1)
                {
                case u32(0):
                    {
                        var o_12 : u32 = MaterialWord_0(operands_1);
                        if(o_12 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_12 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_12 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_12 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.baseWeight_0 = MaterialOperand_0(o_12, slot_4, header_5.constantBase_0).x;
                        }
                        var o_13 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_13 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_13 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_13 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_13 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.baseColor_0 = MaterialOperand_0(o_13, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_14 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_14 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_14 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_14 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_14 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.baseDiffuseRoughness_0 = MaterialOperand_0(o_14, slot_4, header_5.constantBase_0).x;
                        }
                        var o_15 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_15 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_15 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_15 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_15 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.baseMetalness_0 = MaterialOperand_0(o_15, slot_4, header_5.constantBase_0).x;
                        }
                    }
                case u32(1):
                    {
                        var o_16 : u32 = MaterialWord_0(operands_1);
                        if(o_16 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_16 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_16 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_16 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularWeight_0 = MaterialOperand_0(o_16, slot_4, header_5.constantBase_0).x;
                        }
                        var o_17 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_17 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_17 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_17 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_17 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularColor_0 = MaterialOperand_0(o_17, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_18 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_18 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_18 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_18 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_18 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularRoughness_0 = MaterialOperand_0(o_18, slot_4, header_5.constantBase_0).x;
                        }
                        var o_19 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_19 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_19 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_19 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_19 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularIor_0 = MaterialOperand_0(o_19, slot_4, header_5.constantBase_0).x;
                        }
                        var o_20 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_20 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_20 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_20 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_20 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularDielectricOnly_0 = (MaterialOperand_0(o_20, slot_4, header_5.constantBase_0).x) != 0.0f;
                        }
                    }
                case u32(2):
                    {
                        var o_21 : u32 = MaterialWord_0(operands_1);
                        if(o_21 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_21 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_21 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_21 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.specularRoughnessAnisotropy_0 = MaterialOperand_0(o_21, slot_4, header_5.constantBase_0).x;
                        }
                        var o_22 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_22 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_22 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_22 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_22 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).tangent_2 = MaterialOperand_0(o_22, slot_4, header_5.constantBase_0).xyz;
                        }
                    }
                case u32(3):
                    {
                        var o_23 : u32 = MaterialWord_0(operands_1);
                        if(o_23 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_23 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_23 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_23 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionWeight_0 = MaterialOperand_0(o_23, slot_4, header_5.constantBase_0).x;
                        }
                        var o_24 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_24 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_24 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_24 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_24 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionColor_0 = MaterialOperand_0(o_24, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_25 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_25 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_25 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_25 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_25 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionDepth_0 = MaterialOperand_0(o_25, slot_4, header_5.constantBase_0).x;
                        }
                        var o_26 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_26 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_26 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_26 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_26 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionScatter_0 = MaterialOperand_0(o_26, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_27 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_27 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_27 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_27 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_27 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionScatterAnisotropy_0 = MaterialOperand_0(o_27, slot_4, header_5.constantBase_0).x;
                        }
                        var o_28 : u32 = MaterialWord_0(operands_1 + u32(5));
                        if(o_28 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_28 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_28 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_28 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionDispersionScale_0 = MaterialOperand_0(o_28, slot_4, header_5.constantBase_0).x;
                        }
                        var o_29 : u32 = MaterialWord_0(operands_1 + u32(6));
                        if(o_29 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_29 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_29 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_29 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.transmissionDispersionAbbeNumber_0 = MaterialOperand_0(o_29, slot_4, header_5.constantBase_0).x;
                        }
                    }
                case u32(4):
                    {
                        var o_30 : u32 = MaterialWord_0(operands_1);
                        if(o_30 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_30 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_30 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_30 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.subsurfaceWeight_0 = MaterialOperand_0(o_30, slot_4, header_5.constantBase_0).x;
                        }
                        var o_31 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_31 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_31 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_31 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_31 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.subsurfaceColor_0 = MaterialOperand_0(o_31, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_32 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_32 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_32 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_32 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_32 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.subsurfaceRadius_0 = MaterialOperand_0(o_32, slot_4, header_5.constantBase_0).x;
                        }
                        var o_33 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_33 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_33 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_33 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_33 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.subsurfaceRadiusScale_0 = MaterialOperand_0(o_33, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_34 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_34 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_34 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_34 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_34 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.subsurfaceScatterAnisotropy_0 = MaterialOperand_0(o_34, slot_4, header_5.constantBase_0).x;
                        }
                    }
                case u32(5):
                    {
                        var o_35 : u32 = MaterialWord_0(operands_1);
                        if(o_35 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_35 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_35 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_35 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatWeight_0 = MaterialOperand_0(o_35, slot_4, header_5.constantBase_0).x;
                        }
                        var o_36 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_36 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_36 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_36 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_36 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatColor_0 = MaterialOperand_0(o_36, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_37 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_37 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_37 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_37 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_37 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatRoughness_0 = MaterialOperand_0(o_37, slot_4, header_5.constantBase_0).x;
                        }
                        var o_38 : u32 = MaterialWord_0(operands_1 + u32(3));
                        if(o_38 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_38 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_38 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_38 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatRoughnessAnisotropy_0 = MaterialOperand_0(o_38, slot_4, header_5.constantBase_0).x;
                        }
                        var o_39 : u32 = MaterialWord_0(operands_1 + u32(4));
                        if(o_39 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_39 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_39 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_39 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatIor_0 = MaterialOperand_0(o_39, slot_4, header_5.constantBase_0).x;
                        }
                        var o_40 : u32 = MaterialWord_0(operands_1 + u32(5));
                        if(o_40 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_40 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_40 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_40 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.coatDarkening_0 = MaterialOperand_0(o_40, slot_4, header_5.constantBase_0).x;
                        }
                        var o_41 : u32 = MaterialWord_0(operands_1 + u32(6));
                        if(o_41 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_41 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_41 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_41 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).coatNormal_0 = MaterialOperand_0(o_41, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_42 : u32 = MaterialWord_0(operands_1 + u32(7));
                        if(o_42 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_42 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_42 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_42 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).coatTangent_0 = MaterialOperand_0(o_42, slot_4, header_5.constantBase_0).xyz;
                        }
                    }
                case u32(6):
                    {
                        var o_43 : u32 = MaterialWord_0(operands_1);
                        if(o_43 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_43 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_43 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_43 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.fuzzWeight_0 = MaterialOperand_0(o_43, slot_4, header_5.constantBase_0).x;
                        }
                        var o_44 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_44 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_44 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_44 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_44 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.fuzzColor_0 = MaterialOperand_0(o_44, slot_4, header_5.constantBase_0).xyz;
                        }
                        var o_45 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_45 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_45 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_45 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_45 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.fuzzRoughness_0 = MaterialOperand_0(o_45, slot_4, header_5.constantBase_0).x;
                        }
                    }
                case u32(7):
                    {
                        var o_46 : u32 = MaterialWord_0(operands_1);
                        if(o_46 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_46 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_46 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_46 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.thinFilmWeight_1 = MaterialOperand_0(o_46, slot_4, header_5.constantBase_0).x;
                        }
                        var o_47 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_47 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_47 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_47 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_47 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.thinFilmThickness_1 = MaterialOperand_0(o_47, slot_4, header_5.constantBase_0).x;
                        }
                        var o_48 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_48 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_48 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_48 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_48 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.thinFilmIor_1 = MaterialOperand_0(o_48, slot_4, header_5.constantBase_0).x;
                        }
                    }
                case u32(8):
                    {
                        var o_49 : u32 = MaterialWord_0(operands_1);
                        if(o_49 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_49 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_49 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_49 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_49, slot_4, header_5.constantBase_0).x;
                        }
                        var o_50 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_50 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_50 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_50 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_50 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.emissionColor_0 = MaterialOperand_0(o_50, slot_4, header_5.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_51 : u32 = MaterialWord_0(operands_1);
                        if(o_51 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_51 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_51 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_51 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_51, slot_4, header_5.constantBase_0).x;
                        }
                        var o_52 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_52 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_52 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_52 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_52 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_52, slot_4, header_5.constantBase_0).x) != 0.0f;
                        }
                        var o_53 : u32 = MaterialWord_0(operands_1 + u32(2));
                        if(o_53 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_1 = true;
                            }
                            else
                            {
                                write_1 = ((o_53 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_1)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_4 = stack_3[(o_53 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_53 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_4 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_4 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_4 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_4 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_4 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_4 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_4 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_4 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_4 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_4 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_4 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_4 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_4 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_4 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_4 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_4 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_4 = _S325;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_4 = _S325;
                            }
                            (*outputs_1).normal_9 = MaterialOperand_0(o_53, slot_4, header_5.constantBase_0).xyz;
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
            if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
            {
                stack_3[dst_1] = r_8;
            }
            else
            {
                switch(dst_1)
                {
                case u32(0):
                    {
                        stack_3[i32(0)] = r_8;
                    }
                case u32(1):
                    {
                        stack_3[i32(1)] = r_8;
                    }
                case u32(2):
                    {
                        stack_3[i32(2)] = r_8;
                    }
                case u32(3):
                    {
                        stack_3[i32(3)] = r_8;
                    }
                case u32(4):
                    {
                        stack_3[i32(4)] = r_8;
                    }
                case u32(5):
                    {
                        stack_3[i32(5)] = r_8;
                    }
                case u32(6):
                    {
                        stack_3[i32(6)] = r_8;
                    }
                case u32(7):
                    {
                        stack_3[i32(7)] = r_8;
                    }
                case u32(8):
                    {
                        stack_3[i32(8)] = r_8;
                    }
                case u32(9):
                    {
                        stack_3[i32(9)] = r_8;
                    }
                case u32(10):
                    {
                        stack_3[i32(10)] = r_8;
                    }
                case u32(11):
                    {
                        stack_3[i32(11)] = r_8;
                    }
                case u32(12):
                    {
                        stack_3[i32(12)] = r_8;
                    }
                case u32(13):
                    {
                        stack_3[i32(13)] = r_8;
                    }
                case u32(14):
                    {
                        stack_3[i32(14)] = r_8;
                    }
                case u32(15):
                    {
                        stack_3[i32(15)] = r_8;
                    }
                default :
                    {
                    }
                }
            }
        }
        n_11 = n_11 + u32(1);
        pc_2 = pc_3;
    }
    return;
}

fn AlignWithFace_0( n_12 : vec3<f32>,  V_0 : vec3<f32>,  frontFacing_1 : bool) -> vec3<f32>
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
    var cosV_0 : f32 = dot(V_0, n_12) * side_0;
    if((cosV_0 >= 9.9999997473787516e-05f))
    {
        return n_12;
    }
    return normalize(n_12 + V_0 * vec3<f32>((side_0 * (9.9999997473787516e-05f - cosV_0))));
}

fn BranchlessONB_1( n_13 : vec3<f32>,  b1_1 : ptr<function, vec3<f32>>,  b2_1 : ptr<function, vec3<f32>>)
{
    var _S336 : f32 = n_13.z;
    var s_13 : f32;
    if((_S336 >= 0.0f))
    {
        s_13 = 1.0f;
    }
    else
    {
        s_13 = -1.0f;
    }
    var a_15 : f32 = -1.0f / (s_13 + _S336);
    var _S337 : f32 = n_13.x;
    var _S338 : f32 = n_13.y;
    var b_14 : f32 = _S337 * _S338 * a_15;
    (*b1_1) = vec3<f32>(1.0f + s_13 * _S337 * _S337 * a_15, s_13 * b_14, - s_13 * _S337);
    (*b2_1) = vec3<f32>(b_14, s_13 + _S338 * _S338 * a_15, - _S338);
    return;
}

fn Frame_FromNormal_0( n_14 : vec3<f32>) -> Frame_0
{
    var f_10 : Frame_0;
    f_10.n_1 = n_14;
    var _S339 : vec3<f32> = f_10.t_0;
    var _S340 : vec3<f32> = f_10.b_0;
    BranchlessONB_1(n_14, &(_S339), &(_S340));
    f_10.t_0 = _S339;
    f_10.b_0 = _S340;
    return f_10;
}

fn Frame_FromTangent_0( tangent_6 : vec4<f32>,  n_15 : vec3<f32>) -> Frame_0
{
    var _S341 : vec3<f32> = tangent_6.xyz;
    var NdotT_0 : f32 = dot(_S341, n_15);
    var _S342 : f32 = tangent_6.w;
    var valid_0 : bool;
    if(_S342 != 0.0f)
    {
        valid_0 = ((dot(_S341, _S341)) > 0.0f);
    }
    else
    {
        valid_0 = false;
    }
    if(valid_0)
    {
        valid_0 = ((abs(NdotT_0)) < 0.99989998340606689f);
    }
    else
    {
        valid_0 = false;
    }
    if(!valid_0)
    {
        return Frame_FromNormal_0(n_15);
    }
    var f_11 : Frame_0;
    f_11.n_1 = n_15;
    var _S343 : vec3<f32> = normalize(_S341 - n_15 * vec3<f32>(NdotT_0));
    f_11.t_0 = _S343;
    f_11.b_0 = cross(n_15, _S343) * vec3<f32>(_S342);
    return f_11;
}

fn EvalMaterial_0( si_3 : SurfaceInteraction_0,  V_1 : vec3<f32>) -> MaterialSample_0
{
    var header_6 : MaterialHeader_0 = LoadMaterialHeader_0(si_3.materialIndex_1);
    var ctx_5 : MaterialContext_0;
    ctx_5.tex_1 = si_3.tex_0;
    ctx_5.position_2 = si_3.position_0;
    ctx_5.normal_10 = si_3.normal_0;
    ctx_5.tangent_3 = si_3.tangent_1;
    ctx_5.instanceIndex_1 = si_3.instanceIndex_0;
    var o_54 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_5);
    if((header_6.surface_0) != u32(4294967295))
    {
        RunMaterialProgram_1(header_6, header_6.surface_0, ctx_5, &(o_54));
    }
    var ms_0 : MaterialSample_0;
    ms_0.inputs_1 = o_54.inputs_0;
    ms_0.albedo_3 = o_54.inputs_0.baseColor_0;
    ms_0.roughness_4 = o_54.inputs_0.specularRoughness_0;
    ms_0.doubleSided_2 = MaterialHeader_DoubleSided_0(header_6);
    ms_0.thinWalled_0 = o_54.inputs_0.geometryThinWalled_0;
    var _S344 : f32 = si_3.tangent_1.w;
    var handedness_0 : f32;
    if(_S344 != 0.0f)
    {
        handedness_0 = _S344;
    }
    else
    {
        handedness_0 = 1.0f;
    }
    ms_0.inputs_1.basis_1 = Frame_FromTangent_0(vec4<f32>(o_54.tangent_2, handedness_0), AlignWithFace_0(o_54.normal_9, V_1, si_3.frontFacing_0));
    var _S345 : bool;
    if((all(((o_54.coatNormal_0) == (o_54.normal_9)))))
    {
        _S345 = (all(((o_54.coatTangent_0) == (o_54.tangent_2))));
    }
    else
    {
        _S345 = false;
    }
    if(_S345)
    {
        ms_0.inputs_1.coatBasis_0 = ms_0.inputs_1.basis_1;
    }
    else
    {
        ms_0.inputs_1.coatBasis_0 = Frame_FromTangent_0(vec4<f32>(o_54.coatTangent_0, handedness_0), AlignWithFace_0(o_54.coatNormal_0, V_1, si_3.frontFacing_0));
    }
    return ms_0;
}

struct VolumeDerived_0
{
     thinWallSubsurfaceColor_0 : vec3<f32>,
     thinWallSubsurfaceAnisotropy_0 : f32,
     transmissionTint_0 : vec3<f32>,
};

fn HomogeneousVolume_x24init_0( extinction_1 : vec3<f32>,  albedo_4 : vec3<f32>,  anisotropy_1 : f32) -> HomogeneousVolume_0
{
    var _S346 : HomogeneousVolume_0;
    _S346.extinction_0 = extinction_1;
    _S346.albedo_0 = albedo_4;
    _S346.anisotropy_0 = anisotropy_1;
    return _S346;
}

fn HomogeneousVolume_Empty_0() -> HomogeneousVolume_0
{
    var _S347 : vec3<f32> = vec3<f32>(0.0f);
    return HomogeneousVolume_x24init_0(_S347, _S347, 0.0f);
}

fn Square_1( v_14 : vec3<f32>) -> vec3<f32>
{
    return v_14 * v_14;
}

fn CreateSubsurfaceVolume_0( radius_2 : f32,  radiusScale_0 : vec3<f32>,  color_4 : vec3<f32>,  anisotropy_2 : f32) -> HomogeneousVolume_0
{
    var _S348 : vec3<f32> = vec3<f32>(1.0f);
    var g_2 : f32 = clamp(anisotropy_2, -0.99900001287460327f, 0.99900001287460327f);
    var _S349 : vec3<f32> = Square_1(vec3<f32>(4.0971198081970215f) + vec3<f32>(4.2086300849914551f) * color_4 - sqrt(vec3<f32>(9.5921697616577148f) + vec3<f32>(41.680801391601562f) * color_4 + vec3<f32>(17.712600708007812f) * Square_1(color_4)));
    return HomogeneousVolume_x24init_0(_S348 / max(vec3<f32>(radius_2) * radiusScale_0, vec3<f32>(0.0010000000474974513f)), saturate((_S348 - _S349) / (_S348 - vec3<f32>(g_2) * _S349)), g_2);
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
        var _S350 : f32;
        if(((extinction_2[i32(0)]) > 0.0f))
        {
            _S350 = scattering_0[i32(0)] / extinction_2[i32(0)];
        }
        else
        {
            _S350 = 0.0f;
        }
        albedo_5[i32(0)] = _S350;
        if(((extinction_2[i32(1)]) > 0.0f))
        {
            _S350 = scattering_0[i32(1)] / extinction_2[i32(1)];
        }
        else
        {
            _S350 = 0.0f;
        }
        albedo_5[i32(1)] = _S350;
        if(((extinction_2[i32(2)]) > 0.0f))
        {
            _S350 = scattering_0[i32(2)] / extinction_2[i32(2)];
        }
        else
        {
            _S350 = 0.0f;
        }
        albedo_5[i32(2)] = _S350;
    }
    return HomogeneousVolume_x24init_0(extinction_2, albedo_5, anisotropy_3);
}

fn CreateTransmissionVolume_0( color_5 : vec3<f32>,  depth_1 : f32,  scatter_0 : vec3<f32>,  anisotropy_4 : f32) -> HomogeneousVolume_0
{
    var _S351 : bool;
    if(((MinComponent_0(color_5)) >= 1.0f))
    {
        _S351 = ((MaxComponent_0(scatter_0)) <= 0.0f);
    }
    else
    {
        _S351 = false;
    }
    if(_S351)
    {
        return HomogeneousVolume_Empty_0();
    }
    var _S352 : vec3<f32> = vec3<f32>((1.0f / max(depth_1, 0.0010000000474974513f)));
    var scattering_1 : vec3<f32> = scatter_0 * _S352;
    var absorption_2 : vec3<f32> = (vec3<f32>(0) - log(max(color_5, vec3<f32>(0.0010000000474974513f)))) * _S352 - scattering_1;
    var _S353 : f32 = MinComponent_0(absorption_2);
    var absorption_3 : vec3<f32>;
    if((_S353 < 0.0f))
    {
        absorption_3 = absorption_2 - vec3<f32>(_S353);
    }
    else
    {
        absorption_3 = absorption_2;
    }
    return HomogeneousVolume_FromAbsorptionAndScattering_0(absorption_3, scattering_1, clamp(anisotropy_4, -0.99900001287460327f, 0.99900001287460327f));
}

fn HomogeneousVolume_Absorption_0( this_70 : HomogeneousVolume_0) -> vec3<f32>
{
    return this_70.extinction_0 * (vec3<f32>(1.0f) - this_70.albedo_0);
}

fn HomogeneousVolume_Scattering_0( this_71 : HomogeneousVolume_0) -> vec3<f32>
{
    return this_71.extinction_0 * this_71.albedo_0;
}

fn AddVolumes_0( a_16 : HomogeneousVolume_0,  b_15 : HomogeneousVolume_0,  weightA_0 : f32,  weightB_0 : f32) -> HomogeneousVolume_0
{
    var _S354 : vec3<f32> = vec3<f32>(weightA_0);
    var _S355 : vec3<f32> = vec3<f32>(weightB_0);
    return HomogeneousVolume_FromAbsorptionAndScattering_0(HomogeneousVolume_Absorption_0(a_16) * _S354 + HomogeneousVolume_Absorption_0(b_15) * _S355, HomogeneousVolume_Scattering_0(a_16) * _S354 + HomogeneousVolume_Scattering_0(b_15) * _S355, SafeDivide_0(a_16.anisotropy_0 * weightA_0 + b_15.anisotropy_0 * weightB_0, weightA_0 + weightB_0, 0.0f));
}

fn PrepareVolume_0( inputs_2 : BSDFInputs_0,  derived_0 : ptr<function, VolumeDerived_0>) -> HomogeneousVolume_0
{
    var _S356 : HomogeneousVolume_0 = HomogeneousVolume_Empty_0();
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
            subsurfaceVolume_0 = _S356;
        }
    }
    else
    {
        subsurfaceVolume_0 = _S356;
    }
    (*derived_0).transmissionTint_0 = vec3<f32>(1.0f);
    var transmissionVolume_0 : HomogeneousVolume_0;
    if(((inputs_2.transmissionWeight_0) > 0.0f))
    {
        var _S357 : bool;
        if((inputs_2.transmissionDepth_0) == 0.0f)
        {
            _S357 = true;
        }
        else
        {
            _S357 = inputs_2.geometryThinWalled_0;
        }
        if(_S357)
        {
            (*derived_0).transmissionTint_0 = inputs_2.transmissionColor_0;
            transmissionVolume_0 = _S356;
        }
        else
        {
            transmissionVolume_0 = CreateTransmissionVolume_0(inputs_2.transmissionColor_0, inputs_2.transmissionDepth_0, inputs_2.transmissionScatter_0, inputs_2.transmissionScatterAnisotropy_0);
        }
    }
    else
    {
        transmissionVolume_0 = _S356;
    }
    var subsurfaceFraction_0 : f32 = (1.0f - inputs_2.transmissionWeight_0) * inputs_2.subsurfaceWeight_0;
    var invTotal_0 : f32 = SafeDivide_0(1.0f, subsurfaceFraction_0 + inputs_2.transmissionWeight_0, 0.0f);
    return AddVolumes_0(subsurfaceVolume_0, transmissionVolume_0, subsurfaceFraction_0 * invTotal_0, inputs_2.transmissionWeight_0 * invTotal_0);
}

fn Frame_Handedness_0( this_72 : Frame_0) -> f32
{
    var _S358 : f32;
    if(((dot(cross(this_72.t_0, this_72.b_0), this_72.n_1)) >= 0.0f))
    {
        _S358 = 1.0f;
    }
    else
    {
        _S358 = -1.0f;
    }
    return _S358;
}

fn Frame_RotatedAroundNormal_0( this_73 : Frame_0,  cosSin_0 : vec2<f32>) -> Frame_0
{
    if((all((cosSin_0 == vec2<f32>(0.0f)))))
    {
        return this_73;
    }
    var cs_0 : vec2<f32> = normalize(cosSin_0);
    var h_11 : f32 = Frame_Handedness_0(this_73);
    var f_12 : Frame_0;
    f_12.n_1 = this_73.n_1;
    var _S359 : vec3<f32> = vec3<f32>(cs_0.x);
    var _S360 : vec3<f32> = vec3<f32>(h_11);
    var _S361 : vec3<f32> = vec3<f32>(cs_0.y);
    f_12.t_0 = this_73.t_0 * _S359 + _S360 * this_73.b_0 * _S361;
    f_12.b_0 = this_73.b_0 * _S359 - _S360 * this_73.t_0 * _S361;
    return f_12;
}

fn Frame_Inverted_0( this_74 : Frame_0) -> Frame_0
{
    var f_13 : Frame_0;
    f_13.t_0 = (vec3<f32>(0) - this_74.t_0);
    f_13.b_0 = (vec3<f32>(0) - this_74.b_0);
    f_13.n_1 = (vec3<f32>(0) - this_74.n_1);
    return f_13;
}

fn IorFromF0_0( f0_2 : f32) -> f32
{
    var sqrtF0_0 : f32 = sqrt(f0_2);
    return (1.0f + sqrtF0_0) / (1.0f - sqrtF0_0);
}

fn ApplySpecularWeightToIor_0( eta_6 : f32,  specularWeight_1 : f32) -> f32
{
    var externalIor_0 : f32 = IorFromF0_0(min(F0FromIor_0(eta_6) * specularWeight_1, 0.99989998340606689f));
    var _S362 : f32;
    if((eta_6 < 1.0f))
    {
        _S362 = 1.0f / externalIor_0;
    }
    else
    {
        _S362 = externalIor_0;
    }
    return _S362;
}

fn Average_0( v_15 : vec3<f32>) -> f32
{
    return Sum_0(v_15) * 0.3333333432674408f;
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

fn AnisotropicAlpha_0( isotropicAlpha_1 : f32,  anisotropy_5 : f32) -> vec2<f32>
{
    var alpha_13 : vec2<f32>;
    if((anisotropy_5 > 0.0f))
    {
        var _S363 : f32 = 1.0f - anisotropy_5;
        alpha_13[i32(0)] = isotropicAlpha_1 * sqrt(2.0f / (1.0f + Square_0(_S363)));
        alpha_13[i32(1)] = _S363 * alpha_13.x;
    }
    else
    {
        alpha_13 = vec2<f32>(isotropicAlpha_1);
    }
    return max(alpha_13, vec2<f32>(1.00000011116208043e-06f));
}

fn AverageFresnelMetalF82_0( f0_3 : vec3<f32>,  f82Tint_2 : vec3<f32>) -> vec3<f32>
{
    return saturate(f0_3 + (vec3<f32>(1.0f) - f0_3) * vec3<f32>(0.0476190485060215f) - MetalSchlickBFactor_0(f0_3, f82Tint_2) * vec3<f32>(0.0079365083947777748f));
}

fn AverageFresnel_0( eta_7 : f32) -> f32
{
    if((eta_7 > 1.0f))
    {
        return (eta_7 - 1.0f) / (4.085669994354248f + 1.0007100105285645f * eta_7);
    }
    var _S364 : f32 = eta_7 * eta_7;
    return 0.99711799621582031f + 0.10140000283718109f * eta_7 - 0.96524101495742798f * _S364 - 0.1306069940328598f * _S364 * eta_7;
}

fn GGXDistribution_x24init_0( alpha_14 : vec2<f32>,  frame_2 : Frame_0,  isotropicAlpha_2 : f32) -> GGXDistribution_0
{
    var _S365 : GGXDistribution_0;
    _S365.alpha_0 = alpha_14;
    _S365.frame_1 = frame_2;
    _S365.isotropicAlpha_0 = isotropicAlpha_2;
    return _S365;
}

fn BSDFInputs_HasDispersion_0( this_75 : BSDFInputs_0) -> bool
{
    var _S366 : bool;
    if(((this_75.transmissionDispersionScale_0) > 0.0f))
    {
        _S366 = ((this_75.transmissionDispersionAbbeNumber_0) > 0.0f);
    }
    else
    {
        _S366 = false;
    }
    if(_S366)
    {
        _S366 = ((this_75.baseMetalness_0) < 1.0f);
    }
    else
    {
        _S366 = false;
    }
    return _S366;
}

fn DispersionAdjustedIor_0( ior_5 : f32,  dispersion_1 : f32,  wavelength_0 : f32) -> f32
{
    var belowOne_0 : bool = (ior_5 < 1.0f);
    var iorAboveOne_0 : f32;
    if(belowOne_0)
    {
        iorAboveOne_0 = 1.0f / ior_5;
    }
    else
    {
        iorAboveOne_0 = ior_5;
    }
    var b_16 : f32 = (iorAboveOne_0 - 1.0f) / (20.0f / dispersion_1 * (Square_0(0.0020571898203343153f) - Square_0(0.001523693441413343f)));
    var adjusted_0 : f32 = iorAboveOne_0 - b_16 * Square_0(0.0017018381040543318f) + b_16 * Square_0(1.0f / wavelength_0);
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

fn FinalTransmissionTint_0( tint_2 : vec3<f32>,  thinWall_0 : bool,  cosI_0 : f32,  etaForRefraction_0 : f32) -> vec3<f32>
{
    if(!thinWall_0)
    {
        return tint_2;
    }
    var sin2T_0 : f32 = (1.0f - Square_0(cosI_0)) / Square_0(etaForRefraction_0);
    if((sin2T_0 >= 1.0f))
    {
        return vec3<f32>(0.0f);
    }
    return pow(tint_2, vec3<f32>((1.0f / sqrt(1.0f - sin2T_0))));
}

fn ThinWallFresnel_0( eta_8 : f32,  cosThetaI_6 : f32) -> f32
{
    var r_9 : f32 = FresnelDielectric_0(eta_8, cosThetaI_6);
    return 2.0f * r_9 / (1.0f + r_9);
}

fn SpecularLobe_x24init_0( normal_12 : vec3<f32>,  distribution_2 : GGXDistribution_0,  coefficient_2 : BaseReflectionTransmission_0,  eta_9 : vec3<f32>,  throughput_8 : vec3<f32>) -> SpecularLobe_0
{
    var _S367 : SpecularLobe_0;
    _S367.normal_1 = normal_12;
    _S367.distribution_0 = distribution_2;
    _S367.coefficient_0 = coefficient_2;
    _S367.eta_0 = eta_9;
    _S367.throughput_0 = throughput_8;
    return _S367;
}

fn IdealDielectricReflectionRatio_0( ior_6 : f32,  alpha_15 : f32) -> f32
{
    return LookUpBilinear_0(i32(65), IorToExactIndex_0(ior_6), AlphaToExactIndex_0(alpha_15));
}

fn DielectricMultipleScatteringLobe_x24init_0( normal_13 : vec3<f32>,  wo_28 : vec3<f32>,  alpha_16 : f32,  eta_10 : f32,  reflectionScale_1 : vec3<f32>,  transmissionScale_1 : vec3<f32>) -> DielectricMultipleScatteringLobe_0
{
    var _S368 : DielectricMultipleScatteringLobe_0;
    _S368.normal_2 = normal_13;
    _S368.alpha_1 = alpha_16;
    _S368.eta_1 = eta_10;
    _S368.reflectionScale_0 = reflectionScale_1;
    _S368.transmissionScale_0 = transmissionScale_1;
    _S368.reflectionRatio_0 = 0.0f;
    _S368.energyComplementWo_0 = 0.0f;
    var _S369 : bool;
    if((alpha_16 >= 0.0015999999595806003f))
    {
        _S369 = (any((((max(reflectionScale_1, transmissionScale_1)) > vec3<f32>(0.0f)))));
    }
    else
    {
        _S369 = false;
    }
    if(_S369)
    {
        _S368.reflectionRatio_0 = IdealDielectricReflectionRatio_0(eta_10, alpha_16);
        _S368.energyComplementWo_0 = IdealDielectricEnergyComplement_0(eta_10, alpha_16, dot(wo_28, normal_13));
    }
    return _S368;
}

fn MetalMultipleScatteringLobe_x24init_0( normal_14 : vec3<f32>,  wo_29 : vec3<f32>,  alpha_17 : f32,  scale_5 : vec3<f32>) -> MetalMultipleScatteringLobe_0
{
    var _S370 : MetalMultipleScatteringLobe_0;
    _S370.normal_3 = normal_14;
    _S370.alpha_2 = alpha_17;
    _S370.scale_0 = scale_5;
    var _S371 : bool;
    if(MetalMultipleScatteringLobe_Active_0(_S370))
    {
        _S371 = (any(((scale_5 > vec3<f32>(0.0f)))));
    }
    else
    {
        _S371 = false;
    }
    var _S372 : f32;
    if(_S371)
    {
        _S372 = IdealMetalEnergyComplement_0(alpha_17, dot(wo_29, normal_14));
    }
    else
    {
        _S372 = 0.0f;
    }
    _S370.energyComplementWo_1 = _S372;
    return _S370;
}

fn OpaqueDielectricAverageEnergyComplement_0( ior_7 : f32,  alpha_18 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpBilinear_0(i32(66), IorToExactIndex_0(ior_7), AlphaToExactIndex_0(alpha_18)), ior_7);
}

fn DiffuseLobe_x24init_0( normal_15 : vec3<f32>,  wo_30 : vec3<f32>,  albedo_6 : vec3<f32>,  roughness_5 : f32,  specularAlpha_1 : f32,  specularEta_1 : f32) -> DiffuseLobe_0
{
    var _S373 : DiffuseLobe_0;
    _S373.normal_4 = normal_15;
    _S373.albedo_1 = albedo_6;
    _S373.roughness_0 = roughness_5;
    _S373.specularAlpha_0 = specularAlpha_1;
    _S373.specularEta_0 = specularEta_1;
    _S373.specularCompensation_0 = 0.0f;
    if((any(((albedo_6 > vec3<f32>(0.0f))))))
    {
        _S373.specularCompensation_0 = OpaqueDielectricEnergyComplement_0(specularEta_1, specularAlpha_1, dot(wo_30, normal_15)) / ClampAverageEnergyComplement_0(OpaqueDielectricAverageEnergyComplement_0(specularEta_1, specularAlpha_1));
    }
    return _S373;
}

fn ConstantReflection_x24init_0( color_6 : vec3<f32>) -> ConstantReflection_0
{
    var _S374 : ConstantReflection_0;
    _S374.color_0 = color_6;
    return _S374;
}

fn MicrofacetReflectionLobe_x24init_0( normal_16 : vec3<f32>,  distribution_3 : GGXDistribution_0,  coefficient_3 : ConstantReflection_0) -> MicrofacetReflectionLobe_0
{
    var _S375 : MicrofacetReflectionLobe_0;
    _S375.normal_5 = normal_16;
    _S375.distribution_1 = distribution_3;
    _S375.coefficient_1 = coefficient_3;
    return _S375;
}

fn FlippedLobe_x24init_0( lobe_3 : MicrofacetReflectionLobe_0) -> FlippedLobe_0
{
    var _S376 : FlippedLobe_0;
    _S376.lobe_0 = lobe_3;
    return _S376;
}

fn MakeThinWallSpecularTransmissionLobe_0( normal_17 : vec3<f32>,  distribution_4 : GGXDistribution_0,  transmissionColor_1 : vec3<f32>) -> FlippedLobe_0
{
    var flipped_0 : GGXDistribution_0 = distribution_4;
    flipped_0.frame_1.n_1 = (vec3<f32>(0) - flipped_0.frame_1.n_1);
    return FlippedLobe_x24init_0(MicrofacetReflectionLobe_x24init_0((vec3<f32>(0) - normal_17), flipped_0, ConstantReflection_x24init_0(transmissionColor_1)));
}

fn FlippedLobe_x24init_1( lobe_4 : DiffuseLobe_0) -> FlippedLobe_1
{
    var _S377 : FlippedLobe_1;
    _S377.lobe_0 = lobe_4;
    return _S377;
}

fn MakeThinWallDiffuseTransmissionLobe_0( normal_18 : vec3<f32>,  wo_31 : vec3<f32>,  albedo_7 : vec3<f32>,  roughness_6 : f32,  specularAlpha_2 : f32,  specularEta_2 : f32) -> FlippedLobe_1
{
    var flippedNormal_0 : vec3<f32> = (vec3<f32>(0) - normal_18);
    var reflectedWo_0 : vec3<f32> = reflect(wo_31, normal_18);
    var reflectedWo_1 : vec3<f32>;
    if(((dot(reflectedWo_0, flippedNormal_0)) < 0.0f))
    {
        reflectedWo_1 = (vec3<f32>(0) - reflectedWo_0);
    }
    else
    {
        reflectedWo_1 = reflectedWo_0;
    }
    return FlippedLobe_x24init_1(DiffuseLobe_x24init_0(flippedNormal_0, reflectedWo_1, albedo_7, roughness_6, specularAlpha_2, specularEta_2));
}

fn BaseReflectionTransmission_EstimateWeight_0( this_76 : BaseReflectionTransmission_0,  throughput_9 : vec3<f32>,  idotn_7 : f32) -> f32
{
    var c_13 : ReflectionTransmission_0 = BaseReflectionTransmission_Coefficients_0(this_76, idotn_7);
    return ThroughputWeightedMax_0(throughput_9, c_13.reflection_1 + c_13.transmission_1);
}

fn SpecularLobe_EstimateContribution_0( this_77 : SpecularLobe_0,  wo_32 : vec3<f32>,  throughput_10 : vec3<f32>) -> f32
{
    return BaseReflectionTransmission_EstimateWeight_0(this_77.coefficient_0, throughput_10, dot(wo_32, this_77.normal_1));
}

fn DielectricMultipleScatteringLobe_EstimateContribution_0( this_78 : DielectricMultipleScatteringLobe_0,  wo_33 : vec3<f32>,  throughput_11 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_78))
    {
        return 0.0f;
    }
    return ThroughputWeightedMax_0(throughput_11, this_78.reflectionScale_0 * vec3<f32>(this_78.reflectionRatio_0) + this_78.transmissionScale_0 * vec3<f32>((1.0f - this_78.reflectionRatio_0))) * this_78.energyComplementWo_0;
}

fn MetalMultipleScatteringLobe_EstimateContribution_0( this_79 : MetalMultipleScatteringLobe_0,  wo_34 : vec3<f32>,  throughput_12 : vec3<f32>) -> f32
{
    var _S378 : f32;
    if(MetalMultipleScatteringLobe_Active_0(this_79))
    {
        _S378 = ThroughputWeightedMax_0(throughput_12, this_79.scale_0) * this_79.energyComplementWo_1;
    }
    else
    {
        _S378 = 0.0f;
    }
    return _S378;
}

fn DiffuseLobe_EstimateContribution_0( this_80 : DiffuseLobe_0,  wo_35 : vec3<f32>,  throughput_13 : vec3<f32>) -> f32
{
    return ThroughputWeightedMax_0(throughput_13, this_80.albedo_1 * vec3<f32>(this_80.specularCompensation_0));
}

fn ConstantReflection_EstimateWeightOnGGX_0( this_81 : ConstantReflection_0,  throughput_14 : vec3<f32>,  idotn_8 : f32,  isotropicAlpha_3 : f32) -> f32
{
    return ThroughputWeightedMax_0(throughput_14, this_81.color_0);
}

fn MicrofacetReflectionLobe_EstimateContribution_0( this_82 : MicrofacetReflectionLobe_0,  wo_36 : vec3<f32>,  throughput_15 : vec3<f32>) -> f32
{
    return ConstantReflection_EstimateWeightOnGGX_0(this_82.coefficient_1, throughput_15, dot(wo_36, this_82.normal_5), this_82.distribution_1.isotropicAlpha_0);
}

fn FlippedLobe_EstimateContribution_0( this_83 : FlippedLobe_0,  wo_37 : vec3<f32>,  throughput_16 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_EstimateContribution_0(this_83.lobe_0, reflect(wo_37, MicrofacetReflectionLobe_GetNormal_0(this_83.lobe_0)), throughput_16);
}

fn FlippedLobe_EstimateContribution_1( this_84 : FlippedLobe_1,  wo_38 : vec3<f32>,  throughput_17 : vec3<f32>) -> f32
{
    return DiffuseLobe_EstimateContribution_0(this_84.lobe_0, reflect(wo_38, DiffuseLobe_GetNormal_0(this_84.lobe_0)), throughput_17);
}

fn BaseLobe_LobeEstimate_0( this_85 : BaseLobe_0,  index_14 : i32,  wo_39 : vec3<f32>,  throughput_18 : vec3<f32>) -> f32
{
    switch(index_14)
    {
    case i32(0):
        {
            return SpecularLobe_EstimateContribution_0(this_85.specular_0, wo_39, throughput_18);
        }
    case i32(1):
        {
            return DielectricMultipleScatteringLobe_EstimateContribution_0(this_85.dielectricMultipleScattering_0, wo_39, throughput_18);
        }
    case i32(2):
        {
            return MetalMultipleScatteringLobe_EstimateContribution_0(this_85.metalMultipleScattering_0, wo_39, throughput_18);
        }
    case i32(3):
        {
            return DiffuseLobe_EstimateContribution_0(this_85.diffuse_0, wo_39, throughput_18);
        }
    case i32(4):
        {
            return FlippedLobe_EstimateContribution_0(this_85.thinWallSpecularTransmission_0, wo_39, throughput_18);
        }
    default :
        {
            return FlippedLobe_EstimateContribution_1(this_85.thinWallDiffuseTransmission_0, wo_39, throughput_18);
        }
    }
}

fn BaseLobe_InitWeights_0( this_86 : ptr<function, BaseLobe_0>,  wo_40 : vec3<f32>,  throughput_19 : vec3<f32>)
{
    var _S379 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(0), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(0)] = _S379;
    if(BaseLobeEnabled_0(i32(1)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(1), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(1)] = _S379;
    if(BaseLobeEnabled_0(i32(2)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(2), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(2)] = _S379;
    if(BaseLobeEnabled_0(i32(3)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(3), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(3)] = _S379;
    if(BaseLobeEnabled_0(i32(4)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(4), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(4)] = _S379;
    if(BaseLobeEnabled_0(i32(5)))
    {
        _S379 = BaseLobe_LobeEstimate_0((*this_86), i32(5), wo_40, throughput_19);
    }
    else
    {
        _S379 = 0.0f;
    }
    (*this_86).weights_0[i32(5)] = _S379;
    return;
}

fn DielectricReflection_x24init_0( eta_11 : f32) -> DielectricReflection_0
{
    var _S380 : DielectricReflection_0;
    _S380.eta_2 = eta_11;
    return _S380;
}

fn MicrofacetReflectionLobe_x24init_1( normal_19 : vec3<f32>,  distribution_5 : GGXDistribution_0,  coefficient_4 : DielectricReflection_0) -> MicrofacetReflectionLobe_1
{
    var _S381 : MicrofacetReflectionLobe_1;
    _S381.normal_5 = normal_19;
    _S381.distribution_1 = distribution_5;
    _S381.coefficient_1 = coefficient_4;
    return _S381;
}

fn DielectricEnergyReflected_0( ior_8 : f32,  alpha_19 : f32,  cosTheta_12 : f32) -> f32
{
    if(alpha_19 == 0.0f)
    {
        return FresnelDielectric_0(ior_8, cosTheta_12);
    }
    return 1.0f - OpaqueDielectricEnergyComplement_0(ior_8, alpha_19, cosTheta_12);
}

fn CoatLobe_ProportionReflected_0( this_87 : CoatLobe_0,  cosine_2 : f32) -> f32
{
    var _S382 : bool;
    if((cosine_2 > 0.0f))
    {
        _S382 = CoatLobe_HasCoat_0(this_87);
    }
    else
    {
        _S382 = false;
    }
    if(_S382)
    {
        return DielectricEnergyReflected_0(this_87.reflection_0.coefficient_1.eta_2, this_87.reflection_0.distribution_1.isotropicAlpha_0, cosine_2) * this_87.presence_0;
    }
    return 0.0f;
}

fn CoatLobe_x24init_0( base_6 : BaseLobe_0,  reflection_2 : MicrofacetReflectionLobe_1,  normal_20 : vec3<f32>,  wo_41 : vec3<f32>,  tint_3 : vec3<f32>,  presence_5 : f32,  extraBaseLayerScale_0 : vec3<f32>,  inside_1 : bool) -> CoatLobe_0
{
    var _S383 : CoatLobe_0;
    _S383.base_2 = base_6;
    _S383.reflection_0 = reflection_2;
    _S383.normal_6 = normal_20;
    _S383.tint_0 = tint_3;
    _S383.presence_0 = presence_5;
    _S383.inside_0 = inside_1;
    var idotn_9 : f32 = dot(wo_41, normal_20);
    var _S384 : f32 = CoatLobe_ProportionReflected_0(_S383, idotn_9);
    _S383.inReflected_0 = _S384;
    _S383.inBaseLayerScale_0 = CoatLobe_BaseLayerScaleOneSide_0(_S383, idotn_9, _S384) * extraBaseLayerScale_0;
    return _S383;
}

fn FuzzLobe_ProportionReflected_0( this_88 : FuzzLobe_0,  directionLocal_1 : vec3<f32>) -> f32
{
    var _S385 : bool;
    if(((directionLocal_1.z) <= 0.0f))
    {
        _S385 = true;
    }
    else
    {
        _S385 = !FuzzLobe_HasFuzz_0(this_88);
    }
    if(_S385)
    {
        return 0.0f;
    }
    return this_88.presence_1 * FuzzLobe_Coefficients_0(this_88, directionLocal_1).z;
}

fn FuzzLobe_x24init_0( base_7 : CoatLobe_0,  normal_21 : vec3<f32>,  wo_42 : vec3<f32>,  roughness_7 : f32,  tint_4 : vec3<f32>,  presence_6 : f32) -> FuzzLobe_0
{
    var _S386 : FuzzLobe_0;
    _S386.base_3 = base_7;
    _S386.alpha_3 = roughness_7;
    _S386.tint_1 = tint_4;
    _S386.presence_1 = presence_6;
    var _S387 : Frame_0 = BasisFromNormal_0(normal_21);
    _S386.basis_0 = _S387;
    var _S388 : vec3<f32> = Frame_ToLocal_0(_S387, wo_42);
    _S386.woLocal_0 = _S388;
    _S386.viewReflected_0 = 0.0f;
    _S386.viewReflected_0 = FuzzLobe_ProportionReflected_0(_S386, _S388);
    return _S386;
}

fn PrepareLobes_0( inputs_3 : BSDFInputs_0,  derived_1 : VolumeDerived_0,  wo_43 : vec3<f32>,  throughput_20 : vec3<f32>,  wavelengths_2 : vec3<f32>,  exteriorIor_0 : f32) -> FuzzLobe_0
{
    var cosTheta_13 : f32 = dot(wo_43, inputs_3.basis_1.n_1);
    var backFacing_0 : bool = (cosTheta_13 < 0.0f);
    var inside_2 : bool;
    if(backFacing_0)
    {
        inside_2 = !inputs_3.geometryThinWalled_0;
    }
    else
    {
        inside_2 = false;
    }
    var specularBasis_0 : Frame_0 = Frame_RotatedAroundNormal_0(inputs_3.basis_1, inputs_3.specularAnisotropyRotation_0);
    var specularBasis_1 : Frame_0;
    if(backFacing_0)
    {
        specularBasis_1 = Frame_Inverted_0(specularBasis_0);
    }
    else
    {
        specularBasis_1 = specularBasis_0;
    }
    var _S389 : Frame_0 = specularBasis_1;
    var coatBasis_1 : Frame_0 = Frame_RotatedAroundNormal_0(inputs_3.coatBasis_0, inputs_3.coatAnisotropyRotation_0);
    var coatBasis_2 : Frame_0;
    if(((dot(wo_43, inputs_3.coatBasis_0.n_1)) < 0.0f))
    {
        coatBasis_2 = Frame_Inverted_0(coatBasis_1);
    }
    else
    {
        coatBasis_2 = coatBasis_1;
    }
    var _S390 : Frame_0 = coatBasis_2;
    var enterCoat_0 : bool;
    if(((inputs_3.coatWeight_0) > 0.0f))
    {
        enterCoat_0 = !inside_2;
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
    if(inside_2)
    {
        var etaRefraction_1 : f32 = exteriorIor_0 / weightedSpecularIor_0;
        var _S391 : f32 = weightedSpecularIor_0 / exteriorIor_0;
        etaRefraction_0 = etaRefraction_1;
        etaCoat_0 = 1.0f;
        etaOpaqueReflection_0 = _S391;
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
        var _S392 : f32 = etaRefraction_0;
        var _S393 : f32 = etaRefraction_0;
        etaRefraction_0 = etaRefraction_2;
        etaOpaqueReflection_0 = _S393;
        etaTransReflection_0 = _S392;
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
    var _S394 : vec3<f32> = AverageFresnelMetalF82_0(weightedBaseColor_0, metalF82Tint_2);
    var kSmooth_0 : f32 = AverageFresnel_0(etaCoat_0);
    var specularityOpaqueDielectric_0 : f32 = AverageFresnel_0(etaOpaqueReflection_0);
    var k_2 : f32 = mix(kSmooth_0, 1.0f - (1.0f - kSmooth_0) / Square_0(etaCoat_0), mix(1.0f, specularRoughness_1, opaqueDielectric_0 * specularityOpaqueDielectric_0 + (sss_0 + trans_0) * AverageFresnel_0(etaTransReflection_0) + inputs_3.baseMetalness_0));
    var _S395 : vec3<f32> = vec3<f32>(darkenedMetal_0);
    var _S396 : vec3<f32> = vec3<f32>(1.0f);
    var _S397 : vec3<f32> = vec3<f32>(opaqueDielectric_0);
    var _S398 : vec3<f32> = vec3<f32>(sss_0);
    var albedoTrans_0 : vec3<f32> = vec3<f32>(trans_0);
    var coatDarkening_1 : vec3<f32> = mix(_S396, vec3<f32>((1.0f - k_2)) / (_S396 - (_S395 * _S394 + _S397 * mix(weightedBaseColor_0, _S396, vec3<f32>(specularityOpaqueDielectric_0)) + _S398 * inputs_3.subsurfaceColor_0 + albedoTrans_0) * vec3<f32>(k_2)), vec3<f32>((inputs_3.coatWeight_0 * inputs_3.coatDarkening_0)));
    var distribution_6 : GGXDistribution_0 = GGXDistribution_x24init_0(anisotropicSpecularAlpha_0, specularBasis_1, specularAlpha_3);
    var transIncludingSss_0 : f32 = trans_0 + sss_0;
    var scaleOpaqueReflection_0 : vec3<f32> = inputs_3.specularColor_0 * _S397;
    var thinWallSpecularTransmissionAlbedoScale_0 : vec3<f32>;
    var thinWallAwareScaleTransReflection_0 : vec3<f32>;
    var scaleTransReflection_0 : vec3<f32>;
    if(inside_2)
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
            var _S399 : vec3<f32> = inputs_3.specularColor_0 * _S398;
            thinWallSpecularTransmissionAlbedoScale_0 = inputs_3.specularColor_0 * albedoTrans_0;
            thinWallAwareScaleTransReflection_0 = _S399;
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
        var _S400 : f32 = SafeDivide_0(20.0f, SafeDivide_0(inputs_3.transmissionDispersionAbbeNumber_0, inputs_3.transmissionDispersionScale_0, 0.0f), 0.0f);
        etaRefractionRGB_0[i32(0)] = DispersionAdjustedIor_0(etaRefraction_0, _S400, wavelengths_2[i32(0)]);
        var _S401 : bool = etaTransReflection_0 == etaRefraction_0;
        if(_S401)
        {
            dispersion_2 = etaRefractionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S400, wavelengths_2[i32(0)]);
        }
        etaTransReflectionRGB_0[i32(0)] = dispersion_2;
        var _S402 : bool = etaOpaqueReflection_0 == etaTransReflection_0;
        if(_S402)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S400, wavelengths_2[i32(0)]);
        }
        etaOpaqueReflectionRGB_0[i32(0)] = dispersion_2;
        etaRefractionRGB_0[i32(1)] = DispersionAdjustedIor_0(etaRefraction_0, _S400, wavelengths_2[i32(1)]);
        if(_S401)
        {
            dispersion_2 = etaRefractionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S400, wavelengths_2[i32(1)]);
        }
        etaTransReflectionRGB_0[i32(1)] = dispersion_2;
        if(_S402)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S400, wavelengths_2[i32(1)]);
        }
        etaOpaqueReflectionRGB_0[i32(1)] = dispersion_2;
        etaRefractionRGB_0[i32(2)] = DispersionAdjustedIor_0(etaRefraction_0, _S400, wavelengths_2[i32(2)]);
        if(_S401)
        {
            dispersion_2 = etaRefractionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S400, wavelengths_2[i32(2)]);
        }
        etaTransReflectionRGB_0[i32(2)] = dispersion_2;
        if(_S402)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S400, wavelengths_2[i32(2)]);
        }
        etaOpaqueReflectionRGB_0[i32(2)] = dispersion_2;
        dispersion_2 = _S400;
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
        thinWallAwareCosTheta_0 = abs(cosTheta_13);
    }
    else
    {
        thinWallAwareCosTheta_0 = cosTheta_13;
    }
    var tintedTrans_0 : vec3<f32> = albedoTrans_0 * FinalTransmissionTint_0(derived_1.transmissionTint_0, inputs_3.geometryThinWalled_0, thinWallAwareCosTheta_0, etaRefraction_0);
    var tintedTransIncludingSss_0 : vec3<f32> = tintedTrans_0 + _S398;
    var thinWallAwareTintedTransIncludingSss_0 : vec3<f32> = vec3<f32>(nonThinWallWeight_0) * tintedTransIncludingSss_0;
    var thinFilmInteriorIor_1 : vec3<f32>;
    var thinFilmExteriorIor_1 : f32;
    if(inside_2)
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
    var _S403 : vec3<f32> = vec3<f32>(0.0f);
    var thinWallSpecularReflectionAlbedo_0 : vec3<f32>;
    var thinWallSpecularTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var _S404 : vec3<f32> = tintedTrans_0 * vec3<f32>((1.0f - ThinWallFresnel_0(etaRefraction_0, thinWallAwareCosTheta_0)));
        thinWallSpecularReflectionAlbedo_0 = thinWallSpecularTransmissionAlbedoScale_0 * vec3<f32>(ThinWallFresnel_0(etaTransReflection_0, thinWallAwareCosTheta_0));
        thinWallSpecularTransmissionAlbedo_0 = _S404;
    }
    else
    {
        thinWallSpecularReflectionAlbedo_0 = _S403;
        thinWallSpecularTransmissionAlbedo_0 = _S403;
    }
    var thinWallSubsurfaceReflectionAlbedo_0 : vec3<f32>;
    var thinWallSubsurfaceTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var transmissionProportion_0 : f32 = (derived_1.thinWallSubsurfaceAnisotropy_0 + 1.0f) * 0.5f;
        var subsurfaceAlbedo_0 : vec3<f32> = _S398 * derived_1.thinWallSubsurfaceColor_0;
        var _S405 : vec3<f32> = subsurfaceAlbedo_0 * vec3<f32>(transmissionProportion_0);
        thinWallSubsurfaceReflectionAlbedo_0 = subsurfaceAlbedo_0 * vec3<f32>((1.0f - transmissionProportion_0));
        thinWallSubsurfaceTransmissionAlbedo_0 = _S405;
    }
    else
    {
        thinWallSubsurfaceReflectionAlbedo_0 = _S403;
        thinWallSubsurfaceTransmissionAlbedo_0 = _S403;
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
    coefficient_5.thinFilmWeight_0 = inputs_3.thinFilmWeight_1;
    coefficient_5.thinFilmThickness_0 = inputs_3.thinFilmThickness_1 * 1000.0f;
    coefficient_5.thinFilmExteriorIor_0 = thinFilmExteriorIor_1;
    coefficient_5.thinFilmIor_0 = inputs_3.thinFilmIor_1;
    coefficient_5.thinFilmInteriorIor_0 = thinFilmInteriorIor_1;
    coefficient_5.wavelengths_0 = wavelengths_2;
    coefficient_5.thinWallReflection_0 = thinWallSpecularReflectionAlbedo_0;
    var base_8 : BaseLobe_0;
    base_8.specular_0 = SpecularLobe_x24init_0(_S389.n_1, distribution_6, coefficient_5, etaRefractionRGB_0, throughput_20);
    base_8.dielectricMultipleScattering_0 = DielectricMultipleScatteringLobe_x24init_0(_S389.n_1, wo_43, specularAlpha_3, etaRefraction_0, scaleTransReflection_0, tintedTransIncludingSss_0);
    base_8.metalMultipleScattering_0 = MetalMultipleScatteringLobe_x24init_0(_S389.n_1, wo_43, specularAlpha_3, Square_1(_S394) * _S395);
    base_8.diffuse_0 = DiffuseLobe_x24init_0(_S389.n_1, wo_43, weightedBaseColor_0 * _S397 + thinWallSubsurfaceReflectionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    base_8.thinWallSpecularTransmission_0 = MakeThinWallSpecularTransmissionLobe_0(_S389.n_1, distribution_6, thinWallSpecularTransmissionAlbedo_0);
    base_8.thinWallDiffuseTransmission_0 = MakeThinWallDiffuseTransmissionLobe_0(_S389.n_1, wo_43, thinWallSubsurfaceTransmissionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    BaseLobe_InitWeights_0(&(base_8), wo_43, throughput_20);
    var coat_0 : CoatLobe_0 = CoatLobe_x24init_0(base_8, MicrofacetReflectionLobe_x24init_1(_S390.n_1, GGXDistribution_x24init_0(anisotropicCoatAlpha_0, coatBasis_2, coatAlpha_0), DielectricReflection_x24init_0(etaCoat_0)), _S390.n_1, wo_43, inputs_3.coatColor_0, inputs_3.coatWeight_0, coatDarkening_1, inside_2);
    var fuzzNormal_0 : vec3<f32> = normalize(mix(_S389.n_1, _S390.n_1, vec3<f32>(inputs_3.coatWeight_0)));
    if(inside_2)
    {
        weightedCoatIor_0 = 0.0f;
    }
    else
    {
        weightedCoatIor_0 = inputs_3.fuzzWeight_0;
    }
    return FuzzLobe_x24init_0(coat_0, fuzzNormal_0, wo_43, inputs_3.fuzzRoughness_0, inputs_3.fuzzColor_0, weightedCoatIor_0);
}

fn ComputeEmission_0( inputs_4 : BSDFInputs_0,  wo_44 : vec3<f32>,  lobes_1 : FuzzLobe_0) -> vec3<f32>
{
    var inside_3 : bool;
    if((inputs_4.emissionLuminance_0) == 0.0f)
    {
        inside_3 = true;
    }
    else
    {
        inside_3 = (all(((inputs_4.emissionColor_0) == vec3<f32>(0.0f))));
    }
    if(inside_3)
    {
        return vec3<f32>(0.0f);
    }
    if(((dot(wo_44, inputs_4.basis_1.n_1)) < 0.0f))
    {
        inside_3 = !inputs_4.geometryThinWalled_0;
    }
    else
    {
        inside_3 = false;
    }
    if(inside_3)
    {
        return vec3<f32>(0.0f);
    }
    var result_5 : vec3<f32> = vec3<f32>(inputs_4.emissionLuminance_0) * inputs_4.emissionColor_0;
    var result_6 : vec3<f32>;
    if(((inputs_4.coatWeight_0) > 0.0f))
    {
        result_6 = result_5 * lobes_1.base_3.inBaseLayerScale_0;
    }
    else
    {
        result_6 = result_5;
    }
    if(((inputs_4.fuzzWeight_0) > 0.0f))
    {
        result_6 = result_6 * vec3<f32>(FuzzLobe_BaseLayerScaleIncoming_0(lobes_1));
    }
    return result_6;
}

fn BSDF_x24init_0( inputs_5 : BSDFInputs_0,  wo_45 : vec3<f32>,  throughput_21 : vec3<f32>,  wavelengths_3 : vec3<f32>,  exteriorIor_1 : f32) -> BSDF_0
{
    var _S406 : BSDF_0;
    _S406.wo_0 = wo_45;
    var derived_2 : VolumeDerived_0;
    var _S407 : HomogeneousVolume_0 = PrepareVolume_0(inputs_5, &(derived_2));
    _S406.volume_0 = _S407;
    var _S408 : FuzzLobe_0 = PrepareLobes_0(inputs_5, derived_2, wo_45, throughput_21, wavelengths_3, exteriorIor_1);
    _S406.lobes_0 = _S408;
    _S406.emission_0 = ComputeEmission_0(inputs_5, wo_45, _S408);
    return _S406;
}

fn EmissiveHitPdf_0( _S409 : u32,  _S410 : u32,  _S411 : vec3<f32>,  _S412 : vec3<f32>) -> f32
{
    if((((gInstances_0[_S409].flags_0) & (u32(2)))) == u32(0))
    {
        return 0.0f;
    }
    var light_4 : EmissiveTriangle_std430_0 = gLights_0[gInstances_0[_S409].lightOffset_0 + _S410];
    return light_4.p1_0.w * EmissiveSolidAnglePdf_0(light_4.p0_0.w, MaterialHeader_DoubleSided_0(LoadMaterialHeader_0((bitcast<u32>((light_4.n_0.w))))), _S411, _S412, light_4.n_0.xyz);
}

fn RandomSequence_x24init_0( positionSeed_0 : u32,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S413 : RandomSequence_0;
    _S413.seed_0 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_0));
    return _S413;
}

fn BaseLobe_MaxActiveAlpha_0( this_89 : BaseLobe_0) -> f32
{
    var _S414 : bool;
    if(BaseLobe_IsActive_0(this_89, i32(3)))
    {
        _S414 = true;
    }
    else
    {
        _S414 = BaseLobe_IsActive_0(this_89, i32(5));
    }
    if(_S414)
    {
        _S414 = true;
    }
    else
    {
        _S414 = BaseLobe_IsActive_0(this_89, i32(1));
    }
    if(_S414)
    {
        _S414 = true;
    }
    else
    {
        _S414 = BaseLobe_IsActive_0(this_89, i32(2));
    }
    if(_S414)
    {
        return 1.0f;
    }
    if(BaseLobe_IsActive_0(this_89, i32(0)))
    {
        _S414 = true;
    }
    else
    {
        _S414 = BaseLobe_IsActive_0(this_89, i32(4));
    }
    if(_S414)
    {
        return max(this_89.specular_0.distribution_0.alpha_0.x, this_89.specular_0.distribution_0.alpha_0.y);
    }
    return 0.0f;
}

fn CoatLobe_MaxActiveAlpha_0( this_90 : CoatLobe_0) -> f32
{
    var _S415 : bool;
    if(this_90.inside_0)
    {
        _S415 = true;
    }
    else
    {
        _S415 = !CoatLobe_HasCoat_0(this_90);
    }
    var _S416 : f32;
    if(_S415)
    {
        _S416 = 0.0f;
    }
    else
    {
        _S416 = max(this_90.reflection_0.distribution_1.alpha_0.x, this_90.reflection_0.distribution_1.alpha_0.y);
    }
    return _S416;
}

fn BSDF_MaxActiveAlpha_0( this_91 : BSDF_0) -> f32
{
    var baseAlpha_0 : f32 = BaseLobe_MaxActiveAlpha_0(this_91.lobes_0.base_3.base_2);
    var _S417 : f32;
    if(FuzzLobe_HasFuzz_0(this_91.lobes_0))
    {
        _S417 = 1.0f;
    }
    else
    {
        _S417 = max(baseAlpha_0, CoatLobe_MaxActiveAlpha_0(this_91.lobes_0.base_3));
    }
    return _S417;
}

struct LobeSample_0
{
     wi_26 : vec3<f32>,
     weight_1 : DiffuseSpecular_0,
     pdf_7 : f32,
     type_0 : u32,
     valid_1 : bool,
};

fn SampleCosineHemisphere_0( u_10 : vec2<f32>) -> vec3<f32>
{
    var phi_2 : f32 = 2.0f * float_getPi_0() * u_10.x;
    var _S418 : f32 = u_10.y;
    var sinTheta_1 : f32 = sqrt(1.0f - _S418);
    return vec3<f32>(sinTheta_1 * cos(phi_2), sinTheta_1 * sin(phi_2), sqrt(_S418));
}

fn SheenSampleLTC_0( ltc_2 : vec3<f32>,  u_11 : vec2<f32>) -> vec3<f32>
{
    var wiOriginal_1 : vec3<f32> = SampleCosineHemisphere_0(u_11);
    var a_17 : f32 = 1.0f / ltc_2.x;
    var _S419 : f32 = wiOriginal_1.z;
    return normalize(vec3<f32>(wiOriginal_1.x * a_17 - _S419 * ltc_2.y * a_17, wiOriginal_1.y * a_17, _S419));
}

fn Frame_ToWorld_0( this_92 : Frame_0,  v_16 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(v_16.x) * this_92.t_0 + vec3<f32>(v_16.y) * this_92.b_0 + vec3<f32>(v_16.z) * this_92.n_1;
}

fn ClampRemappedRandom_0( u_12 : f32) -> f32
{
    return min(u_12, 0.99999994039535522f);
}

fn SampleGGXVisibleNormal_0( alpha_20 : vec2<f32>,  wo_46 : vec3<f32>,  u_13 : vec2<f32>) -> vec3<f32>
{
    var toHemisphere_0 : vec3<f32> = vec3<f32>(alpha_20.x, alpha_20.y, 1.0f);
    var woHemisphere_0 : vec3<f32> = normalize(toHemisphere_0 * wo_46);
    var _S420 : f32 = min(woHemisphere_0.z, 1.0f);
    var angle_2 : f32 = 2.0f * float_getPi_0() * u_13.x;
    var onePlusCos_0 : f32 = 1.0f + _S420;
    var _S421 : f32 = u_13.y;
    var z_8 : f32 = (1.0f - _S421) * onePlusCos_0;
    var radius_3 : f32 = sqrt((z_8 + (1.0f - _S420)) * (_S421 * onePlusCos_0));
    return normalize(toHemisphere_0 * vec3<f32>(radius_3 * cos(angle_2) + woHemisphere_0.x, radius_3 * sin(angle_2) + woHemisphere_0.y, z_8));
}

fn GGXDistribution_SampleVisibleNormal_0( this_93 : GGXDistribution_0,  wo_47 : vec3<f32>,  u_14 : vec2<f32>) -> vec3<f32>
{
    return Frame_ToWorld_0(this_93.frame_1, SampleGGXVisibleNormal_0(this_93.alpha_0, Frame_ToLocal_0(this_93.frame_1, wo_47), u_14));
}

fn LobeSample_Invalid_0() -> LobeSample_0
{
    var s_14 : LobeSample_0;
    s_14.wi_26 = vec3<f32>(0.0f);
    s_14.weight_1 = DiffuseSpecular_Zero_0();
    s_14.pdf_7 = 0.0f;
    s_14.type_0 = u32(0);
    s_14.valid_1 = false;
    return s_14;
}

fn MicrofacetReflectionLobe_LobeType_0( this_94 : MicrofacetReflectionLobe_1) -> u32
{
    return u32(9);
}

fn LobeSample_Make_0( wi_27 : vec3<f32>,  weight_2 : DiffuseSpecular_0,  pdf_8 : f32,  type_1 : u32) -> LobeSample_0
{
    var s_15 : LobeSample_0;
    s_15.wi_26 = wi_27;
    s_15.weight_1 = weight_2;
    s_15.pdf_7 = pdf_8;
    s_15.type_0 = type_1;
    s_15.valid_1 = true;
    return s_15;
}

fn MicrofacetReflectionLobe_Sample_0( this_95 : MicrofacetReflectionLobe_1,  u_15 : vec3<f32>,  wo_48 : vec3<f32>) -> LobeSample_0
{
    var idotn_10 : f32 = dot(wo_48, this_95.normal_5);
    var h_12 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_95.distribution_1, wo_48, u_15.xy);
    var idoth_14 : f32 = dot(wo_48, h_12);
    if((idoth_14 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_28 : vec3<f32> = normalize((vec3<f32>(0) - wo_48) + h_12 * vec3<f32>(2.0f) * vec3<f32>(idoth_14));
    if(((idotn_10 * dot(this_95.normal_5, wi_28)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_4 : f32 = dot(wi_28, h_12);
    var f_14 : vec3<f32> = DielectricReflection_Reflection_0(this_95.coefficient_1, idoth_14);
    var gShadowing_0 : f32 = GGXDistribution_G1_0(this_95.distribution_1, wi_28);
    var d_8 : f32 = GGXDistribution_D_0(this_95.distribution_1, h_12);
    if((d_8 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_28, DiffuseSpecular_Specular_0(f_14 * vec3<f32>(gShadowing_0)), d_8 * GGXDistribution_G1_0(this_95.distribution_1, wo_48) * idoth_14 / (4.0f * odoth_4 * idotn_10), MicrofacetReflectionLobe_LobeType_0(this_95));
}

fn SampledLobe_Make_0( layer_1 : i32,  lobe_5 : i32,  sample_0 : LobeSample_0) -> SampledLobe_0
{
    var s_16 : SampledLobe_0;
    s_16.layer_0 = layer_1;
    s_16.lobe_1 = lobe_5;
    s_16.f_1 = x2A_1(sample_0.weight_1, sample_0.pdf_7);
    s_16.pdf_0 = sample_0.pdf_7;
    return s_16;
}

fn BaseLobe_SelectLobe_0( this_96 : BaseLobe_0,  u_16 : ptr<function, f32>,  selectedWeight_0 : ptr<function, f32>,  totalWeight_2 : ptr<function, f32>) -> i32
{
    var weightSoFar_0 : f32;
    var _S422 : f32 = BaseLobe_TotalWeight_0(this_96);
    (*totalWeight_2) = _S422;
    if((_S422 <= 1.17549435082228751e-38f))
    {
        (*selectedWeight_0) = 0.0f;
        return i32(-1);
    }
    (*u_16) = (*u_16) * (*totalWeight_2);
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
                (*selectedWeight_0) = this_96.weights_0[i32(0)];
                if(((*u_16) < (this_96.weights_0[i32(0)])))
                {
                    (*u_16) = ClampRemappedRandom_0((*u_16) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_96.weights_0[i32(1)];
                if(((*u_16) < (weightSoFar_0 + this_96.weights_0[i32(1)])))
                {
                    (*u_16) = ClampRemappedRandom_0(((*u_16) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_96.weights_0[i32(2)];
                if(((*u_16) < (weightSoFar_0 + this_96.weights_0[i32(2)])))
                {
                    (*u_16) = ClampRemappedRandom_0(((*u_16) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_96.weights_0[i32(3)];
                if(((*u_16) < (weightSoFar_0 + this_96.weights_0[i32(3)])))
                {
                    (*u_16) = ClampRemappedRandom_0(((*u_16) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_96.weights_0[i32(4)];
                if(((*u_16) < (weightSoFar_0 + this_96.weights_0[i32(4)])))
                {
                    (*u_16) = ClampRemappedRandom_0(((*u_16) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(4);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        break;
    }
    (*selectedWeight_0) = this_96.weights_0[i32(5)];
    (*u_16) = ClampRemappedRandom_0(((*u_16) - weightSoFar_0) / this_96.weights_0[i32(5)]);
    return i32(5);
}

fn Refract_0( wi_29 : vec3<f32>,  n_16 : vec3<f32>,  cosThetaI_7 : f32,  eta_12 : f32,  wt_0 : ptr<function, vec3<f32>>) -> bool
{
    var invEta_0 : f32 = 1.0f / eta_12;
    var sin2ThetaT_1 : f32 = Square_0(invEta_0) * max(0.0f, 1.0f - Square_0(cosThetaI_7));
    if((sin2ThetaT_1 >= 1.0f))
    {
        (*wt_0) = vec3<f32>(0.0f);
        return false;
    }
    (*wt_0) = normalize((vec3<f32>(0) - wi_29) * vec3<f32>(invEta_0) + n_16 * vec3<f32>((invEta_0 * cosThetaI_7 - sqrt(1.0f - sin2ThetaT_1))));
    return true;
}

fn SpecularLobe_Sample_0( this_97 : SpecularLobe_0,  u_17 : vec3<f32>,  wo_49 : vec3<f32>) -> LobeSample_0
{
    var idotn_11 : f32 = dot(wo_49, this_97.normal_1);
    var h_13 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_97.distribution_0, wo_49, u_17.xy);
    var idoth_15 : f32 = dot(wo_49, h_13);
    if((idoth_15 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var c_14 : ReflectionTransmission_0 = BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_97.coefficient_0, this_97.throughput_0, idoth_15);
    if((c_14.reflectionProbability_0 + c_14.transmissionProbability_0) == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var _S423 : f32 = u_17.z;
    if((_S423 < (c_14.reflectionProbability_0)))
    {
        var wi_30 : vec3<f32> = normalize((vec3<f32>(0) - wo_49) + h_13 * vec3<f32>(2.0f) * vec3<f32>(idoth_15));
        if(((idotn_11 * dot(this_97.normal_1, wi_30)) <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        var odoth_5 : f32 = dot(wi_30, h_13);
        var weight_3 : DiffuseSpecular_0 = DiffuseSpecular_Specular_0(c_14.reflection_1 * vec3<f32>((1.0f / c_14.reflectionProbability_0)) * vec3<f32>(GGXDistribution_G1_0(this_97.distribution_0, wi_30)));
        var d_9 : f32 = GGXDistribution_D_0(this_97.distribution_0, h_13);
        if((d_9 <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        return LobeSample_Make_0(wi_30, weight_3, c_14.reflectionProbability_0 * d_9 * GGXDistribution_G1_0(this_97.distribution_0, wo_49) * idoth_15 / (4.0f * odoth_5 * idotn_11), u32(9));
    }
    var remapped_0 : f32 = (_S423 - c_14.reflectionProbability_0) / c_14.transmissionProbability_0;
    var channelProbabilities_0 : vec3<f32> = SpecularLobe_ChannelProbabilities_0(this_97);
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
    var wi_31 : vec3<f32>;
    var _S424 : bool = Refract_0(wo_49, h_13, idoth_15, this_97.eta_0[channel_0], &(wi_31));
    if(!_S424)
    {
        return LobeSample_Invalid_0();
    }
    if(((idotn_11 * dot(wi_31, this_97.normal_1)) >= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var pdf_9 : f32 = SpecularLobe_Pdf_0(this_97, wo_49, wi_31);
    if(pdf_9 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_31, x2A_1(SpecularLobe_Eval_0(this_97, wo_49, wi_31), 1.0f / pdf_9), pdf_9, u32(10));
}

fn UniformHemisphereDirection_0( basis_3 : Frame_0,  z_9 : f32,  u_18 : f32) -> vec3<f32>
{
    var horizontal_0 : f32 = sqrt(1.0f - Square_0(z_9));
    var azimuth_2 : f32 = 2.0f * float_getPi_0() * u_18;
    return Frame_ToWorld_0(basis_3, vec3<f32>(cos(azimuth_2) * horizontal_0, sin(azimuth_2) * horizontal_0, z_9));
}

fn DielectricMultipleScatteringLobe_Sample_0( this_98 : DielectricMultipleScatteringLobe_0,  u_19 : vec3<f32>,  wo_50 : vec3<f32>) -> LobeSample_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_98))
    {
        return LobeSample_Invalid_0();
    }
    var ux_0 : f32 = u_19.x;
    var z_10 : f32;
    if((ux_0 < (this_98.reflectionRatio_0)))
    {
        z_10 = ClampRemappedRandom_0(ux_0 / this_98.reflectionRatio_0);
    }
    else
    {
        z_10 = - ClampRemappedRandom_0((ux_0 - this_98.reflectionRatio_0) / (1.0f - this_98.reflectionRatio_0));
    }
    var wi_32 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_98.normal_2), z_10, u_19.y);
    var odotn_4 : f32 = dot(wi_32, this_98.normal_2);
    var unscaledWeight_0 : f32 = 2.0f * abs(odotn_4) * DielectricMultipleScatteringLobe_TabulatedFactors_0(this_98, odotn_4, false);
    if((odotn_4 > 0.0f))
    {
        return LobeSample_Make_0(wi_32, DiffuseSpecular_Specular_0(this_98.reflectionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * this_98.reflectionRatio_0, u32(9));
    }
    return LobeSample_Make_0(wi_32, DiffuseSpecular_Specular_0(this_98.transmissionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * (1.0f - this_98.reflectionRatio_0), u32(10));
}

fn MetalMultipleScatteringLobe_LobeType_0( this_99 : MetalMultipleScatteringLobe_0) -> u32
{
    return u32(9);
}

fn MetalMultipleScatteringLobe_Sample_0( this_100 : MetalMultipleScatteringLobe_0,  u_20 : vec3<f32>,  wo_51 : vec3<f32>) -> LobeSample_0
{
    if(!MetalMultipleScatteringLobe_Active_0(this_100))
    {
        return LobeSample_Invalid_0();
    }
    var wi_33 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_100.normal_3), u_20.x, u_20.y);
    var odotn_5 : f32 = dot(wi_33, this_100.normal_3);
    return LobeSample_Make_0(wi_33, DiffuseSpecular_Specular_0(this_100.scale_0 * vec3<f32>((2.0f * odotn_5 * MetalMultipleScatteringLobe_TabulatedFactors_0(this_100, odotn_5)))), 0.5f / float_getPi_0(), MetalMultipleScatteringLobe_LobeType_0(this_100));
}

fn DiffuseLobe_LobeType_0( this_101 : DiffuseLobe_0) -> u32
{
    return u32(5);
}

fn DiffuseLobe_Sample_0( this_102 : DiffuseLobe_0,  u_21 : vec3<f32>,  wo_52 : vec3<f32>) -> LobeSample_0
{
    var wiLocal_6 : vec3<f32> = SampleCosineHemisphere_0(u_21.xy);
    var cosOut_1 : f32 = wiLocal_6.z;
    if(cosOut_1 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var basis_4 : Frame_0 = BasisFromNormal_0(this_102.normal_4);
    var PI_5 : f32 = float_getPi_0();
    return LobeSample_Make_0(Frame_ToWorld_0(basis_4, wiLocal_6), DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_102, Frame_ToLocal_0(basis_4, wo_52), wiLocal_6) * vec3<f32>(PI_5)), cosOut_1 * (1.0f / PI_5), DiffuseLobe_LobeType_0(this_102));
}

fn MicrofacetReflectionLobe_LobeType_1( this_103 : MicrofacetReflectionLobe_0) -> u32
{
    return u32(9);
}

fn MicrofacetReflectionLobe_Sample_1( this_104 : MicrofacetReflectionLobe_0,  u_22 : vec3<f32>,  wo_53 : vec3<f32>) -> LobeSample_0
{
    var idotn_12 : f32 = dot(wo_53, this_104.normal_5);
    var h_14 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_104.distribution_1, wo_53, u_22.xy);
    var idoth_16 : f32 = dot(wo_53, h_14);
    if((idoth_16 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_34 : vec3<f32> = normalize((vec3<f32>(0) - wo_53) + h_14 * vec3<f32>(2.0f) * vec3<f32>(idoth_16));
    if(((idotn_12 * dot(this_104.normal_5, wi_34)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_6 : f32 = dot(wi_34, h_14);
    var f_15 : vec3<f32> = ConstantReflection_Reflection_0(this_104.coefficient_1, idoth_16);
    var gShadowing_1 : f32 = GGXDistribution_G1_0(this_104.distribution_1, wi_34);
    var d_10 : f32 = GGXDistribution_D_0(this_104.distribution_1, h_14);
    if((d_10 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_34, DiffuseSpecular_Specular_0(f_15 * vec3<f32>(gShadowing_1)), d_10 * GGXDistribution_G1_0(this_104.distribution_1, wo_53) * idoth_16 / (4.0f * odoth_6 * idotn_12), MicrofacetReflectionLobe_LobeType_1(this_104));
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

fn FlippedLobe_Sample_0( this_105 : FlippedLobe_0,  u_23 : vec3<f32>,  wo_54 : vec3<f32>) -> LobeSample_0
{
    var s_17 : LobeSample_0 = MicrofacetReflectionLobe_Sample_1(this_105.lobe_0, u_23, reflect(wo_54, MicrofacetReflectionLobe_GetNormal_0(this_105.lobe_0)));
    s_17.type_0 = SwapReflectionTransmission_0(s_17.type_0);
    return s_17;
}

fn FlippedLobe_Sample_1( this_106 : FlippedLobe_1,  u_24 : vec3<f32>,  wo_55 : vec3<f32>) -> LobeSample_0
{
    var s_18 : LobeSample_0 = DiffuseLobe_Sample_0(this_106.lobe_0, u_24, reflect(wo_55, DiffuseLobe_GetNormal_0(this_106.lobe_0)));
    s_18.type_0 = SwapReflectionTransmission_0(s_18.type_0);
    return s_18;
}

fn BaseLobe_LobeSampleAt_0( this_107 : BaseLobe_0,  index_15 : i32,  u_25 : vec3<f32>,  wo_56 : vec3<f32>) -> LobeSample_0
{
    switch(index_15)
    {
    case i32(0):
        {
            return SpecularLobe_Sample_0(this_107.specular_0, u_25, wo_56);
        }
    case i32(1):
        {
            return DielectricMultipleScatteringLobe_Sample_0(this_107.dielectricMultipleScattering_0, u_25, wo_56);
        }
    case i32(2):
        {
            return MetalMultipleScatteringLobe_Sample_0(this_107.metalMultipleScattering_0, u_25, wo_56);
        }
    case i32(3):
        {
            return DiffuseLobe_Sample_0(this_107.diffuse_0, u_25, wo_56);
        }
    case i32(4):
        {
            return FlippedLobe_Sample_0(this_107.thinWallSpecularTransmission_0, u_25, wo_56);
        }
    default :
        {
            return FlippedLobe_Sample_1(this_107.thinWallDiffuseTransmission_0, u_25, wo_56);
        }
    }
}

fn BaseLobe_SampleLobe_0( this_108 : BaseLobe_0,  u_26 : vec3<f32>,  wo_57 : vec3<f32>,  wi_35 : ptr<function, vec3<f32>>,  type_3 : ptr<function, u32>,  sampled_3 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_35) = vec3<f32>(0.0f);
    (*type_3) = u32(0);
    (*sampled_3) = SampledLobe_None_0();
    var ux_1 : f32 = u_26.x;
    var selectedWeight_1 : f32;
    var totalWeight_3 : f32;
    var selected_0 : i32 = BaseLobe_SelectLobe_0(this_108, &(ux_1), &(selectedWeight_1), &(totalWeight_3));
    if((selected_0 < i32(0)))
    {
        return false;
    }
    var s_19 : LobeSample_0 = BaseLobe_LobeSampleAt_0(this_108, selected_0, vec3<f32>(ux_1, u_26.y, u_26.z), wo_57);
    (*wi_35) = s_19.wi_26;
    (*type_3) = s_19.type_0;
    (*sampled_3) = SampledLobe_Make_0(i32(1), selected_0, s_19);
    return s_19.valid_1;
}

fn CoatLobe_SampleLobe_0( this_109 : CoatLobe_0,  u_27 : vec3<f32>,  wo_58 : vec3<f32>,  wi_36 : ptr<function, vec3<f32>>,  type_4 : ptr<function, u32>,  sampled_4 : ptr<function, SampledLobe_0>) -> bool
{
    var _S425 : bool = !this_109.inside_0;
    var _S426 : bool;
    if(_S425)
    {
        _S426 = CoatLobe_HasCoat_0(this_109);
    }
    else
    {
        _S426 = false;
    }
    var coatProbability_0 : f32;
    if(_S426)
    {
        coatProbability_0 = CoatLobe_ReflectionProbability_0(this_109, wo_58);
    }
    else
    {
        coatProbability_0 = 0.0f;
    }
    var ux_2 : f32 = u_27.x;
    if(_S425)
    {
        _S426 = (ux_2 < coatProbability_0);
    }
    else
    {
        _S426 = false;
    }
    if(_S426)
    {
        var s_20 : LobeSample_0 = MicrofacetReflectionLobe_Sample_0(this_109.reflection_0, vec3<f32>(ClampRemappedRandom_0(ux_2 * (1.0f / coatProbability_0)), u_27.y, u_27.z), wo_58);
        (*wi_36) = s_20.wi_26;
        (*type_4) = s_20.type_0;
        (*sampled_4) = SampledLobe_Make_0(i32(2), i32(0), s_20);
        return s_20.valid_1;
    }
    var ux_3 : f32;
    if(_S425)
    {
        ux_3 = ClampRemappedRandom_0((ux_2 - coatProbability_0) * (1.0f / (1.0f - coatProbability_0)));
    }
    else
    {
        ux_3 = ux_2;
    }
    var _S427 : bool = BaseLobe_SampleLobe_0(this_109.base_2, vec3<f32>(ux_3, u_27.y, u_27.z), wo_58, &((*wi_36)), &((*type_4)), &((*sampled_4)));
    return _S427;
}

fn FuzzLobe_SampleLobe_0( this_110 : FuzzLobe_0,  u_28 : vec3<f32>,  wo_59 : vec3<f32>,  wi_37 : ptr<function, vec3<f32>>,  type_5 : ptr<function, u32>,  sampled_5 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_37) = vec3<f32>(0.0f);
    (*type_5) = u32(9);
    (*sampled_5) = SampledLobe_None_0();
    var sheenProbability_0 : f32;
    if(FuzzLobe_HasFuzz_0(this_110))
    {
        sheenProbability_0 = FuzzLobe_SheenProbability_0(this_110, wo_59);
    }
    else
    {
        sheenProbability_0 = 0.0f;
    }
    var _S428 : f32 = u_28.x;
    if((_S428 < sheenProbability_0))
    {
        var _S429 : f32 = this_110.woLocal_0.z;
        if((_S429 <= 0.0f))
        {
            return false;
        }
        var wiLocal_7 : vec3<f32> = SheenRotate_0(SheenSampleLTC_0(FuzzLobe_Coefficients_0(this_110, this_110.woLocal_0), u_28.yz), this_110.woLocal_0.xy);
        if(((_S429 * wiLocal_7.z) <= 0.0f))
        {
            return false;
        }
        (*wi_37) = normalize(Frame_ToWorld_0(this_110.basis_0, wiLocal_7));
        return true;
    }
    var _S430 : bool = CoatLobe_SampleLobe_0(this_110.base_3, vec3<f32>(ClampRemappedRandom_0((_S428 - sheenProbability_0) * (1.0f / (1.0f - sheenProbability_0))), u_28.y, u_28.z), wo_59, &((*wi_37)), &((*type_5)), &((*sampled_5)));
    return _S430;
}

fn BaseLobe_LobeEvalPdf_1( this_111 : BaseLobe_0,  index_16 : i32,  wo_60 : vec3<f32>,  wi_38 : vec3<f32>,  f_16 : ptr<function, DiffuseSpecular_0>,  pdf_10 : ptr<function, f32>)
{
    switch(index_16)
    {
    case i32(0):
        {
            (*f_16) = SpecularLobe_Eval_0(this_111.specular_0, wo_60, wi_38);
            (*pdf_10) = SpecularLobe_Pdf_0(this_111.specular_0, wo_60, wi_38);
        }
    case i32(1):
        {
            (*f_16) = DielectricMultipleScatteringLobe_Eval_0(this_111.dielectricMultipleScattering_0, wo_60, wi_38);
            (*pdf_10) = DielectricMultipleScatteringLobe_Pdf_0(this_111.dielectricMultipleScattering_0, wo_60, wi_38);
        }
    case i32(2):
        {
            (*f_16) = MetalMultipleScatteringLobe_Eval_0(this_111.metalMultipleScattering_0, wo_60, wi_38);
            (*pdf_10) = MetalMultipleScatteringLobe_Pdf_0(this_111.metalMultipleScattering_0, wo_60, wi_38);
        }
    case i32(3):
        {
            (*f_16) = DiffuseLobe_Eval_0(this_111.diffuse_0, wo_60, wi_38);
            (*pdf_10) = DiffuseLobe_Pdf_0(this_111.diffuse_0, wo_60, wi_38);
        }
    case i32(4):
        {
            (*f_16) = FlippedLobe_Eval_0(this_111.thinWallSpecularTransmission_0, wo_60, wi_38);
            (*pdf_10) = FlippedLobe_Pdf_0(this_111.thinWallSpecularTransmission_0, wo_60, wi_38);
        }
    default :
        {
            (*f_16) = FlippedLobe_Eval_1(this_111.thinWallDiffuseTransmission_0, wo_60, wi_38);
            (*pdf_10) = FlippedLobe_Pdf_1(this_111.thinWallDiffuseTransmission_0, wo_60, wi_38);
        }
    }
    return;
}

fn BaseLobe_EvalPdf_1( this_112 : BaseLobe_0,  wo_61 : vec3<f32>,  wi_39 : vec3<f32>,  sampled_6 : SampledLobe_0,  f_17 : ptr<function, DiffuseSpecular_0>,  pdf_11 : ptr<function, f32>)
{
    (*f_17) = DiffuseSpecular_Zero_0();
    var i_7 : i32 = i32(0);
    var sum_4 : f32 = 0.0f;
    var totalWeight_4 : f32 = 0.0f;
    loop
    {
        if((i_7 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_112, i_7))
        {
            var lobeF_1 : DiffuseSpecular_0 = sampled_6.f_1;
            var lobePdf_1 : f32 = sampled_6.pdf_0;
            var _S431 : bool;
            if((sampled_6.layer_0) != i32(1))
            {
                _S431 = true;
            }
            else
            {
                _S431 = (sampled_6.lobe_1) != i_7;
            }
            if(_S431)
            {
                BaseLobe_LobeEvalPdf_1(this_112, i_7, wo_61, wi_39, &(lobeF_1), &(lobePdf_1));
            }
            (*f_17) = x2B_0((*f_17), lobeF_1);
            var totalWeight_5 : f32 = totalWeight_4 + this_112.weights_0[i_7];
            sum_4 = sum_4 + this_112.weights_0[i_7] * lobePdf_1;
            totalWeight_4 = totalWeight_5;
        }
        i_7 = i_7 + i32(1);
    }
    if((totalWeight_4 > 0.0f))
    {
        sum_4 = sum_4 / totalWeight_4;
    }
    else
    {
        sum_4 = 0.0f;
    }
    (*pdf_11) = sum_4;
    return;
}

fn CoatLobe_EvalPdf_1( this_113 : CoatLobe_0,  wo_62 : vec3<f32>,  wi_40 : vec3<f32>,  sampled_7 : SampledLobe_0,  f_18 : ptr<function, DiffuseSpecular_0>,  pdf_12 : ptr<function, f32>)
{
    var baseF_2 : DiffuseSpecular_0;
    var basePdf_2 : f32;
    BaseLobe_EvalPdf_1(this_113.base_2, wo_62, wi_40, sampled_7, &(baseF_2), &(basePdf_2));
    if(this_113.inside_0)
    {
        (*f_18) = x2A_0(baseF_2, CoatLobe_PassageColor_0(this_113, - dot(wi_40, this_113.normal_6)));
        (*pdf_12) = basePdf_2;
        return;
    }
    var coatSampled_1 : bool = (sampled_7.layer_0) == i32(2);
    var _S432 : DiffuseSpecular_0;
    if(coatSampled_1)
    {
        _S432 = sampled_7.f_1;
    }
    else
    {
        _S432 = CoatLobe_CoatEval_0(this_113, wo_62, wi_40);
    }
    (*f_18) = CoatLobe_Combine_0(this_113, _S432, baseF_2, wi_40);
    var _S433 : f32;
    if(CoatLobe_HasCoat_0(this_113))
    {
        var _S434 : f32 = basePdf_2;
        if(coatSampled_1)
        {
            _S433 = sampled_7.pdf_0;
        }
        else
        {
            _S433 = MicrofacetReflectionLobe_Pdf_1(this_113.reflection_0, wo_62, wi_40);
        }
        _S433 = mix(_S434, _S433, CoatLobe_ReflectionProbability_0(this_113, wo_62));
    }
    else
    {
        _S433 = basePdf_2;
    }
    (*pdf_12) = _S433;
    return;
}

fn FuzzLobe_EvalPdf_1( this_114 : FuzzLobe_0,  wo_63 : vec3<f32>,  wi_41 : vec3<f32>,  sampled_8 : SampledLobe_0,  f_19 : ptr<function, DiffuseSpecular_0>,  pdf_13 : ptr<function, f32>)
{
    var baseF_3 : DiffuseSpecular_0;
    var basePdf_3 : f32;
    CoatLobe_EvalPdf_1(this_114.base_3, wo_63, wi_41, sampled_8, &(baseF_3), &(basePdf_3));
    var wiLocal_8 : vec3<f32> = Frame_ToLocal_0(this_114.basis_0, wi_41);
    (*f_19) = x2B_0(x2A_1(baseF_3, FuzzLobe_BaseLayerScaleComplete_0(this_114, wiLocal_8)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_114, wiLocal_8)));
    var _S435 : f32;
    if(FuzzLobe_HasFuzz_0(this_114))
    {
        _S435 = mix(basePdf_3, FuzzLobe_SheenPdf_0(this_114, wiLocal_8), FuzzLobe_SheenProbability_0(this_114, wo_63));
    }
    else
    {
        _S435 = basePdf_3;
    }
    (*pdf_13) = _S435;
    return;
}

fn SampleLayer_0( layer_2 : FuzzLobe_0,  u_29 : vec3<f32>,  wo_64 : vec3<f32>) -> LobeSample_0
{
    var wi_42 : vec3<f32>;
    var type_6 : u32;
    var sampled_9 : SampledLobe_0;
    var _S436 : bool = FuzzLobe_SampleLobe_0(layer_2, u_29, wo_64, &(wi_42), &(type_6), &(sampled_9));
    if(!_S436)
    {
        return LobeSample_Invalid_0();
    }
    var f_20 : DiffuseSpecular_0;
    var pdf_14 : f32;
    FuzzLobe_EvalPdf_1(layer_2, wo_64, wi_42, sampled_9, &(f_20), &(pdf_14));
    if(!(pdf_14 > 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_42, x2A_1(f_20, 1.0f / pdf_14), pdf_14, type_6);
}

fn FuzzLobe_Sample_0( this_115 : FuzzLobe_0,  u_30 : vec3<f32>,  wo_65 : vec3<f32>) -> LobeSample_0
{
    return SampleLayer_0(this_115, u_30, wo_65);
}

fn BSDF_Sample_0( this_116 : BSDF_0,  u_31 : vec3<f32>) -> LobeSample_0
{
    return FuzzLobe_Sample_0(this_116.lobes_0, u_31, this_116.wo_0);
}

fn SurfaceInteraction_ComputeRayOrigin_0( this_117 : SurfaceInteraction_0,  viewSide_0 : bool) -> vec3<f32>
{
    var n_17 : vec3<f32>;
    if((this_117.frontFacing_0) == viewSide_0)
    {
        n_17 = this_117.faceNormal_0;
    }
    else
    {
        n_17 = (vec3<f32>(0) - this_117.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(this_117.position_0, n_17);
}

fn ScatterConeSpread_0( lobe_6 : u32,  roughness_8 : f32) -> f32
{
    if(((lobe_6 & (u32(4)))) != u32(0))
    {
        return 0.5f;
    }
    return 0.5f * roughness_8 * roughness_8;
}

fn ShadePath_0( base_9 : u32,  s_21 : ptr<function, WavefrontPath_0>,  hit_3 : HitRecord_0,  bounce_1 : u32)
{
    var _S437 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_21).path_0.absorption_0) > _S437)))))
    {
        (*s_21).path_0.throughput_7 = (*s_21).path_0.throughput_7 * exp((*s_21).path_0.absorption_0 * vec3<f32>(- hit_3.t_6));
    }
    var hitConeWidth_0 : f32 = (*s_21).path_0.coneWidth_2 + (*s_21).path_0.coneSpread_0 * hit_3.t_6;
    var si_4 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_21).path_0.direction_1, hit_3, hitConeWidth_0);
    var V_2 : vec3<f32> = (vec3<f32>(0) - (*s_21).path_0.direction_1);
    var ms_1 : MaterialSample_0 = EvalMaterial_0(si_4, V_2);
    var bsdf_1 : BSDF_0 = BSDF_x24init_0(ms_1.inputs_1, V_2, (*s_21).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S438 : bool = bounce_1 == u32(0);
    var throughput_22 : vec3<f32>;
    if(_S438)
    {
        (*s_21).albedo_2 = ms_1.albedo_3;
        if(si_4.frontFacing_0)
        {
            throughput_22 = ms_1.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_22 = (vec3<f32>(0) - ms_1.inputs_1.basis_1.n_1);
        }
        (*s_21).normal_11 = throughput_22;
    }
    (*s_21).active_0 = u32(0);
    var _S439 : bool;
    if(!si_4.frontFacing_0)
    {
        _S439 = !ms_1.doubleSided_2;
    }
    else
    {
        _S439 = false;
    }
    if(_S439)
    {
        _S439 = ((ms_1.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S439 = false;
    }
    if(_S439)
    {
        return;
    }
    if((any((((bsdf_1.emission_0) > _S437)))))
    {
        var _S440 : bool = !_S438;
        if(_S440)
        {
            _S439 = (*s_21).path_0.lightsSampled_0;
        }
        else
        {
            _S439 = false;
        }
        var mis_1 : f32;
        if(_S439)
        {
            mis_1 = EvalMISRobust_0((*s_21).path_0.scatterPdf_0, EmissiveHitPdf_0(si_4.instanceIndex_0, si_4.primitiveIndex_0, (*s_21).path_0.origin_3, si_4.position_0));
        }
        else
        {
            mis_1 = 1.0f;
        }
        var contribution_0 : vec3<f32> = (*s_21).path_0.throughput_7 * vec3<f32>(mis_1) * bsdf_1.emission_0;
        var clampValue_0 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_0 > 0.0f))
        {
            _S439 = _S440;
        }
        else
        {
            _S439 = false;
        }
        if(_S439)
        {
            throughput_22 = min(contribution_0, vec3<f32>(clampValue_0));
        }
        else
        {
            throughput_22 = contribution_0;
        }
        (*s_21).path_0.radiance_1 = (*s_21).path_0.radiance_1 + throughput_22;
    }
    if(bounce_1 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_5 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_5.seed_0 = (*s_21).randomSeed_0;
    var _S441 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_1)) >= 0.0010000000474974513f);
    (*s_21).path_0.lightsSampled_0 = _S441;
    if(_S441)
    {
        var _S442 : vec3<f32> = NextEventEstimation_0(si_4, bsdf_1, vec2<f32>(hitConeWidth_0, (*s_21).path_0.coneSpread_0), &(rng_5));
        var direct_0 : vec3<f32> = (*s_21).path_0.throughput_7 * _S442;
        var clampValue_1 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_1 > 0.0f))
        {
            _S439 = !_S438;
        }
        else
        {
            _S439 = false;
        }
        if(_S439)
        {
            throughput_22 = min(direct_0, vec3<f32>(clampValue_1));
        }
        else
        {
            throughput_22 = direct_0;
        }
        (*s_21).path_0.radiance_1 = (*s_21).path_0.radiance_1 + throughput_22;
    }
    var u_32 : vec2<f32> = RandomSequence_Next2D_0(&(rng_5));
    var _S443 : f32 = RandomSequence_Next_1(&(rng_5));
    var bs_0 : LobeSample_0 = BSDF_Sample_0(bsdf_1, vec3<f32>(u_32, _S443));
    var weight_4 : vec3<f32> = bs_0.weight_1.diffuse_1 + bs_0.weight_1.specular_1;
    if(!bs_0.valid_1)
    {
        _S439 = true;
    }
    else
    {
        _S439 = ((bs_0.pdf_7) <= 0.0f);
    }
    if(_S439)
    {
        _S439 = true;
    }
    else
    {
        _S439 = (all(((weight_4 <= _S437))));
    }
    if(_S439)
    {
        return;
    }
    var throughput_23 : vec3<f32> = (*s_21).path_0.throughput_7 * weight_4;
    var continuation_0 : f32 = sqrt(saturate(MaxComponent_0(throughput_23) / max(MaxComponent_0((*s_21).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_0 < 1.0f))
    {
        var _S444 : f32 = RandomSequence_Next_1(&(rng_5));
        if((_S444 >= continuation_0))
        {
            return;
        }
        throughput_22 = throughput_23 / vec3<f32>(continuation_0);
    }
    else
    {
        throughput_22 = throughput_23;
    }
    (*s_21).path_0.throughput_7 = throughput_22;
    (*s_21).path_0.direction_1 = bs_0.wi_26;
    (*s_21).path_0.scatterPdf_0 = bs_0.pdf_7;
    var crossesSurface_0 : bool = ((dot(bs_0.wi_26, si_4.faceNormal_0)) > 0.0f) != (si_4.frontFacing_0);
    (*s_21).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_4, !crossesSurface_0);
    if(crossesSurface_0)
    {
        _S439 = !ms_1.thinWalled_0;
    }
    else
    {
        _S439 = false;
    }
    if(_S439)
    {
        if(si_4.frontFacing_0)
        {
            throughput_22 = HomogeneousVolume_Absorption_0(bsdf_1.volume_0);
        }
        else
        {
            throughput_22 = vec3<f32>(0.0f);
        }
        (*s_21).path_0.absorption_0 = throughput_22;
    }
    (*s_21).path_0.coneWidth_2 = hitConeWidth_0;
    (*s_21).path_0.coneSpread_0 = (*s_21).path_0.coneSpread_0 + ScatterConeSpread_0(bs_0.type_0, ms_1.roughness_4);
    (*s_21).randomSeed_0 = rng_5.seed_0;
    (*s_21).active_0 = u32(1);
    return;
}

fn VertexUV0_1( v_17 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_17).positionU_0.w, (*v_17).normalV_0.w);
}

fn AlphaTestRejects_0( _S445 : u32,  _S446 : u32,  _S447 : vec2<f32>,  _S448 : f32) -> bool
{
    var material_2 : MaterialHeader_0 = LoadMaterialHeader_0(gInstances_0[_S445].materialIndex_0);
    var _S449 : u32 = MaterialHeader_AlphaMode_0(material_2);
    if(_S449 == u32(0))
    {
        return false;
    }
    var _S450 : vec3<u32> = LoadTriangleIndices_0(_S445, _S446);
    var _S451 : Vertex_std430_0 = gVertices_0[_S450.x];
    var _S452 : Vertex_std430_0 = gVertices_0[_S450.y];
    var _S453 : Vertex_std430_0 = gVertices_0[_S450.z];
    var _S454 : f32 = _S447.x;
    var _S455 : f32 = _S447.y;
    var _S456 : f32 = 1.0f - _S454 - _S455;
    var _S457 : vec2<f32> = VertexUV0_1(&(_S451));
    var _S458 : vec2<f32> = VertexUV0_1(&(_S452));
    var _S459 : vec2<f32> = VertexUV0_1(&(_S453));
    var _S460 : vec2<f32> = vec2<f32>(_S456);
    var _S461 : vec2<f32> = vec2<f32>(_S454);
    var _S462 : vec2<f32> = vec2<f32>(_S455);
    var _S463 : vec2<f32> = _S451.uv1_0.xy;
    var _S464 : vec2<f32> = _S452.uv1_0.xy;
    var _S465 : vec2<f32> = _S453.uv1_0.xy;
    var _S466 : vec3<f32> = _S452.positionU_0.xyz;
    var _S467 : vec3<f32> = _S451.positionU_0.xyz;
    var _S468 : vec3<f32> = _S453.positionU_0.xyz;
    var tc_8 : TextureCoords_0 = MakeTextureCoords_0(_S457 * _S460 + _S458 * _S461 + _S459 * _S462, _S463 * _S460 + _S464 * _S461 + _S465 * _S462, TransformVector_0(_S445, _S466 - _S467), TransformVector_0(_S445, _S468 - _S467), _S458 - _S457, _S459 - _S457, _S464 - _S463, _S465 - _S463, gRayCone_0.x + gRayCone_0.y * _S448, 1.0f);
    tc_8.objectPosition_0 = _S467 * vec3<f32>(_S456) + _S466 * vec3<f32>(_S454) + _S468 * vec3<f32>(_S455);
    var opacity_1 : f32 = EvalOpacity_0(material_2, tc_8);
    if(_S449 == u32(1))
    {
        return (opacity_1 < (material_2.alphaCutoff_0));
    }
    return (opacity_1 < (f32(((StrongIntegerHash_0((_S446 ^ ((StrongIntegerHash_0(((bitcast<u32>((_S448))) ^ ((gFrame_0.frame_0.w))))))))) & (u32(16777215)))) * 5.9604644775390625e-08f));
}

fn TraverseBLAS_1( _S469 : u32,  _S470 : u32,  _S471 : vec3<f32>,  _S472 : vec3<f32>,  _S473 : f32,  _S474 : bool,  _S475 : ptr<function, HitRecord_0>) -> bool
{
    var found_4 : bool;
    var _S476 : vec3<f32> = SafeRcp_0(_S472);
    var _S477 : bool = (((gInstances_0[_S470].flags_0) & (u32(1)))) != u32(0);
    var stack_4 : array<u32, i32(48)>;
    var nodeRef_2 : u32 = u32(0);
    var found_5 : bool = false;
    var stackPtr_8 : u32 = u32(0);
    loop
    {
        var i_8 : u32;
        if(((nodeRef_2 & (u32(2147483648)))) != u32(0))
        {
            var _S478 : u32 = (((nodeRef_2 >> (u32(24)))) & (u32(127)));
            var _S479 : u32 = (nodeRef_2 & (u32(16777215)));
            found_4 = found_5;
            i_8 = u32(0);
            loop
            {
                if((i_8 < _S478))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_10 : u32 = (gInstances_0[_S470].blasTriOffset_0 + _S479 + i_8) * u32(3);
                var v0_2 : vec4<f32> = gTris_0[base_10];
                var t_12 : f32;
                var bary_3 : vec2<f32>;
                var _S480 : bool = IntersectTriangle_0(_S471, _S472, v0_2.xyz, gTris_0[base_10 + u32(1)].xyz, gTris_0[base_10 + u32(2)].xyz, _S473, (*_S475).t_6, &(t_12), &(bary_3));
                if(!_S480)
                {
                    i_8 = i_8 + u32(1);
                    continue;
                }
                var primitiveIndex_3 : u32 = (bitcast<u32>((v0_2.w)));
                var _S481 : bool;
                if(_S477)
                {
                    var _S482 : bool = AlphaTestRejects_0(_S470, primitiveIndex_3, bary_3, t_12);
                    _S481 = _S482;
                }
                else
                {
                    _S481 = false;
                }
                if(_S481)
                {
                    i_8 = i_8 + u32(1);
                    continue;
                }
                (*_S475).t_6 = t_12;
                (*_S475).barycentrics_0 = bary_3;
                (*_S475).instanceIndex_2 = _S469;
                (*_S475).primitiveIndex_1 = primitiveIndex_3;
                if(_S474)
                {
                    return true;
                }
                found_4 = true;
                i_8 = i_8 + u32(1);
            }
            if(stackPtr_8 == u32(0))
            {
                break;
            }
            var stackPtr_9 : u32 = stackPtr_8 - u32(1);
            nodeRef_2 = stack_4[stackPtr_9];
            found_5 = found_4;
            stackPtr_8 = stackPtr_9;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_2 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S470].blasNodeOffset_0 + nodeRef_2];
        var dist1_4 : f32 = IntersectBox_0(node_2.lmin_0, node_2.lmax_0, _S471, _S476, _S473, (*_S475).t_6);
        var dist2_4 : f32 = IntersectBox_0(node_2.rmin_0, node_2.rmax_0, _S471, _S476, _S473, (*_S475).t_6);
        var far_2 : u32;
        var dist1_5 : f32;
        var dist2_5 : f32;
        if((dist1_4 > dist2_4))
        {
            dist1_5 = dist2_4;
            i_8 = node_2.right_0;
            dist2_5 = dist1_4;
            far_2 = node_2.left_0;
        }
        else
        {
            dist1_5 = dist1_4;
            i_8 = node_2.left_0;
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
            nodeRef_2 = stack_4[stackPtr_10];
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
                var _S483 : u32 = stackPtr_8 + u32(1);
                stack_4[stackPtr_8] = far_2;
                stackPtr_11 = _S483;
            }
            else
            {
                stackPtr_11 = stackPtr_8;
            }
            nodeRef_2 = i_8;
            stackPtr_8 = stackPtr_11;
        }
    }
    return found_4;
}

fn TraceScene_1( ray_2 : Ray_0,  anyHit_1 : bool,  hit_4 : ptr<function, HitRecord_0>) -> bool
{
    var found_6 : bool;
    (*hit_4).t_6 = ray_2.tMax_0;
    (*hit_4).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_4).instanceIndex_2 = u32(4294967295);
    (*hit_4).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S484 : u32 = gFrame_0.counts_0.z;
    var _S485 : vec3<f32> = SafeRcp_0(ray_2.direction_0);
    var stack_5 : array<u32, i32(32)>;
    var nodeRef_3 : u32 = u32(0);
    var found_7 : bool = false;
    var stackPtr_12 : u32 = u32(0);
    loop
    {
        var i_9 : u32;
        if(((nodeRef_3 & (u32(2147483648)))) != u32(0))
        {
            var _S486 : u32 = (((nodeRef_3 >> (u32(24)))) & (u32(127)));
            var _S487 : u32 = (nodeRef_3 & (u32(16777215)));
            found_6 = found_7;
            i_9 = u32(0);
            loop
            {
                if((i_9 < _S486))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_4 : u32 = gIndices_0[_S484 + _S487 + i_9];
                var _S488 : bool = TraverseBLAS_1(instanceIndex_4, instanceIndex_4, InverseTransformPoint_0(instanceIndex_4, ray_2.origin_0), InverseTransformVector_0(instanceIndex_4, ray_2.direction_0), ray_2.tMin_0, anyHit_1, &((*hit_4)));
                if(_S488)
                {
                    if(anyHit_1)
                    {
                        return true;
                    }
                    found_6 = true;
                }
                i_9 = i_9 + u32(1);
            }
            if(stackPtr_12 == u32(0))
            {
                break;
            }
            var stackPtr_13 : u32 = stackPtr_12 - u32(1);
            nodeRef_3 = stack_5[stackPtr_13];
            found_7 = found_6;
            stackPtr_12 = stackPtr_13;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_3 : BVHNode_std430_0 = gNodes_0[nodeRef_3];
        var dist1_6 : f32 = IntersectBox_0(node_3.lmin_0, node_3.lmax_0, ray_2.origin_0, _S485, ray_2.tMin_0, (*hit_4).t_6);
        var dist2_6 : f32 = IntersectBox_0(node_3.rmin_0, node_3.rmax_0, ray_2.origin_0, _S485, ray_2.tMin_0, (*hit_4).t_6);
        var far_3 : u32;
        var dist1_7 : f32;
        var dist2_7 : f32;
        if((dist1_6 > dist2_6))
        {
            dist1_7 = dist2_6;
            i_9 = node_3.right_0;
            dist2_7 = dist1_6;
            far_3 = node_3.left_0;
        }
        else
        {
            dist1_7 = dist1_6;
            i_9 = node_3.left_0;
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
            nodeRef_3 = stack_5[stackPtr_14];
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
                var _S489 : u32 = stackPtr_12 + u32(1);
                stack_5[stackPtr_12] = far_3;
                stackPtr_15 = _S489;
            }
            else
            {
                stackPtr_15 = stackPtr_12;
            }
            nodeRef_3 = i_9;
            stackPtr_12 = stackPtr_15;
        }
    }
    return found_6;
}

fn TraceOcclusion_1( ray_3 : Ray_0) -> bool
{
    var hit_5 : HitRecord_0;
    var _S490 : bool = TraceScene_1(ray_3, true, &(hit_5));
    return _S490;
}

fn NextEventEstimation_1( si_5 : SurfaceInteraction_0,  bsdf_2 : BSDF_0,  cone_2 : vec2<f32>,  rng_6 : ptr<function, RandomSequence_0>) -> vec3<f32>
{
    var _S491 : vec3<f32> = vec3<f32>(0.0f);
    gRayCone_0 = cone_2;
    var source_1 : u32 = u32(0);
    var result_7 : vec3<f32> = _S491;
    loop
    {
        if((source_1 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var origin_4 : vec3<f32>;
        var dir_12 : vec3<f32>;
        var shadow_2 : bool;
        var mis_2 : bool;
        var maxDistance_2 : f32;
        var ls_4 : LightSample_0;
        if(source_1 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                source_1 = source_1 + u32(1);
                continue;
            }
            var ls_5 : LightSample_0 = SampleEnvironment_0(&((*rng_6)));
            if((any((((ls_5.radiance_0) > vec3<f32>(0.0f))))))
            {
                shadow_2 = ((ls_5.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                shadow_2 = false;
            }
            if(!shadow_2)
            {
                source_1 = source_1 + u32(1);
                continue;
            }
            var dir_13 : vec3<f32> = (vec3<f32>(0) - ls_5.normal_7);
            var _S492 : vec3<f32> = ShadowOrigin_0(si_5, dir_13);
            shadow_2 = true;
            origin_4 = _S492;
            maxDistance_2 = 1.00000001504746622e+30f;
            mis_2 = true;
            ls_4 = ls_5;
            dir_12 = dir_13;
        }
        else
        {
            if(source_1 == u32(1))
            {
                if((LightCount_0()) == u32(0))
                {
                    source_1 = source_1 + u32(1);
                    continue;
                }
                var ls_6 : LightSample_0 = SampleEmissive_0(si_5.position_0, cone_2, &((*rng_6)));
                if((any((((ls_6.radiance_0) > vec3<f32>(0.0f))))))
                {
                    shadow_2 = ((ls_6.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    shadow_2 = false;
                }
                if(!shadow_2)
                {
                    source_1 = source_1 + u32(1);
                    continue;
                }
                var lightPos_2 : vec3<f32> = ComputeOffsetOrigin_0(ls_6.position_1, ls_6.normal_7);
                var origin_5 : vec3<f32> = ShadowOrigin_0(si_5, lightPos_2 - si_5.position_0);
                var dir_14 : vec3<f32> = lightPos_2 - origin_5;
                var maxDistance_3 : f32 = length(dir_14);
                var dir_15 : vec3<f32> = dir_14 / vec3<f32>(maxDistance_3);
                var _S493 : bool = !ls_6.delta_0;
                shadow_2 = ls_6.shadow_0;
                origin_4 = origin_5;
                maxDistance_2 = maxDistance_3;
                mis_2 = _S493;
                ls_4 = ls_6;
                dir_12 = dir_15;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    source_1 = source_1 + u32(1);
                    continue;
                }
                var ls_7 : LightSample_0 = SampleSun_0(&((*rng_6)));
                var dir_16 : vec3<f32> = (vec3<f32>(0) - ls_7.normal_7);
                var _S494 : vec3<f32> = ShadowOrigin_0(si_5, dir_16);
                shadow_2 = true;
                origin_4 = _S494;
                maxDistance_2 = 1.00000001504746622e+30f;
                mis_2 = false;
                ls_4 = ls_7;
                dir_12 = dir_16;
            }
        }
        var eval_1 : DiffuseSpecular_0;
        var bsdfPdf_1 : f32;
        BSDF_EvalPdf_0(bsdf_2, dir_12, &(eval_1), &(bsdfPdf_1));
        var f_21 : vec3<f32> = eval_1.diffuse_1 + eval_1.specular_1;
        var _S495 : bool;
        if((any(((f_21 > vec3<f32>(0.0f))))))
        {
            if(!shadow_2)
            {
                _S495 = true;
            }
            else
            {
                var _S496 : bool = TraceOcclusion_1(Ray_x24init_0(origin_4, dir_12, maxDistance_2));
                _S495 = !_S496;
            }
        }
        else
        {
            _S495 = false;
        }
        var result_8 : vec3<f32>;
        if(_S495)
        {
            var weight_5 : f32;
            if(mis_2)
            {
                weight_5 = EvalMISRobust_0(ls_4.solidAnglePdf_0, bsdfPdf_1);
            }
            else
            {
                weight_5 = 1.0f;
            }
            result_8 = result_7 + vec3<f32>(weight_5) * ls_4.radiance_0 * f_21 / vec3<f32>(ls_4.solidAnglePdf_0);
        }
        else
        {
            result_8 = result_7;
        }
        result_7 = result_8;
        source_1 = source_1 + u32(1);
    }
    return result_7;
}

fn ShadePath_1( base_11 : u32,  s_22 : ptr<function, WavefrontPath_0>,  hit_6 : HitRecord_0,  bounce_2 : u32)
{
    var _S497 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_22).path_0.absorption_0) > _S497)))))
    {
        (*s_22).path_0.throughput_7 = (*s_22).path_0.throughput_7 * exp((*s_22).path_0.absorption_0 * vec3<f32>(- hit_6.t_6));
    }
    var hitConeWidth_1 : f32 = (*s_22).path_0.coneWidth_2 + (*s_22).path_0.coneSpread_0 * hit_6.t_6;
    var si_6 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_22).path_0.direction_1, hit_6, hitConeWidth_1);
    var V_3 : vec3<f32> = (vec3<f32>(0) - (*s_22).path_0.direction_1);
    var ms_2 : MaterialSample_0 = EvalMaterial_0(si_6, V_3);
    var bsdf_3 : BSDF_0 = BSDF_x24init_0(ms_2.inputs_1, V_3, (*s_22).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S498 : bool = bounce_2 == u32(0);
    var throughput_24 : vec3<f32>;
    if(_S498)
    {
        (*s_22).albedo_2 = ms_2.albedo_3;
        if(si_6.frontFacing_0)
        {
            throughput_24 = ms_2.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_24 = (vec3<f32>(0) - ms_2.inputs_1.basis_1.n_1);
        }
        (*s_22).normal_11 = throughput_24;
    }
    (*s_22).active_0 = u32(0);
    var _S499 : bool;
    if(!si_6.frontFacing_0)
    {
        _S499 = !ms_2.doubleSided_2;
    }
    else
    {
        _S499 = false;
    }
    if(_S499)
    {
        _S499 = ((ms_2.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S499 = false;
    }
    if(_S499)
    {
        return;
    }
    if((any((((bsdf_3.emission_0) > _S497)))))
    {
        var _S500 : bool = !_S498;
        if(_S500)
        {
            _S499 = (*s_22).path_0.lightsSampled_0;
        }
        else
        {
            _S499 = false;
        }
        var mis_3 : f32;
        if(_S499)
        {
            mis_3 = EvalMISRobust_0((*s_22).path_0.scatterPdf_0, EmissiveHitPdf_0(si_6.instanceIndex_0, si_6.primitiveIndex_0, (*s_22).path_0.origin_3, si_6.position_0));
        }
        else
        {
            mis_3 = 1.0f;
        }
        var contribution_1 : vec3<f32> = (*s_22).path_0.throughput_7 * vec3<f32>(mis_3) * bsdf_3.emission_0;
        var clampValue_2 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_2 > 0.0f))
        {
            _S499 = _S500;
        }
        else
        {
            _S499 = false;
        }
        if(_S499)
        {
            throughput_24 = min(contribution_1, vec3<f32>(clampValue_2));
        }
        else
        {
            throughput_24 = contribution_1;
        }
        (*s_22).path_0.radiance_1 = (*s_22).path_0.radiance_1 + throughput_24;
    }
    if(bounce_2 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_7 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_7.seed_0 = (*s_22).randomSeed_0;
    var _S501 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_3)) >= 0.0010000000474974513f);
    (*s_22).path_0.lightsSampled_0 = _S501;
    if(_S501)
    {
        var _S502 : vec3<f32> = NextEventEstimation_1(si_6, bsdf_3, vec2<f32>(hitConeWidth_1, (*s_22).path_0.coneSpread_0), &(rng_7));
        var direct_1 : vec3<f32> = (*s_22).path_0.throughput_7 * _S502;
        var clampValue_3 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_3 > 0.0f))
        {
            _S499 = !_S498;
        }
        else
        {
            _S499 = false;
        }
        if(_S499)
        {
            throughput_24 = min(direct_1, vec3<f32>(clampValue_3));
        }
        else
        {
            throughput_24 = direct_1;
        }
        (*s_22).path_0.radiance_1 = (*s_22).path_0.radiance_1 + throughput_24;
    }
    var u_33 : vec2<f32> = RandomSequence_Next2D_0(&(rng_7));
    var _S503 : f32 = RandomSequence_Next_1(&(rng_7));
    var bs_1 : LobeSample_0 = BSDF_Sample_0(bsdf_3, vec3<f32>(u_33, _S503));
    var weight_6 : vec3<f32> = bs_1.weight_1.diffuse_1 + bs_1.weight_1.specular_1;
    if(!bs_1.valid_1)
    {
        _S499 = true;
    }
    else
    {
        _S499 = ((bs_1.pdf_7) <= 0.0f);
    }
    if(_S499)
    {
        _S499 = true;
    }
    else
    {
        _S499 = (all(((weight_6 <= _S497))));
    }
    if(_S499)
    {
        return;
    }
    var throughput_25 : vec3<f32> = (*s_22).path_0.throughput_7 * weight_6;
    var continuation_1 : f32 = sqrt(saturate(MaxComponent_0(throughput_25) / max(MaxComponent_0((*s_22).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_1 < 1.0f))
    {
        var _S504 : f32 = RandomSequence_Next_1(&(rng_7));
        if((_S504 >= continuation_1))
        {
            return;
        }
        throughput_24 = throughput_25 / vec3<f32>(continuation_1);
    }
    else
    {
        throughput_24 = throughput_25;
    }
    (*s_22).path_0.throughput_7 = throughput_24;
    (*s_22).path_0.direction_1 = bs_1.wi_26;
    (*s_22).path_0.scatterPdf_0 = bs_1.pdf_7;
    var crossesSurface_1 : bool = ((dot(bs_1.wi_26, si_6.faceNormal_0)) > 0.0f) != (si_6.frontFacing_0);
    (*s_22).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_6, !crossesSurface_1);
    if(crossesSurface_1)
    {
        _S499 = !ms_2.thinWalled_0;
    }
    else
    {
        _S499 = false;
    }
    if(_S499)
    {
        if(si_6.frontFacing_0)
        {
            throughput_24 = HomogeneousVolume_Absorption_0(bsdf_3.volume_0);
        }
        else
        {
            throughput_24 = vec3<f32>(0.0f);
        }
        (*s_22).path_0.absorption_0 = throughput_24;
    }
    (*s_22).path_0.coneWidth_2 = hitConeWidth_1;
    (*s_22).path_0.coneSpread_0 = (*s_22).path_0.coneSpread_0 + ScatterConeSpread_0(bs_1.type_0, ms_2.roughness_4);
    (*s_22).randomSeed_0 = rng_7.seed_0;
    (*s_22).active_0 = u32(1);
    return;
}

fn LoadPath_0( base_12 : u32) -> WavefrontPath_0
{
    var s_23 : WavefrontPath_0;
    s_23.path_0.radiance_1 = gAccum_0[base_12].xyz;
    s_23.active_0 = (bitcast<u32>((gAccum_0[base_12].w)));
    s_23.path_0.throughput_7 = gAccum_0[Field_0(base_12, u32(1))].xyz;
    s_23.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_12, u32(1))].w)));
    s_23.path_0.origin_3 = gAccum_0[Field_0(base_12, u32(2))].xyz;
    s_23.path_0.scatterPdf_0 = gAccum_0[Field_0(base_12, u32(2))].w;
    s_23.path_0.direction_1 = gAccum_0[Field_0(base_12, u32(3))].xyz;
    s_23.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_12, u32(3))].w))) != u32(0);
    s_23.path_0.absorption_0 = gAccum_0[Field_0(base_12, u32(4))].xyz;
    s_23.path_0.coneWidth_2 = gAccum_0[Field_0(base_12, u32(4))].w;
    var _S505 : vec3<f32> = vec3<f32>(0.0f);
    s_23.albedo_2 = _S505;
    s_23.path_0.coneSpread_0 = gAccum_0[Field_0(base_12, u32(5))].w;
    s_23.normal_11 = _S505;
    s_23.path_0.lobe_2 = u32(0);
    return s_23;
}

fn QueueDirectLighting_0( base_13 : u32,  si_7 : SurfaceInteraction_0,  bsdf_4 : BSDF_0,  cone_3 : vec2<f32>,  throughput_26 : vec3<f32>,  primary_0 : bool,  rng_8 : ptr<function, RandomSequence_0>)
{
    var maxDistance_4 : f32;
    gRayCone_0 = cone_3;
    var source_2 : u32 = u32(0);
    var mask_0 : u32 = u32(0);
    loop
    {
        if((source_2 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var mis_4 : bool;
        var shadow_3 : bool;
        var ls_8 : LightSample_0;
        var origin_6 : vec3<f32>;
        var dir_17 : vec3<f32>;
        if(source_2 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                source_2 = source_2 + u32(1);
                continue;
            }
            var ls_9 : LightSample_0 = SampleEnvironment_0(&((*rng_8)));
            if((any((((ls_9.radiance_0) > vec3<f32>(0.0f))))))
            {
                mis_4 = ((ls_9.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                mis_4 = false;
            }
            if(!mis_4)
            {
                source_2 = source_2 + u32(1);
                continue;
            }
            var dir_18 : vec3<f32> = (vec3<f32>(0) - ls_9.normal_7);
            var _S506 : vec3<f32> = ShadowOrigin_0(si_7, dir_18);
            mis_4 = true;
            ls_8 = ls_9;
            origin_6 = _S506;
            maxDistance_4 = 1.00000001504746622e+30f;
            shadow_3 = true;
            dir_17 = dir_18;
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
                var _S507 : LightSample_0 = SampleEmissive_0(si_7.position_0, cone_3, &((*rng_8)));
                if((any((((_S507.radiance_0) > vec3<f32>(0.0f))))))
                {
                    mis_4 = ((_S507.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    mis_4 = false;
                }
                if(!mis_4)
                {
                    source_2 = source_2 + u32(1);
                    continue;
                }
                var lightPos_3 : vec3<f32> = ComputeOffsetOrigin_0(_S507.position_1, _S507.normal_7);
                var origin_7 : vec3<f32> = ShadowOrigin_0(si_7, lightPos_3 - si_7.position_0);
                var dir_19 : vec3<f32> = lightPos_3 - origin_7;
                var maxDistance_5 : f32 = length(dir_19);
                var dir_20 : vec3<f32> = dir_19 / vec3<f32>(maxDistance_5);
                mis_4 = !_S507.delta_0;
                ls_8 = _S507;
                origin_6 = origin_7;
                maxDistance_4 = maxDistance_5;
                shadow_3 = _S507.shadow_0;
                dir_17 = dir_20;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    source_2 = source_2 + u32(1);
                    continue;
                }
                var ls_10 : LightSample_0 = SampleSun_0(&((*rng_8)));
                var dir_21 : vec3<f32> = (vec3<f32>(0) - ls_10.normal_7);
                var _S508 : vec3<f32> = ShadowOrigin_0(si_7, dir_21);
                mis_4 = false;
                ls_8 = ls_10;
                origin_6 = _S508;
                maxDistance_4 = 1.00000001504746622e+30f;
                shadow_3 = true;
                dir_17 = dir_21;
            }
        }
        var eval_2 : DiffuseSpecular_0;
        var pdf_15 : f32;
        BSDF_EvalPdf_0(bsdf_4, dir_17, &(eval_2), &(pdf_15));
        var f_22 : vec3<f32> = eval_2.diffuse_1 + eval_2.specular_1;
        var mask_1 : u32;
        if((any(((f_22 > vec3<f32>(0.0f))))))
        {
            var weight_7 : f32;
            if(mis_4)
            {
                weight_7 = EvalMISRobust_0(ls_8.solidAnglePdf_0, pdf_15);
            }
            else
            {
                weight_7 = 1.0f;
            }
            var offset_1 : u32 = u32(12) + source_2 * u32(3);
            gAccum_0[Field_0(base_13, offset_1)] = vec4<f32>(origin_6, maxDistance_4);
            gAccum_0[Field_0(base_13, offset_1 + u32(1))] = vec4<f32>(dir_17, (bitcast<f32>((select(u32(0), u32(1), shadow_3)))));
            gAccum_0[Field_0(base_13, offset_1 + u32(2))] = vec4<f32>(vec3<f32>(weight_7) * ls_8.radiance_0 * f_22 / vec3<f32>(ls_8.solidAnglePdf_0), 0.0f);
            mask_1 = (mask_0 | (((u32(1) << (source_2)))));
        }
        else
        {
            mask_1 = mask_0;
        }
        mask_0 = mask_1;
        source_2 = source_2 + u32(1);
    }
    if(primary_0)
    {
        maxDistance_4 = 0.0f;
    }
    else
    {
        maxDistance_4 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    gAccum_0[Field_0(base_13, u32(10))] = vec4<f32>(throughput_26, maxDistance_4);
    gAccum_0[Field_0(base_13, u32(11))] = vec4<f32>(cone_3, (bitcast<f32>((mask_0))), 0.0f);
    return;
}

fn ShadePath_2( base_14 : u32,  s_24 : ptr<function, WavefrontPath_0>,  hit_7 : HitRecord_0,  bounce_3 : u32)
{
    var hitConeWidth_2 : f32 = (*s_24).path_0.coneWidth_2 + (*s_24).path_0.coneSpread_0 * hit_7.t_6;
    var si_8 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_24).path_0.direction_1, hit_7, hitConeWidth_2);
    var V_4 : vec3<f32> = (vec3<f32>(0) - (*s_24).path_0.direction_1);
    var ms_3 : MaterialSample_0 = EvalMaterial_0(si_8, V_4);
    (*s_24) = LoadPath_0(base_14);
    var _S509 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_24).path_0.absorption_0) > _S509)))))
    {
        (*s_24).path_0.throughput_7 = (*s_24).path_0.throughput_7 * exp((*s_24).path_0.absorption_0 * vec3<f32>(- hit_7.t_6));
    }
    var bsdf_5 : BSDF_0 = BSDF_x24init_0(ms_3.inputs_1, V_4, (*s_24).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_24).active_0 = u32(0);
    var _S510 : bool;
    if(!si_8.frontFacing_0)
    {
        _S510 = !ms_3.doubleSided_2;
    }
    else
    {
        _S510 = false;
    }
    if(_S510)
    {
        _S510 = ((ms_3.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S510 = false;
    }
    if(_S510)
    {
        return;
    }
    var throughput_27 : vec3<f32>;
    if((any((((bsdf_5.emission_0) > _S509)))))
    {
        var mis_5 : f32;
        if((*s_24).path_0.lightsSampled_0)
        {
            mis_5 = EvalMISRobust_0((*s_24).path_0.scatterPdf_0, EmissiveHitPdf_0(si_8.instanceIndex_0, si_8.primitiveIndex_0, (*s_24).path_0.origin_3, si_8.position_0));
        }
        else
        {
            mis_5 = 1.0f;
        }
        var contribution_2 : vec3<f32> = (*s_24).path_0.throughput_7 * vec3<f32>(mis_5) * bsdf_5.emission_0;
        var clampValue_4 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        var _S511 : bool = (clampValue_4 > 0.0f);
        if(_S511)
        {
            throughput_27 = min(contribution_2, vec3<f32>(clampValue_4));
        }
        else
        {
            throughput_27 = contribution_2;
        }
        (*s_24).path_0.radiance_1 = (*s_24).path_0.radiance_1 + throughput_27;
    }
    if(bounce_3 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_9 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_9.seed_0 = (*s_24).randomSeed_0;
    var _S512 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_5)) >= 0.0010000000474974513f);
    (*s_24).path_0.lightsSampled_0 = _S512;
    if(_S512)
    {
        QueueDirectLighting_0(base_14, si_8, bsdf_5, vec2<f32>(hitConeWidth_2, (*s_24).path_0.coneSpread_0), (*s_24).path_0.throughput_7, false, &(rng_9));
    }
    var u_34 : vec2<f32> = RandomSequence_Next2D_0(&(rng_9));
    var _S513 : f32 = RandomSequence_Next_1(&(rng_9));
    var bs_2 : LobeSample_0 = BSDF_Sample_0(bsdf_5, vec3<f32>(u_34, _S513));
    var weight_8 : vec3<f32> = bs_2.weight_1.diffuse_1 + bs_2.weight_1.specular_1;
    if(!bs_2.valid_1)
    {
        _S510 = true;
    }
    else
    {
        _S510 = ((bs_2.pdf_7) <= 0.0f);
    }
    if(_S510)
    {
        _S510 = true;
    }
    else
    {
        _S510 = (all(((weight_8 <= _S509))));
    }
    if(_S510)
    {
        return;
    }
    var throughput_28 : vec3<f32> = (*s_24).path_0.throughput_7 * weight_8;
    var continuation_2 : f32 = sqrt(saturate(MaxComponent_0(throughput_28) / max(MaxComponent_0((*s_24).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_2 < 1.0f))
    {
        var _S514 : f32 = RandomSequence_Next_1(&(rng_9));
        if((_S514 >= continuation_2))
        {
            return;
        }
        throughput_27 = throughput_28 / vec3<f32>(continuation_2);
    }
    else
    {
        throughput_27 = throughput_28;
    }
    (*s_24).path_0.throughput_7 = throughput_27;
    (*s_24).path_0.direction_1 = bs_2.wi_26;
    (*s_24).path_0.scatterPdf_0 = bs_2.pdf_7;
    var crossesSurface_2 : bool = ((dot(bs_2.wi_26, si_8.faceNormal_0)) > 0.0f) != (si_8.frontFacing_0);
    (*s_24).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_8, !crossesSurface_2);
    if(crossesSurface_2)
    {
        _S510 = !ms_3.thinWalled_0;
    }
    else
    {
        _S510 = false;
    }
    if(_S510)
    {
        if(si_8.frontFacing_0)
        {
            throughput_27 = HomogeneousVolume_Absorption_0(bsdf_5.volume_0);
        }
        else
        {
            throughput_27 = vec3<f32>(0.0f);
        }
        (*s_24).path_0.absorption_0 = throughput_27;
    }
    (*s_24).path_0.coneWidth_2 = hitConeWidth_2;
    (*s_24).path_0.coneSpread_0 = (*s_24).path_0.coneSpread_0 + ScatterConeSpread_0(bs_2.type_0, ms_3.roughness_4);
    (*s_24).randomSeed_0 = rng_9.seed_0;
    (*s_24).active_0 = u32(1);
    return;
}

fn LoadPath_1( base_15 : u32) -> WavefrontPath_0
{
    var s_25 : WavefrontPath_0;
    s_25.path_0.radiance_1 = gAccum_0[base_15].xyz;
    s_25.active_0 = (bitcast<u32>((gAccum_0[base_15].w)));
    s_25.path_0.throughput_7 = gAccum_0[Field_0(base_15, u32(1))].xyz;
    s_25.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_15, u32(1))].w)));
    s_25.path_0.origin_3 = gAccum_0[Field_0(base_15, u32(2))].xyz;
    s_25.path_0.scatterPdf_0 = gAccum_0[Field_0(base_15, u32(2))].w;
    s_25.path_0.direction_1 = gAccum_0[Field_0(base_15, u32(3))].xyz;
    s_25.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_15, u32(3))].w))) != u32(0);
    s_25.path_0.absorption_0 = gAccum_0[Field_0(base_15, u32(4))].xyz;
    s_25.path_0.coneWidth_2 = gAccum_0[Field_0(base_15, u32(4))].w;
    s_25.albedo_2 = gAccum_0[Field_0(base_15, u32(5))].xyz;
    s_25.path_0.coneSpread_0 = gAccum_0[Field_0(base_15, u32(5))].w;
    s_25.normal_11 = gAccum_0[Field_0(base_15, u32(6))].xyz;
    s_25.path_0.lobe_2 = u32(0);
    return s_25;
}

fn ShadePath_3( base_16 : u32,  s_26 : ptr<function, WavefrontPath_0>,  hit_8 : HitRecord_0,  bounce_4 : u32)
{
    var hitConeWidth_3 : f32 = (*s_26).path_0.coneWidth_2 + (*s_26).path_0.coneSpread_0 * hit_8.t_6;
    var si_9 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_26).path_0.direction_1, hit_8, hitConeWidth_3);
    var V_5 : vec3<f32> = (vec3<f32>(0) - (*s_26).path_0.direction_1);
    var ms_4 : MaterialSample_0 = EvalMaterial_0(si_9, V_5);
    (*s_26) = LoadPath_1(base_16);
    var _S515 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_26).path_0.absorption_0) > _S515)))))
    {
        (*s_26).path_0.throughput_7 = (*s_26).path_0.throughput_7 * exp((*s_26).path_0.absorption_0 * vec3<f32>(- hit_8.t_6));
    }
    var bsdf_6 : BSDF_0 = BSDF_x24init_0(ms_4.inputs_1, V_5, (*s_26).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_26).albedo_2 = ms_4.albedo_3;
    var throughput_29 : vec3<f32>;
    if(si_9.frontFacing_0)
    {
        throughput_29 = ms_4.inputs_1.basis_1.n_1;
    }
    else
    {
        throughput_29 = (vec3<f32>(0) - ms_4.inputs_1.basis_1.n_1);
    }
    (*s_26).normal_11 = throughput_29;
    (*s_26).active_0 = u32(0);
    var _S516 : bool;
    if(!si_9.frontFacing_0)
    {
        _S516 = !ms_4.doubleSided_2;
    }
    else
    {
        _S516 = false;
    }
    if(_S516)
    {
        _S516 = ((ms_4.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S516 = false;
    }
    if(_S516)
    {
        return;
    }
    if((any((((bsdf_6.emission_0) > _S515)))))
    {
        (*s_26).path_0.radiance_1 = (*s_26).path_0.radiance_1 + (*s_26).path_0.throughput_7 * bsdf_6.emission_0;
    }
    if(bounce_4 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_10 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_10.seed_0 = (*s_26).randomSeed_0;
    var _S517 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_6)) >= 0.0010000000474974513f);
    (*s_26).path_0.lightsSampled_0 = _S517;
    if(_S517)
    {
        QueueDirectLighting_0(base_16, si_9, bsdf_6, vec2<f32>(hitConeWidth_3, (*s_26).path_0.coneSpread_0), (*s_26).path_0.throughput_7, true, &(rng_10));
    }
    var u_35 : vec2<f32> = RandomSequence_Next2D_0(&(rng_10));
    var _S518 : f32 = RandomSequence_Next_1(&(rng_10));
    var bs_3 : LobeSample_0 = BSDF_Sample_0(bsdf_6, vec3<f32>(u_35, _S518));
    var weight_9 : vec3<f32> = bs_3.weight_1.diffuse_1 + bs_3.weight_1.specular_1;
    if(!bs_3.valid_1)
    {
        _S516 = true;
    }
    else
    {
        _S516 = ((bs_3.pdf_7) <= 0.0f);
    }
    if(_S516)
    {
        _S516 = true;
    }
    else
    {
        _S516 = (all(((weight_9 <= _S515))));
    }
    if(_S516)
    {
        return;
    }
    var throughput_30 : vec3<f32> = (*s_26).path_0.throughput_7 * weight_9;
    var continuation_3 : f32 = sqrt(saturate(MaxComponent_0(throughput_30) / max(MaxComponent_0((*s_26).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_3 < 1.0f))
    {
        var _S519 : f32 = RandomSequence_Next_1(&(rng_10));
        if((_S519 >= continuation_3))
        {
            return;
        }
        throughput_29 = throughput_30 / vec3<f32>(continuation_3);
    }
    else
    {
        throughput_29 = throughput_30;
    }
    (*s_26).path_0.throughput_7 = throughput_29;
    (*s_26).path_0.direction_1 = bs_3.wi_26;
    (*s_26).path_0.scatterPdf_0 = bs_3.pdf_7;
    var crossesSurface_3 : bool = ((dot(bs_3.wi_26, si_9.faceNormal_0)) > 0.0f) != (si_9.frontFacing_0);
    (*s_26).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_9, !crossesSurface_3);
    if(crossesSurface_3)
    {
        _S516 = !ms_4.thinWalled_0;
    }
    else
    {
        _S516 = false;
    }
    if(_S516)
    {
        if(si_9.frontFacing_0)
        {
            throughput_29 = HomogeneousVolume_Absorption_0(bsdf_6.volume_0);
        }
        else
        {
            throughput_29 = vec3<f32>(0.0f);
        }
        (*s_26).path_0.absorption_0 = throughput_29;
    }
    (*s_26).path_0.coneWidth_2 = hitConeWidth_3;
    (*s_26).path_0.coneSpread_0 = (*s_26).path_0.coneSpread_0 + ScatterConeSpread_0(bs_3.type_0, ms_4.roughness_4);
    (*s_26).randomSeed_0 = rng_10.seed_0;
    (*s_26).active_0 = u32(1);
    return;
}

fn ShadePath_4( base_17 : u32,  s_27 : ptr<function, WavefrontPath_0>,  hit_9 : HitRecord_0,  bounce_5 : u32)
{
    var hitConeWidth_4 : f32 = (*s_27).path_0.coneWidth_2 + (*s_27).path_0.coneSpread_0 * hit_9.t_6;
    var si_10 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_27).path_0.direction_1, hit_9, hitConeWidth_4);
    var V_6 : vec3<f32> = (vec3<f32>(0) - (*s_27).path_0.direction_1);
    var ms_5 : MaterialSample_0 = EvalMaterial_0(si_10, V_6);
    (*s_27) = LoadPath_1(base_17);
    var _S520 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_27).path_0.absorption_0) > _S520)))))
    {
        (*s_27).path_0.throughput_7 = (*s_27).path_0.throughput_7 * exp((*s_27).path_0.absorption_0 * vec3<f32>(- hit_9.t_6));
    }
    var bsdf_7 : BSDF_0 = BSDF_x24init_0(ms_5.inputs_1, V_6, (*s_27).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S521 : bool = bounce_5 == u32(0);
    var throughput_31 : vec3<f32>;
    if(_S521)
    {
        (*s_27).albedo_2 = ms_5.albedo_3;
        if(si_10.frontFacing_0)
        {
            throughput_31 = ms_5.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_31 = (vec3<f32>(0) - ms_5.inputs_1.basis_1.n_1);
        }
        (*s_27).normal_11 = throughput_31;
    }
    (*s_27).active_0 = u32(0);
    var _S522 : bool;
    if(!si_10.frontFacing_0)
    {
        _S522 = !ms_5.doubleSided_2;
    }
    else
    {
        _S522 = false;
    }
    if(_S522)
    {
        _S522 = ((ms_5.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S522 = false;
    }
    if(_S522)
    {
        return;
    }
    if((any((((bsdf_7.emission_0) > _S520)))))
    {
        var _S523 : bool = !_S521;
        if(_S523)
        {
            _S522 = (*s_27).path_0.lightsSampled_0;
        }
        else
        {
            _S522 = false;
        }
        var mis_6 : f32;
        if(_S522)
        {
            mis_6 = EvalMISRobust_0((*s_27).path_0.scatterPdf_0, EmissiveHitPdf_0(si_10.instanceIndex_0, si_10.primitiveIndex_0, (*s_27).path_0.origin_3, si_10.position_0));
        }
        else
        {
            mis_6 = 1.0f;
        }
        var contribution_3 : vec3<f32> = (*s_27).path_0.throughput_7 * vec3<f32>(mis_6) * bsdf_7.emission_0;
        var clampValue_5 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_5 > 0.0f))
        {
            _S522 = _S523;
        }
        else
        {
            _S522 = false;
        }
        if(_S522)
        {
            throughput_31 = min(contribution_3, vec3<f32>(clampValue_5));
        }
        else
        {
            throughput_31 = contribution_3;
        }
        (*s_27).path_0.radiance_1 = (*s_27).path_0.radiance_1 + throughput_31;
    }
    if(bounce_5 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_11 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_11.seed_0 = (*s_27).randomSeed_0;
    var _S524 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_7)) >= 0.0010000000474974513f);
    (*s_27).path_0.lightsSampled_0 = _S524;
    if(_S524)
    {
        QueueDirectLighting_0(base_17, si_10, bsdf_7, vec2<f32>(hitConeWidth_4, (*s_27).path_0.coneSpread_0), (*s_27).path_0.throughput_7, _S521, &(rng_11));
    }
    var u_36 : vec2<f32> = RandomSequence_Next2D_0(&(rng_11));
    var _S525 : f32 = RandomSequence_Next_1(&(rng_11));
    var bs_4 : LobeSample_0 = BSDF_Sample_0(bsdf_7, vec3<f32>(u_36, _S525));
    var weight_10 : vec3<f32> = bs_4.weight_1.diffuse_1 + bs_4.weight_1.specular_1;
    if(!bs_4.valid_1)
    {
        _S522 = true;
    }
    else
    {
        _S522 = ((bs_4.pdf_7) <= 0.0f);
    }
    if(_S522)
    {
        _S522 = true;
    }
    else
    {
        _S522 = (all(((weight_10 <= _S520))));
    }
    if(_S522)
    {
        return;
    }
    var throughput_32 : vec3<f32> = (*s_27).path_0.throughput_7 * weight_10;
    var continuation_4 : f32 = sqrt(saturate(MaxComponent_0(throughput_32) / max(MaxComponent_0((*s_27).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_4 < 1.0f))
    {
        var _S526 : f32 = RandomSequence_Next_1(&(rng_11));
        if((_S526 >= continuation_4))
        {
            return;
        }
        throughput_31 = throughput_32 / vec3<f32>(continuation_4);
    }
    else
    {
        throughput_31 = throughput_32;
    }
    (*s_27).path_0.throughput_7 = throughput_31;
    (*s_27).path_0.direction_1 = bs_4.wi_26;
    (*s_27).path_0.scatterPdf_0 = bs_4.pdf_7;
    var crossesSurface_4 : bool = ((dot(bs_4.wi_26, si_10.faceNormal_0)) > 0.0f) != (si_10.frontFacing_0);
    (*s_27).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_10, !crossesSurface_4);
    if(crossesSurface_4)
    {
        _S522 = !ms_5.thinWalled_0;
    }
    else
    {
        _S522 = false;
    }
    if(_S522)
    {
        if(si_10.frontFacing_0)
        {
            throughput_31 = HomogeneousVolume_Absorption_0(bsdf_7.volume_0);
        }
        else
        {
            throughput_31 = vec3<f32>(0.0f);
        }
        (*s_27).path_0.absorption_0 = throughput_31;
    }
    (*s_27).path_0.coneWidth_2 = hitConeWidth_4;
    (*s_27).path_0.coneSpread_0 = (*s_27).path_0.coneSpread_0 + ScatterConeSpread_0(bs_4.type_0, ms_5.roughness_4);
    (*s_27).randomSeed_0 = rng_11.seed_0;
    (*s_27).active_0 = u32(1);
    return;
}

fn ShadePath_5( base_18 : u32,  s_28 : ptr<function, WavefrontPath_0>,  hit_10 : HitRecord_0,  bounce_6 : u32)
{
    var _S527 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_28).path_0.absorption_0) > _S527)))))
    {
        (*s_28).path_0.throughput_7 = (*s_28).path_0.throughput_7 * exp((*s_28).path_0.absorption_0 * vec3<f32>(- hit_10.t_6));
    }
    var hitConeWidth_5 : f32 = (*s_28).path_0.coneWidth_2 + (*s_28).path_0.coneSpread_0 * hit_10.t_6;
    var si_11 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_28).path_0.direction_1, hit_10, hitConeWidth_5);
    var V_7 : vec3<f32> = (vec3<f32>(0) - (*s_28).path_0.direction_1);
    var ms_6 : MaterialSample_0 = EvalMaterial_0(si_11, V_7);
    var bsdf_8 : BSDF_0 = BSDF_x24init_0(ms_6.inputs_1, V_7, (*s_28).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_28).active_0 = u32(0);
    var _S528 : bool;
    if(!si_11.frontFacing_0)
    {
        _S528 = !ms_6.doubleSided_2;
    }
    else
    {
        _S528 = false;
    }
    if(_S528)
    {
        _S528 = ((ms_6.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S528 = false;
    }
    if(_S528)
    {
        return;
    }
    var throughput_33 : vec3<f32>;
    if((any((((bsdf_8.emission_0) > _S527)))))
    {
        var mis_7 : f32;
        if((*s_28).path_0.lightsSampled_0)
        {
            mis_7 = EvalMISRobust_0((*s_28).path_0.scatterPdf_0, EmissiveHitPdf_0(si_11.instanceIndex_0, si_11.primitiveIndex_0, (*s_28).path_0.origin_3, si_11.position_0));
        }
        else
        {
            mis_7 = 1.0f;
        }
        var contribution_4 : vec3<f32> = (*s_28).path_0.throughput_7 * vec3<f32>(mis_7) * bsdf_8.emission_0;
        var clampValue_6 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        var _S529 : bool = (clampValue_6 > 0.0f);
        if(_S529)
        {
            throughput_33 = min(contribution_4, vec3<f32>(clampValue_6));
        }
        else
        {
            throughput_33 = contribution_4;
        }
        (*s_28).path_0.radiance_1 = (*s_28).path_0.radiance_1 + throughput_33;
    }
    if(bounce_6 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_12 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_12.seed_0 = (*s_28).randomSeed_0;
    var _S530 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_8)) >= 0.0010000000474974513f);
    (*s_28).path_0.lightsSampled_0 = _S530;
    if(_S530)
    {
        QueueDirectLighting_0(base_18, si_11, bsdf_8, vec2<f32>(hitConeWidth_5, (*s_28).path_0.coneSpread_0), (*s_28).path_0.throughput_7, false, &(rng_12));
    }
    var u_37 : vec2<f32> = RandomSequence_Next2D_0(&(rng_12));
    var _S531 : f32 = RandomSequence_Next_1(&(rng_12));
    var bs_5 : LobeSample_0 = BSDF_Sample_0(bsdf_8, vec3<f32>(u_37, _S531));
    var weight_11 : vec3<f32> = bs_5.weight_1.diffuse_1 + bs_5.weight_1.specular_1;
    if(!bs_5.valid_1)
    {
        _S528 = true;
    }
    else
    {
        _S528 = ((bs_5.pdf_7) <= 0.0f);
    }
    if(_S528)
    {
        _S528 = true;
    }
    else
    {
        _S528 = (all(((weight_11 <= _S527))));
    }
    if(_S528)
    {
        return;
    }
    var throughput_34 : vec3<f32> = (*s_28).path_0.throughput_7 * weight_11;
    var continuation_5 : f32 = sqrt(saturate(MaxComponent_0(throughput_34) / max(MaxComponent_0((*s_28).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_5 < 1.0f))
    {
        var _S532 : f32 = RandomSequence_Next_1(&(rng_12));
        if((_S532 >= continuation_5))
        {
            return;
        }
        throughput_33 = throughput_34 / vec3<f32>(continuation_5);
    }
    else
    {
        throughput_33 = throughput_34;
    }
    (*s_28).path_0.throughput_7 = throughput_33;
    (*s_28).path_0.direction_1 = bs_5.wi_26;
    (*s_28).path_0.scatterPdf_0 = bs_5.pdf_7;
    var crossesSurface_5 : bool = ((dot(bs_5.wi_26, si_11.faceNormal_0)) > 0.0f) != (si_11.frontFacing_0);
    (*s_28).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_11, !crossesSurface_5);
    if(crossesSurface_5)
    {
        _S528 = !ms_6.thinWalled_0;
    }
    else
    {
        _S528 = false;
    }
    if(_S528)
    {
        if(si_11.frontFacing_0)
        {
            throughput_33 = HomogeneousVolume_Absorption_0(bsdf_8.volume_0);
        }
        else
        {
            throughput_33 = vec3<f32>(0.0f);
        }
        (*s_28).path_0.absorption_0 = throughput_33;
    }
    (*s_28).path_0.coneWidth_2 = hitConeWidth_5;
    (*s_28).path_0.coneSpread_0 = (*s_28).path_0.coneSpread_0 + ScatterConeSpread_0(bs_5.type_0, ms_6.roughness_4);
    (*s_28).randomSeed_0 = rng_12.seed_0;
    (*s_28).active_0 = u32(1);
    return;
}

fn StorePath_0( base_19 : u32,  s_29 : WavefrontPath_0)
{
    gAccum_0[base_19] = vec4<f32>(s_29.path_0.radiance_1, (bitcast<f32>((s_29.active_0))));
    gAccum_0[Field_0(base_19, u32(1))] = vec4<f32>(s_29.path_0.throughput_7, (bitcast<f32>((s_29.randomSeed_0))));
    gAccum_0[Field_0(base_19, u32(2))] = vec4<f32>(s_29.path_0.origin_3, s_29.path_0.scatterPdf_0);
    gAccum_0[Field_0(base_19, u32(3))] = vec4<f32>(s_29.path_0.direction_1, (bitcast<f32>((select(u32(0), u32(1), s_29.path_0.lightsSampled_0)))));
    gAccum_0[Field_0(base_19, u32(4))] = vec4<f32>(s_29.path_0.absorption_0, s_29.path_0.coneWidth_2);
    gAccum_0[Field_0(base_19, u32(5))][i32(3)] = s_29.path_0.coneSpread_0;
    return;
}

fn ShadePath_6( base_20 : u32,  s_30 : ptr<function, WavefrontPath_0>,  hit_11 : HitRecord_0,  bounce_7 : u32)
{
    var _S533 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_30).path_0.absorption_0) > _S533)))))
    {
        (*s_30).path_0.throughput_7 = (*s_30).path_0.throughput_7 * exp((*s_30).path_0.absorption_0 * vec3<f32>(- hit_11.t_6));
    }
    var hitConeWidth_6 : f32 = (*s_30).path_0.coneWidth_2 + (*s_30).path_0.coneSpread_0 * hit_11.t_6;
    var si_12 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_30).path_0.direction_1, hit_11, hitConeWidth_6);
    var V_8 : vec3<f32> = (vec3<f32>(0) - (*s_30).path_0.direction_1);
    var ms_7 : MaterialSample_0 = EvalMaterial_0(si_12, V_8);
    var bsdf_9 : BSDF_0 = BSDF_x24init_0(ms_7.inputs_1, V_8, (*s_30).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_30).albedo_2 = ms_7.albedo_3;
    var throughput_35 : vec3<f32>;
    if(si_12.frontFacing_0)
    {
        throughput_35 = ms_7.inputs_1.basis_1.n_1;
    }
    else
    {
        throughput_35 = (vec3<f32>(0) - ms_7.inputs_1.basis_1.n_1);
    }
    (*s_30).normal_11 = throughput_35;
    (*s_30).active_0 = u32(0);
    var _S534 : bool;
    if(!si_12.frontFacing_0)
    {
        _S534 = !ms_7.doubleSided_2;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        _S534 = ((ms_7.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        return;
    }
    if((any((((bsdf_9.emission_0) > _S533)))))
    {
        (*s_30).path_0.radiance_1 = (*s_30).path_0.radiance_1 + (*s_30).path_0.throughput_7 * bsdf_9.emission_0;
    }
    if(bounce_7 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_13 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_13.seed_0 = (*s_30).randomSeed_0;
    var _S535 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_9)) >= 0.0010000000474974513f);
    (*s_30).path_0.lightsSampled_0 = _S535;
    if(_S535)
    {
        QueueDirectLighting_0(base_20, si_12, bsdf_9, vec2<f32>(hitConeWidth_6, (*s_30).path_0.coneSpread_0), (*s_30).path_0.throughput_7, true, &(rng_13));
    }
    var u_38 : vec2<f32> = RandomSequence_Next2D_0(&(rng_13));
    var _S536 : f32 = RandomSequence_Next_1(&(rng_13));
    var bs_6 : LobeSample_0 = BSDF_Sample_0(bsdf_9, vec3<f32>(u_38, _S536));
    var weight_12 : vec3<f32> = bs_6.weight_1.diffuse_1 + bs_6.weight_1.specular_1;
    if(!bs_6.valid_1)
    {
        _S534 = true;
    }
    else
    {
        _S534 = ((bs_6.pdf_7) <= 0.0f);
    }
    if(_S534)
    {
        _S534 = true;
    }
    else
    {
        _S534 = (all(((weight_12 <= _S533))));
    }
    if(_S534)
    {
        return;
    }
    var throughput_36 : vec3<f32> = (*s_30).path_0.throughput_7 * weight_12;
    var continuation_6 : f32 = sqrt(saturate(MaxComponent_0(throughput_36) / max(MaxComponent_0((*s_30).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_6 < 1.0f))
    {
        var _S537 : f32 = RandomSequence_Next_1(&(rng_13));
        if((_S537 >= continuation_6))
        {
            return;
        }
        throughput_35 = throughput_36 / vec3<f32>(continuation_6);
    }
    else
    {
        throughput_35 = throughput_36;
    }
    (*s_30).path_0.throughput_7 = throughput_35;
    (*s_30).path_0.direction_1 = bs_6.wi_26;
    (*s_30).path_0.scatterPdf_0 = bs_6.pdf_7;
    var crossesSurface_6 : bool = ((dot(bs_6.wi_26, si_12.faceNormal_0)) > 0.0f) != (si_12.frontFacing_0);
    (*s_30).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_12, !crossesSurface_6);
    if(crossesSurface_6)
    {
        _S534 = !ms_7.thinWalled_0;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        if(si_12.frontFacing_0)
        {
            throughput_35 = HomogeneousVolume_Absorption_0(bsdf_9.volume_0);
        }
        else
        {
            throughput_35 = vec3<f32>(0.0f);
        }
        (*s_30).path_0.absorption_0 = throughput_35;
    }
    (*s_30).path_0.coneWidth_2 = hitConeWidth_6;
    (*s_30).path_0.coneSpread_0 = (*s_30).path_0.coneSpread_0 + ScatterConeSpread_0(bs_6.type_0, ms_7.roughness_4);
    (*s_30).randomSeed_0 = rng_13.seed_0;
    (*s_30).active_0 = u32(1);
    return;
}

fn ConstantMaterialOutput_0( header_7 : MaterialHeader_0,  program_3 : u32,  group_0 : u32,  field_1 : u32,  fallback_2 : vec4<f32>) -> vec4<f32>
{
    if(program_3 == u32(4294967295))
    {
        return fallback_2;
    }
    var _S538 : vec4<f32> = fallback_2;
    var n_18 : u32 = u32(0);
    var pc_4 : u32 = program_3;
    loop
    {
        if((n_18 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var _S539 : u32 = gMaterialData_0[pc_4].x;
        if(((_S539 & (u32(255)))) == u32(0))
        {
            break;
        }
        var outputGroup_0 : u32 = (_S539 >> (u32(16)));
        if(outputGroup_0 == group_0)
        {
            var operand_1 : u32 = MaterialWord_0(pc_4 * u32(4) + u32(1) + field_1);
            var _S540 : vec4<f32>;
            if(operand_1 != u32(4294967295))
            {
                _S540 = MaterialOperand_0(operand_1, vec4<f32>(0.0f), header_7.constantBase_0);
            }
            else
            {
                _S540 = _S538;
            }
            _S538 = _S540;
        }
        var pc_5 : u32 = pc_4 + ((((u32(351898) >> ((u32(2) * min(outputGroup_0, u32(9)))))) & (u32(3))));
        n_18 = n_18 + u32(1);
        pc_4 = pc_5;
    }
    return _S538;
}

fn ConstantEmissiveRadiance_0( header_8 : MaterialHeader_0) -> vec3<f32>
{
    var defaults_0 : BSDFInputs_0 = BSDFInputs_Default_0();
    var _S541 : bool;
    if((MaterialHeader_AlphaMode_0(header_8)) == u32(1))
    {
        _S541 = ((ConstantMaterialOutput_0(header_8, header_8.opacity_0, u32(9), u32(0), vec4<f32>(defaults_0.geometryOpacity_0)).x) < (header_8.alphaCutoff_0));
    }
    else
    {
        _S541 = false;
    }
    if(_S541)
    {
        return vec3<f32>(0.0f);
    }
    return ConstantMaterialOutput_0(header_8, header_8.emission_1, u32(8), u32(1), vec4<f32>(defaults_0.emissionColor_0, 0.0f)).xyz * vec3<f32>(ConstantMaterialOutput_0(header_8, header_8.emission_1, u32(8), u32(0), vec4<f32>(defaults_0.emissionLuminance_0)).x);
}

fn SampleEmissiveGeometry_0( viewer_3 : vec3<f32>,  rng_14 : ptr<function, RandomSequence_0>,  index_17 : ptr<function, u32>,  bary_4 : ptr<function, vec3<f32>>) -> LightSample_0
{
    var _S542 : f32 = RandomSequence_Next_1(&((*rng_14)));
    (*index_17) = SelectLight_0(_S542);
    (*bary_4) = vec3<f32>(0.0f);
    var _S543 : EmissiveTriangle_std430_0 = gLights_0[(*index_17)];
    var _S544 : u32 = AnalyticFlags_0(&(_S543));
    if(((_S544 & (u32(2147483648)))) != u32(0))
    {
        var _S545 : LightSample_0 = SampleAnalytic_0(&(_S543), viewer_3, &((*rng_14)));
        return _S545;
    }
    var _S546 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_14)));
    var _S547 : vec3<f32> = SampleTriangle_0(_S546);
    (*bary_4) = _S547;
    var s_31 : LightSample_0;
    s_31.delta_0 = false;
    s_31.shadow_0 = true;
    var _S548 : vec4<f32> = _S543.p0_0;
    var _S549 : vec4<f32> = _S543.p1_0;
    s_31.position_1 = _S543.p0_0.xyz * vec3<f32>(_S547.x) + _S543.p1_0.xyz * vec3<f32>(_S547.y) + _S543.p2_0.xyz * vec3<f32>(_S547.z);
    s_31.normal_7 = _S543.n_0.xyz;
    var material_3 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S543.n_0.w))));
    var _S550 : vec3<f32>;
    if((((((material_3.flags_1) >> (u32(26)))) & (u32(31)))) == u32(0))
    {
        _S550 = ConstantEmissiveRadiance_0(material_3);
    }
    else
    {
        _S550 = vec3<f32>(1.0f);
    }
    s_31.radiance_0 = _S550;
    var _S551 : bool = MaterialHeader_DoubleSided_0(material_3);
    s_31.solidAnglePdf_0 = _S549.w * EmissiveSolidAnglePdf_0(_S548.w, _S551, viewer_3, s_31.position_1, s_31.normal_7);
    var _S552 : bool;
    if(_S551)
    {
        _S552 = ((dot(s_31.normal_7, viewer_3 - s_31.position_1)) < 0.0f);
    }
    else
    {
        _S552 = false;
    }
    if(_S552)
    {
        s_31.normal_7 = (vec3<f32>(0) - s_31.normal_7);
    }
    return s_31;
}

fn BucketMetadataBase_0() -> u32
{
    return ShadowQueueBase_0() + (gWavefront_0.capacity_0 + u32(3)) / u32(4);
}

fn LightWorkBase_0( index_18 : u32) -> u32
{
    return BucketMetadataBase_0() + u32(262) + index_18;
}

fn QueueDirectLighting_1( base_21 : u32,  si_13 : SurfaceInteraction_0,  bsdf_10 : BSDF_0,  cone_4 : vec2<f32>,  throughput_37 : vec3<f32>,  primary_1 : bool,  rng_15 : ptr<function, RandomSequence_0>)
{
    var maxDistance_6 : f32;
    gRayCone_0 = cone_4;
    var source_3 : u32 = u32(0);
    var mask_2 : u32 = u32(0);
    loop
    {
        if((source_3 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var mask_3 : u32;
        var mis_8 : bool;
        var shadow_4 : bool;
        var pendingLight_0 : bool;
        var ls_11 : LightSample_0;
        var origin_8 : vec3<f32>;
        var dir_22 : vec3<f32>;
        if(source_3 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                mask_3 = mask_2;
                source_3 = source_3 + u32(1);
                mask_2 = mask_3;
                continue;
            }
            var ls_12 : LightSample_0 = SampleEnvironment_0(&((*rng_15)));
            if((any((((ls_12.radiance_0) > vec3<f32>(0.0f))))))
            {
                mis_8 = ((ls_12.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                mis_8 = false;
            }
            if(!mis_8)
            {
                mask_3 = mask_2;
                source_3 = source_3 + u32(1);
                mask_2 = mask_3;
                continue;
            }
            var dir_23 : vec3<f32> = (vec3<f32>(0) - ls_12.normal_7);
            var _S553 : vec3<f32> = ShadowOrigin_0(si_13, dir_23);
            mis_8 = true;
            ls_11 = ls_12;
            origin_8 = _S553;
            maxDistance_6 = 1.00000001504746622e+30f;
            shadow_4 = true;
            pendingLight_0 = false;
            dir_22 = dir_23;
            mask_3 = mask_2;
        }
        else
        {
            if(source_3 == u32(1))
            {
                if((LightCount_0()) == u32(0))
                {
                    mask_3 = mask_2;
                    source_3 = source_3 + u32(1);
                    mask_2 = mask_3;
                    continue;
                }
                var lightIndex_0 : u32;
                var bary_5 : vec3<f32>;
                var ls_13 : LightSample_0 = SampleEmissiveGeometry_0(si_13.position_0, &((*rng_15)), &(lightIndex_0), &(bary_5));
                var _S554 : EmissiveTriangle_std430_0 = gLights_0[lightIndex_0];
                var _S555 : u32 = AnalyticFlags_0(&(_S554));
                if(((_S555 & (u32(2147483648)))) == u32(0))
                {
                    mis_8 = (((((LoadMaterialHeader_0((bitcast<u32>((_S554.n_0.w)))).flags_1) >> (u32(26)))) & (u32(31)))) != u32(0);
                }
                else
                {
                    mis_8 = false;
                }
                if(mis_8)
                {
                    var lightBase_0 : u32 = LightWorkBase_0(base_21 - WorkBase_0(u32(0)));
                    gAccum_0[lightBase_0] = vec4<f32>(bary_5, (bitcast<f32>((lightIndex_0))));
                    gAccum_0[Field_0(lightBase_0, u32(1))] = vec4<f32>(si_13.position_0, ls_13.solidAnglePdf_0);
                    mask_3 = (mask_2 | (u32(8)));
                }
                else
                {
                    mask_3 = mask_2;
                }
                if((any((((ls_13.radiance_0) > vec3<f32>(0.0f))))))
                {
                    shadow_4 = ((ls_13.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    shadow_4 = false;
                }
                if(!shadow_4)
                {
                    source_3 = source_3 + u32(1);
                    mask_2 = mask_3;
                    continue;
                }
                var lightPos_4 : vec3<f32> = ComputeOffsetOrigin_0(ls_13.position_1, ls_13.normal_7);
                var origin_9 : vec3<f32> = ShadowOrigin_0(si_13, lightPos_4 - si_13.position_0);
                var dir_24 : vec3<f32> = lightPos_4 - origin_9;
                var maxDistance_7 : f32 = length(dir_24);
                var dir_25 : vec3<f32> = dir_24 / vec3<f32>(maxDistance_7);
                var _S556 : bool = mis_8;
                mis_8 = !ls_13.delta_0;
                ls_11 = ls_13;
                origin_8 = origin_9;
                maxDistance_6 = maxDistance_7;
                shadow_4 = ls_13.shadow_0;
                pendingLight_0 = _S556;
                dir_22 = dir_25;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    mask_3 = mask_2;
                    source_3 = source_3 + u32(1);
                    mask_2 = mask_3;
                    continue;
                }
                var ls_14 : LightSample_0 = SampleSun_0(&((*rng_15)));
                var dir_26 : vec3<f32> = (vec3<f32>(0) - ls_14.normal_7);
                var _S557 : vec3<f32> = ShadowOrigin_0(si_13, dir_26);
                mis_8 = false;
                ls_11 = ls_14;
                origin_8 = _S557;
                maxDistance_6 = 1.00000001504746622e+30f;
                shadow_4 = true;
                pendingLight_0 = false;
                dir_22 = dir_26;
                mask_3 = mask_2;
            }
        }
        var eval_3 : DiffuseSpecular_0;
        var pdf_16 : f32;
        BSDF_EvalPdf_0(bsdf_10, dir_22, &(eval_3), &(pdf_16));
        var f_23 : vec3<f32> = eval_3.diffuse_1 + eval_3.specular_1;
        var mask_4 : u32;
        if((any(((f_23 > vec3<f32>(0.0f))))))
        {
            var weight_13 : f32;
            if(mis_8)
            {
                weight_13 = EvalMISRobust_0(ls_11.solidAnglePdf_0, pdf_16);
            }
            else
            {
                weight_13 = 1.0f;
            }
            var offset_2 : u32 = u32(12) + source_3 * u32(3);
            gAccum_0[Field_0(base_21, offset_2)] = vec4<f32>(origin_8, maxDistance_6);
            gAccum_0[Field_0(base_21, offset_2 + u32(1))] = vec4<f32>(dir_22, (bitcast<f32>((select(u32(0), u32(1), shadow_4)))));
            var _S558 : vec4<f32>;
            if(pendingLight_0)
            {
                _S558 = vec4<f32>(f_23, weight_13);
            }
            else
            {
                _S558 = vec4<f32>(vec3<f32>(weight_13) * ls_11.radiance_0 * f_23 / vec3<f32>(ls_11.solidAnglePdf_0), 0.0f);
            }
            gAccum_0[Field_0(base_21, offset_2 + u32(2))] = _S558;
            mask_4 = (mask_3 | (((u32(1) << (source_3)))));
        }
        else
        {
            mask_4 = mask_3;
        }
        mask_3 = mask_4;
        source_3 = source_3 + u32(1);
        mask_2 = mask_3;
    }
    if(primary_1)
    {
        maxDistance_6 = 0.0f;
    }
    else
    {
        maxDistance_6 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    gAccum_0[Field_0(base_21, u32(10))] = vec4<f32>(throughput_37, maxDistance_6);
    gAccum_0[Field_0(base_21, u32(11))] = vec4<f32>(cone_4, (bitcast<f32>((mask_2))), 0.0f);
    return;
}

fn ShadePath_7( base_22 : u32,  s_32 : ptr<function, WavefrontPath_0>,  hit_12 : HitRecord_0,  bounce_8 : u32)
{
    var _S559 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_32).path_0.absorption_0) > _S559)))))
    {
        (*s_32).path_0.throughput_7 = (*s_32).path_0.throughput_7 * exp((*s_32).path_0.absorption_0 * vec3<f32>(- hit_12.t_6));
    }
    var hitConeWidth_7 : f32 = (*s_32).path_0.coneWidth_2 + (*s_32).path_0.coneSpread_0 * hit_12.t_6;
    var si_14 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_32).path_0.direction_1, hit_12, hitConeWidth_7);
    var V_9 : vec3<f32> = (vec3<f32>(0) - (*s_32).path_0.direction_1);
    var ms_8 : MaterialSample_0 = EvalMaterial_0(si_14, V_9);
    var bsdf_11 : BSDF_0 = BSDF_x24init_0(ms_8.inputs_1, V_9, (*s_32).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S560 : bool = bounce_8 == u32(0);
    var throughput_38 : vec3<f32>;
    if(_S560)
    {
        (*s_32).albedo_2 = ms_8.albedo_3;
        if(si_14.frontFacing_0)
        {
            throughput_38 = ms_8.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_38 = (vec3<f32>(0) - ms_8.inputs_1.basis_1.n_1);
        }
        (*s_32).normal_11 = throughput_38;
    }
    (*s_32).active_0 = u32(0);
    var _S561 : bool;
    if(!si_14.frontFacing_0)
    {
        _S561 = !ms_8.doubleSided_2;
    }
    else
    {
        _S561 = false;
    }
    if(_S561)
    {
        _S561 = ((ms_8.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S561 = false;
    }
    if(_S561)
    {
        return;
    }
    if((any((((bsdf_11.emission_0) > _S559)))))
    {
        var _S562 : bool = !_S560;
        if(_S562)
        {
            _S561 = (*s_32).path_0.lightsSampled_0;
        }
        else
        {
            _S561 = false;
        }
        var mis_9 : f32;
        if(_S561)
        {
            mis_9 = EvalMISRobust_0((*s_32).path_0.scatterPdf_0, EmissiveHitPdf_0(si_14.instanceIndex_0, si_14.primitiveIndex_0, (*s_32).path_0.origin_3, si_14.position_0));
        }
        else
        {
            mis_9 = 1.0f;
        }
        var contribution_5 : vec3<f32> = (*s_32).path_0.throughput_7 * vec3<f32>(mis_9) * bsdf_11.emission_0;
        var clampValue_7 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_7 > 0.0f))
        {
            _S561 = _S562;
        }
        else
        {
            _S561 = false;
        }
        if(_S561)
        {
            throughput_38 = min(contribution_5, vec3<f32>(clampValue_7));
        }
        else
        {
            throughput_38 = contribution_5;
        }
        (*s_32).path_0.radiance_1 = (*s_32).path_0.radiance_1 + throughput_38;
    }
    if(bounce_8 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_16 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_16.seed_0 = (*s_32).randomSeed_0;
    var _S563 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_11)) >= 0.0010000000474974513f);
    (*s_32).path_0.lightsSampled_0 = _S563;
    if(_S563)
    {
        QueueDirectLighting_1(base_22, si_14, bsdf_11, vec2<f32>(hitConeWidth_7, (*s_32).path_0.coneSpread_0), (*s_32).path_0.throughput_7, _S560, &(rng_16));
    }
    var u_39 : vec2<f32> = RandomSequence_Next2D_0(&(rng_16));
    var _S564 : f32 = RandomSequence_Next_1(&(rng_16));
    var bs_7 : LobeSample_0 = BSDF_Sample_0(bsdf_11, vec3<f32>(u_39, _S564));
    var weight_14 : vec3<f32> = bs_7.weight_1.diffuse_1 + bs_7.weight_1.specular_1;
    if(!bs_7.valid_1)
    {
        _S561 = true;
    }
    else
    {
        _S561 = ((bs_7.pdf_7) <= 0.0f);
    }
    if(_S561)
    {
        _S561 = true;
    }
    else
    {
        _S561 = (all(((weight_14 <= _S559))));
    }
    if(_S561)
    {
        return;
    }
    var throughput_39 : vec3<f32> = (*s_32).path_0.throughput_7 * weight_14;
    var continuation_7 : f32 = sqrt(saturate(MaxComponent_0(throughput_39) / max(MaxComponent_0((*s_32).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_7 < 1.0f))
    {
        var _S565 : f32 = RandomSequence_Next_1(&(rng_16));
        if((_S565 >= continuation_7))
        {
            return;
        }
        throughput_38 = throughput_39 / vec3<f32>(continuation_7);
    }
    else
    {
        throughput_38 = throughput_39;
    }
    (*s_32).path_0.throughput_7 = throughput_38;
    (*s_32).path_0.direction_1 = bs_7.wi_26;
    (*s_32).path_0.scatterPdf_0 = bs_7.pdf_7;
    var crossesSurface_7 : bool = ((dot(bs_7.wi_26, si_14.faceNormal_0)) > 0.0f) != (si_14.frontFacing_0);
    (*s_32).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_14, !crossesSurface_7);
    if(crossesSurface_7)
    {
        _S561 = !ms_8.thinWalled_0;
    }
    else
    {
        _S561 = false;
    }
    if(_S561)
    {
        if(si_14.frontFacing_0)
        {
            throughput_38 = HomogeneousVolume_Absorption_0(bsdf_11.volume_0);
        }
        else
        {
            throughput_38 = vec3<f32>(0.0f);
        }
        (*s_32).path_0.absorption_0 = throughput_38;
    }
    (*s_32).path_0.coneWidth_2 = hitConeWidth_7;
    (*s_32).path_0.coneSpread_0 = (*s_32).path_0.coneSpread_0 + ScatterConeSpread_0(bs_7.type_0, ms_8.roughness_4);
    (*s_32).randomSeed_0 = rng_16.seed_0;
    (*s_32).active_0 = u32(1);
    return;
}

fn ShadePath_8( base_23 : u32,  s_33 : ptr<function, WavefrontPath_0>,  hit_13 : HitRecord_0,  bounce_9 : u32)
{
    var _S566 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_33).path_0.absorption_0) > _S566)))))
    {
        (*s_33).path_0.throughput_7 = (*s_33).path_0.throughput_7 * exp((*s_33).path_0.absorption_0 * vec3<f32>(- hit_13.t_6));
    }
    var hitConeWidth_8 : f32 = (*s_33).path_0.coneWidth_2 + (*s_33).path_0.coneSpread_0 * hit_13.t_6;
    var si_15 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_33).path_0.direction_1, hit_13, hitConeWidth_8);
    var V_10 : vec3<f32> = (vec3<f32>(0) - (*s_33).path_0.direction_1);
    var ms_9 : MaterialSample_0 = EvalMaterial_0(si_15, V_10);
    var bsdf_12 : BSDF_0 = BSDF_x24init_0(ms_9.inputs_1, V_10, (*s_33).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S567 : bool = bounce_9 == u32(0);
    var throughput_40 : vec3<f32>;
    if(_S567)
    {
        (*s_33).albedo_2 = ms_9.albedo_3;
        if(si_15.frontFacing_0)
        {
            throughput_40 = ms_9.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_40 = (vec3<f32>(0) - ms_9.inputs_1.basis_1.n_1);
        }
        (*s_33).normal_11 = throughput_40;
    }
    (*s_33).active_0 = u32(0);
    var _S568 : bool;
    if(!si_15.frontFacing_0)
    {
        _S568 = !ms_9.doubleSided_2;
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        _S568 = ((ms_9.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        return;
    }
    if((any((((bsdf_12.emission_0) > _S566)))))
    {
        var _S569 : bool = !_S567;
        if(_S569)
        {
            _S568 = (*s_33).path_0.lightsSampled_0;
        }
        else
        {
            _S568 = false;
        }
        var mis_10 : f32;
        if(_S568)
        {
            mis_10 = EvalMISRobust_0((*s_33).path_0.scatterPdf_0, EmissiveHitPdf_0(si_15.instanceIndex_0, si_15.primitiveIndex_0, (*s_33).path_0.origin_3, si_15.position_0));
        }
        else
        {
            mis_10 = 1.0f;
        }
        var contribution_6 : vec3<f32> = (*s_33).path_0.throughput_7 * vec3<f32>(mis_10) * bsdf_12.emission_0;
        var clampValue_8 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_8 > 0.0f))
        {
            _S568 = _S569;
        }
        else
        {
            _S568 = false;
        }
        if(_S568)
        {
            throughput_40 = min(contribution_6, vec3<f32>(clampValue_8));
        }
        else
        {
            throughput_40 = contribution_6;
        }
        (*s_33).path_0.radiance_1 = (*s_33).path_0.radiance_1 + throughput_40;
    }
    if(bounce_9 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_17 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_17.seed_0 = (*s_33).randomSeed_0;
    var _S570 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_12)) >= 0.0010000000474974513f);
    (*s_33).path_0.lightsSampled_0 = _S570;
    if(_S570)
    {
        QueueDirectLighting_0(base_23, si_15, bsdf_12, vec2<f32>(hitConeWidth_8, (*s_33).path_0.coneSpread_0), (*s_33).path_0.throughput_7, _S567, &(rng_17));
    }
    var u_40 : vec2<f32> = RandomSequence_Next2D_0(&(rng_17));
    var _S571 : f32 = RandomSequence_Next_1(&(rng_17));
    var bs_8 : LobeSample_0 = BSDF_Sample_0(bsdf_12, vec3<f32>(u_40, _S571));
    var weight_15 : vec3<f32> = bs_8.weight_1.diffuse_1 + bs_8.weight_1.specular_1;
    if(!bs_8.valid_1)
    {
        _S568 = true;
    }
    else
    {
        _S568 = ((bs_8.pdf_7) <= 0.0f);
    }
    if(_S568)
    {
        _S568 = true;
    }
    else
    {
        _S568 = (all(((weight_15 <= _S566))));
    }
    if(_S568)
    {
        return;
    }
    var throughput_41 : vec3<f32> = (*s_33).path_0.throughput_7 * weight_15;
    var continuation_8 : f32 = sqrt(saturate(MaxComponent_0(throughput_41) / max(MaxComponent_0((*s_33).path_0.throughput_7), 9.999999960041972e-13f)));
    if((continuation_8 < 1.0f))
    {
        var _S572 : f32 = RandomSequence_Next_1(&(rng_17));
        if((_S572 >= continuation_8))
        {
            return;
        }
        throughput_40 = throughput_41 / vec3<f32>(continuation_8);
    }
    else
    {
        throughput_40 = throughput_41;
    }
    (*s_33).path_0.throughput_7 = throughput_40;
    (*s_33).path_0.direction_1 = bs_8.wi_26;
    (*s_33).path_0.scatterPdf_0 = bs_8.pdf_7;
    var crossesSurface_8 : bool = ((dot(bs_8.wi_26, si_15.faceNormal_0)) > 0.0f) != (si_15.frontFacing_0);
    (*s_33).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_15, !crossesSurface_8);
    if(crossesSurface_8)
    {
        _S568 = !ms_9.thinWalled_0;
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        if(si_15.frontFacing_0)
        {
            throughput_40 = HomogeneousVolume_Absorption_0(bsdf_12.volume_0);
        }
        else
        {
            throughput_40 = vec3<f32>(0.0f);
        }
        (*s_33).path_0.absorption_0 = throughput_40;
    }
    (*s_33).path_0.coneWidth_2 = hitConeWidth_8;
    (*s_33).path_0.coneSpread_0 = (*s_33).path_0.coneSpread_0 + ScatterConeSpread_0(bs_8.type_0, ms_9.roughness_4);
    (*s_33).randomSeed_0 = rng_17.seed_0;
    (*s_33).active_0 = u32(1);
    return;
}

fn IntersectTriangle_1( o_55 : vec3<f32>,  d_11 : vec3<f32>,  v0_3 : vec3<f32>,  e1_1 : vec3<f32>,  e2_1 : vec3<f32>,  tMin_3 : f32,  tMax_3 : f32,  t_13 : ptr<function, f32>,  bary_6 : ptr<function, vec2<f32>>) -> bool
{
    (*t_13) = 0.0f;
    (*bary_6) = vec2<f32>(0.0f);
    var h_15 : vec3<f32> = cross(d_11, e2_1);
    var a_18 : f32 = dot(e1_1, h_15);
    if(a_18 == 0.0f)
    {
        return false;
    }
    var f_24 : f32 = rcp_1(a_18);
    var s_34 : vec3<f32> = o_55 - v0_3;
    var u_41 : f32 = f_24 * dot(s_34, h_15);
    var _S573 : bool;
    if((u_41 < 0.0f))
    {
        _S573 = true;
    }
    else
    {
        _S573 = (u_41 > 1.0f);
    }
    if(_S573)
    {
        return false;
    }
    var q_1 : vec3<f32> = cross(s_34, e1_1);
    var v_18 : f32 = f_24 * dot(d_11, q_1);
    if((v_18 < 0.0f))
    {
        _S573 = true;
    }
    else
    {
        _S573 = ((u_41 + v_18) > 1.0f);
    }
    if(_S573)
    {
        return false;
    }
    (*t_13) = f_24 * dot(e2_1, q_1);
    (*bary_6) = vec2<f32>(u_41, v_18);
    if(((*t_13) > tMin_3))
    {
        _S573 = ((*t_13) < tMax_3);
    }
    else
    {
        _S573 = false;
    }
    return _S573;
}

fn TraverseBLAS_2( _S574 : u32,  _S575 : u32,  _S576 : vec3<f32>,  _S577 : vec3<f32>,  _S578 : f32,  _S579 : bool,  _S580 : ptr<function, HitRecord_0>) -> bool
{
    var found_8 : bool;
    var _S581 : vec3<f32> = SafeRcp_0(_S577);
    var stack_6 : array<u32, i32(48)>;
    var nodeRef_4 : u32 = u32(0);
    var found_9 : bool = false;
    var stackPtr_16 : u32 = u32(0);
    loop
    {
        var i_10 : u32;
        if(((nodeRef_4 & (u32(2147483648)))) != u32(0))
        {
            var _S582 : u32 = (((nodeRef_4 >> (u32(24)))) & (u32(127)));
            var _S583 : u32 = (nodeRef_4 & (u32(16777215)));
            found_8 = found_9;
            i_10 = u32(0);
            loop
            {
                if((i_10 < _S582))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_24 : u32 = (gInstances_0[_S575].blasTriOffset_0 + _S583 + i_10) * u32(3);
                var v0_4 : vec4<f32> = gTris_0[base_24];
                var t_14 : f32;
                var bary_7 : vec2<f32>;
                var _S584 : bool = IntersectTriangle_1(_S576, _S577, v0_4.xyz, gTris_0[base_24 + u32(1)].xyz, gTris_0[base_24 + u32(2)].xyz, _S578, (*_S580).t_6, &(t_14), &(bary_7));
                if(!_S584)
                {
                    i_10 = i_10 + u32(1);
                    continue;
                }
                var primitiveIndex_4 : u32 = (bitcast<u32>((v0_4.w)));
                (*_S580).t_6 = t_14;
                (*_S580).barycentrics_0 = bary_7;
                (*_S580).instanceIndex_2 = _S574;
                (*_S580).primitiveIndex_1 = primitiveIndex_4;
                if(_S579)
                {
                    return true;
                }
                found_8 = true;
                i_10 = i_10 + u32(1);
            }
            if(stackPtr_16 == u32(0))
            {
                break;
            }
            var stackPtr_17 : u32 = stackPtr_16 - u32(1);
            nodeRef_4 = stack_6[stackPtr_17];
            found_9 = found_8;
            stackPtr_16 = stackPtr_17;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_4 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S575].blasNodeOffset_0 + nodeRef_4];
        var dist1_8 : f32 = IntersectBox_0(node_4.lmin_0, node_4.lmax_0, _S576, _S581, _S578, (*_S580).t_6);
        var dist2_8 : f32 = IntersectBox_0(node_4.rmin_0, node_4.rmax_0, _S576, _S581, _S578, (*_S580).t_6);
        var far_4 : u32;
        var dist1_9 : f32;
        var dist2_9 : f32;
        if((dist1_8 > dist2_8))
        {
            dist1_9 = dist2_8;
            i_10 = node_4.right_0;
            dist2_9 = dist1_8;
            far_4 = node_4.left_0;
        }
        else
        {
            dist1_9 = dist1_8;
            i_10 = node_4.left_0;
            dist2_9 = dist2_8;
            far_4 = node_4.right_0;
        }
        if(dist1_9 == 1.00000001504746622e+30f)
        {
            if(stackPtr_16 == u32(0))
            {
                found_8 = found_9;
                break;
            }
            var stackPtr_18 : u32 = stackPtr_16 - u32(1);
            nodeRef_4 = stack_6[stackPtr_18];
            stackPtr_16 = stackPtr_18;
        }
        else
        {
            if(dist2_9 != 1.00000001504746622e+30f)
            {
                found_8 = (stackPtr_16 < u32(48));
            }
            else
            {
                found_8 = false;
            }
            var stackPtr_19 : u32;
            if(found_8)
            {
                var _S585 : u32 = stackPtr_16 + u32(1);
                stack_6[stackPtr_16] = far_4;
                stackPtr_19 = _S585;
            }
            else
            {
                stackPtr_19 = stackPtr_16;
            }
            nodeRef_4 = i_10;
            stackPtr_16 = stackPtr_19;
        }
    }
    return found_8;
}

fn TraceScene_2( ray_4 : Ray_0,  anyHit_2 : bool,  hit_14 : ptr<function, HitRecord_0>) -> bool
{
    var found_10 : bool;
    (*hit_14).t_6 = ray_4.tMax_0;
    (*hit_14).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_14).instanceIndex_2 = u32(4294967295);
    (*hit_14).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S586 : u32 = gFrame_0.counts_0.z;
    var _S587 : vec3<f32> = SafeRcp_0(ray_4.direction_0);
    var stack_7 : array<u32, i32(32)>;
    var nodeRef_5 : u32 = u32(0);
    var found_11 : bool = false;
    var stackPtr_20 : u32 = u32(0);
    loop
    {
        var i_11 : u32;
        if(((nodeRef_5 & (u32(2147483648)))) != u32(0))
        {
            var _S588 : u32 = (((nodeRef_5 >> (u32(24)))) & (u32(127)));
            var _S589 : u32 = (nodeRef_5 & (u32(16777215)));
            found_10 = found_11;
            i_11 = u32(0);
            loop
            {
                if((i_11 < _S588))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_5 : u32 = gIndices_0[_S586 + _S589 + i_11];
                var _S590 : bool = TraverseBLAS_2(instanceIndex_5, instanceIndex_5, InverseTransformPoint_0(instanceIndex_5, ray_4.origin_0), InverseTransformVector_0(instanceIndex_5, ray_4.direction_0), ray_4.tMin_0, anyHit_2, &((*hit_14)));
                if(_S590)
                {
                    if(anyHit_2)
                    {
                        return true;
                    }
                    found_10 = true;
                }
                i_11 = i_11 + u32(1);
            }
            if(stackPtr_20 == u32(0))
            {
                break;
            }
            var stackPtr_21 : u32 = stackPtr_20 - u32(1);
            nodeRef_5 = stack_7[stackPtr_21];
            found_11 = found_10;
            stackPtr_20 = stackPtr_21;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_5 : BVHNode_std430_0 = gNodes_0[nodeRef_5];
        var dist1_10 : f32 = IntersectBox_0(node_5.lmin_0, node_5.lmax_0, ray_4.origin_0, _S587, ray_4.tMin_0, (*hit_14).t_6);
        var dist2_10 : f32 = IntersectBox_0(node_5.rmin_0, node_5.rmax_0, ray_4.origin_0, _S587, ray_4.tMin_0, (*hit_14).t_6);
        var far_5 : u32;
        var dist1_11 : f32;
        var dist2_11 : f32;
        if((dist1_10 > dist2_10))
        {
            dist1_11 = dist2_10;
            i_11 = node_5.right_0;
            dist2_11 = dist1_10;
            far_5 = node_5.left_0;
        }
        else
        {
            dist1_11 = dist1_10;
            i_11 = node_5.left_0;
            dist2_11 = dist2_10;
            far_5 = node_5.right_0;
        }
        if(dist1_11 == 1.00000001504746622e+30f)
        {
            if(stackPtr_20 == u32(0))
            {
                found_10 = found_11;
                break;
            }
            var stackPtr_22 : u32 = stackPtr_20 - u32(1);
            nodeRef_5 = stack_7[stackPtr_22];
            stackPtr_20 = stackPtr_22;
        }
        else
        {
            if(dist2_11 != 1.00000001504746622e+30f)
            {
                found_10 = (stackPtr_20 < u32(32));
            }
            else
            {
                found_10 = false;
            }
            var stackPtr_23 : u32;
            if(found_10)
            {
                var _S591 : u32 = stackPtr_20 + u32(1);
                stack_7[stackPtr_20] = far_5;
                stackPtr_23 = _S591;
            }
            else
            {
                stackPtr_23 = stackPtr_20;
            }
            nodeRef_5 = i_11;
            stackPtr_20 = stackPtr_23;
        }
    }
    return found_10;
}

fn TraceClosest_0( ray_5 : Ray_0) -> HitRecord_0
{
    var hit_15 : HitRecord_0;
    var _S592 : bool = TraceScene_2(ray_5, false, &(hit_15));
    return hit_15;
}

fn AnalyticLightCount_0() -> u32
{
    return gFrame_0.counts_0.w;
}

fn HitRecord_IsHit_0( this_118 : HitRecord_0) -> bool
{
    return (this_118.instanceIndex_2) != u32(4294967295);
}

fn IntersectAnalyticLights_0( origin_10 : vec3<f32>,  dir_27 : vec3<f32>,  tMax_4 : f32,  cameraRay_0 : bool,  radiance_2 : ptr<function, vec3<f32>>,  pdf_17 : ptr<function, f32>) -> bool
{
    (*radiance_2) = vec3<f32>(0.0f);
    (*pdf_17) = 0.0f;
    var nearest_0 : f32 = tMax_4;
    var found_12 : bool = false;
    var i_12 : u32 = u32(0);
    loop
    {
        if((i_12 < (AnalyticLightCount_0())))
        {
        }
        else
        {
            break;
        }
        var _S593 : EmissiveTriangle_std430_0 = gLights_0[i_12];
        var _S594 : u32 = AnalyticFlags_0(&(_S593));
        var _S595 : bool;
        if(cameraRay_0)
        {
            _S595 = ((_S594 & (u32(256)))) != u32(0);
        }
        else
        {
            _S595 = false;
        }
        if(_S595)
        {
            i_12 = i_12 + u32(1);
            continue;
        }
        var nearest_1 : f32;
        var _S596 : bool;
        var inside_4 : bool;
        if(((_S594 & (u32(255)))) == u32(2))
        {
            var n_19 : vec3<f32> = _S593.p2_0.xyz;
            var cosTheta_14 : f32 = - dot(n_19, dir_27);
            if((cosTheta_14 <= 9.99999997475242708e-07f))
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var _S597 : vec4<f32> = _S593.p0_0;
            var _S598 : vec3<f32> = _S593.p0_0.xyz;
            var t_15 : f32 = dot(_S598 - origin_10, n_19) / - cosTheta_14;
            if((t_15 <= 0.0f))
            {
                _S596 = true;
            }
            else
            {
                _S596 = (t_15 >= nearest_0);
            }
            if(_S596)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var local_3 : vec3<f32> = origin_10 + dir_27 * vec3<f32>(t_15) - _S598;
            var _S599 : vec3<f32> = _S593.n_0.xyz;
            var _S600 : vec3<f32> = _S593.uvA_0.xyz;
            var d_12 : vec2<f32> = vec2<f32>(dot(local_3, _S599) / dot(_S599, _S599), dot(local_3, _S600) / dot(_S600, _S600));
            if(((_S594 & (u32(512)))) != u32(0))
            {
                inside_4 = ((dot(d_12, d_12)) <= 0.25f);
            }
            else
            {
                inside_4 = (all((((abs(d_12)) <= vec2<f32>(0.5f)))));
            }
            if(!inside_4)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            (*radiance_2) = _S593.p1_0.xyz;
            (*pdf_17) = _S593.p1_0.w * t_15 * t_15 / (cosTheta_14 * _S597.w);
            nearest_1 = t_15;
        }
        else
        {
            var _S601 : vec4<f32> = _S593.p0_0;
            var radius_4 : f32 = _S593.p0_0.w;
            if((radius_4 <= 0.0f))
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var toCenter_1 : vec3<f32> = _S601.xyz - origin_10;
            var distSq_4 : f32 = dot(toCenter_1, toCenter_1);
            var tc_9 : f32 = dot(toCenter_1, dir_27);
            var _S602 : f32 = radius_4 * radius_4;
            var h_16 : f32 = _S602 - (distSq_4 - tc_9 * tc_9);
            if((h_16 < 0.0f))
            {
                _S596 = true;
            }
            else
            {
                _S596 = (distSq_4 <= _S602);
            }
            if(_S596)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var t_16 : f32 = tc_9 - sqrt(h_16);
            if((t_16 <= 0.0f))
            {
                inside_4 = true;
            }
            else
            {
                inside_4 = (t_16 >= nearest_0);
            }
            if(inside_4)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var _S603 : vec4<f32> = _S593.p1_0;
            var _S604 : vec3<f32> = _S593.p1_0.xyz;
            var _S605 : f32 = SpotAttenuation_0(&(_S593), (vec3<f32>(0) - toCenter_1) * vec3<f32>(rsqrt_0(distSq_4)));
            (*radiance_2) = _S604 * vec3<f32>(_S605);
            (*pdf_17) = _S603.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_4, distSq_4));
            nearest_1 = t_16;
        }
        nearest_0 = nearest_1;
        found_12 = true;
        i_12 = i_12 + u32(1);
    }
    return found_12;
}

fn HitsSun_0( dir_28 : vec3<f32>) -> bool
{
    var _S606 : bool;
    if(SunEnabled_0())
    {
        _S606 = ((dot(dir_28, gFrame_0.sunDirection_0.xyz)) >= (gFrame_0.sunDirection_0.w));
    }
    else
    {
        _S606 = false;
    }
    return _S606;
}

fn EnvironmentPdf_0( dir_29 : vec3<f32>) -> f32
{
    if(!EnvironmentEnabled_0())
    {
        return 0.0f;
    }
    if((((gFrame_0.settings_0.z) & (u32(4)))) == u32(0))
    {
        return 1.0f / (4.0f * float_getPi_0());
    }
    var W_1 : u32 = gFrame_0.envInfo_0.x;
    var H_1 : u32 = gFrame_0.envInfo_0.y;
    var local_4 : vec3<f32> = RotateY_0(dir_29, - gFrame_0.envParams_0.y);
    var uv_4 : vec2<f32> = fract(DirectionToEquirectUV_0(local_4));
    var _S607 : f32 = f32(W_1);
    var _S608 : u32 = min(u32(uv_4.x * _S607), W_1 - u32(1));
    var _S609 : f32 = f32(H_1);
    var _S610 : u32 = min(u32(uv_4.y * _S609), H_1 - u32(1));
    var _S611 : f32 = local_4.y;
    var PI_6 : f32 = float_getPi_0();
    return (EnvCdf_0(_S608 + u32(1), _S610) - EnvCdf_0(_S608, _S610)) * _S607 * ((EnvCdf_0(_S610 + u32(1), H_1) - EnvCdf_0(_S610, H_1)) * _S609) / (2.0f * PI_6 * PI_6 * sqrt(clamp(1.0f - _S611 * _S611, 9.99999997475242708e-07f, 1.0f)));
}

fn IntersectPath_0( s_35 : ptr<function, WavefrontPath_0>,  bounce_10 : u32) -> HitRecord_0
{
    gRayCone_0 = vec2<f32>((*s_35).path_0.coneWidth_2, (*s_35).path_0.coneSpread_0);
    var ray_6 : Ray_0 = Ray_x24init_0((*s_35).path_0.origin_3, (*s_35).path_0.direction_1, 1.00000001504746622e+30f);
    var hit_16 : HitRecord_0 = TraceClosest_0(ray_6);
    var clampValue_9 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var mis_11 : f32;
    var _S612 : bool;
    var contribution_7 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_3 : vec3<f32>;
        var pdf_18 : f32;
        if(HitRecord_IsHit_0(hit_16))
        {
            mis_11 = hit_16.t_6;
        }
        else
        {
            mis_11 = 1.00000001504746622e+30f;
        }
        var _S613 : bool = IntersectAnalyticLights_0(ray_6.origin_0, ray_6.direction_0, mis_11, bounce_10 == u32(0), &(radiance_3), &(pdf_18));
        if(_S613)
        {
            var _S614 : bool = (bounce_10 > u32(0));
            if(_S614)
            {
                _S612 = (*s_35).path_0.lightsSampled_0;
            }
            else
            {
                _S612 = false;
            }
            if(_S612)
            {
                mis_11 = EvalMISRobust_0((*s_35).path_0.scatterPdf_0, pdf_18);
            }
            else
            {
                mis_11 = 1.0f;
            }
            var contribution_8 : vec3<f32> = (*s_35).path_0.throughput_7 * vec3<f32>(mis_11) * radiance_3;
            if((clampValue_9 > 0.0f))
            {
                _S612 = _S614;
            }
            else
            {
                _S612 = false;
            }
            if(_S612)
            {
                contribution_7 = min(contribution_8, vec3<f32>(clampValue_9));
            }
            else
            {
                contribution_7 = contribution_8;
            }
            (*s_35).path_0.radiance_1 = (*s_35).path_0.radiance_1 + contribution_7;
        }
    }
    if(!HitRecord_IsHit_0(hit_16))
    {
        if(bounce_10 == u32(0))
        {
            var visible_0 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_0)
            {
                contribution_7 = EvalEnvironment_0(ray_6.direction_0);
            }
            else
            {
                contribution_7 = gFrame_0.background_0.xyz;
            }
            (*s_35).path_0.radiance_1 = (*s_35).path_0.radiance_1 + contribution_7;
            if(visible_0)
            {
                _S612 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S612 = false;
            }
            if(_S612)
            {
                (*s_35).path_0.radiance_1 = (*s_35).path_0.radiance_1 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if((*s_35).path_0.lightsSampled_0)
            {
                mis_11 = EvalMISRobust_0((*s_35).path_0.scatterPdf_0, EnvironmentPdf_0(ray_6.direction_0));
            }
            else
            {
                mis_11 = 1.0f;
            }
            var contribution_9 : vec3<f32> = (*s_35).path_0.throughput_7 * vec3<f32>(mis_11) * EvalEnvironment_0(ray_6.direction_0);
            if(!(*s_35).path_0.lightsSampled_0)
            {
                _S612 = SunEnabled_0();
            }
            else
            {
                _S612 = false;
            }
            if(_S612)
            {
                _S612 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S612 = false;
            }
            if(_S612)
            {
                contribution_7 = contribution_9 + (*s_35).path_0.throughput_7 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_7 = contribution_9;
            }
            if((clampValue_9 > 0.0f))
            {
                contribution_7 = min(contribution_7, vec3<f32>(clampValue_9));
            }
            (*s_35).path_0.radiance_1 = (*s_35).path_0.radiance_1 + contribution_7;
        }
        (*s_35).active_0 = u32(0);
    }
    return hit_16;
}

fn TraverseBLAS_3( _S615 : u32,  _S616 : u32,  _S617 : vec3<f32>,  _S618 : vec3<f32>,  _S619 : f32,  _S620 : bool,  _S621 : ptr<function, HitRecord_0>) -> bool
{
    var found_13 : bool;
    var _S622 : vec3<f32> = SafeRcp_0(_S618);
    var _S623 : bool = (((gInstances_0[_S616].flags_0) & (u32(1)))) != u32(0);
    var stack_8 : array<u32, i32(48)>;
    var nodeRef_6 : u32 = u32(0);
    var found_14 : bool = false;
    var stackPtr_24 : u32 = u32(0);
    loop
    {
        var i_13 : u32;
        if(((nodeRef_6 & (u32(2147483648)))) != u32(0))
        {
            var _S624 : u32 = (((nodeRef_6 >> (u32(24)))) & (u32(127)));
            var _S625 : u32 = (nodeRef_6 & (u32(16777215)));
            found_13 = found_14;
            i_13 = u32(0);
            loop
            {
                if((i_13 < _S624))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_25 : u32 = (gInstances_0[_S616].blasTriOffset_0 + _S625 + i_13) * u32(3);
                var v0_5 : vec4<f32> = gTris_0[base_25];
                var t_17 : f32;
                var bary_8 : vec2<f32>;
                var _S626 : bool = IntersectTriangle_1(_S617, _S618, v0_5.xyz, gTris_0[base_25 + u32(1)].xyz, gTris_0[base_25 + u32(2)].xyz, _S619, (*_S621).t_6, &(t_17), &(bary_8));
                if(!_S626)
                {
                    i_13 = i_13 + u32(1);
                    continue;
                }
                var primitiveIndex_5 : u32 = (bitcast<u32>((v0_5.w)));
                var _S627 : bool;
                if(_S623)
                {
                    var _S628 : bool = AlphaTestRejects_0(_S616, primitiveIndex_5, bary_8, t_17);
                    _S627 = _S628;
                }
                else
                {
                    _S627 = false;
                }
                if(_S627)
                {
                    i_13 = i_13 + u32(1);
                    continue;
                }
                (*_S621).t_6 = t_17;
                (*_S621).barycentrics_0 = bary_8;
                (*_S621).instanceIndex_2 = _S615;
                (*_S621).primitiveIndex_1 = primitiveIndex_5;
                if(_S620)
                {
                    return true;
                }
                found_13 = true;
                i_13 = i_13 + u32(1);
            }
            if(stackPtr_24 == u32(0))
            {
                break;
            }
            var stackPtr_25 : u32 = stackPtr_24 - u32(1);
            nodeRef_6 = stack_8[stackPtr_25];
            found_14 = found_13;
            stackPtr_24 = stackPtr_25;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_6 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S616].blasNodeOffset_0 + nodeRef_6];
        var dist1_12 : f32 = IntersectBox_0(node_6.lmin_0, node_6.lmax_0, _S617, _S622, _S619, (*_S621).t_6);
        var dist2_12 : f32 = IntersectBox_0(node_6.rmin_0, node_6.rmax_0, _S617, _S622, _S619, (*_S621).t_6);
        var far_6 : u32;
        var dist1_13 : f32;
        var dist2_13 : f32;
        if((dist1_12 > dist2_12))
        {
            dist1_13 = dist2_12;
            i_13 = node_6.right_0;
            dist2_13 = dist1_12;
            far_6 = node_6.left_0;
        }
        else
        {
            dist1_13 = dist1_12;
            i_13 = node_6.left_0;
            dist2_13 = dist2_12;
            far_6 = node_6.right_0;
        }
        if(dist1_13 == 1.00000001504746622e+30f)
        {
            if(stackPtr_24 == u32(0))
            {
                found_13 = found_14;
                break;
            }
            var stackPtr_26 : u32 = stackPtr_24 - u32(1);
            nodeRef_6 = stack_8[stackPtr_26];
            stackPtr_24 = stackPtr_26;
        }
        else
        {
            if(dist2_13 != 1.00000001504746622e+30f)
            {
                found_13 = (stackPtr_24 < u32(48));
            }
            else
            {
                found_13 = false;
            }
            var stackPtr_27 : u32;
            if(found_13)
            {
                var _S629 : u32 = stackPtr_24 + u32(1);
                stack_8[stackPtr_24] = far_6;
                stackPtr_27 = _S629;
            }
            else
            {
                stackPtr_27 = stackPtr_24;
            }
            nodeRef_6 = i_13;
            stackPtr_24 = stackPtr_27;
        }
    }
    return found_13;
}

fn TraceScene_3( ray_7 : Ray_0,  anyHit_3 : bool,  hit_17 : ptr<function, HitRecord_0>) -> bool
{
    var found_15 : bool;
    (*hit_17).t_6 = ray_7.tMax_0;
    (*hit_17).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_17).instanceIndex_2 = u32(4294967295);
    (*hit_17).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S630 : u32 = gFrame_0.counts_0.z;
    var _S631 : vec3<f32> = SafeRcp_0(ray_7.direction_0);
    var stack_9 : array<u32, i32(32)>;
    var nodeRef_7 : u32 = u32(0);
    var found_16 : bool = false;
    var stackPtr_28 : u32 = u32(0);
    loop
    {
        var i_14 : u32;
        if(((nodeRef_7 & (u32(2147483648)))) != u32(0))
        {
            var _S632 : u32 = (((nodeRef_7 >> (u32(24)))) & (u32(127)));
            var _S633 : u32 = (nodeRef_7 & (u32(16777215)));
            found_15 = found_16;
            i_14 = u32(0);
            loop
            {
                if((i_14 < _S632))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_6 : u32 = gIndices_0[_S630 + _S633 + i_14];
                var _S634 : bool = TraverseBLAS_3(instanceIndex_6, instanceIndex_6, InverseTransformPoint_0(instanceIndex_6, ray_7.origin_0), InverseTransformVector_0(instanceIndex_6, ray_7.direction_0), ray_7.tMin_0, anyHit_3, &((*hit_17)));
                if(_S634)
                {
                    if(anyHit_3)
                    {
                        return true;
                    }
                    found_15 = true;
                }
                i_14 = i_14 + u32(1);
            }
            if(stackPtr_28 == u32(0))
            {
                break;
            }
            var stackPtr_29 : u32 = stackPtr_28 - u32(1);
            nodeRef_7 = stack_9[stackPtr_29];
            found_16 = found_15;
            stackPtr_28 = stackPtr_29;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_7 : BVHNode_std430_0 = gNodes_0[nodeRef_7];
        var dist1_14 : f32 = IntersectBox_0(node_7.lmin_0, node_7.lmax_0, ray_7.origin_0, _S631, ray_7.tMin_0, (*hit_17).t_6);
        var dist2_14 : f32 = IntersectBox_0(node_7.rmin_0, node_7.rmax_0, ray_7.origin_0, _S631, ray_7.tMin_0, (*hit_17).t_6);
        var far_7 : u32;
        var dist1_15 : f32;
        var dist2_15 : f32;
        if((dist1_14 > dist2_14))
        {
            dist1_15 = dist2_14;
            i_14 = node_7.right_0;
            dist2_15 = dist1_14;
            far_7 = node_7.left_0;
        }
        else
        {
            dist1_15 = dist1_14;
            i_14 = node_7.left_0;
            dist2_15 = dist2_14;
            far_7 = node_7.right_0;
        }
        if(dist1_15 == 1.00000001504746622e+30f)
        {
            if(stackPtr_28 == u32(0))
            {
                found_15 = found_16;
                break;
            }
            var stackPtr_30 : u32 = stackPtr_28 - u32(1);
            nodeRef_7 = stack_9[stackPtr_30];
            stackPtr_28 = stackPtr_30;
        }
        else
        {
            if(dist2_15 != 1.00000001504746622e+30f)
            {
                found_15 = (stackPtr_28 < u32(32));
            }
            else
            {
                found_15 = false;
            }
            var stackPtr_31 : u32;
            if(found_15)
            {
                var _S635 : u32 = stackPtr_28 + u32(1);
                stack_9[stackPtr_28] = far_7;
                stackPtr_31 = _S635;
            }
            else
            {
                stackPtr_31 = stackPtr_28;
            }
            nodeRef_7 = i_14;
            stackPtr_28 = stackPtr_31;
        }
    }
    return found_15;
}

fn TraceClosest_1( ray_8 : Ray_0) -> HitRecord_0
{
    var hit_18 : HitRecord_0;
    var _S636 : bool = TraceScene_3(ray_8, false, &(hit_18));
    return hit_18;
}

fn IntersectPath_1( s_36 : ptr<function, WavefrontPath_0>,  bounce_11 : u32) -> HitRecord_0
{
    gRayCone_0 = vec2<f32>((*s_36).path_0.coneWidth_2, (*s_36).path_0.coneSpread_0);
    var ray_9 : Ray_0 = Ray_x24init_0((*s_36).path_0.origin_3, (*s_36).path_0.direction_1, 1.00000001504746622e+30f);
    var hit_19 : HitRecord_0 = TraceClosest_1(ray_9);
    var clampValue_10 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var mis_12 : f32;
    var _S637 : bool;
    var contribution_10 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_4 : vec3<f32>;
        var pdf_19 : f32;
        if(HitRecord_IsHit_0(hit_19))
        {
            mis_12 = hit_19.t_6;
        }
        else
        {
            mis_12 = 1.00000001504746622e+30f;
        }
        var _S638 : bool = IntersectAnalyticLights_0(ray_9.origin_0, ray_9.direction_0, mis_12, bounce_11 == u32(0), &(radiance_4), &(pdf_19));
        if(_S638)
        {
            var _S639 : bool = (bounce_11 > u32(0));
            if(_S639)
            {
                _S637 = (*s_36).path_0.lightsSampled_0;
            }
            else
            {
                _S637 = false;
            }
            if(_S637)
            {
                mis_12 = EvalMISRobust_0((*s_36).path_0.scatterPdf_0, pdf_19);
            }
            else
            {
                mis_12 = 1.0f;
            }
            var contribution_11 : vec3<f32> = (*s_36).path_0.throughput_7 * vec3<f32>(mis_12) * radiance_4;
            if((clampValue_10 > 0.0f))
            {
                _S637 = _S639;
            }
            else
            {
                _S637 = false;
            }
            if(_S637)
            {
                contribution_10 = min(contribution_11, vec3<f32>(clampValue_10));
            }
            else
            {
                contribution_10 = contribution_11;
            }
            (*s_36).path_0.radiance_1 = (*s_36).path_0.radiance_1 + contribution_10;
        }
    }
    if(!HitRecord_IsHit_0(hit_19))
    {
        if(bounce_11 == u32(0))
        {
            var visible_1 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_1)
            {
                contribution_10 = EvalEnvironment_0(ray_9.direction_0);
            }
            else
            {
                contribution_10 = gFrame_0.background_0.xyz;
            }
            (*s_36).path_0.radiance_1 = (*s_36).path_0.radiance_1 + contribution_10;
            if(visible_1)
            {
                _S637 = HitsSun_0(ray_9.direction_0);
            }
            else
            {
                _S637 = false;
            }
            if(_S637)
            {
                (*s_36).path_0.radiance_1 = (*s_36).path_0.radiance_1 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if((*s_36).path_0.lightsSampled_0)
            {
                mis_12 = EvalMISRobust_0((*s_36).path_0.scatterPdf_0, EnvironmentPdf_0(ray_9.direction_0));
            }
            else
            {
                mis_12 = 1.0f;
            }
            var contribution_12 : vec3<f32> = (*s_36).path_0.throughput_7 * vec3<f32>(mis_12) * EvalEnvironment_0(ray_9.direction_0);
            if(!(*s_36).path_0.lightsSampled_0)
            {
                _S637 = SunEnabled_0();
            }
            else
            {
                _S637 = false;
            }
            if(_S637)
            {
                _S637 = HitsSun_0(ray_9.direction_0);
            }
            else
            {
                _S637 = false;
            }
            if(_S637)
            {
                contribution_10 = contribution_12 + (*s_36).path_0.throughput_7 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_10 = contribution_12;
            }
            if((clampValue_10 > 0.0f))
            {
                contribution_10 = min(contribution_10, vec3<f32>(clampValue_10));
            }
            (*s_36).path_0.radiance_1 = (*s_36).path_0.radiance_1 + contribution_10;
        }
        (*s_36).active_0 = u32(0);
    }
    return hit_19;
}

fn PathState_x24init_0( radiance_5 : vec3<f32>,  throughput_42 : vec3<f32>,  origin_11 : vec3<f32>,  direction_2 : vec3<f32>,  scatterPdf_1 : f32,  lobe_7 : u32,  coneWidth_4 : f32,  coneSpread_1 : f32,  absorption_4 : vec3<f32>,  lightsSampled_1 : bool) -> PathState_0
{
    var _S640 : PathState_0;
    _S640.radiance_1 = radiance_5;
    _S640.throughput_7 = throughput_42;
    _S640.origin_3 = origin_11;
    _S640.direction_1 = direction_2;
    _S640.scatterPdf_0 = scatterPdf_1;
    _S640.lobe_2 = lobe_7;
    _S640.coneWidth_2 = coneWidth_4;
    _S640.coneSpread_0 = coneSpread_1;
    _S640.absorption_0 = absorption_4;
    _S640.lightsSampled_0 = lightsSampled_1;
    return _S640;
}

fn WavefrontPath_x24init_0( path_1 : PathState_0,  active_1 : u32,  randomSeed_1 : u32,  albedo_8 : vec3<f32>,  normal_22 : vec3<f32>) -> WavefrontPath_0
{
    var _S641 : WavefrontPath_0;
    _S641.path_0 = path_1;
    _S641.active_0 = active_1;
    _S641.randomSeed_0 = randomSeed_1;
    _S641.albedo_2 = albedo_8;
    _S641.normal_11 = normal_22;
    return _S641;
}

fn LoadShadingPath_0( base_26 : u32) -> WavefrontPath_0
{
    var _S642 : vec3<f32> = vec3<f32>(0.0f);
    var s_37 : WavefrontPath_0 = WavefrontPath_x24init_0(PathState_x24init_0(_S642, _S642, _S642, _S642, 0.0f, u32(0), 0.0f, 0.0f, _S642, false), u32(0), u32(0), _S642, _S642);
    s_37.active_0 = (bitcast<u32>((gAccum_0[base_26].w)));
    s_37.path_0.direction_1 = gAccum_0[Field_0(base_26, u32(3))].xyz;
    s_37.path_0.coneWidth_2 = gAccum_0[Field_0(base_26, u32(4))].w;
    s_37.path_0.coneSpread_0 = gAccum_0[Field_0(base_26, u32(5))].w;
    return s_37;
}

fn LoadFeedbackState_0( base_27 : u32)
{
    var state_0 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(base_27, u32(7))])));
    gVTRequest_0 = state_0.x;
    gVTRequestCount_0 = state_0.y;
    gVTRandom_0 = state_0.z;
    return;
}

fn StoreFeedbackState_0( base_28 : u32)
{
    gAccum_0[Field_0(base_28, u32(7))] = (bitcast<vec4<f32>>((vec4<u32>(gVTRequest_0, gVTRequestCount_0, gVTRandom_0, u32(0)))));
    return;
}

fn ShadeImpl_0( tid_0 : vec3<u32>)
{
    var _S643 : u32 = tid_0.x;
    if((_S643 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_29 : u32 = WorkBase_0(_S643);
    gAccum_0[Field_0(base_29, u32(11))] = vec4<f32>(0.0f);
    var s_38 : WavefrontPath_0 = LoadShadingPath_0(base_29);
    if((s_38.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_29);
    var hit_20 : HitRecord_0;
    hit_20.t_6 = gAccum_0[Field_0(base_29, u32(8))].x;
    hit_20.barycentrics_0 = gAccum_0[Field_0(base_29, u32(8))].yz;
    hit_20.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_29, u32(8))].w)));
    hit_20.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_29, u32(9))].x)));
    var _S644 : HitRecord_0 = hit_20;
    ShadePath_2(base_29, &(s_38), _S644, gWavefront_0.bounce_0);
    StorePath_0(base_29, s_38);
    StoreFeedbackState_0(base_29);
    return;
}

fn StorePath_1( base_30 : u32,  s_39 : WavefrontPath_0)
{
    gAccum_0[base_30] = vec4<f32>(s_39.path_0.radiance_1, (bitcast<f32>((s_39.active_0))));
    gAccum_0[Field_0(base_30, u32(1))] = vec4<f32>(s_39.path_0.throughput_7, (bitcast<f32>((s_39.randomSeed_0))));
    gAccum_0[Field_0(base_30, u32(2))] = vec4<f32>(s_39.path_0.origin_3, s_39.path_0.scatterPdf_0);
    gAccum_0[Field_0(base_30, u32(3))] = vec4<f32>(s_39.path_0.direction_1, (bitcast<f32>((select(u32(0), u32(1), s_39.path_0.lightsSampled_0)))));
    gAccum_0[Field_0(base_30, u32(4))] = vec4<f32>(s_39.path_0.absorption_0, s_39.path_0.coneWidth_2);
    gAccum_0[Field_0(base_30, u32(5))] = vec4<f32>(s_39.albedo_2, s_39.path_0.coneSpread_0);
    gAccum_0[Field_0(base_30, u32(6))] = vec4<f32>(s_39.normal_11, 0.0f);
    return;
}

fn ShadeImpl_1( tid_1 : vec3<u32>)
{
    var _S645 : u32 = tid_1.x;
    if((_S645 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_31 : u32 = WorkBase_0(_S645);
    gAccum_0[Field_0(base_31, u32(11))] = vec4<f32>(0.0f);
    var s_40 : WavefrontPath_0 = LoadShadingPath_0(base_31);
    if((s_40.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_31);
    var hit_21 : HitRecord_0;
    hit_21.t_6 = gAccum_0[Field_0(base_31, u32(8))].x;
    hit_21.barycentrics_0 = gAccum_0[Field_0(base_31, u32(8))].yz;
    hit_21.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_31, u32(8))].w)));
    hit_21.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_31, u32(9))].x)));
    var _S646 : HitRecord_0 = hit_21;
    ShadePath_3(base_31, &(s_40), _S646, u32(0));
    StorePath_1(base_31, s_40);
    StoreFeedbackState_0(base_31);
    return;
}

fn ShadeImpl_2( tid_2 : vec3<u32>)
{
    var _S647 : u32 = tid_2.x;
    if((_S647 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_32 : u32 = WorkBase_0(_S647);
    gAccum_0[Field_0(base_32, u32(11))] = vec4<f32>(0.0f);
    var s_41 : WavefrontPath_0 = LoadShadingPath_0(base_32);
    if((s_41.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_32);
    var hit_22 : HitRecord_0;
    hit_22.t_6 = gAccum_0[Field_0(base_32, u32(8))].x;
    hit_22.barycentrics_0 = gAccum_0[Field_0(base_32, u32(8))].yz;
    hit_22.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_32, u32(8))].w)));
    hit_22.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_32, u32(9))].x)));
    var _S648 : HitRecord_0 = hit_22;
    ShadePath_4(base_32, &(s_41), _S648, gWavefront_0.bounce_0);
    StorePath_1(base_32, s_41);
    StoreFeedbackState_0(base_32);
    return;
}

fn ShadeImpl_3( tid_3 : vec3<u32>)
{
    var _S649 : u32 = tid_3.x;
    if((_S649 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_33 : u32 = WorkBase_0(_S649);
    gAccum_0[Field_0(base_33, u32(11))] = vec4<f32>(0.0f);
    var s_42 : WavefrontPath_0 = LoadPath_0(base_33);
    if((s_42.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_33);
    var hit_23 : HitRecord_0;
    hit_23.t_6 = gAccum_0[Field_0(base_33, u32(8))].x;
    hit_23.barycentrics_0 = gAccum_0[Field_0(base_33, u32(8))].yz;
    hit_23.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_33, u32(8))].w)));
    hit_23.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_33, u32(9))].x)));
    var _S650 : HitRecord_0 = hit_23;
    ShadePath_5(base_33, &(s_42), _S650, gWavefront_0.bounce_0);
    StorePath_0(base_33, s_42);
    StoreFeedbackState_0(base_33);
    return;
}

fn ShadeImpl_4( tid_4 : vec3<u32>)
{
    var _S651 : u32 = tid_4.x;
    if((_S651 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_34 : u32 = WorkBase_0(_S651);
    gAccum_0[Field_0(base_34, u32(11))] = vec4<f32>(0.0f);
    var s_43 : WavefrontPath_0 = LoadPath_1(base_34);
    if((s_43.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_34);
    var hit_24 : HitRecord_0;
    hit_24.t_6 = gAccum_0[Field_0(base_34, u32(8))].x;
    hit_24.barycentrics_0 = gAccum_0[Field_0(base_34, u32(8))].yz;
    hit_24.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_34, u32(8))].w)));
    hit_24.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_34, u32(9))].x)));
    var _S652 : HitRecord_0 = hit_24;
    ShadePath_6(base_34, &(s_43), _S652, u32(0));
    StorePath_1(base_34, s_43);
    StoreFeedbackState_0(base_34);
    return;
}

fn ShadeQueueBase_0() -> u32
{
    return MainQueueBase_0() + (gWavefront_0.capacity_0 + u32(3)) / u32(4);
}

fn ShadeImpl_5( tid_5 : vec3<u32>)
{
    var _S653 : u32 = tid_5.x;
    if((_S653 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_35 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S653));
    gAccum_0[Field_0(base_35, u32(11))] = vec4<f32>(0.0f);
    var s_44 : WavefrontPath_0 = LoadShadingPath_0(base_35);
    if((s_44.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_35);
    var hit_25 : HitRecord_0;
    hit_25.t_6 = gAccum_0[Field_0(base_35, u32(8))].x;
    hit_25.barycentrics_0 = gAccum_0[Field_0(base_35, u32(8))].yz;
    hit_25.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_35, u32(8))].w)));
    hit_25.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_35, u32(9))].x)));
    var _S654 : HitRecord_0 = hit_25;
    ShadePath_2(base_35, &(s_44), _S654, gWavefront_0.bounce_0);
    StorePath_0(base_35, s_44);
    StoreFeedbackState_0(base_35);
    return;
}

fn ShadeImpl_6( tid_6 : vec3<u32>)
{
    var _S655 : u32 = tid_6.x;
    if((_S655 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_36 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S655));
    gAccum_0[Field_0(base_36, u32(11))] = vec4<f32>(0.0f);
    var s_45 : WavefrontPath_0 = LoadShadingPath_0(base_36);
    if((s_45.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_36);
    var hit_26 : HitRecord_0;
    hit_26.t_6 = gAccum_0[Field_0(base_36, u32(8))].x;
    hit_26.barycentrics_0 = gAccum_0[Field_0(base_36, u32(8))].yz;
    hit_26.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_36, u32(8))].w)));
    hit_26.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_36, u32(9))].x)));
    var _S656 : HitRecord_0 = hit_26;
    ShadePath_3(base_36, &(s_45), _S656, u32(0));
    StorePath_1(base_36, s_45);
    StoreFeedbackState_0(base_36);
    return;
}

fn ShadeImpl_7( tid_7 : vec3<u32>)
{
    var _S657 : u32 = tid_7.x;
    if((_S657 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_37 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S657));
    gAccum_0[Field_0(base_37, u32(11))] = vec4<f32>(0.0f);
    var s_46 : WavefrontPath_0 = LoadShadingPath_0(base_37);
    if((s_46.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_37);
    var hit_27 : HitRecord_0;
    hit_27.t_6 = gAccum_0[Field_0(base_37, u32(8))].x;
    hit_27.barycentrics_0 = gAccum_0[Field_0(base_37, u32(8))].yz;
    hit_27.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_37, u32(8))].w)));
    hit_27.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_37, u32(9))].x)));
    var _S658 : HitRecord_0 = hit_27;
    ShadePath_4(base_37, &(s_46), _S658, gWavefront_0.bounce_0);
    StorePath_1(base_37, s_46);
    StoreFeedbackState_0(base_37);
    return;
}

fn ShadeImpl_8( tid_8 : vec3<u32>)
{
    var _S659 : u32 = tid_8.x;
    if((_S659 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_38 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S659));
    gAccum_0[Field_0(base_38, u32(11))] = vec4<f32>(0.0f);
    var s_47 : WavefrontPath_0 = LoadPath_0(base_38);
    if((s_47.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_38);
    var hit_28 : HitRecord_0;
    hit_28.t_6 = gAccum_0[Field_0(base_38, u32(8))].x;
    hit_28.barycentrics_0 = gAccum_0[Field_0(base_38, u32(8))].yz;
    hit_28.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_38, u32(8))].w)));
    hit_28.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_38, u32(9))].x)));
    var _S660 : HitRecord_0 = hit_28;
    ShadePath_5(base_38, &(s_47), _S660, gWavefront_0.bounce_0);
    StorePath_0(base_38, s_47);
    StoreFeedbackState_0(base_38);
    return;
}

fn ShadeImpl_9( tid_9 : vec3<u32>)
{
    var _S661 : u32 = tid_9.x;
    if((_S661 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_39 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S661));
    gAccum_0[Field_0(base_39, u32(11))] = vec4<f32>(0.0f);
    var s_48 : WavefrontPath_0 = LoadPath_1(base_39);
    if((s_48.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_39);
    var hit_29 : HitRecord_0;
    hit_29.t_6 = gAccum_0[Field_0(base_39, u32(8))].x;
    hit_29.barycentrics_0 = gAccum_0[Field_0(base_39, u32(8))].yz;
    hit_29.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_39, u32(8))].w)));
    hit_29.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_39, u32(9))].x)));
    var _S662 : HitRecord_0 = hit_29;
    ShadePath_6(base_39, &(s_48), _S662, u32(0));
    StorePath_1(base_39, s_48);
    StoreFeedbackState_0(base_39);
    return;
}

fn EvalSampledEmission_0( index_19 : u32,  bary_9 : vec3<f32>,  viewer_4 : vec3<f32>,  cone_5 : vec2<f32>) -> vec3<f32>
{
    var light_5 : EmissiveTriangle_std430_0 = gLights_0[index_19];
    var _S663 : vec3<f32> = light_5.p0_0.xyz;
    var _S664 : f32 = bary_9.x;
    var _S665 : vec3<f32> = light_5.p1_0.xyz;
    var _S666 : f32 = bary_9.y;
    var _S667 : vec3<f32> = light_5.p2_0.xyz;
    var _S668 : f32 = bary_9.z;
    var position_3 : vec3<f32> = _S663 * vec3<f32>(_S664) + _S665 * vec3<f32>(_S666) + _S667 * vec3<f32>(_S668);
    var toLight_3 : vec3<f32> = position_3 - viewer_4;
    var dist_1 : f32 = length(toLight_3);
    var tc_10 : TextureCoords_0;
    var _S669 : vec2<f32> = light_5.uvA_0.xy;
    var _S670 : vec2<f32> = vec2<f32>(_S664);
    var _S671 : vec2<f32> = light_5.uvA_0.zw;
    var _S672 : vec2<f32> = vec2<f32>(_S666);
    var _S673 : vec2<f32> = light_5.uvB_0.xy;
    var _S674 : vec2<f32> = vec2<f32>(_S668);
    var _S675 : vec2<f32> = _S669 * _S670 + _S671 * _S672 + _S673 * _S674;
    var _S676 : vec2<f32> = light_5.uvB_0.zw;
    var _S677 : vec2<f32> = light_5.uvC_0.xy;
    var _S678 : vec2<f32> = light_5.uvC_0.zw;
    var _S679 : vec2<f32> = _S676 * _S670 + _S677 * _S672 + _S678 * _S674;
    var _S680 : vec3<f32> = _S665 - _S663;
    var _S681 : vec3<f32> = _S667 - _S663;
    var _S682 : vec2<f32> = _S671 - _S669;
    var _S683 : vec2<f32> = _S673 - _S669;
    var _S684 : vec2<f32> = _S677 - _S676;
    var _S685 : vec2<f32> = _S678 - _S676;
    var _S686 : f32 = cone_5.x + cone_5.y * dist_1;
    var _S687 : f32;
    if((dist_1 > 0.0f))
    {
        _S687 = dot(light_5.n_0.xyz, toLight_3) / dist_1;
    }
    else
    {
        _S687 = 1.0f;
    }
    tc_10 = MakeTextureCoords_0(_S675, _S679, _S680, _S681, _S682, _S683, _S684, _S685, _S686, _S687);
    tc_10.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((light_5.pad_0.x))), position_3);
    var _S688 : vec3<f32> = EmissiveRadiance_0(LoadMaterialHeader_0((bitcast<u32>((light_5.n_0.w)))), tc_10);
    return _S688;
}

fn ShadeLightImpl_0( tid_10 : vec3<u32>)
{
    var _S689 : u32 = tid_10.x;
    if((_S689 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_40 : u32 = WorkBase_0(_S689);
    var _S690 : u32 = Field_0(base_40, u32(11));
    var mask_5 : u32 = (bitcast<u32>((gAccum_0[_S690].z)));
    if(((mask_5 & (u32(8)))) == u32(0))
    {
        return;
    }
    var lightBase_1 : u32 = LightWorkBase_0(_S689);
    var viewer_5 : vec4<f32> = gAccum_0[Field_0(lightBase_1, u32(1))];
    LoadFeedbackState_0(base_40);
    var radiance_6 : vec3<f32> = EvalSampledEmission_0((bitcast<u32>((gAccum_0[lightBase_1].w))), gAccum_0[lightBase_1].xyz, gAccum_0[Field_0(lightBase_1, u32(1))].xyz, gAccum_0[_S690].xy);
    var mask_6 : u32;
    if(((mask_5 & (u32(2)))) != u32(0))
    {
        var _S691 : u32 = Field_0(base_40, u32(17));
        gAccum_0[_S691] = vec4<f32>(vec3<f32>(gAccum_0[_S691].w) * radiance_6 * gAccum_0[_S691].xyz / vec3<f32>(viewer_5.w), 0.0f);
        if(!(any(((radiance_6 > vec3<f32>(0.0f))))))
        {
            mask_6 = (mask_5 & (u32(4294967293)));
        }
        else
        {
            mask_6 = mask_5;
        }
    }
    else
    {
        mask_6 = mask_5;
    }
    gAccum_0[_S690][i32(2)] = (bitcast<f32>(((mask_6 & (u32(4294967287))))));
    StoreFeedbackState_0(base_40);
    return;
}

fn ShadeLightImpl_1( tid_11 : vec3<u32>)
{
    var _S692 : u32 = tid_11.x;
    if((_S692 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var _S693 : u32 = QueueIndex_0(ShadowQueueBase_0(), _S692);
    var base_41 : u32 = WorkBase_0(_S693);
    var _S694 : u32 = Field_0(base_41, u32(11));
    var mask_7 : u32 = (bitcast<u32>((gAccum_0[_S694].z)));
    if(((mask_7 & (u32(8)))) == u32(0))
    {
        return;
    }
    var lightBase_2 : u32 = LightWorkBase_0(_S693);
    var viewer_6 : vec4<f32> = gAccum_0[Field_0(lightBase_2, u32(1))];
    LoadFeedbackState_0(base_41);
    var radiance_7 : vec3<f32> = EvalSampledEmission_0((bitcast<u32>((gAccum_0[lightBase_2].w))), gAccum_0[lightBase_2].xyz, gAccum_0[Field_0(lightBase_2, u32(1))].xyz, gAccum_0[_S694].xy);
    var mask_8 : u32;
    if(((mask_7 & (u32(2)))) != u32(0))
    {
        var _S695 : u32 = Field_0(base_41, u32(17));
        gAccum_0[_S695] = vec4<f32>(vec3<f32>(gAccum_0[_S695].w) * radiance_7 * gAccum_0[_S695].xyz / vec3<f32>(viewer_6.w), 0.0f);
        if(!(any(((radiance_7 > vec3<f32>(0.0f))))))
        {
            mask_8 = (mask_7 & (u32(4294967293)));
        }
        else
        {
            mask_8 = mask_7;
        }
    }
    else
    {
        mask_8 = mask_7;
    }
    gAccum_0[_S694][i32(2)] = (bitcast<f32>(((mask_8 & (u32(4294967287))))));
    StoreFeedbackState_0(base_41);
    return;
}

fn ShadeImpl_10( tid_12 : vec3<u32>)
{
    var _S696 : u32 = BucketMetadataBase_0() + (countOneBits(u32(15)) + u32(1));
    var _S697 : u32 = tid_12.x;
    if((_S697 >= (bitcast<u32>((gAccum_0[_S696].x)))))
    {
        return;
    }
    var base_42 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), (bitcast<u32>((gAccum_0[_S696].y))) + _S697));
    gAccum_0[Field_0(base_42, u32(11))] = vec4<f32>(0.0f);
    var s_49 : WavefrontPath_0 = LoadPath_1(base_42);
    if((s_49.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_42);
    var hit_30 : HitRecord_0;
    hit_30.t_6 = gAccum_0[Field_0(base_42, u32(8))].x;
    hit_30.barycentrics_0 = gAccum_0[Field_0(base_42, u32(8))].yz;
    hit_30.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_42, u32(8))].w)));
    hit_30.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_42, u32(9))].x)));
    var _S698 : HitRecord_0 = hit_30;
    ShadePath_7(base_42, &(s_49), _S698, gWavefront_0.bounce_0);
    StorePath_1(base_42, s_49);
    StoreFeedbackState_0(base_42);
    return;
}

fn ShadeImpl_11( tid_13 : vec3<u32>)
{
    var _S699 : u32 = tid_13.x;
    if((_S699 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_43 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S699));
    if((bitcast<u32>((gAccum_0[base_43].w))) == u32(0))
    {
        return;
    }
    var _S700 : u32 = Field_0(base_43, u32(8));
    var _S701 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S700].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S701 >> (u32(21)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_43, u32(11))] = vec4<f32>(0.0f);
    var s_50 : WavefrontPath_0 = LoadPath_1(base_43);
    if((s_50.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_43);
    var hit_31 : HitRecord_0;
    hit_31.t_6 = gAccum_0[_S700].x;
    hit_31.barycentrics_0 = gAccum_0[_S700].yz;
    hit_31.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S700].w)));
    hit_31.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_43, u32(9))].x)));
    var _S702 : HitRecord_0 = hit_31;
    ShadePath_7(base_43, &(s_50), _S702, gWavefront_0.bounce_0);
    StorePath_1(base_43, s_50);
    StoreFeedbackState_0(base_43);
    return;
}

fn ShadeImpl_12( tid_14 : vec3<u32>)
{
    var _S703 : u32 = tid_14.x;
    if((_S703 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_44 : u32 = WorkBase_0(_S703);
    gAccum_0[Field_0(base_44, u32(11))] = vec4<f32>(0.0f);
    var s_51 : WavefrontPath_0 = LoadPath_1(base_44);
    if((s_51.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_44);
    var hit_32 : HitRecord_0;
    hit_32.t_6 = gAccum_0[Field_0(base_44, u32(8))].x;
    hit_32.barycentrics_0 = gAccum_0[Field_0(base_44, u32(8))].yz;
    hit_32.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_44, u32(8))].w)));
    hit_32.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_44, u32(9))].x)));
    var _S704 : HitRecord_0 = hit_32;
    ShadePath_7(base_44, &(s_51), _S704, gWavefront_0.bounce_0);
    StorePath_1(base_44, s_51);
    StoreFeedbackState_0(base_44);
    return;
}

fn ShadeImpl_13( tid_15 : vec3<u32>)
{
    var _S705 : u32 = tid_15.x;
    if((_S705 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_45 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S705));
    gAccum_0[Field_0(base_45, u32(11))] = vec4<f32>(0.0f);
    var s_52 : WavefrontPath_0 = LoadPath_1(base_45);
    if((s_52.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_45);
    var hit_33 : HitRecord_0;
    hit_33.t_6 = gAccum_0[Field_0(base_45, u32(8))].x;
    hit_33.barycentrics_0 = gAccum_0[Field_0(base_45, u32(8))].yz;
    hit_33.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_45, u32(8))].w)));
    hit_33.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_45, u32(9))].x)));
    var _S706 : HitRecord_0 = hit_33;
    ShadePath_7(base_45, &(s_52), _S706, gWavefront_0.bounce_0);
    StorePath_1(base_45, s_52);
    StoreFeedbackState_0(base_45);
    return;
}

fn ResolveShadowBatchImpl_0( tid_16 : vec3<u32>)
{
    var index_20 : u32;
    var _S707 : bool = ShadowBatchIndex_0(tid_16.x, &(index_20));
    if(!_S707)
    {
        return;
    }
    var base_46 : u32 = WorkBase_0(index_20);
    var _S708 : u32 = Field_0(base_46, u32(11));
    var _S709 : u32 = (bitcast<u32>((gAccum_0[_S708].z)));
    var _S710 : vec3<f32> = vec3<f32>(0.0f);
    var source_4 : u32 = u32(0);
    var sum_5 : vec3<f32> = _S710;
    loop
    {
        if((source_4 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((_S709 & (((u32(1) << (source_4)))))) != u32(0))
        {
            sum_5 = sum_5 + gAccum_0[Field_0(base_46, u32(14) + source_4 * u32(3))].xyz;
        }
        source_4 = source_4 + u32(1);
    }
    var contribution_13 : vec3<f32> = gAccum_0[Field_0(base_46, u32(10))].xyz * sum_5;
    var _S711 : f32 = gAccum_0[Field_0(base_46, u32(10))].w;
    var contribution_14 : vec3<f32>;
    if((_S711 > 0.0f))
    {
        contribution_14 = min(contribution_13, vec3<f32>(_S711));
    }
    else
    {
        contribution_14 = contribution_13;
    }
    var path_2 : vec4<f32> = gAccum_0[base_46];
    var _S712 : vec3<f32> = gAccum_0[base_46].xyz + contribution_14;
    path_2.x = _S712.x;
    path_2.y = _S712.y;
    path_2.z = _S712.z;
    gAccum_0[base_46] = path_2;
    gAccum_0[_S708] = vec4<f32>(0.0f);
    return;
}

var<private> gShadowBatchSkip_0 : u32;

fn TraverseBLAS_4( _S713 : u32,  _S714 : u32,  _S715 : vec3<f32>,  _S716 : vec3<f32>,  _S717 : f32,  _S718 : bool,  _S719 : ptr<function, HitRecord_0>) -> bool
{
    var found_17 : bool;
    var _S720 : vec3<f32> = SafeRcp_0(_S716);
    var _S721 : bool = (((gInstances_0[_S714].flags_0) & (u32(1)))) != u32(0);
    var stack_10 : array<u32, i32(48)>;
    var nodeRef_8 : u32 = u32(0);
    var found_18 : bool = false;
    var stackPtr_32 : u32 = u32(0);
    loop
    {
        var i_15 : u32;
        if(((nodeRef_8 & (u32(2147483648)))) != u32(0))
        {
            var _S722 : u32 = (((nodeRef_8 >> (u32(24)))) & (u32(127)));
            var _S723 : u32 = (nodeRef_8 & (u32(16777215)));
            found_17 = found_18;
            i_15 = u32(0);
            loop
            {
                if((i_15 < _S722))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_47 : u32 = (gInstances_0[_S714].blasTriOffset_0 + _S723 + i_15) * u32(3);
                var v0_6 : vec4<f32> = gTris_0[base_47];
                var t_18 : f32;
                var bary_10 : vec2<f32>;
                var _S724 : bool = IntersectTriangle_1(_S715, _S716, v0_6.xyz, gTris_0[base_47 + u32(1)].xyz, gTris_0[base_47 + u32(2)].xyz, _S717, (*_S719).t_6, &(t_18), &(bary_10));
                if(!_S724)
                {
                    i_15 = i_15 + u32(1);
                    continue;
                }
                var primitiveIndex_6 : u32 = (bitcast<u32>((v0_6.w)));
                if((gShadowBatchSkip_0 > u32(0)))
                {
                    gShadowBatchSkip_0 = gShadowBatchSkip_0 - u32(1);
                    i_15 = i_15 + u32(1);
                    continue;
                }
                var _S725 : bool;
                if(_S721)
                {
                    var _S726 : bool = AlphaTestRejects_0(_S714, primitiveIndex_6, bary_10, t_18);
                    _S725 = _S726;
                }
                else
                {
                    _S725 = false;
                }
                if(_S725)
                {
                    i_15 = i_15 + u32(1);
                    continue;
                }
                (*_S719).t_6 = t_18;
                (*_S719).barycentrics_0 = bary_10;
                (*_S719).instanceIndex_2 = _S713;
                (*_S719).primitiveIndex_1 = primitiveIndex_6;
                if(_S718)
                {
                    return true;
                }
                found_17 = true;
                i_15 = i_15 + u32(1);
            }
            if(stackPtr_32 == u32(0))
            {
                break;
            }
            var stackPtr_33 : u32 = stackPtr_32 - u32(1);
            nodeRef_8 = stack_10[stackPtr_33];
            found_18 = found_17;
            stackPtr_32 = stackPtr_33;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_8 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S714].blasNodeOffset_0 + nodeRef_8];
        var dist1_16 : f32 = IntersectBox_0(node_8.lmin_0, node_8.lmax_0, _S715, _S720, _S717, (*_S719).t_6);
        var dist2_16 : f32 = IntersectBox_0(node_8.rmin_0, node_8.rmax_0, _S715, _S720, _S717, (*_S719).t_6);
        var far_8 : u32;
        var dist1_17 : f32;
        var dist2_17 : f32;
        if((dist1_16 > dist2_16))
        {
            dist1_17 = dist2_16;
            i_15 = node_8.right_0;
            dist2_17 = dist1_16;
            far_8 = node_8.left_0;
        }
        else
        {
            dist1_17 = dist1_16;
            i_15 = node_8.left_0;
            dist2_17 = dist2_16;
            far_8 = node_8.right_0;
        }
        if(dist1_17 == 1.00000001504746622e+30f)
        {
            if(stackPtr_32 == u32(0))
            {
                found_17 = found_18;
                break;
            }
            var stackPtr_34 : u32 = stackPtr_32 - u32(1);
            nodeRef_8 = stack_10[stackPtr_34];
            stackPtr_32 = stackPtr_34;
        }
        else
        {
            if(dist2_17 != 1.00000001504746622e+30f)
            {
                found_17 = (stackPtr_32 < u32(48));
            }
            else
            {
                found_17 = false;
            }
            var stackPtr_35 : u32;
            if(found_17)
            {
                var _S727 : u32 = stackPtr_32 + u32(1);
                stack_10[stackPtr_32] = far_8;
                stackPtr_35 = _S727;
            }
            else
            {
                stackPtr_35 = stackPtr_32;
            }
            nodeRef_8 = i_15;
            stackPtr_32 = stackPtr_35;
        }
    }
    return found_17;
}

fn TraceScene_4( ray_10 : Ray_0,  anyHit_4 : bool,  hit_34 : ptr<function, HitRecord_0>) -> bool
{
    var found_19 : bool;
    (*hit_34).t_6 = ray_10.tMax_0;
    (*hit_34).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_34).instanceIndex_2 = u32(4294967295);
    (*hit_34).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S728 : u32 = gFrame_0.counts_0.z;
    var _S729 : vec3<f32> = SafeRcp_0(ray_10.direction_0);
    var stack_11 : array<u32, i32(32)>;
    var nodeRef_9 : u32 = u32(0);
    var found_20 : bool = false;
    var stackPtr_36 : u32 = u32(0);
    loop
    {
        var i_16 : u32;
        if(((nodeRef_9 & (u32(2147483648)))) != u32(0))
        {
            var _S730 : u32 = (((nodeRef_9 >> (u32(24)))) & (u32(127)));
            var _S731 : u32 = (nodeRef_9 & (u32(16777215)));
            found_19 = found_20;
            i_16 = u32(0);
            loop
            {
                if((i_16 < _S730))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_7 : u32 = gIndices_0[_S728 + _S731 + i_16];
                var _S732 : bool = TraverseBLAS_4(instanceIndex_7, instanceIndex_7, InverseTransformPoint_0(instanceIndex_7, ray_10.origin_0), InverseTransformVector_0(instanceIndex_7, ray_10.direction_0), ray_10.tMin_0, anyHit_4, &((*hit_34)));
                if(_S732)
                {
                    if(anyHit_4)
                    {
                        return true;
                    }
                    found_19 = true;
                }
                i_16 = i_16 + u32(1);
            }
            if(stackPtr_36 == u32(0))
            {
                break;
            }
            var stackPtr_37 : u32 = stackPtr_36 - u32(1);
            nodeRef_9 = stack_11[stackPtr_37];
            found_20 = found_19;
            stackPtr_36 = stackPtr_37;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_9 : BVHNode_std430_0 = gNodes_0[nodeRef_9];
        var dist1_18 : f32 = IntersectBox_0(node_9.lmin_0, node_9.lmax_0, ray_10.origin_0, _S729, ray_10.tMin_0, (*hit_34).t_6);
        var dist2_18 : f32 = IntersectBox_0(node_9.rmin_0, node_9.rmax_0, ray_10.origin_0, _S729, ray_10.tMin_0, (*hit_34).t_6);
        var far_9 : u32;
        var dist1_19 : f32;
        var dist2_19 : f32;
        if((dist1_18 > dist2_18))
        {
            dist1_19 = dist2_18;
            i_16 = node_9.right_0;
            dist2_19 = dist1_18;
            far_9 = node_9.left_0;
        }
        else
        {
            dist1_19 = dist1_18;
            i_16 = node_9.left_0;
            dist2_19 = dist2_18;
            far_9 = node_9.right_0;
        }
        if(dist1_19 == 1.00000001504746622e+30f)
        {
            if(stackPtr_36 == u32(0))
            {
                found_19 = found_20;
                break;
            }
            var stackPtr_38 : u32 = stackPtr_36 - u32(1);
            nodeRef_9 = stack_11[stackPtr_38];
            stackPtr_36 = stackPtr_38;
        }
        else
        {
            if(dist2_19 != 1.00000001504746622e+30f)
            {
                found_19 = (stackPtr_36 < u32(32));
            }
            else
            {
                found_19 = false;
            }
            var stackPtr_39 : u32;
            if(found_19)
            {
                var _S733 : u32 = stackPtr_36 + u32(1);
                stack_11[stackPtr_36] = far_9;
                stackPtr_39 = _S733;
            }
            else
            {
                stackPtr_39 = stackPtr_36;
            }
            nodeRef_9 = i_16;
            stackPtr_36 = stackPtr_39;
        }
    }
    return found_19;
}

fn TraceOcclusionResume_0( ray_11 : Ray_0,  skipped_0 : u32) -> bool
{
    gShadowBatchSkip_0 = skipped_0;
    var hit_35 : HitRecord_0;
    var _S734 : bool = TraceScene_4(ray_11, true, &(hit_35));
    return _S734;
}

fn FinishShadowBatchImpl_0( tid_17 : vec3<u32>)
{
    var index_21 : u32;
    var _S735 : bool = ShadowBatchIndex_0(tid_17.x, &(index_21));
    if(!_S735)
    {
        return;
    }
    var base_48 : u32 = WorkBase_0(index_21);
    var state_1 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(LightWorkBase_0(index_21), u32(2))])));
    var _S736 : u32 = state_1.x;
    if((_S736 >= u32(3)))
    {
        return;
    }
    LoadFeedbackState_0(base_48);
    var _S737 : u32 = Field_0(base_48, u32(11));
    gRayCone_0 = gAccum_0[_S737].xy;
    var _S738 : u32 = (bitcast<u32>((gAccum_0[_S737].z)));
    var source_5 : u32 = _S736;
    var mask_9 : u32 = _S738;
    loop
    {
        if((source_5 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var _S739 : u32 = (u32(1) << (source_5));
        if(((mask_9 & (_S739))) == u32(0))
        {
            source_5 = source_5 + u32(1);
            continue;
        }
        var offset_3 : u32 = u32(12) + source_5 * u32(3);
        var origin_12 : vec4<f32> = gAccum_0[Field_0(base_48, offset_3)];
        var direction_3 : vec4<f32> = gAccum_0[Field_0(base_48, offset_3 + u32(1))];
        var mask_10 : u32;
        var _S740 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_48, offset_3 + u32(1))].w))) != u32(0))
        {
            var _S741 : Ray_0 = Ray_x24init_0(origin_12.xyz, direction_3.xyz, origin_12.w);
            if(source_5 == _S736)
            {
                mask_10 = state_1.y;
            }
            else
            {
                mask_10 = u32(0);
            }
            var _S742 : bool = TraceOcclusionResume_0(_S741, mask_10);
            _S740 = _S742;
        }
        else
        {
            _S740 = false;
        }
        if(_S740)
        {
            mask_10 = (mask_9 & ((~_S739)));
        }
        else
        {
            mask_10 = mask_9;
        }
        mask_9 = mask_10;
        source_5 = source_5 + u32(1);
    }
    gAccum_0[_S737][i32(2)] = (bitcast<f32>((mask_9)));
    StoreFeedbackState_0(base_48);
    return;
}

fn EvaluateShadowBatchImpl_0( tid_18 : vec3<u32>)
{
    var _S743 : u32;
    var blocked_0 : bool;
    var index_22 : u32;
    var _S744 : bool = ShadowBatchIndex_0(tid_18.x, &(index_22));
    if(!_S744)
    {
        return;
    }
    var base_49 : u32 = WorkBase_0(index_22);
    var aux_0 : u32 = LightWorkBase_0(index_22);
    var _S745 : u32 = Field_0(aux_0, u32(2));
    var state_2 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[_S745])));
    var _S746 : u32 = state_2.x;
    if((_S746 >= u32(3)))
    {
        return;
    }
    LoadFeedbackState_0(base_49);
    var _S747 : u32 = Field_0(base_49, u32(11));
    gRayCone_0 = gAccum_0[_S747].xy;
    var i_17 : u32 = u32(0);
    loop
    {
        var _S748 : u32 = state_2.z;
        _S743 = _S748;
        if((i_17 < _S748))
        {
        }
        else
        {
            blocked_0 = false;
            break;
        }
        var _S749 : u32 = i_17 * u32(2);
        var hit_36 : vec4<f32> = gAccum_0[Field_0(aux_0, u32(3) + _S749)];
        var _S750 : u32 = (bitcast<u32>((gAccum_0[Field_0(aux_0, u32(3) + _S749)].w)));
        var primitive_0 : u32 = (bitcast<u32>((gAccum_0[Field_0(aux_0, u32(4) + _S749)].x)));
        if((((gInstances_0[_S750].flags_0) & (u32(1)))) == u32(0))
        {
            blocked_0 = true;
        }
        else
        {
            var _S751 : bool = AlphaTestRejects_0(_S750, primitive_0, hit_36.yz, hit_36.x);
            blocked_0 = !_S751;
        }
        if(blocked_0)
        {
            blocked_0 = true;
            break;
        }
        i_17 = i_17 + u32(1);
    }
    if(blocked_0)
    {
        gAccum_0[_S747][i32(2)] = (bitcast<f32>((((bitcast<u32>((gAccum_0[_S747].z))) & ((~((u32(1) << (_S746)))))))));
    }
    if(blocked_0)
    {
        blocked_0 = true;
    }
    else
    {
        blocked_0 = (state_2.w) != u32(0);
    }
    var state_3 : vec4<u32>;
    if(blocked_0)
    {
        state_3 = vec4<u32>(_S746 + u32(1), u32(0), u32(0), u32(0));
    }
    else
    {
        state_3 = vec4<u32>(_S746, state_2.y + _S743, u32(0), u32(0));
    }
    gAccum_0[_S745] = (bitcast<vec4<f32>>((state_3)));
    StoreFeedbackState_0(base_49);
    return;
}

var<private> gShadowBatchCount_0 : u32;

var<private> gShadowBatchComplete_0 : bool;

var<private> gShadowBatch_0 : array<HitRecord_0, i32(4)>;

fn TraverseBLAS_5( _S752 : u32,  _S753 : u32,  _S754 : vec3<f32>,  _S755 : vec3<f32>,  _S756 : f32,  _S757 : bool,  _S758 : ptr<function, HitRecord_0>) -> bool
{
    var _S759 : vec3<f32> = SafeRcp_0(_S755);
    var stack_12 : array<u32, i32(48)>;
    var nodeRef_10 : u32 = u32(0);
    var stackPtr_40 : u32 = u32(0);
    loop
    {
        var i_18 : u32;
        var _S760 : bool;
        if(((nodeRef_10 & (u32(2147483648)))) != u32(0))
        {
            var _S761 : u32 = (((nodeRef_10 >> (u32(24)))) & (u32(127)));
            var _S762 : u32 = (nodeRef_10 & (u32(16777215)));
            i_18 = u32(0);
            loop
            {
                if((i_18 < _S761))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_50 : u32 = (gInstances_0[_S753].blasTriOffset_0 + _S762 + i_18) * u32(3);
                var v0_7 : vec4<f32> = gTris_0[base_50];
                var t_19 : f32;
                var bary_11 : vec2<f32>;
                var _S763 : bool = IntersectTriangle_1(_S754, _S755, v0_7.xyz, gTris_0[base_50 + u32(1)].xyz, gTris_0[base_50 + u32(2)].xyz, _S756, (*_S758).t_6, &(t_19), &(bary_11));
                if(!_S763)
                {
                    i_18 = i_18 + u32(1);
                    continue;
                }
                var primitiveIndex_7 : u32 = (bitcast<u32>((v0_7.w)));
                if((gShadowBatchSkip_0 > u32(0)))
                {
                    gShadowBatchSkip_0 = gShadowBatchSkip_0 - u32(1);
                    i_18 = i_18 + u32(1);
                    continue;
                }
                var candidate_0 : HitRecord_0;
                candidate_0.t_6 = t_19;
                candidate_0.barycentrics_0 = bary_11;
                candidate_0.instanceIndex_2 = _S752;
                candidate_0.primitiveIndex_1 = primitiveIndex_7;
                var _S764 : u32 = gShadowBatchCount_0;
                gShadowBatchCount_0 = gShadowBatchCount_0 + u32(1);
                gShadowBatch_0[_S764] = candidate_0;
                var _S765 : bool = (((gInstances_0[_S753].flags_0) & (u32(1)))) == u32(0);
                gShadowBatchComplete_0 = _S765;
                if(_S765)
                {
                    _S760 = true;
                }
                else
                {
                    _S760 = gShadowBatchCount_0 == u32(4);
                }
                if(_S760)
                {
                    return true;
                }
                i_18 = i_18 + u32(1);
            }
            if(stackPtr_40 == u32(0))
            {
                break;
            }
            var stackPtr_41 : u32 = stackPtr_40 - u32(1);
            nodeRef_10 = stack_12[stackPtr_41];
            stackPtr_40 = stackPtr_41;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_10 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S753].blasNodeOffset_0 + nodeRef_10];
        var dist1_20 : f32 = IntersectBox_0(node_10.lmin_0, node_10.lmax_0, _S754, _S759, _S756, (*_S758).t_6);
        var dist2_20 : f32 = IntersectBox_0(node_10.rmin_0, node_10.rmax_0, _S754, _S759, _S756, (*_S758).t_6);
        var far_10 : u32;
        var dist1_21 : f32;
        var dist2_21 : f32;
        if((dist1_20 > dist2_20))
        {
            dist1_21 = dist2_20;
            i_18 = node_10.right_0;
            dist2_21 = dist1_20;
            far_10 = node_10.left_0;
        }
        else
        {
            dist1_21 = dist1_20;
            i_18 = node_10.left_0;
            dist2_21 = dist2_20;
            far_10 = node_10.right_0;
        }
        if(dist1_21 == 1.00000001504746622e+30f)
        {
            if(stackPtr_40 == u32(0))
            {
                break;
            }
            var stackPtr_42 : u32 = stackPtr_40 - u32(1);
            nodeRef_10 = stack_12[stackPtr_42];
            stackPtr_40 = stackPtr_42;
        }
        else
        {
            if(dist2_21 != 1.00000001504746622e+30f)
            {
                _S760 = (stackPtr_40 < u32(48));
            }
            else
            {
                _S760 = false;
            }
            var stackPtr_43 : u32;
            if(_S760)
            {
                var _S766 : u32 = stackPtr_40 + u32(1);
                stack_12[stackPtr_40] = far_10;
                stackPtr_43 = _S766;
            }
            else
            {
                stackPtr_43 = stackPtr_40;
            }
            nodeRef_10 = i_18;
            stackPtr_40 = stackPtr_43;
        }
    }
    return false;
}

fn TraceScene_5( ray_12 : Ray_0,  anyHit_5 : bool,  hit_37 : ptr<function, HitRecord_0>) -> bool
{
    var found_21 : bool;
    (*hit_37).t_6 = ray_12.tMax_0;
    (*hit_37).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_37).instanceIndex_2 = u32(4294967295);
    (*hit_37).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S767 : u32 = gFrame_0.counts_0.z;
    var _S768 : vec3<f32> = SafeRcp_0(ray_12.direction_0);
    var stack_13 : array<u32, i32(32)>;
    var nodeRef_11 : u32 = u32(0);
    var found_22 : bool = false;
    var stackPtr_44 : u32 = u32(0);
    loop
    {
        var i_19 : u32;
        if(((nodeRef_11 & (u32(2147483648)))) != u32(0))
        {
            var _S769 : u32 = (((nodeRef_11 >> (u32(24)))) & (u32(127)));
            var _S770 : u32 = (nodeRef_11 & (u32(16777215)));
            found_21 = found_22;
            i_19 = u32(0);
            loop
            {
                if((i_19 < _S769))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_8 : u32 = gIndices_0[_S767 + _S770 + i_19];
                var _S771 : bool = TraverseBLAS_5(instanceIndex_8, instanceIndex_8, InverseTransformPoint_0(instanceIndex_8, ray_12.origin_0), InverseTransformVector_0(instanceIndex_8, ray_12.direction_0), ray_12.tMin_0, anyHit_5, &((*hit_37)));
                if(_S771)
                {
                    if(anyHit_5)
                    {
                        return true;
                    }
                    found_21 = true;
                }
                i_19 = i_19 + u32(1);
            }
            if(stackPtr_44 == u32(0))
            {
                break;
            }
            var stackPtr_45 : u32 = stackPtr_44 - u32(1);
            nodeRef_11 = stack_13[stackPtr_45];
            found_22 = found_21;
            stackPtr_44 = stackPtr_45;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_11 : BVHNode_std430_0 = gNodes_0[nodeRef_11];
        var dist1_22 : f32 = IntersectBox_0(node_11.lmin_0, node_11.lmax_0, ray_12.origin_0, _S768, ray_12.tMin_0, (*hit_37).t_6);
        var dist2_22 : f32 = IntersectBox_0(node_11.rmin_0, node_11.rmax_0, ray_12.origin_0, _S768, ray_12.tMin_0, (*hit_37).t_6);
        var far_11 : u32;
        var dist1_23 : f32;
        var dist2_23 : f32;
        if((dist1_22 > dist2_22))
        {
            dist1_23 = dist2_22;
            i_19 = node_11.right_0;
            dist2_23 = dist1_22;
            far_11 = node_11.left_0;
        }
        else
        {
            dist1_23 = dist1_22;
            i_19 = node_11.left_0;
            dist2_23 = dist2_22;
            far_11 = node_11.right_0;
        }
        if(dist1_23 == 1.00000001504746622e+30f)
        {
            if(stackPtr_44 == u32(0))
            {
                found_21 = found_22;
                break;
            }
            var stackPtr_46 : u32 = stackPtr_44 - u32(1);
            nodeRef_11 = stack_13[stackPtr_46];
            stackPtr_44 = stackPtr_46;
        }
        else
        {
            if(dist2_23 != 1.00000001504746622e+30f)
            {
                found_21 = (stackPtr_44 < u32(32));
            }
            else
            {
                found_21 = false;
            }
            var stackPtr_47 : u32;
            if(found_21)
            {
                var _S772 : u32 = stackPtr_44 + u32(1);
                stack_13[stackPtr_44] = far_11;
                stackPtr_47 = _S772;
            }
            else
            {
                stackPtr_47 = stackPtr_44;
            }
            nodeRef_11 = i_19;
            stackPtr_44 = stackPtr_47;
        }
    }
    return found_21;
}

fn TraceShadowBatch_0( ray_13 : Ray_0,  skipped_1 : u32)
{
    gShadowBatchCount_0 = u32(0);
    gShadowBatchSkip_0 = skipped_1;
    gShadowBatchComplete_0 = false;
    var hit_38 : HitRecord_0;
    var _S773 : bool = TraceScene_5(ray_13, true, &(hit_38));
    if(!_S773)
    {
        gShadowBatchComplete_0 = true;
    }
    return;
}

fn CollectShadowBatchImpl_0( tid_19 : vec3<u32>)
{
    var index_23 : u32;
    var _S774 : bool = ShadowBatchIndex_0(tid_19.x, &(index_23));
    if(!_S774)
    {
        return;
    }
    var base_51 : u32 = WorkBase_0(index_23);
    var aux_1 : u32 = LightWorkBase_0(index_23);
    var state_4 : vec4<u32>;
    var _S775 : u32 = Field_0(aux_1, u32(2));
    state_4 = (bitcast<vec4<u32>>((gAccum_0[_S775])));
    var _S776 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_51, u32(11))].z)));
    loop
    {
        if(((state_4.x) < u32(3)))
        {
        }
        else
        {
            break;
        }
        var offset_4 : u32 = u32(12) + state_4.x * u32(3);
        var direction_4 : vec4<f32> = gAccum_0[Field_0(base_51, offset_4 + u32(1))];
        var _S777 : bool;
        if(((_S776 & (((u32(1) << ((state_4.x))))))) != u32(0))
        {
            _S777 = (bitcast<u32>((direction_4.w))) != u32(0);
        }
        else
        {
            _S777 = false;
        }
        if(_S777)
        {
            TraceShadowBatch_0(Ray_x24init_0(gAccum_0[Field_0(base_51, offset_4)].xyz, direction_4.xyz, gAccum_0[Field_0(base_51, offset_4)].w), state_4.y);
            state_4[i32(2)] = gShadowBatchCount_0;
            var i_20 : u32;
            if(gShadowBatchComplete_0)
            {
                i_20 = u32(1);
            }
            else
            {
                i_20 = u32(0);
            }
            state_4[i32(3)] = i_20;
            i_20 = u32(0);
            loop
            {
                if((i_20 < (state_4.z)))
                {
                }
                else
                {
                    break;
                }
                var _S778 : u32 = i_20 * u32(2);
                gAccum_0[Field_0(aux_1, u32(3) + _S778)] = vec4<f32>(gShadowBatch_0[i_20].t_6, gShadowBatch_0[i_20].barycentrics_0, (bitcast<f32>((gShadowBatch_0[i_20].instanceIndex_2))));
                gAccum_0[Field_0(aux_1, u32(4) + _S778)] = vec4<f32>((bitcast<f32>((gShadowBatch_0[i_20].primitiveIndex_1))), 0.0f, 0.0f, 0.0f);
                i_20 = i_20 + u32(1);
            }
            break;
        }
        state_4 = vec4<u32>(state_4.x + u32(1), u32(0), u32(0), u32(0));
    }
    gAccum_0[_S775] = (bitcast<vec4<f32>>((state_4)));
    return;
}

fn CollectShadowBatchImpl_1( tid_20 : vec3<u32>)
{
    var index_24 : u32;
    var _S779 : bool = ShadowBatchIndex_0(tid_20.x, &(index_24));
    if(!_S779)
    {
        return;
    }
    var base_52 : u32 = WorkBase_0(index_24);
    var aux_2 : u32 = LightWorkBase_0(index_24);
    var state_5 : vec4<u32>;
    state_5 = vec4<u32>(u32(0));
    var _S780 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_52, u32(11))].z)));
    loop
    {
        if(((state_5.x) < u32(3)))
        {
        }
        else
        {
            break;
        }
        var offset_5 : u32 = u32(12) + state_5.x * u32(3);
        var direction_5 : vec4<f32> = gAccum_0[Field_0(base_52, offset_5 + u32(1))];
        var _S781 : bool;
        if(((_S780 & (((u32(1) << ((state_5.x))))))) != u32(0))
        {
            _S781 = (bitcast<u32>((direction_5.w))) != u32(0);
        }
        else
        {
            _S781 = false;
        }
        if(_S781)
        {
            TraceShadowBatch_0(Ray_x24init_0(gAccum_0[Field_0(base_52, offset_5)].xyz, direction_5.xyz, gAccum_0[Field_0(base_52, offset_5)].w), state_5.y);
            state_5[i32(2)] = gShadowBatchCount_0;
            var i_21 : u32;
            if(gShadowBatchComplete_0)
            {
                i_21 = u32(1);
            }
            else
            {
                i_21 = u32(0);
            }
            state_5[i32(3)] = i_21;
            i_21 = u32(0);
            loop
            {
                if((i_21 < (state_5.z)))
                {
                }
                else
                {
                    break;
                }
                var _S782 : u32 = i_21 * u32(2);
                gAccum_0[Field_0(aux_2, u32(3) + _S782)] = vec4<f32>(gShadowBatch_0[i_21].t_6, gShadowBatch_0[i_21].barycentrics_0, (bitcast<f32>((gShadowBatch_0[i_21].instanceIndex_2))));
                gAccum_0[Field_0(aux_2, u32(4) + _S782)] = vec4<f32>((bitcast<f32>((gShadowBatch_0[i_21].primitiveIndex_1))), 0.0f, 0.0f, 0.0f);
                i_21 = i_21 + u32(1);
            }
            break;
        }
        state_5 = vec4<u32>(state_5.x + u32(1), u32(0), u32(0), u32(0));
    }
    gAccum_0[Field_0(aux_2, u32(2))] = (bitcast<vec4<f32>>((state_5)));
    return;
}

fn ResolveShadowBatchImpl_1( tid_21 : vec3<u32>)
{
    var index_25 : u32;
    var _S783 : bool = ShadowBatchIndex_1(tid_21.x, &(index_25));
    if(!_S783)
    {
        return;
    }
    var base_53 : u32 = WorkBase_0(index_25);
    var _S784 : u32 = Field_0(base_53, u32(11));
    var _S785 : u32 = (bitcast<u32>((gAccum_0[_S784].z)));
    var _S786 : vec3<f32> = vec3<f32>(0.0f);
    var source_6 : u32 = u32(0);
    var sum_6 : vec3<f32> = _S786;
    loop
    {
        if((source_6 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((_S785 & (((u32(1) << (source_6)))))) != u32(0))
        {
            sum_6 = sum_6 + gAccum_0[Field_0(base_53, u32(14) + source_6 * u32(3))].xyz;
        }
        source_6 = source_6 + u32(1);
    }
    var contribution_15 : vec3<f32> = gAccum_0[Field_0(base_53, u32(10))].xyz * sum_6;
    var _S787 : f32 = gAccum_0[Field_0(base_53, u32(10))].w;
    var contribution_16 : vec3<f32>;
    if((_S787 > 0.0f))
    {
        contribution_16 = min(contribution_15, vec3<f32>(_S787));
    }
    else
    {
        contribution_16 = contribution_15;
    }
    var path_3 : vec4<f32> = gAccum_0[base_53];
    var _S788 : vec3<f32> = gAccum_0[base_53].xyz + contribution_16;
    path_3.x = _S788.x;
    path_3.y = _S788.y;
    path_3.z = _S788.z;
    gAccum_0[base_53] = path_3;
    gAccum_0[_S784] = vec4<f32>(0.0f);
    return;
}

fn FinishShadowBatchImpl_1( tid_22 : vec3<u32>)
{
    var index_26 : u32;
    var _S789 : bool = ShadowBatchIndex_1(tid_22.x, &(index_26));
    if(!_S789)
    {
        return;
    }
    var base_54 : u32 = WorkBase_0(index_26);
    var state_6 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(LightWorkBase_0(index_26), u32(2))])));
    var _S790 : u32 = state_6.x;
    if((_S790 >= u32(3)))
    {
        return;
    }
    LoadFeedbackState_0(base_54);
    var _S791 : u32 = Field_0(base_54, u32(11));
    gRayCone_0 = gAccum_0[_S791].xy;
    var _S792 : u32 = (bitcast<u32>((gAccum_0[_S791].z)));
    var source_7 : u32 = _S790;
    var mask_11 : u32 = _S792;
    loop
    {
        if((source_7 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var _S793 : u32 = (u32(1) << (source_7));
        if(((mask_11 & (_S793))) == u32(0))
        {
            source_7 = source_7 + u32(1);
            continue;
        }
        var offset_6 : u32 = u32(12) + source_7 * u32(3);
        var origin_13 : vec4<f32> = gAccum_0[Field_0(base_54, offset_6)];
        var direction_6 : vec4<f32> = gAccum_0[Field_0(base_54, offset_6 + u32(1))];
        var mask_12 : u32;
        var _S794 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_54, offset_6 + u32(1))].w))) != u32(0))
        {
            var _S795 : Ray_0 = Ray_x24init_0(origin_13.xyz, direction_6.xyz, origin_13.w);
            if(source_7 == _S790)
            {
                mask_12 = state_6.y;
            }
            else
            {
                mask_12 = u32(0);
            }
            var _S796 : bool = TraceOcclusionResume_0(_S795, mask_12);
            _S794 = _S796;
        }
        else
        {
            _S794 = false;
        }
        if(_S794)
        {
            mask_12 = (mask_11 & ((~_S793)));
        }
        else
        {
            mask_12 = mask_11;
        }
        mask_11 = mask_12;
        source_7 = source_7 + u32(1);
    }
    gAccum_0[_S791][i32(2)] = (bitcast<f32>((mask_11)));
    StoreFeedbackState_0(base_54);
    return;
}

fn EvaluateShadowBatchImpl_1( tid_23 : vec3<u32>)
{
    var _S797 : u32;
    var blocked_1 : bool;
    var index_27 : u32;
    var _S798 : bool = ShadowBatchIndex_1(tid_23.x, &(index_27));
    if(!_S798)
    {
        return;
    }
    var base_55 : u32 = WorkBase_0(index_27);
    var aux_3 : u32 = LightWorkBase_0(index_27);
    var _S799 : u32 = Field_0(aux_3, u32(2));
    var state_7 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[_S799])));
    var _S800 : u32 = state_7.x;
    if((_S800 >= u32(3)))
    {
        return;
    }
    LoadFeedbackState_0(base_55);
    var _S801 : u32 = Field_0(base_55, u32(11));
    gRayCone_0 = gAccum_0[_S801].xy;
    var i_22 : u32 = u32(0);
    loop
    {
        var _S802 : u32 = state_7.z;
        _S797 = _S802;
        if((i_22 < _S802))
        {
        }
        else
        {
            blocked_1 = false;
            break;
        }
        var _S803 : u32 = i_22 * u32(2);
        var hit_39 : vec4<f32> = gAccum_0[Field_0(aux_3, u32(3) + _S803)];
        var _S804 : u32 = (bitcast<u32>((gAccum_0[Field_0(aux_3, u32(3) + _S803)].w)));
        var primitive_1 : u32 = (bitcast<u32>((gAccum_0[Field_0(aux_3, u32(4) + _S803)].x)));
        if((((gInstances_0[_S804].flags_0) & (u32(1)))) == u32(0))
        {
            blocked_1 = true;
        }
        else
        {
            var _S805 : bool = AlphaTestRejects_0(_S804, primitive_1, hit_39.yz, hit_39.x);
            blocked_1 = !_S805;
        }
        if(blocked_1)
        {
            blocked_1 = true;
            break;
        }
        i_22 = i_22 + u32(1);
    }
    if(blocked_1)
    {
        gAccum_0[_S801][i32(2)] = (bitcast<f32>((((bitcast<u32>((gAccum_0[_S801].z))) & ((~((u32(1) << (_S800)))))))));
    }
    if(blocked_1)
    {
        blocked_1 = true;
    }
    else
    {
        blocked_1 = (state_7.w) != u32(0);
    }
    var state_8 : vec4<u32>;
    if(blocked_1)
    {
        state_8 = vec4<u32>(_S800 + u32(1), u32(0), u32(0), u32(0));
    }
    else
    {
        state_8 = vec4<u32>(_S800, state_7.y + _S797, u32(0), u32(0));
    }
    gAccum_0[_S799] = (bitcast<vec4<f32>>((state_8)));
    StoreFeedbackState_0(base_55);
    return;
}

fn CollectShadowBatchImpl_2( tid_24 : vec3<u32>)
{
    var index_28 : u32;
    var _S806 : bool = ShadowBatchIndex_1(tid_24.x, &(index_28));
    if(!_S806)
    {
        return;
    }
    var base_56 : u32 = WorkBase_0(index_28);
    var aux_4 : u32 = LightWorkBase_0(index_28);
    var state_9 : vec4<u32>;
    var _S807 : u32 = Field_0(aux_4, u32(2));
    state_9 = (bitcast<vec4<u32>>((gAccum_0[_S807])));
    var _S808 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_56, u32(11))].z)));
    loop
    {
        if(((state_9.x) < u32(3)))
        {
        }
        else
        {
            break;
        }
        var offset_7 : u32 = u32(12) + state_9.x * u32(3);
        var direction_7 : vec4<f32> = gAccum_0[Field_0(base_56, offset_7 + u32(1))];
        var _S809 : bool;
        if(((_S808 & (((u32(1) << ((state_9.x))))))) != u32(0))
        {
            _S809 = (bitcast<u32>((direction_7.w))) != u32(0);
        }
        else
        {
            _S809 = false;
        }
        if(_S809)
        {
            TraceShadowBatch_0(Ray_x24init_0(gAccum_0[Field_0(base_56, offset_7)].xyz, direction_7.xyz, gAccum_0[Field_0(base_56, offset_7)].w), state_9.y);
            state_9[i32(2)] = gShadowBatchCount_0;
            var i_23 : u32;
            if(gShadowBatchComplete_0)
            {
                i_23 = u32(1);
            }
            else
            {
                i_23 = u32(0);
            }
            state_9[i32(3)] = i_23;
            i_23 = u32(0);
            loop
            {
                if((i_23 < (state_9.z)))
                {
                }
                else
                {
                    break;
                }
                var _S810 : u32 = i_23 * u32(2);
                gAccum_0[Field_0(aux_4, u32(3) + _S810)] = vec4<f32>(gShadowBatch_0[i_23].t_6, gShadowBatch_0[i_23].barycentrics_0, (bitcast<f32>((gShadowBatch_0[i_23].instanceIndex_2))));
                gAccum_0[Field_0(aux_4, u32(4) + _S810)] = vec4<f32>((bitcast<f32>((gShadowBatch_0[i_23].primitiveIndex_1))), 0.0f, 0.0f, 0.0f);
                i_23 = i_23 + u32(1);
            }
            break;
        }
        state_9 = vec4<u32>(state_9.x + u32(1), u32(0), u32(0), u32(0));
    }
    gAccum_0[_S807] = (bitcast<vec4<f32>>((state_9)));
    return;
}

fn CollectShadowBatchImpl_3( tid_25 : vec3<u32>)
{
    var index_29 : u32;
    var _S811 : bool = ShadowBatchIndex_1(tid_25.x, &(index_29));
    if(!_S811)
    {
        return;
    }
    var base_57 : u32 = WorkBase_0(index_29);
    var aux_5 : u32 = LightWorkBase_0(index_29);
    var state_10 : vec4<u32>;
    state_10 = vec4<u32>(u32(0));
    var _S812 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_57, u32(11))].z)));
    loop
    {
        if(((state_10.x) < u32(3)))
        {
        }
        else
        {
            break;
        }
        var offset_8 : u32 = u32(12) + state_10.x * u32(3);
        var direction_8 : vec4<f32> = gAccum_0[Field_0(base_57, offset_8 + u32(1))];
        var _S813 : bool;
        if(((_S812 & (((u32(1) << ((state_10.x))))))) != u32(0))
        {
            _S813 = (bitcast<u32>((direction_8.w))) != u32(0);
        }
        else
        {
            _S813 = false;
        }
        if(_S813)
        {
            TraceShadowBatch_0(Ray_x24init_0(gAccum_0[Field_0(base_57, offset_8)].xyz, direction_8.xyz, gAccum_0[Field_0(base_57, offset_8)].w), state_10.y);
            state_10[i32(2)] = gShadowBatchCount_0;
            var i_24 : u32;
            if(gShadowBatchComplete_0)
            {
                i_24 = u32(1);
            }
            else
            {
                i_24 = u32(0);
            }
            state_10[i32(3)] = i_24;
            i_24 = u32(0);
            loop
            {
                if((i_24 < (state_10.z)))
                {
                }
                else
                {
                    break;
                }
                var _S814 : u32 = i_24 * u32(2);
                gAccum_0[Field_0(aux_5, u32(3) + _S814)] = vec4<f32>(gShadowBatch_0[i_24].t_6, gShadowBatch_0[i_24].barycentrics_0, (bitcast<f32>((gShadowBatch_0[i_24].instanceIndex_2))));
                gAccum_0[Field_0(aux_5, u32(4) + _S814)] = vec4<f32>((bitcast<f32>((gShadowBatch_0[i_24].primitiveIndex_1))), 0.0f, 0.0f, 0.0f);
                i_24 = i_24 + u32(1);
            }
            break;
        }
        state_10 = vec4<u32>(state_10.x + u32(1), u32(0), u32(0), u32(0));
    }
    gAccum_0[Field_0(aux_5, u32(2))] = (bitcast<vec4<f32>>((state_10)));
    return;
}

fn ShadowImpl_0( tid_26 : vec3<u32>)
{
    var sum_7 : vec3<f32>;
    var _S815 : u32 = tid_26.x;
    if((_S815 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_58 : u32 = WorkBase_0(_S815);
    var _S816 : u32 = Field_0(base_58, u32(11));
    var info_0 : vec4<f32> = gAccum_0[_S816];
    var mask_13 : u32 = (bitcast<u32>((gAccum_0[_S816].z)));
    if(mask_13 == u32(0))
    {
        return;
    }
    gRayCone_0 = info_0.xy;
    var _S817 : vec3<f32> = vec3<f32>(0.0f);
    var source_8 : u32 = u32(0);
    var sum_8 : vec3<f32> = _S817;
    loop
    {
        if((source_8 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_13 & (((u32(1) << (source_8)))))) == u32(0))
        {
            source_8 = source_8 + u32(1);
            continue;
        }
        var offset_9 : u32 = u32(12) + source_8 * u32(3);
        var origin_14 : vec4<f32> = gAccum_0[Field_0(base_58, offset_9)];
        var direction_9 : vec4<f32> = gAccum_0[Field_0(base_58, offset_9 + u32(1))];
        var _S818 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_58, offset_9 + u32(1))].w))) == u32(0))
        {
            _S818 = true;
        }
        else
        {
            var _S819 : bool = TraceOcclusion_0(Ray_x24init_0(origin_14.xyz, direction_9.xyz, origin_14.w));
            _S818 = !_S819;
        }
        if(_S818)
        {
            sum_7 = sum_8 + gAccum_0[Field_0(base_58, offset_9 + u32(2))].xyz;
        }
        else
        {
            sum_7 = sum_8;
        }
        sum_8 = sum_7;
        source_8 = source_8 + u32(1);
    }
    var contribution_17 : vec3<f32> = gAccum_0[Field_0(base_58, u32(10))].xyz * sum_8;
    var _S820 : f32 = gAccum_0[Field_0(base_58, u32(10))].w;
    if((_S820 > 0.0f))
    {
        sum_7 = min(contribution_17, vec3<f32>(_S820));
    }
    else
    {
        sum_7 = contribution_17;
    }
    var path_4 : vec4<f32> = gAccum_0[base_58];
    var _S821 : vec3<f32> = gAccum_0[base_58].xyz + sum_7;
    path_4.x = _S821.x;
    path_4.y = _S821.y;
    path_4.z = _S821.z;
    gAccum_0[base_58] = path_4;
    gAccum_0[_S816] = vec4<f32>(0.0f);
    return;
}

fn ShadowImpl_1( tid_27 : vec3<u32>)
{
    var sum_9 : vec3<f32>;
    var _S822 : u32 = tid_27.x;
    if((_S822 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_59 : u32 = WorkBase_0(_S822);
    var _S823 : u32 = Field_0(base_59, u32(11));
    var info_1 : vec4<f32> = gAccum_0[_S823];
    var mask_14 : u32 = (bitcast<u32>((gAccum_0[_S823].z)));
    if(mask_14 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_59);
    gRayCone_0 = info_1.xy;
    var _S824 : vec3<f32> = vec3<f32>(0.0f);
    var source_9 : u32 = u32(0);
    var sum_10 : vec3<f32> = _S824;
    loop
    {
        if((source_9 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_14 & (((u32(1) << (source_9)))))) == u32(0))
        {
            source_9 = source_9 + u32(1);
            continue;
        }
        var offset_10 : u32 = u32(12) + source_9 * u32(3);
        var origin_15 : vec4<f32> = gAccum_0[Field_0(base_59, offset_10)];
        var direction_10 : vec4<f32> = gAccum_0[Field_0(base_59, offset_10 + u32(1))];
        var _S825 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_59, offset_10 + u32(1))].w))) == u32(0))
        {
            _S825 = true;
        }
        else
        {
            var _S826 : bool = TraceOcclusion_1(Ray_x24init_0(origin_15.xyz, direction_10.xyz, origin_15.w));
            _S825 = !_S826;
        }
        if(_S825)
        {
            sum_9 = sum_10 + gAccum_0[Field_0(base_59, offset_10 + u32(2))].xyz;
        }
        else
        {
            sum_9 = sum_10;
        }
        sum_10 = sum_9;
        source_9 = source_9 + u32(1);
    }
    var contribution_18 : vec3<f32> = gAccum_0[Field_0(base_59, u32(10))].xyz * sum_10;
    var _S827 : f32 = gAccum_0[Field_0(base_59, u32(10))].w;
    if((_S827 > 0.0f))
    {
        sum_9 = min(contribution_18, vec3<f32>(_S827));
    }
    else
    {
        sum_9 = contribution_18;
    }
    var path_5 : vec4<f32> = gAccum_0[base_59];
    var _S828 : vec3<f32> = gAccum_0[base_59].xyz + sum_9;
    path_5.x = _S828.x;
    path_5.y = _S828.y;
    path_5.z = _S828.z;
    gAccum_0[base_59] = path_5;
    gAccum_0[_S823] = vec4<f32>(0.0f);
    StoreFeedbackState_0(base_59);
    return;
}

fn ShadeImpl_14( tid_28 : vec3<u32>)
{
    var _S829 : u32 = BucketMetadataBase_0() + (countOneBits(u32(15)) + u32(1));
    var _S830 : u32 = tid_28.x;
    if((_S830 >= (bitcast<u32>((gAccum_0[_S829].x)))))
    {
        return;
    }
    var base_60 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), (bitcast<u32>((gAccum_0[_S829].y))) + _S830));
    gAccum_0[Field_0(base_60, u32(11))] = vec4<f32>(0.0f);
    var s_53 : WavefrontPath_0 = LoadPath_1(base_60);
    if((s_53.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_60);
    var hit_40 : HitRecord_0;
    hit_40.t_6 = gAccum_0[Field_0(base_60, u32(8))].x;
    hit_40.barycentrics_0 = gAccum_0[Field_0(base_60, u32(8))].yz;
    hit_40.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_60, u32(8))].w)));
    hit_40.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_60, u32(9))].x)));
    var _S831 : HitRecord_0 = hit_40;
    ShadePath_8(base_60, &(s_53), _S831, gWavefront_0.bounce_0);
    StorePath_1(base_60, s_53);
    StoreFeedbackState_0(base_60);
    return;
}

fn ShadeImpl_15( tid_29 : vec3<u32>)
{
    var _S832 : u32 = tid_29.x;
    if((_S832 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_61 : u32 = WorkBase_0(_S832);
    if((bitcast<u32>((gAccum_0[base_61].w))) == u32(0))
    {
        return;
    }
    var _S833 : u32 = Field_0(base_61, u32(8));
    var _S834 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S833].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S834 >> (u32(16)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_61, u32(11))] = vec4<f32>(0.0f);
    var s_54 : WavefrontPath_0 = LoadPath_1(base_61);
    if((s_54.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_61);
    var hit_41 : HitRecord_0;
    hit_41.t_6 = gAccum_0[_S833].x;
    hit_41.barycentrics_0 = gAccum_0[_S833].yz;
    hit_41.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S833].w)));
    hit_41.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_61, u32(9))].x)));
    var _S835 : HitRecord_0 = hit_41;
    ShadePath_8(base_61, &(s_54), _S835, gWavefront_0.bounce_0);
    StorePath_1(base_61, s_54);
    StoreFeedbackState_0(base_61);
    return;
}

fn ShadeImpl_16( tid_30 : vec3<u32>)
{
    var _S836 : u32 = tid_30.x;
    if((_S836 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_62 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S836));
    if((bitcast<u32>((gAccum_0[base_62].w))) == u32(0))
    {
        return;
    }
    var _S837 : u32 = Field_0(base_62, u32(8));
    var _S838 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S837].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S838 >> (u32(16)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_62, u32(11))] = vec4<f32>(0.0f);
    var s_55 : WavefrontPath_0 = LoadPath_1(base_62);
    if((s_55.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_62);
    var hit_42 : HitRecord_0;
    hit_42.t_6 = gAccum_0[_S837].x;
    hit_42.barycentrics_0 = gAccum_0[_S837].yz;
    hit_42.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S837].w)));
    hit_42.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_62, u32(9))].x)));
    var _S839 : HitRecord_0 = hit_42;
    ShadePath_8(base_62, &(s_55), _S839, gWavefront_0.bounce_0);
    StorePath_1(base_62, s_55);
    StoreFeedbackState_0(base_62);
    return;
}

fn ShadeImpl_17( tid_31 : vec3<u32>)
{
    var _S840 : u32 = tid_31.x;
    if((_S840 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_63 : u32 = WorkBase_0(_S840);
    gAccum_0[Field_0(base_63, u32(11))] = vec4<f32>(0.0f);
    var s_56 : WavefrontPath_0 = LoadPath_1(base_63);
    if((s_56.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_63);
    var hit_43 : HitRecord_0;
    hit_43.t_6 = gAccum_0[Field_0(base_63, u32(8))].x;
    hit_43.barycentrics_0 = gAccum_0[Field_0(base_63, u32(8))].yz;
    hit_43.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_63, u32(8))].w)));
    hit_43.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_63, u32(9))].x)));
    var _S841 : HitRecord_0 = hit_43;
    ShadePath_8(base_63, &(s_56), _S841, gWavefront_0.bounce_0);
    StorePath_1(base_63, s_56);
    StoreFeedbackState_0(base_63);
    return;
}

fn IntersectImpl_0( tid_32 : vec3<u32>)
{
    var _S842 : u32 = tid_32.x;
    if((_S842 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_64 : u32 = WorkBase_0(_S842);
    var s_57 : WavefrontPath_0 = LoadPath_1(base_64);
    if((s_57.active_0) == u32(0))
    {
        return;
    }
    var hit_44 : HitRecord_0 = IntersectPath_0(&(s_57), gWavefront_0.bounce_0);
    if(HitRecord_IsHit_0(hit_44))
    {
        gAccum_0[Field_0(base_64, u32(8))] = vec4<f32>(hit_44.t_6, hit_44.barycentrics_0, (bitcast<f32>((hit_44.instanceIndex_2))));
        gAccum_0[Field_0(base_64, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_44.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_64] = vec4<f32>(s_57.path_0.radiance_1, (bitcast<f32>((s_57.active_0))));
    return;
}

fn IntersectImpl_1( tid_33 : vec3<u32>)
{
    var _S843 : u32 = tid_33.x;
    if((_S843 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_65 : u32 = WorkBase_0(_S843);
    var s_58 : WavefrontPath_0 = LoadPath_1(base_65);
    if((s_58.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_65);
    var hit_45 : HitRecord_0 = IntersectPath_1(&(s_58), gWavefront_0.bounce_0);
    if(HitRecord_IsHit_0(hit_45))
    {
        gAccum_0[Field_0(base_65, u32(8))] = vec4<f32>(hit_45.t_6, hit_45.barycentrics_0, (bitcast<f32>((hit_45.instanceIndex_2))));
        gAccum_0[Field_0(base_65, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_45.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_65] = vec4<f32>(s_58.path_0.radiance_1, (bitcast<f32>((s_58.active_0))));
    StoreFeedbackState_0(base_65);
    return;
}

fn isfinite_1( x_31 : vec3<f32>) -> vec3<bool>
{
    var result_9 : vec3<bool>;
    var i_25 : i32 = i32(0);
    loop
    {
        if((i_25 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_9[i_25] = isfinite_0(x_31[i_25]);
        i_25 = i_25 + i32(1);
    }
    return result_9;
}

fn TailImpl_0( tid_34 : vec3<u32>)
{
    var count_1 : u32 = (bitcast<u32>((gAccum_0[HeaderBase_0()].x)));
    var _S844 : u32 = tid_34.x;
    var _S845 : bool;
    if((_S844 >= count_1))
    {
        _S845 = true;
    }
    else
    {
        if((gWavefront_0.tailThreshold_0) != u32(0))
        {
            _S845 = (count_1 > (gWavefront_0.tailThreshold_0));
        }
        else
        {
            _S845 = false;
        }
    }
    if(_S845)
    {
        return;
    }
    var base_66 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S844));
    var s_59 : WavefrontPath_0 = LoadPath_1(base_66);
    if((s_59.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_66);
    var bounce_12 : u32 = gWavefront_0.bounce_0;
    loop
    {
        if((bounce_12 <= (gFrame_0.settings_0.x)))
        {
        }
        else
        {
            break;
        }
        var hit_46 : HitRecord_0 = IntersectPath_0(&(s_59), bounce_12);
        if((s_59.active_0) == u32(0))
        {
            break;
        }
        ShadePath_0(base_66, &(s_59), hit_46, bounce_12);
        if((s_59.active_0) == u32(0))
        {
            break;
        }
        bounce_12 = bounce_12 + u32(1);
    }
    StorePath_1(base_66, s_59);
    StoreFeedbackState_0(base_66);
    return;
}

fn TailImpl_1( tid_35 : vec3<u32>)
{
    var count_2 : u32 = (bitcast<u32>((gAccum_0[HeaderBase_0()].x)));
    var _S846 : u32 = tid_35.x;
    var _S847 : bool;
    if((_S846 >= count_2))
    {
        _S847 = true;
    }
    else
    {
        if((gWavefront_0.tailThreshold_0) != u32(0))
        {
            _S847 = (count_2 > (gWavefront_0.tailThreshold_0));
        }
        else
        {
            _S847 = false;
        }
    }
    if(_S847)
    {
        return;
    }
    var base_67 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S846));
    var s_60 : WavefrontPath_0 = LoadPath_1(base_67);
    if((s_60.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_67);
    var bounce_13 : u32 = gWavefront_0.bounce_0;
    loop
    {
        if((bounce_13 <= (gFrame_0.settings_0.x)))
        {
        }
        else
        {
            break;
        }
        var hit_47 : HitRecord_0 = IntersectPath_1(&(s_60), bounce_13);
        if((s_60.active_0) == u32(0))
        {
            break;
        }
        ShadePath_1(base_67, &(s_60), hit_47, bounce_13);
        if((s_60.active_0) == u32(0))
        {
            break;
        }
        bounce_13 = bounce_13 + u32(1);
    }
    StorePath_1(base_67, s_60);
    StoreFeedbackState_0(base_67);
    return;
}

fn ShadowImpl_2( tid_36 : vec3<u32>)
{
    var sum_11 : vec3<f32>;
    var _S848 : u32 = tid_36.x;
    if((_S848 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_68 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S848));
    var _S849 : u32 = Field_0(base_68, u32(11));
    var info_2 : vec4<f32> = gAccum_0[_S849];
    var mask_15 : u32 = (bitcast<u32>((gAccum_0[_S849].z)));
    if(mask_15 == u32(0))
    {
        return;
    }
    gRayCone_0 = info_2.xy;
    var _S850 : vec3<f32> = vec3<f32>(0.0f);
    var source_10 : u32 = u32(0);
    var sum_12 : vec3<f32> = _S850;
    loop
    {
        if((source_10 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_15 & (((u32(1) << (source_10)))))) == u32(0))
        {
            source_10 = source_10 + u32(1);
            continue;
        }
        var offset_11 : u32 = u32(12) + source_10 * u32(3);
        var origin_16 : vec4<f32> = gAccum_0[Field_0(base_68, offset_11)];
        var direction_11 : vec4<f32> = gAccum_0[Field_0(base_68, offset_11 + u32(1))];
        var _S851 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_68, offset_11 + u32(1))].w))) == u32(0))
        {
            _S851 = true;
        }
        else
        {
            var _S852 : bool = TraceOcclusion_0(Ray_x24init_0(origin_16.xyz, direction_11.xyz, origin_16.w));
            _S851 = !_S852;
        }
        if(_S851)
        {
            sum_11 = sum_12 + gAccum_0[Field_0(base_68, offset_11 + u32(2))].xyz;
        }
        else
        {
            sum_11 = sum_12;
        }
        sum_12 = sum_11;
        source_10 = source_10 + u32(1);
    }
    var contribution_19 : vec3<f32> = gAccum_0[Field_0(base_68, u32(10))].xyz * sum_12;
    var _S853 : f32 = gAccum_0[Field_0(base_68, u32(10))].w;
    if((_S853 > 0.0f))
    {
        sum_11 = min(contribution_19, vec3<f32>(_S853));
    }
    else
    {
        sum_11 = contribution_19;
    }
    var path_6 : vec4<f32> = gAccum_0[base_68];
    var _S854 : vec3<f32> = gAccum_0[base_68].xyz + sum_11;
    path_6.x = _S854.x;
    path_6.y = _S854.y;
    path_6.z = _S854.z;
    gAccum_0[base_68] = path_6;
    gAccum_0[_S849] = vec4<f32>(0.0f);
    return;
}

fn ShadowImpl_3( tid_37 : vec3<u32>)
{
    var sum_13 : vec3<f32>;
    var _S855 : u32 = tid_37.x;
    if((_S855 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_69 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S855));
    var _S856 : u32 = Field_0(base_69, u32(11));
    var info_3 : vec4<f32> = gAccum_0[_S856];
    var mask_16 : u32 = (bitcast<u32>((gAccum_0[_S856].z)));
    if(mask_16 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_69);
    gRayCone_0 = info_3.xy;
    var _S857 : vec3<f32> = vec3<f32>(0.0f);
    var source_11 : u32 = u32(0);
    var sum_14 : vec3<f32> = _S857;
    loop
    {
        if((source_11 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_16 & (((u32(1) << (source_11)))))) == u32(0))
        {
            source_11 = source_11 + u32(1);
            continue;
        }
        var offset_12 : u32 = u32(12) + source_11 * u32(3);
        var origin_17 : vec4<f32> = gAccum_0[Field_0(base_69, offset_12)];
        var direction_12 : vec4<f32> = gAccum_0[Field_0(base_69, offset_12 + u32(1))];
        var _S858 : bool;
        if((bitcast<u32>((gAccum_0[Field_0(base_69, offset_12 + u32(1))].w))) == u32(0))
        {
            _S858 = true;
        }
        else
        {
            var _S859 : bool = TraceOcclusion_1(Ray_x24init_0(origin_17.xyz, direction_12.xyz, origin_17.w));
            _S858 = !_S859;
        }
        if(_S858)
        {
            sum_13 = sum_14 + gAccum_0[Field_0(base_69, offset_12 + u32(2))].xyz;
        }
        else
        {
            sum_13 = sum_14;
        }
        sum_14 = sum_13;
        source_11 = source_11 + u32(1);
    }
    var contribution_20 : vec3<f32> = gAccum_0[Field_0(base_69, u32(10))].xyz * sum_14;
    var _S860 : f32 = gAccum_0[Field_0(base_69, u32(10))].w;
    if((_S860 > 0.0f))
    {
        sum_13 = min(contribution_20, vec3<f32>(_S860));
    }
    else
    {
        sum_13 = contribution_20;
    }
    var path_7 : vec4<f32> = gAccum_0[base_69];
    var _S861 : vec3<f32> = gAccum_0[base_69].xyz + sum_13;
    path_7.x = _S861.x;
    path_7.y = _S861.y;
    path_7.z = _S861.z;
    gAccum_0[base_69] = path_7;
    gAccum_0[_S856] = vec4<f32>(0.0f);
    StoreFeedbackState_0(base_69);
    return;
}

fn ShadeImpl_18( tid_38 : vec3<u32>)
{
    var _S862 : u32 = tid_38.x;
    if((_S862 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_70 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S862));
    gAccum_0[Field_0(base_70, u32(11))] = vec4<f32>(0.0f);
    var s_61 : WavefrontPath_0 = LoadPath_1(base_70);
    if((s_61.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_70);
    var hit_48 : HitRecord_0;
    hit_48.t_6 = gAccum_0[Field_0(base_70, u32(8))].x;
    hit_48.barycentrics_0 = gAccum_0[Field_0(base_70, u32(8))].yz;
    hit_48.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_70, u32(8))].w)));
    hit_48.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_70, u32(9))].x)));
    var _S863 : HitRecord_0 = hit_48;
    ShadePath_8(base_70, &(s_61), _S863, gWavefront_0.bounce_0);
    StorePath_1(base_70, s_61);
    StoreFeedbackState_0(base_70);
    return;
}

fn IntersectImpl_2( tid_39 : vec3<u32>)
{
    var _S864 : u32 = tid_39.x;
    if((_S864 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_71 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S864));
    var s_62 : WavefrontPath_0 = LoadPath_1(base_71);
    if((s_62.active_0) == u32(0))
    {
        return;
    }
    var hit_49 : HitRecord_0 = IntersectPath_0(&(s_62), gWavefront_0.bounce_0);
    if(HitRecord_IsHit_0(hit_49))
    {
        gAccum_0[Field_0(base_71, u32(8))] = vec4<f32>(hit_49.t_6, hit_49.barycentrics_0, (bitcast<f32>((hit_49.instanceIndex_2))));
        gAccum_0[Field_0(base_71, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_49.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_71] = vec4<f32>(s_62.path_0.radiance_1, (bitcast<f32>((s_62.active_0))));
    return;
}

fn IntersectImpl_3( tid_40 : vec3<u32>)
{
    var _S865 : u32 = tid_40.x;
    if((_S865 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_72 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S865));
    var s_63 : WavefrontPath_0 = LoadPath_1(base_72);
    if((s_63.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_72);
    var hit_50 : HitRecord_0 = IntersectPath_1(&(s_63), gWavefront_0.bounce_0);
    if(HitRecord_IsHit_0(hit_50))
    {
        gAccum_0[Field_0(base_72, u32(8))] = vec4<f32>(hit_50.t_6, hit_50.barycentrics_0, (bitcast<f32>((hit_50.instanceIndex_2))));
        gAccum_0[Field_0(base_72, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_50.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_72] = vec4<f32>(s_63.path_0.radiance_1, (bitcast<f32>((s_63.active_0))));
    StoreFeedbackState_0(base_72);
    return;
}

fn WorkPixel_0( index_30 : u32) -> vec2<u32>
{
    var work_0 : u32 = gWavefront_0.tileStart_0 + index_30;
    var block_0 : u32 = work_0 / u32(64);
    var lane_0 : u32 = (work_0 & (u32(63)));
    var blocksX_0 : u32 = (gFrame_0.frame_0.x + u32(7)) / u32(8);
    var _S866 : u32 = block_0 % blocksX_0;
    var _S867 : u32 = _S866 * u32(8) + ((lane_0 & (u32(7))));
    var _S868 : u32 = block_0 / blocksX_0;
    return vec2<u32>(_S867, _S868 * u32(8) + lane_0 / u32(8));
}

fn RandomSequence_x24init_1( pixel_0 : vec2<u32>,  timeSeed_1 : u32) -> RandomSequence_0
{
    var _S869 : RandomSequence_0;
    _S869.seed_0 = StrongIntegerHash_0(pixel_0.x + pixel_0.y * u32(65536) + StrongIntegerHash_0(timeSeed_1));
    return _S869;
}

fn GenerateCameraRay_0( pixel_1 : vec2<u32>,  rng_18 : ptr<function, RandomSequence_0>) -> Ray_0
{
    var _S870 : vec2<f32> = vec2<f32>(gFrame_0.frame_0.xy);
    var _S871 : vec2<f32> = vec2<f32>(pixel_1);
    var _S872 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_18)));
    var film_2 : vec2<f32> = (_S871 + _S872) / _S870;
    var forward_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var dir_30 : vec3<f32> = normalize(forward_0 + gFrame_0.cameraRight_0.xyz * vec3<f32>((film_2.x * 2.0f - 1.0f)) + gFrame_0.cameraUp_0.xyz * vec3<f32>((1.0f - film_2.y * 2.0f)));
    var origin_18 : vec3<f32> = gFrame_0.cameraPosition_0.xyz;
    var lensRadius_0 : f32 = gFrame_0.cameraPosition_0.w;
    var dir_31 : vec3<f32>;
    var origin_19 : vec3<f32>;
    if((lensRadius_0 > 0.0f))
    {
        var focusPoint_0 : vec3<f32> = origin_18 + dir_30 * vec3<f32>((gFrame_0.cameraRight_0.w / dot(dir_30, forward_0)));
        var _S873 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_18)));
        var lens_0 : vec2<f32> = SampleDisk_0(_S873) * vec2<f32>(lensRadius_0);
        var origin_20 : vec3<f32> = origin_18 + (normalize(gFrame_0.cameraRight_0.xyz) * vec3<f32>(lens_0.x) + normalize(gFrame_0.cameraUp_0.xyz) * vec3<f32>(lens_0.y));
        dir_31 = normalize(focusPoint_0 - origin_20);
        origin_19 = origin_20;
    }
    else
    {
        dir_31 = dir_30;
        origin_19 = origin_18;
    }
    return Ray_x24init_0(origin_19, dir_31, 1.00000001504746622e+30f);
}

fn InitVirtualTextureFeedback_0( pixel_2 : vec2<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = StrongIntegerHash_0(((pixel_2.x) ^ ((StrongIntegerHash_0(((pixel_2.y) ^ ((StrongIntegerHash_0(gFrame_0.frame_0.w)))))))));
    return;
}

fn _S874( _S875 : ptr<function, array<HitRecord_0, i32(4)>>)
{
    var _S876 : HitRecord_0 = HitRecord_0( 0.0f, vec2<f32>(0.0f), u32(0), u32(0) );
    (*_S875)[i32(0)] = _S876;
    (*_S875)[i32(1)] = _S876;
    (*_S875)[i32(2)] = _S876;
    (*_S875)[i32(3)] = _S876;
    return;
}

fn _S877() -> vec2<f32>
{
    return vec2<f32>(0.0f);
}

@compute
@workgroup_size(64, 1, 1)
fn Initialize(@builtin(global_invocation_id) tid_41 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S878 : array<HitRecord_0, i32(4)>;
    _S874(&(_S878));
    gShadowBatch_0 = _S878;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_31 : u32 = tid_41.x;
    if((index_31 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var pixel_3 : vec2<u32> = WorkPixel_0(index_31);
    var rng_19 : RandomSequence_0 = RandomSequence_x24init_1(pixel_3, gFrame_0.frame_0.w);
    var ray_14 : Ray_0 = GenerateCameraRay_0(pixel_3, &(rng_19));
    var s_64 : WavefrontPath_0;
    var _S879 : vec3<f32> = vec3<f32>(0.0f);
    s_64.path_0.radiance_1 = _S879;
    s_64.path_0.throughput_7 = vec3<f32>(1.0f);
    s_64.path_0.origin_3 = ray_14.origin_0;
    s_64.path_0.direction_1 = ray_14.direction_0;
    s_64.path_0.scatterPdf_0 = 1.0f;
    s_64.path_0.lobe_2 = u32(0);
    s_64.path_0.coneWidth_2 = 0.0f;
    s_64.path_0.coneSpread_0 = gFrame_0.vtParams_0.y;
    s_64.path_0.absorption_0 = _S879;
    s_64.path_0.lightsSampled_0 = false;
    s_64.active_0 = select(u32(0), u32(1), (all(((pixel_3 < (gFrame_0.frame_0.xy))))));
    s_64.randomSeed_0 = rng_19.seed_0;
    s_64.albedo_2 = _S879;
    s_64.normal_11 = _S879;
    var base_73 : u32 = WorkBase_0(index_31);
    StorePath_1(base_73, s_64);
    gAccum_0[Field_0(base_73, u32(11))] = vec4<f32>(0.0f);
    if(((index_31 & (u32(3)))) == u32(0))
    {
        gAccum_0[MainQueueBase_0() + index_31 / u32(4)] = (bitcast<vec4<f32>>((vec4<u32>(index_31, index_31 + u32(1), index_31 + u32(2), index_31 + u32(3)))));
    }
    if(index_31 == u32(0))
    {
        var sortGroups_0 : u32;
        if((gWavefront_0.sortGroupSize_0) == u32(256))
        {
            sortGroups_0 = (gWavefront_0.pathCount_0 + u32(255)) / u32(256);
        }
        else
        {
            sortGroups_0 = u32(0);
        }
        var _S880 : u32 = HeaderBase_0();
        gAccum_0[_S880] = (bitcast<vec4<f32>>((vec4<u32>(gWavefront_0.pathCount_0, u32(0), u32(0), sortGroups_0))));
        gAccum_0[_S880 + u32(1)] = (bitcast<vec4<f32>>((vec4<u32>((gWavefront_0.pathCount_0 + u32(63)) / u32(64), u32(1), u32(1), u32(0)))));
        gAccum_0[_S880 + u32(2)] = (bitcast<vec4<f32>>((vec4<u32>(u32(0), u32(1), u32(1), u32(0)))));
    }
    InitVirtualTextureFeedback_0(pixel_3);
    StoreFeedbackState_0(base_73);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Intersect(@builtin(global_invocation_id) tid_42 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S881 : array<HitRecord_0, i32(4)>;
    _S874(&(_S881));
    gShadowBatch_0 = _S881;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_3(tid_42);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectOpaque(@builtin(global_invocation_id) tid_43 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S882 : array<HitRecord_0, i32(4)>;
    _S874(&(_S882));
    gShadowBatch_0 = _S882;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_2(tid_43);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shade(@builtin(global_invocation_id) tid_44 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S883 : array<HitRecord_0, i32(4)>;
    _S874(&(_S883));
    gShadowBatch_0 = _S883;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_18(tid_44);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shadow(@builtin(global_invocation_id) tid_45 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S884 : array<HitRecord_0, i32(4)>;
    _S874(&(_S884));
    gShadowBatch_0 = _S884;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_3(tid_45);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowOpaque(@builtin(global_invocation_id) tid_46 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S885 : array<HitRecord_0, i32(4)>;
    _S874(&(_S885));
    gShadowBatch_0 = _S885;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_2(tid_46);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Tail(@builtin(global_invocation_id) tid_47 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S886 : array<HitRecord_0, i32(4)>;
    _S874(&(_S886));
    gShadowBatch_0 = _S886;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    TailImpl_1(tid_47);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn TailOpaque(@builtin(global_invocation_id) tid_48 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S887 : array<HitRecord_0, i32(4)>;
    _S874(&(_S887));
    gShadowBatch_0 = _S887;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    TailImpl_0(tid_48);
    return;
}

fn IsFeedbackPixel_0( pixel_4 : vec2<u32>) -> bool
{
    var _S888 : vec2<u32> = vec2<u32>(gFrame_0.vtInfo_0.w);
    return (all((pixel_4 == (min(((((pixel_4 >> (_S888))) << (_S888))) + vec2<u32>(((gFrame_0.vtInfo_0.z) & (u32(65535))), ((gFrame_0.vtInfo_0.z) >> (u32(16)))), gFrame_0.frame_0.xy - vec2<u32>(u32(1)))))));
}

@compute
@workgroup_size(64, 1, 1)
fn Finalize(@builtin(global_invocation_id) tid_49 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S889 : array<HitRecord_0, i32(4)>;
    _S874(&(_S889));
    gShadowBatch_0 = _S889;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_32 : u32 = tid_49.x;
    if((index_32 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_74 : u32 = WorkBase_0(index_32);
    var s_65 : WavefrontPath_0 = LoadPath_1(base_74);
    var pixel_5 : vec2<u32> = WorkPixel_0(index_32);
    if((any(((pixel_5 >= (gFrame_0.frame_0.xy))))))
    {
        return;
    }
    LoadFeedbackState_0(base_74);
    if(IsFeedbackPixel_0(pixel_5))
    {
        textureStore((gVTFeedback_0), ((pixel_5 >> (vec2<u32>(gFrame_0.vtInfo_0.w)))), vec4<u32>((gVTRequest_0), 0, 0, 1));
    }
    var radiance_8 : vec3<f32> = s_65.path_0.radiance_1 * vec3<f32>(gFrame_0.envParams_0.z);
    var radiance_9 : vec3<f32>;
    if(!(all((isfinite_1(radiance_8)))))
    {
        radiance_9 = vec3<f32>(0.0f);
    }
    else
    {
        radiance_9 = radiance_8;
    }
    var output_0 : u32 = (pixel_5.y * gFrame_0.frame_0.x + pixel_5.x) * u32(3);
    if((gFrame_0.frame_0.z) == u32(0))
    {
        gAccum_0[output_0] = vec4<f32>(radiance_9, 1.0f);
        gAccum_0[output_0 + u32(1)] = vec4<f32>(s_65.albedo_2, 1.0f);
        gAccum_0[output_0 + u32(2)] = vec4<f32>(s_65.normal_11, 1.0f);
    }
    else
    {
        var _S890 : vec3<f32> = vec3<f32>((1.0f / f32(gFrame_0.frame_0.z + u32(1))));
        gAccum_0[output_0] = vec4<f32>(mix(gAccum_0[output_0].xyz, radiance_9, _S890), 1.0f);
        var _S891 : u32 = output_0 + u32(1);
        gAccum_0[_S891] = vec4<f32>(mix(gAccum_0[_S891].xyz, s_65.albedo_2, _S890), 1.0f);
        var _S892 : u32 = output_0 + u32(2);
        gAccum_0[_S892] = vec4<f32>(mix(gAccum_0[_S892].xyz, s_65.normal_11, _S890), 1.0f);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectDirect(@builtin(global_invocation_id) tid_50 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S893 : array<HitRecord_0, i32(4)>;
    _S874(&(_S893));
    gShadowBatch_0 = _S893;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_1(tid_50);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectOpaqueDirect(@builtin(global_invocation_id) tid_51 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S894 : array<HitRecord_0, i32(4)>;
    _S874(&(_S894));
    gShadowBatch_0 = _S894;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_0(tid_51);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeDirect(@builtin(global_invocation_id) tid_52 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S895 : array<HitRecord_0, i32(4)>;
    _S874(&(_S895));
    gShadowBatch_0 = _S895;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_17(tid_52);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucket(@builtin(global_invocation_id) tid_53 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S896 : array<HitRecord_0, i32(4)>;
    _S874(&(_S896));
    gShadowBatch_0 = _S896;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_16(tid_53);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucketDirect(@builtin(global_invocation_id) tid_54 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S897 : array<HitRecord_0, i32(4)>;
    _S874(&(_S897));
    gShadowBatch_0 = _S897;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_15(tid_54);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucketCompact(@builtin(global_invocation_id) tid_55 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S898 : array<HitRecord_0, i32(4)>;
    _S874(&(_S898));
    gShadowBatch_0 = _S898;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_14(tid_55);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowDirect(@builtin(global_invocation_id) tid_56 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S899 : array<HitRecord_0, i32(4)>;
    _S874(&(_S899));
    gShadowBatch_0 = _S899;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_1(tid_56);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowOpaqueDirect(@builtin(global_invocation_id) tid_57 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S900 : array<HitRecord_0, i32(4)>;
    _S874(&(_S900));
    gShadowBatch_0 = _S900;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_0(tid_57);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CollectShadowBatch(@builtin(global_invocation_id) tid_58 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S901 : array<HitRecord_0, i32(4)>;
    _S874(&(_S901));
    gShadowBatch_0 = _S901;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    CollectShadowBatchImpl_3(tid_58);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ContinueShadowBatch(@builtin(global_invocation_id) tid_59 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S902 : array<HitRecord_0, i32(4)>;
    _S874(&(_S902));
    gShadowBatch_0 = _S902;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    CollectShadowBatchImpl_2(tid_59);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn EvaluateShadowBatch(@builtin(global_invocation_id) tid_60 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S903 : array<HitRecord_0, i32(4)>;
    _S874(&(_S903));
    gShadowBatch_0 = _S903;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    EvaluateShadowBatchImpl_1(tid_60);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn FinishShadowBatch(@builtin(global_invocation_id) tid_61 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S904 : array<HitRecord_0, i32(4)>;
    _S874(&(_S904));
    gShadowBatch_0 = _S904;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    FinishShadowBatchImpl_1(tid_61);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ResolveShadowBatch(@builtin(global_invocation_id) tid_62 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S905 : array<HitRecord_0, i32(4)>;
    _S874(&(_S905));
    gShadowBatch_0 = _S905;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ResolveShadowBatchImpl_1(tid_62);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn CollectShadowBatchDirect(@builtin(global_invocation_id) tid_63 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S906 : array<HitRecord_0, i32(4)>;
    _S874(&(_S906));
    gShadowBatch_0 = _S906;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    CollectShadowBatchImpl_1(tid_63);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ContinueShadowBatchDirect(@builtin(global_invocation_id) tid_64 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S907 : array<HitRecord_0, i32(4)>;
    _S874(&(_S907));
    gShadowBatch_0 = _S907;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    CollectShadowBatchImpl_0(tid_64);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn EvaluateShadowBatchDirect(@builtin(global_invocation_id) tid_65 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S908 : array<HitRecord_0, i32(4)>;
    _S874(&(_S908));
    gShadowBatch_0 = _S908;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    EvaluateShadowBatchImpl_0(tid_65);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn FinishShadowBatchDirect(@builtin(global_invocation_id) tid_66 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S909 : array<HitRecord_0, i32(4)>;
    _S874(&(_S909));
    gShadowBatch_0 = _S909;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    FinishShadowBatchImpl_0(tid_66);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ResolveShadowBatchDirect(@builtin(global_invocation_id) tid_67 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S910 : array<HitRecord_0, i32(4)>;
    _S874(&(_S910));
    gShadowBatch_0 = _S910;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ResolveShadowBatchImpl_0(tid_67);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurface(@builtin(global_invocation_id) tid_68 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S911 : array<HitRecord_0, i32(4)>;
    _S874(&(_S911));
    gShadowBatch_0 = _S911;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_13(tid_68);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceDirect(@builtin(global_invocation_id) tid_69 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S912 : array<HitRecord_0, i32(4)>;
    _S874(&(_S912));
    gShadowBatch_0 = _S912;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_12(tid_69);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceBucket(@builtin(global_invocation_id) tid_70 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S913 : array<HitRecord_0, i32(4)>;
    _S874(&(_S913));
    gShadowBatch_0 = _S913;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_11(tid_70);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceCompact(@builtin(global_invocation_id) tid_71 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S914 : array<HitRecord_0, i32(4)>;
    _S874(&(_S914));
    gShadowBatch_0 = _S914;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_10(tid_71);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLight(@builtin(global_invocation_id) tid_72 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S915 : array<HitRecord_0, i32(4)>;
    _S874(&(_S915));
    gShadowBatch_0 = _S915;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeLightImpl_1(tid_72);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLightDirect(@builtin(global_invocation_id) tid_73 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S916 : array<HitRecord_0, i32(4)>;
    _S874(&(_S916));
    gShadowBatch_0 = _S916;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeLightImpl_0(tid_73);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimary(@builtin(global_invocation_id) tid_74 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S917 : array<HitRecord_0, i32(4)>;
    _S874(&(_S917));
    gShadowBatch_0 = _S917;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_9(tid_74);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondary(@builtin(global_invocation_id) tid_75 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S918 : array<HitRecord_0, i32(4)>;
    _S874(&(_S918));
    gShadowBatch_0 = _S918;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_8(tid_75);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLate(@builtin(global_invocation_id) tid_76 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S919 : array<HitRecord_0, i32(4)>;
    _S874(&(_S919));
    gShadowBatch_0 = _S919;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_7(tid_76);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryLate(@builtin(global_invocation_id) tid_77 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S920 : array<HitRecord_0, i32(4)>;
    _S874(&(_S920));
    gShadowBatch_0 = _S920;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_6(tid_77);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryLate(@builtin(global_invocation_id) tid_78 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S921 : array<HitRecord_0, i32(4)>;
    _S874(&(_S921));
    gShadowBatch_0 = _S921;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_5(tid_78);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryDirect(@builtin(global_invocation_id) tid_79 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S922 : array<HitRecord_0, i32(4)>;
    _S874(&(_S922));
    gShadowBatch_0 = _S922;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_4(tid_79);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryDirect(@builtin(global_invocation_id) tid_80 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S923 : array<HitRecord_0, i32(4)>;
    _S874(&(_S923));
    gShadowBatch_0 = _S923;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_3(tid_80);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLateDirect(@builtin(global_invocation_id) tid_81 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S924 : array<HitRecord_0, i32(4)>;
    _S874(&(_S924));
    gShadowBatch_0 = _S924;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_2(tid_81);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryLateDirect(@builtin(global_invocation_id) tid_82 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S925 : array<HitRecord_0, i32(4)>;
    _S874(&(_S925));
    gShadowBatch_0 = _S925;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_1(tid_82);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryLateDirect(@builtin(global_invocation_id) tid_83 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gTraversalCost_0 = u32(0);
    gShadowBatchSkip_0 = u32(0);
    gShadowBatchCount_0 = u32(0);
    var _S926 : array<HitRecord_0, i32(4)>;
    _S874(&(_S926));
    gShadowBatch_0 = _S926;
    gShadowBatchComplete_0 = false;
    gRayCone_0 = _S877();
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_0(tid_83);
    return;
}

