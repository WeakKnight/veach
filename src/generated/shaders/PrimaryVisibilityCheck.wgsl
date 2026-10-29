// Generated from shaders/Tests/PrimaryVisibility.slang by scripts/build-shaders.mjs. Do not edit.
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

@binding(6) @group(0) var<storage, read> gMaterialData_0 : array<vec4<u32>>;

@binding(12) @group(0) var gVTPageTable_0 : texture_2d<u32>;

@binding(11) @group(0) var gVTPhysical_0 : texture_2d<f32>;

@binding(8) @group(0) var gLinearSampler_0 : sampler;

@id(1) override gMaterialOpcodesHigh_0 : u32 = u32(4294967295);

@id(0) override gMaterialOpcodesLow_0 : u32 = u32(4294967295);

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
     normal_0 : vec3<f32>,
     tangent_1 : vec4<f32>,
     instanceIndex_0 : u32,
};

struct Frame_0
{
     t_0 : vec3<f32>,
     b_0 : vec3<f32>,
     n_0 : vec3<f32>,
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
     normal_1 : vec3<f32>,
     coatNormal_0 : vec3<f32>,
     tangent_2 : vec3<f32>,
     coatTangent_0 : vec3<f32>,
};

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

fn LanesBelow_0( size_0 : u32) -> vec4<bool>
{
    return (vec4<u32>(u32(0), u32(1), u32(2), u32(3)) < vec4<u32>(size_0));
}

fn MaterialWord_0( index_0 : u32) -> u32
{
    return gMaterialData_0[(index_0 >> (u32(2)))][(index_0 & (u32(3)))];
}

fn Bitangent_0( tangent_3 : vec4<f32>,  n_1 : vec3<f32>) -> vec3<f32>
{
    var _S1 : f32 = tangent_3.w;
    var _S2 : bool;
    if(_S1 == 0.0f)
    {
        _S2 = true;
    }
    else
    {
        var _S3 : vec3<f32> = tangent_3.xyz;
        _S2 = (dot(_S3, _S3)) == 0.0f;
    }
    if(_S2)
    {
        return vec3<f32>(0.0f);
    }
    var _S4 : vec3<f32> = tangent_3.xyz;
    return cross(n_1, normalize(_S4 - n_1 * vec3<f32>(dot(_S4, n_1)))) * vec3<f32>(_S1);
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
    var _S5 : u32 = header_0.textureBase_0 + index_1 * u32(2);
    var a_0 : vec4<u32> = gMaterialData_0[_S5];
    var ref_0 : TextureRef_0;
    ref_0.flags_2 = a_0.x;
    ref_0.pageTableOffset_0 = a_0.y;
    ref_0.reserved_0 = a_0.z;
    ref_0.rotation_0 = (bitcast<f32>((a_0.w)));
    ref_0.scaleOffset_0 = (bitcast<vec4<f32>>((gMaterialData_0[_S5 + u32(1)])));
    return ref_0;
}

fn HasTexture_0( ref_1 : TextureRef_0) -> bool
{
    return (((ref_1.flags_2) & (u32(1)))) != u32(0);
}

fn TransformUV_0( ref_2 : TextureRef_0,  uv_0 : vec2<f32>) -> vec2<f32>
{
    var s_0 : vec2<f32> = ref_2.scaleOffset_0.xy * uv_0;
    var c_0 : f32 = cos(ref_2.rotation_0);
    var r_0 : f32 = sin(ref_2.rotation_0);
    var _S6 : f32 = s_0.x;
    var _S7 : f32 = s_0.y;
    return vec2<f32>(c_0 * _S6 + r_0 * _S7, - r_0 * _S6 + c_0 * _S7) + ref_2.scaleOffset_0.zw;
}

fn WrapCoord_0( x_0 : f32,  mode_0 : u32) -> f32
{
    if(mode_0 == u32(1))
    {
        return saturate(x_0);
    }
    if(mode_0 == u32(2))
    {
        var t_1 : f32 = x_0 - 2.0f * floor(x_0 * 0.5f);
        var _S8 : f32;
        if((t_1 > 1.0f))
        {
            _S8 = 2.0f - t_1;
        }
        else
        {
            _S8 = t_1;
        }
        return _S8;
    }
    return fract(x_0);
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
    var _S9 : u32 = u32(1664525) * gVTRandom_0 + u32(1013904223);
    gVTRandom_0 = _S9;
    return _S9;
}

fn VTPageCount_0( log2Size_0 : vec2<u32>,  level_0 : u32) -> vec2<u32>
{
    var _S10 : vec2<i32> = max(vec2<i32>(log2Size_0) - vec2<i32>(i32(level_0)) - vec2<i32>(i32(7)), vec2<i32>(i32(0)));
    return vec2<u32>((u32(1) << (u32(_S10.x))), (u32(1) << (u32(_S10.y))));
}

fn VTLevelSize_0( log2Size_1 : vec2<u32>,  level_1 : u32) -> vec2<f32>
{
    var _S11 : vec2<i32> = max(vec2<i32>(log2Size_1) - vec2<i32>(i32(level_1)), vec2<i32>(i32(0)));
    return vec2<f32>(f32((u32(1) << (u32(_S11.x)))), f32((u32(1) << (u32(_S11.y)))));
}

var<private> gVTRequestCount_0 : u32;

var<private> gVTRequest_0 : u32;

fn StoreVirtualTextureFeedback_0( pageIndex_0 : u32)
{
    gVTRequestCount_0 = gVTRequestCount_0 + u32(1);
    var _S12 : u32 = NextVTRandom_0();
    if(((f32((_S12 >> (u32(8)))) * 5.9604644775390625e-08f * f32(gVTRequestCount_0)) < 1.0f))
    {
        gVTRequest_0 = pageIndex_0 + u32(1);
    }
    return;
}

fn VTLoadEntry_0( index_2 : u32) -> u32
{
    var width_0 : u32 = gFrame_0.vtInfo_0.y;
    var _S13 : u32 = index_2 % width_0;
    var _S14 : i32 = i32(_S13);
    var _S15 : u32 = index_2 / width_0;
    var _S16 : vec3<i32> = vec3<i32>(_S14, i32(_S15), i32(0));
    return (textureLoad((gVTPageTable_0), ((_S16)).xy, ((_S16)).z).x);
}

var<private> gVTLastMappedLevel_0 : u32;

var<private> gVTLastRequestedLevel_0 : u32;

fn SampleVirtualTexture_0( ref_6 : TextureRef_0,  uv_1 : vec2<f32>,  uvFootprint_0 : f32) -> vec4<f32>
{
    var levels_0 : u32 = VTLevels_0(ref_6);
    var _S17 : u32 = VTLog2Width_0(ref_6);
    var _S18 : u32 = VTLog2Height_0(ref_6);
    var log2Size_2 : vec2<u32> = vec2<u32>(_S17, _S18);
    var lod_0 : f32 = uvFootprint_0 + 0.5f * (f32(_S17 + _S18) + log2(max(abs(ref_6.scaleOffset_0.x * ref_6.scaleOffset_0.y), 9.99999968265522539e-21f))) + gFrame_0.vtParams_0.z;
    var _S19 : u32 = NextVTRandom_0();
    var level_2 : u32 = u32(clamp(floor(lod_0 + f32((_S19 >> (u32(8)))) * 5.9604644775390625e-08f), 0.0f, f32(levels_0 - u32(1))));
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
    var _S20 : vec2<u32> = min((vec2<u32>(uv_1 * VTLevelSize_0(log2Size_2, level_2)) >> (vec2<u32>(u32(7)))), pages_0 - vec2<u32>(u32(1)));
    var index_5 : u32 = index_3 + (_S20.y * pages_0.x + _S20.x);
    StoreVirtualTextureFeedback_0(index_5);
    var entry_0 : u32 = VTLoadEntry_0(index_5);
    if(((entry_0 & (u32(2147483648)))) == u32(0))
    {
        return vec4<f32>(1.0f, 0.0f, 1.0f, 1.0f);
    }
    var mappedLevel_0 : u32 = (((entry_0 >> (u32(16)))) & (u32(15)));
    gVTLastMappedLevel_0 = mappedLevel_0;
    gVTLastRequestedLevel_0 = level_2;
    var local_0 : vec2<f32> = uv_1 * VTLevelSize_0(log2Size_2, mappedLevel_0) - vec2<f32>((_S20 >> (vec2<u32>((mappedLevel_0 - level_2))))) * vec2<f32>(128.0f);
    var tile_0 : u32 = (entry_0 & (u32(65535)));
    var tilesPerRow_0 : u32 = gFrame_0.vtInfo_0.x;
    var _S21 : u32 = tile_0 % tilesPerRow_0;
    var _S22 : f32 = f32(_S21);
    var _S23 : u32 = tile_0 / tilesPerRow_0;
    return (textureSampleLevel((gVTPhysical_0), (gLinearSampler_0), ((vec2<f32>(_S22, f32(_S23)) * vec2<f32>(136.0f) + vec2<f32>(4.0f) + local_0) * vec2<f32>(gFrame_0.vtParams_0.x)), (0.0f)));
}

