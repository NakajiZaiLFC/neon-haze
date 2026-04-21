#!/usr/bin/env python3
"""
Pixel art renderer: reads a small PNG at native resolution,
outputs half-block (▀) with exact pixel colors. No interpolation.
Each pixel maps 1:1 to a terminal color.

Usage: python3 pixelart-render.py <sprite.png> [--transparent R,G,B]
"""
import sys
from PIL import Image

def render_sprite(path, transparent=None, indent=2):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    pixels = img.load()

    # Pad height to even
    if h % 2 != 0:
        h += 1

    prefix = " " * indent
    lines = []

    for y in range(0, h, 2):
        line = prefix
        for x in range(w):
            # Top pixel
            if y < img.height:
                tr, tg, tb, ta = pixels[x, y]
            else:
                tr, tg, tb, ta = 0, 0, 0, 0

            # Bottom pixel
            if y + 1 < img.height:
                br, bg, bb, ba = pixels[x, y + 1]
            else:
                br, bg, bb, ba = 0, 0, 0, 0

            # Handle transparency
            t_transparent = ta < 128
            b_transparent = ba < 128

            if transparent:
                rt, gt, bt = transparent
                if abs(tr-rt)<30 and abs(tg-gt)<30 and abs(tb-bt)<30:
                    t_transparent = True
                if abs(br-rt)<30 and abs(bg-gt)<30 and abs(bb-bt)<30:
                    b_transparent = True

            if t_transparent and b_transparent:
                line += " "
            elif t_transparent:
                line += f"\033[38;2;{br};{bg};{bb}m▄\033[0m"
            elif b_transparent:
                line += f"\033[38;2;{tr};{tg};{tb}m▀\033[0m"
            elif tr == br and tg == bg and tb == bb:
                line += f"\033[38;2;{tr};{tg};{tb}m█\033[0m"
            else:
                line += f"\033[38;2;{tr};{tg};{tb}m\033[48;2;{br};{bg};{bb}m▀\033[0m"

        lines.append(line)

    return lines, w, h


def create_noblesse_emblem():
    """Create a 20x20 pixel art Noblesse emblem, designed at native resolution"""
    img = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    px = img.load()

    # Color palette (intentional pixel art colors)
    GOLD = (220, 170, 50, 255)
    DARK = (50, 28, 15, 255)
    INNER = (190, 148, 55, 255)
    SWORD = (65, 35, 20, 255)
    SKIN = (160, 120, 40, 255)  # text band
    CLEAR = (0, 0, 0, 0)

    # Fill with gold
    for y in range(20):
        for x in range(20):
            px[x, y] = GOLD

    # Circle outline (dark ring)
    import math
    cx, cy, r_out, r_in, r_text_out, r_text_in = 9.5, 9.5, 9.5, 8.5, 8.0, 6.5
    for y in range(20):
        for x in range(20):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx*dx + dy*dy)
            if dist > r_out:
                px[x, y] = GOLD  # outside
            elif dist > r_in:
                px[x, y] = DARK  # outer ring
            elif dist > r_text_out:
                px[x, y] = SKIN  # text band
            elif dist > r_text_in:
                px[x, y] = DARK  # inner ring
            else:
                px[x, y] = INNER  # inner area

    # Sword (vertical line, center)
    for y in range(3, 17):
        px[9, y] = SWORD
        px[10, y] = SWORD

    # Crossguard
    for x in range(6, 14):
        px[x, 7] = SWORD

    # Scale pans (left)
    px[6, 8] = DARK
    px[7, 8] = DARK
    for x in range(5, 9):
        px[x, 12] = DARK
    # chains
    px[6, 9] = DARK
    px[6, 10] = DARK
    px[6, 11] = DARK
    px[8, 9] = DARK
    px[8, 10] = DARK
    px[8, 11] = DARK
    # pan bottom
    for x in range(5, 9):
        px[x, 13] = DARK

    # Scale pans (right)
    px[12, 8] = DARK
    px[13, 8] = DARK
    for x in range(11, 15):
        px[x, 11] = DARK
    px[11, 9] = DARK
    px[11, 10] = DARK
    px[13, 9] = DARK
    px[13, 10] = DARK
    for x in range(11, 15):
        px[x, 12] = DARK

    # Sword pommel
    px[9, 3] = DARK
    px[10, 3] = DARK
    px[9, 4] = SWORD
    px[10, 4] = SWORD

    # Sword tip
    px[9, 16] = SWORD
    px[10, 16] = SWORD

    return img


