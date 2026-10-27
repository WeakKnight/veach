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

@binding(2) @group(0) var<storage, read> gTris_0 : array<vec4<f32>>;

@binding(6) @group(0) var<storage, read> gMaterialData_0 : array<vec4<u32>>;

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
     normal_0 : vec3<f32>,
     distribution_0 : GGXDistribution_0,
     coefficient_0 : BaseReflectionTransmission_0,
     eta_0 : vec3<f32>,
     throughput_0 : vec3<f32>,
};

struct DielectricMultipleScatteringLobe_0
{
     normal_1 : vec3<f32>,
     alpha_1 : f32,
     eta_1 : f32,
     reflectionScale_0 : vec3<f32>,
     transmissionScale_0 : vec3<f32>,
     reflectionRatio_0 : f32,
     energyComplementWo_0 : f32,
};

struct MetalMultipleScatteringLobe_0
{
     normal_2 : vec3<f32>,
     alpha_2 : f32,
     scale_0 : vec3<f32>,
     energyComplementWo_1 : f32,
};

struct DiffuseLobe_0
{
     normal_3 : vec3<f32>,
     albedo_0 : vec3<f32>,
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
     normal_4 : vec3<f32>,
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
     normal_4 : vec3<f32>,
     distribution_1 : GGXDistribution_0,
     coefficient_1 : DielectricReflection_0,
};

struct CoatLobe_0
{
     base_0 : BaseLobe_0,
     reflection_0 : MicrofacetReflectionLobe_1,
     normal_5 : vec3<f32>,
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

struct DiffuseSpecular_0
{
     diffuse_1 : vec3<f32>,
     specular_1 : vec3<f32>,
};

struct SampledLobe_0
{
     layer_0 : i32,
     lobe_1 : i32,
     f_0 : DiffuseSpecular_0,
     pdf_0 : f32,
};

fn DiffuseSpecular_x24init_0( diffuse_2 : vec3<f32>,  specular_2 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S8 : DiffuseSpecular_0;
    _S8.diffuse_1 = diffuse_2;
    _S8.specular_1 = specular_2;
    return _S8;
}

fn DiffuseSpecular_Zero_0() -> DiffuseSpecular_0
{
    var _S9 : vec3<f32> = vec3<f32>(0.0f);
    return DiffuseSpecular_x24init_0(_S9, _S9);
}

fn SampledLobe_None_0() -> SampledLobe_0
{
    var s_0 : SampledLobe_0;
    s_0.layer_0 = i32(0);
    s_0.lobe_1 = i32(-1);
    s_0.f_0 = DiffuseSpecular_Zero_0();
    s_0.pdf_0 = 0.0f;
    return s_0;
}

fn FuzzLobe_HasFuzz_0( this_0 : FuzzLobe_0) -> bool
{
    return ((this_0.presence_1) > 0.0f);
}

fn MaxComponent_0( v_0 : vec3<f32>) -> f32
{
    return max(v_0.x, max(v_0.y, v_0.z));
}

fn BaseLobeEnabled_0( index_0 : i32) -> bool
{
    return true;
}

fn BaseLobe_TotalWeight_0( this_1 : BaseLobe_0) -> f32
{
    var total_0 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        total_0 = this_1.weights_0[i32(0)];
    }
    else
    {
        total_0 = 0.0f;
    }
    if(BaseLobeEnabled_0(i32(1)))
    {
        total_0 = total_0 + this_1.weights_0[i32(1)];
    }
    if(BaseLobeEnabled_0(i32(2)))
    {
        total_0 = total_0 + this_1.weights_0[i32(2)];
    }
    if(BaseLobeEnabled_0(i32(3)))
    {
        total_0 = total_0 + this_1.weights_0[i32(3)];
    }
    if(BaseLobeEnabled_0(i32(4)))
    {
        total_0 = total_0 + this_1.weights_0[i32(4)];
    }
    if(BaseLobeEnabled_0(i32(5)))
    {
        total_0 = total_0 + this_1.weights_0[i32(5)];
    }
    return total_0;
}

fn BaseLobe_EstimateContribution_0( this_2 : BaseLobe_0,  wo_0 : vec3<f32>,  throughput_1 : vec3<f32>) -> f32
{
    return BaseLobe_TotalWeight_0(this_2);
}

fn CoatLobe_EstimateContribution_0( this_3 : CoatLobe_0,  wo_1 : vec3<f32>,  throughput_2 : vec3<f32>) -> f32
{
    var baseContribution_0 : f32 = BaseLobe_EstimateContribution_0(this_3.base_0, wo_1, throughput_2);
    if(this_3.inside_0)
    {
        return baseContribution_0;
    }
    return MaxComponent_0(throughput_2) * this_3.inReflected_0 + baseContribution_0 * MaxComponent_0(this_3.inBaseLayerScale_0);
}

fn FuzzLobe_BaseLayerScaleIncoming_0( this_4 : FuzzLobe_0) -> f32
{
    return 1.0f - this_4.viewReflected_0;
}

fn SafeDivide_0( numerator_0 : f32,  denominator_0 : f32,  fallback_0 : f32) -> f32
{
    var _S10 : f32;
    if(denominator_0 != 0.0f)
    {
        _S10 = numerator_0 / denominator_0;
    }
    else
    {
        _S10 = fallback_0;
    }
    return _S10;
}

fn FuzzLobe_SheenProbability_0( this_5 : FuzzLobe_0,  wo_2 : vec3<f32>) -> f32
{
    var sheenContribution_0 : f32 = this_5.viewReflected_0 * MaxComponent_0(this_5.tint_1);
    return SafeDivide_0(sheenContribution_0, sheenContribution_0 + CoatLobe_EstimateContribution_0(this_5.base_1, wo_2, vec3<f32>(1.0f)) * FuzzLobe_BaseLayerScaleIncoming_0(this_5), 0.5f);
}

fn FetchTable_0( x_3 : i32,  y_0 : i32,  slice_0 : i32) -> f32
{
    var _S11 : vec4<i32> = vec4<i32>(x_3, y_0, slice_0, i32(0));
    return (textureLoad((gBSDFTables_0), ((_S11)).xyz, ((_S11)).w).x);
}

fn FetchLTC_0( row_0 : i32,  col_0 : i32) -> vec3<f32>
{
    return vec3<f32>(FetchTable_0(col_0, row_0, i32(69)), FetchTable_0(col_0, row_0, i32(70)), FetchTable_0(col_0, row_0, i32(71)));
}

fn SheenLTCCoefficients_0( alpha_4 : f32,  cosTheta_0 : f32) -> vec3<f32>
{
    var row_1 : f32 = max(0.0f, min(alpha_4, 0.99999994039535522f)) * 31.0f;
    var col_1 : f32 = max(0.0f, min(cosTheta_0, 0.99999994039535522f)) * 31.0f;
    var r_0 : f32 = floor(row_1);
    var c_0 : f32 = floor(col_1);
    var ri_0 : i32 = i32(r_0);
    var ci_0 : i32 = i32(c_0);
    var _S12 : i32 = ci_0 + i32(1);
    var _S13 : vec3<f32> = vec3<f32>((col_1 - c_0));
    var _S14 : i32 = ri_0 + i32(1);
    return mix(mix(FetchLTC_0(ri_0, ci_0), FetchLTC_0(ri_0, _S12), _S13), mix(FetchLTC_0(_S14, ci_0), FetchLTC_0(_S14, _S12), _S13), vec3<f32>((row_1 - r_0)));
}

fn FuzzLobe_Coefficients_0( this_6 : FuzzLobe_0,  directionLocal_0 : vec3<f32>) -> vec3<f32>
{
    return SheenLTCCoefficients_0(this_6.alpha_3, directionLocal_0.z);
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn SampleCosineHemisphere_0( u_0 : vec2<f32>) -> vec3<f32>
{
    var phi_0 : f32 = 2.0f * float_getPi_0() * u_0.x;
    var _S15 : f32 = u_0.y;
    var sinTheta_0 : f32 = sqrt(1.0f - _S15);
    return vec3<f32>(sinTheta_0 * cos(phi_0), sinTheta_0 * sin(phi_0), sqrt(_S15));
}

fn SheenSampleLTC_0( ltc_0 : vec3<f32>,  u_1 : vec2<f32>) -> vec3<f32>
{
    var wiOriginal_0 : vec3<f32> = SampleCosineHemisphere_0(u_1);
    var a_0 : f32 = 1.0f / ltc_0.x;
    var _S16 : f32 = wiOriginal_0.z;
    return normalize(vec3<f32>(wiOriginal_0.x * a_0 - _S16 * ltc_0.y * a_0, wiOriginal_0.y * a_0, _S16));
}

fn SheenRotate_0( v_1 : vec3<f32>,  woXY_0 : vec2<f32>) -> vec3<f32>
{
    var r2_0 : f32 = dot(woXY_0, woXY_0);
    if(r2_0 == 0.0f)
    {
        return v_1;
    }
    var invR_0 : f32 = 1.0f / sqrt(r2_0);
    var sinPhi_0 : f32 = woXY_0.y * invR_0;
    var cosPhi_0 : f32 = woXY_0.x * invR_0;
    var _S17 : f32 = v_1.x;
    var _S18 : f32 = v_1.y;
    return vec3<f32>(cosPhi_0 * _S17 + sinPhi_0 * - _S18, cosPhi_0 * _S18 + sinPhi_0 * _S17, v_1.z);
}

fn Frame_ToWorld_0( this_7 : Frame_0,  v_2 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(v_2.x) * this_7.t_0 + vec3<f32>(v_2.y) * this_7.b_0 + vec3<f32>(v_2.z) * this_7.n_1;
}

fn ClampRemappedRandom_0( u_2 : f32) -> f32
{
    return min(u_2, 0.99999994039535522f);
}

fn CoatLobe_HasCoat_0( this_8 : CoatLobe_0) -> bool
{
    return ((this_8.presence_0) > 0.0f);
}

fn CoatLobe_ReflectionProbability_0( this_9 : CoatLobe_0,  wo_3 : vec3<f32>) -> f32
{
    return SafeDivide_0(this_9.inReflected_0, this_9.inReflected_0 + BaseLobe_EstimateContribution_0(this_9.base_0, wo_3, vec3<f32>(1.0f)) * MaxComponent_0(this_9.inBaseLayerScale_0), 0.5f);
}

struct LobeSample_0
{
     wi_0 : vec3<f32>,
     weight_0 : DiffuseSpecular_0,
     pdf_1 : f32,
     type_0 : u32,
     valid_0 : bool,
};

fn Frame_ToLocal_0( this_10 : Frame_0,  v_3 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(v_3, this_10.t_0), dot(v_3, this_10.b_0), dot(v_3, this_10.n_1));
}

fn SampleGGXVisibleNormal_0( alpha_5 : vec2<f32>,  wo_4 : vec3<f32>,  u_3 : vec2<f32>) -> vec3<f32>
{
    var toHemisphere_0 : vec3<f32> = vec3<f32>(alpha_5.x, alpha_5.y, 1.0f);
    var woHemisphere_0 : vec3<f32> = normalize(toHemisphere_0 * wo_4);
    var _S19 : f32 = min(woHemisphere_0.z, 1.0f);
    var angle_0 : f32 = 2.0f * float_getPi_0() * u_3.x;
    var onePlusCos_0 : f32 = 1.0f + _S19;
    var _S20 : f32 = u_3.y;
    var z_0 : f32 = (1.0f - _S20) * onePlusCos_0;
    var radius_0 : f32 = sqrt((z_0 + (1.0f - _S19)) * (_S20 * onePlusCos_0));
    return normalize(toHemisphere_0 * vec3<f32>(radius_0 * cos(angle_0) + woHemisphere_0.x, radius_0 * sin(angle_0) + woHemisphere_0.y, z_0));
}

fn GGXDistribution_SampleVisibleNormal_0( this_11 : GGXDistribution_0,  wo_5 : vec3<f32>,  u_4 : vec2<f32>) -> vec3<f32>
{
    return Frame_ToWorld_0(this_11.frame_1, SampleGGXVisibleNormal_0(this_11.alpha_0, Frame_ToLocal_0(this_11.frame_1, wo_5), u_4));
}

fn LobeSample_Invalid_0() -> LobeSample_0
{
    var s_1 : LobeSample_0;
    s_1.wi_0 = vec3<f32>(0.0f);
    s_1.weight_0 = DiffuseSpecular_Zero_0();
    s_1.pdf_1 = 0.0f;
    s_1.type_0 = u32(0);
    s_1.valid_0 = false;
    return s_1;
}

fn Square_0( x_4 : f32) -> f32
{
    return x_4 * x_4;
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

fn DielectricReflection_Reflection_0( this_12 : DielectricReflection_0,  idoth_0 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(this_12.eta_2, idoth_0));
}

fn SmithG1_0( v_4 : vec3<f32>,  alpha_6 : vec2<f32>) -> f32
{
    var vz2_0 : f32 = Square_0(v_4.z);
    if(vz2_0 == 0.0f)
    {
        return 0.0f;
    }
    return 2.0f / (1.0f + sqrt(1.0f + (Square_0(alpha_6.x * v_4.x) + Square_0(alpha_6.y * v_4.y)) / vz2_0));
}

fn GGXDistribution_G1_0( this_13 : GGXDistribution_0,  v_5 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_13.frame_1, v_5), this_13.alpha_0);
}

fn EvalGGX_0( m_0 : vec3<f32>,  alpha_7 : vec2<f32>) -> f32
{
    var _S21 : f32 = alpha_7.x;
    var _S22 : f32 = alpha_7.y;
    return 1.0f / (float_getPi_0() * _S21 * _S22 * Square_0(Square_0(m_0.x / _S21) + Square_0(m_0.y / _S22) + Square_0(m_0.z)));
}

fn GGXDistribution_D_0( this_14 : GGXDistribution_0,  m_1 : vec3<f32>) -> f32
{
    return EvalGGX_0(Frame_ToLocal_0(this_14.frame_1, m_1), this_14.alpha_0);
}

fn DiffuseSpecular_Specular_0( value_0 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(vec3<f32>(0.0f), value_0);
}

fn MicrofacetReflectionLobe_LobeType_0( this_15 : MicrofacetReflectionLobe_1) -> u32
{
    return u32(9);
}

fn LobeSample_Make_0( wi_1 : vec3<f32>,  weight_1 : DiffuseSpecular_0,  pdf_2 : f32,  type_1 : u32) -> LobeSample_0
{
    var s_2 : LobeSample_0;
    s_2.wi_0 = wi_1;
    s_2.weight_0 = weight_1;
    s_2.pdf_1 = pdf_2;
    s_2.type_0 = type_1;
    s_2.valid_0 = true;
    return s_2;
}

