extends Node2D
## 사용자 제공 별 이미지 + 실시간 회전 + 노란 잔광/입자.
## 파티클은 소규모 실험을 위해 스크립트 기반으로 구현했다.

signal impacted(at: Vector2)

const STAR_TEXTURE: Texture2D = preload("res://assets/star_bolt.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/spark.png")
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
            "size": randf_range(4.0, 10.0)
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
        draw_texture_rect(SPARK_TEXTURE, Rect2(local_pos - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(1.0, 1.0, 1.0, factor * 0.90))
        if size >= 5.0:
            draw_circle(local_pos, size * 0.25, Color(1.0, 0.90, 0.45, factor * 0.9))
    draw_line(-heading * 49.0, -heading * 8.0, Color(1.0, 0.70, 0.10, 0.18), 14.0, true)
    draw_circle(Vector2.ZERO, 42.0, Color(1.0, 0.72, 0.11, 0.08))
    draw_set_transform(Vector2.ZERO, age * 3.1, Vector2.ONE)
    var side := STAR_DIAMETER * (1.0 + 0.04 * sin(age * 15.0))
    draw_texture_rect(STAR_TEXTURE, Rect2(-Vector2.ONE * side * 0.5, Vector2.ONE * side), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
