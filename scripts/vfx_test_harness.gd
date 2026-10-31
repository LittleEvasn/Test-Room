extends Node2D
## Stage 0: instrumentation only. Dummy contacts and VFX signals do not deal damage.
## The spell scene remains authoritative for visuals and lifetime.

const TARGETS := [
	Vector2(605.0, 490.0),
	Vector2(845.0, 348.0),
	Vector2(1080.0, 635.0),
	Vector2(1320.0, 490.0)
]
const TARGET_RADIUS := 33.0
const MAX_LOG_LINES := 7

var active: Dictionary = {}
var recent: Array[String] = []
var target_flash: Dictionary = {}
var elapsed := 0.0
var next_cast_number := 1
var spawned_count := 0
var moved_count := 0
var mock_contact_count := 0
var visual_event_count := 0
var despawn_count := 0
var stats_label: Label
var log_label: Label

func _ready() -> void:
	z_index = 0 # Draw dummies above the arena background, below projectile children.
	_create_overlay()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	for id in active.keys():
		var entry: Dictionary = active[id]
		var projectile: Node2D = entry["node"]
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		var previous: Vector2 = entry["position"]
		var current: Vector2 = projectile.global_position
		if not bool(entry["moved"]) and current.distance_to(Vector2(entry["start"])) >= 14.0:
			entry["moved"] = true
			active[id] = entry # Persist the once-per-cast flag before contact sampling.
			moved_count += 1
			_add_log("#%d %s · 이동 시작" % [int(entry["number"]), str(entry["name"])])
		# Sample the swept segment instead of only the current frame position.
		_check_contacts(id, previous, current)
		if active.has(id):
			entry = active[id]
			entry["position"] = current
			active[id] = entry
	_refresh_overlay()
	queue_redraw()

func track(projectile: Node2D, spell_name: String) -> int:
	var id: int = projectile.get_instance_id()
	var number := next_cast_number
	next_cast_number += 1
	active[id] = {
		"node": projectile,
		"name": spell_name,
		"number": number,
		"start": projectile.global_position,
		"position": projectile.global_position,
		"moved": false,
		"hits": {}
	}
	spawned_count += 1
	_add_log("#%d %s · 생성" % [number, spell_name])
	projectile.tree_exiting.connect(_on_projectile_exiting.bind(id))
	_connect_visual_signals(projectile, id)
	# Catch stationary visual effects already overlapping a dummy.
	_check_contacts(id, projectile.global_position, projectile.global_position)
	return id

func check_beam(id: int, origin: Vector2, endpoint: Vector2) -> void:
	# Instant beams never move their Node2D, so explicitly sample their full segment.
	_check_contacts(id, origin, endpoint)

func check_path(id: int, points: PackedVector2Array) -> void:
	# A round laser must be tested against EACH arc segment. Never approximate
	# the circle with a straight chord through the player.
	for i in range(1, points.size()):
		_check_contacts(id, points[i - 1], points[i])

func reset_statistics() -> void:
	# A subsequent C/queue_free must not count as a normal spell expiration.
	active.clear()
	recent.clear()
	target_flash.clear()
	next_cast_number = 1
	spawned_count = 0
	moved_count = 0
	mock_contact_count = 0
	visual_event_count = 0
	despawn_count = 0
	_add_log("기록 초기화 · 표적 4개 유지")

func _check_contacts(id: int, a: Vector2, b: Vector2) -> void:
	if not active.has(id):
		return
	var entry: Dictionary = active[id]
	var hits: Dictionary = entry["hits"]
	for i in range(TARGETS.size()):
		if hits.has(i):
			continue
		var target: Vector2 = TARGETS[i]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target, a, b)
		if target.distance_to(closest) <= TARGET_RADIUS:
			hits[i] = true
			mock_contact_count += 1
			target_flash[i] = elapsed
			_add_log("#%d 표적 %d · 가상 접촉 (피해 없음)" % [int(entry["number"]), i + 1])
	entry["hits"] = hits
	active[id] = entry

