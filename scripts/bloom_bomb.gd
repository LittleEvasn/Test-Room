extends Node2D
## 꽃탄.png는 투사체 본체, 꽃.png는 이동 중 흩날리는 꽃잎 한 장이다.
## 이 실험실에서는 실제 몬스터 판정 대신 표적 도착/수명 종료를 폭발 사건으로 취급한다.

signal impacted(at: Vector2, radius: float)

const CORE_TEXTURE: Texture2D = preload("res://assets/꽃탄.png")
const PETAL_TEXTURE: Texture2D = preload("res://assets/꽃.png")
const SPEED := 455.0
const MAX_LIFETIME := 2.6
const CORE_DIAMETER := 84.0
const MAX_PARTICLES := 90

var destination := Vector2.ZERO
var heading := Vector2.RIGHT
var elapsed := 0.0
var blast_radius := 70.0
var emission_density := 1.0
var emission_carry := 0.0
var motes: Array[Dictionary] = []

func configure(start_pos: Vector2, end_pos: Vector2, density: float, radius: float) -> void:
    position = start_pos
    destination = end_pos
    heading = start_pos.direction_to(end_pos)
    if heading.length_squared() < 0.001:
        heading = Vector2.RIGHT
    emission_density = maxf(0.0, density)
    blast_radius = radius

func _process(delta: float) -> void:
    elapsed += delta
    _update_motes(delta)

    var distance_left := global_position.distance_to(destination)
    var step := SPEED * delta
    if has_meta("aux_falling"):
        # Particle update, emission, and petal spin continue while descending.
        heading = Vector2(get_meta("aux_fall_direction", heading))
    else:
        if distance_left <= step + 8.0 or elapsed >= MAX_LIFETIME:
            var blast_at := destination if distance_left <= step + 8.0 else global_position
            impacted.emit(blast_at, blast_radius)
            queue_free()
            return
        global_position += heading * step
    emission_carry += delta * 29.0 * emission_density
    while emission_carry >= 1.0 and motes.size() < MAX_PARTICLES:
        emission_carry -= 1.0
        var life := randf_range(0.24, 0.62)
        var roll := randf()
        var kind := 0 if roll < 0.52 else (1 if roll < 0.83 else 2)
        motes.append({
            "kind": kind,
            "pos": global_position - heading * randf_range(14.0, 37.0) + heading.orthogonal() * randf_range(-17.0, 17.0),
            "vel": -heading * randf_range(25.0, 75.0) + heading.orthogonal() * randf_range(-60.0, 60.0),
            "life": life,
            "total": life,
            "size": randf_range(13.0, 24.0) if kind == 0 else randf_range(4.0, 9.0),
            "angle": randf_range(0.0, TAU),
            "spin": randf_range(-5.0, 5.0)
        })
    queue_redraw()

func _update_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var mote: Dictionary = motes[i]
        mote["life"] = float(mote["life"]) - delta
        if float(mote["life"]) <= 0.0:
            motes.remove_at(i)
            continue
        mote["pos"] = Vector2(mote["pos"]) + Vector2(mote["vel"]) * delta
        mote["angle"] = float(mote["angle"]) + float(mote["spin"]) * delta

func _draw() -> void:
    var backwards := -heading
    draw_line(backwards * 66.0, backwards * 10.0, Color(1.0, 0.53, 0.64, 0.13), 23.0, true)
    draw_line(backwards * 43.0, backwards * 8.0, Color(1.0, 0.83, 0.63, 0.20), 8.0, true)

    for mote in motes:
        var fade := clampf(float(mote["life"]) / float(mote["total"]), 0.0, 1.0)
        var local_pos := to_local(Vector2(mote["pos"]))
        var size := float(mote["size"]) * (0.35 + fade * 0.65)
        match int(mote["kind"]):
            0:
                draw_set_transform(local_pos, float(mote["angle"]), Vector2.ONE)
                draw_texture_rect(PETAL_TEXTURE, Rect2(-Vector2.ONE * size * 0.5, Vector2.ONE * size), false, Color(1.0, 1.0, 1.0, fade * 0.90))
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
            1:
                draw_circle(local_pos, size * 0.64, Color(1.0, 0.61, 0.75, fade * 0.16))
                draw_circle(local_pos, size * 0.31, Color(1.0, 0.78, 0.84, fade * 0.76))
                draw_circle(local_pos, size * 0.13, Color(1.0, 0.98, 0.85, fade * 0.95))
            2:
                _draw_diamond(local_pos, size * 0.88, float(mote["angle"]), Color(1.0, 0.86, 0.77, fade * 0.86))

    draw_circle(Vector2.ZERO, 49.0, Color(1.0, 0.55, 0.65, 0.095))
    draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.92, 0.76, 0.055))
    var bob := 1.0 + 0.065 * sin(elapsed * 12.0)
    var diameter := CORE_DIAMETER * bob
    draw_set_transform(Vector2.ZERO, elapsed * 1.45, Vector2.ONE)
    draw_texture_rect(CORE_TEXTURE, Rect2(-Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_diamond(at: Vector2, radius: float, angle: float, tint: Color) -> void:
    var polygon := PackedVector2Array([
        Vector2(0.0, -radius * 1.35),
        Vector2(radius * 0.62, 0.0),
        Vector2(0.0, radius * 1.35),
        Vector2(-radius * 0.62, 0.0)
    ])
    for i in polygon.size():
        polygon[i] = at + polygon[i].rotated(angle)
    draw_colored_polygon(polygon, tint)
    draw_circle(at, radius * 0.15, Color(1.0, 1.0, 0.95, tint.a))
