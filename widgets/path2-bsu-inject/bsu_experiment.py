#!/usr/bin/env python3
"""
Path 2: BSU-wrapped async_inject experiment.

Tests inject patterns to isolate the root cause of flicker and verify
that BSU-wrapped rotation works flicker-free.

Static patterns (1-11): pre-built bytes, same every inject
Dynamic patterns (12-17): per-frame image rotation with BSU/ESU

Patterns:
  1.  Empty bytes (baseline)
  2.  Single space (inject path alone)
  3.  DECSC+DECRC only (cursor save/restore)
  4.  CUP only (cursor absolute position)
  5.  Minimal OSC 1337 image (1x1)
  6.  OSC 1337 + doNotMoveCursor=1
  7.  SCP/RCP wrapped image
  8.  OSC 8 hyperlink only
  9.  CSI EL (clear line)
  10. BSU + full sequence + ESU (static)
  11. Current full sequence, no BSU (static control)
  --- dynamic rotation ---
  12. BSU + rotating image + ESU @ 1Hz (5°/frame)
  13. BSU + rotating image + ESU @ 2Hz (5°/frame)
  14. BSU + rotating image + ESU @ 5Hz (5°/frame)
  15. Rotating image WITHOUT BSU @ 1Hz (flicker control)
  16. BSU + rotating image + ESU @ 1Hz (15°/frame, fast spin)
  17. BSU + rotating image + ESU @ 10Hz (5°/frame, stress test)

Usage:
  python3 bsu_experiment.py [pattern_number]  # run single pattern
  python3 bsu_experiment.py all               # run all patterns sequentially
  python3 bsu_experiment.py rotate            # run only rotation patterns (12-17)
  python3 bsu_experiment.py interactive       # show pattern list
"""

import asyncio
import base64
import io
import os
import sys
import time
from typing import Callable, Optional, Union

import iterm2

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

PATTERN_DURATION = 15  # seconds per pattern
SPRITE_PNG = os.path.expanduser("~/.cache/claude-statusline/sprite-widget.png")

BSU = b"\x1b[?2026h"
ESU = b"\x1b[?2026l"
DECSC = b"\x1b7"
DECRC = b"\x1b8"
SCP = b"\x1b[s"
RCP = b"\x1b[u"

_img_cache: dict[str, "Image.Image"] = {}


def make_1x1_png_b64() -> str:
    if HAS_PIL:
        img = Image.new("RGBA", (1, 1), (200, 150, 50, 255))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode()
    return base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"\x00" * 50).decode()


def make_sprite_b64() -> str:
    if os.path.isfile(SPRITE_PNG):
        with open(SPRITE_PNG, "rb") as f:
            return base64.b64encode(f.read()).decode()
    return make_1x1_png_b64()


def rotate_image_b64(path: str, angle: float) -> str:
    if not HAS_PIL:
        return make_sprite_b64()
    if path not in _img_cache:
        _img_cache[path] = Image.open(path).convert("RGBA")
    img = _img_cache[path].rotate(angle, resample=Image.BICUBIC, expand=False)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def build_osc_image(b64: str, w="auto", h="8", extra="") -> bytes:
    header = f"\x1b]1337;File=inline=1;width={w};height={h};preserveAspectRatio=1"
    if extra:
        header += f";{extra}"
    return (header + ":" + b64 + "\a").encode("ascii")


# Pattern definition: either static bytes or (name, hz, generator_fn)
PatternDef = Union[
    tuple[str, bytes],                              # static: (name, data)
    tuple[str, float, Callable[[int], bytes]],      # dynamic: (name, hz, fn(frame) -> bytes)
]


