extends Node2D
## Asset-free Test-Room poison bouncing ball; each landing emits a puddle.
## Bounce height, flight time and horizontal distance all decay each hop.
## A parabolic height (constant gravity) replaces equal-height sine jumps.
signal landed(at: Vector2, puddle_radius: float, puddle_lifetime: float)
signal finished()

const RADII := [24.0, 30.0, 36.0, 42.0]
const LIFETIMES := [1.8, 2.2, 2.6, 3.0]
const HOPS := [3, 4, 5, 6]

# Test-Room motion tuning (pixels / seconds, not game-combat balance).
const FIRST_BOUNCE_HEIGHT := 155.0
const LAST_BOUNCE_HEIGHT := 9.0
const GRAVITY := 1650.0
const DISTANCE_EXPONENT := 0.92

var start_point := Vector2.ZERO
var end_point := Vector2.RIGHT * 600.0
var density := 1.0
var rank := 0
var hop_count := 3
var hop_index := 0
var hop_clock := 0.0
var height := 0.0

# Precalculated per-cast data: each last landing is EXACTLY the target.
var hop_heights: Array[float] = []
var hop_durations: Array[float] = []
var landing_points: Array[Vector2] = []

func configure(origin: Vector2, target: Vector2, particle_scale: float, cast_rank: int) -> void:
    start_point = origin
    end_point = target
    density = clampf(particle_scale, 0.0, 3.0)
    rank = clampi(cast_rank, 0, 3)
    hop_count = int(HOPS[rank])
    hop_index = 0
    hop_clock = 0.0
    height = 0.0
    _build_bounces()

func _build_bounces() -> void:
    hop_heights.clear()
    hop_durations.clear()
    landing_points.clear()

    # Larger bounces naturally travel farther and stay airborne longer.
    # Geometric height reduction reaches the same tiny final bounce at every rank.
    var distance_weights: Array[float] = []
    var total_weight := 0.0
    for i in range(hop_count):
        var fraction := float(i) / float(maxi(1, hop_count - 1))
        var peak: float = FIRST_BOUNCE_HEIGHT * pow(
            LAST_BOUNCE_HEIGHT / FIRST_BOUNCE_HEIGHT, fraction)
        hop_heights.append(peak)
        # Peak H = g*T^2/8, so T gets shorter as the bounce loses energy.
        hop_durations.append(sqrt(8.0 * peak / GRAVITY))
        var weight: float = pow(peak / FIRST_BOUNCE_HEIGHT, DISTANCE_EXPONENT)
        distance_weights.append(weight)
        total_weight += weight

    var travel_fraction := 0.0
    for i in range(hop_count):
        travel_fraction += distance_weights[i] / total_weight
        # The final position is exact even after accumulated float rounding.
        landing_points.append(end_point if i == hop_count - 1 else
            start_point.lerp(end_point, travel_fraction))

func _ready() -> void:
    z_index = 2
    if landing_points.is_empty():
        _build_bounces()
    position = start_point
    queue_redraw()

func _process(delta: float) -> void:
    hop_clock += maxf(delta, 0.0)

    # Use remaining time, not frame count, so a dropped frame misses no puddle.
    while hop_index < hop_count and hop_clock >= hop_durations[hop_index]:
        hop_clock -= hop_durations[hop_index]
        var landing_at: Vector2 = landing_points[hop_index]
        hop_index += 1
        landed.emit(landing_at, float(RADII[rank]), float(LIFETIMES[rank]))

    if hop_index >= hop_count:
        position = end_point
        height = 0.0
        finished.emit()
        queue_free()
        return

    var duration: float = hop_durations[hop_index]
    var phase := clampf(hop_clock / duration, 0.0, 1.0)
    var previous_landing: Vector2 = start_point if hop_index == 0 else landing_points[hop_index - 1]
    var next_landing: Vector2 = landing_points[hop_index]
    position = previous_landing.lerp(next_landing, phase)
    # 4H*t*(1-t) is the exact vertical arc under constant gravity,
    # with apex H at t=0.5 and ground contact at t=0 and t=1.
    height = 4.0 * hop_heights[hop_index] * phase * (1.0 - phase)
    queue_redraw()

func _draw() -> void:
    var radius := 16.0 + float(rank) * 2.0
    var duration: float = hop_durations[hop_index] if hop_index < hop_count else 1.0
    var phase := clampf(hop_clock / duration, 0.0, 1.0)
    var sh := 1.0 - height / 360.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(sh, sh * 0.47))
    draw_circle(Vector2.ZERO, radius * 1.28, Color(0.015, 0.045, 0.018, 0.38))
    draw_circle(Vector2.ZERO, radius * 0.67, Color(0.15, 0.30, 0.08, 0.24))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    # Flatten at landing/takeoff and stretch slightly near each arc's apex.
    var impact_squash := maxf(
        pow(1.0 - minf(phase / 0.14, 1.0), 2.0),
        pow(1.0 - minf((1.0 - phase) / 0.14, 1.0), 2.0))
    var squish := 1.0 - 0.12 * impact_squash
    var stretch := 1.0 + 0.08 * sin(phase * PI)
    draw_set_transform(Vector2(0, -height), 0.0,
        Vector2(1.0 / squish, squish * stretch))
    # Clear green disk with glow and two small poison bubbles.
    draw_circle(Vector2.ZERO, radius * 1.55, Color(0.37, 0.95, 0.06, 0.08))
    draw_circle(Vector2.ZERO, radius * 1.17, Color(0.19, 0.49, 0.08, 0.48))
    draw_circle(Vector2.ZERO, radius, Color("336c1e"))
    draw_circle(Vector2(-1.0, -1.0), radius * 0.88, Color("83c52f"))
    draw_circle(Vector2(-radius * 0.18, -radius * 0.19),
        radius * 0.62, Color("b5eb4a"))
    draw_circle(Vector2(-radius * 0.35, -radius * 0.41),
        radius * 0.25, Color("efffb3"))
    if density > 0.0:
        draw_circle(Vector2(radius * 0.39, radius * 0.21),
            radius * 0.16, Color("4c9c23"))
        draw_circle(Vector2(radius * 0.34, radius * 0.15),
            radius * 0.055, Color("defb8c"))
        draw_circle(Vector2(-radius * 0.18, radius * 0.40),
            radius * 0.10, Color("4e9220"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
