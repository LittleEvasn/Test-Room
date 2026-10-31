shader_type canvas_item;
render_mode blend_mix, unshaded;

// A soft, irregular fire blob, not a rectangular particle sprite.
// Explicitly use TEXTURE alpha: the GPU texture's transparent edge is a
// robust second mask on top of the procedural flame silhouette.
uniform float variation = 0.0;
uniform float heat_level : hint_range(0.0, 2.0) = 0.0;
varying float flame_age;
varying float flame_seed;
varying vec4 vertex_tint;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}
void vertex() {
    flame_age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
    flame_seed = hash21(vec2(float(INSTANCE_ID) + 0.5, variation));
    vertex_tint = COLOR;
}
void fragment() {
    float age = flame_age;
    float phase = flame_seed * 19.0 + variation * 0.31;
    vec2 uv = (UV - 0.5) * 2.0;

    // Two differently scrolling noise fields continuously erode each blob.
    float n1 = noise21(uv * 3.2 + vec2(phase, -TIME * 3.9 - age * 1.2));
    float n2 = noise21(uv * 5.1 + vec2(phase * 0.61, -TIME * 2.6 + age * 2.8));
    vec2 warped = uv;
    warped.x += (n1 - 0.5) * 0.32 + (n2 - 0.5) * 0.12;
    warped.y += (n2 - 0.5) * 0.17;

    float dist = length(vec2(warped.x * 1.07, warped.y * 0.92));
    float edge = dist + (n1 - 0.5) * 0.25;
    float body = 1.0 - smoothstep(0.51, 0.98, edge);

    float upper = 1.0 - smoothstep(-0.54, 0.18, warped.y);
    float breakup = smoothstep(0.17, 0.67, n2);
    float tear = smoothstep(0.30, 0.87, age) * upper * 0.66;
    body *= mix(1.0, breakup, tear);

    // Always mask with the source alpha. The original opaque white quad
    // was able to show up as a square; this can no longer happen.
    vec2 mask_uv = clamp(UV + (warped - uv) * 0.11, vec2(0.0), vec2(1.0));
    float tex_alpha = texture(TEXTURE, mask_uv).a;
    float appear = smoothstep(0.0, 0.11, age);
    float fade = 1.0 - smoothstep(0.58, 0.99, age);
    float alpha = body * tex_alpha * appear * fade * vertex_tint.a;

    // Most of the visible body is now yellow/orange, not brick-red.
    float heart = 1.0 - smoothstep(0.12, 0.78, dist);
    float base_strength = 0.53 + 0.47 * heart;
    float heat = clamp(base_strength * (1.0 - age * 0.27), 0.0, 1.0);
    vec3 warm_outer = vec3(1.0, 0.42, 0.075);
    vec3 orange = vec3(1.0, 0.69, 0.16);
    vec3 golden = vec3(1.0, 0.87, 0.39);
    vec3 cream = vec3(1.0, 0.97, 0.75);
    vec3 white_hot = vec3(1.0, 0.995, 0.92);

    vec3 rgb = mix(warm_outer, orange, clamp(0.43 + 0.48 * heat, 0.0, 1.0));
    rgb = mix(rgb, golden, clamp(0.17 + heat * (0.30 + 0.28 * min(heat_level, 1.0)), 0.0, 1.0));
    if (heat_level > 0.5) {
        float center = (0.34 + 0.66 * heart) * (1.0 - age * 0.20);
        rgb = mix(rgb, cream, clamp(center * (0.40 + 0.23 * (heat_level - 1.0)), 0.0, 0.8));
    }
    if (heat_level > 1.5) {
        rgb = mix(rgb, white_hot, clamp(heart * 0.75 + 0.21, 0.0, 0.94));
    }
    COLOR = vec4(rgb * vertex_tint.rgb, alpha);
}
