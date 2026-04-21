#!/usr/bin/env python3
"""
Split Laughing Man into two clean layers:
  - Outer: complete text ring (brim area inpainted from opposite side)
  - Inner: face + cap + brim ink only (no white fill, transparent bg)
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 144
CENTER = SIZE // 2
OUTER_R = 70   # outer edge of text ring
INNER_R = 44   # inner edge of text ring (face boundary)
BRIM_TOP = 50
BRIM_BOT = 78
FEATHER_PX = 1

SRC = os.path.expanduser("~/.claude/crest/laughingman.png")
DEBUG_DIR = os.path.expanduser("~/.claude/crest/debug")


def circle_mask(size, radius, center=None):
    if center is None:
        center = (size // 2, size // 2)
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = center
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=255)
    return mask


def extract_ink(img_arr, threshold=180):
    """Extract dark ink pixels. Returns alpha mask where ink=255, white bg=0."""
    r, g, b, a = img_arr[:,:,0], img_arr[:,:,1], img_arr[:,:,2], img_arr[:,:,3]
    luminance = 0.299 * r.astype(float) + 0.587 * g.astype(float) + 0.114 * b.astype(float)
    # Ink pixels: dark AND visible
    ink_alpha = np.zeros_like(a, dtype=np.float32)
    visible = a > 10
    # Smooth transition: darker = more opaque
    ink_alpha[visible] = np.clip((threshold - luminance[visible]) / threshold * 1.5, 0, 1)
    return (ink_alpha * 255).astype(np.uint8)


def inpaint_ring_brim(img, outer_r, inner_r, brim_top, brim_bot):
    """
    Reconstruct the text ring in the brim zone by sampling from
    the opposite side (180° rotation) of the ring.
    """
    arr = np.array(img).copy()
    h, w = arr.shape[:2]
    cx, cy = w // 2, h // 2

    # Create ring mask (annular region between inner_r and outer_r)
    ring = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            dist = math.sqrt((x - cx)**2 + (y - cy)**2)
            if inner_r - 2 <= dist <= outer_r + 2:
                ring[y, x] = True

    # Brim zone: rows within brim range AND within ring
    brim_zone = np.zeros((h, w), dtype=bool)
    brim_zone[brim_top:brim_bot, :] = True
    fill_zone = ring & brim_zone

    # Fill from 180° opposite: pixel at (x,y) gets value from (2*cx - x, 2*cy - y)
    for y in range(h):
        for x in range(w):
            if fill_zone[y, x]:
                opp_x = 2 * cx - x
                opp_y = 2 * cy - y
                if 0 <= opp_x < w and 0 <= opp_y < h:
                    arr[y, x] = arr[opp_y, opp_x]

    return Image.fromarray(arr)


def main():
    os.makedirs(DEBUG_DIR, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)

    # === OUTER LAYER: complete text ring ===
    # Step 1: inpaint brim zone in the ring
    inpainted = inpaint_ring_brim(img, OUTER_R, INNER_R, BRIM_TOP, BRIM_BOT)

    # Step 2: extract ring only (between outer and inner circles)
    outer_mask = circle_mask(SIZE, OUTER_R)
    inner_mask_circle = circle_mask(SIZE, INNER_R)
    outer_arr = np.array(outer_mask, dtype=np.float32)
    inner_arr = np.array(inner_mask_circle, dtype=np.float32)
    ring_mask_arr = np.clip(outer_arr - inner_arr, 0, 255).astype(np.uint8)
    ring_mask = Image.fromarray(ring_mask_arr, mode="L")
    ring_soft = ring_mask.filter(ImageFilter.GaussianBlur(FEATHER_PX))

    outer_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    outer_layer.paste(inpainted, mask=ring_soft)

    outer_layer.save(f"{DEBUG_DIR}/outer_ring_lm.png")
    print(f"Outer ring: {DEBUG_DIR}/outer_ring_lm.png")

    # === INNER LAYER: face + brim ink only ===
    # Step 1: extract ink pixels (dark parts only, no white background)
    ink_mask = extract_ink(arr)

    # Step 2: limit to inner region (circle + brim rect)
    inner_region = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(inner_region)
    # Circle for face
    draw.ellipse((CENTER - INNER_R, CENTER - INNER_R,
                  CENTER + INNER_R, CENTER + INNER_R), fill=255)
    # Brim rectangle
    draw.rectangle((0, BRIM_TOP, SIZE, BRIM_BOT), fill=255)

    # Combine: ink AND inner region
    ink_arr = np.array(ink_mask, dtype=np.float32) / 255.0
    region_arr = np.array(inner_region, dtype=np.float32) / 255.0
    combined_alpha = (ink_arr * region_arr * 255).astype(np.uint8)

    inner_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    inner_rgba = arr.copy()
    inner_rgba[:, :, 3] = combined_alpha
    inner_layer = Image.fromarray(inner_rgba)

    inner_layer.save(f"{DEBUG_DIR}/inner_face_lm.png")
    print(f"Inner face: {DEBUG_DIR}/inner_face_lm.png")

    # === COMPOSITE TEST: rotate outer 45° + inner on top ===
    for angle in [0, 30, 90, 180]:
        rotated = outer_layer.rotate(angle, resample=Image.BICUBIC, expand=False)
        comp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        comp = Image.alpha_composite(comp, rotated)
        comp = Image.alpha_composite(comp, inner_layer)
        comp.save(f"{DEBUG_DIR}/composite_lm_{angle:03d}.png")
        print(f"Composite {angle}°: {DEBUG_DIR}/composite_lm_{angle:03d}.png")


if __name__ == "__main__":
    main()
