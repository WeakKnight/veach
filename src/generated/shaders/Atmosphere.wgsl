// Generated from shaders/Passes/Atmosphere.slang by scripts/build-shaders.mjs. Do not edit.
@binding(6) @group(0) var gLutOut_0 : texture_storage_2d<rgba32float, write>;

@binding(1) @group(0) var gTransmittance_0 : texture_2d<f32>;

struct AtmosphereUniforms_std140_0
{
    @align(16) sunDirection_0 : vec4<f32>,
    @align(16) illuminance_0 : vec4<f32>,
};

@binding(0) @group(0) var<uniform> gAtmosphere_0 : AtmosphereUniforms_std140_0;
@binding(2) @group(0) var gMultiScattering_0 : texture_2d<f32>;

@binding(5) @group(0) var<storage, read_write> gScratch_0 : array<f32>;

@binding(3) @group(0) var gSkyView_0 : texture_2d<f32>;

@binding(7) @group(0) var gEnvironmentOut_0 : texture_storage_2d<rgba16float, write>;

@binding(4) @group(0) var gEnvironment_0 : texture_2d<f32>;

@binding(8) @group(0) var gCdfOut_0 : texture_storage_2d<r32float, write>;

fn TexelToAltitudeParams_0( p_0 : vec2<i32>,  size_0 : vec2<i32>,  r_0 : ptr<function, f32>,  cosSun_0 : ptr<function, f32>)
{
    (*cosSun_0) = 2.0f * (f32(p_0.x) + 0.5f) / f32(size_0.x) - 1.0f;
    var v_0 : f32 = (f32(p_0.y) + 0.5f) / f32(size_0.y);
    (*r_0) = 6.3600001335144043f + v_0 * v_0 * 0.099999904632568359f;
    return;
}

fn IntersectSphere_0( o_0 : vec3<f32>,  d_0 : vec3<f32>,  radius_0 : f32) -> f32
{
    var b_0 : f32 = dot(o_0, d_0);
    var c_0 : f32 = dot(o_0, o_0) - radius_0 * radius_0;
    var _S1 : bool;
    if((c_0 > 0.0f))
    {
        _S1 = (b_0 > 0.0f);
    }
    else
    {
        _S1 = false;
    }
    if(_S1)
    {
        return -1.0f;
    }
    var _S2 : f32 = b_0 * b_0;
    var disc_0 : f32 = _S2 - c_0;
    if((disc_0 < 0.0f))
    {
        return -1.0f;
    }
    var _S3 : f32;
    if((disc_0 > _S2))
    {
        _S3 = - b_0 + sqrt(disc_0);
    }
    else
    {
        _S3 = - b_0 - sqrt(disc_0);
    }
    return _S3;
}

fn MarchEnd_0( s_0 : u32,  n_0 : u32,  tMax_0 : f32) -> f32
{
    var x_0 : f32 = f32(s_0 + u32(1)) / f32(n_0);
    return x_0 * x_0 * tMax_0;
}

struct Medium_0
{
     rayleighScattering_0 : vec3<f32>,
     mieScattering_0 : f32,
     extinction_0 : vec3<f32>,
};

fn SampleMedium_0( r_1 : f32) -> Medium_0
{
    var _S4 : f32 = max(0.0f, (r_1 - 6.3600001335144043f) * 1000.0f);
    var _S5 : f32 = - _S4;
    var mie_0 : f32 = exp(_S5 / 1.2000000476837158f);
    var _S6 : f32 = max(0.0f, 1.0f - abs(_S4 - 25.0f) / 15.0f);
    var m_0 : Medium_0;
    var _S7 : vec3<f32> = vec3<f32>(5.8020000457763672f, 13.557999610900879f, 33.099998474121094f) * vec3<f32>(exp(_S5 / 8.0f));
    m_0.rayleighScattering_0 = _S7;
    m_0.mieScattering_0 = 3.9960000514984131f * mie_0;
    m_0.extinction_0 = _S7 + vec3<f32>((8.3959999084472656f * mie_0)) + vec3<f32>(0.64999997615814209f, 1.8810000419616699f, 0.085000000894069672f) * vec3<f32>(_S6);
    return m_0;
}

