extends Node2D
## VFX-only fall motion. The original spell owns its animation/particles.
## Only its XY position is overridden during the descent.
signal arrived(at: Vector2)

const ORBIT_MOTION = preload("res://scripts/aux_orbit_motion.gd")
const WARNING_SECONDS := 0.23 # ground-only spells
const DESCENT_SECONDS := 0.58
const HORIZONTAL_BACK := 112.0
const VERTICAL_HEIGHT := 350.0

var landing := Vector2.ZERO
var starting := Vector2.ZERO
var actor: Node2D
var age := 0.0
var cancelled := false
var orbit_cast := false
var orbit_anchor := Vector2.ZERO
var orbit_radius := 134.0
var orbit_phase := 0.0
var orbit_angular_speed := 0.0

func configure(target: Vector2, projectile: Node2D = null, cast_origin: Vector2 = Vector2.ZERO, should_orbit: bool = false, orbit_level: int = 0, orbit_speed: float = 320.0) -> void:
	landing = target
	actor = projectile
	orbit_cast = should_orbit and is_instance_valid(projectile)
	orbit_anchor = cast_origin
	var forward: Vector2 = target - cast_origin
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT
	if orbit_cast:
		orbit_phase = forward.angle()
		orbit_radius = ORBIT_MOTION.radius_for(orbit_level)
		orbit_angular_speed = ORBIT_MOTION.angular_speed_for(orbit_speed, orbit_level)
		landing = orbit_anchor + Vector2.from_angle(orbit_phase + DESCENT_SECONDS * orbit_angular_speed) * orbit_radius
		starting = orbit_anchor + Vector2.from_angle(orbit_phase) * orbit_radius + Vector2(0, -VERTICAL_HEIGHT)
	else:
		starting = target - forward.normalized() * HORIZONTAL_BACK + Vector2(0, -VERTICAL_HEIGHT)

func _ready() -> void:
	add_to_group("vfx_fall_preview")
	process_priority = -100 # before spell visual _process(), never after it
	z_index = 4
	if is_instance_valid(actor):
		actor.set_meta("aux_falling", true)
		actor.global_position = starting
		actor.visible = true
		if actor.has_method("begin_fall_vfx"):
			actor.call("begin_fall_vfx", starting)
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
		if orbit_cast:
			var angle := orbit_phase + progress * DESCENT_SECONDS * orbit_angular_speed
			landing = orbit_anchor + Vector2.from_angle(angle) * orbit_radius
			actor.global_position = landing + Vector2(0.0, -VERTICAL_HEIGHT * (1.0 - progress))
		else:
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
		arrived.emit(landing)
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
