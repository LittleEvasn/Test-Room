shader_type canvas_item;
render_mode blend_mix, unshaded;

// v5: continuously changing fire-line, not three conical tongues.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;

float n(vec2 uv) { return texture(noise_tex, uv).r; }

void fragment() {
    vec2 uv = UV;
    float t = TIME + phase;
    float h = (0.92 - uv.y) / 0.80;
    float altitude = clamp(h, 0.0, 1.15);
    float large_flow = n(vec2(uv.x * 0.53 + phase * 0.016,
        h * 0.63 - t * 0.105));
    float small_flow = n(vec2(uv.x * 1.65 + phase * 0.051,
        h * 1.46 - t * 0.29));
    // The ignition root is stable, while upper regions distort.
    float x = uv.x + ((large_flow - 0.5) * 0.12 +
        (small_flow - 0.5) * 0.04) * pow(altitude, 1.30);

    // A time-varying irregular CREST, not triangles tapering to a point.
    float crest_big = n(vec2(x * 0.67 + phase * 0.011,
        0.19 + sin(t * 0.84) * 0.065));
    float crest_small = n(vec2(x * 1.25 + phase * 0.043,
        0.38 + cos(t * 1.13) * 0.08));
    float crest = 0.32 + 0.32 * crest_big + 0.16 * crest_small
        + 0.085 * sin(x * 18.0 + t * 3.4 + phase)
        + 0.043 * sin(x * 39.0 - t * 2.1);
    float detail = n(vec2(x * 3.12 + phase * 0.08 + 0.3,
        h * 2.75 - t * 0.49));
    float field = crest - h + (large_flow - 0.5) * 0.18
        + (small_flow - 0.5) * 0.12 * altitude
        + (detail - 0.5) * 0.065 * altitude;

    float side_distance = abs(x - 0.5) /
        max(0.23, 0.43 - min(altitude, 1.0) * 0.10);
    float side_mask = 1.0 - smoothstep(0.66, 1.07, side_distance);
    // The lower edge fades rather than forming a straight horizontal cut.
    float ground_fade = 1.0 - smoothstep(0.86, 0.985, uv.y);
    float root = smoothstep(-0.045, 0.026, h);
    float outer = smoothstep(-0.10, 0.047, field)
        * side_mask * ground_fade * root;

    // Bright center is sampled from THE SAME FIRE FIELD.
    float yellow = smoothstep(0.055, 0.24, field);
    float hot = smoothstep(0.27, 0.51, field)
        * smoothstep(0.25, 0.79, uv.y);
    vec3 rgb = mix(vec3(1.0, 0.36, 0.046),
        vec3(1.0, 0.81, 0.16), yellow);
    rgb = mix(rgb, vec3(1.0, 0.974, 0.73), hot * 0.80);

    float appear = smoothstep(0.0, 0.075, life);
    float vanish = 1.0 - smoothstep(0.79, 1.0, life);
    COLOR = vec4(min(rgb * brightness, vec3(1.0)),
        outer * appear * vanish);
}
