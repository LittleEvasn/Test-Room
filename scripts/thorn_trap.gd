extends Node2D
## Thorn trap VFX lab: roll + bounce -> snap-open -> armed -> triggered/expired.
## Uses the user's five centered, transparent 512x512 original sprites.
## Test room: press T to simulate enemy proximity; this file does not deal damage.

signal deployed(at: Vector2, radius: float)
signal triggered(at: Vector2, radius: float)
signal vanished(at: Vector2)

const SEED_TEXTURE: Texture2D = preload("res://assets/가시꽃 탄.png")
const STEM_TEXTURE: Texture2D = preload("res://assets/가시꽃 줄기.png")
const LEAF_TEXTURE: Texture2D = preload("res://assets/가시꽃 잎.png")
const CORE_TEXTURE: Texture2D = preload("res://assets/가시꽃 심지.png")
const FINAL_TEXTURE: Texture2D = preload("res://assets/가시꽃 완성본.png")

const ROLLING := "ROLLING"
const DEPLOYING := "DEPLOYING"
const ARMED := "ARMED"
const TRIGGERED := "TRIGGERED"
const EXPIRED := "EXPIRED"
const RADII := [62.0, 80.0, 100.0, 125.0]
const ARMED_SECONDS := [6.0, 7.0, 8.0, 9.0]
const ROLL_DURATION := 1.55
const OPEN_DURATION := 0.26
const HIT_DURATION := 0.42
const END_DURATION := 0.32
const GRAVITY := 980.0
const LIMBS := 5
const TEX_CENTER := Vector2(256.0, 256.0)
const ART_RADIUS := 225.0

var rank := 0
var density := 1.0
var state := ROLLING
var origin := Vector2.ZERO
var landing := Vector2.ZERO
var ground_pos := Vector2.ZERO
var travel_time := 0.0
var state_time := 0.0
var seed_height := 0.0
var vertical_speed := 315.0
var seed_angle := 0.0
var dust: Array[Dictionary] = []

func configure(from_point: Vector2, to_point: Vector2, particle_density: float, upgrade_rank: int) -> void:
    origin = from_point
    landing = to_point
    ground_pos = from_point
    global_position = from_point
    density = clampf(particle_density, 0.0, 3.0)
    rank = clampi(upgrade_rank, 0, 3)

func trap_radius() -> float:
    return float(RADII[rank])

func trap_state() -> String:
    return state

func trigger_trap() -> bool:
    if state != ARMED:
        return false
    state = TRIGGERED
    state_time = 0.0
    triggered.emit(global_position, trap_radius())
    return true

func _process(delta: float) -> void:
    _update_dust(delta)
    if state == ROLLING:
        _roll(delta)
    elif state == DEPLOYING:
        state_time += delta
        if state_time >= OPEN_DURATION:
            state = ARMED
            state_time = 0.0
            deployed.emit(global_position, trap_radius())
    elif state == ARMED:
        state_time += delta
        if state_time >= float(ARMED_SECONDS[rank]):
            state = EXPIRED
            state_time = 0.0
    elif state == TRIGGERED:
        state_time += delta
        if state_time >= HIT_DURATION:
            vanished.emit(global_position)
            queue_free()
            return
    elif state == EXPIRED:
        state_time += delta
        if state_time >= END_DURATION:
            vanished.emit(global_position)
            queue_free()
            return
    queue_redraw()

func _roll(delta: float) -> void:
    travel_time = minf(ROLL_DURATION, travel_time + delta)
    var t := clampf(travel_time / ROLL_DURATION, 0.0, 1.0)
    # Horizontal travel uses friction easing; vertical launch obeys gravity/rebound.
    var progress := 1.0 - pow(1.0 - t, 1.46)
    var previous_ground := ground_pos
    ground_pos = origin.lerp(landing, progress)
    global_position = ground_pos
    seed_angle += ground_pos.distance_to(previous_ground) / 21.0
    seed_height += vertical_speed * delta
    vertical_speed -= GRAVITY * delta
    if seed_height <= 0.0:
        seed_height = 0.0
        if absf(vertical_speed) >= 62.0 and t < 0.90:
            vertical_speed = -vertical_speed * 0.39
            _scatter_dust()
        else:
            vertical_speed = 0.0
    if t >= 1.0:
        global_position = landing
        ground_pos = landing
        seed_height = 0.0
        state = DEPLOYING
        state_time = 0.0
        _scatter_dust()

func _scatter_dust() -> void:
    var count := int(round(4.0 * density))
    for i in count:
        if dust.size() >= 32:
            break
        var a := randf_range(0.0, TAU)
        dust.append({
            "world": ground_pos + Vector2.RIGHT.rotated(a) * randf_range(2.0, 12.0),
            "age": 0.0,
            "duration": randf_range(0.22, 0.42),
            "size": randf_range(1.5, 3.8)
        })

func _update_dust(delta: float) -> void:
    for i in range(dust.size() - 1, -1, -1):
        dust[i]["age"] = float(dust[i]["age"]) + delta
        if float(dust[i]["age"]) >= float(dust[i]["duration"]):
            dust.remove_at(i)

