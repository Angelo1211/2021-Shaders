#include "common.glsl"
vec2
Map(vec3 p)
{
    vec2 res = vec2(MAX_DIST, -1.0);

    UOP(sdf_ground(p - vec3(0.0, -0.2, 0.0)), ID_GROUND);
    UOP(sdf_sphere(p - vec3(0.1, 0.1, 0.0), 0.25), ID_SPHERE);

    return res;
}



vec3
CalcMaterial(float id, vec3 P)
{
    vec3 col = vec3(1.0);

    if(id == ID_GROUND)
    {
        vec2 tile_id = floor(P.xz * 5.0);
        float is_even = mod(tile_id.x + tile_id.y,2.0);
        col = vec3(is_even) * 0.1 + 0.15;
    }

    return col;
}

DEF_SOFT_SHADOW()
DEF_AO()
DEF_NORMAL()
DEF_RAY_MARCH()

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec2 res = Ray_March(ro, rd);
    float t = res.x;
    float id= res.y;

    vec3 sky_color = vec3(0.2, 0.4, 0.8);
    if(id < 0.0)
    {
        col = sky_color;
    }
    else
    {
        // Geometry 
        vec3 P = ro + t*rd;
        vec3 N = Calc_Normal(P);

        // Material
        col = CalcMaterial(id, P);

        // Lighting
        vec3 L = normalize(vec3(1.0, 1.0, -1.0));
        vec3 H = normalize(L - rd);
        vec3 acc = vec3(0.0);

        // Shadowing
        float shadow = Calc_Soft_Shadow(P, L);
        float ao = Calc_AO(P, N);

        // Sun shading
        {
            vec3  sun_color  = vec3(1.0, 0.8, 0.7);
            float diffuse    = saturate(dot(N, L));
            diffuse *= shadow;
            float ambient    = 0.01;
            float specular   = pow(saturate(dot(H, N)), 64.0);
                  acc       += 1.0 * diffuse * sun_color;
                  acc       += 1.0 * specular * sun_color;
                  acc       += 1.0 * ambient * vec3(1.0, 0.0, 1.0);
        }

        // Sky shading
        {
            float diffuse  = sqrt(saturate(0.5 + 0.5*N.y));
                  diffuse *= ao;
                  acc     += 1.0 * diffuse * sky_color;
        }


        col *= acc;
    }

    col = mix(col, sky_color, 1.0 - exp(-0.06*t*t*t));

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
    mat3 camera_to_world = Set_Camera(ray_origin, target, roll);

#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j)/float(AA) - 0.5;
        vec2 uv = ((fragCoord + offset) - 0.5*iResolution.xy) / iResolution.y;
#else 
        vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
#endif
        vec3 ray_direction = camera_to_world * vec3(uv, near_plane);

        vec3 col = Render(ray_origin, ray_direction);

        col = pow(col, vec3(1.0 / 2.2));

        total += col;

#if AA > 1
    }
    total /= float(AA * AA);
#endif

    fragColor = vec4(total, 1.0);
}