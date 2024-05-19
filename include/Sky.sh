#ifndef HEADER_SKY_SH
#define HEADER_SKY_SH

/*
    Consider a scenario where a camera is positioned at a fixed location (height) 
    between the ground and the atmosphere.
    
    The center of the Earth is considered to be (0, 0, 0).
    LUTs are made based on the values below.
*/

#define SUN_LUMINANCE      10.0
#define MOON_LUMINANCE      0.05
#define STARMAP_LUMINANCE   0.02

// Unit: megameter ( x1,000,000 meter )

    #define EARTH_RADIUS            6.360
    #define CLOUD_MIN_RADIUS        6.36155
    #define CLOUD_MAX_RADIUS        6.3617
    #define ATMOSPHERE_RADIUS       6.400
    #define CAMERA_POSITION         vec3(0.000, 6.361, 0.000)

// Unit: per megameter ( x0.000 001 / meter )

    #define RAYLEIGH_SCATTERING_COEFFICIENT vec3(5.802, 13.558, 33.1)
    // Rayleigh absorption is 0

    #define MIE_SCATTERING_COEFFICIENT      vec3(3.996, 3.996, 3.996)
    #define MIE_ABSORPTION_COEFFICIENT      vec3(4.400, 4.400, 4.400)

    // Ozone scattering is 0
    #define OZONE_ABSORPTION_COEFFICIENT    vec3(0.650, 1.881, 0.085)


// Unit: kilometer ( x1,000 meter )

    #define RAYLEIGH_ALTITUDE   8.0
    #define MIE_ALTITUDE        1.2


/*
    Simple implementation of
    https://sebh.github.io/publications/egsr2020.pdf
    
    Consider a scenario where a camera is positioned at a fixed location (height) 
    between the ground and the atmosphere.
    
    The center of the Earth is considered to be (0, 0, 0).
*/

// Stars, galaxies, etc. (excluding the Sun and Moon)
    #ifndef TERRAIN_FOG

        highp vec2 getStarmapUV( highp vec3 sun, highp vec3 view ) {

            highp vec3 forward  = sun;
            highp vec3 up       = vec3(0.0, 0.6, -0.8);
            highp vec3 right    = cross(forward, up);  // left in Windows / iOS

            /*
                Perform inverse transformation to obtain the current coordinates 
                after transforming to celestial coordinates. 
                
                Since all row and column vectors are normalized and orthogonal to 
                each other, the inverse matrix is equal to the transpose matrix. 
                
                Moreover, multiplying by the transpose matrix is equivalent to 
                changing the order of matrix multiplication.
            */
            highp vec3 celestial_view = mul(view, mtxFromCols(forward, up, right));

            celestial_view.xz = normalize(celestial_view.xz);

            return 
                vec2(
                    sign(celestial_view.z) * acos(celestial_view.x),
                    asin(celestial_view.y)
                ) * F_1_TWO_PI + vec2(0.5, 0.75);
        }
    #endif

// Phase Functions

    // 3.0 * (1.0 + cos_theta * cos_theta) / (16.0 * PI)
    float getRayleighPhase( float cos_theta ) {
        return 3.0 * (1.0 + cos_theta * cos_theta) / (16.0 * PI);
    }

    // The Henyey-Greenstein Phase Function
    float getMiePhase( float cos_theta, float g ) {

        float denominator = 1.0 + g * g - 2.0 * g * cos_theta;

        return
                            (1.0 - g * g) 
        / //-----------------------------------------------
            ( FOUR_PI * denominator * sqrt(denominator) );
    }

highp float getIntersectionLength(  highp vec3 x, highp vec3 ray,
                                    highp float min_radius, 
                                    highp float max_radius ) {
    
    highp float b = -dot(x, ray);  // -1.0 multiplied
    highp float d = b * b - dot(x, x);
    
    highp float d_min = d + min_radius * min_radius;
    
    // Underneath the layer
    if ( length(x) < min_radius ) {
        // if ( d_min > 0.0 && b > -sqrt(d_min) ) {
            return b + sqrt(d_min);
        // }
        // Doesn't really happen
        // return -1.0;
    }

    // Inside the layer
    if ( d_min > 0.0 && b > sqrt(d_min) ) {
        return b - sqrt(d_min);
    }

    return b + sqrt(d + max_radius * max_radius);
}

