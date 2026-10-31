shader_type canvas_item;
render_mode blend_mix, unshaded;

// Ground heat ONLY. The moving flames are independent GPU particles.
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float variation = 0.0;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 p = (UV - vec2(0.5, 0.55)) * vec2(2.0, 3.1);
    float n = noise21(p * 3.8 + vec2(variation, TIME * 1.5));
    float radius = length(p);
    float soft_edge = 1.0 - smoothstep(0.40, 1.13, radius + (n - 0.5) * 0.23);
    float hot_spot = exp(-4.0 * dot(p, p));
    float breathing = 0.90 + 0.10 * sin(TIME * 7.3 + variation);
    float appear = smoothstep(0.0, 0.07, life);
    float vanish = 1.0 - smoothstep(0.74, 1.0, life);
    float alpha = (soft_edge * 0.19 + hot_spot * 0.25) * breathing * appear * vanish;
    vec3 rgb = mix(vec3(0.82, 0.18, 0.025), vec3(1.0, 0.60, 0.11), hot_spot);
    COLOR = vec4(rgb, alpha);
}
