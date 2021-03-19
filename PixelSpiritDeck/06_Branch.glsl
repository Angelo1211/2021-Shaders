// Expected Resolution: -w 448 -h 748

#define PI 3.1415926535

float 
stroke(float x, float s, float w)
{
    float d = step(s, x + w*0.5f) - step(s, x - w*0.5f);
    return clamp(d, 0.0, 1.0);
}

// Card 06
// Branch
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.0);
    vec2 uv = fragCoord / iResolution.xy;

    float sdf = (uv.x - uv.y) * 0.5 + 0.5;
    col += stroke(sdf, .5 , 0.1);

    fragColor = vec4(col, 1.0);
}