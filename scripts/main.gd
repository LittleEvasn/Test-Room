extends Node2D
## 별빛탄/꽃폭탄 VFX 독립 실험실. 본게임 마법의 충돌/피해 로직에는 의존하지 않는다.

const BOLT_SCRIPT = preload("res://scripts/star_bolt.gd")
const IMPACT_SCRIPT = preload("res://scripts/impact_burst.gd")
const BLOOM_SCRIPT = preload("res://scripts/bloom_bomb.gd")
const BLOOM_BURST_SCRIPT = preload("res://scripts/bloom_burst.gd")

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
var selected_spell := 0 # 0 = 별빛탄, 1 = 꽃폭탄
var bloom_rank := 0

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
            fire_clock = fire_interval
            shoot()
    var spell_name := "별빛탄" if selected_spell == 0 else "꽃폭탄"
    var rank_str := "" if selected_spell == 0 else "  |  꽃폭탄 +%d (폭발 반경 %.0f)" % [bloom_rank, BLOOM_RADII[bloom_rank]]
    status_label.text = "선택 %s%s  |  발사 %d  명중 %d  |  파티클 %.1fx  |  자동 %s" % [
        spell_name, rank_str, fired_count, impact_count, particle_multiplier, "ON" if autofire else "OFF"
    ]
    queue_redraw()

func shoot() -> void:
    var active_count := get_tree().get_nodes_in_group("vfx_bolt").size() + get_tree().get_nodes_in_group("vfx_bloom").size()
    if active_count >= 50:
        return
    if selected_spell == 0:
        var bolt = BOLT_SCRIPT.new()
        bolt.configure(START_POINT, target_point, particle_multiplier)
        add_child(bolt)
        bolt.add_to_group("vfx_bolt")
        bolt.impacted.connect(_on_bolt_impact)
    else:
        var bomb = BLOOM_SCRIPT.new()
        bomb.configure(START_POINT, target_point, particle_multiplier, BLOOM_RADII[bloom_rank])
        add_child(bomb)
        bomb.add_to_group("vfx_bloom")
        bomb.impacted.connect(_on_bloom_impact.bind(bloom_rank))
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
            KEY_Q:
                bloom_rank = maxi(0, bloom_rank - 1)
            KEY_E:
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
                for group_name in ["vfx_bolt", "vfx_bloom"]:
                    for projectile in get_tree().get_nodes_in_group(group_name):
                        projectile.queue_free()
                # 이미 생성된 폭발은 자연스럽게 사라진다.
                fired_count = 0
                impact_count = 0

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("1b2030"), true)
    for x in range(0, 1601, 80):
        draw_line(Vector2(x, 140), Vector2(x, 900), Color(0.62, 0.70, 0.9, 0.065), 1.0)
    for y in range(140, 901, 80):
        draw_line(Vector2(0, y), Vector2(1600, y), Color(0.62, 0.70, 0.9, 0.065), 1.0)

    var aiming_color := Color("ffd98e") if selected_spell == 0 else Color("f4a6c4")
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
    info_label.text = "1 별빛탄 / 2 꽃폭탄  |  Q/E 꽃폭탄 강화  |  클릭 표적·발사  |  SPACE 발사  |  R 자동  |  ↑/↓ 입자  |  C 초기화"
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
    title_label.text = "WITCHLINGS / MAGIC VFX LAB     %s" % ("별빛탄" if selected_spell == 0 else "꽃폭탄")
