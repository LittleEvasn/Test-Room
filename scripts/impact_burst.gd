extends Node2D
## 명중 시 0.4초 동안 원형 섬광, 별 조각, 스파크를 표시.

const SPARK_TEXTURE: Texture2D = preload("res://assets/spark.png")
const DURATION := 0.44
var elapsed := 0.0
var fragments: Array[Dictionary] = []

func _ready() -> void:
    for i in range(16):
        var theta := (float(i) / 16.0) * TAU + randf_range(-0.15, 0.15)
        var speed := randf_range(65.0, 185.0)
        fragments.append({"velocity": Vector2.RIGHT.rotated(theta) * speed, "size": randf_range(4.0, 10.0)})

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
        draw_texture_rect(SPARK_TEXTURE, Rect2(pt - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(1.0, 1.0, 1.0, fade))
