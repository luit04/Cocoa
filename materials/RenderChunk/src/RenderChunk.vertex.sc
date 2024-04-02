$input a_color0, a_position, a_texcoord0, a_texcoord1
#ifdef INSTANCING
    $input i_data0, i_data1, i_data2
#endif
$output v_color0, v_texcoord0, v_lightmapUV
$output v_position, v_world, v_shadow, v_darkness, v_torchlight, v_ao
$output v_sun, v_day, v_water, v_sun_illuminance, v_moon_illuminance
$output v_ambient_zenith, v_ambient_horizon, v_ambient_average, v_time, v_ev
$output v_fog_transmittance, v_fog_scattering

#include <bgfx_shader.sh>
#include <common.sh>

uniform vec4 RenderChunkFogAlpha;   // x: fog offset
uniform vec4 FogAndDistanceControl; // x: fog_start, y: fog_end, z: max distance
uniform vec4 ViewPositionAndTime;
uniform vec4 FogColor;

SAMPLER2D_AUTOREG(s_MatTexture);

highp vec4 read( highp ivec2 atlas_size, highp vec2 uv ) {
    return texelFetch(s_MatTexture, ivec2(uv * 4096.0) + atlas_size - 4096, 0);
}

highp vec3 getLUT( highp ivec2 atlas_size, highp vec2 uv ) {

    highp ivec2 texel = ivec2(uv * 4096.0) + atlas_size - 4096;

    return
        texelFetch(s_MatTexture, texel, 0).rgb +
        texelFetch(s_MatTexture, texel + ivec2(256, 0), 0).rgb * F_1_255;
}

// Interpolate smoothly over time (sun.y, uv.x) for gradual changes.
highp vec3 getLUT_mix( highp ivec2 atlas_size, highp vec2 uv ) {

    highp float v = fract(uv.x * 4096.0 - 0.5);

    highp ivec2 texel = ivec2(uv * 4096.0) + atlas_size - 4096;

    highp vec3 pixel0 =
        texelFetch(s_MatTexture, texel, 0).rgb +
        texelFetch(s_MatTexture, texel + ivec2(256, 0), 0).rgb * F_1_255;

    texel.x += (v < 0.5 ? 1 : -1);
    
    highp vec3 pixel1 =
        texelFetch(s_MatTexture, texel, 0).rgb +
        texelFetch(s_MatTexture, texel + ivec2(256, 0), 0).rgb * F_1_255;

    return mix(pixel0, pixel1, (v < 0.5 ? v : 1.0 - v));
}

highp vec4 separateAO( highp vec4 color0 ) {

    if ( all(lessThan(color0.rgb - color0.gbr, vec3(0.01, 0.01, 0.01))) ) {
        return vec4(WHITE, color0.r);
    }

    // grass
    vec3 p0 = vec3(128.0, 180.0, 150.0);
    vec3 p1 = vec3(190.0, 182.0, 84.0);
    vec3 p2 = vec3(71.0, 208.0, 51.0);

    /*
        foliage
        p0 = vec3(96.0, 161.0, 123.0);
        p1 = vec3(174.0, 164.0, 42.0);
        p2 = vec3(26.0, 191.0, 0.0);
    */

    highp vec3 N = cross(p1 - p0, p2 - p0);

    highp float t = dot(N, p0) / dot(N, color0.rgb) * F_1_255;

    return vec4( color0.rgb * t, 1.0 / t );
}

#define TERRAIN_FOG
#include <Sky.sh>

void main() {

    mat4 model;
#ifdef INSTANCING
    model = mtxFromCols(i_data0, i_data1, i_data2, vec4(0.0, 0.0, 0.0, 1.0));
#else
    model = u_model[0];
#endif

    vec3 world = mul(model, vec4(a_position, 1.0)).xyz;
#ifdef RENDER_AS_BILLBOARDS
    world += 0.5;

    vec3 board_view     = normalize(world);
    vec3 board_plane    = normalize(vec3(board_view.z, 0.0, -board_view.x));

    // Here, a_color0.xz represents the size of the billboard.
    world -= 
        cross(board_view, board_plane) * (a_color0.z - 0.5) + 
        board_plane * (a_color0.x - 0.5);

    v_color0 = vec4(WHITE, 1.0);
    v_ao = 1.0;
#else
    #if defined(SEASONS) && (defined(OPAQUE) || defined(ALPHA_TEST))
        v_color0 = a_color0;
        v_ao = mix(a_color0.w, 1.0, 0.5);
    #else
        vec4 color_ao = separateAO(a_color0);
        v_color0 = vec4(color_ao.rgb, a_color0.a);
        v_ao = mix(color_ao.w, 1.0, 0.5);
    #endif
#endif

    v_texcoord0     = a_texcoord0;
    v_lightmapUV    = a_texcoord1;

    v_position      = a_position;
    v_world         = world;
    v_shadow        = linearstep(F_1_32, F_15_16, max(v_lightmapUV.y, F_1_32));
    v_darkness      = sqrt(v_lightmapUV.y * F_16_15);
    v_torchlight    = v_lightmapUV.x * F_16_15;

    highp ivec2 atlas_size = textureSize(s_MatTexture, 0);

    v_sun   = getSunVector(FogAndDistanceControl.x, ViewPositionAndTime.w);
    v_day   = v_sun.y * 0.5 + 0.5;
    v_water = float(v_color0.a < 0.75 && v_color0.a > 0.25);

    v_sun_illuminance = 
        SUN_LUMINANCE * getLUT_mix(atlas_size, vec2(v_day, 0.025) * F_1_16);

    v_moon_illuminance = 
        MOON_LUMINANCE * getLUT_mix(atlas_size, vec2(1.0 - v_day, 0.025) * F_1_16);
    
    v_ambient_zenith = 
        getLUT_mix(atlas_size, vec2(v_day, 0.75) * F_1_16 + vec2(F_4_16, 0.0));

    v_ambient_horizon = 
        getLUT_mix(atlas_size, vec2(v_day, 0.25) * F_1_16 + vec2(F_4_16, 0.0));

    v_ambient_average   = mix(v_ambient_zenith, v_ambient_horizon, 0.25);
    v_time              = ViewPositionAndTime.w;
    v_ev                = getEV(v_sun.y);

    highp float view_distance = length(v_world);
    highp vec3 view = v_world / view_distance;

    /* 
        As the altitude is set 1km higher, the fog effect is 
        applied more extensively than the actual value.
    */
    v_fog_scattering = 
        getSky(
            atlas_size, 
            view_distance * 0.00002,   // t_0 : 20 meter to megameter
            v_fog_transmittance, 
            view, 
            v_sun
        );

    gl_Position = mul(u_viewProj, vec4(world, 1.0));
}