fn TransmittanceToTop_0( r_2 : f32,  cosZenith_0 : f32) -> vec3<f32>
{
    var o_1 : vec3<f32> = vec3<f32>(0.0f, r_2, 0.0f);
    var d_1 : vec3<f32> = vec3<f32>(0.0f, cosZenith_0, - sqrt(max(0.0f, 1.0f - cosZenith_0 * cosZenith_0)));
    if(((IntersectSphere_0(o_1, d_1, 6.3600001335144043f)) > 0.0f))
    {
        return vec3<f32>(0.0f);
    }
    var _S8 : f32 = IntersectSphere_0(o_1, d_1, 6.4600000381469727f);
    var _S9 : vec3<f32> = vec3<f32>(0.0f);
    var t0_0 : f32 = 0.0f;
    var s_1 : u32 = u32(0);
    var depth_0 : vec3<f32> = _S9;
    loop
    {
        if((s_1 < u32(40)))
        {
        }
        else
        {
            break;
        }
        var t1_0 : f32 = MarchEnd_0(s_1, u32(40), _S8);
        var dt_0 : f32 = t1_0 - t0_0;
        var depth_1 : vec3<f32> = depth_0 + vec3<f32>(dt_0) * SampleMedium_0(length(o_1 + vec3<f32>((t0_0 + 0.5f * dt_0)) * d_1)).extinction_0;
        var _S10 : u32 = s_1 + u32(1);
        t0_0 = t1_0;
        s_1 = _S10;
        depth_0 = depth_1;
    }
    return exp((vec3<f32>(0) - depth_0));
}

@compute
@workgroup_size(8, 8, 1)
fn TransmittanceLut(@builtin(global_invocation_id) id_0 : vec3<u32>)
{
    var _S11 : vec2<u32> = id_0.xy;
    if((any(((_S11 >= vec2<u32>(vec2<i32>(i32(256), i32(64))))))))
    {
        return;
    }
    var r_3 : f32;
    var cosSun_1 : f32;
    TexelToAltitudeParams_0(vec2<i32>(_S11), vec2<i32>(i32(256), i32(64)), &(r_3), &(cosSun_1));
    textureStore((gLutOut_0), (_S11), (vec4<f32>(TransmittanceToTop_0(r_3, cosSun_1), 1.0f)));
    return;
}

fn float_getPi_0() -> f32
{
    return 3.1415927410125732f;
}

fn AltitudeLutUV_0( r_4 : f32,  cosSunZenith_0 : f32) -> vec2<f32>
{
    return vec2<f32>(0.5f + 0.5f * cosSunZenith_0, sqrt(max(0.0f, (r_4 - 6.3600001335144043f) / 0.099999904632568359f)));
}

fn SampleLut_0( lut_0 : texture_2d<f32>,  size_1 : vec2<i32>,  uv_0 : vec2<f32>) -> vec3<f32>
{
    var _S12 : vec2<i32> = vec2<i32>(i32(1));
    var _S13 : vec2<i32> = size_1 - _S12;
    var p_1 : vec2<f32> = clamp(uv_0 * vec2<f32>(size_1) - vec2<f32>(0.5f), vec2<f32>(0.0f), vec2<f32>(_S13));
    var _S14 : vec2<i32> = vec2<i32>(floor(p_1));
    var _S15 : vec2<i32> = min(_S14 + _S12, _S13);
    var f_0 : vec2<f32> = p_1 - vec2<f32>(_S14);
    var _S16 : i32 = _S14.x;
    var _S17 : i32 = _S14.y;
    var _S18 : vec3<i32> = vec3<i32>(_S16, _S17, i32(0));
    var _S19 : i32 = _S15.x;
    var _S20 : vec3<i32> = vec3<i32>(_S19, _S17, i32(0));
    var _S21 : i32 = _S15.y;
    var _S22 : vec3<i32> = vec3<i32>(_S16, _S21, i32(0));
    var _S23 : vec3<i32> = vec3<i32>(_S19, _S21, i32(0));
    var _S24 : vec3<f32> = vec3<f32>(f_0.x);
    return mix(mix((textureLoad((lut_0), ((_S18)).xy, ((_S18)).z)).xyz, (textureLoad((lut_0), ((_S20)).xy, ((_S20)).z)).xyz, _S24), mix((textureLoad((lut_0), ((_S22)).xy, ((_S22)).z)).xyz, (textureLoad((lut_0), ((_S23)).xy, ((_S23)).z)).xyz, _S24), vec3<f32>(f_0.y));
}

