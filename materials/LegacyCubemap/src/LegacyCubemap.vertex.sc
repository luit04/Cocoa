$input a_position, a_texcoord0
$output v_texcoord0, v_title, v_position, v_sun, v_time, v_ev

#include <bgfx_shader.sh>
#include <common.sh>

uniform mat4 CubemapRotation;

uniform vec4 FogAndDistanceControl; // x: fog_start, y: fog_end, z: distance
uniform vec4 ViewPositionAndTime;

SAMPLER2D_AUTOREG(s_MatTexture);

highp vec3 getLUT( highp vec2 uv ) {
    return
        texture2DLod(s_MatTexture, uv, 0).rgb +
        texture2DLod(s_MatTexture, uv + vec2(F_1_16, 0.0), 0).rgb * F_1_255;
}

void main() {
    
    v_texcoord0 = a_texcoord0;
    v_title     = 0.0;
    v_position  = vec3(a_position.x, 0.205 - a_position.y, -a_position.z);
    
    /*
        It prevents time from changing quickly due to the render distance that changes when you open the UI
        FogAndDistanceControl.x = fog start (fixed) / FogAndDistanceControl.z
    */
    v_sun   = getSunVector(FogAndDistanceControl.x * FogAndDistanceControl.z * 0.02, ViewPositionAndTime.w);
    v_time      = ViewPositionAndTime.w;
    v_ev        = getEV(v_sun.y);
    
    gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));
    
    if ( CubemapRotation[0][0] < 1.0 ) { 
        gl_Position = mul(u_modelViewProj, mul(CubemapRotation, vec4(a_position, 1.0)));
        v_title = 1.0; 
    }
}
