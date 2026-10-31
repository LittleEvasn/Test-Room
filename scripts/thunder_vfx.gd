extends Node2D
## Lightning STRIKE VISUAL ONLY. No hitboxes, damage, freeze, targeting or balance.
## Procedural method: GodotLightning (JarLowrey, MIT).
## Visual hierarchy reference: LeLu 2D Elemental Pack public preview only.
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

var rank: int = 0
var density: float = 1.0
var radius: float = 45.0
var phase: String = "WARNING"
var phase_time: float = 0.0
var elapsed: float = 0.0
var pulse_index: int = 0
var rng := RandomNumberGenerator.new()
var main_path: PackedVector2Array = PackedVector2Array()
var forks: Array[PackedVector2Array] = []
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
    main_path.clear()
    forks.clear()
    particles.clear()
    _make_ground_arcs()

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
    queue_redraw()

func _begin_strike() -> void:
    pulse_index += 1
    phase = "STRIKE"
    phase_time = 0.0
    _build_bolt()
    _spawn_impact_particles()
    _make_ground_arcs()
    struck.emit(global_position)

func _make_jagged_line(from_point: Vector2, to_point: Vector2,
        generations: int, displacement: float) -> PackedVector2Array:
    # Midpoint displacement preserves endpoints and gives naturally varied
    # angular lightning, unlike a fixed 4-point zigzag.
    var pts: PackedVector2Array = PackedVector2Array([from_point, to_point])
    var deviation: float = displacement
    for generation in range(generations):
        var next_pts: PackedVector2Array = PackedVector2Array()
        for i in range(pts.size() - 1):
            var a: Vector2 = pts[i]
            var b: Vector2 = pts[i + 1]
            var midpoint: Vector2 = (a + b) * 0.5
            var sideways: Vector2 = (b - a).orthogonal().normalized()
            midpoint += sideways * rng.randf_range(-deviation, deviation)
            next_pts.append(a)
            next_pts.append(midpoint)
        next_pts.append(to_point)
        pts = next_pts
        deviation *= 0.52
    return pts

func _build_bolt() -> void:
    # Position is LOCAL to the eventual impact at (0, 0).
    # For a top-down test, a 390px projected lightning shaft reads as overhead.
    # 16 clear segments, a narrower central shaft, two limited side arcs.
    var source: Vector2 = Vector2(rng.randf_range(-17.0, 17.0), -390.0)
    main_path = _make_jagged_line(source, Vector2.ZERO, 4, 31.0)
    forks.clear()
    for fork_index in range(2):
        var junction_index: int = (4 if fork_index == 0 else 10) + rng.randi_range(-1, 1)
        var source_point: Vector2 = main_path[junction_index]
        var sideways: float = -1.0 if fork_index == 0 else 1.0
        var target: Vector2 = source_point + Vector2(
            sideways * rng.randf_range(50.0, 98.0),
            rng.randf_range(65.0, 110.0))
        forks.append(_make_jagged_line(source_point, target, 2, 13.0))

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
    # Only three short near-ground discharges. The central flare carries impact.
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
            _draw_strike()
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
    draw_circle(Vector2.ZERO, radius * 0.56, Color(1.0, 0.73, 0.28, 0.08 + 0.07 * t))
    draw_arc(Vector2.ZERO, radius * (0.90 + 0.08 * (1.0 - t)),
        0.0, TAU, 64, Color(1.0, 0.78, 0.33, transparency), 2.1, true)
    draw_arc(Vector2.ZERO, radius * 0.70, 0.0, TAU, 56,
        Color(1.0, 0.97, 0.77, 0.15 + 0.17 * t), 1.2, true)
    # Telegraph radial marks and a clear impact center, not a damage circle.
    for i in range(4):
        var a: float = float(i) * TAU / 4.0 + elapsed * 0.45
        var ray: Vector2 = Vector2.RIGHT.rotated(a)
        draw_line(ray * radius * 0.85, ray * radius * 1.01,
            Color(1.0, 0.9, 0.58, transparency * 0.65), 2.0, true)
    draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0),
        Color(1.0, 0.96, 0.72, 0.24 + t * 0.45), 1.4, true)
    draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0),
        Color(1.0, 0.96, 0.72, 0.24 + t * 0.45), 1.4, true)

