#!/usr/bin/env bash
#
# build-deb.sh — assemble the airplay-receiver .deb from this repository.
#
# Clones the pinned UxPlay release, applies our patches, bundles the source
# (so the package compiles the engine offline on install), and builds the .deb.
#
# Requires: dpkg-deb, git, python3. Produces: dist/airplay-receiver_<ver>_all.deb
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(cat "$REPO_ROOT/VERSION")"
UXPLAY_REPO="${UXPLAY_REPO:-https://github.com/FDH2/UxPlay.git}"
# Pin UxPlay for reproducible builds (UxPlay 1.74). Override with UXPLAY_REF=...
UXPLAY_REF="${UXPLAY_REF:-28ed70a9876fe3f5864479f4e0d07abe4678383a}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PKG="$WORK/airplay-receiver_${VERSION}_all"
mkdir -p "$PKG/DEBIAN" \
         "$PKG/usr/bin" \
         "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/scalable/apps" \
         "$PKG/usr/share/airplay-receiver"

echo "• Fetching UxPlay ($UXPLAY_REF)…"
git clone --quiet "$UXPLAY_REPO" "$WORK/UxPlay"
git -C "$WORK/UxPlay" checkout --quiet "$UXPLAY_REF"

echo "• Applying patches…"
for p in "$REPO_ROOT"/patches/*.patch; do
  [ -e "$p" ] || continue
  git -C "$WORK/UxPlay" apply "$p" || patch -p1 -d "$WORK/UxPlay" < "$p"
  echo "  applied $(basename "$p")"
done

echo "• Staging bundled source…"
SRCDST="$PKG/usr/share/airplay-receiver/uxplay-src"
mkdir -p "$SRCDST"
git -C "$WORK/UxPlay" archive --format=tar HEAD | tar -x -C "$SRCDST"
# re-apply patches into the archived (committed) tree, since git archive uses HEAD
for p in "$REPO_ROOT"/patches/*.patch; do
  [ -e "$p" ] || continue
  git apply --directory="$SRCDST" "$p" 2>/dev/null || patch -p1 -d "$SRCDST" < "$p"
done

echo "• Staging app files…"
install -m755 "$REPO_ROOT/bin/airplay-receiver"     "$PKG/usr/bin/airplay-receiver"
install -m755 "$REPO_ROOT/bin/airplay-receiver-gui" "$PKG/usr/bin/airplay-receiver-gui"
install -m644 "$REPO_ROOT"/share/applications/*.desktop "$PKG/usr/share/applications/"
install -m644 "$REPO_ROOT/share/icons/airplay-receiver.svg" \
              "$PKG/usr/share/icons/hicolor/scalable/apps/airplay-receiver.svg"

# engine builder (offline, from bundled source)
cat > "$PKG/usr/share/airplay-receiver/build-engine.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SRC="/usr/share/airplay-receiver/uxplay-src"
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/airplay-uxplay-build.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
cmake -B "$BUILD" -S "$SRC" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD" -j "$(nproc)"
$SUDO cmake --install "$BUILD"
$SUDO ldconfig || true
hash -r 2>/dev/null || true
echo "UxPlay engine installed (/usr/local/bin/uxplay): $(/usr/local/bin/uxplay -v 2>/dev/null || true)"
EOF
chmod 755 "$PKG/usr/share/airplay-receiver/build-engine.sh"

cat > "$PKG/usr/bin/airplay-build-uxplay" <<'EOF'
#!/usr/bin/env bash
exec /usr/share/airplay-receiver/build-engine.sh "$@"
EOF
chmod 755 "$PKG/usr/bin/airplay-build-uxplay"

echo "• Writing control + maintainer scripts…"
INSTALLED_KB=$(du -sk "$PKG" | cut -f1)
cat > "$PKG/DEBIAN/control" <<EOF
Package: airplay-receiver
Version: $VERSION
Architecture: all
Maintainer: AirPlay Receiver for Linux contributors
Installed-Size: $INSTALLED_KB
Depends: python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1,
 gstreamer1.0-plugins-base, gstreamer1.0-plugins-good,
 gstreamer1.0-plugins-bad, gstreamer1.0-libav, gstreamer1.0-vaapi,
 avahi-daemon, cmake, build-essential, git, libssl-dev, libplist-dev,
 libavahi-compat-libdnssd-dev, libgstreamer1.0-dev,
 libgstreamer-plugins-base1.0-dev
Section: video
Priority: optional
Homepage: https://github.com/OWNER/airplay-receiver-linux
Description: AirPlay receiver for Linux (GUI + CLI over UxPlay)
 Mirror an iPhone, iPad or Mac to this computer over AirPlay. Provides a
 GTK4/libadwaita app and a friendly command-line wrapper, and builds and
 installs a current, patched UxPlay engine (double-click fullscreen) on
 install. Tuned for Pop!_OS COSMIC; works on GNOME and other desktops.
EOF

cat > "$PKG/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    update-desktop-database -q /usr/share/applications 2>/dev/null || true
    gtk-update-icon-cache -q -t /usr/share/icons/hicolor 2>/dev/null || true
    systemctl enable --now avahi-daemon 2>/dev/null || true
    ver=$(/usr/local/bin/uxplay -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)
    need=1
    if [ -n "$ver" ]; then
        maj=${ver%%.*}; min=${ver#*.}
        if [ "$maj" -gt 1 ] 2>/dev/null; then need=0; fi
        if [ "$maj" -eq 1 ] 2>/dev/null && [ "$min" -ge 74 ] 2>/dev/null; then need=0; fi
    fi
    if [ "$need" -eq 1 ]; then
        echo "airplay-receiver: building the UxPlay engine (one-time, ~1-2 min)..."
        if /usr/share/airplay-receiver/build-engine.sh; then
            echo "airplay-receiver: engine ready."
        else
            echo "airplay-receiver: engine build failed. Run 'sudo airplay-build-uxplay' to retry." >&2
        fi
    else
        echo "airplay-receiver: UxPlay $ver already present (>= 1.74); engine build skipped."
    fi
fi
exit 0
EOF
chmod 755 "$PKG/DEBIAN/postinst"

cat > "$PKG/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
# On purge, remove the engine we built into /usr/local (not tracked by dpkg).
if [ "$1" = "purge" ]; then
    rm -f /usr/local/bin/uxplay /usr/local/bin/uxplay-beacon.py \
          /usr/local/bin/uxplay_beacon_module_*.py \
          /usr/local/share/man/man1/uxplay.1 \
          /usr/local/share/man/man1/uxplay-beacon.1 2>/dev/null || true
    rm -rf /usr/local/share/doc/uxplay 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$PKG/DEBIAN/postrm"

echo "• Building .deb…"
mkdir -p "$REPO_ROOT/dist"
dpkg-deb --root-owner-group --build "$PKG" "$REPO_ROOT/dist/airplay-receiver_${VERSION}_all.deb"
echo "✔ dist/airplay-receiver_${VERSION}_all.deb"