def build_patterns(target_row: int, target_col: int) -> dict[int, PatternDef]:
    img_1x1 = make_1x1_png_b64()
    img_sprite = make_sprite_b64()
    cup = f"\x1b[{target_row};{target_col}H".encode("ascii")

    full_seq = DECSC + cup + build_osc_image(img_sprite) + DECRC

    def make_rotate_gen(deg_per_frame: float, use_bsu: bool):
        """Return a generator function that builds rotated inject bytes per frame."""
        def gen(frame_idx: int) -> bytes:
            angle = (frame_idx * deg_per_frame) % 360
            rotated_b64 = rotate_image_b64(SPRITE_PNG, angle)
            seq = DECSC + cup + build_osc_image(rotated_b64) + DECRC
            if use_bsu:
                return BSU + seq + ESU
            return seq
        return gen

    patterns: dict[int, PatternDef] = {
        # --- static patterns ---
        1:  ("empty bytes (baseline)", b""),
        2:  ("single space", b" "),
        3:  ("DECSC+DECRC only", DECSC + DECRC),
        4:  ("CUP only", cup),
        5:  ("minimal 1x1 image", DECSC + cup + build_osc_image(img_1x1, w="1", h="1") + DECRC),
        6:  ("1x1 + doNotMoveCursor", DECSC + cup + build_osc_image(img_1x1, w="1", h="1", extra="doNotMoveCursor=1") + DECRC),
        7:  ("SCP/RCP wrapped image", SCP + cup + build_osc_image(img_sprite) + RCP),
        8:  ("OSC 8 hyperlink only", b"\x1b]8;;https://example.com\x07test\x1b]8;;\x07"),
        9:  ("CSI EL (clear line)", DECSC + cup + b"\x1b[2K" + DECRC),
        10: ("BSU + static image + ESU", BSU + full_seq + ESU),
        11: ("static image, no BSU (control)", full_seq),
        # --- dynamic rotation patterns ---
        12: ("BSU + rotate 5°/f + ESU @ 1Hz", 1.0, make_rotate_gen(5.0, True)),
        13: ("BSU + rotate 5°/f + ESU @ 2Hz", 2.0, make_rotate_gen(5.0, True)),
        14: ("BSU + rotate 5°/f + ESU @ 5Hz", 5.0, make_rotate_gen(5.0, True)),
        15: ("rotate 5°/f NO BSU @ 1Hz (flicker ctrl)", 1.0, make_rotate_gen(5.0, False)),
        16: ("BSU + rotate 15°/f + ESU @ 1Hz (fast)", 1.0, make_rotate_gen(15.0, True)),
        17: ("BSU + rotate 5°/f + ESU @ 10Hz (stress)", 10.0, make_rotate_gen(5.0, True)),
    }
    return patterns


def is_dynamic(p: PatternDef) -> bool:
    return len(p) == 3


async def run_static(session, num: int, name: str, data: bytes, duration: int):
    """Run a static pattern (same bytes every inject)."""
    hz = 1.0
    interval = 1.0 / hz
    print(f"[P{num:2d}] {name}")
    print(f"  type: static, inject size: {len(data)} bytes, {hz} Hz, {duration}s")

    start = time.time()
    count = 0
    while time.time() - start < duration:
        if data:
            try:
                await session.async_inject(data)
                count += 1
            except Exception as e:
                print(f"  ERROR at inject #{count}: {e}", file=sys.stderr)
                break
        await asyncio.sleep(interval)

    elapsed = time.time() - start
    print(f"  done: {count} injects in {elapsed:.1f}s ({count/max(elapsed,0.001):.1f} Hz)")
    return {"pattern": num, "name": name, "injects": count, "elapsed": elapsed, "type": "static"}


async def run_dynamic(session, num: int, name: str, hz: float,
                      gen: Callable[[int], bytes], duration: int):
    """Run a dynamic pattern (new bytes generated per frame)."""
    interval = 1.0 / hz
    print(f"[P{num:2d}] {name}")
    print(f"  type: dynamic (rotation), {hz} Hz, {duration}s")

    start = time.time()
    count = 0
    total_bytes = 0
    max_gen_ms = 0.0
    while time.time() - start < duration:
        t0 = time.time()
        data = gen(count)
        gen_ms = (time.time() - t0) * 1000
        max_gen_ms = max(max_gen_ms, gen_ms)
        total_bytes += len(data)

        try:
            await session.async_inject(data)
            count += 1
        except Exception as e:
            print(f"  ERROR at inject #{count}: {e}", file=sys.stderr)
            break
        await asyncio.sleep(interval)

    elapsed = time.time() - start
    avg_size = total_bytes // max(count, 1)
    print(f"  done: {count} injects in {elapsed:.1f}s ({count/max(elapsed,0.001):.1f} Hz)")
    print(f"  avg frame: {avg_size} bytes, max gen time: {max_gen_ms:.1f}ms")
    return {
        "pattern": num, "name": name, "injects": count, "elapsed": elapsed,
        "type": "dynamic", "avg_bytes": avg_size, "max_gen_ms": round(max_gen_ms, 1),
    }