fn MicrofacetReflectionLobe_Sample_0( this_16 : MicrofacetReflectionLobe_1,  u_5 : vec3<f32>,  wo_6 : vec3<f32>) -> LobeSample_0
{
    var idotn_0 : f32 = dot(wo_6, this_16.normal_4);
    var h_0 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_16.distribution_1, wo_6, u_5.xy);
    var idoth_1 : f32 = dot(wo_6, h_0);
    if((idoth_1 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_2 : vec3<f32> = normalize((vec3<f32>(0) - wo_6) + h_0 * vec3<f32>(2.0f) * vec3<f32>(idoth_1));
    if(((idotn_0 * dot(this_16.normal_4, wi_2)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_0 : f32 = dot(wi_2, h_0);
    var f_1 : vec3<f32> = DielectricReflection_Reflection_0(this_16.coefficient_1, idoth_1);
    var gShadowing_0 : f32 = GGXDistribution_G1_0(this_16.distribution_1, wi_2);
    var d_0 : f32 = GGXDistribution_D_0(this_16.distribution_1, h_0);
    if((d_0 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_2, DiffuseSpecular_Specular_0(f_1 * vec3<f32>(gShadowing_0)), d_0 * GGXDistribution_G1_0(this_16.distribution_1, wo_6) * idoth_1 / (4.0f * odoth_0 * idotn_0), MicrofacetReflectionLobe_LobeType_0(this_16));
}

fn x2A_0( a_1 : DiffuseSpecular_0,  scale_1 : f32) -> DiffuseSpecular_0
{
    var _S23 : vec3<f32> = vec3<f32>(scale_1);
    return DiffuseSpecular_x24init_0(a_1.diffuse_1 * _S23, a_1.specular_1 * _S23);
}

fn SampledLobe_Make_0( layer_1 : i32,  lobe_2 : i32,  sample_0 : LobeSample_0) -> SampledLobe_0
{
    var s_3 : SampledLobe_0;
    s_3.layer_0 = layer_1;
    s_3.lobe_1 = lobe_2;
    s_3.f_0 = x2A_0(sample_0.weight_0, sample_0.pdf_1);
    s_3.pdf_0 = sample_0.pdf_1;
    return s_3;
}

fn BaseLobe_SelectLobe_0( this_17 : BaseLobe_0,  u_6 : ptr<function, f32>,  selectedWeight_0 : ptr<function, f32>,  totalWeight_0 : ptr<function, f32>) -> i32
{
    var weightSoFar_0 : f32;
    var _S24 : f32 = BaseLobe_TotalWeight_0(this_17);
    (*totalWeight_0) = _S24;
    if((_S24 <= 1.17549435082228751e-38f))
    {
        (*selectedWeight_0) = 0.0f;
        return i32(-1);
    }
    (*u_6) = (*u_6) * (*totalWeight_0);
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
                (*selectedWeight_0) = this_17.weights_0[i32(0)];
                if(((*u_6) < (this_17.weights_0[i32(0)])))
                {
                    (*u_6) = ClampRemappedRandom_0((*u_6) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_17.weights_0[i32(1)];
                if(((*u_6) < (weightSoFar_0 + this_17.weights_0[i32(1)])))
                {
                    (*u_6) = ClampRemappedRandom_0(((*u_6) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_17.weights_0[i32(2)];
                if(((*u_6) < (weightSoFar_0 + this_17.weights_0[i32(2)])))
                {
                    (*u_6) = ClampRemappedRandom_0(((*u_6) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_17.weights_0[i32(3)];
                if(((*u_6) < (weightSoFar_0 + this_17.weights_0[i32(3)])))
                {
                    (*u_6) = ClampRemappedRandom_0(((*u_6) - weightSoFar_0) / (*selectedWeight_0));
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
                (*selectedWeight_0) = this_17.weights_0[i32(4)];
                if(((*u_6) < (weightSoFar_0 + this_17.weights_0[i32(4)])))
                {
                    (*u_6) = ClampRemappedRandom_0(((*u_6) - weightSoFar_0) / (*selectedWeight_0));
                    return i32(4);
                }
                weightSoFar_0 = weightSoFar_0 + (*selectedWeight_0);
                break;
            }
            break;
        }
        break;
    }
    (*selectedWeight_0) = this_17.weights_0[i32(5)];
    (*u_6) = ClampRemappedRandom_0(((*u_6) - weightSoFar_0) / this_17.weights_0[i32(5)]);
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

fn BaseReflectionTransmission_ThinFilmPresenceAt_0( this_18 : BaseReflectionTransmission_0,  idoth_2 : f32) -> f32
{
    var _S25 : f32;
    if((idoth_2 >= 0.0f))
    {
        _S25 = this_18.thinFilmWeight_0 * ThinFilmPresence_0(this_18.thinFilmThickness_0);
    }
    else
    {
        _S25 = 0.0f;
    }
    return _S25;
}

fn FresnelDielectric_1( eta_4 : vec3<f32>,  cosThetaI_1 : f32) -> vec3<f32>
{
    return vec3<f32>(FresnelDielectric_0(eta_4.x, cosThetaI_1), FresnelDielectric_0(eta_4.y, cosThetaI_1), FresnelDielectric_0(eta_4.z, cosThetaI_1));
}

fn FifthPower_0( x_5 : f32) -> f32
{
    var xx_0 : f32 = x_5 * x_5;
    return xx_0 * xx_0 * x_5;
}

fn SixthPower_0( x_6 : f32) -> f32
{
    var xx_1 : f32 = x_6 * x_6;
    return xx_1 * xx_1 * xx_1;
}

fn MetalSchlickBFactor_0( f0_0 : vec3<f32>,  f82Tint_0 : vec3<f32>) -> vec3<f32>
{
    var _S26 : vec3<f32> = vec3<f32>(1.0f);
    return (f0_0 + (_S26 - f0_0) * vec3<f32>(FifthPower_0(0.8571428656578064f))) * (_S26 - f82Tint_0) * vec3<f32>((1.0f / (0.1428571492433548f * SixthPower_0(0.8571428656578064f))));
}

fn FresnelMetalF82_0( f0_1 : vec3<f32>,  f82Tint_1 : vec3<f32>,  cosTheta_1 : f32) -> vec3<f32>
{
    var oneMinusCos_0 : f32 = 1.0f - cosTheta_1;
    return saturate(f0_1 + (vec3<f32>(1.0f) - f0_1 - MetalSchlickBFactor_0(f0_1, f82Tint_1) * vec3<f32>(cosTheta_1) * vec3<f32>(oneMinusCos_0)) * vec3<f32>(FifthPower_0(oneMinusCos_0)));
}

fn BaseReflectionTransmission_HasDielectric_0( this_19 : BaseReflectionTransmission_0) -> bool
{
    var _S27 : vec3<f32> = vec3<f32>(0.0f);
    var _S28 : bool;
    if((any((((this_19.reflectionScaleTransparent_0) > _S27)))))
    {
        _S28 = true;
    }
    else
    {
        _S28 = (any((((this_19.reflectionScaleOpaque_0) > _S27))));
    }
    return _S28;
}

fn BaseReflectionTransmission_HasMetal_0( this_20 : BaseReflectionTransmission_0) -> bool
{
    return ((this_20.metalAmount_0) > 0.0f);
}

struct ThinFilmResults_0
{
     dielectric_0 : vec3<f32>,
     metal_0 : vec3<f32>,
};

struct Polarized_0
{
     s_4 : f32,
     p_0 : f32,
};

fn FresnelAmplitudesDielectric_0( cosThetaI_2 : f32,  etaI_0 : f32,  etaT_0 : f32,  r_1 : ptr<function, Polarized_0>,  t_1 : ptr<function, Polarized_0>,  cosThetaT_1 : ptr<function, f32>)
{
    var sinThetaT_0 : f32 = etaI_0 / etaT_0 * sqrt(saturate(1.0f - cosThetaI_2 * cosThetaI_2));
    if((sinThetaT_0 >= 1.0f))
    {
        (*r_1).s_4 = 1.0f;
        (*r_1).p_0 = 1.0f;
        (*t_1).s_4 = 0.0f;
        (*t_1).p_0 = 0.0f;
        (*cosThetaT_1) = 0.0f;
        return;
    }
    var _S29 : f32 = sqrt(saturate(1.0f - sinThetaT_0 * sinThetaT_0));
    (*cosThetaT_1) = _S29;
    var etaICosI_0 : f32 = etaI_0 * cosThetaI_2;
    var etaTCosT_0 : f32 = etaT_0 * _S29;
    var etaTCosI_0 : f32 = etaT_0 * cosThetaI_2;
    var etaICosT_0 : f32 = etaI_0 * _S29;
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
    (*r_1).s_4 = (etaICosI_0 - etaTCosT_0) * rcpS_0;
    (*r_1).p_0 = (etaTCosI_0 - etaICosT_0) * rcpP_0;
    var _S30 : f32 = 2.0f * etaICosI_0;
    (*t_1).s_4 = _S30 * rcpS_0;
    (*t_1).p_0 = _S30 * rcpP_0;
    return;
}

struct PolarizedComplex_0
{
     s_5 : vec2<f32>,
     p_1 : vec2<f32>,
};

fn ComplexDiv_0( a_2 : vec2<f32>,  b_1 : vec2<f32>,  minMagnitude_0 : f32,  fallback_1 : vec2<f32>) -> vec2<f32>
{
    var denominator_1 : f32 = dot(b_1, b_1);
    if((denominator_1 < (minMagnitude_0 * minMagnitude_0)))
    {
        return fallback_1;
    }
    var rcpDenominator_0 : f32 = 1.0f / denominator_1;
    var _S31 : f32 = a_2.x;
    var _S32 : f32 = b_1.x;
    var _S33 : f32 = a_2.y;
    var _S34 : f32 = b_1.y;
    return vec2<f32>((_S31 * _S32 + _S33 * _S34) * rcpDenominator_0, (_S33 * _S32 - _S31 * _S34) * rcpDenominator_0);
}

fn ComplexMul_0( a_3 : vec2<f32>,  b_2 : vec2<f32>) -> vec2<f32>
{
    var _S35 : f32 = a_3.x;
    var _S36 : f32 = b_2.x;
    var _S37 : f32 = a_3.y;
    var _S38 : f32 = b_2.y;
    return vec2<f32>(_S35 * _S36 - _S37 * _S38, _S35 * _S38 + _S37 * _S36);
}

fn SignNonZero_0( x_7 : f32) -> f32
{
    var _S39 : f32;
    if((x_7 >= 0.0f))
    {
        _S39 = 1.0f;
    }
    else
    {
        _S39 = -1.0f;
    }
    return _S39;
}

fn ComplexSqrt_0( z_1 : vec2<f32>) -> vec2<f32>
{
    var r_2 : f32 = length(z_1);
    var _S40 : f32 = z_1.x;
    return vec2<f32>(sqrt(max((r_2 + _S40) * 0.5f, 0.0f)), SignNonZero_0(z_1.y) * sqrt(max((r_2 - _S40) * 0.5f, 0.0f)));
}

fn RefractedCosine_0( cosThetaI_3 : f32,  etaI_1 : f32,  etaT_1 : vec2<f32>) -> vec2<f32>
{
    const _S41 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    var sinThetaT_1 : vec2<f32> = vec2<f32>(sqrt(saturate(1.0f - cosThetaI_3 * cosThetaI_3))) * ComplexDiv_0(vec2<f32>(etaI_1, 0.0f), etaT_1, 9.99999971718068537e-10f, _S41);
    var cosThetaT_2 : vec2<f32> = ComplexSqrt_0(_S41 - ComplexMul_0(sinThetaT_1, sinThetaT_1));
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
    var r_3 : PolarizedComplex_0;
    const _S42 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    r_3.s_5 = ComplexDiv_0(etaICosI_1 - etaTCosT_1, etaICosI_1 + etaTCosT_1, 9.99999971718068537e-10f, _S42);
    r_3.p_1 = ComplexDiv_0(etaTCosI_1 - etaICosT_1, etaTCosI_1 + etaICosT_1, 9.99999971718068537e-10f, _S42);
    return r_3;
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
    return 0.5f * (AiryReflectance_0(r12_1.s_4, t12_1.s_4, r21_1.s_4, t21_1.s_4, r23_1.s_5, expIPhi_1) + AiryReflectance_0(r12_1.p_0, t12_1.p_0, r21_1.p_0, t21_1.p_0, r23_1.p_1, expIPhi_1));
}

fn GulbrandsenIor_0( r_4 : f32,  g_0 : f32) -> vec2<f32>
{
    var clampedR_0 : f32 = clamp(r_4, 0.0f, 0.99000000953674316f);
    var sqrtR_0 : f32 = sqrt(clampedR_0);
    var _S43 : f32 = 1.0f - clampedR_0;
    var n_2 : f32 = mix((1.0f + sqrtR_0) / (1.0f - sqrtR_0), _S43 / (1.0f + clampedR_0), g_0);
    return vec2<f32>(n_2, sqrt(max((Square_0(n_2 + 1.0f) * clampedR_0 - Square_0(n_2 - 1.0f)) / _S43, 0.0f)));
}

fn ThinFilmAndBaseReflectance_0( cosThetaI_5 : f32,  etaExterior_0 : f32,  etaFilm_0 : f32,  etaBase_0 : vec3<f32>,  dispersion_0 : bool,  metalF0_1 : vec3<f32>,  metalF82Tint_1 : vec3<f32>,  enableDielectric_0 : bool,  enableMetal_0 : bool,  thickness_1 : f32,  wavelengths_1 : vec3<f32>) -> ThinFilmResults_0
{
    var results_0 : ThinFilmResults_0;
    var _S44 : vec3<f32> = vec3<f32>(0.0f);
    results_0.dielectric_0 = _S44;
    results_0.metal_0 = _S44;
    var _S45 : bool;
    if(enableDielectric_0)
    {
        _S45 = true;
    }
    else
    {
        _S45 = enableMetal_0;
    }
    if(!_S45)
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
    r21_2.s_4 = - r12_2.s_4;
    r21_2.p_0 = - r12_2.p_0;
    var t21Scale_0 : f32 = etaFilm_0 * cosThetaFilm_0 / (etaExterior_0 * max(cosThetaI_5, 9.99999971718068537e-10f));
    var t21_2 : Polarized_0;
    t21_2.s_4 = t12_2.s_4 * t21Scale_0;
    t21_2.p_0 = t12_2.p_0 * t21Scale_0;
    var _S46 : vec3<f32> = vec3<f32>((2.0f * float_getPi_0() * (2.0f * etaFilm_0 * thickness_1 * cosThetaFilm_0))) / wavelengths_1;
    var c_1 : i32;
    if(enableDielectric_0)
    {
        var r23_2 : array<PolarizedComplex_0, i32(3)>;
        c_1 = i32(0);
        loop
        {
            if((c_1 < i32(3)))
            {
            }
            else
            {
                break;
            }
            if(dispersion_0)
            {
                _S45 = true;
            }
            else
            {
                _S45 = c_1 == i32(0);
            }
            if(_S45)
            {
                r23_2[c_1] = FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, vec2<f32>(etaBase_0[c_1], 0.0f));
            }
            else
            {
                r23_2[c_1] = r23_2[i32(0)];
            }
            c_1 = c_1 + i32(1);
        }
        c_1 = i32(0);
        loop
        {
            if((c_1 < i32(3)))
            {
            }
            else
            {
                break;
            }
            results_0.dielectric_0[c_1] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, r23_2[c_1], _S46[c_1]);
            c_1 = c_1 + i32(1);
        }
    }
    if(enableMetal_0)
    {
        c_1 = i32(0);
        loop
        {
            if((c_1 < i32(3)))
            {
            }
            else
            {
                break;
            }
            results_0.metal_0[c_1] = ThinFilmReflectance_0(r12_2, t12_2, r21_2, t21_2, FresnelAmplitudesComplex_0(cosThetaFilm_0, etaFilm_0, GulbrandsenIor_0(metalF0_1[c_1], metalF82Tint_1[c_1])), _S46[c_1]);
            c_1 = c_1 + i32(1);
        }
    }
    return results_0;
}

fn BaseReflectionTransmission_ThinFilm_0( this_21 : BaseReflectionTransmission_0,  idoth_3 : f32,  enableDielectric_1 : bool,  enableMetal_1 : bool) -> ThinFilmResults_0
{
    return ThinFilmAndBaseReflectance_0(idoth_3, this_21.thinFilmExteriorIor_0, this_21.thinFilmIor_0, this_21.thinFilmInteriorIor_0, true, this_21.metalF0_0, this_21.metalF82Tint_0, enableDielectric_1, enableMetal_1, this_21.thinFilmThickness_0, this_21.wavelengths_0);
}

fn BaseReflectionTransmission_Coefficients_0( this_22 : BaseReflectionTransmission_0,  idoth_4 : f32) -> ReflectionTransmission_0
{
    var standardReflection_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_2 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_22, idoth_4);
    var standardReflection_1 : vec3<f32>;
    var standardTransmission_0 : vec3<f32>;
    if((presence_2 < 1.0f))
    {
        var fresnel_0 : vec3<f32> = FresnelDielectric_1(this_22.etaTransparent_0, idoth_4);
        var _S47 : vec3<f32> = this_22.transmission_0 * (vec3<f32>(1.0f) - fresnel_0);
        standardReflection_1 = this_22.reflectionScaleTransparent_0 * fresnel_0 + this_22.reflectionScaleOpaque_0 * FresnelDielectric_1(this_22.etaOpaque_0, idoth_4) + vec3<f32>(this_22.metalAmount_0) * FresnelMetalF82_0(this_22.metalF0_0, this_22.metalF82Tint_0, idoth_4);
        standardTransmission_0 = _S47;
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
        var film_0 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_22, idoth_4, BaseReflectionTransmission_HasDielectric_0(this_22), BaseReflectionTransmission_HasMetal_0(this_22));
        var _S48 : vec3<f32> = this_22.transmission_0 * (vec3<f32>(1.0f) - film_0.dielectric_0);
        thinFilmReflection_0 = this_22.reflectionScaleTransparent_0 * film_0.dielectric_0 + this_22.reflectionScaleOpaque_0 * film_0.dielectric_0 + vec3<f32>(this_22.metalAmount_0) * film_0.metal_0;
        thinFilmTransmission_0 = _S48;
    }
    else
    {
        thinFilmReflection_0 = standardReflection_0;
        thinFilmTransmission_0 = standardReflection_0;
    }
    var result_0 : ReflectionTransmission_0;
    var _S49 : vec3<f32> = vec3<f32>(presence_2);
    result_0.reflection_1 = mix(standardReflection_1, thinFilmReflection_0, _S49) + this_22.thinWallReflection_0;
    result_0.transmission_1 = mix(standardTransmission_0, thinFilmTransmission_0, _S49);
    result_0.reflectionProbability_0 = 0.0f;
    result_0.transmissionProbability_0 = 0.0f;
    return result_0;
}

fn ThroughputWeightedMax_0( throughput_3 : vec3<f32>,  color_1 : vec3<f32>) -> f32
{
    return MaxComponent_0(throughput_3 * color_1);
}

fn BaseReflectionTransmission_CoefficientsAndProbabilities_0( this_23 : BaseReflectionTransmission_0,  throughput_4 : vec3<f32>,  idoth_5 : f32) -> ReflectionTransmission_0
{
    var result_1 : ReflectionTransmission_0 = BaseReflectionTransmission_Coefficients_0(this_23, idoth_5);
    var reflectionMax_0 : f32 = ThroughputWeightedMax_0(throughput_4, result_1.reflection_1);
    var transmissionMax_0 : f32 = ThroughputWeightedMax_0(throughput_4, result_1.transmission_1);
    var sum_0 : f32 = reflectionMax_0 + transmissionMax_0;
    result_1.reflectionProbability_0 = SafeDivide_0(reflectionMax_0, sum_0, 0.0f);
    result_1.transmissionProbability_0 = SafeDivide_0(transmissionMax_0, sum_0, 0.0f);
    return result_1;
}

fn Sum_0( v_6 : vec3<f32>) -> f32
{
    return v_6.x + v_6.y + v_6.z;
}

fn SpecularLobe_ChannelProbabilities_0( this_24 : SpecularLobe_0) -> vec3<f32>
{
    return this_24.throughput_0 / vec3<f32>(Sum_0(this_24.throughput_0));
}

fn Refract_0( wi_3 : vec3<f32>,  n_3 : vec3<f32>,  cosThetaI_6 : f32,  eta_5 : f32,  wt_0 : ptr<function, vec3<f32>>) -> bool
{
    var invEta_0 : f32 = 1.0f / eta_5;
    var sin2ThetaT_1 : f32 = Square_0(invEta_0) * max(0.0f, 1.0f - Square_0(cosThetaI_6));
    if((sin2ThetaT_1 >= 1.0f))
    {
        (*wt_0) = vec3<f32>(0.0f);
        return false;
    }
    (*wt_0) = normalize((vec3<f32>(0) - wi_3) * vec3<f32>(invEta_0) + n_3 * vec3<f32>((invEta_0 * cosThetaI_6 - sqrt(1.0f - sin2ThetaT_1))));
    return true;
}

fn BaseReflectionTransmission_ReflectionProbability_0( this_25 : BaseReflectionTransmission_0,  throughput_5 : vec3<f32>,  idoth_6 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_25, throughput_5, idoth_6).reflectionProbability_0;
}

fn SpecularLobe_ValidTransmissionHalfVector_0( this_26 : SpecularLobe_0,  h_1 : vec3<f32>) -> bool
{
    var _S50 : f32 = this_26.eta_0.x;
    var _S51 : bool;
    if((_S50 >= 1.0f))
    {
        _S51 = ((dot(this_26.normal_0, h_1)) > 0.0f);
    }
    else
    {
        _S51 = false;
    }
    if(_S51)
    {
        _S51 = true;
    }
    else
    {
        if((_S50 < 1.0f))
        {
            _S51 = ((dot(this_26.normal_0, h_1)) < 0.0f);
        }
        else
        {
            _S51 = false;
        }
    }
    return _S51;
}

fn SpecularLobe_TransmissionTerms_0( this_27 : SpecularLobe_0,  wo_7 : vec3<f32>,  wi_4 : vec3<f32>,  idotn_1 : f32,  channelEta_0 : f32,  d_1 : ptr<function, f32>,  otherTerms_0 : ptr<function, f32>,  absIdoth_0 : ptr<function, f32>) -> bool
{
    (*d_1) = 0.0f;
    (*otherTerms_0) = 0.0f;
    (*absIdoth_0) = 0.0f;
    var h_2 : vec3<f32> = (vec3<f32>(0) - normalize(wo_7 + wi_4 * vec3<f32>(channelEta_0)));
    if(!SpecularLobe_ValidTransmissionHalfVector_0(this_27, h_2))
    {
        return false;
    }
    var idoth_7 : f32 = dot(wo_7, h_2);
    var odoth_1 : f32 = dot(wi_4, h_2);
    if(((idoth_7 * odoth_1) >= 0.0f))
    {
        return false;
    }
    (*d_1) = GGXDistribution_D_0(this_27.distribution_0, h_2);
    var _S52 : f32 = abs(idoth_7);
    (*otherTerms_0) = Square_0(channelEta_0) * _S52 * abs(odoth_1) / (Square_0(idoth_7 + channelEta_0 * odoth_1) * idotn_1);
    (*absIdoth_0) = _S52;
    return true;
}

fn BaseReflectionTransmission_TransmissionProbability_0( this_28 : BaseReflectionTransmission_0,  throughput_6 : vec3<f32>,  idoth_8 : f32) -> f32
{
    return BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_28, throughput_6, idoth_8).transmissionProbability_0;
}

fn SpecularLobe_Pdf_0( this_29 : SpecularLobe_0,  wo_8 : vec3<f32>,  wi_5 : vec3<f32>) -> f32
{
    var idotn_2 : f32 = dot(this_29.normal_0, wo_8);
    var _S53 : f32 = idotn_2 * dot(this_29.normal_0, wi_5);
    if((_S53 > 0.0f))
    {
        var h_3 : vec3<f32> = normalize(wo_8 + wi_5);
        var idoth_9 : f32 = dot(wo_8, h_3);
        var odoth_2 : f32 = dot(wi_5, h_3);
        if(((idoth_9 * odoth_2) < 0.0f))
        {
            return 0.0f;
        }
        return GGXDistribution_G1_0(this_29.distribution_0, wo_8) * (BaseReflectionTransmission_ReflectionProbability_0(this_29.coefficient_0, this_29.throughput_0, abs(idoth_9)) * GGXDistribution_D_0(this_29.distribution_0, h_3) * (idoth_9 / (4.0f * odoth_2 * idotn_2)));
    }
    if((_S53 >= 0.0f))
    {
        return 0.0f;
    }
    var d_2 : f32;
    var otherTerms_1 : f32;
    var absIdoth_1 : f32;
    var probabilityDOtherTerms_0 : vec3<f32>;
    var c_2 : i32 = i32(0);
    loop
    {
        if((c_2 < i32(3)))
        {
        }
        else
        {
            break;
        }
        var _S54 : bool = SpecularLobe_TransmissionTerms_0(this_29, wo_8, wi_5, idotn_2, this_29.eta_0[c_2], &(d_2), &(otherTerms_1), &(absIdoth_1));
        var _S55 : f32;
        if(_S54)
        {
            _S55 = BaseReflectionTransmission_TransmissionProbability_0(this_29.coefficient_0, this_29.throughput_0, absIdoth_1) * d_2 * otherTerms_1;
        }
        else
        {
            _S55 = 0.0f;
        }
        probabilityDOtherTerms_0[c_2] = _S55;
        c_2 = c_2 + i32(1);
    }
    return GGXDistribution_G1_0(this_29.distribution_0, wo_8) * dot(probabilityDOtherTerms_0, SpecularLobe_ChannelProbabilities_0(this_29));
}

fn BaseReflectionTransmission_Reflection_0( this_30 : BaseReflectionTransmission_0,  idoth_10 : f32) -> vec3<f32>
{
    var standard_0 : vec3<f32> = vec3<f32>(0.0f);
    var presence_3 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_30, idoth_10);
    var standard_1 : vec3<f32>;
    if((presence_3 < 1.0f))
    {
        standard_1 = this_30.reflectionScaleTransparent_0 * FresnelDielectric_1(this_30.etaTransparent_0, idoth_10) + this_30.reflectionScaleOpaque_0 * FresnelDielectric_1(this_30.etaOpaque_0, idoth_10) + vec3<f32>(this_30.metalAmount_0) * FresnelMetalF82_0(this_30.metalF0_0, this_30.metalF82Tint_0, idoth_10);
    }
    else
    {
        standard_1 = standard_0;
    }
    var thinFilm_0 : vec3<f32>;
    if((presence_3 > 0.0f))
    {
        var film_1 : ThinFilmResults_0 = BaseReflectionTransmission_ThinFilm_0(this_30, idoth_10, BaseReflectionTransmission_HasDielectric_0(this_30), BaseReflectionTransmission_HasMetal_0(this_30));
        thinFilm_0 = this_30.reflectionScaleTransparent_0 * film_1.dielectric_0 + this_30.reflectionScaleOpaque_0 * film_1.dielectric_0 + vec3<f32>(this_30.metalAmount_0) * film_1.metal_0;
    }
    else
    {
        thinFilm_0 = standard_0;
    }
    return mix(standard_1, thinFilm_0, vec3<f32>(presence_3)) + this_30.thinWallReflection_0;
}

fn GGXDistribution_G2_0( this_31 : GGXDistribution_0,  wo_9 : vec3<f32>,  wi_6 : vec3<f32>) -> f32
{
    return SmithG1_0(Frame_ToLocal_0(this_31.frame_1, wo_9), this_31.alpha_0) * SmithG1_0(Frame_ToLocal_0(this_31.frame_1, wi_6), this_31.alpha_0);
}

fn BaseReflectionTransmission_Transmission_0( this_32 : BaseReflectionTransmission_0,  idoth_11 : f32) -> vec3<f32>
{
    var standard_2 : vec3<f32> = vec3<f32>(0.0f);
    var presence_4 : f32 = BaseReflectionTransmission_ThinFilmPresenceAt_0(this_32, idoth_11);
    var standard_3 : vec3<f32>;
    if((presence_4 < 1.0f))
    {
        standard_3 = this_32.transmission_0 * (vec3<f32>(1.0f) - FresnelDielectric_1(this_32.etaTransparent_0, idoth_11));
    }
    else
    {
        standard_3 = standard_2;
    }
    var thinFilm_1 : vec3<f32>;
    if((presence_4 > 0.0f))
    {
        thinFilm_1 = this_32.transmission_0 * (vec3<f32>(1.0f) - BaseReflectionTransmission_ThinFilm_0(this_32, idoth_11, (any((((this_32.reflectionScaleTransparent_0) > standard_2)))), false).dielectric_0);
    }
    else
    {
        thinFilm_1 = standard_2;
    }
    return mix(standard_3, thinFilm_1, vec3<f32>(presence_4));
}

fn SpecularLobe_Eval_0( this_33 : SpecularLobe_0,  wo_10 : vec3<f32>,  wi_7 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_3 : f32 = dot(this_33.normal_0, wo_10);
    var _S56 : f32 = idotn_3 * dot(this_33.normal_0, wi_7);
    if((_S56 > 0.0f))
    {
        var h_4 : vec3<f32> = normalize(wo_10 + wi_7);
        return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_33.distribution_0, wo_10, wi_7)) * (vec3<f32>((GGXDistribution_D_0(this_33.distribution_0, h_4) * (1.0f / (4.0f * idotn_3)))) * BaseReflectionTransmission_Reflection_0(this_33.coefficient_0, abs(dot(wo_10, h_4)))));
    }
    if((_S56 >= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var dOtherTermsF_0 : vec3<f32>;
    var d_3 : f32;
    var otherTerms_2 : f32;
    var absIdoth_2 : f32;
    var c_3 : i32 = i32(0);
    loop
    {
        if((c_3 < i32(3)))
        {
        }
        else
        {
            break;
        }
        var _S57 : bool = SpecularLobe_TransmissionTerms_0(this_33, wo_10, wi_7, idotn_3, this_33.eta_0[c_3], &(d_3), &(otherTerms_2), &(absIdoth_2));
        var _S58 : f32;
        if(_S57)
        {
            _S58 = d_3 * otherTerms_2 * BaseReflectionTransmission_Transmission_0(this_33.coefficient_0, absIdoth_2)[c_3];
        }
        else
        {
            _S58 = 0.0f;
        }
        dOtherTermsF_0[c_3] = _S58;
        c_3 = c_3 + i32(1);
    }
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_33.distribution_0, wo_10, wi_7)) * dOtherTermsF_0);
}

fn SpecularLobe_Sample_0( this_34 : SpecularLobe_0,  u_7 : vec3<f32>,  wo_11 : vec3<f32>) -> LobeSample_0
{
    var idotn_4 : f32 = dot(wo_11, this_34.normal_0);
    var h_5 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_34.distribution_0, wo_11, u_7.xy);
    var idoth_12 : f32 = dot(wo_11, h_5);
    if((idoth_12 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var c_4 : ReflectionTransmission_0 = BaseReflectionTransmission_CoefficientsAndProbabilities_0(this_34.coefficient_0, this_34.throughput_0, idoth_12);
    if((c_4.reflectionProbability_0 + c_4.transmissionProbability_0) == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var _S59 : f32 = u_7.z;
    if((_S59 < (c_4.reflectionProbability_0)))
    {
        var wi_8 : vec3<f32> = normalize((vec3<f32>(0) - wo_11) + h_5 * vec3<f32>(2.0f) * vec3<f32>(idoth_12));
        if(((idotn_4 * dot(this_34.normal_0, wi_8)) <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        var odoth_3 : f32 = dot(wi_8, h_5);
        var weight_2 : DiffuseSpecular_0 = DiffuseSpecular_Specular_0(c_4.reflection_1 * vec3<f32>((1.0f / c_4.reflectionProbability_0)) * vec3<f32>(GGXDistribution_G1_0(this_34.distribution_0, wi_8)));
        var d_4 : f32 = GGXDistribution_D_0(this_34.distribution_0, h_5);
        if((d_4 <= 0.0f))
        {
            return LobeSample_Invalid_0();
        }
        return LobeSample_Make_0(wi_8, weight_2, c_4.reflectionProbability_0 * d_4 * GGXDistribution_G1_0(this_34.distribution_0, wo_11) * idoth_12 / (4.0f * odoth_3 * idotn_4), u32(9));
    }
    var remapped_0 : f32 = (_S59 - c_4.reflectionProbability_0) / c_4.transmissionProbability_0;
    var channelProbabilities_0 : vec3<f32> = SpecularLobe_ChannelProbabilities_0(this_34);
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
    var _S60 : bool = Refract_0(wo_11, h_5, idoth_12, this_34.eta_0[channel_0], &(wi_9));
    if(!_S60)
    {
        return LobeSample_Invalid_0();
    }
    if(((idotn_4 * dot(wi_9, this_34.normal_0)) >= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var pdf_3 : f32 = SpecularLobe_Pdf_0(this_34, wo_11, wi_9);
    if(pdf_3 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_9, x2A_0(SpecularLobe_Eval_0(this_34, wo_11, wi_9), 1.0f / pdf_3), pdf_3, u32(10));
}

fn DielectricMultipleScatteringLobe_Active_0( this_35 : DielectricMultipleScatteringLobe_0) -> bool
{
    return ((this_35.alpha_1) >= 0.0015999999595806003f);
}

fn BasisFromNormal_0( n_4 : vec3<f32>) -> Frame_0
{
    var _S61 : f32 = n_4.z;
    var s_6 : f32;
    if((_S61 < 0.0f))
    {
        s_6 = -1.0f;
    }
    else
    {
        s_6 = 1.0f;
    }
    var a_4 : f32 = -1.0f / (s_6 + _S61);
    var _S62 : f32 = n_4.x;
    var _S63 : f32 = n_4.y;
    var b_3 : f32 = _S62 * _S63 * a_4;
    var f_2 : Frame_0;
    f_2.n_1 = n_4;
    f_2.t_0 = vec3<f32>(b_3, s_6 + _S63 * _S63 * a_4, - _S63);
    f_2.b_0 = vec3<f32>(1.0f + s_6 * _S62 * _S62 * a_4, s_6 * b_3, - s_6 * _S62);
    return f_2;
}

fn UniformHemisphereDirection_0( basis_1 : Frame_0,  z_2 : f32,  u_8 : f32) -> vec3<f32>
{
    var horizontal_0 : f32 = sqrt(1.0f - Square_0(z_2));
    var azimuth_0 : f32 = 2.0f * float_getPi_0() * u_8;
    return Frame_ToWorld_0(basis_1, vec3<f32>(cos(azimuth_0) * horizontal_0, sin(azimuth_0) * horizontal_0, z_2));
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

fn CosToExactIndex_0( cosTheta_2 : f32) -> f32
{
    return cosTheta_2 * 31.0f;
}

fn ClampExactIndex_0( index_1 : f32) -> f32
{
    return clamp(index_1, 0.0f, 31.0f);
}

fn FetchEnergy_0( x_8 : i32,  y_1 : i32,  slice_1 : i32) -> f32
{
    return FetchTable_0(x_8, y_1, slice_1) * 1.5259021893143654e-05f;
}

fn LookUpTrilinear_0( firstSlice_0 : i32,  exactX_0 : f32,  exactY_0 : f32,  exactZ_0 : f32) -> f32
{
    var x_9 : f32 = ClampExactIndex_0(exactX_0);
    var y_2 : f32 = ClampExactIndex_0(exactY_0);
    var z_3 : f32 = ClampExactIndex_0(exactZ_0);
    var ix0_0 : i32 = i32(floor(x_9));
    var iy0_0 : i32 = i32(floor(y_2));
    var iz0_0 : i32 = i32(floor(z_3));
    var _S64 : i32 = min(iy0_0 + i32(1), i32(31));
    var _S65 : i32 = min(iz0_0 + i32(1), i32(31));
    var tx_0 : f32 = x_9 - f32(ix0_0);
    var ty_0 : f32 = y_2 - f32(iy0_0);
    var _S66 : i32 = firstSlice_0 + ix0_0;
    var _S67 : i32 = firstSlice_0 + min(ix0_0 + i32(1), i32(31));
    return mix(mix(mix(FetchEnergy_0(iz0_0, iy0_0, _S66), FetchEnergy_0(iz0_0, iy0_0, _S67), tx_0), mix(FetchEnergy_0(iz0_0, _S64, _S66), FetchEnergy_0(iz0_0, _S64, _S67), tx_0), ty_0), mix(mix(FetchEnergy_0(_S65, iy0_0, _S66), FetchEnergy_0(_S65, iy0_0, _S67), tx_0), mix(FetchEnergy_0(_S65, _S64, _S66), FetchEnergy_0(_S65, _S64, _S67), tx_0), ty_0), z_3 - f32(iz0_0));
}

fn IdealDielectricEnergyComplement_0( ior_1 : f32,  alpha_9 : f32,  cosTheta_3 : f32) -> f32
{
    return LookUpTrilinear_0(i32(0), IorToExactIndex_0(ior_1), AlphaToExactIndex_0(alpha_9), CosToExactIndex_0(cosTheta_3));
}

fn LookUpBilinear_0( slice_2 : i32,  exactX_1 : f32,  exactY_1 : f32) -> f32
{
    var x_10 : f32 = ClampExactIndex_0(exactX_1);
    var y_3 : f32 = ClampExactIndex_0(exactY_1);
    var ix0_1 : i32 = i32(floor(x_10));
    var iy0_1 : i32 = i32(floor(y_3));
    var _S68 : i32 = min(ix0_1 + i32(1), i32(31));
    var _S69 : i32 = min(iy0_1 + i32(1), i32(31));
    var tx_1 : f32 = x_10 - f32(ix0_1);
    return mix(mix(FetchEnergy_0(iy0_1, ix0_1, slice_2), FetchEnergy_0(iy0_1, _S68, slice_2), tx_1), mix(FetchEnergy_0(_S69, ix0_1, slice_2), FetchEnergy_0(_S69, _S68, slice_2), tx_1), y_3 - f32(iy0_1));
}

fn IdealDielectricAverageEnergyComplement_0( ior_2 : f32,  alpha_10 : f32) -> f32
{
    return LookUpBilinear_0(i32(64), IorToExactIndex_0(ior_2), AlphaToExactIndex_0(alpha_10));
}

fn ClampAverageEnergyComplement_0( value_1 : f32) -> f32
{
    return max(value_1, 9.999999960041972e-13f);
}

fn DielectricMultipleScatteringLobe_TabulatedFactors_0( this_36 : DielectricMultipleScatteringLobe_0,  odotn_0 : f32,  includeRatio_0 : bool) -> f32
{
    var iorToUse_0 : f32;
    var _S70 : f32;
    var ratio_0 : f32;
    if((odotn_0 <= 0.0f))
    {
        var _S71 : f32 = - odotn_0;
        var _S72 : f32 = 1.0f - this_36.reflectionRatio_0;
        iorToUse_0 = 1.0f / this_36.eta_1;
        _S70 = _S71;
        ratio_0 = _S72;
    }
    else
    {
        iorToUse_0 = this_36.eta_1;
        _S70 = odotn_0;
        ratio_0 = this_36.reflectionRatio_0;
    }
    var factors_0 : f32 = this_36.energyComplementWo_0 * IdealDielectricEnergyComplement_0(iorToUse_0, this_36.alpha_1, _S70) / ClampAverageEnergyComplement_0(IdealDielectricAverageEnergyComplement_0(iorToUse_0, this_36.alpha_1));
    var factors_1 : f32;
    if(includeRatio_0)
    {
        factors_1 = factors_0 * ratio_0;
    }
    else
    {
        factors_1 = factors_0;
    }
    return min(factors_1, SafeDivide_0(1.0f, _S70, 0.0f));
}

fn DielectricMultipleScatteringLobe_Sample_0( this_37 : DielectricMultipleScatteringLobe_0,  u_9 : vec3<f32>,  wo_12 : vec3<f32>) -> LobeSample_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_37))
    {
        return LobeSample_Invalid_0();
    }
    var ux_0 : f32 = u_9.x;
    var z_4 : f32;
    if((ux_0 < (this_37.reflectionRatio_0)))
    {
        z_4 = ClampRemappedRandom_0(ux_0 / this_37.reflectionRatio_0);
    }
    else
    {
        z_4 = - ClampRemappedRandom_0((ux_0 - this_37.reflectionRatio_0) / (1.0f - this_37.reflectionRatio_0));
    }
    var wi_10 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_37.normal_1), z_4, u_9.y);
    var odotn_1 : f32 = dot(wi_10, this_37.normal_1);
    var unscaledWeight_0 : f32 = 2.0f * abs(odotn_1) * DielectricMultipleScatteringLobe_TabulatedFactors_0(this_37, odotn_1, false);
    if((odotn_1 > 0.0f))
    {
        return LobeSample_Make_0(wi_10, DiffuseSpecular_Specular_0(this_37.reflectionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * this_37.reflectionRatio_0, u32(9));
    }
    return LobeSample_Make_0(wi_10, DiffuseSpecular_Specular_0(this_37.transmissionScale_0 * vec3<f32>(unscaledWeight_0)), 0.5f / float_getPi_0() * (1.0f - this_37.reflectionRatio_0), u32(10));
}

fn MetalMultipleScatteringLobe_Active_0( this_38 : MetalMultipleScatteringLobe_0) -> bool
{
    return ((this_38.alpha_2) >= 0.0015999999595806003f);
}

fn IdealMetalEnergyComplement_0( alpha_11 : f32,  cosTheta_4 : f32) -> f32
{
    return LookUpBilinear_0(i32(67), AlphaToExactIndex_0(alpha_11), CosToExactIndex_0(cosTheta_4));
}

fn LookUpLinear_0( slice_3 : i32,  exactX_2 : f32) -> f32
{
    var x_11 : f32 = ClampExactIndex_0(exactX_2);
    var i0_0 : i32 = i32(floor(x_11));
    return mix(FetchEnergy_0(i0_0, i32(0), slice_3), FetchEnergy_0(min(i0_0 + i32(1), i32(31)), i32(0), slice_3), x_11 - f32(i0_0));
}

fn IdealMetalAverageEnergyComplement_0( alpha_12 : f32) -> f32
{
    return LookUpLinear_0(i32(68), AlphaToExactIndex_0(alpha_12));
}

fn MetalMultipleScatteringLobe_TabulatedFactors_0( this_39 : MetalMultipleScatteringLobe_0,  odotn_2 : f32) -> f32
{
    return min(this_39.energyComplementWo_1 * IdealMetalEnergyComplement_0(this_39.alpha_2, odotn_2) / ClampAverageEnergyComplement_0(IdealMetalAverageEnergyComplement_0(this_39.alpha_2)), SafeDivide_0(1.0f, odotn_2, 0.0f));
}

fn MetalMultipleScatteringLobe_LobeType_0( this_40 : MetalMultipleScatteringLobe_0) -> u32
{
    return u32(9);
}

fn MetalMultipleScatteringLobe_Sample_0( this_41 : MetalMultipleScatteringLobe_0,  u_10 : vec3<f32>,  wo_13 : vec3<f32>) -> LobeSample_0
{
    if(!MetalMultipleScatteringLobe_Active_0(this_41))
    {
        return LobeSample_Invalid_0();
    }
    var wi_11 : vec3<f32> = UniformHemisphereDirection_0(BasisFromNormal_0(this_41.normal_2), u_10.x, u_10.y);
    var odotn_3 : f32 = dot(wi_11, this_41.normal_2);
    return LobeSample_Make_0(wi_11, DiffuseSpecular_Specular_0(this_41.scale_0 * vec3<f32>((2.0f * odotn_3 * MetalMultipleScatteringLobe_TabulatedFactors_0(this_41, odotn_3)))), 0.5f / float_getPi_0(), MetalMultipleScatteringLobe_LobeType_0(this_41));
}

fn FONAlbedo_0( mu_0 : f32,  roughness_1 : f32) -> f32
{
    var mucomp_0 : f32 = 1.0f - mu_0;
    return (1.0f + roughness_1 * (mucomp_0 * (0.057108528912067413f + mucomp_0 * (0.49188187718391418f + mucomp_0 * (-0.33218145370483398f + mucomp_0 * 0.071442998945713043f))))) / (1.0f + (0.5f - 2.0f / (3.0f * float_getPi_0())) * roughness_1);
}

fn EvalEON_0( rho_0 : vec3<f32>,  roughness_2 : f32,  viewLocal_0 : vec3<f32>,  lightLocal_0 : vec3<f32>) -> vec3<f32>
{
    var muI_0 : f32 = viewLocal_0.z;
    var muO_0 : f32 = lightLocal_0.z;
    var s_7 : f32 = dot(viewLocal_0, lightLocal_0) - muI_0 * muO_0;
    var sOverT_0 : f32;
    if((s_7 > 0.0f))
    {
        sOverT_0 = s_7 / max(muI_0, muO_0);
    }
    else
    {
        sOverT_0 = s_7;
    }
    var PI_0 : f32 = float_getPi_0();
    var aF_0 : f32 = 1.0f / (1.0f + (0.5f - 2.0f / (3.0f * PI_0)) * roughness_2);
    var averageEF_0 : f32 = aF_0 * (1.0f + (0.66666668653488159f - 28.0f / (15.0f * PI_0)) * roughness_2);
    var _S73 : f32 = 1.0f - averageEF_0;
    return rho_0 * vec3<f32>((1.0f / PI_0)) * vec3<f32>(aF_0) * vec3<f32>((1.0f + roughness_2 * sOverT_0)) + rho_0 * rho_0 * vec3<f32>(averageEF_0) / (vec3<f32>(1.0f) - rho_0 * vec3<f32>(_S73)) * vec3<f32>((1.0f / PI_0)) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muO_0, roughness_2))) * vec3<f32>(max(1.00000001168609742e-07f, 1.0f - FONAlbedo_0(muI_0, roughness_2))) / vec3<f32>(max(1.00000001168609742e-07f, _S73));
}

fn F0FromIor_0( eta_6 : f32) -> f32
{
    return Square_0((eta_6 - 1.0f) / (eta_6 + 1.0f));
}

fn ExtrapolateBeyondIorMax_0( tableValue_0 : f32,  ior_3 : f32) -> f32
{
    var _S74 : bool;
    if((ior_3 > 2.5f))
    {
        _S74 = true;
    }
    else
    {
        _S74 = (ior_3 < 0.40000000596046448f);
    }
    if(_S74)
    {
        var F0_MAX_0 : f32 = F0FromIor_0(2.5f);
        return (1.0f - (F0FromIor_0(ior_3) - F0_MAX_0) * (1.0f / (1.0f - F0_MAX_0))) * tableValue_0;
    }
    return tableValue_0;
}

fn OpaqueDielectricEnergyComplement_0( ior_4 : f32,  alpha_13 : f32,  cosTheta_5 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpTrilinear_0(i32(32), IorToExactIndex_0(ior_4), AlphaToExactIndex_0(alpha_13), CosToExactIndex_0(cosTheta_5)), ior_4);
}

fn DiffuseLobe_BRDFLocal_0( this_42 : DiffuseLobe_0,  woLocal_1 : vec3<f32>,  wiLocal_0 : vec3<f32>) -> vec3<f32>
{
    return EvalEON_0(this_42.albedo_0, this_42.roughness_0, woLocal_1, wiLocal_0) * vec3<f32>((this_42.specularCompensation_0 * OpaqueDielectricEnergyComplement_0(this_42.specularEta_0, this_42.specularAlpha_0, wiLocal_0.z)));
}

fn DiffuseSpecular_Diffuse_0( value_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(value_2, vec3<f32>(0.0f));
}

fn DiffuseLobe_LobeType_0( this_43 : DiffuseLobe_0) -> u32
{
    return u32(5);
}

fn DiffuseLobe_Sample_0( this_44 : DiffuseLobe_0,  u_11 : vec3<f32>,  wo_14 : vec3<f32>) -> LobeSample_0
{
    var wiLocal_1 : vec3<f32> = SampleCosineHemisphere_0(u_11.xy);
    var cosOut_0 : f32 = wiLocal_1.z;
    if(cosOut_0 == 0.0f)
    {
        return LobeSample_Invalid_0();
    }
    var basis_2 : Frame_0 = BasisFromNormal_0(this_44.normal_3);
    var PI_1 : f32 = float_getPi_0();
    return LobeSample_Make_0(Frame_ToWorld_0(basis_2, wiLocal_1), DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_44, Frame_ToLocal_0(basis_2, wo_14), wiLocal_1) * vec3<f32>(PI_1)), cosOut_0 * (1.0f / PI_1), DiffuseLobe_LobeType_0(this_44));
}

fn MicrofacetReflectionLobe_GetNormal_0( this_45 : MicrofacetReflectionLobe_0) -> vec3<f32>
{
    return this_45.normal_4;
}

fn ConstantReflection_Reflection_0( this_46 : ConstantReflection_0,  idoth_13 : f32) -> vec3<f32>
{
    return this_46.color_0;
}

fn MicrofacetReflectionLobe_LobeType_1( this_47 : MicrofacetReflectionLobe_0) -> u32
{
    return u32(9);
}

