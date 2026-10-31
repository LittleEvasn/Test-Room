extends Node2D
## Standalone visual-only ice sword. No damage, hitboxes, status, balance or game runtime.
## Uses user's assets/얼음칼.png (blade points DOWN, pommel UP).
## Swing timing + polynomial curve: Magicraft Spell1021MoveJob / DTool.GetCurveY.

signal finished(at: Vector2)

const SWORD_TEXTURE: Texture2D = preload("res://assets/얼음칼.png")
# PNG: pommel/hilt END is at the top around (256,20).
# Crossguard is near y=135; the BLADE begins below it and ends near y=490.
# Rotate around the pommel, not the crossguard.
const SWORD_PIVOT := Vector2(256.0, 20.0)
const BLADE_START_FROM_PIVOT := 138.0
const TIP_FROM_PIVOT := 470.0
const BEFORE_TIME := 0.20
const AFTER_TIME := 0.25
# A continuous time-sampled ring ribbon removes gaps from per-frame quads.
const TRAIL_TIME := 0.17
const MAX_TRAIL_SAMPLES := 96
const MAX_ICE_DUST := 52

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
    ice_dust.clear()

func _magicraft_curve(percent: float) -> float:
    # Exact DTool.GetCurveY polynomial for control points (0.2,0.5),(0.6,0.95).
    # The decompiled helper is NOT a generic Bezier x-inversion algorithm.
    var t: float = clampf(percent, 0.0, 1.0)
    return (25.0 / 24.0) * t * t * t - (25.0 / 8.0) * t * t + (37.0 / 12.0) * t

func _scale() -> float:
    return float(SIZES[rank])

func _blade_point(angle: float, fraction: float) -> Vector2:
    var radius: float = lerpf(BLADE_START_FROM_PIVOT, TIP_FROM_PIVOT, fraction)
    return Vector2.RIGHT.rotated(angle) * radius * _scale()

func _angle_at(sample_time: float) -> float:
    var fraction: float = _magicraft_curve(sample_time / slash_time)
    return first_angle + deg_to_rad(float(SCATTERS[rank])) * fraction * slash_sign

func _process(delta: float) -> void:
    var dt: float = minf(delta, 0.10)
    age += dt
    _advance_dust(dt)

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

    # Keep the original Magicraft cubic swing progression, but do not let
    # the fade-out create extra invisible/blurry rotations past stroke_end.
    present_angle = _angle_at(minf(age, stroke_end))

    # Emit a few directional flakes evenly along the ANGLE passed, instead
    # of a random burst at only one possibly skipped animation frame.
    if particle_density > 0.0 and phase != "AFTER":
        var angle_delta: float = present_angle - last_emission_angle
        var count: int = mini(6, int(absf(angle_delta) / 0.23))
        for i in range(1, count + 1):
            var emit_angle: float = last_emission_angle + signf(angle_delta) * 0.23 * float(i)
            _emit_ice_flakes(emit_angle)
        if count > 0:
            last_emission_angle += signf(angle_delta) * 0.23 * float(count)
    queue_redraw()

func _emit_ice_flakes(angle: float) -> void:
    var count: int = mini(3, int(round(particle_density * 0.7)))
    var radial: Vector2 = Vector2.RIGHT.rotated(angle)
    var tangent: Vector2 = radial.rotated(slash_sign * PI * 0.5)
    for i in range(count):
        if ice_dust.size() >= MAX_ICE_DUST:
            break
        var along: float = randf_range(0.62, 0.98)
        ice_dust.append({
            "position": _blade_point(angle, along),
            "velocity": tangent * randf_range(26.0, 65.0) + radial * randf_range(-18.0, 18.0),
            "life": randf_range(0.14, 0.31),
            "age": 0.0,
            "size": randf_range(1.2, 3.1),
            "spin": randf_range(0.0, TAU)
        })

