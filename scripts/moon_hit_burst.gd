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

    # 베기 궤적 주변에 달빛 점·보라색 수정 파편·작은 원호가 따로 번진다.
    for i in 12:
        var angle := float(i) * TAU / 12.0 + turn
        var pt := Vector2.RIGHT.rotated(angle) * (17.0 + 59.0 * progress) * scale_factor
        var spark_size := (3.5 + float(i % 4) * 1.25) * (1.0 - progress * 0.62) * scale_factor
        match i % 3:
            0:
                draw_circle(pt, spark_size * 0.85, Color(0.64, 0.54, 1.0, alpha * 0.25))
                draw_circle(pt, spark_size * 0.37, Color(0.93, 0.91, 1.0, alpha * 0.9))
            1:
                _draw_hit_shard(pt, spark_size, angle + elapsed * 4.0, Color(0.76, 0.65, 1.0, alpha * 0.9))
            2:
                draw_arc(pt, spark_size * 1.4, angle, angle + 1.6, 9, Color(0.89, 0.82, 1.0, alpha * 0.82), maxf(1.0, spark_size * 0.25), true)

func _draw_hit_shard(at: Vector2, radius: float, angle: float, tint: Color) -> void:
    var polygon := PackedVector2Array([
        Vector2(0.0, -radius * 1.5),
        Vector2(radius * 0.55, -radius * 0.22),
        Vector2(0.0, radius * 1.05),
        Vector2(-radius * 0.55, radius * 0.22)
    ])
    for i in polygon.size():
        polygon[i] = at + polygon[i].rotated(angle)
    draw_colored_polygon(polygon, tint)
