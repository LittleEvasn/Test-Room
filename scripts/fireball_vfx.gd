extends Node2D
## Fireball projectile VFX only. A connected turbulent shader, no PNGs.
## Base game has 270px/s; the Lab uses speeded-up travel to reach its
## deliberately distant test reticle before the projectile expires.
signal impacted(at: Vector2)
signal finished()

const BODY_SHADER = preload("res://shaders/fireball_body.gdshader")
const RADII := [50.0, 65.0, 80.0, 100.0]
const PREVIEW_SPEED := 590.0
const MAX_PREVIEW_LIFE := 2.45

var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var stage := 0
var density := 1.0
var velocity := Vector2.RIGHT
var distance := 1.0
var traveled := 0.0
var elapsed := 0.0
var shader_material: ShaderMaterial
var sparks: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var spawn_clock := 0.0
var rng := RandomNumberGenerator.new()
var done := false

func configure(origin: Vector2, target: Vector2, multiplier: float, rank: int) -> void:
    from_point = origin
    to_point = target
    density = clampf(multiplier, 0.0, 3.0)
    stage = clampi(rank, 0, 3)

func _ready() -> void:
    rng.randomize()
    position = from_point
    velocity = (to_point - from_point).normalized()
    if velocity.length_squared() < 0.01:
        velocity = Vector2.RIGHT
    distance = from_point.distance_to(to_point)
    rotation = velocity.angle()
    scale = Vector2.ONE * (0.78 + float(stage) * 0.09)
    shader_material = ShaderMaterial.new()
    shader_material.shader = BODY_SHADER
    shader_material.set_shader_parameter("seed", rng.randf_range(0.0, 100.0))
    shader_material.set_shader_parameter("vigor", rng.randf_range(0.9, 1.15))
    shader_material.set_shader_parameter("appear", 0.0)
    var face := ColorRect.new()
    face.color = Color.WHITE
    face.position = Vector2(-149.0, -62.0)
    face.size = Vector2(224.0, 124.0)
    face.mouse_filter = Control.MOUSE_FILTER_IGNORE
    face.material = shader_material
    add_child(face)

func _process(delta: float) -> void:
    if done:
        return
    elapsed += delta
    var step := minf(PREVIEW_SPEED * delta, maxf(0.0, distance - traveled))
    traveled += step
    position = from_point + velocity * traveled
    shader_material.set_shader_parameter("appear", minf(elapsed / 0.12, 1.0))
    spawn_clock += delta * (30.0 + density * 23.0)
    while spawn_clock >= 1.0:
        spawn_clock -= 1.0
        _add_spark()
    for index in range(sparks.size() - 1, -1, -1):
        var spark: Dictionary = sparks[index]
        spark["life"] = float(spark["life"]) - delta
        spark["pos"] = Vector2(spark["pos"]) + Vector2(spark["vel"]) * delta
        spark["vel"] = Vector2(spark["vel"]) * (1.0 - minf(delta * 1.7, 0.5))
        if float(spark["life"]) <= 0.0:
            sparks.remove_at(index)
        else:
            sparks[index] = spark
    # Short fiery wake made from continuous streaks, not separate round blobs.
    streaks.push_front({"pos": position, "age": 0.0})
    if streaks.size() > 14:
        streaks.pop_back()
    for index in range(streaks.size()):
        var s: Dictionary = streaks[index]
        s["age"] = float(s["age"]) + delta
        streaks[index] = s
    queue_redraw()
    if traveled >= distance - 0.1 or elapsed >= MAX_PREVIEW_LIFE:
        _finish()

func _add_spark() -> void:
    if density <= 0.0 or sparks.size() >= 42:
        return
    var side := velocity.orthogonal()
    var point := position - velocity * rng.randf_range(13.0, 34.0) + side * rng.randf_range(-14.0, 14.0)
    var life := rng.randf_range(0.22, 0.58)
    sparks.append({
        "pos": point,
        "vel": -velocity * rng.randf_range(45.0, 155.0) + side * rng.randf_range(-45.0, 45.0),
        "life": life, "max": life, "size": rng.randf_range(1.2, 3.0)
    })

func _draw() -> void:
    for index in range(streaks.size() - 1):
        var a: Vector2 = to_local(Vector2(streaks[index]["pos"]))
        var b: Vector2 = to_local(Vector2(streaks[index + 1]["pos"]))
        var fade := 1.0 - float(index) / float(maxi(streaks.size(), 1))
        draw_line(a, b, Color(1.0, 0.29 + 0.4 * fade, 0.035, fade * 0.25), 15.0 * fade, true)
        draw_line(a, b, Color(1.0, 0.80, 0.19, fade * 0.24), 4.0 * fade, true)
    for spark in sparks:
        var point: Vector2 = to_local(Vector2(spark["pos"]))
        var dir: Vector2 = Vector2(spark["vel"]).normalized()
        var alpha: float = float(spark["life"]) / float(spark["max"])
        draw_line(point, point - dir * (4.0 + float(spark["size"]) * 1.4),
            Color(1.0, 0.64 + 0.27 * alpha, 0.16, alpha * 0.85),
            maxf(float(spark["size"]) * 0.65, 0.7), true)

func _finish() -> void:
    if done:
        return
    done = true
    impacted.emit(global_position)
    finished.emit()
    queue_free()