fn MicrofacetReflectionLobe_Sample_1( this_48 : MicrofacetReflectionLobe_0,  u_12 : vec3<f32>,  wo_15 : vec3<f32>) -> LobeSample_0
{
    var idotn_5 : f32 = dot(wo_15, this_48.normal_4);
    var h_6 : vec3<f32> = GGXDistribution_SampleVisibleNormal_0(this_48.distribution_1, wo_15, u_12.xy);
    var idoth_14 : f32 = dot(wo_15, h_6);
    if((idoth_14 < 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var wi_12 : vec3<f32> = normalize((vec3<f32>(0) - wo_15) + h_6 * vec3<f32>(2.0f) * vec3<f32>(idoth_14));
    if(((idotn_5 * dot(this_48.normal_4, wi_12)) <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    var odoth_4 : f32 = dot(wi_12, h_6);
    var f_3 : vec3<f32> = ConstantReflection_Reflection_0(this_48.coefficient_1, idoth_14);
    var gShadowing_1 : f32 = GGXDistribution_G1_0(this_48.distribution_1, wi_12);
    var d_5 : f32 = GGXDistribution_D_0(this_48.distribution_1, h_6);
    if((d_5 <= 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_12, DiffuseSpecular_Specular_0(f_3 * vec3<f32>(gShadowing_1)), d_5 * GGXDistribution_G1_0(this_48.distribution_1, wo_15) * idoth_14 / (4.0f * odoth_4 * idotn_5), MicrofacetReflectionLobe_LobeType_1(this_48));
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

fn FlippedLobe_Sample_0( this_49 : FlippedLobe_0,  u_13 : vec3<f32>,  wo_16 : vec3<f32>) -> LobeSample_0
{
    var s_8 : LobeSample_0 = MicrofacetReflectionLobe_Sample_1(this_49.lobe_0, u_13, reflect(wo_16, MicrofacetReflectionLobe_GetNormal_0(this_49.lobe_0)));
    s_8.type_0 = SwapReflectionTransmission_0(s_8.type_0);
    return s_8;
}

fn DiffuseLobe_GetNormal_0( this_50 : DiffuseLobe_0) -> vec3<f32>
{
    return this_50.normal_3;
}

fn FlippedLobe_Sample_1( this_51 : FlippedLobe_1,  u_14 : vec3<f32>,  wo_17 : vec3<f32>) -> LobeSample_0
{
    var s_9 : LobeSample_0 = DiffuseLobe_Sample_0(this_51.lobe_0, u_14, reflect(wo_17, DiffuseLobe_GetNormal_0(this_51.lobe_0)));
    s_9.type_0 = SwapReflectionTransmission_0(s_9.type_0);
    return s_9;
}

fn BaseLobe_LobeSampleAt_0( this_52 : BaseLobe_0,  index_2 : i32,  u_15 : vec3<f32>,  wo_18 : vec3<f32>) -> LobeSample_0
{
    switch(index_2)
    {
    case i32(0):
        {
            return SpecularLobe_Sample_0(this_52.specular_0, u_15, wo_18);
        }
    case i32(1):
        {
            return DielectricMultipleScatteringLobe_Sample_0(this_52.dielectricMultipleScattering_0, u_15, wo_18);
        }
    case i32(2):
        {
            return MetalMultipleScatteringLobe_Sample_0(this_52.metalMultipleScattering_0, u_15, wo_18);
        }
    case i32(3):
        {
            return DiffuseLobe_Sample_0(this_52.diffuse_0, u_15, wo_18);
        }
    case i32(4):
        {
            return FlippedLobe_Sample_0(this_52.thinWallSpecularTransmission_0, u_15, wo_18);
        }
    default :
        {
            return FlippedLobe_Sample_1(this_52.thinWallDiffuseTransmission_0, u_15, wo_18);
        }
    }
}

fn BaseLobe_SampleLobe_0( this_53 : BaseLobe_0,  u_16 : vec3<f32>,  wo_19 : vec3<f32>,  wi_13 : ptr<function, vec3<f32>>,  type_3 : ptr<function, u32>,  sampled_0 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_13) = vec3<f32>(0.0f);
    (*type_3) = u32(0);
    (*sampled_0) = SampledLobe_None_0();
    var ux_1 : f32 = u_16.x;
    var selectedWeight_1 : f32;
    var totalWeight_1 : f32;
    var selected_0 : i32 = BaseLobe_SelectLobe_0(this_53, &(ux_1), &(selectedWeight_1), &(totalWeight_1));
    if((selected_0 < i32(0)))
    {
        return false;
    }
    var s_10 : LobeSample_0 = BaseLobe_LobeSampleAt_0(this_53, selected_0, vec3<f32>(ux_1, u_16.y, u_16.z), wo_19);
    (*wi_13) = s_10.wi_0;
    (*type_3) = s_10.type_0;
    (*sampled_0) = SampledLobe_Make_0(i32(1), selected_0, s_10);
    return s_10.valid_0;
}

fn CoatLobe_SampleLobe_0( this_54 : CoatLobe_0,  u_17 : vec3<f32>,  wo_20 : vec3<f32>,  wi_14 : ptr<function, vec3<f32>>,  type_4 : ptr<function, u32>,  sampled_1 : ptr<function, SampledLobe_0>) -> bool
{
    var _S75 : bool = !this_54.inside_0;
    var _S76 : bool;
    if(_S75)
    {
        _S76 = CoatLobe_HasCoat_0(this_54);
    }
    else
    {
        _S76 = false;
    }
    var coatProbability_0 : f32;
    if(_S76)
    {
        coatProbability_0 = CoatLobe_ReflectionProbability_0(this_54, wo_20);
    }
    else
    {
        coatProbability_0 = 0.0f;
    }
    var ux_2 : f32 = u_17.x;
    if(_S75)
    {
        _S76 = (ux_2 < coatProbability_0);
    }
    else
    {
        _S76 = false;
    }
    if(_S76)
    {
        var s_11 : LobeSample_0 = MicrofacetReflectionLobe_Sample_0(this_54.reflection_0, vec3<f32>(ClampRemappedRandom_0(ux_2 * (1.0f / coatProbability_0)), u_17.y, u_17.z), wo_20);
        (*wi_14) = s_11.wi_0;
        (*type_4) = s_11.type_0;
        (*sampled_1) = SampledLobe_Make_0(i32(2), i32(0), s_11);
        return s_11.valid_0;
    }
    var ux_3 : f32;
    if(_S75)
    {
        ux_3 = ClampRemappedRandom_0((ux_2 - coatProbability_0) * (1.0f / (1.0f - coatProbability_0)));
    }
    else
    {
        ux_3 = ux_2;
    }
    var _S77 : bool = BaseLobe_SampleLobe_0(this_54.base_0, vec3<f32>(ux_3, u_17.y, u_17.z), wo_20, &((*wi_14)), &((*type_4)), &((*sampled_1)));
    return _S77;
}

fn FuzzLobe_SampleLobe_0( this_55 : FuzzLobe_0,  u_18 : vec3<f32>,  wo_21 : vec3<f32>,  wi_15 : ptr<function, vec3<f32>>,  type_5 : ptr<function, u32>,  sampled_2 : ptr<function, SampledLobe_0>) -> bool
{
    (*wi_15) = vec3<f32>(0.0f);
    (*type_5) = u32(9);
    (*sampled_2) = SampledLobe_None_0();
    var sheenProbability_0 : f32;
    if(FuzzLobe_HasFuzz_0(this_55))
    {
        sheenProbability_0 = FuzzLobe_SheenProbability_0(this_55, wo_21);
    }
    else
    {
        sheenProbability_0 = 0.0f;
    }
    var _S78 : f32 = u_18.x;
    if((_S78 < sheenProbability_0))
    {
        var _S79 : f32 = this_55.woLocal_0.z;
        if((_S79 <= 0.0f))
        {
            return false;
        }
        var wiLocal_2 : vec3<f32> = SheenRotate_0(SheenSampleLTC_0(FuzzLobe_Coefficients_0(this_55, this_55.woLocal_0), u_18.yz), this_55.woLocal_0.xy);
        if(((_S79 * wiLocal_2.z) <= 0.0f))
        {
            return false;
        }
        (*wi_15) = normalize(Frame_ToWorld_0(this_55.basis_0, wiLocal_2));
        return true;
    }
    var _S80 : bool = CoatLobe_SampleLobe_0(this_55.base_1, vec3<f32>(ClampRemappedRandom_0((_S78 - sheenProbability_0) * (1.0f / (1.0f - sheenProbability_0))), u_18.y, u_18.z), wo_21, &((*wi_15)), &((*type_5)), &((*sampled_2)));
    return _S80;
}

fn BaseLobe_IsActive_0( this_56 : BaseLobe_0,  index_3 : i32) -> bool
{
    var _S81 : bool;
    if(BaseLobeEnabled_0(index_3))
    {
        _S81 = ((this_56.weights_0[index_3]) > 0.0f);
    }
    else
    {
        _S81 = false;
    }
    return _S81;
}

fn DielectricMultipleScatteringLobe_Eval_0( this_57 : DielectricMultipleScatteringLobe_0,  wo_22 : vec3<f32>,  wi_16 : vec3<f32>) -> DiffuseSpecular_0
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_57))
    {
        return DiffuseSpecular_Zero_0();
    }
    var odotn_4 : f32 = dot(wi_16, this_57.normal_1);
    var unscaledCos_0 : f32 = DielectricMultipleScatteringLobe_TabulatedFactors_0(this_57, odotn_4, true) * (1.0f / float_getPi_0()) * abs(odotn_4);
    var _S82 : vec3<f32>;
    if((odotn_4 > 0.0f))
    {
        _S82 = this_57.reflectionScale_0;
    }
    else
    {
        _S82 = this_57.transmissionScale_0;
    }
    return DiffuseSpecular_Specular_0(_S82 * vec3<f32>(unscaledCos_0));
}

fn DielectricMultipleScatteringLobe_Pdf_0( this_58 : DielectricMultipleScatteringLobe_0,  wo_23 : vec3<f32>,  wi_17 : vec3<f32>) -> f32
{
    if(!DielectricMultipleScatteringLobe_Active_0(this_58))
    {
        return 0.0f;
    }
    var _S83 : f32;
    if(((dot(wi_17, this_58.normal_1)) > 0.0f))
    {
        _S83 = this_58.reflectionRatio_0;
    }
    else
    {
        _S83 = 1.0f - this_58.reflectionRatio_0;
    }
    return 0.5f / float_getPi_0() * _S83;
}

fn MetalMultipleScatteringLobe_Eval_0( this_59 : MetalMultipleScatteringLobe_0,  wo_24 : vec3<f32>,  wi_18 : vec3<f32>) -> DiffuseSpecular_0
{
    var odotn_5 : f32 = dot(wi_18, this_59.normal_2);
    var _S84 : bool;
    if(!MetalMultipleScatteringLobe_Active_0(this_59))
    {
        _S84 = true;
    }
    else
    {
        _S84 = (odotn_5 <= 0.0f);
    }
    if(_S84)
    {
        return DiffuseSpecular_Zero_0();
    }
    return DiffuseSpecular_Specular_0(this_59.scale_0 * vec3<f32>((MetalMultipleScatteringLobe_TabulatedFactors_0(this_59, odotn_5) * (1.0f / float_getPi_0()) * odotn_5)));
}

fn MetalMultipleScatteringLobe_Pdf_0( this_60 : MetalMultipleScatteringLobe_0,  wo_25 : vec3<f32>,  wi_19 : vec3<f32>) -> f32
{
    var _S85 : bool;
    if(MetalMultipleScatteringLobe_Active_0(this_60))
    {
        _S85 = ((dot(wi_19, this_60.normal_2)) > 0.0f);
    }
    else
    {
        _S85 = false;
    }
    var _S86 : f32;
    if(_S85)
    {
        _S86 = 0.5f / float_getPi_0();
    }
    else
    {
        _S86 = 0.0f;
    }
    return _S86;
}

fn DiffuseLobe_Eval_0( this_61 : DiffuseLobe_0,  wo_26 : vec3<f32>,  wi_20 : vec3<f32>) -> DiffuseSpecular_0
{
    var cosOut_1 : f32 = dot(wi_20, this_61.normal_3);
    if((cosOut_1 <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var basis_3 : Frame_0 = BasisFromNormal_0(this_61.normal_3);
    return DiffuseSpecular_Diffuse_0(DiffuseLobe_BRDFLocal_0(this_61, Frame_ToLocal_0(basis_3, wo_26), Frame_ToLocal_0(basis_3, wi_20)) * vec3<f32>(cosOut_1));
}

fn DiffuseLobe_Pdf_0( this_62 : DiffuseLobe_0,  wo_27 : vec3<f32>,  wi_21 : vec3<f32>) -> f32
{
    return max(dot(wi_21, this_62.normal_3), 0.0f) * (1.0f / float_getPi_0());
}

fn MicrofacetReflectionLobe_Eval_0( this_63 : MicrofacetReflectionLobe_0,  wo_28 : vec3<f32>,  wi_22 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_6 : f32 = dot(this_63.normal_4, wo_28);
    if(((idotn_6 * dot(this_63.normal_4, wi_22)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_7 : vec3<f32> = normalize(wo_28 + wi_22);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_63.distribution_1, wo_28, wi_22)) * (vec3<f32>((GGXDistribution_D_0(this_63.distribution_1, h_7) * (1.0f / (4.0f * idotn_6)))) * ConstantReflection_Reflection_0(this_63.coefficient_1, abs(dot(wo_28, h_7)))));
}

fn FlippedLobe_Eval_0( this_64 : FlippedLobe_0,  wo_29 : vec3<f32>,  wi_23 : vec3<f32>) -> DiffuseSpecular_0
{
    return MicrofacetReflectionLobe_Eval_0(this_64.lobe_0, reflect(wo_29, MicrofacetReflectionLobe_GetNormal_0(this_64.lobe_0)), wi_23);
}

fn MicrofacetReflectionLobe_Pdf_0( this_65 : MicrofacetReflectionLobe_0,  wo_30 : vec3<f32>,  wi_24 : vec3<f32>) -> f32
{
    var idotn_7 : f32 = dot(this_65.normal_4, wo_30);
    if(((idotn_7 * dot(this_65.normal_4, wi_24)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_8 : vec3<f32> = normalize(wo_30 + wi_24);
    var idoth_15 : f32 = dot(wo_30, h_8);
    var odoth_5 : f32 = dot(wi_24, h_8);
    if(((idoth_15 * odoth_5) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_65.distribution_1, wo_30) * (GGXDistribution_D_0(this_65.distribution_1, h_8) * (idoth_15 / (4.0f * odoth_5 * idotn_7)));
}

fn FlippedLobe_Pdf_0( this_66 : FlippedLobe_0,  wo_31 : vec3<f32>,  wi_25 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_Pdf_0(this_66.lobe_0, reflect(wo_31, MicrofacetReflectionLobe_GetNormal_0(this_66.lobe_0)), wi_25);
}

fn FlippedLobe_Eval_1( this_67 : FlippedLobe_1,  wo_32 : vec3<f32>,  wi_26 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseLobe_Eval_0(this_67.lobe_0, reflect(wo_32, DiffuseLobe_GetNormal_0(this_67.lobe_0)), wi_26);
}

fn FlippedLobe_Pdf_1( this_68 : FlippedLobe_1,  wo_33 : vec3<f32>,  wi_27 : vec3<f32>) -> f32
{
    return DiffuseLobe_Pdf_0(this_68.lobe_0, reflect(wo_33, DiffuseLobe_GetNormal_0(this_68.lobe_0)), wi_27);
}

fn BaseLobe_LobeEvalPdf_0( this_69 : BaseLobe_0,  index_4 : i32,  wo_34 : vec3<f32>,  wi_28 : vec3<f32>,  f_4 : ptr<function, DiffuseSpecular_0>,  pdf_4 : ptr<function, f32>)
{
    switch(index_4)
    {
    case i32(0):
        {
            (*f_4) = SpecularLobe_Eval_0(this_69.specular_0, wo_34, wi_28);
            (*pdf_4) = SpecularLobe_Pdf_0(this_69.specular_0, wo_34, wi_28);
        }
    case i32(1):
        {
            (*f_4) = DielectricMultipleScatteringLobe_Eval_0(this_69.dielectricMultipleScattering_0, wo_34, wi_28);
            (*pdf_4) = DielectricMultipleScatteringLobe_Pdf_0(this_69.dielectricMultipleScattering_0, wo_34, wi_28);
        }
    case i32(2):
        {
            (*f_4) = MetalMultipleScatteringLobe_Eval_0(this_69.metalMultipleScattering_0, wo_34, wi_28);
            (*pdf_4) = MetalMultipleScatteringLobe_Pdf_0(this_69.metalMultipleScattering_0, wo_34, wi_28);
        }
    case i32(3):
        {
            (*f_4) = DiffuseLobe_Eval_0(this_69.diffuse_0, wo_34, wi_28);
            (*pdf_4) = DiffuseLobe_Pdf_0(this_69.diffuse_0, wo_34, wi_28);
        }
    case i32(4):
        {
            (*f_4) = FlippedLobe_Eval_0(this_69.thinWallSpecularTransmission_0, wo_34, wi_28);
            (*pdf_4) = FlippedLobe_Pdf_0(this_69.thinWallSpecularTransmission_0, wo_34, wi_28);
        }
    default :
        {
            (*f_4) = FlippedLobe_Eval_1(this_69.thinWallDiffuseTransmission_0, wo_34, wi_28);
            (*pdf_4) = FlippedLobe_Pdf_1(this_69.thinWallDiffuseTransmission_0, wo_34, wi_28);
        }
    }
    return;
}

fn x2B_0( a_5 : DiffuseSpecular_0,  b_4 : DiffuseSpecular_0) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_5.diffuse_1 + b_4.diffuse_1, a_5.specular_1 + b_4.specular_1);
}

fn BaseLobe_EvalPdf_0( this_70 : BaseLobe_0,  wo_35 : vec3<f32>,  wi_29 : vec3<f32>,  sampled_3 : SampledLobe_0,  f_5 : ptr<function, DiffuseSpecular_0>,  pdf_5 : ptr<function, f32>)
{
    (*f_5) = DiffuseSpecular_Zero_0();
    var i_0 : i32 = i32(0);
    var sum_1 : f32 = 0.0f;
    var totalWeight_2 : f32 = 0.0f;
    loop
    {
        if((i_0 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_70, i_0))
        {
            var lobeF_0 : DiffuseSpecular_0 = sampled_3.f_0;
            var lobePdf_0 : f32 = sampled_3.pdf_0;
            var _S87 : bool;
            if((sampled_3.layer_0) != i32(1))
            {
                _S87 = true;
            }
            else
            {
                _S87 = (sampled_3.lobe_1) != i_0;
            }
            if(_S87)
            {
                BaseLobe_LobeEvalPdf_0(this_70, i_0, wo_35, wi_29, &(lobeF_0), &(lobePdf_0));
            }
            (*f_5) = x2B_0((*f_5), lobeF_0);
            var totalWeight_3 : f32 = totalWeight_2 + this_70.weights_0[i_0];
            sum_1 = sum_1 + this_70.weights_0[i_0] * lobePdf_0;
            totalWeight_2 = totalWeight_3;
        }
        i_0 = i_0 + i32(1);
    }
    if((totalWeight_2 > 0.0f))
    {
        sum_1 = sum_1 / totalWeight_2;
    }
    else
    {
        sum_1 = 0.0f;
    }
    (*pdf_5) = sum_1;
    return;
}

fn MinComponent_0( v_7 : vec3<f32>) -> f32
{
    return min(min(v_7.x, v_7.y), v_7.z);
}

fn SafePow_0( a_6 : f32,  b_5 : f32) -> f32
{
    var _S88 : f32;
    if((a_6 > 0.0f))
    {
        _S88 = pow(a_6, b_5);
    }
    else
    {
        _S88 = 0.0f;
    }
    return _S88;
}

fn SafePow_1( a_7 : vec3<f32>,  b_6 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(SafePow_0(a_7.x, b_6.x), SafePow_0(a_7.y, b_6.y), SafePow_0(a_7.z, b_6.z));
}

fn CoatLobe_PassageColor_0( this_71 : CoatLobe_0,  cosine_0 : f32) -> vec3<f32>
{
    var _S89 : bool;
    if((cosine_0 > 0.0f))
    {
        _S89 = ((MinComponent_0(this_71.tint_0)) < 1.0f);
    }
    else
    {
        _S89 = false;
    }
    if(_S89)
    {
        return mix(vec3<f32>(1.0f), SafePow_1(sqrt(this_71.tint_0), vec3<f32>((1.0f / sqrt(max(0.0f, 1.0f - (1.0f - Square_0(cosine_0)) / Square_0(this_71.reflection_0.coefficient_1.eta_2)))))), vec3<f32>(this_71.presence_0));
    }
    return vec3<f32>(1.0f);
}

fn x2A_1( a_8 : DiffuseSpecular_0,  scale_2 : vec3<f32>) -> DiffuseSpecular_0
{
    return DiffuseSpecular_x24init_0(a_8.diffuse_1 * scale_2, a_8.specular_1 * scale_2);
}

fn MicrofacetReflectionLobe_Eval_1( this_72 : MicrofacetReflectionLobe_1,  wo_36 : vec3<f32>,  wi_30 : vec3<f32>) -> DiffuseSpecular_0
{
    var idotn_8 : f32 = dot(this_72.normal_4, wo_36);
    if(((idotn_8 * dot(this_72.normal_4, wi_30)) <= 0.0f))
    {
        return DiffuseSpecular_Zero_0();
    }
    var h_9 : vec3<f32> = normalize(wo_36 + wi_30);
    return DiffuseSpecular_Specular_0(vec3<f32>(GGXDistribution_G2_0(this_72.distribution_1, wo_36, wi_30)) * (vec3<f32>((GGXDistribution_D_0(this_72.distribution_1, h_9) * (1.0f / (4.0f * idotn_8)))) * DielectricReflection_Reflection_0(this_72.coefficient_1, abs(dot(wo_36, h_9)))));
}

fn CoatLobe_CoatEval_0( this_73 : CoatLobe_0,  wo_37 : vec3<f32>,  wi_31 : vec3<f32>) -> DiffuseSpecular_0
{
    var _S90 : DiffuseSpecular_0;
    if(CoatLobe_HasCoat_0(this_73))
    {
        _S90 = MicrofacetReflectionLobe_Eval_1(this_73.reflection_0, wo_37, wi_31);
    }
    else
    {
        _S90 = DiffuseSpecular_Zero_0();
    }
    return _S90;
}

fn CoatLobe_BaseLayerScaleOneSide_0( this_74 : CoatLobe_0,  cosine_1 : f32,  reflectedFromThisSide_0 : f32) -> vec3<f32>
{
    return CoatLobe_PassageColor_0(this_74, cosine_1) * vec3<f32>((1.0f - reflectedFromThisSide_0));
}

fn CoatLobe_BaseLayerScaleComplete_0( this_75 : CoatLobe_0,  wi_32 : vec3<f32>) -> vec3<f32>
{
    return this_75.inBaseLayerScale_0 * CoatLobe_BaseLayerScaleOneSide_0(this_75, dot(wi_32, this_75.normal_5), 0.0f);
}

fn CoatLobe_Combine_0( this_76 : CoatLobe_0,  coatEval_0 : DiffuseSpecular_0,  baseEval_0 : DiffuseSpecular_0,  wi_33 : vec3<f32>) -> DiffuseSpecular_0
{
    return x2B_0(x2A_0(coatEval_0, this_76.presence_0), x2A_1(baseEval_0, CoatLobe_BaseLayerScaleComplete_0(this_76, wi_33)));
}

fn MicrofacetReflectionLobe_Pdf_1( this_77 : MicrofacetReflectionLobe_1,  wo_38 : vec3<f32>,  wi_34 : vec3<f32>) -> f32
{
    var idotn_9 : f32 = dot(this_77.normal_4, wo_38);
    if(((idotn_9 * dot(this_77.normal_4, wi_34)) <= 0.0f))
    {
        return 0.0f;
    }
    var h_10 : vec3<f32> = normalize(wo_38 + wi_34);
    var idoth_16 : f32 = dot(wo_38, h_10);
    var odoth_6 : f32 = dot(wi_34, h_10);
    if(((idoth_16 * odoth_6) < 0.0f))
    {
        return 0.0f;
    }
    return GGXDistribution_G1_0(this_77.distribution_1, wo_38) * (GGXDistribution_D_0(this_77.distribution_1, h_10) * (idoth_16 / (4.0f * odoth_6 * idotn_9)));
}

fn CoatLobe_EvalPdf_0( this_78 : CoatLobe_0,  wo_39 : vec3<f32>,  wi_35 : vec3<f32>,  sampled_4 : SampledLobe_0,  f_6 : ptr<function, DiffuseSpecular_0>,  pdf_6 : ptr<function, f32>)
{
    var baseF_0 : DiffuseSpecular_0;
    var basePdf_0 : f32;
    BaseLobe_EvalPdf_0(this_78.base_0, wo_39, wi_35, sampled_4, &(baseF_0), &(basePdf_0));
    if(this_78.inside_0)
    {
        (*f_6) = x2A_1(baseF_0, CoatLobe_PassageColor_0(this_78, - dot(wi_35, this_78.normal_5)));
        (*pdf_6) = basePdf_0;
        return;
    }
    var coatSampled_0 : bool = (sampled_4.layer_0) == i32(2);
    var _S91 : DiffuseSpecular_0;
    if(coatSampled_0)
    {
        _S91 = sampled_4.f_0;
    }
    else
    {
        _S91 = CoatLobe_CoatEval_0(this_78, wo_39, wi_35);
    }
    (*f_6) = CoatLobe_Combine_0(this_78, _S91, baseF_0, wi_35);
    var _S92 : f32;
    if(CoatLobe_HasCoat_0(this_78))
    {
        var _S93 : f32 = basePdf_0;
        if(coatSampled_0)
        {
            _S92 = sampled_4.pdf_0;
        }
        else
        {
            _S92 = MicrofacetReflectionLobe_Pdf_1(this_78.reflection_0, wo_39, wi_35);
        }
        _S92 = mix(_S93, _S92, CoatLobe_ReflectionProbability_0(this_78, wo_39));
    }
    else
    {
        _S92 = basePdf_0;
    }
    (*pdf_6) = _S92;
    return;
}

fn FuzzLobe_BaseLayerScaleComplete_0( this_79 : FuzzLobe_0,  wiLocal_3 : vec3<f32>) -> f32
{
    return FuzzLobe_BaseLayerScaleIncoming_0(this_79);
}

fn SheenEvalLTC_0( wiLocal_4 : vec3<f32>,  ltc_1 : vec3<f32>) -> f32
{
    var aInv_0 : f32 = ltc_1.x;
    var _S94 : f32 = wiLocal_4.z;
    var wiOriginal_1 : vec3<f32> = vec3<f32>(aInv_0 * wiLocal_4.x + ltc_1.y * _S94, aInv_0 * wiLocal_4.y, _S94);
    var _S95 : f32 = max(0.0f, _S94);
    var lengthSquared_0 : f32 = dot(wiOriginal_1, wiOriginal_1);
    var _S96 : bool;
    if(lengthSquared_0 == 0.0f)
    {
        _S96 = true;
    }
    else
    {
        _S96 = aInv_0 == 0.0f;
    }
    if(_S96)
    {
        _S96 = true;
    }
    else
    {
        _S96 = _S95 == 0.0f;
    }
    if(_S96)
    {
        return 0.0f;
    }
    var aInvOverLengthSquared_0 : f32 = aInv_0 / lengthSquared_0;
    return 1.0f / float_getPi_0() * (_S95 * aInvOverLengthSquared_0) * aInvOverLengthSquared_0;
}

fn FuzzLobe_SheenEval_0( this_80 : FuzzLobe_0,  wiLocal_5 : vec3<f32>) -> vec3<f32>
{
    var _S97 : bool;
    if(((this_80.woLocal_0.z) <= 0.0f))
    {
        _S97 = true;
    }
    else
    {
        _S97 = ((wiLocal_5.z) <= 0.0f);
    }
    if(_S97)
    {
        _S97 = true;
    }
    else
    {
        _S97 = !FuzzLobe_HasFuzz_0(this_80);
    }
    if(_S97)
    {
        return vec3<f32>(0.0f);
    }
    var ltc_2 : vec3<f32> = FuzzLobe_Coefficients_0(this_80, this_80.woLocal_0);
    return vec3<f32>(SheenEvalLTC_0(SheenRotate_0(wiLocal_5, vec2<f32>(this_80.woLocal_0.x, - this_80.woLocal_0.y)), ltc_2)) * (vec3<f32>((this_80.presence_1 * ltc_2.z)) * this_80.tint_1);
}

fn FuzzLobe_SheenPdf_0( this_81 : FuzzLobe_0,  wiLocal_6 : vec3<f32>) -> f32
{
    var _S98 : bool;
    if(((this_81.woLocal_0.z) <= 0.0f))
    {
        _S98 = true;
    }
    else
    {
        _S98 = ((wiLocal_6.z) <= 0.0f);
    }
    if(_S98)
    {
        _S98 = true;
    }
    else
    {
        _S98 = !FuzzLobe_HasFuzz_0(this_81);
    }
    if(_S98)
    {
        return 0.0f;
    }
    return SheenEvalLTC_0(SheenRotate_0(wiLocal_6, vec2<f32>(this_81.woLocal_0.x, - this_81.woLocal_0.y)), FuzzLobe_Coefficients_0(this_81, this_81.woLocal_0));
}

fn FuzzLobe_EvalPdf_0( this_82 : FuzzLobe_0,  wo_40 : vec3<f32>,  wi_36 : vec3<f32>,  sampled_5 : SampledLobe_0,  f_7 : ptr<function, DiffuseSpecular_0>,  pdf_7 : ptr<function, f32>)
{
    var baseF_1 : DiffuseSpecular_0;
    var basePdf_1 : f32;
    CoatLobe_EvalPdf_0(this_82.base_1, wo_40, wi_36, sampled_5, &(baseF_1), &(basePdf_1));
    var wiLocal_7 : vec3<f32> = Frame_ToLocal_0(this_82.basis_0, wi_36);
    (*f_7) = x2B_0(x2A_0(baseF_1, FuzzLobe_BaseLayerScaleComplete_0(this_82, wiLocal_7)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_82, wiLocal_7)));
    var _S99 : f32;
    if(FuzzLobe_HasFuzz_0(this_82))
    {
        _S99 = mix(basePdf_1, FuzzLobe_SheenPdf_0(this_82, wiLocal_7), FuzzLobe_SheenProbability_0(this_82, wo_40));
    }
    else
    {
        _S99 = basePdf_1;
    }
    (*pdf_7) = _S99;
    return;
}

fn SampleLayer_0( layer_2 : FuzzLobe_0,  u_19 : vec3<f32>,  wo_41 : vec3<f32>) -> LobeSample_0
{
    var wi_37 : vec3<f32>;
    var type_6 : u32;
    var sampled_6 : SampledLobe_0;
    var _S100 : bool = FuzzLobe_SampleLobe_0(layer_2, u_19, wo_41, &(wi_37), &(type_6), &(sampled_6));
    if(!_S100)
    {
        return LobeSample_Invalid_0();
    }
    var f_8 : DiffuseSpecular_0;
    var pdf_8 : f32;
    FuzzLobe_EvalPdf_0(layer_2, wo_41, wi_37, sampled_6, &(f_8), &(pdf_8));
    if(!(pdf_8 > 0.0f))
    {
        return LobeSample_Invalid_0();
    }
    return LobeSample_Make_0(wi_37, x2A_0(f_8, 1.0f / pdf_8), pdf_8, type_6);
}

fn FuzzLobe_ProportionReflected_0( this_83 : FuzzLobe_0,  directionLocal_1 : vec3<f32>) -> f32
{
    var _S101 : bool;
    if(((directionLocal_1.z) <= 0.0f))
    {
        _S101 = true;
    }
    else
    {
        _S101 = !FuzzLobe_HasFuzz_0(this_83);
    }
    if(_S101)
    {
        return 0.0f;
    }
    return this_83.presence_1 * FuzzLobe_Coefficients_0(this_83, directionLocal_1).z;
}

fn DielectricEnergyReflected_0( ior_5 : f32,  alpha_14 : f32,  cosTheta_6 : f32) -> f32
{
    if(alpha_14 == 0.0f)
    {
        return FresnelDielectric_0(ior_5, cosTheta_6);
    }
    return 1.0f - OpaqueDielectricEnergyComplement_0(ior_5, alpha_14, cosTheta_6);
}

fn CoatLobe_ProportionReflected_0( this_84 : CoatLobe_0,  cosine_2 : f32) -> f32
{
    var _S102 : bool;
    if((cosine_2 > 0.0f))
    {
        _S102 = CoatLobe_HasCoat_0(this_84);
    }
    else
    {
        _S102 = false;
    }
    if(_S102)
    {
        return DielectricEnergyReflected_0(this_84.reflection_0.coefficient_1.eta_2, this_84.reflection_0.distribution_1.isotropicAlpha_0, cosine_2) * this_84.presence_0;
    }
    return 0.0f;
}

fn BaseLobe_LobeEvalPdf_1( this_85 : BaseLobe_0,  index_5 : i32,  wo_42 : vec3<f32>,  wi_38 : vec3<f32>,  f_9 : ptr<function, DiffuseSpecular_0>,  pdf_9 : ptr<function, f32>)
{
    switch(index_5)
    {
    case i32(0):
        {
            (*f_9) = SpecularLobe_Eval_0(this_85.specular_0, wo_42, wi_38);
            (*pdf_9) = SpecularLobe_Pdf_0(this_85.specular_0, wo_42, wi_38);
        }
    case i32(1):
        {
            (*f_9) = DielectricMultipleScatteringLobe_Eval_0(this_85.dielectricMultipleScattering_0, wo_42, wi_38);
            (*pdf_9) = DielectricMultipleScatteringLobe_Pdf_0(this_85.dielectricMultipleScattering_0, wo_42, wi_38);
        }
    case i32(2):
        {
            (*f_9) = MetalMultipleScatteringLobe_Eval_0(this_85.metalMultipleScattering_0, wo_42, wi_38);
            (*pdf_9) = MetalMultipleScatteringLobe_Pdf_0(this_85.metalMultipleScattering_0, wo_42, wi_38);
        }
    case i32(3):
        {
            (*f_9) = DiffuseLobe_Eval_0(this_85.diffuse_0, wo_42, wi_38);
            (*pdf_9) = DiffuseLobe_Pdf_0(this_85.diffuse_0, wo_42, wi_38);
        }
    case i32(4):
        {
            (*f_9) = FlippedLobe_Eval_0(this_85.thinWallSpecularTransmission_0, wo_42, wi_38);
            (*pdf_9) = FlippedLobe_Pdf_0(this_85.thinWallSpecularTransmission_0, wo_42, wi_38);
        }
    default :
        {
            (*f_9) = FlippedLobe_Eval_1(this_85.thinWallDiffuseTransmission_0, wo_42, wi_38);
            (*pdf_9) = FlippedLobe_Pdf_1(this_85.thinWallDiffuseTransmission_0, wo_42, wi_38);
        }
    }
    return;
}

fn BaseLobe_EvalPdf_1( this_86 : BaseLobe_0,  wo_43 : vec3<f32>,  wi_39 : vec3<f32>,  sampled_7 : SampledLobe_0,  f_10 : ptr<function, DiffuseSpecular_0>,  pdf_10 : ptr<function, f32>)
{
    (*f_10) = DiffuseSpecular_Zero_0();
    var i_1 : i32 = i32(0);
    var sum_2 : f32 = 0.0f;
    var totalWeight_4 : f32 = 0.0f;
    loop
    {
        if((i_1 < i32(6)))
        {
        }
        else
        {
            break;
        }
        if(BaseLobe_IsActive_0(this_86, i_1))
        {
            var lobeF_1 : DiffuseSpecular_0 = sampled_7.f_0;
            var lobePdf_1 : f32 = sampled_7.pdf_0;
            var _S103 : bool;
            if((sampled_7.layer_0) != i32(1))
            {
                _S103 = true;
            }
            else
            {
                _S103 = (sampled_7.lobe_1) != i_1;
            }
            if(_S103)
            {
                BaseLobe_LobeEvalPdf_1(this_86, i_1, wo_43, wi_39, &(lobeF_1), &(lobePdf_1));
            }
            (*f_10) = x2B_0((*f_10), lobeF_1);
            var totalWeight_5 : f32 = totalWeight_4 + this_86.weights_0[i_1];
            sum_2 = sum_2 + this_86.weights_0[i_1] * lobePdf_1;
            totalWeight_4 = totalWeight_5;
        }
        i_1 = i_1 + i32(1);
    }
    if((totalWeight_4 > 0.0f))
    {
        sum_2 = sum_2 / totalWeight_4;
    }
    else
    {
        sum_2 = 0.0f;
    }
    (*pdf_10) = sum_2;
    return;
}

fn CoatLobe_EvalPdf_1( this_87 : CoatLobe_0,  wo_44 : vec3<f32>,  wi_40 : vec3<f32>,  sampled_8 : SampledLobe_0,  f_11 : ptr<function, DiffuseSpecular_0>,  pdf_11 : ptr<function, f32>)
{
    var baseF_2 : DiffuseSpecular_0;
    var basePdf_2 : f32;
    BaseLobe_EvalPdf_1(this_87.base_0, wo_44, wi_40, sampled_8, &(baseF_2), &(basePdf_2));
    if(this_87.inside_0)
    {
        (*f_11) = x2A_1(baseF_2, CoatLobe_PassageColor_0(this_87, - dot(wi_40, this_87.normal_5)));
        (*pdf_11) = basePdf_2;
        return;
    }
    var coatSampled_1 : bool = (sampled_8.layer_0) == i32(2);
    var _S104 : DiffuseSpecular_0;
    if(coatSampled_1)
    {
        _S104 = sampled_8.f_0;
    }
    else
    {
        _S104 = CoatLobe_CoatEval_0(this_87, wo_44, wi_40);
    }
    (*f_11) = CoatLobe_Combine_0(this_87, _S104, baseF_2, wi_40);
    var _S105 : f32;
    if(CoatLobe_HasCoat_0(this_87))
    {
        var _S106 : f32 = basePdf_2;
        if(coatSampled_1)
        {
            _S105 = sampled_8.pdf_0;
        }
        else
        {
            _S105 = MicrofacetReflectionLobe_Pdf_1(this_87.reflection_0, wo_44, wi_40);
        }
        _S105 = mix(_S106, _S105, CoatLobe_ReflectionProbability_0(this_87, wo_44));
    }
    else
    {
        _S105 = basePdf_2;
    }
    (*pdf_11) = _S105;
    return;
}

fn ConstantReflection_EstimateWeightOnGGX_0( this_88 : ConstantReflection_0,  throughput_7 : vec3<f32>,  idotn_10 : f32,  isotropicAlpha_1 : f32) -> f32
{
    return ThroughputWeightedMax_0(throughput_7, this_88.color_0);
}

fn MicrofacetReflectionLobe_EstimateContribution_0( this_89 : MicrofacetReflectionLobe_0,  wo_45 : vec3<f32>,  throughput_8 : vec3<f32>) -> f32
{
    return ConstantReflection_EstimateWeightOnGGX_0(this_89.coefficient_1, throughput_8, dot(wo_45, this_89.normal_4), this_89.distribution_1.isotropicAlpha_0);
}

fn isfinite_1( x_12 : vec3<f32>) -> vec3<bool>
{
    var result_2 : vec3<bool>;
    var i_2 : i32 = i32(0);
    loop
    {
        if((i_2 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_2[i_2] = isfinite_0(x_12[i_2]);
        i_2 = i_2 + i32(1);
    }
    return result_2;
}

fn FuzzLobe_Sample_0( this_90 : FuzzLobe_0,  u_20 : vec3<f32>,  wo_46 : vec3<f32>) -> LobeSample_0
{
    return SampleLayer_0(this_90, u_20, wo_46);
}

fn FuzzLobe_EvalPdf_1( this_91 : FuzzLobe_0,  wo_47 : vec3<f32>,  wi_41 : vec3<f32>,  sampled_9 : SampledLobe_0,  f_12 : ptr<function, DiffuseSpecular_0>,  pdf_12 : ptr<function, f32>)
{
    var baseF_3 : DiffuseSpecular_0;
    var basePdf_3 : f32;
    CoatLobe_EvalPdf_1(this_91.base_1, wo_47, wi_41, sampled_9, &(baseF_3), &(basePdf_3));
    var wiLocal_8 : vec3<f32> = Frame_ToLocal_0(this_91.basis_0, wi_41);
    (*f_12) = x2B_0(x2A_0(baseF_3, FuzzLobe_BaseLayerScaleComplete_0(this_91, wiLocal_8)), DiffuseSpecular_Specular_0(FuzzLobe_SheenEval_0(this_91, wiLocal_8)));
    var _S107 : f32;
    if(FuzzLobe_HasFuzz_0(this_91))
    {
        _S107 = mix(basePdf_3, FuzzLobe_SheenPdf_0(this_91, wiLocal_8), FuzzLobe_SheenProbability_0(this_91, wo_47));
    }
    else
    {
        _S107 = basePdf_3;
    }
    (*pdf_12) = _S107;
    return;
}

fn CoatLobe_MaxActiveAlpha_0( this_92 : CoatLobe_0) -> f32
{
    var _S108 : bool;
    if(this_92.inside_0)
    {
        _S108 = true;
    }
    else
    {
        _S108 = !CoatLobe_HasCoat_0(this_92);
    }
    var _S109 : f32;
    if(_S108)
    {
        _S109 = 0.0f;
    }
    else
    {
        _S109 = max(this_92.reflection_0.distribution_1.alpha_0.x, this_92.reflection_0.distribution_1.alpha_0.y);
    }
    return _S109;
}

fn FuzzLobe_x24init_0( base_2 : CoatLobe_0,  normal_6 : vec3<f32>,  wo_48 : vec3<f32>,  roughness_3 : f32,  tint_2 : vec3<f32>,  presence_5 : f32) -> FuzzLobe_0
{
    var _S110 : FuzzLobe_0;
    _S110.base_1 = base_2;
    _S110.alpha_3 = roughness_3;
    _S110.tint_1 = tint_2;
    _S110.presence_1 = presence_5;
    var _S111 : Frame_0 = BasisFromNormal_0(normal_6);
    _S110.basis_0 = _S111;
    var _S112 : vec3<f32> = Frame_ToLocal_0(_S111, wo_48);
    _S110.woLocal_0 = _S112;
    _S110.viewReflected_0 = 0.0f;
    _S110.viewReflected_0 = FuzzLobe_ProportionReflected_0(_S110, _S112);
    return _S110;
}

fn CoatLobe_x24init_0( base_3 : BaseLobe_0,  reflection_2 : MicrofacetReflectionLobe_1,  normal_7 : vec3<f32>,  wo_49 : vec3<f32>,  tint_3 : vec3<f32>,  presence_6 : f32,  extraBaseLayerScale_0 : vec3<f32>,  inside_1 : bool) -> CoatLobe_0
{
    var _S113 : CoatLobe_0;
    _S113.base_0 = base_3;
    _S113.reflection_0 = reflection_2;
    _S113.normal_5 = normal_7;
    _S113.tint_0 = tint_3;
    _S113.presence_0 = presence_6;
    _S113.inside_0 = inside_1;
    var idotn_11 : f32 = dot(wo_49, normal_7);
    var _S114 : f32 = CoatLobe_ProportionReflected_0(_S113, idotn_11);
    _S113.inReflected_0 = _S114;
    _S113.inBaseLayerScale_0 = CoatLobe_BaseLayerScaleOneSide_0(_S113, idotn_11, _S114) * extraBaseLayerScale_0;
    return _S113;
}

fn MicrofacetReflectionLobe_x24init_0( normal_8 : vec3<f32>,  distribution_2 : GGXDistribution_0,  coefficient_2 : DielectricReflection_0) -> MicrofacetReflectionLobe_1
{
    var _S115 : MicrofacetReflectionLobe_1;
    _S115.normal_4 = normal_8;
    _S115.distribution_1 = distribution_2;
    _S115.coefficient_1 = coefficient_2;
    return _S115;
}

fn DiffuseLobe_EstimateContribution_0( this_93 : DiffuseLobe_0,  wo_50 : vec3<f32>,  throughput_9 : vec3<f32>) -> f32
{
    return ThroughputWeightedMax_0(throughput_9, this_93.albedo_0 * vec3<f32>(this_93.specularCompensation_0));
}

fn FlippedLobe_EstimateContribution_0( this_94 : FlippedLobe_1,  wo_51 : vec3<f32>,  throughput_10 : vec3<f32>) -> f32
{
    return DiffuseLobe_EstimateContribution_0(this_94.lobe_0, reflect(wo_51, DiffuseLobe_GetNormal_0(this_94.lobe_0)), throughput_10);
}

fn FlippedLobe_EstimateContribution_1( this_95 : FlippedLobe_0,  wo_52 : vec3<f32>,  throughput_11 : vec3<f32>) -> f32
{
    return MicrofacetReflectionLobe_EstimateContribution_0(this_95.lobe_0, reflect(wo_52, MicrofacetReflectionLobe_GetNormal_0(this_95.lobe_0)), throughput_11);
}

fn FlippedLobe_x24init_0( lobe_3 : DiffuseLobe_0) -> FlippedLobe_1
{
    var _S116 : FlippedLobe_1;
    _S116.lobe_0 = lobe_3;
    return _S116;
}

fn FlippedLobe_x24init_1( lobe_4 : MicrofacetReflectionLobe_0) -> FlippedLobe_0
{
    var _S117 : FlippedLobe_0;
    _S117.lobe_0 = lobe_4;
    return _S117;
}

fn MicrofacetReflectionLobe_x24init_1( normal_9 : vec3<f32>,  distribution_3 : GGXDistribution_0,  coefficient_3 : ConstantReflection_0) -> MicrofacetReflectionLobe_0
{
    var _S118 : MicrofacetReflectionLobe_0;
    _S118.normal_4 = normal_9;
    _S118.distribution_1 = distribution_3;
    _S118.coefficient_1 = coefficient_3;
    return _S118;
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

struct TextureCoords_0
{
     uv0_0 : vec2<f32>,
     uv1_1 : vec2<f32>,
     footprint0_0 : f32,
     footprint1_0 : f32,
     objectPosition_0 : vec3<f32>,
};

struct MaterialContext_0
{
     tex_0 : TextureCoords_0,
     position_0 : vec3<f32>,
     normal_10 : vec3<f32>,
     tangent_1 : vec4<f32>,
     instanceIndex_0 : u32,
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
     thinFilmWeight_1 : f32,
     thinFilmThickness_1 : f32,
     thinFilmIor_1 : f32,
     emissionLuminance_0 : f32,
     emissionColor_0 : vec3<f32>,
     geometryOpacity_0 : f32,
     geometryThinWalled_0 : bool,
     basis_4 : Frame_0,
     coatBasis_0 : Frame_0,
};

struct MaterialOutputs_0
{
     inputs_0 : BSDFInputs_0,
     normal_11 : vec3<f32>,
     coatNormal_0 : vec3<f32>,
     tangent_2 : vec3<f32>,
     coatTangent_0 : vec3<f32>,
};

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

fn MaterialWord_0( index_6 : u32) -> u32
{
    return gMaterialData_0[(index_6 >> (u32(2)))][(index_6 & (u32(3)))];
}

fn Bitangent_0( tangent_3 : vec4<f32>,  n_5 : vec3<f32>) -> vec3<f32>
{
    var _S119 : f32 = tangent_3.w;
    var _S120 : bool;
    if(_S119 == 0.0f)
    {
        _S120 = true;
    }
    else
    {
        var _S121 : vec3<f32> = tangent_3.xyz;
        _S120 = (dot(_S121, _S121)) == 0.0f;
    }
    if(_S120)
    {
        return vec3<f32>(0.0f);
    }
    var _S122 : vec3<f32> = tangent_3.xyz;
    return cross(n_5, normalize(_S122 - n_5 * vec3<f32>(dot(_S122, n_5)))) * vec3<f32>(_S119);
}

struct TextureRef_0
{
     flags_2 : u32,
     pageTableOffset_0 : u32,
     reserved_0 : u32,
     rotation_0 : f32,
     scaleOffset_0 : vec4<f32>,
};

fn LoadTextureRef_0( header_0 : MaterialHeader_0,  index_7 : u32) -> TextureRef_0
{
    var _S123 : u32 = header_0.textureBase_0 + index_7 * u32(2);
    var a_9 : vec4<u32> = gMaterialData_0[_S123];
    var ref_0 : TextureRef_0;
    ref_0.flags_2 = a_9.x;
    ref_0.pageTableOffset_0 = a_9.y;
    ref_0.reserved_0 = a_9.z;
    ref_0.rotation_0 = (bitcast<f32>((a_9.w)));
    ref_0.scaleOffset_0 = (bitcast<vec4<f32>>((gMaterialData_0[_S123 + u32(1)])));
    return ref_0;
}

fn HasTexture_0( ref_1 : TextureRef_0) -> bool
{
    return (((ref_1.flags_2) & (u32(1)))) != u32(0);
}

fn TransformUV_0( ref_2 : TextureRef_0,  uv_0 : vec2<f32>) -> vec2<f32>
{
    var s_12 : vec2<f32> = ref_2.scaleOffset_0.xy * uv_0;
    var c_5 : f32 = cos(ref_2.rotation_0);
    var r_5 : f32 = sin(ref_2.rotation_0);
    var _S124 : f32 = s_12.x;
    var _S125 : f32 = s_12.y;
    return vec2<f32>(c_5 * _S124 + r_5 * _S125, - r_5 * _S124 + c_5 * _S125) + ref_2.scaleOffset_0.zw;
}

fn WrapCoord_0( x_13 : f32,  mode_0 : u32) -> f32
{
    if(mode_0 == u32(1))
    {
        return saturate(x_13);
    }
    if(mode_0 == u32(2))
    {
        var t_2 : f32 = x_13 - 2.0f * floor(x_13 * 0.5f);
        var _S126 : f32;
        if((t_2 > 1.0f))
        {
            _S126 = 2.0f - t_2;
        }
        else
        {
            _S126 = t_2;
        }
        return _S126;
    }
    return fract(x_13);
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
    var _S127 : u32 = u32(1664525) * gVTRandom_0 + u32(1013904223);
    gVTRandom_0 = _S127;
    return _S127;
}

fn VTPageCount_0( log2Size_0 : vec2<u32>,  level_0 : u32) -> vec2<u32>
{
    var _S128 : vec2<i32> = max(vec2<i32>(log2Size_0) - vec2<i32>(i32(level_0)) - vec2<i32>(i32(7)), vec2<i32>(i32(0)));
    return vec2<u32>((u32(1) << (u32(_S128.x))), (u32(1) << (u32(_S128.y))));
}

fn VTLevelSize_0( log2Size_1 : vec2<u32>,  level_1 : u32) -> vec2<f32>
{
    var _S129 : vec2<i32> = max(vec2<i32>(log2Size_1) - vec2<i32>(i32(level_1)), vec2<i32>(i32(0)));
    return vec2<f32>(f32((u32(1) << (u32(_S129.x)))), f32((u32(1) << (u32(_S129.y)))));
}

var<private> gVTRequestCount_0 : u32;

var<private> gVTRequest_0 : u32;

fn StoreVirtualTextureFeedback_0( pageIndex_0 : u32)
{
    gVTRequestCount_0 = gVTRequestCount_0 + u32(1);
    var _S130 : u32 = NextVTRandom_0();
    if(((f32((_S130 >> (u32(8)))) * 5.9604644775390625e-08f * f32(gVTRequestCount_0)) < 1.0f))
    {
        gVTRequest_0 = pageIndex_0 + u32(1);
    }
    return;
}

fn VTLoadEntry_0( index_8 : u32) -> u32
{
    var width_0 : u32 = gFrame_0.vtInfo_0.y;
    var _S131 : u32 = index_8 % width_0;
    var _S132 : i32 = i32(_S131);
    var _S133 : u32 = index_8 / width_0;
    var _S134 : vec3<i32> = vec3<i32>(_S132, i32(_S133), i32(0));
    return (textureLoad((gVTPageTable_0), ((_S134)).xy, ((_S134)).z).x);
}

var<private> gVTLastMappedLevel_0 : u32;

var<private> gVTLastRequestedLevel_0 : u32;

fn SampleVirtualTexture_0( ref_6 : TextureRef_0,  uv_1 : vec2<f32>,  uvFootprint_0 : f32) -> vec4<f32>
{
    var levels_0 : u32 = VTLevels_0(ref_6);
    var _S135 : u32 = VTLog2Width_0(ref_6);
    var _S136 : u32 = VTLog2Height_0(ref_6);
    var log2Size_2 : vec2<u32> = vec2<u32>(_S135, _S136);
    var lod_0 : f32 = uvFootprint_0 + 0.5f * (f32(_S135 + _S136) + log2(max(abs(ref_6.scaleOffset_0.x * ref_6.scaleOffset_0.y), 9.99999968265522539e-21f))) + gFrame_0.vtParams_0.z;
    var _S137 : u32 = NextVTRandom_0();
    var level_2 : u32 = u32(clamp(floor(lod_0 + f32((_S137 >> (u32(8)))) * 5.9604644775390625e-08f), 0.0f, f32(levels_0 - u32(1))));
    var l_0 : u32 = u32(0);
    var index_9 : u32 = ref_6.pageTableOffset_0;
    loop
    {
        if((l_0 < level_2))
        {
        }
        else
        {
            break;
        }
        var n_6 : vec2<u32> = VTPageCount_0(log2Size_2, l_0);
        var index_10 : u32 = index_9 + n_6.x * n_6.y;
        l_0 = l_0 + u32(1);
        index_9 = index_10;
    }
    var pages_0 : vec2<u32> = VTPageCount_0(log2Size_2, level_2);
    var _S138 : vec2<u32> = min((vec2<u32>(uv_1 * VTLevelSize_0(log2Size_2, level_2)) >> (vec2<u32>(u32(7)))), pages_0 - vec2<u32>(u32(1)));
    var index_11 : u32 = index_9 + (_S138.y * pages_0.x + _S138.x);
    StoreVirtualTextureFeedback_0(index_11);
    var entry_0 : u32 = VTLoadEntry_0(index_11);
    if(((entry_0 & (u32(2147483648)))) == u32(0))
    {
        return vec4<f32>(1.0f, 0.0f, 1.0f, 1.0f);
    }
    var mappedLevel_0 : u32 = (((entry_0 >> (u32(16)))) & (u32(15)));
    gVTLastMappedLevel_0 = mappedLevel_0;
    gVTLastRequestedLevel_0 = level_2;
    var local_0 : vec2<f32> = uv_1 * VTLevelSize_0(log2Size_2, mappedLevel_0) - vec2<f32>((_S138 >> (vec2<u32>((mappedLevel_0 - level_2))))) * vec2<f32>(128.0f);
    var tile_0 : u32 = (entry_0 & (u32(65535)));
    var tilesPerRow_0 : u32 = gFrame_0.vtInfo_0.x;
    var _S139 : u32 = tile_0 % tilesPerRow_0;
    var _S140 : f32 = f32(_S139);
    var _S141 : u32 = tile_0 / tilesPerRow_0;
    return (textureSampleLevel((gVTPhysical_0), (gLinearSampler_0), ((vec2<f32>(_S140, f32(_S141)) * vec2<f32>(136.0f) + vec2<f32>(4.0f) + local_0) * vec2<f32>(gFrame_0.vtParams_0.x)), (0.0f)));
}

fn SrgbToLinear_0( c_6 : vec3<f32>) -> vec3<f32>
{
    return select(pow((c_6 + vec3<f32>(0.054999999701976776f)) / vec3<f32>(1.0549999475479126f), vec3<f32>(2.4000000953674316f)), c_6 / vec3<f32>(12.920000076293945f), (c_6 <= vec3<f32>(0.040449999272823334f)));
}

fn SampleTexture_0( ref_7 : TextureRef_0,  tc_0 : TextureCoords_0) -> vec4<f32>
{
    var useUV1_0 : bool = (((ref_7.flags_2) & (u32(4)))) != u32(0);
    var uv_2 : vec2<f32>;
    var _S142 : vec2<f32>;
    if(useUV1_0)
    {
        _S142 = tc_0.uv1_1;
    }
    else
    {
        _S142 = tc_0.uv0_0;
    }
    var _S143 : vec2<f32> = TransformUV_0(ref_7, _S142);
    uv_2 = _S143;
    uv_2[i32(0)] = WrapCoord_0(_S143.x, ((((ref_7.flags_2) >> (u32(8)))) & (u32(3))));
    uv_2[i32(1)] = WrapCoord_0(uv_2.y, ((((ref_7.flags_2) >> (u32(10)))) & (u32(3))));
    var color_2 : vec4<f32>;
    var _S144 : vec2<f32> = uv_2;
    var _S145 : f32;
    if(useUV1_0)
    {
        _S145 = tc_0.footprint1_0;
    }
    else
    {
        _S145 = tc_0.footprint0_0;
    }
    var _S146 : vec4<f32> = SampleVirtualTexture_0(ref_7, _S144, _S145);
    color_2 = _S146;
    if((((ref_7.flags_2) & (u32(2)))) != u32(0))
    {
        var _S147 : vec3<f32> = SrgbToLinear_0(color_2.xyz);
        color_2.x = _S147.x;
        color_2.y = _S147.y;
        color_2.z = _S147.z;
    }
    return color_2;
}

fn ApplyNormalMap_0( tangent_4 : vec4<f32>,  n_7 : vec3<f32>,  texel_0 : vec3<f32>,  scale_3 : f32) -> vec3<f32>
{
    var _S148 : f32 = tangent_4.w;
    var _S149 : bool;
    if(_S148 == 0.0f)
    {
        _S149 = true;
    }
    else
    {
        var _S150 : vec3<f32> = tangent_4.xyz;
        _S149 = (dot(_S150, _S150)) == 0.0f;
    }
    if(_S149)
    {
        return n_7;
    }
    var _S151 : vec2<f32> = (texel_0.xy * vec2<f32>(2.0f) - vec2<f32>(1.0f)) * vec2<f32>(scale_3);
    var local_1 : vec3<f32>;
    local_1.x = _S151.x;
    local_1.y = _S151.y;
    var _S152 : f32 = texel_0.z;
    var _S153 : f32;
    if((_S152 <= 0.0f))
    {
        _S153 = sqrt(saturate(1.0f - dot(local_1.xy, local_1.xy)));
    }
    else
    {
        _S153 = abs(_S152 * 2.0f - 1.0f);
    }
    local_1[i32(2)] = _S153;
    if((dot(local_1, local_1)) == 0.0f)
    {
        return n_7;
    }
    var _S154 : vec3<f32> = normalize(local_1);
    local_1 = _S154;
    var _S155 : vec3<f32> = tangent_4.xyz;
    var t_3 : vec3<f32> = normalize(_S155 - n_7 * vec3<f32>(dot(_S155, n_7)));
    return normalize(t_3 * vec3<f32>(_S154.x) + cross(n_7, t_3) * vec3<f32>(_S148) * vec3<f32>(_S154.y) + n_7 * vec3<f32>(_S154.z));
}

fn TransformVector_0( _S156 : u32,  _S157 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S156].objectToWorld_0[i32(0)].xyz, _S157), dot(gInstances_0[_S156].objectToWorld_0[i32(1)].xyz, _S157), dot(gInstances_0[_S156].objectToWorld_0[i32(2)].xyz, _S157));
}

fn InverseTransformVector_0( _S158 : u32,  _S159 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S158].worldToObject_0[i32(0)].xyz, _S159), dot(gInstances_0[_S158].worldToObject_0[i32(1)].xyz, _S159), dot(gInstances_0[_S158].worldToObject_0[i32(2)].xyz, _S159));
}

fn HashRotate_0( x_14 : u32,  k_0 : u32) -> u32
{
    return (((x_14 << (k_0))) | (((x_14 >> ((u32(32) - k_0))))));
}

fn HashFinal_0( a_10 : u32,  b_7 : u32,  c_7 : u32) -> u32
{
    var _S160 : u32 = ((c_7 ^ (b_7))) - HashRotate_0(b_7, u32(14));
    var _S161 : u32 = ((a_10 ^ (_S160))) - HashRotate_0(_S160, u32(11));
    var _S162 : u32 = ((b_7 ^ (_S161))) - HashRotate_0(_S161, u32(25));
    var _S163 : u32 = ((_S160 ^ (_S162))) - HashRotate_0(_S162, u32(16));
    var _S164 : u32 = ((_S161 ^ (_S163))) - HashRotate_0(_S163, u32(4));
    var _S165 : u32 = ((_S162 ^ (_S164))) - HashRotate_0(_S164, u32(14));
    return ((_S163 ^ (_S165))) - HashRotate_0(_S165, u32(24));
}

fn HashUint2_0( kx_0 : u32,  ky_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928580) + kx_0, u32(3735928580) + ky_0, u32(3735928580));
}

