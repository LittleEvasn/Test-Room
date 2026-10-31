shader_type canvas_item;
render_mode blend_mix, unshaded;

// Black hole VFX v5: halve only the event-horizon radius; preserve the outer vortex.
// Keep the same mature silhouette from its very first visible frame.
uniform float u_time = 0.0;
uniform float u_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float u_scale : hint_range(0.0, 1.0) = 1.0;
uniform float u_tick_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 disk_shadow : source_color = vec4(0.14, 0.018, 0.29, 1.0);
uniform vec4 disk_violet : source_color = vec4(0.53, 0.075, 0.83, 1.0);
uniform vec4 disk_highlight : source_color = vec4(0.90, 0.74, 1.0, 1.0);

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 smooth_f = f * f * (3.0 - 2.0 * f);
    float a = hash21(cell);
    float b = hash21(cell + vec2(1.0, 0.0));
    float c = hash21(cell + vec2(0.0, 1.0));
    float d = hash21(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, smooth_f.x), mix(c, d, smooth_f.x), smooth_f.y);
}

float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        total += value_noise(p) * amplitude;
        p = p * 2.12 + vec2(5.7, 3.2);
        amplitude *= 0.5;
    }
    return total;
}

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float r = length(p) / max(u_scale, 0.025);
    float angle = atan(p.y, p.x);
    // Inner black void + its bright rim are 50% of their former radius.
    // Leave the outer disk's r, noise, warp, rotation and outer fade untouched.
    float core_r = r / 0.5;

    // Distort the OUTER silhouette only. Preserve a clear black event horizon.
    // Two different angular frequencies prevent the symmetric portal/donut look.
    float edge_warp = 0.039 * sin(angle * 3.0 + u_time * 0.67);
    edge_warp += 0.021 * sin(angle * 7.0 - u_time * 1.07);
    edge_warp += 0.010 * sin(angle * 11.0 + u_time * 0.87);
    float warped_r = r + edge_warp * smoothstep(0.39, 0.85, r);

    // Fast near the center, slower outside. Continuous Cartesian noise prevents
    // a visible seam where the polar angle wraps.
    float angular_speed = 1.6 + 1.12 / max(r, 0.23);
    float spin = angle - u_time * angular_speed;
    vec2 flow = vec2(cos(spin), sin(spin)) * r * 4.3;
    float smoke = fbm(flow * 2.35 + vec2(u_time * 0.16, -u_time * 0.10));
    float detail = value_noise(flow * 8.2 + vec2(-u_time * 0.31, u_time * 0.22));

    // Short, broken spiral filaments rather than perfectly circular rings.
    float spiral_phase = angle * 11.0 - u_time * (2.5 + 1.1 / max(r, 0.26));
    spiral_phase += smoke * 5.5 - r * 12.5;
    float filament = pow(0.5 + 0.5 * sin(spiral_phase), 4.0);

    // Extend the EXISTING flowing disk inward to fill the area vacated by the core.
    // Outside the former inner transition all disk values are identical to v4.
    float disk_inner = smoothstep(0.1675, 0.2875, warped_r);
    float disk_outer = 1.0 - smoothstep(0.70, 0.985, warped_r);
    float disk_mask = disk_inner * disk_outer;
    float turbulence = clamp(0.12 + smoke * 1.13 + detail * 0.24 + filament * 0.25, 0.0, 1.0);

    // Unequal brightness by angle + slowly changing shadow lanes.
    float asymmetry = 0.74 + 0.21 * sin(angle - 0.55 + u_time * 0.29);
    asymmetry += 0.11 * sin(angle * 3.0 + u_time * 0.46);
    asymmetry = clamp(asymmetry, 0.42, 1.09);
    float intensity = disk_mask * (0.16 + 0.89 * turbulence) * asymmetry;
    float highlights = smoothstep(0.56, 0.89, turbulence) * filament;

    vec3 disk_color = mix(disk_shadow.rgb, disk_violet.rgb, clamp(turbulence * 1.13, 0.0, 1.0));
    disk_color = mix(disk_color, disk_highlight.rgb, highlights * 0.54);

    // A slightly rough, shadowy purple skirt, not a circular neon outline.
    float haze = smoothstep(0.46, 0.58, warped_r) * (1.0 - smoothstep(0.83, 1.07, warped_r));
    haze *= 0.38 + 0.62 * smoke;

    // Pale lavender-white broken rim emphasizes the void.
    float rim = smoothstep(0.296, 0.329, core_r) * (1.0 - smoothstep(0.337, 0.379, core_r));
    float rim_variation = clamp(0.74 + 0.25 * smoke + 0.14 * sin(angle * 5.0 + u_time * 3.1), 0.45, 1.0);
    float void_mask = 1.0 - smoothstep(0.298, 0.327, core_r);

    vec3 rgb = disk_color * intensity;
    rgb += disk_violet.rgb * haze * 0.19;
    rgb += disk_highlight.rgb * rim * rim_variation * (1.12 + u_tick_flash * 0.13);
    rgb = mix(rgb, vec3(0.007, 0.004, 0.018), void_mask);

    float alpha = max(intensity * 0.93, haze * 0.19);
    alpha = max(alpha, rim * 0.94);
    alpha = max(alpha, void_mask);
    alpha *= 1.0 - smoothstep(0.99, 1.09, warped_r);
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), clamp(alpha * u_opacity, 0.0, 1.0));
}
