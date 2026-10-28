#!/usr/bin/env bash
#
# build-uxplay.sh — build and install the latest UxPlay from source.
#
# Pop!_OS / Ubuntu ships UxPlay 1.68.2 (Dec 2023). Newer iPhones/iOS use a
# revised AirPlay clock-sync that 1.68 mishandles, producing endless
# "invalid ntp_time < gst_video_pipeline_base_time" errors and no video.
# The current UxPlay (1.74) reworked that timing code. This script builds it
# and installs it to /usr/local/bin, which takes precedence over the apt copy.
#
# Safe to re-run. Needs sudo for dependencies and the final install.
#
set -euo pipefail

info() { printf '\033[36m•\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

REPO="https://github.com/FDH2/UxPlay.git"
SRC="${HOME}/.cache/uxplay-easy/UxPlay"

# Run from a directory that is guaranteed to exist. If this script is launched
# from a folder that was just deleted (e.g. by airplay-update), the shell's CWD
# is gone and git/cmake fail with "Unable to read current working directory".
cd "$HOME" 2>/dev/null || cd / || true

# ---- 1. build dependencies -------------------------------------------------
info "Installing build dependencies (needs sudo)…"
sudo apt update
sudo apt install -y \
  cmake build-essential \
  libssl-dev libplist-dev libavahi-compat-libdnssd-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-vaapi

# ---- 2. fetch source -------------------------------------------------------
if [ -d "$SRC/.git" ]; then
  info "Updating existing checkout at $SRC"
  git -C "$SRC" fetch --depth 1 origin && git -C "$SRC" reset --hard origin/HEAD
else
  info "Cloning UxPlay into $SRC"
  mkdir -p "$(dirname "$SRC")"
  rm -rf "$SRC"
  git clone --depth 1 "$REPO" "$SRC"
fi

# ---- 2b. patch: double-click toggles fullscreen ----------------------------
# UxPlay natively toggles fullscreen on F11 / left-Alt+Enter (key events on its
# X11 video window). This adds the same toggle on a left-button double-click,
# using GStreamer mouse navigation events that xvimagesink already forwards.
info "Applying double-click-to-fullscreen patch…"
python3 - "$SRC/renderers/video_renderer.c" <<'PYEOF'
import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()

if "last_click_us" in src:
    print("  already patched; skipping")
    sys.exit(0)
if "GST_NAVIGATION_EVENT_KEY_PRESS" not in src or "switch (event_type) {" not in src:
    print("  WARNING: expected code not found — skipping patch (F11 still works)")
    sys.exit(0)

# 1) a static timestamp for detecting the double-click
src = src.replace(
    "static bool alt_keypress = false;",
    "static bool alt_keypress = false;\n"
    "static gint64 last_click_us = 0; /* for double-click fullscreen toggle */",
    1,
)

# 2) a mouse-button case in the navigation event switch
case_code = (
    "switch (event_type) {\n"
    "                    case GST_NAVIGATION_EVENT_MOUSE_BUTTON_PRESS: {\n"
    "                        gint _btn = 0; gdouble _mx = 0, _my = 0;\n"
    "                        if (gst_navigation_event_parse_mouse_button_event (event, &_btn, &_mx, &_my) && _btn == 1) {\n"
    "                            gint64 _now = g_get_monotonic_time();\n"
    "                            if (_now - last_click_us > 0 && _now - last_click_us < 400000) {\n"
    "                                fullscreen = !(fullscreen);\n"
    "                                set_fullscreen(renderer->gst_window, &fullscreen);\n"
    "                                last_click_us = 0;\n"
    "                            } else {\n"
    "                                last_click_us = _now;\n"
    "                            }\n"
    "                        }\n"
    "                        break;\n"
    "                    }\n"
)
src = src.replace("switch (event_type) {", case_code, 1)

open(path, "w", encoding="utf-8").write(src)
print("  patched: double-click now toggles fullscreen")
PYEOF

# ---- 3. build --------------------------------------------------------------
info "Building…"
cmake -B "$SRC/build" -S "$SRC" -DCMAKE_BUILD_TYPE=Release
cmake --build "$SRC/build" -j "$(nproc)"

# ---- 4. install ------------------------------------------------------------
info "Installing to /usr/local (needs sudo)…"
sudo cmake --install "$SRC/build"
sudo ldconfig || true
hash -r 2>/dev/null || true

# ---- 5. verify -------------------------------------------------------------
newbin="$(command -v uxplay || true)"
built_ver="$("$newbin" -v 2>/dev/null | head -1 || true)"
info "uxplay now resolves to: ${newbin:-not found}"
info "version: ${built_ver:-unknown}"

if [ "$newbin" != "/usr/local/bin/uxplay" ]; then
  warn "PATH still points at $newbin, not the new /usr/local/bin/uxplay."
  warn "Open a new terminal, or run:  hash -r"
  warn "If it persists, the apt copy is shadowing it — remove it with:  sudo apt remove uxplay"
fi

cat <<EOF

Done. Test mirroring with:
  uxplay -n test
If video now plays (no "invalid ntp_time" spam), you're fixed — use the app as normal.
EOF