void getCoefficients(   highp vec3 x,
                        out highp vec3 rayleigh_scattering, 
                        out highp vec3 mie_scattering, 
                        out highp vec3 total ) {

    // (length(x) - ER) * 1000.0, megameter to kilometer
    highp float h = length(x) * 1000.0 - 6360.0; 
    
    highp float rayleigh_density    = exp(-h / RAYLEIGH_ALTITUDE);
    highp float mie_density         = exp(-h / MIE_ALTITUDE);

    // A tent function of width 30km centered at altitude 25km
    highp float ozone_density = max(1.0 - abs(h - 25.0) * F_1_15, 0.0);
    
    rayleigh_scattering = RAYLEIGH_SCATTERING_COEFFICIENT * rayleigh_density;
    mie_scattering      = MIE_SCATTERING_COEFFICIENT * mie_density;
    
    total = 
        rayleigh_scattering +
        mie_scattering + MIE_ABSORPTION_COEFFICIENT * mie_density +
        OZONE_ABSORPTION_COEFFICIENT * ozone_density;
}

highp vec2 getLUT_UV( highp vec3 x, highp vec3 sun ) {

    return 
        vec2(
            dot(normalize(x), sun) * 0.5 + 0.5,
            linearstep(EARTH_RADIUS, ATMOSPHERE_RADIUS, length(x))
        );
}

