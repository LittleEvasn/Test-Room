extends SceneTree
## Run with Godot 4.6:
## godot --headless --path . --script res://tests/stage2_fall_orbit_test.gd
const LAB = preload("res://scripts/main.gd")

func _check(value: bool, detail: String) -> void:
	if not value:
		push_error("STAGE2 FAIL: " + detail)
		quit(1)
		assert(value, detail)

func _clear(lab: Node2D) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_C
	e.pressed = true
	lab._unhandled_input(e)

func _run_tests() -> void:
	var lab = LAB.new()
	root.add_child(lab)
	lab.autofire = false

	# Every VFX has a fall sequence. Seven physical bodies are shown IN flight,
	# never replaced by a proxy; the other instant/special VFX use a marker.
	for spell_id in range(11):
		lab.selected_spell = spell_id
		lab.support_1 = 5
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 0, "fall waits before arrival %d" % spell_id)
		var previews: Array = lab.get_tree().get_nodes_in_group("vfx_fall_preview")
		_check(previews.size() == 1, "fall visual created %d" % spell_id)
		var preview = previews[0]
		if spell_id in [0, 1, 2, 3, 4, 7, 9]:
			_check(is_instance_valid(preview.actor), "real VFX actor bound %d" % spell_id)
			var actor: Node2D = preview.actor
			preview._process(0.40)
			var airborne: Vector2 = actor.global_position
			_check(actor.visible, "actual sprite is visible in flight %d" % spell_id)
			_check(airborne.y < preview.landing.y, "actual sprite starts above landing %d" % spell_id)
			_check(airborne.x != preview.landing.x, "actual sprite moves diagonally %d" % spell_id)
			preview._process(0.42)
		else:
			preview._process(0.82)
		_check(lab.fired_count == 1, "one VFX launched at arrival %d" % spell_id)
		_clear(lab)
		await process_frame

	# Truly orbiting projectiles: trap is intentionally NOT in this list.
	for spell_id in [0, 1, 2, 3, 7]:
		lab.selected_spell = spell_id
		lab.support_1 = 6
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 1, "projectile orbit cast %d" % spell_id)
		_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").size() == 1, "driver exists %d" % spell_id)
		if spell_id == 7:
			var poison = lab.get_tree().get_nodes_in_group("vfx_poison_ball")[0]
			_check(poison.hop_count > int(poison.HOPS[poison.rank]), "orbit poison has extra bounces")
		_clear(lab)
		await process_frame

	lab.selected_spell = 4 # thorn: tangential throw -> stops and deploys
	lab.support_1 = 6
	lab.shoot()
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").is_empty(), "orbit thorn never attaches to a circular driver")
	var trap = lab.get_tree().get_nodes_in_group("vfx_thorn")[0]
	_check(trap.state == "ROLLING", "orbit thorn starts as a rolling seed, not an armed orbiting trap")
	_clear(lab)
	await process_frame

	lab.selected_spell = 5
	lab.support_1 = 6
	lab.shoot()
	var sword = lab.get_tree().get_nodes_in_group("vfx_ice_sword")[0]
	_check(sword.aux_orbit, "ice sword uses hilt-inward orbital animation")
	_clear(lab)
	await process_frame

	lab.selected_spell = 6
	lab.support_1 = 6
	lab.shoot()
	var strike_a = lab.get_tree().get_nodes_in_group("vfx_thunder")[0].global_position
	lab.shoot()
	var strike_b = lab.get_tree().get_nodes_in_group("vfx_thunder")[1].global_position
	_check(strike_a.distance_to(strike_b) > 15.0, "lightning target advances around the player")
	_clear(lab)
	await process_frame

	lab.selected_spell = 9
	lab.support_1 = 6
	lab.shoot()
	var fireball = lab.get_tree().get_nodes_in_group("vfx_fireball")[0]
	_check(fireball.aux_orbit, "fireball retains world-space trail in the shared orbit math")
	_clear(lab)
	await process_frame

	lab.selected_spell = 10
	lab.support_1 = 6
	lab.shoot()
	var ray = lab.get_tree().get_nodes_in_group("vfx_laser")[0]
	_check(ray.orbit_mode, "laser renders full 36-segment Magicraft circular beam")
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").is_empty(), "ring laser is NOT a rotating straight line")
	_clear(lab)
	await process_frame

	# Fall + orbit uses the landed point as the new orbit anchor.
	lab.selected_spell = 0
	lab.support_1 = 5
	lab.support_2 = 6
	lab.shoot()
	var falling = lab.get_tree().get_nodes_in_group("vfx_fall_preview")[0]
	falling._process(0.82)
	_check(lab.fired_count == 1, "fall + orbit launched the original once")
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").size() == 1, "fall + orbit attaches at landing")
	_clear(lab)
	await process_frame

	lab.selected_spell = 0
	lab.support_1 = 4
	lab.support_2 = 5
	lab.shoot()
	_check(lab.pending_echoes.size() == 1, "one echo wave for fall")
	lab._update_pending_echoes(0.19)
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").size() == 2, "echo + fall two descending actors")
	_check(lab.pending_echoes.is_empty(), "echo does not recursively schedule")
	_clear(lab)
	await process_frame
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").is_empty(), "C cancels all falling sprites")

	print("STAGE2 PASS: real diagonal fall, 5 orbit bodies, thorn, sword, lightning, poison, laser, echo/reset")
	quit(0)

func _initialize() -> void:
	call_deferred("_run_tests")
