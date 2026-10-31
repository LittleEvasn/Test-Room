extends Node2D
## 별빛탄/꽃폭탄/달빛 부메랑/블랙홀/가시꽃 덫/서리검/벼락/잔불 발자국 VFX 독립 실험실.

const BOLT_SCRIPT = preload("res://scripts/star_bolt.gd")
const IMPACT_SCRIPT = preload("res://scripts/impact_burst.gd")
const BLOOM_SCRIPT = preload("res://scripts/bloom_bomb.gd")
const BLOOM_BURST_SCRIPT = preload("res://scripts/bloom_burst.gd")
const MOON_SCRIPT = preload("res://scripts/moon_boomerang.gd")
const MOON_HIT_SCRIPT = preload("res://scripts/moon_hit_burst.gd")
const BLACK_HOLE_SCRIPT = preload("res://scripts/vortex_black_hole.gd")
const THORN_SCRIPT = preload("res://scripts/thorn_trap.gd")
const ICE_SWORD_SCRIPT = preload("res://scripts/ice_sword_vfx.gd")
const THUNDER_SCRIPT = preload("res://scripts/thunder_vfx.gd")
const EMBER_TRAIL_SCRIPT = preload("res://scripts/ember_footprint_trail.gd")

const SCREEN_SIZE := Vector2(1600.0, 900.0)
const START_POINT := Vector2(200.0, 490.0)
# Test-Room 전용으로 확대한 VFX 반경. 본게임 꽃폭탄 밸런스에는 영향 없음.
const BLOOM_RADII := [90.0, 115.0, 145.0, 180.0]

var target_point := Vector2(1330.0, 490.0)
var autofire := true
var fire_interval := 0.72
var fire_clock := 0.2
var particle_multiplier := 1.0
var fired_count := 0
var impact_count := 0
var selected_spell := 0 # 0..7 = 별빛탄/꽃폭탄/부메랑/블랙홀/가시꽃/서리검/벼락/잔불 발자국
var bloom_rank := 0
var black_hole_rank := 0
var black_hole_ticks := 0
var black_hole_finished := 0
var thorn_rank := 0
var thorn_deploys := 0
var thorn_triggers := 0
var thorn_finished := 0
var ice_sword_rank := 0
var ice_sword_swings := 0
var ice_sword_finished := 0
var thunder_rank := 0
var thunder_strikes := 0
var thunder_finished := 0
var ember_rank := 1
var ember_steps := 0
var ember_finished := 0

var title_label: Label
var info_label: Label
var status_label: Label

