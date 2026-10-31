extends Node2D
## Stage-2 falling and orbital VFX previews on the shared fan/echo runner.

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
const LIGHTNING_ARC_SCRIPT = preload("res://scripts/lightning_arc_vfx.gd")
const POISON_BALL_SCRIPT = preload("res://scripts/poison_bounce_ball.gd")
const POISON_PUDDLE_SCRIPT = preload("res://scripts/poison_puddle.gd")
const FIREBALL_SCRIPT = preload("res://scripts/fireball_vfx.gd")
const FIREBALL_IMPACT_SCRIPT = preload("res://scripts/fireball_impact_vfx.gd")
const LASER_SCRIPT = preload("res://scripts/instant_laser_vfx.gd")
const HARNESS_SCRIPT = preload("res://scripts/vfx_test_harness.gd")
const ORBIT_SCRIPT = preload("res://scripts/aux_orbit_motion.gd")
const FALL_SCRIPT = preload("res://scripts/aux_fall_preview.gd")

# Add any future spell here: the clickable catalog needs no new keyboard shortcut.
const SPELL_CHOICES := ["별빛탄", "꽃폭탄", "달빛 부메랑", "블랙홀", "가시꽃 덫", "얼음검", "벼락", "독 탱탱볼", "번개 아크", "화염구", "광선"]
# Only genuinely implemented test motions are selectable.
const SPELL_TEST_MODES := {9: ["직선 비행", "공전", "급선회"]}
# Stage 2: fall/orbit now active for compatible VFX types.
const SUPPORT_CHOICES := ["없음", "갈래", "추적", "도탄", "메아리", "낙하", "공전", "분열", "복제 궤적"]
const FAN_INDEX := 1
const ECHO_INDEX := 4
const FALL_INDEX := 5
const ORBIT_INDEX := 6
const ORBIT_SPELLS := [0, 1, 2, 3, 4, 5, 6, 7, 9, 10]
const FALL_PHYSICAL_SPELLS := [0, 1, 2, 3, 4, 7, 9]
const MAX_FALL_PREVIEWS := 18
const FAN_ANGLE := 0.24 # radians, same base fan spacing as the main game
const ECHO_DELAY := 0.18
const ECHO_PREVIEW_ALPHA := 0.35 # visual-only substitute for damage scaling
const MAX_PENDING_ECHO := 12

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
var selected_spell := 0 # 0..10; controlled by the spell dropdown
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
var lightning_arc_rank := 0
var lightning_arc_finished := 0
var poison_rank := 1
var poison_landings := 0
var poison_finished := 0
var fireball_rank := 0
var fireball_impacts := 0
var fireball_finished := 0
var fireball_motion := 0 # 0 straight, 1 orbit, 2 curving
var laser_finished := 0
var pending_echoes: Array[Dictionary] = []
var original_casts := 0
var echo_casts := 0
var blocked_spawns := 0
var thunder_orbit_phase := 0.0

var title_label: Label
var info_label: Label
var status_label: Label
var effect_label: Label
var spell_picker: OptionButton
var mode_picker: OptionButton
var support_picker_1: OptionButton
var support_picker_2: OptionButton
var support_1 := 0
var support_2 := 0
var harness

func _ready() -> void:
	randomize()
	harness = HARNESS_SCRIPT.new()
	harness.process_priority = 200
	add_child(harness)
	_create_hud()
	queue_redraw()

