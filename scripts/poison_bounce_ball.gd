extends Node2D
## Asset-free Test-Room poison bouncing ball; each landing emits a puddle.
## Shadow stays on the ground; ball lifts with a sine wave.
signal landed(at: Vector2, puddle_radius: float, puddle_lifetime: float)
signal finished()

const RADII := [24.0, 30.0, 36.0, 42.0]
const LIFETIMES := [1.8, 2.2, 2.6, 3.0]
const HOPS := [3, 4, 5, 6]
const HOP_SECONDS := 0.50

var start_point := Vector2.ZERO
var end_point := Vector2.RIGHT * 600.0
var density := 1.0
var rank := 0
var hop_count := 3
var landed_count := 0
var hop_clock := 0.0
var height := 0.0

func configure(origin: Vector2, target: Vector2, particle_scale: float, cast_rank: int) -> void:
    start_point = origin
    end_point = target
    density = clampf(particle_scale, 0.0, 3.0)
    rank = clampi(cast_rank, 0, 3)
    hop_count = int(HOPS[rank])

func _ready() -> void:
    z_index = 2
    position = start_point
    queue_redraw()

func _process(delta: float) -> void:
    hop_clock += maxf(delta, 0.0)
    # A dropped frame must not skip a landing.
    while hop_clock >= HOP_SECONDS and landed_count < hop_count:
        hop_clock -= HOP_SECONDS
        landed_count += 1
        landed.emit(start_point.lerp(end_point, float(landed_count) / float(hop_count)),
            float(RADII[rank]), float(LIFETIMES[rank]))

    if landed_count >= hop_count:
        finished.emit()
        queue_free()
        return

    var phase := clampf(hop_clock / HOP_SECONDS, 0.0, 1.0)
    position = start_point.lerp(end_point,
        (float(landed_count) + phase) / float(hop_count))
    height = sin(phase * PI) * (80.0 + 4.0 * float(rank))
    queue_redraw()

func _draw() -> void:
    var radius := 16.0 + float(rank) * 2.0
    var phase := clampf(hop_clock / HOP_SECONDS, 0.0, 1.0)
    var sh := 1.0 - height / 360.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(sh, sh * 0.47))
    draw_circle(Vector2.ZERO, radius * 1.28, Color(0.015, 0.045, 0.018, 0.38))
    draw_circle(Vector2.ZERO, radius * 0.67, Color(0.15, 0.30, 0.08, 0.24))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var squish := 1.0 - 0.11 * pow(1.0 - minf(phase / 0.12, 1.0), 2.0)
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
