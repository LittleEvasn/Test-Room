shader_type canvas_item;
render_mode blend_mix, unshaded;

// Fireball VFX: cohesive incandescent core + advected turbulent outer fire.
// Local +X is forward. No moving circle sprites or static triangular tongues.
uniform float seed = 0.0;
uniform float vigor : hint_range(0.4, 2.0) = 1.0;
uniform float appear : hint_range(0.0, 1.0) = 0.0;

float h21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float n21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x),
        mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.56;
    for (int k = 0; k < 3; k++) {
        v += a * n21(p);
        p = mat2(vec2(1.7, 1.1), vec2(-1.1, 1.7)) * p + vec2(5.2, 8.3);
        a *= 0.5;
    }
    return v;
}
void fragment() {
    // The hot core is around UV (0.67,0.5); the flame wake stretches LEFT.
    vec2 p = vec2((UV.x - 0.67) * 2.48, (UV.y - 0.50) * 2.28);
    float t = TIME * vigor + seed;
    float advect = fbm(vec2(p.x * 2.5 + t * 1.7, p.y * 3.8 - t * 0.7));
    float curl = fbm(vec2(p.x * 4.5 - t * 0.8, p.y * 4.9 + t * 1.15));
    float flicker = (advect - 0.45) * 0.27 + (curl - 0.45) * 0.10;
    vec2 bent = p + vec2(flicker * 0.20, flicker * 0.39);
    float radial = length(vec2(bent.x * 1.06, bent.y * 1.10));

    // Irregular but CONNECTED envelope around a recognisable hot projectile.
    float corona = 1.0 - smoothstep(0.45, 0.88, radial - flicker * 0.62);
    float ignition = 1.0 - smoothstep(0.17, 0.43, radial + (curl - 0.5) * 0.075);

    // Continuous wake convected back from the projectile; no separate blobs.
    float back = max(-p.x - 0.13, 0.0);
    float wake_width = max(0.10, 0.42 - back * 0.18);
    float wake_y = p.y + 0.072 * back * sin(back * 6.8 - t * 5.2 + seed);
    float ribbon = 1.0 - smoothstep(0.50, 1.12,
        abs(wake_y + (advect - 0.45) * back * 0.23) / wake_width);
    float wake_cut = (1.0 - smoothstep(0.80, 1.55, back))
        * smoothstep(0.02, 0.35, back);
    float wake = ribbon * wake_cut * (0.68 + 0.32 * curl);
    float flame = max(corona * 0.92, wake);
    float alpha = clamp(max(flame, ignition), 0.0, 1.0);
    // Faint warm corona, but not a blurry orange ball.
    float aura = exp(-radial * radial * 4.4) * 0.16;
    alpha = max(alpha, aura);

    // Bright cream-white nucleus; orange appears only on the outer envelope.
    float yellow = clamp(max(ignition * 0.95, flame * 0.38), 0.0, 1.0);
    float white = pow(max(ignition, 0.0), 1.45)
        * (0.91 + 0.09 * sin(t * 12.0 + seed));
    vec3 rgb = vec3(1.0, 0.29, 0.025);
    rgb = mix(rgb, vec3(1.0, 0.75, 0.11), yellow);
    rgb = mix(rgb, vec3(1.0, 0.955, 0.61), ignition * 0.83);
    rgb = mix(rgb, vec3(1.0, 0.995, 0.89), white * 0.90);
    float on = smoothstep(0.0, 0.12, appear);
    COLOR = vec4(rgb, alpha * on);
}
