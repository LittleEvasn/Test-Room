extends Node2D
## Stage-2 falling movement preview. It emits a single arrival signal at landing.
## The original attack VFX is instantiated only AFTER the visual descent.
signal arrived()

const WARNING_SECONDS := 0.40
const DESCENT_SECONDS := 0.48
const DESCENT_HEIGHT := 340.0

var landing := Vector2.ZERO
var age := 0.0
var cancelled := false

func configure(landing_at: Vector2) -> void:
	landing = landing_at

func _ready() -> void:
	add_to_group("vfx_fall_preview")
	z_index = 4
	queue_redraw()

func cancel() -> void:
	cancelled = true
	queue_free()

func _process(delta: float) -> void:
	if cancelled:
		return
	age += maxf(delta, 0.0)
	if age >= WARNING_SECONDS + DESCENT_SECONDS:
		cancelled = true
		arrived.emit()
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if cancelled:
		return
	var ring := 1.0 - clampf(age / (WARNING_SECONDS + DESCENT_SECONDS), 0.0, 1.0)
	draw_arc(landing, 32.0 + 13.0 * ring, 0.0, TAU, 48, Color(0.89, 0.76, 1.0, 0.68 * (0.5 + ring * 0.5)), 2.2, true)
	draw_line(landing + Vector2(-13.0, 0.0), landing + Vector2(13.0, 0.0), Color(0.80, 0.75, 1.0, 0.38), 1.0)
	if age < WARNING_SECONDS:
		return
	var t := clampf((age - WARNING_SECONDS) / DESCENT_SECONDS, 0.0, 1.0)
	var p := landing + Vector2(0.0, -DESCENT_HEIGHT * (1.0 - t * t))
	draw_line(p + Vector2(0, -51), p + Vector2(0, 15), Color(0.70, 0.86, 1.0, 0.18 + t * 0.37), 8.0, true)
	draw_circle(p, 16.0 + 5.0 * t, Color(0.34, 0.68, 1.0, 0.13))
	draw_circle(p, 10.0, Color(0.78, 0.84, 1.0, 0.84))
	draw_circle(p, 4.0, Color.WHITE)