// Clouds
    #if !defined(REFLECTION) && !defined(TERRAIN_FOG)

        // 256 * 256 * 256
        float checkCloudDensity( highp vec3 x, highp vec3 move ) {
            
            highp vec3 voxel = mod(x + move, 256.0);
            
            voxel.y = floor(voxel.y);

            voxel.xz *= F_255_256;

            highp float voxel_y = mod(voxel.y, 64.0);

            voxel.x += floor(mod(voxel_y, 8.0)) * 256.0 + 0.5;
            voxel.z += floor(voxel_y / 8.0) * 256.0 + 0.5;

            voxel.xz = voxel.xz * F_1_4096 + vec2(0.5, 0.0);

            highp float density = 0.0;

            if      ( voxel.y <  63.5 ) density = texture2D(s_MatTexture, voxel.xz).x;
            else if ( voxel.y < 127.5 ) density = texture2D(s_MatTexture, voxel.xz).y;
            else if ( voxel.y < 191.5 ) density = texture2D(s_MatTexture, voxel.xz).z;
            else                        density = texture2D(s_MatTexture, voxel.xz).w;

            return density;
        }
        // 256 * 256 * 256
        void getCloudCoefficients(  highp vec3 x, highp vec3 move,
                                    out highp vec3 rayleigh_scattering,
                                    out highp vec3 mie_scattering, 
                                    out highp vec3 total 
                                    ) {
            
            highp vec3 voxel = mod(x + move, 256.0);
            
            voxel.y = floor(voxel.y);

            voxel.xz *= F_255_256;

            highp float voxel_y = mod(voxel.y, 64.0);

            voxel.x += floor(mod(voxel_y, 8.0)) * 256.0 + 0.5;
            voxel.z += floor(voxel_y / 8.0) * 256.0 + 0.5;

            voxel.xz = voxel.xz * F_1_4096 + vec2(0.5, 0.0);

            highp float density = 0.0;

            if      ( voxel.y <  63.5 ) density = texture2D(s_MatTexture, voxel.xz).x;
            else if ( voxel.y < 127.5 ) density = texture2D(s_MatTexture, voxel.xz).y;
            else if ( voxel.y < 191.5 ) density = texture2D(s_MatTexture, voxel.xz).z;
            else                        density = texture2D(s_MatTexture, voxel.xz).w;

            density = 1750.0 * smoothstep(0.5, 0.55, density);

            // (length(x) - ER) * 1000.0, megameter to kilometer
            highp float h = length(x) * 1000.0 - 6360.0; 
            
            highp float rayleigh_density    = exp(-h / RAYLEIGH_ALTITUDE);
            highp float mie_density         = exp(-h / MIE_ALTITUDE) + density;

            // A tent function of width 30km centered at altitude 25km
            highp float ozone_density = max(1.0 - abs(h - 25.0) * F_1_15, 0.0);
            
            rayleigh_scattering = RAYLEIGH_SCATTERING_COEFFICIENT * rayleigh_density;
            mie_scattering = MIE_SCATTERING_COEFFICIENT * mie_density;
            
            total = 
                rayleigh_scattering +
                mie_scattering + MIE_ABSORPTION_COEFFICIENT * mie_density +
                OZONE_ABSORPTION_COEFFICIENT * ozone_density;
        }

        void getCloud(  highp vec3 view, highp vec3 sun, highp float time,
                        inout highp vec3 x_view,
                        highp float mie_phase_sun, highp float mie_phase_moon, 
                        out highp vec3 mie_scattering_sun, 
                        out highp vec3 mie_scattering_moon, 
                        inout highp vec3 multiple_scattering_sun,
                        inout highp vec3 multiple_scattering_moon,
                        inout highp vec3 transmittance ) {

            // Calculations are omitted due to precision issues near the horizon.
            if ( view.y < 0.0 ) {
                mie_scattering_sun = BLACK;
                mie_scattering_moon = BLACK;
                return;
            }

            // Thickness = 150m = 9.6 voxels
            
            const int VIEW_STEP_NUMBER  = 8;
            const int SUN_STEP_NUMBER   = 2;

            float VIEW_STEP_INV = 0.125;
            float SUN_STEP_INV = 0.5;

            // x axis : 5m/s
            highp vec3 move = vec3_splat(-time * 1.28);
            move.z = 0.0;

            highp float dl_view =         
                getIntersectionLength(
                    x_view, view, 
                    0.0, 
                    CLOUD_MAX_RADIUS
                ) * VIEW_STEP_INV;

            highp vec3 dx_view = view * dl_view;

            x_view += 0.5 * dx_view;
            

            highp vec3 optical_depth_view   = BLACK;
            
            // Temporary Variables, temp_*
                highp vec3 temp_mie_scattering_sun   = BLACK;
                highp vec3 temp_mie_scattering_moon  = BLACK;

                highp vec3 temp_multiple_scattering_sun   = BLACK;
                highp vec3 temp_multiple_scattering_moon  = BLACK;

            // *_view
            for ( int t_view = 0; t_view < VIEW_STEP_NUMBER; t_view++ ) {

                highp vec3 sample_x_view = x_view * 64000.0;
                if ( checkCloudDensity(sample_x_view, move) < 0.345 ) break;

                highp vec3 sample_rayleigh_scattering_view;
                highp vec3 sample_mie_scattering_view;
                highp vec3 sample_total_view;
                getCloudCoefficients(
                    sample_x_view, move,
                    sample_rayleigh_scattering_view,
                    sample_mie_scattering_view,
                    sample_total_view
                    );

                
                optical_depth_view += sample_total_view;

                highp vec3 transmittance_view = exp(-optical_depth_view * dl_view);

                highp vec3 uv;
                uv.xz   = getLUT_UV(x_view, sun) * F_1_16;
                uv.y    = F_1_16 - uv.x;

                highp vec3 mie_scattering_view = 
                    sample_mie_scattering_view * transmittance_view;

                highp vec3 optical_depth_sun = BLACK;
                /* Calculate sun optical depth, *_sun */ { 
                    highp float dl_sun = 
                        min(     
                            getIntersectionLength(
                                x_view, sun, 
                                CLOUD_MIN_RADIUS - 0.00002, 
                                CLOUD_MAX_RADIUS
                            ) * SUN_STEP_INV,
                            0.000075    // 4.8 voxels
                        );

                    highp vec3 dx_sun = sun * dl_sun;

                    highp vec3 x_sun = x_view + 0.5 * dx_sun;

                    for ( int t_sun = 0; t_sun < SUN_STEP_NUMBER; t_sun++ ) {

                        highp vec3 sample_rayleigh_scattering_sun;
                        highp vec3 sample_mie_scattering_sun;
                        highp vec3 sample_total_sun;
                        getCloudCoefficients(
                            x_sun * 64000.0, move,
                            sample_rayleigh_scattering_sun,
                            sample_mie_scattering_sun,
                            sample_total_sun
                            );

                        /*
                            For single scattering, only transmitance is 
                            considered for secondary rays.
                        */
                        optical_depth_sun += sample_total_sun;
                        x_sun += dx_sun;
                    }

                    temp_mie_scattering_sun += 
                        getLUT(uv.xz) * mie_scattering_view * 
                        exp(-optical_depth_sun * dl_sun);
                }
                
                highp vec3 optical_depth_moon = BLACK;
                /* Calculate moon optical depth, *_moon */ { 
                    highp float dl_moon =
                        min( 
                            getIntersectionLength(
                                x_view, -sun, 
                                CLOUD_MIN_RADIUS - 0.00002, 
                                CLOUD_MAX_RADIUS
                            ) * SUN_STEP_INV,
                            0.000075    // 4.8 voxels
                        );

                    highp vec3 dx_moon = -sun * dl_moon;

                    highp vec3 x_moon = x_view + 0.5 * dx_moon;

                    for ( int t_moon = 0; t_moon < SUN_STEP_NUMBER; t_moon++ ) {

                        highp vec3 sample_rayleigh_scattering_moon;
                        highp vec3 sample_mie_scattering_moon;
                        highp vec3 sample_total_moon;
                        getCloudCoefficients(
                            x_moon * 64000.0, move,
                            sample_rayleigh_scattering_moon,
                            sample_mie_scattering_moon,
                            sample_total_moon
                            );

                        /*
                            For single scattering, only transmitance is 
                            considered for secondary rays.
                        */
                        optical_depth_moon += sample_total_moon;
                        x_moon += dx_moon;
                    }
                    temp_mie_scattering_moon += 
                        getLUT(uv.yz) * mie_scattering_view * 
                        exp(-optical_depth_moon * dl_moon);
                }

                /* Multiple scattering */ {
                    
                    uv.xy += F_2_16;

                    highp vec3 sample_scattering = 
                        transmittance_view * (
                            sample_rayleigh_scattering_view + 
                            sample_mie_scattering_view
                            );

                        temp_multiple_scattering_sun     += 
                            sample_scattering * getLUT(uv.xz);
                        temp_multiple_scattering_moon    += 
                            sample_scattering * getLUT(uv.yz);
                }
                x_view += dx_view;
            }

            mie_scattering_sun += 
                temp_mie_scattering_sun * transmittance * 
                mix(mie_phase_sun, F_1_FOUR_PI, 0.8) * dl_view;

            mie_scattering_moon += 
                temp_mie_scattering_moon * transmittance * 
                mix(mie_phase_moon, F_1_FOUR_PI, 0.8) * dl_view;

            multiple_scattering_sun += 
                temp_multiple_scattering_sun * transmittance * dl_view;
                
            multiple_scattering_moon += 
                temp_multiple_scattering_moon * transmittance * dl_view;

            transmittance *= exp(-optical_depth_view * dl_view);
        }
    #endif // !defined(REFLECTION) && !defined(TERRAIN_FOG)