func _connect_visual_signals(projectile: Node2D, id: int) -> void:
	# Record original VFX callbacks, but never interpret them as combat hits.
	for signal_name in ["impacted", "struck", "landed", "triggered"]:
		if not projectile.has_signal(signal_name):
			continue
		var argument_count := -1
		for description in projectile.get_signal_list():
			if str(description.get("name", "")) == signal_name:
				var arguments: Array = description.get("args", [])
				argument_count = arguments.size()
				break
		match argument_count:
			0:
				projectile.connect(signal_name, Callable(self, "_on_visual_event_0").bind(id, signal_name))
			1:
				projectile.connect(signal_name, Callable(self, "_on_visual_event_1").bind(id, signal_name))
			2:
				projectile.connect(signal_name, Callable(self, "_on_visual_event_2").bind(id, signal_name))

func _on_visual_event_0(id: int, signal_name: String) -> void:
	_record_visual_event(id, signal_name)

func _on_visual_event_1(_first: Variant, id: int, signal_name: String) -> void:
	_record_visual_event(id, signal_name)

func _on_visual_event_2(_first: Variant, _second: Variant, id: int, signal_name: String) -> void:
	_record_visual_event(id, signal_name)

func _record_visual_event(id: int, signal_name: String) -> void:
	if not active.has(id):
		return
	var entry: Dictionary = active[id]
	visual_event_count += 1
	_add_log("#%d %s · VFX %s 신호" % [int(entry["number"]), str(entry["name"]), signal_name])

func _on_projectile_exiting(id: int) -> void:
	if not active.has(id):
		return
	var entry: Dictionary = active[id]
	active.erase(id)
	despawn_count += 1
	_add_log("#%d %s · 소멸" % [int(entry["number"]), str(entry["name"])])

func _add_log(message: String) -> void:
	recent.append(message)
	if recent.size() > MAX_LOG_LINES:
		recent.pop_front()
	_refresh_overlay()

func _refresh_overlay() -> void:
	if stats_label == null or log_label == null:
		return
	stats_label.text = "생성 %d  이동 %d  가상 접촉 %d  VFX 신호 %d  소멸 %d  |  활성 %d" % [
		spawned_count, moved_count, mock_contact_count, visual_event_count, despawn_count, active.size()
	]
	log_label.text = "\n".join(recent)

func _create_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(20.0, 678.0)
	panel.size = Vector2(633.0, 204.0)
	panel.color = Color(0.055, 0.078, 0.13, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	var heading := Label.new()
	heading.position = Vector2(34.0, 690.0)
	heading.text = "보조 마법 실험 기록  |  정적 표적 4개 / 실제 피해 판정 없음"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("ffdda0"))
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(heading)

	stats_label = Label.new()
	stats_label.position = Vector2(34.0, 722.0)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color("b9dfed"))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stats_label)

	log_label = Label.new()
	log_label.position = Vector2(34.0, 749.0)
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.add_theme_color_override("font_color", Color("d6dce8"))
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(log_label)
	_refresh_overlay()

func _draw() -> void:
	for i in range(TARGETS.size()):
		var point: Vector2 = TARGETS[i]
		var lit: bool = target_flash.has(i) and elapsed - float(target_flash[i]) < 0.32
		var color := Color("ffd27e") if lit else Color("90bdc8")
		draw_circle(point + Vector2(0.0, 13.0), 36.0, Color(0, 0, 0, 0.18))
		draw_circle(point, TARGET_RADIUS, Color(0.10, 0.16, 0.23, 0.52))
		draw_arc(point, TARGET_RADIUS, 0.0, TAU, 48, color, 2.0, true)
		draw_arc(point, 14.0, 0.0, TAU, 32, Color(color, 0.72), 1.6, true)
		draw_line(point + Vector2(-7.0, 0.0), point + Vector2(7.0, 0.0), color, 1.4, true)
		draw_line(point + Vector2(0.0, -7.0), point + Vector2(0.0, 7.0), color, 1.4, true)
		draw_string(ThemeDB.fallback_font, point + Vector2(-23.0, -47.0),
			"표적 %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15,
			Color("c2dce3"))
