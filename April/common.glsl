// -------------------------------------------------------------------------------------------------------
// DEFINES
// -------------------------------------------------------------------------------------------------------
#define SHADERTOY 0

#define MAX_DIST 200.0
#define MAX_STEP 200
#define MIN_DIST 0.001
#define M_PI acos(-1)

// -------------------------------------------------------------------------------------------------------
// UTILITY
// -------------------------------------------------------------------------------------------------------
#define GAMMA(col) col = pow(col,vec3(1.0/2.2))
#define UV(coord) ((coord) - 0.5*iResolution.xy) / iResolution.y
#define ZERO_TO_ONE(val) (0.5 + 0.5 * val)
#define DEF_EVERYTHING()\
DEF_AO()\
DEF_NORMAL()\
DEF_RAY_MARCH()\
DEF_SOFT_SHADOW()

// -------------------------------------------------------------------------------------------------------
// SDF FUNCTIONS
// -------------------------------------------------------------------------------------------------------
float
sdf_ground(vec3 p)
{
    return p.y;
}

float 
sdf_sphere(vec3 p, float r)
{
    return length(p) - r;
}

// -------------------------------------------------------------------------------------------------------
// SDF OPERATORS
// -------------------------------------------------------------------------------------------------------
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

// NOTE(AO): I always use res for my return value in Map()
#define UOP(sdf, id) res = uop(res, vec2(sdf, id))

// -------------------------------------------------------------------------------------------------------
// GEOMETRY
// -------------------------------------------------------------------------------------------------------
#define DEF_NORMAL()                                          \
vec3                                                          \
Calc_Normal(vec3 p)                                           \
{                                                             \
    vec2 e = vec2(0.001, 0.0);                                \
                                                              \
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,\
                          Map(p + e.yxy).x - Map(p - e.yxy).x,\
                          Map(p + e.yyx).x - Map(p - e.yyx).x \
    ));                                                       \
}


// -------------------------------------------------------------------------------------------------------
// RAY MARCHING
// -------------------------------------------------------------------------------------------------------
#define DEF_RAY_MARCH()                                      \
vec2                                                         \
Ray_March(vec3 ro, vec3 rd)                                  \
{                                                            \
    vec2 res = vec2(-1.0);                                   \
    float t = 0.0;                                           \
                                                             \
    for(int i = 0; i < MAX_STEP && t < MAX_DIST; ++i)        \
    {                                                        \
        vec2 hit = Map(ro + t *rd);                          \
                                                             \
        if(abs(hit.x) < MIN_DIST)                            \
        {                                                    \
            res = vec2(t, hit.y);                            \
            break;                                           \
        }                                                    \
                                                             \
        t += hit.x;                                          \
    }                                                        \
                                                             \
    return res;                                              \
}

// -------------------------------------------------------------------------------------------------------
// MATERIAL IDs
// -------------------------------------------------------------------------------------------------------
#define ID_SPHERE 1.0
#define ID_GROUND 0.0

// -------------------------------------------------------------------------------------------------------
// COLOURS
// -------------------------------------------------------------------------------------------------------
#define MAGENTA vec3(1.0, 0.0, 1.0)

// -------------------------------------------------------------------------------------------------------
// SHADING
// -------------------------------------------------------------------------------------------------------
float
Fresnel_Shlick(vec3 N, vec3 V)
{
    return pow(clamp(1.0 - dot(N, V), 0.0, 1.0), 5.0);
}

#define DEFAULT_FLOOR_TILE_SHADING() Shade_Floor_Tile(P.xz, 5.0, vec3(0.1), vec3(0.25))
vec3
Shade_Floor_Tile(vec2 p, float frequency, vec3 col_1, vec3 col_2)
{
    vec2 tile_id = floor(p.xy * frequency);
    float is_even = mod(tile_id.x + tile_id.y, 2.0);
    return is_even *col_1 + (1.0 - is_even)*col_2;
}

// -------------------------------------------------------------------------------------------------------
// CAMERA
// -------------------------------------------------------------------------------------------------------
mat3
Set_Camera(vec3 eye, vec3 target, float roll)
{
    vec3 i, j, k, temp_j;
    k = normalize(target - eye);
    temp_j = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp_j, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

// -------------------------------------------------------------------------------------------------------
// VISIBILITY
// -------------------------------------------------------------------------------------------------------

#define DEF_AO()                                     \
float                                                \
Calc_AO(vec3 P, vec3 N)                              \
{                                                    \
    float occlusion = 0.0;                           \
    float intensity = 1.0;                           \
                                                     \
    for(int i = 0; i < 5; ++i)                       \
    {                                                \
        float h = 0.01 + 0.12 * float(i) / 4.00;     \
        float d = Map(P + N *h).x;                   \
        occlusion += (h - d) * intensity;            \
        intensity *= 0.95;                           \
        if (occlusion > 0.35) break;                 \
    }                                                \
                                                     \
    return (1.0 - 3.0 * occlusion) * (0.5 + 0.5*N.y);\
}


#define DEF_SOFT_SHADOW()            \
float                                \
Calc_Soft_Shadow(vec3 ro, vec3 rd)   \
{                                    \
    float n = 1.0;                   \
    float k = 32.0;                  \
    for(float t = 0.1; t < MAX_DIST;)\
    {                                \
        float h = Map(ro + t *rd).x; \
                                     \
        if(h < MIN_DIST) return 0.0; \
        n = min(n, h * k / t);       \
                                     \
        t += h;                      \
    }                                \
                                     \
    return n;                        \
}