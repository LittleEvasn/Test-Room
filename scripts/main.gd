extends Node2D
## 별빛탄/꽃폭탄/달빛 부메랑/블랙홀 VFX 독립 실험실. 본게임 전투 로직과 별개다.

const BOLT_SCRIPT = preload("res://scripts/star_bolt.gd")
const IMPACT_SCRIPT = preload("res://scripts/impact_burst.gd")
const BLOOM_SCRIPT = preload("res://scripts/bloom_bomb.gd")
const BLOOM_BURST_SCRIPT = preload("res://scripts/bloom_burst.gd")
const MOON_SCRIPT = preload("res://scripts/moon_boomerang.gd")
const MOON_HIT_SCRIPT = preload("res://scripts/moon_hit_burst.gd")
const BLACK_HOLE_SCRIPT = preload("res://scripts/vortex_black_hole.gd")

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
var selected_spell := 0 # 0 = 별빛탄, 1 = 꽃폭탄, 2 = 달빛 부메랑, 3 = 소용돌이 씨앗(블랙홀)
var bloom_rank := 0
var black_hole_rank := 0
var black_hole_ticks := 0
var black_hole_finished := 0

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
            fire_clock = 1.8 if selected_spell == 3 else fire_interval
            shoot()
    var spell_name := _spell_name()
    if selected_spell == 3:
        status_label.text = "선택 %s +%d  |  생성 %d  가상 틱 %d  소멸 %d  |  파티클 %.1fx  |  자동 %s" % [
            spell_name, black_hole_rank, fired_count, black_hole_ticks, black_hole_finished, particle_multiplier, "ON" if autofire else "OFF"
        ]
    else:
        var rank_str := "" if selected_spell != 1 else "  |  꽃폭탄 +%d (폭발 반경 %.0f)" % [bloom_rank, BLOOM_RADII[bloom_rank]]
        status_label.text = "선택 %s%s  |  발사 %d  명중 %d  |  파티클 %.1fx  |  자동 %s" % [
            spell_name, rank_str, fired_count, impact_count, particle_multiplier, "ON" if autofire else "OFF"
        ]
    queue_redraw()

func shoot() -> void:
    var active_count := get_tree().get_nodes_in_group("vfx_bolt").size() + get_tree().get_nodes_in_group("vfx_bloom").size() + get_tree().get_nodes_in_group("vfx_moon").size() + get_tree().get_nodes_in_group("vfx_hole").size()
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
    else:
        # Test-Room 전용: 병합 없이 서로 떨어진 최대 3개 개체로 시각 실험.
        if get_tree().get_nodes_in_group("vfx_hole").size() >= 3:
            return
        var spawn_at := _find_black_hole_spawn()
        if spawn_at.x < 0.0:
            return
        var hole = BLACK_HOLE_SCRIPT.new()
        hole.configure(spawn_at, START_POINT, particle_multiplier, black_hole_rank)
        add_child(hole)
        hole.add_to_group("vfx_hole")
        hole.pulsed.connect(_on_black_hole_pulse)
        hole.vanished.connect(_on_black_hole_vanished)
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

func _find_black_hole_spawn() -> Vector2:
    # 배치 정책은 본게임에 적용하지 않는다. 겹침 없이 이펙트만 비교하기 위한 고정 실험 좌표.
    var existing := get_tree().get_nodes_in_group("vfx_hole")
    var offsets := [
        Vector2.ZERO,
        Vector2(-400.0, -250.0), Vector2(-400.0, 250.0),
        Vector2(400.0, -250.0), Vector2(400.0, 250.0),
        Vector2(0.0, -380.0), Vector2(0.0, 380.0)
    ]
    var best := Vector2(-1.0, -1.0)
    var best_gap := -1.0
    for offset in offsets:
        var candidate: Vector2 = (target_point + offset).clamp(Vector2(220.0, 255.0), Vector2(1380.0, 720.0))
        var nearest := INF
        for node in existing:
            var hole_node := node as Node2D
            if hole_node != null:
                nearest = minf(nearest, candidate.distance_to(hole_node.global_position))
        if nearest > best_gap:
            best_gap = nearest
            best = candidate
    if not existing.is_empty() and best_gap < 335.0:
        return Vector2(-1.0, -1.0)
    return best

