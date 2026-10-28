#!/usr/bin/env bash
#
# reinstall.sh — update uxplay-easy in place from a freshly downloaded tarball.
#
# Finds the newest uxplay-easy*.tar.gz in your Downloads folder, clears any old
# extracted copy, unpacks it, and runs its install.sh. After the first install
# this is also available anywhere as the command:  airplay-update
#
# Usage:
#   airplay-update                 # look in ~/Downloads/appleairplay-uxplay
#   airplay-update /path/to/dir    # look in a different folder
#
set -euo pipefail

info() { printf '\033[36m•\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

DL="${1:-$HOME/Downloads/appleairplay-uxplay}"
[ -d "$DL" ] || die "folder not found: $DL (pass the folder holding the tarball as an argument)"

# Newest matching tarball (handles 'uxplay-easy (1).tar.gz' etc.)
tarball="$(ls -t "$DL"/uxplay-easy*.tar.gz 2>/dev/null | head -1 || true)"
[ -n "$tarball" ] || die "no uxplay-easy*.tar.gz found in $DL"
info "Using $tarball"

cd "$DL"
rm -rf uxplay-easy
tar xzf "$tarball"
[ -f uxplay-easy/install.sh ] || die "install.sh missing after extract — bad tarball?"

cd uxplay-easy
info "Running install.sh…"
exec ./install.sh
