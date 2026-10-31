extends RefCounted
## Original procedural flame-fragment textures. No external copyrighted textures.
## Each texture is a soft, asymmetric fire shard, not a round particle.
static var cached: Array[Texture2D] = []

static func get_flame(variant: int) -> Texture2D:
    if cached.is_empty():
        cached.append(_generate(0))
        cached.append(_generate(1))
        cached.append(_generate(2))
    return cached[clampi(variant, 0, cached.size() - 1)]

static func _generate(variant: int) -> Texture2D:
    const SIZE := 64
    var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
    for y in range(SIZE):
        for x in range(SIZE):
            var p := Vector2((float(x) + 0.5) / float(SIZE) * 2.0 - 1.0,
                (float(y) + 0.5) / float(SIZE) * 2.0 - 1.0)
            var angle := atan2(p.y, p.x)
            var radial := Vector2(p.x * (0.91 if variant == 2 else 1.05),
                p.y * (1.28 if variant == 1 else 0.93)).length()
            var wavy := 0.68
            wavy += 0.115 * sin(angle * 3.0 + float(variant) * 1.9)
            wavy += 0.095 * sin(angle * 5.0 - float(variant) * 1.3)
            wavy += 0.048 * sin(angle * 8.0 + float(variant) * 2.6)
            var edge := 1.0 - smoothstep(wavy - 0.14, wavy + 0.055, radial)
            var alpha := clampf(edge, 0.0, 1.0)
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
    return ImageTexture.create_from_image(img)