func _spell_name() -> String:
    match selected_spell:
        0: return "별빛탄"
        1: return "꽃폭탄"
        2: return "달빛 부메랑"
        3: return "소용돌이 씨앗(블랙홀)"
    return "미지의 마법"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            target_point = get_global_mouse_position().clamp(Vector2(185, 230), SCREEN_SIZE - Vector2(185, 170))
            shoot()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            shoot()
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
            KEY_Q:
                if selected_spell == 3:
                    black_hole_rank = maxi(0, black_hole_rank - 1)
                elif selected_spell == 1:
                    bloom_rank = maxi(0, bloom_rank - 1)
            KEY_E:
                if selected_spell == 3:
                    black_hole_rank = mini(3, black_hole_rank + 1)
                elif selected_spell == 1:
                    bloom_rank = mini(3, bloom_rank + 1)
            KEY_SPACE:
                shoot()
            KEY_R:
                autofire = not autofire
            KEY_UP, KEY_EQUAL, KEY_KP_ADD:
                particle_multiplier = minf(3.0, particle_multiplier + 0.5)
            KEY_DOWN, KEY_MINUS, KEY_KP_SUBTRACT:
                particle_multiplier = maxf(0.0, particle_multiplier - 0.5)
            KEY_C:
                for group_name in ["vfx_bolt", "vfx_bloom", "vfx_moon", "vfx_hole"]:
                    for projectile in get_tree().get_nodes_in_group(group_name):
                        projectile.queue_free()
                # 이미 생성된 폭발은 자연스럽게 사라진다.
                fired_count = 0
                impact_count = 0
                black_hole_ticks = 0
                black_hole_finished = 0

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("1b2030"), true)
    for x in range(0, 1601, 80):
        draw_line(Vector2(x, 140), Vector2(x, 900), Color(0.62, 0.70, 0.9, 0.065), 1.0)
    for y in range(140, 901, 80):
        draw_line(Vector2(0, y), Vector2(1600, y), Color(0.62, 0.70, 0.9, 0.065), 1.0)

    var aiming_color := Color("ffd98e") if selected_spell == 0 else (Color("f4a6c4") if selected_spell == 1 else (Color("c6b7ff") if selected_spell == 2 else Color("a38cff")))
    draw_line(START_POINT, target_point, Color(aiming_color, 0.09), 2.0)
    draw_circle(START_POINT + Vector2(0, 22), 35.0, Color(0, 0, 0, 0.24))
    draw_circle(START_POINT, 32.0, Color("6d658b"))
    draw_circle(START_POINT, 21.0, Color("ad9ed0"))
    draw_circle(START_POINT, 9.0, Color("eee2ff"))
    draw_arc(START_POINT, 40.0, 0.0, TAU, 48, Color("d9bbff"), 2.0)

    draw_circle(target_point + Vector2(0, 25), 38.0, Color(0, 0, 0, 0.26))
    draw_circle(target_point, 38.0, Color("554f67"))
    draw_circle(target_point, 29.0, Color("c48eaa"))
    draw_circle(target_point, 19.0, Color("e6b0c2"))
    draw_arc(target_point, 43.0, 0.0, TAU, 48, Color("d9a2b8"), 2.0)
    if selected_spell == 1:
        draw_arc(target_point, BLOOM_RADII[bloom_rank], 0.0, TAU, 64, Color(1.0, 0.65, 0.75, 0.28), 1.5, true)
    elif selected_spell == 3:
        draw_arc(target_point, 76.0, 0.0, TAU, 64, Color(0.75, 0.61, 1.0, 0.29), 1.5, true)

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
    info_label.text = "1 별빛탄 / 2 꽃폭탄 / 3 달빛 부메랑 / 4 블랙홀  |  Q/E 강화  |  클릭 표적·발사  |  SPACE 발사  |  R 자동  |  ↑/↓ 입자  |  C 초기화"
    info_label.position = Vector2(36, 66)
    info_label.add_theme_font_size_override("font_size", 17)
    info_label.add_theme_color_override("font_color", Color("c9d0e0"))
    layer.add_child(info_label)

    status_label = Label.new()
    status_label.position = Vector2(36, 104)
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("a8b8d6"))
    layer.add_child(status_label)

func _update_title() -> void:
    title_label.text = "WITCHLINGS / MAGIC VFX LAB     %s" % _spell_name()
