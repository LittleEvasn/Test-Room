extends Node2D
## 명중 시 0.4초 동안 원형 섬광, 별 조각, 스파크를 표시.

const DURATION := 0.44
var elapsed := 0.0
var fragments: Array[Dictionary] = []

func _ready() -> void:
    for i in range(21):
        var theta := (float(i) / 21.0) * TAU + randf_range(-0.15, 0.15)
        var speed := randf_range(75.0, 225.0)
        fragments.append({"velocity": Vector2.RIGHT.rotated(theta) * speed, "size": randf_range(4.0, 10.0), "kind": i % 3, "angle": theta})

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= DURATION:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var p := clampf(elapsed / DURATION, 0.0, 1.0)
    var fade := 1.0 - p
    draw_circle(Vector2.ZERO, 38.0 * (0.5 + p), Color(1.0, 0.82, 0.25, 0.22 * fade))
    draw_circle(Vector2.ZERO, 17.0 * (0.5 + p), Color(1.0, 0.96, 0.68, 0.64 * fade))
    draw_arc(Vector2.ZERO, 17.0 + p * 46.0, 0.0, TAU, 36, Color(1.0, 0.83, 0.28, 0.78 * fade), 3.0, true)
    for f in fragments:
        var velocity := Vector2(f["velocity"])
        var pt := velocity * elapsed * (1.0 - 0.25 * p)
        var size := float(f["size"]) * (0.35 + fade)
        match int(f["kind"]):
            0:
                _draw_hit_glint(pt, size, Color(1.0, 0.94, 0.61, fade * 0.92))
            1:
                draw_circle(pt, size * 0.68, Color(1.0, 0.77, 0.24, fade * 0.20))
                draw_circle(pt, size * 0.28, Color(1.0, 0.97, 0.75, fade * 0.94))
            2:
                var ray := Vector2.RIGHT.rotated(float(f["angle"]))
                draw_line(pt - ray * size * 1.7, pt + ray * size * 0.5, Color(1.0, 0.82, 0.31, fade * 0.82), maxf(1.0, size * 0.23), true)
                draw_circle(pt + ray * size * 0.45, size * 0.16, Color(1.0, 1.0, 0.9, fade))

func _draw_hit_glint(at: Vector2, size: float, tint: Color) -> void:
    draw_line(at + Vector2(-size, 0.0), at + Vector2(size, 0.0), tint, maxf(1.0, size * 0.22), true)
    draw_line(at + Vector2(0.0, -size * 1.25), at + Vector2(0.0, size * 1.25), tint, maxf(1.0, size * 0.22), true)
    draw_circle(at, size * 0.15, Color(1.0, 1.0, 0.94, tint.a))