func _process(delta: float) -> void:
	_update_pending_echoes(delta)
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
		status_label.text = "선택 %s +%d | %d회 도약 | 장판 반경 %.0f / 유지 %.1fs | 발사 %d 착지 %d 장판 %d 종료 %d | 기포 %.1fx 자동 %s" % [
			spell_name, poison_rank, int(POISON_BALL_SCRIPT.HOPS[poison_rank]), float(POISON_BALL_SCRIPT.RADII[poison_rank]),
			float(POISON_BALL_SCRIPT.LIFETIMES[poison_rank]), fired_count, poison_landings,
			get_tree().get_nodes_in_group("vfx_poison_puddle").size(), poison_finished,
			particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 10:
		status_label.text = "선택 %s | 즉발 직선 / 사거리 %.0fpx / 잔상 %.2f초 | 발사 %d 종료 %d | 광채 %.1fx 자동 %s | 전투 판정·굴절 미구현" % [
			spell_name, float(LASER_SCRIPT.MAX_RANGE), float(LASER_SCRIPT.VFX_SECONDS),
			fired_count, laser_finished, particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 9:
		status_label.text = "선택 %s +%d | %s | 폭발 %.0f | 발사 %d  폭발 %d  종료 %d | 불꽃 %.1fx 자동 %s  [F 이동방식]" % [
			spell_name, fireball_rank, ["직선 비행", "공전", "급선회"][fireball_motion], float(FIREBALL_SCRIPT.RADII[fireball_rank]), fired_count,
			fireball_impacts, fireball_finished, particle_multiplier, "ON" if autofire else "OFF"
		]
	elif selected_spell == 8:
		status_label.text = "선택 %s / VFX +%d  |  단일 줄기 / 분기 없음  |  시전 %d  종료 %d  |  외광 %.1fx  자동 %s" % [
			spell_name, lightning_arc_rank, fired_count, lightning_arc_finished, particle_multiplier, "ON" if autofire else "OFF"
		]
	else:
		var rank_str := "" if selected_spell != 1 else "  |  꽃폭탄 +%d (폭발 반경 %.0f)" % [bloom_rank, BLOOM_RADII[bloom_rank]]
		status_label.text = "선택 %s%s  |  발사 %d  명중 %d  |  파티클 %.1fx  |  자동 %s" % [
			spell_name, rank_str, fired_count, impact_count, particle_multiplier, "ON" if autofire else "OFF"
		]
	if effect_label != null:
		var pending: Array[String] = []
		for chosen in [support_1, support_2]:
			if chosen != 0 and chosen != FAN_INDEX and chosen != ECHO_INDEX and chosen != FALL_INDEX and chosen != ORBIT_INDEX:
				pending.append(SUPPORT_CHOICES[chosen])
		var note := " | 미구현: " + ", ".join(pending) if not pending.is_empty() else ""
		if _has_support(ORBIT_INDEX) and not _orbit_supported(selected_spell):
			note += " | 번개 아크는 공전 미지원"
		elif _has_support(ORBIT_INDEX) and selected_spell == 4:
			note += " | 덫: 접선 발사·고정 설치"
		elif _has_support(ORBIT_INDEX) and selected_spell == 10:
			note += " | 광선: 원형 빔"
		effect_label.text = "갈래 %s / 메아리 %s / 낙하 %s / 공전 %s | 원본 %d 재시전 %d 대기 %d 제한 %d%s" % [
			"3발" if _has_support(FAN_INDEX) else "OFF",
			"ON" if _has_support(ECHO_INDEX) else "OFF",
			"ON" if _has_support(FALL_INDEX) else "OFF",
			"ON" if _has_support(ORBIT_INDEX) and _orbit_supported(selected_spell) else "OFF",
			original_casts, echo_casts, pending_echoes.size(), blocked_spawns, note
		]
	queue_redraw()

func _auto_interval() -> float:
	if _has_support(FALL_INDEX):
		return 2.0 # Separate landing animations instead of stacking warnings.
	match selected_spell:
		3: return 6.3 if _has_support(FAN_INDEX) or _has_support(ECHO_INDEX) or _has_support(ORBIT_INDEX) else 5.2
		4: return 2.6
		5: return 1.15
		6:
			# Avoid overlapping auto pulses at +2/+3 while reviewing one strike.
			return 1.55 if thunder_rank <= 1 else (2.20 if thunder_rank == 2 else 2.85)
		7: return 3.85 if _has_support(FAN_INDEX) or _has_support(ECHO_INDEX) else 3.25
		8: return 1.15
		9: return 5.20 if fireball_motion == 1 else (3.45 if _has_support(FAN_INDEX) or _has_support(ECHO_INDEX) else 2.50)
		10: return 0.94
	return fire_interval

func _has_support(index: int) -> bool:
	return support_1 == index or support_2 == index

func _orbit_supported(spell_id: int) -> bool:
	return spell_id in ORBIT_SPELLS

func _orbit_velocity(spell_id: int) -> float:
	match spell_id:
		0: return 720.0
		1: return 455.0
		2: return 460.0
		3, 4: return 320.0
		7: return 400.0 # preview-only value; original motion is a bounce
		9: return float(FIREBALL_SCRIPT.PREVIEW_SPEED)
	return 320.0

func _spell_rank(spell_id: int) -> int:
	match spell_id:
		1: return bloom_rank
		3: return black_hole_rank
		4: return thorn_rank
		5: return ice_sword_rank
		6: return thunder_rank
		7: return poison_rank
		8: return lightning_arc_rank
		9: return fireball_rank
	return 0

func _cast_snapshot(replace_hole: bool) -> Dictionary:
	# Freeze the source spell, direction, rank and test settings for a delayed echo.
	var aim := target_point
	if selected_spell == 6 and _has_support(ORBIT_INDEX):
		aim = START_POINT + Vector2.from_angle(thunder_orbit_phase) * ORBIT_SCRIPT.radius_for(thunder_rank)
		thunder_orbit_phase += 0.82
	return {
		"spell": selected_spell, "origin": START_POINT, "aim": aim,
		"rank": _spell_rank(selected_spell), "density": particle_multiplier,
		"motion": fireball_motion, "fan": _has_support(FAN_INDEX),
		"echo": _has_support(ECHO_INDEX), "fall": _has_support(FALL_INDEX),
		"orbit": _has_support(ORBIT_INDEX) and _orbit_supported(selected_spell),
		"replace_hole": replace_hole
	}

func shoot(replace_hole: bool = false) -> void:
	var context := _cast_snapshot(replace_hole)
	if _fire_wave(context, false) <= 0:
		return
	original_casts += 1
	if bool(context["echo"]):
		if pending_echoes.size() < MAX_PENDING_ECHO:
			# Scheduled once per original cast, NEVER per bullet or echo copy.
			pending_echoes.append({"delay": ECHO_DELAY, "cast": context.duplicate(true)})
		else:
			blocked_spawns += 1

func _update_pending_echoes(delta: float) -> void:
	for i in range(pending_echoes.size() - 1, -1, -1):
		var task: Dictionary = pending_echoes[i]
		task["delay"] = float(task["delay"]) - delta
		if float(task["delay"]) <= 0.0:
			pending_echoes.remove_at(i)
			if _fire_wave(task["cast"], true) > 0:
				echo_casts += 1
		else:
			pending_echoes[i] = task

func _fire_wave(context: Dictionary, echo_copy: bool) -> int:
	var count := 3 if bool(context["fan"]) else 1
	var origin: Vector2 = context["origin"]
	var delta_aim: Vector2 = Vector2(context["aim"]) - origin
	if delta_aim.length_squared() < 0.001:
		delta_aim = Vector2.RIGHT * 300.0
	var successes := 0
	for i in range(count):
		var angle := (float(i) - float(count - 1) * 0.5) * FAN_ANGLE
		var shot_aim: Vector2 = origin + delta_aim.rotated(angle)
		if _spawn_single_cast(context, shot_aim, echo_copy, i + 1, count):
			successes += 1
	return successes

func _spawn_single_cast(context: Dictionary, shot_aim: Vector2, is_echo: bool, branch: int, branches: int) -> bool:
	if bool(context.get("fall", false)) and int(context["spell"]) not in FALL_PHYSICAL_SPELLS and not bool(context.get("_fall_arrived", false)):
		if get_tree().get_nodes_in_group("vfx_fall_preview").size() >= MAX_FALL_PREVIEWS:
			blocked_spawns += 1
			return false
		var warning = FALL_SCRIPT.new()
		warning.configure(shot_aim, null, Vector2(context["origin"]))
		warning.arrived.connect(_on_fall_arrived.bind(context.duplicate(true), shot_aim, is_echo, branch, branches))
		add_child(warning)
		return true

	var spell_id: int = int(context["spell"])
	var origin: Vector2 = context["origin"]
	var density: float = float(context["density"])
	var rank: int = int(context["rank"])
	var motion: int = int(context["motion"])
	var replace_hole: bool = bool(context["replace_hole"]) and not is_echo
	var in_orbit: bool = bool(context.get("orbit", false))
	var in_fall: bool = bool(context.get("fall", false)) and not bool(context.get("_fall_arrived", false))
	var cast_aim: Vector2 = shot_aim
	if in_orbit:
		var heading: Vector2 = shot_aim - origin
		if heading.length_squared() < 0.001:
			heading = Vector2.RIGHT
		# Native projectile arrival checks need a distant virtual endpoint;
		# only the orbit driver sets the actual visible world position.
		cast_aim = origin + heading.normalized() * 1200.0
	var spawned_spell: Node2D = null
	var active_count := get_tree().get_nodes_in_group("vfx_bolt").size() + get_tree().get_nodes_in_group("vfx_bloom").size() + get_tree().get_nodes_in_group("vfx_moon").size() + get_tree().get_nodes_in_group("vfx_hole").size() + get_tree().get_nodes_in_group("vfx_thorn").size() + get_tree().get_nodes_in_group("vfx_ice_sword").size() + get_tree().get_nodes_in_group("vfx_thunder").size() + get_tree().get_nodes_in_group("vfx_poison_ball").size() + get_tree().get_nodes_in_group("vfx_lightning_arc").size() + get_tree().get_nodes_in_group("vfx_fireball").size() + get_tree().get_nodes_in_group("vfx_laser").size()
	if active_count >= 50:
		blocked_spawns += 1
		return false
	if spell_id == 0:
		var bolt = BOLT_SCRIPT.new()
		bolt.configure(origin, cast_aim, density)
		if in_orbit:
			bolt.set_meta("aux_orbit", true)
		add_child(bolt)
		spawned_spell = bolt
		bolt.add_to_group("vfx_bolt")
		bolt.impacted.connect(_on_bolt_impact.bind(is_echo))
	elif spell_id == 1:
		var bomb = BLOOM_SCRIPT.new()
		bomb.configure(origin, cast_aim, density, BLOOM_RADII[rank])
		if in_orbit:
			bomb.set_meta("aux_orbit", true)
		add_child(bomb)
		spawned_spell = bomb
		bomb.add_to_group("vfx_bloom")
		bomb.impacted.connect(_on_bloom_impact.bind(rank, density, is_echo))
	elif spell_id == 2:
		var moon = MOON_SCRIPT.new()
		moon.configure(origin, cast_aim, density)
		if in_orbit:
			moon.set_meta("aux_orbit", true)
		add_child(moon)
		spawned_spell = moon
		moon.add_to_group("vfx_moon")
		moon.struck.connect(_on_moon_struck.bind(is_echo))
		moon.returned.connect(_on_moon_returned.bind(is_echo))
	elif spell_id == 3:
		# 이펙트 평가 중에는 블랙홀 한 개에만 집중한다.
		# 자동 발사는 기존 개체가 소멸할 때까지 기다리고, 수동 발사는 위치를 바꿔 다시 소환한다.
		var active_holes := get_tree().get_nodes_in_group("vfx_hole")
		if not bool(context["fan"]) and not bool(context["echo"]) and not in_orbit:
			if not active_holes.is_empty():
				if not replace_hole:
					return false
				for old_hole in active_holes:
					old_hole.remove_from_group("vfx_hole")
					old_hole.queue_free()
		elif active_holes.size() >= 6:
			blocked_spawns += 1
			return false
		var hole = BLACK_HOLE_SCRIPT.new()
		hole.configure(origin if in_orbit else shot_aim, origin, density, rank)
		if in_orbit:
			hole.set_meta("aux_orbit", true)
		add_child(hole)
		spawned_spell = hole
		hole.add_to_group("vfx_hole")
		hole.pulsed.connect(_on_black_hole_pulse)
		hole.vanished.connect(_on_black_hole_vanished)
	elif spell_id == 5:
		# Pure animation preview: no enemy, status effects, hitbox or spell combat.
		var sword = ICE_SWORD_SCRIPT.new()
		sword.configure(origin, shot_aim, density, rank, ice_sword_swings)
		if in_orbit:
			sword.aux_orbit = true
			sword.orbit_anchor = origin
			sword.orbit_angle = (shot_aim - origin).angle()
		add_child(sword)
		spawned_spell = sword
		sword.add_to_group("vfx_ice_sword")
		sword.finished.connect(_on_ice_sword_finished)
		ice_sword_swings += 1
	elif spell_id == 6:
		# Ground-targeted lightning VFX only. No combat collision or damage.
		var lightning = THUNDER_SCRIPT.new()
		lightning.configure(shot_aim, density, rank)
		add_child(lightning)
		spawned_spell = lightning
		lightning.add_to_group("vfx_thunder")
		lightning.struck.connect(_on_thunder_struck)
		lightning.finished.connect(_on_thunder_finished)
	elif spell_id == 7:
		# VFX-only: a simple bouncing poison circle leaves one ground puddle per landing.
		if get_tree().get_nodes_in_group("vfx_poison_ball").size() >= (6 if bool(context["fan"]) or bool(context["echo"]) else 5):
			blocked_spawns += 1
			return false
		var orb = POISON_BALL_SCRIPT.new()
		orb.configure(origin, cast_aim, density, rank)
		if in_orbit:
			orb.set_meta("aux_orbit", true)
		add_child(orb)
		spawned_spell = orb
		orb.add_to_group("vfx_poison_ball")
		orb.landed.connect(_on_poison_land.bind(density, is_echo))
		orb.finished.connect(_on_poison_finished)
	elif spell_id == 8:
		# FencerDevLog-inspired single unbranched electric arc, visually isolated from 7: strike.
		var arc = LIGHTNING_ARC_SCRIPT.new()
		arc.configure(origin, shot_aim, density, rank)
		add_child(arc)
		spawned_spell = arc
		arc.add_to_group("vfx_lightning_arc")
		arc.finished.connect(_on_lightning_arc_finished)
	elif spell_id == 10:
		# Magicraft 1004 basic: instant straight beam, no refraction until a later test.
		var ray = LASER_SCRIPT.new()
		ray.configure(origin, shot_aim, density, in_orbit)
		add_child(ray)
		spawned_spell = ray
		ray.add_to_group("vfx_laser")
		ray.finished.connect(_on_laser_finished)
	elif spell_id == 9:
		if get_tree().get_nodes_in_group("vfx_fireball").size() >= 6:
			blocked_spawns += 1
			return false
		var fireball = FIREBALL_SCRIPT.new()
		fireball.configure(origin, shot_aim, density, rank, 1 if in_orbit else motion)
		if in_orbit:
			fireball.aux_orbit = true
			fireball.aux_orbit_phase = (shot_aim - origin).angle()
		add_child(fireball)
		spawned_spell = fireball
		fireball.add_to_group("vfx_fireball")
		fireball.impacted.connect(_on_fireball_impact.bind(rank, density, is_echo))
		fireball.finished.connect(_on_fireball_finished)
	else:
		# Unlike the black-hole preview, multiple deployed thorn traps are allowed.
		if get_tree().get_nodes_in_group("vfx_thorn").size() >= 12:
			blocked_spawns += 1
			return false
		var trap = THORN_SCRIPT.new()
		var trap_aim := shot_aim
		if in_orbit:
			# Tangential throw, but normal trap setup after stopping.
			var radial := (shot_aim - origin).normalized()
			if radial.length_squared() < 0.001:
				radial = Vector2.RIGHT
			trap_aim = origin + radial * 125.0 + radial.orthogonal() * 230.0
		trap.configure(origin, trap_aim, density, rank)
		add_child(trap)
		spawned_spell = trap
		trap.add_to_group("vfx_thorn")
		trap.deployed.connect(_on_thorn_deployed)
		trap.triggered.connect(_on_thorn_triggered)
		trap.vanished.connect(_on_thorn_vanished)
	if spawned_spell == null:
		return false
	if is_echo:
		spawned_spell.modulate.a = ECHO_PREVIEW_ALPHA
	if in_orbit and spell_id != 9:
		var driver = ORBIT_SCRIPT.new()
		var phase: float = (shot_aim - origin).angle()
		driver.configure(spawned_spell, origin, rank, _orbit_velocity(spell_id), phase, spell_id)
		add_child(driver)
	fired_count += 1
	var label: String = SPELL_CHOICES[spell_id]
	if is_echo:
		label += " [메아리]"
	if branches > 1:
		label += " 갈래 %d/%d" % [branch, branches]
	if in_orbit:
		label += " [공전]"
	if bool(context.get("_fall_arrived", false)):
		label += " [낙하 완료]"
	var cast_id: int = harness.track(spawned_spell, label)
	if spell_id == 10:
		var beam_direction: Vector2 = (shot_aim - origin).normalized()
		if beam_direction.length_squared() <= 0.001:
			beam_direction = Vector2.RIGHT
		harness.check_beam(cast_id, origin, origin + beam_direction * float(LASER_SCRIPT.MAX_RANGE))
	return true

func _on_fall_arrived(context: Dictionary, landing: Vector2, is_echo: bool, branch: int, branches: int) -> void:
	var landed_context := context.duplicate(true)
	landed_context["_fall_arrived"] = true
	# Non-orbit attacks start just above the impact point, rather than flying
	# across the entire arena again after descent.
	if bool(context["orbit"]):
		landed_context["origin"] = landing
		var outward: Vector2 = landing - Vector2(context["origin"])
		if outward.length_squared() < 0.001:
			outward = Vector2.RIGHT
		# Keep a distant internal destination so projectile-specific arrival
		# checks cannot immediately kill the new orbiting projectile.
		_spawn_single_cast(landed_context, landing + outward.normalized() * 1200.0, is_echo, branch, branches)
	else:
		landed_context["origin"] = landing + Vector2(0.0, -65.0)
		_spawn_single_cast(landed_context, landing, is_echo, branch, branches)

func _on_laser_finished() -> void:
	laser_finished += 1

func _on_fireball_impact(point: Vector2, cast_rank: int, cast_density: float, is_echo: bool) -> void:
	fireball_impacts += 1
	var burst = FIREBALL_IMPACT_SCRIPT.new()
	burst.global_position = point
	burst.configure(float(FIREBALL_SCRIPT.RADII[cast_rank]), cast_density)
	add_child(burst)
	if is_echo:
		burst.modulate.a = ECHO_PREVIEW_ALPHA

func _on_fireball_finished() -> void:
	fireball_finished += 1

func _on_bolt_impact(point: Vector2, is_echo: bool) -> void:
	impact_count += 1
	var burst = IMPACT_SCRIPT.new()
	burst.global_position = point
	add_child(burst)
	if is_echo:
		burst.modulate.a = ECHO_PREVIEW_ALPHA

func _on_bloom_impact(point: Vector2, radius: float, cast_rank: int, cast_density: float, is_echo: bool) -> void:
	impact_count += 1
	var burst = BLOOM_BURST_SCRIPT.new()
	burst.global_position = point
	burst.configure(radius, cast_density, cast_rank)
	add_child(burst)
	if is_echo:
		burst.modulate.a = ECHO_PREVIEW_ALPHA

func _on_moon_struck(point: Vector2, is_echo: bool) -> void:
	impact_count += 1
	var flash = MOON_HIT_SCRIPT.new()
	flash.global_position = point
	flash.configure(false)
	add_child(flash)
	if is_echo:
		flash.modulate.a = ECHO_PREVIEW_ALPHA

func _on_moon_returned(point: Vector2, is_echo: bool) -> void:
	var flash = MOON_HIT_SCRIPT.new()
	flash.global_position = point
	flash.configure(true)
	add_child(flash)
	if is_echo:
		flash.modulate.a = ECHO_PREVIEW_ALPHA

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

func _on_lightning_arc_finished(_point: Vector2) -> void:
	lightning_arc_finished += 1

func _on_poison_land(point: Vector2, radius: float, lifetime: float, cast_density: float, is_echo: bool) -> void:
	poison_landings += 1
	# Bound the preview under repeated casts and high-rank tests.
	var pools := get_tree().get_nodes_in_group("vfx_poison_puddle")
	if pools.size() >= 60:
		pools[0].queue_free()
	var puddle = POISON_PUDDLE_SCRIPT.new()
	puddle.position = point
	puddle.configure(radius, lifetime, cast_density)
	add_child(puddle)
	if is_echo:
		puddle.modulate.a = ECHO_PREVIEW_ALPHA
	puddle.add_to_group("vfx_poison_puddle")

func _on_poison_finished() -> void:
	poison_finished += 1

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
		7: return "독 탱탱볼"
		8: return "번개 아크"
		9: return "화염구"
		10: return "광선"
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
			KEY_PAGEUP:
				_select_spell(selected_spell - 1)
			KEY_PAGEDOWN:
				_select_spell(selected_spell + 1)
			KEY_1, KEY_KP_1:
				_select_spell(0)
			KEY_2, KEY_KP_2:
				_select_spell(1)
			KEY_3, KEY_KP_3:
				_select_spell(2)
			KEY_4, KEY_KP_4:
				_select_spell(3)
			KEY_5, KEY_KP_5:
				_select_spell(4)
			KEY_6, KEY_KP_6:
				_select_spell(5)
			KEY_7, KEY_KP_7:
				_select_spell(6)
			KEY_8, KEY_KP_8:
				_select_spell(7)
			KEY_9, KEY_KP_9:
				_select_spell(8)
			KEY_0, KEY_KP_0:
				_select_spell(9)
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
					poison_rank = maxi(0, poison_rank - 1)
				elif selected_spell == 8:
					lightning_arc_rank = maxi(0, lightning_arc_rank - 1)
				elif selected_spell == 9:
					fireball_rank = maxi(0, fireball_rank - 1)
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
					poison_rank = mini(3, poison_rank + 1)
				elif selected_spell == 8:
					lightning_arc_rank = mini(3, lightning_arc_rank + 1)
				elif selected_spell == 9:
					fireball_rank = mini(3, fireball_rank + 1)
			KEY_F:
				_cycle_test_mode()
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
				for preview in get_tree().get_nodes_in_group("vfx_fall_preview"):
					preview.cancel()
				for driver in get_tree().get_nodes_in_group("vfx_orbit_driver"):
					driver.queue_free()
				pending_echoes.clear()
				original_casts = 0
				echo_casts = 0
				blocked_spawns = 0
				fire_clock = _auto_interval()
				for group_name in ["vfx_bolt", "vfx_bloom", "vfx_moon", "vfx_hole", "vfx_thorn", "vfx_ice_sword", "vfx_thunder", "vfx_poison_ball", "vfx_poison_puddle", "vfx_lightning_arc", "vfx_fireball", "vfx_laser"]:
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
				lightning_arc_finished = 0
				fireball_impacts = 0
				fireball_finished = 0
				laser_finished = 0
				poison_landings = 0
				poison_finished = 0
				harness.reset_statistics()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("1b2030"), true)
	for x in range(0, 1601, 80):
		draw_line(Vector2(x, 186), Vector2(x, 900), Color(0.62, 0.70, 0.9, 0.065), 1.0)
	for y in range(186, 901, 80):
		draw_line(Vector2(0, y), Vector2(1600, y), Color(0.62, 0.70, 0.9, 0.065), 1.0)

	var aiming_color := Color("ffd98e")
	match selected_spell:
		1: aiming_color = Color("f4a6c4")
		2: aiming_color = Color("c6b7ff")
		3: aiming_color = Color("a38cff")
		4: aiming_color = Color("ecadd2")
		5: aiming_color = Color("8ceaff")
		6: aiming_color = Color("76baff")
		7: aiming_color = Color("a5dc45")
		8: aiming_color = Color("64aeff")
		9: aiming_color = Color("ffbf62")
		10: aiming_color = Color("70dbff")
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
		# 블랙홀/가시꽃/서리검/벼락/독 탱탱볼/번개 아크에는 분홍색 표적 모형을 그리지 않는다.
		draw_arc(target_point, 8.0, 0.0, TAU, 24, Color(0.58, 0.80, 0.77, 0.28), 1.5, true)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color("111725")
	panel.position = Vector2.ZERO
	panel.size = Vector2(1600, 186)
	layer.add_child(panel)

	title_label = Label.new()
	title_label.position = Vector2(35, 16)
	title_label.add_theme_font_size_override("font_size", 27)
	title_label.add_theme_color_override("font_color", Color("ffdba8"))
	layer.add_child(title_label)
	_update_title()

	info_label = Label.new()
	info_label.text = "마법 선택: 목록 / PgUp·PgDn 이전·다음 (1~0 유지)  |  갈래·메아리·낙하·공전 실험\n클릭·SPACE 발사   R 자동   Q/E 강화   F 이동 방식   T 덫 발동   ↑/↓ 입자   C 기록 초기화"
	info_label.position = Vector2(36, 57)
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color("c9d0e0"))
	layer.add_child(info_label)

	effect_label = Label.new()
	effect_label.position = Vector2(36, 99)
	effect_label.add_theme_font_size_override("font_size", 14)
	effect_label.add_theme_color_override("font_color", Color("bfe7da"))
	layer.add_child(effect_label)

	status_label = Label.new()
	status_label.position = Vector2(36, 151)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("a8b8d6"))
	layer.add_child(status_label)
	_create_spell_controls(layer)

