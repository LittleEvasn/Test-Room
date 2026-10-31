extends Node2D
## Lightning STRIKE VISUAL ONLY. No hitboxes, damage, freeze, targeting or balance.
## The unbranched animated shaft reuses the CC0 FencerDevLog-inspired
## lightning_arc.gdshader introduced for Test-Room's 9th VFX slot.
## Previous midpoint-displacement/forked silhouette has been removed.
## No paid assets, code, textures or effects imported.
##
## Sequence: .45s warning -> bright bolt -> impact flash -> ground electricity.
## Preview-only +0..+3 sizes/pulse counts reflect current main-game display data.

signal struck(at: Vector2)
signal finished(at: Vector2)

const WARNING_TIME := 0.45
const STRIKE_TIME := 0.12
const AFTER_TIME := 0.31
const REPEAT_GAP := 0.22
# One stable silhouette per lightning strike; no chaotic frame rerolls.
const RADII := [45.0, 60.0, 75.0, 90.0]
const PULSES := [1, 1, 2, 3]
const MAX_PARTICLES := 42
const SHAFT_HEIGHT := 390.0
const STRIP_HEIGHT := 190.0
const ARC_SHADER: Shader = preload("res://shaders/lightning_arc.gdshader")

var rank: int = 0
var density: float = 1.0
var radius: float = 45.0
var phase: String = "WARNING"
var phase_time: float = 0.0
var elapsed: float = 0.0
var pulse_index: int = 0
var rng := RandomNumberGenerator.new()
var bolt_rect: ColorRect
var bolt_material: ShaderMaterial
var particles: Array[Dictionary] = []
var ground_arcs: Array[PackedVector2Array] = []

func configure(landing_point: Vector2, particle_scale: float, preview_rank: int) -> void:
    global_position = landing_point
    rank = clampi(preview_rank, 0, 3)
    radius = float(RADII[rank])
    density = clampf(particle_scale, 0.0, 3.0)
    phase = "WARNING"
    phase_time = 0.0
    elapsed = 0.0
    pulse_index = 0
    rng.randomize()
    particles.clear()
    _make_ground_arcs()

func _ready() -> void:
    # The shader's horizontal progress axis is rotated 90 degrees so the
    # animated line falls from local (0,-390) to the landing point (0,0).
    bolt_rect = ColorRect.new()
    bolt_rect.name = "UnbranchedAnimatedStrike"
    bolt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bolt_rect.position = Vector2(STRIP_HEIGHT * 0.5, -SHAFT_HEIGHT)
    bolt_rect.rotation = PI * 0.5
    bolt_rect.size = Vector2(SHAFT_HEIGHT, STRIP_HEIGHT)
    bolt_rect.visible = false
    bolt_material = ShaderMaterial.new()
    bolt_material.shader = ARC_SHADER
    bolt_material.set_shader_parameter("offset_strength", 0.17)
    bolt_material.set_shader_parameter("core_width", 0.013)
    bolt_material.set_shader_parameter("speed", 3.9)
    bolt_material.set_shader_parameter("glow_strength", clampf(0.35 + density * 0.65, 0.0, 2.4))
    bolt_material.set_shader_parameter("life_alpha", 0.0)
    bolt_rect.material = bolt_material
    add_child(bolt_rect)

func _update_bolt_shader() -> void:
    if bolt_rect == null:
        return
    bolt_rect.visible = phase == "STRIKE"
    if bolt_rect.visible:
        var t: float = clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
        # Keep the beam visibly animated while the impact quickly fades.
        var strength: float = 1.0 - smoothstep(0.13, 1.0, t) * 0.60
        bolt_material.set_shader_parameter("life_alpha", strength)

func _process(delta: float) -> void:
    var dt: float = minf(delta, 0.1)
    elapsed += dt
    phase_time += dt
    _update_particles(dt)

    match phase:
        "WARNING":
            if phase_time >= WARNING_TIME:
                _begin_strike()
        "STRIKE":
            if phase_time >= STRIKE_TIME:
                phase = "AFTER"
                phase_time = 0.0
        "AFTER":
            if phase_time >= AFTER_TIME:
                if pulse_index < int(PULSES[rank]):
                    phase = "GAP"
                    phase_time = 0.0
                else:
                    finished.emit(global_position)
                    queue_free()
                    return
        "GAP":
            if phase_time >= REPEAT_GAP:
                _begin_strike()
    _update_bolt_shader()
    queue_redraw()

func _begin_strike() -> void:
    pulse_index += 1
    phase = "STRIKE"
    phase_time = 0.0
    # Each strike gets a fresh noise phase; never any secondary bolt/fork.
    bolt_material.set_shader_parameter("phase_offset", rng.randf_range(-40.0, 40.0))
    _spawn_impact_particles()
    _make_ground_arcs()
    struck.emit(global_position)

func _spawn_impact_particles() -> void:
    if density <= 0.0:
        return
    var count: int = mini(MAX_PARTICLES, int(round(6.0 * density)))
    for i in range(count):
        var angle: float = rng.randf_range(0.0, TAU)
        var speed: float = rng.randf_range(50.0, 132.0)
        var direction: Vector2 = Vector2.RIGHT.rotated(angle)
        particles.append({
            "pos": direction * rng.randf_range(2.0, 12.0),
            "vel": direction * speed + Vector2(0.0, -rng.randf_range(3.0, 30.0)),
            "age": 0.0,
            "life": rng.randf_range(0.16, 0.33),
            "size": rng.randf_range(1.5, 3.2)
        })