func _ready() -> void:
	randomize()
	_create_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if autofire:
		fire_clock -= delta
		if fire_clock <= 0.0:
			fire_clock = _auto_interval()
			shoot()
	var spell_name := _spell_name()
	if selected_spell == 3:
		status_label.text = "선택 %s +%d  |  생성 %d  가상 틱 %d  소멸 %d  |  파티클 %.1fx  |  자동 %s" % [
			spell_name, black_hole_rank, fired_count, black_hole_ticks, black_hole_finished, particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 4:
		var active_traps := get_tree().get_nodes_in_group("vfx_thorn")
		var rolling := 0
		var opening := 0
		var armed := 0
		for trap in active_traps:
			if trap.is_queued_for_deletion():
				continue
			match trap.trap_state():
				"ROLLING": rolling += 1
				"DEPLOYING": opening += 1
				"ARMED": armed += 1
		status_label.text = "선택 %s +%d (반경 %.0f)  |  발사 %d  굴림 %d  전개중 %d  설치 %d  발동 %d  소멸 %d  |  T 덫 발동" % [
			spell_name, thorn_rank, float(THORN_SCRIPT.RADII[thorn_rank]),
			fired_count, rolling, opening, armed, thorn_triggers, thorn_finished
		]
	elif selected_spell == 5:
		status_label.text = "선택 %s / VFX +%d  |  원호 %.0f도  |  시전 %d  종료 %d  |  좌우 교대  |  파티클 %.1fx  |  자동 %s" % [
			spell_name, ice_sword_rank, float(ICE_SWORD_SCRIPT.SCATTERS[ice_sword_rank]),
			ice_sword_swings, ice_sword_finished, particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 6:
		status_label.text = "선택 %s / VFX +%d  |  예고 0.45초  크기 %.0f  반복 %d회  |  낙뢰 %d  완료 %d  |  입자 %.1fx  자동 %s" % [
			spell_name, thunder_rank, float(THUNDER_SCRIPT.RADII[thunder_rank]),
			int(THUNDER_SCRIPT.PULSES[thunder_rank]), thunder_strikes, thunder_finished,
			particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 7:
		status_label.text = "선택 %s / VFX 크기 %d  |  발자국 %d  생성된 불꽃 %d  활성 불꽃 %d  종료 경로 %d  |  입자 %.1fx  자동 %s" % [
			spell_name, ember_rank, fired_count, ember_steps, get_tree().get_nodes_in_group("vfx_ember_patch").size(), ember_finished,
			particle_multiplier, "ON" if autofire else "OFF"
		]
	else:
		var rank_str := "" if selected_spell != 1 else "  |  꽃폭탄 +%d (폭발 반경 %.0f)" % [bloom_rank, BLOOM_RADII[bloom_rank]]
		status_label.text = "선택 %s%s  |  발사 %d  명중 %d  |  파티클 %.1fx  |  자동 %s" % [
			spell_name, rank_str, fired_count, impact_count, particle_multiplier, "ON" if autofire else "OFF"
		]
	queue_redraw()

func _auto_interval() -> float:
	match selected_spell:
		3: return 5.2
		4: return 2.6
		5: return 1.15
		6:
			# Avoid overlapping auto pulses at +2/+3 while reviewing one strike.
			return 1.55 if thunder_rank <= 1 else (2.20 if thunder_rank == 2 else 2.85)
		7: return 4.4
	return fire_interval

func shoot(replace_hole: bool = false) -> void:
	var active_count := get_tree().get_nodes_in_group("vfx_bolt").size() + get_tree().get_nodes_in_group("vfx_bloom").size() + get_tree().get_nodes_in_group("vfx_moon").size() + get_tree().get_nodes_in_group("vfx_hole").size() + get_tree().get_nodes_in_group("vfx_thorn").size() + get_tree().get_nodes_in_group("vfx_ice_sword").size() + get_tree().get_nodes_in_group("vfx_thunder").size() + get_tree().get_nodes_in_group("vfx_ember_trail").size()
	if active_count >= 50:
		return
	if selected_spell == 0:
		var bolt = BOLT_SCRIPT.new()
		bolt.configure(START_POINT, target_point, particle_multiplier)
		add_child(bolt)
		bolt.add_to_group("vfx_bolt")
		bolt.impacted.connect(_on_bolt_impact)
	elif selected_spell == 1:
		var bomb = BLOOM_SCRIPT.new()
		bomb.configure(START_POINT, target_point, particle_multiplier, BLOOM_RADII[bloom_rank])
		add_child(bomb)
		bomb.add_to_group("vfx_bloom")
		bomb.impacted.connect(_on_bloom_impact.bind(bloom_rank))
	elif selected_spell == 2:
		var moon = MOON_SCRIPT.new()
		moon.configure(START_POINT, target_point, particle_multiplier)
		add_child(moon)
		moon.add_to_group("vfx_moon")
		moon.struck.connect(_on_moon_struck)
		moon.returned.connect(_on_moon_returned)
	elif selected_spell == 3:
		# 이펙트 평가 중에는 블랙홀 한 개에만 집중한다.
		# 자동 발사는 기존 개체가 소멸할 때까지 기다리고, 수동 발사는 위치를 바꿔 다시 소환한다.
		var active_holes := get_tree().get_nodes_in_group("vfx_hole")
		if not active_holes.is_empty():
			if not replace_hole:
				return
			for old_hole in active_holes:
				old_hole.remove_from_group("vfx_hole")
				old_hole.queue_free()
		var hole = BLACK_HOLE_SCRIPT.new()
		hole.configure(target_point, START_POINT, particle_multiplier, black_hole_rank)
		add_child(hole)
		hole.add_to_group("vfx_hole")
		hole.pulsed.connect(_on_black_hole_pulse)
		hole.vanished.connect(_on_black_hole_vanished)
	elif selected_spell == 5:
		# Pure animation preview: no enemy, status effects, hitbox or spell combat.
		var sword = ICE_SWORD_SCRIPT.new()
		sword.configure(START_POINT, target_point, particle_multiplier, ice_sword_rank, ice_sword_swings)
		add_child(sword)
		sword.add_to_group("vfx_ice_sword")
		sword.finished.connect(_on_ice_sword_finished)
		ice_sword_swings += 1
	elif selected_spell == 6:
		# Ground-targeted lightning VFX only. No combat collision or damage.
		var lightning = THUNDER_SCRIPT.new()
		lightning.configure(target_point, particle_multiplier, thunder_rank)
		add_child(lightning)
		lightning.add_to_group("vfx_thunder")
		lightning.struck.connect(_on_thunder_struck)
		lightning.finished.connect(_on_thunder_finished)
	elif selected_spell == 7:
		# A single cast lays eight staggered ground flames; no gameplay hitboxes.
		if get_tree().get_nodes_in_group("vfx_ember_trail").size() >= 3:
			return
		var trail = EMBER_TRAIL_SCRIPT.new()
		trail.configure(START_POINT, target_point, particle_multiplier, ember_rank)
		add_child(trail)
		trail.add_to_group("vfx_ember_trail")
		trail.step_ignited.connect(_on_ember_step)
		trail.finished.connect(_on_ember_finished)
	else:
		# Unlike the black-hole preview, multiple deployed thorn traps are allowed.
		if get_tree().get_nodes_in_group("vfx_thorn").size() >= 12:
			return
		var trap = THORN_SCRIPT.new()
		trap.configure(START_POINT, target_point, particle_multiplier, thorn_rank)
		add_child(trap)
		trap.add_to_group("vfx_thorn")
		trap.deployed.connect(_on_thorn_deployed)
		trap.triggered.connect(_on_thorn_triggered)
		trap.vanished.connect(_on_thorn_vanished)
	fired_count += 1

func _on_bolt_impact(point: Vector2) -> void:
	impact_count += 1
	var burst = IMPACT_SCRIPT.new()
	burst.global_position = point
	add_child(burst)

func _on_bloom_impact(point: Vector2, radius: float, cast_rank: int) -> void:
	impact_count += 1
	var burst = BLOOM_BURST_SCRIPT.new()
	burst.global_position = point
	burst.configure(radius, particle_multiplier, cast_rank)
	add_child(burst)

func _on_moon_struck(point: Vector2) -> void:
	impact_count += 1
	var flash = MOON_HIT_SCRIPT.new()
	flash.global_position = point
	flash.configure(false)
	add_child(flash)

func _on_moon_returned(point: Vector2) -> void:
	var flash = MOON_HIT_SCRIPT.new()
	flash.global_position = point
	flash.configure(true)
	add_child(flash)

func _on_black_hole_pulse(_point: Vector2, _radius: float) -> void:
	# 실험실에는 적이 없으므로 실제 피해 대신 0.25초 틱 신호만 기록한다.
	black_hole_ticks += 1

func _on_black_hole_vanished(_point: Vector2) -> void:
	black_hole_finished += 1

func _on_ice_sword_finished(_point: Vector2) -> void:
	ice_sword_finished += 1

func _on_thunder_struck(_point: Vector2) -> void:
	thunder_strikes += 1

func _on_thunder_finished(_point: Vector2) -> void:
	thunder_finished += 1

func _on_ember_step(_point: Vector2) -> void:
	ember_steps += 1

func _on_ember_finished() -> void:
	ember_finished += 1

func _on_thorn_deployed(_point: Vector2, _radius: float) -> void:
	thorn_deploys += 1

func _on_thorn_triggered(_point: Vector2, _radius: float) -> void:
	# Preview trigger: separate from deployment; no actual enemies or damage.
	thorn_triggers += 1

func _on_thorn_vanished(_point: Vector2) -> void:
	thorn_finished += 1

func _activate_nearest_thorn() -> void:
	# The test room has no enemies. T simulates one approaching the aimed trap.
	var selected_trap: Node2D = null
	var nearest: float = INF
	for node in get_tree().get_nodes_in_group("vfx_thorn"):
		var trap_node: Node2D = node as Node2D
		if trap_node == null or trap_node.is_queued_for_deletion():
			continue
		if trap_node.call("trap_state") != "ARMED":
			continue
		var distance: float = trap_node.global_position.distance_squared_to(target_point)
		if distance < nearest:
			nearest = distance
			selected_trap = trap_node
	if selected_trap != null:
		selected_trap.call("trigger_trap")

func _spell_name() -> String:
	match selected_spell:
		0: return "별빛탄"
		1: return "꽃폭탄"
		2: return "달빛 부메랑"
		3: return "소용돌이 씨앗(블랙홀)"
		4: return "가시꽃 덫"
		5: return "서리검"
		6: return "벼락"
		7: return "잔불 발자국"
	return "미지의 마법"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			target_point = get_global_mouse_position().clamp(Vector2(185, 230), SCREEN_SIZE - Vector2(185, 170))
			shoot(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			shoot(true)
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				selected_spell = 0
				_update_title()
			KEY_2, KEY_KP_2:
				selected_spell = 1
				_update_title()
			KEY_3, KEY_KP_3:
				selected_spell = 2
				_update_title()
			KEY_4, KEY_KP_4:
				selected_spell = 3
				_update_title()
			KEY_5, KEY_KP_5:
				selected_spell = 4
				_update_title()
			KEY_6, KEY_KP_6:
				selected_spell = 5
				_update_title()
			KEY_7, KEY_KP_7:
				selected_spell = 6
				_update_title()
			KEY_8, KEY_KP_8:
				selected_spell = 7
				_update_title()
			KEY_Q:
				if selected_spell == 3:
					black_hole_rank = maxi(0, black_hole_rank - 1)
				elif selected_spell == 1:
					bloom_rank = maxi(0, bloom_rank - 1)
				elif selected_spell == 4:
					thorn_rank = maxi(0, thorn_rank - 1)
				elif selected_spell == 5:
					ice_sword_rank = maxi(0, ice_sword_rank - 1)
				elif selected_spell == 6:
					thunder_rank = maxi(0, thunder_rank - 1)
				elif selected_spell == 7:
					ember_rank = maxi(0, ember_rank - 1)
			KEY_E:
				if selected_spell == 3:
					black_hole_rank = mini(3, black_hole_rank + 1)
				elif selected_spell == 1:
					bloom_rank = mini(3, bloom_rank + 1)
				elif selected_spell == 4:
					thorn_rank = mini(3, thorn_rank + 1)
				elif selected_spell == 5:
					ice_sword_rank = mini(3, ice_sword_rank + 1)
				elif selected_spell == 6:
					thunder_rank = mini(3, thunder_rank + 1)
				elif selected_spell == 7:
					ember_rank = mini(3, ember_rank + 1)
			KEY_SPACE:
				shoot(true)
			KEY_T:
				_activate_nearest_thorn()
			KEY_R:
				autofire = not autofire
			KEY_UP, KEY_EQUAL, KEY_KP_ADD:
				particle_multiplier = minf(3.0, particle_multiplier + 0.5)
			KEY_DOWN, KEY_MINUS, KEY_KP_SUBTRACT:
				particle_multiplier = maxf(0.0, particle_multiplier - 0.5)
			KEY_C:
				for group_name in ["vfx_bolt", "vfx_bloom", "vfx_moon", "vfx_hole", "vfx_thorn", "vfx_ice_sword", "vfx_thunder", "vfx_ember_trail"]:
					for projectile in get_tree().get_nodes_in_group(group_name):
						projectile.queue_free()
				# 이미 생성된 폭발은 자연스럽게 사라진다.
				fired_count = 0
				impact_count = 0
				black_hole_ticks = 0
				black_hole_finished = 0
				thorn_deploys = 0
				thorn_triggers = 0
				thorn_finished = 0
				ice_sword_swings = 0
				ice_sword_finished = 0
				thunder_strikes = 0
				thunder_finished = 0
				ember_steps = 0
				ember_finished = 0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("1b2030"), true)
	for x in range(0, 1601, 80):
		draw_line(Vector2(x, 140), Vector2(x, 900), Color(0.62, 0.70, 0.9, 0.065), 1.0)
	for y in range(140, 901, 80):
		draw_line(Vector2(0, y), Vector2(1600, y), Color(0.62, 0.70, 0.9, 0.065), 1.0)

	var aiming_color := Color("ffd98e")
	match selected_spell:
		1: aiming_color = Color("f4a6c4")
		2: aiming_color = Color("c6b7ff")
		3: aiming_color = Color("a38cff")
		4: aiming_color = Color("ecadd2")
		5: aiming_color = Color("8ceaff")
		6: aiming_color = Color("ffe7a3")
		7: aiming_color = Color("ff9c4e")
	draw_line(START_POINT, target_point, Color(aiming_color, 0.09), 2.0)
	draw_circle(START_POINT + Vector2(0, 22), 35.0, Color(0, 0, 0, 0.24))
	draw_circle(START_POINT, 32.0, Color("6d658b"))
	draw_circle(START_POINT, 21.0, Color("ad9ed0"))
	draw_circle(START_POINT, 9.0, Color("eee2ff"))
	draw_arc(START_POINT, 40.0, 0.0, TAU, 48, Color("d9bbff"), 2.0)

	if selected_spell < 3:
		draw_circle(target_point + Vector2(0, 25), 38.0, Color(0, 0, 0, 0.26))
		draw_circle(target_point, 38.0, Color("554f67"))
		draw_circle(target_point, 29.0, Color("c48eaa"))
		draw_circle(target_point, 19.0, Color("e6b0c2"))
		draw_arc(target_point, 43.0, 0.0, TAU, 48, Color("d9a2b8"), 2.0)
		if selected_spell == 1:
			draw_arc(target_point, BLOOM_RADII[bloom_rank], 0.0, TAU, 64, Color(1.0, 0.65, 0.75, 0.28), 1.5, true)
	else:
		# 블랙홀/가시꽃/서리검/벼락/잔불 발자국에는 분홍색 표적 모형을 그리지 않는다.
		draw_arc(target_point, 8.0, 0.0, TAU, 24, Color(0.58, 0.80, 0.77, 0.28), 1.5, true)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color("111725")
	panel.position = Vector2.ZERO
	panel.size = Vector2(1600, 140)
	layer.add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(35, 16)
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color("ffdba8"))
	layer.add_child(title_label)
	_update_title()

	info_label = Label.new()
	info_label.text = "1 별빛탄  ·  2 꽃폭탄  ·  3 부메랑  ·  4 블랙홀  ·  5 가시꽃  ·  6 서리검  ·  7 벼락  ·  8 잔불 발자국\nQ/E 단계  ·  T 덫 발동  ·  클릭/SPACE 시전  ·  R 자동  ·  ↑/↓ 입자  ·  C 초기화"
	info_label.position = Vector2(36, 57)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color("c9d0e0"))
	layer.add_child(info_label)

	status_label = Label.new()
	status_label.position = Vector2(36, 110)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("a8b8d6"))
	layer.add_child(status_label)

func _update_title() -> void:
	title_label.text = "WITCHLINGS / MAGIC VFX LAB     %s" % _spell_name()
