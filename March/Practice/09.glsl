float
sdf_sphere(vec3 p, float r)
{
    return length(p) - r;
}

float
sdf_ground(vec3 p)
{
    return p.y;
}

vec2 
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

#define ID_SPHERE 0.0
#define ID_GROUND 1.0
#define UOP(sdf, id) res = uop(res, vec2(sdf, id))
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdf_ground(p - vec3(0.0, -0.2, 0.0)), ID_GROUND);
    UOP(sdf_sphere(p - vec3(0.1, 0.1, 0.0), 0.25), ID_SPHERE);
    UOP(sdf_sphere(p - vec3(0.1, 0.1, -2.0), 0.25), ID_SPHERE);
    UOP(sdf_sphere(p - vec3(0.7, 0.1, 0.0), 0.25), ID_SPHERE);
    UOP(sdf_sphere(p - vec3(-0.7, 0.1, 0.0), 0.25), ID_SPHERE);

    return res;
}

#define MAX_DIST 200.0
#define MAX_STEP 200
#define MIN_DIST 0.001
vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEP && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + t * rd);

        if(abs(hit.x) < MIN_DIST)
        {
            res = vec2(t, hit.y);
            break;
        }

        t += hit.x;
    }

    return res;
}

vec3
CalcNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(Map(p + e.xyy).x - Map(p - e.xyy).x,
                          Map(p + e.yxy).x - Map(p - e.yxy).x,
                          Map(p + e.yyx).x - Map(p - e.yyx).x
    ));
}

float
CalcSoftShadows(vec3 ro, vec3 rd)
{
    float k = 32.0;
    float n = 1.0;
    for(float t = 0.1; t < MAX_DIST;)
    {
        float h = Map(ro + t *rd).x;

        if(h < MIN_DIST) return 0.0;

        n = min(n, h * k / t);
        t += h;
    }
    return n;
}

vec3
CalcMaterial(float id, vec3 p)
{
    vec3 col = vec3(1.0);

    if(id == ID_GROUND)
    {
        vec2 tile_id = floor(p.xz * 5.0);
        float is_even = mod(tile_id.x + tile_id.y, 2.0);
        col = vec3(is_even) * 0.1 + 0.15;   
    }


    return col;
}

float
CalcAO(vec3 p, vec3 n)
{
    float occlusion = 0.0;
    float intensity = 1.0;
    for(int i = 0; i < 5; ++i)
    {
        float d = 0.01 + 0.12 * float(i) /4.0;
        float h = Map(p + d *n).x;
        occlusion += (d - h)*intensity;
        intensity *= 0.95;
        if (occlusion > 0.35) break;
    }

    return (1.0 - 3.0*occlusion) * (0.5 + 0.5*n.y);
}

vec3
Render(vec3 ro, vec3 rd)
{
    vec3 col = vec3(0.0);

    vec2 res = RayMarch(ro, rd);
    float t =res.x;
    float id = res.y;

    // Sky
    vec3 sky_color = vec3(0.2, 0.4, 0.8);
    if(id < 0.0)
    {
        col = sky_color;
    }
    else
    {
        //Geometry
        vec3 P = ro + t * rd;
        vec3 N = CalcNormal(P);
        vec3 R = reflect(rd, N);

        // Material
        col = CalcMaterial(id, P);

        // Lighting 
        vec3 acc = vec3(0.0);
        vec3 L = normalize(vec3(1.0, 1.0, -1.0));
        vec3 H = normalize(L - rd);

        // Shadowing
        float shadow = CalcSoftShadows(P, L);
        float ao = CalcAO(P, N);

        // Sun shading
        {
            float diffuse = saturate(dot(L, N));
            diffuse *= shadow;
            float specular = pow(saturate(dot(H, N)),64.0);
            float ambient = 0.01;
            //acc += 1.0 * ambient * vec3(1.0, 0.0, 1.0);
            //acc += 1.0 * diffuse * vec3(1.0, 0.8, 0.9);
            //acc += 1.0 * specular * vec3(1.0, 0.8, 0.9);
        }
        
        // Sky shading
        {
            float diffuse = sqrt(saturate(0.5 +0.5*N.y));
            diffuse *= ao;
            float specular = smoothstep(-0.2, 0.2, R.y);
            specular *= diffuse;
            specular *= 0.04+0.96*pow(saturate(1.0 + dot(N, rd)), 5.0);
            specular *= CalcSoftShadows(P, R) * 2.0;
            acc += 1.0 * diffuse * vec3(1.0, 0.8, 0.9) * ao;
            acc += 1.0 * specular * vec3(1.0, 0.8, 0.9);
        }
        col *= acc;
    }

    col = mix(col, sky_color, 1.0 - exp(-0.005*t*t*t));

    return col;
}

mat3
SetCamera(vec3 eye, vec3 target, float roll)
{
    vec3 i,j,k,temp_j;
    k = normalize(target - eye);
    temp_j = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp_j, k));
    j = cross(k, i);

    return mat3(i, j, k);
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
    mat3 camera_to_world = SetCamera(ray_origin, target,roll);

#if AA > 1
    for(int i = 0; i < AA; ++i)
    for(int j = 0; j < AA; ++j)
    {
        vec2 offset = vec2(i, j) / float(AA) - 0.5;
        vec2 uv = ((fragCoord + offset) - 0.5*iResolution.xy) / iResolution.y;
#else 
        vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
#endif

        vec3 ray_direction = camera_to_world * normalize(vec3(uv, near_plane));

        vec3 col = Render(ray_origin, ray_direction);

        col = pow(col, vec3(1.0 / 2.2));
        total += col;
#if AA > 1
    }
    total /= float(AA * AA);
#endif

    fragColor = vec4(total, 1.0);
}