fn SunTransmittanceAt_0( p_2 : vec3<f32>,  sun_0 : vec3<f32>) -> vec3<f32>
{
    var r_5 : f32 = length(p_2);
    return SampleLut_0(gTransmittance_0, vec2<i32>(i32(256), i32(64)), AltitudeLutUV_0(r_5, dot(p_2, sun_0) / r_5));
}

fn GroundRadiance_0( p_3 : vec3<f32>,  sun_1 : vec3<f32>) -> vec3<f32>
{
    var cosSun_2 : f32 = dot(normalize(p_3), sun_1);
    if((cosSun_2 <= 0.0f))
    {
        return vec3<f32>(0.0f);
    }
    return SampleLut_0(gTransmittance_0, vec2<i32>(i32(256), i32(64)), AltitudeLutUV_0(6.3600001335144043f, cosSun_2)) * vec3<f32>((0.30000001192092896f * (1.0f / float_getPi_0()) * cosSun_2));
}

@compute
@workgroup_size(8, 8, 1)
fn MultiScatteringLut(@builtin(global_invocation_id) id_1 : vec3<u32>)
{
    var _S25 : vec2<u32> = id_1.xy;
    if((any(((_S25 >= vec2<u32>(vec2<i32>(i32(32), i32(32))))))))
    {
        return;
    }
    var r_6 : f32;
    var cosSun_3 : f32;
    TexelToAltitudeParams_0(vec2<i32>(_S25), vec2<i32>(i32(32), i32(32)), &(r_6), &(cosSun_3));
    var _S26 : vec3<f32> = vec3<f32>(0.0f, r_6, 0.0f);
    var _S27 : vec3<f32> = vec3<f32>(0.0f, cosSun_3, - sqrt(max(0.0f, 1.0f - cosSun_3 * cosSun_3)));
    var _S28 : vec3<f32> = vec3<f32>(0.0f);
    var i_0 : u32 = u32(0);
    var fms_0 : vec3<f32> = _S28;
    var lum_0 : vec3<f32> = _S28;
    loop
    {
        if((i_0 < u32(8)))
        {
        }
        else
        {
            break;
        }
        var PI_0 : f32 = float_getPi_0();
        var _S29 : f32 = PI_0 * (f32(i_0) + 0.5f) / 8.0f;
        var j_0 : u32 = u32(0);
        loop
        {
            if((j_0 < u32(8)))
            {
            }
            else
            {
                break;
            }
            var cosPhi_0 : f32 = 1.0f - 2.0f * (f32(j_0) + 0.5f) / 8.0f;
            var sinPhi_0 : f32 = sqrt(1.0f - cosPhi_0 * cosPhi_0);
            var d_2 : vec3<f32> = vec3<f32>(sinPhi_0 * sin(_S29), cosPhi_0, sinPhi_0 * cos(_S29));
            var groundDist_0 : f32 = IntersectSphere_0(_S26, d_2, 6.3600001335144043f);
            var _S30 : bool = (groundDist_0 > 0.0f);
            var _S31 : f32;
            if(_S30)
            {
                _S31 = groundDist_0;
            }
            else
            {
                _S31 = IntersectSphere_0(_S26, d_2, 6.4600000381469727f);
            }
            var _S32 : vec3<f32> = vec3<f32>(1.0f);
            var t0_1 : f32 = 0.0f;
            var s_2 : u32 = u32(0);
            var tr_0 : vec3<f32> = _S32;
            var fms_1 : vec3<f32> = fms_0;
            var lum_1 : vec3<f32> = lum_0;
            loop
            {
                if((s_2 < u32(20)))
                {
                }
                else
                {
                    break;
                }
                var t1_1 : f32 = MarchEnd_0(s_2, u32(20), _S31);
                var dt_1 : f32 = t1_1 - t0_1;
                var p_4 : vec3<f32> = _S26 + vec3<f32>((t0_1 + 0.5f * dt_1)) * d_2;
                var m_1 : Medium_0 = SampleMedium_0(length(p_4));
                var segment_0 : vec3<f32> = exp(vec3<f32>(- dt_1) * m_1.extinction_0);
                var integral_0 : vec3<f32> = (vec3<f32>(1.0f) - segment_0) / m_1.extinction_0;
                var _S33 : vec3<f32> = tr_0 * (m_1.rayleighScattering_0 + vec3<f32>(m_1.mieScattering_0));
                var _S34 : vec3<f32> = vec3<f32>(0.015625f);
                var fms_2 : vec3<f32> = fms_1 + _S33 * integral_0 * _S34;
                var lum_2 : vec3<f32> = lum_1 + _S33 * vec3<f32>((0.25f * (1.0f / PI_0))) * SunTransmittanceAt_0(p_4, _S27) * integral_0 * _S34;
                var tr_1 : vec3<f32> = tr_0 * segment_0;
                var _S35 : u32 = s_2 + u32(1);
                t0_1 = t1_1;
                s_2 = _S35;
                tr_0 = tr_1;
                fms_1 = fms_2;
                lum_1 = lum_2;
            }
            var lum_3 : vec3<f32>;
            if(_S30)
            {
                lum_3 = lum_1 + tr_0 * GroundRadiance_0(_S26 + vec3<f32>(groundDist_0) * d_2, _S27) * vec3<f32>(0.015625f);
            }
            else
            {
                lum_3 = lum_1;
            }
            j_0 = j_0 + u32(1);
            fms_0 = fms_1;
            lum_0 = lum_3;
        }
        i_0 = i_0 + u32(1);
    }
    textureStore((gLutOut_0), (_S25), (vec4<f32>(lum_0 / (vec3<f32>(1.0f) - fms_0), 1.0f)));
    return;
}

