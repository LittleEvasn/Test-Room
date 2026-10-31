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

// Optional distance-safe, slow body motion for slot 9.
// Defaults are disabled to preserve slot 7's existing strike appearance.
uniform float arc_length_px = 1100.0;
uniform float distance_adaptation : hint_range(0.0, 1.0) = 0.0;
uniform float body_crawl : hint_range(0.0, 1.0) = 0.0;

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

    // The earlier UV-only frequencies caused 26 tiny bends even on a 30px bolt.
    // In slot 9, the number of bends now follows its physical screen length.
    float frequency_ratio = clamp(arc_length_px / 950.0, 0.04, 1.50);
    // Preserve a few visible curves even when the bolt spans only a short distance.
    // A strict proportional frequency could make close-range fBm nearly straight.
    float broad_frequency = mix(6.0, clamp(6.0 * frequency_ratio, 2.0, 9.0), distance_adaptation);
    float fine_frequency = mix(26.0, clamp(26.0 * frequency_ratio, 5.0, 39.0), distance_adaptation);

    float broad = fbm(vec2(progress * broad_frequency + phase_offset,
        time * mix(1.0, 0.64, body_crawl))) - 0.5;
    float fine = fbm(vec2(progress * fine_frequency - phase_offset * 0.31,
        time * mix(1.75, 1.35, body_crawl))) - 0.5;

    // A separate, slower drifting noise field bends the body organically.
    // Keep its contribution optional: slot 7 uses the original lightning.
    float flowing = 0.0;
    if (body_crawl > 0.001) {
        flowing = fbm(vec2(
            progress * max(broad_frequency * 0.60, 0.45)
                + phase_offset * 0.13 - time * 0.36,
            time * 0.34)) - 0.5;
    }
    float original_shape = broad * 1.2 + fine * 0.32;
    float crawling_shape = broad * 1.10 + flowing * 1.22 + fine * 0.12;
    float shape = mix(original_shape, crawling_shape, body_crawl);

    // Preserve both endpoints while retaining visible writhing at short range.
    // Square-root distance scaling is gentler than the old linear 1/290 rule.
    // This limits exaggerated loops without flattening close-range arcs.
    float envelope = pow(max(sin(progress * 3.14159265), 0.0), 0.7);
    float amplitude_scale = mix(1.0,
        clamp(sqrt(max(arc_length_px, 0.0) / 290.0), 0.23, 1.0),
        distance_adaptation);
    float displacement = shape * offset_strength * envelope * amplitude_scale;
    float distance_to_bolt = abs(UV.y - 0.5 - displacement);

    // Core thickness, inner glow and outer glow must remain independent of
    // endpoint distance. Scaling them made short lightning thin and washed out.
    // This same expression matches the previous slot-7 rendering at defaults.
    float core = 1.0 - smoothstep(core_width * 0.30,
        core_width * 1.3, distance_to_bolt);
    float inner = exp(-2.1 * pow(
        distance_to_bolt / (core_width * 4.0), 1.6));
    float aura = exp(-3.0 * pow(
        distance_to_bolt / 0.14, 1.25));

    float flicker = clamp(0.87 + 0.09 * sin(TIME * 65.0 + phase_offset)
        + 0.04 * sin(TIME * 121.0 + phase_offset * 2.0), 0.70, 1.0);
    float edge = smoothstep(0.0, 0.008, progress)
        * (1.0 - smoothstep(0.992, 1.0, progress));

    float opacity = clamp(core * 0.98 + inner * 0.60
        + aura * 0.17 * glow_strength, 0.0, 1.0);
    vec3 color = mix(arc_color, vec3(0.94, 0.97, 1.0), core);
    COLOR = vec4(color, opacity * life_alpha * flicker * edge);
}
