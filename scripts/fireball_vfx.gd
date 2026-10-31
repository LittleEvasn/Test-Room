extends Node2D
## Fireflies-inspired kinetic fireball — ORIGINAL Godot recreation.
## Source study: NestGameStudio/Fireflies Player.prefab (Unity TrailRenderer)
## + lookAlongVelocity.cs + scaleByVelocity.cs.
## Particles keep their world positions; the source can orbit, turn or bounce.
## No original Fireflies game art/code is bundled or copied.
signal impacted(at: Vector2)
signal finished()

const FRAGMENT_TEXTURE = preload("res://scripts/fireflies_flame_fragment.gd")
const ORBIT_MOTION = preload("res://scripts/aux_orbit_motion.gd")
const RADII := [50.0, 65.0, 80.0, 100.0]
const PREVIEW_SPEED := 590.0
const MAX_STRAIGHT_LIFE := 2.45
const ORBIT_LIFE := 4.95

var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var density := 1.0
var rank := 0
var motion := 0 # 0 straight, 1 orbit, 2 curving
var aux_orbit := false
var aux_orbit_phase := 0.0
var age := 0.0
var dying := false
var linger := 0.0
var distance := 0.0
var last_world := Vector2.ZERO
var current_velocity := Vector2.RIGHT
var particles: Array[Dictionary] = []
var flame_images: Array[Texture2D] = []
var rng := RandomNumberGenerator.new()
var pulse_seed := 0.0

func configure(origin: Vector2, target: Vector2, multiplier: float, cast_rank: int, travel_mode: int = 0) -> void:
    from_point = origin
    to_point = target
    density = clampf(multiplier, 0.0, 3.0)
    rank = clampi(cast_rank, 0, 3)
    motion = clampi(travel_mode, 0, 2)

func _ready() -> void:
    rng.randomize()
    pulse_seed = rng.randf_range(0.0, TAU)
    flame_images = [
        FRAGMENT_TEXTURE.get_flame(0),
        FRAGMENT_TEXTURE.get_flame(1),
        FRAGMENT_TEXTURE.get_flame(2)
    ]
    distance = from_point.distance_to(to_point)
    if motion == 1:
        position = ORBIT_MOTION.orbit_point(from_point, rank, PREVIEW_SPEED, 0.0, aux_orbit_phase) if aux_orbit else from_point + Vector2(134.0 + float(rank) * 10.0, 0.0)
    else:
        position = from_point
    last_world = global_position
    current_velocity = (to_point - from_point).normalized() * PREVIEW_SPEED

func begin_fall_vfx(start: Vector2) -> void:
    # Preserve world-space trail positions: don't connect the caster to the
    # first airborne frame with a giant, visually false flame streak.
    last_world = start
    current_velocity = Vector2.RIGHT * PREVIEW_SPEED

func _process(delta: float) -> void:
    var dt := minf(delta, 0.06)
    age += dt
    _update_fragments(dt)
    if dying:
        linger -= dt
        queue_redraw()
        if linger <= 0.0:
            queue_free()
        return

    if has_meta("aux_falling"):
        # Lifetime, flame swirl and world-space fragments remain LIVE.
        # Only the normal flight path / early arrival test is suppressed.
        var now_falling: Vector2 = global_position
        current_velocity = Vector2(get_meta("aux_fall_direction", Vector2.RIGHT)) * PREVIEW_SPEED
        if now_falling.distance_to(last_world) > 0.5:
            _emit_along(last_world, now_falling)
        last_world = now_falling
        queue_redraw()
        return

    var previous := global_position
    match motion:
        1:
            var theta := age * 2.65
            var radius := 134.0 + float(rank) * 10.0
            position = ORBIT_MOTION.orbit_point(from_point, rank, PREVIEW_SPEED, age, aux_orbit_phase) if aux_orbit else from_point + Vector2(cos(theta), sin(theta)) * radius
        2:
            var direction := (to_point - from_point).normalized()
            if direction.length_squared() < 0.001:
                direction = Vector2.RIGHT
            var progress := minf(age * PREVIEW_SPEED / maxf(distance, 1.0), 1.0)
            var sideways := sin(progress * TAU * 2.2) * sin(progress * PI) * 77.0
            position = from_point.lerp(to_point, progress) + direction.orthogonal() * sideways
        _:
            var direction := (to_point - from_point).normalized()
            if direction.length_squared() < 0.001:
                direction = Vector2.RIGHT
            position = from_point + direction * minf(age * PREVIEW_SPEED, distance)

    var now := global_position
    current_velocity = (now - previous) / maxf(dt, 0.0001)
    if current_velocity.length_squared() > 0.01:
        _emit_along(previous, now)
    last_world = now
    queue_redraw()
    if (motion == 1 and age >= ORBIT_LIFE) or (motion != 1 and
            (now.distance_to(to_point) < 1.0 or age >= MAX_STRAIGHT_LIFE)):
        _impact()

