// Generated from shaders/Passes/PathTracing.slang by scripts/build-shaders.mjs. Do not edit.
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

@binding(1) @group(1) var gVTFeedback_0 : texture_storage_2d<r32uint, write>;

@binding(0) @group(1) var<storage, read_write> gAccum_0 : array<vec4<f32>>;

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

fn isfinite_1( x_3 : vec3<f32>) -> vec3<bool>
{
    var result_0 : vec3<bool>;
    var i_0 : i32 = i32(0);
    loop
    {
        if((i_0 < i32(3)))
        {
        }
        else
        {
            break;
        }
        result_0[i_0] = isfinite_0(x_3[i_0]);
        i_0 = i_0 + i32(1);
    }
    return result_0;
}

fn rsqrt_0( x_4 : f32) -> f32
{
    return 1.0f / sqrt(x_4);
}

fn StrongIntegerHash_0( x_5 : u32) -> u32
{
    var _S8 : u32 = ((x_5 ^ (((x_5 >> (u32(16))))))) * u32(2819806515);
    var _S9 : u32 = ((_S8 ^ (((_S8 >> (u32(15))))))) * u32(2994267309);
    return (_S9 ^ (((_S9 >> (u32(17))))));
}

struct RandomSequence_0
{
     seed_0 : u32,
};

fn RandomSequence_x24init_0( pixel_0 : vec2<u32>,  timeSeed_0 : u32) -> RandomSequence_0
{
    var _S10 : RandomSequence_0;
    _S10.seed_0 = StrongIntegerHash_0(pixel_0.x + pixel_0.y * u32(65536) + StrongIntegerHash_0(timeSeed_0));
    return _S10;
}

var<private> gVTRequest_0 : u32;

var<private> gVTRequestCount_0 : u32;

var<private> gVTRandom_0 : u32;

fn InitVirtualTextureFeedback_0( pixel_1 : vec2<u32>)
{
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = StrongIntegerHash_0(((pixel_1.x) ^ ((StrongIntegerHash_0(((pixel_1.y) ^ ((StrongIntegerHash_0(gFrame_0.frame_0.w)))))))));
    return;
}

