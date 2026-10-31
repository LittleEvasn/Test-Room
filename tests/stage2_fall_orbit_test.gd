extends SceneTree
## Run with Godot 4.6:
## godot --headless --path . --script res://tests/stage2_fall_orbit_test.gd
## VFX preview only; not a collision/damage integration test.
const LAB = preload("res://scripts/main.gd")

func _check(value: bool, detail: String) -> void:
	if not value:
		push_error("STAGE2 FAIL: " + detail)
		quit(1)
		assert(value, detail)

func _clear(lab: Node2D) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	lab._unhandled_input(key)

func _run_tests() -> void:
	var lab = LAB.new()
	root.add_child(lab)
	lab.autofire = false

	# All eleven VFX can be scheduled behind a fall marker.
	for spell_id in range(11):
		lab.selected_spell = spell_id
		lab.support_1 = 5 # fall
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 0, "fall waits for landing: %d" % spell_id)
		_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").size() == 1, "one warning: %d" % spell_id)
		var preview = lab.get_tree().get_nodes_in_group("vfx_fall_preview")[0]
		preview._process(0.90)
		_check(lab.fired_count == 1, "base spell launches after fall: %d" % spell_id)
		_clear(lab)
		await process_frame

	# Position-bearing VFX share a motion driver; fireball reuses its native
	# Fireflies-compatible orbit with the SAME shared speed/radius formula.
	for spell_id in [0, 1, 2, 3, 4, 7, 9]:
		lab.selected_spell = spell_id
		lab.support_1 = 6 # orbit
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 1, "orbit launches: %d" % spell_id)
		if spell_id != 9:
			_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").size() == 1, "shared orbit driver: %d" % spell_id)
		else:
			_check(lab.get_tree().get_nodes_in_group("vfx_fireball").size() == 1, "fireball native orbit exists")
			_check(lab.get_tree().get_nodes_in_group("vfx_fireball")[0].aux_orbit, "fireball uses common orbit formula")
		_clear(lab)
		await process_frame

	# Unsupported instant/area VFX must not pretend to be continuously orbiting.
	lab.selected_spell = 10
	lab.support_1 = 6
	lab.support_2 = 0
	lab.shoot()
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").is_empty(), "instant laser has no orbital driver")
	_clear(lab)
	await process_frame

	# Fall + orbit should not accidentally spawn a zero-distance projectile.
	lab.selected_spell = 0
	lab.support_1 = 5
	lab.support_2 = 6
	lab.shoot()
	var warning = lab.get_tree().get_nodes_in_group("vfx_fall_preview")[0]
	warning._process(0.90)
	_check(lab.fired_count == 1, "fall + orbit launches exactly once")
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").size() == 1, "fall + orbit activates driver")
	_clear(lab)
	await process_frame

	# Echo + fall creates a separate delayed warning, but never a nested echo.
	lab.selected_spell = 0
	lab.support_1 = 4
	lab.support_2 = 5
	lab.shoot()
	_check(lab.pending_echoes.size() == 1, "echo + fall schedules one echo wave")
	lab._update_pending_echoes(0.19)
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").size() == 2, "two separate fall previews")
	_check(lab.pending_echoes.is_empty(), "no recursive echo")
	_clear(lab)
	await process_frame
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").is_empty(), "C cancels falling previews")
	print("STAGE2 PASS: 11 fall spawns, 7 orbital VFX, unsupported laser, combined schedules, C reset")
	quit(0)

func _initialize() -> void:
	call_deferred("_run_tests")
