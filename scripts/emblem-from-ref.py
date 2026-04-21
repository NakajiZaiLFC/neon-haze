#!/usr/bin/env python3
"""
Reference image → pixel art emblem via downscale + palette reduction.
The original image IS the art. We just shrink it to pixel-art resolution.
Text becomes unreadable patterns. Shapes are preserved faithfully.
"""
import subprocess, sys, os, math
from PIL import Image, ImageFilter, ImageEnhance

SRC = "/Users/nassy/.claude/image-cache/95743819-5921-4fee-a7b4-2b7152b28f92/3.png"


def process(src_path, size=160, colors=0, contrast=1.0, sharpen=False):
    """Downscale reference image to pixel art resolution"""
    img = Image.open(src_path).convert("RGBA")

    # Crop to circle region (remove gold margin)
    w, h = img.size
    cx, cy = w // 2, h // 2
    margin = min(w, h) // 12
    box = (margin, margin, w - margin, h - margin)
    img = img.crop(box)

    # Resize to target (LANCZOS for best downscale quality)
    img = img.resize((size, size), Image.LANCZOS)

    # Optional contrast boost
    if contrast != 1.0:
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(contrast)

    # Optional sharpen (makes edges crisper at small sizes)
    if sharpen:
        img = img.filter(ImageFilter.SHARPEN)

    # Optional palette reduction (gives pixel-art feel)
    if colors > 0:
        # Convert to P mode (palette) then back to RGBA
        rgb = img.convert("RGB")
        quantized = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        img = quantized.convert("RGBA")

    return img


def make_transparent_bg(img, threshold=30):
    """Make the gold background transparent"""
    pixels = img.load()
    w, h = img.size
    # Sample corner color as "background"
    bg_r, bg_g, bg_b = pixels[0, 0][:3]

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if abs(r - bg_r) < threshold and abs(g - bg_g) < threshold and abs(b - bg_b) < threshold:
                pixels[x, y] = (0, 0, 0, 0)

    return img


def show_sixel(img, width=None):
    tmp = "/tmp/_emblem_ref.png"
    img.save(tmp)
    cmd = ["img2sixel"]
    if width:
        cmd += ["-w", str(width)]
    cmd.append(tmp)
    result = subprocess.run(cmd, capture_output=True)
    sys.stdout.buffer.write(result.stdout)
    sys.stdout.flush()


def show_halfblock(img, indent=2):
    """Fallback: half-block rendering"""
    w, h = img.size
    pixels = img.load()
    prefix = " " * indent

    for y in range(0, h - (h % 2), 2):
        line = prefix
        for x in range(w):
            tr, tg, tb, ta = pixels[x, y]
            br, bg, bb, ba = pixels[x, y + 1]
            t_clear = ta < 128
            b_clear = ba < 128

            if t_clear and b_clear:
                line += " "
            elif t_clear:
                line += f"\033[38;2;{br};{bg};{bb}m▄\033[0m"
            elif b_clear:
                line += f"\033[38;2;{tr};{tg};{tb}m▀\033[0m"
            elif tr == br and tg == bg and tb == bb:
                line += f"\033[38;2;{tr};{tg};{tb}m█\033[0m"
            else:
                line += f"\033[38;2;{tr};{tg};{tb}m\033[48;2;{br};{bg};{bb}m▀\033[0m"
        print(line)


def main():
    if not os.path.exists(SRC):
        print(f"Reference image not found: {SRC}")
        sys.exit(1)

    print()
    print("=" * 50)
    print(" Reference Image → Pixel Art Emblem")
    print(" 元画像の形をそのまま活かす")
    print("=" * 50)

    # --- A: Sixel at different sizes ---
    for size in [80, 120, 160]:
        print(f"\n【Sixel {size}×{size}】")
        img = process(SRC, size=size, contrast=1.2, sharpen=True)
        img.save(f"/tmp/emblem_{size}.png")
        show_sixel(img, width=size)

    # --- B: With palette reduction ---
    for colors in [16, 32, 64]:
        print(f"\n【Sixel 160×160, {colors}色パレット】")
        img = process(SRC, size=160, colors=colors, contrast=1.3, sharpen=True)
        img.save(f"/tmp/emblem_160_{colors}c.png")
        show_sixel(img, width=160)

    # --- C: Half-block fallback ---
    print(f"\n【Half-block 40×40 (Sixel非対応向け)】")
    img = process(SRC, size=40, contrast=1.3, sharpen=True)
    show_halfblock(img)

    print()
    print("─" * 50)
    print(" ポイント:")
    print("  - 元画像をそのまま縮小 → 形が忠実")
    print("  - 文字は読めない模様になる（意図通り）")
    print("  - パレット制限でドット絵感が増す")
    print("  - 色数が少ないほどレトロ感")
    print("─" * 50)
    print()


if __name__ == "__main__":
    main()
