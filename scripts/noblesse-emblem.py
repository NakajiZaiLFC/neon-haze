#!/usr/bin/env python3
"""
Noblesse Emblem - Sixel animated pixel art
Outer text ring rotates, sword+scales stay fixed.
"""
import math, subprocess, sys, time, os
from PIL import Image, ImageDraw, ImageFont

SIZE = 160
CX, CY = SIZE / 2, SIZE / 2

GOLD    = (220, 170, 50)
DARK    = (50, 28, 15)
INNER   = (195, 155, 60)
SWORD   = (55, 30, 15)
BAND    = (130, 95, 35)
CHAIN   = (75, 42, 22)
PAN     = (40, 22, 10)
HILT    = (85, 50, 28)
ACCENT  = (170, 125, 40)
TRANSP  = (0, 0, 0, 0)


def draw_background(rotation_deg=0):
    """Circle frame + rotating text band"""
    img = Image.new("RGBA", (SIZE, SIZE), TRANSP)
    draw = ImageDraw.Draw(img)
    r = SIZE / 2 - 2

    draw.ellipse([CX-r, CY-r, CX+r, CY+r], fill=DARK)
    draw.ellipse([CX-r*0.92, CY-r*0.92, CX+r*0.92, CY+r*0.92], fill=BAND)
    draw.ellipse([CX-r*0.78, CY-r*0.78, CX+r*0.78, CY+r*0.78], fill=DARK)
    draw.ellipse([CX-r*0.72, CY-r*0.72, CX+r*0.72, CY+r*0.72], fill=INNER)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size=9)
    except:
        font = ImageFont.load_default()

    text_top = "THE HOUSE OF EKERITES"
    text_bot = "IT IS WHAT FROM IT DISSOLVES REMORSE ALWAYS"
    band_r = r * 0.85

    for i, ch in enumerate(text_top):
        angle = math.radians(-180 + (i - len(text_top)/2) * 8 + rotation_deg)
        tx = int(CX + band_r * math.cos(angle))
        ty = int(CY + band_r * math.sin(angle))
        draw.text((tx-3, ty-5), ch, fill=DARK, font=font)

    for i, ch in enumerate(text_bot):
        angle = math.radians(0 + (i - len(text_bot)/2) * 5.5 + rotation_deg)
        tx = int(CX + band_r * math.cos(angle))
        ty = int(CY + band_r * math.sin(angle))
        draw.text((tx-3, ty-5), ch, fill=DARK, font=font)

    for angle_deg in [90 + rotation_deg, 270 + rotation_deg]:
        angle = math.radians(angle_deg)
        dx = int(CX + band_r * math.cos(angle))
        dy = int(CY + band_r * math.sin(angle))
        draw.ellipse([dx-3, dy-3, dx+3, dy+3], fill=DARK)

    return img