fn HorizonAltitude_0() -> f32
{
    return - acos(0.99996858835220337f);
}

fn SkyViewVToAltitude_0( v_1 : f32) -> f32
{
    var horizon_0 : f32 = HorizonAltitude_0();
    if((v_1 >= 0.5f))
    {
        var c_1 : f32 = 2.0f * v_1 - 1.0f;
        return horizon_0 + (0.5f * float_getPi_0() - horizon_0) * c_1 * c_1;
    }
    var c_2 : f32 = 1.0f - 2.0f * v_1;
    return horizon_0 - (0.5f * float_getPi_0() + horizon_0) * c_2 * c_2;
}

fn RayleighPhase_0( cosTheta_0 : f32) -> f32
{
    return 3.0f / (16.0f * float_getPi_0()) * (1.0f + cosTheta_0 * cosTheta_0);
}

fn MiePhase_0( cosTheta_1 : f32) -> f32
{
    return 3.0f / (8.0f * float_getPi_0()) * (0.35999995470046997f * (1.0f + cosTheta_1 * cosTheta_1)) / (2.6400001049041748f * pow(1.6400001049041748f - 1.6000000238418579f * cosTheta_1, 1.5f));
}

fn SkyViewTexel_0( p_5 : vec2<i32>)
{
    var altitude_0 : f32 = SkyViewVToAltitude_0((f32(p_5.y) + 0.5f) / 200.0f);
    var PI_1 : f32 = float_getPi_0();
    var azimuth_0 : f32 = ((f32(p_5.x) + 0.5f) / 200.0f - 0.5f) * (2.0f * PI_1);
    var cosAlt_0 : f32 = cos(altitude_0);
    var d_3 : vec3<f32> = vec3<f32>(cosAlt_0 * sin(azimuth_0), sin(altitude_0), - cosAlt_0 * cos(azimuth_0));
    var sy_0 : f32 = gAtmosphere_0.sunDirection_0.y;
    var sun_2 : vec3<f32> = vec3<f32>(0.0f, sy_0, - sqrt(max(0.0f, 1.0f - sy_0 * sy_0)));
    var cosTheta_2 : f32 = dot(d_3, sun_2);
    var _S36 : f32 = RayleighPhase_0(cosTheta_2);
    var _S37 : f32 = MiePhase_0(cosTheta_2);
    const o_2 : vec3<f32> = vec3<f32>(0.0f, 6.3601999282836914f, 0.0f);
    var groundDist_1 : f32 = IntersectSphere_0(o_2, d_3, 6.3600001335144043f);
    var _S38 : bool = (groundDist_1 > 0.0f);
    var _S39 : f32;
    if(_S38)
    {
        _S39 = groundDist_1;
    }
    else
    {
        _S39 = IntersectSphere_0(o_2, d_3, 6.4600000381469727f);
    }
    var _S40 : vec3<f32> = vec3<f32>(0.0f);
    var _S41 : vec3<f32> = vec3<f32>(1.0f);
    var t0_2 : f32 = 0.0f;
    var s_3 : u32 = u32(0);
    var tr_2 : vec3<f32> = _S41;
    var lum_4 : vec3<f32> = _S40;
    loop
    {
        if((s_3 < u32(32)))
        {
        }
        else
        {
            break;
        }
        var t1_2 : f32 = MarchEnd_0(s_3, u32(32), _S39);
        var dt_2 : f32 = t1_2 - t0_2;
        var pos_0 : vec3<f32> = o_2 + vec3<f32>((t0_2 + 0.5f * dt_2)) * d_3;
        var r_7 : f32 = length(pos_0);
        var uv_1 : vec2<f32> = AltitudeLutUV_0(r_7, dot(pos_0, sun_2) / r_7);
        var sunTr_0 : vec3<f32> = SampleLut_0(gTransmittance_0, vec2<i32>(i32(256), i32(64)), uv_1);
        var psi_0 : vec3<f32> = SampleLut_0(gMultiScattering_0, vec2<i32>(i32(32), i32(32)), uv_1);
        var m_2 : Medium_0 = SampleMedium_0(r_7);
        var segment_1 : vec3<f32> = exp(vec3<f32>(- dt_2) * m_2.extinction_0);
        var lum_5 : vec3<f32> = lum_4 + tr_2 * (m_2.rayleighScattering_0 * (vec3<f32>(_S36) * sunTr_0 + psi_0) + vec3<f32>(m_2.mieScattering_0) * (vec3<f32>(_S37) * sunTr_0 + psi_0)) * (vec3<f32>(1.0f) - segment_1) / m_2.extinction_0;
        var tr_3 : vec3<f32> = tr_2 * segment_1;
        var _S42 : u32 = s_3 + u32(1);
        t0_2 = t1_2;
        s_3 = _S42;
        tr_2 = tr_3;
        lum_4 = lum_5;
    }
    if(_S38)
    {
        lum_4 = lum_4 + tr_2 * (GroundRadiance_0(o_2 + vec3<f32>(groundDist_1) * d_3, sun_2) + vec3<f32>((0.30000001192092896f * (1.0f / PI_1))) * vec3<f32>(gScratch_0[i32(0)], gScratch_0[i32(1)], gScratch_0[i32(2)]));
    }
    textureStore((gLutOut_0), (vec2<u32>(p_5)), (vec4<f32>(lum_4, 1.0f)));
    return;
}

