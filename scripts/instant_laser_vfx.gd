extends Node2D
## Test-Room-only, asset-free Magicraft-1004-style instant straight laser.
## Full beam appears at cast time. Duration is visual only; no collision or damage.
signal finished()

const MAX_RANGE := 480.0
const VFX_SECONDS := 0.22
const BRIGHT_SECONDS := 0.055

var start_point := Vector2.ZERO
var direction := Vector2.RIGHT
var glow_scale := 1.0
var elapsed := 0.0

func configure(origin: Vector2, aim_at: Vector2, particle_multiplier: float = 1.0) -> void:
    start_point = origin
    direction = (aim_at - origin).normalized()
    if direction.length_squared() < 0.001:
        direction = Vector2.RIGHT
    glow_scale = clampf(particle_multiplier, 0.0, 3.0)

func _ready() -> void:
    position = start_point
    rotation = direction.angle()
    z_index = 5
    queue_redraw()

func _process(delta: float) -> void:
    elapsed += maxf(delta, 0.0)
    if elapsed >= VFX_SECONDS:
        finished.emit()
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var alpha := 1.0 - smoothstep(BRIGHT_SECONDS, VFX_SECONDS, elapsed)
    if alpha <= 0.001:
        return
    var glow := clampf(glow_scale, 0.0, 2.5)
    var endpoint := Vector2(MAX_RANGE, 0.0)
    # Wide transparent aura -> saturated cyan -> needle-thin white core.
    draw_line(Vector2.ZERO, endpoint, Color(0.06, 0.59, 1.0, 0.045 * alpha * glow), 37.0, true)
    draw_line(Vector2.ZERO, endpoint, Color(0.15, 0.77, 1.0, 0.12 * alpha * glow), 21.0, true)
    draw_line(Vector2.ZERO, endpoint, Color(0.34, 0.85, 1.0, 0.40 * alpha), 10.0, true)
    draw_line(Vector2.ZERO, endpoint, Color(0.67, 0.96, 1.0, 0.90 * alpha), 4.5, true)
    draw_line(Vector2.ZERO, endpoint, Color(1.0, 1.0, 1.0, 0.98 * alpha), 1.8, true)
    # Small optical flashes (not impact or enemy-hit indicators).
    var flash := 1.0 - smoothstep(0.0, 0.11, elapsed)
    draw_circle(Vector2.ZERO, 22.0, Color(0.13, 0.76, 1.0, 0.08 * alpha * glow))
    draw_circle(Vector2.ZERO, 9.0, Color(0.44, 0.87, 1.0, 0.25 * alpha))
    draw_circle(Vector2.ZERO, 3.3, Color(1.0, 1.0, 1.0, alpha))
    draw_circle(endpoint, 13.0, Color(0.18, 0.72, 1.0, 0.08 * alpha * glow))
    draw_circle(endpoint, 3.1, Color(0.79, 0.97, 1.0, 0.74 * alpha))
    draw_line(Vector2(0.0, -27.0), Vector2(0.0, 27.0),
        Color(0.44, 0.87, 1.0, 0.60 * flash), 2.0, true)
    draw_line(endpoint + Vector2(0.0, -10.0), endpoint + Vector2(0.0, 10.0),
        Color(0.71, 0.97, 1.0, 0.26 * flash), 1.5, true)
    for offset in [0.18, 0.39, 0.67, 0.84]:
        var x: float = MAX_RANGE * float(offset)
        var shimmer: float = (0.18 + 0.10 * sin(elapsed * 22.0 + float(offset) * 19.0)) * alpha
        draw_line(Vector2(x - 7.0, -5.0), Vector2(x + 6.0, -5.0),
            Color(0.64, 0.93, 1.0, shimmer), 1.3, true)
