shader_type canvas_item;
render_mode blend_mix, unshaded;

// B: independently generated, genuine 12-frame 4x3 fire flipbook.
// C: the same authored-by-code animation used as a softer accent layer.
uniform sampler2D fire_atlas : source_color, filter_linear, repeat_disable;
uniform float phase = 0.0;
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    float frame = mod(floor(TIME * 12.0 + phase * 2.1), 12.0);
    vec2 local_uv = clamp(UV, vec2(0.004), vec2(0.996));
    float bend = pow(1.0 - UV.y, 1.9);
    local_uv.x = clamp(local_uv.x + sin(TIME * 3.5 + phase + UV.y * 4.0)
        * 0.013 * bend, 0.004, 0.996);
    vec2 atlas_uv = (local_uv + vec2(mod(frame, 4.0),
        floor(frame / 4.0))) / vec2(4.0, 3.0);
    vec4 fire = texture(fire_atlas, atlas_uv);
    float appear = smoothstep(0.0, 0.07, life);
    float vanish = 1.0 - smoothstep(0.79, 1.0, life);
    COLOR = vec4(fire.rgb, fire.a * strength * appear * vanish);
}
