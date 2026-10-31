extends Node2D
## 잔불 발자국 v2: living procedural GPU flame blobs + ground heat + sparse smoke/embers.
## No authored PNG, no combat logic, no hitboxes and no borrowed Magicraft assets.

const GROUND_SHADER = preload("res://shaders/ember_footprint.gdshader")
const FLAME_SHADER = preload("res://shaders/ember_flame_particle.gdshader")
const BASE_LIFETIME := 2.2 # Main game's +1 preview. Other ranks are set by the trail.

static var _flame_quad: GradientTexture2D
static var _smoke_quad: GradientTexture2D
static var _spark_quad: GradientTexture2D
static var _flame_scale: CurveTexture
static var _smoke_scale: CurveTexture
static var _spark_scale: CurveTexture
static var _smoke_ramp: GradientTexture1D
static var _spark_ramp: GradientTexture1D

var size_factor: float = 1.0
var particle_density: float = 1.0
var lifetime: float = BASE_LIFETIME
var age: float = 0.0
var ground_material: ShaderMaterial
var emitters: Array[GPUParticles2D] = []
var rng := RandomNumberGenerator.new()

func configure(preview_scale: float, density: float, duration: float = BASE_LIFETIME) -> void:
    size_factor = clampf(preview_scale, 0.65, 1.55)
    particle_density = clampf(density, 0.0, 3.0)
    lifetime = maxf(duration, 1.2)

func _ready() -> void:
    rng.randomize()
    _ensure_shared_resources()
    scale = Vector2.ONE * size_factor
    add_to_group("vfx_ember_patch")
    _make_ground_heat()
    _make_fire(false)
    _make_fire(true)
    if particle_density > 0.0:
        _make_smoke()
        _make_embers()

static func _plain_quad(size_px: int) -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.set_color(0, Color.WHITE)
    gradient.set_color(1, Color.WHITE)
    var tex := GradientTexture2D.new()
    tex.width = size_px
    tex.height = size_px
    tex.gradient = gradient
    return tex

static func _soft_quad(size_px: int) -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
    gradient.add_point(0.35, Color(1.0, 1.0, 1.0, 0.45))
    gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    var tex := GradientTexture2D.new()
    tex.width = size_px
    tex.height = size_px
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(0.5, 0.0)
    tex.gradient = gradient
    return tex

static func _scale_texture(points: Array[Vector2]) -> CurveTexture:
    var curve := Curve.new()
    for point in points:
        curve.add_point(point)
    var tex := CurveTexture.new()
    tex.curve = curve
    return tex

static func _color_ramp(stops: Array[Dictionary]) -> GradientTexture1D:
    var gradient := Gradient.new()
    gradient.set_color(0, stops[0]["color"])
    gradient.set_color(1, stops[stops.size() - 1]["color"])
    for i in range(1, stops.size() - 1):
        gradient.add_point(float(stops[i]["time"]), stops[i]["color"])
    var tex := GradientTexture1D.new()
    tex.gradient = gradient
    return tex

static func _ensure_shared_resources() -> void:
    if _flame_quad != null:
        return
    _flame_quad = _plain_quad(48)
    _smoke_quad = _soft_quad(46)
    _spark_quad = _soft_quad(12)
    _flame_scale = _scale_texture([
        Vector2(0.0, 0.20), Vector2(0.16, 0.89),
        Vector2(0.39, 1.0), Vector2(0.72, 0.78), Vector2(1.0, 0.03)
    ])
    _smoke_scale = _scale_texture([
        Vector2(0.0, 0.30), Vector2(0.22, 0.72),
        Vector2(0.72, 1.0), Vector2(1.0, 0.25)
    ])
    _spark_scale = _scale_texture([
        Vector2(0.0, 0.40), Vector2(0.22, 0.85),
        Vector2(0.70, 0.65), Vector2(1.0, 0.05)
    ])
    _smoke_ramp = _color_ramp([
        {"time": 0.0, "color": Color(0.38, 0.31, 0.33, 0.0)},
        {"time": 0.24, "color": Color(0.48, 0.36, 0.34, 0.11)},
        {"time": 0.70, "color": Color(0.38, 0.35, 0.37, 0.07)},
        {"time": 1.0, "color": Color(0.38, 0.35, 0.37, 0.0)}
    ])
    _spark_ramp = _color_ramp([
        {"time": 0.0, "color": Color(1.0, 0.88, 0.43, 0.0)},
        {"time": 0.15, "color": Color(1.0, 0.82, 0.32, 0.90)},
        {"time": 0.55, "color": Color(1.0, 0.48, 0.075, 0.60)},
        {"time": 1.0, "color": Color(0.73, 0.17, 0.027, 0.0)}
    ])

