#!/usr/bin/env python3
"""
Push crest_state to iTerm2 session variable for StatusBarComponent.

Usage:
  python3 push_state.py thinking
  python3 push_state.py streaming
  python3 push_state.py idle
  python3 push_state.py working

The StatusBarComponent reads iterm2.Reference("user.crest_state?")
and updates its display accordingly. No PTY bytes written.
"""
import sys
import iterm2


async def push(connection: iterm2.Connection):
    state = sys.argv[1] if len(sys.argv) > 1 else "idle"
    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    if not window or not window.current_tab:
        print(f"[push] No active window/tab", file=sys.stderr)
        return
    session = window.current_tab.current_session
    if not session:
        print(f"[push] No active session", file=sys.stderr)
        return
    await session.async_set_variable("user.crest_state", state)
    print(f"[push] Set crest_state={state} on {session.session_id}")


if __name__ == "__main__":
    iterm2.run_until_complete(push)