void getAtmosphereScattering(   
                                #if defined(REFLECTION) || defined(TERRAIN_FOG)
                                highp ivec2 atlas_size,
                                #endif
                                highp vec3 sun, highp vec3 dx, highp float dt,
                                inout highp vec3 x, 
                                in highp float rayleigh_phase,
                                in highp float mie_phase_sun,
                                in highp float mie_phase_moon,
                                inout highp vec3 transmittance,
                                inout highp vec3 rayleigh_scattering_sun,
                                inout highp vec3 rayleigh_scattering_moon,
                                inout highp vec3 mie_scattering_sun,
                                inout highp vec3 mie_scattering_moon,
                                inout highp vec3 multiple_scattering_sun,
                                inout highp vec3 multiple_scattering_moon ) {
    
    const int VIEW_STEP_NUMBER = 4;

    // Rayleigh Scattering
        highp vec3 temp_rayleigh_scattering_sun  = BLACK;
        highp vec3 temp_rayleigh_scattering_moon = BLACK;

    // Mie Scattering
        highp vec3 temp_mie_scattering_sun   = BLACK;
        highp vec3 temp_mie_scattering_moon  = BLACK;

    for ( int t = 0; t < VIEW_STEP_NUMBER; t++ ) {

        highp vec3 rayleigh_scattering, mie_scattering, total;
        getCoefficients(x, rayleigh_scattering, mie_scattering, total);
        highp vec3 sample_transmittance = exp(-total * dt);
        highp vec3 sample_sum = transmittance * (1.0 - sample_transmittance) / total;

        highp vec3 uv;
        uv.xz   = getLUT_UV(x, sun) * F_1_16;
        uv.y    = F_1_16 - uv.x;

        /* Rayleigh & Mie scattering */ {

            // Due to minimal difference, sun and moon visibility check omitted.
            #if defined(REFLECTION) || defined(TERRAIN_FOG)
                highp vec3 sample_sun   = getLUT_mix(atlas_size, uv.xz) * sample_sum;
                highp vec3 sample_moon  = getLUT_mix(atlas_size, uv.yz) * sample_sum;
            #else
                highp vec3 sample_sun   = getLUT(uv.xz) * sample_sum;
                highp vec3 sample_moon  = getLUT(uv.yz) * sample_sum;
            #endif

            temp_rayleigh_scattering_sun     += rayleigh_scattering * sample_sun;
            temp_rayleigh_scattering_moon    += rayleigh_scattering * sample_moon;

            temp_mie_scattering_sun  += mie_scattering * sample_sun * mie_phase_sun;
            temp_mie_scattering_moon += mie_scattering * sample_moon * mie_phase_moon;
        }
        /* Multiple scattering */ {
            
            uv.xy += F_2_16;

            highp vec3 sample_scattering = sample_sum * (rayleigh_scattering + mie_scattering);

            #if defined(REFLECTION) || defined(TERRAIN_FOG)
                multiple_scattering_sun += 
                    sample_scattering * getLUT_mix(atlas_size, uv.xz);
                multiple_scattering_moon += 
                    sample_scattering * getLUT_mix(atlas_size, uv.yz);
            #else
                multiple_scattering_sun     += sample_scattering * getLUT(uv.xz);
                multiple_scattering_moon    += sample_scattering * getLUT(uv.yz);
            #endif
        }
        transmittance *= sample_transmittance;
        x += dx;
    }

    rayleigh_scattering_sun += temp_rayleigh_scattering_sun * rayleigh_phase;
    rayleigh_scattering_moon += temp_rayleigh_scattering_moon * rayleigh_phase;

    mie_scattering_sun += temp_mie_scattering_sun * mie_phase_sun;
    mie_scattering_moon += temp_mie_scattering_moon * mie_phase_moon;
}

