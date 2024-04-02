$input v_texcoord0, v_title, v_position, v_sun, v_time, v_ev

#include <bgfx_shader.sh>
#include <common.sh>
#include <ACES.sh>

SAMPLER2D_AUTOREG(s_MatTexture);

// In LegacyCubemap, textures are sampled with bilinear interpolation.

highp vec3 getLUT( highp vec2 uv ) {
    return
        texture2D(s_MatTexture, uv).rgb +
        texture2D(s_MatTexture, uv + vec2(F_1_16, 0.0)).rgb * F_1_255;
}


vec3 getDither( highp vec2 coord ) {

    coord = fract(coord * F_1_256) * F_1_16 + vec2(F_7_16, 0.0);

    return texture2D(s_MatTexture, coord).rgb * 32.0 - 16.0;
}

#include <Sky.sh>

void main() {
    
    if ( v_title > 0.5 ) { 
        gl_FragColor = texture2D(s_MatTexture, v_texcoord0); 
        return;
    }

    highp vec3 view = normalize(v_position);

    highp vec3 LDR = 
        ACESFitted(
            getSky( v_time, view, v_sun ) * v_ev
        );

    linearToGamma(LDR);    

    applyDithering(LDR, getDither(gl_FragCoord.xy));

    gl_FragColor = vec4(LDR, 1.0);
}