func _emit_along(a: Vector2, b: Vector2) -> void:
    if density <= 0.0:
        return
    var step_distance := a.distance_to(b)
    var amount := clampi(roundi(step_distance * 0.245 * density), 0, 24)
    if amount <= 0:
        return
    var heading := current_velocity.normalized()
    var tangent := heading.orthogonal()
    for k in range(amount):
        var fraction := (float(k) + rng.randf_range(0.2, 0.8)) / float(amount)
        var location := a.lerp(b, fraction)
        var hot := rng.randf() < 0.63
        var life := rng.randf_range(0.23, 0.41) if hot else rng.randf_range(0.38, 0.60)
        var vel := heading * rng.randf_range(-58.0, 42.0)
        vel += tangent * rng.randf_range(-64.0, 64.0)
        vel += current_velocity * rng.randf_range(0.015, 0.075)
        var width := rng.randf_range(9.0, 17.0) if hot else rng.randf_range(4.2, 11.0)
        particles.append({
            "p": location + tangent * rng.randf_range(-5.0, 5.0),
            "v": vel,
            "age": rng.randf_range(0.0, 0.045),
            "life": life,
            "width": width * (0.84 + float(rank) * 0.065),
            "rot": rng.randf_range(-PI, PI),
            "turn": rng.randf_range(-2.5, 2.5),
            "variation": rng.randi_range(0, 2),
            "seed": rng.randf_range(0.0, TAU),
            "hot": hot
        })
    # Bounded draw work; old fragments disappear first.
    if particles.size() > 280:
        particles = particles.slice(particles.size() - 280)

func _update_fragments(dt: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var frag: Dictionary = particles[i]
        frag["age"] = float(frag["age"]) + dt
        if float(frag["age"]) >= float(frag["life"]):
            particles.remove_at(i)
            continue
        var t: float = float(frag["age"]) / float(frag["life"])
        var swirl := Vector2(
            sin(float(frag["seed"]) + age * 14.0),
            cos(float(frag["seed"]) * 0.6 + age * 11.0)
        ) * (24.0 * t)
        frag["p"] = Vector2(frag["p"]) + (Vector2(frag["v"]) + swirl + Vector2(0.0, -11.0)) * dt
        frag["v"] = Vector2(frag["v"]) * maxf(0.0, 1.0 - dt * 2.7)
        frag["rot"] = float(frag["rot"]) + float(frag["turn"]) * dt
        particles[i] = frag

func _fragment_color(life_fraction: float, is_hot: bool) -> Color:
    var t := clampf(life_fraction, 0.0, 1.0)
    var color: Color
    if t < 0.30:
        color = Color("fff9ac").lerp(Color("ffdb45"), t / 0.30)
    elif t < 0.65:
        color = Color("ffdb45").lerp(Color("ff8a20"), (t - 0.30) / 0.35)
    else:
        color = Color("ff8a20").lerp(Color("d72a20"), (t - 0.65) / 0.35)
    if is_hot and t < 0.16:
        color = Color("fffef0").lerp(color, t / 0.16)
    color.a = pow(1.0 - t, 0.56) * minf(1.0, (1.0 - t) * 5.0) * 0.96
    return color

func _draw() -> void:
    # Particle positions are in world space. The emitter node moves freely.
    # Unlike a rotated PNG, previously spawned fragments NEVER rotate with it.
    for frag in particles:
        var t: float = float(frag["age"]) / float(frag["life"])
        var color := _fragment_color(t, bool(frag["hot"]))
        var width := float(frag["width"]) * (1.0 + 0.22 * sin(t * PI))
        width *= (1.0 - 0.55 * t * t)
        var texture: Texture2D = flame_images[int(frag["variation"])]
        draw_set_transform(to_local(Vector2(frag["p"])), float(frag["rot"]), Vector2.ONE)
        var glow_extent := width * 1.55
        draw_texture_rect(texture, Rect2(Vector2(-glow_extent, -glow_extent),
            Vector2.ONE * glow_extent * 2.0), false,
            Color(1.0, 0.25, 0.025, color.a * 0.13))
        draw_texture_rect(texture, Rect2(Vector2(-width, -width),
            Vector2.ONE * width * 2.0), false, color)
        if bool(frag["hot"]) and t < 0.30:
            draw_circle(Vector2(-width * 0.08, -width * 0.10), width * 0.24,
                Color(1.0, 1.0, 0.82, (0.30 - t) * 1.55))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if not dying:
        var pulse := 1.0 + sin(age * 24.0 + pulse_seed) * 0.07
        var r := (7.7 + float(rank) * 0.6) * pulse
        draw_circle(Vector2.ZERO, r * 2.45, Color(1.0, 0.25, 0.018, 0.065))
        draw_circle(Vector2.ZERO, r * 1.62, Color(1.0, 0.56, 0.09, 0.20))
        draw_circle(Vector2.ZERO, r * 1.20, Color(1.0, 0.78, 0.25, 0.92))
        draw_circle(Vector2.ZERO, r * 0.81, Color(1.0, 0.97, 0.77, 1.0))
        draw_circle(Vector2.ZERO, r * 0.44, Color(1.0, 1.0, 0.995, 1.0))

func _impact() -> void:
    if dying:
        return
    dying = true
    linger = 0.67
    impacted.emit(global_position)
    finished.emit()
