#include "April/common.glsl"

vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdf_sphere(p -  vec3(0.1, 0.1, 0.0), 0.25), ID_SPHERE);
    UOP(sdf_sphere(p -  vec3(-0.4, 0.1, -0.3+ sin(iTime)), 0.15), ID_SPHERE);
    UOP(sdf_ground(p -  vec3(0.0, -0.2, 0.0)), ID_GROUND);

    return res;
}

DEF_EVERYTHING()

vec3
Calc_Material(float id, vec3 P)
{
    vec3 col = vec3(1.0);

    if(id == ID_GROUND) col = DEFAULT_FLOOR_TILE_SHADING();

    if(id == ID_SPHERE) col = vec3(0.9, 0.8, 0.4);

    return col;
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec3 V = -rd;
    vec2 res = Ray_March(ro, rd);
    float t = res.x;
    float id = res.y;

    vec3 sky_col = vec3(0.2, 0.4, 0.8);
    if(id < 0.0)
    {
        col = sky_col;
    }
    else
    {
        // Geometry
        vec3 P = ro + t *rd;
        vec3 N = Calc_Normal(P);
        vec3 R = reflect(rd, N);

        // Material
        col = Calc_Material(id, P);

        // Lighting
        vec3 L = normalize(vec3(1.0, 1.0, -1.0));
        vec3 H = normalize(L + V);
        vec3 acc = vec3(0.0);

        // Shadowing
        float shadow = Calc_Soft_Shadow(P, L);
        float ao = Calc_AO(P, N);

        // Sun
        {
            vec3 sun_col = vec3(1.0, 0.8, 0.8);
            float diffuse = saturate(dot(N, L));
            diffuse *= shadow;
            float specular = pow(saturate(dot(H, N)), 64.0);
            float ambient = 0.01;
            acc += 1.0 * ambient * MAGENTA;
            acc += 1.0 * diffuse * sun_col;
            acc += 1.0 * specular * sun_col;
        }

        // Sky
        {
            float diffuse = sqrt(saturate(ZERO_TO_ONE(N.y)));
            diffuse *= ao;
            float specular = smoothstep(-0.2, 0.2, R.y);
            specular *= diffuse;
            specular *= Fresnel_Shlick(N, V);
            specular *= Calc_Soft_Shadow(P, R) * 2.0;
            acc += 1.0 * diffuse * sky_col;
            acc += 1.0 * specular * sky_col;
        }

        col *= acc;
    }

    col = mix(col, sky_col, 1.0 - exp(-0.005*t*t*t));

    return col;
}

#define AA 2
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 total = vec3(0.0);

    float near_plane = 1.0;
    float roll = 0.0;
    vec3 target = vec3(0.0);
    vec3 ray_origin = target + vec3(0.0, 0.0, -1.0);
    mat3 camera_to_ray = Set_Camera(ray_origin, target, roll);

#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv = UV(fragCoord + offset);
#else
        vec2 uv = UV(fragCoord);
#endif
        vec3 ray_direction = camera_to_ray * normalize(vec3(uv, near_plane));

        vec3 col = Render(ray_origin, ray_direction);

        GAMMA(col);

        total += col;
#if AA > 1
    }
    total /= float(AA * AA);
#endif
    fragColor = vec4(total, 1.0);
}