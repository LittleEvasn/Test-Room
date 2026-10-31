extends Node2D
## Magicraft 3119-inspired falling: the ACTUAL source VFX travels diagonally.
## Separate telegraph only for non-projectile spells (laser, lightning, sword).
signal arrived()

const WARNING_SECONDS := 0.28
const DESCENT_SECONDS := 0.50
const HORIZONTAL_BACK := 112.0
const VERTICAL_HEIGHT := 350.0

var landing := Vector2.ZERO
var starting := Vector2.ZERO
var actor: Node2D
var age := 0.0
var cancelled := false

func configure(target: Vector2, projectile: Node2D = null, cast_origin: Vector2 = Vector2.ZERO) -> void:
	landing = target
	actor = projectile
	var forward: Vector2 = target - cast_origin
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	starting = target - forward.normalized() * HORIZONTAL_BACK + Vector2(0, -VERTICAL_HEIGHT)

func _ready() -> void:
	add_to_group("vfx_fall_preview")
	process_priority = 100
	z_index = 4
	if is_instance_valid(actor):
		actor.set_process(false)
		actor.visible = false # telegraph precedes the actual spell sprite
		actor.global_position = starting
	queue_redraw()

func cancel() -> void:
	cancelled = true
	queue_free()

func _process(delta: float) -> void:
	if cancelled:
		return
	if actor != null and (not is_instance_valid(actor) or actor.is_queued_for_deletion()):
		cancel()
		return
	age += maxf(delta, 0.0)
	if age >= WARNING_SECONDS and is_instance_valid(actor):
		actor.visible = true
		var p := clampf((age - WARNING_SECONDS) / DESCENT_SECONDS, 0.0, 1.0)
		# Reference fall: start behind the target and at an elevated Z, keep
		# projectile's own sprite visible while XY + projected height descend.
		actor.global_position = starting.lerp(landing, p)
	if age >= WARNING_SECONDS + DESCENT_SECONDS:
		cancelled = true
		if is_instance_valid(actor):
			actor.global_position = landing
		arrived.emit()
		if is_instance_valid(actor):
			actor.set_process(true)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if cancelled:
		return
	var progress := clampf(age / (WARNING_SECONDS + DESCENT_SECONDS), 0.0, 1.0)
	var tint := Color(0.74, 0.76, 1.0, (0.58 - progress * 0.28))
	draw_arc(landing, 38.0 - progress * 13.0, 0.0, TAU, 48, tint, 1.8, true)
	draw_line(landing - Vector2(10, 0), landing + Vector2(10, 0), Color(tint, tint.a * 0.55), 1.0)
