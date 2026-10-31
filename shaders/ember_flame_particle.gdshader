shader_type canvas_item;
render_mode blend_mix, unshaded;

// Per-particle procedural flame. No fixed 5-tongue silhouette.
// INSTANCE_CUSTOM.y = each particle's normalized age in Godot 4.
uniform float variation = 0.0;
uniform float core_layer : hint_range(0.0, 1.0) = 0.0;
varying float flame_age;
varying float flame_seed;

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
}

void fragment() {
    vec4 particle_tint = COLOR;
    float age = flame_age;
    float phase = flame_seed * 17.0 + variation * 0.27;

    // A different, constantly eroding blob for every particle.
    vec2 uv = (UV - vec2(0.5)) * 2.0;
    float breakup = noise21(uv * 3.3 + vec2(phase, -TIME * 4.3 - age));
    float fold = noise21(uv * 5.0 + vec2(phase * 0.6, -TIME * 2.8 + age * 2.2));
    uv.x += (breakup - 0.5) * 0.36 + (fold - 0.5) * 0.12;
    uv.y += (fold - 0.5) * 0.21;

    float dist = length(vec2(uv.x * 1.10, uv.y * 0.88));
    float edge = dist + (breakup - 0.5) * 0.30;
    float silhouette = 1.0 - smoothstep(0.56, 0.98, edge);

    // Tear the ascending half into smaller fragments near the end.
    float upper_half = 1.0 - smoothstep(-0.5, 0.24, uv.y);
    float erosion = smoothstep(0.22, 0.64, fold);
    float breakup_weight = smoothstep(0.37, 0.93, age) * upper_half;
    silhouette *= mix(1.0, erosion, breakup_weight * 0.77);

    float fade_in = smoothstep(0.0, 0.11, age);
    float fade_out = 1.0 - smoothstep(0.61, 0.99, age);
    float alpha = silhouette * fade_in * fade_out;
    alpha *= mix(0.89, 1.0, breakup);

    float heart = 1.0 - smoothstep(0.13, 0.66, dist);
    float lower_half = smoothstep(-0.45, 0.75, uv.y);
    float brightness = heart * (0.42 + 0.58 * lower_half) * (1.0 - age * 0.48);
    vec3 outer = vec3(0.79, 0.155, 0.025);
    vec3 orange = vec3(1.0, 0.42, 0.045);
    vec3 gold = vec3(1.0, 0.77, 0.17);
    vec3 pale = vec3(1.0, 0.94, 0.57);
    vec3 rgb = mix(outer, orange, 0.42 + 0.45 * (1.0 - dist));
    rgb = mix(rgb, gold, clamp(brightness * (0.64 + 0.30 * core_layer), 0.0, 1.0));
    rgb = mix(rgb, pale, clamp(brightness * core_layer * 0.49, 0.0, 0.65));

    COLOR = vec4(rgb * particle_tint.rgb, alpha * particle_tint.a);
}
