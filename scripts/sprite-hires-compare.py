#!/usr/bin/env python3
"""
Compare: half-block 20x20 vs sixel 80x80 pixel art in similar terminal space.
Both are NATIVE pixel art (designed at target resolution), not downscaled.
"""
import math, subprocess, tempfile, os
from PIL import Image

def draw_noblesse(size):
    """Draw Noblesse emblem at arbitrary pixel resolution"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()

    GOLD   = (220, 170, 50, 255)
    DARK   = (50, 28, 15, 255)
    INNER  = (190, 148, 55, 255)
    SWORD  = (65, 35, 20, 255)
    BAND   = (140, 105, 35, 255)
    CHAIN  = (80, 45, 25, 255)
    PAN    = (45, 25, 12, 255)
    HILT   = (90, 55, 30, 255)

    cx, cy = size/2, size/2
    r = size/2

    for y in range(size):
        for x in range(size):
            dx, dy = x - cx + 0.5, y - cy + 0.5
            dist = math.sqrt(dx*dx + dy*dy)

            if dist > r:
                px[x, y] = (0, 0, 0, 0)  # transparent
            elif dist > r * 0.92:
                px[x, y] = DARK  # outer ring
            elif dist > r * 0.82:
                px[x, y] = BAND  # text band
            elif dist > r * 0.72:
                px[x, y] = DARK  # inner ring
            else:
                px[x, y] = INNER  # inner field

    # Sword blade (vertical center)
    sw = max(1, size // 20)  # sword width
    for y in range(int(size*0.18), int(size*0.85)):
        for x in range(int(cx) - sw, int(cx) + sw):
            if 0 <= x < size:
                px[x, y] = SWORD

    # Crossguard
    cg_y = int(size * 0.38)
    cg_w = int(size * 0.35)
    cg_h = max(1, size // 25)
    for y in range(cg_y, cg_y + cg_h):
        for x in range(int(cx) - cg_w, int(cx) + cg_w):
            if 0 <= x < size and 0 <= y < size:
                px[x, y] = HILT

    # Pommel
    pm_r = max(1, size // 15)
    pm_cy = int(size * 0.17)
    for y in range(pm_cy - pm_r, pm_cy + pm_r):
        for x in range(int(cx) - pm_r, int(cx) + pm_r):
            if 0 <= x < size and 0 <= y < size:
                if math.sqrt((x-cx)**2 + (y-pm_cy)**2) <= pm_r:
                    px[x, y] = HILT

    # Scale chains
    chain_len = int(size * 0.25)
    for side in [-1, 1]:
        anchor_x = int(cx + side * cg_w * 0.8)
        anchor_y = cg_y + cg_h

        # Chain lines
        for i in range(chain_len):
            lx = anchor_x - side * int(i * 0.3)
            ly = anchor_y + i
            if 0 <= lx < size and 0 <= ly < size:
                px[lx, ly] = CHAIN

        # Scale pan (triangle/arc at bottom)
        pan_y = anchor_y + chain_len
        pan_w = max(2, size // 8)
        pan_cx = anchor_x - side * int(chain_len * 0.3)
        for dy in range(max(1, size // 20)):
            for dx in range(-pan_w, pan_w + 1):
                px_x = pan_cx + dx
                px_y = pan_y + dy
                if 0 <= px_x < size and 0 <= px_y < size:
                    # Taper the pan
                    if abs(dx) <= pan_w - dy:
                        px[px_x, px_y] = PAN

    # Add some text-band detail (dots to suggest text)
    band_r_inner = r * 0.82
    band_r_outer = r * 0.92
    band_r_mid = (band_r_inner + band_r_outer) / 2
    dot_r = max(1, size // 40)
    for angle_deg in range(0, 360, 15):
        angle = math.radians(angle_deg)
        dx = band_r_mid * math.cos(angle)
        dy = band_r_mid * math.sin(angle)
        dot_cx = int(cx + dx)
        dot_cy = int(cy + dy)
        for yy in range(dot_cy - dot_r, dot_cy + dot_r + 1):
            for xx in range(dot_cx - dot_r, dot_cx + dot_r + 1):
                if 0 <= xx < size and 0 <= yy < size:
                    if math.sqrt((xx-dot_cx)**2 + (yy-dot_cy)**2) <= dot_r:
                        px[xx, yy] = DARK

    return img


def render_halfblock(img, indent=2):
    """Render image using half-block technique"""
    w, h = img.size
    pixels = img.load()
    prefix = " " * indent

    if h % 2 != 0:
        h_padded = h + 1
    else:
        h_padded = h

    result = []
    for y in range(0, h_padded, 2):
        line = prefix
        for x in range(w):
            if y < img.height:
                tr, tg, tb, ta = pixels[x, y]
            else:
                tr, tg, tb, ta = 0, 0, 0, 0
            if y + 1 < img.height:
                br, bg, bb, ba = pixels[x, y + 1]
            else:
                br, bg, bb, ba = 0, 0, 0, 0

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
        result.append(line)

    return result


def render_sixel(img_path, width_px=None):
    """Render image using sixel"""
    cmd = ["img2sixel"]
    if width_px:
        cmd += ["-w", str(width_px)]
    cmd.append(img_path)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout
    except:
        return "[sixel not available]"


def main():
    print()
    print("=" * 55)
    print(" Resolution Comparison: Same Emblem, Same Terminal Space")
    print("=" * 55)
    print()

    # --- 1. Half-block 20×20 ---
    print("【A】Half-block 20×20 pixels (= 20 chars × 10 lines)")
    print("    解像度: 20×20 = 400 pixels")
    print()
    img20 = draw_noblesse(20)
    img20.save("/tmp/noblesse_20.png")
    for line in render_halfblock(img20):
        print(line)
    print()

    # --- 2. Half-block 40×40 ---
    print("【B】Half-block 40×40 pixels (= 40 chars × 20 lines)")
    print("    解像度: 40×40 = 1,600 pixels")
    print()
    img40 = draw_noblesse(40)
    img40.save("/tmp/noblesse_40.png")
    for line in render_halfblock(img40):
        print(line)
    print()

    # --- 3. Half-block 60×60 ---
    print("【C】Half-block 60×60 pixels (= 60 chars × 30 lines)")
    print("    解像度: 60×60 = 3,600 pixels")
    print()
    img60 = draw_noblesse(60)
    img60.save("/tmp/noblesse_60.png")
    for line in render_halfblock(img60):
        print(line)
    print()

    # --- 4. Sixel 80×80 ---
    print("【D】Sixel 80×80 pixels (対応ターミナルのみ)")
    print("    解像度: 80×80 = 6,400 pixels")
    print("    ターミナル上の表示サイズは【A】とほぼ同じ")
    print()
    img80 = draw_noblesse(80)
    img80.save("/tmp/noblesse_80.png")
    sixel_out = render_sixel("/tmp/noblesse_80.png", 80)
    print(sixel_out)
    print()

    # --- 5. Sixel 160×160 ---
    print("【E】Sixel 160×160 pixels")
    print("    解像度: 160×160 = 25,600 pixels")
    print()
    img160 = draw_noblesse(160)
    img160.save("/tmp/noblesse_160.png")
    sixel_out = render_sixel("/tmp/noblesse_160.png", 160)
    print(sixel_out)
    print()

    print("─" * 55)
    print(" 比較まとめ:")
    print("  A: 20×20  →  最小、カルチョビット感")
    print("  B: 40×40  →  ディテール見える、紋章らしさ出る")
    print("  C: 60×60  →  かなり精密、場所は取る")
    print("  D: Sixel  →  同じ表示サイズで4倍の解像度")
    print("  E: Sixel  →  高精細（対応ターミナルのみ）")
    print("─" * 55)
    print()


if __name__ == "__main__":
    main()
