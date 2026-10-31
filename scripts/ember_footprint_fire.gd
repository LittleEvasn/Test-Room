extends Node2D
## One reusable ground-flame patch for an ember footprint. Visual only.
## Procedural shader + CPU embers; no PNG, collision, damage or status effects.

const FIRE_SHADER = preload("res://shaders/ember_footprint.gdshader")
const BASE_LIFETIME := 3.4

var size_factor: float = 1.0
var particle_density: float = 1.0
var lifetime: float = BASE_LIFETIME
var age: float = 0.0
var material_instance: ShaderMaterial
var sparks: CPUParticles2D
var rng := RandomNumberGenerator.new()

func configure(preview_scale: float, density: float, duration: float = BASE_LIFETIME) -> void:
    size_factor = clampf(preview_scale, 0.5, 1.7)
    particle_density = clampf(density, 0.0, 3.0)
    lifetime = maxf(duration, 0.5)

func _ready() -> void:
    rng.randomize()
    scale = Vector2.ONE * size_factor
    add_to_group("vfx_ember_patch")

    material_instance = ShaderMaterial.new()
    material_instance.shader = FIRE_SHADER
    material_instance.set_shader_parameter("variation", rng.randf_range(0.0, 60.0))
    material_instance.set_shader_parameter("life", 0.0)

    var flame := ColorRect.new()
    flame.color = Color.WHITE
    flame.position = Vector2(-64.0, -94.0)
    flame.size = Vector2(128.0, 112.0)
    flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flame.material = material_instance
    add_child(flame)

    _make_embers()

func _make_embers() -> void:
    sparks = CPUParticles2D.new()
    sparks.position = Vector2(0.0, -9.0)
    sparks.amount = clampi(roundi(7.0 * particle_density), 1, 21)
    sparks.lifetime = 0.75
    sparks.preprocess = 0.0
    sparks.explosiveness = 0.0
    sparks.randomness = 0.45
    sparks.direction = Vector2.UP
    sparks.spread = 32.0
    sparks.gravity = Vector2(0.0, -9.0)
    sparks.initial_velocity_min = 16.0
    sparks.initial_velocity_max = 34.0
    sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    sparks.emission_rect_extents = Vector2(20.0, 3.0)
    sparks.scale_amount_min = 0.12
    sparks.scale_amount_max = 0.23
    sparks.local_coords = false

    # Runtime-generated radial texture (not an external image).
    var texture_gradient := Gradient.new()
    texture_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
    texture_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var dot_texture := GradientTexture2D.new()
    dot_texture.width = 12
    dot_texture.height = 12
    dot_texture.fill = GradientTexture2D.FILL_RADIAL
    dot_texture.fill_from = Vector2(0.5, 0.5)
    dot_texture.fill_to = Vector2(0.5, 0.0)
    dot_texture.gradient = texture_gradient
    sparks.texture = dot_texture

    var color_gradient := Gradient.new()
    color_gradient.set_color(0, Color(1.0, 0.80, 0.28, 0.92))
    color_gradient.add_point(0.50, Color(1.0, 0.44, 0.065, 0.57))
    color_gradient.set_color(1, Color(0.75, 0.16, 0.015, 0.0))
    sparks.color_ramp = color_gradient
    sparks.emitting = particle_density > 0.0
    add_child(sparks)

func _process(delta: float) -> void:
    age += delta
    var progress := clampf(age / lifetime, 0.0, 1.0)
    material_instance.set_shader_parameter("life", progress)
    if progress > 0.77 and sparks.emitting:
        sparks.emitting = false
    if age >= lifetime:
        queue_free()
