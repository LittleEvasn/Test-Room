shader_type canvas_item;
render_mode unshaded;

// Low, ground-hugging fire patch. No authored texture or sprite sheet.
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float variation = 0.0;

float tongue(vec2 uv, float center, float height, float width, float rate, float offset) {
    float birth = mix(0.35, 1.0, smoothstep(0.0, 0.11, life));
    float rise = (0.82 - uv.y) / (height * birth);
    float bend = (sin(TIME * rate + variation + offset + rise * 5.1) * 0.045
        + sin(TIME * rate * 1.6 + offset * 2.7 + rise * 11.0) * 0.014)
        * max(rise, 0.0);
    float edge = width * pow(clamp(1.0 - rise, 0.0, 1.0), 0.75);
    float distance_to_axis = abs(uv.x - center - bend);
    float silhouette = 1.0 - smoothstep(edge - 0.012, edge + 0.014, distance_to_axis);
    return silhouette * smoothstep(-0.08, 0.05, rise)
        * (1.0 - smoothstep(0.90, 1.02, rise));
}

void fragment() {
    vec2 uv = UV;
    float outer = 0.0;
    float core = 0.0;
    outer = max(outer, tongue(uv, 0.28, 0.32, 0.105, 4.8, 0.1));
    outer = max(outer, tongue(uv, 0.41, 0.45, 0.125, 3.7, 1.4));
    outer = max(outer, tongue(uv, 0.53, 0.53, 0.12, 4.2, 2.8));
    outer = max(outer, tongue(uv, 0.65, 0.37, 0.11, 5.3, 4.5));
    outer = max(outer, tongue(uv, 0.74, 0.27, 0.085, 4.5, 5.7));

    // Smaller nested tongues make a hot center without an overexposed white disk.
    core = max(core, tongue(uv, 0.30, 0.21, 0.047, 4.8, 0.1));
    core = max(core, tongue(uv, 0.42, 0.30, 0.065, 3.7, 1.4));
    core = max(core, tongue(uv, 0.53, 0.34, 0.066, 4.2, 2.8));
    core = max(core, tongue(uv, 0.64, 0.25, 0.055, 5.3, 4.5));

    float flicker = 0.89 + 0.11 * sin(TIME * 10.5 + variation * 1.8);
    float vertical = clamp((0.82 - uv.y) / 0.52, 0.0, 1.0);
    vec3 flame_color = mix(vec3(0.98, 0.24, 0.025), vec3(1.0, 0.54, 0.055),
        0.22 + 0.55 * vertical);
    flame_color = mix(flame_color, vec3(1.0, 0.84, 0.30), core * 0.82);

    // An oval hot ground, not a round projectile or a tall campfire.
    vec2 ground = vec2((uv.x - 0.5) / 0.30, (uv.y - 0.82) / 0.080);
    float heat = exp(-2.7 * dot(ground, ground)) * 0.39;
    vec3 ground_color = vec3(0.87, 0.22, 0.015);
    float flame_alpha = clamp(outer * flicker, 0.0, 1.0);
    float alpha = max(flame_alpha, heat);
    vec3 rgb = mix(ground_color, flame_color, flame_alpha / max(alpha, 0.001));

    float appear = smoothstep(0.0, 0.055, life);
    float fade = 1.0 - smoothstep(0.78, 1.0, life);
    COLOR = vec4(rgb, alpha * appear * fade);
}
