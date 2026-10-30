extends Node2D
## 소용돌이 씨앗 / 블랙홀 VFX v2: 거대한 암흑 중심 + 넓은 강착 원반.
## 구 버전의 보라색 다중 타원·나선 팔·수정 장식은 폐기.
## 시각 효과만 구현하며 실제 적 흡입/피해는 본게임에서 별도 연결한다.

signal pulsed(at: Vector2, radius: float)
signal vanished(at: Vector2)

const LIFETIME := 5.0
const TICK_INTERVAL := 0.25
const BIRTH_TIME := 0.26
const COLLAPSE_TIME := 0.42
const BASE_RADIUS := 94.0
# 본게임 +0~+3 성장 계수는 아직 미확정. 이 값은 비교용 모의 계수이다.
const PREVIEW_GROWTH := [0.0, 0.07, 0.14, 0.21]
const MAX_MOTES := 72

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
    global_position = at
    rank = clampi(upgrade_rank, 0, 3)
    density = clampf(particle_density, 0.0, 3.0)
    drift = (toward - at).normalized()
    if drift.length_squared() < 0.01:
        drift = Vector2.LEFT

func _radius() -> float:
    return BASE_RADIUS * (1.0 + float(PREVIEW_GROWTH[rank]) * minf(elapsed, LIFETIME - COLLAPSE_TIME))

func _appearance() -> float:
    var birth := 1.0 - pow(1.0 - clampf(elapsed / BIRTH_TIME, 0.0, 1.0), 3.0)
    var end := clampf((LIFETIME - elapsed) / COLLAPSE_TIME, 0.0, 1.0)
    end = end * end * (3.0 - 2.0 * end)
    return maxf(0.0, birth * end)

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= LIFETIME:
        vanished.emit(global_position)
        queue_free()
        return

    # 완전히 정지된 장판이 아니라 천천히 전진하는 개체. 이동 폭은 과장하지 않는다.
    global_position = spawn_pos + drift * (elapsed * 24.0)

    tick_clock += delta
    while tick_clock >= TICK_INTERVAL:
        tick_clock -= TICK_INTERVAL
        if elapsed < LIFETIME - COLLAPSE_TIME:
            pulsed.emit(global_position, _radius())

    _advance_motes(delta)
    if elapsed < LIFETIME - COLLAPSE_TIME:
        _emit_motes(delta)
    queue_redraw()

func _emit_motes(delta: float) -> void:
    emit_carry = minf(4.0, emit_carry + delta * 22.0 * density)
    while emit_carry >= 1.0 and motes.size() < MAX_MOTES:
        emit_carry -= 1.0
        var theta := randf_range(0.0, TAU)
        var distance := _radius() * randf_range(0.98, 1.30)
        var lifetime := randf_range(0.78, 1.75)
        motes.append({
            "pos": global_position + Vector2.RIGHT.rotated(theta) * distance,
            "life": lifetime,
            "total": lifetime,
            "size": randf_range(1.8, 4.8),
            "kind": randi_range(0, 2),
            "spin": randf_range(0.65, 1.15),
            "speed": randf_range(90.0, 137.0)
        })

func _advance_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var mote: Dictionary = motes[i]
        var world_pos: Vector2 = mote["pos"]
        var to_center := global_position - world_pos
        var distance := to_center.length()
        mote["life"] = float(mote["life"]) - delta
        if float(mote["life"]) <= 0.0 or distance <= _radius() * 0.42:
            motes.remove_at(i)
            continue
        var inward := to_center / maxf(distance, 0.01)
        var inward_speed := float(mote["speed"]) * (1.0 + clampf(1.0 - distance / (_radius() * 1.4), 0.0, 0.65))
        var tangent := inward.orthogonal()
        mote["pos"] = world_pos + (inward * inward_speed + tangent * inward_speed * float(mote["spin"]) * 0.66) * delta