fn RandomSequence_Next_0( this_0 : ptr<function, RandomSequence_0>) -> f32
{
    var _S11 : u32 = (*this_0).seed_0 + u32(1);
    (*this_0).seed_0 = _S11;
    return f32(((StrongIntegerHash_0(_S11)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next_1( this_1 : ptr<function, RandomSequence_0>) -> f32
{
    var _S12 : u32 = (*this_1).seed_0 + u32(1);
    (*this_1).seed_0 = _S12;
    return f32(((StrongIntegerHash_0(_S12)) & (u32(16777215)))) * 5.9604644775390625e-08f;
}

fn RandomSequence_Next2D_0( this_2 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_6 : f32 = RandomSequence_Next_0(&((*this_2)));
    var y_0 : f32 = RandomSequence_Next_0(&((*this_2)));
    return vec2<f32>(x_6, y_0);
}

fn RandomSequence_Next2D_1( this_3 : ptr<function, RandomSequence_0>) -> vec2<f32>
{
    var x_7 : f32 = RandomSequence_Next_1(&((*this_3)));
    var y_1 : f32 = RandomSequence_Next_1(&((*this_3)));
    return vec2<f32>(x_7, y_1);
}

fn RandomSequence_x24init_1( positionSeed_0 : u32,  timeSeed_1 : u32) -> RandomSequence_0
{
    var _S13 : RandomSequence_0;
    _S13.seed_0 = StrongIntegerHash_0(positionSeed_0 + StrongIntegerHash_0(timeSeed_1));
    return _S13;
}

fn PrimaryCameraJitter_0() -> vec2<f32>
{
    var rng_0 : RandomSequence_0 = RandomSequence_x24init_1(u32(1447646018), gFrame_0.frame_0.w);
    var _S14 : vec2<f32> = RandomSequence_Next2D_0(&(rng_0));
    return _S14;
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn SampleDisk_0( u_0 : vec2<f32>) -> vec2<f32>
{
    var angle_0 : f32 = 2.0f * float_getPi_0() * u_0.x;
    return vec2<f32>(cos(angle_0), sin(angle_0)) * vec2<f32>(sqrt(u_0.y));
}

struct Ray_0
{
     origin_0 : vec3<f32>,
     tMin_0 : f32,
     direction_0 : vec3<f32>,
     tMax_0 : f32,
};

fn Ray_x24init_0( o_0 : vec3<f32>,  d_0 : vec3<f32>,  tmax_0 : f32) -> Ray_0
{
    var _S15 : Ray_0;
    _S15.origin_0 = o_0;
    _S15.direction_0 = d_0;
    _S15.tMin_0 = 0.0f;
    _S15.tMax_0 = tmax_0;
    return _S15;
}

fn GenerateCameraRay_0( pixel_2 : vec2<u32>,  rng_1 : ptr<function, RandomSequence_0>) -> Ray_0
{
    var _S16 : vec2<f32> = vec2<f32>(gFrame_0.frame_0.xy);
    var _S17 : vec2<f32> = RandomSequence_Next2D_1(&((*rng_1)));
    var jitter_0 : vec2<f32>;
    if((((gFrame_0.settings_0.z) & (u32(16)))) != u32(0))
    {
        jitter_0 = PrimaryCameraJitter_0();
    }
    else
    {
        jitter_0 = _S17;
    }
    var film_0 : vec2<f32> = (vec2<f32>(pixel_2) + jitter_0) / _S16;
    var forward_0 : vec3<f32> = gFrame_0.cameraForward_0.xyz;
    var dir_0 : vec3<f32> = normalize(forward_0 + gFrame_0.cameraRight_0.xyz * vec3<f32>((film_0.x * 2.0f - 1.0f)) + gFrame_0.cameraUp_0.xyz * vec3<f32>((1.0f - film_0.y * 2.0f)));
    var origin_1 : vec3<f32> = gFrame_0.cameraPosition_0.xyz;
    var lensRadius_0 : f32 = gFrame_0.cameraPosition_0.w;
    var dir_1 : vec3<f32>;
    var origin_2 : vec3<f32>;
    if((lensRadius_0 > 0.0f))
    {
        var focusPoint_0 : vec3<f32> = origin_1 + dir_0 * vec3<f32>((gFrame_0.cameraRight_0.w / dot(dir_0, forward_0)));
        var _S18 : vec2<f32> = RandomSequence_Next2D_1(&((*rng_1)));
        var lens_0 : vec2<f32> = SampleDisk_0(_S18) * vec2<f32>(lensRadius_0);
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

fn _S19() -> vec2<f32>
{
    return vec2<f32>(0.0f);
}

var<private> gRayCone_0 : vec2<f32>;

var<private> gTraversalCost_0 : u32;

fn HeatMap_0( t_0 : f32) -> vec3<f32>
{
    var _S20 : f32 = 4.0f * saturate(t_0);
    return saturate(vec3<f32>(1.5f - abs(_S20 - 3.0f), 1.5f - abs(_S20 - 2.0f), 1.5f - abs(_S20 - 1.0f)));
}

fn AnalyticLightCount_0() -> u32
{
    return gFrame_0.counts_0.w;
}

struct HitRecord_0
{
     t_1 : f32,
     barycentrics_0 : vec2<f32>,
     instanceIndex_0 : u32,
     primitiveIndex_0 : u32,
};

fn HitRecord_IsHit_0( this_4 : HitRecord_0) -> bool
{
    return (this_4.instanceIndex_0) != u32(4294967295);
}

fn AnalyticFlags_0( light_0 : ptr<function, EmissiveTriangle_std430_0>) -> u32
{
    return (bitcast<u32>(((*light_0).n_0.w)));
}

fn SpotAttenuation_0( light_1 : ptr<function, EmissiveTriangle_std430_0>,  dir_2 : vec3<f32>) -> f32
{
    var _S21 : u32 = AnalyticFlags_0(&((*light_1)));
    if(((_S21 & (u32(255)))) != u32(1))
    {
        return 1.0f;
    }
    var x_8 : f32 = dot(dir_2, (*light_1).p2_0.xyz) - (*light_1).uvA_0.w;
    var scale_0 : f32 = (*light_1).uvB_0.x;
    var _S22 : f32;
    if((scale_0 > 0.0f))
    {
        _S22 = smoothstep(0.0f, 1.0f, x_8 * scale_0);
    }
    else
    {
        if((x_8 > 0.0f))
        {
            _S22 = 1.0f;
        }
        else
        {
            _S22 = 0.0f;
        }
    }
    return _S22;
}

fn SphereOneMinusCos_0( radius_0 : f32,  distSq_0 : f32) -> f32
{
    var sinSq_0 : f32 = radius_0 * radius_0 / distSq_0;
    var _S23 : f32;
    if((sinSq_0 < 1.0f))
    {
        _S23 = sinSq_0 / (1.0f + sqrt(1.0f - sinSq_0));
    }
    else
    {
        _S23 = 0.0f;
    }
    return _S23;
}

fn IntersectAnalyticLights_0( origin_4 : vec3<f32>,  dir_3 : vec3<f32>,  tMax_1 : f32,  cameraRay_0 : bool,  radiance_0 : ptr<function, vec3<f32>>,  pdf_0 : ptr<function, f32>) -> bool
{
    (*radiance_0) = vec3<f32>(0.0f);
    (*pdf_0) = 0.0f;
    var nearest_0 : f32 = tMax_1;
    var found_0 : bool = false;
    var i_1 : u32 = u32(0);
    loop
    {
        if((i_1 < (AnalyticLightCount_0())))
        {
        }
        else
        {
            break;
        }
        var _S24 : EmissiveTriangle_std430_0 = gLights_0[i_1];
        var _S25 : u32 = AnalyticFlags_0(&(_S24));
        var _S26 : bool;
        if(cameraRay_0)
        {
            _S26 = ((_S25 & (u32(256)))) != u32(0);
        }
        else
        {
            _S26 = false;
        }
        if(_S26)
        {
            i_1 = i_1 + u32(1);
            continue;
        }
        var nearest_1 : f32;
        var _S27 : bool;
        var inside_0 : bool;
        if(((_S25 & (u32(255)))) == u32(2))
        {
            var n_1 : vec3<f32> = _S24.p2_0.xyz;
            var cosTheta_0 : f32 = - dot(n_1, dir_3);
            if((cosTheta_0 <= 9.99999997475242708e-07f))
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            var _S28 : vec4<f32> = _S24.p0_0;
            var _S29 : vec3<f32> = _S24.p0_0.xyz;
            var t_2 : f32 = dot(_S29 - origin_4, n_1) / - cosTheta_0;
            if((t_2 <= 0.0f))
            {
                _S27 = true;
            }
            else
            {
                _S27 = (t_2 >= nearest_0);
            }
            if(_S27)
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            var local_0 : vec3<f32> = origin_4 + dir_3 * vec3<f32>(t_2) - _S29;
            var _S30 : vec3<f32> = _S24.n_0.xyz;
            var _S31 : vec3<f32> = _S24.uvA_0.xyz;
            var d_1 : vec2<f32> = vec2<f32>(dot(local_0, _S30) / dot(_S30, _S30), dot(local_0, _S31) / dot(_S31, _S31));
            if(((_S25 & (u32(512)))) != u32(0))
            {
                inside_0 = ((dot(d_1, d_1)) <= 0.25f);
            }
            else
            {
                inside_0 = (all((((abs(d_1)) <= vec2<f32>(0.5f)))));
            }
            if(!inside_0)
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            (*radiance_0) = _S24.p1_0.xyz;
            (*pdf_0) = _S24.p1_0.w * t_2 * t_2 / (cosTheta_0 * _S28.w);
            nearest_1 = t_2;
        }
        else
        {
            var _S32 : vec4<f32> = _S24.p0_0;
            var radius_1 : f32 = _S24.p0_0.w;
            if((radius_1 <= 0.0f))
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            var toCenter_0 : vec3<f32> = _S32.xyz - origin_4;
            var distSq_1 : f32 = dot(toCenter_0, toCenter_0);
            var tc_0 : f32 = dot(toCenter_0, dir_3);
            var _S33 : f32 = radius_1 * radius_1;
            var h_0 : f32 = _S33 - (distSq_1 - tc_0 * tc_0);
            if((h_0 < 0.0f))
            {
                _S27 = true;
            }
            else
            {
                _S27 = (distSq_1 <= _S33);
            }
            if(_S27)
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            var t_3 : f32 = tc_0 - sqrt(h_0);
            if((t_3 <= 0.0f))
            {
                inside_0 = true;
            }
            else
            {
                inside_0 = (t_3 >= nearest_0);
            }
            if(inside_0)
            {
                i_1 = i_1 + u32(1);
                continue;
            }
            var _S34 : vec4<f32> = _S24.p1_0;
            var _S35 : vec3<f32> = _S24.p1_0.xyz;
            var _S36 : f32 = SpotAttenuation_0(&(_S24), (vec3<f32>(0) - toCenter_0) * vec3<f32>(rsqrt_0(distSq_1)));
            (*radiance_0) = _S35 * vec3<f32>(_S36);
            (*pdf_0) = _S34.w / (2.0f * float_getPi_0() * SphereOneMinusCos_0(radius_1, distSq_1));
            nearest_1 = t_3;
        }
        nearest_0 = nearest_1;
        found_0 = true;
        i_1 = i_1 + u32(1);
    }
    return found_0;
}

fn EnvironmentEnabled_0() -> bool
{
    return (((gFrame_0.settings_0.z) & (u32(1)))) != u32(0);
}

fn RotateY_0( v_0 : vec3<f32>,  angle_1 : f32) -> vec3<f32>
{
    var s_0 : f32 = sin(angle_1);
    var c_0 : f32 = cos(angle_1);
    var _S37 : f32 = v_0.x;
    var _S38 : f32 = v_0.z;
    return vec3<f32>(c_0 * _S37 + s_0 * _S38, v_0.y, - s_0 * _S37 + c_0 * _S38);
}

fn DirectionToEquirectUV_0( dir_4 : vec3<f32>) -> vec2<f32>
{
    var _S39 : f32 = dir_4.y;
    var elevation_0 : f32 = asin(clamp(_S39, -1.0f, 1.0f));
    var azimuth_0 : f32;
    if(((abs(_S39)) < 1.0f))
    {
        azimuth_0 = atan2(dir_4.z, dir_4.x);
    }
    else
    {
        azimuth_0 = 0.0f;
    }
    var PI_0 : f32 = float_getPi_0();
    return vec2<f32>(azimuth_0 * (0.5f / PI_0) - 0.25f, 0.5f - elevation_0 * (1.0f / PI_0));
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
    var _S40 : bool;
    if(SunEnabled_0())
    {
        _S40 = ((dot(dir_6, gFrame_0.sunDirection_0.xyz)) >= (gFrame_0.sunDirection_0.w));
    }
    else
    {
        _S40 = false;
    }
    return _S40;
}

fn IsFeedbackPixel_0( pixel_3 : vec2<u32>) -> bool
{
    var _S41 : vec2<u32> = vec2<u32>(gFrame_0.vtInfo_0.w);
    return (all((pixel_3 == (min(((((pixel_3 >> (_S41))) << (_S41))) + vec2<u32>(((gFrame_0.vtInfo_0.z) & (u32(65535))), ((gFrame_0.vtInfo_0.z) >> (u32(16)))), gFrame_0.frame_0.xy - vec2<u32>(u32(1)))))));
}

struct PathState_0
{
     radiance_1 : vec3<f32>,
     throughput_0 : vec3<f32>,
     origin_5 : vec3<f32>,
     direction_1 : vec3<f32>,
     scatterPdf_0 : f32,
     lobe_0 : u32,
     coneWidth_0 : f32,
     coneSpread_0 : f32,
     absorption_0 : vec3<f32>,
     lightsSampled_0 : bool,
};

@compute
@workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var debugOut_0 : vec3<f32>;
    gVTRequest_0 = u32(0);
    gVTRequestCount_0 = u32(0);
    gVTRandom_0 = u32(0);
    gRayCone_0 = _S19();
    gTraversalCost_0 = u32(0);
    var pixel_4 : vec2<u32> = tid_0.xy;
    var _S42 : u32 = pixel_4.x;
    var _S43 : bool;
    if((_S42 >= (gFrame_0.frame_0.x)))
    {
        _S43 = true;
    }
    else
    {
        _S43 = ((pixel_4.y) >= (gFrame_0.frame_0.y));
    }
    if(_S43)
    {
        return;
    }
    var frameIndex_0 : u32 = gFrame_0.frame_0.z;
    var _S44 : u32 = gFrame_0.settings_0.x;
    var debugMode_0 : u32 = gFrame_0.settings_0.y;
    var rng_2 : RandomSequence_0 = RandomSequence_x24init_0(pixel_4, gFrame_0.frame_0.w);
    InitVirtualTextureFeedback_0(pixel_4);
    var cameraRay_1 : Ray_0 = GenerateCameraRay_0(pixel_4, &(rng_2));
    var path_0 : PathState_0;
    var _S45 : vec3<f32> = vec3<f32>(0.0f);
    path_0.radiance_1 = _S45;
    path_0.throughput_0 = vec3<f32>(1.0f);
    path_0.origin_5 = cameraRay_1.origin_0;
    path_0.direction_1 = cameraRay_1.direction_0;
    path_0.scatterPdf_0 = 1.0f;
    path_0.lobe_0 = u32(0);
    path_0.coneWidth_0 = 0.0f;
    path_0.coneSpread_0 = gFrame_0.vtParams_0.y;
    path_0.absorption_0 = _S45;
    path_0.lightsSampled_0 = false;
    var preExposure_0 : f32 = gFrame_0.envParams_0.z;
    loop
    {
        if((u32(0) <= _S44))
        {
        }
        else
        {
            debugOut_0 = _S45;
            break;
        }
        var ray_0 : Ray_0 = Ray_x24init_0(path_0.origin_5, path_0.direction_1, 1.00000001504746622e+30f);
        gRayCone_0 = vec2<f32>(path_0.coneWidth_0, path_0.coneSpread_0);
        var hit_0 : HitRecord_0;
        hit_0.t_1 = ray_0.tMax_0;
        hit_0.barycentrics_0 = vec2<f32>(0.0f);
        hit_0.instanceIndex_0 = u32(4294967295);
        hit_0.primitiveIndex_0 = u32(4294967295);
        if(debugMode_0 == u32(7))
        {
            debugOut_0 = HeatMap_0(f32(gTraversalCost_0) / 256.0f);
            break;
        }
        if(((AnalyticLightCount_0()) > u32(0)))
        {
            var lightRadiance_0 : vec3<f32>;
            var lightPdf_0 : f32;
            var _S46 : f32;
            if(HitRecord_IsHit_0(hit_0))
            {
                _S46 = hit_0.t_1;
            }
            else
            {
                _S46 = 1.00000001504746622e+30f;
            }
            var _S47 : bool = IntersectAnalyticLights_0(ray_0.origin_0, ray_0.direction_0, _S46, true, &(lightRadiance_0), &(lightPdf_0));
            if(_S47)
            {
                path_0.radiance_1 = path_0.radiance_1 + path_0.throughput_0 * lightRadiance_0;
            }
        }
        var visible_0 : bool = (((gFrame_0.settings_0.z) & (u32(8)))) != u32(0);
        if(visible_0)
        {
            debugOut_0 = EvalEnvironment_0(ray_0.direction_0);
        }
        else
        {
            debugOut_0 = gFrame_0.background_0.xyz;
        }
        path_0.radiance_1 = path_0.radiance_1 + debugOut_0;
        if(visible_0)
        {
            _S43 = HitsSun_0(ray_0.direction_0);
        }
        else
        {
            _S43 = false;
        }
        if(_S43)
        {
            path_0.radiance_1 = path_0.radiance_1 + gFrame_0.sunRadiance_0.xyz;
        }
        debugOut_0 = _S45;
        break;
    }
    if(IsFeedbackPixel_0(pixel_4))
    {
        textureStore((gVTFeedback_0), ((pixel_4 >> (vec2<u32>(gFrame_0.vtInfo_0.w)))), vec4<u32>((gVTRequest_0), 0, 0, 1));
    }
    var radiance_2 : vec3<f32>;
    if(debugMode_0 != u32(0))
    {
        radiance_2 = debugOut_0;
    }
    else
    {
        radiance_2 = path_0.radiance_1 * vec3<f32>(preExposure_0);
    }
    if(!(all((isfinite_1(radiance_2)))))
    {
        radiance_2 = _S45;
    }
    var base_0 : u32 = (pixel_4.y * gFrame_0.frame_0.x + _S42) * u32(3);
    if(frameIndex_0 == u32(0))
    {
        gAccum_0[base_0] = vec4<f32>(radiance_2, 1.0f);
        var _S48 : vec4<f32> = vec4<f32>(_S45, 1.0f);
        gAccum_0[base_0 + u32(1)] = _S48;
        gAccum_0[base_0 + u32(2)] = _S48;
    }
    else
    {
        var _S49 : vec3<f32> = vec3<f32>((1.0f / f32(frameIndex_0 + u32(1))));
        gAccum_0[base_0] = vec4<f32>(mix(gAccum_0[base_0].xyz, radiance_2, _S49), 1.0f);
        var _S50 : u32 = base_0 + u32(1);
        gAccum_0[_S50] = vec4<f32>(mix(gAccum_0[_S50].xyz, _S45, _S49), 1.0f);
        var _S51 : u32 = base_0 + u32(2);
        gAccum_0[_S51] = vec4<f32>(mix(gAccum_0[_S51].xyz, _S45, _S49), 1.0f);
    }
    return;
}

