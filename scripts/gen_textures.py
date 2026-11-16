#!/usr/bin/env python3
"""Bake PBR textures used by the React city. Albedo is sRGB JPEG; normals and roughness are PNG."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parents[1] / "public" / "textures"
OUT.mkdir(parents=True, exist_ok=True)

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def value_noise(w, h, cells, seed):
    rng = np.random.default_rng(seed)
    gx = w // cells + 2
    gy = h // cells + 2
    grid = rng.random((gy, gx)).astype(np.float32)
    ys = np.linspace(0, gy - 1.001, h)
    xs = np.linspace(0, gx - 1.001, w)
    x, y = np.meshgrid(xs, ys)
    x0 = np.floor(x).astype(np.int32)
    y0 = np.floor(y).astype(np.int32)
    tx = x - x0
    ty = y - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    v00 = grid[y0, x0]
    v10 = grid[y0, x0 + 1]
    v01 = grid[y0 + 1, x0]
    v11 = grid[y0 + 1, x0 + 1]
    return v00 * (1 - tx) * (1 - ty) + v10 * tx * (1 - ty) + v01 * (1 - tx) * ty + v11 * tx * ty


def fbm(w, h, seed, octaves=5, base=8):
    acc = np.zeros((h, w), np.float32)
    amp = 1.0
    total = 0.0
    cells = base
    for i in range(octaves):
        acc += value_noise(w, h, cells, seed + i * 17) * amp
        total += amp
        amp *= 0.5
        cells *= 2
    return acc / total


def normal_from_height(height, strength=2.5):
    h = height.astype(np.float32)
    dx = np.zeros_like(h)
    dy = np.zeros_like(h)
    dx[:, 1:-1] = h[:, 2:] - h[:, :-2]
    dy[1:-1, :] = h[2:, :] - h[:-2, :]
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    rgb = np.stack(((nx / length) * 0.5 + 0.5, (ny / length) * 0.5 + 0.5, (nz / length) * 0.5 + 0.5), axis=-1)
    return (np.clip(rgb, 0, 1) * 255).astype(np.uint8)


def save_rgb(name, arr, quality=86):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    img.save(OUT / name, quality=quality, optimize=True)


def save_gray(name, arr):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "L")
    img.save(OUT / name, optimize=True)


def asphalt():
    h, w = 1024, 1024
    n = fbm(w, h, 3, 6, 6)
    grit = fbm(w, h, 9, 4, 40)
    cracks = np.zeros((h, w), np.float32)
    rng = np.random.default_rng(4)
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(18):
        x0, y0 = rng.integers(0, w), rng.integers(0, h)
        ang = rng.random() * np.pi
        length = rng.integers(180, 700)
        width = rng.uniform(0.6, 1.6)
        for t in range(length):
            x = int(x0 + np.cos(ang) * t + np.sin(t * 0.04) * 6)
            y = int(y0 + np.sin(ang) * t + np.cos(t * 0.03) * 5)
            if 0 <= x < w and 0 <= y < h:
                cracks[max(0, y - 1) : y + 2, max(0, x - 1) : x + 2] = 1
            ang += rng.normal(0, 0.01)
    stone = 0.55 + 0.45 * grit
    base = np.array([28, 29, 34], np.float32)
    col = base * (0.75 + 0.35 * n)[..., None] * (0.85 + 0.25 * stone)[..., None]
    col[cracks > 0.5] *= 0.35
    # tar patches
    patches = fbm(w, h, 12, 3, 3)
    wet = patches > 0.62
    col[wet] *= 0.72
    save_rgb("asphalt.jpg", col)
    height = n * 0.55 + grit * 0.25 - cracks * 0.85
    save_rgb("asphalt_normal.png", normal_from_height(height, 3.2))
    rough = np.full((h, w), 210, np.float32)
    rough -= wet.astype(np.float32) * 120
    rough -= grit * 20
    save_gray("asphalt_rough.png", rough)


def facade():
    w, h = 512, 1024
    img = Image.new("RGB", (w, h), (18, 16, 24))
    draw = ImageDraw.Draw(img)
    em = Image.new("RGB", (w, h), (0, 0, 0))
    ed = ImageDraw.Draw(em)
    colors = [(255, 186, 92), (255, 214, 140), (90, 170, 255), (255, 70, 140), (40, 30, 50)]
    rng = np.random.default_rng(8)
    for floor in range(14):
        y = 30 + floor * 70
        draw.rectangle((0, y + 52, w, y + 60), fill=(40, 36, 48))
        for col in range(4):
            x = 28 + col * 120
            lit = colors[int(rng.integers(0, len(colors)))]
            if rng.random() < 0.18:
                lit = (12, 10, 16)
            draw.rectangle((x, y, x + 78, y + 46), fill=lit)
            draw.rectangle((x, y, x + 78, y + 46), outline=(70, 60, 80))
            # mullion
            draw.line((x + 39, y, x + 39, y + 46), fill=(50, 44, 58))
            if lit[0] > 30:
                ed.rectangle((x + 4, y + 4, x + 74, y + 42), fill=lit)
    # cornice
    draw.rectangle((0, 0, w, 18), fill=(70, 62, 78))
    img.save(OUT / "facade.jpg", quality=90)
    em.save(OUT / "facade_emit.jpg", quality=90)


def brick():
    w, h = 512, 512
    img = Image.new("RGB", (w, h), (92, 48, 42))
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(2)
    mortar = (150, 140, 136)
    bh, bw = 36, 84
    for row in range(h // bh + 1):
        off = 0 if row % 2 == 0 else bw // 2
        y = row * bh
        draw.rectangle((0, y, w, y + 4), fill=mortar)
        x = -off
        while x < w:
            shade = int(rng.integers(-18, 18))
            color = (120 + shade, 62 + shade // 2, 52 + shade // 3)
            draw.rectangle((x + 3, y + 4, x + bw - 3, y + bh - 2), fill=color)
            x += bw
    arr = np.asarray(img).astype(np.float32)
    grit = fbm(w, h, 5, 4, 16)
    arr *= (0.88 + 0.2 * grit)[..., None]
    save_rgb("brick.jpg", arr)
    height = grit * 0.3
    height[::bh, :] += 0.4
    save_rgb("brick_normal.png", normal_from_height(height, 2.2))


def concrete():
    w = h = 512
    n = fbm(w, h, 21, 5, 8)
    pits = fbm(w, h, 22, 2, 48)
    col = np.array([168, 166, 170], np.float32) * (0.82 + 0.28 * n)[..., None]
    col[pits > 0.72] *= 0.8
    save_rgb("concrete.jpg", col)
    save_rgb("concrete_normal.png", normal_from_height(n * 0.5 - (pits > 0.72) * 0.4, 1.6))


def graffiti():
    brick()
    base = Image.open(OUT / "brick.jpg").convert("RGB").resize((1024, 1024))
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    rng = np.random.default_rng(15)
    for _ in range(30):
        x, y = int(rng.integers(0, 900)), int(rng.integers(0, 900))
        r = int(rng.integers(20, 90))
        color = tuple(int(c) for c in rng.choice([
            [255, 40, 140, 90],
            [40, 140, 255, 80],
            [180, 60, 255, 70],
            [255, 220, 80, 50],
        ]))
        draw.ellipse((x, y, x + r, y + int(r * 0.7)), fill=color)
    font = ImageFont.truetype(FONT, 180)
    font2 = ImageFont.truetype(FONT, 120)
    draw.text((40, 80), "REBEL", font=font, fill=(255, 45, 150, 230))
    draw.text((80, 360), "ANI", font=font, fill=(70, 170, 255, 230))
    draw.text((60, 640), "HOOD", font=font2, fill=(200, 80, 255, 220))
    overlay = overlay.filter(ImageFilter.GaussianBlur(0.6))
    out = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    out.save(OUT / "hood.jpg", quality=90)


def skin():
    w = h = 1024
    pores = fbm(w, h, 30, 5, 48)
    blotch = fbm(w, h, 31, 3, 4)
    fine = fbm(w, h, 32, 2, 80)
    base = np.array([232, 186, 162], np.float32)
    col = base * (0.9 + 0.12 * blotch)[..., None]
    col += (pores - 0.5)[..., None] * 10
    # subtle warmer variation, not makeup painted on a cylinder
    col[..., 0] += fine * 6
    save_rgb("skin.jpg", col, quality=90)
    height = pores * 0.35 + fine * 0.15
    save_rgb("skin_normal.png", normal_from_height(height, 4.5))
    rough = 150 + pores * 40 + fine * 20
    save_gray("skin_rough.png", rough)


def lace():
    w = h = 1024
    img = Image.new("RGB", (w, h), (8, 6, 10))
    draw = ImageDraw.Draw(img)
    # woven thread grid with floral knots
    for y in range(0, h, 28):
        draw.line((0, y, w, y), fill=(70, 54, 66), width=2)
    for x in range(0, w, 28):
        draw.line((x, 0, x, h), fill=(70, 54, 66), width=2)
    for y in range(14, h, 28):
        for x in range(14, w, 28):
            draw.ellipse((x - 7, y - 7, x + 7, y + 7), outline=(150, 120, 138), width=2)
            draw.arc((x - 12, y - 4, x - 2, y + 6), 20, 200, fill=(120, 90, 110), width=1)
    arr = np.asarray(img).astype(np.float32)
    grain = fbm(w, h, 40, 3, 32)
    arr *= (0.85 + 0.3 * grain)[..., None]
    save_rgb("lace.jpg", arr, quality=90)
    height = grain * 0.25
    # threads bump
    height[::28, :] += 0.35
    height[:, ::28] += 0.35
    save_rgb("lace_normal.png", normal_from_height(height, 3.0))


def fabric():
    w = h = 512
    n = fbm(w, h, 50, 5, 20)
    threads = np.zeros((h, w), np.float32)
    threads[::4, :] += 0.15
    threads[:, ::4] += 0.1
    col = np.array([210, 210, 214], np.float32) * (0.82 + 0.28 * n)[..., None]
    save_rgb("fabric.jpg", col)
    save_rgb("fabric_normal.png", normal_from_height(n * 0.4 + threads, 2.4))


def hair():
    w, h = 512, 1024
    streak = fbm(w, h, 60, 4, 12)
    fine = np.zeros((h, w), np.float32)
    rng = np.random.default_rng(7)
    ys = np.linspace(0, 1, h)
    for _ in range(400):
        x = int(rng.integers(0, w))
        wobble = rng.normal(0, 0.4, h)
        xs = np.clip((x + np.cumsum(wobble)).astype(int), 0, w - 1)
        fine[np.arange(h), xs] = 1
    col = np.array([214, 176, 92], np.float32) * (0.75 + 0.4 * streak)[..., None]
    col += fine[..., None] * 18
    # darker roots toward v=1 (top of UV often the root depending on loft; keep gentle)
    col *= (0.82 + 0.18 * ys)[:, None, None]
    save_rgb("hair.jpg", col, quality=90)
    height = streak * 0.2 + fine * 0.55
    save_rgb("hair_normal.png", normal_from_height(height, 3.5))


def iris():
    w = h = 256
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = w / 2, h / 2
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (w * 0.5)
    ang = np.arctan2(yy - cy, xx - cx)
    fibers = 0.5 + 0.5 * np.sin(ang * 18 + r * 30)
    col = np.zeros((h, w, 3), np.float32)
    blue = np.array([40, 140, 255], np.float32)
    deep = np.array([8, 30, 90], np.float32)
    mix = np.clip(1 - r, 0, 1)[..., None]
    col = deep * (1 - mix) + blue * mix
    col *= (0.75 + 0.35 * fibers)[..., None]
    col[r < 0.28] = (8, 8, 12)
    col[r > 0.98] = (240, 240, 245)
    save_rgb("iris.jpg", col, quality=92)


if __name__ == "__main__":
    asphalt()
    facade()
    concrete()
    graffiti()
    skin()
    lace()
    fabric()
    hair()
    iris()
    print("textures in", OUT)
