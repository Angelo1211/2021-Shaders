// Expected Resolution: -w 448 -h 748

// Card 01
// Justice
void
mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec3 col = vec3(0.0);
    vec2 uv = fragCoord / iResolution.xy;

    col += step(.5, uv.x);

    fragColor = vec4(col, 1.0);
}