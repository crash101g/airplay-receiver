# Credits & Attribution

**AirPlay Receiver for Linux** is a GUI/CLI front-end and packaging layer. It
does **not** implement the AirPlay protocol itself — the heavy lifting is done
by **UxPlay**, which this project builds, patches, and bundles.

## UxPlay
- Project: https://github.com/FDH2/UxPlay
- License: GNU GPL v3
- UxPlay is derived from **RPiPlay** (https://github.com/FD-/RPiPlay), which in
  turn builds on shairplay, AirplayServer and years of community reverse
  engineering of the AirPlay / RAOP protocols.

This project pins a specific UxPlay release and applies the patches in
[`patches/`](patches/) (currently: double-click-to-fullscreen on the X11 video
window). All of UxPlay's copyright and licensing is retained in the bundled
source and installed documentation.

## This project
- The GTK4/libadwaita app (`airplay-receiver-gui`), the CLI wrapper
  (`airplay-receiver`), the packaging, and the patches are licensed under the
  **GNU GPL v3** to remain compatible with UxPlay.

## Trademarks
AirPlay®, iPhone®, iPad®, and Mac® are trademarks of Apple Inc. This project is
an independent, community effort and is **not affiliated with, authorized, or
endorsed by Apple Inc.** "AirPlay" is used only to describe compatibility.
