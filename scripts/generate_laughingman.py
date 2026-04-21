#!/usr/bin/env python3
"""
Process pre-split Laughing Man layers into 144x144 sprites.
  - Outer: text ring (rotates) — white-filled circle, color-matched blue
  - Inner: face + brim (static, on top)
"""

import os
import numpy as np
from PIL import Image, ImageDraw

SIZE = 144
TRIM_PX = 2

OUTER_SRC = os.path.expanduser(
    "~/Downloads/png-transparent-laughing-man-logo-ghost-in-the-shell-anime-sample-text-blue-text-logo-thumbnail.png"
)
INNER_SRC = os.path.expanduser("~/Downloads/warai_layer_f.png")

OUT_DIR = os.path.expanduser("~/.claude/crest")


def crop_square_center(img):
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def get_dominant_blue(img):
    arr = np.array(img)
    mask = (arr[:,:,3] > 100) & (arr[:,:,0] < 120) & (arr[:,:,2] > 50)
    if mask.any():
        return (
            int(np.median(arr[mask, 0])),
            int(np.median(arr[mask, 1])),
            int(np.median(arr[mask, 2])),
        )
    return (42, 86, 138)


def recolor_to_target(img, target_rgb):
    """Replace blue pixels directly with target color, using alpha for blending."""
    arr = np.array(img, dtype=np.float32)
    r, g, b, a = arr[:,:,0], arr[:,:,1], arr[:,:,2], arr[:,:,3]
    # How "blue" is each pixel (0=white, 1=full ink)
    is_colored = (a > 10)
    lum = (0.299 * r + 0.587 * g + 0.114 * b)
    # ink_strength: 0 for white(255), 1 for darkest blue — boost contrast
    ink = np.zeros_like(lum)
    ink[is_colored] = np.clip((1.0 - lum[is_colored] / 255.0) * 1.8, 0, 1)
    is_ink = (ink > 0.1) & is_colored
    if not is_ink.any():
        return img
    tr, tg, tb = target_rgb
    # Blend: ink_strength * target_color + (1 - ink_strength) * white
    arr[is_ink, 0] = np.clip(ink[is_ink] * tr + (1 - ink[is_ink]) * 255, 0, 255)
    arr[is_ink, 1] = np.clip(ink[is_ink] * tg + (1 - ink[is_ink]) * 255, 0, 255)
    arr[is_ink, 2] = np.clip(ink[is_ink] * tb + (1 - ink[is_ink]) * 255, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def process_outer(src_path, target_blue):
    img = Image.open(src_path).convert("RGBA")
    img = crop_square_center(img)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)

    cx, cy = SIZE // 2, SIZE // 2
    r = SIZE // 2 - TRIM_PX

    # Step 1: white-ify non-blue using ORIGINAL source colors (before recolor)
    arr = np.array(img)
    for y in range(SIZE):
        for x in range(SIZE):
            dist = ((x - cx)**2 + (y - cy)**2) ** 0.5
            if dist <= r:
                ri, gi, bi = int(arr[y, x, 0]), int(arr[y, x, 1]), int(arr[y, x, 2])
                if not (bi > ri + 10 and bi > 50):
                    arr[y, x] = [255, 255, 255, 255]
                else:
                    arr[y, x, 3] = 255
            else:
                arr[y, x] = [0, 0, 0, 0]
    img = Image.fromarray(arr)

    # Step 2: recolor remaining blue to match inner
    img = recolor_to_target(img, target_blue)
    return img


def process_inner(src_path):
    img = Image.open(src_path).convert("RGBA")
    img = crop_square_center(img)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    inner = process_inner(INNER_SRC)
    target_blue = get_dominant_blue(inner)
    print(f"Target blue: {target_blue}")

    inner.save(f"{OUT_DIR}/laughingman_inner.png")
    print(f"Inner: {OUT_DIR}/laughingman_inner.png")

    outer = process_outer(OUTER_SRC, target_blue)
    outer.save(f"{OUT_DIR}/laughingman_outer.png")
    print(f"Outer: {OUT_DIR}/laughingman_outer.png")

    # Verify color
    oarr = np.array(outer)
    o_mask = (oarr[:,:,3] > 100) & (oarr[:,:,0] < 100) & (oarr[:,:,2] > 50)
    if o_mask.any():
        print(f"Outer blue result: R={np.median(oarr[o_mask,0]):.0f} G={np.median(oarr[o_mask,1]):.0f} B={np.median(oarr[o_mask,2]):.0f}")

    # Debug composites
    debug_dir = f"{OUT_DIR}/debug"
    os.makedirs(debug_dir, exist_ok=True)
    for angle in [0, 45, 90, 180]:
        rotated = outer.rotate(angle, resample=Image.BICUBIC, expand=False)
        comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        comp = Image.alpha_composite(comp, rotated)
        comp = Image.alpha_composite(comp, inner)
        comp.save(f"{debug_dir}/lm_comp_{angle:03d}.png")
    print("Composites saved")


if __name__ == "__main__":
    main()
