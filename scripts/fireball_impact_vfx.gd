extends Node2D
## Original fire-fragment burst for the Fireflies-inspired projectile.
## Independent expanding particles, not a stretched explosion PNG or ring shader.
const FRAGMENT_TEXTURE = preload("res://scripts/fireflies_flame_fragment.gd")
const DURATION := 0.83

var radius := 50.0
var density := 1.0
var elapsed := 0.0
var fragments: Array[Dictionary] = []
var images: Array[Texture2D] = []
var rng := RandomNumberGenerator.new()

func configure(burst_radius: float, particle_multiplier: float) -> void:
    radius = clampf(burst_radius, 16.0, 180.0)
    density = clampf(particle_multiplier, 0.0, 3.0)

func _ready() -> void:
    rng.randomize()
    images = [
        FRAGMENT_TEXTURE.get_flame(0),
        FRAGMENT_TEXTURE.get_flame(1),
        FRAGMENT_TEXTURE.get_flame(2)
    ]
    var count := clampi(roundi(18.0 + 26.0 * density), 18, 94)
    for i in range(count):
        var angle := (float(i) + rng.randf_range(-0.35, 0.35)) / float(count) * TAU
        var direction := Vector2.RIGHT.rotated(angle)
        fragments.append({
            "p": direction * rng.randf_range(0.0, 6.0),
            "v": direction * (radius / DURATION) * rng.randf_range(0.65, 1.65),
            "life": rng.randf_range(0.35, 0.78),
            "age": -rng.randf_range(0.0, 0.12),
            "width": rng.randf_range(6.0, 15.0),
            "rot": rng.randf_range(-PI, PI),
            "spin": rng.randf_range(-3.0, 3.0),
            "variant": rng.randi_range(0, 2)
        })

func _process(delta: float) -> void:
    var dt := minf(delta, 0.06)
    elapsed += dt
    for i in range(fragments.size()):
        var f: Dictionary = fragments[i]
        f["age"] = float(f["age"]) + dt
        if float(f["age"]) > 0.0:
            f["p"] = Vector2(f["p"]) + Vector2(f["v"]) * dt
            f["v"] = Vector2(f["v"]) * maxf(0.0, 1.0 - dt * 1.9)
            f["rot"] = float(f["rot"]) + float(f["spin"]) * dt
        fragments[i] = f
    queue_redraw()
    if elapsed >= DURATION:
        queue_free()

func _draw() -> void:
    var flash := 1.0 - smoothstep(0.0, 0.17, elapsed)
    draw_circle(Vector2.ZERO, radius * (0.15 + elapsed * 0.60),
        Color(1.0, 0.50, 0.10, flash * 0.19))
    draw_circle(Vector2.ZERO, radius * (0.08 + elapsed * 0.25),
        Color(1.0, 0.97, 0.72, flash * 0.87))
    for f in fragments:
        if float(f["age"]) < 0.0:
            continue
        var t := float(f["age"]) / float(f["life"])
        if t >= 1.0:
            continue
        var col := Color("fff3a6").lerp(Color("ff9824"),
            smoothstep(0.0, 0.55, t))
        col = col.lerp(Color("ce2c20"), smoothstep(0.40, 1.0, t))
        col.a = pow(1.0 - t, 0.68) * 0.89
        var w := float(f["width"]) * (1.0 + t * 0.45) * (1.0 - 0.65 * t * t)
        draw_set_transform(Vector2(f["p"]), float(f["rot"]), Vector2.ONE)
        var texture: Texture2D = images[int(f["variant"])]
        var glow := w * 1.50
        draw_texture_rect(texture, Rect2(Vector2(-glow, -glow), Vector2.ONE * glow * 2.0),
            false, Color(1.0, 0.32, 0.02, col.a * 0.12))
        draw_texture_rect(texture, Rect2(Vector2(-w, -w), Vector2.ONE * w * 2.0), false, col)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
