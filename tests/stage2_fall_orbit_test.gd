extends SceneTree
## Run: godot --headless --path . --script res://tests/stage2_fall_orbit_test.gd
## VFX-only regression, no combat damage test.
const LAB = preload("res://scripts/main.gd")

func _check(ok: bool, detail: String) -> void:
	if not ok:
		push_error("STAGE2 FAIL: " + detail)
		quit(1)
		assert(ok, detail)

func _clear(lab: Node2D) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_C
	e.pressed = true
	lab._unhandled_input(e)

func _run_tests() -> void:
	var lab = LAB.new()
	root.add_child(lab)
	lab.autofire = false
	lab.particle_multiplier = 1.0

	# Physical falling: REAL actor remains processed/visible all the way down.
	for spell_id in [0, 1, 2, 3, 4, 7, 9]:
		lab.selected_spell = spell_id
		lab.support_1 = 5
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 0, "no premature ground cast %d" % spell_id)
		var previews: Array = lab.get_tree().get_nodes_in_group("vfx_fall_preview")
		_check(previews.size() == 1, "one fall driver %d" % spell_id)
		var fall = previews[0]
		_check(is_instance_valid(fall.actor), "original actor assigned %d" % spell_id)
		var actor: Node2D = fall.actor
		_check(actor.is_processing(), "VFX _process is NOT disabled %d" % spell_id)
		_check(actor.visible and actor.has_meta("aux_falling"), "original sprite visible and falling %d" % spell_id)
		fall._process(0.14)
		var airborne: Vector2 = actor.global_position
		_check(airborne.y < fall.landing.y and airborne.x != fall.landing.x, "diagonal descent %d" % spell_id)
		actor.call("_process", 0.14)
		_check(actor.is_processing(), "VFX processor still enabled %d" % spell_id)
		if spell_id == 0:
			_check(Array(actor.get("particles")).size() > 0, "star particles emitted in midair")
			_check(float(actor.get("age")) > 0.0, "star spin/age continues in midair")
		if spell_id == 1:
			_check(Array(actor.get("motes")).size() > 0, "flower bomb emits petals midair")
		if spell_id == 2:
			_check(float(actor.get("age")) > 0.0 and Array(actor.get("motes")).size() > 0, "boomerang keeps spin/trail")
		if spell_id == 3:
			_check(float((actor.get("disk_material") as ShaderMaterial).get_shader_parameter("u_opacity")) > 0.0, "black hole shader is visible while falling")
		if spell_id == 4:
			_check(float(actor.get("seed_angle")) != 0.0, "thorn seed still rotates while descending")
		if spell_id == 9:
			_check(Array(actor.get("particles")).size() > 0, "falling fireball retains world-space flame trail")
		fall._process(0.45) # total > 0.58s descent
		_check(lab.fired_count == 1, "landing handled exactly once %d" % spell_id)
		if spell_id == 3:
			_check(actor.has_meta("aux_fall_landed"), "black hole collapses, no hovering on the ground")
		_clear(lab)
		await process_frame

	# Instant laser uses the source's one-frame fall LINE, not a ground preview.
	lab.selected_spell = 10
	lab.support_1 = 5
	lab.support_2 = 0
	lab.shoot()
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").is_empty(), "no delayed laser proxy")
	_check(lab.fired_count == 1, "falling laser renders on the same cast")
	var ray = lab.get_tree().get_nodes_in_group("vfx_laser")[0]
	_check(ray.fall_mode and ray.fall_path.size() == 2, "normal laser has a ground-reaching line")
	_clear(lab)
	await process_frame

	lab.support_1 = 5
	lab.support_2 = 6
	lab.shoot()
	var spiral_ray = lab.get_tree().get_nodes_in_group("vfx_laser")[0]
	_check(spiral_ray.fall_mode and spiral_ray.orbit_mode, "orbit+fall laser is a separate path type")
	_check(spiral_ray.fall_path.size() == 16, "orbit+fall laser has 15 descending 10-degree segments")
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").is_empty(), "orbit+fall beam is instant")
	_clear(lab)
	await process_frame

	# Non-physical special VFX retain ground telegraph until their own launch.
	for spell_id in [5, 6, 8]:
		lab.selected_spell = spell_id
		lab.support_1 = 5
		lab.support_2 = 0
		lab.shoot()
		_check(lab.fired_count == 0, "special spell delayed until grounded %d" % spell_id)
		var marker = lab.get_tree().get_nodes_in_group("vfx_fall_preview")[0]
		marker._process(0.90)
		_check(lab.fired_count == 1, "special spell fires on landing %d" % spell_id)
		_clear(lab)
		await process_frame

	# Standalone orbit behaviors remain unchanged.
	for spell_id in [0, 1, 2, 3, 7]:
		lab.selected_spell = spell_id
		lab.support_1 = 6
		lab.support_2 = 0
		lab.shoot()
		_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").size() == 1, "orbit driver %d" % spell_id)
		_clear(lab)
		await process_frame

	lab.selected_spell = 4
	lab.support_1 = 6
	lab.shoot()
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").is_empty(), "thorn launches tangentially")
	_clear(lab)
	await process_frame

	# Fall + orbit is an airborne circular descent, not a new orbit after landing.
	lab.selected_spell = 0
	lab.support_1 = 5
	lab.support_2 = 6
	lab.shoot()
	var circular = lab.get_tree().get_nodes_in_group("vfx_fall_preview")[0]
	_check(circular.orbit_cast, "fall driver receives orbit setting")
	circular._process(0.30)
	var during_fall: Vector2 = circular.actor.global_position
	_check(during_fall.y < circular.landing.y, "orbiting body remains airborne")
	circular._process(0.31)
	_check(lab.fired_count == 1, "airborne orbit lands once")
	_check(lab.get_tree().get_nodes_in_group("vfx_orbit_driver").is_empty(), "no second ground orbit")
	_clear(lab)
	await process_frame

	# Echo remains single-depth, and C cancels both pending bodies.
	lab.selected_spell = 0
	lab.support_1 = 4
	lab.support_2 = 5
	lab.shoot()
	_check(lab.pending_echoes.size() == 1, "one delayed echo wave")
	lab._update_pending_echoes(0.19)
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").size() == 2, "two original falling sprites")
	_check(lab.pending_echoes.is_empty(), "no recursive echo")
	_clear(lab)
	await process_frame
	_check(lab.get_tree().get_nodes_in_group("vfx_fall_preview").is_empty(), "C clears fall drivers")
	print("STAGE2 PASS: live VFX fall, shader, particles, diagonal, laser, airborne orbit, echo/reset")
	quit(0)

func _initialize() -> void:
	call_deferred("_run_tests")
