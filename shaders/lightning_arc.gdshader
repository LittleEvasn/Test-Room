shader_type canvas_item;
render_mode blend_add, unshaded;

// Reference: FencerDevLog, "Lightning", https://godotshaders.com/shader/lightning/
// Original shader/snippets: CC0. Adapted for a horizontal, endpoint-anchored,
// transparent, unbranched Godot 4.6 gameplay VFX.
// One continuous fBm displacement field; NO recursive branches or extra bolts.

uniform vec3 arc_color : source_color = vec3(0.18, 0.53, 1.0);
uniform float offset_strength : hint_range(0.0, 0.45) = 0.16;
uniform float core_width : hint_range(0.001, 0.04) = 0.009;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float speed : hint_range(0.0, 10.0) = 2.4;
uniform float phase_offset = 0.0;
uniform float life_alpha : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
    vec2 cell = floor(p);
    vec2 local_uv = fract(p);
    vec2 blend_uv = local_uv * local_uv * (3.0 - 2.0 * local_uv);
    float a = hash21(cell);
    float b = hash21(cell + vec2(1.0, 0.0));
    float c = hash21(cell + vec2(0.0, 1.0));
    float d = hash21(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, blend_uv.x), mix(c, d, blend_uv.x), blend_uv.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise2(p);
        p *= 2.03;
        amplitude *= 0.5;
    }
    return value / 0.96875;
}

void fragment() {
    float progress = UV.x;
    float time = TIME * speed;
    float broad = fbm(vec2(progress * 6.0 + phase_offset, time)) - 0.5;
    float fine = fbm(vec2(progress * 26.0 - phase_offset * 0.31, time * 1.75)) - 0.5;

    // Zero displacement at both endpoints, so the arc reaches the cast and aim positions.
    float envelope = pow(max(sin(progress * 3.14159265), 0.0), 0.7);
    float displacement = (broad * 1.2 + fine * 0.32) * offset_strength * envelope;
    float distance_to_bolt = abs(UV.y - 0.5 - displacement);

    float core = 1.0 - smoothstep(core_width * 0.30, core_width * 1.3, distance_to_bolt);
    float inner = exp(-2.1 * pow(distance_to_bolt / (core_width * 4.0), 1.6));
    float aura = exp(-3.0 * pow(distance_to_bolt / 0.14, 1.25));

    float flicker = clamp(0.87 + 0.09 * sin(TIME * 65.0 + phase_offset)
        + 0.04 * sin(TIME * 121.0 + phase_offset * 2.0), 0.70, 1.0);
    float edge = smoothstep(0.0, 0.008, progress)
        * (1.0 - smoothstep(0.992, 1.0, progress));

    float opacity = clamp(core * 0.98 + inner * 0.60
        + aura * 0.17 * glow_strength, 0.0, 1.0);
    vec3 color = mix(arc_color, vec3(0.94, 0.97, 1.0), core);
    COLOR = vec4(color, opacity * life_alpha * flicker * edge);
}
