/*
    <BRDF>
    Source
        https://learnopengl.com/PBR/Lighting
    License
        CC BY-NC 4.0
        https://github.com/JoeyDeVries/LearnOpenGL?tab=License-1-ov-file#readme
*/

#ifndef HEADER_BRDF_SH
#define HEADER_BRDF_SH

highp float FresnelSchlick( highp float VoH, highp float F0 ) {
    return F0 + (1.0 - F0) * pow5(1.0 - VoH);
}

highp float DistributionGGX( highp float NoH, highp float roughness ) {

    highp float a       = roughness * roughness;
    highp float a2      = a * a;
    highp float NoH2    = NoH*NoH;
	
    highp float num     = a2;
    highp float denom   = (NoH2 * (a2 - 1.0) + 1.0);
    
    denom = PI * denom * denom;
	
    return num / denom;
}

highp float GeometrySchlickGGX( highp float NoV, highp float roughness ) {

    highp float r = (roughness + 1.0);
    highp float k = (r * r) / 8.0;
	
    return NoV / (NoV * (1.0 - k) + k);
}

highp float GeometrySmith( highp float NoV, highp float NoL, highp float roughness ) {

    highp float ggx2 = GeometrySchlickGGX(NoV, roughness);
    highp float ggx1 = GeometrySchlickGGX(NoL, roughness);
	
    return ggx1 * ggx2;
}

#endif