#version 410 core

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec2 resolution;
uniform float time;

out vec4 finalColor;

void main() {
    vec2 uv = fragTexCoord;
    vec2 px = 1.0 / resolution; // one pixel in UV space

    // Base sample with chromatic aberration
    float ab = 0.003;
    vec4 col;
    col.r = texture(texture0, vec2(uv.x + ab, uv.y)).r;
    col.g = texture(texture0, uv).g;
    col.b = texture(texture0, vec2(uv.x - ab, uv.y)).b;
    col.a = texture(texture0, uv).a;  // was col.a = 1.0;

    // Glow — sample neighbors and add a brightened average
    vec3 glow = vec3(0.0);
    glow += texture(texture0, uv + vec2( px.x * 2.0,  0.0)).rgb;
    glow += texture(texture0, uv + vec2(-px.x * 2.0,  0.0)).rgb;
    glow += texture(texture0, uv + vec2( 0.0,  px.y * 2.0)).rgb;
    glow += texture(texture0, uv + vec2( 0.0, -px.y * 2.0)).rgb;
    glow += texture(texture0, uv + vec2( px.x * 4.0,  0.0)).rgb;
    glow += texture(texture0, uv + vec2(-px.x * 4.0,  0.0)).rgb;
    glow += texture(texture0, uv + vec2( 0.0,  px.y * 4.0)).rgb;
    glow += texture(texture0, uv + vec2( 0.0, -px.y * 4.0)).rgb;
    glow /= 8.0;
    // Tint the glow green like a phosphor monitor
    col.rgb += glow * vec3(0.6, 0.9, 0.5) * 0.8;

    // Soft scanlines — sine wave instead of hard bands
    float scan = sin(uv.y * resolution.y * 3.14159) * 0.5 + 0.5;
    col.rgb *= 0.88 + 0.12 * scan;


    // Vignette
    float dx = uv.x - 0.5;
    float dy = uv.y - 0.5;
    float vig = max(0.6, 1.0 - (dx * dx + dy * dy) * 1.2);
    col.rgb *= vig;

    // Flicker
    col.rgb *= max(0.9, 0.925 + 0.05 * sin(time * 60.0));

    finalColor = col * fragColor;
}