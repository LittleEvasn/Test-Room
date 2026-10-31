extends RefCounted
## Procedurally generated ORIGINAL 12-frame (4x3) fire flipbook.
## Built once in memory; never loads or copies Magicraft textures.
const FRAME_WIDTH := 80
const FRAME_HEIGHT := 88
const COLUMNS := 4
const FRAMES := 12
const LOBE_CENTERS := [-0.175, -0.02, 0.19]
const LOBE_WIDTHS := [0.19, 0.245, 0.21]
const LOBE_HEIGHTS := [0.68, 0.98, 0.78]

static var _cached: ImageTexture

static func get_atlas() -> Texture2D:
    if _cached != null:
        return _cached
    var image := Image.create_empty(FRAME_WIDTH * COLUMNS, FRAME_HEIGHT * 3, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var noise := FastNoiseLite.new()
    noise.seed = 52731
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.09
    noise.fractal_type = FastNoiseLite.FRACTAL_FBM
    noise.fractal_octaves = 3
    for frame in range(FRAMES):
        var frame_phase := TAU * float(frame) / float(FRAMES)
        for y in range(FRAME_HEIGHT):
            var v := (float(y) + 0.5) / float(FRAME_HEIGHT)
            var h := (0.92 - v) / 0.77
            if h < 0.0 or h > 1.13:
                continue
            for x in range(FRAME_WIDTH):
                var u := (float(x) + 0.5) / float(FRAME_WIDTH)
                var xx := u - 0.5
                var jitter := sin(h * 7.1 + frame_phase * 1.5) * 0.016 * h * h
                var f := -3.0
                # Three overlapping tongues share the same BASE, so the result
                # is a connected sheet of fire, not independent round blobs.
                for lobe in range(3):
                    var center: float = float(LOBE_CENTERS[lobe])
                    var width: float = float(LOBE_WIDTHS[lobe])
                    var height: float = float(LOBE_HEIGHTS[lobe])
                    var z := h / height
                    if z > 1.11:
                        continue
                    var sway := sin(frame_phase + z * 3.0 + float(lobe) * 2.1) * 0.053 * z * z
                    var half_width := width * pow(maxf(0.0, 1.0 - z), 0.68) + 0.003
                    f = maxf(f, (half_width - absf(xx - center - jitter - sway)) / width)
                var motion_x := sin(frame_phase) * 5.0
                var motion_y := cos(frame_phase) * 5.0
                var n := noise.get_noise_2d(float(x) * 0.82 + motion_x, float(y) * 0.86 + motion_y)
                var fine := noise.get_noise_2d(float(x) * 2.2 - motion_y * 0.7, float(y) * 2.0 + motion_x)
                f += (n * 0.105 + fine * 0.055) * clampf(h * 1.35, 0.18, 1.0)
                var alpha := smoothstep(-0.12, 0.12, f)
                if alpha < 0.004:
                    continue
                var gold := smoothstep(0.04, 0.34, f)
                var hot := smoothstep(0.27, 0.66, f) * smoothstep(0.20, 0.80, v)
                var color := Color(1.0, 0.39, 0.045).lerp(Color(1.0, 0.86, 0.27), gold)
                color = color.lerp(Color(1.0, 0.98, 0.78), hot * 0.88)
                color.a = alpha
                var dst_x := (frame % COLUMNS) * FRAME_WIDTH + x
                var dst_y: int = (frame / COLUMNS) * FRAME_HEIGHT + y
                image.set_pixel(dst_x, dst_y, color)
    _cached = ImageTexture.create_from_image(image)
    return _cached