def draw_foreground():
    """Sword + scales (fixed, no rotation)"""
    img = Image.new("RGBA", (SIZE, SIZE), TRANSP)
    draw = ImageDraw.Draw(img)
    r = SIZE / 2 - 2
    sw = 3

    # Blade
    draw.rectangle([CX-sw, CY - r*0.55, CX+sw, CY + r*0.58], fill=SWORD)
    # Fuller
    draw.rectangle([CX-1, CY - r*0.45, CX+1, CY + r*0.45], fill=ACCENT)
    # Crossguard
    cg_y = CY - r * 0.12
    cg_w = r * 0.32
    cg_h = 5
    draw.rectangle([CX - cg_w, cg_y - cg_h, CX + cg_w, cg_y + cg_h], fill=HILT)
    draw.ellipse([CX - cg_w - 4, cg_y - 4, CX - cg_w + 4, cg_y + 4], fill=HILT)
    draw.ellipse([CX + cg_w - 4, cg_y - 4, CX + cg_w + 4, cg_y + 4], fill=HILT)
    # Pommel
    pm_y = CY - r * 0.55
    draw.ellipse([CX-6, pm_y-6, CX+6, pm_y+6], fill=HILT)
    draw.ellipse([CX-3, pm_y-3, CX+3, pm_y+3], fill=ACCENT)
    # Tip
    tip_y = CY + r * 0.58
    draw.polygon([(CX-sw, tip_y), (CX+sw, tip_y), (CX, tip_y+12)], fill=SWORD)

    # Scales
    for side in [-1, 1]:
        anchor_x = CX + side * cg_w * 0.85
        anchor_y = cg_y
        beam_angle = side * 0.15
        beam_len = r * 0.28
        beam_end_x = anchor_x + side * beam_len * math.cos(beam_angle)
        beam_end_y = anchor_y + beam_len * math.sin(beam_angle) + 8
        draw.line([(anchor_x, anchor_y), (beam_end_x, beam_end_y)], fill=CHAIN, width=2)

        chain_len = r * 0.22
        chain_bottom_y = beam_end_y + chain_len
        draw.line([(beam_end_x - 8, beam_end_y), (beam_end_x - 10, chain_bottom_y)], fill=CHAIN, width=1)
        draw.line([(beam_end_x + 8, beam_end_y), (beam_end_x + 10, chain_bottom_y)], fill=CHAIN, width=1)
        draw.line([(beam_end_x, beam_end_y), (beam_end_x, chain_bottom_y)], fill=CHAIN, width=1)

        pan_w = 14
        pan_h = 6
        pan_cx = beam_end_x
        pan_cy = chain_bottom_y
        draw.arc([pan_cx-pan_w, pan_cy-pan_h, pan_cx+pan_w, pan_cy+pan_h*2],
                 0, 180, fill=PAN, width=3)
        draw.line([(pan_cx-pan_w, pan_cy), (pan_cx+pan_w, pan_cy)], fill=PAN, width=2)

    return img


def compose(rotation_deg=0):
    bg = draw_background(rotation_deg)
    fg = draw_foreground()
    bg.paste(fg, (0, 0), fg)
    return bg


def show_sixel(img, width=None):
    tmp = "/tmp/_neonhaze_sprite.png"
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

    if mode == "static":
        print("\n⚔️  Noblesse Emblem (160×160 Sixel)\n")
        img = compose(rotation_deg=0)
        img.save("/tmp/noblesse_emblem.png")
        show_sixel(img, width=160)
        print(f"\n  Saved to /tmp/noblesse_emblem.png\n")

    elif mode == "rotate":
        frames = 36
        duration = int(sys.argv[2]) if len(sys.argv) > 2 else 10

        print("\n⚔️  Noblesse Emblem - Ring Rotation (sword fixed)\n")
        print("  Generating frames...", end="", flush=True)

        fg = draw_foreground()
        frame_imgs = []
        for i in range(frames):
            angle = (360 / frames) * i
            bg = draw_background(rotation_deg=angle)
            bg.paste(fg, (0, 0), fg)
            frame_imgs.append(bg)
        print(" done.\n")

        show_sixel(frame_imgs[0], width=160)
        sixel_lines = SIZE // 12 + 2

        start = time.time()
        frame = 0
        while time.time() - start < duration:
            clear_lines(sixel_lines)
            show_sixel(frame_imgs[frame % frames], width=160)
            frame += 1
            time.sleep(duration / frames / 3)

        print()

    elif mode == "frames":
        print("\n⚔️  Generating animation frames...\n")
        os.makedirs("/tmp/noblesse_frames", exist_ok=True)
        fg = draw_foreground()
        for i in range(24):
            angle = (360 / 24) * i
            bg = draw_background(rotation_deg=angle)
            bg.paste(fg, (0, 0), fg)
            path = f"/tmp/noblesse_frames/frame_{i:02d}.png"
            bg.save(path)
            print(f"  {path}")
        print(f"\n  24 frames saved.\n")


if __name__ == "__main__":
    main()