@compute
@workgroup_size(8, 8, 1)
fn SkyViewSkyRows(@builtin(global_invocation_id) id_2 : vec3<u32>)
{
    var p_6 : vec2<i32> = vec2<i32>(id_2.xy) + vec2<i32>(i32(0), i32(100));
    var _S43 : bool;
    if(((p_6.x) < i32(200)))
    {
        _S43 = ((p_6.y) < i32(200));
    }
    else
    {
        _S43 = false;
    }
    if(_S43)
    {
        SkyViewTexel_0(p_6);
    }
    return;
}

var<workgroup> gsIrradiance_0 : array<vec3<f32>, i32(64)>;

@compute
@workgroup_size(64, 1, 1)
fn SkyIrradiance(@builtin(local_invocation_id) tid_0 : vec3<u32>)
{
    var _S44 : vec3<f32> = vec3<f32>(0.0f);
    var _S45 : u32 = tid_0.x;
    var i_1 : i32 = i32(_S45);
    var sum_0 : vec3<f32> = _S44;
    loop
    {
        if((i_1 < i32(20000)))
        {
        }
        else
        {
            break;
        }
        var y_0 : i32 = i32(100) + i_1 / i32(200);
        var _S46 : f32 = f32(y_0);
        var altitude_1 : f32 = SkyViewVToAltitude_0((_S46 + 0.5f) / 200.0f);
        var _S47 : vec3<i32> = vec3<i32>(i_1 % i32(200), y_0, i32(0));
        var sum_1 : vec3<f32> = sum_0 + (textureLoad((gSkyView_0), ((_S47)).xy, ((_S47)).z)).xyz * vec3<f32>((max(0.0f, sin(altitude_1)) * cos(altitude_1) * (SkyViewVToAltitude_0(f32(y_0 + i32(1)) / 200.0f) - SkyViewVToAltitude_0(_S46 / 200.0f)) * (2.0f * float_getPi_0()) / 200.0f));
        i_1 = i_1 + i32(64);
        sum_0 = sum_1;
    }
    gsIrradiance_0[_S45] = sum_0;
    workgroupBarrier();
    var stride_0 : u32 = u32(32);
    loop
    {
        if((stride_0 > u32(0)))
        {
        }
        else
        {
            break;
        }
        if((_S45 < stride_0))
        {
            gsIrradiance_0[_S45] = gsIrradiance_0[_S45] + gsIrradiance_0[_S45 + stride_0];
        }
        workgroupBarrier();
        stride_0 = (stride_0 >> (u32(1)));
    }
    if(_S45 == u32(0))
    {
        gScratch_0[i32(0)] = gsIrradiance_0[i32(0)].x;
        gScratch_0[i32(1)] = gsIrradiance_0[i32(0)].y;
        gScratch_0[i32(2)] = gsIrradiance_0[i32(0)].z;
    }
    return;
}