fn RandomOffset3_0( seed_0 : f32) -> vec3<f32>
{
    var _S166 : u32 = (bitcast<u32>((seed_0)));
    return vec3<f32>(100.0f) + vec3<f32>(f32(HashUint2_0(_S166, (bitcast<u32>((0.0f))))), f32(HashUint2_0(_S166, (bitcast<u32>((1.0f))))), f32(HashUint2_0(_S166, (bitcast<u32>((2.0f)))))) * vec3<f32>(2.32830643653869629e-08f);
}

fn FMod_0( x_15 : f32,  y_4 : f32) -> f32
{
    return x_15 - trunc(x_15 / y_4) * y_4;
}

fn NoiseFade_0( t_4 : f32) -> f32
{
    return t_4 * t_4 * t_4 * (t_4 * (t_4 * 6.0f - 15.0f) + 10.0f);
}

fn HashUint3_0( kx_1 : u32,  ky_1 : u32,  kz_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928584) + kx_1, u32(3735928584) + ky_1, u32(3735928584) + kz_0);
}

fn NoiseGrad3_0( hash_0 : u32,  x_16 : f32,  y_5 : f32,  z_5 : f32) -> f32
{
    var h_11 : u32 = (hash_0 & (u32(15)));
    var u_21 : f32;
    if((h_11 < u32(8)))
    {
        u_21 = x_16;
    }
    else
    {
        u_21 = y_5;
    }
    var v_8 : f32;
    if((h_11 < u32(4)))
    {
        v_8 = y_5;
    }
    else
    {
        var _S167 : bool;
        if(h_11 == u32(12))
        {
            _S167 = true;
        }
        else
        {
            _S167 = h_11 == u32(14);
        }
        if(_S167)
        {
            v_8 = x_16;
        }
        else
        {
            v_8 = z_5;
        }
    }
    if(((h_11 & (u32(1)))) != u32(0))
    {
        u_21 = - u_21;
    }
    if(((h_11 & (u32(2)))) != u32(0))
    {
        v_8 = - v_8;
    }
    return u_21 + v_8;
}

