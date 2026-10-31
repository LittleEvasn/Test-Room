extends SceneTree
## Run locally with Godot 4.6:
## godot --headless --path . --script res://tests/stage1_fan_echo_test.gd
## This is a runtime regression test. It is NOT a combat/damage test.
const LAB = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run_tests")

func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error("STAGE1 FAIL: " + description)
		quit(1)
		assert(condition, description)

func _clear(lab: Node2D) -> void:
	var input := InputEventKey.new()
	input.keycode = KEY_C
	input.pressed = true
	lab._unhandled_input(input)

func _run_tests() -> void:
	var lab = LAB.new()
	root.add_child(lab)
	lab.autofire = false
	lab.selected_spell = 10 # fast, short-lived instant laser
	lab.support_1 = 1
	lab.support_2 = 4
	lab.shoot()
	_check(lab.fired_count == 3, "fan fires exactly three original lasers")
	_check(lab.original_casts == 1, "original cast is counted once")
	_check(lab.pending_echoes.size() == 1, "only one echo wave is scheduled")
	lab.target_point = Vector2(960.0, 310.0)
	lab.selected_spell = 0
	lab.support_1 = 0
	lab.support_2 = 0
	lab._update_pending_echoes(0.19)
	_check(lab.fired_count == 6, "the frozen original laser is replayed three times")
	_check(lab.echo_casts == 1, "echo is counted once per wave")
	_check(lab.pending_echoes.is_empty(), "echo copies do not recursively schedule new echoes")
	lab._update_pending_echoes(1.0)
	_check(lab.fired_count == 6, "a second scheduler tick adds no extra copy")

	_clear(lab)
	await process_frame
	_check(lab.pending_echoes.is_empty(), "C clears the echo queue")
	_check(lab.original_casts == 0 and lab.echo_casts == 0, "C resets the counters")

	lab.selected_spell = 10
	lab.support_1 = 4
	lab.support_2 = 0
	lab.shoot()
	_check(lab.fired_count == 1, "echo without fan fires one original")
	lab._update_pending_echoes(0.19)
	_check(lab.fired_count == 2, "echo without fan fires one delayed copy")
	_clear(lab)
	await process_frame

	# Each currently supported VFX type should create exactly 3+3 nodes.
	# The clear/process_frame pair lets queue_free complete before the next spell.
	for spell_id in range(lab.SPELL_CHOICES.size()):
		lab.selected_spell = spell_id
		lab.support_1 = 1
		lab.support_2 = 4
		lab.shoot()
		_check(lab.fired_count == 3, "fan produced three VFX for spell %d" % spell_id)
		lab._update_pending_echoes(0.19)
		_check(lab.fired_count == 6, "echo replayed three VFX for spell %d" % spell_id)
		_check(lab.pending_echoes.is_empty(), "no recursive echo for spell %d" % spell_id)
		_clear(lab)
		await process_frame

	# Selecting one modifier twice must release the previous selection.
	lab._on_support_selected(4, 1)
	lab._on_support_selected(4, 2)
	_check(lab.support_1 == 0 and lab.support_2 == 4, "duplicated supports are rejected")
	print("STAGE1 PASS: 11 spells, 3-way fan, single echo, snapshot, clear, duplicate guard")
	quit(0)
