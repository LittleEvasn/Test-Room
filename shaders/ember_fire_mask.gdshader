shader_type canvas_item;
render_mode blend_mix, unshaded;

// A: one connected flame body driven by upward-flowing seamless noise.
// No round particle shapes. Bottom remains anchored; tips flow and erode.
// Procedural texture is generated once by ember_footprint_fire.gd.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float phase = 0.0;
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;

float sample_noise(vec2 uv) {
    return texture(noise_tex, uv).r;
}
float tongue(float x, float h, float center, float width, float height, float t, float sway_id) {
    float z = h / height;
    float bend = (sin(t * 2.7 + sway_id + z * 3.4) * 0.048
        + sin(t * 1.6 + sway_id * 2.1 + z * 6.3) * 0.015) * z * z;
    float w = width * pow(clamp(1.0 - z, 0.0, 1.0), 0.69);
    return (w - abs(x - center - bend)) / width;
}
void fragment() {
    vec2 uv = UV;
    float h = (0.92 - uv.y) / 0.77;
    if (h < -0.02 || h > 1.18) {
        COLOR = vec4(0.0);
    } else {
        float t = TIME + phase;
        float topness = clamp(h, 0.0, 1.0);
        // Two noise scales move upwards at DIFFERENT speeds, not sideways.
        float coarse = sample_noise(vec2(uv.x * 0.84 + phase * 0.043,
            h * 0.75 - t * 0.18));
        float detail = sample_noise(vec2(uv.x * 2.6 + phase * 0.067 + 0.31,
            h * 1.85 - t * 0.36));
        float x = uv.x - 0.5;
        x -= (coarse - 0.5) * 0.10 * pow(topness, 1.35);
        float body = max(tongue(x, h, -0.17, 0.19, 0.69, t, 1.3),
            max(tongue(x, h, -0.01, 0.245, 0.99, t, 2.6),
                tongue(x, h, 0.18, 0.21, 0.81, t, 4.3)));

        // Keep a stable, connected ignition root. More breakup near tips.
        float flutter = ((coarse - 0.5) * 0.20 + (detail - 0.5) * 0.12)
            * mix(0.10, 1.0, smoothstep(0.17, 0.84, topness));
        float field = body + flutter;
        float outer = smoothstep(-0.12, 0.12, field);
        float gold = smoothstep(0.02, 0.32, field);
        float core = smoothstep(0.28, 0.67, field);
        float hot = smoothstep(0.56, 0.92, field)
            * smoothstep(0.22, 0.78, uv.y);
        float rise = smoothstep(-0.08, 0.04, h)
            * (1.0 - smoothstep(1.01, 1.16, h));

        vec3 rgb = mix(vec3(1.0, 0.34, 0.045), vec3(1.0, 0.71, 0.16), gold);
        rgb = mix(rgb, vec3(1.0, 0.89, 0.34), core * 0.90);
        rgb = mix(rgb, vec3(1.0, 0.99, 0.84), hot * 0.92);
        float appear = smoothstep(0.0, 0.075, life);
        float vanish = 1.0 - smoothstep(0.82, 1.0, life);
        COLOR = vec4(min(rgb * brightness, vec3(1.0)), outer * rise * appear * vanish);
    }
}
