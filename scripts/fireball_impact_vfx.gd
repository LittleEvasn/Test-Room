extends Node2D
## A brief fireball impact/explosion visual. Does not deal damage or burn.
const IMPACT_SHADER = preload("res://shaders/fireball_impact.gdshader")
const DURATION := 0.69

var size_radius := 50.0
var density := 1.0
var age := 0.0
var material_instance: ShaderMaterial
var motes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func configure(radius: float, multiplier: float) -> void:
    size_radius = clampf(radius, 18.0, 160.0)
    density = clampf(multiplier, 0.0, 3.0)

func _ready() -> void:
    rng.randomize()
    material_instance = ShaderMaterial.new()
    material_instance.shader = IMPACT_SHADER
    material_instance.set_shader_parameter("seed", rng.randf_range(0.0, 100.0))
    material_instance.set_shader_parameter("progress", 0.0)
    var surface := ColorRect.new()
    surface.color = Color.WHITE
    surface.position = Vector2.ONE * (-size_radius * 1.15)
    surface.size = Vector2.ONE * (size_radius * 2.30)
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.material = material_instance
    add_child(surface)
    var count := clampi(roundi(9.0 * density), 0, 27)
    for index in range(count):
        var angle := TAU * (float(index) + rng.randf_range(-0.22, 0.22)) / float(maxi(count, 1))
        var speed := size_radius * rng.randf_range(0.96, 1.90)
        motes.append({
            "angle": angle,
            "speed": speed,
            "size": rng.randf_range(1.2, 3.8),
            "delay": rng.randf_range(0.01, 0.09)
        })

func _process(delta: float) -> void:
    age += delta
    material_instance.set_shader_parameter("progress", minf(age / DURATION, 1.0))
    queue_redraw()
    if age >= DURATION:
        queue_free()

func _draw() -> void:
    var progress := clampf(age / DURATION, 0.0, 1.0)
    var ring_radius := size_radius * pow(progress, 0.62)
    var fade := 1.0 - smoothstep(0.17, 0.92, progress)
    draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 56,
        Color(1.0, 0.67, 0.14, fade * 0.38), 2.0 + fade * 2.0, true)
    for mote in motes:
        var active_age := age - float(mote["delay"])
        if active_age <= 0.0:
            continue
        var duration := 0.45
        var fraction := clampf(active_age / duration, 0.0, 1.0)
        if fraction >= 1.0:
            continue
        var dir := Vector2.RIGHT.rotated(float(mote["angle"]))
        var position_now := dir * float(mote["speed"]) * active_age
        var alpha := (1.0 - fraction) * 0.86
        draw_line(position_now, position_now - dir * (5.0 + 5.0 * fraction),
            Color(1.0, 0.58 + 0.28 * fraction, 0.09, alpha),
            float(mote["size"]) * (1.0 - fraction * 0.50), true)