func _spray_finish() -> void:
    if particle_density <= 0.0:
        return
    var center: Vector2 = _blade_point(present_angle, 0.88)
    var count: int = int(round(2.0 + particle_density * 2.5))
    for i in range(count):
        if ice_dust.size() >= MAX_ICE_DUST:
            break
        var angle: float = randf_range(0.0, TAU)
        var flight: Vector2 = Vector2.RIGHT.rotated(angle) * randf_range(22.0, 85.0)
        ice_dust.append({
            "position": center + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0)),
            "velocity": flight,
            "life": randf_range(0.16, 0.32),
            "age": 0.0,
            "size": randf_range(1.4, 3.5),
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
    var end_time: float = minf(age, slash_time * 0.80)
    var start_time: float = maxf(0.0, end_time - TRAIL_TIME)
    if end_time <= start_time + 0.0001:
        return

    # Unlike the old frame-stamped quad strip, every frame recomputes an
    # entire smooth arc from the EXACT swing curve at uniformly sampled times.
    # No gaps even when the slash advances more than 15 degrees in one frame.
    var angular_distance: float = absf(_angle_at(end_time) - _angle_at(start_time))
    var samples: int = clampi(int(ceilf(angular_distance / deg_to_rad(1.5))), 12, MAX_TRAIL_SAMPLES)

    # Three layers form one coherent frost slash: faint bloom, ice fill,
    # and a thin uninterrupted antialiased cutting edge near the true tip.
    _draw_ribbon_layer(start_time, end_time, samples, 0.66, 1.02,
        Color(0.22, 0.65, 1.0, 0.075), Color(0.52, 0.85, 1.0, 0.02))
    _draw_ribbon_layer(start_time, end_time, samples, 0.79, 0.985,
        Color(0.37, 0.84, 1.0, 0.32), Color(0.93, 1.0, 1.0, 0.08))

    var tip_points: PackedVector2Array = PackedVector2Array()
    var tip_colors: PackedColorArray = PackedColorArray()
    for i in range(samples + 1):
        var u: float = float(i) / float(samples)
        var sample_time: float = lerpf(start_time, end_time, u)
        var alpha: float = _trail_fade(sample_time)
        var angle: float = _angle_at(sample_time)
        tip_points.append(Vector2.RIGHT.rotated(angle) * TIP_FROM_PIVOT * _scale() * 0.99)
        tip_colors.append(Color(0.90, 0.98, 1.0, 0.63 * alpha))
    draw_polyline_colors(tip_points, tip_colors, 1.7, true)


func _trail_fade(sample_time: float) -> float:
    # World-time fade, so the entire ribbon vanishes naturally after a swing.
    var elapsed: float = maxf(0.0, age - sample_time)
    var freshness: float = 1.0 - smoothstep(0.0, TRAIL_TIME, elapsed)
    return freshness * freshness


func _draw_ribbon_layer(start_time: float, end_time: float, samples: int,
        inner_ratio: float, outer_ratio: float, inner_color: Color, outer_color: Color) -> void:
    var inner_points: PackedVector2Array = PackedVector2Array()
    var outer_points: PackedVector2Array = PackedVector2Array()
    var inner_colors: PackedColorArray = PackedColorArray()
    var outer_colors: PackedColorArray = PackedColorArray()

    # One continuous gradient-filled annular strip, not disjoint trapezoids.
    for i in range(samples + 1):
        var u: float = float(i) / float(samples)
        var moment: float = lerpf(start_time, end_time, u)
        var direction_at: Vector2 = Vector2.RIGHT.rotated(_angle_at(moment))
        var fade: float = _trail_fade(moment)
        inner_points.append(direction_at * TIP_FROM_PIVOT * _scale() * inner_ratio)
        outer_points.append(direction_at * TIP_FROM_PIVOT * _scale() * outer_ratio)
        inner_colors.append(Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * fade))
        outer_colors.append(Color(outer_color.r, outer_color.g, outer_color.b, outer_color.a * fade))

    var points: PackedVector2Array = PackedVector2Array()
    var colors: PackedColorArray = PackedColorArray()
    for i in range(samples + 1):
        points.append(inner_points[i])
        colors.append(inner_colors[i])
    for i in range(samples, -1, -1):
        points.append(outer_points[i])
        colors.append(outer_colors[i])
    draw_polygon(points, colors)


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
    # Tiny motion ghost follows the same curve; avoid multiple ghost swords
    # that used to look like dots and disconnected blade outlines.
    if phase == "NORMAL" and age > 0.035:
        _draw_sword(_angle_at(maxf(0.0, age - 0.035)), visible_alpha * 0.10)
    _draw_sword(present_angle, visible_alpha)
    _draw_dust()
