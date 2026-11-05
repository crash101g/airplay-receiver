#!/usr/bin/env bash
#
# install.sh — set up UxPlay + the friendly wrapper/GUI on Pop!_OS (COSMIC or GNOME).
#
# Installs per-user (no files outside your home except via apt). Re-runnable.
#
set -euo pipefail

info() { printf '\033[36m•\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

VERSION="1.7.0"   # keep in sync with bin/airplay-receiver and airplay-receiver-gui
PREFIX="${PREFIX:-$HOME/.local}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

info "Installing uxplay-easy v$VERSION"

# ---- 1. system dependencies (uxplay + GStreamer + GTK4 bindings) ----------
if ! command -v uxplay >/dev/null 2>&1; then
  info "Installing uxplay and dependencies via apt (needs sudo)…"
  sudo apt update
  sudo apt install -y \
    uxplay \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-vaapi \
    avahi-daemon \
    python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
  sudo systemctl enable --now avahi-daemon || warn "could not enable avahi-daemon; discovery may fail"
else
  info "uxplay already installed: $(command -v uxplay)"
fi

# ---- 1b. check UxPlay version -------------------------------------------
# The apt build (1.68.x) mis-handles AirPlay clock sync with recent iPhones
# ("invalid ntp_time" spam, no video). 1.74+ fixes it. Offer to build it.
uxver="$(uxplay -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
if [ -n "$uxver" ]; then
  major="${uxver%%.*}"; minor="${uxver#*.}"
  if [ "$major" -lt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -lt 74 ]; }; then
    warn "Your UxPlay is $uxver. Versions below 1.74 fail to mirror from recent iPhones/iOS."
    if [ -t 0 ]; then
      read -rp "Build and install UxPlay 1.74 from source now? [Y/n] " ans
      case "${ans:-Y}" in
        [nN]*) warn "Skipping. You can build it later with:  airplay-build-uxplay" ;;
        *)     bash "$SRC_DIR/build-uxplay.sh" ;;
      esac
    else
      warn "Run 'airplay-build-uxplay' to upgrade (needed for mirroring to work)."
    fi
  else
    info "UxPlay $uxver is current enough (>= 1.74)."
  fi
fi

# ---- 2. copy the wrapper + GUI into ~/.local/bin --------------------------
install -d "$PREFIX/bin"
install -m 0755 "$SRC_DIR/bin/airplay-receiver"     "$PREFIX/bin/"
install -m 0755 "$SRC_DIR/bin/airplay-receiver-gui" "$PREFIX/bin/"
# The updater, exposed as 'airplay-update' so future updates are one command.
install -m 0755 "$SRC_DIR/reinstall.sh"             "$PREFIX/bin/airplay-update"
# Source builder for UxPlay (fixes old-apt-version clock-sync bugs).
install -m 0755 "$SRC_DIR/build-uxplay.sh"          "$PREFIX/bin/airplay-build-uxplay"
info "Installed commands to $PREFIX/bin (including 'airplay-update', 'airplay-build-uxplay')"

# ---- 3. desktop entry + icon ----------------------------------------------
install -d "$PREFIX/share/applications" "$PREFIX/share/icons/hicolor/scalable/apps"
install -m 0644 "$SRC_DIR/share/applications/airplay-receiver.desktop"      "$PREFIX/share/applications/"
install -m 0644 "$SRC_DIR/share/applications/airplay-receiver-open.desktop" "$PREFIX/share/applications/"
if [ -f "$SRC_DIR/share/icons/airplay-receiver.svg" ]; then
  install -m 0644 "$SRC_DIR/share/icons/airplay-receiver.svg" \
    "$PREFIX/share/icons/hicolor/scalable/apps/airplay-receiver.svg"
fi
update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
info "Installed the AirPlay Receiver app launcher"

# ---- 4. PATH check ---------------------------------------------------------
case ":$PATH:" in
  *":$PREFIX/bin:"*) : ;;
  *) warn "$PREFIX/bin is not on your PATH. Add this to ~/.bashrc:"
     printf '      export PATH="%s/bin:$PATH"\n' "$PREFIX" ;;
esac

cat <<EOF

Done — uxplay-easy v$VERSION installed. Try it:
  airplay-receiver            # terminal, secure PIN mode (default)
  airplay-receiver open       # no PIN, trusted LAN only
  airplay-receiver-gui        # graphical app (also in your app launcher)

To update later: download the new tarball into this folder and run:
  airplay-update

If a device can't find the receiver, check your firewall (mDNS is UDP 5353)
and that avahi-daemon is running:  systemctl status avahi-daemon
EOF
