
// Expected Resolution: -w 448 -h 748

#define PI 3.1415926535

float 
stroke(float x, float s, float w)
{
    float d = step(s, x + w*0.5f) - step(s, x - w*0.5f);
    return clamp(d, 0.0, 1.0);
}

float
circleSDF(vec2 st)
{
    return length(st - 0.5)*2.0;
}

// Card 08
// 
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.0);
    vec2 uv = (fragCoord) / iResolution.y;

    col += stroke(circleSDF(uv), .5 , 0.05);

    fragColor = vec4(col, 1.0);
}