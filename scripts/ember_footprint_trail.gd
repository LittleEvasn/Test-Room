extends Node2D
## Test-Room preview: staggered footprints on a short path toward the aim point.
## Each patch is a separate scene-independent Node2D, reusable in the main game.

signal step_ignited(at: Vector2)
signal finished()

const PATCH_SCRIPT = preload("res://scripts/ember_footprint_fire.gd")
const STEP_COUNT := 8
const STEP_GAP := 0.19
const SCALES := [0.85, 1.0, 1.15, 1.30] # VFX comparison only, not spell upgrades.

var from_point: Vector2
var to_point: Vector2
var density: float = 1.0
var preview_rank: int = 1
var elapsed: float = 0.0
var next_step: int = 0
var track_length: float = 300.0
var direction: Vector2 = Vector2.RIGHT
var rng := RandomNumberGenerator.new()

func configure(start: Vector2, target: Vector2, particle_scale: float, rank: int) -> void:
    from_point = start
    to_point = target
    density = clampf(particle_scale, 0.0, 3.0)
    preview_rank = clampi(rank, 0, 3)
    var delta := to_point - from_point
    direction = delta.normalized() if delta.length_squared() > 0.01 else Vector2.RIGHT
    track_length = clampf(delta.length() * 0.57, 120.0, 330.0)

func _ready() -> void:
    rng.randomize()

func _process(delta: float) -> void:
    elapsed += delta
    while next_step < STEP_COUNT and elapsed >= float(next_step) * STEP_GAP:
        _ignite(next_step)
        next_step += 1
    if next_step == STEP_COUNT and elapsed >= float(STEP_COUNT - 1) * STEP_GAP + PATCH_SCRIPT.BASE_LIFETIME + 0.7:
        finished.emit()
        queue_free()

func _ignite(index: int) -> void:
    var ratio := float(index) / float(STEP_COUNT - 1)
    var center := to_point - direction * track_length * (1.0 - ratio)
    var side := direction.orthogonal() * (9.0 if index % 2 == 0 else -9.0)
    var spawn_point := center + side + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))

    var patch = PATCH_SCRIPT.new()
    patch.position = spawn_point
    patch.configure(float(SCALES[preview_rank]) * rng.randf_range(0.88, 1.12),
        density, PATCH_SCRIPT.BASE_LIFETIME + rng.randf_range(-0.20, 0.25))
    add_child(patch)
    step_ignited.emit(spawn_point)
