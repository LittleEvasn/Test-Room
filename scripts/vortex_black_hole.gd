extends Node2D
## 블랙홀(소용돌이 씨앗) VFX 실험실 전용.
## 본게임의 흡입/피해 판정은 건드리지 않는다. 시각 반경과 0.25초 펄스만 모의한다.

signal pulsed(at: Vector2, radius: float)
signal vanished(at: Vector2)

const LIFETIME := 5.0
const TICK_INTERVAL := 0.25
const BIRTH_TIME := 0.30
const COLLAPSE_TIME := 0.48
const BASE_RADIUS := 76.0
# 4단계로 비교하기 위한 임시 시각 성장 계수: 원작 3단계와의 대응은 아직 미확정.
const PREVIEW_GROWTH := [0.0, 0.07, 0.14, 0.21]
const MAX_MOTES := 115

var elapsed := 0.0
var tick_clock := 0.0
var density := 1.0
var rank := 0
var spawn_pos := Vector2.ZERO
var drift := Vector2.LEFT
var emit_carry := 0.0
var motes: Array[Dictionary] = []

func configure(at: Vector2, toward: Vector2, particle_density: float, upgrade_rank: int) -> void:
    spawn_pos = at
    position = at
    rank = clampi(upgrade_rank, 0, 3)
    density = clampf(particle_density, 0.0, 3.0)
    drift = (toward - at).normalized()
    if drift.length_squared() < 0.01:
        drift = Vector2.LEFT

func _radius() -> float:
    return BASE_RADIUS * (1.0 + float(PREVIEW_GROWTH[rank]) * minf(elapsed, LIFETIME - COLLAPSE_TIME))

func _visual_radius() -> float:
    var birth := 1.0 - pow(1.0 - clampf(elapsed / BIRTH_TIME, 0.0, 1.0), 3.0)
    var collapse := clampf((LIFETIME - elapsed) / COLLAPSE_TIME, 0.0, 1.0)
    collapse = collapse * collapse * (3.0 - 2.0 * collapse)
    return _radius() * birth * (0.08 + collapse * 0.92)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= LIFETIME:
        vanished.emit(global_position)
        queue_free()
        return

    # 표적에서 형성된 뒤 천천히 이동하며, 미세하게 휘어지는 궤적을 따른다.
    global_position = spawn_pos + drift * (elapsed * 54.0) + drift.orthogonal() * (sin(elapsed * 1.7) * 25.0)

    tick_clock += delta
    while tick_clock >= TICK_INTERVAL:
        tick_clock -= TICK_INTERVAL
        if elapsed < LIFETIME - COLLAPSE_TIME:
            pulsed.emit(global_position, _radius())

    _advance_motes(delta)
    if elapsed < LIFETIME - COLLAPSE_TIME:
        _emit_motes(delta)
    queue_redraw()

func _advance_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var mote: Dictionary = motes[i]
        mote["life"] = float(mote["life"]) - delta
        mote["distance"] = float(mote["distance"]) - float(mote["speed"]) * delta
        mote["angle"] = float(mote["angle"]) + float(mote["spin"]) * delta
        if float(mote["life"]) <= 0.0 or float(mote["distance"]) <= _visual_radius() * 0.24:
            motes.remove_at(i)

func _emit_motes(delta: float) -> void:
    emit_carry = minf(5.0, emit_carry + delta * (38.0 * density))
    while emit_carry >= 1.0 and motes.size() < MAX_MOTES:
        emit_carry -= 1.0
        var radius := maxf(16.0, _visual_radius())
        var start_distance := radius * randf_range(1.12, 1.49)
        var speed := randf_range(155.0, 235.0) * (0.8 + rank * 0.1)
        var life := clampf((start_distance - radius * 0.23) / speed + 0.17, 0.42, 2.5)
        motes.append({
            "angle": randf_range(0.0, TAU),
            "distance": start_distance,
            "speed": speed,
            "spin": randf_range(-4.0, -1.9),
            "life": life,
            "total": life,
            "size": randf_range(2.7, 7.8),
            "kind": randi_range(0, 3)
        })

