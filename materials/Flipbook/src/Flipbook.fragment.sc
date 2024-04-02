$input v_position, v_texcoord0, v_is_atlas, v_uv_from, v_uv_to

#include <bgfx_shader.sh>

uniform vec4 VBlendControl;

SAMPLER2D_AUTOREG(s_BlitTexture);

void main() {

    if ( v_is_atlas > 0.5 ) {

        #if BGFX_SHADER_LANGUAGE_GLSL
            highp vec2 uv = (v_texcoord0 - 1.0) * u_viewRect.zw / 4096.0 + 1.0;
        #else
            highp vec2 uv = vec2(v_texcoord0.x - 1.0, -v_texcoord0.y) * u_viewRect.zw / 4096.0 + 1.0;
        #endif

        if ( any(lessThan(uv, vec2(0.0, 0.0))) ) discard;

        gl_FragColor = texture2D(s_BlitTexture, uv);
        return;
    }

    vec4 color_from = texture2D(s_BlitTexture, v_uv_from);
    vec4 color_to   = texture2D(s_BlitTexture, v_uv_to);

    vec4 color = color_from;
    
    if ( color_from.a < 0.01 ) {
        color = color_to;
    }
    else if ( color_to.a >= 0.01 ) {
        color = mix(color_from, color_to, VBlendControl.z);
    }

    gl_FragColor = color;
}