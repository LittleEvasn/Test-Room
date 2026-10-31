extends Node2D
## 사용자 제공 별 이미지 + 금빛 별 모양·구슬형 먼지·짧은 광선 파티클.
## 파티클은 소규모 실험을 위해 스크립트 기반으로 구현했다.

signal impacted(at: Vector2)

const STAR_TEXTURE: Texture2D = preload("res://assets/star_bolt.png")
const SPEED := 720.0
const STAR_DIAMETER := 76.0

var destination := Vector2.ZERO
var heading := Vector2.RIGHT
var age := 0.0
var emission_density := 1.0
var spawn_accumulator := 0.0
var particles: Array[Dictionary] = []

func configure(start_pos: Vector2, end_pos: Vector2, density: float) -> void:
    position = start_pos
    destination = end_pos
    heading = start_pos.direction_to(end_pos)
    emission_density = density

func _process(delta: float) -> void:
    age += delta
    var travel := SPEED * delta
    if has_meta("aux_falling"):
        # Fall driver owns only movement; keep the normal sparkling trail and spin.
        heading = Vector2(get_meta("aux_fall_direction", heading))
    else:
        if global_position.distance_to(destination) <= travel + 10.0:
            impacted.emit(destination)
            queue_free()
            return
        global_position += heading * travel
    spawn_accumulator += delta * 55.0 * emission_density
    while spawn_accumulator >= 1.0 and particles.size() < 120:
        spawn_accumulator -= 1.0
        var life := randf_range(0.18, 0.42)
        particles.append({
            "pos": global_position - heading * randf_range(10.0, 29.0) + Vector2(randf_range(-11.0, 11.0), randf_range(-11.0, 11.0)),
            "velocity": -heading * randf_range(15.0, 75.0) + Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0)),
            "life": life,
            "max_life": life,
            "size": randf_range(4.0, 10.0),
            "kind": 0 if randf() < 0.42 else (1 if randf() < 0.61 else 2),
            "angle": randf_range(0.0, TAU)
        })
    for i in range(particles.size() - 1, -1, -1):
        var part := particles[i]
        part["life"] = float(part["life"]) - delta
        if float(part["life"]) <= 0.0:
            particles.remove_at(i)
        else:
            part["pos"] = Vector2(part["pos"]) + Vector2(part["velocity"]) * delta
    queue_redraw()

func _draw() -> void:
    for part in particles:
        var factor := float(part["life"]) / float(part["max_life"])
        var size := float(part["size"]) * (0.4 + 0.6 * factor)
        var local_pos := Vector2(part["pos"]) - global_position
        match int(part["kind"]):
            0:
                _draw_star_glint(local_pos, size * 0.90, Color(1.0, 0.95, 0.58, factor * 0.92))
            1:
                draw_circle(local_pos, size * 0.53, Color(1.0, 0.74, 0.20, factor * 0.36))
                draw_circle(local_pos, size * 0.26, Color(1.0, 0.93, 0.58, factor * 0.85))
                draw_circle(local_pos, size * 0.12, Color(1.0, 1.0, 0.91, factor))
            2:
                var tangent := heading.rotated(float(part["angle"]) * 0.09)
                draw_line(local_pos - tangent * size * 1.7, local_pos + tangent * size * 0.7, Color(1.0, 0.83, 0.38, factor * 0.72), maxf(1.0, size * 0.22), true)
                draw_circle(local_pos + tangent * size * 0.65, size * 0.17, Color(1.0, 0.99, 0.77, factor * 0.9))
    draw_line(-heading * 49.0, -heading * 8.0, Color(1.0, 0.70, 0.10, 0.18), 14.0, true)
    draw_circle(Vector2.ZERO, 42.0, Color(1.0, 0.72, 0.11, 0.08))
    draw_set_transform(Vector2.ZERO, age * 3.1, Vector2.ONE)
    var side := STAR_DIAMETER * (1.0 + 0.04 * sin(age * 15.0))
    draw_texture_rect(STAR_TEXTURE, Rect2(-Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_star_glint(at: Vector2, radius: float, tint: Color) -> void:
    var thin := maxf(1.0, radius * 0.17)
    draw_line(at - Vector2(radius, 0.0), at + Vector2(radius, 0.0), tint, thin, true)
    draw_line(at - Vector2(0.0, radius * 1.4), at + Vector2(0.0, radius * 1.4), tint, thin, true)
    draw_line(at - Vector2(radius * 0.45, radius * 0.45), at + Vector2(radius * 0.45, radius * 0.45), Color(1.0, 0.87, 0.53, tint.a * 0.45), 1.0, true)
    draw_circle(at, radius * 0.20, Color(1.0, 1.0, 0.88, tint.a))