fn SrgbToLinear_0( c_1 : vec3<f32>) -> vec3<f32>
{
    return select(pow((c_1 + vec3<f32>(0.054999999701976776f)) / vec3<f32>(1.0549999475479126f), vec3<f32>(2.4000000953674316f)), c_1 / vec3<f32>(12.920000076293945f), (c_1 <= vec3<f32>(0.040449999272823334f)));
}

fn SampleTexture_0( ref_7 : TextureRef_0,  tc_0 : TextureCoords_0) -> vec4<f32>
{
    var useUV1_0 : bool = (((ref_7.flags_2) & (u32(4)))) != u32(0);
    var uv_2 : vec2<f32>;
    var _S24 : vec2<f32>;
    if(useUV1_0)
    {
        _S24 = tc_0.uv1_1;
    }
    else
    {
        _S24 = tc_0.uv0_0;
    }
    var _S25 : vec2<f32> = TransformUV_0(ref_7, _S24);
    uv_2 = _S25;
    uv_2[i32(0)] = WrapCoord_0(_S25.x, ((((ref_7.flags_2) >> (u32(8)))) & (u32(3))));
    uv_2[i32(1)] = WrapCoord_0(uv_2.y, ((((ref_7.flags_2) >> (u32(10)))) & (u32(3))));
    var color_0 : vec4<f32>;
    var _S26 : vec2<f32> = uv_2;
    var _S27 : f32;
    if(useUV1_0)
    {
        _S27 = tc_0.footprint1_0;
    }
    else
    {
        _S27 = tc_0.footprint0_0;
    }
    var _S28 : vec4<f32> = SampleVirtualTexture_0(ref_7, _S26, _S27);
    color_0 = _S28;
    if((((ref_7.flags_2) & (u32(2)))) != u32(0))
    {
        var _S29 : vec3<f32> = SrgbToLinear_0(color_0.xyz);
        color_0.x = _S29.x;
        color_0.y = _S29.y;
        color_0.z = _S29.z;
    }
    return color_0;
}

fn ApplyNormalMap_0( tangent_4 : vec4<f32>,  n_3 : vec3<f32>,  texel_0 : vec3<f32>,  scale_0 : f32) -> vec3<f32>
{
    var _S30 : f32 = tangent_4.w;
    var _S31 : bool;
    if(_S30 == 0.0f)
    {
        _S31 = true;
    }
    else
    {
        var _S32 : vec3<f32> = tangent_4.xyz;
        _S31 = (dot(_S32, _S32)) == 0.0f;
    }
    if(_S31)
    {
        return n_3;
    }
    var _S33 : vec2<f32> = (texel_0.xy * vec2<f32>(2.0f) - vec2<f32>(1.0f)) * vec2<f32>(scale_0);
    var local_1 : vec3<f32>;
    local_1.x = _S33.x;
    local_1.y = _S33.y;
    var _S34 : f32 = texel_0.z;
    var _S35 : f32;
    if((_S34 <= 0.0f))
    {
        _S35 = sqrt(saturate(1.0f - dot(local_1.xy, local_1.xy)));
    }
    else
    {
        _S35 = abs(_S34 * 2.0f - 1.0f);
    }
    local_1[i32(2)] = _S35;
    if((dot(local_1, local_1)) == 0.0f)
    {
        return n_3;
    }
    var _S36 : vec3<f32> = normalize(local_1);
    local_1 = _S36;
    var _S37 : vec3<f32> = tangent_4.xyz;
    var t_2 : vec3<f32> = normalize(_S37 - n_3 * vec3<f32>(dot(_S37, n_3)));
    return normalize(t_2 * vec3<f32>(_S36.x) + cross(n_3, t_2) * vec3<f32>(_S30) * vec3<f32>(_S36.y) + n_3 * vec3<f32>(_S36.z));
}

fn TransformVector_0( _S38 : u32,  _S39 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S38].objectToWorld_0[i32(0)].xyz, _S39), dot(gInstances_0[_S38].objectToWorld_0[i32(1)].xyz, _S39), dot(gInstances_0[_S38].objectToWorld_0[i32(2)].xyz, _S39));
}

fn InverseTransformVector_0( _S40 : u32,  _S41 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S40].worldToObject_0[i32(0)].xyz, _S41), dot(gInstances_0[_S40].worldToObject_0[i32(1)].xyz, _S41), dot(gInstances_0[_S40].worldToObject_0[i32(2)].xyz, _S41));
}

fn HashRotate_0( x_1 : u32,  k_0 : u32) -> u32
{
    return (((x_1 << (k_0))) | (((x_1 >> ((u32(32) - k_0))))));
}

fn HashFinal_0( a_1 : u32,  b_1 : u32,  c_2 : u32) -> u32
{
    var _S42 : u32 = ((c_2 ^ (b_1))) - HashRotate_0(b_1, u32(14));
    var _S43 : u32 = ((a_1 ^ (_S42))) - HashRotate_0(_S42, u32(11));
    var _S44 : u32 = ((b_1 ^ (_S43))) - HashRotate_0(_S43, u32(25));
    var _S45 : u32 = ((_S42 ^ (_S44))) - HashRotate_0(_S44, u32(16));
    var _S46 : u32 = ((_S43 ^ (_S45))) - HashRotate_0(_S45, u32(4));
    var _S47 : u32 = ((_S44 ^ (_S46))) - HashRotate_0(_S46, u32(14));
    return ((_S45 ^ (_S47))) - HashRotate_0(_S47, u32(24));
}

fn HashUint2_0( kx_0 : u32,  ky_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928580) + kx_0, u32(3735928580) + ky_0, u32(3735928580));
}

fn RandomOffset3_0( seed_0 : f32) -> vec3<f32>
{
    var _S48 : u32 = (bitcast<u32>((seed_0)));
    return vec3<f32>(100.0f) + vec3<f32>(f32(HashUint2_0(_S48, (bitcast<u32>((0.0f))))), f32(HashUint2_0(_S48, (bitcast<u32>((1.0f))))), f32(HashUint2_0(_S48, (bitcast<u32>((2.0f)))))) * vec3<f32>(2.32830643653869629e-08f);
}

fn FMod_0( x_2 : f32,  y_0 : f32) -> f32
{
    return x_2 - trunc(x_2 / y_0) * y_0;
}

fn NoiseFade_0( t_3 : f32) -> f32
{
    return t_3 * t_3 * t_3 * (t_3 * (t_3 * 6.0f - 15.0f) + 10.0f);
}

fn HashUint3_0( kx_1 : u32,  ky_1 : u32,  kz_0 : u32) -> u32
{
    return HashFinal_0(u32(3735928584) + kx_1, u32(3735928584) + ky_1, u32(3735928584) + kz_0);
}

fn NoiseGrad3_0( hash_0 : u32,  x_3 : f32,  y_1 : f32,  z_0 : f32) -> f32
{
    var h_0 : u32 = (hash_0 & (u32(15)));
    var u_0 : f32;
    if((h_0 < u32(8)))
    {
        u_0 = x_3;
    }
    else
    {
        u_0 = y_1;
    }
    var v_0 : f32;
    if((h_0 < u32(4)))
    {
        v_0 = y_1;
    }
    else
    {
        var _S49 : bool;
        if(h_0 == u32(12))
        {
            _S49 = true;
        }
        else
        {
            _S49 = h_0 == u32(14);
        }
        if(_S49)
        {
            v_0 = x_3;
        }
        else
        {
            v_0 = z_0;
        }
    }
    if(((h_0 & (u32(1)))) != u32(0))
    {
        u_0 = - u_0;
    }
    if(((h_0 & (u32(2)))) != u32(0))
    {
        v_0 = - v_0;
    }
    return u_0 + v_0;
}

