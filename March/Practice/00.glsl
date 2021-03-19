float
sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float
sdGround(vec3 p)
{
    return p.y;
}

#define UNION(sdf, ID) res = uop(res, vec2(sdf, ID));
vec2
uop(vec2 a, vec2 b)
{
    return (a.x < b.x) ? a : b;
}

#define ID_SPHERE 0.0
#define ID_GROUND 1.0
vec2
Map(vec3 p)
{
    vec2 res = vec2(1e10, -1.0);

    UNION(sdSphere(p - vec3(0.0 , 0.0 , 1.0 ), 0.25), ID_SPHERE);
    UNION(sdGround(p - vec3(0.0 , -0.2 , 1.0)), ID_GROUND);

    return res;
}

#define MAX_DIST 200.0
#define MIN_DIST 0.0001
#define MAX_STEPS 200
vec2
RayMarch(vec3 ro, vec3 rd)
{
    vec2 res = vec2(-1.0);
    float t = 0.0;

    for(int i = 0; i < MAX_STEPS && t < MAX_DIST; ++i)
    {
        vec2 hit = Map(ro + t * rd);

        if (abs(hit.x) < t * MIN_DIST )
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
    // Ofset the ray from ground
    for (float t = 50.0 *MIN_DIST; t < MAX_DIST;)
    {
        float hit = Map(ro + t*rd).x;

        if (hit < MIN_DIST)
            return 0.0;

        t += hit;
    }

    return 1.0;
}

vec3
Render(vec3 ro, vec3 rd)
{
    // Ray marching 
    vec3  col = vec3(0.0);
    vec2  res = RayMarch(ro, rd);
    float t   = res.x;
    float id  = res.y;

    // Sky
    if (id < 0.0)
    {
        col = vec3(0.0, 0.0, 1.0);
    }
    else // Everything else
    {
        // Geometry
        vec3 P = ro + t * rd;
        vec3 N = CalcNormal(P);

        // Material

        // Lighting
        vec3  L         = normalize(vec3(1.0, 1.0, 0.0));
        vec3  luminance = vec3(0.0);
        float diffuse   = saturate(dot(N, L));
        float ambient  = 0.1;

        // Shadowing
        diffuse *= CalcSoftShadow(P, L);

        // Shading
        luminance += 1.00 * ambient * vec3(0.0, 0.3, 0.9);
        luminance += 1.00 * diffuse * vec3(1.2, 0.8, 0.4);
        col += luminance;
    }

    return col;
}

mat3
SetCamera(vec3 ray_origin, vec3 target, float roll)
{
    vec3 i, j, k, temp;

    k    = normalize(target - ray_origin);
    temp = normalize(vec3(sin(roll), cos(roll), 0.0));
    i    = normalize(cross(temp, k));
    j    = cross(k, i);

    return mat3(i, j ,k);
}

void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // Camera setup
    float near_plane      = 1.0;
    float roll            = 0.0;
    vec3  target          = vec3(0.0);
    vec3  ray_origin      = target + vec3(0.0, 0.0, -0.1);
    mat3  camera_to_world = SetCamera(ray_origin, target, roll);

    vec2 uv = ((fragCoord) - 0.5*iResolution.xy) / iResolution.y;
    vec3 ray_direction = camera_to_world * vec3(uv, near_plane);

    vec3 col = Render(ray_origin, ray_direction);

    col = pow(col, vec3(0.454545));
    fragColor = vec4(col, 1.0);
}