highp vec3 getSky(  
                    #if defined(REFLECTION) || defined(TERRAIN_FOG)
                    highp ivec2 atlas_size,
                        #ifdef TERRAIN_FOG
                        highp float t_0,
                        out highp vec3 fog_transmittance,
                        #endif
                    #else
                    highp float time,
                    #endif
                    highp vec3 view, highp vec3 sun ) {

    // Constants

        /*
            pow2(CAMERA_POSITION.y) = pow2(EARTH_RADIUS) + pow2(L)

            L : the distance from the camera to the horizon.

            Cosine value of the angle between the vector from the 
            camera to the zenith and the horizon :

                -L / CAMERA_POSITION.y ~= -0.017731081692341
        */
        bool is_ground = view.y < -0.017731081692341;

        highp float cos_theta = dot(view, sun);

        highp float rayleigh_phase  = getRayleighPhase(cos_theta);
        highp float mie_phase_sun   = getMiePhase(cos_theta, 0.8);
        highp float mie_phase_moon  = getMiePhase(-cos_theta, 0.8);

        #if !defined(REFLECTION) && !defined(TERRAIN_FOG)
            highp float t_0 = 
                getIntersectionLength(
                    CAMERA_POSITION, view, 
                    EARTH_RADIUS, CLOUD_MIN_RADIUS
                );
        #elif defined(REFLECTION)
            highp float t_0 = 
                getIntersectionLength(
                    CAMERA_POSITION, view, 
                    EARTH_RADIUS, ATMOSPHERE_RADIUS
                );
        #endif
        highp float dt_0 = t_0 * 0.25;
        highp vec3 dx_0  = dt_0 * view;

    // Variables
        highp vec3 transmittance = WHITE;

        // Rayleigh Scattering
            highp vec3 rayleigh_scattering_sun  = BLACK;
            highp vec3 rayleigh_scattering_moon = BLACK;

        // Mie Scattering
            highp vec3 mie_scattering_sun   = BLACK;
            highp vec3 mie_scattering_moon  = BLACK;

        // Multiple Scattering
            highp vec3 multiple_scattering_sun  = BLACK;
            highp vec3 multiple_scattering_moon = BLACK;

        highp vec3 x = CAMERA_POSITION + dx_0 * 0.5;

    getAtmosphereScattering(
        #if defined(REFLECTION) || defined(TERRAIN_FOG)
        atlas_size,
        #endif
        sun, dx_0, dt_0, x,
        rayleigh_phase,
        mie_phase_sun,
        mie_phase_moon,
        transmittance,
        rayleigh_scattering_sun,
        rayleigh_scattering_moon,
        mie_scattering_sun,
        mie_scattering_moon,
        multiple_scattering_sun,
        multiple_scattering_moon
    );

    // Clouds
        #if !defined(REFLECTION) && !defined(TERRAIN_FOG)
            if ( !is_ground ) {

                getCloud(
                    view, sun, time, x,
                    mie_phase_sun, mie_phase_moon, 
                    mie_scattering_sun, 
                    mie_scattering_moon, 
                    multiple_scattering_sun,
                    multiple_scattering_moon,
                    transmittance
                );

                highp float t_1 = 
                    getIntersectionLength(
                        x, view, 
                        0.0, ATMOSPHERE_RADIUS
                    );

                highp float dt_1 = t_1 * 0.25;
                highp vec3 dx_1  = dt_1 * view;

                getAtmosphereScattering(
                    sun, dx_1, dt_1, x,
                    rayleigh_phase,
                    mie_phase_sun,
                    mie_phase_moon,
                    transmittance,
                    rayleigh_scattering_sun,
                    rayleigh_scattering_moon,
                    mie_scattering_sun,
                    mie_scattering_moon,
                    multiple_scattering_sun,
                    multiple_scattering_moon
                );
            }
        #endif  // #if !defined(REFLECTION) && !defined(TERRAIN_FOG)

    float is_sky = 1.0 - float(is_ground);

    // Sun, Moon, Starmap
        #ifdef TERRAIN_FOG
            fog_transmittance = transmittance;

            float starmap = 0.0;

            float sun_disk_LDR  = 0.0;
            float moon_disk_LDR = 0.0;
        #else
            transmittance *= is_sky;

            #ifdef REFLECTION
                highp vec3 starmap = read(atlas_size, getStarmapUV(sun, view)).rgb;

                float sun_disk_LDR  = 0.0;
                float moon_disk_LDR = 0.0;
            #else
                highp float sun_disk    = step(0.999989180457106, cos_theta);
                highp float moon_disk   = step(0.999989438255720, -cos_theta);

                highp vec3 starmap = 
                    texture2D(s_MatTexture, getStarmapUV(sun, view)).rgb;

                starmap *= (1.0 - sun_disk) * (1.0 - moon_disk);

                highp vec3 sun_disk_LDR = sun_disk * transmittance;
                highp vec3 moon_disk_LDR = moon_disk * transmittance;
            #endif  // REFLECTION

            gammaToLinear(starmap);

            starmap *= transmittance;

        #endif  // TERRAIN_FOG


    return 
        SUN_LUMINANCE  * (
            sun_disk_LDR +
            rayleigh_scattering_sun +
            mie_scattering_sun +
            multiple_scattering_sun
            ) +
        MOON_LUMINANCE  * (
            moon_disk_LDR +
            rayleigh_scattering_moon +
            mie_scattering_moon +
            multiple_scattering_moon
            ) +
        STARMAP_LUMINANCE * starmap;
}

#endif // HEADER_SKY_SH
