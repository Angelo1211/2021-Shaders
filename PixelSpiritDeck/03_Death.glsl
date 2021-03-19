// Expected Resolution: -w 448 -h 748

#define PI 3.1415926535

// Card 03
// Death
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.0);
    vec2 uv = fragCoord / iResolution.xy;

    col += step(.5, (uv.y+ uv.x) * 0.5);

    fragColor = vec4(col, 1.0);
}