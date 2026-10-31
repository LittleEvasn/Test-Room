extends Node2D
## v5: connected turbulent fire sheets instead of conical mountains.
## No copied artwork; light smoke/sparks are accents, NEVER the fire body.
const GROUND_SHADER = preload("res://shaders/ember_footprint.gdshader")
const MASK_SHADER = preload("res://shaders/ember_fire_mask.gdshader")
const FLIP_SHADER = preload("res://shaders/ember_fire_flipbook.gdshader")
const ATLAS_BUILDER = preload("res://scripts/ember_fire_flipbook_builder.gd")
const BASE_LIFETIME := 2.2

static var _noise_texture: NoiseTexture2D
static var _spark_texture: GradientTexture2D
static var _smoke_texture: GradientTexture2D
static var _spark_ramp: GradientTexture1D
static var _smoke_ramp: GradientTexture1D

var size_factor: float = 1.0
var particle_density: float = 1.0
var lifetime: float = BASE_LIFETIME
var age: float = 0.0
var style: int = 2 # 0=flow mask, 1=flipbook, 2=hybrid
var phase: float = 0.0
var materials: Array[ShaderMaterial] = []
var emitters: Array[GPUParticles2D] = []
var rng := RandomNumberGenerator.new()

func configure(preview_scale: float, density: float, duration: float = BASE_LIFETIME,
        preview_style: int = 2) -> void:
    size_factor = clampf(preview_scale, 0.65, 1.55)
    particle_density = clampf(density, 0.0, 3.0)
    lifetime = maxf(duration, 1.2)
    style = clampi(preview_style, 0, 2)

func _ready() -> void:
    rng.randomize()
    phase = rng.randf_range(0.0, 30.0)
    _ensure_assets()
    scale = Vector2.ONE * size_factor
    add_to_group("vfx_ember_patch")
    _make_ground()
    if style == 0 or style == 2:
        _make_mask()
    if style == 1 or style == 2:
        _make_flipbook()
    if particle_density > 0.0:
        _make_accents()

static func _soft_dot(size_px: int) -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1, 1, 1, 0.8))
    gradient.set_color(1, Color(1, 1, 1, 0))
    gradient.add_point(0.36, Color(1, 1, 1, 0.33))
    var texture := GradientTexture2D.new()
    texture.width = size_px
    texture.height = size_px
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(0.5, 0.0)
    texture.gradient = gradient
    return texture

static func _make_ramp(colors: Array[Color]) -> GradientTexture1D:
    var grad := Gradient.new()
    grad.set_color(0, colors[0])
    grad.set_color(1, colors[2])
    grad.add_point(0.42, colors[1])
    var texture := GradientTexture1D.new()
    texture.gradient = grad
    return texture

static func _ensure_assets() -> void:
    if _noise_texture != null:
        return
    var noise := FastNoiseLite.new()
    noise.seed = 52731
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 3
    noise.frequency = 0.042
    _noise_texture = NoiseTexture2D.new()
    _noise_texture.width = 192
    _noise_texture.height = 192
    _noise_texture.seamless = true
    _noise_texture.noise = noise
    _spark_texture = _soft_dot(12)
    _smoke_texture = _soft_dot(40)
    _spark_ramp = _make_ramp([
        Color(1.0, 0.89, 0.37, 0.0),
        Color(1.0, 0.71, 0.18, 0.75),
        Color(0.95, 0.39, 0.05, 0.0)
    ])
    _smoke_ramp = _make_ramp([
        Color(0.42, 0.37, 0.35, 0.0),
        Color(0.42, 0.36, 0.32, 0.10),
        Color(0.37, 0.36, 0.37, 0.0)
    ])

func _quad(rect_position: Vector2, rect_size: Vector2, shader: Shader) -> ShaderMaterial:
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("phase", phase)
    mat.set_shader_parameter("life", 0.0)
    var quad := ColorRect.new()
    quad.color = Color.WHITE
    quad.position = rect_position
    quad.size = rect_size
    quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    quad.material = mat
    add_child(quad)
    materials.append(mat)
    return mat

func _make_ground() -> void:
    var mat := ShaderMaterial.new()
    mat.shader = GROUND_SHADER
    mat.set_shader_parameter("life", 0.0)
    mat.set_shader_parameter("variation", phase)
    var heat := ColorRect.new()
    heat.color = Color.WHITE
    heat.position = Vector2(-45.0, -18.0)
    heat.size = Vector2(90.0, 35.0)
    heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heat.material = mat
    add_child(heat)
    materials.append(mat)

func _make_mask() -> void:
    var mat := _quad(Vector2(-51.0, -68.0), Vector2(102.0, 72.0), MASK_SHADER)
    mat.set_shader_parameter("noise_tex", _noise_texture)
    mat.set_shader_parameter("brightness", 1.0 if style == 0 else 0.94)

func _make_flipbook() -> void:
    var mat := _quad(Vector2(-49.0, -66.0), Vector2(98.0, 70.0), FLIP_SHADER)
    mat.set_shader_parameter("fire_atlas", ATLAS_BUILDER.get_atlas())
    mat.set_shader_parameter("strength", 1.0 if style == 1 else 0.32)

func _accent(texture: Texture2D, amount: int, duration: float,
        speed: float, spread: float, color_ramp: GradientTexture1D,
        offset: Vector2, box_half: Vector3) -> void:
    var p := GPUParticles2D.new()
    p.amount = maxi(1, amount)
    p.lifetime = duration
    p.one_shot = false
    p.local_coords = false
    p.texture = texture
    p.position = offset
    p.visibility_rect = Rect2(-110.0, -110.0, 220.0, 180.0)
    var move := ParticleProcessMaterial.new()
    move.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    move.emission_box_extents = box_half
    move.direction = Vector3(0.0, -1.0, 0.0)
    move.spread = spread
    move.gravity = Vector3(0.0, -1.5, 0.0)
    move.initial_velocity_min = speed * 0.6
    move.initial_velocity_max = speed
    move.scale_min = 0.22
    move.scale_max = 0.54
    move.color_ramp = color_ramp
    p.process_material = move
    add_child(p)
    emitters.append(p)

func _make_accents() -> void:
    # Deliberately sparse. A puff or spark must not resemble the fire body.
    _accent(_smoke_texture, mini(3, maxi(1, roundi(1.2 * particle_density))),
        0.85, 17.0, 42.0, _smoke_ramp,
        Vector2(1, -22), Vector3(13, 2, 0))
    _accent(_spark_texture, mini(5, maxi(1, roundi(2.0 * particle_density))),
        0.55, 30.0, 40.0, _spark_ramp,
        Vector2(0, -11), Vector3(17, 2, 0))

func _process(delta: float) -> void:
    age += delta
    var fraction := clampf(age / lifetime, 0.0, 1.0)
    for mat in materials:
        mat.set_shader_parameter("life", fraction)
    for p in emitters:
        if p.emitting and age >= lifetime - p.lifetime:
            p.emitting = false
    if age >= lifetime:
        queue_free()