fn Perlin3_0( p_2 : vec3<f32>) -> f32
{
    var i_3 : vec3<f32> = floor(p_2);
    var f_13 : vec3<f32> = p_2 - i_3;
    var _S168 : u32 = (bitcast<u32>((i32(i_3.x))));
    var _S169 : u32 = (bitcast<u32>((i32(i_3.y))));
    var _S170 : u32 = (bitcast<u32>((i32(i_3.z))));
    var _S171 : f32 = f_13.x;
    var u_22 : f32 = NoiseFade_0(_S171);
    var _S172 : f32 = f_13.y;
    var v_9 : f32 = NoiseFade_0(_S172);
    var _S173 : f32 = f_13.z;
    var w_0 : f32 = NoiseFade_0(_S173);
    var g_1 : array<f32, i32(8)>;
    var c_8 : u32 = u32(0);
    loop
    {
        if((c_8 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var _S174 : u32 = (c_8 & (u32(1)));
        var _S175 : u32 = (((c_8 >> (u32(1)))) & (u32(1)));
        var _S176 : u32 = (c_8 >> (u32(2)));
        g_1[c_8] = NoiseGrad3_0(HashUint3_0(_S168 + _S174, _S169 + _S175, _S170 + _S176), _S171 - f32(_S174), _S172 - f32(_S175), _S173 - f32(_S176));
        c_8 = c_8 + u32(1);
    }
    return mix(mix(mix(g_1[i32(0)], g_1[i32(1)], u_22), mix(g_1[i32(2)], g_1[i32(3)], u_22), v_9), mix(mix(g_1[i32(4)], g_1[i32(5)], u_22), mix(g_1[i32(6)], g_1[i32(7)], u_22), v_9), w_0);
}

fn SNoise3_0( p_3 : vec3<f32>) -> f32
{
    return 0.98199999332427979f * Perlin3_0(vec3<f32>(FMod_0(p_3.x, 1.0e+05f), FMod_0(p_3.y, 1.0e+05f), FMod_0(p_3.z, 1.0e+05f)) + select(vec3<f32>(0.0f), vec3<f32>(0.5f), ((abs(p_3)) >= vec3<f32>(1.0e+06f))));
}

fn NoiseFbm_0( p_4 : vec3<f32>,  detail_0 : f32,  roughness_4 : f32,  lacunarity_0 : f32,  normalize_0 : bool) -> f32
{
    var sum2_0 : f32;
    var octaves_0 : i32 = i32(detail_0);
    var rmd_0 : f32 = detail_0 - floor(detail_0);
    var _S177 : bool = rmd_0 != 0.0f;
    var _S178 : i32;
    if(_S177)
    {
        _S178 = octaves_0 + i32(1);
    }
    else
    {
        _S178 = octaves_0;
    }
    var i_4 : i32 = i32(0);
    var fscale_0 : f32 = 1.0f;
    var sum_3 : f32 = 0.0f;
    var amp_0 : f32 = 1.0f;
    var maxamp_0 : f32 = 0.0f;
    loop
    {
        if((i_4 <= _S178))
        {
        }
        else
        {
            sum2_0 = 0.0f;
            break;
        }
        var n_8 : f32 = SNoise3_0(vec3<f32>(fscale_0) * p_4);
        if((i_4 > octaves_0))
        {
            sum2_0 = sum_3 + n_8 * amp_0;
            break;
        }
        var sum_4 : f32 = sum_3 + n_8 * amp_0;
        var maxamp_1 : f32 = maxamp_0 + amp_0;
        var amp_1 : f32 = amp_0 * roughness_4;
        var fscale_1 : f32 = fscale_0 * lacunarity_0;
        i_4 = i_4 + i32(1);
        fscale_0 = fscale_1;
        sum_3 = sum_4;
        amp_0 = amp_1;
        maxamp_0 = maxamp_1;
    }
    if(_S177)
    {
        var a_11 : f32;
        if(normalize_0)
        {
            a_11 = 0.5f * sum_3 / maxamp_0 + 0.5f;
        }
        else
        {
            a_11 = sum_3;
        }
        var b_8 : f32;
        if(normalize_0)
        {
            b_8 = 0.5f * sum2_0 / (maxamp_0 + amp_0) + 0.5f;
        }
        else
        {
            b_8 = sum2_0;
        }
        return mix(a_11, b_8, rmd_0);
    }
    if(normalize_0)
    {
        fscale_0 = 0.5f * sum_3 / maxamp_0 + 0.5f;
    }
    else
    {
        fscale_0 = sum_3;
    }
    return fscale_0;
}

fn BlenderNoise_0( co_0 : vec3<f32>,  params_0 : vec4<f32>,  normalize_1 : bool,  color_3 : bool) -> vec3<f32>
{
    var _S179 : f32 = clamp(params_0.x, 0.0f, 15.0f);
    var _S180 : f32 = max(params_0.y, 0.0f);
    var _S181 : f32 = params_0.z;
    var distortion_0 : f32 = params_0.w;
    var k_1 : u32;
    var p_5 : vec3<f32>;
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
        p_5 = co_0 + offset_0 * vec3<f32>(distortion_0);
    }
    else
    {
        p_5 = co_0;
    }
    var result_3 : vec3<f32>;
    k_1 = u32(0);
    loop
    {
        var _S182 : u32;
        if(color_3)
        {
            _S182 = u32(3);
        }
        else
        {
            _S182 = u32(1);
        }
        if((k_1 < _S182))
        {
        }
        else
        {
            break;
        }
        var _S183 : vec3<f32>;
        if(k_1 == u32(0))
        {
            _S183 = p_5;
        }
        else
        {
            _S183 = p_5 + RandomOffset3_0(f32(k_1 + u32(2)));
        }
        result_3[k_1] = NoiseFbm_0(_S183, _S179, _S180, _S181, normalize_1);
        k_1 = k_1 + u32(1);
    }
    if(color_3)
    {
        p_5 = result_3;
    }
    else
    {
        p_5 = vec3<f32>(result_3.x);
    }
    return p_5;
}

fn BlenderMagic_0( p_6 : vec3<f32>,  depth_0 : u32,  d_6 : f32) -> vec3<f32>
{
    var TWO_PI_0 : f32 = 2.0f * float_getPi_0();
    var px_0 : f32 = FMod_0(p_6.x, TWO_PI_0);
    var py_0 : f32 = FMod_0(p_6.y, TWO_PI_0);
    var pz_0 : f32 = FMod_0(p_6.z, TWO_PI_0);
    var x_17 : f32 = sin((px_0 + py_0 + pz_0) * 5.0f);
    var _S184 : f32 = - px_0;
    var y_6 : f32 = cos((_S184 + py_0 - pz_0) * 5.0f);
    var z_6 : f32 = - cos((_S184 - py_0 + pz_0) * 5.0f);
    var x_18 : f32;
    var z_7 : f32;
    var y_7 : f32;
    if((depth_0 > u32(0)))
    {
        var x_19 : f32 = x_17 * d_6;
        var z_8 : f32 = z_6 * d_6;
        var y_8 : f32 = - cos(x_19 - y_6 * d_6 + z_8) * d_6;
        if((depth_0 > u32(1)))
        {
            x_18 = cos(x_19 - y_8 - z_8) * d_6;
        }
        else
        {
            x_18 = x_19;
        }
        if((depth_0 > u32(2)))
        {
            z_7 = sin(- x_18 - y_8 - z_8) * d_6;
        }
        else
        {
            z_7 = z_8;
        }
        if((depth_0 > u32(3)))
        {
            x_18 = - cos(- x_18 + y_8 - z_7) * d_6;
        }
        if((depth_0 > u32(4)))
        {
            y_7 = - sin(- x_18 + y_8 + z_7) * d_6;
        }
        else
        {
            y_7 = y_8;
        }
        if((depth_0 > u32(5)))
        {
            y_7 = - cos(- x_18 + y_7 + z_7) * d_6;
        }
        if((depth_0 > u32(6)))
        {
            x_18 = cos(x_18 + y_7 + z_7) * d_6;
        }
        if((depth_0 > u32(7)))
        {
            z_7 = sin(x_18 + y_7 - z_7) * d_6;
        }
        if((depth_0 > u32(8)))
        {
            x_18 = - cos(- x_18 - y_7 + z_7) * d_6;
        }
        if((depth_0 > u32(9)))
        {
            y_7 = - sin(x_18 - y_7 + z_7) * d_6;
        }
    }
    else
    {
        x_18 = x_17;
        y_7 = y_6;
        z_7 = z_6;
    }
    if(d_6 != 0.0f)
    {
        var _S185 : f32 = 2.0f * d_6;
        var y_9 : f32 = y_7 / _S185;
        var z_9 : f32 = z_7 / _S185;
        x_18 = x_18 / _S185;
        y_7 = y_9;
        z_7 = z_9;
    }
    return vec3<f32>(0.5f - x_18, 0.5f - y_7, 0.5f - z_7);
}

fn BlenderChecker_0( p_7 : vec3<f32>) -> f32
{
    var i_5 : vec3<i32> = abs(vec3<i32>(floor((p_7 + vec3<f32>(9.99999997475242708e-07f)) * vec3<f32>(0.99999898672103882f))));
    var _S186 : f32;
    if(((((i_5.x) & (i32(1)))) == (((i_5.y) & (i32(1))))) == ((((i_5.z) & (i32(1)))) == i32(1)))
    {
        _S186 = 1.0f;
    }
    else
    {
        _S186 = 0.0f;
    }
    return _S186;
}

fn RunMaterialProgram_0( header_1 : MaterialHeader_0,  program_0 : u32,  ctx_0 : MaterialContext_0,  outputs_0 : ptr<function, MaterialOutputs_0>)
{
    var stack_0 : array<vec4<f32>, i32(16)>;
    var n_9 : u32 = u32(0);
    var pc_0 : u32 = program_0;
    loop
    {
        if((n_9 < u32(1024)))
        {
        }
        else
        {
            break;
        }
        var ins_0 : vec4<u32> = gMaterialData_0[pc_0];
        var _S187 : u32 = ins_0.x;
        var op_0 : u32 = (_S187 & (u32(255)));
        var dst_0 : u32 = (((_S187 >> (u32(8)))) & (u32(15)));
        var imm_0 : u32 = (_S187 >> (u32(16)));
        if(op_0 == u32(0))
        {
            return;
        }
        var _S188 : u32 = ins_0.y;
        var a_12 : vec4<f32> = MaterialOperand_0(_S188, stack_0[(_S188 & (u32(15)))], header_1.constantBase_0);
        var _S189 : u32 = ins_0.z;
        var b_9 : vec4<f32> = MaterialOperand_0(_S189, stack_0[(_S189 & (u32(15)))], header_1.constantBase_0);
        var _S190 : u32 = ins_0.w;
        var c_9 : vec4<f32> = MaterialOperand_0(_S190, stack_0[(_S190 & (u32(15)))], header_1.constantBase_0);
        var operands_0 : u32 = pc_0 * u32(4) + u32(1);
        var _S191 : u32;
        if(op_0 == u32(23))
        {
            _S191 = (((u32(351898) >> ((u32(2) * min(imm_0, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_0 == u32(17))
            {
                _S191 = u32(1) + imm_0 / u32(4);
            }
            else
            {
                _S191 = u32(1);
            }
        }
        var pc_1 : u32 = pc_0 + _S191;
        var _S192 : vec4<f32> = vec4<f32>(0.0f);
        var r_6 : vec4<f32> = _S192;
        var _S193 : vec4<f32>;
        var write_0 : bool;
        switch(op_0)
        {
        case u32(1):
            {
                r_6 = a_12 + b_9;
                write_0 = true;
            }
        case u32(2):
            {
                r_6 = a_12 - b_9;
                write_0 = true;
            }
        case u32(3):
            {
                r_6 = a_12 * b_9;
                write_0 = true;
            }
        case u32(4):
            {
                r_6 = a_12 / b_9;
                write_0 = true;
            }
        case u32(5):
            {
                r_6 = min(a_12, b_9);
                write_0 = true;
            }
        case u32(6):
            {
                r_6 = max(a_12, b_9);
                write_0 = true;
            }
        case u32(7):
            {
                r_6 = pow(a_12, b_9);
                write_0 = true;
            }
        case u32(8):
            {
                r_6 = atan2(a_12, b_9);
                write_0 = true;
            }
        case u32(9):
            {
                r_6 = sqrt(a_12);
                write_0 = true;
            }
        case u32(10):
            {
                r_6 = sin(a_12);
                write_0 = true;
            }
        case u32(11):
            {
                r_6 = cos(a_12);
                write_0 = true;
            }
        case u32(12):
            {
                r_6 = abs(a_12);
                write_0 = true;
            }
        case u32(13):
            {
                r_6 = min(max(a_12, b_9), c_9);
                write_0 = true;
            }
        case u32(14):
            {
                r_6 = mix(a_12, b_9, c_9);
                write_0 = true;
            }
        case u32(15):
            {
                r_6 = vec4<f32>(a_12[min(imm_0, u32(3))]);
                write_0 = true;
            }
        case u32(16):
            {
                r_6 = select(vec4<f32>(f32((imm_0 >> (u32(8))))), a_12, LanesBelow_0((imm_0 & (u32(255)))));
                write_0 = true;
            }
        case u32(17):
            {
                r_6 = vec4<f32>(a_12.x, b_9.x, c_9.x, 0.0f);
                if((imm_0 > u32(3)))
                {
                    var o_0 : u32 = MaterialWord_0(operands_0 + u32(3));
                    r_6[i32(3)] = MaterialOperand_0(o_0, stack_0[(o_0 & (u32(15)))], header_1.constantBase_0).x;
                }
                write_0 = true;
            }
        case u32(18):
            {
                var lanes_0 : vec4<bool> = LanesBelow_0(imm_0);
                r_6 = vec4<f32>(dot(select(_S192, a_12, lanes_0), select(_S192, b_9, lanes_0)));
                write_0 = true;
            }
        case u32(19):
            {
                var len_0 : f32 = length(select(_S192, a_12, LanesBelow_0(imm_0)));
                if((len_0 > 0.0f))
                {
                    _S193 = a_12 / vec4<f32>(len_0);
                }
                else
                {
                    _S193 = _S192;
                }
                r_6 = _S193;
                write_0 = true;
            }
        case u32(20):
            {
                if(imm_0 == u32(0))
                {
                    r_6 = vec4<f32>(ctx_0.tex_0.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_0 == u32(1))
                    {
                        r_6 = vec4<f32>(ctx_0.tex_0.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_0 == u32(6))
                        {
                            r_6 = vec4<f32>(ctx_0.tex_0.objectPosition_0, 0.0f);
                        }
                        else
                        {
                            if(imm_0 == u32(2))
                            {
                                r_6 = vec4<f32>(ctx_0.position_0, 0.0f);
                            }
                            else
                            {
                                if(imm_0 == u32(3))
                                {
                                    r_6 = vec4<f32>(ctx_0.normal_10, 0.0f);
                                }
                                else
                                {
                                    if(imm_0 == u32(4))
                                    {
                                        r_6 = ctx_0.tangent_1;
                                    }
                                    else
                                    {
                                        r_6 = vec4<f32>(Bitangent_0(ctx_0.tangent_1, ctx_0.normal_10), 0.0f);
                                    }
                                }
                            }
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
                    var _S194 : vec4<f32> = SampleTexture_0(ref_8, ctx_0.tex_0);
                    _S193 = _S194;
                }
                else
                {
                    _S193 = vec4<f32>(1.0f);
                }
                r_6 = _S193;
                write_0 = true;
            }
        case u32(22):
            {
                r_6 = vec4<f32>(ApplyNormalMap_0(ctx_0.tangent_1, ctx_0.normal_10, a_12.xyz, b_9.x), 0.0f);
                write_0 = true;
            }
        case u32(24):
            {
                r_6 = floor(a_12);
                write_0 = true;
            }
        case u32(25):
            {
                r_6 = vec4<f32>((vec4<i32>(sign((a_12)))));
                write_0 = true;
            }
        case u32(26):
            {
                r_6 = exp(a_12);
                write_0 = true;
            }
        case u32(27):
            {
                r_6 = log(a_12);
                write_0 = true;
            }
        case u32(28):
            {
                r_6 = a_12 - b_9 * floor(a_12 / b_9);
                write_0 = true;
            }
        case u32(29):
            {
                r_6 = select(_S192, vec4<f32>(1.0f), (a_12 > b_9));
                write_0 = true;
            }
        case u32(30):
            {
                r_6 = vec4<f32>(cross(a_12.xyz, b_9.xyz), 0.0f);
                write_0 = true;
            }
        case u32(31):
            {
                var _S195 : vec3<f32>;
                if(imm_0 == u32(1))
                {
                    _S195 = TransformVector_0(ctx_0.instanceIndex_0, a_12.xyz);
                }
                else
                {
                    _S195 = InverseTransformVector_0(ctx_0.instanceIndex_0, a_12.xyz);
                }
                r_6 = vec4<f32>(_S195, 0.0f);
                write_0 = true;
            }
        case u32(32):
            {
                var _S196 : bool = ((imm_0 & (u32(2)))) != u32(0);
                var v_10 : vec3<f32> = BlenderNoise_0(a_12.xyz, b_9, ((imm_0 & (u32(1)))) != u32(0), _S196);
                if(_S196)
                {
                    _S193 = vec4<f32>(v_10, 0.0f);
                }
                else
                {
                    _S193 = vec4<f32>(v_10.x);
                }
                r_6 = _S193;
                write_0 = true;
            }
        case u32(33):
            {
                var c_10 : vec3<f32> = BlenderMagic_0(a_12.xyz, imm_0, b_9.x);
                r_6 = vec4<f32>(c_10, (c_10.x + c_10.y + c_10.z) / 3.0f);
                write_0 = true;
            }
        case u32(34):
            {
                r_6 = vec4<f32>(BlenderChecker_0(a_12.xyz));
                write_0 = true;
            }
        case u32(23):
            {
                switch(imm_0)
                {
                case u32(0):
                    {
                        var o_1 : u32 = MaterialWord_0(operands_0);
                        if(o_1 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.baseWeight_0 = MaterialOperand_0(o_1, stack_0[(o_1 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_2 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_2 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.baseColor_0 = MaterialOperand_0(o_2, stack_0[(o_2 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_3 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_3 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.baseDiffuseRoughness_0 = MaterialOperand_0(o_3, stack_0[(o_3 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_4 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_4 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.baseMetalness_0 = MaterialOperand_0(o_4, stack_0[(o_4 & (u32(15)))], header_1.constantBase_0).x;
                        }
                    }
                case u32(1):
                    {
                        var o_5 : u32 = MaterialWord_0(operands_0);
                        if(o_5 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularWeight_0 = MaterialOperand_0(o_5, stack_0[(o_5 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_6 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_6 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularColor_0 = MaterialOperand_0(o_6, stack_0[(o_6 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_7 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_7 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularRoughness_0 = MaterialOperand_0(o_7, stack_0[(o_7 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_8 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_8 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularIor_0 = MaterialOperand_0(o_8, stack_0[(o_8 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_9 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_9 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularDielectricOnly_0 = (MaterialOperand_0(o_9, stack_0[(o_9 & (u32(15)))], header_1.constantBase_0).x) != 0.0f;
                        }
                    }
                case u32(2):
                    {
                        var o_10 : u32 = MaterialWord_0(operands_0);
                        if(o_10 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.specularRoughnessAnisotropy_0 = MaterialOperand_0(o_10, stack_0[(o_10 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_11 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_11 != u32(4294967295))
                        {
                            (*outputs_0).tangent_2 = MaterialOperand_0(o_11, stack_0[(o_11 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                    }
                case u32(3):
                    {
                        var o_12 : u32 = MaterialWord_0(operands_0);
                        if(o_12 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionWeight_0 = MaterialOperand_0(o_12, stack_0[(o_12 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_13 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_13 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionColor_0 = MaterialOperand_0(o_13, stack_0[(o_13 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_14 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_14 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionDepth_0 = MaterialOperand_0(o_14, stack_0[(o_14 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_15 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_15 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionScatter_0 = MaterialOperand_0(o_15, stack_0[(o_15 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_16 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_16 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionScatterAnisotropy_0 = MaterialOperand_0(o_16, stack_0[(o_16 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_17 : u32 = MaterialWord_0(operands_0 + u32(5));
                        if(o_17 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionDispersionScale_0 = MaterialOperand_0(o_17, stack_0[(o_17 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_18 : u32 = MaterialWord_0(operands_0 + u32(6));
                        if(o_18 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.transmissionDispersionAbbeNumber_0 = MaterialOperand_0(o_18, stack_0[(o_18 & (u32(15)))], header_1.constantBase_0).x;
                        }
                    }
                case u32(4):
                    {
                        var o_19 : u32 = MaterialWord_0(operands_0);
                        if(o_19 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.subsurfaceWeight_0 = MaterialOperand_0(o_19, stack_0[(o_19 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_20 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_20 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.subsurfaceColor_0 = MaterialOperand_0(o_20, stack_0[(o_20 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_21 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_21 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.subsurfaceRadius_0 = MaterialOperand_0(o_21, stack_0[(o_21 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_22 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_22 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.subsurfaceRadiusScale_0 = MaterialOperand_0(o_22, stack_0[(o_22 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_23 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_23 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.subsurfaceScatterAnisotropy_0 = MaterialOperand_0(o_23, stack_0[(o_23 & (u32(15)))], header_1.constantBase_0).x;
                        }
                    }
                case u32(5):
                    {
                        var o_24 : u32 = MaterialWord_0(operands_0);
                        if(o_24 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatWeight_0 = MaterialOperand_0(o_24, stack_0[(o_24 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_25 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_25 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatColor_0 = MaterialOperand_0(o_25, stack_0[(o_25 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_26 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_26 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatRoughness_0 = MaterialOperand_0(o_26, stack_0[(o_26 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_27 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_27 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatRoughnessAnisotropy_0 = MaterialOperand_0(o_27, stack_0[(o_27 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_28 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_28 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatIor_0 = MaterialOperand_0(o_28, stack_0[(o_28 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_29 : u32 = MaterialWord_0(operands_0 + u32(5));
                        if(o_29 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.coatDarkening_0 = MaterialOperand_0(o_29, stack_0[(o_29 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_30 : u32 = MaterialWord_0(operands_0 + u32(6));
                        if(o_30 != u32(4294967295))
                        {
                            (*outputs_0).coatNormal_0 = MaterialOperand_0(o_30, stack_0[(o_30 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_31 : u32 = MaterialWord_0(operands_0 + u32(7));
                        if(o_31 != u32(4294967295))
                        {
                            (*outputs_0).coatTangent_0 = MaterialOperand_0(o_31, stack_0[(o_31 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                    }
                case u32(6):
                    {
                        var o_32 : u32 = MaterialWord_0(operands_0);
                        if(o_32 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.fuzzWeight_0 = MaterialOperand_0(o_32, stack_0[(o_32 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_33 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_33 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.fuzzColor_0 = MaterialOperand_0(o_33, stack_0[(o_33 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                        var o_34 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_34 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.fuzzRoughness_0 = MaterialOperand_0(o_34, stack_0[(o_34 & (u32(15)))], header_1.constantBase_0).x;
                        }
                    }
                case u32(7):
                    {
                        var o_35 : u32 = MaterialWord_0(operands_0);
                        if(o_35 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.thinFilmWeight_1 = MaterialOperand_0(o_35, stack_0[(o_35 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_36 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_36 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.thinFilmThickness_1 = MaterialOperand_0(o_36, stack_0[(o_36 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_37 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_37 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.thinFilmIor_1 = MaterialOperand_0(o_37, stack_0[(o_37 & (u32(15)))], header_1.constantBase_0).x;
                        }
                    }
                case u32(8):
                    {
                        var o_38 : u32 = MaterialWord_0(operands_0);
                        if(o_38 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_38, stack_0[(o_38 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_39 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_39 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.emissionColor_0 = MaterialOperand_0(o_39, stack_0[(o_39 & (u32(15)))], header_1.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_40 : u32 = MaterialWord_0(operands_0);
                        if(o_40 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_40, stack_0[(o_40 & (u32(15)))], header_1.constantBase_0).x;
                        }
                        var o_41 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_41 != u32(4294967295))
                        {
                            (*outputs_0).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_41, stack_0[(o_41 & (u32(15)))], header_1.constantBase_0).x) != 0.0f;
                        }
                        var o_42 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_42 != u32(4294967295))
                        {
                            (*outputs_0).normal_11 = MaterialOperand_0(o_42, stack_0[(o_42 & (u32(15)))], header_1.constantBase_0).xyz;
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
            stack_0[dst_0] = r_6;
        }
        n_9 = n_9 + u32(1);
        pc_0 = pc_1;
    }
    return;
}

fn rsqrt_0( x_20 : f32) -> f32
{
    return 1.0f / sqrt(x_20);
}

fn RunMaterialProgram_1( header_2 : MaterialHeader_0,  program_1 : u32,  ctx_1 : MaterialContext_0,  outputs_1 : ptr<function, MaterialOutputs_0>)
{
    var stack_1 : array<vec4<f32>, i32(16)>;
    var n_10 : u32 = u32(0);
    var pc_2 : u32 = program_1;
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
        var _S197 : u32 = ins_1.x;
        var op_1 : u32 = (_S197 & (u32(255)));
        var dst_1 : u32 = (((_S197 >> (u32(8)))) & (u32(15)));
        var imm_1 : u32 = (_S197 >> (u32(16)));
        if(op_1 == u32(0))
        {
            return;
        }
        var _S198 : u32 = ins_1.y;
        var a_13 : vec4<f32> = MaterialOperand_0(_S198, stack_1[(_S198 & (u32(15)))], header_2.constantBase_0);
        var _S199 : u32 = ins_1.z;
        var b_10 : vec4<f32> = MaterialOperand_0(_S199, stack_1[(_S199 & (u32(15)))], header_2.constantBase_0);
        var _S200 : u32 = ins_1.w;
        var c_11 : vec4<f32> = MaterialOperand_0(_S200, stack_1[(_S200 & (u32(15)))], header_2.constantBase_0);
        var operands_1 : u32 = pc_2 * u32(4) + u32(1);
        var _S201 : u32;
        if(op_1 == u32(23))
        {
            _S201 = (((u32(351898) >> ((u32(2) * min(imm_1, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_1 == u32(17))
            {
                _S201 = u32(1) + imm_1 / u32(4);
            }
            else
            {
                _S201 = u32(1);
            }
        }
        var pc_3 : u32 = pc_2 + _S201;
        var _S202 : vec4<f32> = vec4<f32>(0.0f);
        var r_7 : vec4<f32> = _S202;
        var _S203 : vec4<f32>;
        var write_1 : bool;
        switch(op_1)
        {
        case u32(1):
            {
                r_7 = a_13 + b_10;
                write_1 = true;
            }
        case u32(2):
            {
                r_7 = a_13 - b_10;
                write_1 = true;
            }
        case u32(3):
            {
                r_7 = a_13 * b_10;
                write_1 = true;
            }
        case u32(4):
            {
                r_7 = a_13 / b_10;
                write_1 = true;
            }
        case u32(5):
            {
                r_7 = min(a_13, b_10);
                write_1 = true;
            }
        case u32(6):
            {
                r_7 = max(a_13, b_10);
                write_1 = true;
            }
        case u32(7):
            {
                r_7 = pow(a_13, b_10);
                write_1 = true;
            }
        case u32(8):
            {
                r_7 = atan2(a_13, b_10);
                write_1 = true;
            }
        case u32(9):
            {
                r_7 = sqrt(a_13);
                write_1 = true;
            }
        case u32(10):
            {
                r_7 = sin(a_13);
                write_1 = true;
            }
        case u32(11):
            {
                r_7 = cos(a_13);
                write_1 = true;
            }
        case u32(12):
            {
                r_7 = abs(a_13);
                write_1 = true;
            }
        case u32(13):
            {
                r_7 = min(max(a_13, b_10), c_11);
                write_1 = true;
            }
        case u32(14):
            {
                r_7 = mix(a_13, b_10, c_11);
                write_1 = true;
            }
        case u32(15):
            {
                r_7 = vec4<f32>(a_13[min(imm_1, u32(3))]);
                write_1 = true;
            }
        case u32(16):
            {
                r_7 = select(vec4<f32>(f32((imm_1 >> (u32(8))))), a_13, LanesBelow_0((imm_1 & (u32(255)))));
                write_1 = true;
            }
        case u32(17):
            {
                r_7 = vec4<f32>(a_13.x, b_10.x, c_11.x, 0.0f);
                if((imm_1 > u32(3)))
                {
                    var o_43 : u32 = MaterialWord_0(operands_1 + u32(3));
                    r_7[i32(3)] = MaterialOperand_0(o_43, stack_1[(o_43 & (u32(15)))], header_2.constantBase_0).x;
                }
                write_1 = true;
            }
        case u32(18):
            {
                var lanes_1 : vec4<bool> = LanesBelow_0(imm_1);
                r_7 = vec4<f32>(dot(select(_S202, a_13, lanes_1), select(_S202, b_10, lanes_1)));
                write_1 = true;
            }
        case u32(19):
            {
                var len_1 : f32 = length(select(_S202, a_13, LanesBelow_0(imm_1)));
                if((len_1 > 0.0f))
                {
                    _S203 = a_13 / vec4<f32>(len_1);
                }
                else
                {
                    _S203 = _S202;
                }
                r_7 = _S203;
                write_1 = true;
            }
        case u32(20):
            {
                if(imm_1 == u32(0))
                {
                    r_7 = vec4<f32>(ctx_1.tex_0.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_1 == u32(1))
                    {
                        r_7 = vec4<f32>(ctx_1.tex_0.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_1 == u32(6))
                        {
                            r_7 = vec4<f32>(ctx_1.tex_0.objectPosition_0, 0.0f);
                        }
                    }
                }
                write_1 = true;
            }
        case u32(21):
            {
                var ref_9 : TextureRef_0 = LoadTextureRef_0(header_2, imm_1);
                if(HasTexture_0(ref_9))
                {
                    var _S204 : vec4<f32> = SampleTexture_0(ref_9, ctx_1.tex_0);
                    _S203 = _S204;
                }
                else
                {
                    _S203 = vec4<f32>(1.0f);
                }
                r_7 = _S203;
                write_1 = true;
            }
        case u32(22):
            {
                write_1 = true;
            }
        case u32(24):
            {
                r_7 = floor(a_13);
                write_1 = true;
            }
        case u32(25):
            {
                r_7 = vec4<f32>((vec4<i32>(sign((a_13)))));
                write_1 = true;
            }
        case u32(26):
            {
                r_7 = exp(a_13);
                write_1 = true;
            }
        case u32(27):
            {
                r_7 = log(a_13);
                write_1 = true;
            }
        case u32(28):
            {
                r_7 = a_13 - b_10 * floor(a_13 / b_10);
                write_1 = true;
            }
        case u32(29):
            {
                r_7 = select(_S202, vec4<f32>(1.0f), (a_13 > b_10));
                write_1 = true;
            }
        case u32(30):
            {
                r_7 = vec4<f32>(cross(a_13.xyz, b_10.xyz), 0.0f);
                write_1 = true;
            }
        case u32(31):
            {
                write_1 = true;
            }
        case u32(32):
            {
                var _S205 : bool = ((imm_1 & (u32(2)))) != u32(0);
                var v_11 : vec3<f32> = BlenderNoise_0(a_13.xyz, b_10, ((imm_1 & (u32(1)))) != u32(0), _S205);
                if(_S205)
                {
                    _S203 = vec4<f32>(v_11, 0.0f);
                }
                else
                {
                    _S203 = vec4<f32>(v_11.x);
                }
                r_7 = _S203;
                write_1 = true;
            }
        case u32(33):
            {
                var c_12 : vec3<f32> = BlenderMagic_0(a_13.xyz, imm_1, b_10.x);
                r_7 = vec4<f32>(c_12, (c_12.x + c_12.y + c_12.z) / 3.0f);
                write_1 = true;
            }
        case u32(34):
            {
                r_7 = vec4<f32>(BlenderChecker_0(a_13.xyz));
                write_1 = true;
            }
        case u32(23):
            {
                switch(imm_1)
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
                        var o_44 : u32 = MaterialWord_0(operands_1);
                        if(o_44 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_44, stack_1[(o_44 & (u32(15)))], header_2.constantBase_0).x;
                        }
                        var o_45 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_45 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.emissionColor_0 = MaterialOperand_0(o_45, stack_1[(o_45 & (u32(15)))], header_2.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_46 : u32 = MaterialWord_0(operands_1);
                        if(o_46 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_46, stack_1[(o_46 & (u32(15)))], header_2.constantBase_0).x;
                        }
                        var o_47 : u32 = MaterialWord_0(operands_1 + u32(1));
                        if(o_47 != u32(4294967295))
                        {
                            (*outputs_1).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_47, stack_1[(o_47 & (u32(15)))], header_2.constantBase_0).x) != 0.0f;
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
            stack_1[dst_1] = r_7;
        }
        n_10 = n_10 + u32(1);
        pc_2 = pc_3;
    }
    return;
}

fn rcp_0( x_21 : f32) -> f32
{
    return 1.0f / x_21;
}

fn rcp_1( x_22 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(1.0f) / x_22;
}

fn WorkPixel_0( index_12 : u32) -> vec2<u32>
{
    var pixel_0 : u32 = gWavefront_0.tileStart_0 + index_12;
    var _S206 : u32 = pixel_0 % gFrame_0.frame_0.x;
    var _S207 : u32 = pixel_0 / gFrame_0.frame_0.x;
    return vec2<u32>(_S206, _S207);
}

fn StrongIntegerHash_0( x_23 : u32) -> u32
{
    var _S208 : u32 = ((x_23 ^ (((x_23 >> (u32(16))))))) * u32(2819806515);
    var _S209 : u32 = ((_S208 ^ (((_S208 >> (u32(15))))))) * u32(2994267309);
    return (_S209 ^ (((_S209 >> (u32(17))))));
}

struct RandomSequence_0
{
     seed_1 : u32,
};

fn RandomSequence_x24init_0( pixel_1 : vec2<u32>,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S210 : RandomSequence_0;
    _S210.seed_1 = StrongIntegerHash_0(pixel_1.x + pixel_1.y * u32(65536) + StrongIntegerHash_0(timeSeed_0));
    return _S210;
}

fn RandomSequence_Next_0( this_96 : ptr<function, RandomSequence_0>) -> f32
{
    var _S211 : u32 = (*this_96).seed_1 + u32(1);
    (*this_96).seed_1 = _S211;
    return f32(((StrongIntegerHash_0(_S211)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next_1( this_97 : ptr<function, RandomSequence_0>) -> f32
{
    var _S212 : u32 = (*this_97).seed_1 + u32(1);
    (*this_97).seed_1 = _S212;
    return f32(((StrongIntegerHash_0(_S212)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_98 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_24 : f32 = RandomSequence_Next_1(&((*this_98)));
    var y_10 : f32 = RandomSequence_Next_1(&((*this_98)));
    return vec2<f32>(x_24, y_10);
}

fn SampleDisk_0( u_23 : vec2<f32>) -> vec2<f32>
{
    var angle_1 : f32 = 2.0f * float_getPi_0() * u_23.x;
    return vec2<f32>(cos(angle_1), sin(angle_1)) * vec2<f32>(sqrt(u_23.y));
}

struct Ray_0
{
     origin_0 : vec3<f32>,
     tMin_0 : f32,
     direction_0 : vec3<f32>,
     tMax_0 : f32,
};

fn Ray_x24init_0( o_48 : vec3<f32>,  d_7 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S213 : Ray_0;
    _S213.origin_0 = o_48;
    _S213.direction_0 = d_7;
    _S213.tMin_0 = 0.0f;
    _S213.tMax_0 = tmax_0;
    return _S213;
}

fn GenerateCameraRay_0( pixel_2 : vec2<u32>,  rng_0 : ptr<function, RandomSequence_0>) -> Ray_0
{
    var _S214 : vec2<f32> = vec2<f32>(gFrame_0.frame_0.xy);
    var _S215 : vec2<f32> = vec2<f32>(pixel_2);
    var _S216 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_0)));
    var film_2 : vec2<f32> = (_S215 + _S216) / _S214;
    var forward_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var dir_0 : vec3<f32> = normalize(forward_0 + gFrame_0.cameraRight_0.xyz * vec3<f32>((film_2.x * 2.0f - 1.0f)) + gFrame_0.cameraUp_0.xyz * vec3<f32>((1.0f - film_2.y * 2.0f)));
    var origin_1 : vec3<f32> = gFrame_0.cameraPosition_0.xyz;
    var lensRadius_0 : f32 = gFrame_0.cameraPosition_0.w;
    var dir_1 : vec3<f32>;
    var origin_2 : vec3<f32>;
    if((lensRadius_0 > 0.0f))
    {
        var focusPoint_0 : vec3<f32> = origin_1 + dir_0 * vec3<f32>((gFrame_0.cameraRight_0.w / dot(dir_0, forward_0)));
        var _S217 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_0)));
        var lens_0 : vec2<f32> = SampleDisk_0(_S217) * vec2<f32>(lensRadius_0);
        var origin_3 : vec3<f32> = origin_1 + (normalize(gFrame_0.cameraRight_0.xyz) * vec3<f32>(lens_0.x) + normalize(gFrame_0.cameraUp_0.xyz) * vec3<f32>(lens_0.y));
        dir_1 = normalize(focusPoint_0 - origin_3);
        origin_2 = origin_3;
    }
    else
    {
        dir_1 = dir_0;
        origin_2 = origin_1;
    }
    return Ray_x24init_0(origin_2, dir_1, 1.00000001504746622e+30f);
}

fn WorkBase_0( index_13 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + index_13 * u32(21);
}

struct PathState_0
{
     radiance_0 : vec3<f32>,
     throughput_12 : vec3<f32>,
     origin_4 : vec3<f32>,
     direction_1 : vec3<f32>,
     scatterPdf_0 : f32,
     lobe_5 : u32,
     coneWidth_0 : f32,
     coneSpread_0 : f32,
     absorption_0 : vec3<f32>,
     lightsSampled_0 : bool,
};

struct WavefrontPath_0
{
     path_0 : PathState_0,
     active_0 : u32,
     randomSeed_0 : u32,
     albedo_1 : vec3<f32>,
     normal_12 : vec3<f32>,
};

fn StorePath_0( base_4 : u32,  s_13 : WavefrontPath_0)
{
    gAccum_0[base_4] = vec4<f32>(s_13.path_0.radiance_0, (bitcast<f32>((s_13.active_0))));
    gAccum_0[base_4 + u32(1)] = vec4<f32>(s_13.path_0.throughput_12, (bitcast<f32>((s_13.randomSeed_0))));
    gAccum_0[base_4 + u32(2)] = vec4<f32>(s_13.path_0.origin_4, s_13.path_0.scatterPdf_0);
    gAccum_0[base_4 + u32(3)] = vec4<f32>(s_13.path_0.direction_1, (bitcast<f32>((select(u32(0), u32(1), s_13.path_0.lightsSampled_0)))));
    gAccum_0[base_4 + u32(4)] = vec4<f32>(s_13.path_0.absorption_0, s_13.path_0.coneWidth_0);
    gAccum_0[base_4 + u32(5)] = vec4<f32>(s_13.albedo_1, s_13.path_0.coneSpread_0);
    gAccum_0[base_4 + u32(6)] = vec4<f32>(s_13.normal_12, 0.0f);
    return;
}

fn InitVirtualTextureFeedback_0( pixel_3 : vec2<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = StrongIntegerHash_0(((pixel_3.x) ^ ((StrongIntegerHash_0(((pixel_3.y) ^ ((StrongIntegerHash_0(gFrame_0.frame_0.w)))))))));
    return;
}

fn StoreFeedbackState_0( base_5 : u32)
{
    gAccum_0[base_5 + u32(7)] = (bitcast<vec4<f32>>((vec4<u32>(gVTRequest_0, gVTRequestCount_0, gVTRandom_0, u32(0)))));
    return;
}

fn _S218() -> vec2<f32>
{
    return vec2<f32>(0.0f);
}

var<private> gRayCone_0 : vec2<f32>;

var<private> gTraversalCost_0 : u32;

@compute
@workgroup_size(64, 1, 1)
fn Initialize(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S218();
    gTraversalCost_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_14 : u32 = tid_0.x;
    if((index_14 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var pixel_4 : vec2<u32> = WorkPixel_0(index_14);
    var rng_1 : RandomSequence_0 = RandomSequence_x24init_0(pixel_4, gFrame_0.frame_0.w);
    var ray_0 : Ray_0 = GenerateCameraRay_0(pixel_4, &(rng_1));
    var s_14 : WavefrontPath_0;
    var _S219 : vec3<f32> = vec3<f32>(0.0f);
    s_14.path_0.radiance_0 = _S219;
    s_14.path_0.throughput_12 = vec3<f32>(1.0f);
    s_14.path_0.origin_4 = ray_0.origin_0;
    s_14.path_0.direction_1 = ray_0.direction_0;
    s_14.path_0.scatterPdf_0 = 1.0f;
    s_14.path_0.lobe_5 = u32(0);
    s_14.path_0.coneWidth_0 = 0.0f;
    s_14.path_0.coneSpread_0 = gFrame_0.vtParams_0.y;
    s_14.path_0.absorption_0 = _S219;
    s_14.path_0.lightsSampled_0 = false;
    s_14.active_0 = u32(1);
    s_14.randomSeed_0 = rng_1.seed_1;
    s_14.albedo_1 = _S219;
    s_14.normal_12 = _S219;
    var base_6 : u32 = WorkBase_0(index_14);
    StorePath_0(base_6, s_14);
    InitVirtualTextureFeedback_0(pixel_4);
    StoreFeedbackState_0(base_6);
    return;
}

fn LoadPath_0( base_7 : u32) -> WavefrontPath_0
{
    var s_15 : WavefrontPath_0;
    s_15.path_0.radiance_0 = gAccum_0[base_7].xyz;
    s_15.active_0 = (bitcast<u32>((gAccum_0[base_7].w)));
    s_15.path_0.throughput_12 = gAccum_0[base_7 + u32(1)].xyz;
    s_15.randomSeed_0 = (bitcast<u32>((gAccum_0[base_7 + u32(1)].w)));
    s_15.path_0.origin_4 = gAccum_0[base_7 + u32(2)].xyz;
    s_15.path_0.scatterPdf_0 = gAccum_0[base_7 + u32(2)].w;
    s_15.path_0.direction_1 = gAccum_0[base_7 + u32(3)].xyz;
    s_15.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[base_7 + u32(3)].w))) != u32(0);
    s_15.path_0.absorption_0 = gAccum_0[base_7 + u32(4)].xyz;
    s_15.path_0.coneWidth_0 = gAccum_0[base_7 + u32(4)].w;
    s_15.albedo_1 = gAccum_0[base_7 + u32(5)].xyz;
    s_15.path_0.coneSpread_0 = gAccum_0[base_7 + u32(5)].w;
    s_15.normal_12 = gAccum_0[base_7 + u32(6)].xyz;
    s_15.path_0.lobe_5 = u32(0);
    return s_15;
}

fn LoadFeedbackState_0( base_8 : u32)
{
    var state_0 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[base_8 + u32(7)])));
    gVTRequest_0 = state_0.x;
    gVTRequestCount_0 = state_0.y;
    gVTRandom_0 = state_0.z;
    return;
}

fn SafeRcp_0( d_8 : vec3<f32>) -> vec3<f32>
{
    return rcp_1(select(d_8, select(vec3<f32>(9.99999968265522539e-21f), vec3<f32>(-9.99999968265522539e-21f), (d_8 < vec3<f32>(0.0f))), ((abs(d_8)) < vec3<f32>(9.99999968265522539e-21f))));
}

fn IntersectTriangle_0( o_49 : vec3<f32>,  d_9 : vec3<f32>,  v0_0 : vec3<f32>,  e1_0 : vec3<f32>,  e2_0 : vec3<f32>,  tMin_1 : f32,  tMax_1 : f32,  t_5 : ptr<function, f32>,  bary_0 : ptr<function, vec2<f32>>) -> bool
{
    (*t_5) = 0.0f;
    (*bary_0) = vec2<f32>(0.0f);
    var h_12 : vec3<f32> = cross(d_9, e2_0);
    var a_14 : f32 = dot(e1_0, h_12);
    if(a_14 == 0.0f)
    {
        return false;
    }
    var f_14 : f32 = rcp_0(a_14);
    var s_16 : vec3<f32> = o_49 - v0_0;
    var u_24 : f32 = f_14 * dot(s_16, h_12);
    var _S220 : bool;
    if((u_24 < 0.0f))
    {
        _S220 = true;
    }
    else
    {
        _S220 = (u_24 > 1.0f);
    }
    if(_S220)
    {
        return false;
    }
    var q_0 : vec3<f32> = cross(s_16, e1_0);
    var v_12 : f32 = f_14 * dot(d_9, q_0);
    if((v_12 < 0.0f))
    {
        _S220 = true;
    }
    else
    {
        _S220 = ((u_24 + v_12) > 1.0f);
    }
    if(_S220)
    {
        return false;
    }
    (*t_5) = f_14 * dot(e2_0, q_0);
    (*bary_0) = vec2<f32>(u_24, v_12);
    if(((*t_5) > tMin_1))
    {
        _S220 = ((*t_5) < tMax_1);
    }
    else
    {
        _S220 = false;
    }
    return _S220;
}

fn LoadMaterialHeader_0( materialIndex_1 : u32) -> MaterialHeader_0
{
    var _S221 : u32 = materialIndex_1 * u32(2);
    var h0_0 : vec4<u32> = gMaterialData_0[_S221];
    var h1_0 : vec4<u32> = gMaterialData_0[_S221 + u32(1)];
    var h_13 : MaterialHeader_0;
    h_13.surface_0 = h0_0.x;
    h_13.opacity_0 = h0_0.y;
    h_13.emission_0 = h0_0.z;
    h_13.flags_1 = h0_0.w;
    h_13.textureBase_0 = h1_0.x;
    h_13.constantBase_0 = h1_0.y;
    h_13.alphaCutoff_0 = (bitcast<f32>((h1_0.z)));
    h_13.debugTexture_0 = h1_0.w;
    return h_13;
}

fn MaterialHeader_AlphaMode_0( this_99 : MaterialHeader_0) -> u32
{
    return ((((this_99.flags_1) >> (u32(8)))) & (u32(3)));
}

fn VertexUV0_0( v_13 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_13).positionU_0.w, (*v_13).normalV_0.w);
}

fn UVFootprintLog2_0( coneWidth_1 : f32,  worldArea_0 : f32,  uvArea_0 : f32,  cosTheta_7 : f32) -> f32
{
    return log2(max(coneWidth_1, 9.99999968265522539e-21f)) - log2(max(abs(cosTheta_7), 0.0010000000474974513f)) + 0.5f * log2(max(uvArea_0 / max(worldArea_0, 1.00000000317107685e-30f), 1.00000000317107685e-30f));
}

fn MakeTextureCoords_0( uv0_1 : vec2<f32>,  uv1_2 : vec2<f32>,  worldE1_0 : vec3<f32>,  worldE2_0 : vec3<f32>,  uv0E1_0 : vec2<f32>,  uv0E2_0 : vec2<f32>,  uv1E1_0 : vec2<f32>,  uv1E2_0 : vec2<f32>,  coneWidth_2 : f32,  cosTheta_8 : f32) -> TextureCoords_0
{
    var tc_1 : TextureCoords_0;
    tc_1.uv0_0 = uv0_1;
    tc_1.uv1_1 = uv1_2;
    tc_1.objectPosition_0 = vec3<f32>(0.0f);
    var worldArea_1 : f32 = length(cross(worldE1_0, worldE2_0));
    tc_1.footprint0_0 = UVFootprintLog2_0(coneWidth_2, worldArea_1, abs(uv0E1_0.x * uv0E2_0.y - uv0E1_0.y * uv0E2_0.x), cosTheta_8);
    tc_1.footprint1_0 = UVFootprintLog2_0(coneWidth_2, worldArea_1, abs(uv1E1_0.x * uv1E2_0.y - uv1E1_0.y * uv1E2_0.x), cosTheta_8);
    return tc_1;
}

fn MakeMaterialContext_0( tex_1 : TextureCoords_0) -> MaterialContext_0
{
    var ctx_2 : MaterialContext_0;
    ctx_2.tex_0 = tex_1;
    ctx_2.position_0 = vec3<f32>(0.0f);
    ctx_2.normal_10 = vec3<f32>(0.0f, 0.0f, 1.0f);
    ctx_2.tangent_1 = vec4<f32>(0.0f);
    ctx_2.instanceIndex_0 = u32(0);
    return ctx_2;
}

fn BSDFInputs_Default_0() -> BSDFInputs_0
{
    var i_6 : BSDFInputs_0;
    i_6.baseWeight_0 = 1.0f;
    var _S222 : vec3<f32> = vec3<f32>(0.80000001192092896f);
    i_6.baseColor_0 = _S222;
    i_6.baseDiffuseRoughness_0 = 0.0f;
    i_6.baseMetalness_0 = 0.0f;
    i_6.subsurfaceWeight_0 = 0.0f;
    i_6.subsurfaceColor_0 = _S222;
    i_6.subsurfaceRadius_0 = 1.0f;
    i_6.subsurfaceRadiusScale_0 = vec3<f32>(1.0f, 0.5f, 0.25f);
    i_6.subsurfaceScatterAnisotropy_0 = 0.0f;
    i_6.specularWeight_0 = 1.0f;
    i_6.specularDielectricOnly_0 = false;
    var _S223 : vec3<f32> = vec3<f32>(1.0f);
    i_6.specularColor_0 = _S223;
    i_6.specularRoughness_0 = 0.30000001192092896f;
    i_6.specularRoughnessAnisotropy_0 = 0.0f;
    i_6.specularIor_0 = 1.5f;
    const _S224 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    i_6.specularAnisotropyRotation_0 = _S224;
    i_6.coatWeight_0 = 0.0f;
    i_6.coatColor_0 = _S223;
    i_6.coatRoughness_0 = 0.0f;
    i_6.coatRoughnessAnisotropy_0 = 0.0f;
    i_6.coatIor_0 = 1.6000000238418579f;
    i_6.coatDarkening_0 = 1.0f;
    i_6.coatAnisotropyRotation_0 = _S224;
    i_6.fuzzWeight_0 = 0.0f;
    i_6.fuzzColor_0 = _S223;
    i_6.fuzzRoughness_0 = 0.5f;
    i_6.transmissionWeight_0 = 0.0f;
    i_6.transmissionColor_0 = _S223;
    i_6.transmissionDepth_0 = 0.0f;
    i_6.transmissionScatter_0 = vec3<f32>(0.0f);
    i_6.transmissionScatterAnisotropy_0 = 0.0f;
    i_6.transmissionDispersionScale_0 = 0.0f;
    i_6.transmissionDispersionAbbeNumber_0 = 20.0f;
    i_6.thinFilmWeight_1 = 0.0f;
    i_6.thinFilmThickness_1 = 0.5f;
    i_6.thinFilmIor_1 = 1.3999999761581421f;
    i_6.emissionLuminance_0 = 0.0f;
    i_6.emissionColor_0 = _S223;
    i_6.geometryOpacity_0 = 1.0f;
    i_6.geometryThinWalled_0 = false;
    i_6.basis_4.t_0 = vec3<f32>(1.0f, 0.0f, 0.0f);
    i_6.basis_4.b_0 = vec3<f32>(0.0f, 1.0f, 0.0f);
    i_6.basis_4.n_1 = vec3<f32>(0.0f, 0.0f, 1.0f);
    i_6.coatBasis_0 = i_6.basis_4;
    return i_6;
}

fn MaterialOutputs_Default_0( ctx_3 : MaterialContext_0) -> MaterialOutputs_0
{
    var o_50 : MaterialOutputs_0;
    o_50.inputs_0 = BSDFInputs_Default_0();
    o_50.normal_11 = ctx_3.normal_10;
    o_50.coatNormal_0 = ctx_3.normal_10;
    var _S225 : vec3<f32> = ctx_3.tangent_1.xyz;
    o_50.tangent_2 = _S225;
    o_50.coatTangent_0 = _S225;
    return o_50;
}

fn RunScalarMaterialProgram_0( header_3 : MaterialHeader_0,  program_2 : u32,  tc_2 : TextureCoords_0) -> MaterialOutputs_0
{
    var ctx_4 : MaterialContext_0 = MakeMaterialContext_0(tc_2);
    var o_51 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_4);
    RunMaterialProgram_1(header_3, program_2, ctx_4, &(o_51));
    return o_51;
}

fn EvalOpacity_0( header_4 : MaterialHeader_0,  tc_3 : TextureCoords_0) -> f32
{
    if((header_4.opacity_0) == u32(4294967295))
    {
        return 1.0f;
    }
    var _S226 : MaterialOutputs_0 = RunScalarMaterialProgram_0(header_4, header_4.opacity_0, tc_3);
    return _S226.inputs_0.geometryOpacity_0;
}

fn IntersectBox_0( bmin_0 : vec3<f32>,  bmax_0 : vec3<f32>,  o_52 : vec3<f32>,  rD_0 : vec3<f32>,  tMin_2 : f32,  tMax_2 : f32) -> f32
{
    var t1_0 : vec3<f32> = (bmin_0 - o_52) * rD_0;
    var t2_0 : vec3<f32> = (bmax_0 - o_52) * rD_0;
    var _S227 : vec3<f32> = min(t1_0, t2_0);
    var _S228 : vec3<f32> = max(t1_0, t2_0);
    var _S229 : f32 = max(max(_S227.x, _S227.y), max(_S227.z, tMin_2));
    var _S230 : f32;
    if((_S229 <= (min(min(_S228.x, _S228.y), min(_S228.z, tMax_2)))))
    {
        _S230 = _S229;
    }
    else
    {
        _S230 = 1.00000001504746622e+30f;
    }
    return _S230;
}

struct HitRecord_0
{
     t_6 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_1 : u32,
     primitiveIndex_0 : u32,
};

fn InverseTransformPoint_0( _S231 : u32,  _S232 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S231].worldToObject_0[i32(0)].xyz, _S232) + gInstances_0[_S231].worldToObject_0[i32(0)].w, dot(gInstances_0[_S231].worldToObject_0[i32(1)].xyz, _S232) + gInstances_0[_S231].worldToObject_0[i32(1)].w, dot(gInstances_0[_S231].worldToObject_0[i32(2)].xyz, _S232) + gInstances_0[_S231].worldToObject_0[i32(2)].w);
}

fn LoadTriangleIndices_0( _S233 : u32,  _S234 : u32) -> vec3<u32>
{
    var base_9 : u32 = gInstances_0[_S233].indexOffset_0 + _S234 * u32(3);
    return vec3<u32>(gIndices_0[base_9], gIndices_0[base_9 + u32(1)], gIndices_0[base_9 + u32(2)]) + vec3<u32>(gInstances_0[_S233].vertexOffset_0);
}

fn AlphaTestRejects_0( _S235 : u32,  _S236 : u32,  _S237 : vec2<f32>,  _S238 : f32) -> bool
{
    var material_0 : MaterialHeader_0 = LoadMaterialHeader_0(gInstances_0[_S235].materialIndex_0);
    var _S239 : u32 = MaterialHeader_AlphaMode_0(material_0);
    if(_S239 == u32(0))
    {
        return false;
    }
    var _S240 : vec3<u32> = LoadTriangleIndices_0(_S235, _S236);
    var _S241 : Vertex_std430_0 = gVertices_0[_S240.x];
    var _S242 : Vertex_std430_0 = gVertices_0[_S240.y];
    var _S243 : Vertex_std430_0 = gVertices_0[_S240.z];
    var _S244 : f32 = _S237.x;
    var _S245 : f32 = _S237.y;
    var _S246 : f32 = 1.0f - _S244 - _S245;
    var _S247 : vec2<f32> = VertexUV0_0(&(_S241));
    var _S248 : vec2<f32> = VertexUV0_0(&(_S242));
    var _S249 : vec2<f32> = VertexUV0_0(&(_S243));
    var _S250 : vec2<f32> = vec2<f32>(_S246);
    var _S251 : vec2<f32> = vec2<f32>(_S244);
    var _S252 : vec2<f32> = vec2<f32>(_S245);
    var _S253 : vec2<f32> = _S241.uv1_0.xy;
    var _S254 : vec2<f32> = _S242.uv1_0.xy;
    var _S255 : vec2<f32> = _S243.uv1_0.xy;
    var _S256 : vec3<f32> = _S242.positionU_0.xyz;
    var _S257 : vec3<f32> = _S241.positionU_0.xyz;
    var _S258 : vec3<f32> = _S243.positionU_0.xyz;
    var tc_4 : TextureCoords_0 = MakeTextureCoords_0(_S247 * _S250 + _S248 * _S251 + _S249 * _S252, _S253 * _S250 + _S254 * _S251 + _S255 * _S252, TransformVector_0(_S235, _S256 - _S257), TransformVector_0(_S235, _S258 - _S257), _S248 - _S247, _S249 - _S247, _S254 - _S253, _S255 - _S253, gRayCone_0.x + gRayCone_0.y * _S238, 1.0f);
    tc_4.objectPosition_0 = _S257 * vec3<f32>(_S246) + _S256 * vec3<f32>(_S244) + _S258 * vec3<f32>(_S245);
    var opacity_1 : f32 = EvalOpacity_0(material_0, tc_4);
    if(_S239 == u32(1))
    {
        return (opacity_1 < (material_0.alphaCutoff_0));
    }
    return (opacity_1 < (f32(((StrongIntegerHash_0((_S236 ^ ((StrongIntegerHash_0(((bitcast<u32>((_S238))) ^ ((gFrame_0.frame_0.w))))))))) & (u32(16777215)))) * 5.9604644775390625e-08f));
}

fn TraverseBLAS_0( _S259 : u32,  _S260 : u32,  _S261 : vec3<f32>,  _S262 : vec3<f32>,  _S263 : f32,  _S264 : bool,  _S265 : ptr<function, HitRecord_0>) -> bool
{
    var found_0 : bool;
    var _S266 : vec3<f32> = SafeRcp_0(_S262);
    var _S267 : bool = (((gInstances_0[_S260].flags_0) & (u32(1)))) != u32(0);
    var stack_2 : array<u32, i32(48)>;
    var nodeRef_0 : u32 = u32(0);
    var found_1 : bool = false;
    var stackPtr_0 : u32 = u32(0);
    loop
    {
        var i_7 : u32;
        if(((nodeRef_0 & (u32(2147483648)))) != u32(0))
        {
            var _S268 : u32 = (((nodeRef_0 >> (u32(24)))) & (u32(127)));
            var _S269 : u32 = (nodeRef_0 & (u32(16777215)));
            found_0 = found_1;
            i_7 = u32(0);
            loop
            {
                if((i_7 < _S268))
                {
                }
                else
                {
                    break;
                }
                gTraversalCost_0 = gTraversalCost_0 + u32(1);
                var base_10 : u32 = (gInstances_0[_S260].blasTriOffset_0 + _S269 + i_7) * u32(3);
                var v0_1 : vec4<f32> = gTris_0[base_10];
                var t_7 : f32;
                var bary_1 : vec2<f32>;
                var _S270 : bool = IntersectTriangle_0(_S261, _S262, v0_1.xyz, gTris_0[base_10 + u32(1)].xyz, gTris_0[base_10 + u32(2)].xyz, _S263, (*_S265).t_6, &(t_7), &(bary_1));
                if(!_S270)
                {
                    i_7 = i_7 + u32(1);
                    continue;
                }
                var primitiveIndex_1 : u32 = (bitcast<u32>((v0_1.w)));
                var _S271 : bool;
                if(_S267)
                {
                    var _S272 : bool = AlphaTestRejects_0(_S260, primitiveIndex_1, bary_1, t_7);
                    _S271 = _S272;
                }
                else
                {
                    _S271 = false;
                }
                if(_S271)
                {
                    i_7 = i_7 + u32(1);
                    continue;
                }
                (*_S265).t_6 = t_7;
                (*_S265).barycentrics_0 = bary_1;
                (*_S265).instanceIndex_1 = _S259;
                (*_S265).primitiveIndex_0 = primitiveIndex_1;
                if(_S264)
                {
                    return true;
                }
                found_0 = true;
                i_7 = i_7 + u32(1);
            }
            if(stackPtr_0 == u32(0))
            {
                break;
            }
            var stackPtr_1 : u32 = stackPtr_0 - u32(1);
            nodeRef_0 = stack_2[stackPtr_1];
            found_1 = found_0;
            stackPtr_0 = stackPtr_1;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_0 : BVHNode_std430_0 = gNodes_0[gInstances_0[_S260].blasNodeOffset_0 + nodeRef_0];
        var dist1_0 : f32 = IntersectBox_0(node_0.lmin_0, node_0.lmax_0, _S261, _S266, _S263, (*_S265).t_6);
        var dist2_0 : f32 = IntersectBox_0(node_0.rmin_0, node_0.rmax_0, _S261, _S266, _S263, (*_S265).t_6);
        var far_0 : u32;
        var dist1_1 : f32;
        var dist2_1 : f32;
        if((dist1_0 > dist2_0))
        {
            dist1_1 = dist2_0;
            i_7 = node_0.right_0;
            dist2_1 = dist1_0;
            far_0 = node_0.left_0;
        }
        else
        {
            dist1_1 = dist1_0;
            i_7 = node_0.left_0;
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
            nodeRef_0 = stack_2[stackPtr_2];
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
                var _S273 : u32 = stackPtr_0 + u32(1);
                stack_2[stackPtr_0] = far_0;
                stackPtr_3 = _S273;
            }
            else
            {
                stackPtr_3 = stackPtr_0;
            }
            nodeRef_0 = i_7;
            stackPtr_0 = stackPtr_3;
        }
    }
    return found_0;
}

fn TraceScene_0( ray_1 : Ray_0,  anyHit_0 : bool,  hit_0 : ptr<function, HitRecord_0>) -> bool
{
    var found_2 : bool;
    (*hit_0).t_6 = ray_1.tMax_0;
    (*hit_0).barycentrics_0 = vec2<f32>(0.0f);
    (*hit_0).instanceIndex_1 = u32(4294967295);
    (*hit_0).primitiveIndex_0 = u32(4294967295);
    if((gFrame_0.counts_0.x) == u32(0))
    {
        return false;
    }
    var _S274 : u32 = gFrame_0.counts_0.z;
    var _S275 : vec3<f32> = SafeRcp_0(ray_1.direction_0);
    var stack_3 : array<u32, i32(32)>;
    var nodeRef_1 : u32 = u32(0);
    var found_3 : bool = false;
    var stackPtr_4 : u32 = u32(0);
    loop
    {
        var i_8 : u32;
        if(((nodeRef_1 & (u32(2147483648)))) != u32(0))
        {
            var _S276 : u32 = (((nodeRef_1 >> (u32(24)))) & (u32(127)));
            var _S277 : u32 = (nodeRef_1 & (u32(16777215)));
            found_2 = found_3;
            i_8 = u32(0);
            loop
            {
                if((i_8 < _S276))
                {
                }
                else
                {
                    break;
                }
                var instanceIndex_2 : u32 = gIndices_0[_S274 + _S277 + i_8];
                var _S278 : bool = TraverseBLAS_0(instanceIndex_2, instanceIndex_2, InverseTransformPoint_0(instanceIndex_2, ray_1.origin_0), InverseTransformVector_0(instanceIndex_2, ray_1.direction_0), ray_1.tMin_0, anyHit_0, &((*hit_0)));
                if(_S278)
                {
                    if(anyHit_0)
                    {
                        return true;
                    }
                    found_2 = true;
                }
                i_8 = i_8 + u32(1);
            }
            if(stackPtr_4 == u32(0))
            {
                break;
            }
            var stackPtr_5 : u32 = stackPtr_4 - u32(1);
            nodeRef_1 = stack_3[stackPtr_5];
            found_3 = found_2;
            stackPtr_4 = stackPtr_5;
            continue;
        }
        gTraversalCost_0 = gTraversalCost_0 + u32(1);
        var node_1 : BVHNode_std430_0 = gNodes_0[nodeRef_1];
        var dist1_2 : f32 = IntersectBox_0(node_1.lmin_0, node_1.lmax_0, ray_1.origin_0, _S275, ray_1.tMin_0, (*hit_0).t_6);
        var dist2_2 : f32 = IntersectBox_0(node_1.rmin_0, node_1.rmax_0, ray_1.origin_0, _S275, ray_1.tMin_0, (*hit_0).t_6);
        var far_1 : u32;
        var dist1_3 : f32;
        var dist2_3 : f32;
        if((dist1_2 > dist2_2))
        {
            dist1_3 = dist2_2;
            i_8 = node_1.right_0;
            dist2_3 = dist1_2;
            far_1 = node_1.left_0;
        }
        else
        {
            dist1_3 = dist1_2;
            i_8 = node_1.left_0;
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
            nodeRef_1 = stack_3[stackPtr_6];
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
                var _S279 : u32 = stackPtr_4 + u32(1);
                stack_3[stackPtr_4] = far_1;
                stackPtr_7 = _S279;
            }
            else
            {
                stackPtr_7 = stackPtr_4;
            }
            nodeRef_1 = i_8;
            stackPtr_4 = stackPtr_7;
        }
    }
    return found_2;
}

fn TraceClosest_0( ray_2 : Ray_0) -> HitRecord_0
{
    var hit_1 : HitRecord_0;
    var _S280 : bool = TraceScene_0(ray_2, false, &(hit_1));
    return hit_1;
}

fn AnalyticLightCount_0() -> u32
{
    return gFrame_0.counts_0.w;
}

fn HitRecord_IsHit_0( this_100 : HitRecord_0) -> bool
{
    return (this_100.instanceIndex_1) != u32(4294967295);
}

fn AnalyticFlags_0( light_0 : ptr<function, EmissiveTriangle_std430_0>) -> u32
{
    return (bitcast<u32>(((*light_0).n_0.w)));
}

fn SpotAttenuation_0( light_1 : ptr<function, EmissiveTriangle_std430_0>,  dir_2 : vec3<f32>) -> f32
{
    var _S281 : u32 = AnalyticFlags_0(&((*light_1)));
    if(((_S281 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_25 : f32 = dot(dir_2, (*light_1).p2_0.xyz) - (*light_1).uvA_0.w;
    var scale_4 : f32 = (*light_1).uvB_0.x;
    var _S282 : f32;
    if((scale_4 > 0.0f))
    {
        _S282 = smoothstep(0.0f, 1.0f, x_25 * scale_4);
    }
    else
    {
        if((x_25 > 0.0f))
        {
            _S282 = 1.0f;
        }
        else
        {
            _S282 = 0.0f;
        }
    }
    return _S282;
}

fn SphereOneMinusCos_0( radius_1 : f32,  distSq_0 : f32) -> f32
{
    var sinSq_0 : f32 = radius_1 * radius_1 / distSq_0;
    var _S283 : f32;
    if((sinSq_0 < 1.0f))
    {
        _S283 = sinSq_0 / (1.0f + sqrt(1.0f - sinSq_0));
    }
    else
    {
        _S283 = 0.0f;
    }
    return _S283;
}

fn IntersectAnalyticLights_0( origin_5 : vec3<f32>,  dir_3 : vec3<f32>,  tMax_3 : f32,  cameraRay_0 : bool,  radiance_1 : ptr<function, vec3<f32>>,  pdf_13 : ptr<function, f32>) -> bool
{
    (*radiance_1) = vec3<f32>(0.0f);
    (*pdf_13) = 0.0f;
    var nearest_0 : f32 = tMax_3;
    var found_4 : bool = false;
    var i_9 : u32 = u32(0);
    loop
    {
        if((i_9 < (AnalyticLightCount_0())))
        {
        }
        else
        {
            break;
        }
        var _S284 : EmissiveTriangle_std430_0 = gLights_0[i_9];
        var _S285 : u32 = AnalyticFlags_0(&(_S284));
        var _S286 : bool;
        if(cameraRay_0)
        {
            _S286 = ((_S285 & (u32(256)))) != u32(0);
        }
        else
        {
            _S286 = false;
        }
        if(_S286)
        {
            i_9 = i_9 + u32(1);
            continue;
        }
        var nearest_1 : f32;
        var _S287 : bool;
        var inside_2 : bool;
        if(((_S285 & (u32(255)))) == u32(2))
        {
            var n_11 : vec3<f32> = _S284.p2_0.xyz;
            var cosTheta_9 : f32 = - dot(n_11, dir_3);
            if((cosTheta_9 <= 9.99999997475242708e-07f))
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            var _S288 : vec4<f32> = _S284.p0_0;
            var _S289 : vec3<f32> = _S284.p0_0.xyz;
            var t_8 : f32 = dot(_S289 - origin_5, n_11) / - cosTheta_9;
            if((t_8 <= 0.0f))
            {
                _S287 = true;
            }
            else
            {
                _S287 = (t_8 >= nearest_0);
            }
            if(_S287)
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            var local_2 : vec3<f32> = origin_5 + dir_3 * vec3<f32>(t_8) - _S289;
            var _S290 : vec3<f32> = _S284.n_0.xyz;
            var _S291 : vec3<f32> = _S284.uvA_0.xyz;
            var d_10 : vec2<f32> = vec2<f32>(dot(local_2, _S290) / dot(_S290, _S290), dot(local_2, _S291) / dot(_S291, _S291));
            if(((_S285 & (u32(512)))) != u32(0))
            {
                inside_2 = ((dot(d_10, d_10)) <= 0.25f);
            }
            else
            {
                inside_2 = (all((((abs(d_10)) <= vec2<f32>(0.5f)))));
            }
            if(!inside_2)
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            (*radiance_1) = _S284.p1_0.xyz;
            (*pdf_13) = _S284.p1_0.w * t_8 * t_8 / (cosTheta_9 * _S288.w);
            nearest_1 = t_8;
        }
        else
        {
            var _S292 : vec4<f32> = _S284.p0_0;
            var radius_2 : f32 = _S284.p0_0.w;
            if((radius_2 <= 0.0f))
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            var toCenter_0 : vec3<f32> = _S292.xyz - origin_5;
            var distSq_1 : f32 = dot(toCenter_0, toCenter_0);
            var tc_5 : f32 = dot(toCenter_0, dir_3);
            var _S293 : f32 = radius_2 * radius_2;
            var h_14 : f32 = _S293 - (distSq_1 - tc_5 * tc_5);
            if((h_14 < 0.0f))
            {
                _S287 = true;
            }
            else
            {
                _S287 = (distSq_1 <= _S293);
            }
            if(_S287)
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            var t_9 : f32 = tc_5 - sqrt(h_14);
            if((t_9 <= 0.0f))
            {
                inside_2 = true;
            }
            else
            {
                inside_2 = (t_9 >= nearest_0);
            }
            if(inside_2)
            {
                i_9 = i_9 + u32(1);
                continue;
            }
            var _S294 : vec4<f32> = _S284.p1_0;
            var _S295 : vec3<f32> = _S284.p1_0.xyz;
            var _S296 : f32 = SpotAttenuation_0(&(_S284), (vec3<f32>(0) - toCenter_0) * vec3<f32>(rsqrt_0(distSq_1)));
            (*radiance_1) = _S295 * vec3<f32>(_S296);
            (*pdf_13) = _S294.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_2, distSq_1));
            nearest_1 = t_9;
        }
        nearest_0 = nearest_1;
        found_4 = true;
        i_9 = i_9 + u32(1);
    }
    return found_4;
}

fn EvalMISRobust_0( pdf_14 : f32,  otherPdf_0 : f32) -> f32
{
    if(pdf_14 == otherPdf_0)
    {
        return 0.5f;
    }
    if((otherPdf_0 < pdf_14))
    {
        var x_26 : f32 = otherPdf_0 / pdf_14;
        return 1.0f / (1.0f + x_26 * x_26);
    }
    var x_27 : f32 = pdf_14 / otherPdf_0;
    return 1.0f - 1.0f / (1.0f + x_27 * x_27);
}

fn EnvironmentEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(1)))) != u32(0);
}

fn RotateY_0( v_14 : vec3<f32>,  angle_2 : f32) -> vec3<f32>
{
    var s_17 : f32 = sin(angle_2);
    var c_13 : f32 = cos(angle_2);
    var _S297 : f32 = v_14.x;
    var _S298 : f32 = v_14.z;
    return vec3<f32>(c_13 * _S297 + s_17 * _S298, v_14.y, - s_17 * _S297 + c_13 * _S298);
}

fn DirectionToEquirectUV_0( dir_4 : vec3<f32>) -> vec2<f32>
{
    var _S299 : f32 = dir_4.y;
    var elevation_0 : f32 = asin(clamp(_S299, -1.0f, 1.0f));
    var azimuth_1 : f32;
    if(((abs(_S299)) < 1.0f))
    {
        azimuth_1 = atan2(dir_4.z, dir_4.x);
    }
    else
    {
        azimuth_1 = 0.0f;
    }
    var PI_2 : f32 = float_getPi_0();
    return vec2<f32>(azimuth_1 * (0.5f / PI_2) - 0.25f, 0.5f - elevation_0 * (1.0f / PI_2));
}

fn EvalEnvironment_0( dir_5 : vec3<f32>) -> vec3<f32>
{
    if(!EnvironmentEnabled_0())
    {
        return vec3<f32>(0.0f);
    }
    return (textureSampleLevel((gEnvMap_0), (gLinearSampler_0), (DirectionToEquirectUV_0(RotateY_0(dir_5, - gFrame_0.envParams_0.y))), (0.0f))).xyz * vec3<f32>(gFrame_0.envParams_0.x);
}

fn SunEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(2)))) != u32(0);
}

fn HitsSun_0( dir_6 : vec3<f32>) -> bool
{
    var _S300 : bool;
    if(SunEnabled_0())
    {
        _S300 = ((dot(dir_6, gFrame_0.sunDirection_0.xyz)) >= (gFrame_0.sunDirection_0.w));
    }
    else
    {
        _S300 = false;
    }
    return _S300;
}

fn EnvCdf_0( x_28 : u32,  y_11 : u32) -> f32
{
    var _S301 : vec3<i32> = vec3<i32>(i32(x_28), i32(y_11), i32(0));
    return (textureLoad((gEnvCdf_0), ((_S301)).xy, ((_S301)).z).x);
}

fn EnvironmentPdf_0( dir_7 : vec3<f32>) -> f32
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
    var local_3 : vec3<f32> = RotateY_0(dir_7, - gFrame_0.envParams_0.y);
    var uv_3 : vec2<f32> = fract(DirectionToEquirectUV_0(local_3));
    var _S302 : f32 = f32(W_0);
    var _S303 : u32 = min(u32(uv_3.x * _S302), W_0 - u32(1));
    var _S304 : f32 = f32(H_0);
    var _S305 : u32 = min(u32(uv_3.y * _S304), H_0 - u32(1));
    var _S306 : f32 = local_3.y;
    var PI_3 : f32 = float_getPi_0();
    return (EnvCdf_0(_S303 + u32(1), _S305) - EnvCdf_0(_S303, _S305)) * _S302 * ((EnvCdf_0(_S305 + u32(1), H_0) - EnvCdf_0(_S305, H_0)) * _S304) / (2.0f * PI_3 * PI_3 * sqrt(clamp(1.0f - _S306 * _S306, 9.99999997475242708e-07f, 1.0f)));
}

@compute
@workgroup_size(64, 1, 1)
fn Intersect(@builtin(global_invocation_id) tid_1 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S218();
    gTraversalCost_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_15 : u32 = tid_1.x;
    if((index_15 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_11 : u32 = WorkBase_0(index_15);
    var s_18 : WavefrontPath_0 = LoadPath_0(base_11);
    if((s_18.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_11);
    gRayCone_0 = vec2<f32>(s_18.path_0.coneWidth_0, s_18.path_0.coneSpread_0);
    var ray_3 : Ray_0 = Ray_x24init_0(s_18.path_0.origin_4, s_18.path_0.direction_1, 1.00000001504746622e+30f);
    var hit_2 : HitRecord_0 = TraceClosest_0(ray_3);
    var clampValue_0 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    var bounce_1 : u32 = gWavefront_0.bounce_0;
    var mis_0 : f32;
    var _S307 : bool;
    var contribution_0 : vec3<f32>;
    if(((AnalyticLightCount_0()) > u32(0)))
    {
        var radiance_2 : vec3<f32>;
        var pdf_15 : f32;
        if(HitRecord_IsHit_0(hit_2))
        {
            mis_0 = hit_2.t_6;
        }
        else
        {
            mis_0 = 1.00000001504746622e+30f;
        }
        var _S308 : bool = IntersectAnalyticLights_0(ray_3.origin_0, ray_3.direction_0, mis_0, bounce_1 == u32(0), &(radiance_2), &(pdf_15));
        if(_S308)
        {
            var _S309 : bool = (bounce_1 > u32(0));
            if(_S309)
            {
                _S307 = s_18.path_0.lightsSampled_0;
            }
            else
            {
                _S307 = false;
            }
            if(_S307)
            {
                mis_0 = EvalMISRobust_0(s_18.path_0.scatterPdf_0, pdf_15);
            }
            else
            {
                mis_0 = 1.0f;
            }
            var contribution_1 : vec3<f32> = s_18.path_0.throughput_12 * vec3<f32>(mis_0) * radiance_2;
            if((clampValue_0 > 0.0f))
            {
                _S307 = _S309;
            }
            else
            {
                _S307 = false;
            }
            if(_S307)
            {
                contribution_0 = min(contribution_1, vec3<f32>(clampValue_0));
            }
            else
            {
                contribution_0 = contribution_1;
            }
            s_18.path_0.radiance_0 = s_18.path_0.radiance_0 + contribution_0;
        }
    }
    if(!HitRecord_IsHit_0(hit_2))
    {
        if(bounce_1 == u32(0))
        {
            var visible_0 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
            if(visible_0)
            {
                contribution_0 = EvalEnvironment_0(ray_3.direction_0);
            }
            else
            {
                contribution_0 = gFrame_0.background_0.xyz;
            }
            s_18.path_0.radiance_0 = s_18.path_0.radiance_0 + contribution_0;
            if(visible_0)
            {
                _S307 = HitsSun_0(ray_3.direction_0);
            }
            else
            {
                _S307 = false;
            }
            if(_S307)
            {
                s_18.path_0.radiance_0 = s_18.path_0.radiance_0 + gFrame_0.sunRadiance_0.xyz;
            }
        }
        else
        {
            if(s_18.path_0.lightsSampled_0)
            {
                mis_0 = EvalMISRobust_0(s_18.path_0.scatterPdf_0, EnvironmentPdf_0(ray_3.direction_0));
            }
            else
            {
                mis_0 = 1.0f;
            }
            var contribution_2 : vec3<f32> = s_18.path_0.throughput_12 * vec3<f32>(mis_0) * EvalEnvironment_0(ray_3.direction_0);
            if(!s_18.path_0.lightsSampled_0)
            {
                _S307 = SunEnabled_0();
            }
            else
            {
                _S307 = false;
            }
            if(_S307)
            {
                _S307 = HitsSun_0(ray_3.direction_0);
            }
            else
            {
                _S307 = false;
            }
            if(_S307)
            {
                contribution_0 = contribution_2 + s_18.path_0.throughput_12 * gFrame_0.sunRadiance_0.xyz;
            }
            else
            {
                contribution_0 = contribution_2;
            }
            if((clampValue_0 > 0.0f))
            {
                contribution_0 = min(contribution_0, vec3<f32>(clampValue_0));
            }
            s_18.path_0.radiance_0 = s_18.path_0.radiance_0 + contribution_0;
        }
        s_18.active_0 = u32(0);
    }
    else
    {
        gAccum_0[base_11 + u32(8)] = vec4<f32>(hit_2.t_6, hit_2.barycentrics_0, (bitcast<f32>((hit_2.instanceIndex_1))));
        gAccum_0[base_11 + u32(9)] = (bitcast<vec4<f32>>((vec4<u32>(hit_2.primitiveIndex_0, u32(0), u32(0), u32(0)))));
    }
    StorePath_0(base_11, s_18);
    StoreFeedbackState_0(base_11);
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
     instanceIndex_3 : u32,
     primitiveIndex_2 : u32,
     frontFacing_0 : bool,
};

fn TransformPoint_0( _S310 : u32,  _S311 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S310].objectToWorld_0[i32(0)].xyz, _S311) + gInstances_0[_S310].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S310].objectToWorld_0[i32(1)].xyz, _S311) + gInstances_0[_S310].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S310].objectToWorld_0[i32(2)].xyz, _S311) + gInstances_0[_S310].objectToWorld_0[i32(2)].w);
}

fn TransformNormal_0( _S312 : u32,  _S313 : vec3<f32>) -> vec3<f32>
{
    return gInstances_0[_S312].worldToObject_0[i32(0)].xyz * vec3<f32>(_S313.x) + gInstances_0[_S312].worldToObject_0[i32(1)].xyz * vec3<f32>(_S313.y) + gInstances_0[_S312].worldToObject_0[i32(2)].xyz * vec3<f32>(_S313.z);
}

fn GetSurfaceInteraction_0( rayDirection_0 : vec3<f32>,  hit_3 : HitRecord_0,  coneWidth_3 : f32) -> SurfaceInteraction_0
{
    var _S314 : vec3<u32> = LoadTriangleIndices_0(hit_3.instanceIndex_1, hit_3.primitiveIndex_0);
    var _S315 : Vertex_std430_0 = gVertices_0[_S314.x];
    var _S316 : Vertex_std430_0 = gVertices_0[_S314.y];
    var _S317 : Vertex_std430_0 = gVertices_0[_S314.z];
    var _S318 : f32 = hit_3.barycentrics_0.x;
    var _S319 : f32 = hit_3.barycentrics_0.y;
    var _S320 : f32 = 1.0f - _S318 - _S319;
    var p0_1 : vec3<f32> = _S315.positionU_0.xyz;
    var p1_1 : vec3<f32> = _S316.positionU_0.xyz;
    var p2_1 : vec3<f32> = _S317.positionU_0.xyz;
    var si_0 : SurfaceInteraction_0;
    si_0.instanceIndex_3 = hit_3.instanceIndex_1;
    si_0.primitiveIndex_2 = hit_3.primitiveIndex_0;
    si_0.materialIndex_2 = gInstances_0[hit_3.instanceIndex_1].materialIndex_0;
    var _S321 : vec3<f32> = vec3<f32>(_S320);
    var _S322 : vec3<f32> = vec3<f32>(_S318);
    var _S323 : vec3<f32> = vec3<f32>(_S319);
    var _S324 : vec3<f32> = p0_1 * _S321 + p1_1 * _S322 + p2_1 * _S323;
    si_0.position_1 = TransformPoint_0(hit_3.instanceIndex_1, _S324);
    var _S325 : vec3<f32> = p1_1 - p0_1;
    var _S326 : vec3<f32> = p2_1 - p0_1;
    si_0.faceNormal_0 = normalize(TransformNormal_0(hit_3.instanceIndex_1, cross(normalize(_S325), normalize(_S326))));
    var n_12 : vec3<f32> = _S315.normalV_0.xyz * _S321 + _S316.normalV_0.xyz * _S322 + _S317.normalV_0.xyz * _S323;
    var t_10 : vec3<f32>;
    if(((dot(n_12, n_12)) > 0.0f))
    {
        t_10 = normalize(TransformNormal_0(hit_3.instanceIndex_1, n_12));
    }
    else
    {
        t_10 = si_0.faceNormal_0;
    }
    si_0.normal_13 = t_10;
    var _S327 : vec2<f32> = VertexUV0_0(&(_S315));
    var _S328 : vec2<f32> = VertexUV0_0(&(_S316));
    var _S329 : vec2<f32> = VertexUV0_0(&(_S317));
    var _S330 : vec2<f32> = vec2<f32>(_S320);
    var _S331 : vec2<f32> = vec2<f32>(_S318);
    var _S332 : vec2<f32> = vec2<f32>(_S319);
    var _S333 : vec2<f32> = _S315.uv1_0.xy;
    var _S334 : vec2<f32> = _S316.uv1_0.xy;
    var _S335 : vec2<f32> = _S317.uv1_0.xy;
    si_0.tex_2 = MakeTextureCoords_0(_S327 * _S330 + _S328 * _S331 + _S329 * _S332, _S333 * _S330 + _S334 * _S331 + _S335 * _S332, TransformVector_0(hit_3.instanceIndex_1, _S325), TransformVector_0(hit_3.instanceIndex_1, _S326), _S328 - _S327, _S329 - _S327, _S334 - _S333, _S335 - _S333, coneWidth_3, dot(si_0.faceNormal_0, rayDirection_0));
    si_0.tex_2.objectPosition_0 = _S324;
    si_0.frontFacing_0 = ((dot(si_0.faceNormal_0, (vec3<f32>(0) - rayDirection_0))) > 0.0f);
    var _S336 : vec4<f32> = _S315.tangent_0;
    var t_11 : vec3<f32> = _S315.tangent_0.xyz * _S321 + _S316.tangent_0.xyz * _S322 + _S317.tangent_0.xyz * _S323;
    if(((dot(t_11, t_11)) > 0.0f))
    {
        t_10 = normalize(TransformVector_0(hit_3.instanceIndex_1, t_11));
    }
    else
    {
        t_10 = vec3<f32>(0.0f);
    }
    si_0.tangent_5 = vec4<f32>(t_10, _S336.w);
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
    var _S337 : f32 = n_14.z;
    var s_19 : f32;
    if((_S337 >= 0.0f))
    {
        s_19 = 1.0f;
    }
    else
    {
        s_19 = -1.0f;
    }
    var a_15 : f32 = -1.0f / (s_19 + _S337);
    var _S338 : f32 = n_14.x;
    var _S339 : f32 = n_14.y;
    var b_11 : f32 = _S338 * _S339 * a_15;
    (*b1_0) = vec3<f32>(1.0f + s_19 * _S338 * _S338 * a_15, s_19 * b_11, - s_19 * _S338);
    (*b2_0) = vec3<f32>(b_11, s_19 + _S339 * _S339 * a_15, - _S339);
    return;
}

fn BranchlessONB_1( n_15 : vec3<f32>,  b1_1 : ptr<function, vec3<f32>>,  b2_1 : ptr<function, vec3<f32>>)
{
    var _S340 : f32 = n_15.z;
    var s_20 : f32;
    if((_S340 >= 0.0f))
    {
        s_20 = 1.0f;
    }
    else
    {
        s_20 = -1.0f;
    }
    var a_16 : f32 = -1.0f / (s_20 + _S340);
    var _S341 : f32 = n_15.x;
    var _S342 : f32 = n_15.y;
    var b_12 : f32 = _S341 * _S342 * a_16;
    (*b1_1) = vec3<f32>(1.0f + s_20 * _S341 * _S341 * a_16, s_20 * b_12, - s_20 * _S341);
    (*b2_1) = vec3<f32>(b_12, s_20 + _S342 * _S342 * a_16, - _S342);
    return;
}

fn Frame_FromNormal_0( n_16 : vec3<f32>) -> Frame_0
{
    var f_15 : Frame_0;
    f_15.n_1 = n_16;
    var _S343 : vec3<f32> = f_15.t_0;
    var _S344 : vec3<f32> = f_15.b_0;
    BranchlessONB_0(n_16, &(_S343), &(_S344));
    f_15.t_0 = _S343;
    f_15.b_0 = _S344;
    return f_15;
}

fn Frame_FromTangent_0( tangent_6 : vec4<f32>,  n_17 : vec3<f32>) -> Frame_0
{
    var _S345 : vec3<f32> = tangent_6.xyz;
    var NdotT_0 : f32 = dot(_S345, n_17);
    var _S346 : f32 = tangent_6.w;
    var valid_1 : bool;
    if(_S346 != 0.0f)
    {
        valid_1 = ((dot(_S345, _S345)) > 0.0f);
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
    var _S347 : vec3<f32> = normalize(_S345 - n_17 * vec3<f32>(NdotT_0));
    f_16.t_0 = _S347;
    f_16.b_0 = cross(n_17, _S347) * vec3<f32>(_S346);
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
    ctx_5.normal_10 = si_1.normal_13;
    ctx_5.tangent_1 = si_1.tangent_5;
    ctx_5.instanceIndex_0 = si_1.instanceIndex_3;
    var o_53 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_5);
    if((header_5.surface_0) != u32(4294967295))
    {
        RunMaterialProgram_0(header_5, header_5.surface_0, ctx_5, &(o_53));
    }
    var ms_0 : MaterialSample_0;
    ms_0.inputs_1 = o_53.inputs_0;
    ms_0.albedo_2 = o_53.inputs_0.baseColor_0;
    ms_0.roughness_5 = o_53.inputs_0.specularRoughness_0;
    ms_0.doubleSided_0 = MaterialHeader_DoubleSided_0(header_5);
    ms_0.thinWalled_0 = o_53.inputs_0.geometryThinWalled_0;
    var _S348 : f32 = si_1.tangent_5.w;
    var handedness_0 : f32;
    if(_S348 != 0.0f)
    {
        handedness_0 = _S348;
    }
    else
    {
        handedness_0 = 1.0f;
    }
    ms_0.inputs_1.basis_4 = Frame_FromTangent_0(vec4<f32>(o_53.tangent_2, handedness_0), AlignWithFace_0(o_53.normal_11, V_1, si_1.frontFacing_0));
    var _S349 : bool;
    if((all(((o_53.coatNormal_0) == (o_53.normal_11)))))
    {
        _S349 = (all(((o_53.coatTangent_0) == (o_53.tangent_2))));
    }
    else
    {
        _S349 = false;
    }
    if(_S349)
    {
        ms_0.inputs_1.coatBasis_0 = ms_0.inputs_1.basis_4;
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
    var _S350 : HomogeneousVolume_0;
    _S350.extinction_0 = extinction_1;
    _S350.albedo_3 = albedo_4;
    _S350.anisotropy_0 = anisotropy_1;
    return _S350;
}

fn HomogeneousVolume_Empty_0() -> HomogeneousVolume_0
{
    var _S351 : vec3<f32> = vec3<f32>(0.0f);
    return HomogeneousVolume_x24init_0(_S351, _S351, 0.0f);
}

fn Square_1( v_15 : vec3<f32>) -> vec3<f32>
{
    return v_15 * v_15;
}

fn CreateSubsurfaceVolume_0( radius_3 : f32,  radiusScale_0 : vec3<f32>,  color_4 : vec3<f32>,  anisotropy_2 : f32) -> HomogeneousVolume_0
{
    var _S352 : vec3<f32> = vec3<f32>(1.0f);
    var g_2 : f32 = clamp(anisotropy_2, -0.99900001287460327f, 0.99900001287460327f);
    var _S353 : vec3<f32> = Square_1(vec3<f32>(4.0971198081970215f) + vec3<f32>(4.2086300849914551f) * color_4 - sqrt(vec3<f32>(9.5921697616577148f) + vec3<f32>(41.680801391601562f) * color_4 + vec3<f32>(17.712600708007812f) * Square_1(color_4)));
    return HomogeneousVolume_x24init_0(_S352 / max(vec3<f32>(radius_3) * radiusScale_0, vec3<f32>(0.0010000000474974513f)), saturate((_S352 - _S353) / (_S352 - vec3<f32>(g_2) * _S353)), g_2);
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
        var _S354 : f32;
        if(((extinction_2[i32(0)]) > 0.0f))
        {
            _S354 = scattering_0[i32(0)] / extinction_2[i32(0)];
        }
        else
        {
            _S354 = 0.0f;
        }
        albedo_5[i32(0)] = _S354;
        if(((extinction_2[i32(1)]) > 0.0f))
        {
            _S354 = scattering_0[i32(1)] / extinction_2[i32(1)];
        }
        else
        {
            _S354 = 0.0f;
        }
        albedo_5[i32(1)] = _S354;
        if(((extinction_2[i32(2)]) > 0.0f))
        {
            _S354 = scattering_0[i32(2)] / extinction_2[i32(2)];
        }
        else
        {
            _S354 = 0.0f;
        }
        albedo_5[i32(2)] = _S354;
    }
    return HomogeneousVolume_x24init_0(extinction_2, albedo_5, anisotropy_3);
}

fn CreateTransmissionVolume_0( color_5 : vec3<f32>,  depth_1 : f32,  scatter_0 : vec3<f32>,  anisotropy_4 : f32) -> HomogeneousVolume_0
{
    var _S355 : bool;
    if(((MinComponent_0(color_5)) >= 1.0f))
    {
        _S355 = ((MaxComponent_0(scatter_0)) <= 0.0f);
    }
    else
    {
        _S355 = false;
    }
    if(_S355)
    {
        return HomogeneousVolume_Empty_0();
    }
    var _S356 : vec3<f32> = vec3<f32>((1.0f / max(depth_1, 0.0010000000474974513f)));
    var scattering_1 : vec3<f32> = scatter_0 * _S356;
    var absorption_2 : vec3<f32> = (vec3<f32>(0) - log(max(color_5, vec3<f32>(0.0010000000474974513f)))) * _S356 - scattering_1;
    var _S357 : f32 = MinComponent_0(absorption_2);
    var absorption_3 : vec3<f32>;
    if((_S357 < 0.0f))
    {
        absorption_3 = absorption_2 - vec3<f32>(_S357);
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
    var _S358 : vec3<f32> = vec3<f32>(weightA_0);
    var _S359 : vec3<f32> = vec3<f32>(weightB_0);
    return HomogeneousVolume_FromAbsorptionAndScattering_0(HomogeneousVolume_Absorption_0(a_17) * _S358 + HomogeneousVolume_Absorption_0(b_13) * _S359, HomogeneousVolume_Scattering_0(a_17) * _S358 + HomogeneousVolume_Scattering_0(b_13) * _S359, SafeDivide_0(a_17.anisotropy_0 * weightA_0 + b_13.anisotropy_0 * weightB_0, weightA_0 + weightB_0, 0.0f));
}

struct VolumeDerived_0
{
     thinWallSubsurfaceColor_0 : vec3<f32>,
     thinWallSubsurfaceAnisotropy_0 : f32,
     transmissionTint_0 : vec3<f32>,
};

fn PrepareVolume_0( inputs_2 : BSDFInputs_0,  derived_0 : ptr<function, VolumeDerived_0>) -> HomogeneousVolume_0
{
    var _S360 : HomogeneousVolume_0 = HomogeneousVolume_Empty_0();
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
            subsurfaceVolume_0 = _S360;
        }
    }
    else
    {
        subsurfaceVolume_0 = _S360;
    }
    (*derived_0).transmissionTint_0 = vec3<f32>(1.0f);
    var transmissionVolume_0 : HomogeneousVolume_0;
    if(((inputs_2.transmissionWeight_0) > 0.0f))
    {
        var _S361 : bool;
        if((inputs_2.transmissionDepth_0) == 0.0f)
        {
            _S361 = true;
        }
        else
        {
            _S361 = inputs_2.geometryThinWalled_0;
        }
        if(_S361)
        {
            (*derived_0).transmissionTint_0 = inputs_2.transmissionColor_0;
            transmissionVolume_0 = _S360;
        }
        else
        {
            transmissionVolume_0 = CreateTransmissionVolume_0(inputs_2.transmissionColor_0, inputs_2.transmissionDepth_0, inputs_2.transmissionScatter_0, inputs_2.transmissionScatterAnisotropy_0);
        }
    }
    else
    {
        transmissionVolume_0 = _S360;
    }
    var subsurfaceFraction_0 : f32 = (1.0f - inputs_2.transmissionWeight_0) * inputs_2.subsurfaceWeight_0;
    var invTotal_0 : f32 = SafeDivide_0(1.0f, subsurfaceFraction_0 + inputs_2.transmissionWeight_0, 0.0f);
    return AddVolumes_0(subsurfaceVolume_0, transmissionVolume_0, subsurfaceFraction_0 * invTotal_0, inputs_2.transmissionWeight_0 * invTotal_0);
}

fn Frame_Handedness_0( this_104 : Frame_0) -> f32
{
    var _S362 : f32;
    if(((dot(cross(this_104.t_0, this_104.b_0), this_104.n_1)) >= 0.0f))
    {
        _S362 = 1.0f;
    }
    else
    {
        _S362 = -1.0f;
    }
    return _S362;
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
    var _S363 : vec3<f32> = vec3<f32>(cs_0.x);
    var _S364 : vec3<f32> = vec3<f32>(h_15);
    var _S365 : vec3<f32> = vec3<f32>(cs_0.y);
    f_17.t_0 = this_105.t_0 * _S363 + _S364 * this_105.b_0 * _S365;
    f_17.b_0 = this_105.b_0 * _S363 - _S364 * this_105.t_0 * _S365;
    return f_17;
}

fn Frame_Inverted_0( this_106 : Frame_0) -> Frame_0
{
    var f_18 : Frame_0;
    f_18.t_0 = (vec3<f32>(0) - this_106.t_0);
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
    var _S366 : f32;
    if((eta_7 < 1.0f))
    {
        _S366 = 1.0f / externalIor_0;
    }
    else
    {
        _S366 = externalIor_0;
    }
    return _S366;
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
        var _S367 : f32 = 1.0f - anisotropy_5;
        alpha_15[i32(0)] = isotropicAlpha_2 * sqrt(2.0f / (1.0f + Square_0(_S367)));
        alpha_15[i32(1)] = _S367 * alpha_15.x;
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
    var _S368 : f32 = eta_8 * eta_8;
    return 0.99711799621582031f + 0.10140000283718109f * eta_8 - 0.96524101495742798f * _S368 - 0.1306069940328598f * _S368 * eta_8;
}

fn GGXDistribution_x24init_0( alpha_16 : vec2<f32>,  frame_2 : Frame_0,  isotropicAlpha_3 : f32) -> GGXDistribution_0
{
    var _S369 : GGXDistribution_0;
    _S369.alpha_0 = alpha_16;
    _S369.frame_1 = frame_2;
    _S369.isotropicAlpha_0 = isotropicAlpha_3;
    return _S369;
}

fn BSDFInputs_HasDispersion_0( this_107 : BSDFInputs_0) -> bool
{
    var _S370 : bool;
    if(((this_107.transmissionDispersionScale_0) > 0.0f))
    {
        _S370 = ((this_107.transmissionDispersionAbbeNumber_0) > 0.0f);
    }
    else
    {
        _S370 = false;
    }
    if(_S370)
    {
        _S370 = ((this_107.baseMetalness_0) < 1.0f);
    }
    else
    {
        _S370 = false;
    }
    return _S370;
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
    var _S371 : SpecularLobe_0;
    _S371.normal_0 = normal_14;
    _S371.distribution_0 = distribution_4;
    _S371.coefficient_0 = coefficient_4;
    _S371.eta_0 = eta_10;
    _S371.throughput_0 = throughput_13;
    return _S371;
}

fn IdealDielectricReflectionRatio_0( ior_7 : f32,  alpha_17 : f32) -> f32
{
    return LookUpBilinear_0(i32(65), IorToExactIndex_0(ior_7), AlphaToExactIndex_0(alpha_17));
}

fn DielectricMultipleScatteringLobe_x24init_0( normal_15 : vec3<f32>,  wo_53 : vec3<f32>,  alpha_18 : f32,  eta_11 : f32,  reflectionScale_1 : vec3<f32>,  transmissionScale_1 : vec3<f32>) -> DielectricMultipleScatteringLobe_0
{
    var _S372 : DielectricMultipleScatteringLobe_0;
    _S372.normal_1 = normal_15;
    _S372.alpha_1 = alpha_18;
    _S372.eta_1 = eta_11;
    _S372.reflectionScale_0 = reflectionScale_1;
    _S372.transmissionScale_0 = transmissionScale_1;
    _S372.reflectionRatio_0 = 0.0f;
    _S372.energyComplementWo_0 = 0.0f;
    var _S373 : bool;
    if((alpha_18 >= 0.0015999999595806003f))
    {
        _S373 = (any((((max(reflectionScale_1, transmissionScale_1)) > vec3<f32>(0.0f)))));
    }
    else
    {
        _S373 = false;
    }
    if(_S373)
    {
        _S372.reflectionRatio_0 = IdealDielectricReflectionRatio_0(eta_11, alpha_18);
        _S372.energyComplementWo_0 = IdealDielectricEnergyComplement_0(eta_11, alpha_18, dot(wo_53, normal_15));
    }
    return _S372;
}

fn MetalMultipleScatteringLobe_x24init_0( normal_16 : vec3<f32>,  wo_54 : vec3<f32>,  alpha_19 : f32,  scale_5 : vec3<f32>) -> MetalMultipleScatteringLobe_0
{
    var _S374 : MetalMultipleScatteringLobe_0;
    _S374.normal_2 = normal_16;
    _S374.alpha_2 = alpha_19;
    _S374.scale_0 = scale_5;
    var _S375 : bool;
    if(MetalMultipleScatteringLobe_Active_0(_S374))
    {
        _S375 = (any(((scale_5 > vec3<f32>(0.0f)))));
    }
    else
    {
        _S375 = false;
    }
    var _S376 : f32;
    if(_S375)
    {
        _S376 = IdealMetalEnergyComplement_0(alpha_19, dot(wo_54, normal_16));
    }
    else
    {
        _S376 = 0.0f;
    }
    _S374.energyComplementWo_1 = _S376;
    return _S374;
}

fn OpaqueDielectricAverageEnergyComplement_0( ior_8 : f32,  alpha_20 : f32) -> f32
{
    return ExtrapolateBeyondIorMax_0(LookUpBilinear_0(i32(66), IorToExactIndex_0(ior_8), AlphaToExactIndex_0(alpha_20)), ior_8);
}

fn DiffuseLobe_x24init_0( normal_17 : vec3<f32>,  wo_55 : vec3<f32>,  albedo_6 : vec3<f32>,  roughness_6 : f32,  specularAlpha_1 : f32,  specularEta_1 : f32) -> DiffuseLobe_0
{
    var _S377 : DiffuseLobe_0;
    _S377.normal_3 = normal_17;
    _S377.albedo_0 = albedo_6;
    _S377.roughness_0 = roughness_6;
    _S377.specularAlpha_0 = specularAlpha_1;
    _S377.specularEta_0 = specularEta_1;
    _S377.specularCompensation_0 = 0.0f;
    if((any(((albedo_6 > vec3<f32>(0.0f))))))
    {
        _S377.specularCompensation_0 = OpaqueDielectricEnergyComplement_0(specularEta_1, specularAlpha_1, dot(wo_55, normal_17)) / ClampAverageEnergyComplement_0(OpaqueDielectricAverageEnergyComplement_0(specularEta_1, specularAlpha_1));
    }
    return _S377;
}

fn ConstantReflection_x24init_0( color_6 : vec3<f32>) -> ConstantReflection_0
{
    var _S378 : ConstantReflection_0;
    _S378.color_0 = color_6;
    return _S378;
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
    return BaseReflectionTransmission_EstimateWeight_0(this_109.coefficient_0, throughput_15, dot(wo_57, this_109.normal_0));
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
    var _S379 : f32;
    if(MetalMultipleScatteringLobe_Active_0(this_111))
    {
        _S379 = ThroughputWeightedMax_0(throughput_17, this_111.scale_0) * this_111.energyComplementWo_1;
    }
    else
    {
        _S379 = 0.0f;
    }
    return _S379;
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
    var _S380 : f32;
    if(BaseLobeEnabled_0(i32(0)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(0), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(0)] = _S380;
    if(BaseLobeEnabled_0(i32(1)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(1), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(1)] = _S380;
    if(BaseLobeEnabled_0(i32(2)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(2), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(2)] = _S380;
    if(BaseLobeEnabled_0(i32(3)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(3), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(3)] = _S380;
    if(BaseLobeEnabled_0(i32(4)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(4), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(4)] = _S380;
    if(BaseLobeEnabled_0(i32(5)))
    {
        _S380 = BaseLobe_LobeEstimate_0((*this_113), i32(5), wo_61, throughput_19);
    }
    else
    {
        _S380 = 0.0f;
    }
    (*this_113).weights_0[i32(5)] = _S380;
    return;
}

fn DielectricReflection_x24init_0( eta_12 : f32) -> DielectricReflection_0
{
    var _S381 : DielectricReflection_0;
    _S381.eta_2 = eta_12;
    return _S381;
}

fn PrepareLobes_0( inputs_3 : BSDFInputs_0,  derived_1 : VolumeDerived_0,  wo_62 : vec3<f32>,  throughput_20 : vec3<f32>,  wavelengths_2 : vec3<f32>,  exteriorIor_0 : f32) -> FuzzLobe_0
{
    var cosTheta_10 : f32 = dot(wo_62, inputs_3.basis_4.n_1);
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
    var specularBasis_0 : Frame_0 = Frame_RotatedAroundNormal_0(inputs_3.basis_4, inputs_3.specularAnisotropyRotation_0);
    var specularBasis_1 : Frame_0;
    if(backFacing_0)
    {
        specularBasis_1 = Frame_Inverted_0(specularBasis_0);
    }
    else
    {
        specularBasis_1 = specularBasis_0;
    }
    var _S382 : Frame_0 = specularBasis_1;
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
    var _S383 : Frame_0 = coatBasis_2;
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
        var _S384 : f32 = weightedSpecularIor_0 / exteriorIor_0;
        etaRefraction_0 = etaRefraction_1;
        etaCoat_0 = 1.0f;
        etaOpaqueReflection_0 = _S384;
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
        var _S385 : f32 = etaRefraction_0;
        var _S386 : f32 = etaRefraction_0;
        etaRefraction_0 = etaRefraction_2;
        etaOpaqueReflection_0 = _S386;
        etaTransReflection_0 = _S385;
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
    var _S387 : vec3<f32> = AverageFresnelMetalF82_0(weightedBaseColor_0, metalF82Tint_2);
    var kSmooth_0 : f32 = AverageFresnel_0(etaCoat_0);
    var specularityOpaqueDielectric_0 : f32 = AverageFresnel_0(etaOpaqueReflection_0);
    var k_2 : f32 = mix(kSmooth_0, 1.0f - (1.0f - kSmooth_0) / Square_0(etaCoat_0), mix(1.0f, specularRoughness_1, opaqueDielectric_0 * specularityOpaqueDielectric_0 + (sss_0 + trans_0) * AverageFresnel_0(etaTransReflection_0) + inputs_3.baseMetalness_0));
    var _S388 : vec3<f32> = vec3<f32>(darkenedMetal_0);
    var _S389 : vec3<f32> = vec3<f32>(1.0f);
    var _S390 : vec3<f32> = vec3<f32>(opaqueDielectric_0);
    var _S391 : vec3<f32> = vec3<f32>(sss_0);
    var albedoTrans_0 : vec3<f32> = vec3<f32>(trans_0);
    var coatDarkening_1 : vec3<f32> = mix(_S389, vec3<f32>((1.0f - k_2)) / (_S389 - (_S388 * _S387 + _S390 * mix(weightedBaseColor_0, _S389, vec3<f32>(specularityOpaqueDielectric_0)) + _S391 * inputs_3.subsurfaceColor_0 + albedoTrans_0) * vec3<f32>(k_2)), vec3<f32>((inputs_3.coatWeight_0 * inputs_3.coatDarkening_0)));
    var distribution_6 : GGXDistribution_0 = GGXDistribution_x24init_0(anisotropicSpecularAlpha_0, specularBasis_1, specularAlpha_3);
    var transIncludingSss_0 : f32 = trans_0 + sss_0;
    var scaleOpaqueReflection_0 : vec3<f32> = inputs_3.specularColor_0 * _S390;
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
            var _S392 : vec3<f32> = inputs_3.specularColor_0 * _S391;
            thinWallSpecularTransmissionAlbedoScale_0 = inputs_3.specularColor_0 * albedoTrans_0;
            thinWallAwareScaleTransReflection_0 = _S392;
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
        var _S393 : f32 = SafeDivide_0(20.0f, SafeDivide_0(inputs_3.transmissionDispersionAbbeNumber_0, inputs_3.transmissionDispersionScale_0, 0.0f), 0.0f);
        etaRefractionRGB_0[i32(0)] = DispersionAdjustedIor_0(etaRefraction_0, _S393, wavelengths_2[i32(0)]);
        var _S394 : bool = etaTransReflection_0 == etaRefraction_0;
        if(_S394)
        {
            dispersion_2 = etaRefractionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S393, wavelengths_2[i32(0)]);
        }
        etaTransReflectionRGB_0[i32(0)] = dispersion_2;
        var _S395 : bool = etaOpaqueReflection_0 == etaTransReflection_0;
        if(_S395)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(0)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S393, wavelengths_2[i32(0)]);
        }
        etaOpaqueReflectionRGB_0[i32(0)] = dispersion_2;
        etaRefractionRGB_0[i32(1)] = DispersionAdjustedIor_0(etaRefraction_0, _S393, wavelengths_2[i32(1)]);
        if(_S394)
        {
            dispersion_2 = etaRefractionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S393, wavelengths_2[i32(1)]);
        }
        etaTransReflectionRGB_0[i32(1)] = dispersion_2;
        if(_S395)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(1)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S393, wavelengths_2[i32(1)]);
        }
        etaOpaqueReflectionRGB_0[i32(1)] = dispersion_2;
        etaRefractionRGB_0[i32(2)] = DispersionAdjustedIor_0(etaRefraction_0, _S393, wavelengths_2[i32(2)]);
        if(_S394)
        {
            dispersion_2 = etaRefractionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaTransReflection_0, _S393, wavelengths_2[i32(2)]);
        }
        etaTransReflectionRGB_0[i32(2)] = dispersion_2;
        if(_S395)
        {
            dispersion_2 = etaTransReflectionRGB_0[i32(2)];
        }
        else
        {
            dispersion_2 = DispersionAdjustedIor_0(etaOpaqueReflection_0, _S393, wavelengths_2[i32(2)]);
        }
        etaOpaqueReflectionRGB_0[i32(2)] = dispersion_2;
        dispersion_2 = _S393;
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
    var tintedTransIncludingSss_0 : vec3<f32> = tintedTrans_0 + _S391;
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
    var _S396 : vec3<f32> = vec3<f32>(0.0f);
    var thinWallSpecularReflectionAlbedo_0 : vec3<f32>;
    var thinWallSpecularTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var _S397 : vec3<f32> = tintedTrans_0 * vec3<f32>((1.0f - ThinWallFresnel_0(etaRefraction_0, thinWallAwareCosTheta_0)));
        thinWallSpecularReflectionAlbedo_0 = thinWallSpecularTransmissionAlbedoScale_0 * vec3<f32>(ThinWallFresnel_0(etaTransReflection_0, thinWallAwareCosTheta_0));
        thinWallSpecularTransmissionAlbedo_0 = _S397;
    }
    else
    {
        thinWallSpecularReflectionAlbedo_0 = _S396;
        thinWallSpecularTransmissionAlbedo_0 = _S396;
    }
    var thinWallSubsurfaceReflectionAlbedo_0 : vec3<f32>;
    var thinWallSubsurfaceTransmissionAlbedo_0 : vec3<f32>;
    if(inputs_3.geometryThinWalled_0)
    {
        var transmissionProportion_0 : f32 = (derived_1.thinWallSubsurfaceAnisotropy_0 + 1.0f) * 0.5f;
        var subsurfaceAlbedo_0 : vec3<f32> = _S391 * derived_1.thinWallSubsurfaceColor_0;
        var _S398 : vec3<f32> = subsurfaceAlbedo_0 * vec3<f32>(transmissionProportion_0);
        thinWallSubsurfaceReflectionAlbedo_0 = subsurfaceAlbedo_0 * vec3<f32>((1.0f - transmissionProportion_0));
        thinWallSubsurfaceTransmissionAlbedo_0 = _S398;
    }
    else
    {
        thinWallSubsurfaceReflectionAlbedo_0 = _S396;
        thinWallSubsurfaceTransmissionAlbedo_0 = _S396;
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
    var base_12 : BaseLobe_0;
    base_12.specular_0 = SpecularLobe_x24init_0(_S382.n_1, distribution_6, coefficient_5, etaRefractionRGB_0, throughput_20);
    base_12.dielectricMultipleScattering_0 = DielectricMultipleScatteringLobe_x24init_0(_S382.n_1, wo_62, specularAlpha_3, etaRefraction_0, scaleTransReflection_0, tintedTransIncludingSss_0);
    base_12.metalMultipleScattering_0 = MetalMultipleScatteringLobe_x24init_0(_S382.n_1, wo_62, specularAlpha_3, Square_1(_S387) * _S388);
    base_12.diffuse_0 = DiffuseLobe_x24init_0(_S382.n_1, wo_62, weightedBaseColor_0 * _S390 + thinWallSubsurfaceReflectionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    base_12.thinWallSpecularTransmission_0 = MakeThinWallSpecularTransmissionLobe_0(_S382.n_1, distribution_6, thinWallSpecularTransmissionAlbedo_0);
    base_12.thinWallDiffuseTransmission_0 = MakeThinWallDiffuseTransmissionLobe_0(_S382.n_1, wo_62, thinWallSubsurfaceTransmissionAlbedo_0, inputs_3.baseDiffuseRoughness_0, specularAlpha_3, etaOpaqueReflection_0);
    BaseLobe_InitWeights_0(&(base_12), wo_62, throughput_20);
    var coat_0 : CoatLobe_0 = CoatLobe_x24init_0(base_12, MicrofacetReflectionLobe_x24init_0(_S383.n_1, GGXDistribution_x24init_0(anisotropicCoatAlpha_0, coatBasis_2, coatAlpha_0), DielectricReflection_x24init_0(etaCoat_0)), _S383.n_1, wo_62, inputs_3.coatColor_0, inputs_3.coatWeight_0, coatDarkening_1, inside_3);
    var fuzzNormal_0 : vec3<f32> = normalize(mix(_S382.n_1, _S383.n_1, vec3<f32>(inputs_3.coatWeight_0)));
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
    if(((dot(wo_63, inputs_4.basis_4.n_1)) < 0.0f))
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
        result_5 = result_4 * lobes_0.base_1.inBaseLayerScale_0;
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
    var _S399 : BSDF_0;
    _S399.wo_64 = wo_65;
    var derived_2 : VolumeDerived_0;
    var _S400 : HomogeneousVolume_0 = PrepareVolume_0(inputs_5, &(derived_2));
    _S399.volume_0 = _S400;
    var _S401 : FuzzLobe_0 = PrepareLobes_0(inputs_5, derived_2, wo_65, throughput_21, wavelengths_3, exteriorIor_1);
    _S399.lobes_1 = _S401;
    _S399.emission_1 = ComputeEmission_0(inputs_5, wo_65, _S401);
    return _S399;
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
    var _S402 : RandomSequence_0;
    _S402.seed_1 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_1));
    return _S402;
}

fn BaseLobe_MaxActiveAlpha_0( this_114 : BaseLobe_0) -> f32
{
    var _S403 : bool;
    if(BaseLobe_IsActive_0(this_114, i32(3)))
    {
        _S403 = true;
    }
    else
    {
        _S403 = BaseLobe_IsActive_0(this_114, i32(5));
    }
    if(_S403)
    {
        _S403 = true;
    }
    else
    {
        _S403 = BaseLobe_IsActive_0(this_114, i32(1));
    }
    if(_S403)
    {
        _S403 = true;
    }
    else
    {
        _S403 = BaseLobe_IsActive_0(this_114, i32(2));
    }
    if(_S403)
    {
        return 1.0f;
    }
    if(BaseLobe_IsActive_0(this_114, i32(0)))
    {
        _S403 = true;
    }
    else
    {
        _S403 = BaseLobe_IsActive_0(this_114, i32(4));
    }
    if(_S403)
    {
        return max(this_114.specular_0.distribution_0.alpha_0.x, this_114.specular_0.distribution_0.alpha_0.y);
    }
    return 0.0f;
}

fn BSDF_MaxActiveAlpha_0( this_115 : BSDF_0) -> f32
{
    var baseAlpha_0 : f32 = BaseLobe_MaxActiveAlpha_0(this_115.lobes_1.base_1.base_0);
    var _S404 : f32;
    if(FuzzLobe_HasFuzz_0(this_115.lobes_1))
    {
        _S404 = 1.0f;
    }
    else
    {
        _S404 = max(baseAlpha_0, CoatLobe_MaxActiveAlpha_0(this_115.lobes_1.base_1));
    }
    return _S404;
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
    var _S405 : f32 = cos(elevation_1);
    (*cosElevation_0) = _S405;
    return vec3<f32>(cos(azimuth_2) * _S405, sin(elevation_1), sin(azimuth_2) * _S405);
}

struct LightSample_0
{
     position_2 : vec3<f32>,
     normal_20 : vec3<f32>,
     radiance_3 : vec3<f32>,
     solidAnglePdf_0 : f32,
     delta_0 : bool,
     shadow_0 : bool,
};

fn SampleEnvironment_0( rng_2 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_21 : LightSample_0;
    s_21.position_2 = vec3<f32>(0.0f);
    s_21.delta_0 = false;
    s_21.shadow_0 = true;
    var u_26 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_2)));
    var dir_8 : vec3<f32>;
    if((((gFrame_0.settings_0.z) & (u32(4)))) == u32(0))
    {
        var z_10 : f32 = 1.0f - 2.0f * u_26.x;
        var r_9 : f32 = sqrt(max(0.0f, 1.0f - z_10 * z_10));
        var PI_5 : f32 = float_getPi_0();
        var phi_1 : f32 = 2.0f * PI_5 * u_26.y;
        var _S406 : vec3<f32> = vec3<f32>(r_9 * cos(phi_1), r_9 * sin(phi_1), z_10);
        s_21.solidAnglePdf_0 = 1.0f / (4.0f * PI_5);
        dir_8 = _S406;
    }
    else
    {
        var W_1 : u32 = gFrame_0.envInfo_0.x;
        var H_1 : u32 = gFrame_0.envInfo_0.y;
        var _S407 : f32 = u_26.y;
        var y_12 : u32 = SearchCdfRow_0(H_1, H_1, _S407);
        var cy0_0 : f32 = EnvCdf_0(y_12, H_1);
        var cy1_0 : f32 = EnvCdf_0(y_12 + u32(1), H_1);
        var dv_0 : f32;
        if((cy1_0 > cy0_0))
        {
            dv_0 = (_S407 - cy0_0) / (cy1_0 - cy0_0);
        }
        else
        {
            dv_0 = 0.5f;
        }
        var _S408 : f32 = u_26.x;
        var x_31 : u32 = SearchCdfRow_0(y_12, W_1, _S408);
        var cx0_0 : f32 = EnvCdf_0(x_31, y_12);
        var cx1_0 : f32 = EnvCdf_0(x_31 + u32(1), y_12);
        var du_0 : f32;
        if((cx1_0 > cx0_0))
        {
            du_0 = (_S408 - cx0_0) / (cx1_0 - cx0_0);
        }
        else
        {
            du_0 = 0.5f;
        }
        var _S409 : f32 = f32(H_1);
        var _S410 : f32 = f32(W_1);
        var pdfUV_0 : f32 = (cy1_0 - cy0_0) * _S409 * (cx1_0 - cx0_0) * _S410;
        var cosElevation_1 : f32;
        var local_4 : vec3<f32> = EquirectUVToDirection_0(vec2<f32>((f32(x_31) + du_0) / _S410, (f32(y_12) + dv_0) / _S409), &(cosElevation_1));
        var _S411 : vec3<f32> = RotateY_0(local_4, gFrame_0.envParams_0.y);
        var PI_6 : f32 = float_getPi_0();
        s_21.solidAnglePdf_0 = pdfUV_0 / (2.0f * PI_6 * PI_6 * max(cosElevation_1, 9.99999997475242708e-07f));
        dir_8 = _S411;
    }
    s_21.normal_20 = (vec3<f32>(0) - dir_8);
    s_21.radiance_3 = EvalEnvironment_0(dir_8);
    return s_21;
}

fn ComputeOffsetOrigin_0( pos_0 : vec3<f32>,  normal_21 : vec3<f32>) -> vec3<f32>
{
    var _S412 : vec3<i32> = vec3<i32>(normal_21 * vec3<f32>(768.0f));
    var _S413 : vec3<i32> = (bitcast<vec3<i32>>((pos_0)));
    var _S414 : f32 = pos_0.x;
    var _S415 : i32;
    if((_S414 < 0.0f))
    {
        _S415 = - _S412.x;
    }
    else
    {
        _S415 = _S412.x;
    }
    var _S416 : f32 = pos_0.y;
    var _S417 : i32;
    if((_S416 < 0.0f))
    {
        _S417 = - _S412.y;
    }
    else
    {
        _S417 = _S412.y;
    }
    var _S418 : f32 = pos_0.z;
    var _S419 : i32;
    if((_S418 < 0.0f))
    {
        _S419 = - _S412.z;
    }
    else
    {
        _S419 = _S412.z;
    }
    var pI_0 : vec3<f32> = (bitcast<vec3<f32>>((_S413 + vec3<i32>(_S415, _S417, _S419))));
    var fOff_0 : vec3<f32> = normal_21 * vec3<f32>(4.57763671875e-05f);
    var _S420 : f32;
    if(((abs(_S414)) < 0.0625f))
    {
        _S420 = _S414 + fOff_0.x;
    }
    else
    {
        _S420 = pI_0.x;
    }
    var _S421 : f32;
    if(((abs(_S416)) < 0.0625f))
    {
        _S421 = _S416 + fOff_0.y;
    }
    else
    {
        _S421 = pI_0.y;
    }
    var _S422 : f32;
    if(((abs(_S418)) < 0.0625f))
    {
        _S422 = _S418 + fOff_0.z;
    }
    else
    {
        _S422 = pI_0.z;
    }
    return vec3<f32>(_S420, _S421, _S422);
}

fn ShadowOrigin_0( si_2 : SurfaceInteraction_0,  dir_9 : vec3<f32>) -> vec3<f32>
{
    var _S423 : vec3<f32>;
    if(((dot(si_2.faceNormal_0, dir_9)) >= 0.0f))
    {
        _S423 = si_2.faceNormal_0;
    }
    else
    {
        _S423 = (vec3<f32>(0) - si_2.faceNormal_0);
    }
    return ComputeOffsetOrigin_0(si_2.position_1, _S423);
}

fn LightCount_0() -> u32
{
    return gFrame_0.counts_0.y;
}

fn SelectLight_0( u_27 : f32) -> u32
{
    var _S424 : u32 = LightCount_0() - u32(1);
    var lo_1 : u32 = u32(0);
    var hi_1 : u32 = _S424;
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
    var _S425 : u32 = AnalyticFlags_0(&((*light_2)));
    var d_11 : vec2<f32>;
    if(((_S425 & (u32(512)))) != u32(0))
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
    var s_22 : LightSample_0;
    s_22.delta_0 = false;
    s_22.radiance_3 = vec3<f32>(0.0f);
    s_22.solidAnglePdf_0 = 0.0f;
    var _S426 : u32 = AnalyticFlags_0(&((*light_3)));
    s_22.shadow_0 = ((_S426 & (u32(1024)))) == u32(0);
    var u_29 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_3)));
    if(((_S426 & (u32(255)))) == u32(2))
    {
        var _S427 : vec3<f32> = AreaLightPoint_0(&((*light_3)), u_29);
        s_22.position_2 = _S427;
        var _S428 : vec3<f32> = (*light_3).p2_0.xyz;
        s_22.normal_20 = _S428;
        var toLight_1 : vec3<f32> = _S427 - viewer_1;
        var distSq_3 : f32 = dot(toLight_1, toLight_1);
        var cosTheta_13 : f32 = - dot(_S428, toLight_1) * rsqrt_0(max(distSq_3, 9.99999968265522539e-21f));
        if((cosTheta_13 > 9.99999997475242708e-07f))
        {
            s_22.radiance_3 = (*light_3).p1_0.xyz;
            s_22.solidAnglePdf_0 = (*light_3).p1_0.w * distSq_3 / (cosTheta_13 * (*light_3).p0_0.w);
        }
        return s_22;
    }
    var _S429 : vec3<f32> = (*light_3).p0_0.xyz;
    var toCenter_1 : vec3<f32> = _S429 - viewer_1;
    var distSq_4 : f32 = dot(toCenter_1, toCenter_1);
    var w_1 : vec3<f32> = toCenter_1 / vec3<f32>(max(sqrt(distSq_4), 9.99999968265522539e-21f));
    var radius_4 : f32 = (*light_3).p0_0.w;
    if((radius_4 <= 0.0f))
    {
        s_22.position_2 = _S429;
        var _S430 : vec3<f32> = (vec3<f32>(0) - w_1);
        s_22.normal_20 = _S430;
        var _S431 : vec4<f32> = (*light_3).p1_0;
        var _S432 : vec3<f32> = (*light_3).p1_0.xyz;
        var _S433 : f32 = SpotAttenuation_0(&((*light_3)), _S430);
        s_22.radiance_3 = _S432 * vec3<f32>(_S433) / vec3<f32>(max(distSq_4, 9.99999968265522539e-21f));
        s_22.solidAnglePdf_0 = _S431.w;
        s_22.delta_0 = true;
        return s_22;
    }
    var oneMinusCosMax_0 : f32 = SphereOneMinusCos_0(radius_4, distSq_4);
    if((oneMinusCosMax_0 <= 0.0f))
    {
        s_22.position_2 = _S429;
        s_22.normal_20 = (vec3<f32>(0) - w_1);
        return s_22;
    }
    var oneMinusCos_1 : f32 = u_29.x * oneMinusCosMax_0;
    var cosTheta_14 : f32 = 1.0f - oneMinusCos_1;
    var sinTheta_1 : f32 = sqrt(max(0.0f, oneMinusCos_1 * (2.0f - oneMinusCos_1)));
    var TWO_PI_1 : f32 = 2.0f * float_getPi_0();
    var phi_2 : f32 = TWO_PI_1 * u_29.y;
    var t_12 : vec3<f32>;
    var b_15 : vec3<f32>;
    BranchlessONB_1(w_1, &(t_12), &(b_15));
    var dir_10 : vec3<f32> = (t_12 * vec3<f32>(cos(phi_2)) + b_15 * vec3<f32>(sin(phi_2))) * vec3<f32>(sinTheta_1) + w_1 * vec3<f32>(cosTheta_14);
    var tc_6 : f32 = dot(toCenter_1, dir_10);
    var _S434 : vec3<f32> = viewer_1 + dir_10 * vec3<f32>((tc_6 - sqrt(max(0.0f, radius_4 * radius_4 - (distSq_4 - tc_6 * tc_6)))));
    s_22.position_2 = _S434;
    s_22.normal_20 = normalize(_S434 - _S429);
    var _S435 : vec4<f32> = (*light_3).p1_0;
    var _S436 : vec3<f32> = (*light_3).p1_0.xyz;
    var _S437 : f32 = SpotAttenuation_0(&((*light_3)), (vec3<f32>(0) - w_1));
    s_22.radiance_3 = _S436 * vec3<f32>(_S437);
    s_22.solidAnglePdf_0 = _S435.w / (TWO_PI_1 * oneMinusCosMax_0);
    return s_22;
}

fn SampleTriangle_0( u_30 : vec2<f32>) -> vec3<f32>
{
    var su_0 : f32 = sqrt(u_30.x);
    var _S438 : f32 = u_30.y;
    return vec3<f32>(1.0f - su_0, su_0 * (1.0f - _S438), su_0 * _S438);
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
    var _S439 : bool;
    if((MaterialHeader_AlphaMode_0(material_1)) == u32(1))
    {
        var _S440 : f32 = EvalOpacity_0(material_1, tc_8);
        _S439 = (_S440 < (material_1.alphaCutoff_0));
    }
    else
    {
        _S439 = false;
    }
    if(_S439)
    {
        return vec3<f32>(0.0f);
    }
    var _S441 : vec3<f32> = EvalEmission_0(material_1, tc_8);
    return _S441;
}

fn SampleEmissive_0( viewer_2 : vec3<f32>,  cone_0 : vec2<f32>,  rng_4 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var s_23 : LightSample_0;
    s_23.delta_0 = false;
    s_23.shadow_0 = true;
    var _S442 : f32 = RandomSequence_Next_0(&((*rng_4)));
    var _S443 : EmissiveTriangle_std430_0 = gLights_0[SelectLight_0(_S442)];
    var _S444 : u32 = AnalyticFlags_0(&(_S443));
    if(((_S444 & (u32(2147483648)))) != u32(0))
    {
        var _S445 : LightSample_0 = SampleAnalytic_0(&(_S443), viewer_2, &((*rng_4)));
        return _S445;
    }
    var _S446 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_4)));
    var bary_2 : vec3<f32> = SampleTriangle_0(_S446);
    var _S447 : vec4<f32> = _S443.p0_0;
    var _S448 : vec3<f32> = _S443.p0_0.xyz;
    var _S449 : f32 = bary_2.x;
    var _S450 : vec4<f32> = _S443.p1_0;
    var _S451 : vec3<f32> = _S443.p1_0.xyz;
    var _S452 : f32 = bary_2.y;
    var _S453 : vec3<f32> = _S443.p2_0.xyz;
    var _S454 : f32 = bary_2.z;
    var _S455 : vec3<f32> = _S448 * vec3<f32>(_S449) + _S451 * vec3<f32>(_S452) + _S453 * vec3<f32>(_S454);
    s_23.position_2 = _S455;
    s_23.normal_20 = _S443.n_0.xyz;
    var material_2 : MaterialHeader_0 = LoadMaterialHeader_0((bitcast<u32>((_S443.n_0.w))));
    var doubleSided_2 : bool = MaterialHeader_DoubleSided_0(material_2);
    var toLight_2 : vec3<f32> = _S455 - viewer_2;
    var dist_0 : f32 = length(toLight_2);
    var tc_9 : TextureCoords_0;
    var _S456 : vec2<f32> = _S443.uvA_0.xy;
    var _S457 : vec2<f32> = vec2<f32>(_S449);
    var _S458 : vec2<f32> = _S443.uvA_0.zw;
    var _S459 : vec2<f32> = vec2<f32>(_S452);
    var _S460 : vec2<f32> = _S443.uvB_0.xy;
    var _S461 : vec2<f32> = vec2<f32>(_S454);
    var _S462 : vec2<f32> = _S456 * _S457 + _S458 * _S459 + _S460 * _S461;
    var _S463 : vec2<f32> = _S443.uvB_0.zw;
    var _S464 : vec2<f32> = _S443.uvC_0.xy;
    var _S465 : vec2<f32> = _S443.uvC_0.zw;
    var _S466 : vec2<f32> = _S463 * _S457 + _S464 * _S459 + _S465 * _S461;
    var _S467 : vec3<f32> = _S451 - _S448;
    var _S468 : vec3<f32> = _S453 - _S448;
    var _S469 : vec2<f32> = _S458 - _S456;
    var _S470 : vec2<f32> = _S460 - _S456;
    var _S471 : vec2<f32> = _S464 - _S463;
    var _S472 : vec2<f32> = _S465 - _S463;
    var _S473 : f32 = cone_0.x + cone_0.y * dist_0;
    var _S474 : f32;
    if((dist_0 > 0.0f))
    {
        _S474 = dot(s_23.normal_20, toLight_2) / dist_0;
    }
    else
    {
        _S474 = 1.0f;
    }
    tc_9 = MakeTextureCoords_0(_S462, _S466, _S467, _S468, _S469, _S470, _S471, _S472, _S473, _S474);
    tc_9.objectPosition_0 = InverseTransformPoint_0((bitcast<u32>((_S443.pad_0.x))), s_23.position_2);
    var _S475 : vec3<f32> = EmissiveRadiance_0(material_2, tc_9);
    s_23.radiance_3 = _S475;
    s_23.solidAnglePdf_0 = _S450.w * EmissiveSolidAnglePdf_0(_S447.w, doubleSided_2, viewer_2, s_23.position_2, s_23.normal_20);
    var _S476 : bool;
    if(doubleSided_2)
    {
        _S476 = ((dot(s_23.normal_20, viewer_2 - s_23.position_2)) < 0.0f);
    }
    else
    {
        _S476 = false;
    }
    if(_S476)
    {
        s_23.normal_20 = (vec3<f32>(0) - s_23.normal_20);
    }
    return s_23;
}

fn SampleSun_0( rng_5 : ptr<function, RandomSequence_0>) -> LightSample_0
{
    var toSun_0 : vec3<f32> = gFrame_0.sunDirection_0.xyz;
    var t_13 : vec3<f32>;
    var b_16 : vec3<f32>;
    BranchlessONB_1(toSun_0, &(t_13), &(b_16));
    var _S477 : vec2<f32> = RandomSequence_Next2D_0(&((*rng_5)));
    var disk_0 : vec2<f32> = SampleDisk_0(_S477);
    var dir_11 : vec3<f32> = normalize(toSun_0 + (t_13 * vec3<f32>(disk_0.x) + b_16 * vec3<f32>(disk_0.y)) * vec3<f32>(sqrt(max(0.0f, 1.0f - Square_0(gFrame_0.sunDirection_0.w)))));
    var s_24 : LightSample_0;
    s_24.position_2 = vec3<f32>(0.0f);
    s_24.normal_20 = (vec3<f32>(0) - dir_11);
    s_24.radiance_3 = gFrame_0.sunRadiance_0.xyz;
    s_24.solidAnglePdf_0 = 1.0f / gFrame_0.sunRadiance_0.w;
    s_24.delta_0 = false;
    s_24.shadow_0 = true;
    return s_24;
}

fn BSDF_EvalPdf_0( this_116 : BSDF_0,  wi_42 : vec3<f32>,  f_19 : ptr<function, DiffuseSpecular_0>,  pdf_16 : ptr<function, f32>)
{
    FuzzLobe_EvalPdf_1(this_116.lobes_1, this_116.wo_64, wi_42, SampledLobe_None_0(), &((*f_19)), &((*pdf_16)));
    return;
}

fn QueueDirectLighting_0( base_13 : u32,  si_3 : SurfaceInteraction_0,  bsdf_0 : BSDF_0,  cone_1 : vec2<f32>,  throughput_22 : vec3<f32>,  rng_6 : ptr<function, RandomSequence_0>)
{
    var maxDistance_0 : f32;
    gRayCone_0 = cone_1;
    var source_0 : u32 = u32(0);
    var mask_0 : u32 = u32(0);
    loop
    {
        if((source_0 < u32(3)))
        {
        }
        else
        {
            break;
        }
        var mis_1 : bool;
        var shadow_1 : bool;
        var ls_0 : LightSample_0;
        var origin_6 : vec3<f32>;
        var dir_12 : vec3<f32>;
        if(source_0 == u32(0))
        {
            if(!EnvironmentEnabled_0())
            {
                source_0 = source_0 + u32(1);
                continue;
            }
            var ls_1 : LightSample_0 = SampleEnvironment_0(&((*rng_6)));
            if((any((((ls_1.radiance_3) > vec3<f32>(0.0f))))))
            {
                mis_1 = ((ls_1.solidAnglePdf_0) > 0.0f);
            }
            else
            {
                mis_1 = false;
            }
            if(!mis_1)
            {
                source_0 = source_0 + u32(1);
                continue;
            }
            var dir_13 : vec3<f32> = (vec3<f32>(0) - ls_1.normal_20);
            var _S478 : vec3<f32> = ShadowOrigin_0(si_3, dir_13);
            mis_1 = true;
            ls_0 = ls_1;
            origin_6 = _S478;
            maxDistance_0 = 1.00000001504746622e+30f;
            shadow_1 = true;
            dir_12 = dir_13;
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
                var ls_2 : LightSample_0 = SampleEmissive_0(si_3.position_1, cone_1, &((*rng_6)));
                if((any((((ls_2.radiance_3) > vec3<f32>(0.0f))))))
                {
                    mis_1 = ((ls_2.solidAnglePdf_0) > 0.0f);
                }
                else
                {
                    mis_1 = false;
                }
                if(!mis_1)
                {
                    source_0 = source_0 + u32(1);
                    continue;
                }
                var lightPos_1 : vec3<f32> = ComputeOffsetOrigin_0(ls_2.position_2, ls_2.normal_20);
                var origin_7 : vec3<f32> = ShadowOrigin_0(si_3, lightPos_1 - si_3.position_1);
                var dir_14 : vec3<f32> = lightPos_1 - origin_7;
                var maxDistance_1 : f32 = length(dir_14);
                var dir_15 : vec3<f32> = dir_14 / vec3<f32>(maxDistance_1);
                mis_1 = !ls_2.delta_0;
                ls_0 = ls_2;
                origin_6 = origin_7;
                maxDistance_0 = maxDistance_1;
                shadow_1 = ls_2.shadow_0;
                dir_12 = dir_15;
            }
            else
            {
                if(!SunEnabled_0())
                {
                    source_0 = source_0 + u32(1);
                    continue;
                }
                var ls_3 : LightSample_0 = SampleSun_0(&((*rng_6)));
                var dir_16 : vec3<f32> = (vec3<f32>(0) - ls_3.normal_20);
                var _S479 : vec3<f32> = ShadowOrigin_0(si_3, dir_16);
                mis_1 = false;
                ls_0 = ls_3;
                origin_6 = _S479;
                maxDistance_0 = 1.00000001504746622e+30f;
                shadow_1 = true;
                dir_12 = dir_16;
            }
        }
        var eval_0 : DiffuseSpecular_0;
        var pdf_17 : f32;
        BSDF_EvalPdf_0(bsdf_0, dir_12, &(eval_0), &(pdf_17));
        var f_20 : vec3<f32> = eval_0.diffuse_1 + eval_0.specular_1;
        var mask_1 : u32;
        if((any(((f_20 > vec3<f32>(0.0f))))))
        {
            var weight_3 : f32;
            if(mis_1)
            {
                weight_3 = EvalMISRobust_0(ls_0.solidAnglePdf_0, pdf_17);
            }
            else
            {
                weight_3 = 1.0f;
            }
            var offset_1 : u32 = base_13 + u32(12) + source_0 * u32(3);
            gAccum_0[offset_1] = vec4<f32>(origin_6, maxDistance_0);
            gAccum_0[offset_1 + u32(1)] = vec4<f32>(dir_12, (bitcast<f32>((select(u32(0), u32(1), shadow_1)))));
            gAccum_0[offset_1 + u32(2)] = vec4<f32>(vec3<f32>(weight_3) * ls_0.radiance_3 * f_20 / vec3<f32>(ls_0.solidAnglePdf_0), 0.0f);
            mask_1 = (mask_0 | (((u32(1) << (source_0)))));
        }
        else
        {
            mask_1 = mask_0;
        }
        mask_0 = mask_1;
        source_0 = source_0 + u32(1);
    }
    if(((gWavefront_0.bounce_0) > u32(0)))
    {
        maxDistance_0 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
    }
    else
    {
        maxDistance_0 = 0.0f;
    }
    gAccum_0[base_13 + u32(10)] = vec4<f32>(throughput_22, maxDistance_0);
    gAccum_0[base_13 + u32(11)] = vec4<f32>(cone_1, (bitcast<f32>((mask_0))), 0.0f);
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

fn EmissiveHitPdf_0( _S480 : u32,  _S481 : u32,  _S482 : vec3<f32>,  _S483 : vec3<f32>) -> f32
{
    if((((gInstances_0[_S480].flags_0) & (u32(2)))) == u32(0))
    {
        return 0.0f;
    }
    var light_4 : EmissiveTriangle_std430_0 = gLights_0[gInstances_0[_S480].lightOffset_0 + _S481];
    return light_4.p1_0.w * EmissiveSolidAnglePdf_0(light_4.p0_0.w, MaterialHeader_DoubleSided_0(LoadMaterialHeader_0((bitcast<u32>((light_4.n_0.w))))), _S482, _S483, light_4.n_0.xyz);
}

fn ShadePath_0( base_14 : u32,  s_25 : ptr<function, WavefrontPath_0>)
{
    var hit_4 : HitRecord_0;
    hit_4.t_6 = gAccum_0[base_14 + u32(8)].x;
    hit_4.barycentrics_0 = gAccum_0[base_14 + u32(8)].yz;
    hit_4.instanceIndex_1 = (bitcast<u32>((gAccum_0[base_14 + u32(8)].w)));
    hit_4.primitiveIndex_0 = (bitcast<u32>((gAccum_0[base_14 + u32(9)].x)));
    var _S484 : vec3<f32> = vec3<f32>(0.0f);
    if((any(((((*s_25).path_0.absorption_0) > _S484)))))
    {
        (*s_25).path_0.throughput_12 = (*s_25).path_0.throughput_12 * exp((*s_25).path_0.absorption_0 * vec3<f32>(- hit_4.t_6));
    }
    var hitConeWidth_0 : f32 = (*s_25).path_0.coneWidth_0 + (*s_25).path_0.coneSpread_0 * hit_4.t_6;
    var si_4 : SurfaceInteraction_0 = GetSurfaceInteraction_0((*s_25).path_0.direction_1, hit_4, hitConeWidth_0);
    var V_2 : vec3<f32> = (vec3<f32>(0) - (*s_25).path_0.direction_1);
    var ms_1 : MaterialSample_0 = EvalMaterial_0(si_4, V_2);
    var bsdf_1 : BSDF_0 = BSDF_x24init_0(ms_1.inputs_1, V_2, (*s_25).path_0.throughput_12, vec3<f32>(620.0f, 540.0f, 450.0f), 1.0f);
    var bounce_2 : u32 = gWavefront_0.bounce_0;
    var throughput_23 : vec3<f32>;
    if((gWavefront_0.bounce_0) == u32(0))
    {
        (*s_25).albedo_1 = ms_1.albedo_2;
        if(si_4.frontFacing_0)
        {
            throughput_23 = ms_1.inputs_1.basis_4.n_1;
        }
        else
        {
            throughput_23 = (vec3<f32>(0) - ms_1.inputs_1.basis_4.n_1);
        }
        (*s_25).normal_12 = throughput_23;
    }
    (*s_25).active_0 = u32(0);
    var _S485 : bool;
    if(!si_4.frontFacing_0)
    {
        _S485 = !ms_1.doubleSided_0;
    }
    else
    {
        _S485 = false;
    }
    if(_S485)
    {
        _S485 = ((ms_1.inputs_1.transmissionWeight_0) <= 0.0f);
    }
    else
    {
        _S485 = false;
    }
    if(_S485)
    {
        return;
    }
    if((any((((bsdf_1.emission_1) > _S484)))))
    {
        var _S486 : bool = (bounce_2 > u32(0));
        if(_S486)
        {
            _S485 = (*s_25).path_0.lightsSampled_0;
        }
        else
        {
            _S485 = false;
        }
        var mis_2 : f32;
        if(_S485)
        {
            mis_2 = EvalMISRobust_0((*s_25).path_0.scatterPdf_0, EmissiveHitPdf_0(si_4.instanceIndex_3, si_4.primitiveIndex_2, (*s_25).path_0.origin_4, si_4.position_1));
        }
        else
        {
            mis_2 = 1.0f;
        }
        var contribution_3 : vec3<f32> = (*s_25).path_0.throughput_12 * vec3<f32>(mis_2) * bsdf_1.emission_1;
        var clampValue_1 : f32 = gFrame_0.envParams_0.w / gFrame_0.envParams_0.z;
        if((clampValue_1 > 0.0f))
        {
            _S485 = _S486;
        }
        else
        {
            _S485 = false;
        }
        if(_S485)
        {
            throughput_23 = min(contribution_3, vec3<f32>(clampValue_1));
        }
        else
        {
            throughput_23 = contribution_3;
        }
        (*s_25).path_0.radiance_0 = (*s_25).path_0.radiance_0 + throughput_23;
    }
    if(bounce_2 == (gFrame_0.settings_0.x))
    {
        return;
    }
    var rng_7 : RandomSequence_0 = RandomSequence_x24init_1(u32(0), u32(0));
    rng_7.seed_1 = (*s_25).randomSeed_0;
    var _S487 : bool = ((BSDF_MaxActiveAlpha_0(bsdf_1)) >= 0.0010000000474974513f);
    (*s_25).path_0.lightsSampled_0 = _S487;
    if(_S487)
    {
        QueueDirectLighting_0(base_14, si_4, bsdf_1, vec2<f32>(hitConeWidth_0, (*s_25).path_0.coneSpread_0), (*s_25).path_0.throughput_12, &(rng_7));
    }
    var u_32 : vec2<f32> = RandomSequence_Next2D_0(&(rng_7));
    var _S488 : f32 = RandomSequence_Next_0(&(rng_7));
    var bs_0 : LobeSample_0 = BSDF_Sample_0(bsdf_1, vec3<f32>(u_32, _S488));
    var weight_4 : vec3<f32> = bs_0.weight_0.diffuse_1 + bs_0.weight_0.specular_1;
    if(!bs_0.valid_0)
    {
        _S485 = true;
    }
    else
    {
        _S485 = ((bs_0.pdf_1) <= 0.0f);
    }
    if(_S485)
    {
        _S485 = true;
    }
    else
    {
        _S485 = (all(((weight_4 <= _S484))));
    }
    if(_S485)
    {
        return;
    }
    var throughput_24 : vec3<f32> = (*s_25).path_0.throughput_12 * weight_4;
    var continuation_0 : f32 = sqrt(saturate(MaxComponent_0(throughput_24) / max(MaxComponent_0((*s_25).path_0.throughput_12), 9.999999960041972e-13f)));
    if((continuation_0 < 1.0f))
    {
        var _S489 : f32 = RandomSequence_Next_0(&(rng_7));
        if((_S489 >= continuation_0))
        {
            return;
        }
        throughput_23 = throughput_24 / vec3<f32>(continuation_0);
    }
    else
    {
        throughput_23 = throughput_24;
    }
    (*s_25).path_0.throughput_12 = throughput_23;
    (*s_25).path_0.direction_1 = bs_0.wi_0;
    (*s_25).path_0.scatterPdf_0 = bs_0.pdf_1;
    var crossesSurface_0 : bool = ((dot(bs_0.wi_0, si_4.faceNormal_0)) > 0.0f) != (si_4.frontFacing_0);
    (*s_25).path_0.origin_4 = SurfaceInteraction_ComputeRayOrigin_0(si_4, !crossesSurface_0);
    if(crossesSurface_0)
    {
        _S485 = !ms_1.thinWalled_0;
    }
    else
    {
        _S485 = false;
    }
    if(_S485)
    {
        if(si_4.frontFacing_0)
        {
            throughput_23 = HomogeneousVolume_Absorption_0(bsdf_1.volume_0);
        }
        else
        {
            throughput_23 = vec3<f32>(0.0f);
        }
        (*s_25).path_0.absorption_0 = throughput_23;
    }
    (*s_25).path_0.coneWidth_0 = hitConeWidth_0;
    (*s_25).path_0.coneSpread_0 = (*s_25).path_0.coneSpread_0 + ScatterConeSpread_0(bs_0.type_0, ms_1.roughness_5);
    (*s_25).randomSeed_0 = rng_7.seed_1;
    (*s_25).active_0 = u32(1);
    return;
}

@compute
@workgroup_size(64, 1, 1)
fn Shade(@builtin(global_invocation_id) tid_2 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S218();
    gTraversalCost_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_17 : u32 = tid_2.x;
    if((index_17 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_15 : u32 = WorkBase_0(index_17);
    gAccum_0[base_15 + u32(11)] = vec4<f32>(0.0f);
    var s_26 : WavefrontPath_0 = LoadPath_0(base_15);
    if((s_26.active_0) == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_15);
    ShadePath_0(base_15, &(s_26));
    StorePath_0(base_15, s_26);
    StoreFeedbackState_0(base_15);
    return;
}

fn TraceOcclusion_0( ray_4 : Ray_0) -> bool
{
    var hit_5 : HitRecord_0;
    var _S490 : bool = TraceScene_0(ray_4, true, &(hit_5));
    return _S490;
}

@compute
@workgroup_size(64, 1, 1)
fn Shadow(@builtin(global_invocation_id) tid_3 : vec3<u32>)
{
    var sum_5 : vec3<f32>;
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S218();
    gTraversalCost_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_18 : u32 = tid_3.x;
    if((index_18 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_16 : u32 = WorkBase_0(index_18);
    var info_0 : vec4<f32> = gAccum_0[base_16 + u32(11)];
    var mask_2 : u32 = (bitcast<u32>((gAccum_0[base_16 + u32(11)].z)));
    if(mask_2 == u32(0))
    {
        return;
    }
    LoadFeedbackState_0(base_16);
    gRayCone_0 = info_0.xy;
    var _S491 : vec3<f32> = vec3<f32>(0.0f);
    var source_1 : u32 = u32(0);
    var sum_6 : vec3<f32> = _S491;
    loop
    {
        if((source_1 < u32(3)))
        {
        }
        else
        {
            break;
        }
        if(((mask_2 & (((u32(1) << (source_1)))))) == u32(0))
        {
            source_1 = source_1 + u32(1);
            continue;
        }
        var offset_2 : u32 = base_16 + u32(12) + source_1 * u32(3);
        var origin_8 : vec4<f32> = gAccum_0[offset_2];
        var direction_2 : vec4<f32> = gAccum_0[offset_2 + u32(1)];
        var _S492 : bool;
        if((bitcast<u32>((gAccum_0[offset_2 + u32(1)].w))) == u32(0))
        {
            _S492 = true;
        }
        else
        {
            var _S493 : bool = TraceOcclusion_0(Ray_x24init_0(origin_8.xyz, direction_2.xyz, origin_8.w));
            _S492 = !_S493;
        }
        if(_S492)
        {
            sum_5 = sum_6 + gAccum_0[offset_2 + u32(2)].xyz;
        }
        else
        {
            sum_5 = sum_6;
        }
        sum_6 = sum_5;
        source_1 = source_1 + u32(1);
    }
    var contribution_4 : vec3<f32> = gAccum_0[base_16 + u32(10)].xyz * sum_6;
    var _S494 : f32 = gAccum_0[base_16 + u32(10)].w;
    if((_S494 > 0.0f))
    {
        sum_5 = min(contribution_4, vec3<f32>(_S494));
    }
    else
    {
        sum_5 = contribution_4;
    }
    var path_1 : vec4<f32> = gAccum_0[base_16];
    var _S495 : vec3<f32> = gAccum_0[base_16].xyz + sum_5;
    path_1.x = _S495.x;
    path_1.y = _S495.y;
    path_1.z = _S495.z;
    gAccum_0[base_16] = path_1;
    StoreFeedbackState_0(base_16);
    return;
}

fn IsFeedbackPixel_0( pixel_5 : vec2<u32>) -> bool
{
    var _S496 : vec2<u32> = vec2<u32>(gFrame_0.vtInfo_0.w);
    return (all((pixel_5 == (min(((((pixel_5 >> (_S496))) << (_S496))) + vec2<u32>(((gFrame_0.vtInfo_0.z) & (u32(65535))), ((gFrame_0.vtInfo_0.z) >> (u32(16)))), gFrame_0.frame_0.xy - vec2<u32>(u32(1)))))));
}

@compute
@workgroup_size(64, 1, 1)
fn Finalize(@builtin(global_invocation_id) tid_4 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S218();
    gTraversalCost_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var index_19 : u32 = tid_4.x;
    if((index_19 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_17 : u32 = WorkBase_0(index_19);
    var s_27 : WavefrontPath_0 = LoadPath_0(base_17);
    var pixel_6 : vec2<u32> = WorkPixel_0(index_19);
    LoadFeedbackState_0(base_17);
    if(IsFeedbackPixel_0(pixel_6))
    {
        textureStore((gVTFeedback_0), ((pixel_6 >> (vec2<u32>(gFrame_0.vtInfo_0.w)))), vec4<u32>((gVTRequest_0), 0, 0, 1));
    }
    var radiance_4 : vec3<f32> = s_27.path_0.radiance_0 * vec3<f32>(gFrame_0.envParams_0.z);
    var radiance_5 : vec3<f32>;
    if(!(all((isfinite_1(radiance_4)))))
    {
        radiance_5 = vec3<f32>(0.0f);
    }
    else
    {
        radiance_5 = radiance_4;
    }
    var output_0 : u32 = (gWavefront_0.tileStart_0 + index_19) * u32(3);
    if((gFrame_0.frame_0.z) == u32(0))
    {
        gAccum_0[output_0] = vec4<f32>(radiance_5, 1.0f);
        gAccum_0[output_0 + u32(1)] = vec4<f32>(s_27.albedo_1, 1.0f);
        gAccum_0[output_0 + u32(2)] = vec4<f32>(s_27.normal_12, 1.0f);
    }
    else
    {
        var _S497 : vec3<f32> = vec3<f32>((1.0f / f32(gFrame_0.frame_0.z + u32(1))));
        gAccum_0[output_0] = vec4<f32>(mix(gAccum_0[output_0].xyz, radiance_5, _S497), 1.0f);
        var _S498 : u32 = output_0 + u32(1);
        gAccum_0[_S498] = vec4<f32>(mix(gAccum_0[_S498].xyz, s_27.albedo_1, _S497), 1.0f);
        var _S499 : u32 = output_0 + u32(2);
        gAccum_0[_S499] = vec4<f32>(mix(gAccum_0[_S499].xyz, s_27.normal_12, _S497), 1.0f);
    }
    return;
}