func _draw() -> void:
    var amount := _appearance()
    var radius := _radius() * amount
    if radius < 1.0:
        return

    var phase := elapsed * 1.65
    var core := radius * 0.48
    var tick_flash := pow(1.0 - clampf(tick_clock / TICK_INTERVAL, 0.0, 1.0), 4.0)

    # 강한 암흑 중심을 먼저 위한, 넓고 탁한 청록·황록색 강착 원반.
    # 얇은 타원선을 겹치는 대신 두껍고 부드러운 띠를 원형으로 배치한다.
    draw_circle(Vector2.ZERO, radius * 1.08, Color(0.15, 0.27, 0.29, 0.075 * amount))
    draw_circle(Vector2.ZERO, radius * 1.01, Color(0.18, 0.32, 0.30, 0.15 * amount))
    draw_circle(Vector2.ZERO, radius * 0.94, Color(0.20, 0.32, 0.21, 0.27 * amount))
    draw_circle(Vector2.ZERO, radius * 0.84, Color(0.34, 0.40, 0.18, 0.28 * amount))
    draw_circle(Vector2.ZERO, radius * 0.71, Color(0.18, 0.37, 0.34, 0.43 * amount))

    # 둥근 가스 띠 4개: 서로 다른 폭/명도로 회전하는 강착 원반.
    # 나선 팔 모양을 명확히 그리지 않아 바람개비처럼 보이지 않게 한다.
    for band in 4:
        var angle := phase * (0.67 + float(band) * 0.13) + float(band) * TAU / 4.0
        var band_color := Color(0.34, 0.67, 0.56, 0.27 * amount)
        match band:
            0: band_color = Color(0.78, 0.81, 0.38, 0.48 * amount)
            1: band_color = Color(0.21, 0.68, 0.70, 0.40 * amount)
            2: band_color = Color(0.50, 0.72, 0.35, 0.38 * amount)
            3: band_color = Color(0.30, 0.50, 0.81, 0.29 * amount)
        _draw_gas_band(radius, angle, band_color, float(band))

    # 넓고 희미한 안쪽 회전 고리. 특정 지점만 강하게 빛나도록 불균일하게 처리.
    draw_arc(Vector2.ZERO, radius * 0.65, phase, phase + 1.85, 42, Color(0.64, 0.83, 0.52, 0.42 * amount), radius * 0.095, true)
    draw_arc(Vector2.ZERO, radius * 0.64, phase + PI, phase + PI + 1.35, 33, Color(0.30, 0.75, 0.80, 0.43 * amount), radius * 0.075, true)
    draw_arc(Vector2.ZERO, radius * 0.85, -phase * 0.72 + 1.2, -phase * 0.72 + 2.55, 28, Color(0.78, 0.86, 0.49, 0.30 * amount), radius * 0.065, true)

    # 실제로 바깥에서 안으로 끌려오는 입자. 금빛 반짝이나 수정 조각은 넣지 않는다.
    for mote in motes:
        var f := clampf(float(mote["life"]) / float(mote["total"]), 0.0, 1.0)
        var at := to_local(Vector2(mote["pos"]))
        var size := float(mote["size"]) * (0.5 + 0.5 * f)
        var alpha := amount * minf(1.0, f * 3.0)
        var toward := -at.normalized()
        match int(mote["kind"]):
            0:
                draw_circle(at, size * 0.7, Color(0.81, 0.91, 0.66, alpha * 0.72))
            1:
                draw_line(at - toward * size * 1.9, at + toward * size * 0.65, Color(0.43, 0.85, 0.91, alpha * 0.82), maxf(1.0, size * 0.46), true)
            2:
                draw_circle(at, size * 0.85, Color(0.61, 0.75, 0.40, alpha * 0.19))
                draw_circle(at, size * 0.34, Color(0.90, 0.96, 0.84, alpha * 0.80))

    # 이벤트 호라이즌: 중심부를 크게 확보해야 '블랙홀'로 인지된다.
    draw_circle(Vector2.ZERO, core * 1.20, Color(0.19, 0.48, 0.50, 0.28 * amount))
    draw_circle(Vector2.ZERO, core * 1.10, Color(0.45, 0.78, 0.73, (0.55 + tick_flash * 0.06) * amount))
    draw_circle(Vector2.ZERO, core * 1.025, Color(0.066, 0.11, 0.13, amount))
    draw_circle(Vector2.ZERO, core, Color(0.006, 0.009, 0.018, amount))

    # 광량이 일정한 흰 링 대신 '굴절된 밝은 가장자리' 일부만 남긴다.
    draw_arc(Vector2.ZERO, core * 1.10, phase * 0.92 - 0.9, phase * 0.92 + 0.82, 32, Color(0.81, 0.99, 0.90, 0.79 * amount), 2.8, true)
    draw_arc(Vector2.ZERO, core * 1.10, phase * 0.92 + 2.2, phase * 0.92 + 3.0, 22, Color(0.66, 0.91, 0.93, 0.44 * amount), 2.3, true)

func _draw_gas_band(radius: float, start_angle: float, tint: Color, band_index: float) -> void:
    var polygon := PackedVector2Array()
    var inner_points := PackedVector2Array()
    var steps := 24
    for i in steps + 1:
        var t := float(i) / float(steps)
        var angle := start_angle + t * (1.72 + band_index * 0.07)
        var radial := radius * (0.68 + 0.16 * t + 0.028 * sin(t * PI * 2.0 + band_index))
        var taper := pow(sin(t * PI), 0.7)
        var width := radius * (0.008 + 0.091 * taper)
        polygon.append(Vector2.RIGHT.rotated(angle) * (radial + width))
        inner_points.append(Vector2.RIGHT.rotated(angle) * (radial - width))
    for i in range(inner_points.size() - 1, -1, -1):
        polygon.append(inner_points[i])
    draw_colored_polygon(polygon, tint)
