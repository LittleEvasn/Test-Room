extends Node2D
## 독립 실행형 별빛탄 VFX 테스트. 원본 게임 코드에는 의존하지 않음.

const BOLT_SCRIPT = preload("res://scripts/star_bolt.gd")
const IMPACT_SCRIPT = preload("res://scripts/impact_burst.gd")
const SCREEN_SIZE := Vector2(1600.0, 900.0)
const START_POINT := Vector2(200.0, 490.0)

var target_point := Vector2(1330.0, 490.0)
var autofire := true
var fire_interval := 0.72
var fire_clock := 0.2
var particle_multiplier := 1.0
var fired_count := 0
var impact_count := 0
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
    status_label.text = "발사 %d  |  명중 %d  |  파티클 밀도 %.1fx  |  자동 발사 %s" % [fired_count, impact_count, particle_multiplier, "ON" if autofire else "OFF"]
    queue_redraw()

func shoot() -> void:
    if get_tree().get_nodes_in_group("vfx_bolt").size() >= 50:
        return
    var bolt = BOLT_SCRIPT.new()
    bolt.configure(START_POINT, target_point, particle_multiplier)
    add_child(bolt)
    bolt.add_to_group("vfx_bolt")
    bolt.impacted.connect(_on_impact)
    fired_count += 1

func _on_impact(point: Vector2) -> void:
    impact_count += 1
    var burst = IMPACT_SCRIPT.new()
    burst.global_position = point
    add_child(burst)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            target_point = get_global_mouse_position().clamp(Vector2(50, 150), SCREEN_SIZE - Vector2(50, 70))
            shoot()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            shoot()
        queue_redraw()
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_SPACE:
                shoot()
            KEY_R:
                autofire = not autofire
            KEY_UP, KEY_EQUAL, KEY_KP_ADD:
                particle_multiplier = minf(3.0, particle_multiplier + 0.5)
            KEY_DOWN, KEY_MINUS, KEY_KP_SUBTRACT:
                particle_multiplier = maxf(0.0, particle_multiplier - 0.5)
            KEY_C:
                for bolt in get_tree().get_nodes_in_group("vfx_bolt"):
                    bolt.queue_free()
                fired_count = 0
                impact_count = 0

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color("1b2030"), true)
    for x in range(0, 1601, 80):
        draw_line(Vector2(x, 140), Vector2(x, 900), Color(0.62, 0.70, 0.9, 0.065), 1.0)
    for y in range(140, 901, 80):
        draw_line(Vector2(0, y), Vector2(1600, y), Color(0.62, 0.70, 0.9, 0.065), 1.0)
    draw_line(START_POINT, target_point, Color(0.85, 0.75, 0.45, 0.09), 2.0)
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

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color("111725")
    panel.position = Vector2.ZERO
    panel.size = Vector2(1600, 140)
    layer.add_child(panel)
    var title := Label.new()
    title.text = "WITCHLINGS  /  별빛탄 VFX LAB"
    title.position = Vector2(35, 20)
    title.add_theme_font_size_override("font_size", 27)
    title.add_theme_color_override("font_color", Color("ffe17a"))
    layer.add_child(title)
    info_label = Label.new()
    info_label.text = "마우스 왼쪽: 표적 이동·발사   |   SPACE: 발사   |   R: 자동 발사   |   ↑/↓: 파티클 밀도   |   C: 초기화"
    info_label.position = Vector2(36, 69)
    info_label.add_theme_font_size_override("font_size", 17)
    info_label.add_theme_color_override("font_color", Color("c9d0e0"))
    layer.add_child(info_label)
    status_label = Label.new()
    status_label.position = Vector2(36, 104)
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("a8b8d6"))
    layer.add_child(status_label)
