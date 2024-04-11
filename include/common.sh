#ifndef HEADER_COMMON_SH
#define HEADER_COMMON_SH

// Constants

    #define PI          3.141592653589793
    #define TWO_PI      6.283185307179586
    #define FOUR_PI     12.566370614359173
    #define F_1_FOUR_PI 0.079577471545948
    #define F_1_TWO_PI  0.159154943091895
    #define F_1_PI      0.318309886183791

    #define F_1_4096    0.000244140625
    #define F_1_1200    0.000833333333333
    #define F_1_256     0.00390625
    #define F_1_255     0.003921568627451
    #define F_1_32      0.03125
    #define F_1_16      0.0625
    #define F_1_15      0.066666666666667
    #define F_2_16      0.125
    #define F_1_7       0.142857142857143
    #define F_4_16      0.25
    #define F_1_3       0.333333333333333
    #define F_6_16      0.375
    #define F_7_16      0.4375
    #define F_15_16     0.9375
    #define F_255_256   0.99609375
    #define F_16_15     1.066666666666667

    #define GAMMA       2.2
    #define F_1_GAMMA   0.454545454545455

    #define MAX_EV      13.0

    #define BLACK       vec3(0.00, 0.00, 0.00)
    #define GRAY        vec3(0.18, 0.18, 0.18)
    #define WHITE       vec3(1.00, 1.00, 1.00)

    #define F_GRAY_PI   vec3(0.057295779513082, 0.057295779513082, 0.057295779513082)

highp float pow2( highp float x ) {
    return x * x;
}

highp float pow3( highp float x ) {
    return x * x * x;
}

highp float pow4( highp float x ) {
    x *= x;
    return x * x;
}

highp float pow5( highp float x ) {
    highp float p2 = x * x;
    return p2 * p2 * x;
}

highp float linearstep( highp float a, highp float b, highp float x ) {
    return clamp((a - x) / (a - b), 0.0, 1.0);
}

// Color Management

    highp float luminance( highp vec3 RGB ) {
        return dot(RGB, vec3(0.2126f, 0.7152f, 0.0722f));
    }

    void gammaToLinear( inout highp vec3 LDR ) {
        LDR = pow(LDR, vec3_splat(GAMMA));
    }

    void linearToGamma( inout highp vec3 LDR ) {
        LDR = pow(LDR, vec3_splat(F_1_GAMMA));
    }

    void applyDithering( inout highp vec3 LDR, vec3 dither ) {
        LDR = clamp(floor(LDR * 255.0 + dither) * F_1_255, 0.0, 1.0);
    }

    
// Key Functions

    float getEV( float sun_y ) {
        return mix(MAX_EV, 1.0, smoothstep(-0.1, 0.1, sun_y));
    }

    // Sun
        /*
            fog_start : FogAndDistanceControl.x * FogAndDistanceControl.z * 0.02

                day         : 0.04
                noon        : 0.25
                sunset      : 0.50
                night       : 0.54
                midnight    : 0.75
                sunrise     : 0.96
                
                -> fog_start * TWO_PI 
                --------------------
                default     : 1.20

            time : ViewPositionAndTime.w

            * in vertex shader *
        */
        highp float getDayTimeRadian( highp float fog_start_fixed, highp float time ) {
            if ( fog_start_fixed < 1.1 ) return fog_start_fixed * TWO_PI;
            return time * TWO_PI * F_1_1200;
        }

        highp vec3 getSunVector( highp float fog_start_fixed, highp float time ) {
            
            highp float angle = getDayTimeRadian(fog_start_fixed, time);

            highp vec2 sc = vec2( sin(angle), cos(angle) );
            return vec3(sc.y, sc.x * 0.8, sc.x * 0.6);
        }
        
#endif  // HEADER_COMMON_SH