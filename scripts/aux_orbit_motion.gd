extends Node2D
## Shared orbit motion for Test-Room VFX. No combat collisions or damage.
## Existing VFX keeps drawing; this driver only owns its position and lifetime.
const LIFE_SECONDS := 4.95
const BASE_RADIUS := 134.0
const RANK_RADIUS_STEP := 10.0
const MIN_ANGULAR_SPEED := 1.25
const MAX_ANGULAR_SPEED := 5.25
const PUDDLE_STEP := 0.85
const POISON_RADII := [24.0, 30.0, 36.0, 42.0]
const POISON_LIFETIMES := [1.8, 2.2, 2.6, 3.0]

var visual: Node2D
var center := Vector2.ZERO
var phase := 0.0
var speed := 320.0
var rank := 0
var spell_id := 0
var age := 0.0
var puddle_clock := 0.0

static func radius_for(level: int) -> float:
	return BASE_RADIUS + float(clampi(level, 0, 3)) * RANK_RADIUS_STEP

static func angular_speed_for(projectile_speed: float, level: int) -> float:
	return clampf(projectile_speed / radius_for(level), MIN_ANGULAR_SPEED, MAX_ANGULAR_SPEED)

static func orbit_point(anchor: Vector2, level: int, projectile_speed: float, time: float, starting_angle: float) -> Vector2:
	var theta := starting_angle + time * angular_speed_for(projectile_speed, level)
	return anchor + Vector2.from_angle(theta) * radius_for(level)

func configure(node: Node2D, anchor: Vector2, level: int, velocity: float, starting_angle: float, kind: int) -> void:
	visual = node
	center = anchor
	rank = clampi(level, 0, 3)
	speed = maxf(1.0, velocity)
	phase = starting_angle
	spell_id = kind
	age = 0.0
	puddle_clock = 0.0

func _ready() -> void:
	process_priority = 100
	add_to_group("vfx_orbit_driver")
	if is_instance_valid(visual):
		visual.global_position = orbit_point(center, rank, speed, 0.0, phase)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(visual) or visual.is_queued_for_deletion():
		queue_free()
		return
	age += maxf(0.0, delta)
	visual.global_position = orbit_point(center, rank, speed, age, phase)
	# Preserve the original VFX animation but avoid its normal straight-line expiry.
	if spell_id == 1 and float(visual.get("elapsed")) >= 1.8:
		visual.set("elapsed", 1.5)
	if spell_id == 7:
		puddle_clock += delta
		if puddle_clock >= PUDDLE_STEP:
			puddle_clock -= PUDDLE_STEP
			visual.emit_signal("landed", visual.global_position, float(POISON_RADII[rank]), float(POISON_LIFETIMES[rank]))
	if age >= LIFE_SECONDS:
		# Match a bomb's VFX-only finish to its current orbital location.
		if spell_id == 1:
			visual.emit_signal("impacted", visual.global_position, float(visual.get("blast_radius")))
		elif spell_id == 3 or spell_id == 4:
			visual.emit_signal("vanished", visual.global_position)
		elif spell_id == 7:
			visual.emit_signal("finished")
		visual.queue_free()
		queue_free()
	queue_redraw()

func _draw() -> void:
	# Very faint track, not an attack hitbox.
	draw_arc(center, radius_for(rank), 0.0, TAU, 80, Color(0.55, 0.72, 0.97, 0.11), 1.0, true)
