#!/usr/bin/env python3
"""
Noblesse Emblem - Layered rotation with precise circular masking.
Outer text ring rotates within a perfect circle. Sword+scales fixed.
"""
import subprocess, sys, os, math, time
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SRC = "/Users/nassy/.claude/image-cache/95743819-5921-4fee-a7b4-2b7152b28f92/3.png"

SIZE = 160


def load_and_prepare(src_path, size=SIZE, colors=32):
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    # Find the emblem circle: detect non-background region
    # The emblem is dark on gold background
    # Crop generously first
    margin = min(w, h) // 12
    img = img.crop((margin, margin, w - margin, h - margin))
    img = img.resize((size, size), Image.LANCZOS)

    rgb = img.convert("RGB")
    rgb = ImageEnhance.Contrast(rgb).enhance(1.3)
    rgb = rgb.filter(ImageFilter.SHARPEN)

    if colors > 0:
        quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        rgb = quantized.convert("RGB")

    return rgb.convert("RGBA")


def find_emblem_center(img):
    """Find the center and radius of the dark circular emblem"""
    w, h = img.size
    pixels = img.load()

    # The emblem is darker than the gold background
    # Scan to find bounding box of dark pixels
    bg_r, bg_g, bg_b = pixels[2, 2][:3]
    threshold = 60

    min_x, max_x, min_y, max_y = w, 0, h, 0
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y][:3]
            diff = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
            if diff > threshold:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

    cx = (min_x + max_x) / 2
    cy = (min_y + max_y) / 2
    radius = min(max_x - min_x, max_y - min_y) / 2

    return cx, cy, radius


def circle_mask(size, cx, cy, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=255)
    return mask


def ring_mask(size, cx, cy, r_outer, r_inner):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], fill=255)
    draw.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], fill=0)
    return mask


def apply_mask(img, mask):
    result = Image.new("RGBA", img.size, (0, 0, 0, 0))
    result.paste(img, mask=mask)
    return result


def show_sixel(img, width=None):
    tmp = "/tmp/_emblem_frame.png"
    img.save(tmp)
    cmd = ["img2sixel"]
    if width:
        cmd += ["-w", str(width)]
    cmd.append(tmp)
    result = subprocess.run(cmd, capture_output=True)
    sys.stdout.buffer.write(result.stdout)
    sys.stdout.flush()


def clear_lines(n):
    sys.stdout.write(f"\033[{n}A")
    for _ in range(n):
        sys.stdout.write("\033[2K\033[1B")
    sys.stdout.write(f"\033[{n}A")
    sys.stdout.flush()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "static"

    print("\n  Loading...", end="", flush=True)
    img = load_and_prepare(SRC, size=SIZE, colors=32)
    cx, cy, radius = find_emblem_center(img)
    print(f" center=({cx:.0f},{cy:.0f}) r={radius:.0f}")

    # Inner/outer boundary: the inner dark ring is at about 70% of emblem radius
    inner_ratio = 0.70
    r_inner = radius * inner_ratio
    r_outer = radius

    # Create layers with precise circular masks
    outer_ring = apply_mask(img, ring_mask(SIZE, cx, cy, r_outer, r_inner))
    inner_content = apply_mask(img, circle_mask(SIZE, cx, cy, r_inner))

    # For rotation: outer ring rotates around emblem center
    # We need to rotate around (cx, cy), not image center
    # PIL rotates around image center, so offset if needed

    def rotate_outer(angle):
        """Rotate outer ring around emblem center"""
        # Translate so emblem center is at image center, rotate, translate back
        img_cx, img_cy = SIZE / 2, SIZE / 2
        dx, dy = cx - img_cx, cy - img_cy

        if abs(dx) < 2 and abs(dy) < 2:
            # Close enough to center, just rotate
            rotated = outer_ring.rotate(angle, resample=Image.BICUBIC, expand=False)
        else:
            # Shift, rotate, shift back
            from PIL import ImageTransform
            shifted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            shifted.paste(outer_ring, (-int(dx), -int(dy)), outer_ring)
            rotated = shifted.rotate(angle, resample=Image.BICUBIC, expand=False)
            result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            result.paste(rotated, (int(dx), int(dy)), rotated)
            rotated = result

        # Re-apply ring mask to clean up rotation artifacts
        rotated = apply_mask(rotated, ring_mask(SIZE, cx, cy, r_outer, r_inner))
        return rotated

    def compose(angle=0):
        frame = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        rotated = rotate_outer(angle)
        frame.paste(rotated, (0, 0), rotated)
        frame.paste(inner_content, (0, 0), inner_content)
        return frame

    if mode == "static":
        print("\n⚔️  Noblesse Emblem (static)\n")
        frame = compose(0)
        frame.save("/tmp/emblem_final.png")
        show_sixel(frame, width=SIZE)
        print()

    elif mode == "rotate":
        duration = int(sys.argv[2]) if len(sys.argv) > 2 else 12
        num_frames = 36

        print("\n  Generating frames...", end="", flush=True)
        frames = []
        for i in range(num_frames):
            angle = (360 / num_frames) * i
            frames.append(compose(angle))
        print(" done.\n")

        show_sixel(frames[0], width=SIZE)
        sixel_lines = SIZE // 12 + 2

        start = time.time()
        f = 0
        while time.time() - start < duration:
            clear_lines(sixel_lines)
            show_sixel(frames[f % num_frames], width=SIZE)
            f += 1
            time.sleep(0.3)
        print()

    elif mode == "compare":
        print("\n【A】160×160 / 32色 / 円マスク")
        show_sixel(compose(0), width=SIZE)
        print()

        print("【A-rotated】外周15°回転")
        show_sixel(compose(15), width=SIZE)
        print()

        print("【A-rotated】外周45°回転")
        show_sixel(compose(45), width=SIZE)
        print()

    elif mode == "frames":
        os.makedirs("/tmp/noblesse_frames", exist_ok=True)
        for i in range(24):
            angle = (360 / 24) * i
            frame = compose(angle)
            path = f"/tmp/noblesse_frames/frame_{i:02d}.png"
            frame.save(path)
            print(f"  {path}")
        print(f"\n  24 frames saved.\n")


if __name__ == "__main__":
    main()