func _create_spell_controls(layer: CanvasLayer) -> void:
	var name_label := Label.new()
	name_label.text = "마법 선택"
	name_label.position = Vector2(880, 17)
	name_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(name_label)

	var prev := Button.new()
	prev.text = "<"
	prev.position = Vector2(977, 12)
	prev.size = Vector2(35, 35)
	prev.pressed.connect(_previous_spell)
	layer.add_child(prev)

	spell_picker = OptionButton.new()
	spell_picker.position = Vector2(1018, 12)
	spell_picker.size = Vector2(278, 35)
	for i in range(SPELL_CHOICES.size()):
		spell_picker.add_item(SPELL_CHOICES[i], i)
	spell_picker.select(selected_spell)
	spell_picker.item_selected.connect(_select_spell)
	layer.add_child(spell_picker)

	var next := Button.new()
	next.text = ">"
	next.position = Vector2(1304, 12)
	next.size = Vector2(35, 35)
	next.pressed.connect(_next_spell)
	layer.add_child(next)

	var mode_label := Label.new()
	mode_label.text = "실험 방식"
	mode_label.position = Vector2(880, 62)
	mode_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(mode_label)

	mode_picker = OptionButton.new()
	mode_picker.position = Vector2(1018, 57)
	mode_picker.size = Vector2(278, 35)
	mode_picker.item_selected.connect(_on_test_mode_selected)
	layer.add_child(mode_picker)
	_refresh_test_modes()
	_create_support_controls(layer)