async def run_pattern(session, num: int, pdef: PatternDef, duration: int) -> dict:
    if is_dynamic(pdef):
        name, hz, gen = pdef
        return await run_dynamic(session, num, name, hz, gen, duration)
    else:
        name, data = pdef
        return await run_static(session, num, name, data, duration)


def print_results(results: list[dict]):
    print(f"\n{'='*70}")
    print(f"  {'#':>3s}  {'Name':30s}  {'Type':7s}  {'Injects':>7s}  {'Hz':>5s}  {'Notes':s}")
    print(f"  {'---':>3s}  {'------------------------------':30s}  {'-------':7s}  {'-------':>7s}  {'-----':>5s}  {'-----':s}")
    for r in results:
        hz = r["injects"] / max(r["elapsed"], 0.001)
        notes = ""
        if r.get("type") == "dynamic":
            notes = f"avg {r.get('avg_bytes',0)}B, gen {r.get('max_gen_ms',0)}ms"
        print(f"  {r['pattern']:3d}  {r['name']:30s}  {r['type']:7s}  {r['injects']:7d}  {hz:5.1f}  {notes}")
    print(f"{'='*70}")


async def main(connection: iterm2.Connection):
    app = await iterm2.async_get_app(connection)
    print("[bsu-exp] Connected to iTerm2")

    window = app.current_terminal_window
    if not window or not window.current_tab:
        print("ERROR: No active window", file=sys.stderr)
        return
    session = window.current_tab.current_session
    if not session:
        print("ERROR: No active session", file=sys.stderr)
        return

    tty = await session.async_get_variable("session.tty")
    rows = await session.async_get_variable("session.rows")
    cols = await session.async_get_variable("session.columns")
    rows = int(rows) if rows else 40
    cols = int(cols) if cols else 120
    print(f"[bsu-exp] Session: {session.session_id}, TTY: {tty}, {cols}x{rows}")

    if not HAS_PIL:
        print("[bsu-exp] WARNING: PIL not available — dynamic patterns will use static image")

    target_row = max(1, rows - 8)
    target_col = max(1, cols - 25)
    patterns = build_patterns(target_row, target_col)

    arg = sys.argv[1] if len(sys.argv) > 1 else "interactive"

    if arg == "all":
        results = []
        for num in sorted(patterns.keys()):
            r = await run_pattern(session, num, patterns[num], PATTERN_DURATION)
            results.append(r)
            await asyncio.sleep(2)
        print_results(results)

    elif arg == "rotate":
        results = []
        for num in sorted(patterns.keys()):
            if num >= 12:
                r = await run_pattern(session, num, patterns[num], PATTERN_DURATION)
                results.append(r)
                await asyncio.sleep(2)
        print_results(results)

    elif arg == "interactive":
        print("\nAvailable patterns:")
        print("  --- static ---")
        for num in sorted(patterns.keys()):
            if num <= 11:
                p = patterns[num]
                name = p[0]
                size = len(p[1]) if not is_dynamic(p) else "dynamic"
                print(f"  {num:2d}. {name} ({size} bytes)")
        print("  --- dynamic (rotation) ---")
        for num in sorted(patterns.keys()):
            if num >= 12:
                p = patterns[num]
                name, hz = p[0], p[1]
                print(f"  {num:2d}. {name}")
        print(f"\n  Commands:")
        print(f"    python3 bsu_experiment.py <number>   # single pattern")
        print(f"    python3 bsu_experiment.py all         # all patterns")
        print(f"    python3 bsu_experiment.py rotate      # rotation patterns only (12-17)")

    else:
        try:
            num = int(arg)
        except ValueError:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            return
        if num not in patterns:
            print(f"Pattern {num} not found (valid: 1-17)", file=sys.stderr)
            return
        await run_pattern(session, num, patterns[num], PATTERN_DURATION)


if __name__ == "__main__":
    iterm2.run_until_complete(main)
