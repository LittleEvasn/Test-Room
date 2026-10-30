extends Node2D
## 꽃잎 하나를 복제/회전해 순간 개화와 흩날리는 파편을 만든다.
## 충격파는 VFX 실험실에 설정된 폭발 반경까지 확장된다.

const PETAL_TEXTURE: Texture2D = preload("res://assets/꽃.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/spark.png")
const DURATION := 0.62

var elapsed := 0.0
var blast_radius := 70.0
var density := 1.0
var rank := 0
var petals: Array[Dictionary] = []
var sparks: Array[Dictionary] = []

func configure(radius: float, particle_density: float, upgrade_rank: int) -> void:
    blast_radius = radius
    density = maxf(0.0, particle_density)
    rank = clampi(upgrade_rank, 0, 3)

func _ready() -> void:
    var count := int(roundi(float(10 + rank * 5) * density))
    count = clampi(count, 0, 50)
    for i in count:
        var theta := TAU * float(i % 5) / 5.0 + randf_range(-0.26, 0.26)
        petals.append({
            "angle": theta,
            "speed": randf_range(blast_radius * 1.15, blast_radius * 1.95),
            "size": randf_range(21.0, 42.0) * (0.85 + 0.08 * rank),
            "spin": randf_range(-7.0, 7.0),
            "phase": randf_range(-0.3, 0.3)
        })
    var spark_count := clampi(int(roundi(15.0 * density)), 0, 60)
    for i in spark_count:
        var theta := randf_range(0.0, TAU)
        sparks.append({
            "vel": Vector2.RIGHT.rotated(theta) * randf_range(65.0, 230.0),
            "size": randf_range(3.0, 7.0)
        })
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= DURATION:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var progress := clampf(elapsed / DURATION, 0.0, 1.0)
    var flower_phase := clampf(elapsed / 0.18, 0.0, 1.0)
    var open := 1.0 - pow(1.0 - flower_phase, 3.0)
    var flower_alpha := 1.0 - smoothstep(0.13, 0.40, elapsed)
    var ring_progress := clampf(elapsed / 0.23, 0.0, 1.0)
    var ring_alpha := 1.0 - smoothstep(0.12, 0.40, elapsed)

    # 즉발 피해의 최대 범위를 정확하게 표시한다.
    draw_circle(Vector2.ZERO, blast_radius * (0.15 + 0.55 * open), Color(1.0, 0.67, 0.73, 0.17 * flower_alpha))
    draw_arc(Vector2.ZERO, maxf(1.0, blast_radius * ring_progress), 0.0, TAU, 64, Color(1.0, 0.73, 0.79, 0.92 * ring_alpha), 6.0, true)
    draw_arc(Vector2.ZERO, maxf(1.0, blast_radius * ring_progress * 0.72), 0.0, TAU, 56, Color(1.0, 0.94, 0.79, 0.34 * ring_alpha), 2.0, true)

    # 꽃잎 다섯 장을 72도 간격으로 펼쳐서 폭발의 바깥 경계까지 확장한다.
    for i in 5:
        var angle := TAU * float(i) / 5.0 - PI * 0.5
        var outward := Vector2.RIGHT.rotated(angle) * blast_radius * (0.10 + 0.38 * open)
        var size := blast_radius * (0.28 + 0.70 * open)
        draw_set_transform(outward, angle + PI * 0.5, Vector2.ONE)
        draw_texture_rect(PETAL_TEXTURE, Rect2(-Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(1.0, 1.0, 1.0, flower_alpha * 0.95))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    # 꽃잎 파편은 폭발 이후 따로 날아가며 서서히 사라진다.
    for petal in petals:
        var velocity_dir := Vector2.RIGHT.rotated(float(petal["angle"]))
        var travel := float(petal["speed"]) * elapsed * (1.0 - progress * 0.26)
        var pt := velocity_dir * travel + velocity_dir.orthogonal() * sin(elapsed * 9.0 + float(petal["phase"])) * (5.0 * progress)
        var size := float(petal["size"]) * (0.50 + 0.50 * (1.0 - progress))
        draw_set_transform(pt, float(petal["angle"]) + elapsed * float(petal["spin"]), Vector2.ONE)
        draw_texture_rect(PETAL_TEXTURE, Rect2(-Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(1.0, 1.0, 1.0, pow(1.0 - progress, 1.4)))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    for spark in sparks:
        var pt := Vector2(spark["vel"]) * elapsed * (1.0 - 0.25 * progress)
        var size := float(spark["size"]) * (0.45 + 0.55 * (1.0 - progress))
        draw_texture_rect(SPARK_TEXTURE, Rect2(pt - Vector2.ONE * size, Vector2.ONE * size * 2.0), false, Color(1.0, 0.94, 0.74, 0.9 * (1.0 - progress)))

    var flash := 1.0 - smoothstep(0.0, 0.13, elapsed)
    draw_circle(Vector2.ZERO, blast_radius * 0.16 * (1.0 + open * 0.4), Color(1.0, 0.97, 0.87, 0.85 * flash))
    draw_circle(Vector2.ZERO, blast_radius * 0.075, Color(1.0, 1.0, 1.0, 0.93 * flash))
