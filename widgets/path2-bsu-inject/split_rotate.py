#!/usr/bin/env python3
"""
Split-rotate: rotate only the outer ring of the crest,
keeping the inner scales/sword static.

The crest is split into:
  - Outer ring: text band + decorative border (rotates)
  - Inner circle: scales + sword (stays fixed)

A circular mask separates the two layers. The inner radius
is tunable to match the crest design.

Usage:
  # Preview the split (saves debug images)
  python3 split_rotate.py preview

  # Generate rotation frames
  python3 split_rotate.py generate [frame_count] [deg_per_frame]

  # Single rotated frame to stdout (for piping)
  python3 split_rotate.py frame <angle_degrees>
"""

import io
import os
import sys
import base64

from PIL import Image, ImageDraw, ImageFilter

SPRITE_PNG = os.path.expanduser("~/.cache/claude-statusline/sprite-widget.png")
FRAMES_DIR = os.path.expanduser("~/.claude/crest/rotate-frames")

# Inner circle ratio: fraction of image radius that is "inner" (static)
# 0.68 covers the full balance/scales including dish edges
INNER_RATIO = 0.68

# Feather radius for mask edge blending (eliminates black dots at boundary)
FEATHER_PX = 1


def load_crest(path: str = SPRITE_PNG) -> Image.Image:
    return Image.open(path).convert("RGBA")


def make_circle_mask(size: int, radius: int, center: tuple[int, int] = None) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if center is None:
        center = (size // 2, size // 2)
    cx, cy = center
    draw.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=255,
    )
    return mask


def split_layers(img: Image.Image, inner_ratio: float = INNER_RATIO):
    """Split crest into outer ring and inner circle with feathered boundary."""
    w, h = img.size
    radius = min(w, h) // 2
    inner_r = int(radius * inner_ratio)
    center = (w // 2, h // 2)

    # Hard masks
    inner_mask_hard = make_circle_mask(max(w, h), inner_r, center).crop((0, 0, w, h))
    outer_mask_full = make_circle_mask(max(w, h), radius, center).crop((0, 0, w, h))

    # Feathered inner mask: blur the edge for smooth blending
    inner_mask_soft = inner_mask_hard.filter(ImageFilter.GaussianBlur(FEATHER_PX))

    # Inner layer: gold background + original pixels (no black bleed)
    gold_bg = Image.new("RGBA", (w, h), (200, 160, 80, 255))
    inner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inner.paste(gold_bg, mask=inner_mask_soft)
    inner_with_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inner_with_img.paste(img, mask=inner_mask_soft)
    inner = Image.alpha_composite(inner, inner_with_img)

    # Outer layer: invert the soft mask to get the ring
    # outer_alpha = outer_full_alpha * (1 - inner_soft_alpha)
    import numpy as np
    outer_full_arr = np.array(outer_mask_full, dtype=np.float32) / 255.0
    inner_soft_arr = np.array(inner_mask_soft, dtype=np.float32) / 255.0
    ring_arr = np.clip(outer_full_arr - inner_soft_arr, 0, 1)
    ring_mask = Image.fromarray((ring_arr * 255).astype(np.uint8), mode="L")

    outer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    outer.paste(img, mask=ring_mask)

    return outer, inner, inner_r, img


def compose_rotated(outer: Image.Image, inner: Image.Image,
                    angle: float, orig: Image.Image = None) -> Image.Image:
    """Rotate outer ring by angle degrees, composite with static inner."""
    w, h = outer.size
    rotated_outer = outer.rotate(angle, resample=Image.BICUBIC, expand=False)
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    result = Image.alpha_composite(result, rotated_outer)
    result = Image.alpha_composite(result, inner)
    return result


def frame_to_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def preview(path: str = SPRITE_PNG):
    """Save debug images showing the split."""
    img = load_crest(path)
    outer, inner, inner_r, orig = split_layers(img)

    out_dir = os.path.dirname(path) or "."
    debug_dir = os.path.expanduser("~/.claude/crest/debug")
    os.makedirs(debug_dir, exist_ok=True)

    outer.save(f"{debug_dir}/outer_ring.png")
    inner.save(f"{debug_dir}/inner_emblem.png")

    # Save a few sample rotations
    for angle in [0, 30, 90, 180]:
        comp = compose_rotated(outer, inner, angle, orig)
        comp.save(f"{debug_dir}/rotated_{angle:03d}.png")

    print(f"Debug images saved to {debug_dir}/")
    print(f"  outer_ring.png    — the rotating part")
    print(f"  inner_emblem.png  — the static part (scales + sword)")
    print(f"  rotated_*.png     — sample compositions")
    print(f"  inner_ratio={INNER_RATIO}, inner_radius={inner_r}px")
    print(f"\nAdjust INNER_RATIO in script if the split isn't right.")


def generate(frame_count: int = 360, deg_per_frame: float = 1.0,
             path: str = SPRITE_PNG):
    """Generate pre-rendered rotation frames."""
    img = load_crest(path)
    outer, inner, _, orig = split_layers(img)

    os.makedirs(FRAMES_DIR, exist_ok=True)

    print(f"Generating {frame_count} frames ({deg_per_frame}°/frame)")
    print(f"  Full rotation: {frame_count * deg_per_frame}° = {frame_count * deg_per_frame / 360:.1f} loops")
    print(f"  At 1Hz: {frame_count}s per loop")

    for i in range(frame_count):
        angle = i * deg_per_frame
        comp = compose_rotated(outer, inner, angle, orig)
        comp.save(f"{FRAMES_DIR}/{i:04d}.png")
        if (i + 1) % 60 == 0 or i == frame_count - 1:
            print(f"  {i+1}/{frame_count}")

    print(f"Done: {FRAMES_DIR}/")


def single_frame(angle: float, path: str = SPRITE_PNG) -> Image.Image:
    """Generate a single rotated frame."""
    img = load_crest(path)
    outer, inner, _, orig = split_layers(img)
    return compose_rotated(outer, inner, angle, orig)


# --- Cache for runtime use by bsu_experiment.py ---
_split_cache: dict[str, tuple] = {}


def get_rotated_b64(path: str, angle: float, inner_ratio: float = INNER_RATIO) -> str:
    """Cached split-rotate for use in inject loop."""
    if path not in _split_cache:
        img = load_crest(path)
        outer, inner, _, orig = split_layers(img, inner_ratio)
        _split_cache[path] = (outer, inner, orig)
    outer, inner, orig = _split_cache[path]
    comp = compose_rotated(outer, inner, angle, orig)
    return frame_to_b64(comp)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "preview"

    if cmd == "preview":
        preview()

    elif cmd == "generate":
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 360
        deg = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
        generate(count, deg)

    elif cmd == "frame":
        angle = float(sys.argv[2]) if len(sys.argv) > 2 else 0
        img = single_frame(angle)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        sys.stdout.buffer.write(buf.getvalue())

    else:
        print(f"Unknown command: {cmd}")
        print("Usage: split_rotate.py [preview|generate|frame <angle>]")
