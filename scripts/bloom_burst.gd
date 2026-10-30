extends Node2D
## 꽃잎 하나를 복제/회전해 순간 개화와 흩날리는 파편을 만든다.
## 충격파의 최대 반경은 게임의 폭발 반경 값과 동일하다.

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
    var count := int(roundi(float(8 + rank * 2) * density))
    count = clampi(count, 0, 50)
    for i in count:
        var theta := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.22, 0.22)
        petals.append({
            "angle": theta,
            "speed": randf_range(blast_radius * 1.0, blast_radius * 1.8),
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
    draw_circle(Vector2.ZERO, blast_radius * (0.12 + 0.18 * open), Color(1.0, 0.67, 0.73, 0.20 * flower_alpha))
    draw_arc(Vector2.ZERO, maxf(1.0, blast_radius * ring_progress), 0.0, TAU, 64, Color(1.0, 0.73, 0.79, 0.88 * ring_alpha), 4.0, true)
    draw_arc(Vector2.ZERO, maxf(1.0, blast_radius * ring_progress * 0.72), 0.0, TAU, 56, Color(1.0, 0.94, 0.79, 0.34 * ring_alpha), 2.0, true)

    # 작은 꽃봉오리가 찰나에 여섯 꽃잎으로 열리는 모습.
    for i in 6:
        var angle := TAU * float(i) / 6.0 - PI * 0.5
        var outward := Vector2.RIGHT.rotated(angle) * blast_radius * (0.08 + 0.28 * open)
        var size := blast_radius * (0.25 + 0.43 * open)
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