func _make_ground_heat() -> void:
    ground_material = ShaderMaterial.new()
    ground_material.shader = GROUND_SHADER
    ground_material.set_shader_parameter("life", 0.0)
    ground_material.set_shader_parameter("variation", rng.randf_range(0.0, 60.0))
    var heat := ColorRect.new()
    heat.color = Color.WHITE
    heat.position = Vector2(-47.0, -20.0)
    heat.size = Vector2(94.0, 37.0)
    heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heat.material = ground_material
    add_child(heat)

func _new_emitter(texture: Texture2D, count: int, particle_life: float,
        emission_extent: Vector3, upwards_min: float, upwards_max: float,
        spread_degrees: float, scale_low: float, scale_high: float,
        scale_texture: Texture2D) -> GPUParticles2D:
    var p := GPUParticles2D.new()
    p.amount = maxi(count, 1)
    p.lifetime = particle_life
    p.randomness = 0.42
    p.explosiveness = 0.0
    p.one_shot = false
    p.local_coords = false
    p.texture = texture
    p.visibility_rect = Rect2(-120.0, -115.0, 240.0, 180.0)
    var movement := ParticleProcessMaterial.new()
    movement.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    movement.emission_box_extents = emission_extent
    movement.direction = Vector3(0.0, -1.0, 0.0)
    movement.spread = spread_degrees
    movement.gravity = Vector3(0.0, -2.0, 0.0)
    movement.initial_velocity_min = upwards_min
    movement.initial_velocity_max = upwards_max
    movement.scale_min = scale_low
    movement.scale_max = scale_high
    movement.scale_curve = scale_texture
    p.process_material = movement
    p.emitting = true
    return p

func _make_fire(is_core: bool) -> void:
    var count := maxi(3, roundi((7.0 if is_core else 13.0) * (0.42 + particle_density * 0.58)))
    var p := _new_emitter(_flame_quad, count, 0.40 if is_core else 0.63,
        Vector3(12.0, 2.0, 0.0) if is_core else Vector3(22.0, 3.5, 0.0),
        7.0 if is_core else 12.0, 19.0 if is_core else 28.0,
        28.0 if is_core else 41.0,
        0.27 if is_core else 0.41, 0.45 if is_core else 0.74, _flame_scale)
    p.position = Vector2(0.0, -5.0)
    var mat := ShaderMaterial.new()
    mat.shader = FLAME_SHADER
    mat.set_shader_parameter("variation", rng.randf_range(0.0, 80.0))
    mat.set_shader_parameter("core_layer", 1.0 if is_core else 0.0)
    p.material = mat
    add_child(p)
    emitters.append(p)

func _make_smoke() -> void:
    var count := clampi(roundi(2.5 * particle_density), 1, 7)
    var p := _new_emitter(_smoke_quad, count, 0.98, Vector3(15.0, 2.0, 0.0),
        7.0, 16.0, 48.0, 0.37, 0.70, _smoke_scale)
    p.position = Vector2(0.0, -16.0)
    var move := p.process_material as ParticleProcessMaterial
    move.color_ramp = _smoke_ramp
    # Very restrained smoke is behind flame body. No gray wall.
    move.gravity = Vector3(0.0, -3.0, 0.0)
    add_child(p)
    move_child(p, 1)
    emitters.append(p)

func _make_embers() -> void:
    var count := clampi(roundi(2.0 * particle_density), 1, 6)
    var p := _new_emitter(_spark_quad, count, 0.60, Vector3(17.0, 2.0, 0.0),
        17.0, 37.0, 56.0, 0.29, 0.56, _spark_scale)
    p.position = Vector2(0.0, -9.0)
    var move := p.process_material as ParticleProcessMaterial
    move.color_ramp = _spark_ramp
    move.gravity = Vector3(0.0, -3.0, 0.0)
    add_child(p)
    emitters.append(p)

func _process(delta: float) -> void:
    age += delta
    var progress := clampf(age / lifetime, 0.0, 1.0)
    ground_material.set_shader_parameter("life", progress)
    for particle in emitters:
        # No abrupt clipping: stop each source one particle-lifetime before disposal.
        if particle.emitting and age >= lifetime - particle.lifetime:
            particle.emitting = false
    if age >= lifetime:
        queue_free()