fn Perlin3_0( p_0 : vec3<f32>) -> f32
{
    var i_0 : vec3<f32> = floor(p_0);
    var f_0 : vec3<f32> = p_0 - i_0;
    var _S50 : u32 = (bitcast<u32>((i32(i_0.x))));
    var _S51 : u32 = (bitcast<u32>((i32(i_0.y))));
    var _S52 : u32 = (bitcast<u32>((i32(i_0.z))));
    var _S53 : f32 = f_0.x;
    var u_1 : f32 = NoiseFade_0(_S53);
    var _S54 : f32 = f_0.y;
    var v_1 : f32 = NoiseFade_0(_S54);
    var _S55 : f32 = f_0.z;
    var w_0 : f32 = NoiseFade_0(_S55);
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
        var _S56 : u32 = (c_3 & (u32(1)));
        var _S57 : u32 = (((c_3 >> (u32(1)))) & (u32(1)));
        var _S58 : u32 = (c_3 >> (u32(2)));
        g_0[c_3] = NoiseGrad3_0(HashUint3_0(_S50 + _S56, _S51 + _S57, _S52 + _S58), _S53 - f32(_S56), _S54 - f32(_S57), _S55 - f32(_S58));
        c_3 = c_3 + u32(1);
    }
    return mix(mix(mix(g_0[i32(0)], g_0[i32(1)], u_1), mix(g_0[i32(2)], g_0[i32(3)], u_1), v_1), mix(mix(g_0[i32(4)], g_0[i32(5)], u_1), mix(g_0[i32(6)], g_0[i32(7)], u_1), v_1), w_0);
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
    var _S59 : bool = rmd_0 != 0.0f;
    var _S60 : i32;
    if(_S59)
    {
        _S60 = octaves_0 + i32(1);
    }
    else
    {
        _S60 = octaves_0;
    }
    var i_1 : i32 = i32(0);
    var fscale_0 : f32 = 1.0f;
    var sum_0 : f32 = 0.0f;
    var amp_0 : f32 = 1.0f;
    var maxamp_0 : f32 = 0.0f;
    loop
    {
        if((i_1 <= _S60))
        {
        }
        else
        {
            sum2_0 = 0.0f;
            break;
        }
        var n_4 : f32 = SNoise3_0(vec3<f32>(fscale_0) * p_2);
        if((i_1 > octaves_0))
        {
            sum2_0 = sum_0 + n_4 * amp_0;
            break;
        }
        var sum_1 : f32 = sum_0 + n_4 * amp_0;
        var maxamp_1 : f32 = maxamp_0 + amp_0;
        var amp_1 : f32 = amp_0 * roughness_0;
        var fscale_1 : f32 = fscale_0 * lacunarity_0;
        i_1 = i_1 + i32(1);
        fscale_0 = fscale_1;
        sum_0 = sum_1;
        amp_0 = amp_1;
        maxamp_0 = maxamp_1;
    }
    if(_S59)
    {
        var a_2 : f32;
        if(normalize_0)
        {
            a_2 = 0.5f * sum_0 / maxamp_0 + 0.5f;
        }
        else
        {
            a_2 = sum_0;
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
        return mix(a_2, b_2, rmd_0);
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
    var _S61 : f32 = clamp(params_0.x, 0.0f, 15.0f);
    var _S62 : f32 = max(params_0.y, 0.0f);
    var _S63 : f32 = params_0.z;
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
        var _S64 : u32;
        if(color_1)
        {
            _S64 = u32(3);
        }
        else
        {
            _S64 = u32(1);
        }
        if((k_1 < _S64))
        {
        }
        else
        {
            break;
        }
        var _S65 : vec3<f32>;
        if(k_1 == u32(0))
        {
            _S65 = p_3;
        }
        else
        {
            _S65 = p_3 + RandomOffset3_0(f32(k_1 + u32(2)));
        }
        result_0[k_1] = NoiseFbm_0(_S65, _S61, _S62, _S63, normalize_1);
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

fn BlenderMagic_0( p_4 : vec3<f32>,  depth_0 : u32,  d_0 : f32) -> vec3<f32>
{
    var TWO_PI_0 : f32 = 2.0f * float_getPi_0();
    var px_0 : f32 = FMod_0(p_4.x, TWO_PI_0);
    var py_0 : f32 = FMod_0(p_4.y, TWO_PI_0);
    var pz_0 : f32 = FMod_0(p_4.z, TWO_PI_0);
    var x_4 : f32 = sin((px_0 + py_0 + pz_0) * 5.0f);
    var _S66 : f32 = - px_0;
    var y_2 : f32 = cos((_S66 + py_0 - pz_0) * 5.0f);
    var z_1 : f32 = - cos((_S66 - py_0 + pz_0) * 5.0f);
    var x_5 : f32;
    var z_2 : f32;
    var y_3 : f32;
    if((depth_0 > u32(0)))
    {
        var x_6 : f32 = x_4 * d_0;
        var z_3 : f32 = z_1 * d_0;
        var y_4 : f32 = - cos(x_6 - y_2 * d_0 + z_3) * d_0;
        if((depth_0 > u32(1)))
        {
            x_5 = cos(x_6 - y_4 - z_3) * d_0;
        }
        else
        {
            x_5 = x_6;
        }
        if((depth_0 > u32(2)))
        {
            z_2 = sin(- x_5 - y_4 - z_3) * d_0;
        }
        else
        {
            z_2 = z_3;
        }
        if((depth_0 > u32(3)))
        {
            x_5 = - cos(- x_5 + y_4 - z_2) * d_0;
        }
        if((depth_0 > u32(4)))
        {
            y_3 = - sin(- x_5 + y_4 + z_2) * d_0;
        }
        else
        {
            y_3 = y_4;
        }
        if((depth_0 > u32(5)))
        {
            y_3 = - cos(- x_5 + y_3 + z_2) * d_0;
        }
        if((depth_0 > u32(6)))
        {
            x_5 = cos(x_5 + y_3 + z_2) * d_0;
        }
        if((depth_0 > u32(7)))
        {
            z_2 = sin(x_5 + y_3 - z_2) * d_0;
        }
        if((depth_0 > u32(8)))
        {
            x_5 = - cos(- x_5 - y_3 + z_2) * d_0;
        }
        if((depth_0 > u32(9)))
        {
            y_3 = - sin(x_5 - y_3 + z_2) * d_0;
        }
    }
    else
    {
        x_5 = x_4;
        y_3 = y_2;
        z_2 = z_1;
    }
    if(d_0 != 0.0f)
    {
        var _S67 : f32 = 2.0f * d_0;
        var y_5 : f32 = y_3 / _S67;
        var z_4 : f32 = z_2 / _S67;
        x_5 = x_5 / _S67;
        y_3 = y_5;
        z_2 = z_4;
    }
    return vec3<f32>(0.5f - x_5, 0.5f - y_3, 0.5f - z_2);
}

fn BlenderChecker_0( p_5 : vec3<f32>) -> f32
{
    var i_2 : vec3<i32> = abs(vec3<i32>(floor((p_5 + vec3<f32>(9.99999997475242708e-07f)) * vec3<f32>(0.99999898672103882f))));
    var _S68 : f32;
    if(((((i_2.x) & (i32(1)))) == (((i_2.y) & (i32(1))))) == ((((i_2.z) & (i32(1)))) == i32(1)))
    {
        _S68 = 1.0f;
    }
    else
    {
        _S68 = 0.0f;
    }
    return _S68;
}

fn RunMaterialProgram_0( header_1 : MaterialHeader_0,  program_0 : u32,  ctx_0 : MaterialContext_0,  outputs_0 : ptr<function, MaterialOutputs_0>)
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
        var _S69 : u32 = ins_0.x;
        var op_0 : u32 = (_S69 & (u32(255)));
        var dst_0 : u32 = (((_S69 >> (u32(8)))) & (u32(15)));
        var imm_0 : u32 = (_S69 >> (u32(16)));
        if(op_0 == u32(0))
        {
            return;
        }
        var _S70 : vec4<f32> = vec4<f32>(0.0f);
        var _S71 : bool;
        if(((gMaterialOperandMode_0 & (u32(2)))) == u32(0))
        {
            _S71 = true;
        }
        else
        {
            _S71 = op_0 != u32(23);
        }
        var write_0 : bool;
        var a_3 : vec4<f32>;
        var b_3 : vec4<f32>;
        var c_4 : vec4<f32>;
        if(_S71)
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
                    a_3 = stack_0[((ins_0.y) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.y) & (u32(15))))
                    {
                    case u32(0):
                        {
                            a_3 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            a_3 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            a_3 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            a_3 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            a_3 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            a_3 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            a_3 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            a_3 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            a_3 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            a_3 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            a_3 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            a_3 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            a_3 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            a_3 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            a_3 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            a_3 = stack_0[i32(15)];
                        }
                    default :
                        {
                            a_3 = _S70;
                        }
                    }
                }
            }
            else
            {
                a_3 = _S70;
            }
            var _S72 : vec4<f32> = MaterialOperand_0(ins_0.y, a_3, header_1.constantBase_0);
            var _S73 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S73 = true;
            }
            else
            {
                _S73 = (((ins_0.z) & (u32(2147483648)))) == u32(0);
            }
            if(_S73)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    b_3 = stack_0[((ins_0.z) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.z) & (u32(15))))
                    {
                    case u32(0):
                        {
                            b_3 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            b_3 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            b_3 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            b_3 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            b_3 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            b_3 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            b_3 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            b_3 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            b_3 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            b_3 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            b_3 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            b_3 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            b_3 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            b_3 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            b_3 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            b_3 = stack_0[i32(15)];
                        }
                    default :
                        {
                            b_3 = _S70;
                        }
                    }
                }
            }
            else
            {
                b_3 = _S70;
            }
            var _S74 : vec4<f32> = MaterialOperand_0(ins_0.z, b_3, header_1.constantBase_0);
            var _S75 : bool;
            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
            {
                _S75 = true;
            }
            else
            {
                _S75 = (((ins_0.w) & (u32(2147483648)))) == u32(0);
            }
            if(_S75)
            {
                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                {
                    c_4 = stack_0[((ins_0.w) & (u32(15)))];
                }
                else
                {
                    switch(((ins_0.w) & (u32(15))))
                    {
                    case u32(0):
                        {
                            c_4 = stack_0[i32(0)];
                        }
                    case u32(1):
                        {
                            c_4 = stack_0[i32(1)];
                        }
                    case u32(2):
                        {
                            c_4 = stack_0[i32(2)];
                        }
                    case u32(3):
                        {
                            c_4 = stack_0[i32(3)];
                        }
                    case u32(4):
                        {
                            c_4 = stack_0[i32(4)];
                        }
                    case u32(5):
                        {
                            c_4 = stack_0[i32(5)];
                        }
                    case u32(6):
                        {
                            c_4 = stack_0[i32(6)];
                        }
                    case u32(7):
                        {
                            c_4 = stack_0[i32(7)];
                        }
                    case u32(8):
                        {
                            c_4 = stack_0[i32(8)];
                        }
                    case u32(9):
                        {
                            c_4 = stack_0[i32(9)];
                        }
                    case u32(10):
                        {
                            c_4 = stack_0[i32(10)];
                        }
                    case u32(11):
                        {
                            c_4 = stack_0[i32(11)];
                        }
                    case u32(12):
                        {
                            c_4 = stack_0[i32(12)];
                        }
                    case u32(13):
                        {
                            c_4 = stack_0[i32(13)];
                        }
                    case u32(14):
                        {
                            c_4 = stack_0[i32(14)];
                        }
                    case u32(15):
                        {
                            c_4 = stack_0[i32(15)];
                        }
                    default :
                        {
                            c_4 = _S70;
                        }
                    }
                }
            }
            else
            {
                c_4 = _S70;
            }
            var _S76 : vec4<f32> = MaterialOperand_0(ins_0.w, c_4, header_1.constantBase_0);
            a_3 = _S72;
            b_3 = _S74;
            c_4 = _S76;
        }
        else
        {
            a_3 = _S70;
            b_3 = _S70;
            c_4 = _S70;
        }
        var operands_0 : u32 = pc_0 * u32(4) + u32(1);
        var _S77 : u32;
        if(op_0 == u32(23))
        {
            _S77 = (((u32(351898) >> ((u32(2) * min(imm_0, u32(9)))))) & (u32(3)));
        }
        else
        {
            if(op_0 == u32(17))
            {
                _S77 = u32(1) + imm_0 / u32(4);
            }
            else
            {
                _S77 = u32(1);
            }
        }
        var pc_1 : u32 = pc_0 + _S77;
        var r_1 : vec4<f32> = _S70;
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
                r_1 = a_3 + b_3;
                write_0 = true;
            }
        case u32(2):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = a_3 - b_3;
                write_0 = true;
            }
        case u32(3):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(3)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = a_3 * b_3;
                write_0 = true;
            }
        case u32(4):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(4)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = a_3 / b_3;
                write_0 = true;
            }
        case u32(5):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(5)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = min(a_3, b_3);
                write_0 = true;
            }
        case u32(6):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(6)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = max(a_3, b_3);
                write_0 = true;
            }
        case u32(7):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(7)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = pow(a_3, b_3);
                write_0 = true;
            }
        case u32(8):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(8)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = atan2(a_3, b_3);
                write_0 = true;
            }
        case u32(9):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(9)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = sqrt(a_3);
                write_0 = true;
            }
        case u32(10):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(10)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = sin(a_3);
                write_0 = true;
            }
        case u32(11):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(11)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = cos(a_3);
                write_0 = true;
            }
        case u32(12):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(12)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = abs(a_3);
                write_0 = true;
            }
        case u32(13):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(13)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = min(max(a_3, b_3), c_4);
                write_0 = true;
            }
        case u32(14):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(14)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = mix(a_3, b_3, c_4);
                write_0 = true;
            }
        case u32(15):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(15)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>(a_3[min(imm_0, u32(3))]);
                write_0 = true;
            }
        case u32(16):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(16)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = select(vec4<f32>(f32((imm_0 >> (u32(8))))), a_3, LanesBelow_0((imm_0 & (u32(255)))));
                write_0 = true;
            }
        case u32(17):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(17)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>(a_3.x, b_3.x, c_4.x, 0.0f);
                if((imm_0 > u32(3)))
                {
                    var o_0 : u32 = MaterialWord_0(operands_0 + u32(3));
                    if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                    {
                        write_0 = true;
                    }
                    else
                    {
                        write_0 = ((o_0 & (u32(2147483648)))) == u32(0);
                    }
                    if(write_0)
                    {
                        if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                        {
                            slot_1 = stack_0[(o_0 & (u32(15)))];
                        }
                        else
                        {
                            switch((o_0 & (u32(15))))
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
                                    slot_1 = _S70;
                                }
                            }
                        }
                    }
                    else
                    {
                        slot_1 = _S70;
                    }
                    r_1[i32(3)] = MaterialOperand_0(o_0, slot_1, header_1.constantBase_0).x;
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
                r_1 = vec4<f32>(dot(select(_S70, a_3, lanes_0), select(_S70, b_3, lanes_0)));
                write_0 = true;
            }
        case u32(19):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(19)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var len_0 : f32 = length(select(_S70, a_3, LanesBelow_0(imm_0)));
                if((len_0 > 0.0f))
                {
                    slot_1 = a_3 / vec4<f32>(len_0);
                }
                else
                {
                    slot_1 = _S70;
                }
                r_1 = slot_1;
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
                    r_1 = vec4<f32>(ctx_0.tex_0.uv0_0, 0.0f, 0.0f);
                }
                else
                {
                    if(imm_0 == u32(1))
                    {
                        r_1 = vec4<f32>(ctx_0.tex_0.uv1_1, 0.0f, 0.0f);
                    }
                    else
                    {
                        if(imm_0 == u32(6))
                        {
                            r_1 = vec4<f32>(ctx_0.tex_0.objectPosition_0, 0.0f);
                        }
                        else
                        {
                            if(imm_0 == u32(2))
                            {
                                r_1 = vec4<f32>(ctx_0.position_0, 0.0f);
                            }
                            else
                            {
                                if(imm_0 == u32(3))
                                {
                                    r_1 = vec4<f32>(ctx_0.normal_0, 0.0f);
                                }
                                else
                                {
                                    if(imm_0 == u32(4))
                                    {
                                        r_1 = ctx_0.tangent_1;
                                    }
                                    else
                                    {
                                        r_1 = vec4<f32>(Bitangent_0(ctx_0.tangent_1, ctx_0.normal_0), 0.0f);
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
                if(((((gMaterialOpcodesLow_0 >> (u32(21)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var ref_8 : TextureRef_0 = LoadTextureRef_0(header_1, imm_0);
                if(HasTexture_0(ref_8))
                {
                    var _S78 : vec4<f32> = SampleTexture_0(ref_8, ctx_0.tex_0);
                    slot_1 = _S78;
                }
                else
                {
                    slot_1 = vec4<f32>(1.0f);
                }
                r_1 = slot_1;
                write_0 = true;
            }
        case u32(22):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(22)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>(ApplyNormalMap_0(ctx_0.tangent_1, ctx_0.normal_0, a_3.xyz, b_3.x), 0.0f);
                write_0 = true;
            }
        case u32(24):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(24)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = floor(a_3);
                write_0 = true;
            }
        case u32(25):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(25)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>((vec4<i32>(sign((a_3)))));
                write_0 = true;
            }
        case u32(26):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(26)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = exp(a_3);
                write_0 = true;
            }
        case u32(27):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(27)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = log(a_3);
                write_0 = true;
            }
        case u32(28):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(28)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = a_3 - b_3 * floor(a_3 / b_3);
                write_0 = true;
            }
        case u32(29):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(29)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = select(_S70, vec4<f32>(1.0f), (a_3 > b_3));
                write_0 = true;
            }
        case u32(30):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(30)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>(cross(a_3.xyz, b_3.xyz), 0.0f);
                write_0 = true;
            }
        case u32(31):
            {
                if(((((gMaterialOpcodesLow_0 >> (u32(31)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var _S79 : vec3<f32>;
                if(imm_0 == u32(1))
                {
                    _S79 = TransformVector_0(ctx_0.instanceIndex_0, a_3.xyz);
                }
                else
                {
                    _S79 = InverseTransformVector_0(ctx_0.instanceIndex_0, a_3.xyz);
                }
                r_1 = vec4<f32>(_S79, 0.0f);
                write_0 = true;
            }
        case u32(32):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(0)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var _S80 : bool = ((imm_0 & (u32(2)))) != u32(0);
                var v_2 : vec3<f32> = BlenderNoise_0(a_3.xyz, b_3, ((imm_0 & (u32(1)))) != u32(0), _S80);
                if(_S80)
                {
                    slot_1 = vec4<f32>(v_2, 0.0f);
                }
                else
                {
                    slot_1 = vec4<f32>(v_2.x);
                }
                r_1 = slot_1;
                write_0 = true;
            }
        case u32(33):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(1)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                var c_5 : vec3<f32> = BlenderMagic_0(a_3.xyz, imm_0, b_3.x);
                r_1 = vec4<f32>(c_5, (c_5.x + c_5.y + c_5.z) / 3.0f);
                write_0 = true;
            }
        case u32(34):
            {
                if(((((gMaterialOpcodesHigh_0 >> (u32(2)))) & (u32(1)))) == u32(0))
                {
                    write_0 = true;
                    break;
                }
                r_1 = vec4<f32>(BlenderChecker_0(a_3.xyz));
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.baseWeight_0 = MaterialOperand_0(o_1, slot_1, header_1.constantBase_0).x;
                        }
                        var o_2 : u32 = MaterialWord_0(operands_0 + u32(1));
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.baseColor_0 = MaterialOperand_0(o_2, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_3 : u32 = MaterialWord_0(operands_0 + u32(2));
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.baseDiffuseRoughness_0 = MaterialOperand_0(o_3, slot_1, header_1.constantBase_0).x;
                        }
                        var o_4 : u32 = MaterialWord_0(operands_0 + u32(3));
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.baseMetalness_0 = MaterialOperand_0(o_4, slot_1, header_1.constantBase_0).x;
                        }
                    }
                case u32(1):
                    {
                        var o_5 : u32 = MaterialWord_0(operands_0);
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularWeight_0 = MaterialOperand_0(o_5, slot_1, header_1.constantBase_0).x;
                        }
                        var o_6 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_6 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_6 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_6 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_6 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularColor_0 = MaterialOperand_0(o_6, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_7 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_7 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_7 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_7 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_7 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularRoughness_0 = MaterialOperand_0(o_7, slot_1, header_1.constantBase_0).x;
                        }
                        var o_8 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_8 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_8 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_8 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_8 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularIor_0 = MaterialOperand_0(o_8, slot_1, header_1.constantBase_0).x;
                        }
                        var o_9 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_9 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_9 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_9 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_9 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularDielectricOnly_0 = (MaterialOperand_0(o_9, slot_1, header_1.constantBase_0).x) != 0.0f;
                        }
                    }
                case u32(2):
                    {
                        var o_10 : u32 = MaterialWord_0(operands_0);
                        if(o_10 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_10 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_10 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_10 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.specularRoughnessAnisotropy_0 = MaterialOperand_0(o_10, slot_1, header_1.constantBase_0).x;
                        }
                        var o_11 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_11 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_11 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_11 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_11 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).tangent_2 = MaterialOperand_0(o_11, slot_1, header_1.constantBase_0).xyz;
                        }
                    }
                case u32(3):
                    {
                        var o_12 : u32 = MaterialWord_0(operands_0);
                        if(o_12 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_12 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_12 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_12 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionWeight_0 = MaterialOperand_0(o_12, slot_1, header_1.constantBase_0).x;
                        }
                        var o_13 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_13 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_13 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_13 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_13 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionColor_0 = MaterialOperand_0(o_13, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_14 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_14 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_14 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_14 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_14 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionDepth_0 = MaterialOperand_0(o_14, slot_1, header_1.constantBase_0).x;
                        }
                        var o_15 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_15 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_15 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_15 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_15 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionScatter_0 = MaterialOperand_0(o_15, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_16 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_16 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_16 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_16 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_16 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionScatterAnisotropy_0 = MaterialOperand_0(o_16, slot_1, header_1.constantBase_0).x;
                        }
                        var o_17 : u32 = MaterialWord_0(operands_0 + u32(5));
                        if(o_17 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_17 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_17 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_17 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionDispersionScale_0 = MaterialOperand_0(o_17, slot_1, header_1.constantBase_0).x;
                        }
                        var o_18 : u32 = MaterialWord_0(operands_0 + u32(6));
                        if(o_18 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_18 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_18 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_18 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.transmissionDispersionAbbeNumber_0 = MaterialOperand_0(o_18, slot_1, header_1.constantBase_0).x;
                        }
                    }
                case u32(4):
                    {
                        var o_19 : u32 = MaterialWord_0(operands_0);
                        if(o_19 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_19 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_19 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_19 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.subsurfaceWeight_0 = MaterialOperand_0(o_19, slot_1, header_1.constantBase_0).x;
                        }
                        var o_20 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_20 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_20 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_20 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_20 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.subsurfaceColor_0 = MaterialOperand_0(o_20, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_21 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_21 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_21 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_21 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_21 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.subsurfaceRadius_0 = MaterialOperand_0(o_21, slot_1, header_1.constantBase_0).x;
                        }
                        var o_22 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_22 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_22 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_22 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_22 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.subsurfaceRadiusScale_0 = MaterialOperand_0(o_22, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_23 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_23 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_23 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_23 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_23 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.subsurfaceScatterAnisotropy_0 = MaterialOperand_0(o_23, slot_1, header_1.constantBase_0).x;
                        }
                    }
                case u32(5):
                    {
                        var o_24 : u32 = MaterialWord_0(operands_0);
                        if(o_24 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_24 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_24 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_24 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatWeight_0 = MaterialOperand_0(o_24, slot_1, header_1.constantBase_0).x;
                        }
                        var o_25 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_25 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_25 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_25 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_25 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatColor_0 = MaterialOperand_0(o_25, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_26 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_26 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_26 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_26 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_26 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatRoughness_0 = MaterialOperand_0(o_26, slot_1, header_1.constantBase_0).x;
                        }
                        var o_27 : u32 = MaterialWord_0(operands_0 + u32(3));
                        if(o_27 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_27 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_27 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_27 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatRoughnessAnisotropy_0 = MaterialOperand_0(o_27, slot_1, header_1.constantBase_0).x;
                        }
                        var o_28 : u32 = MaterialWord_0(operands_0 + u32(4));
                        if(o_28 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_28 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_28 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_28 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatIor_0 = MaterialOperand_0(o_28, slot_1, header_1.constantBase_0).x;
                        }
                        var o_29 : u32 = MaterialWord_0(operands_0 + u32(5));
                        if(o_29 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_29 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_29 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_29 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.coatDarkening_0 = MaterialOperand_0(o_29, slot_1, header_1.constantBase_0).x;
                        }
                        var o_30 : u32 = MaterialWord_0(operands_0 + u32(6));
                        if(o_30 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_30 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_30 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_30 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).coatNormal_0 = MaterialOperand_0(o_30, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_31 : u32 = MaterialWord_0(operands_0 + u32(7));
                        if(o_31 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_31 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_31 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_31 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).coatTangent_0 = MaterialOperand_0(o_31, slot_1, header_1.constantBase_0).xyz;
                        }
                    }
                case u32(6):
                    {
                        var o_32 : u32 = MaterialWord_0(operands_0);
                        if(o_32 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_32 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_32 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_32 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.fuzzWeight_0 = MaterialOperand_0(o_32, slot_1, header_1.constantBase_0).x;
                        }
                        var o_33 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_33 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_33 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_33 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_33 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.fuzzColor_0 = MaterialOperand_0(o_33, slot_1, header_1.constantBase_0).xyz;
                        }
                        var o_34 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_34 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_34 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_34 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_34 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.fuzzRoughness_0 = MaterialOperand_0(o_34, slot_1, header_1.constantBase_0).x;
                        }
                    }
                case u32(7):
                    {
                        var o_35 : u32 = MaterialWord_0(operands_0);
                        if(o_35 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_35 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_35 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_35 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.thinFilmWeight_0 = MaterialOperand_0(o_35, slot_1, header_1.constantBase_0).x;
                        }
                        var o_36 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_36 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_36 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_36 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_36 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.thinFilmThickness_0 = MaterialOperand_0(o_36, slot_1, header_1.constantBase_0).x;
                        }
                        var o_37 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_37 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_37 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_37 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_37 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.thinFilmIor_0 = MaterialOperand_0(o_37, slot_1, header_1.constantBase_0).x;
                        }
                    }
                case u32(8):
                    {
                        var o_38 : u32 = MaterialWord_0(operands_0);
                        if(o_38 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_38 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_38 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_38 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.emissionLuminance_0 = MaterialOperand_0(o_38, slot_1, header_1.constantBase_0).x;
                        }
                        var o_39 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_39 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_39 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_39 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_39 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.emissionColor_0 = MaterialOperand_0(o_39, slot_1, header_1.constantBase_0).xyz;
                        }
                    }
                default :
                    {
                        var o_40 : u32 = MaterialWord_0(operands_0);
                        if(o_40 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_40 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_40 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_40 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.geometryOpacity_0 = MaterialOperand_0(o_40, slot_1, header_1.constantBase_0).x;
                        }
                        var o_41 : u32 = MaterialWord_0(operands_0 + u32(1));
                        if(o_41 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_41 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_41 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_41 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).inputs_0.geometryThinWalled_0 = (MaterialOperand_0(o_41, slot_1, header_1.constantBase_0).x) != 0.0f;
                        }
                        var o_42 : u32 = MaterialWord_0(operands_0 + u32(2));
                        if(o_42 != u32(4294967295))
                        {
                            if(((gMaterialOperandMode_0 & (u32(1)))) == u32(0))
                            {
                                write_0 = true;
                            }
                            else
                            {
                                write_0 = ((o_42 & (u32(2147483648)))) == u32(0);
                            }
                            if(write_0)
                            {
                                if(((gMaterialOperandMode_0 & (u32(4)))) == u32(0))
                                {
                                    slot_1 = stack_0[(o_42 & (u32(15)))];
                                }
                                else
                                {
                                    switch((o_42 & (u32(15))))
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
                                            slot_1 = _S70;
                                        }
                                    }
                                }
                            }
                            else
                            {
                                slot_1 = _S70;
                            }
                            (*outputs_0).normal_1 = MaterialOperand_0(o_42, slot_1, header_1.constantBase_0).xyz;
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
                stack_0[dst_0] = r_1;
            }
            else
            {
                switch(dst_0)
                {
                case u32(0):
                    {
                        stack_0[i32(0)] = r_1;
                    }
                case u32(1):
                    {
                        stack_0[i32(1)] = r_1;
                    }
                case u32(2):
                    {
                        stack_0[i32(2)] = r_1;
                    }
                case u32(3):
                    {
                        stack_0[i32(3)] = r_1;
                    }
                case u32(4):
                    {
                        stack_0[i32(4)] = r_1;
                    }
                case u32(5):
                    {
                        stack_0[i32(5)] = r_1;
                    }
                case u32(6):
                    {
                        stack_0[i32(6)] = r_1;
                    }
                case u32(7):
                    {
                        stack_0[i32(7)] = r_1;
                    }
                case u32(8):
                    {
                        stack_0[i32(8)] = r_1;
                    }
                case u32(9):
                    {
                        stack_0[i32(9)] = r_1;
                    }
                case u32(10):
                    {
                        stack_0[i32(10)] = r_1;
                    }
                case u32(11):
                    {
                        stack_0[i32(11)] = r_1;
                    }
                case u32(12):
                    {
                        stack_0[i32(12)] = r_1;
                    }
                case u32(13):
                    {
                        stack_0[i32(13)] = r_1;
                    }
                case u32(14):
                    {
                        stack_0[i32(14)] = r_1;
                    }
                case u32(15):
                    {
                        stack_0[i32(15)] = r_1;
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

struct PathState_0
{
     radiance_0 : vec3<f32>,
     throughput_0 : vec3<f32>,
     origin_0 : vec3<f32>,
     direction_0 : vec3<f32>,
     scatterPdf_0 : f32,
     lobe_0 : u32,
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
     albedo_0 : vec3<f32>,
     normal_2 : vec3<f32>,
};

fn Field_0( base_0 : u32,  field_0 : u32) -> u32
{
    return base_0 + field_0 * gWavefront_0.capacity_0;
}

fn LoadPath_0( base_1 : u32) -> WavefrontPath_0
{
    var s_1 : WavefrontPath_0;
    s_1.path_0.radiance_0 = gAccum_0[base_1].xyz;
    s_1.active_0 = (bitcast<u32>((gAccum_0[base_1].w)));
    s_1.path_0.throughput_0 = gAccum_0[Field_0(base_1, u32(1))].xyz;
    s_1.randomSeed_0 = (bitcast<u32>((gAccum_0[Field_0(base_1, u32(1))].w)));
    s_1.path_0.origin_0 = gAccum_0[Field_0(base_1, u32(2))].xyz;
    s_1.path_0.scatterPdf_0 = gAccum_0[Field_0(base_1, u32(2))].w;
    s_1.path_0.direction_0 = gAccum_0[Field_0(base_1, u32(3))].xyz;
    s_1.path_0.lightsSampled_0 = (bitcast<u32>((gAccum_0[Field_0(base_1, u32(3))].w))) != u32(0);
    s_1.path_0.absorption_0 = gAccum_0[Field_0(base_1, u32(4))].xyz;
    s_1.path_0.coneWidth_0 = gAccum_0[Field_0(base_1, u32(4))].w;
    s_1.albedo_0 = gAccum_0[Field_0(base_1, u32(5))].xyz;
    s_1.path_0.coneSpread_0 = gAccum_0[Field_0(base_1, u32(5))].w;
    s_1.normal_2 = gAccum_0[Field_0(base_1, u32(6))].xyz;
    s_1.path_0.lobe_0 = u32(0);
    return s_1;
}

fn WorkBase_0( index_6 : u32) -> u32
{
    return gFrame_0.frame_0.x * gFrame_0.frame_0.y * u32(3) + u32(3) + index_6;
}

fn LoadFeedbackState_0( base_2 : u32)
{
    var state_0 : vec4<u32> = (bitcast<vec4<u32>>((gAccum_0[Field_0(base_2, u32(7))])));
    gVTRequest_0 = state_0.x;
    gVTRequestCount_0 = state_0.y;
    gVTRandom_0 = state_0.z;
    return;
}

fn VertexUV0_0( v_3 : ptr<function, Vertex_std430_0>) -> vec2<f32>
{
    return vec2<f32>((*v_3).positionU_0.w, (*v_3).normalV_0.w);
}

fn UVFootprintLog2_0( coneWidth_1 : f32,  worldArea_0 : f32,  uvArea_0 : f32,  cosTheta_0 : f32) -> f32
{
    return log2(max(coneWidth_1, 9.99999968265522539e-21f)) - log2(max(abs(cosTheta_0), 0.0010000000474974513f)) + 0.5f * log2(max(uvArea_0 / max(worldArea_0, 1.00000000317107685e-30f), 1.00000000317107685e-30f));
}

fn MakeTextureCoords_0( uv0_1 : vec2<f32>,  uv1_2 : vec2<f32>,  worldE1_0 : vec3<f32>,  worldE2_0 : vec3<f32>,  uv0E1_0 : vec2<f32>,  uv0E2_0 : vec2<f32>,  uv1E1_0 : vec2<f32>,  uv1E2_0 : vec2<f32>,  coneWidth_2 : f32,  cosTheta_1 : f32) -> TextureCoords_0
{
    var tc_1 : TextureCoords_0;
    tc_1.uv0_0 = uv0_1;
    tc_1.uv1_1 = uv1_2;
    tc_1.objectPosition_0 = vec3<f32>(0.0f);
    var worldArea_1 : f32 = length(cross(worldE1_0, worldE2_0));
    tc_1.footprint0_0 = UVFootprintLog2_0(coneWidth_2, worldArea_1, abs(uv0E1_0.x * uv0E2_0.y - uv0E1_0.y * uv0E2_0.x), cosTheta_1);
    tc_1.footprint1_0 = UVFootprintLog2_0(coneWidth_2, worldArea_1, abs(uv1E1_0.x * uv1E2_0.y - uv1E1_0.y * uv1E2_0.x), cosTheta_1);
    return tc_1;
}

struct SurfaceInteraction_0
{
     position_1 : vec3<f32>,
     faceNormal_0 : vec3<f32>,
     normal_3 : vec3<f32>,
     tangent_5 : vec4<f32>,
     tex_1 : TextureCoords_0,
     materialIndex_1 : u32,
     instanceIndex_1 : u32,
     primitiveIndex_0 : u32,
     frontFacing_0 : bool,
};

struct HitRecord_0
{
     t_4 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_2 : u32,
     primitiveIndex_1 : u32,
};

fn LoadTriangleIndices_0( _S81 : u32,  _S82 : u32) -> vec3<u32>
{
    var base_3 : u32 = gInstances_0[_S81].indexOffset_0 + _S82 * u32(3);
    return vec3<u32>(gIndices_0[base_3], gIndices_0[base_3 + u32(1)], gIndices_0[base_3 + u32(2)]) + vec3<u32>(gInstances_0[_S81].vertexOffset_0);
}

fn TransformPoint_0( _S83 : u32,  _S84 : vec3<f32>) -> vec3<f32>
{
    return vec3<f32>(dot(gInstances_0[_S83].objectToWorld_0[i32(0)].xyz, _S84) + gInstances_0[_S83].objectToWorld_0[i32(0)].w, dot(gInstances_0[_S83].objectToWorld_0[i32(1)].xyz, _S84) + gInstances_0[_S83].objectToWorld_0[i32(1)].w, dot(gInstances_0[_S83].objectToWorld_0[i32(2)].xyz, _S84) + gInstances_0[_S83].objectToWorld_0[i32(2)].w);
}

fn TransformNormal_0( _S85 : u32,  _S86 : vec3<f32>) -> vec3<f32>
{
    return gInstances_0[_S85].worldToObject_0[i32(0)].xyz * vec3<f32>(_S86.x) + gInstances_0[_S85].worldToObject_0[i32(1)].xyz * vec3<f32>(_S86.y) + gInstances_0[_S85].worldToObject_0[i32(2)].xyz * vec3<f32>(_S86.z);
}

fn GetSurfaceInteraction_0( rayDirection_0 : vec3<f32>,  hit_0 : HitRecord_0,  coneWidth_3 : f32) -> SurfaceInteraction_0
{
    var _S87 : vec3<u32> = LoadTriangleIndices_0(hit_0.instanceIndex_2, hit_0.primitiveIndex_1);
    var _S88 : Vertex_std430_0 = gVertices_0[_S87.x];
    var _S89 : Vertex_std430_0 = gVertices_0[_S87.y];
    var _S90 : Vertex_std430_0 = gVertices_0[_S87.z];
    var _S91 : f32 = hit_0.barycentrics_0.x;
    var _S92 : f32 = hit_0.barycentrics_0.y;
    var _S93 : f32 = 1.0f - _S91 - _S92;
    var p0_0 : vec3<f32> = _S88.positionU_0.xyz;
    var p1_0 : vec3<f32> = _S89.positionU_0.xyz;
    var p2_0 : vec3<f32> = _S90.positionU_0.xyz;
    var si_0 : SurfaceInteraction_0;
    si_0.instanceIndex_1 = hit_0.instanceIndex_2;
    si_0.primitiveIndex_0 = hit_0.primitiveIndex_1;
    si_0.materialIndex_1 = gInstances_0[hit_0.instanceIndex_2].materialIndex_0;
    var _S94 : vec3<f32> = vec3<f32>(_S93);
    var _S95 : vec3<f32> = vec3<f32>(_S91);
    var _S96 : vec3<f32> = vec3<f32>(_S92);
    var _S97 : vec3<f32> = p0_0 * _S94 + p1_0 * _S95 + p2_0 * _S96;
    si_0.position_1 = TransformPoint_0(hit_0.instanceIndex_2, _S97);
    var _S98 : vec3<f32> = p1_0 - p0_0;
    var _S99 : vec3<f32> = p2_0 - p0_0;
    si_0.faceNormal_0 = normalize(TransformNormal_0(hit_0.instanceIndex_2, cross(normalize(_S98), normalize(_S99))));
    var n_6 : vec3<f32> = _S88.normalV_0.xyz * _S94 + _S89.normalV_0.xyz * _S95 + _S90.normalV_0.xyz * _S96;
    var t_5 : vec3<f32>;
    if(((dot(n_6, n_6)) > 0.0f))
    {
        t_5 = normalize(TransformNormal_0(hit_0.instanceIndex_2, n_6));
    }
    else
    {
        t_5 = si_0.faceNormal_0;
    }
    si_0.normal_3 = t_5;
    var _S100 : vec2<f32> = VertexUV0_0(&(_S88));
    var _S101 : vec2<f32> = VertexUV0_0(&(_S89));
    var _S102 : vec2<f32> = VertexUV0_0(&(_S90));
    var _S103 : vec2<f32> = vec2<f32>(_S93);
    var _S104 : vec2<f32> = vec2<f32>(_S91);
    var _S105 : vec2<f32> = vec2<f32>(_S92);
    var _S106 : vec2<f32> = _S88.uv1_0.xy;
    var _S107 : vec2<f32> = _S89.uv1_0.xy;
    var _S108 : vec2<f32> = _S90.uv1_0.xy;
    si_0.tex_1 = MakeTextureCoords_0(_S100 * _S103 + _S101 * _S104 + _S102 * _S105, _S106 * _S103 + _S107 * _S104 + _S108 * _S105, TransformVector_0(hit_0.instanceIndex_2, _S98), TransformVector_0(hit_0.instanceIndex_2, _S99), _S101 - _S100, _S102 - _S100, _S107 - _S106, _S108 - _S106, coneWidth_3, dot(si_0.faceNormal_0, rayDirection_0));
    si_0.tex_1.objectPosition_0 = _S97;
    si_0.frontFacing_0 = ((dot(si_0.faceNormal_0, (vec3<f32>(0) - rayDirection_0))) > 0.0f);
    var _S109 : vec4<f32> = _S88.tangent_0;
    var t_6 : vec3<f32> = _S88.tangent_0.xyz * _S94 + _S89.tangent_0.xyz * _S95 + _S90.tangent_0.xyz * _S96;
    if(((dot(t_6, t_6)) > 0.0f))
    {
        t_5 = normalize(TransformVector_0(hit_0.instanceIndex_2, t_6));
    }
    else
    {
        t_5 = vec3<f32>(0.0f);
    }
    si_0.tangent_5 = vec4<f32>(t_5, _S109.w);
    return si_0;
}

fn LoadMaterialHeader_0( materialIndex_2 : u32) -> MaterialHeader_0
{
    var _S110 : u32 = materialIndex_2 * u32(2);
    var h0_0 : vec4<u32> = gMaterialData_0[_S110];
    var h1_0 : vec4<u32> = gMaterialData_0[_S110 + u32(1)];
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

fn BSDFInputs_Default_0() -> BSDFInputs_0
{
    var i_3 : BSDFInputs_0;
    i_3.baseWeight_0 = 1.0f;
    var _S111 : vec3<f32> = vec3<f32>(0.80000001192092896f);
    i_3.baseColor_0 = _S111;
    i_3.baseDiffuseRoughness_0 = 0.0f;
    i_3.baseMetalness_0 = 0.0f;
    i_3.subsurfaceWeight_0 = 0.0f;
    i_3.subsurfaceColor_0 = _S111;
    i_3.subsurfaceRadius_0 = 1.0f;
    i_3.subsurfaceRadiusScale_0 = vec3<f32>(1.0f, 0.5f, 0.25f);
    i_3.subsurfaceScatterAnisotropy_0 = 0.0f;
    i_3.specularWeight_0 = 1.0f;
    i_3.specularDielectricOnly_0 = false;
    var _S112 : vec3<f32> = vec3<f32>(1.0f);
    i_3.specularColor_0 = _S112;
    i_3.specularRoughness_0 = 0.30000001192092896f;
    i_3.specularRoughnessAnisotropy_0 = 0.0f;
    i_3.specularIor_0 = 1.5f;
    const _S113 : vec2<f32> = vec2<f32>(1.0f, 0.0f);
    i_3.specularAnisotropyRotation_0 = _S113;
    i_3.coatWeight_0 = 0.0f;
    i_3.coatColor_0 = _S112;
    i_3.coatRoughness_0 = 0.0f;
    i_3.coatRoughnessAnisotropy_0 = 0.0f;
    i_3.coatIor_0 = 1.6000000238418579f;
    i_3.coatDarkening_0 = 1.0f;
    i_3.coatAnisotropyRotation_0 = _S113;
    i_3.fuzzWeight_0 = 0.0f;
    i_3.fuzzColor_0 = _S112;
    i_3.fuzzRoughness_0 = 0.5f;
    i_3.transmissionWeight_0 = 0.0f;
    i_3.transmissionColor_0 = _S112;
    i_3.transmissionDepth_0 = 0.0f;
    i_3.transmissionScatter_0 = vec3<f32>(0.0f);
    i_3.transmissionScatterAnisotropy_0 = 0.0f;
    i_3.transmissionDispersionScale_0 = 0.0f;
    i_3.transmissionDispersionAbbeNumber_0 = 20.0f;
    i_3.thinFilmWeight_0 = 0.0f;
    i_3.thinFilmThickness_0 = 0.5f;
    i_3.thinFilmIor_0 = 1.3999999761581421f;
    i_3.emissionLuminance_0 = 0.0f;
    i_3.emissionColor_0 = _S112;
    i_3.geometryOpacity_0 = 1.0f;
    i_3.geometryThinWalled_0 = false;
    i_3.basis_0.t_0 = vec3<f32>(1.0f, 0.0f, 0.0f);
    i_3.basis_0.b_0 = vec3<f32>(0.0f, 1.0f, 0.0f);
    i_3.basis_0.n_0 = vec3<f32>(0.0f, 0.0f, 1.0f);
    i_3.coatBasis_0 = i_3.basis_0;
    return i_3;
}

fn MaterialOutputs_Default_0( ctx_1 : MaterialContext_0) -> MaterialOutputs_0
{
    var o_43 : MaterialOutputs_0;
    o_43.inputs_0 = BSDFInputs_Default_0();
    o_43.normal_1 = ctx_1.normal_0;
    o_43.coatNormal_0 = ctx_1.normal_0;
    var _S114 : vec3<f32> = ctx_1.tangent_1.xyz;
    o_43.tangent_2 = _S114;
    o_43.coatTangent_0 = _S114;
    return o_43;
}

fn MaterialHeader_DoubleSided_0( this_0 : MaterialHeader_0) -> bool
{
    return (((this_0.flags_1) & (u32(1)))) != u32(0);
}

fn AlignWithFace_0( n_7 : vec3<f32>,  V_0 : vec3<f32>,  frontFacing_1 : bool) -> vec3<f32>
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
    var cosV_0 : f32 = dot(V_0, n_7) * side_0;
    if((cosV_0 >= 9.9999997473787516e-05f))
    {
        return n_7;
    }
    return normalize(n_7 + V_0 * vec3<f32>((side_0 * (9.9999997473787516e-05f - cosV_0))));
}

fn BranchlessONB_0( n_8 : vec3<f32>,  b1_0 : ptr<function, vec3<f32>>,  b2_0 : ptr<function, vec3<f32>>)
{
    var _S115 : f32 = n_8.z;
    var s_2 : f32;
    if((_S115 >= 0.0f))
    {
        s_2 = 1.0f;
    }
    else
    {
        s_2 = -1.0f;
    }
    var a_4 : f32 = -1.0f / (s_2 + _S115);
    var _S116 : f32 = n_8.x;
    var _S117 : f32 = n_8.y;
    var b_4 : f32 = _S116 * _S117 * a_4;
    (*b1_0) = vec3<f32>(1.0f + s_2 * _S116 * _S116 * a_4, s_2 * b_4, - s_2 * _S116);
    (*b2_0) = vec3<f32>(b_4, s_2 + _S117 * _S117 * a_4, - _S117);
    return;
}

fn Frame_FromNormal_0( n_9 : vec3<f32>) -> Frame_0
{
    var f_1 : Frame_0;
    f_1.n_0 = n_9;
    var _S118 : vec3<f32> = f_1.t_0;
    var _S119 : vec3<f32> = f_1.b_0;
    BranchlessONB_0(n_9, &(_S118), &(_S119));
    f_1.t_0 = _S118;
    f_1.b_0 = _S119;
    return f_1;
}

fn Frame_FromTangent_0( tangent_6 : vec4<f32>,  n_10 : vec3<f32>) -> Frame_0
{
    var _S120 : vec3<f32> = tangent_6.xyz;
    var NdotT_0 : f32 = dot(_S120, n_10);
    var _S121 : f32 = tangent_6.w;
    var valid_0 : bool;
    if(_S121 != 0.0f)
    {
        valid_0 = ((dot(_S120, _S120)) > 0.0f);
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
        return Frame_FromNormal_0(n_10);
    }
    var f_2 : Frame_0;
    f_2.n_0 = n_10;
    var _S122 : vec3<f32> = normalize(_S120 - n_10 * vec3<f32>(NdotT_0));
    f_2.t_0 = _S122;
    f_2.b_0 = cross(n_10, _S122) * vec3<f32>(_S121);
    return f_2;
}

struct MaterialSample_0
{
     inputs_1 : BSDFInputs_0,
     albedo_1 : vec3<f32>,
     roughness_1 : f32,
     doubleSided_0 : bool,
     thinWalled_0 : bool,
};

fn EvalMaterial_0( si_1 : SurfaceInteraction_0,  V_1 : vec3<f32>) -> MaterialSample_0
{
    var header_2 : MaterialHeader_0 = LoadMaterialHeader_0(si_1.materialIndex_1);
    var ctx_2 : MaterialContext_0;
    ctx_2.tex_0 = si_1.tex_1;
    ctx_2.position_0 = si_1.position_1;
    ctx_2.normal_0 = si_1.normal_3;
    ctx_2.tangent_1 = si_1.tangent_5;
    ctx_2.instanceIndex_0 = si_1.instanceIndex_1;
    var o_44 : MaterialOutputs_0 = MaterialOutputs_Default_0(ctx_2);
    if((header_2.surface_0) != u32(4294967295))
    {
        RunMaterialProgram_0(header_2, header_2.surface_0, ctx_2, &(o_44));
    }
    var ms_0 : MaterialSample_0;
    ms_0.inputs_1 = o_44.inputs_0;
    ms_0.albedo_1 = o_44.inputs_0.baseColor_0;
    ms_0.roughness_1 = o_44.inputs_0.specularRoughness_0;
    ms_0.doubleSided_0 = MaterialHeader_DoubleSided_0(header_2);
    ms_0.thinWalled_0 = o_44.inputs_0.geometryThinWalled_0;
    var _S123 : f32 = si_1.tangent_5.w;
    var handedness_0 : f32;
    if(_S123 != 0.0f)
    {
        handedness_0 = _S123;
    }
    else
    {
        handedness_0 = 1.0f;
    }
    ms_0.inputs_1.basis_0 = Frame_FromTangent_0(vec4<f32>(o_44.tangent_2, handedness_0), AlignWithFace_0(o_44.normal_1, V_1, si_1.frontFacing_0));
    var _S124 : bool;
    if((all(((o_44.coatNormal_0) == (o_44.normal_1)))))
    {
        _S124 = (all(((o_44.coatTangent_0) == (o_44.tangent_2))));
    }
    else
    {
        _S124 = false;
    }
    if(_S124)
    {
        ms_0.inputs_1.coatBasis_0 = ms_0.inputs_1.basis_0;
    }
    else
    {
        ms_0.inputs_1.coatBasis_0 = Frame_FromTangent_0(vec4<f32>(o_44.coatTangent_0, handedness_0), AlignWithFace_0(o_44.coatNormal_0, V_1, si_1.frontFacing_0));
    }
    return ms_0;
}

@compute
@workgroup_size(64, 1, 1)
fn InspectPrimarySurface(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gVTLastMappedLevel_0 = u32(0);
    gVTLastRequestedLevel_0 = u32(0);
    var _S125 : u32 = tid_0.x;
    if((_S125 >= (gWavefront_0.pathCount_0)))
    {
        return;
    }
    var base_4 : u32 = WorkBase_0(_S125);
    var s_3 : WavefrontPath_0 = LoadPath_0(base_4);
    var field_1 : u32 = u32(10);
    loop
    {
        if((field_1 <= u32(13)))
        {
        }
        else
        {
            break;
        }
        gAccum_0[Field_0(base_4, field_1)] = vec4<f32>(0.0f);
        field_1 = field_1 + u32(1);
    }
    if((s_3.active_0) == u32(0))
    {
        return;
    }
    var hit_1 : HitRecord_0;
    var _S126 : f32 = gAccum_0[Field_0(base_4, u32(8))].x;
    hit_1.t_4 = _S126;
    hit_1.barycentrics_0 = gAccum_0[Field_0(base_4, u32(8))].yz;
    hit_1.instanceIndex_2 = (bitcast<u32>((gAccum_0[Field_0(base_4, u32(8))].w)));
    hit_1.primitiveIndex_1 = (bitcast<u32>((gAccum_0[Field_0(base_4, u32(9))].x)));
    LoadFeedbackState_0(base_4);
    var si_2 : SurfaceInteraction_0 = GetSurfaceInteraction_0(s_3.path_0.direction_0, hit_1, s_3.path_0.coneWidth_0 + _S126 * s_3.path_0.coneSpread_0);
    var ms_1 : MaterialSample_0 = EvalMaterial_0(si_2, (vec3<f32>(0) - s_3.path_0.direction_0));
    gAccum_0[Field_0(base_4, u32(10))] = vec4<f32>(si_2.tex_1.uv0_0, si_2.tex_1.uv1_1);
    gAccum_0[Field_0(base_4, u32(11))] = vec4<f32>(si_2.normal_3, f32(si_2.materialIndex_1));
    gAccum_0[Field_0(base_4, u32(12))] = vec4<f32>(ms_1.albedo_1, ms_1.roughness_1);
    gAccum_0[Field_0(base_4, u32(13))] = vec4<f32>(ms_1.inputs_1.basis_0.n_0, 0.0f);
    return;
}

