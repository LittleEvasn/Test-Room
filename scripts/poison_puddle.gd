extends Node2D
## VFX-only poison puddle: irregular pool, bubbles, expansion and shrink.
## No combat, no damage ticks, no poison-trail recursion.
var puddle_radius := 24.0
var lifetime := 1.8
var density := 1.0
var age := 0.0
var shape_seed := 0.0
var bubbles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func configure(radius: float, duration: float, particle_scale: float) -> void:
    puddle_radius = maxf(radius, 4.0)
    lifetime = maxf(duration, 0.4)
    density = clampf(particle_scale, 0.0, 3.0)

func _ready() -> void:
    z_index = 1
    rng.randomize()
    shape_seed = rng.randf_range(0.0, TAU)
    var amount := roundi(7.0 * density)
    for i in range(amount):
        var angle := rng.randf_range(0.0, TAU)
        var distance := sqrt(rng.randf()) * 0.72
        bubbles.append({
            "at": Vector2(cos(angle) * puddle_radius, sin(angle) * puddle_radius * 0.67) * distance,
            "size": rng.randf_range(1.7, 4.4),
            "speed": rng.randf_range(0.48, 1.05),
            "phase": rng.randf()
        })
    queue_redraw()

func _process(delta: float) -> void:
    age += maxf(delta, 0.0)
    if age >= lifetime:
        queue_free()
        return
    queue_redraw()

func _outline(radius_factor: float, wobble: float) -> PackedVector2Array:
    var points := PackedVector2Array()
    for i in range(49):
        var a := float(i % 48) / 48.0 * TAU
        var edge := 1.0
        edge += 0.055 * sin(a * 5.0 + shape_seed)
        edge += 0.031 * cos(a * 8.0 - shape_seed * 0.7)
        edge += wobble * sin(a * 3.0 + age * 3.4)
        points.append(Vector2(cos(a), sin(a) * 0.72) * puddle_radius * radius_factor * edge)
    return points

func _draw() -> void:
    var grow := clampf(age / 0.14, 0.0, 1.0)
    var shrink := clampf((lifetime - age) / 0.38, 0.0, 1.0)
    var scale_factor := grow * shrink
    if scale_factor < 0.001:
        return
    var alpha := clampf(age / 0.09, 0.0, 1.0) * clampf((lifetime - age) / 0.30, 0.0, 1.0)
    var outer := _outline(scale_factor, 0.015)
    var inner := _outline(scale_factor * 0.82, 0.010)
    var center := _outline(scale_factor * 0.59, 0.006)
    draw_colored_polygon(outer, Color(0.09, 0.30, 0.06, alpha * 0.58))
    draw_colored_polygon(inner, Color(0.25, 0.60, 0.09, alpha * 0.79))
    draw_colored_polygon(center, Color(0.48, 0.82, 0.12, alpha * 0.60))
    draw_polyline(outer, Color(0.48, 0.88, 0.17, alpha * 0.78), 2.2, true)
    for bubble in bubbles:
        var phase := fmod(age * float(bubble["speed"]) + float(bubble["phase"]), 1.0)
        var at := Vector2(bubble["at"]) * scale_factor + Vector2(0, -7.0 * phase)
        var bsize := float(bubble["size"]) * (0.72 + phase * 0.28) * scale_factor
        var opacity := alpha * (1.0 - phase) * 0.85
        draw_circle(at, bsize, Color(0.82, 1.0, 0.49, opacity * 0.18))
        draw_arc(at, bsize, 0.0, TAU, 12, Color(0.78, 0.99, 0.43, opacity), 1.2, true)
        draw_circle(at + Vector2(-bsize * 0.3, -bsize * 0.3),
            maxf(0.55, bsize * 0.24), Color(0.96, 1.0, 0.75, opacity))
