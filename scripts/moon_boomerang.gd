extends Node2D
## 달빛 부메랑: 진짜 왕복 궤적을 갖는 독립 VFX 테스트용 투사체.
## 투사체 이미지는 사용자가 올린 assets/달빛 부메랑.png 한 장이다.

signal struck(at: Vector2)
signal returned(at: Vector2)

const MOON_TEXTURE: Texture2D = preload("res://assets/달빛 부메랑.png")
const OUTBOUND_TIME := 0.84
const RETURN_TIME := 0.70
const IMAGE_DIAMETER := 96.0
const MAX_TRAIL := 18
const MAX_MOTES := 96

var origin := Vector2.ZERO
var destination := Vector2.ZERO
var outbound_control := Vector2.ZERO
var return_control := Vector2.ZERO
var leg_time := 0.0
var age := 0.0
var returning := false
var emission_density := 1.0
var emission_carry := 0.0
var trail: Array[Vector2] = []
var motes: Array[Dictionary] = []

func configure(start_pos: Vector2, end_pos: Vector2, density: float) -> void:
    origin = start_pos
    destination = end_pos
    position = start_pos
    emission_density = maxf(0.0, density)

    var delta_pos := destination - origin
    var length := maxf(delta_pos.length(), 1.0)
    var direction := delta_pos / length
    var normal := direction.orthogonal()
    var bend := clampf(length * 0.24, 50.0, 205.0)
    var side := -1.0 if randf() < 0.5 else 1.0
    var midpoint := (origin + destination) * 0.5

    # 출격과 귀환의 곡선이 서로 반대편을 지나가며 한 바퀴 도는 실루엣을 만든다.
    outbound_control = midpoint + normal * bend * side
    return_control = midpoint - normal * bend * side * 0.85

func _process(delta: float) -> void:
    age += delta
    leg_time += delta

    if has_meta("aux_orbit"):
        # Orbit is externally positioned. Keep original trail/mote art without
        # running the outbound/return timers that would end this preview early.
        trail.append(global_position)
        if trail.size() > MAX_TRAIL:
            trail.pop_front()
        _advance_motes(delta)
        _emit_motes(delta)
        queue_redraw()
        return

    if not returning:
        var t := minf(1.0, leg_time / OUTBOUND_TIME)
        global_position = _bezier(origin, outbound_control, destination, t)
        if t >= 1.0:
            struck.emit(destination)
            returning = true
            leg_time = 0.0
    else:
        var t := minf(1.0, leg_time / RETURN_TIME)
        global_position = _bezier(destination, return_control, origin, t)
        if t >= 1.0:
            returned.emit(origin)
            queue_free()
            return

    trail.append(global_position)
    if trail.size() > MAX_TRAIL:
        trail.pop_front()
    _advance_motes(delta)
    _emit_motes(delta)
    queue_redraw()

func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
    var reverse := 1.0 - t
    return a * reverse * reverse + control * 2.0 * reverse * t + b * t * t

func _advance_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var mote: Dictionary = motes[i]
        mote["life"] = float(mote["life"]) - delta
        if float(mote["life"]) <= 0.0:
            motes.remove_at(i)
        else:
            mote["pos"] = Vector2(mote["pos"]) + Vector2(mote["vel"]) * delta
            mote["angle"] = float(mote["angle"]) + float(mote["spin"]) * delta

func _emit_motes(delta: float) -> void:
    emission_carry = minf(4.0, emission_carry + delta * 43.0 * emission_density)
    while emission_carry >= 1.0 and motes.size() < MAX_MOTES:
        emission_carry -= 1.0
        var life := randf_range(0.24, 0.52)
        var roll := randf()
        var kind := 0 if roll < 0.36 else (1 if roll < 0.64 else (2 if roll < 0.87 else 3))
        motes.append({
            "pos": global_position + Vector2(randf_range(-17.0, 17.0), randf_range(-17.0, 17.0)),
            "vel": Vector2(randf_range(-75.0, 75.0), randf_range(-75.0, 75.0)),
            "life": life,
            "total": life,
            "size": randf_range(4.0, 10.0),
            "kind": kind,
            "angle": randf_range(0.0, TAU),
            "spin": randf_range(-4.0, 4.0)
        })