func _draw_repeat_warning() -> void:
    var t: float = clampf(phase_time / REPEAT_GAP, 0.0, 1.0)
    draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.85, 0.45, 0.06 + 0.08 * t))
    draw_arc(Vector2.ZERO, radius * 0.80, 0.0, TAU, 48,
        Color(1.0, 0.84, 0.38, 0.21 + t * 0.27), 1.8, true)

func _draw_gold_bolt(points: PackedVector2Array, strength: float) -> void:
    if points.size() < 2:
        return
    # One dominant shaft: warm aura, gold corona, bright cream-white core.
    draw_polyline(points, Color(1.0, 0.64, 0.19, 0.11 * strength), 26.0, true)
    draw_polyline(points, Color(1.0, 0.81, 0.30, 0.29 * strength), 14.0, true)
    draw_polyline(points, Color(1.0, 0.95, 0.63, 0.83 * strength), 7.1, true)
    draw_polyline(points, Color(1.0, 1.0, 0.94, 0.98 * strength), 3.0, true)

func _draw_blue_arc(points: PackedVector2Array, strength: float) -> void:
    if points.size() < 2:
        return
    # Cool accents follow the main bolt without competing for focus.
    draw_polyline(points, Color(0.15, 0.37, 1.0, 0.11 * strength), 15.0, true)
    draw_polyline(points, Color(0.23, 0.66, 1.0, 0.45 * strength), 6.8, true)
    draw_polyline(points, Color(0.75, 0.94, 1.0, 0.76 * strength), 2.2, true)

func _draw_strike() -> void:
    var t: float = clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
    var intensity: float = 1.0 - smoothstep(0.10, 1.0, t) * 0.52
    _draw_gold_bolt(main_path, intensity)
    for fork in forks:
        _draw_blue_arc(fork, intensity * 0.85)

func _draw_impact() -> void:
    var t: float = clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
    var fade: float = 1.0 - smoothstep(0.0, 1.0, t)
    draw_circle(Vector2.ZERO, radius * (0.45 + t * 0.38),
        Color(1.0, 0.72, 0.26, fade * 0.12))
    draw_circle(Vector2.ZERO, radius * (0.22 + t * 0.11),
        Color(1.0, 0.90, 0.49, fade * 0.39))
    draw_circle(Vector2.ZERO, radius * (0.09 + t * 0.04),
        Color(1.0, 1.0, 0.92, fade * 0.97))
    draw_arc(Vector2.ZERO, radius * (0.30 + 0.66 * t), 0.0, TAU, 56,
        Color(1.0, 0.85, 0.43, fade * 0.45), 2.6, true)
    for branch in ground_arcs:
        draw_polyline(branch, Color(1.0, 0.86, 0.39, fade * 0.47), 1.8, true)

func _draw_residual() -> void:
    var t: float = clampf(phase_time / AFTER_TIME, 0.0, 1.0)
    var fade: float = pow(1.0 - t, 2.0)
    draw_circle(Vector2.ZERO, radius * (0.24 + 0.15 * t),
        Color(1.0, 0.81, 0.37, fade * 0.10))
    draw_arc(Vector2.ZERO, radius * (0.90 + t * 0.18), 0.0, TAU, 56,
        Color(1.0, 0.84, 0.44, fade * 0.17), 1.9, true)
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
            Color(1.0, 0.93, 0.60, alpha * 0.87), 1.5, true)
        if size > 1.5:
            draw_circle(pos, size * 0.36,
                Color(1.0, 1.0, 0.86, alpha * 0.75))
