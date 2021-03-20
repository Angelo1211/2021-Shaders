
float
sdf_Sphere(vec3 p, float r)
{
    return length(p) - r;
}

float 
sdf_Ground(vec3 p)
{
    return p.y;
}

#define UOP(sdf, id) res = uop(res, vec2(sdf, id));
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

#define ID_GROUND 0.0
#define ID_SPHERE 1.0
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UOP(sdf_Ground(p - vec3(0.0, -0.5, 0.0)), ID_GROUND);

    UOP(sdf_Sphere(p - vec3(0.1, 0.1, 1.0 + sin(iTime)), 0.25), ID_SPHERE);

    return res;
}

#define MAX_DIST 200.0
#define MIN_DIST 0.001
#define MAX_STEPS 200
vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
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
CalcSoftShadow(vec3 ro, vec3 rd)
{
    float k = 32.0;
    float n = 1.0;

    for(float t = 0.1; t < MAX_DIST;)
    {
        float hit = Map(ro + t*rd).x;

        if (hit < MIN_DIST)
        {
            return 0.0;
        }

        n = min(n, hit * k / t);
        t += hit;
    }
    return n;
}

vec3
Render(vec3 ro, vec3 rd)
{
    // Render output
    vec3 col = vec3(0.0);
    vec3 skyCol = vec3(0.1, 0.1 ,0.8) * 0.3;

    // Raymarch result unpacking
    vec2 res = RayMarch(ro, rd);
    float t = res.x;
    float id = res.y;

    // Sky
    if (id < 0.0)
    {
        col =  skyCol;
    }
    else // Everything else
    {
        // Geometry
        vec3 P = ro + t*rd;
        vec3 N = CalcNormal(P);

        // Material
        if (id == ID_GROUND)
        {
            col = vec3(0.9, 0.5, 0.4);
        }
        else 
        {
            col = vec3(1.0);
        }

        // lighting
        vec3 L = normalize(vec3(1.0, 1.0, 0.0));
        vec3 luminance = vec3(0.0);
        float diffuse = clamp(dot(L, N), 0.0, 1.0);
        float ambient = 0.2;

        // Shadowing
        diffuse *= CalcSoftShadow(P, L);

        // Shading
        luminance += 1.0 * ambient * skyCol;
        luminance += 1.0 * diffuse * vec3(1.0, 0.9, 0.8);
        col *= luminance;
    }

    return col;
}

mat3
SetCamera(vec3 ro, vec3 ta, float roll)
{
    vec3 i, j, k, temp;
    k = normalize(ta - ro);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i = normalize(cross(temp, k));
    j = cross(k, i);

    return mat3(i, j, k);
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    float near_plane = 1.0;
    float roll = 0.0;
    vec3 target = vec3(0.0);
    vec3 ray_origin = target + vec3(0.0, 0.0, -1.0);
    vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
    mat3 camera_to_world = SetCamera(ray_origin, target, roll);
    vec3 ray_direction = camera_to_world * vec3(uv, near_plane);

    vec3 col = Render(ray_origin, ray_direction);

    col = pow(col, vec3(1.0/2.2));
    fragColor = vec4(col, 1.0);
}