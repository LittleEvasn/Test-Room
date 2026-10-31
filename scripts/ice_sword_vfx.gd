extends Node2D
## Standalone visual-only ice sword. No damage, hitboxes, status, balance or game runtime.
## Uses user's assets/얼음칼.png (blade points DOWN, pommel UP).
## Swing timing + polynomial curve: Magicraft Spell1021MoveJob / DTool.GetCurveY.

signal finished(at: Vector2)

const SWORD_TEXTURE: Texture2D = preload("res://assets/얼음칼.png")
const SWORD_PIVOT := Vector2(256.0, 105.0) # handle-side rotation point in 512x512 art
const TIP_FROM_PIVOT := 385.0
const BEFORE_TIME := 0.20
const AFTER_TIME := 0.25
const TRAIL_TIME := 0.19
const MAX_TRAIL := 28
const MAX_ICE_DUST := 84

# These are VFX-preview levels, NOT the main game's approved spell balance.
# 150/180/240 are the reference's three native scatter angles.
# Fourth slot keeps 240deg, with larger presentation to compare appearance.
const SCATTERS := [150.0, 180.0, 240.0, 240.0]
const SIZES := [0.35, 0.38, 0.41, 0.45]

var rank: int = 0
var particle_density: float = 1.0
var slash_index: int = 0
var direction: Vector2 = Vector2.RIGHT
var slash_sign: float = 1.0
var first_angle: float = 0.0
var present_angle: float = 0.0
var slash_time: float = 0.42
var age: float = 0.0
var phase: String = "BEFORE"
var last_emission_angle: float = 0.0
var emitted_exit: bool = false
var history: Array[Dictionary] = []
var ice_dust: Array[Dictionary] = []

func configure(from_point: Vector2, to_point: Vector2, density: float, preview_rank: int, swing_number: int) -> void:
    rank = clampi(preview_rank, 0, 3)
    particle_density = clampf(density, 0.0, 3.0)
    slash_index = swing_number
    direction = (to_point - from_point).normalized()
    if direction.length_squared() < 0.001:
        direction = Vector2.RIGHT
    # In regular Magicraft casts the flip toggles each time.
    slash_sign = 1.0 if slash_index % 2 == 0 else -1.0
    global_position = from_point + direction * 42.0
    # BaseDirection = initial aim offset by half the full swing angle.
    first_angle = direction.angle() - deg_to_rad(float(SCATTERS[rank])) * 0.5 * slash_sign
    present_angle = first_angle
    # Magicraft's SlashTime = Scatter / 360 / (movement.speed / base_speed).
    # Visual lab uses default speed ratio 1, not an invented damage-stat upgrade.
    slash_time = float(SCATTERS[rank]) / 360.0
    last_emission_angle = present_angle
    age = 0.0
    emitted_exit = false
    phase = "BEFORE"
    history.clear()
    ice_dust.clear()

func _magicraft_curve(percent: float) -> float:
    # Exact DTool.GetCurveY polynomial for control points (0.2,0.5),(0.6,0.95).
    # The decompiled helper is NOT a generic Bezier x-inversion algorithm.
    var t: float = clampf(percent, 0.0, 1.0)
    return (25.0 / 24.0) * t * t * t - (25.0 / 8.0) * t * t + (37.0 / 12.0) * t

func _scale() -> float:
    return float(SIZES[rank])

func _blade_point(angle: float, fraction: float) -> Vector2:
    return Vector2.RIGHT.rotated(angle) * (TIP_FROM_PIVOT * _scale() * fraction)

func _process(delta: float) -> void:
    var dt: float = minf(delta, 0.10)
    age += dt
    _advance_dust(dt)
    for i in range(history.size() - 1, -1, -1):
        history[i]["age"] = float(history[i]["age"]) + dt
        if float(history[i]["age"]) >= TRAIL_TIME:
            history.remove_at(i)

    var stroke_end: float = slash_time * 0.80
    if age < BEFORE_TIME:
        phase = "BEFORE"
    elif age < stroke_end:
        phase = "NORMAL"
    elif age < stroke_end + AFTER_TIME:
        phase = "AFTER"
        if not emitted_exit:
            emitted_exit = true
            _spray_finish()
    else:
        finished.emit(global_position)
        queue_free()
        return

    var previous_angle: float = present_angle
    var progress: float = _magicraft_curve(age / slash_time)
    present_angle = first_angle + deg_to_rad(float(SCATTERS[rank])) * progress * slash_sign

    # Source traces the blade's rotating angle, rather than a fixed arc picture.
    if absf(present_angle - previous_angle) > 0.001 and phase != "AFTER":
        history.append({"angle": present_angle, "age": 0.0})
        if history.size() > MAX_TRAIL:
            history.remove_at(0)

    if particle_density > 0.0 and phase != "AFTER":
        if absf(present_angle - last_emission_angle) >= 0.16:
            last_emission_angle = present_angle
            _emit_ice_flakes(present_angle)
    queue_redraw()