func _art_scale() -> float:
    return trap_radius() / ART_RADIUS

func _seed_scale() -> float:
    return 0.54 + float(rank) * 0.055

func _paint_part(texture: Texture2D, angle: float, size: float, alpha: float, shift: Vector2 = Vector2.ZERO) -> void:
    draw_set_transform(shift, angle, Vector2.ONE * size)
    draw_texture(texture, -TEX_CENTER, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
    draw_set_transform()

func _draw_seed() -> void:
    draw_set_transform(Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.30))
    draw_circle(Vector2.ZERO, 18.0 + seed_height * 0.045, Color(0.03, 0.06, 0.08, 0.27))
    draw_set_transform()
    _paint_part(SEED_TEXTURE, seed_angle, _seed_scale(), 1.0, Vector2(0.0, -seed_height))

func _draw_parts(unfold: float, alpha: float, snap := 0.0) -> void:
    var extent := _art_scale()
    # Original stem & leaf share the finished image's 512x512 origin.
    for i in LIMBS:
        var theta := float(i) * TAU / float(LIMBS)
        var fold := -0.80 * (1.0 - unfold)
        var size := extent * lerpf(0.20, 1.0, unfold)
        _paint_part(LEAF_TEXTURE, theta + fold * 0.7, size, alpha * minf(1.0, unfold * 3.5))
        _paint_part(STEM_TEXTURE, theta + fold + snap, size, alpha)
    _paint_part(CORE_TEXTURE, 0.0, extent * lerpf(0.45, 1.0, unfold), alpha)

func _draw_opening() -> void:
    var t := clampf(state_time / OPEN_DURATION, 0.0, 1.0)
    var expansion := 1.0 - pow(1.0 - t, 3.8)
    expansion = minf(1.08, expansion + sin(t * PI) * 0.045)
    var blend := smoothstep(0.58, 0.96, t)
    _draw_parts(expansion, 1.0 - blend)
    _paint_part(FINAL_TEXTURE, 0.0, _art_scale() * (1.0 + 0.04 * sin(t * PI)), blend)
    if density > 0.0:
        draw_arc(Vector2.ZERO, lerpf(12.0, trap_radius(), expansion), 0.0, TAU, 60,
            Color(1.0, 0.73, 0.91, 0.32 * (1.0 - t)), 2.8, true)

func _draw_armed(alpha: float = 1.0, size_fraction: float = 1.0) -> void:
    draw_set_transform(Vector2(0.0, 7.0), 0.0, Vector2(1.0, 0.33))
    draw_circle(Vector2.ZERO, trap_radius() * 0.9 * size_fraction, Color(0.04, 0.09, 0.06, 0.16 * alpha))
    draw_set_transform()
    _paint_part(FINAL_TEXTURE, 0.0, _art_scale() * size_fraction, alpha)
    draw_arc(Vector2.ZERO, trap_radius(), 0.0, TAU, 72,
        Color(0.77, 0.91, 0.67, 0.12 * alpha), 1.2, true)

func _draw_triggered() -> void:
    var t := clampf(state_time / HIT_DURATION, 0.0, 1.0)
    if t < 0.28:
        var strike := sin(t / 0.28 * PI * 0.5)
        _draw_armed(1.0 - 0.86 * strike, 1.0)
        _draw_parts(1.0 - 0.43 * strike, 0.96, 0.40 * strike)
    else:
        var fade := 1.0 - smoothstep(0.28, 1.0, t)
        _draw_parts(0.57, fade, 0.40 * (1.0 - t))
    var wave_t := clampf(t / 0.68, 0.0, 1.0)
    draw_arc(Vector2.ZERO, trap_radius() * (0.50 + 0.64 * wave_t), 0.0, TAU, 60,
        Color(1.0, 0.71, 0.86, (1.0 - wave_t) * 0.78), 3.6, true)
    if t < 0.52:
        for i in LIMBS:
            var angle := float(i) * TAU / float(LIMBS)
            var direction := Vector2.UP.rotated(angle)
            draw_line(direction * trap_radius() * 0.36,
                direction * trap_radius() * (0.80 + 0.20 * t),
                Color(1.0, 0.86, 0.67, (1.0 - t / 0.52) * 0.70), 2.0, true)

func _draw_expired() -> void:
    var t := clampf(state_time / END_DURATION, 0.0, 1.0)
    _draw_armed(1.0 - t, 1.0 - t * 0.28)

func _draw() -> void:
    for puff in dust:
        var t := float(puff["age"]) / float(puff["duration"])
        draw_circle(to_local(Vector2(puff["world"])), float(puff["size"]) * (1.0 + t),
            Color(0.83, 0.77, 0.69, (1.0 - t) * 0.44))
    if state == ROLLING:
        _draw_seed()
    elif state == DEPLOYING:
        _draw_opening()
    elif state == ARMED:
        _draw_armed()
    elif state == TRIGGERED:
        _draw_triggered()
    elif state == EXPIRED:
        _draw_expired()
