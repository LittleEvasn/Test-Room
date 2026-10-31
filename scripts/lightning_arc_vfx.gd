extends Node2D
## FencerDevLog-style 2D electric arc, VFX preview only.
## No branch paths, collision, damage, elemental status or balance logic.
## See shaders/lightning_arc.gdshader for the original CC0 reference.

signal finished(point: Vector2)

const ARC_SHADER: Shader = preload("res://shaders/lightning_arc.gdshader")
const LIFE_SECONDS := 0.82
const STRIP_HEIGHT := 190.0

var _start_point := Vector2.ZERO
var _end_point := Vector2.ZERO
var _visual_rank := 0
var _glow_multiplier := 1.0
var _elapsed := 0.0
var _visible_amount := 0.0
var _bolt_length := 0.0
var _shader_material: ShaderMaterial

func configure(cast_from: Vector2, cast_to: Vector2, particle_multiplier: float = 1.0, visual_rank: int = 0) -> void:
    _start_point = cast_from
    _end_point = cast_to
    _glow_multiplier = particle_multiplier
    _visual_rank = clampi(visual_rank, 0, 3)

func _ready() -> void:
    position = _start_point
    var direction := _end_point - _start_point
    _bolt_length = maxf(direction.length(), 1.0)
    rotation = direction.angle()

    var strip := ColorRect.new()
    strip.name = "UnbranchedArc"
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    strip.position = Vector2(0.0, -STRIP_HEIGHT * 0.5)
    strip.size = Vector2(_bolt_length, STRIP_HEIGHT)
    # At effectively zero range, draw just a small contact spark instead.
    strip.visible = _bolt_length >= 8.0

    _shader_material = ShaderMaterial.new()
    _shader_material.shader = ARC_SHADER
    _shader_material.set_shader_parameter("phase_offset", randf_range(-40.0, 40.0))
    # Distance-aware frequency, displacement and glow scale; ONLY slot 9 opts in.
    _shader_material.set_shader_parameter("arc_length_px", _bolt_length)
    _shader_material.set_shader_parameter("distance_adaptation", 1.0)
    _shader_material.set_shader_parameter("body_crawl", 1.0)
    _shader_material.set_shader_parameter("offset_strength", 0.155 + 0.012 * float(_visual_rank))
    _shader_material.set_shader_parameter("core_width", 0.0085 + 0.0014 * float(_visual_rank))
    _shader_material.set_shader_parameter("glow_strength", clampf(0.35 + 0.65 * _glow_multiplier, 0.0, 2.4))
    _shader_material.set_shader_parameter("life_alpha", 0.0)
    strip.material = _shader_material
    add_child(strip)

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= LIFE_SECONDS:
        finished.emit(_end_point)
        queue_free()
        return

    var attack := smoothstep(0.0, 0.06, _elapsed)
    var release := 1.0 - smoothstep(LIFE_SECONDS - 0.19, LIFE_SECONDS, _elapsed)
    _visible_amount = attack * release
    _shader_material.set_shader_parameter("life_alpha", _visible_amount)
    queue_redraw()

func _draw() -> void:
    if _visible_amount <= 0.0:
        return
    # No branches. Close-range endpoints share a compact contact flash.
    if _bolt_length < 24.0:
        var center := Vector2(_bolt_length * 0.5, 0.0)
        draw_circle(center, 4.0, Color(0.21, 0.52, 1.0, 0.14 * _visible_amount))
        draw_circle(center, 1.6, Color(0.91, 0.97, 1.0, 0.80 * _visible_amount))
        return

    var glint_scale: float = clampf(_bolt_length / 140.0, 0.35, 1.0)
    for endpoint in [Vector2.ZERO, Vector2(_bolt_length, 0.0)]:
        draw_circle(endpoint, 12.0 * glint_scale, Color(0.21, 0.52, 1.0, 0.10 * _visible_amount))
        draw_circle(endpoint, 4.0 * glint_scale, Color(0.64, 0.86, 1.0, 0.30 * _visible_amount))
        draw_circle(endpoint, 1.6, Color(1.0, 1.0, 1.0, 0.77 * _visible_amount))
