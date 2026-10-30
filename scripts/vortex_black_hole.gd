extends Node2D
## Black hole VFX v3: procedural shader disk + a few inward-moving particles.
## This standalone preview does not change gameplay damage, pull or fusion behavior.

signal pulsed(at: Vector2, radius: float)
signal vanished(at: Vector2)

const BLACK_HOLE_SHADER: Shader = preload("res://shaders/black_hole_disk.gdshader")
const LIFETIME := 5.0
const TICK_INTERVAL := 0.25
const BIRTH_TIME := 0.24
const COLLAPSE_TIME := 0.40
const BASE_RADIUS := 96.0
# Preview coefficients only. Mapping to Magicraft's 3 stages is not finalized.
const PREVIEW_GROWTH := [0.0, 0.07, 0.14, 0.21]
const MAX_MOTES := 56

var elapsed := 0.0
var tick_clock := 0.0
var density := 1.0
var rank := 0
var spawn_pos := Vector2.ZERO
var drift := Vector2.LEFT
var emit_carry := 0.0
var motes: Array[Dictionary] = []

var disk_rect: ColorRect
var disk_material: ShaderMaterial

func configure(at: Vector2, toward: Vector2, particle_density: float, upgrade_rank: int) -> void:
    spawn_pos = at
    global_position = at
    density = clampf(particle_density, 0.0, 3.0)
    rank = clampi(upgrade_rank, 0, 3)
    drift = (toward - at).normalized()
    if drift.length_squared() < 0.01:
        drift = Vector2.LEFT

func _ready() -> void:
    # The shader is drawn behind this Node2D's _draw() particles.
    # Without show_behind_parent the opaque black center would obscure the motes.
    disk_rect = ColorRect.new()
    disk_rect.color = Color.WHITE
    disk_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    disk_rect.show_behind_parent = true
    add_child(disk_rect)

    disk_material = ShaderMaterial.new()
    disk_material.shader = BLACK_HOLE_SHADER
    disk_rect.material = disk_material
    _update_visual()

func _radius() -> float:
    return BASE_RADIUS * (1.0 + float(PREVIEW_GROWTH[rank]) * minf(elapsed, LIFETIME - COLLAPSE_TIME))

func _birth_fraction() -> float:
    var t := clampf(elapsed / BIRTH_TIME, 0.0, 1.0)
    return 1.0 - pow(1.0 - t, 3.0)

func _end_fraction() -> float:
    var t := clampf((LIFETIME - elapsed) / COLLAPSE_TIME, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

func _appearance() -> float:
    return _birth_fraction() * _end_fraction()

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= LIFETIME:
        vanished.emit(global_position)
        queue_free()
        return

    # The underlying spell is a moving black hole, not a fixed garden patch.
    global_position = spawn_pos + drift * elapsed * 26.0

    tick_clock += delta
    while tick_clock >= TICK_INTERVAL:
        tick_clock -= TICK_INTERVAL
        if elapsed < LIFETIME - COLLAPSE_TIME:
            pulsed.emit(global_position, _radius())

    _advance_motes(delta)
    if elapsed < LIFETIME - COLLAPSE_TIME:
        _emit_motes(delta)

    _update_visual()
    queue_redraw()

func _update_visual() -> void:
    if disk_rect == null or disk_material == null:
        return

    var diameter := _radius() * 2.9
    disk_rect.position = -Vector2.ONE * diameter * 0.5
    disk_rect.size = Vector2.ONE * diameter

    # Actual shader noise moves over time; the quad itself does not rotate.
    var scale_factor := maxf(0.02, _appearance())
    var pulse := pow(1.0 - clampf(tick_clock / TICK_INTERVAL, 0.0, 1.0), 4.0)
    disk_material.set_shader_parameter("u_time", elapsed)
    disk_material.set_shader_parameter("u_opacity", minf(1.0, _appearance() * 2.0))
    disk_material.set_shader_parameter("u_scale", scale_factor)
    disk_material.set_shader_parameter("u_tick_flash", pulse)

func _emit_motes(delta: float) -> void:
    emit_carry = minf(3.0, emit_carry + delta * 15.0 * density)
    while emit_carry >= 1.0 and motes.size() < MAX_MOTES:
        emit_carry -= 1.0
        var theta := randf_range(0.0, TAU)
        var distance := _radius() * randf_range(0.97, 1.26)
        var duration := randf_range(0.75, 1.55)
        motes.append({
            "pos": global_position + Vector2.RIGHT.rotated(theta) * distance,
            "life": duration,
            "total": duration,
            "size": randf_range(1.5, 4.0),
            "kind": randi_range(0, 1),
            "speed": randf_range(84.0, 132.0),
            "spin": randf_range(0.60, 1.05)
        })

func _advance_motes(delta: float) -> void:
    for i in range(motes.size() - 1, -1, -1):
        var mote: Dictionary = motes[i]
        var world_pos: Vector2 = mote["pos"]
        var toward_center := global_position - world_pos
        var distance := toward_center.length()

        mote["life"] = float(mote["life"]) - delta
        if float(mote["life"]) <= 0.0 or distance <= _radius() * 0.42:
            motes.remove_at(i)
            continue

        var inward := toward_center / maxf(distance, 0.001)
        var tangent := inward.orthogonal()
        var speed := float(mote["speed"])
        var acceleration := 1.0 + clampf(1.0 - distance / (_radius() * 1.35), 0.0, 0.7)
        mote["pos"] = world_pos + (inward * speed * acceleration + tangent * speed * float(mote["spin"]) * 0.62) * delta

func _draw() -> void:
    var opacity := _appearance()
    if opacity < 0.001:
        return
    for mote in motes:
        var fraction := clampf(float(mote["life"]) / float(mote["total"]), 0.0, 1.0)
        var at := to_local(Vector2(mote["pos"]))
        var size := float(mote["size"]) * (0.45 + 0.55 * fraction)
        var alpha := opacity * minf(1.0, fraction * 2.4)
        match int(mote["kind"]):
            0:
                draw_circle(at, size * 0.75, Color(0.83, 0.93, 0.70, alpha * 0.75))
            1:
                var inward := (-at).normalized()
                draw_line(
                    at - inward * size * 1.8,
                    at + inward * size * 0.55,
                    Color(0.42, 0.85, 0.90, alpha * 0.82),
                    maxf(1.0, size * 0.42),
                    true
                )