func _create_support_controls(layer: CanvasLayer) -> void:
	var label_1 := Label.new()
	label_1.text = "보조 1"
	label_1.position = Vector2(880, 109)
	label_1.add_theme_font_size_override("font_size", 16)
	layer.add_child(label_1)

	support_picker_1 = OptionButton.new()
	support_picker_1.position = Vector2(953, 103)
	support_picker_1.size = Vector2(233, 34)
	for i in range(SUPPORT_CHOICES.size()):
		support_picker_1.add_item(SUPPORT_CHOICES[i], i)
	support_picker_1.select(0)
	support_picker_1.item_selected.connect(_on_support_selected.bind(1))
	support_picker_1.tooltip_text = "갈래·메아리·낙하·일부 공격 공전이 작동합니다. 나머지는 준비 중."
	layer.add_child(support_picker_1)

	var label_2 := Label.new()
	label_2.text = "보조 2"
	label_2.position = Vector2(1194, 109)
	label_2.add_theme_font_size_override("font_size", 16)
	layer.add_child(label_2)

	support_picker_2 = OptionButton.new()
	support_picker_2.position = Vector2(1267, 103)
	support_picker_2.size = Vector2(293, 34)
	for i in range(SUPPORT_CHOICES.size()):
		support_picker_2.add_item(SUPPORT_CHOICES[i], i)
	support_picker_2.select(0)
	support_picker_2.item_selected.connect(_on_support_selected.bind(2))
	support_picker_2.tooltip_text = "갈래·메아리·낙하·일부 공격 공전. 동일 보조 중복은 금지."
	layer.add_child(support_picker_2)