@compute
@workgroup_size(8, 8, 1)
fn SkyViewGroundRows(@builtin(global_invocation_id) id_3 : vec3<u32>)
{
    var _S48 : vec2<i32> = vec2<i32>(id_3.xy);
    var _S49 : bool;
    if(((_S48.x) < i32(200)))
    {
        _S49 = ((_S48.y) < i32(100));
    }
    else
    {
        _S49 = false;
    }
    if(_S49)
    {
        SkyViewTexel_0(_S48);
    }
    return;
}

fn EquirectUVToDirection_0( uv_2 : vec2<f32>,  cosElevation_0 : ptr<function, f32>) -> vec3<f32>
{
    var PI_2 : f32 = float_getPi_0();
    var azimuth_1 : f32 = (uv_2.x + 0.25f) * (2.0f * PI_2);
    var elevation_0 : f32 = (0.5f - uv_2.y) * PI_2;
    var _S50 : f32 = cos(elevation_0);
    (*cosElevation_0) = _S50;
    return vec3<f32>(cos(azimuth_1) * _S50, sin(elevation_0), sin(azimuth_1) * _S50);
}

fn AltitudeToSkyViewV_0( altitude_2 : f32) -> f32
{
    var horizon_1 : f32 = HorizonAltitude_0();
    if((altitude_2 >= horizon_1))
    {
        return 0.5f + 0.5f * sqrt(min(1.0f, (altitude_2 - horizon_1) / (0.5f * float_getPi_0() - horizon_1)));
    }
    return 0.5f - 0.5f * sqrt(min(1.0f, (horizon_1 - altitude_2) / (0.5f * float_getPi_0() + horizon_1)));
}

fn SkyViewRadiance_0( dir_0 : vec3<f32>,  sun_3 : vec3<f32>) -> vec3<f32>
{
    var altitude_3 : f32 = asin(clamp(dir_0.y, -1.0f, 1.0f));
    var f_1 : vec2<f32> = sun_3.xz;
    var fLen_0 : f32 = length(f_1);
    var f_2 : vec2<f32>;
    if((fLen_0 > 9.99999997475242708e-07f))
    {
        f_2 = f_1 / vec2<f32>(fLen_0);
    }
    else
    {
        f_2 = vec2<f32>(0.0f, -1.0f);
    }
    var _S51 : f32 = dir_0.x;
    var _S52 : f32 = f_2.x;
    var _S53 : f32 = dir_0.z;
    var _S54 : f32 = f_2.y;
    var forward_0 : f32 = _S51 * _S52 + _S53 * _S54;
    var right_0 : f32 = _S53 * _S52 - _S51 * _S54;
    var _S55 : bool;
    if(forward_0 == 0.0f)
    {
        _S55 = right_0 == 0.0f;
    }
    else
    {
        _S55 = false;
    }
    var azimuth_2 : f32;
    if(_S55)
    {
        azimuth_2 = 0.0f;
    }
    else
    {
        azimuth_2 = atan2(right_0, forward_0);
    }
    return SampleLut_0(gSkyView_0, vec2<i32>(i32(200), i32(200)), vec2<f32>(azimuth_2 * (0.5f / float_getPi_0()) + 0.5f, AltitudeToSkyViewV_0(altitude_3)));
}

@compute
@workgroup_size(8, 8, 1)
fn BakeEnvironment(@builtin(global_invocation_id) id_4 : vec3<u32>)
{
    var _S56 : vec2<u32> = id_4.xy;
    if((any(((_S56 >= vec2<u32>(vec2<i32>(i32(512), i32(256))))))))
    {
        return;
    }
    var cosElevation_1 : f32;
    textureStore((gEnvironmentOut_0), (_S56), (vec4<f32>(min(SkyViewRadiance_0(EquirectUVToDirection_0((vec2<f32>(_S56) + vec2<f32>(0.5f)) / vec2<f32>(vec2<i32>(i32(512), i32(256))), &(cosElevation_1)), gAtmosphere_0.sunDirection_0.xyz) * gAtmosphere_0.illuminance_0.xyz, vec3<f32>(65504.0f)), 1.0f)));
    return;
}