def create_tachikoma():
    """Create a 16x16 pixel art Tachikoma"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    BLUE = (50, 140, 210, 255)
    DBLUE = (30, 90, 150, 255)
    LBLUE = (100, 180, 240, 255)
    EYE = (255, 220, 50, 255)
    DARK = (25, 60, 100, 255)
    LEG = (40, 100, 160, 255)

    # Body (rounded rectangle-ish)
    for y in range(3, 10):
        for x in range(3, 13):
            px[x, y] = BLUE

    # Head dome
    for x in range(5, 11):
        px[x, 2] = BLUE
    for x in range(6, 10):
        px[x, 1] = LBLUE

    # Eyes (3 camera eyes)
    px[5, 4] = EYE
    px[7, 3] = EYE
    px[8, 3] = EYE
    px[10, 4] = EYE

    # Main eye visor
    for x in range(6, 10):
        px[x, 5] = DBLUE
    px[7, 4] = LBLUE
    px[8, 4] = LBLUE

    # Body details
    for x in range(4, 12):
        px[x, 7] = DBLUE
    for x in range(5, 11):
        px[x, 8] = DBLUE
        px[x, 9] = BLUE

    # Legs (4 legs)
    # Front left
    px[3, 10] = LEG
    px[2, 11] = LEG
    px[1, 12] = LEG
    px[1, 13] = DARK
    # Front right
    px[12, 10] = LEG
    px[13, 11] = LEG
    px[14, 12] = LEG
    px[14, 13] = DARK
    # Back left
    px[4, 10] = LEG
    px[4, 11] = LEG
    px[3, 12] = LEG
    px[3, 13] = DARK
    # Back right
    px[11, 10] = LEG
    px[11, 11] = LEG
    px[12, 12] = LEG
    px[12, 13] = DARK

    # Pod on back
    for x in range(6, 10):
        px[x, 10] = DBLUE

    return img


def create_nerv():
    """Create a 16x16 NERV logo (simplified leaf)"""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    RED = (200, 30, 30, 255)
    DRED = (150, 20, 20, 255)
    WHITE = (240, 240, 240, 255)
    BG = (20, 20, 20, 255)

    # Black background circle
    import math
    cx, cy = 7.5, 7.5
    for y in range(16):
        for x in range(16):
            dist = math.sqrt((x-cx)**2 + (y-cy)**2)
            if dist <= 7.5:
                px[x, y] = BG

    # Fig leaf shape (half)
    for y in range(2, 14):
        mid = 8
        # left half of leaf
        spread = max(0, min(4, int(3.5 * math.sin(math.pi * (y-2) / 12))))
        for x in range(mid - spread, mid):
            px[x, y] = RED
        # right half
        for x in range(mid, mid + spread):
            px[x, y] = DRED

    # Leaf vein (center line)
    for y in range(2, 14):
        px[7, y] = WHITE
        px[8, y] = WHITE

    # Text area (NERV)
    for x in range(3, 13):
        px[x, 14] = BG

    return img


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--widget":
        name = sys.argv[2] if len(sys.argv) > 2 else "noblesse"
        size = None
        output = None
        i = 3
        while i < len(sys.argv):
            if sys.argv[i] == "--size" and i + 1 < len(sys.argv):
                size = int(sys.argv[i + 1])
                i += 2
            elif sys.argv[i] == "--output" and i + 1 < len(sys.argv):
                output = sys.argv[i + 1]
                i += 2
            else:
                i += 1

        creators = {
            "noblesse": (create_noblesse_emblem, 20),
            "tachikoma": (create_tachikoma, 16),
            "nerv": (create_nerv, 16),
        }
        if name not in creators:
            print(f"Unknown sprite: {name}. Available: {', '.join(creators.keys())}", file=sys.stderr)
            sys.exit(1)

        create_fn, native_size = creators[name]
        img = create_fn()
        if size and size != native_size:
            img = img.resize((size, size), Image.NEAREST)

        tmp = f"/tmp/_widget_{name}.png"
        img.save(tmp)
        lines, w, h = render_sprite(tmp, indent=0)

        if output:
            with open(output, 'w') as f:
                for line in lines:
                    f.write(line + '\n')
            print(f"Widget: {name} {w}x{h}px -> {w}ch x {len(lines)}ln -> {output}", file=sys.stderr)
        else:
            for line in lines:
                print(line)

    elif len(sys.argv) > 1 and sys.argv[1] != "--demo":
        path = sys.argv[1]
        transparent = None
        if "--transparent" in sys.argv:
            idx = sys.argv.index("--transparent")
            r, g, b = map(int, sys.argv[idx+1].split(","))
            transparent = (r, g, b)
        lines, w, h = render_sprite(path, transparent)
        print(f"\n  Sprite: {w}×{h}px = {w} chars × {len(lines)} lines\n")
        for l in lines:
            print(l)
        print()
    else:
        # Demo mode: show built-in pixel art
        print()
        print("=" * 50)
        print(" Native Pixel Art vs Image Conversion")
        print(" ドット絵はネイティブ解像度で描くもの")
        print("=" * 50)
        print()

        # Generate and save demo sprites
        noblesse = create_noblesse_emblem()
        noblesse.save("/tmp/noblesse_20x20.png")
        tachikoma = create_tachikoma()
        tachikoma.save("/tmp/tachikoma_16x16.png")
        nerv = create_nerv()
        nerv.save("/tmp/nerv_16x16.png")

        print("【Noblesse Emblem】20×20px (= 20 chars × 10 lines)")
        lines, w, h = render_sprite("/tmp/noblesse_20x20.png")
        for l in lines:
            print(l)
        print()

        print("【Tachikoma】16×16px (= 16 chars × 8 lines)")
        lines, w, h = render_sprite("/tmp/tachikoma_16x16.png")
        for l in lines:
            print(l)
        print()

        print("【NERV】16×16px (= 16 chars × 8 lines)")
        lines, w, h = render_sprite("/tmp/nerv_16x16.png")
        for l in lines:
            print(l)
        print()

        print("─" * 50)
        print(" ポイント: 全ドットが意図的に配置されている")
        print(" 高解像度画像の縮小ではなく、最初からこの解像度で設計")
        print(" → Asepriteなどのドット絵エディタで描くのが正解")
        print("─" * 50)
        print()
