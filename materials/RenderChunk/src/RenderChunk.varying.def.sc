vec4 a_color0       : COLOR0;
vec3 a_position     : POSITION;
vec2 a_texcoord0    : TEXCOORD0;
vec2 a_texcoord1    : TEXCOORD1;

vec4 i_data0    : TEXCOORD7;
vec4 i_data1    : TEXCOORD6;
vec4 i_data2    : TEXCOORD5;

vec4          v_color0      : COLOR0;
centroid vec2 v_texcoord0   : TEXCOORD0;
vec2          v_lightmapUV  : TEXCOORD1;

vec3 v_position     : VPOSITION;
vec3 v_world        : WORLD;
float v_shadow      : SHADOW;
float v_brightness  : BRIGHTNESS;
float v_torchlight  : TORCHLIGHT;
float v_ao          : AO;

vec3 v_sun              : SUN;
float v_day             : DAY;
float v_water           : WATER;
vec3 v_sun_illuminance  : SUN_ILLUMINANCE;
vec3 v_moon_illuminance : MOON_ILLUMINANCE;

vec3 v_ambient_zenith   : AMBIENT_ZENITH;
vec3 v_ambient_horizon  : AMBIENT_HORIZON;
vec3 v_ambient_average  : AMBIENT_AVERAGE;
float v_time            : TIME;
float v_ev              : EV;

vec3 v_fog_transmittance    : FOG_TRANSMITTANCE;
vec3 v_fog_scattering       : FOG_SCATTERING;
