$input v_color0, v_texcoord0, v_lightmapUV
$input v_position, v_world, v_shadow, v_darkness, v_torchlight, v_ao
$input v_sun, v_day, v_water, v_sun_illuminance, v_moon_illuminance
$input v_ambient_zenith, v_ambient_horizon, v_ambient_average, v_time, v_ev
$input v_fog_transmittance, v_fog_scattering


#include <bgfx_shader.sh>
#include <common.sh>
#include <ACES.sh>
#include <BRDF.sh>

SAMPLER2D_AUTOREG(s_MatTexture);
SAMPLER2D_AUTOREG(s_SeasonsTexture);
SAMPLER2D_AUTOREG(s_LightMapTexture);

// In RenderChunk, textures are sampled without bilinear interpolation. (nearest)

highp vec4 read( highp ivec2 atlas_size, highp vec2 uv ) {
    return texelFetch(s_MatTexture, ivec2(uv * 4096.0) + atlas_size - 4096, 0);
}

highp vec4 readTexel( highp ivec2 atlas_size, highp ivec2 texel ) {
    return texelFetch(s_MatTexture, texel + atlas_size - 4096, 0);
}

#ifdef TRANSPARENT

    // Interpolate smoothly over sun.y (=uv.x) for gradual changes.
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

    #define REFLECTION
    #include <Sky.sh>

    highp vec3 getWaterNormal( highp ivec2 atlas_size, 
                               highp vec3 position, 
                               highp float time ) {
            
        highp vec2 direction = vec2(5.0, 4.0);
        highp float move = 0.0002 * time;
        
        for ( int i = 0; i < 4; i++, direction.y -= 3.0 ) {

            highp float wavelength = length(direction);

            highp float normalized_phase = dot(direction, position.xz) * F_1_16;
            
            normalized_phase = fract(normalized_phase + pow3(wavelength) * move);
            normalized_phase = 1.998 * abs(normalized_phase - 0.5) + 0.001;

            highp vec2 gerstner_wave = 
                read(
                    atlas_size, 
                    vec2(normalized_phase, 0.025 * wavelength) * F_1_16 + 
                    vec2(F_6_16, 0.0)
                ).xy;

            position.y += 
                0.0027 * (
                    gerstner_wave.x + gerstner_wave.y * F_1_255
                );
        }
        
        return normalize(cross(dFdx(position), dFdy(position)));
    }

#endif

highp vec3 getBRDF( highp vec3 V, highp vec3 N, highp vec3 L, highp float NoV,
                    highp vec3 E, highp vec3 diffuse,
                    float roughness ) {

    highp vec3 H    = normalize(V + L);
    highp float NoL = max(dot(N, L), 0.0);
    highp float NoH = max(dot(N, H), 0.0);
    highp float VoH = max(dot(V, H), 0.0);

    highp float D = DistributionGGX(NoH, roughness);
    highp float G = GeometrySmith(NoV, NoL, roughness);
    highp float F = FresnelSchlick(VoH, 0.04);

    highp float specular = D * G * F / (4.0 * NoV * NoL + 0.0001);

    return (diffuse * (1.0 - F) + specular) * E * NoL;
}

vec3 getDither( highp ivec2 atlas_size, highp vec2 coord ) {

    highp ivec2 texel = ivec2(coord) % 256 + ivec2(1792, 0);

    return readTexel(atlas_size, texel).rgb * 16.0 - 8.0;
}

void main() {

    #if defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY)
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0); return;
    #else // defined(DEPTH_ONLY_OPAQUE) || defined(DEPTH_ONLY)

        highp vec3 albedo;
        highp float alpha;

        /* Prepare albedo and alpha */ {
            vec4 tex = texture2D(s_MatTexture, v_texcoord0);

            albedo  = tex.rgb;
            alpha   = tex.a;

            #if defined(ALPHA_TEST)
                if (alpha < 0.5) discard;
            #endif

            #if defined(SEASONS) && (defined(OPAQUE) || defined(ALPHA_TEST))
                albedo *= 
                    mix(
                        WHITE, 
                        texture2D(s_SeasonsTexture, v_color0.xy).rgb * 2.0, 
                        v_color0.b
                    );
            #else
                albedo *= v_color0.rgb;
            #endif

            gammaToLinear(albedo);
        }

        highp vec3 V    = normalize(-v_world);
        highp vec3 N    = normalize(cross(dFdx(v_position), dFdy(v_position)));
        highp float NoV = max(dot(N, V), 0.0);

        highp ivec2 atlas_size = textureSize(s_MatTexture, 0);

        highp float shadow  = exp2(8.0 * v_shadow - 8.0) * v_shadow;
        highp vec3 dark     = vec3(0.02, 0.02, 0.02) / v_ev;

        highp vec3 sunlight     = BLACK;
        highp vec3 moonlight    = BLACK;

        highp vec3 torchlight = pow4(v_torchlight) * vec3(1.0, 0.3, 0.04);

        #ifdef TRANSPARENT
            if ( v_water > 0.999999 ) {

                float roughness = 0.04;

                alpha = pow3(1.0 - NoV * NoV);

                if ( N.y > 0.5 ) {
                    N = getWaterNormal(atlas_size, v_position, v_time);
                    NoV = max(dot(N, V), 0.0);
                }

                highp vec3 ambient = getSky(atlas_size, reflect(-V, N), v_sun);

                ambient = mix(dark, ambient, v_darkness);

                /* Calculate sun and moon lighting */ {
                    
                    if ( v_day > 0.4 ) 
                        sunlight = 
                            getBRDF(
                                V, N, v_sun, NoV, 
                                v_sun_illuminance, BLACK, 
                                roughness
                            ); 
                    
                    if ( v_day < 0.6 ) 
                        moonlight = 
                            getBRDF(
                                V, N, -v_sun, NoV, 
                                v_moon_illuminance, BLACK, 
                                roughness
                            ); 
                }

                highp vec3 HDR = 
                    shadow * (sunlight + moonlight) + ambient;

                HDR = HDR * v_fog_transmittance + v_fog_scattering;

                highp vec3 LDR = ACESFitted(HDR * v_ev);

                linearToGamma(LDR);    

                applyDithering(LDR, getDither(atlas_size, gl_FragCoord.xy));
                
                gl_FragColor = vec4(LDR, alpha);

                return;
            }
        #endif

        /* Calculate sun and moon lighting */ {

            highp vec3 diffuse = albedo * F_1_PI;

            float roughness = 0.8;
    
            if ( v_day > 0.4 ) 
                sunlight = 
                    getBRDF(
                        V, N, v_sun, NoV, 
                        v_sun_illuminance, diffuse, 
                        roughness
                    ); 
            
            if ( v_day < 0.6 ) 
                moonlight = 
                    getBRDF(
                        V, N, -v_sun, NoV, 
                        v_moon_illuminance, diffuse, 
                        roughness
                    ); 
            
        }

        highp vec3 ambient = albedo * mix(dark, v_ambient_average, v_darkness) * v_ao;

        torchlight *= albedo;

        highp vec3 HDR = shadow * (sunlight + moonlight) + ambient + torchlight;

        HDR = HDR * v_fog_transmittance + v_fog_scattering;

        highp vec3 LDR = ACESFitted(HDR * v_ev);

        linearToGamma(LDR);    

        applyDithering(LDR, getDither(atlas_size, gl_FragCoord.xy));
        
        gl_FragColor = vec4(LDR, alpha);

    #endif
}