func _emit_ice_flakes(angle: float) -> void:
    var count: int = int(round(1.0 + particle_density))
    var radial: Vector2 = Vector2.RIGHT.rotated(angle)
    var tangent: Vector2 = radial.rotated(slash_sign * PI * 0.5)
    for i in range(count):
        if ice_dust.size() >= MAX_ICE_DUST:
            break
        var along: float = randf_range(0.53, 1.0)
        ice_dust.append({
            "position": _blade_point(angle, along),
            "velocity": tangent * randf_range(35.0, 90.0) + radial * randf_range(-22.0, 28.0),
            "life": randf_range(0.19, 0.39),
            "age": 0.0,
            "size": randf_range(1.7, 4.5),
            "spin": randf_range(0.0, TAU)
        })

func _spray_finish() -> void:
    if particle_density <= 0.0:
        return
    var center: Vector2 = _blade_point(present_angle, 0.76)
    var count: int = int(round(5.0 + particle_density * 5.0))
    for i in range(count):
        if ice_dust.size() >= MAX_ICE_DUST:
            break
        var angle: float = randf_range(0.0, TAU)
        var flight: Vector2 = Vector2.RIGHT.rotated(angle) * randf_range(22.0, 85.0)
        ice_dust.append({
            "position": center + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0)),
            "velocity": flight,
            "life": randf_range(0.16, 0.42),
            "age": 0.0,
            "size": randf_range(1.7, 5.5),
            "spin": angle
        })

func _advance_dust(dt: float) -> void:
    for i in range(ice_dust.size() - 1, -1, -1):
        var p: Dictionary = ice_dust[i]
        var life_age: float = float(p["age"]) + dt
        if life_age >= float(p["life"]):
            ice_dust.remove_at(i)
            continue
        p["age"] = life_age
        p["position"] = Vector2(p["position"]) + Vector2(p["velocity"]) * dt
        p["velocity"] = Vector2(p["velocity"]) * exp(-2.6 * dt)
        ice_dust[i] = p

func _visibility() -> float:
    if phase == "BEFORE":
        # Analogous to Magicraft's 0.2s shader fade-in.
        return 1.0 - pow(1.0 - clampf(age / BEFORE_TIME, 0.0, 1.0), 3.0)
    if phase == "AFTER":
        return 1.0 - smoothstep(0.0, AFTER_TIME, age - slash_time * 0.80)
    return 1.0

func _draw_sword(angle: float, opacity: float, scale_factor: float = 1.0) -> void:
    if opacity <= 0.001:
        return
    # PNG handle is at the TOP; blade tip is at the BOTTOM. Align DOWN to
    # the moving swing direction, and rotate around the upper hilt.
    var texture_rotation: float = angle - PI * 0.5
    draw_set_transform(Vector2.ZERO, texture_rotation, Vector2.ONE * _scale() * scale_factor)
    draw_texture(SWORD_TEXTURE, -SWORD_PIVOT, Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0)))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_trail() -> void:
    if history.size() < 2:
        return
    # Dynamic crescent following each actual sampled blade angle. No baked cone.
    var r_inner: float = TIP_FROM_PIVOT * _scale() * 0.57
    var r_outer: float = TIP_FROM_PIVOT * _scale() * 1.05
    for i in range(1, history.size()):
        var prev: Dictionary = history[i - 1]
        var curr: Dictionary = history[i]
        var alpha: float = clampf(1.0 - float(curr["age"]) / TRAIL_TIME, 0.0, 1.0)
        var prev_angle: float = float(prev["angle"])
        var curr_angle: float = float(curr["angle"])
        var p0: Vector2 = Vector2.RIGHT.rotated(prev_angle)
        var p1: Vector2 = Vector2.RIGHT.rotated(curr_angle)
        var ribbon: PackedVector2Array = PackedVector2Array([
            p0 * r_inner, p0 * r_outer, p1 * r_outer, p1 * r_inner
        ])
        draw_colored_polygon(ribbon, Color(0.32, 0.79, 1.0, 0.15 * alpha))
        draw_line(p0 * r_outer, p1 * r_outer, Color(0.83, 0.97, 1.0, 0.56 * alpha), 2.1, true)
        draw_line(p0 * r_inner, p1 * r_inner, Color(0.35, 0.79, 1.0, 0.14 * alpha), 1.2, true)

func _draw_dust() -> void:
    for p in ice_dust:
        var pos: Vector2 = Vector2(p["position"])
        var fraction: float = 1.0 - float(p["age"]) / float(p["life"])
        var size: float = float(p["size"]) * fraction
        var axis: Vector2 = Vector2.RIGHT.rotated(float(p["spin"]))
        var side: Vector2 = axis.orthogonal()
        var vertices: PackedVector2Array = PackedVector2Array([
            pos + axis * size * 1.65,
            pos + side * size * 0.55,
            pos - axis * size * 0.95,
            pos - side * size * 0.55
        ])
        draw_colored_polygon(vertices, Color(0.57, 0.88, 1.0, fraction * 0.76))
        if size >= 2.0:
            draw_line(pos, pos + axis * size, Color(0.95, 1.0, 1.0, fraction * 0.74), 1.0, true)

func _draw() -> void:
    _draw_trail()
    var visible_alpha: float = _visibility()
    # A restrained, faint blade ghost helps read rapid alternating swings.
    for j in range(0, history.size(), 5):
        var past: Dictionary = history[j]
        var alpha: float = 1.0 - float(past["age"]) / TRAIL_TIME
        _draw_sword(float(past["angle"]), alpha * 0.11 * visible_alpha)
    _draw_sword(present_angle, visible_alpha)
    _draw_dust()
