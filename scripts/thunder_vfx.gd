extends Node2D
## Lightning STRIKE VISUAL ONLY. No hitboxes, damage, freeze, targeting or balance.
## Reference: GodotLightning (JarLowrey, MIT) for procedural forked strokes;
## this 4.6 implementation and the timing/impact graphics are independent.
##
## Sequence: .45s warning -> bright bolt -> impact flash -> ground electricity.
## Preview-only +0..+3 sizes/pulse counts reflect current main-game display data.

signal struck(at: Vector2)
signal finished(at: Vector2)

const WARNING_TIME := 0.45
const STRIKE_TIME := 0.12
const AFTER_TIME := 0.31
const REPEAT_GAP := 0.22
const BOLT_REDRAW_INTERVAL := 0.045
const RADII := [45.0, 60.0, 75.0, 90.0]
const PULSES := [1, 1, 2, 3]
const MAX_PARTICLES := 100

var rank: int = 0
var density: float = 1.0
var radius: float = 45.0
var phase: String = "WARNING"
var phase_time: float = 0.0
var elapsed: float = 0.0
var pulse_index: int = 0
var bolt_redraw_time: float = 0.0
var rng := RandomNumberGenerator.new()
var main_path: PackedVector2Array = PackedVector2Array()
var forks: Array[PackedVector2Array] = []
var particles: Array[Dictionary] = []
var ground_arcs: Array[PackedVector2Array] = []
var ground_directions: PackedFloat32Array = PackedFloat32Array()

func configure(landing_point: Vector2, particle_scale: float, preview_rank: int) -> void:
    global_position = landing_point
    rank = clampi(preview_rank, 0, 3)
    radius = float(RADII[rank])
    density = clampf(particle_scale, 0.0, 3.0)
    phase = "WARNING"
    phase_time = 0.0
    elapsed = 0.0
    pulse_index = 0
    bolt_redraw_time = 0.0
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
            bolt_redraw_time += dt
            if bolt_redraw_time >= BOLT_REDRAW_INTERVAL:
                bolt_redraw_time -= BOLT_REDRAW_INTERVAL
                _build_bolt()
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
    bolt_redraw_time = 0.0
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
    var source: Vector2 = Vector2(rng.randf_range(-45.0, 45.0), -390.0)
    main_path = _make_jagged_line(source, Vector2.ZERO, 5, 50.0)
    forks.clear()
    var fork_count: int = clampi(int(round(2.0 + density)), 2, 5)
    for fork_index in range(fork_count):
        var junction_index: int = rng.randi_range(7, main_path.size() - 7)
        var source_point: Vector2 = main_path[junction_index]
        var fork_direction: float = -1.0 if rng.randf() < 0.5 else 1.0
        var target: Vector2 = source_point + Vector2(
            fork_direction * rng.randf_range(28.0, 85.0),
            rng.randf_range(37.0, 105.0))
        forks.append(_make_jagged_line(source_point, target, 3, 15.0))

func _spawn_impact_particles() -> void:
    if density <= 0.0:
        return
    var count: int = mini(MAX_PARTICLES, int(round(14.0 * density)))
    for i in range(count):
        var angle: float = rng.randf_range(0.0, TAU)
        var speed: float = rng.randf_range(55.0, 185.0)
        var direction: Vector2 = Vector2.RIGHT.rotated(angle)
        particles.append({
            "pos": direction * rng.randf_range(2.0, 12.0),
            "vel": direction * speed + Vector2(0.0, -rng.randf_range(3.0, 30.0)),
            "age": 0.0,
            "life": rng.randf_range(0.19, 0.42),
            "size": rng.randf_range(1.4, 3.6)
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
    ground_directions.clear()
    for i in range(7):
        var angle: float = (float(i) / 7.0) * TAU + rng.randf_range(-0.18, 0.18)
        ground_directions.append(angle)
        var radial: Vector2 = Vector2.RIGHT.rotated(angle)
        var tangent: Vector2 = radial.orthogonal()
        var tip_distance: float = radius * rng.randf_range(0.7, 1.15)
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
    for i in range(8):
        var a: float = float(i) * TAU / 8.0 + elapsed * 0.45
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

func _draw_bolt_layer(points: PackedVector2Array,
        outer_alpha: float, outer_width: float, middle_width: float, core_width: float) -> void:
    if points.size() < 2:
        return
    draw_polyline(points, Color(1.0, 0.64, 0.19, outer_alpha * 0.18),
        outer_width * 1.7, true)
    draw_polyline(points, Color(1.0, 0.81, 0.31, outer_alpha * 0.45),
        outer_width, true)
    draw_polyline(points, Color(1.0, 0.96, 0.67, outer_alpha * 0.88),
        middle_width, true)
    draw_polyline(points, Color(1.0, 1.0, 0.97, outer_alpha),
        core_width, true)

func _draw_strike() -> void:
    var intensity: float = 1.0 - 0.48 * clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
    _draw_bolt_layer(main_path, intensity, 11.0, 5.4, 2.1)
    for fork in forks:
        _draw_bolt_layer(fork, intensity * 0.82, 5.4, 2.3, 1.0)

func _draw_impact() -> void:
    var t: float = clampf(phase_time / STRIKE_TIME, 0.0, 1.0)
    var fade: float = 1.0 - smoothstep(0.0, 1.0, t)
    draw_circle(Vector2.ZERO, radius * (0.35 + t * 0.37),
        Color(1.0, 0.95, 0.55, fade * 0.22))
    draw_circle(Vector2.ZERO, radius * (0.14 + t * 0.11),
        Color(1.0, 1.0, 0.91, fade * 0.75))
    draw_arc(Vector2.ZERO, radius * (0.32 + 0.78 * t), 0.0, TAU, 64,
        Color(1.0, 0.95, 0.64, fade * 0.91), 3.4, true)
    draw_arc(Vector2.ZERO, radius * (0.24 + 0.50 * t), 0.0, TAU, 64,
        Color(1.0, 0.76, 0.29, fade * 0.52), 2.1, true)
    for branch in ground_arcs:
        draw_polyline(branch, Color(1.0, 0.89, 0.43, fade * 0.83), 2.2, true)
        draw_polyline(branch, Color(1.0, 1.0, 0.9, fade * 0.52), 0.9, true)

func _draw_residual() -> void:
    var t: float = clampf(phase_time / AFTER_TIME, 0.0, 1.0)
    var fade: float = pow(1.0 - t, 1.8)
    var ring_radius: float = radius * (0.92 + t * 0.40)
    draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64,
        Color(1.0, 0.88, 0.38, 0.23 * fade), 2.2, true)
    draw_circle(Vector2.ZERO, radius * 0.19,
        Color(1.0, 0.9, 0.53, 0.15 * fade))
    for i in range(ground_arcs.size()):
        if (i + pulse_index) % 3 == 1 and t >= 0.36:
            continue
        draw_polyline(ground_arcs[i], Color(1.0, 0.8, 0.32, 0.42 * fade), 1.6, true)
    for i in range(5):
        var a: float = float(i) * TAU / 5.0 + 0.24
        var ray: Vector2 = Vector2.RIGHT.rotated(a)
        var distance: float = radius * (0.16 + 0.63 * t)
        draw_line(ray * distance, ray * (distance + 6.0), 
            Color(1.0, 0.94, 0.63, 0.43 * fade), 1.4, true)

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
