#version 410 core

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec2 resolution;
uniform float time;

out vec4 finalColor;

// ============ TUNABLES ============
const float CURVATURE  = 0.018;
const float SCANLINES  = 120.0;
const float SCAN_DEPTH = 0.6;
const float BLOOM      = 0.5;
const float VIGNETTE   = 0.3;
const float FLICKER    = 0.10;
// ==================================

vec2 curveUV(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    float ax = abs(uv.x) / 3.0;
    float ay = abs(uv.y) / 3.0;
    uv.x *= 1.0 + (ay * ay) * CURVATURE * 1.25;
    uv.y *= 1.0 + (ax * ax) * CURVATURE * 4;
    return uv * 0.5 + 0.5;
}

void main() {
    vec2 uv = curveUV(fragTexCoord);

    vec2 px = 1.0 / vec2(textureSize(texture0, 0));

    // Clean single sample — NO chromatic aberration (monochrome tube)
    vec4 col = texture(texture0, uv);

    // Glow / phosphor halation
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
    col.rgb += glow * vec3(0.6, 0.9, 0.5) * BLOOM;

    // Intensity-aware scanlines
    float lum  = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    float beam = mix(0.16, 0.34, clamp(lum, 0.0, 1.0));
    float pos  = fract(uv.y * SCANLINES) - 0.5;
    float scan = exp(-(pos * pos) / (2.0 * beam * beam));
    col.rgb *= mix(1.0, scan, SCAN_DEPTH);

    // Vignette
    vec2 vd = uv - 0.5;
    col.rgb *= clamp(1.0 - dot(vd, vd) * VIGNETTE, 0.0, 1.0);

    // Flicker
    col.rgb *= 1.0 - FLICKER + FLICKER * sin(time * 120.0);

    finalColor = col * fragColor;
}