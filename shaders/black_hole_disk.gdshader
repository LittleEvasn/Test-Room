shader_type canvas_item;
render_mode blend_mix, unshaded;

// Procedural accretion disk for a top-down 2D black hole.
// No external textures. The dark event horizon stays perfectly round.
uniform float u_time = 0.0;
uniform float u_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float u_scale : hint_range(0.0, 1.0) = 1.0;
uniform float u_tick_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 disk_teal : source_color = vec4(0.17, 0.65, 0.70, 1.0);
uniform vec4 disk_lime : source_color = vec4(0.65, 0.80, 0.34, 1.0);
uniform vec4 disk_pale : source_color = vec4(0.91, 0.97, 0.74, 1.0);

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
    float accum = 0.0;
    float weight = 0.5;
    for (int i = 0; i < 3; i++) {
        accum += value_noise(p) * weight;
        p = p * 2.12 + vec2(5.7, 3.2);
        weight *= 0.5;
    }
    return accum;
}

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float r = length(p) / max(u_scale, 0.035);
    float angle = atan(p.y, p.x);

    // Radius-dependent rotation shears the noise into a continuous gas flow.
    // Circular coordinates avoid a visible UV seam across the disk.
    float spin = angle - u_time * (0.62 + 0.27 / max(r, 0.18));
    vec2 flow = vec2(cos(spin), sin(spin)) * (r * 4.1);
    float smoke = fbm(flow * 2.1 + vec2(u_time * 0.15, -u_time * 0.09));
    float detail = value_noise(flow * 8.3 - vec2(u_time * 0.24, u_time * 0.13));

    // Broad irregular ring: most of the surface is soft, with moving brighter eddies.
    float inner = smoothstep(0.29, 0.43, r);
    float outer = 1.0 - smoothstep(0.72, 0.92, r);
    float disk = inner * outer;
    float eddies = clamp(0.22 + smoke * 1.12 + detail * 0.23, 0.0, 1.0);
    float intensity = disk * (0.38 + 0.62 * eddies);
    float hot = smoothstep(0.58, 0.91, eddies) * (1.0 - smoothstep(0.67, 0.89, r));

    vec3 disk_color = mix(disk_teal.rgb, disk_lime.rgb, clamp(smoke * 1.20, 0.0, 1.0));
    disk_color = mix(disk_color, disk_pale.rgb, hot * 0.52);

    // Low-opacity haze gives the disk depth without an outlined magic circle.
    float haze = smoothstep(0.39, 0.59, r) * (1.0 - smoothstep(0.79, 1.02, r));
    haze *= 0.55 + smoke * 0.45;

    // Slightly broken bright rim; black core is unlit and covers all noise.
    float rim = smoothstep(0.292, 0.33, r) * (1.0 - smoothstep(0.335, 0.392, r));
    float rim_variation = 0.48 + 0.52 * smoke;
    float void_mask = 1.0 - smoothstep(0.292, 0.326, r);

    vec3 rgb = disk_color * intensity;
    rgb += disk_teal.rgb * haze * 0.15;
    rgb += disk_pale.rgb * rim * rim_variation * (0.74 + u_tick_flash * 0.10);
    rgb = mix(rgb, vec3(0.008, 0.011, 0.019), void_mask);

    float alpha = max(intensity * 0.91, haze * 0.16);
    alpha = max(alpha, rim * 0.82);
    alpha = max(alpha, void_mask);
    alpha *= 1.0 - smoothstep(0.92, 1.06, r);

    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), clamp(alpha * u_opacity, 0.0, 1.0));
}
