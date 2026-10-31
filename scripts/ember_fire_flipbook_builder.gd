extends RefCounted
## v5: Original procedural 12-frame fire flipbook, 4x3, generated once.
## No triangular tongues. Every frame has a time-dependent irregular crest.
const FRAME_WIDTH := 80
const FRAME_HEIGHT := 88
const COLUMNS := 4
const FRAMES := 12
static var _cached: ImageTexture

static func get_atlas() -> Texture2D:
    if _cached != null:
        return _cached
    var image := Image.create_empty(
        FRAME_WIDTH * COLUMNS, FRAME_HEIGHT * 3, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var noise := FastNoiseLite.new()
    noise.seed = 67351
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.028
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 3

    for frame in range(FRAMES):
        # Periodic offsets avoid a discontinuity at frame 12 -> frame 0.
        var angle := TAU * float(frame) / float(FRAMES)
        var tx := cos(angle) * 11.0
        var ty := sin(angle) * 11.0
        var contour := PackedFloat32Array()
        contour.resize(FRAME_WIDTH)
        for x in range(FRAME_WIDTH):
            var u := (float(x) + 0.5) / float(FRAME_WIDTH)
            var big := (noise.get_noise_2d(float(x) * 0.80 + tx, 17.0 + ty) + 1.0) * 0.5
            var small := (noise.get_noise_2d(float(x) * 1.80 - ty, 39.0 + tx) + 1.0) * 0.5
            contour[x] = 0.32 + 0.32 * big + 0.16 * small + 0.080 * sin(u * 18.0 + angle + 0.5) + 0.046 * sin(u * 39.0 - angle * 1.5)
        for y in range(FRAME_HEIGHT):
            var v := (float(y) + 0.5) / float(FRAME_HEIGHT)
            var h := (0.92 - v) / 0.80
            var altitude := clampf(h, 0.0, 1.15)
            var ground_fade := 1.0 - smoothstep(0.86, 0.985, v)
            var root := smoothstep(-0.045, 0.026, h)
            if ground_fade * root < 0.005:
                continue
            for x in range(FRAME_WIDTH):
                var u := (float(x) + 0.5) / float(FRAME_WIDTH)
                var big := (noise.get_noise_2d(float(x) * 0.82 + tx, float(y) * 0.94 + ty) + 1.0) * 0.5
                var small := (noise.get_noise_2d(float(x) * 1.72 - ty, float(y) * 1.64 + tx) + 1.0) * 0.5
                var warped_x := u + ((big - 0.5) * 0.11 + (small - 0.5) * 0.050) * pow(altitude, 1.30)
                var side_distance := absf(warped_x - 0.5) / maxf(0.23, 0.43 - minf(altitude, 1.0) * 0.10)
                var side_mask := 1.0 - smoothstep(0.66, 1.07, side_distance)
                var field := contour[x] - h + (big - 0.5) * 0.19 + (small - 0.5) * 0.16 * altitude
                var alpha := smoothstep(-0.10, 0.047, field) * side_mask * ground_fade * root
                if alpha < 0.004:
                    continue
                var gold := smoothstep(0.055, 0.25, field)
                var hot := smoothstep(0.27, 0.53, field) * smoothstep(0.25, 0.79, v)
                var color := Color(1.0, 0.34, 0.043).lerp(Color(1.0, 0.79, 0.16), gold)
                color = color.lerp(Color(1.0, 0.97, 0.76), hot * 0.81)
                color.a = alpha
                var px: int = (frame % COLUMNS) * FRAME_WIDTH + x
                var py: int = (frame / COLUMNS) * FRAME_HEIGHT + y
                image.set_pixel(px, py, color)
    _cached = ImageTexture.create_from_image(image)
    return _cached