func _update_particles(dt: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var spark: Dictionary = particles[i]
        var new_age: float = float(spark["age"]) + dt
        if new_age >= float(spark["life"]):
            particles.remove_at(i)
            continue
        spark["age"] = new_age
        spark["pos"] = Vector2(spark["pos"]) + Vector2(spark["vel"]) * dt
        spark["vel"] = Vector2(spark["vel"]) * exp(-4.2 * dt)
        particles[i] = spark

func _make_ground_arcs() -> void:
    ground_arcs.clear()
    # Three short GROUND discharges are separate impact accents, not bolt branches.
    for i in range(3):
        var angle: float = (float(i) / 3.0) * TAU + rng.randf_range(-0.3, 0.3)
        var radial: Vector2 = Vector2.RIGHT.rotated(angle)
        var tangent: Vector2 = radial.orthogonal()
        var tip_distance: float = radius * rng.randf_range(0.60, 0.92)
        ground_arcs.append(PackedVector2Array([
            radial * 8.0,
            radial * (tip_distance * 0.33) + tangent * rng.randf_range(-5.0, 5.0),
            radial * (tip_distance * 0.66) + tangent * rng.randf_range(-8.0, 8.0),
            radial * tip_distance
        ]))

func _draw() -> void:
    match phase:
        "WARNING":
            _draw_warning()
        "STRIKE":
            _draw_impact()
        "AFTER":
            _draw_residual()
        "GAP":
            _draw_repeat_warning()
    _draw_particles()

func _draw_warning() -> void:
    var t: float = clampf(phase_time / WARNING_TIME, 0.0, 1.0)
    var breathe: float = 0.5 + 0.5 * sin(elapsed * 18.0)
    var transparency: float = (0.27 + 0.23 * breathe) * (0.78 + 0.22 * t)
    draw_circle(Vector2.ZERO, radius * 0.56, Color(0.18, 0.42, 1.0, 0.08 + 0.07 * t))
    draw_arc(Vector2.ZERO, radius * (0.90 + 0.08 * (1.0 - t)),
        0.0, TAU, 64, Color(0.31, 0.65, 1.0, transparency), 2.1, true)
    draw_arc(Vector2.ZERO, radius * 0.70, 0.0, TAU, 56,
        Color(0.77, 0.93, 1.0, 0.15 + 0.17 * t), 1.2, true)
    # Blue telegraph radial marks and a clear impact center, not a damage circle.
    for i in range(4):
        var a: float = float(i) * TAU / 4.0 + elapsed * 0.45
        var ray: Vector2 = Vector2.RIGHT.rotated(a)
        draw_line(ray * radius * 0.85, ray * radius * 1.01,
            Color(0.53, 0.81, 1.0, transparency * 0.65), 2.0, true)
    draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
        Color(0.83, 0.95, 1.0, 0.24 + t * 0.45), 1.4, true)
    draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0),
        Color(0.83, 0.95, 1.0, 0.24 + t * 0.45), 1.4, true)

func _draw_repeat_warning() -> void:
    var t: float = clampf(phase_time / REPEAT_GAP, 0.0, 1.0)
    draw_circle(Vector2.ZERO, radius * 0.5, Color(0.23, 0.56, 1.0, 0.06 + 0.08 * t))
    draw_arc(Vector2.ZERO, radius * 0.80, 0.0, TAU, 48,
        Color(0.43, 0.70, 1.0, 0.21 + t * 0.27), 1.8, true)

func _draw_impact() -> void:
    var t: float = clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
    var fade: float = 1.0 - smoothstep(0.0, 1.0, t)
    draw_circle(Vector2.ZERO, radius * (0.45 + t * 0.38),
        Color(0.23, 0.52, 1.0, fade * 0.12))
    draw_circle(Vector2.ZERO, radius * (0.22 + t * 0.11),
        Color(0.60, 0.85, 1.0, fade * 0.39))
    draw_circle(Vector2.ZERO, radius * (0.09 + t * 0.04),
        Color(0.92, 0.97, 1.0, fade * 0.97))
    draw_arc(Vector2.ZERO, radius * (0.30 + 0.66 * t), 0.0, TAU, 56,
        Color(0.48, 0.75, 1.0, fade * 0.45), 2.6, true)
    for branch in ground_arcs:
        draw_polyline(branch, Color(0.36, 0.74, 1.0, fade * 0.47), 1.8, true)

func _draw_residual() -> void:
    var t: float = clampf(phase_time / AFTER_TIME, 0.0, 1.0)
    var fade: float = pow(1.0 - t, 2.0)
    draw_circle(Vector2.ZERO, radius * (0.24 + 0.15 * t),
        Color(0.16, 0.50, 1.0, fade * 0.10))
    draw_arc(Vector2.ZERO, radius * (0.90 + t * 0.18), 0.0, TAU, 56,
        Color(0.44, 0.73, 1.0, fade * 0.17), 1.9, true)
    for i in range(ground_arcs.size()):
        if i == 1 and t > 0.42:
            continue
        draw_polyline(ground_arcs[i], Color(0.37, 0.71, 1.0, 0.33 * fade), 1.7, true)

func _draw_particles() -> void:
    for spark in particles:
        var pos: Vector2 = Vector2(spark["pos"])
        var alpha: float = 1.0 - float(spark["age"]) / float(spark["life"])
        var velocity: Vector2 = Vector2(spark["vel"])
        var axis: Vector2 = velocity.normalized()
        var size: float = float(spark["size"]) * alpha
        draw_line(pos - axis * size * 0.3, pos + axis * size * 1.7,
            Color(0.52, 0.83, 1.0, alpha * 0.87), 1.5, true)
        if size > 1.5:
            draw_circle(pos, size * 0.36,
                Color(0.90, 0.96, 1.0, alpha * 0.75))