func _draw() -> void:
    # 짧은 유령 초승달 잔상: 실제 이미지의 실루엣을 이용해 궤적을 드러낸다.
    for i in range(0, trail.size(), 3):
        var fraction := float(i + 1) / float(MAX_TRAIL)
        var at := to_local(trail[i])
        var diameter := IMAGE_DIAMETER * (0.72 + 0.20 * fraction)
        draw_set_transform(at, age * 13.0 - (1.0 - fraction) * 0.95, Vector2.ONE)
        draw_texture_rect(
            MOON_TEXTURE,
            Rect2(-Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter),
            false,
            Color(0.79, 0.71, 1.0, fraction * 0.31)
        )
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    for mote in motes:
        var fade := clampf(float(mote["life"]) / float(mote["total"]), 0.0, 1.0)
        var local_pos := to_local(Vector2(mote["pos"]))
        var radius := float(mote["size"]) * (0.4 + fade * 0.6)
        match int(mote["kind"]):
            0:
                draw_circle(local_pos, radius * 0.76, Color(0.56, 0.48, 1.0, fade * 0.16))
                draw_circle(local_pos, radius * 0.34, Color(0.76, 0.77, 1.0, fade * 0.77))
                draw_circle(local_pos, radius * 0.12, Color(1.0, 0.98, 1.0, fade * 0.95))
            1:
                _draw_moon_shard(local_pos, radius, float(mote["angle"]), Color(0.69, 0.57, 1.0, fade * 0.84))
            2:
                draw_arc(local_pos, radius * 1.1, float(mote["angle"]), float(mote["angle"]) + 1.7, 10, Color(0.85, 0.79, 1.0, fade * 0.88), maxf(1.0, radius * 0.23), true)
            3:
                draw_line(local_pos + Vector2(-radius * 1.1, 0), local_pos + Vector2(radius * 1.1, 0), Color(0.89, 0.83, 1.0, fade * 0.87), maxf(1.0, radius * 0.2), true)
                draw_line(local_pos + Vector2(0, -radius * 1.6), local_pos + Vector2(0, radius * 1.6), Color(0.96, 0.94, 1.0, fade * 0.92), maxf(1.0, radius * 0.2), true)

    # 본체는 독립적으로 회전하며, 곡선 비행의 방향과 무관하게 팽이처럼 돈다.
    draw_circle(Vector2.ZERO, IMAGE_DIAMETER * 0.47, Color(0.65, 0.56, 1.0, 0.11))
    draw_circle(Vector2.ZERO, IMAGE_DIAMETER * 0.27, Color(0.92, 0.85, 1.0, 0.11))
    draw_set_transform(Vector2.ZERO, age * 13.0, Vector2.ONE)
    var diameter := IMAGE_DIAMETER * (1.0 + sin(age * 14.0) * 0.025)
    draw_texture_rect(MOON_TEXTURE, Rect2(-Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_moon_shard(at: Vector2, radius: float, angle: float, tint: Color) -> void:
    var polygon := PackedVector2Array([
        Vector2(-radius * 0.30, -radius),
        Vector2(radius * 0.45, -radius * 0.60),
        Vector2(radius * 0.32, radius),
        Vector2(-radius * 0.45, radius * 0.60)
    ])
    for i in polygon.size():
        polygon[i] = at + polygon[i].rotated(angle)
    draw_colored_polygon(polygon, tint)
    draw_line(at - Vector2.RIGHT.rotated(angle) * radius * 0.38, at + Vector2.RIGHT.rotated(angle) * radius * 0.38, Color(0.98, 0.93, 1.0, tint.a * 0.6), 1.0, true)