func _draw() -> void:
    var radius := _visual_radius()
    if radius < 1.0:
        return
    var appear := clampf(elapsed / 0.18, 0.0, 1.0)
    var fade := clampf((LIFETIME - elapsed) / 0.26, 0.0, 1.0)
    var opacity := appear * fade
    var rotation_phase := elapsed * 2.4
    var tick_glow := pow(1.0 - tick_clock / TICK_INTERVAL, 3.0)

    # 보라색 중력권과 청백색 먼지 원반. 공격 판정 반경의 크기 변화를 그대로 따른다.
    draw_circle(Vector2.ZERO, radius * 1.09, Color(0.28, 0.16, 0.64, 0.095 * opacity))
    draw_circle(Vector2.ZERO, radius * 0.80, Color(0.53, 0.36, 0.85, 0.15 * opacity))
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 76, Color(0.70, 0.51, 1.0, 0.24 * opacity), 1.7, true)

    draw_set_transform(Vector2.ZERO, rotation_phase * 0.45, Vector2(1.0, 0.64))
    draw_arc(Vector2.ZERO, radius * 0.77, 0.0, TAU, 76, Color(0.55, 0.33, 0.94, 0.40 * opacity), 7.5, true)
    draw_arc(Vector2.ZERO, radius * 0.77, -0.30, 1.8, 32, Color(0.92, 0.85, 1.0, 0.88 * opacity), 4.0, true)
    draw_set_transform(Vector2.ZERO, rotation_phase * -0.35, Vector2(1.0, 0.82))
    draw_arc(Vector2.ZERO, radius * 0.93, 0.25, 3.75, 52, Color(0.50, 0.73, 1.0, 0.42 * opacity), 3.0, true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    # 네 개의 나선 팔이 검은 중심핵 쪽으로 말려 들어간다.
    for arm in 4:
        var points := PackedVector2Array()
        for j in 18:
            var t := float(j) / 17.0
            var spiral_radius := radius * (0.29 + 0.60 * t)
            var angle := float(arm) * TAU / 4.0 - rotation_phase + t * 3.15
            points.append(Vector2.RIGHT.rotated(angle) * spiral_radius)
        draw_polyline(points, Color(0.80, 0.66, 1.0, (0.32 if arm % 2 == 0 else 0.21) * opacity), 2.4, true)

    # 궤도 밖에서 생성된 입자 네 종류가 실제로 중심으로 이동하면서 사라진다.
    for mote in motes:
        var life_fraction := clampf(float(mote["life"]) / float(mote["total"]), 0.0, 1.0)
        var point := Vector2.RIGHT.rotated(float(mote["angle"])) * float(mote["distance"])
        var size := float(mote["size"]) * (0.5 + 0.5 * life_fraction)
        var alpha := opacity * minf(1.0, life_fraction * 2.2)
        match int(mote["kind"]):
            0:
                draw_circle(point, size * 0.8, Color(0.65, 0.40, 1.0, alpha * 0.24))
                draw_circle(point, size * 0.31, Color(0.91, 0.79, 1.0, alpha * 0.95))
            1:
                _draw_shard(point, size, float(mote["angle"]) + PI * 0.5, Color(0.56, 0.76, 1.0, alpha * 0.82))
            2:
                var tangent := Vector2.RIGHT.rotated(float(mote["angle"]) + PI * 0.5)
                draw_line(point - tangent * size * 1.8, point + tangent * size * 0.7, Color(0.82, 0.65, 1.0, alpha * 0.84), maxf(1.0, size * 0.29), true)
            3:
                draw_arc(point, size, float(mote["angle"]), float(mote["angle"]) + 1.85, 9, Color(0.86, 0.93, 1.0, alpha * 0.9), maxf(1.0, size * 0.3), true)

    # 반짝이는 고리 속의 절대적인 검은 중심. 피해 틱마다 미세하게 테두리가 맥동한다.
    var core := radius * 0.27
    draw_circle(Vector2.ZERO, core * 1.38, Color(0.58, 0.32, 0.96, (0.20 + tick_glow * 0.08) * opacity))
    draw_circle(Vector2.ZERO, core * 1.08, Color(0.71, 0.54, 1.0, 0.87 * opacity))
    draw_circle(Vector2.ZERO, core, Color(0.055, 0.035, 0.12, opacity))
    draw_circle(Vector2.ZERO, core * 0.85, Color(0.012, 0.009, 0.035, opacity))
    draw_arc(Vector2.ZERO, core * 1.08, -rotation_phase, -rotation_phase + PI * 0.83, 26, Color(0.95, 0.89, 1.0, (0.52 + 0.16 * tick_glow) * opacity), 2.5, true)

func _draw_shard(at: Vector2, size: float, angle: float, tint: Color) -> void:
    var polygon := PackedVector2Array([
        Vector2(-size * 0.4, -size),
        Vector2(size * 0.5, -size * 0.3),
        Vector2(size * 0.25, size),
        Vector2(-size * 0.5, size * 0.2)
    ])
    for i in polygon.size():
        polygon[i] = at + polygon[i].rotated(angle)
    draw_colored_polygon(polygon, tint)
