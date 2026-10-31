extends Node2D
## VFX-only fall motion. The original spell owns its animation/particles.
## Only its XY position is overridden during the descent.
signal arrived()

const WARNING_SECONDS := 0.23 # ground-only spells
const DESCENT_SECONDS := 0.58
const HORIZONTAL_BACK := 112.0
const VERTICAL_HEIGHT := 350.0

var landing := Vector2.ZERO
var starting := Vector2.ZERO
var actor: Node2D
var age := 0.0
var cancelled := false
var descent_started := false

func configure(target: Vector2, projectile: Node2D = null, cast_origin: Vector2 = Vector2.ZERO) -> void:
	landing = target
	actor = projectile
	var forward: Vector2 = target - cast_origin
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	starting = target - forward.normalized() * HORIZONTAL_BACK + Vector2(0, -VERTICAL_HEIGHT)

func _ready() -> void:
	add_to_group("vfx_fall_preview")
	process_priority = -100 # before spell visual _process(), never after it
	z_index = 4
	if is_instance_valid(actor):
		actor.set_meta("aux_falling", true)
		actor.global_position = starting
		actor.visible = true
		actor.queue_redraw()
		# Do NOT set_process(false). It would also stop particles, rotation,
		# shader time and the whole VFX's fade-in animation.
	queue_redraw()

func cancel() -> void:
	if cancelled:
		return
	cancelled = true
	if is_instance_valid(actor) and not actor.is_queued_for_deletion():
		actor.queue_free()
	queue_free()

func _process(delta: float) -> void:
	if cancelled:
		return
	if actor != null and (not is_instance_valid(actor) or actor.is_queued_for_deletion()):
		cancelled = true
		queue_free()
		return
	age += maxf(delta, 0.0)
	var warning := WARNING_SECONDS if actor == null else 0.0
	if age >= warning and is_instance_valid(actor):
		var progress := clampf((age - warning) / DESCENT_SECONDS, 0.0, 1.0)
		var prior: Vector2 = actor.global_position
		# Explicit XY + height projection, preserving the source's 2:7
		# horizontal-to-vertical offset. This is a 2D rendering adaptation.
		actor.global_position = starting.lerp(landing, progress)
		var velocity: Vector2 = actor.global_position - prior
		if velocity.length_squared() > 0.001:
			actor.set_meta("aux_fall_direction", velocity.normalized())
		actor.queue_redraw()
	if age >= warning + DESCENT_SECONDS:
		cancelled = true
		if is_instance_valid(actor):
			actor.global_position = landing
			actor.remove_meta("aux_falling")
		arrived.emit()
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if cancelled:
		return
	var warning := WARNING_SECONDS if actor == null else 0.0
	var progress := clampf(age / (warning + DESCENT_SECONDS), 0.0, 1.0)
	var tint := Color(0.74, 0.76, 1.0, 0.48 - progress * 0.2)
	draw_arc(landing, 38.0 - progress * 13.0, 0.0, TAU, 48, tint, 1.8, true)
	draw_line(landing - Vector2(10.0, 0.0), landing + Vector2(10.0, 0.0), Color(tint, tint.a * 0.55), 1.0)
