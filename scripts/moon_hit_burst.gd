extends Node2D
## 달빛 부메랑의 출격 타격 / 귀환 완료용 짧은 섬광.

const DURATION := 0.32

var elapsed := 0.0
var recovery := false
var turn := 0.0

func configure(is_recovery: bool = false) -> void:
    recovery = is_recovery
    turn = randf_range(-0.4, 0.4)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= DURATION:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var progress := clampf(elapsed / DURATION, 0.0, 1.0)
    var alpha := pow(1.0 - progress, 1.6)
    var scale_factor := 0.60 if recovery else 1.0
    var radius := (23.0 + 35.0 * progress) * scale_factor

    draw_arc(Vector2.ZERO, radius, turn - 0.7, turn + 1.45, 20, Color(0.92, 0.84, 1.0, alpha), 5.0 * scale_factor, true)
    draw_arc(Vector2.ZERO, radius * 0.72, turn + PI * 0.45, turn + PI * 1.45, 16, Color(0.67, 0.58, 1.0, alpha * 0.85), 3.5 * scale_factor, true)
    draw_circle(Vector2.ZERO, (14.0 + 15.0 * progress) * scale_factor, Color(0.84, 0.74, 1.0, alpha * 0.16))
    draw_circle(Vector2.ZERO, (7.0 + 8.0 * progress) * scale_factor, Color(1.0, 0.96, 1.0, alpha * 0.55))

    for i in 7:
        var angle := float(i) * TAU / 7.0 + turn
        var pt := Vector2.RIGHT.rotated(angle) * (17.0 + 52.0 * progress) * scale_factor
        var spark_size := (3.0 + float(i % 3) * 1.2) * (1.0 - progress * 0.65)
        draw_circle(pt, spark_size, Color(0.84, 0.78, 1.0, alpha * 0.85))
