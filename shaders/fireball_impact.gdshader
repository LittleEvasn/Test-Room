shader_type canvas_item;
render_mode blend_mix, unshaded;

// A short expanding FIRE burst, not a permanent fire puddle.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(128.7, 311.7))) * 43758.5453);
}
float noise21(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float theta = atan(p.y, p.x);
    float t = progress;
    float rough = noise21(vec2(theta * 1.9 + seed, t * 3.0))
        + 0.34 * noise21(p * 7.0 - vec2(t * 2.6, t * 2.1));
    float shock_radius = mix(0.15, 0.87, pow(t, 0.65));
    float edge = shock_radius + (rough - 0.60) * 0.18;
    float body = 1.0 - smoothstep(edge - 0.17, edge + 0.09, r);
    float hollow = smoothstep(0.02, shock_radius * 0.62, r);
    float ring = body * mix(1.0, hollow, smoothstep(0.13, 0.57, t));
    float flash = exp(-r * r * 15.0) * (1.0 - smoothstep(0.03, 0.30, t));
    float fade = 1.0 - smoothstep(0.42, 0.98, t);
    float yellow = clamp(1.0 - r / max(edge, 0.04), 0.0, 1.0);
    vec3 rgb = mix(vec3(1.0, 0.33, 0.026),
        vec3(1.0, 0.82, 0.18), yellow * 0.72);
    rgb = mix(rgb, vec3(1.0, 0.99, 0.82), flash + yellow * (1.0 - t) * 0.48);
    float alpha = max(ring * fade * 0.87, flash) * smoothstep(0.0, 0.045, t);
    COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
}
