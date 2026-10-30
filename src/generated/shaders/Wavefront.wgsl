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
    @align(16) primaryVisibility_0 : vec4<u32>,
    @align(16) sharc_0 : vec4<u32>,
    @align(16) sharcParams_0 : vec4<f32>,
    @align(16) sharcControl_0 : vec4<u32>,
    @align(16) temporal_0 : vec4<f32>,
};

@binding(0) @group(0) var<uniform> gFrame_0 : FrameUniforms_std140_0;
@binding(0) @group(1) var<storage, read_write> gAccum_0 : array<vec4<f32>>;

@binding(3) @group(1) var gPrimaryVisibility_0 : texture_2d<u32>;

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

struct Vertex_std430_0
{
    @align(16) positionU_0 : vec4<f32>,
    @align(16) normalV_0 : vec4<f32>,
    @align(16) tangent_0 : vec4<f32>,
    @align(16) uv1_0 : vec4<f32>,
};

@binding(4) @group(0) var<storage, read> gVertices_0 : array<Vertex_std430_0>;

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

@binding(8) @group(0) var gLinearSampler_0 : sampler;

@binding(10) @group(0) var gEnvCdf_0 : texture_2d<f32>;

@binding(2) @group(0) var<storage, read> gTris_0 : array<vec4<f32>>;

@binding(6) @group(0) var<storage, read> gMaterialData_0 : array<vec4<u32>>;

@binding(12) @group(0) var gVTPageTable_0 : texture_2d<u32>;

@binding(11) @group(0) var gVTPhysical_0 : texture_2d<f32>;

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

@binding(13) @group(0) var gBSDFTables_0 : texture_3d<f32>;

@binding(1) @group(1) var gVTFeedback_0 : texture_storage_2d<r32uint, write>;

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
     base_0 : BaseLobe_0,
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
     base_1 : CoatLobe_0,
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

fn StrongIntegerHash_0( x_0 : u32) -> u32
{
    var _S1 : u32 = ((x_0 ^ (((x_0 >> (u32(16))))))) * u32(2819806515);
    var _S2 : u32 = ((_S1 ^ (((_S1 >> (u32(15))))))) * u32(2994267309);
    return (_S2 ^ (((_S2 >> (u32(17))))));
}

fn RandomSequence_Next_0( this_0 : ptr<function, RandomSequence_0>) -> f32
{
    var _S3 : u32 = (*this_0).seed_0 + u32(1);
    (*this_0).seed_0 = _S3;
    return f32(((StrongIntegerHash_0(_S3)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_1 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_1 : f32 = RandomSequence_Next_0(&((*this_1)));
    var y_0 : f32 = RandomSequence_Next_0(&((*this_1)));
    return vec2<f32>(x_1, y_0);
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn EnvCdf_0( x_2 : u32,  y_1 : u32) -> f32
{
    var _S4 : vec3<i32> = vec3<i32>(i32(x_2), i32(y_1), i32(0));
    return (textureLoad((gEnvCdf_0), ((_S4)).xy, ((_S4)).z).x);
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
    var _S5 : f32 = cos(elevation_0);
    (*cosElevation_0) = _S5;
    return vec3<f32>(cos(azimuth_0) * _S5, sin(elevation_0), sin(azimuth_0) * _S5);
}

fn RotateY_0( v_0 : vec3<f32>,  angle_0 : f32) -> vec3<f32>
{
    var s_0 : f32 = sin(angle_0);
    var c_0 : f32 = cos(angle_0);
    var _S6 : f32 = v_0.x;
    var _S7 : f32 = v_0.z;
    return vec3<f32>(c_0 * _S6 + s_0 * _S7, v_0.y, - s_0 * _S6 + c_0 * _S7);
}

fn DirectionToEquirectUV_0( dir_0 : vec3<f32>) -> vec2<f32>
{
    var _S8 : f32 = dir_0.y;
    var elevation_1 : f32 = asin(clamp(_S8, -1.0f, 1.0f));
    var azimuth_1 : f32;
    if(((abs(_S8)) < 1.0f))
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
        var _S9 : vec3<f32> = vec3<f32>(r_0 * cos(phi_0), r_0 * sin(phi_0), z_0);
        s_1.solidAnglePdf_0 = 1.0f / (4.0f * PI_2);
        dir_2 = _S9;
    }
    else
    {
        var W_0 : u32 = gFrame_0.envInfo_0.x;
        var H_0 : u32 = gFrame_0.envInfo_0.y;
        var _S10 : f32 = u_1.y;
        var y_2 : u32 = SearchCdfRow_0(H_0, H_0, _S10);
        var cy0_0 : f32 = EnvCdf_0(y_2, H_0);
        var cy1_0 : f32 = EnvCdf_0(y_2 + u32(1), H_0);
        var dv_0 : f32;
        if((cy1_0 > cy0_0))
        {
            dv_0 = (_S10 - cy0_0) / (cy1_0 - cy0_0);
        }
        else
        {
            dv_0 = 0.5f;
        }
        var _S11 : f32 = u_1.x;
        var x_3 : u32 = SearchCdfRow_0(y_2, W_0, _S11);
        var cx0_0 : f32 = EnvCdf_0(x_3, y_2);
        var cx1_0 : f32 = EnvCdf_0(x_3 + u32(1), y_2);
        var du_0 : f32;
        if((cx1_0 > cx0_0))
        {
            du_0 = (_S11 - cx0_0) / (cx1_0 - cx0_0);
        }
        else
        {
            du_0 = 0.5f;
        }
        var _S12 : f32 = f32(H_0);
        var _S13 : f32 = f32(W_0);
        var pdfUV_0 : f32 = (cy1_0 - cy0_0) * _S12 * (cx1_0 - cx0_0) * _S13;
        var cosElevation_1 : f32;
        var local_0 : vec3<f32> = EquirectUVToDirection_0(vec2<f32>((f32(x_3) + du_0) / _S13, (f32(y_2) + dv_0) / _S12), &(cosElevation_1));
        var _S14 : vec3<f32> = RotateY_0(local_0, gFrame_0.envParams_0.y);
        var PI_3 : f32 = float_getPi_0();
        s_1.solidAnglePdf_0 = pdfUV_0 / (2.0f * PI_3 * PI_3 * max(cosElevation_1, 9.99999997475242708e-07f));
        dir_2 = _S14;
    }
    s_1.normal_7 = (vec3<f32>(0) - dir_2);
    s_1.radiance_0 = EvalEnvironment_0(dir_2);
    return s_1;
}

fn ComputeOffsetOrigin_0( pos_0 : vec3<f32>,  normal_8 : vec3<f32>) -> vec3<f32>
{
    var _S15 : vec3<i32> = vec3<i32>(normal_8 * vec3<f32>(768.0f));
    var _S16 : vec3<i32> = (bitcast<vec3<i32>>((pos_0)));
    var _S17 : f32 = pos_0.x;
    var _S18 : i32;
    if((_S17 < 0.0f))
    {
        _S18 = - _S15.x;
    }
    else
    {
        _S18 = _S15.x;
    }
    var _S19 : f32 = pos_0.y;
    var _S20 : i32;
    if((_S19 < 0.0f))
    {
        _S20 = - _S15.y;
    }
    else
    {
        _S20 = _S15.y;
    }
    var _S21 : f32 = pos_0.z;
    var _S22 : i32;
    if((_S21 < 0.0f))
    {
        _S22 = - _S15.z;
    }
    else
    {
        _S22 = _S15.z;
    }
    var pI_0 : vec3<f32> = (bitcast<vec3<f32>>((_S16 + vec3<i32>(_S18, _S20, _S22))));
    var fOff_0 : vec3<f32> = normal_8 * vec3<f32>(4.57763671875e-05f);
    var _S23 : f32;
    if(((abs(_S17)) < 0.0625f))
    {
        _S23 = _S17 + fOff_0.x;
    }
    else
    {
        _S23 = pI_0.x;
    }
    var _S24 : f32;
    if(((abs(_S19)) < 0.0625f))
    {
        _S24 = _S19 + fOff_0.y;
    }
    else
    {
        _S24 = pI_0.y;
    }
    var _S25 : f32;
    if(((abs(_S21)) < 0.0625f))
    {
        _S25 = _S21 + fOff_0.z;
    }
    else
    {
        _S25 = pI_0.z;
    }
    return vec3<f32>(_S23, _S24, _S25);
}

fn ShadowOrigin_0( si_0 : SurfaceInteraction_0,  dir_3 : vec3<f32>) -> vec3<f32>
{
    var _S26 : vec3<f32>;
    if(((dot(si_0.faceNormal_0, dir_3)) >= 0.0f))
    {
        _S26 = si_0.faceNormal_0;
    }
    else
    {
        _S26 = (vec3<f32>(0) - si_0.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(si_0.position_0, _S26);
}

fn LightCount_0() -> u32
{
    return gFrame_0.counts_0.y;
}

fn RandomSequence_Next_1( this_2 : ptr<function, RandomSequence_0>) -> f32
{
    var _S27 : u32 = (*this_2).seed_0 + u32(1);
    (*this_2).seed_0 = _S27;
    return f32(((StrongIntegerHash_0(_S27)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn SelectLight_0( u_2 : f32) -> u32
{
    var _S28 : u32 = LightCount_0() - u32(1);
    var lo_1 : u32 = u32(0);
    var hi_1 : u32 = _S28;
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
    var _S29 : u32 = AnalyticFlags_0(&((*light_1)));
    var d_0 : vec2<f32>;
    if(((_S29 & (u32(512)))) != u32(0))
    {
        d_0 = SampleDisk_0(u_4) * vec2<f32>(0.5f);
    }
    else
    {
        d_0 = u_4 - vec2<f32>(0.5f);
    }
    return (*light_1).p0_0.xyz + (*light_1).n_0.xyz * vec3<f32>(d_0.x) + (*light_1).uvA_0.xyz * vec3<f32>(d_0.y);
}

fn rsqrt_0( x_4 : f32) -> f32
{
    return 1.0f / sqrt(x_4);
}

fn SpotAttenuation_0( light_2 : ptr<function, EmissiveTriangle_std430_0>,  dir_4 : vec3<f32>) -> f32
{
    var _S30 : u32 = AnalyticFlags_0(&((*light_2)));
    if(((_S30 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_5 : f32 = dot(dir_4, (*light_2).p2_0.xyz) - (*light_2).uvA_0.w;
    var scale_1 : f32 = (*light_2).uvB_0.x;
    var _S31 : f32;
    if((scale_1 > 0.0f))
    {
        _S31 = smoothstep(0.0f, 1.0f, x_5 * scale_1);
    }
    else
    {
        if((x_5 > 0.0f))
        {
            _S31 = 1.0f;
        }
        else
        {
            _S31 = 0.0f;
        }
    }
    return _S31;
}

fn SphereOneMinusCos_0( radius_0 : f32,  distSq_0 : f32) -> f32
{
    var sinSq_0 : f32 = radius_0 * radius_0 / distSq_0;
    var _S32 : f32;
    if((sinSq_0 < 1.0f))
    {
        _S32 = sinSq_0 / (1.0f + sqrt(1.0f - sinSq_0));
    }
    else
    {
        _S32 = 0.0f;
    }
    return _S32;
}

fn BranchlessONB_0( n_2 : vec3<f32>,  b1_0 : ptr<function, vec3<f32>>,  b2_0 : ptr<function, vec3<f32>>)
{
    var _S33 : f32 = n_2.z;
    var s_2 : f32;
    if((_S33 >= 0.0f))
    {
        s_2 = 1.0f;
    }
    else
    {
        s_2 = -1.0f;
    }
    var a_0 : f32 = -1.0f / (s_2 + _S33);
    var _S34 : f32 = n_2.x;
    var _S35 : f32 = n_2.y;
    var b_1 : f32 = _S34 * _S35 * a_0;
    (*b1_0) = vec3<f32>(1.0f + s_2 * _S34 * _S34 * a_0, s_2 * b_1, - s_2 * _S34);
    (*b2_0) = vec3<f32>(b_1, s_2 + _S35 * _S35 * a_0, - _S35);
    return;
}

fn SampleAnalytic_0( light_3 : ptr<function, EmissiveTriangle_std430_0>,  viewer_0 : vec3<f32>,  rng_1 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_3 : LightSample_0;
    s_3.delta_0 = false;
    s_3.radiance_0 = vec3<f32>(0.0f);
    s_3.solidAnglePdf_0 = 0.0f;
    var _S36 : u32 = AnalyticFlags_0(&((*light_3)));
    s_3.shadow_0 = ((_S36 & (u32(1024)))) == u32(0);
    var u_5 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_1)));
    if(((_S36 & (u32(255)))) == u32(2))
    {
        var _S37 : vec3<f32> = AreaLightPoint_0(&((*light_3)), u_5);
        s_3.position_1 = _S37;
        var _S38 : vec3<f32> = (*light_3).p2_0.xyz;
        s_3.normal_7 = _S38;
        var toLight_0 : vec3<f32> = _S37 - viewer_0;
        var distSq_1 : f32 = dot(toLight_0, toLight_0);
        var cosTheta_0 : f32 = - dot(_S38, toLight_0) * rsqrt_0(max(distSq_1, 9.99999968265522539e-21f));
        if((cosTheta_0 > 9.99999997475242708e-07f))
        {
            s_3.radiance_0 = (*light_3).p1_0.xyz;
            s_3.solidAnglePdf_0 = (*light_3).p1_0.w * distSq_1 / (cosTheta_0 * (*light_3).p0_0.w);
        }
        return s_3;
    }
    var _S39 : vec3<f32> = (*light_3).p0_0.xyz;
    var toCenter_0 : vec3<f32> = _S39 - viewer_0;
    var distSq_2 : f32 = dot(toCenter_0, toCenter_0);
    var w_0 : vec3<f32> = toCenter_0 / vec3<f32>(max(sqrt(distSq_2), 9.99999968265522539e-21f));
    var radius_1 : f32 = (*light_3).p0_0.w;
    if((radius_1 <= 0.0f))
    {
        s_3.position_1 = _S39;
        var _S40 : vec3<f32> = (vec3<f32>(0) - w_0);
        s_3.normal_7 = _S40;
        var _S41 : vec4<f32> = (*light_3).p1_0;
        var _S42 : vec3<f32> = (*light_3).p1_0.xyz;
        var _S43 : f32 = SpotAttenuation_0(&((*light_3)), _S40);
        s_3.radiance_0 = _S42 * vec3<f32>(_S43) / vec3<f32>(max(distSq_2, 9.99999968265522539e-21f));
        s_3.solidAnglePdf_0 = _S41.w;
        s_3.delta_0 = true;
        return s_3;
    }
    var oneMinusCosMax_0 : f32 = SphereOneMinusCos_0(radius_1, distSq_2);
    if((oneMinusCosMax_0 <= 0.0f))
    {
        s_3.position_1 = _S39;
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
    var _S44 : vec3<f32> = viewer_0 + dir_5 * vec3<f32>((tc_0 - sqrt(max(0.0f, radius_1 * radius_1 - (distSq_2 - tc_0 * tc_0)))));
    s_3.position_1 = _S44;
    s_3.normal_7 = normalize(_S44 - _S39);
    var _S45 : vec4<f32> = (*light_3).p1_0;
    var _S46 : vec3<f32> = (*light_3).p1_0.xyz;
    var _S47 : f32 = SpotAttenuation_0(&((*light_3)), (vec3<f32>(0) - w_0));
    s_3.radiance_0 = _S46 * vec3<f32>(_S47);
    s_3.solidAnglePdf_0 = _S45.w / (TWO_PI_0 * oneMinusCosMax_0);
    return s_3;
}

fn SampleTriangle_0( u_6 : vec2<f32>) -> vec3<f32>
{
    var su_0 : f32 = sqrt(u_6.x);
    var _S48 : f32 = u_6.y;
    return vec3<f32>(1.0f - su_0, su_0 * (1.0f - _S48), su_0 * _S48);
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
    var _S49 : u32 = materialIndex_2 * u32(2);
    var h0_0 : vec4<u32> = gMaterialData_0[_S49];
    var h1_0 : vec4<u32> = gMaterialData_0[_S49 + u32(1)];
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

fn InverseTransformPoint_0( _S50 : u32,  _S51 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S50].worldToObject_0[i32(0)].xyz, _S51) + gInstances_0[_S50].worldToObject_0[i32(0)].w, dot(gInstances_0[_S50].worldToObject_0[i32(1)].xyz, _S51) + gInstances_0[_S50].worldToObject_0[i32(1)].w, dot(gInstances_0[_S50].worldToObject_0[i32(2)].xyz, _S51) + gInstances_0[_S50].worldToObject_0[i32(2)].w);
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
    var _S52 : vec3<f32> = vec3<f32>(0.80000001192092896f);
    i_0.baseColor_0 = _S52;
    i_0.baseDiffuseRoughness_0 = 0.0f;
    i_0.baseMetalness_0 = 0.0f;
    i_0.subsurfaceWeight_0 = 0.0f;
    i_0.subsurfaceColor_0 = _S52;
    i_0.subsurfaceRadius_0 = 1.0f;
    i_0.subsurfaceRadiusScale_0 = vec3<f32>(1.0f, 0.5f, 0.25f);
    i_0.subsurfaceScatterAnisotropy_0 = 0.0f;
    i_0.specularWeight_0 = 1.0f;
    i_0.specularDielectricOnly_0 = false;
    var _S53 : vec3<f32> = vec3<f32>(1.0f);
    i_0.specularColor_0 = _S53;
    i_0.specularRoughness_0 = 0.30000001192092896f;
    i_0.specularRoughnessAnisotropy_0 = 0.0f;
    i_0.specularIor_0 = 1.5f;
    const _S54 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    i_0.specularAnisotropyRotation_0 = _S54;
    i_0.coatWeight_0 = 0.0f;
    i_0.coatColor_0 = _S53;
    i_0.coatRoughness_0 = 0.0f;
    i_0.coatRoughnessAnisotropy_0 = 0.0f;
    i_0.coatIor_0 = 1.6000000238418579f;
    i_0.coatDarkening_0 = 1.0f;
    i_0.coatAnisotropyRotation_0 = _S54;
    i_0.fuzzWeight_0 = 0.0f;
    i_0.fuzzColor_0 = _S53;
    i_0.fuzzRoughness_0 = 0.5f;
    i_0.transmissionWeight_0 = 0.0f;
    i_0.transmissionColor_0 = _S53;
    i_0.transmissionDepth_0 = 0.0f;
    i_0.transmissionScatter_0 = vec3<f32>(0.0f);
    i_0.transmissionScatterAnisotropy_0 = 0.0f;
    i_0.transmissionDispersionScale_0 = 0.0f;
    i_0.transmissionDispersionAbbeNumber_0 = 20.0f;
    i_0.thinFilmWeight_1 = 0.0f;
    i_0.thinFilmThickness_1 = 0.5f;
    i_0.thinFilmIor_1 = 1.3999999761581421f;
    i_0.emissionLuminance_0 = 0.0f;
    i_0.emissionColor_0 = _S53;
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
    var _S55 : vec3<f32> = ctx_1.tangent_3.xyz;
    o_0.tangent_2 = _S55;
    o_0.coatTangent_0 = _S55;
    return o_0;
}

@id(2) override gMaterialOperandMode_0 : u32 = u32(0);

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

@id(0) override gMaterialOpcodesLow_0 : u32 = u32(4294967295);

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
    var _S56 : u32 = header_0.textureBase_0 + index_1 * u32(2);
    var a_1 : vec4<u32> = gMaterialData_0[_S56];
    var ref_0 : TextureRef_0;
    ref_0.flags_2 = a_1.x;
    ref_0.pageTableOffset_0 = a_1.y;
    ref_0.reserved_0 = a_1.z;
    ref_0.rotation_0 = (bitcast<f32>((a_1.w)));
    ref_0.scaleOffset_0 = (bitcast<vec4<f32>>((gMaterialData_0[_S56 + u32(1)])));
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
    var _S57 : f32 = s_4.x;
    var _S58 : f32 = s_4.y;
    return vec2<f32>(c_1 * _S57 + r_1 * _S58, - r_1 * _S57 + c_1 * _S58) + ref_2.scaleOffset_0.zw;
}

fn WrapCoord_0( x_6 : f32,  mode_0 : u32) -> f32
{
    if(mode_0 == u32(1))
    {
        return saturate(x_6);
    }
    if(mode_0 == u32(2))
    {
        var t_2 : f32 = x_6 - 2.0f * floor(x_6 * 0.5f);
        var _S59 : f32;
        if((t_2 > 1.0f))
        {
            _S59 = 2.0f - t_2;
        }
        else
        {
            _S59 = t_2;
        }
        return _S59;
    }
    return fract(x_6);
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
    var _S60 : u32 = u32(1664525) * gVTRandom_0 + u32(1013904223);
    gVTRandom_0 = _S60;
    return _S60;
}

fn VTPageCount_0( log2Size_0 : vec2<u32>,  level_0 : u32) -> vec2<u32>
{
    var _S61 : vec2<i32> = max(vec2<i32>(log2Size_0) - vec2<i32>(i32(level_0)) - vec2<i32>(i32(7)), vec2<i32>(i32(0)));
    return vec2<u32>((u32(1) << (u32(_S61.x))), (u32(1) << (u32(_S61.y))));
}

fn VTLevelSize_0( log2Size_1 : vec2<u32>,  level_1 : u32) -> vec2<f32>
{
    var _S62 : vec2<i32> = max(vec2<i32>(log2Size_1) - vec2<i32>(i32(level_1)), vec2<i32>(i32(0)));
    return vec2<f32>(f32((u32(1) << (u32(_S62.x)))), f32((u32(1) << (u32(_S62.y)))));
}

var<private> gVTRequestCount_0 : u32;

var<private> gVTRequest_0 : u32;

fn StoreVirtualTextureFeedback_0( pageIndex_0 : u32)
{
    gVTRequestCount_0 = gVTRequestCount_0 + u32(1);
    var _S63 : u32 = NextVTRandom_0();
    if(((f32((_S63 >> (u32(8)))) * 5.9604644775390625e-08f * f32(gVTRequestCount_0)) < 1.0f))
    {
        gVTRequest_0 = pageIndex_0 + u32(1);
    }
    return;
}

fn VTLoadEntry_0( index_2 : u32) -> u32
{
    var width_0 : u32 = gFrame_0.vtInfo_0.y;
    var _S64 : u32 = index_2 % width_0;
    var _S65 : i32 = i32(_S64);
    var _S66 : u32 = index_2 / width_0;
    var _S67 : vec3<i32> = vec3<i32>(_S65, i32(_S66), i32(0));
    return (textureLoad((gVTPageTable_0), ((_S67)).xy, ((_S67)).z).x);
}

var<private> gVTLastMappedLevel_0 : u32;

var<private> gVTLastRequestedLevel_0 : u32;

fn SampleVirtualTexture_0( ref_6 : TextureRef_0,  uv_2 : vec2<f32>,  uvFootprint_0 : f32) -> vec4<f32>
{
    var levels_0 : u32 = VTLevels_0(ref_6);
    var _S68 : u32 = VTLog2Width_0(ref_6);
    var _S69 : u32 = VTLog2Height_0(ref_6);
    var log2Size_2 : vec2<u32> = vec2<u32>(_S68, _S69);
    var lod_0 : f32 = uvFootprint_0 + 0.5f * (f32(_S68 + _S69) + log2(max(abs(ref_6.scaleOffset_0.x * ref_6.scaleOffset_0.y), 9.99999968265522539e-21f))) + gFrame_0.vtParams_0.z;
    var _S70 : u32 = NextVTRandom_0();
    var level_2 : u32 = u32(clamp(floor(lod_0 + f32((_S70 >> (u32(8)))) * 5.9604644775390625e-08f), 0.0f, f32(levels_0 - u32(1))));
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
        var n_3 : vec2<u32> = VTPageCount_0(log2Size_2, l_0);
        var index_4 : u32 = index_3 + n_3.x * n_3.y;
        l_0 = l_0 + u32(1);
        index_3 = index_4;
    }
    var pages_0 : vec2<u32> = VTPageCount_0(log2Size_2, level_2);
    var _S71 : vec2<u32> = min((vec2<u32>(uv_2 * VTLevelSize_0(log2Size_2, level_2)) >> (vec2<u32>(u32(7)))), pages_0 - vec2<u32>(u32(1)));
    var index_5 : u32 = index_3 + (_S71.y * pages_0.x + _S71.x);
    StoreVirtualTextureFeedback_0(index_5);
    var entry_0 : u32 = VTLoadEntry_0(index_5);
    if(((entry_0 & (u32(2147483648)))) == u32(0))
    {
        return vec4<f32>(1.0f, 0.0f, 1.0f, 1.0f);
    }
    var mappedLevel_0 : u32 = (((entry_0 >> (u32(16)))) & (u32(15)));
    gVTLastMappedLevel_0 = mappedLevel_0;
    gVTLastRequestedLevel_0 = level_2;
    var local_1 : vec2<f32> = uv_2 * VTLevelSize_0(log2Size_2, mappedLevel_0) - vec2<f32>((_S71 >> (vec2<u32>((mappedLevel_0 - level_2))))) * vec2<f32>(128.0f);
    var tile_0 : u32 = (entry_0 & (u32(65535)));
    var tilesPerRow_0 : u32 = gFrame_0.vtInfo_0.x;
    var _S72 : u32 = tile_0 % tilesPerRow_0;
    var _S73 : f32 = f32(_S72);
    var _S74 : u32 = tile_0 / tilesPerRow_0;
    return (textureSampleLevel((gVTPhysical_0), (gLinearSampler_0), ((vec2<f32>(_S73, f32(_S74)) * vec2<f32>(136.0f) + vec2<f32>(4.0f) + local_1) * vec2<f32>(gFrame_0.vtParams_0.x)), (0.0f)));
}

fn SrgbToLinear_0( c_2 : vec3<f32>) -> vec3<f32>
{
    return select(pow((c_2 + vec3<f32>(0.054999999701976776f)) / vec3<f32>(1.0549999475479126f), vec3<f32>(2.4000000953674316f)), c_2 / vec3<f32>(12.920000076293945f), (c_2 <= vec3<f32>(0.040449999272823334f)));
}

fn SampleTexture_0( ref_7 : TextureRef_0,  tc_2 : TextureCoords_0) -> vec4<f32>
{
    var useUV1_0 : bool = (((ref_7.flags_2) & (u32(4)))) != u32(0);
    var uv_3 : vec2<f32>;
    var _S75 : vec2<f32>;
    if(useUV1_0)
    {
        _S75 = tc_2.uv1_1;
    }
    else
    {
        _S75 = tc_2.uv0_0;
    }
    var _S76 : vec2<f32> = TransformUV_0(ref_7, _S75);
    uv_3 = _S76;
    uv_3[i32(0)] = WrapCoord_0(_S76.x, ((((ref_7.flags_2) >> (u32(8)))) & (u32(3))));
    uv_3[i32(1)] = WrapCoord_0(uv_3.y, ((((ref_7.flags_2) >> (u32(10)))) & (u32(3))));
    var color_1 : vec4<f32>;
    var _S77 : vec2<f32> = uv_3;
    var _S78 : f32;
    if(useUV1_0)
    {
        _S78 = tc_2.footprint1_0;
    }
    else
    {
        _S78 = tc_2.footprint0_0;
    }
    var _S79 : vec4<f32> = SampleVirtualTexture_0(ref_7, _S77, _S78);
    color_1 = _S79;
    if((((ref_7.flags_2) & (u32(2)))) != u32(0))
    {
        var _S80 : vec3<f32> = SrgbToLinear_0(color_1.xyz);
        color_1.x = _S80.x;
        color_1.y = _S80.y;
        color_1.z = _S80.z;
    }
    return color_1;
}

@id(1) override gMaterialOpcodesHigh_0 : u32 = u32(4294967295);

fn HashRotate_0( x_7 : u32,  k_0 : u32) -> u32
{
    return (((x_7 << (k_0))) | (((x_7 >> ((u32(32) - k_0))))));
}

fn HashFinal_0( a_2 : u32,  b_3 : u32,  c_3 : u32) -> u32
{
    var _S81 : u32 = ((c_3 ^ (b_3))) - HashRotate_0(b_3, u32(14));
    var _S82 : u32 = ((a_2 ^ (_S81))) - HashRotate_0(_S81, u32(11));
    var _S83 : u32 = ((b_3 ^ (_S82))) - HashRotate_0(_S82, u32(25));
    var _S84 : u32 = ((_S81 ^ (_S83))) - HashRotate_0(_S83, u32(16));
    var _S85 : u32 = ((_S82 ^ (_S84))) - HashRotate_0(_S84, u32(4));
    var _S86 : u32 = ((_S83 ^ (_S85))) - HashRotate_0(_S85, u32(14));
    return ((_S84 ^ (_S86))) - HashRotate_0(_S86, u32(24));
}

fn HashUint2_0( kx_0 : u32,  ky_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928580) + kx_0, u32(3735928580) + ky_0, u32(3735928580));
}

fn RandomOffset3_0( seed_1 : f32) -> vec3<f32>
{
    var _S87 : u32 = (bitcast<u32>((seed_1)));
    return vec3<f32>(100.0f) + vec3<f32>(f32(HashUint2_0(_S87, (bitcast<u32>((0.0f))))), f32(HashUint2_0(_S87, (bitcast<u32>((1.0f))))), f32(HashUint2_0(_S87, (bitcast<u32>((2.0f)))))) * vec3<f32>(2.32830643653869629e-08f);
}

fn FMod_0( x_8 : f32,  y_3 : f32) -> f32
{
    return x_8 - trunc(x_8 / y_3) * y_3;
}

fn NoiseFade_0( t_3 : f32) -> f32
{
    return t_3 * t_3 * t_3 * (t_3 * (t_3 * 6.0f - 15.0f) + 10.0f);
}

fn HashUint3_0( kx_1 : u32,  ky_1 : u32,  kz_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928584) + kx_1, u32(3735928584) + ky_1, u32(3735928584) + kz_0);
}

fn NoiseGrad3_0( hash_0 : u32,  x_9 : f32,  y_4 : f32,  z_1 : f32) -> f32
{
    var h_1 : u32 = (hash_0 & (u32(15)));
    var u_7 : f32;
    if((h_1 < u32(8)))
    {
        u_7 = x_9;
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
        var _S88 : bool;
        if(h_1 == u32(12))
        {
            _S88 = true;
        }
        else
        {
            _S88 = h_1 == u32(14);
        }
        if(_S88)
        {
            v_1 = x_9;
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
    var _S89 : u32 = (bitcast<u32>((i32(i_1.x))));
    var _S90 : u32 = (bitcast<u32>((i32(i_1.y))));
    var _S91 : u32 = (bitcast<u32>((i32(i_1.z))));
    var _S92 : f32 = f_0.x;
    var u_8 : f32 = NoiseFade_0(_S92);
    var _S93 : f32 = f_0.y;
    var v_2 : f32 = NoiseFade_0(_S93);
    var _S94 : f32 = f_0.z;
    var w_1 : f32 = NoiseFade_0(_S94);
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
        var _S95 : u32 = (c_4 & (u32(1)));
        var _S96 : u32 = (((c_4 >> (u32(1)))) & (u32(1)));
        var _S97 : u32 = (c_4 >> (u32(2)));
        g_0[c_4] = NoiseGrad3_0(HashUint3_0(_S89 + _S95, _S90 + _S96, _S91 + _S97), _S92 - f32(_S95), _S93 - f32(_S96), _S94 - f32(_S97));
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
    var _S98 : bool = rmd_0 != 0.0f;
    var _S99 : i32;
    if(_S98)
    {
        _S99 = octaves_0 + i32(1);
    }
    else
    {
        _S99 = octaves_0;
    }
    var i_2 : i32 = i32(0);
    var fscale_0 : f32 = 1.0f;
    var sum_0 : f32 = 0.0f;
    var amp_0 : f32 = 1.0f;
    var maxamp_0 : f32 = 0.0f;
    loop
    {
        if((i_2 <= _S99))
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
    if(_S98)
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
    var _S100 : f32 = clamp(params_0.x, 0.0f, 15.0f);
    var _S101 : f32 = max(params_0.y, 0.0f);
    var _S102 : f32 = params_0.z;
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
        var _S103 : u32;
        if(color_2)
        {
            _S103 = u32(3);
        }
        else
        {
            _S103 = u32(1);
        }
        if((k_1 < _S103))
        {
        }
        else
        {
            break;
        }
        var _S104 : vec3<f32>;
        if(k_1 == u32(0))
        {
            _S104 = p_3;
        }
        else
        {
            _S104 = p_3 + RandomOffset3_0(f32(k_1 + u32(2)));
        }
        result_0[k_1] = NoiseFbm_0(_S104, _S100, _S101, _S102, normalize_1);
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
    var x_10 : f32 = sin((px_0 + py_0 + pz_0) * 5.0f);
    var _S105 : f32 = - px_0;
    var y_5 : f32 = cos((_S105 + py_0 - pz_0) * 5.0f);
    var z_2 : f32 = - cos((_S105 - py_0 + pz_0) * 5.0f);
    var x_11 : f32;
    var z_3 : f32;
    var y_6 : f32;
    if((depth_0 > u32(0)))
    {
        var x_12 : f32 = x_10 * d_1;
        var z_4 : f32 = z_2 * d_1;
        var y_7 : f32 = - cos(x_12 - y_5 * d_1 + z_4) * d_1;
        if((depth_0 > u32(1)))
        {
            x_11 = cos(x_12 - y_7 - z_4) * d_1;
        }
        else
        {
            x_11 = x_12;
        }
        if((depth_0 > u32(2)))
        {
            z_3 = sin(- x_11 - y_7 - z_4) * d_1;
        }
        else
        {
            z_3 = z_4;
        }
        if((depth_0 > u32(3)))
        {
            x_11 = - cos(- x_11 + y_7 - z_3) * d_1;
        }
        if((depth_0 > u32(4)))
        {
            y_6 = - sin(- x_11 + y_7 + z_3) * d_1;
        }
        else
        {
            y_6 = y_7;
        }
        if((depth_0 > u32(5)))
        {
            y_6 = - cos(- x_11 + y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(6)))
        {
            x_11 = cos(x_11 + y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(7)))
        {
            z_3 = sin(x_11 + y_6 - z_3) * d_1;
        }
        if((depth_0 > u32(8)))
        {
            x_11 = - cos(- x_11 - y_6 + z_3) * d_1;
        }
        if((depth_0 > u32(9)))
        {
            y_6 = - sin(x_11 - y_6 + z_3) * d_1;
        }
    }
    else
    {
        x_11 = x_10;
        y_6 = y_5;
        z_3 = z_2;
    }
    if(d_1 != 0.0f)
    {
        var _S106 : f32 = 2.0f * d_1;
        var y_8 : f32 = y_6 / _S106;
        var z_5 : f32 = z_3 / _S106;
        x_11 = x_11 / _S106;
        y_6 = y_8;
        z_3 = z_5;
    }
    return vec3<f32>(0.5f - x_11, 0.5f - y_6, 0.5f - z_3);
}

fn BlenderChecker_0( p_5 : vec3<f32>) -> f32
{
    var i_3 : vec3<i32> = abs(vec3<i32>(floor((p_5 + vec3<f32>(9.99999997475242708e-07f)) * vec3<f32>(0.99999898672103882f))));
    var _S107 : f32;
    if(((((i_3.x) & (i32(1)))) == (((i_3.y) & (i32(1))))) == ((((i_3.z) & (i32(1)))) == i32(1)))
    {
        _S107 = 1.0f;
    }
    else
    {
        _S107 = 0.0f;
    }
    return _S107;
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
        var _S108 : u32 = ins_0.x;
        var op_0 : u32 = (_S108 & (u32(255)));
        var dst_0 : u32 = (((_S108 >> (u32(8)))) & (u32(15)));
        var imm_0 : u32 = (_S108 >> (u32(16)));
        if(op_0 == u32(0))
        {
            return;
        }
        var _S109 : vec4<f32> = vec4<f32>(0.0f);
        var _S110 : bool;
        if(((gMaterialOperandMode_0 & (u32(2)))) == u32(0))
        {
            _S110 = true;
        }
        else
        {
            _S110 = op_0 != u32(23);
        }
        var write_0 : bool;
        var a_4 : vec4<f32>;
        var b_5 : vec4<f32>;
        var c_5 : vec4<f32>;
        if(_S110)
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
                            a_4 = _S109;
                        }
                    }
                }
            }
            else
            {
                a_4 = _S109;
            }
            var _S111 : vec4<f32> = MaterialOperand_0(ins_0.y, a_4, header_1.constantBase_0);
            var _S112 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S112 = true;
            }
            else
            {
                _S112 = (((ins_0.z) & (u32(2147483648)))) == u32(0);
            }
            if(_S112)
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
                            b_5 = _S109;
                        }
                    }
                }
            }
            else
            {
                b_5 = _S109;
            }
            var _S113 : vec4<f32> = MaterialOperand_0(ins_0.z, b_5, header_1.constantBase_0);
            var _S114 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S114 = true;
            }
            else
            {
                _S114 = (((ins_0.w) & (u32(2147483648)))) == u32(0);
            }
            if(_S114)
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
                            c_5 = _S109;
                        }
                    }
                }
            }
            else
            {
                c_5 = _S109;
            }
            var _S115 : vec4<f32> = MaterialOperand_0(ins_0.w, c_5, header_1.constantBase_0);
            a_4 = _S111;
            b_5 = _S113;
            c_5 = _S115;
        }
        else
        {
            a_4 = _S109;
            b_5 = _S109;
            c_5 = _S109;
        }
        var operands_0 : u32 = pc_0 * u32(4) + u32(1);
        var _S116 : u32;
        if(op_0 == u32(23))
        {
            _S116 = (((u32(351898) >> ((u32(2) * min(imm_0, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_0 == u32(17))
            {
                _S116 = u32(1) + imm_0 / u32(4);
            }
            else
            {
                _S116 = u32(1);
            }
        }
        var pc_1 : u32 = pc_0 + _S116;
        var r_2 : vec4<f32> = _S109;
        var slot_1 : vec4<f32>;
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
                            slot_1 = stack_0[(o_1 & (u32(15)))];
                        }
                        else
                        {
                            switch((o_1 & (u32(15))))
                            {
                            case u32(0):
                                {
                                    slot_1 = stack_0[i32(0)];
                                }
                            case u32(1):
                                {
                                    slot_1 = stack_0[i32(1)];
                                }
                            case u32(2):
                                {
                                    slot_1 = stack_0[i32(2)];
                                }
                            case u32(3):
                                {
                                    slot_1 = stack_0[i32(3)];
                                }
                            case u32(4):
                                {
                                    slot_1 = stack_0[i32(4)];
                                }
                            case u32(5):
                                {
                                    slot_1 = stack_0[i32(5)];
                                }
                            case u32(6):
                                {
                                    slot_1 = stack_0[i32(6)];
                                }
                            case u32(7):
                                {
                                    slot_1 = stack_0[i32(7)];
                                }
                            case u32(8):
                                {
                                    slot_1 = stack_0[i32(8)];
                                }
                            case u32(9):
                                {
                                    slot_1 = stack_0[i32(9)];
                                }
                            case u32(10):
                                {
                                    slot_1 = stack_0[i32(10)];
                                }
                            case u32(11):
                                {
                                    slot_1 = stack_0[i32(11)];
                                }
                            case u32(12):
                                {
                                    slot_1 = stack_0[i32(12)];
                                }
                            case u32(13):
                                {
                                    slot_1 = stack_0[i32(13)];
                                }
                            case u32(14):
                                {
                                    slot_1 = stack_0[i32(14)];
                                }
                            case u32(15):
                                {
                                    slot_1 = stack_0[i32(15)];
                                }
                            default :
                                {
                                    slot_1 = _S109;
                                }
                            }
                        }
                    }
                    else
                    {
                        slot_1 = _S109;
                    }
                    r_2[i32(3)] = MaterialOperand_0(o_1, slot_1, header_1.constantBase_0).x;
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
                r_2 = vec4<f32>(dot(select(_S109, a_4, lanes_0), select(_S109, b_5, lanes_0)));
                write_0 = true;
            }
        case u32(19):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(19)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var len_0 : f32 = length(select(_S109, a_4, LanesBelow_0(imm_0)));
                if((len_0 > 0.0f))
                {
                    slot_1 = a_4 / vec4<f32>(len_0);
                }
                else
                {
                    slot_1 = _S109;
                }
                r_2 = slot_1;
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
                    var _S117 : vec4<f32> = SampleTexture_0(ref_8, ctx_2.tex_1);
                    slot_1 = _S117;
                }
                else
                {
                    slot_1 = vec4<f32>(1.0f);
                }
                r_2 = slot_1;
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
                r_2 = select(_S109, vec4<f32>(1.0f), (a_4 > b_5));
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
                var _S118 : bool = ((imm_0 & (u32(2)))) != u32(0);
                var v_3 : vec3<f32> = BlenderNoise_0(a_4.xyz, b_5, ((imm_0 & (u32(1)))) != u32(0), _S118);
                if(_S118)
                {
                    slot_1 = vec4<f32>(v_3, 0.0f);
                }
                else
                {
                    slot_1 = vec4<f32>(v_3.x);
                }
                r_2 = slot_1;
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
                                    slot_1 = stack_0[(o_2 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_2 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_1 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_1 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_1 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_1 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_1 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_1 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_1 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_1 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_1 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_1 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_1 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_1 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_1 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_1 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_1 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_1 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_1 = _S109;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S109;
                            }
                            (*outputs_0).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_2, slot_1, header_1.constantBase_0).x;
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
                                    slot_1 = stack_0[(o_3 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_3 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_1 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_1 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_1 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_1 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_1 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_1 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_1 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_1 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_1 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_1 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_1 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_1 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_1 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_1 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_1 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_1 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_1 = _S109;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S109;
                            }
                            (*outputs_0).inputs_0.emissionColor_0 = MaterialOperand_0(o_3, slot_1, header_1.constantBase_0).xyz;
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
                                    slot_1 = stack_0[(o_4 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_4 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_1 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_1 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_1 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_1 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_1 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_1 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_1 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_1 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_1 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_1 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_1 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_1 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_1 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_1 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_1 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_1 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_1 = _S109;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S109;
                            }
                            (*outputs_0).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_4, slot_1, header_1.constantBase_0).x;
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
                                    slot_1 = stack_0[(o_5 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_5 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_1 = stack_0[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_1 = stack_0[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_1 = stack_0[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_1 = stack_0[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_1 = stack_0[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_1 = stack_0[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_1 = stack_0[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_1 = stack_0[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_1 = stack_0[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_1 = stack_0[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_1 = stack_0[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_1 = stack_0[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_1 = stack_0[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_1 = stack_0[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_1 = stack_0[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_1 = stack_0[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_1 = _S109;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S109;
                            }
                            (*outputs_0).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_5, slot_1, header_1.constantBase_0).x) != 0.0f;
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
    var _S119 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_3, header_3.opacity_0, tc_4);
    return _S119.inputs_0.geometryOpacity_0;
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
    var _S120 : bool;
    if((MaterialHeader_AlphaMode_0(material_0)) == u32(1))
    {
        var _S121 : f32 = EvalOpacity_0(material_0, tc_6);
        _S120 = (_S121 < (material_0.alphaCutoff_0));
    }
    else
    {
        _S120 = false;
    }
    if(_S120)
    {
        return vec3<f32>(0.0f);
    }
    var _S122 : vec3<f32> = EvalEmission_0(material_0, tc_6);
    return _S122;
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
    var _S123 : f32 = RandomSequence_Next_1(&((*rng_2)));
    var _S124 : EmissiveTriangle_std430_0 = gLights_0[SelectLight_0(_S123)];
    var _S125 : u32 = AnalyticFlags_0(&(_S124));
    if(((_S125 & (u32(2147483648)))) != u32(0))
    {
        var _S126 : LightSample_0 = SampleAnalytic_0(&(_S124), viewer_2, &((*rng_2)));
        return _S126;
    }
    var _S127 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_2)));
    var bary_0 : vec3<f32> = SampleTriangle_0(_S127);
    var _S128 : vec4<f32> = _S124.p0_0;
    var _S129 : vec3<f32> = _S124.p0_0.xyz;
    var _S130 : f32 = bary_0.x;
    var _S131 : vec4<f32> = _S124.p1_0;
    var _S132 : vec3<f32> = _S124.p1_0.xyz;
    var _S133 : f32 = bary_0.y;
    var _S134 : vec3<f32> = _S124.p2_0.xyz;
    var _S135 : f32 = bary_0.z;
    var _S136 : vec3<f32> = _S129 * vec3<f32>(_S130) + _S132 * vec3<f32>(_S133) + _S134 * vec3<f32>(_S135);
    s_5.position_1 = _S136;
    s_5.normal_7 = _S124.n_0.xyz;
    var material_1 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S124.n_0.w))));
    var doubleSided_1 : bool = MaterialHeader_DoubleSided_0(material_1);
    var toLight_2 : vec3<f32> = _S136 - viewer_2;
    var dist_0 : f32 = length(toLight_2);
    var tc_7 : TextureCoords_0;
    var _S137 : vec2<f32> = _S124.uvA_0.xy;
    var _S138 : vec2<f32> = vec2<f32>(_S130);
    var _S139 : vec2<f32> = _S124.uvA_0.zw;
    var _S140 : vec2<f32> = vec2<f32>(_S133);
    var _S141 : vec2<f32> = _S124.uvB_0.xy;
    var _S142 : vec2<f32> = vec2<f32>(_S135);
    var _S143 : vec2<f32> = _S137 * _S138 + _S139 * _S140 + _S141 * _S142;
    var _S144 : vec2<f32> = _S124.uvB_0.zw;
    var _S145 : vec2<f32> = _S124.uvC_0.xy;
    var _S146 : vec2<f32> = _S124.uvC_0.zw;
    var _S147 : vec2<f32> = _S144 * _S138 + _S145 * _S140 + _S146 * _S142;
    var _S148 : vec3<f32> = _S132 - _S129;
    var _S149 : vec3<f32> = _S134 - _S129;
    var _S150 : vec2<f32> = _S139 - _S137;
    var _S151 : vec2<f32> = _S141 - _S137;
    var _S152 : vec2<f32> = _S145 - _S144;
    var _S153 : vec2<f32> = _S146 - _S144;
    var _S154 : f32 = cone_0.x + cone_0.y * dist_0;
    var _S155 : f32;
    if((dist_0 > 0.0f))
    {
        _S155 = dot(s_5.normal_7, toLight_2) / dist_0;
    }
    else
    {
        _S155 = 1.0f;
    }
    tc_7 = MakeTextureCoords_0(_S143, _S147, _S148, _S149, _S150, _S151, _S152, _S153, _S154, _S155);
    tc_7.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((_S124.pad_0.x))), s_5.position_1);
    var _S156 : vec3<f32> = EmissiveRadiance_0(material_1, tc_7);
    s_5.radiance_0 = _S156;
    s_5.solidAnglePdf_0 = _S131.w * EmissiveSolidAnglePdf_0(_S128.w, doubleSided_1, viewer_2, s_5.position_1, s_5.normal_7);
    var _S157 : bool;
    if(doubleSided_1)
    {
        _S157 = ((dot(s_5.normal_7, viewer_2 - s_5.position_1)) < 0.0f);
    }
    else
    {
        _S157 = false;
    }
    if(_S157)
    {
        s_5.normal_7 = (vec3<f32>(0) - s_5.normal_7);
    }
    return s_5;
}

fn SunEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(2)))) != u32(0);
}

fn Square_0( x_13 : f32) -> f32
{
    return x_13 * x_13;
}

fn SampleSun_0( rng_3 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var toSun_0 : vec3<f32> = gFrame_0.sunDirection_0.xyz;
    var t_4 : vec3<f32>;
    var b_6 : vec3<f32>;
    BranchlessONB_0(toSun_0, &(t_4), &(b_6));
    var _S158 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_3)));
    var disk_0 : vec2<f32> = SampleDisk_0(_S158);
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
    var _S159 : DiffuseSpecular_0;
    _S159.diffuse_1 = diffuse_2;
    _S159.specular_1 = specular_2;
    return _S159;
}

fn DiffuseSpecular_Zero_0() -> DiffuseSpecular_0
{
    var _S160 : vec3<f32> = vec3<f32>(0.0f);
    return DiffuseSpecular_x24init_0(_S160, _S160);
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

fn BaseLobeEnabled_0( index_6 : i32) -> bool
{
    return true;
}

fn BaseLobe_IsActive_0( this_5 : BaseLobe_0,  index_7 : i32) -> bool
{
    var _S161 : bool;
    if(BaseLobeEnabled_0(index_7))
    {
        _S161 = ((this_5.weights_0[index_7]) > 0.0f);
    }
    else
    {
        _S161 = false;
    }
    return _S161;
}

fn Frame_ToLocal_0( this_6 : Frame_0,  v_4 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(v_4, this_6.t_0), dot(v_4, this_6.b_0), dot(v_4, this_6.n_1));
}

fn EvalGGX_0( m_0 : vec3<f32>,  alpha_4 : vec2<f32>) -> f32
{
    var _S162 : f32 = alpha_4.x;
    var _S163 : f32 = alpha_4.y;
    return 1.0f / (float_getPi_0() * _S162 * _S163 * Square_0(Square_0(m_0.x / _S162) + Square_0(m_0.y / _S163) + Square_0(m_0.z)));
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
    var _S164 : f32;
    if((idoth_0 >= 0.0f))
    {
        _S164 = this_8.thinFilmWeight_0 * ThinFilmPresence_0(this_8.thinFilmThickness_0);
    }
    else
    {
        _S164 = 0.0f;
    }
    return _S164;
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

fn FifthPower_0( x_14 : f32) -> f32
{
    var xx_0 : f32 = x_14 * x_14;
    return xx_0 * xx_0 * x_14;
}

fn SixthPower_0( x_15 : f32) -> f32
{
    var xx_1 : f32 = x_15 * x_15;
    return xx_1 * xx_1 * xx_1;
}

fn MetalSchlickBFactor_0( f0_0 : vec3<f32>,  f82Tint_0 : vec3<f32>) -> vec3<f32>
{
    var _S165 : vec3<f32> = vec3<f32>(1.0f);
    return (f0_0 + (_S165 - f0_0) * vec3<f32>(FifthPower_0(0.8571428656578064f))) * (_S165 - f82Tint_0) * vec3<f32>((1.0f / (0.1428571492433548f * SixthPower_0(0.8571428656578064f))));
}

fn FresnelMetalF82_0( f0_1 : vec3<f32>,  f82Tint_1 : vec3<f32>,  cosTheta_6 : f32) -> vec3<f32>
{
    var oneMinusCos_1 : f32 = 1.0f - cosTheta_6;
    return saturate(f0_1 + (vec3<f32>(1.0f) - f0_1 - MetalSchlickBFactor_0(f0_1, f82Tint_1) * vec3<f32>(cosTheta_6) * vec3<f32>(oneMinusCos_1)) * vec3<f32>(FifthPower_0(oneMinusCos_1)));
}

fn BaseReflectionTransmission_HasDielectric_0( this_9 : BaseReflectionTransmission_0) -> bool
{
    var _S166 : vec3<f32> = vec3<f32>(0.0f);
    var _S167 : bool;
    if((any((((this_9.reflectionScaleTransparent_0) > _S166)))))
    {
        _S167 = true;
    }
    else
    {
        _S167 = (any((((this_9.reflectionScaleOpaque_0) > _S166))));
    }
    return _S167;
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
    var _S168 : f32 = sqrt(saturate(1.0f - sinThetaT_0 * sinThetaT_0));
    (*cosThetaT_1) = _S168;
    var etaICosI_0 : f32 = etaI_0 * cosThetaI_2;
    var etaTCosT_0 : f32 = etaT_0 * _S168;
    var etaTCosI_0 : f32 = etaT_0 * cosThetaI_2;
    var etaICosT_0 : f32 = etaI_0 * _S168;
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
    var _S169 : f32 = 2.0f * etaICosI_0;
    (*t_5).s_8 = _S169 * rcpS_0;
    (*t_5).p_6 = _S169 * rcpP_0;
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
    var _S170 : f32 = a_5.x;
    var _S171 : f32 = b_7.x;
    var _S172 : f32 = a_5.y;
    var _S173 : f32 = b_7.y;
    return vec2<f32>((_S170 * _S171 + _S172 * _S173) * rcpDenominator_0, (_S172 * _S171 - _S170 * _S173) * rcpDenominator_0);
}

fn ComplexMul_0( a_6 : vec2<f32>,  b_8 : vec2<f32>) -> vec2<f32>
{
    var _S174 : f32 = a_6.x;
    var _S175 : f32 = b_8.x;
    var _S176 : f32 = a_6.y;
    var _S177 : f32 = b_8.y;
    return vec2<f32>(_S174 * _S175 - _S176 * _S177, _S174 * _S177 + _S176 * _S175);
}

fn SignNonZero_0( x_16 : f32) -> f32
{
    var _S178 : f32;
    if((x_16 >= 0.0f))
    {
        _S178 = 1.0f;
    }
    else
    {
        _S178 = -1.0f;
    }
    return _S178;
}

fn ComplexSqrt_0( z_6 : vec2<f32>) -> vec2<f32>
{
    var r_4 : f32 = length(z_6);
    var _S179 : f32 = z_6.x;
    return vec2<f32>(sqrt(max((r_4 + _S179) * 0.5f, 0.0f)), SignNonZero_0(z_6.y) * sqrt(max((r_4 - _S179) * 0.5f, 0.0f)));
}

fn RefractedCosine_0( cosThetaI_3 : f32,  etaI_1 : f32,  etaT_1 : vec2<f32>) -> vec2<f32>
{
    const _S180 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var sinThetaT_1 : vec2<f32> = vec2<f32>(sqrt(saturate(1.0f - cosThetaI_3 * cosThetaI_3))) * ComplexDiv_0(vec2<f32>(etaI_1, 0.0f), etaT_1, 9.99999971718068537e-10f, _S180);
    var cosThetaT_2 : vec2<f32> = ComplexSqrt_0(_S180 - ComplexMul_0(sinThetaT_1, sinThetaT_1));
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
    const _S181 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    r_5.s_9 = ComplexDiv_0(etaICosI_1 - etaTCosT_1, etaICosI_1 + etaTCosT_1, 9.99999971718068537e-10f, _S181);
    r_5.p_7 = ComplexDiv_0(etaTCosI_1 - etaICosT_1, etaTCosI_1 + etaICosT_1, 9.99999971718068537e-10f, _S181);
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
    var _S182 : f32 = 1.0f - clampedR_0;
    var n_6 : f32 = mix((1.0f + sqrtR_0) / (1.0f - sqrtR_0), _S182 / (1.0f + clampedR_0), g_1);
    return vec2<f32>(n_6, sqrt(max((Square_0(n_6 + 1.0f) * clampedR_0 - Square_0(n_6 - 1.0f)) / _S182, 0.0f)));
}

fn ThinFilmAndBaseReflectance_0( cosThetaI_5 : f32,  etaExterior_0 : f32,  etaFilm_0 : f32,  etaBase_0 : vec3<f32>,  dispersion_0 : bool,  metalF0_1 : vec3<f32>,  metalF82Tint_1 : vec3<f32>,  enableDielectric_0 : bool,  enableMetal_0 : bool,  thickness_1 : f32,  wavelengths_1 : vec3<f32>) -> ThinFilmResults_0
{
    var results_0 : ThinFilmResults_0;
    var _S183 : vec3<f32> = vec3<f32>(0.0f);
    results_0.dielectric_0 = _S183;
    results_0.metal_0 = _S183;
    var _S184 : bool;
    if(enableDielectric_0)
    {
        _S184 = true;
    }
    else
    {
        _S184 = enableMetal_0;
    }
    if(!_S184)
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
    var _S185 : vec3<f32> = vec3<f32>((2.0f * float_getPi_0() * (2.0f * etaFilm_0 * thickness_1 * cosThetaFilm_0))) / wavelengths_1;
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
                _S184 = true;
            }
            else
            {
                _S184 = c_7 == i32(0);
            }
            if(_S184)
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
            results_0.dielectric_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, r23_2[c_7], _S185[c_7]);
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
            results_0.metal_0[c_7] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, GulbrandsenIor_0(metalF0_1[c_7], metalF82Tint_1[c_7])), _S185[c_7]);
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
    var _S186 : f32 = this_14.eta_0.x;
    var _S187 : bool;
    if((_S186 >= 1.0f))
    {
        _S187 = ((dot(this_14.normal_1, h_2)) > 0.0f);
    }
    else
    {
        _S187 = false;
    }
    if(_S187)
    {
        _S187 = true;
    }
    else
    {
        if((_S186 < 1.0f))
        {
            _S187 = ((dot(this_14.normal_1, h_2)) < 0.0f);
        }
        else
        {
            _S187 = false;
        }
    }
    return _S187;
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
    var _S188 : f32 = abs(idoth_3);
    (*otherTerms_0) = Square_0(channelEta_0) * _S188 * abs(odoth_0) / (Square_0(idoth_3 + channelEta_0 * odoth_0) * idotn_0);
    (*absIdoth_0) = _S188;
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
    var _S189 : f32 = idotn_1 * dot(this_17.normal_1, wi_2);
    if((_S189 > 0.0f))
    {
        var h_4 : vec3<f32> = normalize(wo_3 + wi_2);
        return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_17.distribution_0, wo_3, wi_2)) * (vec3<f32>((GGXDistribution_D_0(this_17.distribution_0, h_4) * (1.0f / (4.0f * idotn_1)))) * BaseReflectionTransmission_Reflection_0(this_17.coefficient_0, abs(dot(wo_3, h_4)))));
    }
    if((_S189 >= 0.0f))
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
        var _S190 : bool = SpecularLobe_TransmissionTerms_0(this_17, wo_3, wi_2, idotn_1, this_17.eta_0[c_8], &(d_3), &(otherTerms_1), &(absIdoth_1));
        var _S191 : f32;
        if(_S190)
        {
            _S191 = d_3 * otherTerms_1 * BaseReflectionTransmission_Transmission_0(this_17.coefficient_0, absIdoth_1)[c_8];
        }
        else
        {
            _S191 = 0.0f;
        }
        dOtherTermsF_0[c_8] = _S191;
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
        var _S192 : vec3<f32> = this_18.transmission_0 * (vec3<f32>(1.0f) - fresnel_0);
        standardReflection_1 = this_18.reflectionScaleTransparent_0 * fresnel_0 + this_18.reflectionScaleOpaque_0 * FresnelDielectric_1(this_18.etaOpaque_0, idoth_5) + vec3<f32>(this_18.metalAmount_0) * FresnelMetalF82_0(this_18.metalF0_0, this_18.metalF82Tint_0, idoth_5);
        standardTransmission_0 = _S192;
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
        var _S193 : vec3<f32> = this_18.transmission_0 * (vec3<f32>(1.0f) - film_1.dielectric_0);
        thinFilmReflection_0 = this_18.reflectionScaleTransparent_0 * film_1.dielectric_0 + this_18.reflectionScaleOpaque_0 * film_1.dielectric_0 + vec3<f32>(this_18.metalAmount_0) * film_1.metal_0;
        thinFilmTransmission_0 = _S193;
    }
    else
    {
        thinFilmReflection_0 = standardReflection_0;
        thinFilmTransmission_0 = standardReflection_0;
    }
    var result_1 : ReflectionTransmission_0;
    var _S194 : vec3<f32> = vec3<f32>(presence_4);
    result_1.reflection_1 = mix(standardReflection_1, thinFilmReflection_0, _S194) + this_18.thinWallReflection_0;
    result_1.transmission_1 = mix(standardTransmission_0, thinFilmTransmission_0, _S194);
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
    var _S195 : f32;
    if(denominator_1 != 0.0f)
    {
        _S195 = numerator_0 / denominator_1;
    }
    else
    {
        _S195 = fallback_1;
    }
    return _S195;
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
    var _S196 : f32 = idotn_2 * dot(this_24.normal_1, wi_3);
    if((_S196 > 0.0f))
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
    if((_S196 >= 0.0f))
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
        var _S197 : bool = SpecularLobe_TransmissionTerms_0(this_24, wo_4, wi_3, idotn_2, this_24.eta_0[c_9], &(d_4), &(otherTerms_2), &(absIdoth_2));
        var _S198 : f32;
        if(_S197)
        {
            _S198 = BaseReflectionTransmission_TransmissionProbability_0(this_24.coefficient_0, this_24.throughput_0, absIdoth_2) * d_4 * otherTerms_2;
        }
        else
        {
            _S198 = 0.0f;
        }
        probabilityDOtherTerms_0[c_9] = _S198;
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

fn ClampExactIndex_0( index_8 : f32) -> f32
{
    return clamp(index_8, 0.0f, 31.0f);
}

fn FetchTable_0( x_17 : i32,  y_9 : i32,  slice_0 : i32) -> f32
{
    var _S199 : vec4<i32> = vec4<i32>(x_17, y_9, slice_0, i32(0));
    return (textureLoad((gBSDFTables_0), ((_S199)).xyz, ((_S199)).w).x);
}

fn FetchEnergy_0( x_18 : i32,  y_10 : i32,  slice_1 : i32) -> f32
{
    return FetchTable_0(x_18, y_10, slice_1) * 1.5259021893143654e-05f;
}

fn LookUpTrilinear_0( firstSlice_0 : i32,  exactX_0 : f32,  exactY_0 : f32,  exactZ_0 : f32) -> f32
{
    var x_19 : f32 = ClampExactIndex_0(exactX_0);
    var y_11 : f32 = ClampExactIndex_0(exactY_0);
    var z_7 : f32 = ClampExactIndex_0(exactZ_0);
    var ix0_0 : i32 = i32(floor(x_19));
    var iy0_0 : i32 = i32(floor(y_11));
    var iz0_0 : i32 = i32(floor(z_7));
    var _S200 : i32 = min(iy0_0 + i32(1), i32(31));
    var _S201 : i32 = min(iz0_0 + i32(1), i32(31));
    var tx_0 : f32 = x_19 - f32(ix0_0);
    var ty_0 : f32 = y_11 - f32(iy0_0);
    var _S202 : i32 = firstSlice_0 + ix0_0;
    var _S203 : i32 = firstSlice_0 + min(ix0_0 + i32(1), i32(31));
    return mix(mix(mix(FetchEnergy_0(iz0_0, iy0_0, _S202), FetchEnergy_0(iz0_0, iy0_0, _S203), tx_0), mix(FetchEnergy_0(iz0_0, _S200, _S202), FetchEnergy_0(iz0_0, _S200, _S203), tx_0), ty_0), mix(mix(FetchEnergy_0(_S201, iy0_0, _S202), FetchEnergy_0(_S201, iy0_0, _S203), tx_0), mix(FetchEnergy_0(_S201, _S200, _S202), FetchEnergy_0(_S201, _S200, _S203), tx_0), ty_0), z_7 - f32(iz0_0));
}

fn IdealDielectricEnergyComplement_0( ior_1 : f32,  alpha_7 : f32,  cosTheta_8 : f32) -> f32
{
    return LookUpTrilinear_0(i32(0), IorToExactIndex_0(ior_1), AlphaToExactIndex_0(alpha_7), CosToExactIndex_0(cosTheta_8));
}

fn LookUpBilinear_0( slice_2 : i32,  exactX_1 : f32,  exactY_1 : f32) -> f32
{
    var x_20 : f32 = ClampExactIndex_0(exactX_1);
    var y_12 : f32 = ClampExactIndex_0(exactY_1);
    var ix0_1 : i32 = i32(floor(x_20));
    var iy0_1 : i32 = i32(floor(y_12));
    var _S204 : i32 = min(ix0_1 + i32(1), i32(31));
    var _S205 : i32 = min(iy0_1 + i32(1), i32(31));
    var tx_1 : f32 = x_20 - f32(ix0_1);
    return mix(mix(FetchEnergy_0(iy0_1, ix0_1, slice_2), FetchEnergy_0(iy0_1, _S204, slice_2), tx_1), mix(FetchEnergy_0(_S205, ix0_1, slice_2), FetchEnergy_0(_S205, _S204, slice_2), tx_1), y_12 - f32(iy0_1));
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
    var _S206 : f32;
    var ratio_0 : f32;
    if((odotn_0 <= 0.0f))
    {
        var _S207 : f32 = - odotn_0;
        var _S208 : f32 = 1.0f - this_26.reflectionRatio_0;
        iorToUse_0 = 1.0f / this_26.eta_1;
        _S206 = _S207;
        ratio_0 = _S208;
    }
    else
    {
        iorToUse_0 = this_26.eta_1;
        _S206 = odotn_0;
        ratio_0 = this_26.reflectionRatio_0;
    }
    var factors_0 : f32 = this_26.energyComplementWo_0 * IdealDielectricEnergyComplement_0(iorToUse_0, this_26.alpha_1, _S206) / ClampAverageEnergyComplement_0(IdealDielectricAverageEnergyComplement_0(iorToUse_0, this_26.alpha_1));
    var factors_1 : f32;
    if(includeRatio_0)
    {
        factors_1 = factors_0 * ratio_0;
    }
    else
    {
        factors_1 = factors_0;
    }
    return min(factors_1, SafeDivide_0(1.0f, _S206, 0.0f));
}

fn DielectricMultipleScatteringLobe_Eval_0( this_27 : DielectricMultipleScatteringLobe_0,  wo_5 : vec3<f32>,  wi_4 : vec3<f32>) -> DiffuseSpecular_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_27))
    {
        return DiffuseSpecular_Zero_0();
    }
    var odotn_1 : f32 = dot(wi_4, this_27.normal_2);
    var unscaledCos_0 : f32 = DielectricMultipleScatteringLobe_TabulatedFactors_0(this_27, odotn_1, true) * (1.0f / float_getPi_0()) * abs(odotn_1);
    var _S209 : vec3<f32>;
    if((odotn_1 > 0.0f))
    {
        _S209 = this_27.reflectionScale_0;
    }
    else
    {
        _S209 = this_27.transmissionScale_0;
    }
    return DiffuseSpecular_Specular_0(_S209 * vec3<f32>(unscaledCos_0));
}

fn DielectricMultipleScatteringLobe_Pdf_0( this_28 : DielectricMultipleScatteringLobe_0,  wo_6 : vec3<f32>,  wi_5 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_28))
    {
        return 0.0f;
    }
    var _S210 : f32;
    if(((dot(wi_5, this_28.normal_2)) > 0.0f))
    {
        _S210 = this_28.reflectionRatio_0;
    }
    else
    {
        _S210 = 1.0f - this_28.reflectionRatio_0;
    }
    return 0.5f / float_getPi_0() * _S210;
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
    var x_21 : f32 = ClampExactIndex_0(exactX_2);
    var i0_0 : i32 = i32(floor(x_21));
    return mix(FetchEnergy_0(i0_0, i32(0), slice_3), FetchEnergy_0(min(i0_0 + i32(1), i32(31)), i32(0), slice_3), x_21 - f32(i0_0));
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
    var _S211 : bool;
    if(!MetalMultipleScatteringLobe_Active_0(this_31))
    {
        _S211 = true;
    }
    else
    {
        _S211 = (odotn_3 <= 0.0f);
    }
    if(_S211)
    {
        return DiffuseSpecular_Zero_0();
    }
    return DiffuseSpecular_Specular_0(this_31.scale_0 * vec3<f32>((MetalMultipleScatteringLobe_TabulatedFactors_0(this_31, odotn_3) * (1.0f / float_getPi_0()) * odotn_3)));
}

fn MetalMultipleScatteringLobe_Pdf_0( this_32 : MetalMultipleScatteringLobe_0,  wo_8 : vec3<f32>,  wi_7 : vec3<f32>) -> f32
{
    var _S212 : bool;
    if(MetalMultipleScatteringLobe_Active_0(this_32))
    {
        _S212 = ((dot(wi_7, this_32.normal_3)) > 0.0f);
    }
    else
    {
        _S212 = false;
    }
    var _S213 : f32;
    if(_S212)
    {
        _S213 = 0.5f / float_getPi_0();
    }
    else
    {
        _S213 = 0.0f;
    }
    return _S213;
}

fn BasisFromNormal_0( n_7 : vec3<f32>) -> Frame_0
{
    var _S214 : f32 = n_7.z;
    var s_10 : f32;
    if((_S214 < 0.0f))
    {
        s_10 = -1.0f;
    }
    else
    {
        s_10 = 1.0f;
    }
    var a_7 : f32 = -1.0f / (s_10 + _S214);
    var _S215 : f32 = n_7.x;
    var _S216 : f32 = n_7.y;
    var b_9 : f32 = _S215 * _S216 * a_7;
    var f_2 : Frame_0;
    f_2.n_1 = n_7;
    f_2.t_0 = vec3<f32>(b_9, s_10 + _S216 * _S216 * a_7, - _S216);
    f_2.b_0 = vec3<f32>(1.0f + s_10 * _S215 * _S215 * a_7, s_10 * b_9, - s_10 * _S215);
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
    var _S217 : f32 = 1.0f - averageEF_0;
    return rho_0 * vec3<f32>((1.0f / PI_4)) * vec3<f32>(aF_0) * vec3<f32>((1.0f + roughness_3 * sOverT_0)) + rho_0 * rho_0 * vec3<f32>(averageEF_0) / (vec3<f32>(1.0f) - rho_0 * vec3<f32>(_S217)) * vec3<f32>((1.0f / PI_4)) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muO_0, roughness_3))) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muI_0, roughness_3))) / vec3<f32>(max(1.00000001168609742e-07f, _S217));
}

fn F0FromIor_0( eta_5 : f32) -> f32
{
    return Square_0((eta_5 - 1.0f) / (eta_5 + 1.0f));
}

fn ExtrapolateBeyondIorMax_0( tableValue_0 : f32,  ior_3 : f32) -> f32
{
    var _S218 : bool;
    if((ior_3 > 2.5f))
    {
        _S218 = true;
    }
    else
    {
        _S218 = (ior_3 < 0.40000000596046448f);
    }
    if(_S218)
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

fn BaseLobe_LobeEvalPdf_0( this_45 : BaseLobe_0,  index_9 : i32,  wo_17 : vec3<f32>,  wi_16 : vec3<f32>,  f_3 : ptr<function, DiffuseSpecular_0>,  pdf_1 : ptr<function, f32>)
{
    switch(index_9)
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
            var _S219 : bool;
            if((sampled_0.layer_0) != i32(1))
            {
                _S219 = true;
            }
            else
            {
                _S219 = (sampled_0.lobe_1) != i_4;
            }
            if(_S219)
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
    var _S220 : f32;
    if((a_9 > 0.0f))
    {
        _S220 = pow(a_9, b_11);
    }
    else
    {
        _S220 = 0.0f;
    }
    return _S220;
}

fn SafePow_1( a_10 : vec3<f32>,  b_12 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(SafePow_0(a_10.x, b_12.x), SafePow_0(a_10.y, b_12.y), SafePow_0(a_10.z, b_12.z));
}

fn CoatLobe_PassageColor_0( this_47 : CoatLobe_0,  cosine_0 : f32) -> vec3<f32>
{
    var _S221 : bool;
    if((cosine_0 > 0.0f))
    {
        _S221 = ((MinComponent_0(this_47.tint_0)) < 1.0f);
    }
    else
    {
        _S221 = false;
    }
    if(_S221)
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
    var _S222 : DiffuseSpecular_0;
    if(CoatLobe_HasCoat_0(this_51))
    {
        _S222 = MicrofacetReflectionLobe_Eval_1(this_51.reflection_0, wo_20, wi_19);
    }
    else
    {
        _S222 = DiffuseSpecular_Zero_0();
    }
    return _S222;
}

fn x2A_1( a_12 : DiffuseSpecular_0,  scale_3 : f32) -> DiffuseSpecular_0
{
    var _S223 : vec3<f32> = vec3<f32>(scale_3);
    return DiffuseSpecular_x24init_0(a_12.diffuse_1 * _S223, a_12.specular_1 * _S223);
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
    return SafeDivide_0(this_58.inReflected_0, this_58.inReflected_0 + BaseLobe_EstimateContribution_0(this_58.base_0, wo_23, vec3<f32>(1.0f)) * MaxComponent_0(this_58.inBaseLayerScale_0), 0.5f);
}

fn CoatLobe_EvalPdf_0( this_59 : CoatLobe_0,  wo_24 : vec3<f32>,  wi_23 : vec3<f32>,  sampled_1 : SampledLobe_0,  f_5 : ptr<function, DiffuseSpecular_0>,  pdf_3 : ptr<function, f32>)
{
    var baseF_0 : DiffuseSpecular_0;
    var basePdf_0 : f32;
    BaseLobe_EvalPdf_0(this_59.base_0, wo_24, wi_23, sampled_1, &(baseF_0), &(basePdf_0));
    if(this_59.inside_0)
    {
        (*f_5) = x2A_0(baseF_0, CoatLobe_PassageColor_0(this_59, - dot(wi_23, this_59.normal_6)));
        (*pdf_3) = basePdf_0;
        return;
    }
    var coatSampled_0 : bool = (sampled_1.layer_0) == i32(2);
    var _S224 : DiffuseSpecular_0;
    if(coatSampled_0)
    {
        _S224 = sampled_1.f_1;
    }
    else
    {
        _S224 = CoatLobe_CoatEval_0(this_59, wo_24, wi_23);
    }
    (*f_5) = CoatLobe_Combine_0(this_59, _S224, baseF_0, wi_23);
    var _S225 : f32;
    if(CoatLobe_HasCoat_0(this_59))
    {
        var _S226 : f32 = basePdf_0;
        if(coatSampled_0)
        {
            _S225 = sampled_1.pdf_0;
        }
        else
        {
            _S225 = MicrofacetReflectionLobe_Pdf_1(this_59.reflection_0, wo_24, wi_23);
        }
        _S225 = mix(_S226, _S225, CoatLobe_ReflectionProbability_0(this_59, wo_24));
    }
    else
    {
        _S225 = basePdf_0;
    }
    (*pdf_3) = _S225;
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
    var _S227 : f32 = v_10.x;
    var _S228 : f32 = v_10.y;
    return vec3<f32>(cosPhi_0 * _S227 + sinPhi_0 * - _S228, cosPhi_0 * _S228 + sinPhi_0 * _S227, v_10.z);
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
    var _S229 : i32 = ci_0 + i32(1);
    var _S230 : vec3<f32> = vec3<f32>((col_1 - c_10));
    var _S231 : i32 = ri_0 + i32(1);
    return mix(mix(FetchLTC_0(ri_0, ci_0), FetchLTC_0(ri_0, _S229), _S230), mix(FetchLTC_0(_S231, ci_0), FetchLTC_0(_S231, _S229), _S230), vec3<f32>((row_2 - r_7)));
}

fn FuzzLobe_Coefficients_0( this_63 : FuzzLobe_0,  directionLocal_0 : vec3<f32>) -> vec3<f32>
{
    return SheenLTCCoefficients_0(this_63.alpha_3, directionLocal_0.z);
}

fn SheenEvalLTC_0( wiLocal_2 : vec3<f32>,  ltc_0 : vec3<f32>) -> f32
{
    var aInv_0 : f32 = ltc_0.x;
    var _S232 : f32 = wiLocal_2.z;
    var wiOriginal_0 : vec3<f32> = vec3<f32>(aInv_0 * wiLocal_2.x + ltc_0.y * _S232, aInv_0 * wiLocal_2.y, _S232);
    var _S233 : f32 = max(0.0f, _S232);
    var lengthSquared_0 : f32 = dot(wiOriginal_0, wiOriginal_0);
    var _S234 : bool;
    if(lengthSquared_0 == 0.0f)
    {
        _S234 = true;
    }
    else
    {
        _S234 = aInv_0 == 0.0f;
    }
    if(_S234)
    {
        _S234 = true;
    }
    else
    {
        _S234 = _S233 == 0.0f;
    }
    if(_S234)
    {
        return 0.0f;
    }
    var aInvOverLengthSquared_0 : f32 = aInv_0 / lengthSquared_0;
    return 1.0f / float_getPi_0() * (_S233 * aInvOverLengthSquared_0) * aInvOverLengthSquared_0;
}

fn FuzzLobe_SheenEval_0( this_64 : FuzzLobe_0,  wiLocal_3 : vec3<f32>) -> vec3<f32>
{
    var _S235 : bool;
    if(((this_64.woLocal_0.z) <= 0.0f))
    {
        _S235 = true;
    }
    else
    {
        _S235 = ((wiLocal_3.z) <= 0.0f);
    }
    if(_S235)
    {
        _S235 = true;
    }
    else
    {
        _S235 = !FuzzLobe_HasFuzz_0(this_64);
    }
    if(_S235)
    {
        return vec3<f32>(0.0f);
    }
    var ltc_1 : vec3<f32> = FuzzLobe_Coefficients_0(this_64, this_64.woLocal_0);
    return vec3<f32>(SheenEvalLTC_0(SheenRotate_0(wiLocal_3, vec2<f32>(this_64.woLocal_0.x, - this_64.woLocal_0.y)), ltc_1)) * (vec3<f32>((this_64.presence_1 * ltc_1.z)) * this_64.tint_1);
}

fn FuzzLobe_SheenPdf_0( this_65 : FuzzLobe_0,  wiLocal_4 : vec3<f32>) -> f32
{
    var _S236 : bool;
    if(((this_65.woLocal_0.z) <= 0.0f))
    {
        _S236 = true;
    }
    else
    {
        _S236 = ((wiLocal_4.z) <= 0.0f);
    }
    if(_S236)
    {
        _S236 = true;
    }
    else
    {
        _S236 = !FuzzLobe_HasFuzz_0(this_65);
    }
    if(_S236)
    {
        return 0.0f;
    }
    return SheenEvalLTC_0(SheenRotate_0(wiLocal_4, vec2<f32>(this_65.woLocal_0.x, - this_65.woLocal_0.y)), FuzzLobe_Coefficients_0(this_65, this_65.woLocal_0));
}

fn CoatLobe_EstimateContribution_0( this_66 : CoatLobe_0,  wo_25 : vec3<f32>,  throughput_6 : vec3<f32>) -> f32
{
    var baseContribution_0 : f32 = BaseLobe_EstimateContribution_0(this_66.base_0, wo_25, throughput_6);
    if(this_66.inside_0)
    {
        return baseContribution_0;
    }
    return MaxComponent_0(throughput_6) * this_66.inReflected_0 + baseContribution_0 * MaxComponent_0(this_66.inBaseLayerScale_0);
}

fn FuzzLobe_SheenProbability_0( this_67 : FuzzLobe_0,  wo_26 : vec3<f32>) -> f32
{
    var sheenContribution_0 : f32 = this_67.viewReflected_0 * MaxComponent_0(this_67.tint_1);
    return SafeDivide_0(sheenContribution_0, sheenContribution_0 + CoatLobe_EstimateContribution_0(this_67.base_1, wo_26, vec3<f32>(1.0f)) * FuzzLobe_BaseLayerScaleIncoming_0(this_67), 0.5f);
}

fn FuzzLobe_EvalPdf_0( this_68 : FuzzLobe_0,  wo_27 : vec3<f32>,  wi_24 : vec3<f32>,  sampled_2 : SampledLobe_0,  f_6 : ptr<function, DiffuseSpecular_0>,  pdf_4 : ptr<function, f32>)
{
    var baseF_1 : DiffuseSpecular_0;
    var basePdf_1 : f32;
    CoatLobe_EvalPdf_0(this_68.base_1, wo_27, wi_24, sampled_2, &(baseF_1), &(basePdf_1));
    var wiLocal_5 : vec3<f32> = Frame_ToLocal_0(this_68.basis_0, wi_24);
    (*f_6) = x2B_0(x2A_1(baseF_1, FuzzLobe_BaseLayerScaleComplete_0(this_68, wiLocal_5)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_68, wiLocal_5)));
    var _S237 : f32;
    if(FuzzLobe_HasFuzz_0(this_68))
    {
        _S237 = mix(basePdf_1, FuzzLobe_SheenPdf_0(this_68, wiLocal_5), FuzzLobe_SheenProbability_0(this_68, wo_27));
    }
    else
    {
        _S237 = basePdf_1;
    }
    (*pdf_4) = _S237;
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
    var _S238 : Ray_0;
    _S238.origin_0 = o_8;
    _S238.direction_0 = d_5;
    _S238.tMin_0 = 0.0f;
    _S238.tMax_0 = tmax_0;
    return _S238;
}

struct HitRecord_0
{
     t_6 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_2 : u32,
     primitiveIndex_1 : u32,
};

fn rcp_0( x_22 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_22;
}

fn SafeRcp_0( d_6 : vec3<f32>) -> vec3<f32>
{
    return rcp_0(select(d_6, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_6 < vec3<f32>(0.0f))), ((abs(d_6)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn InverseTransformVector_0( _S239 : u32,  _S240 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S239].worldToObject_0[i32(0)].xyz, _S240), dot(gInstances_0[_S239].worldToObject_0[i32(1)].xyz, _S240), dot(gInstances_0[_S239].worldToObject_0[i32(2)].xyz, _S240));
}

var<private> gTraversalCost_0 : u32;

fn rcp_1( x_23 : f32) -> f32
{
    return 1.0f / x_23;
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
    var _S241 : bool;
    if((u_9 < 0.0f))
    {
        _S241 = true;
    }
    else
    {
        _S241 = (u_9 > 1.0f);
    }
    if(_S241)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_12, e1_0);
    var v_11 : f32 = f_8 * dot(d_7, q_0);
    if((v_11 < 0.0f))
    {
        _S241 = true;
    }
    else
    {
        _S241 = ((u_9 + v_11) > 1.0f);
    }
    if(_S241)
    {
        return false;
    }
    (*t_7) = f_8 * dot(e2_0, q_0);
    (*bary_1) = vec2<f32>(u_9, v_11);
    if(((*t_7) > tMin_1))
    {
        _S241 = ((*t_7) < tMax_1);
    }
    else
    {
        _S241 = false;
    }
    return _S241;
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_10 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_2 : f32,  tMax_2 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_10) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_10) * rD_0;
    var _S242 : vec3<f32> = min(t1_0, t2_0);
    var _S243 : vec3<f32> = max(t1_0, t2_0);
    var _S244 : f32 = max(max(_S242.x, _S242.y), max(_S242.z, tMin_2));
    var _S245 : f32;
    if((_S244 <= (min(min(_S243.x, _S243.y), min(_S243.z, tMax_2)))))
    {
        _S245 = _S244;
    }
    else
    {
        _S245 = 1.00000001504746622e+30f;
    }
    return _S245;
}

fn TraverseBLAS_0( _S246 : u32,  _S247 : u32,  _S248 : vec3<f32>,  _S249 : vec3<f32>,  _S250 : f32,  _S251 : bool,  _S252 : ptr<function, HitRecord_0>) -> bool
{
    var found_0 : bool;
    var _S253 : vec3<f32> = SafeRcp_0(_S249);
    var stack_1 : array<u32, i32(48)>;
    var nodeRef_0 : u32 = u32(0);
    var found_1 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var i_5 : u32;
        if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
        {
            var _S254 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
            var _S255 : u32 = (nodeRef_0 & (u32(16777215)));
            found_0 = found_1;
            i_5 = u32(0);
            loop
            {
                if((i_5 < _S254))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_2 : u32 = (gInstances_0[_S247].blasTriOffset_0 + _S255 + i_5) * u32(3);
                var v0_1 : vec4<f32> = gTris_0[base_2];
                var t_8 : f32;
                var bary_2 : vec2<f32>;
                var _S256 : bool = IntersectTriangle_0(_S248, _S249, v0_1.xyz, gTris_0[base_2 + u32(1)].xyz, gTris_0[base_2 + u32(2)].xyz, _S250, (*_S252).t_6, &(t_8), &(bary_2));
                if(!_S256)
                {
                    i_5 = i_5 + u32(1);
                    continue;
                }
                var primitiveIndex_2 : u32 = (bitcast<u32>((v0_1.w)));
                (*_S252).t_6 = t_8;
                (*_S252).barycentrics_0 = bary_2;
                (*_S252).instanceIndex_2 = _S246;
                (*_S252).primitiveIndex_1 = primitiveIndex_2;
                if(_S251)
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
        var node_0 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S247].blasNodeOffset_0 + nodeRef_0];
        var dist1_0 : f32 = IntersectBox_0(node_0.lmin_0, node_0.lmax_0, _S248, _S253, _S250, (*_S252).t_6);
        var dist2_0 : f32 = IntersectBox_0(node_0.rmin_0, node_0.rmax_0, _S248, _S253, _S250, (*_S252).t_6);
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
                var _S257 : u32 = stackPtr_0 + u32(1);
                stack_1[stackPtr_0] = far_0;
                stackPtr_3 = _S257;
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
    var _S258 : u32 = gFrame_0.counts_0.z;
    var _S259 : vec3<f32> = SafeRcp_0(ray_0.direction_0);
    var stack_2 : array<u32, i32(32)>;
    var nodeRef_1 : u32 = u32(0);
    var found_3 : bool = false;
    var stackPtr_4 : u32 = u32(0);
    loop
    {
        var i_6 : u32;
        if(((nodeRef_1 & (u32(2147483648)))) != u32(0))
        {
            var _S260 : u32 = (((nodeRef_1 >> (u32(24)))) & (u32(127)));
            var _S261 : u32 = (nodeRef_1 & (u32(16777215)));
            found_2 = found_3;
            i_6 = u32(0);
            loop
            {
                if((i_6 < _S260))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_3 : u32 = gIndices_0[_S258 + _S261 + i_6];
                var _S262 : bool = TraverseBLAS_0(instanceIndex_3, instanceIndex_3, InverseTransformPoint_0(instanceIndex_3, ray_0.origin_0), InverseTransformVector_0(instanceIndex_3, ray_0.direction_0), ray_0.tMin_0, anyHit_0, &((*hit_0)));
                if(_S262)
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
        var node_1 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_1];
        var dist1_2 : f32 = IntersectBox_0(node_1.lmin_0, node_1.lmax_0, ray_0.origin_0, _S259, ray_0.tMin_0, (*hit_0).t_6);
        var dist2_2 : f32 = IntersectBox_0(node_1.rmin_0, node_1.rmax_0, ray_0.origin_0, _S259, ray_0.tMin_0, (*hit_0).t_6);
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
                var _S263 : u32 = stackPtr_4 + u32(1);
                stack_2[stackPtr_4] = far_1;
                stackPtr_7 = _S263;
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
    var _S264 : bool = TraceScene_0(ray_1, true, &(hit_1));
    return _S264;
}

fn EvalMISRobust_0( pdf_6 : f32,  otherPdf_0 : f32) -> f32
{
    if(pdf_6 == otherPdf_0)
    {
        return 0.5f;
    }
    if((otherPdf_0 < pdf_6))
    {
        var x_24 : f32 = otherPdf_0 / pdf_6;
        return 1.0f / (1.0f + x_24 * x_24);
    }
    var x_25 : f32 = pdf_6 / otherPdf_0;
    return 1.0f - 1.0f / (1.0f + x_25 * x_25);
}

fn NextEventEstimation_0( si_1 : SurfaceInteraction_0,  bsdf_0 : BSDF_0,  cone_1 : vec2<f32>,  rng_4 : ptr<function, RandomSequence_0>) -> vec3<f32>
{
    var _S265 : vec3<f32> = vec3<f32>(0.0f);
    gRayCone_0 = cone_1;
    var source_0 : u32 = u32(0);
    var result_3 : vec3<f32> = _S265;
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
            var _S266 : vec3<f32> = ShadowOrigin_0(si_1, dir_8);
            shadow_1 = true;
            origin_1 = _S266;
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
                var _S267 : bool = !ls_2.delta_0;
                shadow_1 = ls_2.shadow_0;
                origin_1 = origin_2;
                maxDistance_0 = maxDistance_1;
                mis_0 = _S267;
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
                var _S268 : vec3<f32> = ShadowOrigin_0(si_1, dir_11);
                shadow_1 = true;
                origin_1 = _S268;
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
        var _S269 : bool;
        if((any(((f_9 > vec3<f32>(0.0f))))))
        {
            if(!shadow_1)
            {
                _S269 = true;
            }
            else
            {
                var _S270 : bool = TraceOcclusion_0(Ray_x24init_0(origin_1, dir_7, maxDistance_0));
                _S269 = !_S270;
            }
        }
        else
        {
            _S269 = false;
        }
        var result_4 : vec3<f32>;
        if(_S269)
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

fn LoadTriangleIndices_0( _S271 : u32,  _S272 : u32) -> vec3<u32>
{
    var base_3 : u32 = gInstances_0[_S271].indexOffset_0 + _S272 * u32(3);
    return vec3<u32>(gIndices_0[base_3], gIndices_0[base_3 + u32(1)], gIndices_0[base_3 + u32(2)]) + vec3<u32>(gInstances_0[_S271].vertexOffset_0);
}

fn TransformPoint_0( _S273 : u32,  _S274 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S273].objectToWorld_0[i32(0)].xyz, _S274) + gInstances_0[_S273].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S273].objectToWorld_0[i32(1)].xyz, _S274) + gInstances_0[_S273].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S273].objectToWorld_0[i32(2)].xyz, _S274) + gInstances_0[_S273].objectToWorld_0[i32(2)].w);
}

fn TransformNormal_0( _S275 : u32,  _S276 : vec3<f32>) -> vec3<f32>
{
    return gInstances_0[_S275].worldToObject_0[i32(0)].xyz * vec3<f32>(_S276.x) + gInstances_0[_S275].worldToObject_0[i32(1)].xyz * vec3<f32>(_S276.y) + gInstances_0[_S275].worldToObject_0[i32(2)].xyz * vec3<f32>(_S276.z);
}

fn VertexUV0_0( v_12 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_12).positionU_0.w, (*v_12).normalV_0.w);
}

fn TransformVector_0( _S277 : u32,  _S278 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S277].objectToWorld_0[i32(0)].xyz, _S278), dot(gInstances_0[_S277].objectToWorld_0[i32(1)].xyz, _S278), dot(gInstances_0[_S277].objectToWorld_0[i32(2)].xyz, _S278));
}

fn GetSurfaceInteraction_0( rayDirection_0 : vec3<f32>,  hit_2 : HitRecord_0,  coneWidth_3 : f32) -> SurfaceInteraction_0
{
    var _S279 : vec3<u32> = LoadTriangleIndices_0(hit_2.instanceIndex_2, hit_2.primitiveIndex_1);
    var _S280 : Vertex_std430_0 = gVertices_0[_S279.x];
    var _S281 : Vertex_std430_0 = gVertices_0[_S279.y];
    var _S282 : Vertex_std430_0 = gVertices_0[_S279.z];
    var _S283 : f32 = hit_2.barycentrics_0.x;
    var _S284 : f32 = hit_2.barycentrics_0.y;
    var _S285 : f32 = 1.0f - _S283 - _S284;
    var p0_1 : vec3<f32> = _S280.positionU_0.xyz;
    var p1_1 : vec3<f32> = _S281.positionU_0.xyz;
    var p2_1 : vec3<f32> = _S282.positionU_0.xyz;
    var si_2 : SurfaceInteraction_0;
    si_2.instanceIndex_0 = hit_2.instanceIndex_2;
    si_2.primitiveIndex_0 = hit_2.primitiveIndex_1;
    si_2.materialIndex_1 = gInstances_0[hit_2.instanceIndex_2].materialIndex_0;
    var _S286 : vec3<f32> = vec3<f32>(_S285);
    var _S287 : vec3<f32> = vec3<f32>(_S283);
    var _S288 : vec3<f32> = vec3<f32>(_S284);
    var _S289 : vec3<f32> = p0_1 * _S286 + p1_1 * _S287 + p2_1 * _S288;
    si_2.position_0 = TransformPoint_0(hit_2.instanceIndex_2, _S289);
    var _S290 : vec3<f32> = p1_1 - p0_1;
    var _S291 : vec3<f32> = p2_1 - p0_1;
    si_2.faceNormal_0 = normalize(TransformNormal_0(hit_2.instanceIndex_2, cross(normalize(_S290), normalize(_S291))));
    var n_8 : vec3<f32> = _S280.normalV_0.xyz * _S286 + _S281.normalV_0.xyz * _S287 + _S282.normalV_0.xyz * _S288;
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
    var _S292 : vec2<f32> = VertexUV0_0(&(_S280));
    var _S293 : vec2<f32> = VertexUV0_0(&(_S281));
    var _S294 : vec2<f32> = VertexUV0_0(&(_S282));
    var _S295 : vec2<f32> = vec2<f32>(_S285);
    var _S296 : vec2<f32> = vec2<f32>(_S283);
    var _S297 : vec2<f32> = vec2<f32>(_S284);
    var _S298 : vec2<f32> = _S280.uv1_0.xy;
    var _S299 : vec2<f32> = _S281.uv1_0.xy;
    var _S300 : vec2<f32> = _S282.uv1_0.xy;
    si_2.tex_0 = MakeTextureCoords_0(_S292 * _S295 + _S293 * _S296 + _S294 * _S297, _S298 * _S295 + _S299 * _S296 + _S300 * _S297, TransformVector_0(hit_2.instanceIndex_2, _S290), TransformVector_0(hit_2.instanceIndex_2, _S291), _S293 - _S292, _S294 - _S292, _S299 - _S298, _S300 - _S298, coneWidth_3, dot(si_2.faceNormal_0, rayDirection_0));
    si_2.tex_0.objectPosition_0 = _S289;
    si_2.frontFacing_0 = ((dot(si_2.faceNormal_0, (vec3<f32>(0) - rayDirection_0))) > 0.0f);
    var _S301 : vec4<f32> = _S280.tangent_0;
    var t_10 : vec3<f32> = _S280.tangent_0.xyz * _S286 + _S281.tangent_0.xyz * _S287 + _S282.tangent_0.xyz * _S288;
    if(((dot(t_10, t_10)) > 0.0f))
    {
        t_9 = normalize(TransformVector_0(hit_2.instanceIndex_2, t_10));
    }
    else
    {
        t_9 = vec3<f32>(0.0f);
    }
    si_2.tangent_1 = vec4<f32>(t_9, _S301.w);
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
    var _S302 : f32 = tangent_4.w;
    var _S303 : bool;
    if(_S302 == 0.0f)
    {
        _S303 = true;
    }
    else
    {
        var _S304 : vec3<f32> = tangent_4.xyz;
        _S303 = (dot(_S304, _S304)) == 0.0f;
    }
    if(_S303)
    {
        return vec3<f32>(0.0f);
    }
    var _S305 : vec3<f32> = tangent_4.xyz;
    return cross(n_9, normalize(_S305 - n_9 * vec3<f32>(dot(_S305, n_9)))) * vec3<f32>(_S302);
}

fn ApplyNormalMap_0( tangent_5 : vec4<f32>,  n_10 : vec3<f32>,  texel_0 : vec3<f32>,  scale_4 : f32) -> vec3<f32>
{
    var _S306 : f32 = tangent_5.w;
    var _S307 : bool;
    if(_S306 == 0.0f)
    {
        _S307 = true;
    }
    else
    {
        var _S308 : vec3<f32> = tangent_5.xyz;
        _S307 = (dot(_S308, _S308)) == 0.0f;
    }
    if(_S307)
    {
        return n_10;
    }
    var _S309 : vec2<f32> = (texel_0.xy * vec2<f32>(2.0f) - vec2<f32>(1.0f)) * vec2<f32>(scale_4);
    var local_2 : vec3<f32>;
    local_2.x = _S309.x;
    local_2.y = _S309.y;
    var _S310 : f32 = texel_0.z;
    var _S311 : f32;
    if((_S310 <= 0.0f))
    {
        _S311 = sqrt(saturate(1.0f - dot(local_2.xy, local_2.xy)));
    }
    else
    {
        _S311 = abs(_S310 * 2.0f - 1.0f);
    }
    local_2[i32(2)] = _S311;
    if((dot(local_2, local_2)) == 0.0f)
    {
        return n_10;
    }
    var _S312 : vec3<f32> = normalize(local_2);
    local_2 = _S312;
    var _S313 : vec3<f32> = tangent_5.xyz;
    var t_11 : vec3<f32> = normalize(_S313 - n_10 * vec3<f32>(dot(_S313, n_10)));
    return normalize(t_11 * vec3<f32>(_S312.x) + cross(n_10, t_11) * vec3<f32>(_S306) * vec3<f32>(_S312.y) + n_10 * vec3<f32>(_S312.z));
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
        var _S314 : u32 = ins_1.x;
        var op_1 : u32 = (_S314 & (u32(255)));
        var dst_1 : u32 = (((_S314 >> (u32(8)))) & (u32(15)));
        var imm_1 : u32 = (_S314 >> (u32(16)));
        if(op_1 == u32(0))
        {
            return;
        }
        var _S315 : vec4<f32> = vec4<f32>(0.0f);
        var _S316 : bool;
        if(((gMaterialOperandMode_0 & (u32(2)))) == u32(0))
        {
            _S316 = true;
        }
        else
        {
            _S316 = op_1 != u32(23);
        }
        var write_1 : bool;
        var a_14 : vec4<f32>;
        var b_13 : vec4<f32>;
        var c_11 : vec4<f32>;
        if(_S316)
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
                            a_14 = _S315;
                        }
                    }
                }
            }
            else
            {
                a_14 = _S315;
            }
            var _S317 : vec4<f32> = MaterialOperand_0(ins_1.y, a_14, header_5.constantBase_0);
            var _S318 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S318 = true;
            }
            else
            {
                _S318 = (((ins_1.z) & (u32(2147483648)))) == u32(0);
            }
            if(_S318)
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
                            b_13 = _S315;
                        }
                    }
                }
            }
            else
            {
                b_13 = _S315;
            }
            var _S319 : vec4<f32> = MaterialOperand_0(ins_1.z, b_13, header_5.constantBase_0);
            var _S320 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S320 = true;
            }
            else
            {
                _S320 = (((ins_1.w) & (u32(2147483648)))) == u32(0);
            }
            if(_S320)
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
                            c_11 = _S315;
                        }
                    }
                }
            }
            else
            {
                c_11 = _S315;
            }
            var _S321 : vec4<f32> = MaterialOperand_0(ins_1.w, c_11, header_5.constantBase_0);
            a_14 = _S317;
            b_13 = _S319;
            c_11 = _S321;
        }
        else
        {
            a_14 = _S315;
            b_13 = _S315;
            c_11 = _S315;
        }
        var operands_1 : u32 = pc_2 * u32(4) + u32(1);
        var _S322 : u32;
        if(op_1 == u32(23))
        {
            _S322 = (((u32(351898) >> ((u32(2) * min(imm_1, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_1 == u32(17))
            {
                _S322 = u32(1) + imm_1 / u32(4);
            }
            else
            {
                _S322 = u32(1);
            }
        }
        var pc_3 : u32 = pc_2 + _S322;
        var r_8 : vec4<f32> = _S315;
        var slot_2 : vec4<f32>;
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
                            slot_2 = stack_3[(o_11 & (u32(15)))];
                        }
                        else
                        {
                            switch((o_11 & (u32(15))))
                            {
                            case u32(0):
                                {
                                    slot_2 = stack_3[i32(0)];
                                }
                            case u32(1):
                                {
                                    slot_2 = stack_3[i32(1)];
                                }
                            case u32(2):
                                {
                                    slot_2 = stack_3[i32(2)];
                                }
                            case u32(3):
                                {
                                    slot_2 = stack_3[i32(3)];
                                }
                            case u32(4):
                                {
                                    slot_2 = stack_3[i32(4)];
                                }
                            case u32(5):
                                {
                                    slot_2 = stack_3[i32(5)];
                                }
                            case u32(6):
                                {
                                    slot_2 = stack_3[i32(6)];
                                }
                            case u32(7):
                                {
                                    slot_2 = stack_3[i32(7)];
                                }
                            case u32(8):
                                {
                                    slot_2 = stack_3[i32(8)];
                                }
                            case u32(9):
                                {
                                    slot_2 = stack_3[i32(9)];
                                }
                            case u32(10):
                                {
                                    slot_2 = stack_3[i32(10)];
                                }
                            case u32(11):
                                {
                                    slot_2 = stack_3[i32(11)];
                                }
                            case u32(12):
                                {
                                    slot_2 = stack_3[i32(12)];
                                }
                            case u32(13):
                                {
                                    slot_2 = stack_3[i32(13)];
                                }
                            case u32(14):
                                {
                                    slot_2 = stack_3[i32(14)];
                                }
                            case u32(15):
                                {
                                    slot_2 = stack_3[i32(15)];
                                }
                            default :
                                {
                                    slot_2 = _S315;
                                }
                            }
                        }
                    }
                    else
                    {
                        slot_2 = _S315;
                    }
                    r_8[i32(3)] = MaterialOperand_0(o_11, slot_2, header_5.constantBase_0).x;
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
                r_8 = vec4<f32>(dot(select(_S315, a_14, lanes_1), select(_S315, b_13, lanes_1)));
                write_1 = true;
            }
        case u32(19):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(19)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var len_1 : f32 = length(select(_S315, a_14, LanesBelow_0(imm_1)));
                if((len_1 > 0.0f))
                {
                    slot_2 = a_14 / vec4<f32>(len_1);
                }
                else
                {
                    slot_2 = _S315;
                }
                r_8 = slot_2;
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
                    var _S323 : vec4<f32> = SampleTexture_0(ref_9, ctx_4.tex_1);
                    slot_2 = _S323;
                }
                else
                {
                    slot_2 = vec4<f32>(1.0f);
                }
                r_8 = slot_2;
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
                r_8 = select(_S315, vec4<f32>(1.0f), (a_14 > b_13));
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
                var _S324 : vec3<f32>;
                if(imm_1 == u32(1))
                {
                    _S324 = TransformVector_0(ctx_4.instanceIndex_1, a_14.xyz);
                }
                else
                {
                    _S324 = InverseTransformVector_0(ctx_4.instanceIndex_1, a_14.xyz);
                }
                r_8 = vec4<f32>(_S324, 0.0f);
                write_1 = true;
            }
        case u32(32):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(0)))) & (u32(1)))) == u32(0))
                {
                    write_1 = true;
                    break;
                }
                var _S325 : bool = ((imm_1 & (u32(2)))) != u32(0);
                var v_13 : vec3<f32> = BlenderNoise_0(a_14.xyz, b_13, ((imm_1 & (u32(1)))) != u32(0), _S325);
                if(_S325)
                {
                    slot_2 = vec4<f32>(v_13, 0.0f);
                }
                else
                {
                    slot_2 = vec4<f32>(v_13.x);
                }
                r_8 = slot_2;
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
                                    slot_2 = stack_3[(o_12 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_12 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.baseWeight_0 = MaterialOperand_0(o_12, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_13 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_13 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.baseColor_0 = MaterialOperand_0(o_13, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_14 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_14 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.baseDiffuseRoughness_0 = MaterialOperand_0(o_14, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_15 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_15 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.baseMetalness_0 = MaterialOperand_0(o_15, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_16 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_16 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularWeight_0 = MaterialOperand_0(o_16, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_17 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_17 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularColor_0 = MaterialOperand_0(o_17, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_18 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_18 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularRoughness_0 = MaterialOperand_0(o_18, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_19 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_19 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularIor_0 = MaterialOperand_0(o_19, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_20 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_20 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularDielectricOnly_0 = (MaterialOperand_0(o_20, slot_2, header_5.constantBase_0).x) != 0.0f;
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
                                    slot_2 = stack_3[(o_21 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_21 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.specularRoughnessAnisotropy_0 = MaterialOperand_0(o_21, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_22 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_22 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).tangent_2 = MaterialOperand_0(o_22, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_23 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_23 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionWeight_0 = MaterialOperand_0(o_23, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_24 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_24 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionColor_0 = MaterialOperand_0(o_24, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_25 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_25 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionDepth_0 = MaterialOperand_0(o_25, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_26 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_26 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionScatter_0 = MaterialOperand_0(o_26, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_27 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_27 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionScatterAnisotropy_0 = MaterialOperand_0(o_27, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_28 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_28 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionDispersionScale_0 = MaterialOperand_0(o_28, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_29 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_29 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.transmissionDispersionAbbeNumber_0 = MaterialOperand_0(o_29, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_30 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_30 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.subsurfaceWeight_0 = MaterialOperand_0(o_30, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_31 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_31 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.subsurfaceColor_0 = MaterialOperand_0(o_31, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_32 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_32 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.subsurfaceRadius_0 = MaterialOperand_0(o_32, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_33 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_33 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.subsurfaceRadiusScale_0 = MaterialOperand_0(o_33, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_34 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_34 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.subsurfaceScatterAnisotropy_0 = MaterialOperand_0(o_34, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_35 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_35 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatWeight_0 = MaterialOperand_0(o_35, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_36 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_36 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatColor_0 = MaterialOperand_0(o_36, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_37 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_37 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatRoughness_0 = MaterialOperand_0(o_37, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_38 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_38 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatRoughnessAnisotropy_0 = MaterialOperand_0(o_38, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_39 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_39 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatIor_0 = MaterialOperand_0(o_39, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_40 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_40 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.coatDarkening_0 = MaterialOperand_0(o_40, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_41 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_41 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).coatNormal_0 = MaterialOperand_0(o_41, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_42 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_42 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).coatTangent_0 = MaterialOperand_0(o_42, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_43 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_43 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.fuzzWeight_0 = MaterialOperand_0(o_43, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_44 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_44 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.fuzzColor_0 = MaterialOperand_0(o_44, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_45 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_45 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.fuzzRoughness_0 = MaterialOperand_0(o_45, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_46 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_46 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.thinFilmWeight_1 = MaterialOperand_0(o_46, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_47 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_47 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.thinFilmThickness_1 = MaterialOperand_0(o_47, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_48 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_48 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.thinFilmIor_1 = MaterialOperand_0(o_48, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_49 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_49 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_49, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_50 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_50 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.emissionColor_0 = MaterialOperand_0(o_50, slot_2, header_5.constantBase_0).xyz;
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
                                    slot_2 = stack_3[(o_51 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_51 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_51, slot_2, header_5.constantBase_0).x;
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
                                    slot_2 = stack_3[(o_52 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_52 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_52, slot_2, header_5.constantBase_0).x) != 0.0f;
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
                                    slot_2 = stack_3[(o_53 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_53 & (u32(15))))
                                    {
                                    case u32(0):
                                        {
                                            slot_2 = stack_3[i32(0)];
                                        }
                                    case u32(1):
                                        {
                                            slot_2 = stack_3[i32(1)];
                                        }
                                    case u32(2):
                                        {
                                            slot_2 = stack_3[i32(2)];
                                        }
                                    case u32(3):
                                        {
                                            slot_2 = stack_3[i32(3)];
                                        }
                                    case u32(4):
                                        {
                                            slot_2 = stack_3[i32(4)];
                                        }
                                    case u32(5):
                                        {
                                            slot_2 = stack_3[i32(5)];
                                        }
                                    case u32(6):
                                        {
                                            slot_2 = stack_3[i32(6)];
                                        }
                                    case u32(7):
                                        {
                                            slot_2 = stack_3[i32(7)];
                                        }
                                    case u32(8):
                                        {
                                            slot_2 = stack_3[i32(8)];
                                        }
                                    case u32(9):
                                        {
                                            slot_2 = stack_3[i32(9)];
                                        }
                                    case u32(10):
                                        {
                                            slot_2 = stack_3[i32(10)];
                                        }
                                    case u32(11):
                                        {
                                            slot_2 = stack_3[i32(11)];
                                        }
                                    case u32(12):
                                        {
                                            slot_2 = stack_3[i32(12)];
                                        }
                                    case u32(13):
                                        {
                                            slot_2 = stack_3[i32(13)];
                                        }
                                    case u32(14):
                                        {
                                            slot_2 = stack_3[i32(14)];
                                        }
                                    case u32(15):
                                        {
                                            slot_2 = stack_3[i32(15)];
                                        }
                                    default :
                                        {
                                            slot_2 = _S315;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_2 = _S315;
                            }
                            (*outputs_1).normal_9 = MaterialOperand_0(o_53, slot_2, header_5.constantBase_0).xyz;
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
    var _S326 : f32 = n_13.z;
    var s_13 : f32;
    if((_S326 >= 0.0f))
    {
        s_13 = 1.0f;
    }
    else
    {
        s_13 = -1.0f;
    }
    var a_15 : f32 = -1.0f / (s_13 + _S326);
    var _S327 : f32 = n_13.x;
    var _S328 : f32 = n_13.y;
    var b_14 : f32 = _S327 * _S328 * a_15;
    (*b1_1) = vec3<f32>(1.0f + s_13 * _S327 * _S327 * a_15, s_13 * b_14, - s_13 * _S327);
    (*b2_1) = vec3<f32>(b_14, s_13 + _S328 * _S328 * a_15, - _S328);
    return;
}

fn Frame_FromNormal_0( n_14 : vec3<f32>) -> Frame_0
{
    var f_10 : Frame_0;
    f_10.n_1 = n_14;
    var _S329 : vec3<f32> = f_10.t_0;
    var _S330 : vec3<f32> = f_10.b_0;
    BranchlessONB_1(n_14, &(_S329), &(_S330));
    f_10.t_0 = _S329;
    f_10.b_0 = _S330;
    return f_10;
}

fn Frame_FromTangent_0( tangent_6 : vec4<f32>,  n_15 : vec3<f32>) -> Frame_0
{
    var _S331 : vec3<f32> = tangent_6.xyz;
    var NdotT_0 : f32 = dot(_S331, n_15);
    var _S332 : f32 = tangent_6.w;
    var valid_0 : bool;
    if(_S332 != 0.0f)
    {
        valid_0 = ((dot(_S331, _S331)) > 0.0f);
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
    var _S333 : vec3<f32> = normalize(_S331 - n_15 * vec3<f32>(NdotT_0));
    f_11.t_0 = _S333;
    f_11.b_0 = cross(n_15, _S333) * vec3<f32>(_S332);
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
    var _S334 : f32 = si_3.tangent_1.w;
    var handedness_0 : f32;
    if(_S334 != 0.0f)
    {
        handedness_0 = _S334;
    }
    else
    {
        handedness_0 = 1.0f;
    }
    ms_0.inputs_1.basis_1 = Frame_FromTangent_0(vec4<f32>(o_54.tangent_2, handedness_0), AlignWithFace_0(o_54.normal_9, V_1, si_3.frontFacing_0));
    var _S335 : bool;
    if((all(((o_54.coatNormal_0) == (o_54.normal_9)))))
    {
        _S335 = (all(((o_54.coatTangent_0) == (o_54.tangent_2))));
    }
    else
    {
        _S335 = false;
    }
    if(_S335)
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
    var _S336 : HomogeneousVolume_0;
    _S336.extinction_0 = extinction_1;
    _S336.albedo_0 = albedo_4;
    _S336.anisotropy_0 = anisotropy_1;
    return _S336;
}

fn HomogeneousVolume_Empty_0() -> HomogeneousVolume_0
{
    var _S337 : vec3<f32> = vec3<f32>(0.0f);
    return HomogeneousVolume_x24init_0(_S337, _S337, 0.0f);
}

fn Square_1( v_14 : vec3<f32>) -> vec3<f32>
{
    return v_14 * v_14;
}

fn CreateSubsurfaceVolume_0( radius_2 : f32,  radiusScale_0 : vec3<f32>,  color_4 : vec3<f32>,  anisotropy_2 : f32) -> HomogeneousVolume_0
{
    var _S338 : vec3<f32> = vec3<f32>(1.0f);
    var g_2 : f32 = clamp(anisotropy_2, -0.99900001287460327f, 0.99900001287460327f);
    var _S339 : vec3<f32> = Square_1(vec3<f32>(4.0971198081970215f) + vec3<f32>(4.2086300849914551f) * color_4 - sqrt(vec3<f32>(9.5921697616577148f) + vec3<f32>(41.680801391601562f) * color_4 + vec3<f32>(17.712600708007812f) * Square_1(color_4)));
    return HomogeneousVolume_x24init_0(_S338 / max(vec3<f32>(radius_2) * radiusScale_0, vec3<f32>(0.0010000000474974513f)), saturate((_S338 - _S339) / (_S338 - vec3<f32>(g_2) * _S339)), g_2);
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
        var _S340 : f32;
        if(((extinction_2[i32(0)]) > 0.0f))
        {
            _S340 = scattering_0[i32(0)] / extinction_2[i32(0)];
        }
        else
        {
            _S340 = 0.0f;
        }
        albedo_5[i32(0)] = _S340;
        if(((extinction_2[i32(1)]) > 0.0f))
        {
            _S340 = scattering_0[i32(1)] / extinction_2[i32(1)];
        }
        else
        {
            _S340 = 0.0f;
        }
        albedo_5[i32(1)] = _S340;
        if(((extinction_2[i32(2)]) > 0.0f))
        {
            _S340 = scattering_0[i32(2)] / extinction_2[i32(2)];
        }
        else
        {
            _S340 = 0.0f;
        }
        albedo_5[i32(2)] = _S340;
    }
    return HomogeneousVolume_x24init_0(extinction_2, albedo_5, anisotropy_3);
}

fn CreateTransmissionVolume_0( color_5 : vec3<f32>,  depth_1 : f32,  scatter_0 : vec3<f32>,  anisotropy_4 : f32) -> HomogeneousVolume_0
{
    var _S341 : bool;
    if(((MinComponent_0(color_5)) >= 1.0f))
    {
        _S341 = ((MaxComponent_0(scatter_0)) <= 0.0f);
    }
    else
    {
        _S341 = false;
    }
    if(_S341)
    {
        return HomogeneousVolume_Empty_0();
    }
    var _S342 : vec3<f32> = vec3<f32>((1.0f / max(depth_1, 0.0010000000474974513f)));
    var scattering_1 : vec3<f32> = scatter_0 * _S342;
    var absorption_2 : vec3<f32> = (vec3<f32>(0) - log(max(color_5, vec3<f32>(0.0010000000474974513f)))) * _S342 - scattering_1;
    var _S343 : f32 = MinComponent_0(absorption_2);
    var absorption_3 : vec3<f32>;
    if((_S343 < 0.0f))
    {
        absorption_3 = absorption_2 - vec3<f32>(_S343);
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
    var _S344 : vec3<f32> = vec3<f32>(weightA_0);
    var _S345 : vec3<f32> = vec3<f32>(weightB_0);
    return HomogeneousVolume_FromAbsorptionAndScattering_0(HomogeneousVolume_Absorption_0(a_16) * _S344 + HomogeneousVolume_Absorption_0(b_15) * _S345, HomogeneousVolume_Scattering_0(a_16) * _S344 + HomogeneousVolume_Scattering_0(b_15) * _S345, SafeDivide_0(a_16.anisotropy_0 * weightA_0 + b_15.anisotropy_0 * weightB_0, weightA_0 + weightB_0, 0.0f));
}

fn PrepareVolume_0( inputs_2 : BSDFInputs_0,  derived_0 : ptr<function, VolumeDerived_0>) -> HomogeneousVolume_0
{
    var _S346 : HomogeneousVolume_0 = HomogeneousVolume_Empty_0();
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
            subsurfaceVolume_0 = _S346;
        }
    }
    else
    {
        subsurfaceVolume_0 = _S346;
    }
    (*derived_0).transmissionTint_0 = vec3<f32>(1.0f);
    var transmissionVolume_0 : HomogeneousVolume_0;
    if(((inputs_2.transmissionWeight_0) > 0.0f))
    {
        var _S347 : bool;
        if((inputs_2.transmissionDepth_0) == 0.0f)
        {
            _S347 = true;
        }
        else
        {
            _S347 = inputs_2.geometryThinWalled_0;
        }
        if(_S347)
        {
            (*derived_0).transmissionTint_0 = inputs_2.transmissionColor_0;
            transmissionVolume_0 = _S346;
        }
        else
        {
            transmissionVolume_0 = CreateTransmissionVolume_0(inputs_2.transmissionColor_0, inputs_2.transmissionDepth_0, inputs_2.transmissionScatter_0, inputs_2.transmissionScatterAnisotropy_0);
        }
    }
    else
    {
        transmissionVolume_0 = _S346;
    }
    var subsurfaceFraction_0 : f32 = (1.0f - inputs_2.transmissionWeight_0) * inputs_2.subsurfaceWeight_0;
    var invTotal_0 : f32 = SafeDivide_0(1.0f, subsurfaceFraction_0 + inputs_2.transmissionWeight_0, 0.0f);
    return AddVolumes_0(subsurfaceVolume_0, transmissionVolume_0, subsurfaceFraction_0 * invTotal_0, inputs_2.transmissionWeight_0 * invTotal_0);
}

fn Frame_Handedness_0( this_72 : Frame_0) -> f32
{
    var _S348 : f32;
    if(((dot(cross(this_72.t_0, this_72.b_0), this_72.n_1)) >= 0.0f))
    {
        _S348 = 1.0f;
    }
    else
    {
        _S348 = -1.0f;
    }
    return _S348;
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
    var _S349 : vec3<f32> = vec3<f32>(cs_0.x);
    var _S350 : vec3<f32> = vec3<f32>(h_11);
    var _S351 : vec3<f32> = vec3<f32>(cs_0.y);
    f_12.t_0 = this_73.t_0 * _S349 + _S350 * this_73.b_0 * _S351;
    f_12.b_0 = this_73.b_0 * _S349 - _S350 * this_73.t_0 * _S351;
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
    var _S352 : f32;
    if((eta_6 < 1.0f))
    {
        _S352 = 1.0f / externalIor_0;
    }
    else
    {
        _S352 = externalIor_0;
    }
    return _S352;
}

fn Average_0( v_15 : vec3<f32>) -> f32
{
    return Sum_0(v_15) * 0.3333333432674408f;
}

fn FourthPower_0( x_26 : f32) -> f32
{
    var xx_2 : f32 = x_26 * x_26;
    return xx_2 * xx_2;
}

fn FourthRoot_0( x_27 : f32) -> f32
{
    return sqrt(sqrt(x_27));
}

fn AnisotropicAlpha_0( isotropicAlpha_1 : f32,  anisotropy_5 : f32) -> vec2<f32>
{
    var alpha_13 : vec2<f32>;
    if((anisotropy_5 > 0.0f))
    {
        var _S353 : f32 = 1.0f - anisotropy_5;
        alpha_13[i32(0)] = isotropicAlpha_1 * sqrt(2.0f / (1.0f + Square_0(_S353)));
        alpha_13[i32(1)] = _S353 * alpha_13.x;
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
    var _S354 : f32 = eta_7 * eta_7;
    return 0.99711799621582031f + 0.10140000283718109f * eta_7 - 0.96524101495742798f * _S354 - 0.1306069940328598f * _S354 * eta_7;
}

fn GGXDistribution_x24init_0( alpha_14 : vec2<f32>,  frame_2 : Frame_0,  isotropicAlpha_2 : f32) -> GGXDistribution_0
{
    var _S355 : GGXDistribution_0;
    _S355.alpha_0 = alpha_14;
    _S355.frame_1 = frame_2;
    _S355.isotropicAlpha_0 = isotropicAlpha_2;
    return _S355;
}

fn BSDFInputs_HasDispersion_0( this_75 : BSDFInputs_0) -> bool
{
    var _S356 : bool;
    if(((this_75.transmissionDispersionScale_0) > 0.0f))
    {
        _S356 = ((this_75.transmissionDispersionAbbeNumber_0) > 0.0f);
    }
    else
    {
        _S356 = false;
    }
    if(_S356)
    {
        _S356 = ((this_75.baseMetalness_0) < 1.0f);
    }
    else
    {
        _S356 = false;
    }
    return _S356;
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
    var _S357 : SpecularLobe_0;
    _S357.normal_1 = normal_12;
    _S357.distribution_0 = distribution_2;
    _S357.coefficient_0 = coefficient_2;
    _S357.eta_0 = eta_9;
    _S357.throughput_0 = throughput_8;
    return _S357;
}

fn IdealDielectricReflectionRatio_0( ior_6 : f32,  alpha_15 : f32) -> f32
{
    return LookUpBilinear_0(i32(65), IorToExactIndex_0(ior_6), AlphaToExactIndex_0(alpha_15));
}

fn DielectricMultipleScatteringLobe_x24init_0( normal_13 : vec3<f32>,  wo_28 : vec3<f32>,  alpha_16 : f32,  eta_10 : f32,  reflectionScale_1 : vec3<f32>,  transmissionScale_1 : vec3<f32>) -> DielectricMultipleScatteringLobe_0
{
    var _S358 : DielectricMultipleScatteringLobe_0;
    _S358.normal_2 = normal_13;
    _S358.alpha_1 = alpha_16;
    _S358.eta_1 = eta_10;
    _S358.reflectionScale_0 = reflectionScale_1;
    _S358.transmissionScale_0 = transmissionScale_1;
    _S358.reflectionRatio_0 = 0.0f;
    _S358.energyComplementWo_0 = 0.0f;
    var _S359 : bool;
    if((alpha_16 >= 0.0015999999595806003f))
    {
        _S359 = (any((((max(reflectionScale_1, transmissionScale_1)) > vec3<f32>(0.0f)))));
    }
    else
    {
        _S359 = false;
    }
    if(_S359)
    {
        _S358.reflectionRatio_0 = IdealDielectricReflectionRatio_0(eta_10, alpha_16);
        _S358.energyComplementWo_0 = IdealDielectricEnergyComplement_0(eta_10, alpha_16, dot(wo_28, normal_13));
    }
    return _S358;
}

fn MetalMultipleScatteringLobe_x24init_0( normal_14 : vec3<f32>,  wo_29 : vec3<f32>,  alpha_17 : f32,  scale_5 : vec3<f32>) -> MetalMultipleScatteringLobe_0
{
    var _S360 : MetalMultipleScatteringLobe_0;
    _S360.normal_3 = normal_14;
    _S360.alpha_2 = alpha_17;
    _S360.scale_0 = scale_5;
    var _S361 : bool;
    if(MetalMultipleScatteringLobe_Active_0(_S360))
    {
        _S361 = (any(((scale_5 > vec3<f32>(0.0f)))));
    }
    else
    {
        _S361 = false;
    }
    var _S362 : f32;
    if(_S361)
    {
        _S362 = IdealMetalEnergyComplement_0(alpha_17, dot(wo_29, normal_14));
    }
    else
    {
        _S362 = 0.0f;
    }
    _S360.energyComplementWo_1 = _S362;
    return _S360;
}

fn OpaqueDielectricAverageEnergyComplement_0( ior_7 : f32,  alpha_18 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpBilinear_0(i32(66), IorToExactIndex_0(ior_7), AlphaToExactIndex_0(alpha_18)), ior_7);
}

fn DiffuseLobe_x24init_0( normal_15 : vec3<f32>,  wo_30 : vec3<f32>,  albedo_6 : vec3<f32>,  roughness_5 : f32,  specularAlpha_1 : f32,  specularEta_1 : f32) -> DiffuseLobe_0
{
    var _S363 : DiffuseLobe_0;
    _S363.normal_4 = normal_15;
    _S363.albedo_1 = albedo_6;
    _S363.roughness_0 = roughness_5;
    _S363.specularAlpha_0 = specularAlpha_1;
    _S363.specularEta_0 = specularEta_1;
    _S363.specularCompensation_0 = 0.0f;
    if((any(((albedo_6 > vec3<f32>(0.0f))))))
    {
        _S363.specularCompensation_0 = OpaqueDielectricEnergyComplement_0(specularEta_1, specularAlpha_1, dot(wo_30, normal_15)) / ClampAverageEnergyComplement_0(OpaqueDielectricAverageEnergyComplement_0(specularEta_1, specularAlpha_1));
    }
    return _S363;
}

fn ConstantReflection_x24init_0( color_6 : vec3<f32>) -> ConstantReflection_0
{
    var _S364 : ConstantReflection_0;
    _S364.color_0 = color_6;
    return _S364;
}

fn MicrofacetReflectionLobe_x24init_0( normal_16 : vec3<f32>,  distribution_3 : GGXDistribution_0,  coefficient_3 : ConstantReflection_0) -> MicrofacetReflectionLobe_0
{
    var _S365 : MicrofacetReflectionLobe_0;
    _S365.normal_5 = normal_16;
    _S365.distribution_1 = distribution_3;
    _S365.coefficient_1 = coefficient_3;
    return _S365;
}

fn FlippedLobe_x24init_0( lobe_3 : MicrofacetReflectionLobe_0) -> FlippedLobe_0
{
    var _S366 : FlippedLobe_0;
    _S366.lobe_0 = lobe_3;
    return _S366;
}

fn MakeThinWallSpecularTransmissionLobe_0( normal_17 : vec3<f32>,  distribution_4 : GGXDistribution_0,  transmissionColor_1 : vec3<f32>) -> FlippedLobe_0
{
    var flipped_0 : GGXDistribution_0 = distribution_4;
    flipped_0.frame_1.n_1 = (vec3<f32>(0) - flipped_0.frame_1.n_1);
    return FlippedLobe_x24init_0(MicrofacetReflectionLobe_x24init_0((vec3<f32>(0) - normal_17), flipped_0, ConstantReflection_x24init_0(transmissionColor_1)));
}

fn FlippedLobe_x24init_1( lobe_4 : DiffuseLobe_0) -> FlippedLobe_1
{
    var _S367 : FlippedLobe_1;
    _S367.lobe_0 = lobe_4;
    return _S367;
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
    var _S368 : f32;
    if(MetalMultipleScatteringLobe_Active_0(this_79))
    {
        _S368 = ThroughputWeightedMax_0(throughput_12, this_79.scale_0) * this_79.energyComplementWo_1;
    }
    else
    {
        _S368 = 0.0f;
    }
    return _S368;
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

fn BaseLobe_LobeEstimate_0( this_85 : BaseLobe_0,  index_10 : i32,  wo_39 : vec3<f32>,  throughput_18 : vec3<f32>) -> f32
{
    switch(index_10)
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
    var _S369 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(0), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(0)] = _S369;
    if(BaseLobeEnabled_0(i32(1)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(1), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(1)] = _S369;
    if(BaseLobeEnabled_0(i32(2)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(2), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(2)] = _S369;
    if(BaseLobeEnabled_0(i32(3)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(3), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(3)] = _S369;
    if(BaseLobeEnabled_0(i32(4)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(4), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(4)] = _S369;
    if(BaseLobeEnabled_0(i32(5)))
    {
        _S369 = BaseLobe_LobeEstimate_0((*this_86), i32(5), wo_40, throughput_19);
    }
    else
    {
        _S369 = 0.0f;
    }
    (*this_86).weights_0[i32(5)] = _S369;
    return;
}

fn DielectricReflection_x24init_0( eta_11 : f32) -> DielectricReflection_0
{
    var _S370 : DielectricReflection_0;
    _S370.eta_2 = eta_11;
    return _S370;
}

fn MicrofacetReflectionLobe_x24init_1( normal_19 : vec3<f32>,  distribution_5 : GGXDistribution_0,  coefficient_4 : DielectricReflection_0) -> MicrofacetReflectionLobe_1
{
    var _S371 : MicrofacetReflectionLobe_1;
    _S371.normal_5 = normal_19;
    _S371.distribution_1 = distribution_5;
    _S371.coefficient_1 = coefficient_4;
    return _S371;
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
    var _S372 : bool;
    if((cosine_2 > 0.0f))
    {
        _S372 = CoatLobe_HasCoat_0(this_87);
    }
    else
    {
        _S372 = false;
    }
    if(_S372)
    {
        return DielectricEnergyReflected_0(this_87.reflection_0.coefficient_1.eta_2, this_87.reflection_0.distribution_1.isotropicAlpha_0, cosine_2) * this_87.presence_0;
    }
    return 0.0f;
}

fn CoatLobe_x24init_0( base_4 : BaseLobe_0,  reflection_2 : MicrofacetReflectionLobe_1,  normal_20 : vec3<f32>,  wo_41 : vec3<f32>,  tint_3 : vec3<f32>,  presence_5 : f32,  extraBaseLayerScale_0 : vec3<f32>,  inside_1 : bool) -> CoatLobe_0
{
    var _S373 : CoatLobe_0;
    _S373.base_0 = base_4;
    _S373.reflection_0 = reflection_2;
    _S373.normal_6 = normal_20;
    _S373.tint_0 = tint_3;
    _S373.presence_0 = presence_5;
    _S373.inside_0 = inside_1;
    var idotn_9 : f32 = dot(wo_41, normal_20);
    var _S374 : f32 = CoatLobe_ProportionReflected_0(_S373, idotn_9);
    _S373.inReflected_0 = _S374;
    _S373.inBaseLayerScale_0 = CoatLobe_BaseLayerScaleOneSide_0(_S373, idotn_9, _S374) * extraBaseLayerScale_0;
    return _S373;
}

fn FuzzLobe_ProportionReflected_0( this_88 : FuzzLobe_0,  directionLocal_1 : vec3<f32>) -> f32
{
    var _S375 : bool;
    if(((directionLocal_1.z) <= 0.0f))
    {
        _S375 = true;
    }
    else
    {
        _S375 = !FuzzLobe_HasFuzz_0(this_88);
    }
    if(_S375)
    {
        return 0.0f;
    }
    return this_88.presence_1 * FuzzLobe_Coefficients_0(this_88, directionLocal_1).z;
}

fn FuzzLobe_x24init_0( base_5 : CoatLobe_0,  normal_21 : vec3<f32>,  wo_42 : vec3<f32>,  roughness_7 : f32,  tint_4 : vec3<f32>,  presence_6 : f32) -> FuzzLobe_0
{
    var _S376 : FuzzLobe_0;
    _S376.base_1 = base_5;
    _S376.alpha_3 = roughness_7;
    _S376.tint_1 = tint_4;
    _S376.presence_1 = presence_6;
    var _S377 : Frame_0 = BasisFromNormal_0(normal_21);
    _S376.basis_0 = _S377;
    var _S378 : vec3<f32> = Frame_ToLocal_0(_S377, wo_42);
    _S376.woLocal_0 = _S378;
    _S376.viewReflected_0 = 0.0f;
    _S376.viewReflected_0 = FuzzLobe_ProportionReflected_0(_S376, _S378);
    return _S376;
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
    var _S379 : Frame_0 = specularBasis_1;
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
    var _S380 : Frame_0 = coatBasis_2;
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
        var _S381 : f32 = weightedSpecularIor_0 / exteriorIor_0;
        etaRefraction_0 = etaRefraction_1;
        etaCoat_0 = 1.0f;
        etaOpaqueReflection_0 = _S381;
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
        var _S382 : f32 = etaRefraction_0;
        var _S383 : f32 = etaRefraction_0;
        etaRefraction_0 = etaRefraction_2;
        etaOpaqueReflection_0 = _S383;
        etaTransReflection_0 = _S382;
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
    var _S384 : vec3<f32> = AverageFresnelMetalF82_0(weightedBaseColor_0, metalF82Tint_2);
    var kSmooth_0 : f32 = AverageFresnel_0(etaCoat_0);
    var specularityOpaqueDielectric_0 : f32 = AverageFresnel_0(etaOpaqueReflection_0);
    var k_2 : f32 = mix(kSmooth_0, 1.0f - (1.0f - kSmooth_0) / Square_0(etaCoat_0), mix(1.0f, specularRoughness_1, opaqueDielectric_0 * specularityOpaqueDielectric_0 + (sss_0 + trans_0) * AverageFresnel_0(etaTransReflection_0) + inputs_3.baseMetalness_0));
    var _S385 : vec3<f32> = vec3<f32>(darkenedMetal_0);
    var _S386 : vec3<f32> = vec3<f32>(1.0f);
    var _S387 : vec3<f32> = vec3<f32>(opaqueDielectric_0);
    var _S388 : vec3<f32> = vec3<f32>(sss_0);
    var albedoTrans_0 : vec3<f32> = vec3<f32>(trans_0);
    var coatDarkening_1 : vec3<f32> = mix(_S386, vec3<f32>((1.0f - k_2)) / (_S386 - (_S385 * _S384 + _S387 * mix(weightedBaseColor_0, _S386, vec3<f32>(specularityOpaqueDielectric_0)) + _S388 * inputs_3.subsurfaceColor_0 + albedoTrans_0) * vec3<f32>(k_2)), vec3<f32>((inputs_3.coatWeight_0 * inputs_3.coatDarkening_0)));
    var distribution_6 : GGXDistribution_0 = GGXDistribution_x24init_0(anisotropicSpecularAlpha_0, specularBasis_1, specularAlpha_3);
    var transIncludingSss_0 : f32 = trans_0 + sss_0;
    var scaleOpaqueReflection_0 : vec3<f32> = inputs_3.specularColor_0 * _S387;
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
            var _S389 : vec3<f32> = inputs_3.specularColor_0 * _S388;
            thinWallSpecularTransmissionAlbedoScale_0 = inputs_3.specularColor_0 * albedoTrans_0;
            thinWallAwareScaleTransReflection_0 = _S389;
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
        var _S390 : f32 = SafeDivide_0(20.0f, SafeDivide_0(inputs_3.transmissionDispersionAbbeNumber_0, inputs_3.transmissionDispersionScale_0, 0.0f), 0.0f);
        etaRefractionRGB_0[i32(0)] = DispersionAdjustedIor_0(etaRefraction_0, _S390, wavelengths_2[i32(0)]);
        var _S391 : bool = etaTransReflection_0 == etaRefraction_0;
        if(_S391)
        {
            dispersion_2 = etaRefractionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S390, wavelengths_2[i32(0)]);
        }
        etaTransReflectionRGB_0[i32(0)] = dispersion_2;
        var _S392 : bool = etaOpaqueReflection_0 == etaTransReflection_0;
        if(_S392)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S390, wavelengths_2[i32(0)]);
        }
        etaOpaqueReflectionRGB_0[i32(0)] = dispersion_2;
        etaRefractionRGB_0[i32(1)] = DispersionAdjustedIor_0(etaRefraction_0, _S390, wavelengths_2[i32(1)]);
        if(_S391)
        {
            dispersion_2 = etaRefractionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S390, wavelengths_2[i32(1)]);
        }
        etaTransReflectionRGB_0[i32(1)] = dispersion_2;
        if(_S392)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S390, wavelengths_2[i32(1)]);
        }
        etaOpaqueReflectionRGB_0[i32(1)] = dispersion_2;
        etaRefractionRGB_0[i32(2)] = DispersionAdjustedIor_0(etaRefraction_0, _S390, wavelengths_2[i32(2)]);
        if(_S391)
        {
            dispersion_2 = etaRefractionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S390, wavelengths_2[i32(2)]);
        }
        etaTransReflectionRGB_0[i32(2)] = dispersion_2;
        if(_S392)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S390, wavelengths_2[i32(2)]);
        }
        etaOpaqueReflectionRGB_0[i32(2)] = dispersion_2;
        dispersion_2 = _S390;
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
    var tintedTransIncludingSss_0 : vec3<f32> = tintedTrans_0 + _S388;
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
    var _S393 : vec3<f32> = vec3<f32>(0.0f);
    var thinWallSpecularReflectionAlbedo_0 : vec3<f32>;
    var thinWallSpecularTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var _S394 : vec3<f32> = tintedTrans_0 * vec3<f32>((1.0f - ThinWallFresnel_0(etaRefraction_0, thinWallAwareCosTheta_0)));
        thinWallSpecularReflectionAlbedo_0 = thinWallSpecularTransmissionAlbedoScale_0 * vec3<f32>(ThinWallFresnel_0(etaTransReflection_0, thinWallAwareCosTheta_0));
        thinWallSpecularTransmissionAlbedo_0 = _S394;
    }
    else
    {
        thinWallSpecularReflectionAlbedo_0 = _S393;
        thinWallSpecularTransmissionAlbedo_0 = _S393;
    }
    var thinWallSubsurfaceReflectionAlbedo_0 : vec3<f32>;
    var thinWallSubsurfaceTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var transmissionProportion_0 : f32 = (derived_1.thinWallSubsurfaceAnisotropy_0 + 1.0f) * 0.5f;
        var subsurfaceAlbedo_0 : vec3<f32> = _S388 * derived_1.thinWallSubsurfaceColor_0;
        var _S395 : vec3<f32> = subsurfaceAlbedo_0 * vec3<f32>(transmissionProportion_0);
        thinWallSubsurfaceReflectionAlbedo_0 = subsurfaceAlbedo_0 * vec3<f32>((1.0f - transmissionProportion_0));
        thinWallSubsurfaceTransmissionAlbedo_0 = _S395;
    }
    else
    {
        thinWallSubsurfaceReflectionAlbedo_0 = _S393;
        thinWallSubsurfaceTransmissionAlbedo_0 = _S393;
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
    var base_6 : BaseLobe_0;
    base_6.specular_0 = SpecularLobe_x24init_0(_S379.n_1, distribution_6, coefficient_5, etaRefractionRGB_0, throughput_20);
    base_6.dielectricMultipleScattering_0 = DielectricMultipleScatteringLobe_x24init_0(_S379.n_1, wo_43, specularAlpha_3, etaRefraction_0, scaleTransReflection_0, tintedTransIncludingSss_0);
    base_6.metalMultipleScattering_0 = MetalMultipleScatteringLobe_x24init_0(_S379.n_1, wo_43, specularAlpha_3, Square_1(_S384) * _S385);
    base_6.diffuse_0 = DiffuseLobe_x24init_0(_S379.n_1, wo_43, weightedBaseColor_0 * _S387 + thinWallSubsurfaceReflectionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    base_6.thinWallSpecularTransmission_0 = MakeThinWallSpecularTransmissionLobe_0(_S379.n_1, distribution_6, thinWallSpecularTransmissionAlbedo_0);
    base_6.thinWallDiffuseTransmission_0 = MakeThinWallDiffuseTransmissionLobe_0(_S379.n_1, wo_43, thinWallSubsurfaceTransmissionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    BaseLobe_InitWeights_0(&(base_6), wo_43, throughput_20);
    var coat_0 : CoatLobe_0 = CoatLobe_x24init_0(base_6, MicrofacetReflectionLobe_x24init_1(_S380.n_1, GGXDistribution_x24init_0(anisotropicCoatAlpha_0, coatBasis_2, coatAlpha_0), DielectricReflection_x24init_0(etaCoat_0)), _S380.n_1, wo_43, inputs_3.coatColor_0, inputs_3.coatWeight_0, coatDarkening_1, inside_2);
    var fuzzNormal_0 : vec3<f32> = normalize(mix(_S379.n_1, _S380.n_1, vec3<f32>(inputs_3.coatWeight_0)));
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
        result_6 = result_5 * lobes_1.base_1.inBaseLayerScale_0;
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
    var _S396 : BSDF_0;
    _S396.wo_0 = wo_45;
    var derived_2 : VolumeDerived_0;
    var _S397 : HomogeneousVolume_0 = PrepareVolume_0(inputs_5, &(derived_2));
    _S396.volume_0 = _S397;
    var _S398 : FuzzLobe_0 = PrepareLobes_0(inputs_5, derived_2, wo_45, throughput_21, wavelengths_3, exteriorIor_1);
    _S396.lobes_0 = _S398;
    _S396.emission_0 = ComputeEmission_0(inputs_5, wo_45, _S398);
    return _S396;
}

fn WorkBase_0( index_11 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_11;
}

fn WorkPixel_0( index_12 : u32) -> vec2<u32>
{
    var work_0 : u32 = gWavefront_0.tileStart_0 + index_12;
    var block_0 : u32 = work_0 / u32(64);
    var lane_0 : u32 = (work_0 & (u32(63)));
    var blocksX_0 : u32 = (gFrame_0.frame_0.x + u32(7)) / u32(8);
    var _S399 : u32 = block_0 % blocksX_0;
    var _S400 : u32 = _S399 * u32(8) + ((lane_0 & (u32(7))));
    var _S401 : u32 = block_0 / blocksX_0;
    return vec2<u32>(_S400, _S401 * u32(8) + lane_0 / u32(8));
}

fn NrdEnabled_0() -> bool
{
    return (gFrame_0.envInfo_0.w) != u32(0);
}

fn NrdBase_0( base_7 : u32) -> u32
{
    var pixel_0 : vec2<u32> = WorkPixel_0(base_7 - WorkBase_0(u32(0)));
    return gFrame_0.envInfo_0.w + (pixel_0.y * gFrame_0.frame_0.x + pixel_0.x) * u32(5);
}

fn NrdPackFraction_0( f_14 : vec3<f32>) -> u32
{
    var _S402 : vec3<u32> = vec3<u32>(round(saturate(f_14) * vec3<f32>(511.0f)));
    return ((((_S402.x) | ((((_S402.y) << (u32(9))))))) | ((((_S402.z) << (u32(18))))));
}

fn NrdPackSurface_0( roughness_8 : f32,  metalness_0 : f32) -> f32
{
    return saturate(roughness_8) * 0.99000000953674316f + 2.0f * round(saturate(metalness_0) * 255.0f);
}

fn EmissiveHitPdf_0( _S403 : u32,  _S404 : u32,  _S405 : vec3<f32>,  _S406 : vec3<f32>) -> f32
{
    if((((gInstances_0[_S403].flags_0) & (u32(2)))) == u32(0))
    {
        return 0.0f;
    }
    var light_4 : EmissiveTriangle_std430_0 = gLights_0[gInstances_0[_S403].lightOffset_0 + _S404];
    return light_4.p1_0.w * EmissiveSolidAnglePdf_0(light_4.p0_0.w, MaterialHeader_DoubleSided_0(LoadMaterialHeader_0((bitcast<u32>((light_4.n_0.w))))), _S405, _S406, light_4.n_0.xyz);
}

fn SharcEnabled_0() -> bool
{
    return (gFrame_0.sharc_0.y) != u32(0);
}

fn SharcSurface_0( ms_1 : MaterialSample_0) -> bool
{
    var _S407 : bool;
    if(((ms_1.roughness_4) >= (gFrame_0.sharcParams_0.y)))
    {
        _S407 = ((ms_1.inputs_1.baseMetalness_0) < 0.10000000149011612f);
    }
    else
    {
        _S407 = false;
    }
    if(_S407)
    {
        _S407 = (ms_1.inputs_1.transmissionWeight_0) == 0.0f;
    }
    else
    {
        _S407 = false;
    }
    if(_S407)
    {
        _S407 = (ms_1.inputs_1.subsurfaceWeight_0) == 0.0f;
    }
    else
    {
        _S407 = false;
    }
    if(_S407)
    {
        _S407 = (ms_1.inputs_1.coatWeight_0) == 0.0f;
    }
    else
    {
        _S407 = false;
    }
    return _S407;
}

struct SharcKey_0
{
     spatial_0 : vec4<u32>,
     material_2 : u32,
     instance_0 : u32,
};

fn isinf_0( x_28 : f32) -> bool
{
    var _S408 : u32 = (bitcast<u32>((x_28)));
    var _S409 : u32 = (_S408 & (u32(8388607)));
    var _S410 : bool;
    if(((((_S408 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S410 = _S409 == u32(0);
    }
    else
    {
        _S410 = false;
    }
    return _S410;
}

fn isnan_0( x_29 : f32) -> bool
{
    var _S411 : u32 = (bitcast<u32>((x_29)));
    var _S412 : u32 = (_S411 & (u32(8388607)));
    var _S413 : bool;
    if(((((_S411 >> (u32(23)))) & (u32(255)))) == u32(255))
    {
        _S413 = _S412 != u32(0);
    }
    else
    {
        _S413 = false;
    }
    return _S413;
}

fn isfinite_0( x_30 : f32) -> bool
{
    var _S414 : bool;
    if(isinf_0(x_30))
    {
        _S414 = true;
    }
    else
    {
        _S414 = isnan_0(x_30);
    }
    return !_S414;
}

fn isfinite_1( x_31 : vec3<f32>) -> vec3<bool>
{
    var result_7 : vec3<bool>;
    var i_7 : i32 = i32(0);
    loop
    {
        if((i_7 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_7[i_7] = isfinite_0(x_31[i_7]);
        i_7 = i_7 + i32(1);
    }
    return result_7;
}

fn SharcMakeKey_0( position_3 : vec3<f32>,  normal_22 : vec3<f32>,  view_0 : vec3<f32>,  material_3 : u32,  instance_1 : u32,  key_0 : ptr<function, SharcKey_0>,  size_1 : ptr<function, f32>) -> bool
{
    var baseSize_0 : f32 = gFrame_0.sharcParams_0.x;
    var level_3 : u32 = u32(clamp(floor(log2(max(length(position_3 - gFrame_0.cameraPosition_0.xyz) / (baseSize_0 * 32.0f), 1.0f))), 0.0f, 16.0f));
    var _S415 : f32 = baseSize_0 * exp2(f32(level_3));
    (*size_1) = _S415;
    var cell_0 : vec3<f32> = floor(position_3 / vec3<f32>(_S415));
    var _S416 : vec3<f32> = vec3<f32>(0.5f);
    var _S417 : vec3<u32> = vec3<u32>(clamp(floor((normal_22 * _S416 + _S416) * vec3<f32>(15.0f) + _S416), vec3<f32>(0.0f), vec3<f32>(15.0f)));
    var _S418 : u32;
    if(((view_0.x) >= 0.0f))
    {
        _S418 = u32(1);
    }
    else
    {
        _S418 = u32(0);
    }
    var _S419 : u32;
    if(((view_0.y) >= 0.0f))
    {
        _S419 = u32(2);
    }
    else
    {
        _S419 = u32(0);
    }
    var _S420 : u32 = (_S418 | (_S419));
    if(((view_0.z) >= 0.0f))
    {
        _S418 = u32(4);
    }
    else
    {
        _S418 = u32(0);
    }
    (*key_0).spatial_0 = vec4<u32>((bitcast<vec3<u32>>((vec3<i32>(clamp(cell_0, vec3<f32>(-1.073741824e+09f), vec3<f32>(1.073741824e+09f)))))), ((((((((_S417.x) | ((((_S417.y) << (u32(4))))))) | ((((_S417.z) << (u32(8))))))) | (((((_S420 | (_S418))) << (u32(12))))))) | (((level_3 << (u32(15)))))));
    (*key_0).material_2 = material_3;
    (*key_0).instance_0 = instance_1;
    var _S421 : bool;
    if((all((isfinite_1(cell_0)))))
    {
        _S421 = (all((((abs(cell_0)) < vec3<f32>(1.073741824e+09f)))));
    }
    else
    {
        _S421 = false;
    }
    return _S421;
}

fn SharcUpdatePath_0( index_13 : u32,  tileStart_1 : u32) -> bool
{
    return (index_13 % u32(16)) == (((StrongIntegerHash_0(((index_13 / u32(16) + tileStart_1 / u32(16)) ^ ((gFrame_0.sharc_0.w))))) & (u32(15))));
}

fn SharcRecordWord_0( record_0 : u32) -> u32
{
    return gFrame_0.sharc_0.z + record_0 * u32(16);
}

fn SharcRecord_0( index_14 : u32,  bounce_1 : u32,  key_1 : SharcKey_0,  radiance_2 : vec3<f32>,  throughput_22 : vec3<f32>)
{
    var _S422 : bool;
    if(bounce_1 == u32(0))
    {
        _S422 = true;
    }
    else
    {
        _S422 = (bounce_1 > u32(4));
    }
    if(_S422)
    {
        _S422 = true;
    }
    else
    {
        _S422 = (bounce_1 >= (gFrame_0.settings_0.x));
    }
    if(_S422)
    {
        _S422 = true;
    }
    else
    {
        _S422 = (any(((throughput_22 < vec3<f32>(9.9999997473787516e-05f)))));
    }
    if(_S422)
    {
        return;
    }
    var base_8 : u32 = SharcRecordWord_0(index_14 / u32(16) * u32(4) + bounce_1 - u32(1)) / u32(4);
    gAccum_0[base_8] = (bitcast<vec4<f32>>((key_1.spatial_0)));
    gAccum_0[base_8 + u32(1)] = (bitcast<vec4<f32>>((vec4<u32>(key_1.material_2, key_1.instance_0, u32(1), u32(4294967295)))));
    gAccum_0[base_8 + u32(2)] = vec4<f32>(radiance_2, 0.0f);
    gAccum_0[base_8 + u32(3)] = vec4<f32>(throughput_22, 0.0f);
    return;
}

fn Field_0( base_9 : u32,  field_0 : u32) -> u32
{
    return base_9 + field_0 * gWavefront_0.capacity_0;
}

fn SharcHash_0( key_2 : SharcKey_0) -> u32
{
    return ((StrongIntegerHash_0(((((((StrongIntegerHash_0(((((key_2.spatial_0.x) ^ ((StrongIntegerHash_0(key_2.spatial_0.y))))) ^ ((StrongIntegerHash_0(key_2.spatial_0.z)))))) ^ ((key_2.spatial_0.w)))) ^ ((StrongIntegerHash_0(key_2.material_2))))) ^ ((StrongIntegerHash_0(key_2.instance_0)))))) & ((gFrame_0.sharc_0.y - u32(1))));
}

fn SharcCellWord_0( slot_3 : u32) -> u32
{
    return gFrame_0.sharc_0.x + u32(16) + slot_3 * u32(16);
}

fn SharcQuery_0( key_3 : SharcKey_0,  radiance_3 : ptr<function, vec3<f32>>) -> bool
{
    (*radiance_3) = vec3<f32>(0.0f);
    var _S423 : u32 = SharcHash_0(key_3);
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
        var base_10 : u32 = SharcCellWord_0(((_S423 + probe_0) & ((gFrame_0.sharc_0.y - u32(1))))) / u32(4);
        var a_17 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[base_10])));
        var b_17 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[base_10 + u32(1)])));
        var _S424 : u32 = base_10 + u32(3);
        var history_0 : u32 = (bitcast<u32>((gAccum_0[_S424].w)));
        var _S425 : bool;
        if((a_17.x) == u32(4294967295))
        {
            _S425 = (all(((a_17.yzw) == (key_3.spatial_0.xyz))));
        }
        else
        {
            _S425 = false;
        }
        var _S426 : bool;
        if(_S425)
        {
            _S426 = (b_17.x) == (key_3.spatial_0.w);
        }
        else
        {
            _S426 = false;
        }
        var _S427 : bool;
        if(_S426)
        {
            _S427 = (b_17.y) == (key_3.material_2);
        }
        else
        {
            _S427 = false;
        }
        var _S428 : bool;
        if(_S427)
        {
            _S428 = (b_17.z) == (key_3.instance_0);
        }
        else
        {
            _S428 = false;
        }
        var _S429 : bool;
        if(_S428)
        {
            _S429 = (((history_0 & (u32(65535)))) >= (gFrame_0.sharcControl_0.x));
        }
        else
        {
            _S429 = false;
        }
        var _S430 : bool;
        if(_S429)
        {
            _S430 = ((gFrame_0.sharc_0.w - b_17.w) <= (gFrame_0.sharcControl_0.z));
        }
        else
        {
            _S430 = false;
        }
        if(_S430)
        {
            var _S431 : vec3<f32> = gAccum_0[_S424].xyz;
            (*radiance_3) = _S431;
            return (all((isfinite_1(_S431))));
        }
        probe_0 = probe_0 + u32(1);
    }
    return false;
}

fn RandomSequence_x24init_0( positionSeed_0 : u32,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S432 : RandomSequence_0;
    _S432.seed_0 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_0));
    return _S432;
}

fn BaseLobe_MaxActiveAlpha_0( this_89 : BaseLobe_0) -> f32
{
    var _S433 : bool;
    if(BaseLobe_IsActive_0(this_89, i32(3)))
    {
        _S433 = true;
    }
    else
    {
        _S433 = BaseLobe_IsActive_0(this_89, i32(5));
    }
    if(_S433)
    {
        _S433 = true;
    }
    else
    {
        _S433 = BaseLobe_IsActive_0(this_89, i32(1));
    }
    if(_S433)
    {
        _S433 = true;
    }
    else
    {
        _S433 = BaseLobe_IsActive_0(this_89, i32(2));
    }
    if(_S433)
    {
        return 1.0f;
    }
    if(BaseLobe_IsActive_0(this_89, i32(0)))
    {
        _S433 = true;
    }
    else
    {
        _S433 = BaseLobe_IsActive_0(this_89, i32(4));
    }
    if(_S433)
    {
        return max(this_89.specular_0.distribution_0.alpha_0.x, this_89.specular_0.distribution_0.alpha_0.y);
    }
    return 0.0f;
}

fn CoatLobe_MaxActiveAlpha_0( this_90 : CoatLobe_0) -> f32
{
    var _S434 : bool;
    if(this_90.inside_0)
    {
        _S434 = true;
    }
    else
    {
        _S434 = !CoatLobe_HasCoat_0(this_90);
    }
    var _S435 : f32;
    if(_S434)
    {
        _S435 = 0.0f;
    }
    else
    {
        _S435 = max(this_90.reflection_0.distribution_1.alpha_0.x, this_90.reflection_0.distribution_1.alpha_0.y);
    }
    return _S435;
}

fn BSDF_MaxActiveAlpha_0( this_91 : BSDF_0) -> f32
{
    var baseAlpha_0 : f32 = BaseLobe_MaxActiveAlpha_0(this_91.lobes_0.base_1.base_0);
    var _S436 : f32;
    if(FuzzLobe_HasFuzz_0(this_91.lobes_0))
    {
        _S436 = 1.0f;
    }
    else
    {
        _S436 = max(baseAlpha_0, CoatLobe_MaxActiveAlpha_0(this_91.lobes_0.base_1));
    }
    return _S436;
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
    var _S437 : f32 = u_10.y;
    var sinTheta_1 : f32 = sqrt(1.0f - _S437);
    return vec3<f32>(sinTheta_1 * cos(phi_2), sinTheta_1 * sin(phi_2), sqrt(_S437));
}

fn SheenSampleLTC_0( ltc_2 : vec3<f32>,  u_11 : vec2<f32>) -> vec3<f32>
{
    var wiOriginal_1 : vec3<f32> = SampleCosineHemisphere_0(u_11);
    var a_18 : f32 = 1.0f / ltc_2.x;
    var _S438 : f32 = wiOriginal_1.z;
    return normalize(vec3<f32>(wiOriginal_1.x * a_18 - _S438 * ltc_2.y * a_18, wiOriginal_1.y * a_18, _S438));
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
    var _S439 : f32 = min(woHemisphere_0.z, 1.0f);
    var angle_2 : f32 = 2.0f * float_getPi_0() * u_13.x;
    var onePlusCos_0 : f32 = 1.0f + _S439;
    var _S440 : f32 = u_13.y;
    var z_8 : f32 = (1.0f - _S440) * onePlusCos_0;
    var radius_3 : f32 = sqrt((z_8 + (1.0f - _S439)) * (_S440 * onePlusCos_0));
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
    var f_15 : vec3<f32> = DielectricReflection_Reflection_0(this_95.coefficient_1, idoth_14);
    var gShadowing_0 : f32 = GGXDistribution_G1_0(this_95.distribution_1, wi_28);
    var d_8 : f32 = GGXDistribution_D_0(this_95.distribution_1, h_12);
    if((d_8 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_28, DiffuseSpecular_Specular_0(f_15 * vec3<f32>(gShadowing_0)), d_8 * GGXDistribution_G1_0(this_95.distribution_1, wo_48) * idoth_14 / (4.0f * odoth_4 * idotn_10), MicrofacetReflectionLobe_LobeType_0(this_95));
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
    var _S441 : f32 = BaseLobe_TotalWeight_0(this_96);
    (*totalWeight_2) = _S441;
    if((_S441 <= 1.17549435082228751e-38f))
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
    var _S442 : f32 = u_17.z;
    if((_S442 < (c_14.reflectionProbability_0)))
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
    var remapped_0 : f32 = (_S442 - c_14.reflectionProbability_0) / c_14.transmissionProbability_0;
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
    var _S443 : bool = Refract_0(wo_49, h_13, idoth_15, this_97.eta_0[channel_0], &(wi_31));
    if(!_S443)
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
    var f_16 : vec3<f32> = ConstantReflection_Reflection_0(this_104.coefficient_1, idoth_16);
    var gShadowing_1 : f32 = GGXDistribution_G1_0(this_104.distribution_1, wi_34);
    var d_10 : f32 = GGXDistribution_D_0(this_104.distribution_1, h_14);
    if((d_10 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_34, DiffuseSpecular_Specular_0(f_16 * vec3<f32>(gShadowing_1)), d_10 * GGXDistribution_G1_0(this_104.distribution_1, wo_53) * idoth_16 / (4.0f * odoth_6 * idotn_12), MicrofacetReflectionLobe_LobeType_1(this_104));
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
    var _S444 : bool = !this_109.inside_0;
    var _S445 : bool;
    if(_S444)
    {
        _S445 = CoatLobe_HasCoat_0(this_109);
    }
    else
    {
        _S445 = false;
    }
    var coatProbability_0 : f32;
    if(_S445)
    {
        coatProbability_0 = CoatLobe_ReflectionProbability_0(this_109, wo_58);
    }
    else
    {
        coatProbability_0 = 0.0f;
    }
    var ux_2 : f32 = u_27.x;
    if(_S444)
    {
        _S445 = (ux_2 < coatProbability_0);
    }
    else
    {
        _S445 = false;
    }
    if(_S445)
    {
        var s_20 : LobeSample_0 = MicrofacetReflectionLobe_Sample_0(this_109.reflection_0, vec3<f32>(ClampRemappedRandom_0(ux_2 * (1.0f / coatProbability_0)), u_27.y, u_27.z), wo_58);
        (*wi_36) = s_20.wi_26;
        (*type_4) = s_20.type_0;
        (*sampled_4) = SampledLobe_Make_0(i32(2), i32(0), s_20);
        return s_20.valid_1;
    }
    var ux_3 : f32;
    if(_S444)
    {
        ux_3 = ClampRemappedRandom_0((ux_2 - coatProbability_0) * (1.0f / (1.0f - coatProbability_0)));
    }
    else
    {
        ux_3 = ux_2;
    }
    var _S446 : bool = BaseLobe_SampleLobe_0(this_109.base_0, vec3<f32>(ux_3, u_27.y, u_27.z), wo_58, &((*wi_36)), &((*type_4)), &((*sampled_4)));
    return _S446;
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
    var _S447 : f32 = u_28.x;
    if((_S447 < sheenProbability_0))
    {
        var _S448 : f32 = this_110.woLocal_0.z;
        if((_S448 <= 0.0f))
        {
            return false;
        }
        var wiLocal_7 : vec3<f32> = SheenRotate_0(SheenSampleLTC_0(FuzzLobe_Coefficients_0(this_110, this_110.woLocal_0), u_28.yz), this_110.woLocal_0.xy);
        if(((_S448 * wiLocal_7.z) <= 0.0f))
        {
            return false;
        }
        (*wi_37) = normalize(Frame_ToWorld_0(this_110.basis_0, wiLocal_7));
        return true;
    }
    var _S449 : bool = CoatLobe_SampleLobe_0(this_110.base_1, vec3<f32>(ClampRemappedRandom_0((_S447 - sheenProbability_0) * (1.0f / (1.0f - sheenProbability_0))), u_28.y, u_28.z), wo_59, &((*wi_37)), &((*type_5)), &((*sampled_5)));
    return _S449;
}

fn BaseLobe_LobeEvalPdf_1( this_111 : BaseLobe_0,  index_16 : i32,  wo_60 : vec3<f32>,  wi_38 : vec3<f32>,  f_17 : ptr<function, DiffuseSpecular_0>,  pdf_10 : ptr<function, f32>)
{
    switch(index_16)
    {
    case i32(0):
        {
            (*f_17) = SpecularLobe_Eval_0(this_111.specular_0, wo_60, wi_38);
            (*pdf_10) = SpecularLobe_Pdf_0(this_111.specular_0, wo_60, wi_38);
        }
    case i32(1):
        {
            (*f_17) = DielectricMultipleScatteringLobe_Eval_0(this_111.dielectricMultipleScattering_0, wo_60, wi_38);
            (*pdf_10) = DielectricMultipleScatteringLobe_Pdf_0(this_111.dielectricMultipleScattering_0, wo_60, wi_38);
        }
    case i32(2):
        {
            (*f_17) = MetalMultipleScatteringLobe_Eval_0(this_111.metalMultipleScattering_0, wo_60, wi_38);
            (*pdf_10) = MetalMultipleScatteringLobe_Pdf_0(this_111.metalMultipleScattering_0, wo_60, wi_38);
        }
    case i32(3):
        {
            (*f_17) = DiffuseLobe_Eval_0(this_111.diffuse_0, wo_60, wi_38);
            (*pdf_10) = DiffuseLobe_Pdf_0(this_111.diffuse_0, wo_60, wi_38);
        }
    case i32(4):
        {
            (*f_17) = FlippedLobe_Eval_0(this_111.thinWallSpecularTransmission_0, wo_60, wi_38);
            (*pdf_10) = FlippedLobe_Pdf_0(this_111.thinWallSpecularTransmission_0, wo_60, wi_38);
        }
    default :
        {
            (*f_17) = FlippedLobe_Eval_1(this_111.thinWallDiffuseTransmission_0, wo_60, wi_38);
            (*pdf_10) = FlippedLobe_Pdf_1(this_111.thinWallDiffuseTransmission_0, wo_60, wi_38);
        }
    }
    return;
}

fn BaseLobe_EvalPdf_1( this_112 : BaseLobe_0,  wo_61 : vec3<f32>,  wi_39 : vec3<f32>,  sampled_6 : SampledLobe_0,  f_18 : ptr<function, DiffuseSpecular_0>,  pdf_11 : ptr<function, f32>)
{
    (*f_18) = DiffuseSpecular_Zero_0();
    var i_8 : i32 = i32(0);
    var sum_4 : f32 = 0.0f;
    var totalWeight_4 : f32 = 0.0f;
    loop
    {
        if((i_8 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_112, i_8))
        {
            var lobeF_1 : DiffuseSpecular_0 = sampled_6.f_1;
            var lobePdf_1 : f32 = sampled_6.pdf_0;
            var _S450 : bool;
            if((sampled_6.layer_0) != i32(1))
            {
                _S450 = true;
            }
            else
            {
                _S450 = (sampled_6.lobe_1) != i_8;
            }
            if(_S450)
            {
                BaseLobe_LobeEvalPdf_1(this_112, i_8, wo_61, wi_39, &(lobeF_1), &(lobePdf_1));
            }
            (*f_18) = x2B_0((*f_18), lobeF_1);
            var totalWeight_5 : f32 = totalWeight_4 + this_112.weights_0[i_8];
            sum_4 = sum_4 + this_112.weights_0[i_8] * lobePdf_1;
            totalWeight_4 = totalWeight_5;
        }
        i_8 = i_8 + i32(1);
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

fn CoatLobe_EvalPdf_1( this_113 : CoatLobe_0,  wo_62 : vec3<f32>,  wi_40 : vec3<f32>,  sampled_7 : SampledLobe_0,  f_19 : ptr<function, DiffuseSpecular_0>,  pdf_12 : ptr<function, f32>)
{
    var baseF_2 : DiffuseSpecular_0;
    var basePdf_2 : f32;
    BaseLobe_EvalPdf_1(this_113.base_0, wo_62, wi_40, sampled_7, &(baseF_2), &(basePdf_2));
    if(this_113.inside_0)
    {
        (*f_19) = x2A_0(baseF_2, CoatLobe_PassageColor_0(this_113, - dot(wi_40, this_113.normal_6)));
        (*pdf_12) = basePdf_2;
        return;
    }
    var coatSampled_1 : bool = (sampled_7.layer_0) == i32(2);
    var _S451 : DiffuseSpecular_0;
    if(coatSampled_1)
    {
        _S451 = sampled_7.f_1;
    }
    else
    {
        _S451 = CoatLobe_CoatEval_0(this_113, wo_62, wi_40);
    }
    (*f_19) = CoatLobe_Combine_0(this_113, _S451, baseF_2, wi_40);
    var _S452 : f32;
    if(CoatLobe_HasCoat_0(this_113))
    {
        var _S453 : f32 = basePdf_2;
        if(coatSampled_1)
        {
            _S452 = sampled_7.pdf_0;
        }
        else
        {
            _S452 = MicrofacetReflectionLobe_Pdf_1(this_113.reflection_0, wo_62, wi_40);
        }
        _S452 = mix(_S453, _S452, CoatLobe_ReflectionProbability_0(this_113, wo_62));
    }
    else
    {
        _S452 = basePdf_2;
    }
    (*pdf_12) = _S452;
    return;
}

fn FuzzLobe_EvalPdf_1( this_114 : FuzzLobe_0,  wo_63 : vec3<f32>,  wi_41 : vec3<f32>,  sampled_8 : SampledLobe_0,  f_20 : ptr<function, DiffuseSpecular_0>,  pdf_13 : ptr<function, f32>)
{
    var baseF_3 : DiffuseSpecular_0;
    var basePdf_3 : f32;
    CoatLobe_EvalPdf_1(this_114.base_1, wo_63, wi_41, sampled_8, &(baseF_3), &(basePdf_3));
    var wiLocal_8 : vec3<f32> = Frame_ToLocal_0(this_114.basis_0, wi_41);
    (*f_20) = x2B_0(x2A_1(baseF_3, FuzzLobe_BaseLayerScaleComplete_0(this_114, wiLocal_8)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_114, wiLocal_8)));
    var _S454 : f32;
    if(FuzzLobe_HasFuzz_0(this_114))
    {
        _S454 = mix(basePdf_3, FuzzLobe_SheenPdf_0(this_114, wiLocal_8), FuzzLobe_SheenProbability_0(this_114, wo_63));
    }
    else
    {
        _S454 = basePdf_3;
    }
    (*pdf_13) = _S454;
    return;
}

fn SampleLayer_0( layer_2 : FuzzLobe_0,  u_29 : vec3<f32>,  wo_64 : vec3<f32>) -> LobeSample_0
{
    var wi_42 : vec3<f32>;
    var type_6 : u32;
    var sampled_9 : SampledLobe_0;
    var _S455 : bool = FuzzLobe_SampleLobe_0(layer_2, u_29, wo_64, &(wi_42), &(type_6), &(sampled_9));
    if(!_S455)
    {
        return LobeSample_Invalid_0();
    }
    var f_21 : DiffuseSpecular_0;
    var pdf_14 : f32;
    FuzzLobe_EvalPdf_1(layer_2, wo_64, wi_42, sampled_9, &(f_21), &(pdf_14));
    if(!(pdf_14 > 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_42, x2A_1(f_21, 1.0f / pdf_14), pdf_14, type_6);
}

fn FuzzLobe_Sample_0( this_115 : FuzzLobe_0,  u_30 : vec3<f32>,  wo_65 : vec3<f32>) -> LobeSample_0
{
    return SampleLayer_0(this_115, u_30, wo_65);
}

fn BSDF_Sample_0( this_116 : BSDF_0,  u_31 : vec3<f32>) -> LobeSample_0
{
    return FuzzLobe_Sample_0(this_116.lobes_0, u_31, this_116.wo_0);
}

fn NrdOctEncode_0( v_17 : vec3<f32>) -> vec2<f32>
{
    var _S456 : f32 = v_17.z;
    var p_8 : vec2<f32> = v_17.xy / vec2<f32>((abs(v_17.x) + abs(v_17.y) + abs(_S456)));
    var _S457 : vec2<f32>;
    if((_S456 >= 0.0f))
    {
        _S457 = p_8;
    }
    else
    {
        _S457 = (vec2<f32>(1.0f) - abs(p_8.yx)) * select(vec2<f32>(-1.0f), vec2<f32>(1.0f), (p_8 >= vec2<f32>(0.0f)));
    }
    return _S457;
}

fn NrdDiffuseFraction_0( v_18 : DiffuseSpecular_0) -> vec3<f32>
{
    var total_1 : vec3<f32> = v_18.diffuse_1 + v_18.specular_1;
    var _S458 : f32 = total_1.x;
    var _S459 : f32;
    if((_S458 > 0.0f))
    {
        _S459 = v_18.diffuse_1.x / _S458;
    }
    else
    {
        _S459 = 0.5f;
    }
    var _S460 : f32 = total_1.y;
    var _S461 : f32;
    if((_S460 > 0.0f))
    {
        _S461 = v_18.diffuse_1.y / _S460;
    }
    else
    {
        _S461 = 0.5f;
    }
    var _S462 : f32 = total_1.z;
    var _S463 : f32;
    if((_S462 > 0.0f))
    {
        _S463 = v_18.diffuse_1.z / _S462;
    }
    else
    {
        _S463 = 0.5f;
    }
    return vec3<f32>(_S459, _S461, _S463);
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

fn ScatterConeSpread_0( lobe_6 : u32,  roughness_9 : f32) -> f32
{
    if(((lobe_6 & (u32(4)))) != u32(0))
    {
        return 0.5f;
    }
    return 0.5f * roughness_9 * roughness_9;
}

fn ShadePath_0( base_11 : u32,  s_21 : ptr<function, WavefrontPath_0>,  hit_3 : HitRecord_0,  bounce_2 : u32)
{
    var _S464 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_21).path_0.absorption_0) > _S464)))))
    {
        (*s_21).path_0.throughput_7 = (*s_21).path_0.throughput_7 * exp((*s_21).path_0.absorption_0 * vec3<f32>(- hit_3.t_6));
    }
    var hitConeWidth_0 : f32 = (*s_21).path_0.coneWidth_2 + (*s_21).path_0.coneSpread_0 * hit_3.t_6;
    var si_4 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_21).path_0.direction_1, hit_3, hitConeWidth_0);
    var V_2 : vec3<f32> = (vec3<f32>(0) - (*s_21).path_0.direction_1);
    var ms_2 : MaterialSample_0 = EvalMaterial_0(si_4, V_2);
    var bsdf_1 : BSDF_0 = BSDF_x24init_0(ms_2.inputs_1, V_2, (*s_21).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S465 : bool = bounce_2 == u32(0);
    var throughput_23 : vec3<f32>;
    if(_S465)
    {
        (*s_21).albedo_2 = ms_2.albedo_3;
        if(si_4.frontFacing_0)
        {
            throughput_23 = ms_2.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_23 = (vec3<f32>(0) - ms_2.inputs_1.basis_1.n_1);
        }
        (*s_21).normal_11 = throughput_23;
        if((gFrame_0.temporal_0.z) != 0.0f)
        {
            var pixel_1 : vec2<u32> = WorkPixel_0(base_11 - WorkBase_0(u32(0)));
            var output_0 : u32 = (pixel_1.y * gFrame_0.frame_0.x + pixel_1.x) * u32(3);
            gAccum_0[output_0 + u32(1)][i32(3)] = hit_3.t_6;
            gAccum_0[output_0 + u32(2)][i32(3)] = f32(hit_3.instanceIndex_2 + u32(1));
        }
        if(NrdEnabled_0())
        {
            var r_10 : u32 = NrdBase_0(base_11);
            gAccum_0[r_10] = vec4<f32>((*s_21).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
            gAccum_0[r_10 + u32(1)] = vec4<f32>(0.0f);
            gAccum_0[r_10 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_2.roughness_4, ms_2.inputs_1.baseMetalness_0));
        }
    }
    (*s_21).active_0 = u32(0);
    var _S466 : bool;
    if(!si_4.frontFacing_0)
    {
        _S466 = !ms_2.doubleSided_2;
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        _S466 = ((ms_2.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        return;
    }
    var continuation_0 : f32;
    if((any((((bsdf_1.emission_0) > _S464)))))
    {
        var _S467 : bool = !_S465;
        if(_S467)
        {
            _S466 = (*s_21).path_0.lightsSampled_0;
        }
        else
        {
            _S466 = false;
        }
        if(_S466)
        {
            continuation_0 = EvalMISRobust_0((*s_21).path_0.scatterPdf_0, EmissiveHitPdf_0(si_4.instanceIndex_0, si_4.primitiveIndex_0, (*s_21).path_0.origin_3, si_4.position_0));
        }
        else
        {
            continuation_0 = 1.0f;
        }
        var contribution_0 : vec3<f32> = (*s_21).path_0.throughput_7 * vec3<f32>(continuation_0) * bsdf_1.emission_0;
        var clampValue_0 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_0 > 0.0f))
        {
            _S466 = _S467;
        }
        else
        {
            _S466 = false;
        }
        if(_S466)
        {
            throughput_23 = min(contribution_0, vec3<f32>(clampValue_0));
        }
        else
        {
            throughput_23 = contribution_0;
        }
        (*s_21).path_0.radiance_1 = (*s_21).path_0.radiance_1 + throughput_23;
    }
    if(_S465)
    {
        _S466 = NrdEnabled_0();
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        var _S468 : u32 = NrdBase_0(base_11);
        var _S469 : vec3<f32> = (*s_21).path_0.radiance_1;
        gAccum_0[_S468].x = _S469.x;
        gAccum_0[_S468].y = _S469.y;
        gAccum_0[_S468].z = _S469.z;
    }
    if(bounce_2 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S470 : bool = SharcEnabled_0();
    if(_S470)
    {
        _S466 = !_S465;
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        _S466 = SharcSurface_0(ms_2);
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        var key_4 : SharcKey_0;
        var voxelSize_0 : f32;
        if(si_4.frontFacing_0)
        {
            throughput_23 = si_4.faceNormal_0;
        }
        else
        {
            throughput_23 = (vec3<f32>(0) - si_4.faceNormal_0);
        }
        var index_17 : u32 = base_11 - WorkBase_0(u32(0));
        var _S471 : bool = SharcMakeKey_0(si_4.position_0, throughput_23, V_2, si_4.materialIndex_1, si_4.instanceIndex_0, &(key_4), &(voxelSize_0));
        if(_S471)
        {
            if(SharcUpdatePath_0(index_17, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_17, bounce_2, key_4, (*s_21).path_0.radiance_1, (*s_21).path_0.throughput_7);
            }
            else
            {
                if(((hit_3.t_6) > (voxelSize_0 * sqrt(3.0f))))
                {
                    _S466 = (hitConeWidth_0 > voxelSize_0);
                }
                else
                {
                    _S466 = false;
                }
                if(_S466)
                {
                    _S466 = (((*s_21).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S466 = false;
                }
                if(_S466)
                {
                    var _S472 : u32 = Field_0(base_11, u32(6));
                    var state_0 : u32 = (bitcast<u32>((gAccum_0[_S472].w))) + u32(65536);
                    var cached_0 : vec3<f32>;
                    var found_4 : bool = SharcQuery_0(key_4, &(cached_0));
                    var _S473 : u32;
                    if(found_4)
                    {
                        _S473 = u32(256);
                    }
                    else
                    {
                        _S473 = u32(0);
                    }
                    gAccum_0[_S472][i32(3)] = (bitcast<f32>(((state_0 | (_S473)))));
                    if(found_4)
                    {
                        (*s_21).path_0.radiance_1 = (*s_21).path_0.radiance_1 + (*s_21).path_0.throughput_7 * cached_0;
                        return;
                    }
                }
            }
        }
    }
    var rng_5 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_5.seed_0 = (*s_21).randomSeed_0;
    var _S474 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_1)) >= 0.0010000000474974513f);
    (*s_21).path_0.lightsSampled_0 = _S474;
    if(_S474)
    {
        var _S475 : vec3<f32> = NextEventEstimation_0(si_4, bsdf_1, vec2<f32>(hitConeWidth_0, (*s_21).path_0.coneSpread_0), &(rng_5));
        var direct_0 : vec3<f32> = (*s_21).path_0.throughput_7 * _S475;
        var clampValue_1 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_1 > 0.0f))
        {
            _S466 = !_S465;
        }
        else
        {
            _S466 = false;
        }
        if(_S466)
        {
            throughput_23 = min(direct_0, vec3<f32>(clampValue_1));
        }
        else
        {
            throughput_23 = direct_0;
        }
        (*s_21).path_0.radiance_1 = (*s_21).path_0.radiance_1 + throughput_23;
    }
    var u_32 : vec2<f32> = RandomSequence_Next2D_0(&(rng_5));
    var _S476 : f32 = RandomSequence_Next_1(&(rng_5));
    var bs_0 : LobeSample_0 = BSDF_Sample_0(bsdf_1, vec3<f32>(u_32, _S476));
    var weight_4 : vec3<f32> = bs_0.weight_1.diffuse_1 + bs_0.weight_1.specular_1;
    if(!bs_0.valid_1)
    {
        _S466 = true;
    }
    else
    {
        _S466 = ((bs_0.pdf_7) <= 0.0f);
    }
    if(_S466)
    {
        _S466 = true;
    }
    else
    {
        _S466 = (all(((weight_4 <= _S464))));
    }
    if(_S466)
    {
        return;
    }
    if(_S465)
    {
        _S466 = NrdEnabled_0();
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        var r_11 : u32 = NrdBase_0(base_11);
        var oct_0 : vec2<f32> = NrdOctEncode_0(bs_0.wi_26);
        gAccum_0[r_11][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_0.weight_1)))));
        gAccum_0[r_11 + u32(3)][i32(3)] = oct_0.x;
        gAccum_0[r_11 + u32(4)][i32(3)] = oct_0.y;
    }
    var throughput_24 : vec3<f32> = (*s_21).path_0.throughput_7 * weight_4;
    if(_S470)
    {
        _S466 = _S465;
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        continuation_0 = 1.0f;
    }
    else
    {
        continuation_0 = sqrt(saturate(MaxComponent_0(throughput_24) / max(MaxComponent_0((*s_21).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_0 < 1.0f))
    {
        var _S477 : f32 = RandomSequence_Next_1(&(rng_5));
        if((_S477 >= continuation_0))
        {
            return;
        }
        throughput_23 = throughput_24 / vec3<f32>(continuation_0);
    }
    else
    {
        throughput_23 = throughput_24;
    }
    (*s_21).path_0.throughput_7 = throughput_23;
    (*s_21).path_0.direction_1 = bs_0.wi_26;
    (*s_21).path_0.scatterPdf_0 = bs_0.pdf_7;
    var crossesSurface_0 : bool = ((dot(bs_0.wi_26, si_4.faceNormal_0)) > 0.0f) != (si_4.frontFacing_0);
    (*s_21).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_4, !crossesSurface_0);
    if(crossesSurface_0)
    {
        _S466 = !ms_2.thinWalled_0;
    }
    else
    {
        _S466 = false;
    }
    if(_S466)
    {
        if(si_4.frontFacing_0)
        {
            throughput_23 = HomogeneousVolume_Absorption_0(bsdf_1.volume_0);
        }
        else
        {
            throughput_23 = vec3<f32>(0.0f);
        }
        (*s_21).path_0.absorption_0 = throughput_23;
    }
    (*s_21).path_0.coneWidth_2 = hitConeWidth_0;
    (*s_21).path_0.coneSpread_0 = (*s_21).path_0.coneSpread_0 + ScatterConeSpread_0(bs_0.type_0, ms_2.roughness_4);
    (*s_21).randomSeed_0 = rng_5.seed_0;
    (*s_21).active_0 = u32(1);
    if(_S470)
    {
        var _S478 : u32 = Field_0(base_11, u32(6));
        gAccum_0[_S478][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S478].w))) + u32(1))));
    }
    return;
}

fn IntersectTriangle_1( o_55 : vec3<f32>,  d_11 : vec3<f32>,  v0_2 : vec3<f32>,  e1_1 : vec3<f32>,  e2_1 : vec3<f32>,  tMin_3 : f32,  tMax_3 : f32,  t_12 : ptr<function, f32>,  bary_3 : ptr<function, vec2<f32>>) -> bool
{
    (*t_12) = 0.0f;
    (*bary_3) = vec2<f32>(0.0f);
    var h_15 : vec3<f32> = cross(d_11, e2_1);
    var a_19 : f32 = dot(e1_1, h_15);
    if(a_19 == 0.0f)
    {
        return false;
    }
    var f_22 : f32 = rcp_1(a_19);
    var s_22 : vec3<f32> = o_55 - v0_2;
    var u_33 : f32 = f_22 * dot(s_22, h_15);
    var _S479 : bool;
    if((u_33 < 0.0f))
    {
        _S479 = true;
    }
    else
    {
        _S479 = (u_33 > 1.0f);
    }
    if(_S479)
    {
        return false;
    }
    var q_1 : vec3<f32> = cross(s_22, e1_1);
    var v_19 : f32 = f_22 * dot(d_11, q_1);
    if((v_19 < 0.0f))
    {
        _S479 = true;
    }
    else
    {
        _S479 = ((u_33 + v_19) > 1.0f);
    }
    if(_S479)
    {
        return false;
    }
    (*t_12) = f_22 * dot(e2_1, q_1);
    (*bary_3) = vec2<f32>(u_33, v_19);
    if(((*t_12) > tMin_3))
    {
        _S479 = ((*t_12) < tMax_3);
    }
    else
    {
        _S479 = false;
    }
    return _S479;
}

fn VertexUV0_1( v_20 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_20).positionU_0.w, (*v_20).normalV_0.w);
}

fn AlphaTestRejects_0( _S480 : u32,  _S481 : u32,  _S482 : vec2<f32>,  _S483 : f32) -> bool
{
    var material_4 : MaterialHeader_0 = LoadMaterialHeader_0(gInstances_0[_S480].materialIndex_0);
    var _S484 : u32 = MaterialHeader_AlphaMode_0(material_4);
    if(_S484 == u32(0))
    {
        return false;
    }
    var _S485 : vec3<u32> = LoadTriangleIndices_0(_S480, _S481);
    var _S486 : Vertex_std430_0 = gVertices_0[_S485.x];
    var _S487 : Vertex_std430_0 = gVertices_0[_S485.y];
    var _S488 : Vertex_std430_0 = gVertices_0[_S485.z];
    var _S489 : f32 = _S482.x;
    var _S490 : f32 = _S482.y;
    var _S491 : f32 = 1.0f - _S489 - _S490;
    var _S492 : vec2<f32> = VertexUV0_1(&(_S486));
    var _S493 : vec2<f32> = VertexUV0_1(&(_S487));
    var _S494 : vec2<f32> = VertexUV0_1(&(_S488));
    var _S495 : vec2<f32> = vec2<f32>(_S491);
    var _S496 : vec2<f32> = vec2<f32>(_S489);
    var _S497 : vec2<f32> = vec2<f32>(_S490);
    var _S498 : vec2<f32> = _S486.uv1_0.xy;
    var _S499 : vec2<f32> = _S487.uv1_0.xy;
    var _S500 : vec2<f32> = _S488.uv1_0.xy;
    var _S501 : vec3<f32> = _S487.positionU_0.xyz;
    var _S502 : vec3<f32> = _S486.positionU_0.xyz;
    var _S503 : vec3<f32> = _S488.positionU_0.xyz;
    var tc_8 : TextureCoords_0 = MakeTextureCoords_0(_S492 * _S495 + _S493 * _S496 + _S494 * _S497, _S498 * _S495 + _S499 * _S496 + _S500 * _S497, TransformVector_0(_S480, _S501 - _S502), TransformVector_0(_S480, _S503 - _S502), _S493 - _S492, _S494 - _S492, _S499 - _S498, _S500 - _S498, gRayCone_0.x + gRayCone_0.y * _S483, 1.0f);
    tc_8.objectPosition_0 = _S502 * vec3<f32>(_S491) + _S501 * vec3<f32>(_S489) + _S503 * vec3<f32>(_S490);
    var opacity_1 : f32 = EvalOpacity_0(material_4, tc_8);
    if(_S484 == u32(1))
    {
        return (opacity_1 < (material_4.alphaCutoff_0));
    }
    return (opacity_1 < (f32(((StrongIntegerHash_0((_S481 ^ ((StrongIntegerHash_0(((bitcast<u32>((_S483))) ^ ((gFrame_0.frame_0.w))))))))) & (u32(16777215)))) * 5.9604644775390625e-08f));
}

fn TraverseBLAS_1( _S504 : u32,  _S505 : u32,  _S506 : vec3<f32>,  _S507 : vec3<f32>,  _S508 : f32,  _S509 : bool,  _S510 : ptr<function, HitRecord_0>) -> bool
{
    var found_5 : bool;
    var _S511 : vec3<f32> = SafeRcp_0(_S507);
    var _S512 : bool = (((gInstances_0[_S505].flags_0) & (u32(1)))) != u32(0);
    var stack_4 : array<u32, i32(48)>;
    var nodeRef_2 : u32 = u32(0);
    var found_6 : bool = false;
    var stackPtr_8 : u32 = u32(0);
    loop
    {
        var i_9 : u32;
        if(((nodeRef_2 & (u32(2147483648)))) != u32(0))
        {
            var _S513 : u32 = (((nodeRef_2 >> (u32(24)))) & (u32(127)));
            var _S514 : u32 = (nodeRef_2 & (u32(16777215)));
            found_5 = found_6;
            i_9 = u32(0);
            loop
            {
                if((i_9 < _S513))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_12 : u32 = (gInstances_0[_S505].blasTriOffset_0 + _S514 + i_9) * u32(3);
                var v0_3 : vec4<f32> = gTris_0[base_12];
                var t_13 : f32;
                var bary_4 : vec2<f32>;
                var _S515 : bool = IntersectTriangle_1(_S506, _S507, v0_3.xyz, gTris_0[base_12 + u32(1)].xyz, gTris_0[base_12 + u32(2)].xyz, _S508, (*_S510).t_6, &(t_13), &(bary_4));
                if(!_S515)
                {
                    i_9 = i_9 + u32(1);
                    continue;
                }
                var primitiveIndex_3 : u32 = (bitcast<u32>((v0_3.w)));
                var _S516 : bool;
                if(_S512)
                {
                    var _S517 : bool = AlphaTestRejects_0(_S505, primitiveIndex_3, bary_4, t_13);
                    _S516 = _S517;
                }
                else
                {
                    _S516 = false;
                }
                if(_S516)
                {
                    i_9 = i_9 + u32(1);
                    continue;
                }
                (*_S510).t_6 = t_13;
                (*_S510).barycentrics_0 = bary_4;
                (*_S510).instanceIndex_2 = _S504;
                (*_S510).primitiveIndex_1 = primitiveIndex_3;
                if(_S509)
                {
                    return true;
                }
                found_5 = true;
                i_9 = i_9 + u32(1);
            }
            if(stackPtr_8 == u32(0))
            {
                break;
            }
            var stackPtr_9 : u32 = stackPtr_8 - u32(1);
            nodeRef_2 = stack_4[stackPtr_9];
            found_6 = found_5;
            stackPtr_8 = stackPtr_9;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_2 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S505].blasNodeOffset_0 + nodeRef_2];
        var dist1_4 : f32 = IntersectBox_0(node_2.lmin_0, node_2.lmax_0, _S506, _S511, _S508, (*_S510).t_6);
        var dist2_4 : f32 = IntersectBox_0(node_2.rmin_0, node_2.rmax_0, _S506, _S511, _S508, (*_S510).t_6);
        var far_2 : u32;
        var dist1_5 : f32;
        var dist2_5 : f32;
        if((dist1_4 > dist2_4))
        {
            dist1_5 = dist2_4;
            i_9 = node_2.right_0;
            dist2_5 = dist1_4;
            far_2 = node_2.left_0;
        }
        else
        {
            dist1_5 = dist1_4;
            i_9 = node_2.left_0;
            dist2_5 = dist2_4;
            far_2 = node_2.right_0;
        }
        if(dist1_5 == 1.00000001504746622e+30f)
        {
            if(stackPtr_8 == u32(0))
            {
                found_5 = found_6;
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
                found_5 = (stackPtr_8 < u32(48));
            }
            else
            {
                found_5 = false;
            }
            var stackPtr_11 : u32;
            if(found_5)
            {
                var _S518 : u32 = stackPtr_8 + u32(1);
                stack_4[stackPtr_8] = far_2;
                stackPtr_11 = _S518;
            }
            else
            {
                stackPtr_11 = stackPtr_8;
            }
            nodeRef_2 = i_9;
            stackPtr_8 = stackPtr_11;
        }
    }
    return found_5;
}

fn TraceScene_1( ray_2 : Ray_0,  anyHit_1 : bool,  hit_4 : ptr<function, HitRecord_0>) -> bool
{
    var found_7 : bool;
    (*hit_4).t_6 = ray_2.tMax_0;
    (*hit_4).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_4).instanceIndex_2 = u32(4294967295);
    (*hit_4).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S519 : u32 = gFrame_0.counts_0.z;
    var _S520 : vec3<f32> = SafeRcp_0(ray_2.direction_0);
    var stack_5 : array<u32, i32(32)>;
    var nodeRef_3 : u32 = u32(0);
    var found_8 : bool = false;
    var stackPtr_12 : u32 = u32(0);
    loop
    {
        var i_10 : u32;
        if(((nodeRef_3 & (u32(2147483648)))) != u32(0))
        {
            var _S521 : u32 = (((nodeRef_3 >> (u32(24)))) & (u32(127)));
            var _S522 : u32 = (nodeRef_3 & (u32(16777215)));
            found_7 = found_8;
            i_10 = u32(0);
            loop
            {
                if((i_10 < _S521))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_4 : u32 = gIndices_0[_S519 + _S522 + i_10];
                var _S523 : bool = TraverseBLAS_1(instanceIndex_4, instanceIndex_4, InverseTransformPoint_0(instanceIndex_4, ray_2.origin_0), InverseTransformVector_0(instanceIndex_4, ray_2.direction_0), ray_2.tMin_0, anyHit_1, &((*hit_4)));
                if(_S523)
                {
                    if(anyHit_1)
                    {
                        return true;
                    }
                    found_7 = true;
                }
                i_10 = i_10 + u32(1);
            }
            if(stackPtr_12 == u32(0))
            {
                break;
            }
            var stackPtr_13 : u32 = stackPtr_12 - u32(1);
            nodeRef_3 = stack_5[stackPtr_13];
            found_8 = found_7;
            stackPtr_12 = stackPtr_13;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_3 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_3];
        var dist1_6 : f32 = IntersectBox_0(node_3.lmin_0, node_3.lmax_0, ray_2.origin_0, _S520, ray_2.tMin_0, (*hit_4).t_6);
        var dist2_6 : f32 = IntersectBox_0(node_3.rmin_0, node_3.rmax_0, ray_2.origin_0, _S520, ray_2.tMin_0, (*hit_4).t_6);
        var far_3 : u32;
        var dist1_7 : f32;
        var dist2_7 : f32;
        if((dist1_6 > dist2_6))
        {
            dist1_7 = dist2_6;
            i_10 = node_3.right_0;
            dist2_7 = dist1_6;
            far_3 = node_3.left_0;
        }
        else
        {
            dist1_7 = dist1_6;
            i_10 = node_3.left_0;
            dist2_7 = dist2_6;
            far_3 = node_3.right_0;
        }
        if(dist1_7 == 1.00000001504746622e+30f)
        {
            if(stackPtr_12 == u32(0))
            {
                found_7 = found_8;
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
                found_7 = (stackPtr_12 < u32(32));
            }
            else
            {
                found_7 = false;
            }
            var stackPtr_15 : u32;
            if(found_7)
            {
                var _S524 : u32 = stackPtr_12 + u32(1);
                stack_5[stackPtr_12] = far_3;
                stackPtr_15 = _S524;
            }
            else
            {
                stackPtr_15 = stackPtr_12;
            }
            nodeRef_3 = i_10;
            stackPtr_12 = stackPtr_15;
        }
    }
    return found_7;
}

fn TraceOcclusion_1( ray_3 : Ray_0) -> bool
{
    var hit_5 : HitRecord_0;
    var _S525 : bool = TraceScene_1(ray_3, true, &(hit_5));
    return _S525;
}

fn NextEventEstimation_1( si_5 : SurfaceInteraction_0,  bsdf_2 : BSDF_0,  cone_2 : vec2<f32>,  rng_6 : ptr<function, RandomSequence_0>) -> vec3<f32>
{
    var _S526 : vec3<f32> = vec3<f32>(0.0f);
    gRayCone_0 = cone_2;
    var source_1 : u32 = u32(0);
    var result_8 : vec3<f32> = _S526;
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
        var mis_1 : bool;
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
            var _S527 : vec3<f32> = ShadowOrigin_0(si_5, dir_13);
            shadow_2 = true;
            origin_4 = _S527;
            maxDistance_2 = 1.00000001504746622e+30f;
            mis_1 = true;
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
                var _S528 : bool = !ls_6.delta_0;
                shadow_2 = ls_6.shadow_0;
                origin_4 = origin_5;
                maxDistance_2 = maxDistance_3;
                mis_1 = _S528;
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
                var _S529 : vec3<f32> = ShadowOrigin_0(si_5, dir_16);
                shadow_2 = true;
                origin_4 = _S529;
                maxDistance_2 = 1.00000001504746622e+30f;
                mis_1 = false;
                ls_4 = ls_7;
                dir_12 = dir_16;
            }
        }
        var eval_1 : DiffuseSpecular_0;
        var bsdfPdf_1 : f32;
        BSDF_EvalPdf_0(bsdf_2, dir_12, &(eval_1), &(bsdfPdf_1));
        var f_23 : vec3<f32> = eval_1.diffuse_1 + eval_1.specular_1;
        var _S530 : bool;
        if((any(((f_23 > vec3<f32>(0.0f))))))
        {
            if(!shadow_2)
            {
                _S530 = true;
            }
            else
            {
                var _S531 : bool = TraceOcclusion_1(Ray_x24init_0(origin_4, dir_12, maxDistance_2));
                _S530 = !_S531;
            }
        }
        else
        {
            _S530 = false;
        }
        var result_9 : vec3<f32>;
        if(_S530)
        {
            var weight_5 : f32;
            if(mis_1)
            {
                weight_5 = EvalMISRobust_0(ls_4.solidAnglePdf_0, bsdfPdf_1);
            }
            else
            {
                weight_5 = 1.0f;
            }
            result_9 = result_8 + vec3<f32>(weight_5) * ls_4.radiance_0 * f_23 / vec3<f32>(ls_4.solidAnglePdf_0);
        }
        else
        {
            result_9 = result_8;
        }
        result_8 = result_9;
        source_1 = source_1 + u32(1);
    }
    return result_8;
}

fn ShadePath_1( base_13 : u32,  s_23 : ptr<function, WavefrontPath_0>,  hit_6 : HitRecord_0,  bounce_3 : u32)
{
    var _S532 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_23).path_0.absorption_0) > _S532)))))
    {
        (*s_23).path_0.throughput_7 = (*s_23).path_0.throughput_7 * exp((*s_23).path_0.absorption_0 * vec3<f32>(- hit_6.t_6));
    }
    var hitConeWidth_1 : f32 = (*s_23).path_0.coneWidth_2 + (*s_23).path_0.coneSpread_0 * hit_6.t_6;
    var si_6 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_23).path_0.direction_1, hit_6, hitConeWidth_1);
    var V_3 : vec3<f32> = (vec3<f32>(0) - (*s_23).path_0.direction_1);
    var ms_3 : MaterialSample_0 = EvalMaterial_0(si_6, V_3);
    var bsdf_3 : BSDF_0 = BSDF_x24init_0(ms_3.inputs_1, V_3, (*s_23).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S533 : bool = bounce_3 == u32(0);
    var throughput_25 : vec3<f32>;
    if(_S533)
    {
        (*s_23).albedo_2 = ms_3.albedo_3;
        if(si_6.frontFacing_0)
        {
            throughput_25 = ms_3.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_25 = (vec3<f32>(0) - ms_3.inputs_1.basis_1.n_1);
        }
        (*s_23).normal_11 = throughput_25;
        if((gFrame_0.temporal_0.z) != 0.0f)
        {
            var pixel_2 : vec2<u32> = WorkPixel_0(base_13 - WorkBase_0(u32(0)));
            var output_1 : u32 = (pixel_2.y * gFrame_0.frame_0.x + pixel_2.x) * u32(3);
            gAccum_0[output_1 + u32(1)][i32(3)] = hit_6.t_6;
            gAccum_0[output_1 + u32(2)][i32(3)] = f32(hit_6.instanceIndex_2 + u32(1));
        }
        if(NrdEnabled_0())
        {
            var r_12 : u32 = NrdBase_0(base_13);
            gAccum_0[r_12] = vec4<f32>((*s_23).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
            gAccum_0[r_12 + u32(1)] = vec4<f32>(0.0f);
            gAccum_0[r_12 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_3.roughness_4, ms_3.inputs_1.baseMetalness_0));
        }
    }
    (*s_23).active_0 = u32(0);
    var _S534 : bool;
    if(!si_6.frontFacing_0)
    {
        _S534 = !ms_3.doubleSided_2;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        _S534 = ((ms_3.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        return;
    }
    var continuation_1 : f32;
    if((any((((bsdf_3.emission_0) > _S532)))))
    {
        var _S535 : bool = !_S533;
        if(_S535)
        {
            _S534 = (*s_23).path_0.lightsSampled_0;
        }
        else
        {
            _S534 = false;
        }
        if(_S534)
        {
            continuation_1 = EvalMISRobust_0((*s_23).path_0.scatterPdf_0, EmissiveHitPdf_0(si_6.instanceIndex_0, si_6.primitiveIndex_0, (*s_23).path_0.origin_3, si_6.position_0));
        }
        else
        {
            continuation_1 = 1.0f;
        }
        var contribution_1 : vec3<f32> = (*s_23).path_0.throughput_7 * vec3<f32>(continuation_1) * bsdf_3.emission_0;
        var clampValue_2 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_2 > 0.0f))
        {
            _S534 = _S535;
        }
        else
        {
            _S534 = false;
        }
        if(_S534)
        {
            throughput_25 = min(contribution_1, vec3<f32>(clampValue_2));
        }
        else
        {
            throughput_25 = contribution_1;
        }
        (*s_23).path_0.radiance_1 = (*s_23).path_0.radiance_1 + throughput_25;
    }
    if(_S533)
    {
        _S534 = NrdEnabled_0();
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        var _S536 : u32 = NrdBase_0(base_13);
        var _S537 : vec3<f32> = (*s_23).path_0.radiance_1;
        gAccum_0[_S536].x = _S537.x;
        gAccum_0[_S536].y = _S537.y;
        gAccum_0[_S536].z = _S537.z;
    }
    if(bounce_3 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S538 : bool = SharcEnabled_0();
    if(_S538)
    {
        _S534 = !_S533;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        _S534 = SharcSurface_0(ms_3);
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        var key_5 : SharcKey_0;
        var voxelSize_1 : f32;
        if(si_6.frontFacing_0)
        {
            throughput_25 = si_6.faceNormal_0;
        }
        else
        {
            throughput_25 = (vec3<f32>(0) - si_6.faceNormal_0);
        }
        var index_18 : u32 = base_13 - WorkBase_0(u32(0));
        var _S539 : bool = SharcMakeKey_0(si_6.position_0, throughput_25, V_3, si_6.materialIndex_1, si_6.instanceIndex_0, &(key_5), &(voxelSize_1));
        if(_S539)
        {
            if(SharcUpdatePath_0(index_18, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_18, bounce_3, key_5, (*s_23).path_0.radiance_1, (*s_23).path_0.throughput_7);
            }
            else
            {
                if(((hit_6.t_6) > (voxelSize_1 * sqrt(3.0f))))
                {
                    _S534 = (hitConeWidth_1 > voxelSize_1);
                }
                else
                {
                    _S534 = false;
                }
                if(_S534)
                {
                    _S534 = (((*s_23).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S534 = false;
                }
                if(_S534)
                {
                    var _S540 : u32 = Field_0(base_13, u32(6));
                    var state_1 : u32 = (bitcast<u32>((gAccum_0[_S540].w))) + u32(65536);
                    var cached_1 : vec3<f32>;
                    var found_9 : bool = SharcQuery_0(key_5, &(cached_1));
                    var _S541 : u32;
                    if(found_9)
                    {
                        _S541 = u32(256);
                    }
                    else
                    {
                        _S541 = u32(0);
                    }
                    gAccum_0[_S540][i32(3)] = (bitcast<f32>(((state_1 | (_S541)))));
                    if(found_9)
                    {
                        (*s_23).path_0.radiance_1 = (*s_23).path_0.radiance_1 + (*s_23).path_0.throughput_7 * cached_1;
                        return;
                    }
                }
            }
        }
    }
    var rng_7 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_7.seed_0 = (*s_23).randomSeed_0;
    var _S542 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_3)) >= 0.0010000000474974513f);
    (*s_23).path_0.lightsSampled_0 = _S542;
    if(_S542)
    {
        var _S543 : vec3<f32> = NextEventEstimation_1(si_6, bsdf_3, vec2<f32>(hitConeWidth_1, (*s_23).path_0.coneSpread_0), &(rng_7));
        var direct_1 : vec3<f32> = (*s_23).path_0.throughput_7 * _S543;
        var clampValue_3 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_3 > 0.0f))
        {
            _S534 = !_S533;
        }
        else
        {
            _S534 = false;
        }
        if(_S534)
        {
            throughput_25 = min(direct_1, vec3<f32>(clampValue_3));
        }
        else
        {
            throughput_25 = direct_1;
        }
        (*s_23).path_0.radiance_1 = (*s_23).path_0.radiance_1 + throughput_25;
    }
    var u_34 : vec2<f32> = RandomSequence_Next2D_0(&(rng_7));
    var _S544 : f32 = RandomSequence_Next_1(&(rng_7));
    var bs_1 : LobeSample_0 = BSDF_Sample_0(bsdf_3, vec3<f32>(u_34, _S544));
    var weight_6 : vec3<f32> = bs_1.weight_1.diffuse_1 + bs_1.weight_1.specular_1;
    if(!bs_1.valid_1)
    {
        _S534 = true;
    }
    else
    {
        _S534 = ((bs_1.pdf_7) <= 0.0f);
    }
    if(_S534)
    {
        _S534 = true;
    }
    else
    {
        _S534 = (all(((weight_6 <= _S532))));
    }
    if(_S534)
    {
        return;
    }
    if(_S533)
    {
        _S534 = NrdEnabled_0();
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        var r_13 : u32 = NrdBase_0(base_13);
        var oct_1 : vec2<f32> = NrdOctEncode_0(bs_1.wi_26);
        gAccum_0[r_13][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_1.weight_1)))));
        gAccum_0[r_13 + u32(3)][i32(3)] = oct_1.x;
        gAccum_0[r_13 + u32(4)][i32(3)] = oct_1.y;
    }
    var throughput_26 : vec3<f32> = (*s_23).path_0.throughput_7 * weight_6;
    if(_S538)
    {
        _S534 = _S533;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        continuation_1 = 1.0f;
    }
    else
    {
        continuation_1 = sqrt(saturate(MaxComponent_0(throughput_26) / max(MaxComponent_0((*s_23).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_1 < 1.0f))
    {
        var _S545 : f32 = RandomSequence_Next_1(&(rng_7));
        if((_S545 >= continuation_1))
        {
            return;
        }
        throughput_25 = throughput_26 / vec3<f32>(continuation_1);
    }
    else
    {
        throughput_25 = throughput_26;
    }
    (*s_23).path_0.throughput_7 = throughput_25;
    (*s_23).path_0.direction_1 = bs_1.wi_26;
    (*s_23).path_0.scatterPdf_0 = bs_1.pdf_7;
    var crossesSurface_1 : bool = ((dot(bs_1.wi_26, si_6.faceNormal_0)) > 0.0f) != (si_6.frontFacing_0);
    (*s_23).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_6, !crossesSurface_1);
    if(crossesSurface_1)
    {
        _S534 = !ms_3.thinWalled_0;
    }
    else
    {
        _S534 = false;
    }
    if(_S534)
    {
        if(si_6.frontFacing_0)
        {
            throughput_25 = HomogeneousVolume_Absorption_0(bsdf_3.volume_0);
        }
        else
        {
            throughput_25 = vec3<f32>(0.0f);
        }
        (*s_23).path_0.absorption_0 = throughput_25;
    }
    (*s_23).path_0.coneWidth_2 = hitConeWidth_1;
    (*s_23).path_0.coneSpread_0 = (*s_23).path_0.coneSpread_0 + ScatterConeSpread_0(bs_1.type_0, ms_3.roughness_4);
    (*s_23).randomSeed_0 = rng_7.seed_0;
    (*s_23).active_0 = u32(1);
    if(_S538)
    {
        var _S546 : u32 = Field_0(base_13, u32(6));
        gAccum_0[_S546][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S546].w))) + u32(1))));
    }
    return;
}

fn LoadPath_0( base_14 : u32) -> WavefrontPath_0
{
    var s_24 : WavefrontPath_0;
    s_24.path_0.radiance_1 = gAccum_0[base_14].xyz;
    s_24.active_0 = (bitcast<u32>((gAccum_0[base_14].w)));
    s_24.path_0.throughput_7 = gAccum_0[Field_0(base_14, u32(1))].xyz;
    s_24.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_14, u32(1))].w)));
    s_24.path_0.origin_3 = gAccum_0[Field_0(base_14, u32(2))].xyz;
    s_24.path_0.scatterPdf_0 = gAccum_0[Field_0(base_14, u32(2))].w;
    s_24.path_0.direction_1 = gAccum_0[Field_0(base_14, u32(3))].xyz;
    s_24.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_14, u32(3))].w))) != u32(0);
    s_24.path_0.absorption_0 = gAccum_0[Field_0(base_14, u32(4))].xyz;
    s_24.path_0.coneWidth_2 = gAccum_0[Field_0(base_14, u32(4))].w;
    var _S547 : vec3<f32> = vec3<f32>(0.0f);
    s_24.albedo_2 = _S547;
    s_24.path_0.coneSpread_0 = gAccum_0[Field_0(base_14, u32(5))].w;
    s_24.normal_11 = _S547;
    s_24.path_0.lobe_2 = u32(0);
    return s_24;
}

fn ShadowFlags_0( shadow_3 : bool,  primary_0 : bool,  bypass_0 : bool,  eval_2 : DiffuseSpecular_0) -> u32
{
    var _S548 : u32 = select(u32(0), u32(1), shadow_3);
    var _S549 : bool;
    if(primary_0)
    {
        _S549 = NrdEnabled_0();
    }
    else
    {
        _S549 = false;
    }
    var _S550 : u32;
    if(_S549)
    {
        if(bypass_0)
        {
            _S550 = u32(4);
        }
        else
        {
            _S550 = u32(0);
        }
        _S550 = (((u32(2) | (_S550))) | ((((NrdPackFraction_0(NrdDiffuseFraction_0(eval_2))) << (u32(3))))));
    }
    else
    {
        _S550 = u32(0);
    }
    return (_S548 | (_S550));
}

fn QueueDirectLighting_0( base_15 : u32,  si_7 : SurfaceInteraction_0,  bsdf_4 : BSDF_0,  cone_3 : vec2<f32>,  throughput_27 : vec3<f32>,  primary_1 : bool,  rng_8 : ptr<function, RandomSequence_0>)
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
        var mis_2 : bool;
        var shadow_4 : bool;
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
                mis_2 = ((ls_9.solidAnglePdf_0) > 0.0f);
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
            var dir_18 : vec3<f32> = (vec3<f32>(0) - ls_9.normal_7);
            var _S551 : vec3<f32> = ShadowOrigin_0(si_7, dir_18);
            mis_2 = true;
            ls_8 = ls_9;
            origin_6 = _S551;
            maxDistance_4 = 1.00000001504746622e+30f;
            shadow_4 = true;
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
                var _S552 : LightSample_0 = SampleEmissive_0(si_7.position_0, cone_3, &((*rng_8)));
                if((any((((_S552.radiance_0) > vec3<f32>(0.0f))))))
                {
                    mis_2 = ((_S552.solidAnglePdf_0) > 0.0f);
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
                var lightPos_3 : vec3<f32> = ComputeOffsetOrigin_0(_S552.position_1, _S552.normal_7);
                var origin_7 : vec3<f32> = ShadowOrigin_0(si_7, lightPos_3 - si_7.position_0);
                var dir_19 : vec3<f32> = lightPos_3 - origin_7;
                var maxDistance_5 : f32 = length(dir_19);
                var dir_20 : vec3<f32> = dir_19 / vec3<f32>(maxDistance_5);
                mis_2 = !_S552.delta_0;
                ls_8 = _S552;
                origin_6 = origin_7;
                maxDistance_4 = maxDistance_5;
                shadow_4 = _S552.shadow_0;
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
                var _S553 : vec3<f32> = ShadowOrigin_0(si_7, dir_21);
                mis_2 = false;
                ls_8 = ls_10;
                origin_6 = _S553;
                maxDistance_4 = 1.00000001504746622e+30f;
                shadow_4 = true;
                dir_17 = dir_21;
            }
        }
        var eval_3 : DiffuseSpecular_0;
        var pdf_15 : f32;
        BSDF_EvalPdf_0(bsdf_4, dir_17, &(eval_3), &(pdf_15));
        var f_24 : vec3<f32> = eval_3.diffuse_1 + eval_3.specular_1;
        var mask_1 : u32;
        if((any(((f_24 > vec3<f32>(0.0f))))))
        {
            var weight_7 : f32;
            if(mis_2)
            {
                weight_7 = EvalMISRobust_0(ls_8.solidAnglePdf_0, pdf_15);
            }
            else
            {
                weight_7 = 1.0f;
            }
            var offset_1 : u32 = u32(12) + source_2 * u32(3);
            gAccum_0[Field_0(base_15, offset_1)] = vec4<f32>(origin_6, maxDistance_4);
            gAccum_0[Field_0(base_15, offset_1 + u32(1))] = vec4<f32>(dir_17, (bitcast<f32>((ShadowFlags_0(shadow_4, primary_1, source_2 == u32(2), eval_3)))));
            gAccum_0[Field_0(base_15, offset_1 + u32(2))] = vec4<f32>(vec3<f32>(weight_7) * ls_8.radiance_0 * f_24 / vec3<f32>(ls_8.solidAnglePdf_0), 0.0f);
            mask_1 = (mask_0 | (((u32(1) << (source_2)))));
        }
        else
        {
            mask_1 = mask_0;
        }
        mask_0 = mask_1;
        source_2 = source_2 + u32(1);
    }
    if(primary_1)
    {
        maxDistance_4 = 0.0f;
    }
    else
    {
        maxDistance_4 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    gAccum_0[Field_0(base_15, u32(10))] = vec4<f32>(throughput_27, maxDistance_4);
    gAccum_0[Field_0(base_15, u32(11))] = vec4<f32>(cone_3, (bitcast<f32>((mask_0))), 0.0f);
    return;
}

fn ShadePath_2( base_16 : u32,  s_25 : ptr<function, WavefrontPath_0>,  hit_7 : HitRecord_0,  bounce_4 : u32)
{
    var hitConeWidth_2 : f32 = (*s_25).path_0.coneWidth_2 + (*s_25).path_0.coneSpread_0 * hit_7.t_6;
    var si_8 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_25).path_0.direction_1, hit_7, hitConeWidth_2);
    var V_4 : vec3<f32> = (vec3<f32>(0) - (*s_25).path_0.direction_1);
    var ms_4 : MaterialSample_0 = EvalMaterial_0(si_8, V_4);
    (*s_25) = LoadPath_0(base_16);
    var _S554 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_25).path_0.absorption_0) > _S554)))))
    {
        (*s_25).path_0.throughput_7 = (*s_25).path_0.throughput_7 * exp((*s_25).path_0.absorption_0 * vec3<f32>(- hit_7.t_6));
    }
    var bsdf_5 : BSDF_0 = BSDF_x24init_0(ms_4.inputs_1, V_4, (*s_25).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_25).active_0 = u32(0);
    var _S555 : bool;
    if(!si_8.frontFacing_0)
    {
        _S555 = !ms_4.doubleSided_2;
    }
    else
    {
        _S555 = false;
    }
    if(_S555)
    {
        _S555 = ((ms_4.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S555 = false;
    }
    if(_S555)
    {
        return;
    }
    var throughput_28 : vec3<f32>;
    if((any((((bsdf_5.emission_0) > _S554)))))
    {
        var mis_3 : f32;
        if((*s_25).path_0.lightsSampled_0)
        {
            mis_3 = EvalMISRobust_0((*s_25).path_0.scatterPdf_0, EmissiveHitPdf_0(si_8.instanceIndex_0, si_8.primitiveIndex_0, (*s_25).path_0.origin_3, si_8.position_0));
        }
        else
        {
            mis_3 = 1.0f;
        }
        var contribution_2 : vec3<f32> = (*s_25).path_0.throughput_7 * vec3<f32>(mis_3) * bsdf_5.emission_0;
        var clampValue_4 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        var _S556 : bool = (clampValue_4 > 0.0f);
        if(_S556)
        {
            throughput_28 = min(contribution_2, vec3<f32>(clampValue_4));
        }
        else
        {
            throughput_28 = contribution_2;
        }
        (*s_25).path_0.radiance_1 = (*s_25).path_0.radiance_1 + throughput_28;
    }
    if(bounce_4 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S557 : bool = SharcEnabled_0();
    if(_S557)
    {
        _S555 = SharcSurface_0(ms_4);
    }
    else
    {
        _S555 = false;
    }
    if(_S555)
    {
        var key_6 : SharcKey_0;
        var voxelSize_2 : f32;
        if(si_8.frontFacing_0)
        {
            throughput_28 = si_8.faceNormal_0;
        }
        else
        {
            throughput_28 = (vec3<f32>(0) - si_8.faceNormal_0);
        }
        var index_19 : u32 = base_16 - WorkBase_0(u32(0));
        var _S558 : bool = SharcMakeKey_0(si_8.position_0, throughput_28, V_4, si_8.materialIndex_1, si_8.instanceIndex_0, &(key_6), &(voxelSize_2));
        if(_S558)
        {
            if(SharcUpdatePath_0(index_19, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_19, bounce_4, key_6, (*s_25).path_0.radiance_1, (*s_25).path_0.throughput_7);
            }
            else
            {
                if(((hit_7.t_6) > (voxelSize_2 * sqrt(3.0f))))
                {
                    _S555 = (hitConeWidth_2 > voxelSize_2);
                }
                else
                {
                    _S555 = false;
                }
                if(_S555)
                {
                    _S555 = (((*s_25).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S555 = false;
                }
                if(_S555)
                {
                    var _S559 : u32 = Field_0(base_16, u32(6));
                    var state_2 : u32 = (bitcast<u32>((gAccum_0[_S559].w))) + u32(65536);
                    var cached_2 : vec3<f32>;
                    var found_10 : bool = SharcQuery_0(key_6, &(cached_2));
                    var _S560 : u32;
                    if(found_10)
                    {
                        _S560 = u32(256);
                    }
                    else
                    {
                        _S560 = u32(0);
                    }
                    gAccum_0[_S559][i32(3)] = (bitcast<f32>(((state_2 | (_S560)))));
                    if(found_10)
                    {
                        (*s_25).path_0.radiance_1 = (*s_25).path_0.radiance_1 + (*s_25).path_0.throughput_7 * cached_2;
                        return;
                    }
                }
            }
        }
    }
    var rng_9 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_9.seed_0 = (*s_25).randomSeed_0;
    var _S561 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_5)) >= 0.0010000000474974513f);
    (*s_25).path_0.lightsSampled_0 = _S561;
    if(_S561)
    {
        QueueDirectLighting_0(base_16, si_8, bsdf_5, vec2<f32>(hitConeWidth_2, (*s_25).path_0.coneSpread_0), (*s_25).path_0.throughput_7, false, &(rng_9));
    }
    var u_35 : vec2<f32> = RandomSequence_Next2D_0(&(rng_9));
    var _S562 : f32 = RandomSequence_Next_1(&(rng_9));
    var bs_2 : LobeSample_0 = BSDF_Sample_0(bsdf_5, vec3<f32>(u_35, _S562));
    var weight_8 : vec3<f32> = bs_2.weight_1.diffuse_1 + bs_2.weight_1.specular_1;
    if(!bs_2.valid_1)
    {
        _S555 = true;
    }
    else
    {
        _S555 = ((bs_2.pdf_7) <= 0.0f);
    }
    if(_S555)
    {
        _S555 = true;
    }
    else
    {
        _S555 = (all(((weight_8 <= _S554))));
    }
    if(_S555)
    {
        return;
    }
    var throughput_29 : vec3<f32> = (*s_25).path_0.throughput_7 * weight_8;
    var _S563 : f32 = sqrt(saturate(MaxComponent_0(throughput_29) / max(MaxComponent_0((*s_25).path_0.throughput_7), 9.999999960041972e-13f)));
    if((_S563 < 1.0f))
    {
        var _S564 : f32 = RandomSequence_Next_1(&(rng_9));
        if((_S564 >= _S563))
        {
            return;
        }
        throughput_28 = throughput_29 / vec3<f32>(_S563);
    }
    else
    {
        throughput_28 = throughput_29;
    }
    (*s_25).path_0.throughput_7 = throughput_28;
    (*s_25).path_0.direction_1 = bs_2.wi_26;
    (*s_25).path_0.scatterPdf_0 = bs_2.pdf_7;
    var crossesSurface_2 : bool = ((dot(bs_2.wi_26, si_8.faceNormal_0)) > 0.0f) != (si_8.frontFacing_0);
    (*s_25).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_8, !crossesSurface_2);
    if(crossesSurface_2)
    {
        _S555 = !ms_4.thinWalled_0;
    }
    else
    {
        _S555 = false;
    }
    if(_S555)
    {
        if(si_8.frontFacing_0)
        {
            throughput_28 = HomogeneousVolume_Absorption_0(bsdf_5.volume_0);
        }
        else
        {
            throughput_28 = vec3<f32>(0.0f);
        }
        (*s_25).path_0.absorption_0 = throughput_28;
    }
    (*s_25).path_0.coneWidth_2 = hitConeWidth_2;
    (*s_25).path_0.coneSpread_0 = (*s_25).path_0.coneSpread_0 + ScatterConeSpread_0(bs_2.type_0, ms_4.roughness_4);
    (*s_25).randomSeed_0 = rng_9.seed_0;
    (*s_25).active_0 = u32(1);
    if(_S557)
    {
        var _S565 : u32 = Field_0(base_16, u32(6));
        gAccum_0[_S565][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S565].w))) + u32(1))));
    }
    return;
}

fn LoadPath_1( base_17 : u32) -> WavefrontPath_0
{
    var s_26 : WavefrontPath_0;
    s_26.path_0.radiance_1 = gAccum_0[base_17].xyz;
    s_26.active_0 = (bitcast<u32>((gAccum_0[base_17].w)));
    s_26.path_0.throughput_7 = gAccum_0[Field_0(base_17, u32(1))].xyz;
    s_26.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_17, u32(1))].w)));
    s_26.path_0.origin_3 = gAccum_0[Field_0(base_17, u32(2))].xyz;
    s_26.path_0.scatterPdf_0 = gAccum_0[Field_0(base_17, u32(2))].w;
    s_26.path_0.direction_1 = gAccum_0[Field_0(base_17, u32(3))].xyz;
    s_26.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_17, u32(3))].w))) != u32(0);
    s_26.path_0.absorption_0 = gAccum_0[Field_0(base_17, u32(4))].xyz;
    s_26.path_0.coneWidth_2 = gAccum_0[Field_0(base_17, u32(4))].w;
    s_26.albedo_2 = gAccum_0[Field_0(base_17, u32(5))].xyz;
    s_26.path_0.coneSpread_0 = gAccum_0[Field_0(base_17, u32(5))].w;
    s_26.normal_11 = gAccum_0[Field_0(base_17, u32(6))].xyz;
    s_26.path_0.lobe_2 = u32(0);
    return s_26;
}

fn ShadePath_3( base_18 : u32,  s_27 : ptr<function, WavefrontPath_0>,  hit_8 : HitRecord_0,  bounce_5 : u32)
{
    var hitConeWidth_3 : f32 = (*s_27).path_0.coneWidth_2 + (*s_27).path_0.coneSpread_0 * hit_8.t_6;
    var si_9 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_27).path_0.direction_1, hit_8, hitConeWidth_3);
    var V_5 : vec3<f32> = (vec3<f32>(0) - (*s_27).path_0.direction_1);
    var ms_5 : MaterialSample_0 = EvalMaterial_0(si_9, V_5);
    (*s_27) = LoadPath_1(base_18);
    var _S566 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_27).path_0.absorption_0) > _S566)))))
    {
        (*s_27).path_0.throughput_7 = (*s_27).path_0.throughput_7 * exp((*s_27).path_0.absorption_0 * vec3<f32>(- hit_8.t_6));
    }
    var bsdf_6 : BSDF_0 = BSDF_x24init_0(ms_5.inputs_1, V_5, (*s_27).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_27).albedo_2 = ms_5.albedo_3;
    var throughput_30 : vec3<f32>;
    if(si_9.frontFacing_0)
    {
        throughput_30 = ms_5.inputs_1.basis_1.n_1;
    }
    else
    {
        throughput_30 = (vec3<f32>(0) - ms_5.inputs_1.basis_1.n_1);
    }
    (*s_27).normal_11 = throughput_30;
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        var pixel_3 : vec2<u32> = WorkPixel_0(base_18 - WorkBase_0(u32(0)));
        var output_2 : u32 = (pixel_3.y * gFrame_0.frame_0.x + pixel_3.x) * u32(3);
        gAccum_0[output_2 + u32(1)][i32(3)] = hit_8.t_6;
        gAccum_0[output_2 + u32(2)][i32(3)] = f32(hit_8.instanceIndex_2 + u32(1));
    }
    var _S567 : bool = NrdEnabled_0();
    if(_S567)
    {
        var r_14 : u32 = NrdBase_0(base_18);
        gAccum_0[r_14] = vec4<f32>((*s_27).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
        gAccum_0[r_14 + u32(1)] = vec4<f32>(0.0f);
        gAccum_0[r_14 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_5.roughness_4, ms_5.inputs_1.baseMetalness_0));
    }
    (*s_27).active_0 = u32(0);
    var _S568 : bool;
    if(!si_9.frontFacing_0)
    {
        _S568 = !ms_5.doubleSided_2;
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        _S568 = ((ms_5.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        return;
    }
    if((any((((bsdf_6.emission_0) > _S566)))))
    {
        (*s_27).path_0.radiance_1 = (*s_27).path_0.radiance_1 + (*s_27).path_0.throughput_7 * bsdf_6.emission_0;
    }
    if(_S567)
    {
        var _S569 : u32 = NrdBase_0(base_18);
        var _S570 : vec3<f32> = (*s_27).path_0.radiance_1;
        gAccum_0[_S569].x = _S570.x;
        gAccum_0[_S569].y = _S570.y;
        gAccum_0[_S569].z = _S570.z;
    }
    if(bounce_5 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S571 : bool = SharcEnabled_0();
    var rng_10 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_10.seed_0 = (*s_27).randomSeed_0;
    var _S572 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_6)) >= 0.0010000000474974513f);
    (*s_27).path_0.lightsSampled_0 = _S572;
    if(_S572)
    {
        QueueDirectLighting_0(base_18, si_9, bsdf_6, vec2<f32>(hitConeWidth_3, (*s_27).path_0.coneSpread_0), (*s_27).path_0.throughput_7, true, &(rng_10));
    }
    var u_36 : vec2<f32> = RandomSequence_Next2D_0(&(rng_10));
    var _S573 : f32 = RandomSequence_Next_1(&(rng_10));
    var bs_3 : LobeSample_0 = BSDF_Sample_0(bsdf_6, vec3<f32>(u_36, _S573));
    var weight_9 : vec3<f32> = bs_3.weight_1.diffuse_1 + bs_3.weight_1.specular_1;
    if(!bs_3.valid_1)
    {
        _S568 = true;
    }
    else
    {
        _S568 = ((bs_3.pdf_7) <= 0.0f);
    }
    if(_S568)
    {
        _S568 = true;
    }
    else
    {
        _S568 = (all(((weight_9 <= _S566))));
    }
    if(_S568)
    {
        return;
    }
    if(_S567)
    {
        var r_15 : u32 = NrdBase_0(base_18);
        var oct_2 : vec2<f32> = NrdOctEncode_0(bs_3.wi_26);
        gAccum_0[r_15][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_3.weight_1)))));
        gAccum_0[r_15 + u32(3)][i32(3)] = oct_2.x;
        gAccum_0[r_15 + u32(4)][i32(3)] = oct_2.y;
    }
    var throughput_31 : vec3<f32> = (*s_27).path_0.throughput_7 * weight_9;
    var continuation_2 : f32;
    if(_S571)
    {
        continuation_2 = 1.0f;
    }
    else
    {
        continuation_2 = sqrt(saturate(MaxComponent_0(throughput_31) / max(MaxComponent_0((*s_27).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_2 < 1.0f))
    {
        var _S574 : f32 = RandomSequence_Next_1(&(rng_10));
        if((_S574 >= continuation_2))
        {
            return;
        }
        throughput_30 = throughput_31 / vec3<f32>(continuation_2);
    }
    else
    {
        throughput_30 = throughput_31;
    }
    (*s_27).path_0.throughput_7 = throughput_30;
    (*s_27).path_0.direction_1 = bs_3.wi_26;
    (*s_27).path_0.scatterPdf_0 = bs_3.pdf_7;
    var crossesSurface_3 : bool = ((dot(bs_3.wi_26, si_9.faceNormal_0)) > 0.0f) != (si_9.frontFacing_0);
    (*s_27).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_9, !crossesSurface_3);
    if(crossesSurface_3)
    {
        _S568 = !ms_5.thinWalled_0;
    }
    else
    {
        _S568 = false;
    }
    if(_S568)
    {
        if(si_9.frontFacing_0)
        {
            throughput_30 = HomogeneousVolume_Absorption_0(bsdf_6.volume_0);
        }
        else
        {
            throughput_30 = vec3<f32>(0.0f);
        }
        (*s_27).path_0.absorption_0 = throughput_30;
    }
    (*s_27).path_0.coneWidth_2 = hitConeWidth_3;
    (*s_27).path_0.coneSpread_0 = (*s_27).path_0.coneSpread_0 + ScatterConeSpread_0(bs_3.type_0, ms_5.roughness_4);
    (*s_27).randomSeed_0 = rng_10.seed_0;
    (*s_27).active_0 = u32(1);
    if(_S571)
    {
        var _S575 : u32 = Field_0(base_18, u32(6));
        gAccum_0[_S575][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S575].w))) + u32(1))));
    }
    return;
}

fn ShadePath_4( base_19 : u32,  s_28 : ptr<function, WavefrontPath_0>,  hit_9 : HitRecord_0,  bounce_6 : u32)
{
    var hitConeWidth_4 : f32 = (*s_28).path_0.coneWidth_2 + (*s_28).path_0.coneSpread_0 * hit_9.t_6;
    var si_10 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_28).path_0.direction_1, hit_9, hitConeWidth_4);
    var V_6 : vec3<f32> = (vec3<f32>(0) - (*s_28).path_0.direction_1);
    var ms_6 : MaterialSample_0 = EvalMaterial_0(si_10, V_6);
    (*s_28) = LoadPath_1(base_19);
    var _S576 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_28).path_0.absorption_0) > _S576)))))
    {
        (*s_28).path_0.throughput_7 = (*s_28).path_0.throughput_7 * exp((*s_28).path_0.absorption_0 * vec3<f32>(- hit_9.t_6));
    }
    var bsdf_7 : BSDF_0 = BSDF_x24init_0(ms_6.inputs_1, V_6, (*s_28).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S577 : bool = bounce_6 == u32(0);
    var throughput_32 : vec3<f32>;
    if(_S577)
    {
        (*s_28).albedo_2 = ms_6.albedo_3;
        if(si_10.frontFacing_0)
        {
            throughput_32 = ms_6.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_32 = (vec3<f32>(0) - ms_6.inputs_1.basis_1.n_1);
        }
        (*s_28).normal_11 = throughput_32;
        if((gFrame_0.temporal_0.z) != 0.0f)
        {
            var pixel_4 : vec2<u32> = WorkPixel_0(base_19 - WorkBase_0(u32(0)));
            var output_3 : u32 = (pixel_4.y * gFrame_0.frame_0.x + pixel_4.x) * u32(3);
            gAccum_0[output_3 + u32(1)][i32(3)] = hit_9.t_6;
            gAccum_0[output_3 + u32(2)][i32(3)] = f32(hit_9.instanceIndex_2 + u32(1));
        }
        if(NrdEnabled_0())
        {
            var r_16 : u32 = NrdBase_0(base_19);
            gAccum_0[r_16] = vec4<f32>((*s_28).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
            gAccum_0[r_16 + u32(1)] = vec4<f32>(0.0f);
            gAccum_0[r_16 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_6.roughness_4, ms_6.inputs_1.baseMetalness_0));
        }
    }
    (*s_28).active_0 = u32(0);
    var _S578 : bool;
    if(!si_10.frontFacing_0)
    {
        _S578 = !ms_6.doubleSided_2;
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        _S578 = ((ms_6.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        return;
    }
    var continuation_3 : f32;
    if((any((((bsdf_7.emission_0) > _S576)))))
    {
        var _S579 : bool = !_S577;
        if(_S579)
        {
            _S578 = (*s_28).path_0.lightsSampled_0;
        }
        else
        {
            _S578 = false;
        }
        if(_S578)
        {
            continuation_3 = EvalMISRobust_0((*s_28).path_0.scatterPdf_0, EmissiveHitPdf_0(si_10.instanceIndex_0, si_10.primitiveIndex_0, (*s_28).path_0.origin_3, si_10.position_0));
        }
        else
        {
            continuation_3 = 1.0f;
        }
        var contribution_3 : vec3<f32> = (*s_28).path_0.throughput_7 * vec3<f32>(continuation_3) * bsdf_7.emission_0;
        var clampValue_5 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_5 > 0.0f))
        {
            _S578 = _S579;
        }
        else
        {
            _S578 = false;
        }
        if(_S578)
        {
            throughput_32 = min(contribution_3, vec3<f32>(clampValue_5));
        }
        else
        {
            throughput_32 = contribution_3;
        }
        (*s_28).path_0.radiance_1 = (*s_28).path_0.radiance_1 + throughput_32;
    }
    if(_S577)
    {
        _S578 = NrdEnabled_0();
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        var _S580 : u32 = NrdBase_0(base_19);
        var _S581 : vec3<f32> = (*s_28).path_0.radiance_1;
        gAccum_0[_S580].x = _S581.x;
        gAccum_0[_S580].y = _S581.y;
        gAccum_0[_S580].z = _S581.z;
    }
    if(bounce_6 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S582 : bool = SharcEnabled_0();
    if(_S582)
    {
        _S578 = !_S577;
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        _S578 = SharcSurface_0(ms_6);
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        var key_7 : SharcKey_0;
        var voxelSize_3 : f32;
        if(si_10.frontFacing_0)
        {
            throughput_32 = si_10.faceNormal_0;
        }
        else
        {
            throughput_32 = (vec3<f32>(0) - si_10.faceNormal_0);
        }
        var index_20 : u32 = base_19 - WorkBase_0(u32(0));
        var _S583 : bool = SharcMakeKey_0(si_10.position_0, throughput_32, V_6, si_10.materialIndex_1, si_10.instanceIndex_0, &(key_7), &(voxelSize_3));
        if(_S583)
        {
            if(SharcUpdatePath_0(index_20, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_20, bounce_6, key_7, (*s_28).path_0.radiance_1, (*s_28).path_0.throughput_7);
            }
            else
            {
                if(((hit_9.t_6) > (voxelSize_3 * sqrt(3.0f))))
                {
                    _S578 = (hitConeWidth_4 > voxelSize_3);
                }
                else
                {
                    _S578 = false;
                }
                if(_S578)
                {
                    _S578 = (((*s_28).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S578 = false;
                }
                if(_S578)
                {
                    var _S584 : u32 = Field_0(base_19, u32(6));
                    var state_3 : u32 = (bitcast<u32>((gAccum_0[_S584].w))) + u32(65536);
                    var cached_3 : vec3<f32>;
                    var found_11 : bool = SharcQuery_0(key_7, &(cached_3));
                    var _S585 : u32;
                    if(found_11)
                    {
                        _S585 = u32(256);
                    }
                    else
                    {
                        _S585 = u32(0);
                    }
                    gAccum_0[_S584][i32(3)] = (bitcast<f32>(((state_3 | (_S585)))));
                    if(found_11)
                    {
                        (*s_28).path_0.radiance_1 = (*s_28).path_0.radiance_1 + (*s_28).path_0.throughput_7 * cached_3;
                        return;
                    }
                }
            }
        }
    }
    var rng_11 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_11.seed_0 = (*s_28).randomSeed_0;
    var _S586 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_7)) >= 0.0010000000474974513f);
    (*s_28).path_0.lightsSampled_0 = _S586;
    if(_S586)
    {
        QueueDirectLighting_0(base_19, si_10, bsdf_7, vec2<f32>(hitConeWidth_4, (*s_28).path_0.coneSpread_0), (*s_28).path_0.throughput_7, _S577, &(rng_11));
    }
    var u_37 : vec2<f32> = RandomSequence_Next2D_0(&(rng_11));
    var _S587 : f32 = RandomSequence_Next_1(&(rng_11));
    var bs_4 : LobeSample_0 = BSDF_Sample_0(bsdf_7, vec3<f32>(u_37, _S587));
    var weight_10 : vec3<f32> = bs_4.weight_1.diffuse_1 + bs_4.weight_1.specular_1;
    if(!bs_4.valid_1)
    {
        _S578 = true;
    }
    else
    {
        _S578 = ((bs_4.pdf_7) <= 0.0f);
    }
    if(_S578)
    {
        _S578 = true;
    }
    else
    {
        _S578 = (all(((weight_10 <= _S576))));
    }
    if(_S578)
    {
        return;
    }
    if(_S577)
    {
        _S578 = NrdEnabled_0();
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        var r_17 : u32 = NrdBase_0(base_19);
        var oct_3 : vec2<f32> = NrdOctEncode_0(bs_4.wi_26);
        gAccum_0[r_17][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_4.weight_1)))));
        gAccum_0[r_17 + u32(3)][i32(3)] = oct_3.x;
        gAccum_0[r_17 + u32(4)][i32(3)] = oct_3.y;
    }
    var throughput_33 : vec3<f32> = (*s_28).path_0.throughput_7 * weight_10;
    if(_S582)
    {
        _S578 = _S577;
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        continuation_3 = 1.0f;
    }
    else
    {
        continuation_3 = sqrt(saturate(MaxComponent_0(throughput_33) / max(MaxComponent_0((*s_28).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_3 < 1.0f))
    {
        var _S588 : f32 = RandomSequence_Next_1(&(rng_11));
        if((_S588 >= continuation_3))
        {
            return;
        }
        throughput_32 = throughput_33 / vec3<f32>(continuation_3);
    }
    else
    {
        throughput_32 = throughput_33;
    }
    (*s_28).path_0.throughput_7 = throughput_32;
    (*s_28).path_0.direction_1 = bs_4.wi_26;
    (*s_28).path_0.scatterPdf_0 = bs_4.pdf_7;
    var crossesSurface_4 : bool = ((dot(bs_4.wi_26, si_10.faceNormal_0)) > 0.0f) != (si_10.frontFacing_0);
    (*s_28).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_10, !crossesSurface_4);
    if(crossesSurface_4)
    {
        _S578 = !ms_6.thinWalled_0;
    }
    else
    {
        _S578 = false;
    }
    if(_S578)
    {
        if(si_10.frontFacing_0)
        {
            throughput_32 = HomogeneousVolume_Absorption_0(bsdf_7.volume_0);
        }
        else
        {
            throughput_32 = vec3<f32>(0.0f);
        }
        (*s_28).path_0.absorption_0 = throughput_32;
    }
    (*s_28).path_0.coneWidth_2 = hitConeWidth_4;
    (*s_28).path_0.coneSpread_0 = (*s_28).path_0.coneSpread_0 + ScatterConeSpread_0(bs_4.type_0, ms_6.roughness_4);
    (*s_28).randomSeed_0 = rng_11.seed_0;
    (*s_28).active_0 = u32(1);
    if(_S582)
    {
        var _S589 : u32 = Field_0(base_19, u32(6));
        gAccum_0[_S589][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S589].w))) + u32(1))));
    }
    return;
}

fn ShadePath_5( base_20 : u32,  s_29 : ptr<function, WavefrontPath_0>,  hit_10 : HitRecord_0,  bounce_7 : u32)
{
    var _S590 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_29).path_0.absorption_0) > _S590)))))
    {
        (*s_29).path_0.throughput_7 = (*s_29).path_0.throughput_7 * exp((*s_29).path_0.absorption_0 * vec3<f32>(- hit_10.t_6));
    }
    var hitConeWidth_5 : f32 = (*s_29).path_0.coneWidth_2 + (*s_29).path_0.coneSpread_0 * hit_10.t_6;
    var si_11 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_29).path_0.direction_1, hit_10, hitConeWidth_5);
    var V_7 : vec3<f32> = (vec3<f32>(0) - (*s_29).path_0.direction_1);
    var ms_7 : MaterialSample_0 = EvalMaterial_0(si_11, V_7);
    var bsdf_8 : BSDF_0 = BSDF_x24init_0(ms_7.inputs_1, V_7, (*s_29).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_29).active_0 = u32(0);
    var _S591 : bool;
    if(!si_11.frontFacing_0)
    {
        _S591 = !ms_7.doubleSided_2;
    }
    else
    {
        _S591 = false;
    }
    if(_S591)
    {
        _S591 = ((ms_7.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S591 = false;
    }
    if(_S591)
    {
        return;
    }
    var throughput_34 : vec3<f32>;
    if((any((((bsdf_8.emission_0) > _S590)))))
    {
        var mis_4 : f32;
        if((*s_29).path_0.lightsSampled_0)
        {
            mis_4 = EvalMISRobust_0((*s_29).path_0.scatterPdf_0, EmissiveHitPdf_0(si_11.instanceIndex_0, si_11.primitiveIndex_0, (*s_29).path_0.origin_3, si_11.position_0));
        }
        else
        {
            mis_4 = 1.0f;
        }
        var contribution_4 : vec3<f32> = (*s_29).path_0.throughput_7 * vec3<f32>(mis_4) * bsdf_8.emission_0;
        var clampValue_6 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        var _S592 : bool = (clampValue_6 > 0.0f);
        if(_S592)
        {
            throughput_34 = min(contribution_4, vec3<f32>(clampValue_6));
        }
        else
        {
            throughput_34 = contribution_4;
        }
        (*s_29).path_0.radiance_1 = (*s_29).path_0.radiance_1 + throughput_34;
    }
    if(bounce_7 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S593 : bool = SharcEnabled_0();
    if(_S593)
    {
        _S591 = SharcSurface_0(ms_7);
    }
    else
    {
        _S591 = false;
    }
    if(_S591)
    {
        var key_8 : SharcKey_0;
        var voxelSize_4 : f32;
        if(si_11.frontFacing_0)
        {
            throughput_34 = si_11.faceNormal_0;
        }
        else
        {
            throughput_34 = (vec3<f32>(0) - si_11.faceNormal_0);
        }
        var index_21 : u32 = base_20 - WorkBase_0(u32(0));
        var _S594 : bool = SharcMakeKey_0(si_11.position_0, throughput_34, V_7, si_11.materialIndex_1, si_11.instanceIndex_0, &(key_8), &(voxelSize_4));
        if(_S594)
        {
            if(SharcUpdatePath_0(index_21, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_21, bounce_7, key_8, (*s_29).path_0.radiance_1, (*s_29).path_0.throughput_7);
            }
            else
            {
                if(((hit_10.t_6) > (voxelSize_4 * sqrt(3.0f))))
                {
                    _S591 = (hitConeWidth_5 > voxelSize_4);
                }
                else
                {
                    _S591 = false;
                }
                if(_S591)
                {
                    _S591 = (((*s_29).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S591 = false;
                }
                if(_S591)
                {
                    var _S595 : u32 = Field_0(base_20, u32(6));
                    var state_4 : u32 = (bitcast<u32>((gAccum_0[_S595].w))) + u32(65536);
                    var cached_4 : vec3<f32>;
                    var found_12 : bool = SharcQuery_0(key_8, &(cached_4));
                    var _S596 : u32;
                    if(found_12)
                    {
                        _S596 = u32(256);
                    }
                    else
                    {
                        _S596 = u32(0);
                    }
                    gAccum_0[_S595][i32(3)] = (bitcast<f32>(((state_4 | (_S596)))));
                    if(found_12)
                    {
                        (*s_29).path_0.radiance_1 = (*s_29).path_0.radiance_1 + (*s_29).path_0.throughput_7 * cached_4;
                        return;
                    }
                }
            }
        }
    }
    var rng_12 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_12.seed_0 = (*s_29).randomSeed_0;
    var _S597 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_8)) >= 0.0010000000474974513f);
    (*s_29).path_0.lightsSampled_0 = _S597;
    if(_S597)
    {
        QueueDirectLighting_0(base_20, si_11, bsdf_8, vec2<f32>(hitConeWidth_5, (*s_29).path_0.coneSpread_0), (*s_29).path_0.throughput_7, false, &(rng_12));
    }
    var u_38 : vec2<f32> = RandomSequence_Next2D_0(&(rng_12));
    var _S598 : f32 = RandomSequence_Next_1(&(rng_12));
    var bs_5 : LobeSample_0 = BSDF_Sample_0(bsdf_8, vec3<f32>(u_38, _S598));
    var weight_11 : vec3<f32> = bs_5.weight_1.diffuse_1 + bs_5.weight_1.specular_1;
    if(!bs_5.valid_1)
    {
        _S591 = true;
    }
    else
    {
        _S591 = ((bs_5.pdf_7) <= 0.0f);
    }
    if(_S591)
    {
        _S591 = true;
    }
    else
    {
        _S591 = (all(((weight_11 <= _S590))));
    }
    if(_S591)
    {
        return;
    }
    var throughput_35 : vec3<f32> = (*s_29).path_0.throughput_7 * weight_11;
    var _S599 : f32 = sqrt(saturate(MaxComponent_0(throughput_35) / max(MaxComponent_0((*s_29).path_0.throughput_7), 9.999999960041972e-13f)));
    if((_S599 < 1.0f))
    {
        var _S600 : f32 = RandomSequence_Next_1(&(rng_12));
        if((_S600 >= _S599))
        {
            return;
        }
        throughput_34 = throughput_35 / vec3<f32>(_S599);
    }
    else
    {
        throughput_34 = throughput_35;
    }
    (*s_29).path_0.throughput_7 = throughput_34;
    (*s_29).path_0.direction_1 = bs_5.wi_26;
    (*s_29).path_0.scatterPdf_0 = bs_5.pdf_7;
    var crossesSurface_5 : bool = ((dot(bs_5.wi_26, si_11.faceNormal_0)) > 0.0f) != (si_11.frontFacing_0);
    (*s_29).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_11, !crossesSurface_5);
    if(crossesSurface_5)
    {
        _S591 = !ms_7.thinWalled_0;
    }
    else
    {
        _S591 = false;
    }
    if(_S591)
    {
        if(si_11.frontFacing_0)
        {
            throughput_34 = HomogeneousVolume_Absorption_0(bsdf_8.volume_0);
        }
        else
        {
            throughput_34 = vec3<f32>(0.0f);
        }
        (*s_29).path_0.absorption_0 = throughput_34;
    }
    (*s_29).path_0.coneWidth_2 = hitConeWidth_5;
    (*s_29).path_0.coneSpread_0 = (*s_29).path_0.coneSpread_0 + ScatterConeSpread_0(bs_5.type_0, ms_7.roughness_4);
    (*s_29).randomSeed_0 = rng_12.seed_0;
    (*s_29).active_0 = u32(1);
    if(_S593)
    {
        var _S601 : u32 = Field_0(base_20, u32(6));
        gAccum_0[_S601][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S601].w))) + u32(1))));
    }
    return;
}

fn StorePath_0( base_21 : u32,  s_30 : WavefrontPath_0)
{
    gAccum_0[base_21] = vec4<f32>(s_30.path_0.radiance_1, (bitcast<f32>((s_30.active_0))));
    gAccum_0[Field_0(base_21, u32(1))] = vec4<f32>(s_30.path_0.throughput_7, (bitcast<f32>((s_30.randomSeed_0))));
    gAccum_0[Field_0(base_21, u32(2))] = vec4<f32>(s_30.path_0.origin_3, s_30.path_0.scatterPdf_0);
    gAccum_0[Field_0(base_21, u32(3))] = vec4<f32>(s_30.path_0.direction_1, (bitcast<f32>((select(u32(0), u32(1), s_30.path_0.lightsSampled_0)))));
    gAccum_0[Field_0(base_21, u32(4))] = vec4<f32>(s_30.path_0.absorption_0, s_30.path_0.coneWidth_2);
    gAccum_0[Field_0(base_21, u32(5))][i32(3)] = s_30.path_0.coneSpread_0;
    return;
}

fn ShadePath_6( base_22 : u32,  s_31 : ptr<function, WavefrontPath_0>,  hit_11 : HitRecord_0,  bounce_8 : u32)
{
    var _S602 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_31).path_0.absorption_0) > _S602)))))
    {
        (*s_31).path_0.throughput_7 = (*s_31).path_0.throughput_7 * exp((*s_31).path_0.absorption_0 * vec3<f32>(- hit_11.t_6));
    }
    var hitConeWidth_6 : f32 = (*s_31).path_0.coneWidth_2 + (*s_31).path_0.coneSpread_0 * hit_11.t_6;
    var si_12 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_31).path_0.direction_1, hit_11, hitConeWidth_6);
    var V_8 : vec3<f32> = (vec3<f32>(0) - (*s_31).path_0.direction_1);
    var ms_8 : MaterialSample_0 = EvalMaterial_0(si_12, V_8);
    var bsdf_9 : BSDF_0 = BSDF_x24init_0(ms_8.inputs_1, V_8, (*s_31).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    (*s_31).albedo_2 = ms_8.albedo_3;
    var throughput_36 : vec3<f32>;
    if(si_12.frontFacing_0)
    {
        throughput_36 = ms_8.inputs_1.basis_1.n_1;
    }
    else
    {
        throughput_36 = (vec3<f32>(0) - ms_8.inputs_1.basis_1.n_1);
    }
    (*s_31).normal_11 = throughput_36;
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        var pixel_5 : vec2<u32> = WorkPixel_0(base_22 - WorkBase_0(u32(0)));
        var output_4 : u32 = (pixel_5.y * gFrame_0.frame_0.x + pixel_5.x) * u32(3);
        gAccum_0[output_4 + u32(1)][i32(3)] = hit_11.t_6;
        gAccum_0[output_4 + u32(2)][i32(3)] = f32(hit_11.instanceIndex_2 + u32(1));
    }
    var _S603 : bool = NrdEnabled_0();
    if(_S603)
    {
        var r_18 : u32 = NrdBase_0(base_22);
        gAccum_0[r_18] = vec4<f32>((*s_31).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
        gAccum_0[r_18 + u32(1)] = vec4<f32>(0.0f);
        gAccum_0[r_18 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_8.roughness_4, ms_8.inputs_1.baseMetalness_0));
    }
    (*s_31).active_0 = u32(0);
    var _S604 : bool;
    if(!si_12.frontFacing_0)
    {
        _S604 = !ms_8.doubleSided_2;
    }
    else
    {
        _S604 = false;
    }
    if(_S604)
    {
        _S604 = ((ms_8.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S604 = false;
    }
    if(_S604)
    {
        return;
    }
    if((any((((bsdf_9.emission_0) > _S602)))))
    {
        (*s_31).path_0.radiance_1 = (*s_31).path_0.radiance_1 + (*s_31).path_0.throughput_7 * bsdf_9.emission_0;
    }
    if(_S603)
    {
        var _S605 : u32 = NrdBase_0(base_22);
        var _S606 : vec3<f32> = (*s_31).path_0.radiance_1;
        gAccum_0[_S605].x = _S606.x;
        gAccum_0[_S605].y = _S606.y;
        gAccum_0[_S605].z = _S606.z;
    }
    if(bounce_8 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S607 : bool = SharcEnabled_0();
    var rng_13 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_13.seed_0 = (*s_31).randomSeed_0;
    var _S608 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_9)) >= 0.0010000000474974513f);
    (*s_31).path_0.lightsSampled_0 = _S608;
    if(_S608)
    {
        QueueDirectLighting_0(base_22, si_12, bsdf_9, vec2<f32>(hitConeWidth_6, (*s_31).path_0.coneSpread_0), (*s_31).path_0.throughput_7, true, &(rng_13));
    }
    var u_39 : vec2<f32> = RandomSequence_Next2D_0(&(rng_13));
    var _S609 : f32 = RandomSequence_Next_1(&(rng_13));
    var bs_6 : LobeSample_0 = BSDF_Sample_0(bsdf_9, vec3<f32>(u_39, _S609));
    var weight_12 : vec3<f32> = bs_6.weight_1.diffuse_1 + bs_6.weight_1.specular_1;
    if(!bs_6.valid_1)
    {
        _S604 = true;
    }
    else
    {
        _S604 = ((bs_6.pdf_7) <= 0.0f);
    }
    if(_S604)
    {
        _S604 = true;
    }
    else
    {
        _S604 = (all(((weight_12 <= _S602))));
    }
    if(_S604)
    {
        return;
    }
    if(_S603)
    {
        var r_19 : u32 = NrdBase_0(base_22);
        var oct_4 : vec2<f32> = NrdOctEncode_0(bs_6.wi_26);
        gAccum_0[r_19][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_6.weight_1)))));
        gAccum_0[r_19 + u32(3)][i32(3)] = oct_4.x;
        gAccum_0[r_19 + u32(4)][i32(3)] = oct_4.y;
    }
    var throughput_37 : vec3<f32> = (*s_31).path_0.throughput_7 * weight_12;
    var continuation_4 : f32;
    if(_S607)
    {
        continuation_4 = 1.0f;
    }
    else
    {
        continuation_4 = sqrt(saturate(MaxComponent_0(throughput_37) / max(MaxComponent_0((*s_31).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_4 < 1.0f))
    {
        var _S610 : f32 = RandomSequence_Next_1(&(rng_13));
        if((_S610 >= continuation_4))
        {
            return;
        }
        throughput_36 = throughput_37 / vec3<f32>(continuation_4);
    }
    else
    {
        throughput_36 = throughput_37;
    }
    (*s_31).path_0.throughput_7 = throughput_36;
    (*s_31).path_0.direction_1 = bs_6.wi_26;
    (*s_31).path_0.scatterPdf_0 = bs_6.pdf_7;
    var crossesSurface_6 : bool = ((dot(bs_6.wi_26, si_12.faceNormal_0)) > 0.0f) != (si_12.frontFacing_0);
    (*s_31).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_12, !crossesSurface_6);
    if(crossesSurface_6)
    {
        _S604 = !ms_8.thinWalled_0;
    }
    else
    {
        _S604 = false;
    }
    if(_S604)
    {
        if(si_12.frontFacing_0)
        {
            throughput_36 = HomogeneousVolume_Absorption_0(bsdf_9.volume_0);
        }
        else
        {
            throughput_36 = vec3<f32>(0.0f);
        }
        (*s_31).path_0.absorption_0 = throughput_36;
    }
    (*s_31).path_0.coneWidth_2 = hitConeWidth_6;
    (*s_31).path_0.coneSpread_0 = (*s_31).path_0.coneSpread_0 + ScatterConeSpread_0(bs_6.type_0, ms_8.roughness_4);
    (*s_31).randomSeed_0 = rng_13.seed_0;
    (*s_31).active_0 = u32(1);
    if(_S607)
    {
        var _S611 : u32 = Field_0(base_22, u32(6));
        gAccum_0[_S611][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S611].w))) + u32(1))));
    }
    return;
}

fn ConstantMaterialOutput_0( header_7 : MaterialHeader_0,  program_3 : u32,  group_0 : u32,  field_1 : u32,  fallback_2 : vec4<f32>) -> vec4<f32>
{
    if(program_3 == u32(4294967295))
    {
        return fallback_2;
    }
    var _S612 : vec4<f32> = fallback_2;
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
        var _S613 : u32 = gMaterialData_0[pc_4].x;
        if(((_S613 & (u32(255)))) == u32(0))
        {
            break;
        }
        var outputGroup_0 : u32 = (_S613 >> (u32(16)));
        if(outputGroup_0 == group_0)
        {
            var operand_1 : u32 = MaterialWord_0(pc_4 * u32(4) + u32(1) + field_1);
            var _S614 : vec4<f32>;
            if(operand_1 != u32(4294967295))
            {
                _S614 = MaterialOperand_0(operand_1, vec4<f32>(0.0f), header_7.constantBase_0);
            }
            else
            {
                _S614 = _S612;
            }
            _S612 = _S614;
        }
        var pc_5 : u32 = pc_4 + ((((u32(351898) >> ((u32(2) * min(outputGroup_0, u32(9)))))) & (u32(3))));
        n_18 = n_18 + u32(1);
        pc_4 = pc_5;
    }
    return _S612;
}

fn ConstantEmissiveRadiance_0( header_8 : MaterialHeader_0) -> vec3<f32>
{
    var defaults_0 : BSDFInputs_0 = BSDFInputs_Default_0();
    var _S615 : bool;
    if((MaterialHeader_AlphaMode_0(header_8)) == u32(1))
    {
        _S615 = ((ConstantMaterialOutput_0(header_8, header_8.opacity_0, u32(9), u32(0), vec4<f32>(defaults_0.geometryOpacity_0)).x) < (header_8.alphaCutoff_0));
    }
    else
    {
        _S615 = false;
    }
    if(_S615)
    {
        return vec3<f32>(0.0f);
    }
    return ConstantMaterialOutput_0(header_8, header_8.emission_1, u32(8), u32(1), vec4<f32>(defaults_0.emissionColor_0, 0.0f)).xyz * vec3<f32>(ConstantMaterialOutput_0(header_8, header_8.emission_1, u32(8), u32(0), vec4<f32>(defaults_0.emissionLuminance_0)).x);
}

fn SampleEmissiveGeometry_0( viewer_3 : vec3<f32>,  rng_14 : ptr<function, RandomSequence_0>,  index_22 : ptr<function, u32>,  bary_5 : ptr<function, vec3<f32>>) -> LightSample_0
{
    var _S616 : f32 = RandomSequence_Next_1(&((*rng_14)));
    (*index_22) = SelectLight_0(_S616);
    (*bary_5) = vec3<f32>(0.0f);
    var _S617 : EmissiveTriangle_std430_0 = gLights_0[(*index_22)];
    var _S618 : u32 = AnalyticFlags_0(&(_S617));
    if(((_S618 & (u32(2147483648)))) != u32(0))
    {
        var _S619 : LightSample_0 = SampleAnalytic_0(&(_S617), viewer_3, &((*rng_14)));
        return _S619;
    }
    var _S620 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_14)));
    var _S621 : vec3<f32> = SampleTriangle_0(_S620);
    (*bary_5) = _S621;
    var s_32 : LightSample_0;
    s_32.delta_0 = false;
    s_32.shadow_0 = true;
    var _S622 : vec4<f32> = _S617.p0_0;
    var _S623 : vec4<f32> = _S617.p1_0;
    s_32.position_1 = _S617.p0_0.xyz * vec3<f32>(_S621.x) + _S617.p1_0.xyz * vec3<f32>(_S621.y) + _S617.p2_0.xyz * vec3<f32>(_S621.z);
    s_32.normal_7 = _S617.n_0.xyz;
    var material_5 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S617.n_0.w))));
    var _S624 : vec3<f32>;
    if((((((material_5.flags_1) >> (u32(26)))) & (u32(31)))) == u32(0))
    {
        _S624 = ConstantEmissiveRadiance_0(material_5);
    }
    else
    {
        _S624 = vec3<f32>(1.0f);
    }
    s_32.radiance_0 = _S624;
    var _S625 : bool = MaterialHeader_DoubleSided_0(material_5);
    s_32.solidAnglePdf_0 = _S623.w * EmissiveSolidAnglePdf_0(_S622.w, _S625, viewer_3, s_32.position_1, s_32.normal_7);
    var _S626 : bool;
    if(_S625)
    {
        _S626 = ((dot(s_32.normal_7, viewer_3 - s_32.position_1)) < 0.0f);
    }
    else
    {
        _S626 = false;
    }
    if(_S626)
    {
        s_32.normal_7 = (vec3<f32>(0) - s_32.normal_7);
    }
    return s_32;
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

fn BucketMetadataBase_0() -> u32
{
    return ShadowQueueBase_0() + (gWavefront_0.capacity_0 + u32(3)) / u32(4);
}

fn LightWorkBase_0( index_23 : u32) -> u32
{
    return BucketMetadataBase_0() + u32(262) + index_23;
}

fn QueueDirectLighting_1( base_23 : u32,  si_13 : SurfaceInteraction_0,  bsdf_10 : BSDF_0,  cone_4 : vec2<f32>,  throughput_38 : vec3<f32>,  primary_2 : bool,  rng_15 : ptr<function, RandomSequence_0>)
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
        var mis_5 : bool;
        var shadow_5 : bool;
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
                mis_5 = ((ls_12.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                mis_5 = false;
            }
            if(!mis_5)
            {
                mask_3 = mask_2;
                source_3 = source_3 + u32(1);
                mask_2 = mask_3;
                continue;
            }
            var dir_23 : vec3<f32> = (vec3<f32>(0) - ls_12.normal_7);
            var _S627 : vec3<f32> = ShadowOrigin_0(si_13, dir_23);
            mis_5 = true;
            ls_11 = ls_12;
            origin_8 = _S627;
            maxDistance_6 = 1.00000001504746622e+30f;
            shadow_5 = true;
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
                var bary_6 : vec3<f32>;
                var ls_13 : LightSample_0 = SampleEmissiveGeometry_0(si_13.position_0, &((*rng_15)), &(lightIndex_0), &(bary_6));
                var _S628 : EmissiveTriangle_std430_0 = gLights_0[lightIndex_0];
                var _S629 : u32 = AnalyticFlags_0(&(_S628));
                if(((_S629 & (u32(2147483648)))) == u32(0))
                {
                    mis_5 = (((((LoadMaterialHeader_0((bitcast<u32>((_S628.n_0.w)))).flags_1) >> (u32(26)))) & (u32(31)))) != u32(0);
                }
                else
                {
                    mis_5 = false;
                }
                if(mis_5)
                {
                    var lightBase_0 : u32 = LightWorkBase_0(base_23 - WorkBase_0(u32(0)));
                    gAccum_0[lightBase_0] = vec4<f32>(bary_6, (bitcast<f32>((lightIndex_0))));
                    gAccum_0[Field_0(lightBase_0, u32(1))] = vec4<f32>(si_13.position_0, ls_13.solidAnglePdf_0);
                    mask_3 = (mask_2 | (u32(8)));
                }
                else
                {
                    mask_3 = mask_2;
                }
                if((any((((ls_13.radiance_0) > vec3<f32>(0.0f))))))
                {
                    shadow_5 = ((ls_13.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    shadow_5 = false;
                }
                if(!shadow_5)
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
                var _S630 : bool = mis_5;
                mis_5 = !ls_13.delta_0;
                ls_11 = ls_13;
                origin_8 = origin_9;
                maxDistance_6 = maxDistance_7;
                shadow_5 = ls_13.shadow_0;
                pendingLight_0 = _S630;
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
                var _S631 : vec3<f32> = ShadowOrigin_0(si_13, dir_26);
                mis_5 = false;
                ls_11 = ls_14;
                origin_8 = _S631;
                maxDistance_6 = 1.00000001504746622e+30f;
                shadow_5 = true;
                pendingLight_0 = false;
                dir_22 = dir_26;
                mask_3 = mask_2;
            }
        }
        var eval_4 : DiffuseSpecular_0;
        var pdf_16 : f32;
        BSDF_EvalPdf_0(bsdf_10, dir_22, &(eval_4), &(pdf_16));
        var f_25 : vec3<f32> = eval_4.diffuse_1 + eval_4.specular_1;
        var mask_4 : u32;
        if((any(((f_25 > vec3<f32>(0.0f))))))
        {
            var weight_13 : f32;
            if(mis_5)
            {
                weight_13 = EvalMISRobust_0(ls_11.solidAnglePdf_0, pdf_16);
            }
            else
            {
                weight_13 = 1.0f;
            }
            var offset_2 : u32 = u32(12) + source_3 * u32(3);
            gAccum_0[Field_0(base_23, offset_2)] = vec4<f32>(origin_8, maxDistance_6);
            gAccum_0[Field_0(base_23, offset_2 + u32(1))] = vec4<f32>(dir_22, (bitcast<f32>((ShadowFlags_0(shadow_5, primary_2, source_3 == u32(2), eval_4)))));
            var _S632 : vec4<f32>;
            if(pendingLight_0)
            {
                _S632 = vec4<f32>(f_25, weight_13);
            }
            else
            {
                _S632 = vec4<f32>(vec3<f32>(weight_13) * ls_11.radiance_0 * f_25 / vec3<f32>(ls_11.solidAnglePdf_0), 0.0f);
            }
            gAccum_0[Field_0(base_23, offset_2 + u32(2))] = _S632;
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
    if(primary_2)
    {
        maxDistance_6 = 0.0f;
    }
    else
    {
        maxDistance_6 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    gAccum_0[Field_0(base_23, u32(10))] = vec4<f32>(throughput_38, maxDistance_6);
    gAccum_0[Field_0(base_23, u32(11))] = vec4<f32>(cone_4, (bitcast<f32>((mask_2))), 0.0f);
    return;
}

fn ShadePath_7( base_24 : u32,  s_33 : ptr<function, WavefrontPath_0>,  hit_12 : HitRecord_0,  bounce_9 : u32)
{
    var _S633 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_33).path_0.absorption_0) > _S633)))))
    {
        (*s_33).path_0.throughput_7 = (*s_33).path_0.throughput_7 * exp((*s_33).path_0.absorption_0 * vec3<f32>(- hit_12.t_6));
    }
    var hitConeWidth_7 : f32 = (*s_33).path_0.coneWidth_2 + (*s_33).path_0.coneSpread_0 * hit_12.t_6;
    var si_14 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_33).path_0.direction_1, hit_12, hitConeWidth_7);
    var V_9 : vec3<f32> = (vec3<f32>(0) - (*s_33).path_0.direction_1);
    var ms_9 : MaterialSample_0 = EvalMaterial_0(si_14, V_9);
    var bsdf_11 : BSDF_0 = BSDF_x24init_0(ms_9.inputs_1, V_9, (*s_33).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S634 : bool = bounce_9 == u32(0);
    var throughput_39 : vec3<f32>;
    if(_S634)
    {
        (*s_33).albedo_2 = ms_9.albedo_3;
        if(si_14.frontFacing_0)
        {
            throughput_39 = ms_9.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_39 = (vec3<f32>(0) - ms_9.inputs_1.basis_1.n_1);
        }
        (*s_33).normal_11 = throughput_39;
        if((gFrame_0.temporal_0.z) != 0.0f)
        {
            var pixel_6 : vec2<u32> = WorkPixel_0(base_24 - WorkBase_0(u32(0)));
            var output_5 : u32 = (pixel_6.y * gFrame_0.frame_0.x + pixel_6.x) * u32(3);
            gAccum_0[output_5 + u32(1)][i32(3)] = hit_12.t_6;
            gAccum_0[output_5 + u32(2)][i32(3)] = f32(hit_12.instanceIndex_2 + u32(1));
        }
        if(NrdEnabled_0())
        {
            var r_20 : u32 = NrdBase_0(base_24);
            gAccum_0[r_20] = vec4<f32>((*s_33).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
            gAccum_0[r_20 + u32(1)] = vec4<f32>(0.0f);
            gAccum_0[r_20 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_9.roughness_4, ms_9.inputs_1.baseMetalness_0));
        }
    }
    (*s_33).active_0 = u32(0);
    var _S635 : bool;
    if(!si_14.frontFacing_0)
    {
        _S635 = !ms_9.doubleSided_2;
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        _S635 = ((ms_9.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        return;
    }
    var continuation_5 : f32;
    if((any((((bsdf_11.emission_0) > _S633)))))
    {
        var _S636 : bool = !_S634;
        if(_S636)
        {
            _S635 = (*s_33).path_0.lightsSampled_0;
        }
        else
        {
            _S635 = false;
        }
        if(_S635)
        {
            continuation_5 = EvalMISRobust_0((*s_33).path_0.scatterPdf_0, EmissiveHitPdf_0(si_14.instanceIndex_0, si_14.primitiveIndex_0, (*s_33).path_0.origin_3, si_14.position_0));
        }
        else
        {
            continuation_5 = 1.0f;
        }
        var contribution_5 : vec3<f32> = (*s_33).path_0.throughput_7 * vec3<f32>(continuation_5) * bsdf_11.emission_0;
        var clampValue_7 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_7 > 0.0f))
        {
            _S635 = _S636;
        }
        else
        {
            _S635 = false;
        }
        if(_S635)
        {
            throughput_39 = min(contribution_5, vec3<f32>(clampValue_7));
        }
        else
        {
            throughput_39 = contribution_5;
        }
        (*s_33).path_0.radiance_1 = (*s_33).path_0.radiance_1 + throughput_39;
    }
    if(_S634)
    {
        _S635 = NrdEnabled_0();
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        var _S637 : u32 = NrdBase_0(base_24);
        var _S638 : vec3<f32> = (*s_33).path_0.radiance_1;
        gAccum_0[_S637].x = _S638.x;
        gAccum_0[_S637].y = _S638.y;
        gAccum_0[_S637].z = _S638.z;
    }
    if(bounce_9 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S639 : bool = SharcEnabled_0();
    if(_S639)
    {
        _S635 = !_S634;
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        _S635 = SharcSurface_0(ms_9);
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        var key_9 : SharcKey_0;
        var voxelSize_5 : f32;
        if(si_14.frontFacing_0)
        {
            throughput_39 = si_14.faceNormal_0;
        }
        else
        {
            throughput_39 = (vec3<f32>(0) - si_14.faceNormal_0);
        }
        var index_24 : u32 = base_24 - WorkBase_0(u32(0));
        var _S640 : bool = SharcMakeKey_0(si_14.position_0, throughput_39, V_9, si_14.materialIndex_1, si_14.instanceIndex_0, &(key_9), &(voxelSize_5));
        if(_S640)
        {
            if(SharcUpdatePath_0(index_24, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_24, bounce_9, key_9, (*s_33).path_0.radiance_1, (*s_33).path_0.throughput_7);
            }
            else
            {
                if(((hit_12.t_6) > (voxelSize_5 * sqrt(3.0f))))
                {
                    _S635 = (hitConeWidth_7 > voxelSize_5);
                }
                else
                {
                    _S635 = false;
                }
                if(_S635)
                {
                    _S635 = (((*s_33).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S635 = false;
                }
                if(_S635)
                {
                    var _S641 : u32 = Field_0(base_24, u32(6));
                    var state_5 : u32 = (bitcast<u32>((gAccum_0[_S641].w))) + u32(65536);
                    var cached_5 : vec3<f32>;
                    var found_13 : bool = SharcQuery_0(key_9, &(cached_5));
                    var _S642 : u32;
                    if(found_13)
                    {
                        _S642 = u32(256);
                    }
                    else
                    {
                        _S642 = u32(0);
                    }
                    gAccum_0[_S641][i32(3)] = (bitcast<f32>(((state_5 | (_S642)))));
                    if(found_13)
                    {
                        (*s_33).path_0.radiance_1 = (*s_33).path_0.radiance_1 + (*s_33).path_0.throughput_7 * cached_5;
                        return;
                    }
                }
            }
        }
    }
    var rng_16 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_16.seed_0 = (*s_33).randomSeed_0;
    var _S643 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_11)) >= 0.0010000000474974513f);
    (*s_33).path_0.lightsSampled_0 = _S643;
    if(_S643)
    {
        QueueDirectLighting_1(base_24, si_14, bsdf_11, vec2<f32>(hitConeWidth_7, (*s_33).path_0.coneSpread_0), (*s_33).path_0.throughput_7, _S634, &(rng_16));
    }
    var u_40 : vec2<f32> = RandomSequence_Next2D_0(&(rng_16));
    var _S644 : f32 = RandomSequence_Next_1(&(rng_16));
    var bs_7 : LobeSample_0 = BSDF_Sample_0(bsdf_11, vec3<f32>(u_40, _S644));
    var weight_14 : vec3<f32> = bs_7.weight_1.diffuse_1 + bs_7.weight_1.specular_1;
    if(!bs_7.valid_1)
    {
        _S635 = true;
    }
    else
    {
        _S635 = ((bs_7.pdf_7) <= 0.0f);
    }
    if(_S635)
    {
        _S635 = true;
    }
    else
    {
        _S635 = (all(((weight_14 <= _S633))));
    }
    if(_S635)
    {
        return;
    }
    if(_S634)
    {
        _S635 = NrdEnabled_0();
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        var r_21 : u32 = NrdBase_0(base_24);
        var oct_5 : vec2<f32> = NrdOctEncode_0(bs_7.wi_26);
        gAccum_0[r_21][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_7.weight_1)))));
        gAccum_0[r_21 + u32(3)][i32(3)] = oct_5.x;
        gAccum_0[r_21 + u32(4)][i32(3)] = oct_5.y;
    }
    var throughput_40 : vec3<f32> = (*s_33).path_0.throughput_7 * weight_14;
    if(_S639)
    {
        _S635 = _S634;
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        continuation_5 = 1.0f;
    }
    else
    {
        continuation_5 = sqrt(saturate(MaxComponent_0(throughput_40) / max(MaxComponent_0((*s_33).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_5 < 1.0f))
    {
        var _S645 : f32 = RandomSequence_Next_1(&(rng_16));
        if((_S645 >= continuation_5))
        {
            return;
        }
        throughput_39 = throughput_40 / vec3<f32>(continuation_5);
    }
    else
    {
        throughput_39 = throughput_40;
    }
    (*s_33).path_0.throughput_7 = throughput_39;
    (*s_33).path_0.direction_1 = bs_7.wi_26;
    (*s_33).path_0.scatterPdf_0 = bs_7.pdf_7;
    var crossesSurface_7 : bool = ((dot(bs_7.wi_26, si_14.faceNormal_0)) > 0.0f) != (si_14.frontFacing_0);
    (*s_33).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_14, !crossesSurface_7);
    if(crossesSurface_7)
    {
        _S635 = !ms_9.thinWalled_0;
    }
    else
    {
        _S635 = false;
    }
    if(_S635)
    {
        if(si_14.frontFacing_0)
        {
            throughput_39 = HomogeneousVolume_Absorption_0(bsdf_11.volume_0);
        }
        else
        {
            throughput_39 = vec3<f32>(0.0f);
        }
        (*s_33).path_0.absorption_0 = throughput_39;
    }
    (*s_33).path_0.coneWidth_2 = hitConeWidth_7;
    (*s_33).path_0.coneSpread_0 = (*s_33).path_0.coneSpread_0 + ScatterConeSpread_0(bs_7.type_0, ms_9.roughness_4);
    (*s_33).randomSeed_0 = rng_16.seed_0;
    (*s_33).active_0 = u32(1);
    if(_S639)
    {
        var _S646 : u32 = Field_0(base_24, u32(6));
        gAccum_0[_S646][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S646].w))) + u32(1))));
    }
    return;
}

fn ShadePath_8( base_25 : u32,  s_34 : ptr<function, WavefrontPath_0>,  hit_13 : HitRecord_0,  bounce_10 : u32)
{
    var _S647 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_34).path_0.absorption_0) > _S647)))))
    {
        (*s_34).path_0.throughput_7 = (*s_34).path_0.throughput_7 * exp((*s_34).path_0.absorption_0 * vec3<f32>(- hit_13.t_6));
    }
    var hitConeWidth_8 : f32 = (*s_34).path_0.coneWidth_2 + (*s_34).path_0.coneSpread_0 * hit_13.t_6;
    var si_15 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_34).path_0.direction_1, hit_13, hitConeWidth_8);
    var V_10 : vec3<f32> = (vec3<f32>(0) - (*s_34).path_0.direction_1);
    var ms_10 : MaterialSample_0 = EvalMaterial_0(si_15, V_10);
    var bsdf_12 : BSDF_0 = BSDF_x24init_0(ms_10.inputs_1, V_10, (*s_34).path_0.throughput_7, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var _S648 : bool = bounce_10 == u32(0);
    var throughput_41 : vec3<f32>;
    if(_S648)
    {
        (*s_34).albedo_2 = ms_10.albedo_3;
        if(si_15.frontFacing_0)
        {
            throughput_41 = ms_10.inputs_1.basis_1.n_1;
        }
        else
        {
            throughput_41 = (vec3<f32>(0) - ms_10.inputs_1.basis_1.n_1);
        }
        (*s_34).normal_11 = throughput_41;
        if((gFrame_0.temporal_0.z) != 0.0f)
        {
            var pixel_7 : vec2<u32> = WorkPixel_0(base_25 - WorkBase_0(u32(0)));
            var output_6 : u32 = (pixel_7.y * gFrame_0.frame_0.x + pixel_7.x) * u32(3);
            gAccum_0[output_6 + u32(1)][i32(3)] = hit_13.t_6;
            gAccum_0[output_6 + u32(2)][i32(3)] = f32(hit_13.instanceIndex_2 + u32(1));
        }
        if(NrdEnabled_0())
        {
            var r_22 : u32 = NrdBase_0(base_25);
            gAccum_0[r_22] = vec4<f32>((*s_34).path_0.radiance_1, (bitcast<f32>((NrdPackFraction_0(vec3<f32>(0.5f))))));
            gAccum_0[r_22 + u32(1)] = vec4<f32>(0.0f);
            gAccum_0[r_22 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, NrdPackSurface_0(ms_10.roughness_4, ms_10.inputs_1.baseMetalness_0));
        }
    }
    (*s_34).active_0 = u32(0);
    var _S649 : bool;
    if(!si_15.frontFacing_0)
    {
        _S649 = !ms_10.doubleSided_2;
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        _S649 = ((ms_10.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        return;
    }
    var continuation_6 : f32;
    if((any((((bsdf_12.emission_0) > _S647)))))
    {
        var _S650 : bool = !_S648;
        if(_S650)
        {
            _S649 = (*s_34).path_0.lightsSampled_0;
        }
        else
        {
            _S649 = false;
        }
        if(_S649)
        {
            continuation_6 = EvalMISRobust_0((*s_34).path_0.scatterPdf_0, EmissiveHitPdf_0(si_15.instanceIndex_0, si_15.primitiveIndex_0, (*s_34).path_0.origin_3, si_15.position_0));
        }
        else
        {
            continuation_6 = 1.0f;
        }
        var contribution_6 : vec3<f32> = (*s_34).path_0.throughput_7 * vec3<f32>(continuation_6) * bsdf_12.emission_0;
        var clampValue_8 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_8 > 0.0f))
        {
            _S649 = _S650;
        }
        else
        {
            _S649 = false;
        }
        if(_S649)
        {
            throughput_41 = min(contribution_6, vec3<f32>(clampValue_8));
        }
        else
        {
            throughput_41 = contribution_6;
        }
        (*s_34).path_0.radiance_1 = (*s_34).path_0.radiance_1 + throughput_41;
    }
    if(_S648)
    {
        _S649 = NrdEnabled_0();
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        var _S651 : u32 = NrdBase_0(base_25);
        var _S652 : vec3<f32> = (*s_34).path_0.radiance_1;
        gAccum_0[_S651].x = _S652.x;
        gAccum_0[_S651].y = _S652.y;
        gAccum_0[_S651].z = _S652.z;
    }
    if(bounce_10 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var _S653 : bool = SharcEnabled_0();
    if(_S653)
    {
        _S649 = !_S648;
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        _S649 = SharcSurface_0(ms_10);
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        var key_10 : SharcKey_0;
        var voxelSize_6 : f32;
        if(si_15.frontFacing_0)
        {
            throughput_41 = si_15.faceNormal_0;
        }
        else
        {
            throughput_41 = (vec3<f32>(0) - si_15.faceNormal_0);
        }
        var index_25 : u32 = base_25 - WorkBase_0(u32(0));
        var _S654 : bool = SharcMakeKey_0(si_15.position_0, throughput_41, V_10, si_15.materialIndex_1, si_15.instanceIndex_0, &(key_10), &(voxelSize_6));
        if(_S654)
        {
            if(SharcUpdatePath_0(index_25, gWavefront_0.tileStart_0))
            {
                SharcRecord_0(index_25, bounce_10, key_10, (*s_34).path_0.radiance_1, (*s_34).path_0.throughput_7);
            }
            else
            {
                if(((hit_13.t_6) > (voxelSize_6 * sqrt(3.0f))))
                {
                    _S649 = (hitConeWidth_8 > voxelSize_6);
                }
                else
                {
                    _S649 = false;
                }
                if(_S649)
                {
                    _S649 = (((*s_34).path_0.coneSpread_0) >= 0.05000000074505806f);
                }
                else
                {
                    _S649 = false;
                }
                if(_S649)
                {
                    var _S655 : u32 = Field_0(base_25, u32(6));
                    var state_6 : u32 = (bitcast<u32>((gAccum_0[_S655].w))) + u32(65536);
                    var cached_6 : vec3<f32>;
                    var found_14 : bool = SharcQuery_0(key_10, &(cached_6));
                    var _S656 : u32;
                    if(found_14)
                    {
                        _S656 = u32(256);
                    }
                    else
                    {
                        _S656 = u32(0);
                    }
                    gAccum_0[_S655][i32(3)] = (bitcast<f32>(((state_6 | (_S656)))));
                    if(found_14)
                    {
                        (*s_34).path_0.radiance_1 = (*s_34).path_0.radiance_1 + (*s_34).path_0.throughput_7 * cached_6;
                        return;
                    }
                }
            }
        }
    }
    var rng_17 : RandomSequence_0 = RandomSequence_x24init_0(u32(0), u32(0));
    rng_17.seed_0 = (*s_34).randomSeed_0;
    var _S657 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_12)) >= 0.0010000000474974513f);
    (*s_34).path_0.lightsSampled_0 = _S657;
    if(_S657)
    {
        QueueDirectLighting_0(base_25, si_15, bsdf_12, vec2<f32>(hitConeWidth_8, (*s_34).path_0.coneSpread_0), (*s_34).path_0.throughput_7, _S648, &(rng_17));
    }
    var u_41 : vec2<f32> = RandomSequence_Next2D_0(&(rng_17));
    var _S658 : f32 = RandomSequence_Next_1(&(rng_17));
    var bs_8 : LobeSample_0 = BSDF_Sample_0(bsdf_12, vec3<f32>(u_41, _S658));
    var weight_15 : vec3<f32> = bs_8.weight_1.diffuse_1 + bs_8.weight_1.specular_1;
    if(!bs_8.valid_1)
    {
        _S649 = true;
    }
    else
    {
        _S649 = ((bs_8.pdf_7) <= 0.0f);
    }
    if(_S649)
    {
        _S649 = true;
    }
    else
    {
        _S649 = (all(((weight_15 <= _S647))));
    }
    if(_S649)
    {
        return;
    }
    if(_S648)
    {
        _S649 = NrdEnabled_0();
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        var r_23 : u32 = NrdBase_0(base_25);
        var oct_6 : vec2<f32> = NrdOctEncode_0(bs_8.wi_26);
        gAccum_0[r_23][i32(3)] = (bitcast<f32>((NrdPackFraction_0(NrdDiffuseFraction_0(bs_8.weight_1)))));
        gAccum_0[r_23 + u32(3)][i32(3)] = oct_6.x;
        gAccum_0[r_23 + u32(4)][i32(3)] = oct_6.y;
    }
    var throughput_42 : vec3<f32> = (*s_34).path_0.throughput_7 * weight_15;
    if(_S653)
    {
        _S649 = _S648;
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        continuation_6 = 1.0f;
    }
    else
    {
        continuation_6 = sqrt(saturate(MaxComponent_0(throughput_42) / max(MaxComponent_0((*s_34).path_0.throughput_7), 9.999999960041972e-13f)));
    }
    if((continuation_6 < 1.0f))
    {
        var _S659 : f32 = RandomSequence_Next_1(&(rng_17));
        if((_S659 >= continuation_6))
        {
            return;
        }
        throughput_41 = throughput_42 / vec3<f32>(continuation_6);
    }
    else
    {
        throughput_41 = throughput_42;
    }
    (*s_34).path_0.throughput_7 = throughput_41;
    (*s_34).path_0.direction_1 = bs_8.wi_26;
    (*s_34).path_0.scatterPdf_0 = bs_8.pdf_7;
    var crossesSurface_8 : bool = ((dot(bs_8.wi_26, si_15.faceNormal_0)) > 0.0f) != (si_15.frontFacing_0);
    (*s_34).path_0.origin_3 = SurfaceInteraction_ComputeRayOrigin_0(si_15, !crossesSurface_8);
    if(crossesSurface_8)
    {
        _S649 = !ms_10.thinWalled_0;
    }
    else
    {
        _S649 = false;
    }
    if(_S649)
    {
        if(si_15.frontFacing_0)
        {
            throughput_41 = HomogeneousVolume_Absorption_0(bsdf_12.volume_0);
        }
        else
        {
            throughput_41 = vec3<f32>(0.0f);
        }
        (*s_34).path_0.absorption_0 = throughput_41;
    }
    (*s_34).path_0.coneWidth_2 = hitConeWidth_8;
    (*s_34).path_0.coneSpread_0 = (*s_34).path_0.coneSpread_0 + ScatterConeSpread_0(bs_8.type_0, ms_10.roughness_4);
    (*s_34).randomSeed_0 = rng_17.seed_0;
    (*s_34).active_0 = u32(1);
    if(_S653)
    {
        var _S660 : u32 = Field_0(base_25, u32(6));
        gAccum_0[_S660][i32(3)] = (bitcast<f32>(((bitcast<u32>((gAccum_0[_S660].w))) + u32(1))));
    }
    return;
}

fn TraceScene_2( ray_4 : Ray_0,  anyHit_2 : bool,  hit_14 : ptr<function, HitRecord_0>) -> bool
{
    var found_15 : bool;
    (*hit_14).t_6 = ray_4.tMax_0;
    (*hit_14).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_14).instanceIndex_2 = u32(4294967295);
    (*hit_14).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S661 : u32 = gFrame_0.counts_0.z;
    var _S662 : vec3<f32> = SafeRcp_0(ray_4.direction_0);
    var stack_6 : array<u32, i32(32)>;
    var nodeRef_4 : u32 = u32(0);
    var found_16 : bool = false;
    var stackPtr_16 : u32 = u32(0);
    loop
    {
        var i_11 : u32;
        if(((nodeRef_4 & (u32(2147483648)))) != u32(0))
        {
            var _S663 : u32 = (((nodeRef_4 >> (u32(24)))) & (u32(127)));
            var _S664 : u32 = (nodeRef_4 & (u32(16777215)));
            found_15 = found_16;
            i_11 = u32(0);
            loop
            {
                if((i_11 < _S663))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_5 : u32 = gIndices_0[_S661 + _S664 + i_11];
                var _S665 : bool = TraverseBLAS_0(instanceIndex_5, instanceIndex_5, InverseTransformPoint_0(instanceIndex_5, ray_4.origin_0), InverseTransformVector_0(instanceIndex_5, ray_4.direction_0), ray_4.tMin_0, anyHit_2, &((*hit_14)));
                if(_S665)
                {
                    if(anyHit_2)
                    {
                        return true;
                    }
                    found_15 = true;
                }
                i_11 = i_11 + u32(1);
            }
            if(stackPtr_16 == u32(0))
            {
                break;
            }
            var stackPtr_17 : u32 = stackPtr_16 - u32(1);
            nodeRef_4 = stack_6[stackPtr_17];
            found_16 = found_15;
            stackPtr_16 = stackPtr_17;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_4 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_4];
        var dist1_8 : f32 = IntersectBox_0(node_4.lmin_0, node_4.lmax_0, ray_4.origin_0, _S662, ray_4.tMin_0, (*hit_14).t_6);
        var dist2_8 : f32 = IntersectBox_0(node_4.rmin_0, node_4.rmax_0, ray_4.origin_0, _S662, ray_4.tMin_0, (*hit_14).t_6);
        var far_4 : u32;
        var dist1_9 : f32;
        var dist2_9 : f32;
        if((dist1_8 > dist2_8))
        {
            dist1_9 = dist2_8;
            i_11 = node_4.right_0;
            dist2_9 = dist1_8;
            far_4 = node_4.left_0;
        }
        else
        {
            dist1_9 = dist1_8;
            i_11 = node_4.left_0;
            dist2_9 = dist2_8;
            far_4 = node_4.right_0;
        }
        if(dist1_9 == 1.00000001504746622e+30f)
        {
            if(stackPtr_16 == u32(0))
            {
                found_15 = found_16;
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
                found_15 = (stackPtr_16 < u32(32));
            }
            else
            {
                found_15 = false;
            }
            var stackPtr_19 : u32;
            if(found_15)
            {
                var _S666 : u32 = stackPtr_16 + u32(1);
                stack_6[stackPtr_16] = far_4;
                stackPtr_19 = _S666;
            }
            else
            {
                stackPtr_19 = stackPtr_16;
            }
            nodeRef_4 = i_11;
            stackPtr_16 = stackPtr_19;
        }
    }
    return found_15;
}

fn TraceClosest_0( ray_5 : Ray_0) -> HitRecord_0
{
    var hit_15 : HitRecord_0;
    var _S667 : bool = TraceScene_2(ray_5, false, &(hit_15));
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

fn IntersectAnalyticLights_0( origin_10 : vec3<f32>,  dir_27 : vec3<f32>,  tMax_4 : f32,  cameraRay_0 : bool,  radiance_4 : ptr<function, vec3<f32>>,  pdf_17 : ptr<function, f32>) -> bool
{
    (*radiance_4) = vec3<f32>(0.0f);
    (*pdf_17) = 0.0f;
    var nearest_0 : f32 = tMax_4;
    var found_17 : bool = false;
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
        var _S668 : EmissiveTriangle_std430_0 = gLights_0[i_12];
        var _S669 : u32 = AnalyticFlags_0(&(_S668));
        var _S670 : bool;
        if(cameraRay_0)
        {
            _S670 = ((_S669 & (u32(256)))) != u32(0);
        }
        else
        {
            _S670 = false;
        }
        if(_S670)
        {
            i_12 = i_12 + u32(1);
            continue;
        }
        var nearest_1 : f32;
        var _S671 : bool;
        var inside_4 : bool;
        if(((_S669 & (u32(255)))) == u32(2))
        {
            var n_19 : vec3<f32> = _S668.p2_0.xyz;
            var cosTheta_14 : f32 = - dot(n_19, dir_27);
            if((cosTheta_14 <= 9.99999997475242708e-07f))
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var _S672 : vec4<f32> = _S668.p0_0;
            var _S673 : vec3<f32> = _S668.p0_0.xyz;
            var t_14 : f32 = dot(_S673 - origin_10, n_19) / - cosTheta_14;
            if((t_14 <= 0.0f))
            {
                _S671 = true;
            }
            else
            {
                _S671 = (t_14 >= nearest_0);
            }
            if(_S671)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var local_3 : vec3<f32> = origin_10 + dir_27 * vec3<f32>(t_14) - _S673;
            var _S674 : vec3<f32> = _S668.n_0.xyz;
            var _S675 : vec3<f32> = _S668.uvA_0.xyz;
            var d_12 : vec2<f32> = vec2<f32>(dot(local_3, _S674) / dot(_S674, _S674), dot(local_3, _S675) / dot(_S675, _S675));
            if(((_S669 & (u32(512)))) != u32(0))
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
            (*radiance_4) = _S668.p1_0.xyz;
            (*pdf_17) = _S668.p1_0.w * t_14 * t_14 / (cosTheta_14 * _S672.w);
            nearest_1 = t_14;
        }
        else
        {
            var _S676 : vec4<f32> = _S668.p0_0;
            var radius_4 : f32 = _S668.p0_0.w;
            if((radius_4 <= 0.0f))
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var toCenter_1 : vec3<f32> = _S676.xyz - origin_10;
            var distSq_4 : f32 = dot(toCenter_1, toCenter_1);
            var tc_9 : f32 = dot(toCenter_1, dir_27);
            var _S677 : f32 = radius_4 * radius_4;
            var h_16 : f32 = _S677 - (distSq_4 - tc_9 * tc_9);
            if((h_16 < 0.0f))
            {
                _S671 = true;
            }
            else
            {
                _S671 = (distSq_4 <= _S677);
            }
            if(_S671)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var t_15 : f32 = tc_9 - sqrt(h_16);
            if((t_15 <= 0.0f))
            {
                inside_4 = true;
            }
            else
            {
                inside_4 = (t_15 >= nearest_0);
            }
            if(inside_4)
            {
                i_12 = i_12 + u32(1);
                continue;
            }
            var _S678 : vec4<f32> = _S668.p1_0;
            var _S679 : vec3<f32> = _S668.p1_0.xyz;
            var _S680 : f32 = SpotAttenuation_0(&(_S668), (vec3<f32>(0) - toCenter_1) * vec3<f32>(rsqrt_0(distSq_4)));
            (*radiance_4) = _S679 * vec3<f32>(_S680);
            (*pdf_17) = _S678.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_4, distSq_4));
            nearest_1 = t_15;
        }
        nearest_0 = nearest_1;
        found_17 = true;
        i_12 = i_12 + u32(1);
    }
    return found_17;
}

fn HitsSun_0( dir_28 : vec3<f32>) -> bool
{
    var _S681 : bool;
    if(SunEnabled_0())
    {
        _S681 = ((dot(dir_28, gFrame_0.sunDirection_0.xyz)) >= (gFrame_0.sunDirection_0.w));
    }
    else
    {
        _S681 = false;
    }
    return _S681;
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
    var _S682 : f32 = f32(W_1);
    var _S683 : u32 = min(u32(uv_4.x * _S682), W_1 - u32(1));
    var _S684 : f32 = f32(H_1);
    var _S685 : u32 = min(u32(uv_4.y * _S684), H_1 - u32(1));
    var _S686 : f32 = local_4.y;
    var PI_6 : f32 = float_getPi_0();
    return (EnvCdf_0(_S683 + u32(1), _S685) - EnvCdf_0(_S683, _S685)) * _S682 * ((EnvCdf_0(_S685 + u32(1), H_1) - EnvCdf_0(_S685, H_1)) * _S684) / (2.0f * PI_6 * PI_6 * sqrt(clamp(1.0f - _S686 * _S686, 9.99999997475242708e-07f, 1.0f)));
}

fn CompleteIntersection_0( s_35 : ptr<function, WavefrontPath_0>,  bounce_11 : u32,  hit_16 : HitRecord_0) -> HitRecord_0
{
    var ray_6 : Ray_0 = Ray_x24init_0((*s_35).path_0.origin_3, (*s_35).path_0.direction_1, 1.00000001504746622e+30f);
    var clampValue_9 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var mis_6 : f32;
    var _S687 : bool;
    var contribution_7 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_5 : vec3<f32>;
        var pdf_18 : f32;
        if(HitRecord_IsHit_0(hit_16))
        {
            mis_6 = hit_16.t_6;
        }
        else
        {
            mis_6 = 1.00000001504746622e+30f;
        }
        var _S688 : bool = IntersectAnalyticLights_0(ray_6.origin_0, ray_6.direction_0, mis_6, bounce_11 == u32(0), &(radiance_5), &(pdf_18));
        if(_S688)
        {
            var _S689 : bool = (bounce_11 > u32(0));
            if(_S689)
            {
                _S687 = (*s_35).path_0.lightsSampled_0;
            }
            else
            {
                _S687 = false;
            }
            if(_S687)
            {
                mis_6 = EvalMISRobust_0((*s_35).path_0.scatterPdf_0, pdf_18);
            }
            else
            {
                mis_6 = 1.0f;
            }
            var contribution_8 : vec3<f32> = (*s_35).path_0.throughput_7 * vec3<f32>(mis_6) * radiance_5;
            if((clampValue_9 > 0.0f))
            {
                _S687 = _S689;
            }
            else
            {
                _S687 = false;
            }
            if(_S687)
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
        if(bounce_11 == u32(0))
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
                _S687 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S687 = false;
            }
            if(_S687)
            {
                (*s_35).path_0.radiance_1 = (*s_35).path_0.radiance_1 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if((*s_35).path_0.lightsSampled_0)
            {
                mis_6 = EvalMISRobust_0((*s_35).path_0.scatterPdf_0, EnvironmentPdf_0(ray_6.direction_0));
            }
            else
            {
                mis_6 = 1.0f;
            }
            var contribution_9 : vec3<f32> = (*s_35).path_0.throughput_7 * vec3<f32>(mis_6) * EvalEnvironment_0(ray_6.direction_0);
            if(!(*s_35).path_0.lightsSampled_0)
            {
                _S687 = SunEnabled_0();
            }
            else
            {
                _S687 = false;
            }
            if(_S687)
            {
                _S687 = HitsSun_0(ray_6.direction_0);
            }
            else
            {
                _S687 = false;
            }
            if(_S687)
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

fn IntersectPath_0( s_36 : ptr<function, WavefrontPath_0>,  bounce_12 : u32) -> HitRecord_0
{
    gRayCone_0 = vec2<f32>((*s_36).path_0.coneWidth_2, (*s_36).path_0.coneSpread_0);
    var _S690 : HitRecord_0 = TraceClosest_0(Ray_x24init_0((*s_36).path_0.origin_3, (*s_36).path_0.direction_1, 1.00000001504746622e+30f));
    var _S691 : HitRecord_0 = CompleteIntersection_0(&((*s_36)), bounce_12, _S690);
    return _S691;
}

fn TraverseBLAS_2( _S692 : u32,  _S693 : u32,  _S694 : vec3<f32>,  _S695 : vec3<f32>,  _S696 : f32,  _S697 : bool,  _S698 : ptr<function, HitRecord_0>) -> bool
{
    var found_18 : bool;
    var _S699 : vec3<f32> = SafeRcp_0(_S695);
    var _S700 : bool = (((gInstances_0[_S693].flags_0) & (u32(1)))) != u32(0);
    var stack_7 : array<u32, i32(48)>;
    var nodeRef_5 : u32 = u32(0);
    var found_19 : bool = false;
    var stackPtr_20 : u32 = u32(0);
    loop
    {
        var i_13 : u32;
        if(((nodeRef_5 & (u32(2147483648)))) != u32(0))
        {
            var _S701 : u32 = (((nodeRef_5 >> (u32(24)))) & (u32(127)));
            var _S702 : u32 = (nodeRef_5 & (u32(16777215)));
            found_18 = found_19;
            i_13 = u32(0);
            loop
            {
                if((i_13 < _S701))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_26 : u32 = (gInstances_0[_S693].blasTriOffset_0 + _S702 + i_13) * u32(3);
                var v0_4 : vec4<f32> = gTris_0[base_26];
                var t_16 : f32;
                var bary_7 : vec2<f32>;
                var _S703 : bool = IntersectTriangle_0(_S694, _S695, v0_4.xyz, gTris_0[base_26 + u32(1)].xyz, gTris_0[base_26 + u32(2)].xyz, _S696, (*_S698).t_6, &(t_16), &(bary_7));
                if(!_S703)
                {
                    i_13 = i_13 + u32(1);
                    continue;
                }
                var primitiveIndex_4 : u32 = (bitcast<u32>((v0_4.w)));
                var _S704 : bool;
                if(_S700)
                {
                    var _S705 : bool = AlphaTestRejects_0(_S693, primitiveIndex_4, bary_7, t_16);
                    _S704 = _S705;
                }
                else
                {
                    _S704 = false;
                }
                if(_S704)
                {
                    i_13 = i_13 + u32(1);
                    continue;
                }
                (*_S698).t_6 = t_16;
                (*_S698).barycentrics_0 = bary_7;
                (*_S698).instanceIndex_2 = _S692;
                (*_S698).primitiveIndex_1 = primitiveIndex_4;
                if(_S697)
                {
                    return true;
                }
                found_18 = true;
                i_13 = i_13 + u32(1);
            }
            if(stackPtr_20 == u32(0))
            {
                break;
            }
            var stackPtr_21 : u32 = stackPtr_20 - u32(1);
            nodeRef_5 = stack_7[stackPtr_21];
            found_19 = found_18;
            stackPtr_20 = stackPtr_21;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_5 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S693].blasNodeOffset_0 + nodeRef_5];
        var dist1_10 : f32 = IntersectBox_0(node_5.lmin_0, node_5.lmax_0, _S694, _S699, _S696, (*_S698).t_6);
        var dist2_10 : f32 = IntersectBox_0(node_5.rmin_0, node_5.rmax_0, _S694, _S699, _S696, (*_S698).t_6);
        var far_5 : u32;
        var dist1_11 : f32;
        var dist2_11 : f32;
        if((dist1_10 > dist2_10))
        {
            dist1_11 = dist2_10;
            i_13 = node_5.right_0;
            dist2_11 = dist1_10;
            far_5 = node_5.left_0;
        }
        else
        {
            dist1_11 = dist1_10;
            i_13 = node_5.left_0;
            dist2_11 = dist2_10;
            far_5 = node_5.right_0;
        }
        if(dist1_11 == 1.00000001504746622e+30f)
        {
            if(stackPtr_20 == u32(0))
            {
                found_18 = found_19;
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
                found_18 = (stackPtr_20 < u32(48));
            }
            else
            {
                found_18 = false;
            }
            var stackPtr_23 : u32;
            if(found_18)
            {
                var _S706 : u32 = stackPtr_20 + u32(1);
                stack_7[stackPtr_20] = far_5;
                stackPtr_23 = _S706;
            }
            else
            {
                stackPtr_23 = stackPtr_20;
            }
            nodeRef_5 = i_13;
            stackPtr_20 = stackPtr_23;
        }
    }
    return found_18;
}

fn TraceScene_3( ray_7 : Ray_0,  anyHit_3 : bool,  hit_17 : ptr<function, HitRecord_0>) -> bool
{
    var found_20 : bool;
    (*hit_17).t_6 = ray_7.tMax_0;
    (*hit_17).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_17).instanceIndex_2 = u32(4294967295);
    (*hit_17).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S707 : u32 = gFrame_0.counts_0.z;
    var _S708 : vec3<f32> = SafeRcp_0(ray_7.direction_0);
    var stack_8 : array<u32, i32(32)>;
    var nodeRef_6 : u32 = u32(0);
    var found_21 : bool = false;
    var stackPtr_24 : u32 = u32(0);
    loop
    {
        var i_14 : u32;
        if(((nodeRef_6 & (u32(2147483648)))) != u32(0))
        {
            var _S709 : u32 = (((nodeRef_6 >> (u32(24)))) & (u32(127)));
            var _S710 : u32 = (nodeRef_6 & (u32(16777215)));
            found_20 = found_21;
            i_14 = u32(0);
            loop
            {
                if((i_14 < _S709))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_6 : u32 = gIndices_0[_S707 + _S710 + i_14];
                var _S711 : bool = TraverseBLAS_2(instanceIndex_6, instanceIndex_6, InverseTransformPoint_0(instanceIndex_6, ray_7.origin_0), InverseTransformVector_0(instanceIndex_6, ray_7.direction_0), ray_7.tMin_0, anyHit_3, &((*hit_17)));
                if(_S711)
                {
                    if(anyHit_3)
                    {
                        return true;
                    }
                    found_20 = true;
                }
                i_14 = i_14 + u32(1);
            }
            if(stackPtr_24 == u32(0))
            {
                break;
            }
            var stackPtr_25 : u32 = stackPtr_24 - u32(1);
            nodeRef_6 = stack_8[stackPtr_25];
            found_21 = found_20;
            stackPtr_24 = stackPtr_25;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_6 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_6];
        var dist1_12 : f32 = IntersectBox_0(node_6.lmin_0, node_6.lmax_0, ray_7.origin_0, _S708, ray_7.tMin_0, (*hit_17).t_6);
        var dist2_12 : f32 = IntersectBox_0(node_6.rmin_0, node_6.rmax_0, ray_7.origin_0, _S708, ray_7.tMin_0, (*hit_17).t_6);
        var far_6 : u32;
        var dist1_13 : f32;
        var dist2_13 : f32;
        if((dist1_12 > dist2_12))
        {
            dist1_13 = dist2_12;
            i_14 = node_6.right_0;
            dist2_13 = dist1_12;
            far_6 = node_6.left_0;
        }
        else
        {
            dist1_13 = dist1_12;
            i_14 = node_6.left_0;
            dist2_13 = dist2_12;
            far_6 = node_6.right_0;
        }
        if(dist1_13 == 1.00000001504746622e+30f)
        {
            if(stackPtr_24 == u32(0))
            {
                found_20 = found_21;
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
                found_20 = (stackPtr_24 < u32(32));
            }
            else
            {
                found_20 = false;
            }
            var stackPtr_27 : u32;
            if(found_20)
            {
                var _S712 : u32 = stackPtr_24 + u32(1);
                stack_8[stackPtr_24] = far_6;
                stackPtr_27 = _S712;
            }
            else
            {
                stackPtr_27 = stackPtr_24;
            }
            nodeRef_6 = i_14;
            stackPtr_24 = stackPtr_27;
        }
    }
    return found_20;
}

fn TraceClosest_1( ray_8 : Ray_0) -> HitRecord_0
{
    var hit_18 : HitRecord_0;
    var _S713 : bool = TraceScene_3(ray_8, false, &(hit_18));
    return hit_18;
}

fn IntersectPath_1( s_37 : ptr<function, WavefrontPath_0>,  bounce_13 : u32) -> HitRecord_0
{
    gRayCone_0 = vec2<f32>((*s_37).path_0.coneWidth_2, (*s_37).path_0.coneSpread_0);
    var _S714 : HitRecord_0 = TraceClosest_1(Ray_x24init_0((*s_37).path_0.origin_3, (*s_37).path_0.direction_1, 1.00000001504746622e+30f));
    var _S715 : HitRecord_0 = CompleteIntersection_0(&((*s_37)), bounce_13, _S714);
    return _S715;
}

fn PathState_x24init_0( radiance_6 : vec3<f32>,  throughput_43 : vec3<f32>,  origin_11 : vec3<f32>,  direction_2 : vec3<f32>,  scatterPdf_1 : f32,  lobe_7 : u32,  coneWidth_4 : f32,  coneSpread_1 : f32,  absorption_4 : vec3<f32>,  lightsSampled_1 : bool) -> PathState_0
{
    var _S716 : PathState_0;
    _S716.radiance_1 = radiance_6;
    _S716.throughput_7 = throughput_43;
    _S716.origin_3 = origin_11;
    _S716.direction_1 = direction_2;
    _S716.scatterPdf_0 = scatterPdf_1;
    _S716.lobe_2 = lobe_7;
    _S716.coneWidth_2 = coneWidth_4;
    _S716.coneSpread_0 = coneSpread_1;
    _S716.absorption_0 = absorption_4;
    _S716.lightsSampled_0 = lightsSampled_1;
    return _S716;
}

fn WavefrontPath_x24init_0( path_1 : PathState_0,  active_1 : u32,  randomSeed_1 : u32,  albedo_8 : vec3<f32>,  normal_23 : vec3<f32>) -> WavefrontPath_0
{
    var _S717 : WavefrontPath_0;
    _S717.path_0 = path_1;
    _S717.active_0 = active_1;
    _S717.randomSeed_0 = randomSeed_1;
    _S717.albedo_2 = albedo_8;
    _S717.normal_11 = normal_23;
    return _S717;
}

fn LoadShadingPath_0( base_27 : u32) -> WavefrontPath_0
{
    var _S718 : vec3<f32> = vec3<f32>(0.0f);
    var s_38 : WavefrontPath_0 = WavefrontPath_x24init_0(PathState_x24init_0(_S718, _S718, _S718, _S718, 0.0f, u32(0), 0.0f, 0.0f, _S718, false), u32(0), u32(0), _S718, _S718);
    s_38.active_0 = (bitcast<u32>((gAccum_0[base_27].w)));
    s_38.path_0.direction_1 = gAccum_0[Field_0(base_27, u32(3))].xyz;
    s_38.path_0.coneWidth_2 = gAccum_0[Field_0(base_27, u32(4))].w;
    s_38.path_0.coneSpread_0 = gAccum_0[Field_0(base_27, u32(5))].w;
    return s_38;
}

fn LoadFeedbackState_0( base_28 : u32)
{
    var state_7 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(base_28, u32(7))])));
    gVTRequest_0 = state_7.x;
    gVTRequestCount_0 = state_7.y;
    gVTRandom_0 = state_7.z;
    return;
}

fn StoreFeedbackState_0( base_29 : u32)
{
    gAccum_0[Field_0(base_29, u32(7))] = (bitcast<vec4<f32>>((vec4<u32>(gVTRequest_0, gVTRequestCount_0, gVTRandom_0, u32(0)))));
    return;
}

fn ShadeImpl_0( tid_0 : vec3<u32>)
{
    var _S719 : u32 = tid_0.x;
    if((_S719 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_30 : u32 = WorkBase_0(_S719);
    gAccum_0[Field_0(base_30, u32(11))] = vec4<f32>(0.0f);
    var s_39 : WavefrontPath_0 = LoadShadingPath_0(base_30);
    if((s_39.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_30);
    var hit_19 : HitRecord_0;
    hit_19.t_6 = gAccum_0[Field_0(base_30, u32(8))].x;
    hit_19.barycentrics_0 = gAccum_0[Field_0(base_30, u32(8))].yz;
    hit_19.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_30, u32(8))].w)));
    hit_19.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_30, u32(9))].x)));
    var _S720 : HitRecord_0 = hit_19;
    ShadePath_2(base_30, &(s_39), _S720, gWavefront_0.bounce_0);
    StorePath_0(base_30, s_39);
    StoreFeedbackState_0(base_30);
    return;
}

fn StorePath_1( base_31 : u32,  s_40 : WavefrontPath_0)
{
    gAccum_0[base_31] = vec4<f32>(s_40.path_0.radiance_1, (bitcast<f32>((s_40.active_0))));
    gAccum_0[Field_0(base_31, u32(1))] = vec4<f32>(s_40.path_0.throughput_7, (bitcast<f32>((s_40.randomSeed_0))));
    gAccum_0[Field_0(base_31, u32(2))] = vec4<f32>(s_40.path_0.origin_3, s_40.path_0.scatterPdf_0);
    gAccum_0[Field_0(base_31, u32(3))] = vec4<f32>(s_40.path_0.direction_1, (bitcast<f32>((select(u32(0), u32(1), s_40.path_0.lightsSampled_0)))));
    gAccum_0[Field_0(base_31, u32(4))] = vec4<f32>(s_40.path_0.absorption_0, s_40.path_0.coneWidth_2);
    gAccum_0[Field_0(base_31, u32(5))] = vec4<f32>(s_40.albedo_2, s_40.path_0.coneSpread_0);
    var _S721 : u32 = Field_0(base_31, u32(6));
    gAccum_0[_S721] = vec4<f32>(s_40.normal_11, gAccum_0[_S721].w);
    return;
}

fn ShadeImpl_1( tid_1 : vec3<u32>)
{
    var _S722 : u32 = tid_1.x;
    if((_S722 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_32 : u32 = WorkBase_0(_S722);
    gAccum_0[Field_0(base_32, u32(11))] = vec4<f32>(0.0f);
    var s_41 : WavefrontPath_0 = LoadShadingPath_0(base_32);
    if((s_41.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_32);
    var hit_20 : HitRecord_0;
    hit_20.t_6 = gAccum_0[Field_0(base_32, u32(8))].x;
    hit_20.barycentrics_0 = gAccum_0[Field_0(base_32, u32(8))].yz;
    hit_20.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_32, u32(8))].w)));
    hit_20.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_32, u32(9))].x)));
    var _S723 : HitRecord_0 = hit_20;
    ShadePath_3(base_32, &(s_41), _S723, u32(0));
    StorePath_1(base_32, s_41);
    StoreFeedbackState_0(base_32);
    return;
}

fn ShadeImpl_2( tid_2 : vec3<u32>)
{
    var _S724 : u32 = tid_2.x;
    if((_S724 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_33 : u32 = WorkBase_0(_S724);
    gAccum_0[Field_0(base_33, u32(11))] = vec4<f32>(0.0f);
    var s_42 : WavefrontPath_0 = LoadShadingPath_0(base_33);
    if((s_42.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_33);
    var hit_21 : HitRecord_0;
    hit_21.t_6 = gAccum_0[Field_0(base_33, u32(8))].x;
    hit_21.barycentrics_0 = gAccum_0[Field_0(base_33, u32(8))].yz;
    hit_21.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_33, u32(8))].w)));
    hit_21.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_33, u32(9))].x)));
    var _S725 : HitRecord_0 = hit_21;
    ShadePath_4(base_33, &(s_42), _S725, gWavefront_0.bounce_0);
    StorePath_1(base_33, s_42);
    StoreFeedbackState_0(base_33);
    return;
}

fn ShadeImpl_3( tid_3 : vec3<u32>)
{
    var _S726 : u32 = tid_3.x;
    if((_S726 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_34 : u32 = WorkBase_0(_S726);
    gAccum_0[Field_0(base_34, u32(11))] = vec4<f32>(0.0f);
    var s_43 : WavefrontPath_0 = LoadPath_0(base_34);
    if((s_43.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_34);
    var hit_22 : HitRecord_0;
    hit_22.t_6 = gAccum_0[Field_0(base_34, u32(8))].x;
    hit_22.barycentrics_0 = gAccum_0[Field_0(base_34, u32(8))].yz;
    hit_22.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_34, u32(8))].w)));
    hit_22.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_34, u32(9))].x)));
    var _S727 : HitRecord_0 = hit_22;
    ShadePath_5(base_34, &(s_43), _S727, gWavefront_0.bounce_0);
    StorePath_0(base_34, s_43);
    StoreFeedbackState_0(base_34);
    return;
}

fn ShadeImpl_4( tid_4 : vec3<u32>)
{
    var _S728 : u32 = tid_4.x;
    if((_S728 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_35 : u32 = WorkBase_0(_S728);
    gAccum_0[Field_0(base_35, u32(11))] = vec4<f32>(0.0f);
    var s_44 : WavefrontPath_0 = LoadPath_1(base_35);
    if((s_44.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_35);
    var hit_23 : HitRecord_0;
    hit_23.t_6 = gAccum_0[Field_0(base_35, u32(8))].x;
    hit_23.barycentrics_0 = gAccum_0[Field_0(base_35, u32(8))].yz;
    hit_23.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_35, u32(8))].w)));
    hit_23.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_35, u32(9))].x)));
    var _S729 : HitRecord_0 = hit_23;
    ShadePath_6(base_35, &(s_44), _S729, u32(0));
    StorePath_1(base_35, s_44);
    StoreFeedbackState_0(base_35);
    return;
}

fn ShadeQueueBase_0() -> u32
{
    return MainQueueBase_0() + (gWavefront_0.capacity_0 + u32(3)) / u32(4);
}

fn QueueIndex_0( base_36 : u32,  index_26 : u32) -> u32
{
    return (bitcast<u32>((gAccum_0[base_36 + index_26 / u32(4)][(index_26 & (u32(3)))])));
}

fn ShadeImpl_5( tid_5 : vec3<u32>)
{
    var _S730 : u32 = tid_5.x;
    if((_S730 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_37 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S730));
    gAccum_0[Field_0(base_37, u32(11))] = vec4<f32>(0.0f);
    var s_45 : WavefrontPath_0 = LoadShadingPath_0(base_37);
    if((s_45.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_37);
    var hit_24 : HitRecord_0;
    hit_24.t_6 = gAccum_0[Field_0(base_37, u32(8))].x;
    hit_24.barycentrics_0 = gAccum_0[Field_0(base_37, u32(8))].yz;
    hit_24.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_37, u32(8))].w)));
    hit_24.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_37, u32(9))].x)));
    var _S731 : HitRecord_0 = hit_24;
    ShadePath_2(base_37, &(s_45), _S731, gWavefront_0.bounce_0);
    StorePath_0(base_37, s_45);
    StoreFeedbackState_0(base_37);
    return;
}

fn ShadeImpl_6( tid_6 : vec3<u32>)
{
    var _S732 : u32 = tid_6.x;
    if((_S732 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_38 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S732));
    gAccum_0[Field_0(base_38, u32(11))] = vec4<f32>(0.0f);
    var s_46 : WavefrontPath_0 = LoadShadingPath_0(base_38);
    if((s_46.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_38);
    var hit_25 : HitRecord_0;
    hit_25.t_6 = gAccum_0[Field_0(base_38, u32(8))].x;
    hit_25.barycentrics_0 = gAccum_0[Field_0(base_38, u32(8))].yz;
    hit_25.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_38, u32(8))].w)));
    hit_25.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_38, u32(9))].x)));
    var _S733 : HitRecord_0 = hit_25;
    ShadePath_3(base_38, &(s_46), _S733, u32(0));
    StorePath_1(base_38, s_46);
    StoreFeedbackState_0(base_38);
    return;
}

fn ShadeImpl_7( tid_7 : vec3<u32>)
{
    var _S734 : u32 = tid_7.x;
    if((_S734 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_39 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S734));
    gAccum_0[Field_0(base_39, u32(11))] = vec4<f32>(0.0f);
    var s_47 : WavefrontPath_0 = LoadShadingPath_0(base_39);
    if((s_47.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_39);
    var hit_26 : HitRecord_0;
    hit_26.t_6 = gAccum_0[Field_0(base_39, u32(8))].x;
    hit_26.barycentrics_0 = gAccum_0[Field_0(base_39, u32(8))].yz;
    hit_26.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_39, u32(8))].w)));
    hit_26.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_39, u32(9))].x)));
    var _S735 : HitRecord_0 = hit_26;
    ShadePath_4(base_39, &(s_47), _S735, gWavefront_0.bounce_0);
    StorePath_1(base_39, s_47);
    StoreFeedbackState_0(base_39);
    return;
}

fn ShadeImpl_8( tid_8 : vec3<u32>)
{
    var _S736 : u32 = tid_8.x;
    if((_S736 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_40 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S736));
    gAccum_0[Field_0(base_40, u32(11))] = vec4<f32>(0.0f);
    var s_48 : WavefrontPath_0 = LoadPath_0(base_40);
    if((s_48.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_40);
    var hit_27 : HitRecord_0;
    hit_27.t_6 = gAccum_0[Field_0(base_40, u32(8))].x;
    hit_27.barycentrics_0 = gAccum_0[Field_0(base_40, u32(8))].yz;
    hit_27.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_40, u32(8))].w)));
    hit_27.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_40, u32(9))].x)));
    var _S737 : HitRecord_0 = hit_27;
    ShadePath_5(base_40, &(s_48), _S737, gWavefront_0.bounce_0);
    StorePath_0(base_40, s_48);
    StoreFeedbackState_0(base_40);
    return;
}

fn ShadeImpl_9( tid_9 : vec3<u32>)
{
    var _S738 : u32 = tid_9.x;
    if((_S738 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_41 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S738));
    gAccum_0[Field_0(base_41, u32(11))] = vec4<f32>(0.0f);
    var s_49 : WavefrontPath_0 = LoadPath_1(base_41);
    if((s_49.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_41);
    var hit_28 : HitRecord_0;
    hit_28.t_6 = gAccum_0[Field_0(base_41, u32(8))].x;
    hit_28.barycentrics_0 = gAccum_0[Field_0(base_41, u32(8))].yz;
    hit_28.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_41, u32(8))].w)));
    hit_28.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_41, u32(9))].x)));
    var _S739 : HitRecord_0 = hit_28;
    ShadePath_6(base_41, &(s_49), _S739, u32(0));
    StorePath_1(base_41, s_49);
    StoreFeedbackState_0(base_41);
    return;
}

fn EvalSampledEmission_0( index_27 : u32,  bary_8 : vec3<f32>,  viewer_4 : vec3<f32>,  cone_5 : vec2<f32>) -> vec3<f32>
{
    var light_5 : EmissiveTriangle_std430_0 = gLights_0[index_27];
    var _S740 : vec3<f32> = light_5.p0_0.xyz;
    var _S741 : f32 = bary_8.x;
    var _S742 : vec3<f32> = light_5.p1_0.xyz;
    var _S743 : f32 = bary_8.y;
    var _S744 : vec3<f32> = light_5.p2_0.xyz;
    var _S745 : f32 = bary_8.z;
    var position_4 : vec3<f32> = _S740 * vec3<f32>(_S741) + _S742 * vec3<f32>(_S743) + _S744 * vec3<f32>(_S745);
    var toLight_3 : vec3<f32> = position_4 - viewer_4;
    var dist_1 : f32 = length(toLight_3);
    var tc_10 : TextureCoords_0;
    var _S746 : vec2<f32> = light_5.uvA_0.xy;
    var _S747 : vec2<f32> = vec2<f32>(_S741);
    var _S748 : vec2<f32> = light_5.uvA_0.zw;
    var _S749 : vec2<f32> = vec2<f32>(_S743);
    var _S750 : vec2<f32> = light_5.uvB_0.xy;
    var _S751 : vec2<f32> = vec2<f32>(_S745);
    var _S752 : vec2<f32> = _S746 * _S747 + _S748 * _S749 + _S750 * _S751;
    var _S753 : vec2<f32> = light_5.uvB_0.zw;
    var _S754 : vec2<f32> = light_5.uvC_0.xy;
    var _S755 : vec2<f32> = light_5.uvC_0.zw;
    var _S756 : vec2<f32> = _S753 * _S747 + _S754 * _S749 + _S755 * _S751;
    var _S757 : vec3<f32> = _S742 - _S740;
    var _S758 : vec3<f32> = _S744 - _S740;
    var _S759 : vec2<f32> = _S748 - _S746;
    var _S760 : vec2<f32> = _S750 - _S746;
    var _S761 : vec2<f32> = _S754 - _S753;
    var _S762 : vec2<f32> = _S755 - _S753;
    var _S763 : f32 = cone_5.x + cone_5.y * dist_1;
    var _S764 : f32;
    if((dist_1 > 0.0f))
    {
        _S764 = dot(light_5.n_0.xyz, toLight_3) / dist_1;
    }
    else
    {
        _S764 = 1.0f;
    }
    tc_10 = MakeTextureCoords_0(_S752, _S756, _S757, _S758, _S759, _S760, _S761, _S762, _S763, _S764);
    tc_10.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((light_5.pad_0.x))), position_4);
    var _S765 : vec3<f32> = EmissiveRadiance_0(LoadMaterialHeader_0((bitcast<u32>((light_5.n_0.w)))), tc_10);
    return _S765;
}

fn ShadeLightImpl_0( tid_10 : vec3<u32>)
{
    var _S766 : u32 = tid_10.x;
    if((_S766 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_42 : u32 = WorkBase_0(_S766);
    var _S767 : u32 = Field_0(base_42, u32(11));
    var mask_5 : u32 = (bitcast<u32>((gAccum_0[_S767].z)));
    if(((mask_5 & (u32(8)))) == u32(0))
    {
        return;
    }
    var lightBase_1 : u32 = LightWorkBase_0(_S766);
    var viewer_5 : vec4<f32> = gAccum_0[Field_0(lightBase_1, u32(1))];
    LoadFeedbackState_0(base_42);
    var radiance_7 : vec3<f32> = EvalSampledEmission_0((bitcast<u32>((gAccum_0[lightBase_1].w))), gAccum_0[lightBase_1].xyz, gAccum_0[Field_0(lightBase_1, u32(1))].xyz, gAccum_0[_S767].xy);
    var mask_6 : u32;
    if(((mask_5 & (u32(2)))) != u32(0))
    {
        var _S768 : u32 = Field_0(base_42, u32(17));
        gAccum_0[_S768] = vec4<f32>(vec3<f32>(gAccum_0[_S768].w) * radiance_7 * gAccum_0[_S768].xyz / vec3<f32>(viewer_5.w), 0.0f);
        if(!(any(((radiance_7 > vec3<f32>(0.0f))))))
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
    gAccum_0[_S767][i32(2)] = (bitcast<f32>(((mask_6 & (u32(4294967287))))));
    StoreFeedbackState_0(base_42);
    return;
}

fn ShadeLightImpl_1( tid_11 : vec3<u32>)
{
    var _S769 : u32 = tid_11.x;
    if((_S769 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var _S770 : u32 = QueueIndex_0(ShadowQueueBase_0(), _S769);
    var base_43 : u32 = WorkBase_0(_S770);
    var _S771 : u32 = Field_0(base_43, u32(11));
    var mask_7 : u32 = (bitcast<u32>((gAccum_0[_S771].z)));
    if(((mask_7 & (u32(8)))) == u32(0))
    {
        return;
    }
    var lightBase_2 : u32 = LightWorkBase_0(_S770);
    var viewer_6 : vec4<f32> = gAccum_0[Field_0(lightBase_2, u32(1))];
    LoadFeedbackState_0(base_43);
    var radiance_8 : vec3<f32> = EvalSampledEmission_0((bitcast<u32>((gAccum_0[lightBase_2].w))), gAccum_0[lightBase_2].xyz, gAccum_0[Field_0(lightBase_2, u32(1))].xyz, gAccum_0[_S771].xy);
    var mask_8 : u32;
    if(((mask_7 & (u32(2)))) != u32(0))
    {
        var _S772 : u32 = Field_0(base_43, u32(17));
        gAccum_0[_S772] = vec4<f32>(vec3<f32>(gAccum_0[_S772].w) * radiance_8 * gAccum_0[_S772].xyz / vec3<f32>(viewer_6.w), 0.0f);
        if(!(any(((radiance_8 > vec3<f32>(0.0f))))))
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
    gAccum_0[_S771][i32(2)] = (bitcast<f32>(((mask_8 & (u32(4294967287))))));
    StoreFeedbackState_0(base_43);
    return;
}

fn ShadeImpl_10( tid_12 : vec3<u32>)
{
    var _S773 : u32 = BucketMetadataBase_0() + (countOneBits(u32(15)) + u32(1));
    var _S774 : u32 = tid_12.x;
    if((_S774 >= (bitcast<u32>((gAccum_0[_S773].x)))))
    {
        return;
    }
    var base_44 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), (bitcast<u32>((gAccum_0[_S773].y))) + _S774));
    gAccum_0[Field_0(base_44, u32(11))] = vec4<f32>(0.0f);
    var s_50 : WavefrontPath_0 = LoadPath_1(base_44);
    if((s_50.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_44);
    var hit_29 : HitRecord_0;
    hit_29.t_6 = gAccum_0[Field_0(base_44, u32(8))].x;
    hit_29.barycentrics_0 = gAccum_0[Field_0(base_44, u32(8))].yz;
    hit_29.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_44, u32(8))].w)));
    hit_29.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_44, u32(9))].x)));
    var _S775 : HitRecord_0 = hit_29;
    ShadePath_7(base_44, &(s_50), _S775, gWavefront_0.bounce_0);
    StorePath_1(base_44, s_50);
    StoreFeedbackState_0(base_44);
    return;
}

fn ShadeImpl_11( tid_13 : vec3<u32>)
{
    var _S776 : u32 = tid_13.x;
    if((_S776 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_45 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S776));
    if((bitcast<u32>((gAccum_0[base_45].w))) == u32(0))
    {
        return;
    }
    var _S777 : u32 = Field_0(base_45, u32(8));
    var _S778 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S777].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S778 >> (u32(21)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_45, u32(11))] = vec4<f32>(0.0f);
    var s_51 : WavefrontPath_0 = LoadPath_1(base_45);
    if((s_51.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_45);
    var hit_30 : HitRecord_0;
    hit_30.t_6 = gAccum_0[_S777].x;
    hit_30.barycentrics_0 = gAccum_0[_S777].yz;
    hit_30.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S777].w)));
    hit_30.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_45, u32(9))].x)));
    var _S779 : HitRecord_0 = hit_30;
    ShadePath_7(base_45, &(s_51), _S779, gWavefront_0.bounce_0);
    StorePath_1(base_45, s_51);
    StoreFeedbackState_0(base_45);
    return;
}

fn ShadeImpl_12( tid_14 : vec3<u32>)
{
    var _S780 : u32 = tid_14.x;
    if((_S780 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_46 : u32 = WorkBase_0(_S780);
    gAccum_0[Field_0(base_46, u32(11))] = vec4<f32>(0.0f);
    var s_52 : WavefrontPath_0 = LoadPath_1(base_46);
    if((s_52.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_46);
    var hit_31 : HitRecord_0;
    hit_31.t_6 = gAccum_0[Field_0(base_46, u32(8))].x;
    hit_31.barycentrics_0 = gAccum_0[Field_0(base_46, u32(8))].yz;
    hit_31.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_46, u32(8))].w)));
    hit_31.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_46, u32(9))].x)));
    var _S781 : HitRecord_0 = hit_31;
    ShadePath_7(base_46, &(s_52), _S781, gWavefront_0.bounce_0);
    StorePath_1(base_46, s_52);
    StoreFeedbackState_0(base_46);
    return;
}

fn ShadeImpl_13( tid_15 : vec3<u32>)
{
    var _S782 : u32 = tid_15.x;
    if((_S782 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_47 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S782));
    gAccum_0[Field_0(base_47, u32(11))] = vec4<f32>(0.0f);
    var s_53 : WavefrontPath_0 = LoadPath_1(base_47);
    if((s_53.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_47);
    var hit_32 : HitRecord_0;
    hit_32.t_6 = gAccum_0[Field_0(base_47, u32(8))].x;
    hit_32.barycentrics_0 = gAccum_0[Field_0(base_47, u32(8))].yz;
    hit_32.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_47, u32(8))].w)));
    hit_32.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_47, u32(9))].x)));
    var _S783 : HitRecord_0 = hit_32;
    ShadePath_7(base_47, &(s_53), _S783, gWavefront_0.bounce_0);
    StorePath_1(base_47, s_53);
    StoreFeedbackState_0(base_47);
    return;
}

fn TraceScene_4( ray_9 : Ray_0,  anyHit_4 : bool,  hit_33 : ptr<function, HitRecord_0>) -> bool
{
    var found_22 : bool;
    (*hit_33).t_6 = ray_9.tMax_0;
    (*hit_33).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_33).instanceIndex_2 = u32(4294967295);
    (*hit_33).primitiveIndex_1 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S784 : u32 = gFrame_0.counts_0.z;
    var _S785 : vec3<f32> = SafeRcp_0(ray_9.direction_0);
    var stack_9 : array<u32, i32(32)>;
    var nodeRef_7 : u32 = u32(0);
    var found_23 : bool = false;
    var stackPtr_28 : u32 = u32(0);
    loop
    {
        var i_15 : u32;
        if(((nodeRef_7 & (u32(2147483648)))) != u32(0))
        {
            var _S786 : u32 = (((nodeRef_7 >> (u32(24)))) & (u32(127)));
            var _S787 : u32 = (nodeRef_7 & (u32(16777215)));
            found_22 = found_23;
            i_15 = u32(0);
            loop
            {
                if((i_15 < _S786))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_7 : u32 = gIndices_0[_S784 + _S787 + i_15];
                var _S788 : bool = TraverseBLAS_0(instanceIndex_7, instanceIndex_7, InverseTransformPoint_0(instanceIndex_7, ray_9.origin_0), InverseTransformVector_0(instanceIndex_7, ray_9.direction_0), ray_9.tMin_0, anyHit_4, &((*hit_33)));
                if(_S788)
                {
                    if(anyHit_4)
                    {
                        return true;
                    }
                    found_22 = true;
                }
                i_15 = i_15 + u32(1);
            }
            if(stackPtr_28 == u32(0))
            {
                break;
            }
            var stackPtr_29 : u32 = stackPtr_28 - u32(1);
            nodeRef_7 = stack_9[stackPtr_29];
            found_23 = found_22;
            stackPtr_28 = stackPtr_29;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_7 : BVHNode_std430_0 = gNodes_0[gFrame_0.envInfo_0.z + nodeRef_7];
        var dist1_14 : f32 = IntersectBox_0(node_7.lmin_0, node_7.lmax_0, ray_9.origin_0, _S785, ray_9.tMin_0, (*hit_33).t_6);
        var dist2_14 : f32 = IntersectBox_0(node_7.rmin_0, node_7.rmax_0, ray_9.origin_0, _S785, ray_9.tMin_0, (*hit_33).t_6);
        var far_7 : u32;
        var dist1_15 : f32;
        var dist2_15 : f32;
        if((dist1_14 > dist2_14))
        {
            dist1_15 = dist2_14;
            i_15 = node_7.right_0;
            dist2_15 = dist1_14;
            far_7 = node_7.left_0;
        }
        else
        {
            dist1_15 = dist1_14;
            i_15 = node_7.left_0;
            dist2_15 = dist2_14;
            far_7 = node_7.right_0;
        }
        if(dist1_15 == 1.00000001504746622e+30f)
        {
            if(stackPtr_28 == u32(0))
            {
                found_22 = found_23;
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
                found_22 = (stackPtr_28 < u32(32));
            }
            else
            {
                found_22 = false;
            }
            var stackPtr_31 : u32;
            if(found_22)
            {
                var _S789 : u32 = stackPtr_28 + u32(1);
                stack_9[stackPtr_28] = far_7;
                stackPtr_31 = _S789;
            }
            else
            {
                stackPtr_31 = stackPtr_28;
            }
            nodeRef_7 = i_15;
            stackPtr_28 = stackPtr_31;
        }
    }
    return found_22;
}

fn NrdUnpackFraction_0( v_21 : u32) -> vec3<f32>
{
    return vec3<f32>(f32((v_21 & (u32(511)))), f32((((v_21 >> (u32(9)))) & (u32(511)))), f32((((v_21 >> (u32(18)))) & (u32(511))))) / vec3<f32>(511.0f);
}

fn NrdSplitDirect_0( flags_3 : u32,  contribution_10 : vec3<f32>,  diffuse_3 : ptr<function, vec3<f32>>,  specular_3 : ptr<function, vec3<f32>>,  bypass_1 : ptr<function, vec3<f32>>)
{
    var skip_0 : bool = ((flags_3 & (u32(4)))) != u32(0);
    var _S790 : vec3<f32>;
    if(skip_0)
    {
        _S790 = vec3<f32>(0.0f);
    }
    else
    {
        _S790 = contribution_10 * NrdUnpackFraction_0((flags_3 >> (u32(3))));
    }
    (*diffuse_3) = _S790;
    if(skip_0)
    {
        _S790 = vec3<f32>(0.0f);
    }
    else
    {
        _S790 = contribution_10 - (*diffuse_3);
    }
    (*specular_3) = _S790;
    if(skip_0)
    {
        _S790 = contribution_10;
    }
    else
    {
        _S790 = vec3<f32>(0.0f);
    }
    (*bypass_1) = _S790;
    return;
}

fn Luminance_0( color_7 : vec3<f32>) -> f32
{
    return dot(color_7, vec3<f32>(0.2125999927520752f, 0.71520000696182251f, 0.072200000286102295f));
}

fn NrdAddDirect_0( base_48 : u32,  flags_4 : u32,  contribution_11 : vec3<f32>,  direction_3 : vec3<f32>)
{
    if(((flags_4 & (u32(2)))) == u32(0))
    {
        return;
    }
    var diffuse_4 : vec3<f32>;
    var specular_4 : vec3<f32>;
    var bypass_2 : vec3<f32>;
    NrdSplitDirect_0(flags_4, contribution_11, &(diffuse_4), &(specular_4), &(bypass_2));
    var r_24 : u32 = NrdBase_0(base_48);
    var _S791 : vec3<f32> = gAccum_0[r_24].xyz + bypass_2;
    gAccum_0[r_24].x = _S791.x;
    gAccum_0[r_24].y = _S791.y;
    gAccum_0[r_24].z = _S791.z;
    var _S792 : u32 = r_24 + u32(1);
    var _S793 : vec3<f32> = gAccum_0[_S792].xyz + diffuse_4;
    gAccum_0[_S792].x = _S793.x;
    gAccum_0[_S792].y = _S793.y;
    gAccum_0[_S792].z = _S793.z;
    var _S794 : u32 = r_24 + u32(2);
    var _S795 : vec3<f32> = gAccum_0[_S794].xyz + specular_4;
    gAccum_0[_S794].x = _S795.x;
    gAccum_0[_S794].y = _S795.y;
    gAccum_0[_S794].z = _S795.z;
    var _S796 : u32 = r_24 + u32(3);
    var _S797 : vec3<f32> = gAccum_0[_S796].xyz + vec3<f32>(Luminance_0(diffuse_4)) * direction_3;
    gAccum_0[_S796].x = _S797.x;
    gAccum_0[_S796].y = _S797.y;
    gAccum_0[_S796].z = _S797.z;
    var _S798 : u32 = r_24 + u32(4);
    var _S799 : vec3<f32> = gAccum_0[_S798].xyz + vec3<f32>(Luminance_0(specular_4)) * direction_3;
    gAccum_0[_S798].x = _S799.x;
    gAccum_0[_S798].y = _S799.y;
    gAccum_0[_S798].z = _S799.z;
    return;
}

fn ResolveShadowVisibility_0( base_49 : u32,  mask_9 : u32)
{
    var _S800 : vec3<f32> = vec3<f32>(0.0f);
    var throughput_44 : vec4<f32> = gAccum_0[Field_0(base_49, u32(10))];
    var source_4 : u32 = u32(0);
    var sum_5 : vec3<f32> = _S800;
    loop
    {
        if((source_4 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_9 & (((u32(1) << (source_4)))))) == u32(0))
        {
            source_4 = source_4 + u32(1);
            continue;
        }
        var _S801 : u32 = source_4 * u32(3);
        var value_3 : vec3<f32> = gAccum_0[Field_0(base_49, u32(14) + _S801)].xyz;
        var sum_6 : vec3<f32> = sum_5 + value_3;
        NrdAddDirect_0(base_49, (bitcast<u32>((gAccum_0[Field_0(base_49, u32(13) + _S801)].w))), throughput_44.xyz * value_3, gAccum_0[Field_0(base_49, u32(13) + _S801)].xyz);
        sum_5 = sum_6;
        source_4 = source_4 + u32(1);
    }
    var contribution_12 : vec3<f32> = throughput_44.xyz * sum_5;
    var _S802 : f32 = throughput_44.w;
    var contribution_13 : vec3<f32>;
    if((_S802 > 0.0f))
    {
        contribution_13 = min(contribution_12, vec3<f32>(_S802));
    }
    else
    {
        contribution_13 = contribution_12;
    }
    var path_2 : vec4<f32> = gAccum_0[base_49];
    var _S803 : vec3<f32> = gAccum_0[base_49].xyz + contribution_13;
    path_2.x = _S803.x;
    path_2.y = _S803.y;
    path_2.z = _S803.z;
    gAccum_0[base_49] = path_2;
    gAccum_0[Field_0(base_49, u32(11))] = vec4<f32>(0.0f);
    return;
}

fn ShadowClassifyImpl_0( tid_16 : vec3<u32>)
{
    var _S804 : u32 = tid_16.x;
    if((_S804 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_50 : u32 = WorkBase_0(_S804);
    var _S805 : u32 = Field_0(base_50, u32(11));
    var info_0 : vec4<f32> = gAccum_0[_S805];
    var mask_10 : u32 = (bitcast<u32>((gAccum_0[_S805].z)));
    if(mask_10 == u32(0))
    {
        return;
    }
    var source_5 : u32 = u32(0);
    var mask_11 : u32 = mask_10;
    var pending_0 : u32 = u32(0);
    loop
    {
        if((source_5 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var bit_0 : u32 = (u32(1) << (source_5));
        var mask_12 : u32;
        var pending_1 : u32;
        if(((mask_11 & (bit_0))) == u32(0))
        {
            mask_12 = mask_11;
            pending_1 = pending_0;
            source_5 = source_5 + u32(1);
            mask_11 = mask_12;
            pending_0 = pending_1;
            continue;
        }
        var offset_3 : u32 = u32(12) + source_5 * u32(3);
        var origin_12 : vec4<f32> = gAccum_0[Field_0(base_50, offset_3)];
        var direction_4 : vec4<f32> = gAccum_0[Field_0(base_50, offset_3 + u32(1))];
        var hit_34 : HitRecord_0;
        var _S806 : bool;
        if((((bitcast<u32>((gAccum_0[Field_0(base_50, offset_3 + u32(1))].w))) & (u32(1)))) != u32(0))
        {
            var _S807 : bool = TraceScene_4(Ray_x24init_0(origin_12.xyz, direction_4.xyz, origin_12.w), true, &(hit_34));
            _S806 = _S807;
        }
        else
        {
            _S806 = false;
        }
        if(_S806)
        {
            if((((gInstances_0[hit_34.instanceIndex_2].flags_0) & (u32(1)))) != u32(0))
            {
                var pending_2 : u32 = (pending_0 | (bit_0));
                mask_12 = mask_11;
                pending_1 = pending_2;
            }
            else
            {
                mask_12 = (mask_11 & ((~bit_0)));
                pending_1 = pending_0;
            }
        }
        else
        {
            mask_12 = mask_11;
            pending_1 = pending_0;
        }
        source_5 = source_5 + u32(1);
        mask_11 = mask_12;
        pending_0 = pending_1;
    }
    if(pending_0 == u32(0))
    {
        ResolveShadowVisibility_0(base_50, mask_11);
    }
    else
    {
        gAccum_0[_S805] = vec4<f32>(info_0.xy, (bitcast<f32>((mask_11))), (bitcast<f32>((pending_0))));
    }
    return;
}

fn ShadowClassifyImpl_1( tid_17 : vec3<u32>)
{
    var _S808 : u32 = tid_17.x;
    if((_S808 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_51 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S808));
    var _S809 : u32 = Field_0(base_51, u32(11));
    var info_1 : vec4<f32> = gAccum_0[_S809];
    var mask_13 : u32 = (bitcast<u32>((gAccum_0[_S809].z)));
    if(mask_13 == u32(0))
    {
        return;
    }
    var source_6 : u32 = u32(0);
    var mask_14 : u32 = mask_13;
    var pending_3 : u32 = u32(0);
    loop
    {
        if((source_6 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var bit_1 : u32 = (u32(1) << (source_6));
        var mask_15 : u32;
        var pending_4 : u32;
        if(((mask_14 & (bit_1))) == u32(0))
        {
            mask_15 = mask_14;
            pending_4 = pending_3;
            source_6 = source_6 + u32(1);
            mask_14 = mask_15;
            pending_3 = pending_4;
            continue;
        }
        var offset_4 : u32 = u32(12) + source_6 * u32(3);
        var origin_13 : vec4<f32> = gAccum_0[Field_0(base_51, offset_4)];
        var direction_5 : vec4<f32> = gAccum_0[Field_0(base_51, offset_4 + u32(1))];
        var hit_35 : HitRecord_0;
        var _S810 : bool;
        if((((bitcast<u32>((gAccum_0[Field_0(base_51, offset_4 + u32(1))].w))) & (u32(1)))) != u32(0))
        {
            var _S811 : bool = TraceScene_4(Ray_x24init_0(origin_13.xyz, direction_5.xyz, origin_13.w), true, &(hit_35));
            _S810 = _S811;
        }
        else
        {
            _S810 = false;
        }
        if(_S810)
        {
            if((((gInstances_0[hit_35.instanceIndex_2].flags_0) & (u32(1)))) != u32(0))
            {
                var pending_5 : u32 = (pending_3 | (bit_1));
                mask_15 = mask_14;
                pending_4 = pending_5;
            }
            else
            {
                mask_15 = (mask_14 & ((~bit_1)));
                pending_4 = pending_3;
            }
        }
        else
        {
            mask_15 = mask_14;
            pending_4 = pending_3;
        }
        source_6 = source_6 + u32(1);
        mask_14 = mask_15;
        pending_3 = pending_4;
    }
    if(pending_3 == u32(0))
    {
        ResolveShadowVisibility_0(base_51, mask_14);
    }
    else
    {
        gAccum_0[_S809] = vec4<f32>(info_1.xy, (bitcast<f32>((mask_14))), (bitcast<f32>((pending_3))));
    }
    return;
}

fn ShadowImpl_0( tid_18 : vec3<u32>)
{
    var sum_7 : vec3<f32>;
    var _S812 : u32 = tid_18.x;
    if((_S812 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_52 : u32 = WorkBase_0(_S812);
    var _S813 : u32 = Field_0(base_52, u32(11));
    var info_2 : vec4<f32> = gAccum_0[_S813];
    var mask_16 : u32 = (bitcast<u32>((gAccum_0[_S813].z)));
    if(mask_16 == u32(0))
    {
        return;
    }
    gRayCone_0 = info_2.xy;
    var _S814 : vec3<f32> = vec3<f32>(0.0f);
    var throughput_45 : vec4<f32> = gAccum_0[Field_0(base_52, u32(10))];
    var source_7 : u32 = u32(0);
    var sum_8 : vec3<f32> = _S814;
    loop
    {
        if((source_7 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_16 & (((u32(1) << (source_7)))))) == u32(0))
        {
            source_7 = source_7 + u32(1);
            continue;
        }
        var offset_5 : u32 = u32(12) + source_7 * u32(3);
        var origin_14 : vec4<f32> = gAccum_0[Field_0(base_52, offset_5)];
        var direction_6 : vec4<f32> = gAccum_0[Field_0(base_52, offset_5 + u32(1))];
        var flags_5 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_52, offset_5 + u32(1))].w)));
        var _S815 : bool;
        if(((flags_5 & (u32(1)))) == u32(0))
        {
            _S815 = true;
        }
        else
        {
            var _S816 : bool = TraceOcclusion_0(Ray_x24init_0(origin_14.xyz, direction_6.xyz, origin_14.w));
            _S815 = !_S816;
        }
        if(_S815)
        {
            var value_4 : vec3<f32> = gAccum_0[Field_0(base_52, offset_5 + u32(2))].xyz;
            var sum_9 : vec3<f32> = sum_8 + value_4;
            NrdAddDirect_0(base_52, flags_5, throughput_45.xyz * value_4, direction_6.xyz);
            sum_7 = sum_9;
        }
        else
        {
            sum_7 = sum_8;
        }
        sum_8 = sum_7;
        source_7 = source_7 + u32(1);
    }
    var contribution_14 : vec3<f32> = throughput_45.xyz * sum_8;
    var _S817 : f32 = throughput_45.w;
    if((_S817 > 0.0f))
    {
        sum_7 = min(contribution_14, vec3<f32>(_S817));
    }
    else
    {
        sum_7 = contribution_14;
    }
    var path_3 : vec4<f32> = gAccum_0[base_52];
    var _S818 : vec3<f32> = gAccum_0[base_52].xyz + sum_7;
    path_3.x = _S818.x;
    path_3.y = _S818.y;
    path_3.z = _S818.z;
    gAccum_0[base_52] = path_3;
    gAccum_0[_S813] = vec4<f32>(0.0f);
    return;
}

fn ShadowImpl_1( tid_19 : vec3<u32>)
{
    var sum_10 : vec3<f32>;
    var _S819 : u32 = tid_19.x;
    if((_S819 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_53 : u32 = WorkBase_0(_S819);
    var _S820 : u32 = Field_0(base_53, u32(11));
    var info_3 : vec4<f32> = gAccum_0[_S820];
    var mask_17 : u32 = (bitcast<u32>((gAccum_0[_S820].z)));
    if(mask_17 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_53);
    gRayCone_0 = info_3.xy;
    var _S821 : vec3<f32> = vec3<f32>(0.0f);
    var throughput_46 : vec4<f32> = gAccum_0[Field_0(base_53, u32(10))];
    var source_8 : u32 = u32(0);
    var sum_11 : vec3<f32> = _S821;
    loop
    {
        if((source_8 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_17 & (((u32(1) << (source_8)))))) == u32(0))
        {
            source_8 = source_8 + u32(1);
            continue;
        }
        var offset_6 : u32 = u32(12) + source_8 * u32(3);
        var origin_15 : vec4<f32> = gAccum_0[Field_0(base_53, offset_6)];
        var direction_7 : vec4<f32> = gAccum_0[Field_0(base_53, offset_6 + u32(1))];
        var flags_6 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_53, offset_6 + u32(1))].w)));
        var _S822 : bool;
        if(((flags_6 & (u32(1)))) == u32(0))
        {
            _S822 = true;
        }
        else
        {
            var _S823 : bool = TraceOcclusion_1(Ray_x24init_0(origin_15.xyz, direction_7.xyz, origin_15.w));
            _S822 = !_S823;
        }
        if(_S822)
        {
            var value_5 : vec3<f32> = gAccum_0[Field_0(base_53, offset_6 + u32(2))].xyz;
            var sum_12 : vec3<f32> = sum_11 + value_5;
            NrdAddDirect_0(base_53, flags_6, throughput_46.xyz * value_5, direction_7.xyz);
            sum_10 = sum_12;
        }
        else
        {
            sum_10 = sum_11;
        }
        sum_11 = sum_10;
        source_8 = source_8 + u32(1);
    }
    var contribution_15 : vec3<f32> = throughput_46.xyz * sum_11;
    var _S824 : f32 = throughput_46.w;
    if((_S824 > 0.0f))
    {
        sum_10 = min(contribution_15, vec3<f32>(_S824));
    }
    else
    {
        sum_10 = contribution_15;
    }
    var path_4 : vec4<f32> = gAccum_0[base_53];
    var _S825 : vec3<f32> = gAccum_0[base_53].xyz + sum_10;
    path_4.x = _S825.x;
    path_4.y = _S825.y;
    path_4.z = _S825.z;
    gAccum_0[base_53] = path_4;
    gAccum_0[_S820] = vec4<f32>(0.0f);
    StoreFeedbackState_0(base_53);
    return;
}

fn ShadeImpl_14( tid_20 : vec3<u32>)
{
    var _S826 : u32 = BucketMetadataBase_0() + (countOneBits(u32(15)) + u32(1));
    var _S827 : u32 = tid_20.x;
    if((_S827 >= (bitcast<u32>((gAccum_0[_S826].x)))))
    {
        return;
    }
    var base_54 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), (bitcast<u32>((gAccum_0[_S826].y))) + _S827));
    gAccum_0[Field_0(base_54, u32(11))] = vec4<f32>(0.0f);
    var s_54 : WavefrontPath_0 = LoadPath_1(base_54);
    if((s_54.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_54);
    var hit_36 : HitRecord_0;
    hit_36.t_6 = gAccum_0[Field_0(base_54, u32(8))].x;
    hit_36.barycentrics_0 = gAccum_0[Field_0(base_54, u32(8))].yz;
    hit_36.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_54, u32(8))].w)));
    hit_36.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_54, u32(9))].x)));
    var _S828 : HitRecord_0 = hit_36;
    ShadePath_8(base_54, &(s_54), _S828, gWavefront_0.bounce_0);
    StorePath_1(base_54, s_54);
    StoreFeedbackState_0(base_54);
    return;
}

fn ShadeImpl_15( tid_21 : vec3<u32>)
{
    var _S829 : u32 = tid_21.x;
    if((_S829 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_55 : u32 = WorkBase_0(_S829);
    if((bitcast<u32>((gAccum_0[base_55].w))) == u32(0))
    {
        return;
    }
    var _S830 : u32 = Field_0(base_55, u32(8));
    var _S831 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S830].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S831 >> (u32(16)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_55, u32(11))] = vec4<f32>(0.0f);
    var s_55 : WavefrontPath_0 = LoadPath_1(base_55);
    if((s_55.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_55);
    var hit_37 : HitRecord_0;
    hit_37.t_6 = gAccum_0[_S830].x;
    hit_37.barycentrics_0 = gAccum_0[_S830].yz;
    hit_37.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S830].w)));
    hit_37.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_55, u32(9))].x)));
    var _S832 : HitRecord_0 = hit_37;
    ShadePath_8(base_55, &(s_55), _S832, gWavefront_0.bounce_0);
    StorePath_1(base_55, s_55);
    StoreFeedbackState_0(base_55);
    return;
}

fn ShadeImpl_16( tid_22 : vec3<u32>)
{
    var _S833 : u32 = tid_22.x;
    if((_S833 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_56 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S833));
    if((bitcast<u32>((gAccum_0[base_56].w))) == u32(0))
    {
        return;
    }
    var _S834 : u32 = Field_0(base_56, u32(8));
    var _S835 : u32 = gMaterialData_0[gInstances_0[(bitcast<u32>((gAccum_0[_S834].w)))].materialIndex_0 * u32(2)].w;
    if(((((_S835 >> (u32(16)))) & (u32(31)))) != u32(16))
    {
        return;
    }
    gAccum_0[Field_0(base_56, u32(11))] = vec4<f32>(0.0f);
    var s_56 : WavefrontPath_0 = LoadPath_1(base_56);
    if((s_56.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_56);
    var hit_38 : HitRecord_0;
    hit_38.t_6 = gAccum_0[_S834].x;
    hit_38.barycentrics_0 = gAccum_0[_S834].yz;
    hit_38.instanceIndex_2 = (bitcast<u32>((gAccum_0[_S834].w)));
    hit_38.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_56, u32(9))].x)));
    var _S836 : HitRecord_0 = hit_38;
    ShadePath_8(base_56, &(s_56), _S836, gWavefront_0.bounce_0);
    StorePath_1(base_56, s_56);
    StoreFeedbackState_0(base_56);
    return;
}

fn ShadeImpl_17( tid_23 : vec3<u32>)
{
    var _S837 : u32 = tid_23.x;
    if((_S837 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_57 : u32 = WorkBase_0(_S837);
    gAccum_0[Field_0(base_57, u32(11))] = vec4<f32>(0.0f);
    var s_57 : WavefrontPath_0 = LoadPath_1(base_57);
    if((s_57.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_57);
    var hit_39 : HitRecord_0;
    hit_39.t_6 = gAccum_0[Field_0(base_57, u32(8))].x;
    hit_39.barycentrics_0 = gAccum_0[Field_0(base_57, u32(8))].yz;
    hit_39.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_57, u32(8))].w)));
    hit_39.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_57, u32(9))].x)));
    var _S838 : HitRecord_0 = hit_39;
    ShadePath_8(base_57, &(s_57), _S838, gWavefront_0.bounce_0);
    StorePath_1(base_57, s_57);
    StoreFeedbackState_0(base_57);
    return;
}

fn IntersectImpl_0( tid_24 : vec3<u32>)
{
    var _S839 : u32 = tid_24.x;
    if((_S839 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_58 : u32 = WorkBase_0(_S839);
    var s_58 : WavefrontPath_0 = LoadPath_1(base_58);
    if((s_58.active_0) == u32(0))
    {
        return;
    }
    var hit_40 : HitRecord_0 = IntersectPath_0(&(s_58), gWavefront_0.bounce_0);
    var _S840 : bool;
    if((gWavefront_0.bounce_0) == u32(1))
    {
        _S840 = NrdEnabled_0();
    }
    else
    {
        _S840 = false;
    }
    if(_S840)
    {
        var _S841 : u32 = NrdBase_0(base_58);
        var _S842 : f32;
        if(HitRecord_IsHit_0(hit_40))
        {
            _S842 = hit_40.t_6;
        }
        else
        {
            _S842 = 65504.0f;
        }
        gAccum_0[_S841 + u32(1)][i32(3)] = _S842;
    }
    if(HitRecord_IsHit_0(hit_40))
    {
        gAccum_0[Field_0(base_58, u32(8))] = vec4<f32>(hit_40.t_6, hit_40.barycentrics_0, (bitcast<f32>((hit_40.instanceIndex_2))));
        gAccum_0[Field_0(base_58, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_40.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_58] = vec4<f32>(s_58.path_0.radiance_1, (bitcast<f32>((s_58.active_0))));
    return;
}

fn IntersectImpl_1( tid_25 : vec3<u32>)
{
    var _S843 : u32 = tid_25.x;
    if((_S843 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_59 : u32 = WorkBase_0(_S843);
    var s_59 : WavefrontPath_0 = LoadPath_1(base_59);
    if((s_59.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_59);
    var hit_41 : HitRecord_0 = IntersectPath_1(&(s_59), gWavefront_0.bounce_0);
    var _S844 : bool;
    if((gWavefront_0.bounce_0) == u32(1))
    {
        _S844 = NrdEnabled_0();
    }
    else
    {
        _S844 = false;
    }
    if(_S844)
    {
        var _S845 : u32 = NrdBase_0(base_59);
        var _S846 : f32;
        if(HitRecord_IsHit_0(hit_41))
        {
            _S846 = hit_41.t_6;
        }
        else
        {
            _S846 = 65504.0f;
        }
        gAccum_0[_S845 + u32(1)][i32(3)] = _S846;
    }
    if(HitRecord_IsHit_0(hit_41))
    {
        gAccum_0[Field_0(base_59, u32(8))] = vec4<f32>(hit_41.t_6, hit_41.barycentrics_0, (bitcast<f32>((hit_41.instanceIndex_2))));
        gAccum_0[Field_0(base_59, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_41.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_59] = vec4<f32>(s_59.path_0.radiance_1, (bitcast<f32>((s_59.active_0))));
    StoreFeedbackState_0(base_59);
    return;
}

fn TailImpl_0( tid_26 : vec3<u32>)
{
    var count_1 : u32 = (bitcast<u32>((gAccum_0[HeaderBase_0()].x)));
    var _S847 : u32 = tid_26.x;
    var _S848 : bool;
    if((_S847 >= count_1))
    {
        _S848 = true;
    }
    else
    {
        if((gWavefront_0.tailThreshold_0) != u32(0))
        {
            _S848 = (count_1 > (gWavefront_0.tailThreshold_0));
        }
        else
        {
            _S848 = false;
        }
    }
    if(_S848)
    {
        return;
    }
    var base_60 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S847));
    var s_60 : WavefrontPath_0 = LoadPath_1(base_60);
    if((s_60.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_60);
    var bounce_14 : u32 = gWavefront_0.bounce_0;
    loop
    {
        if((bounce_14 <= (gFrame_0.settings_0.x)))
        {
        }
        else
        {
            break;
        }
        var hit_42 : HitRecord_0 = IntersectPath_0(&(s_60), bounce_14);
        if((s_60.active_0) == u32(0))
        {
            break;
        }
        ShadePath_0(base_60, &(s_60), hit_42, bounce_14);
        if((s_60.active_0) == u32(0))
        {
            break;
        }
        bounce_14 = bounce_14 + u32(1);
    }
    StorePath_1(base_60, s_60);
    StoreFeedbackState_0(base_60);
    return;
}

fn TailImpl_1( tid_27 : vec3<u32>)
{
    var count_2 : u32 = (bitcast<u32>((gAccum_0[HeaderBase_0()].x)));
    var _S849 : u32 = tid_27.x;
    var _S850 : bool;
    if((_S849 >= count_2))
    {
        _S850 = true;
    }
    else
    {
        if((gWavefront_0.tailThreshold_0) != u32(0))
        {
            _S850 = (count_2 > (gWavefront_0.tailThreshold_0));
        }
        else
        {
            _S850 = false;
        }
    }
    if(_S850)
    {
        return;
    }
    var base_61 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S849));
    var s_61 : WavefrontPath_0 = LoadPath_1(base_61);
    if((s_61.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_61);
    var bounce_15 : u32 = gWavefront_0.bounce_0;
    loop
    {
        if((bounce_15 <= (gFrame_0.settings_0.x)))
        {
        }
        else
        {
            break;
        }
        var hit_43 : HitRecord_0 = IntersectPath_1(&(s_61), bounce_15);
        if((s_61.active_0) == u32(0))
        {
            break;
        }
        ShadePath_1(base_61, &(s_61), hit_43, bounce_15);
        if((s_61.active_0) == u32(0))
        {
            break;
        }
        bounce_15 = bounce_15 + u32(1);
    }
    StorePath_1(base_61, s_61);
    StoreFeedbackState_0(base_61);
    return;
}

fn ShadowImpl_2( tid_28 : vec3<u32>)
{
    var sum_13 : vec3<f32>;
    var _S851 : u32 = tid_28.x;
    if((_S851 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_62 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S851));
    var _S852 : u32 = Field_0(base_62, u32(11));
    var info_4 : vec4<f32> = gAccum_0[_S852];
    var mask_18 : u32 = (bitcast<u32>((gAccum_0[_S852].z)));
    if(mask_18 == u32(0))
    {
        return;
    }
    gRayCone_0 = info_4.xy;
    var _S853 : vec3<f32> = vec3<f32>(0.0f);
    var throughput_47 : vec4<f32> = gAccum_0[Field_0(base_62, u32(10))];
    var source_9 : u32 = u32(0);
    var sum_14 : vec3<f32> = _S853;
    loop
    {
        if((source_9 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_18 & (((u32(1) << (source_9)))))) == u32(0))
        {
            source_9 = source_9 + u32(1);
            continue;
        }
        var offset_7 : u32 = u32(12) + source_9 * u32(3);
        var origin_16 : vec4<f32> = gAccum_0[Field_0(base_62, offset_7)];
        var direction_8 : vec4<f32> = gAccum_0[Field_0(base_62, offset_7 + u32(1))];
        var flags_7 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_62, offset_7 + u32(1))].w)));
        var _S854 : bool;
        if(((flags_7 & (u32(1)))) == u32(0))
        {
            _S854 = true;
        }
        else
        {
            var _S855 : bool = TraceOcclusion_0(Ray_x24init_0(origin_16.xyz, direction_8.xyz, origin_16.w));
            _S854 = !_S855;
        }
        if(_S854)
        {
            var value_6 : vec3<f32> = gAccum_0[Field_0(base_62, offset_7 + u32(2))].xyz;
            var sum_15 : vec3<f32> = sum_14 + value_6;
            NrdAddDirect_0(base_62, flags_7, throughput_47.xyz * value_6, direction_8.xyz);
            sum_13 = sum_15;
        }
        else
        {
            sum_13 = sum_14;
        }
        sum_14 = sum_13;
        source_9 = source_9 + u32(1);
    }
    var contribution_16 : vec3<f32> = throughput_47.xyz * sum_14;
    var _S856 : f32 = throughput_47.w;
    if((_S856 > 0.0f))
    {
        sum_13 = min(contribution_16, vec3<f32>(_S856));
    }
    else
    {
        sum_13 = contribution_16;
    }
    var path_5 : vec4<f32> = gAccum_0[base_62];
    var _S857 : vec3<f32> = gAccum_0[base_62].xyz + sum_13;
    path_5.x = _S857.x;
    path_5.y = _S857.y;
    path_5.z = _S857.z;
    gAccum_0[base_62] = path_5;
    gAccum_0[_S852] = vec4<f32>(0.0f);
    return;
}

fn ShadowImpl_3( tid_29 : vec3<u32>)
{
    var sum_16 : vec3<f32>;
    var _S858 : u32 = tid_29.x;
    if((_S858 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_63 : u32 = WorkBase_0(QueueIndex_0(ShadowQueueBase_0(), _S858));
    var _S859 : u32 = Field_0(base_63, u32(11));
    var info_5 : vec4<f32> = gAccum_0[_S859];
    var mask_19 : u32 = (bitcast<u32>((gAccum_0[_S859].z)));
    if(mask_19 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_63);
    gRayCone_0 = info_5.xy;
    var _S860 : vec3<f32> = vec3<f32>(0.0f);
    var throughput_48 : vec4<f32> = gAccum_0[Field_0(base_63, u32(10))];
    var source_10 : u32 = u32(0);
    var sum_17 : vec3<f32> = _S860;
    loop
    {
        if((source_10 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_19 & (((u32(1) << (source_10)))))) == u32(0))
        {
            source_10 = source_10 + u32(1);
            continue;
        }
        var offset_8 : u32 = u32(12) + source_10 * u32(3);
        var origin_17 : vec4<f32> = gAccum_0[Field_0(base_63, offset_8)];
        var direction_9 : vec4<f32> = gAccum_0[Field_0(base_63, offset_8 + u32(1))];
        var flags_8 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_63, offset_8 + u32(1))].w)));
        var _S861 : bool;
        if(((flags_8 & (u32(1)))) == u32(0))
        {
            _S861 = true;
        }
        else
        {
            var _S862 : bool = TraceOcclusion_1(Ray_x24init_0(origin_17.xyz, direction_9.xyz, origin_17.w));
            _S861 = !_S862;
        }
        if(_S861)
        {
            var value_7 : vec3<f32> = gAccum_0[Field_0(base_63, offset_8 + u32(2))].xyz;
            var sum_18 : vec3<f32> = sum_17 + value_7;
            NrdAddDirect_0(base_63, flags_8, throughput_48.xyz * value_7, direction_9.xyz);
            sum_16 = sum_18;
        }
        else
        {
            sum_16 = sum_17;
        }
        sum_17 = sum_16;
        source_10 = source_10 + u32(1);
    }
    var contribution_17 : vec3<f32> = throughput_48.xyz * sum_17;
    var _S863 : f32 = throughput_48.w;
    if((_S863 > 0.0f))
    {
        sum_16 = min(contribution_17, vec3<f32>(_S863));
    }
    else
    {
        sum_16 = contribution_17;
    }
    var path_6 : vec4<f32> = gAccum_0[base_63];
    var _S864 : vec3<f32> = gAccum_0[base_63].xyz + sum_16;
    path_6.x = _S864.x;
    path_6.y = _S864.y;
    path_6.z = _S864.z;
    gAccum_0[base_63] = path_6;
    gAccum_0[_S859] = vec4<f32>(0.0f);
    StoreFeedbackState_0(base_63);
    return;
}

fn ShadeImpl_18( tid_30 : vec3<u32>)
{
    var _S865 : u32 = tid_30.x;
    if((_S865 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_64 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S865));
    gAccum_0[Field_0(base_64, u32(11))] = vec4<f32>(0.0f);
    var s_62 : WavefrontPath_0 = LoadPath_1(base_64);
    if((s_62.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_64);
    var hit_44 : HitRecord_0;
    hit_44.t_6 = gAccum_0[Field_0(base_64, u32(8))].x;
    hit_44.barycentrics_0 = gAccum_0[Field_0(base_64, u32(8))].yz;
    hit_44.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_64, u32(8))].w)));
    hit_44.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_64, u32(9))].x)));
    var _S866 : HitRecord_0 = hit_44;
    ShadePath_8(base_64, &(s_62), _S866, gWavefront_0.bounce_0);
    StorePath_1(base_64, s_62);
    StoreFeedbackState_0(base_64);
    return;
}

fn IntersectImpl_2( tid_31 : vec3<u32>)
{
    var _S867 : u32 = tid_31.x;
    if((_S867 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_65 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S867));
    var s_63 : WavefrontPath_0 = LoadPath_1(base_65);
    if((s_63.active_0) == u32(0))
    {
        return;
    }
    var hit_45 : HitRecord_0 = IntersectPath_0(&(s_63), gWavefront_0.bounce_0);
    var _S868 : bool;
    if((gWavefront_0.bounce_0) == u32(1))
    {
        _S868 = NrdEnabled_0();
    }
    else
    {
        _S868 = false;
    }
    if(_S868)
    {
        var _S869 : u32 = NrdBase_0(base_65);
        var _S870 : f32;
        if(HitRecord_IsHit_0(hit_45))
        {
            _S870 = hit_45.t_6;
        }
        else
        {
            _S870 = 65504.0f;
        }
        gAccum_0[_S869 + u32(1)][i32(3)] = _S870;
    }
    if(HitRecord_IsHit_0(hit_45))
    {
        gAccum_0[Field_0(base_65, u32(8))] = vec4<f32>(hit_45.t_6, hit_45.barycentrics_0, (bitcast<f32>((hit_45.instanceIndex_2))));
        gAccum_0[Field_0(base_65, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_45.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_65] = vec4<f32>(s_63.path_0.radiance_1, (bitcast<f32>((s_63.active_0))));
    return;
}

fn IntersectImpl_3( tid_32 : vec3<u32>)
{
    var _S871 : u32 = tid_32.x;
    if((_S871 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].x)))))
    {
        return;
    }
    var base_66 : u32 = WorkBase_0(QueueIndex_0(MainQueueBase_0(), _S871));
    var s_64 : WavefrontPath_0 = LoadPath_1(base_66);
    if((s_64.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_66);
    var hit_46 : HitRecord_0 = IntersectPath_1(&(s_64), gWavefront_0.bounce_0);
    var _S872 : bool;
    if((gWavefront_0.bounce_0) == u32(1))
    {
        _S872 = NrdEnabled_0();
    }
    else
    {
        _S872 = false;
    }
    if(_S872)
    {
        var _S873 : u32 = NrdBase_0(base_66);
        var _S874 : f32;
        if(HitRecord_IsHit_0(hit_46))
        {
            _S874 = hit_46.t_6;
        }
        else
        {
            _S874 = 65504.0f;
        }
        gAccum_0[_S873 + u32(1)][i32(3)] = _S874;
    }
    if(HitRecord_IsHit_0(hit_46))
    {
        gAccum_0[Field_0(base_66, u32(8))] = vec4<f32>(hit_46.t_6, hit_46.barycentrics_0, (bitcast<f32>((hit_46.instanceIndex_2))));
        gAccum_0[Field_0(base_66, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(hit_46.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    }
    gAccum_0[base_66] = vec4<f32>(s_64.path_0.radiance_1, (bitcast<f32>((s_64.active_0))));
    StoreFeedbackState_0(base_66);
    return;
}

fn AnalyticFlags_1( light_6 : ptr<function, EmissiveTriangle_std430_0>) -> u32
{
    return (bitcast<u32>(((*light_6).n_0.w)));
}

fn SpotAttenuation_1( light_7 : ptr<function, EmissiveTriangle_std430_0>,  dir_30 : vec3<f32>) -> f32
{
    var _S875 : u32 = AnalyticFlags_1(&((*light_7)));
    if(((_S875 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_32 : f32 = dot(dir_30, (*light_7).p2_0.xyz) - (*light_7).uvA_0.w;
    var scale_6 : f32 = (*light_7).uvB_0.x;
    var _S876 : f32;
    if((scale_6 > 0.0f))
    {
        _S876 = smoothstep(0.0f, 1.0f, x_32 * scale_6);
    }
    else
    {
        if((x_32 > 0.0f))
        {
            _S876 = 1.0f;
        }
        else
        {
            _S876 = 0.0f;
        }
    }
    return _S876;
}

fn IntersectAnalyticLights_1( origin_18 : vec3<f32>,  dir_31 : vec3<f32>,  tMax_5 : f32,  cameraRay_1 : bool,  radiance_9 : ptr<function, vec3<f32>>,  pdf_19 : ptr<function, f32>) -> bool
{
    (*radiance_9) = vec3<f32>(0.0f);
    (*pdf_19) = 0.0f;
    var nearest_2 : f32 = tMax_5;
    var found_24 : bool = false;
    var i_16 : u32 = u32(0);
    loop
    {
        if((i_16 < (AnalyticLightCount_0())))
        {
        }
        else
        {
            break;
        }
        var _S877 : EmissiveTriangle_std430_0 = gLights_0[i_16];
        var _S878 : u32 = AnalyticFlags_1(&(_S877));
        var _S879 : bool;
        if(cameraRay_1)
        {
            _S879 = ((_S878 & (u32(256)))) != u32(0);
        }
        else
        {
            _S879 = false;
        }
        if(_S879)
        {
            i_16 = i_16 + u32(1);
            continue;
        }
        var nearest_3 : f32;
        var _S880 : bool;
        var inside_5 : bool;
        if(((_S878 & (u32(255)))) == u32(2))
        {
            var n_20 : vec3<f32> = _S877.p2_0.xyz;
            var cosTheta_15 : f32 = - dot(n_20, dir_31);
            if((cosTheta_15 <= 9.99999997475242708e-07f))
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            var _S881 : vec4<f32> = _S877.p0_0;
            var _S882 : vec3<f32> = _S877.p0_0.xyz;
            var t_17 : f32 = dot(_S882 - origin_18, n_20) / - cosTheta_15;
            if((t_17 <= 0.0f))
            {
                _S880 = true;
            }
            else
            {
                _S880 = (t_17 >= nearest_2);
            }
            if(_S880)
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            var local_5 : vec3<f32> = origin_18 + dir_31 * vec3<f32>(t_17) - _S882;
            var _S883 : vec3<f32> = _S877.n_0.xyz;
            var _S884 : vec3<f32> = _S877.uvA_0.xyz;
            var d_13 : vec2<f32> = vec2<f32>(dot(local_5, _S883) / dot(_S883, _S883), dot(local_5, _S884) / dot(_S884, _S884));
            if(((_S878 & (u32(512)))) != u32(0))
            {
                inside_5 = ((dot(d_13, d_13)) <= 0.25f);
            }
            else
            {
                inside_5 = (all((((abs(d_13)) <= vec2<f32>(0.5f)))));
            }
            if(!inside_5)
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            (*radiance_9) = _S877.p1_0.xyz;
            (*pdf_19) = _S877.p1_0.w * t_17 * t_17 / (cosTheta_15 * _S881.w);
            nearest_3 = t_17;
        }
        else
        {
            var _S885 : vec4<f32> = _S877.p0_0;
            var radius_5 : f32 = _S877.p0_0.w;
            if((radius_5 <= 0.0f))
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            var toCenter_2 : vec3<f32> = _S885.xyz - origin_18;
            var distSq_5 : f32 = dot(toCenter_2, toCenter_2);
            var tc_11 : f32 = dot(toCenter_2, dir_31);
            var _S886 : f32 = radius_5 * radius_5;
            var h_17 : f32 = _S886 - (distSq_5 - tc_11 * tc_11);
            if((h_17 < 0.0f))
            {
                _S880 = true;
            }
            else
            {
                _S880 = (distSq_5 <= _S886);
            }
            if(_S880)
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            var t_18 : f32 = tc_11 - sqrt(h_17);
            if((t_18 <= 0.0f))
            {
                inside_5 = true;
            }
            else
            {
                inside_5 = (t_18 >= nearest_2);
            }
            if(inside_5)
            {
                i_16 = i_16 + u32(1);
                continue;
            }
            var _S887 : vec4<f32> = _S877.p1_0;
            var _S888 : vec3<f32> = _S877.p1_0.xyz;
            var _S889 : f32 = SpotAttenuation_1(&(_S877), (vec3<f32>(0) - toCenter_2) * vec3<f32>(rsqrt_0(distSq_5)));
            (*radiance_9) = _S888 * vec3<f32>(_S889);
            (*pdf_19) = _S887.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_5, distSq_5));
            nearest_3 = t_18;
        }
        nearest_2 = nearest_3;
        found_24 = true;
        i_16 = i_16 + u32(1);
    }
    return found_24;
}

fn CompleteIntersection_1( s_65 : ptr<function, WavefrontPath_0>,  bounce_16 : u32,  hit_47 : HitRecord_0) -> HitRecord_0
{
    var ray_10 : Ray_0 = Ray_x24init_0((*s_65).path_0.origin_3, (*s_65).path_0.direction_1, 1.00000001504746622e+30f);
    var clampValue_10 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var mis_7 : f32;
    var _S890 : bool;
    var contribution_18 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_10 : vec3<f32>;
        var pdf_20 : f32;
        if(HitRecord_IsHit_0(hit_47))
        {
            mis_7 = hit_47.t_6;
        }
        else
        {
            mis_7 = 1.00000001504746622e+30f;
        }
        var _S891 : bool = IntersectAnalyticLights_1(ray_10.origin_0, ray_10.direction_0, mis_7, bounce_16 == u32(0), &(radiance_10), &(pdf_20));
        if(_S891)
        {
            var _S892 : bool = (bounce_16 > u32(0));
            if(_S892)
            {
                _S890 = (*s_65).path_0.lightsSampled_0;
            }
            else
            {
                _S890 = false;
            }
            if(_S890)
            {
                mis_7 = EvalMISRobust_0((*s_65).path_0.scatterPdf_0, pdf_20);
            }
            else
            {
                mis_7 = 1.0f;
            }
            var contribution_19 : vec3<f32> = (*s_65).path_0.throughput_7 * vec3<f32>(mis_7) * radiance_10;
            if((clampValue_10 > 0.0f))
            {
                _S890 = _S892;
            }
            else
            {
                _S890 = false;
            }
            if(_S890)
            {
                contribution_18 = min(contribution_19, vec3<f32>(clampValue_10));
            }
            else
            {
                contribution_18 = contribution_19;
            }
            (*s_65).path_0.radiance_1 = (*s_65).path_0.radiance_1 + contribution_18;
        }
    }
    if(!HitRecord_IsHit_0(hit_47))
    {
        if(bounce_16 == u32(0))
        {
            var visible_1 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_1)
            {
                contribution_18 = EvalEnvironment_0(ray_10.direction_0);
            }
            else
            {
                contribution_18 = gFrame_0.background_0.xyz;
            }
            (*s_65).path_0.radiance_1 = (*s_65).path_0.radiance_1 + contribution_18;
            if(visible_1)
            {
                _S890 = HitsSun_0(ray_10.direction_0);
            }
            else
            {
                _S890 = false;
            }
            if(_S890)
            {
                (*s_65).path_0.radiance_1 = (*s_65).path_0.radiance_1 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if((*s_65).path_0.lightsSampled_0)
            {
                mis_7 = EvalMISRobust_0((*s_65).path_0.scatterPdf_0, EnvironmentPdf_0(ray_10.direction_0));
            }
            else
            {
                mis_7 = 1.0f;
            }
            var contribution_20 : vec3<f32> = (*s_65).path_0.throughput_7 * vec3<f32>(mis_7) * EvalEnvironment_0(ray_10.direction_0);
            if(!(*s_65).path_0.lightsSampled_0)
            {
                _S890 = SunEnabled_0();
            }
            else
            {
                _S890 = false;
            }
            if(_S890)
            {
                _S890 = HitsSun_0(ray_10.direction_0);
            }
            else
            {
                _S890 = false;
            }
            if(_S890)
            {
                contribution_18 = contribution_20 + (*s_65).path_0.throughput_7 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_18 = contribution_20;
            }
            if((clampValue_10 > 0.0f))
            {
                contribution_18 = min(contribution_18, vec3<f32>(clampValue_10));
            }
            (*s_65).path_0.radiance_1 = (*s_65).path_0.radiance_1 + contribution_18;
        }
        (*s_65).active_0 = u32(0);
    }
    return hit_47;
}

fn StorePrimaryHit_0( base_67 : u32,  s_66 : ptr<function, WavefrontPath_0>,  hit_48 : HitRecord_0)
{
    var _S893 : HitRecord_0 = CompleteIntersection_1(&((*s_66)), u32(0), hit_48);
    gAccum_0[Field_0(base_67, u32(8))] = vec4<f32>(_S893.t_6, _S893.barycentrics_0, (bitcast<f32>((_S893.instanceIndex_2))));
    gAccum_0[Field_0(base_67, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(_S893.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    gAccum_0[base_67] = vec4<f32>((*s_66).path_0.radiance_1, (bitcast<f32>(((*s_66).active_0))));
    return;
}

fn PrimaryTraceFallbackImpl_0( tid_33 : vec3<u32>)
{
    var _S894 : u32 = tid_33.x;
    if((_S894 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_68 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S894));
    var s_67 : WavefrontPath_0 = LoadPath_1(base_68);
    gRayCone_0 = vec2<f32>(s_67.path_0.coneWidth_2, s_67.path_0.coneSpread_0);
    var hit_49 : HitRecord_0 = TraceClosest_0(Ray_x24init_0(s_67.path_0.origin_3, s_67.path_0.direction_1, 1.00000001504746622e+30f));
    StorePrimaryHit_0(base_68, &(s_67), hit_49);
    return;
}

fn PrimaryTraceFallbackImpl_1( tid_34 : vec3<u32>)
{
    var _S895 : u32 = tid_34.x;
    if((_S895 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].y)))))
    {
        return;
    }
    var base_69 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S895));
    var s_68 : WavefrontPath_0 = LoadPath_1(base_69);
    LoadFeedbackState_0(base_69);
    gRayCone_0 = vec2<f32>(s_68.path_0.coneWidth_2, s_68.path_0.coneSpread_0);
    var hit_50 : HitRecord_0 = TraceClosest_1(Ray_x24init_0(s_68.path_0.origin_3, s_68.path_0.direction_1, 1.00000001504746622e+30f));
    StorePrimaryHit_0(base_69, &(s_68), hit_50);
    StoreFeedbackState_0(base_69);
    return;
}

fn isfinite_2( x_33 : vec2<f32>) -> vec2<bool>
{
    var result_10 : vec2<bool>;
    var i_17 : i32 = i32(0);
    loop
    {
        if((i_17 < i32(2)))
        {
        }
        else
        {
            break;
        }
        result_10[i_17] = isfinite_0(x_33[i_17]);
        i_17 = i_17 + i32(1);
    }
    return result_10;
}

fn StorePrimaryHit_1( base_70 : u32,  s_69 : ptr<function, WavefrontPath_0>,  hit_51 : HitRecord_0)
{
    var _S896 : HitRecord_0 = CompleteIntersection_0(&((*s_69)), u32(0), hit_51);
    gAccum_0[Field_0(base_70, u32(8))] = vec4<f32>(_S896.t_6, _S896.barycentrics_0, (bitcast<f32>((_S896.instanceIndex_2))));
    gAccum_0[Field_0(base_70, u32(9))] = (bitcast<vec4<f32>>((vec4<u32>(_S896.primitiveIndex_1, u32(0), u32(0), u32(0)))));
    gAccum_0[base_70] = vec4<f32>((*s_69).path_0.radiance_1, (bitcast<f32>(((*s_69).active_0))));
    return;
}

fn _S897() -> vec2<f32>
{
    return vec2<f32>(0.0f);
}

@compute
@workgroup_size(64, 1, 1)
fn ResolvePrimaryVisibility(@builtin(global_invocation_id) tid_35 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var _S898 : u32 = tid_35.x;
    if((_S898 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_71 : u32 = WorkBase_0(_S898);
    var _S899 : u32 = Field_0(base_71, u32(9));
    gAccum_0[_S899] = vec4<f32>(0.0f);
    var s_70 : WavefrontPath_0 = LoadPath_1(base_71);
    if((s_70.active_0) == u32(0))
    {
        return;
    }
    var _S900 : vec2<u32> = WorkPixel_0(_S898);
    var _S901 : vec3<i32> = vec3<i32>(vec2<i32>(_S900), i32(0));
    var ids_0 : vec2<u32> = (textureLoad((gPrimaryVisibility_0), ((_S901)).xy, ((_S901)).z).xy);
    var pending_6 : u32;
    if((bitcast<u32>((gAccum_0[gFrame_0.primaryVisibility_0.x / u32(4)].y))) != u32(0))
    {
        pending_6 = u32(3);
    }
    else
    {
        pending_6 = u32(0);
    }
    var hit_52 : HitRecord_0;
    hit_52.t_6 = 1.00000001504746622e+30f;
    hit_52.barycentrics_0 = vec2<f32>(0.0f);
    hit_52.instanceIndex_2 = u32(4294967295);
    hit_52.primitiveIndex_1 = u32(4294967295);
    var _S902 : bool;
    if(pending_6 == u32(0))
    {
        _S902 = (ids_0.x) == u32(4294967295);
    }
    else
    {
        _S902 = false;
    }
    if(_S902)
    {
        _S902 = (ids_0.y) != u32(4294967295);
    }
    else
    {
        _S902 = false;
    }
    if(_S902)
    {
        pending_6 = u32(2);
    }
    if(pending_6 == u32(0))
    {
        _S902 = (ids_0.x) != u32(4294967295);
    }
    else
    {
        _S902 = false;
    }
    if(_S902)
    {
        var _S903 : u32 = ids_0.x;
        if((_S903 >= (gFrame_0.primaryVisibility_0.w)))
        {
            pending_6 = u32(2);
        }
        else
        {
            var _S904 : u32 = ids_0.y;
            if((_S904 >= (gInstances_0[_S903].triCount_0)))
            {
                pending_6 = u32(2);
            }
            else
            {
                if((((gInstances_0[_S903].flags_0) & (u32(1)))) != u32(0))
                {
                    pending_6 = u32(1);
                }
                else
                {
                    var _S905 : vec3<u32> = LoadTriangleIndices_0(_S903, _S904);
                    var p_9 : vec3<f32> = gVertices_0[_S905.x].positionU_0.xyz;
                    var e1_2 : vec3<f32> = gVertices_0[_S905.y].positionU_0.xyz - p_9;
                    var e2_2 : vec3<f32> = gVertices_0[_S905.z].positionU_0.xyz - p_9;
                    var _S906 : vec3<f32> = InverseTransformPoint_0(_S903, s_70.path_0.origin_3);
                    var _S907 : vec3<f32> = InverseTransformVector_0(_S903, s_70.path_0.direction_1);
                    var _S908 : f32 = hit_52.t_6;
                    var _S909 : vec2<f32> = hit_52.barycentrics_0;
                    var valid_2 : bool = IntersectTriangle_0(_S906, _S907, p_9, e1_2, e2_2, 0.0f, 1.00000001504746622e+30f, &(_S908), &(_S909));
                    hit_52.t_6 = _S908;
                    hit_52.barycentrics_0 = _S909;
                    if(!valid_2)
                    {
                        _S902 = true;
                    }
                    else
                    {
                        _S902 = !isfinite_0(hit_52.t_6);
                    }
                    if(_S902)
                    {
                        _S902 = true;
                    }
                    else
                    {
                        _S902 = !(all((isfinite_2(hit_52.barycentrics_0))));
                    }
                    if(_S902)
                    {
                        pending_6 = u32(2);
                    }
                    else
                    {
                        hit_52.instanceIndex_2 = _S903;
                        hit_52.primitiveIndex_1 = _S904;
                    }
                }
            }
        }
    }
    if(pending_6 != u32(0))
    {
        gAccum_0[_S899] = (bitcast<vec4<f32>>((vec4<u32>(u32(0), pending_6, u32(0), u32(0)))));
    }
    else
    {
        StorePrimaryHit_1(base_71, &(s_70), hit_52);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn PrimaryTraceFallback(@builtin(global_invocation_id) tid_36 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    PrimaryTraceFallbackImpl_1(tid_36);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn PrimaryTraceFallbackOpaque(@builtin(global_invocation_id) tid_37 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    PrimaryTraceFallbackImpl_0(tid_37);
    return;
}

@compute
@workgroup_size(1, 1, 1)
fn PrimaryTraceFallbackSparse(@builtin(global_invocation_id) tid_38 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    PrimaryTraceFallbackImpl_1(tid_38);
    return;
}

@compute
@workgroup_size(1, 1, 1)
fn PrimaryTraceFallbackSparseOpaque(@builtin(global_invocation_id) tid_39 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    PrimaryTraceFallbackImpl_0(tid_39);
    return;
}

fn RandomSequence_x24init_1( pixel_8 : vec2<u32>,  timeSeed_1 : u32) -> RandomSequence_0
{
    var _S910 : RandomSequence_0;
    _S910.seed_0 = StrongIntegerHash_0(pixel_8.x + pixel_8.y * u32(65536) + StrongIntegerHash_0(timeSeed_1));
    return _S910;
}

fn RandomSequence_Next2D_1( this_119 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_34 : f32 = RandomSequence_Next_1(&((*this_119)));
    var y_13 : f32 = RandomSequence_Next_1(&((*this_119)));
    return vec2<f32>(x_34, y_13);
}

fn PrimaryCameraJitter_0() -> vec2<f32>
{
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        return gFrame_0.temporal_0.xy;
    }
    var rng_18 : RandomSequence_0 = RandomSequence_x24init_0(u32(1447646018), gFrame_0.frame_0.w);
    var _S911 : vec2<f32> = RandomSequence_Next2D_1(&(rng_18));
    return _S911;
}

fn GenerateCameraRay_0( pixel_9 : vec2<u32>,  rng_19 : ptr<function, RandomSequence_0>) -> Ray_0
{
    var _S912 : vec2<f32> = vec2<f32>(gFrame_0.frame_0.xy);
    var _S913 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_19)));
    var jitter_0 : vec2<f32>;
    if((((gFrame_0.settings_0.z) & (u32(16)))) != u32(0))
    {
        jitter_0 = PrimaryCameraJitter_0();
    }
    else
    {
        jitter_0 = _S913;
    }
    var film_2 : vec2<f32> = (vec2<f32>(pixel_9) + jitter_0) / _S912;
    var forward_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var dir_32 : vec3<f32> = normalize(forward_0 + gFrame_0.cameraRight_0.xyz * vec3<f32>((film_2.x * 2.0f - 1.0f)) + gFrame_0.cameraUp_0.xyz * vec3<f32>((1.0f - film_2.y * 2.0f)));
    var origin_19 : vec3<f32> = gFrame_0.cameraPosition_0.xyz;
    var lensRadius_0 : f32 = gFrame_0.cameraPosition_0.w;
    var dir_33 : vec3<f32>;
    var origin_20 : vec3<f32>;
    if((lensRadius_0 > 0.0f))
    {
        var focusPoint_0 : vec3<f32> = origin_19 + dir_32 * vec3<f32>((gFrame_0.cameraRight_0.w / dot(dir_32, forward_0)));
        var _S914 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_19)));
        var lens_0 : vec2<f32> = SampleDisk_0(_S914) * vec2<f32>(lensRadius_0);
        var origin_21 : vec3<f32> = origin_19 + (normalize(gFrame_0.cameraRight_0.xyz) * vec3<f32>(lens_0.x) + normalize(gFrame_0.cameraUp_0.xyz) * vec3<f32>(lens_0.y));
        dir_33 = normalize(focusPoint_0 - origin_21);
        origin_20 = origin_21;
    }
    else
    {
        dir_33 = dir_32;
        origin_20 = origin_19;
    }
    return Ray_x24init_0(origin_20, dir_33, 1.00000001504746622e+30f);
}

fn InitVirtualTextureFeedback_0( pixel_10 : vec2<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = StrongIntegerHash_0(((pixel_10.x) ^ ((StrongIntegerHash_0(((pixel_10.y) ^ ((StrongIntegerHash_0(gFrame_0.frame_0.w)))))))));
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Initialize(@builtin(global_invocation_id) tid_40 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_28 : u32 = tid_40.x;
    if((index_28 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var pixel_11 : vec2<u32> = WorkPixel_0(index_28);
    var rng_20 : RandomSequence_0 = RandomSequence_x24init_1(pixel_11, gFrame_0.frame_0.w);
    var ray_11 : Ray_0 = GenerateCameraRay_0(pixel_11, &(rng_20));
    var s_71 : WavefrontPath_0;
    var _S915 : vec3<f32> = vec3<f32>(0.0f);
    s_71.path_0.radiance_1 = _S915;
    s_71.path_0.throughput_7 = vec3<f32>(1.0f);
    s_71.path_0.origin_3 = ray_11.origin_0;
    s_71.path_0.direction_1 = ray_11.direction_0;
    s_71.path_0.scatterPdf_0 = 1.0f;
    s_71.path_0.lobe_2 = u32(0);
    s_71.path_0.coneWidth_2 = 0.0f;
    s_71.path_0.coneSpread_0 = gFrame_0.vtParams_0.y;
    s_71.path_0.absorption_0 = _S915;
    s_71.path_0.lightsSampled_0 = false;
    s_71.active_0 = select(u32(0), u32(1), (all(((pixel_11 < (gFrame_0.frame_0.xy))))));
    var _S916 : bool;
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        _S916 = (s_71.active_0) != u32(0);
    }
    else
    {
        _S916 = false;
    }
    if(_S916)
    {
        var output_7 : u32 = (pixel_11.y * gFrame_0.frame_0.x + pixel_11.x) * u32(3);
        gAccum_0[output_7 + u32(1)][i32(3)] = 0.0f;
        gAccum_0[output_7 + u32(2)][i32(3)] = 0.0f;
    }
    if(NrdEnabled_0())
    {
        _S916 = (s_71.active_0) != u32(0);
    }
    else
    {
        _S916 = false;
    }
    if(_S916)
    {
        var r_25 : u32 = gFrame_0.envInfo_0.w + (pixel_11.y * gFrame_0.frame_0.x + pixel_11.x) * u32(5);
        var _S917 : vec4<f32> = vec4<f32>(0.0f);
        gAccum_0[r_25] = _S917;
        gAccum_0[r_25 + u32(1)] = _S917;
        gAccum_0[r_25 + u32(2)] = vec4<f32>(0.0f, 0.0f, 0.0f, -1.0f);
        gAccum_0[r_25 + u32(3)] = _S917;
        gAccum_0[r_25 + u32(4)] = _S917;
    }
    s_71.randomSeed_0 = rng_20.seed_0;
    s_71.albedo_2 = _S915;
    s_71.normal_11 = _S915;
    var base_72 : u32 = WorkBase_0(index_28);
    StorePath_1(base_72, s_71);
    if(SharcEnabled_0())
    {
        _S916 = (s_71.active_0) != u32(0);
    }
    else
    {
        _S916 = false;
    }
    var sortGroups_0 : u32;
    if(_S916)
    {
        if(SharcUpdatePath_0(index_28, gWavefront_0.tileStart_0))
        {
            sortGroups_0 = u32(512);
        }
        else
        {
            sortGroups_0 = u32(0);
        }
        sortGroups_0 = (u32(1) | (sortGroups_0));
    }
    else
    {
        sortGroups_0 = u32(0);
    }
    gAccum_0[Field_0(base_72, u32(6))][i32(3)] = (bitcast<f32>((sortGroups_0)));
    gAccum_0[Field_0(base_72, u32(11))] = vec4<f32>(0.0f);
    if(((index_28 & (u32(3)))) == u32(0))
    {
        gAccum_0[MainQueueBase_0() + index_28 / u32(4)] = (bitcast<vec4<f32>>((vec4<u32>(index_28, index_28 + u32(1), index_28 + u32(2), index_28 + u32(3)))));
    }
    if(index_28 == u32(0))
    {
        if((gWavefront_0.sortGroupSize_0) == u32(256))
        {
            sortGroups_0 = (gWavefront_0.pathCount_0 + u32(255)) / u32(256);
        }
        else
        {
            sortGroups_0 = u32(0);
        }
        var _S918 : u32 = HeaderBase_0();
        gAccum_0[_S918] = (bitcast<vec4<f32>>((vec4<u32>(gWavefront_0.pathCount_0, u32(0), u32(0), sortGroups_0))));
        gAccum_0[_S918 + u32(1)] = (bitcast<vec4<f32>>((vec4<u32>((gWavefront_0.pathCount_0 + u32(63)) / u32(64), u32(1), u32(1), u32(0)))));
        gAccum_0[_S918 + u32(2)] = (bitcast<vec4<f32>>((vec4<u32>(u32(0), u32(1), u32(1), u32(0)))));
    }
    InitVirtualTextureFeedback_0(pixel_11);
    StoreFeedbackState_0(base_72);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Intersect(@builtin(global_invocation_id) tid_41 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_3(tid_41);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectOpaque(@builtin(global_invocation_id) tid_42 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_2(tid_42);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shade(@builtin(global_invocation_id) tid_43 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_18(tid_43);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shadow(@builtin(global_invocation_id) tid_44 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_3(tid_44);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowOpaque(@builtin(global_invocation_id) tid_45 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_2(tid_45);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Tail(@builtin(global_invocation_id) tid_46 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    TailImpl_1(tid_46);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn TailOpaque(@builtin(global_invocation_id) tid_47 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    TailImpl_0(tid_47);
    return;
}

fn SharcFinishUpdate_0( index_29 : u32,  finalRadiance_0 : vec3<f32>)
{
    var vertex_0 : u32 = u32(0);
    loop
    {
        if((vertex_0 < u32(4)))
        {
        }
        else
        {
            break;
        }
        var base_73 : u32 = SharcRecordWord_0(index_29 / u32(16) * u32(4) + vertex_0) / u32(4);
        var _S919 : u32 = base_73 + u32(1);
        if((bitcast<u32>((gAccum_0[_S919].z))) == u32(0))
        {
            vertex_0 = vertex_0 + u32(1);
            continue;
        }
        var _S920 : u32 = base_73 + u32(2);
        var target_0 : vec3<f32> = max(finalRadiance_0 - gAccum_0[_S920].xyz, vec3<f32>(0.0f)) / gAccum_0[base_73 + u32(3)].xyz;
        if(!(all((isfinite_1(target_0)))))
        {
            gAccum_0[_S919][i32(2)] = (bitcast<f32>((u32(0))));
        }
        gAccum_0[_S920] = vec4<f32>(target_0, 0.0f);
        vertex_0 = vertex_0 + u32(1);
    }
    return;
}

fn IsFeedbackPixel_0( pixel_12 : vec2<u32>) -> bool
{
    var _S921 : vec2<u32> = vec2<u32>(gFrame_0.vtInfo_0.w);
    return (all((pixel_12 == (min(((((pixel_12 >> (_S921))) << (_S921))) + vec2<u32>(((gFrame_0.vtInfo_0.z) & (u32(65535))), ((gFrame_0.vtInfo_0.z) >> (u32(16)))), gFrame_0.frame_0.xy - vec2<u32>(u32(1)))))));
}

fn NrdOctDecode_0( p_10 : vec2<f32>) -> vec3<f32>
{
    var _S922 : vec3<f32> = vec3<f32>(p_10, 1.0f - abs(p_10.x) - abs(p_10.y));
    var v_22 : vec3<f32> = _S922;
    if(((_S922.z) < 0.0f))
    {
        var _S923 : vec2<f32> = (vec2<f32>(1.0f) - abs(v_22.yx)) * select(vec2<f32>(-1.0f), vec2<f32>(1.0f), ((v_22.xy) >= vec2<f32>(0.0f)));
        v_22.x = _S923.x;
        v_22.y = _S923.y;
    }
    return normalize(v_22);
}

@compute
@workgroup_size(64, 1, 1)
fn Finalize(@builtin(global_invocation_id) tid_48 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_30 : u32 = tid_48.x;
    if((index_30 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_74 : u32 = WorkBase_0(index_30);
    var s_72 : WavefrontPath_0 = LoadPath_1(base_74);
    var pixel_13 : vec2<u32> = WorkPixel_0(index_30);
    if((any(((pixel_13 >= (gFrame_0.frame_0.xy))))))
    {
        return;
    }
    var valid_3 : bool;
    if(SharcEnabled_0())
    {
        valid_3 = SharcUpdatePath_0(index_30, gWavefront_0.tileStart_0);
    }
    else
    {
        valid_3 = false;
    }
    if(valid_3)
    {
        SharcFinishUpdate_0(index_30, s_72.path_0.radiance_1);
    }
    LoadFeedbackState_0(base_74);
    if(IsFeedbackPixel_0(pixel_13))
    {
        textureStore((gVTFeedback_0), ((pixel_13 >> (vec2<u32>(gFrame_0.vtInfo_0.w)))), vec4<u32>((gVTRequest_0), 0, 0, 1));
    }
    var radiance_11 : vec3<f32> = s_72.path_0.radiance_1 * vec3<f32>(gFrame_0.envParams_0.z);
    var radiance_12 : vec3<f32>;
    if(!(all((isfinite_1(radiance_11)))))
    {
        radiance_12 = vec3<f32>(0.0f);
    }
    else
    {
        radiance_12 = radiance_11;
    }
    var output_8 : u32 = (pixel_13.y * gFrame_0.frame_0.x + pixel_13.x) * u32(3);
    var _S924 : u32 = output_8 + u32(1);
    var _S925 : f32 = gAccum_0[_S924].w;
    var _S926 : u32 = output_8 + u32(2);
    var _S927 : f32 = gAccum_0[_S926].w;
    if((gFrame_0.frame_0.z) == u32(0))
    {
        gAccum_0[output_8] = vec4<f32>(radiance_12, 1.0f);
        gAccum_0[_S924] = vec4<f32>(s_72.albedo_2, 1.0f);
        gAccum_0[_S926] = vec4<f32>(s_72.normal_11, 1.0f);
    }
    else
    {
        var _S928 : vec3<f32> = vec3<f32>((1.0f / f32(gFrame_0.frame_0.z + u32(1))));
        gAccum_0[output_8] = vec4<f32>(mix(gAccum_0[output_8].xyz, radiance_12, _S928), 1.0f);
        gAccum_0[_S924] = vec4<f32>(mix(gAccum_0[_S924].xyz, s_72.albedo_2, _S928), 1.0f);
        gAccum_0[_S926] = vec4<f32>(mix(gAccum_0[_S926].xyz, s_72.normal_11, _S928), 1.0f);
    }
    if((gFrame_0.temporal_0.z) != 0.0f)
    {
        gAccum_0[_S924][i32(3)] = _S925;
        gAccum_0[_S926][i32(3)] = _S927;
    }
    if(NrdEnabled_0())
    {
        var r_26 : u32 = NrdBase_0(base_74);
        var _S929 : u32 = r_26 + u32(1);
        var diffuse_5 : vec4<f32> = gAccum_0[_S929];
        var _S930 : u32 = r_26 + u32(2);
        var _S931 : u32 = r_26 + u32(3);
        var diffuseDirection_0 : vec4<f32> = gAccum_0[_S931];
        var _S932 : u32 = r_26 + u32(4);
        var specularDirection_0 : vec4<f32> = gAccum_0[_S932];
        var _S933 : f32 = gAccum_0[_S930].w;
        var surface_1 : bool = (_S933 >= 0.0f);
        var _S934 : vec3<f32> = gAccum_0[_S929].xyz;
        var _S935 : vec3<f32> = gAccum_0[_S930].xyz;
        var _S936 : vec3<f32> = vec3<f32>(0.0f);
        var _S937 : vec3<f32> = max(s_72.path_0.radiance_1 - gAccum_0[r_26].xyz - _S934 - _S935, _S936);
        var indirectDiffuse_0 : vec3<f32> = _S937 * NrdUnpackFraction_0((bitcast<u32>((gAccum_0[r_26].w))));
        var indirectSpecular_0 : vec3<f32> = _S937 - indirectDiffuse_0;
        var wi_43 : vec3<f32>;
        if((any(((_S937 > vec3<f32>(0.0f))))))
        {
            wi_43 = NrdOctDecode_0(vec2<f32>(diffuseDirection_0.w, specularDirection_0.w));
        }
        else
        {
            wi_43 = _S936;
        }
        var _S938 : vec3<f32> = _S934 + indirectDiffuse_0;
        var dDirection_0 : vec3<f32> = (diffuseDirection_0.xyz + vec3<f32>(Luminance_0(indirectDiffuse_0)) * wi_43) / vec3<f32>(max(Luminance_0(_S938), 9.999999960041972e-13f));
        var _S939 : vec3<f32> = _S935 + indirectSpecular_0;
        var sDirection_0 : vec3<f32> = (specularDirection_0.xyz + vec3<f32>(Luminance_0(indirectSpecular_0)) * wi_43) / vec3<f32>(max(Luminance_0(_S939), 9.999999960041972e-13f));
        var d_14 : vec3<f32> = _S938 * vec3<f32>(gFrame_0.envParams_0.z);
        var sp_0 : vec3<f32> = _S939 * vec3<f32>(gFrame_0.envParams_0.z);
        if(surface_1)
        {
            valid_3 = (all((isfinite_1(d_14))));
        }
        else
        {
            valid_3 = false;
        }
        if(valid_3)
        {
            valid_3 = (all((isfinite_1(sp_0))));
        }
        else
        {
            valid_3 = false;
        }
        if(valid_3)
        {
            wi_43 = d_14;
        }
        else
        {
            wi_43 = _S936;
        }
        gAccum_0[r_26] = vec4<f32>(wi_43, diffuse_5.w);
        if(valid_3)
        {
            wi_43 = sp_0;
        }
        else
        {
            wi_43 = _S936;
        }
        gAccum_0[_S929] = vec4<f32>(wi_43, _S933);
        if(valid_3)
        {
            radiance_12 = max(radiance_12 - d_14 - sp_0, _S936);
        }
        var _S940 : f32;
        if(valid_3)
        {
            _S940 = 1.0f;
        }
        else
        {
            _S940 = 0.0f;
        }
        gAccum_0[_S930] = vec4<f32>(radiance_12, _S940);
        var _S941 : bool;
        if(valid_3)
        {
            _S941 = (all((isfinite_1(dDirection_0))));
        }
        else
        {
            _S941 = false;
        }
        if(_S941)
        {
            radiance_12 = dDirection_0;
        }
        else
        {
            radiance_12 = _S936;
        }
        gAccum_0[_S931] = vec4<f32>(radiance_12, 0.0f);
        if(valid_3)
        {
            valid_3 = (all((isfinite_1(sDirection_0))));
        }
        else
        {
            valid_3 = false;
        }
        if(valid_3)
        {
            radiance_12 = sDirection_0;
        }
        else
        {
            radiance_12 = _S936;
        }
        gAccum_0[_S932] = vec4<f32>(radiance_12, 0.0f);
    }
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectDirect(@builtin(global_invocation_id) tid_49 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_1(tid_49);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn IntersectOpaqueDirect(@builtin(global_invocation_id) tid_50 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    IntersectImpl_0(tid_50);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeDirect(@builtin(global_invocation_id) tid_51 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_17(tid_51);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucket(@builtin(global_invocation_id) tid_52 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_16(tid_52);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucketDirect(@builtin(global_invocation_id) tid_53 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_15(tid_53);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeBucketCompact(@builtin(global_invocation_id) tid_54 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_14(tid_54);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowDirect(@builtin(global_invocation_id) tid_55 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_1(tid_55);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowOpaqueDirect(@builtin(global_invocation_id) tid_56 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowImpl_0(tid_56);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowClassify(@builtin(global_invocation_id) tid_57 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowClassifyImpl_1(tid_57);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowClassifyDirect(@builtin(global_invocation_id) tid_58 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadowClassifyImpl_0(tid_58);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadowAlpha(@builtin(global_invocation_id) tid_59 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var _S942 : u32 = tid_59.x;
    if((_S942 >= (bitcast<u32>((gAccum_0[HeaderBase_0()].z)))))
    {
        return;
    }
    var base_75 : u32 = WorkBase_0(QueueIndex_0(ShadeQueueBase_0(), _S942));
    var _S943 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_75, u32(11))].z)));
    var _S944 : u32 = (bitcast<u32>((gAccum_0[Field_0(base_75, u32(11))].w)));
    LoadFeedbackState_0(base_75);
    gRayCone_0 = gAccum_0[Field_0(base_75, u32(11))].xy;
    var source_11 : u32 = u32(0);
    var mask_20 : u32 = _S943;
    loop
    {
        if((source_11 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var bit_2 : u32 = (u32(1) << (source_11));
        if(((_S944 & (bit_2))) == u32(0))
        {
            source_11 = source_11 + u32(1);
            continue;
        }
        var offset_9 : u32 = u32(12) + source_11 * u32(3);
        var _S945 : bool = TraceOcclusion_1(Ray_x24init_0(gAccum_0[Field_0(base_75, offset_9)].xyz, gAccum_0[Field_0(base_75, offset_9 + u32(1))].xyz, gAccum_0[Field_0(base_75, offset_9)].w));
        var mask_21 : u32;
        if(_S945)
        {
            mask_21 = (mask_20 & ((~bit_2)));
        }
        else
        {
            mask_21 = mask_20;
        }
        mask_20 = mask_21;
        source_11 = source_11 + u32(1);
    }
    ResolveShadowVisibility_0(base_75, mask_20);
    StoreFeedbackState_0(base_75);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurface(@builtin(global_invocation_id) tid_60 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_13(tid_60);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceDirect(@builtin(global_invocation_id) tid_61 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_12(tid_61);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceBucket(@builtin(global_invocation_id) tid_62 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_11(tid_62);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSurfaceCompact(@builtin(global_invocation_id) tid_63 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_10(tid_63);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLight(@builtin(global_invocation_id) tid_64 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeLightImpl_1(tid_64);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLightDirect(@builtin(global_invocation_id) tid_65 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeLightImpl_0(tid_65);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimary(@builtin(global_invocation_id) tid_66 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_9(tid_66);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondary(@builtin(global_invocation_id) tid_67 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_8(tid_67);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLate(@builtin(global_invocation_id) tid_68 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_7(tid_68);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryLate(@builtin(global_invocation_id) tid_69 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_6(tid_69);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryLate(@builtin(global_invocation_id) tid_70 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_5(tid_70);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryDirect(@builtin(global_invocation_id) tid_71 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_4(tid_71);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryDirect(@builtin(global_invocation_id) tid_72 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_3(tid_72);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeLateDirect(@builtin(global_invocation_id) tid_73 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_2(tid_73);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadePrimaryLateDirect(@builtin(global_invocation_id) tid_74 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_1(tid_74);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn ShadeSecondaryLateDirect(@builtin(global_invocation_id) tid_75 : vec3<u32>)
{
    gTraversalCost_0 = u32(0);
    gRayCone_0 = _S897();
    gVTRandom_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRequest_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    ShadeImpl_0(tid_75);
    return;
}

