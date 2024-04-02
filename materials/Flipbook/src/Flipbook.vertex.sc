$input a_position, a_texcoord0
$output v_position, v_texcoord0, v_is_atlas, v_uv_from, v_uv_to

#include <bgfx_shader.sh>

uniform vec4 VBlendControl;

SAMPLER2D_AUTOREG(s_BlitTexture);

void main() {

    highp ivec2 size = textureSize(s_BlitTexture, 0);

    v_is_atlas = float(size.x == 4096 && size.y == 4096);
    
    if ( v_is_atlas > 0.5 ) {
        v_position  = a_position.xy * 0.5 + 0.5;
        v_texcoord0 = a_texcoord0;

        #if BGFX_SHADER_LANGUAGE_GLSL
            v_texcoord0.y = v_texcoord0.y > 0.005 ? 1.0 : 0.0;
        #else
            v_texcoord0.y = v_texcoord0.y < 0.005 ? 1.0 : 0.0;
        #endif

        gl_Position = vec4(v_texcoord0 * 2.0 - 1.0, 0.0, 1.0);

        v_uv_from   = vec2(0.0, 0.0);
        v_uv_to     = vec2(0.0, 0.0);
    } 
    else {

        v_position  = vec2(0.0, 0.0);
        v_texcoord0 = vec2(0.0, 0.0);
        
        v_uv_from   = a_texcoord0;
        v_uv_from.y += VBlendControl.x;
        v_uv_to     = a_texcoord0;
        v_uv_to.y   += VBlendControl.y;

        gl_Position = vec4(a_position, 1.0);
    }
}