fn Luminance_0( color_0 : vec3<f32>) -> f32
{
    return dot(color_0, vec3<f32>(0.2125999927520752f, 0.71520000696182251f, 0.072200000286102295f));
}

@compute
@workgroup_size(64, 1, 1)
fn CdfRows(@builtin(global_invocation_id) id_5 : vec3<u32>)
{
    var y_1 : i32 = i32(id_5.x);
    if((y_1 >= i32(256)))
    {
        return;
    }
    var _S57 : f32 = cos(((f32(y_1) + 0.5f) / 256.0f - 0.5f) * float_getPi_0());
    var x_1 : i32 = i32(0);
    var sum_2 : f32 = 0.0f;
    loop
    {
        if((x_1 < i32(512)))
        {
        }
        else
        {
            break;
        }
        var _S58 : vec3<i32> = vec3<i32>(x_1, y_1, i32(0));
        var sum_3 : f32 = sum_2 + max(Luminance_0((textureLoad((gEnvironment_0), ((_S58)).xy, ((_S58)).z)).xyz), 0.0f) * _S57;
        x_1 = x_1 + i32(1);
        sum_2 = sum_3;
    }
    gScratch_0[i32(4) + y_1] = sum_2;
    textureStore((gCdfOut_0), (vec2<u32>(vec2<i32>(i32(0), y_1))), vec4<f32>((0.0f), 0, 0, 1));
    x_1 = i32(1);
    var running_0 : f32 = 0.0f;
    loop
    {
        if((x_1 < i32(512)))
        {
        }
        else
        {
            break;
        }
        var _S59 : vec3<i32> = vec3<i32>(x_1 - i32(1), y_1, i32(0));
        var running_1 : f32 = running_0 + max(Luminance_0((textureLoad((gEnvironment_0), ((_S59)).xy, ((_S59)).z)).xyz), 0.0f) * _S57;
        var _S60 : vec2<u32> = vec2<u32>(vec2<i32>(x_1, y_1));
        var _S61 : f32;
        if((sum_2 > 0.0f))
        {
            _S61 = running_1 / sum_2;
        }
        else
        {
            _S61 = f32(x_1) / 512.0f;
        }
        textureStore((gCdfOut_0), (_S60), vec4<f32>((_S61), 0, 0, 1));
        x_1 = x_1 + i32(1);
        running_0 = running_1;
    }
    textureStore((gCdfOut_0), (vec2<u32>(vec2<i32>(i32(512), y_1))), vec4<f32>((1.0f), 0, 0, 1));
    return;
}

@compute
@workgroup_size(1, 1, 1)
fn CdfMarginal()
{
    var y_2 : i32 = i32(0);
    var total_0 : f32 = 0.0f;
    loop
    {
        if((y_2 < i32(256)))
        {
        }
        else
        {
            break;
        }
        var total_1 : f32 = total_0 + gScratch_0[i32(4) + y_2];
        y_2 = y_2 + i32(1);
        total_0 = total_1;
    }
    textureStore((gCdfOut_0), (vec2<u32>(vec2<i32>(i32(0), i32(256)))), vec4<f32>((0.0f), 0, 0, 1));
    y_2 = i32(1);
    var running_2 : f32 = 0.0f;
    loop
    {
        if((y_2 < i32(256)))
        {
        }
        else
        {
            break;
        }
        var running_3 : f32 = running_2 + gScratch_0[i32(4) + y_2 - i32(1)];
        var _S62 : vec2<u32> = vec2<u32>(vec2<i32>(y_2, i32(256)));
        var _S63 : f32;
        if((total_0 > 0.0f))
        {
            _S63 = running_3 / total_0;
        }
        else
        {
            _S63 = f32(y_2) / 256.0f;
        }
        textureStore((gCdfOut_0), (_S62), vec4<f32>((_S63), 0, 0, 1));
        y_2 = y_2 + i32(1);
        running_2 = running_3;
    }
    textureStore((gCdfOut_0), (vec2<u32>(vec2<i32>(i32(256), i32(256)))), vec4<f32>((1.0f), 0, 0, 1));
    return;
}