func _on_support_selected(index: int, slot: int) -> void:
	# The same auxiliary spell must not appear in both slots.
	if slot == 1:
		support_1 = index
		if index != 0 and support_2 == index:
			support_2 = 0
			support_picker_2.select(0)
	else:
		support_2 = index
		if index != 0 and support_1 == index:
			support_1 = 0
			support_picker_1.select(0)
	fire_clock = _auto_interval()

func _select_spell(index: int) -> void:
	selected_spell = posmod(index, SPELL_CHOICES.size())
	if spell_picker != null:
		spell_picker.select(selected_spell)
	_refresh_test_modes()
	_update_title()
	fire_clock = 0.05
	queue_redraw()

func _previous_spell() -> void:
	_select_spell(selected_spell - 1)

func _next_spell() -> void:
	_select_spell(selected_spell + 1)

func _refresh_test_modes() -> void:
	if mode_picker == null:
		return
	mode_picker.clear()
	var modes: Array = SPELL_TEST_MODES.get(selected_spell, ["기본"])
	for i in range(modes.size()):
		mode_picker.add_item(str(modes[i]), i)
	mode_picker.disabled = modes.size() <= 1
	mode_picker.select(fireball_motion if selected_spell == 9 else 0)

func _cycle_test_mode() -> void:
	if mode_picker == null or mode_picker.item_count < 2:
		return
	_on_test_mode_selected((mode_picker.selected + 1) % mode_picker.item_count)

func _on_test_mode_selected(index: int) -> void:
	# Per-spell extension: future orbit/seek/bounce runners attach here.
	if selected_spell == 9:
		fireball_motion = index
	mode_picker.select(index)
	fire_clock = 0.05

func _update_title() -> void:
	title_label.text = "WITCHLINGS / MAGIC VFX LAB     %s" % _spell_name()
