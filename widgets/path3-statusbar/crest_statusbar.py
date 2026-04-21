#!/usr/bin/env python3
"""
Path 3: iTerm2 StatusBarComponent — flicker-free by design.

Registers a native iTerm2 status bar component that renders outside
Ink's domain entirely. The component uses:
  - A static icon (16x17pt / 32x34pt for Retina)
  - Braille spinner for activity indication
  - iterm2.Reference("user.crest_state?") for push-driven state updates

Installation:
  1. Copy to ~/Library/Application Support/iTerm2/Scripts/AutoLaunch/
  2. iTerm2 → Preferences → Profiles → Session → Configure Status Bar
  3. Drag "NeonHaze Crest" component into the status bar

State push (from any script):
  python3 -c "
  import iterm2, asyncio
  async def push(conn):
      app = await iterm2.async_get_app(conn)
      s = app.current_terminal_window.current_tab.current_session
      await s.async_set_variable('user.crest_state', 'thinking')
  iterm2.run_until_complete(push)
  "
"""

import asyncio
import base64
import pathlib
import sys
import time

import iterm2

ICON_DIR = pathlib.Path("~/.claude/crest").expanduser()
SPINNER_BRAILLE = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
SPINNER_DOTS = ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"]


def load_icon_b64(name: str) -> str:
    path = ICON_DIR / name
    if path.exists():
        return base64.b64encode(path.read_bytes()).decode()
    return ""


async def main(connection: iterm2.Connection):
    app = await iterm2.async_get_app(connection)
    print("[statusbar] Connected to iTerm2")

    icon_1x = load_icon_b64("icon_16x17.png")
    icon_2x = load_icon_b64("icon_32x34.png")

    icons = []
    if icon_1x:
        icons.append(iterm2.StatusBarComponent.Icon(1, icon_1x))
    if icon_2x:
        icons.append(iterm2.StatusBarComponent.Icon(2, icon_2x))

    component = iterm2.StatusBarComponent(
        short_description="NeonHaze Crest",
        detailed_description="Claude Code dynamic widget — flicker-free status indicator",
        knobs=[
            iterm2.StringKnob("Label", "Claude", "default", "label"),
            iterm2.StringKnob("Spinner Style", "braille", "braille", "spinner_style"),
        ],
        exemplar="Claude ⠋ thinking",
        update_cadence=0.1,
        identifier="com.neonhaze.crest.statusbar",
        icons=icons if icons else None,
    )

    frame = {"i": 0, "last_state": "idle", "idle_since": time.time()}

    @iterm2.StatusBarRPC
    async def coro(
        knobs,
        state=iterm2.Reference("user.crest_state?"),
    ):
        label = knobs.get("label", "Claude")
        style = knobs.get("spinner_style", "braille")
        spinner = SPINNER_BRAILLE if style == "braille" else SPINNER_DOTS

        frame["i"] = (frame["i"] + 1) % len(spinner)

        if not state or state == "idle":
            idle_dur = time.time() - frame.get("idle_since", time.time())
            if frame["last_state"] != "idle":
                frame["idle_since"] = time.time()
                frame["last_state"] = "idle"
            if idle_dur > 60:
                return f"{label}"
            return f"{label} idle"

        if frame["last_state"] != state:
            frame["last_state"] = state
            frame["idle_since"] = time.time()

        if state == "thinking":
            return f"{label} {spinner[frame['i']]} thinking…"
        if state == "streaming":
            return f"{label} ▶ streaming"
        if state == "working":
            return f"{label} {spinner[frame['i']]} working…"
        return f"{label} {state}"

    await component.async_register(connection, coro)
    print("[statusbar] Component registered: com.neonhaze.crest.statusbar")


if __name__ == "__main__":
    iterm2.run_forever(main)
