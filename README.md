<div align="center">

# 📺 AirPlay Receiver for Linux

### Turn your Linux PC into an AirPlay receiver — mirror your iPhone, iPad, or Mac to the big screen.

A clean GTK4 app **and** a friendly command line, powered by a patched, up-to-date [UxPlay](https://github.com/FDH2/UxPlay) engine. One-command install. No cloud, no account, no dongle.

![version](https://img.shields.io/badge/version-1.7.0-blue)
![license](https://img.shields.io/badge/license-GPLv3-green)
![platform](https://img.shields.io/badge/platform-Linux-informational)
![desktop](https://img.shields.io/badge/Pop!__OS%20COSMIC-tested-success)

</div>

---

## ✨ What it does

Mirror an **iPhone, iPad, or Mac** screen (with audio) onto your Linux computer over your local Wi-Fi — the same way you'd AirPlay to an Apple TV. Great for a living-room HTPC, a conference-room display, or just showing something on a bigger screen without cables.

- 🪞 **Screen mirroring** with audio, over standard AirPlay
- 🔊 **Audio-only mode** — stream music/podcasts to your PC's speakers, no window
- 🖥️ **True fullscreen TV mode** — **double-click** the window (or press **F11** / **left-Alt+Enter**) for a borderless, black-background picture
- 🔒 **Optional password** — require a password before any device can cast
- 🏷️ **Clean device name** — shows a name you choose, not your computer's hostname
- 🖱️ **Two ways to use it** — a point-and-click app *and* a scriptable CLI
- 📦 **Self-contained** — bundles and builds a current, patched UxPlay engine; no hunting for the right version

> **Why not just install UxPlay from your distro?** Distro packages are often **years out of date** and fail to mirror from recent iPhones/iOS (you get an `invalid ntp_time` error and no video). This project builds a **current, patched** engine for you automatically.

---

## 🖼️ The app

A native **GTK4 / libadwaita** app that fits right into Pop!_OS COSMIC and GNOME:

- **Display name** — what shows up on your Apple device
- **Mode** — *Open* (no password), *Password required*, or *Audio only*
- **Video output** — a resizable window (recommended) or the Wayland-native sink
- **Start / Stop**, with a live activity log and the fullscreen shortcut right there

Prefer the terminal? `airplay-receiver open` and you're live.

---

## 💻 Supported systems

| System | Status |
|---|---|
| **Pop!_OS 24.04 (COSMIC)** | ✅ Primary target, fully tested |
| **Ubuntu 24.04 / 22.04** | ✅ Expected to work (same `.deb`) |
| **Debian 12+** | ✅ Expected to work (same `.deb`) |
| Linux Mint, Zorin, other Ubuntu derivatives | ✅ Expected to work |
| Fedora / Arch / openSUSE | ⚙️ Not packaged yet — run from source (see below) |
| macOS / Windows | ❌ Use upstream [UxPlay](https://github.com/FDH2/UxPlay) directly |

Works on both **Wayland** (including COSMIC) and **X11** sessions. Fullscreen-by-double-click/F11 uses the X11 video window (the default output; works fine under XWayland on Wayland desktops).

**You'll need:** a GStreamer-capable GPU/driver (any normal desktop install has this) and your PC + Apple device on the **same Wi-Fi network**.

---

## 🚀 Install

### Debian / Ubuntu / Pop!_OS — the `.deb` (recommended)

Download the latest `airplay-receiver_*.deb` from the [Releases](../../releases) page, then:

```bash
sudo apt install ./airplay-receiver_1.7.0_all.deb
```

That's it. `apt` pulls the dependencies, and the package **compiles and installs the bundled UxPlay engine on first install** (a one-time ~1–2 minute build — that's why the build toolchain is listed as a dependency). When it finishes, look for **AirPlay Receiver** in your app launcher.

> The engine is installed to `/usr/local/bin/uxplay`. If you have an old distro `uxplay` (1.68.x), you can remove it with `sudo apt remove uxplay` — this package doesn't use it.

### Any Linux — from source

```bash
git clone https://github.com/OWNER/airplay-receiver-linux.git
cd airplay-receiver-linux
./scripts/install.sh      # installs the app to ~/.local and offers to build the engine
```

Or build the engine yourself at any time:

```bash
./scripts/build-uxplay.sh
```

### Build the `.deb` yourself

```bash
./packaging/build-deb.sh          # → dist/airplay-receiver_<version>_all.deb
```

---

## 🎮 Using it

1. Launch **AirPlay Receiver** (app grid) or run `airplay-receiver-gui`.
2. Pick a **Mode** (Open is fine on a home network) and press **Start**.
3. On your iPhone/iPad/Mac: open **Screen Mirroring** and choose the name you set.
4. Once your screen appears, **double-click** the window (or **F11**) for fullscreen.

> 📱 A phone held in **portrait** mirrors as a tall, narrow image with black bars — that's correct. Rotate to **landscape** (or play a video) to fill the screen.

### CLI quick reference

```bash
airplay-receiver            # open mode (no password)
airplay-receiver locked PW  # require password "PW"
airplay-receiver audio      # audio only, no window
airplay-receiver tv         # reminder: double-click / F11 to go fullscreen
airplay-receiver status     # is a receiver running?
airplay-receiver stop       # stop it
airplay-receiver --version
```

---

## 🔐 Security notes

AirPlay receivers are **network servers**. This one is **unauthenticated by default** (anyone on your network can cast), which is convenient at home but not for untrusted networks.

- Use **Password required** mode if others share your network.
- Keep it on a **trusted LAN**; don't expose it to the open internet.
- Discovery uses **mDNS** (UDP 5353); the control/stream ports are opened by UxPlay.

See [CREDITS.md](CREDITS.md) for the underlying engine and its own security posture.

---

## 🗑️ Uninstall

```bash
sudo apt remove airplay-receiver          # remove the app
sudo apt purge  airplay-receiver          # also remove the built engine in /usr/local
```

From a source install: delete `~/.local/bin/airplay-receiver*`, the `.desktop` files in `~/.local/share/applications`, and `/usr/local/bin/uxplay` if you built the engine.

---

## 🧯 Troubleshooting

| Symptom | Fix |
|---|---|
| Device doesn't see the receiver | Check firewall allows **mDNS (UDP 5353)**; `systemctl status avahi-daemon` |
| Connects, then `invalid ntp_time` and no video | Old UxPlay — run `sudo airplay-build-uxplay` to install the current engine |
| Mirror window won't go fullscreen | Use the **Resizable window (X11)** output; then **double-click** / **F11** |
| Picture is a narrow strip | Portrait phone — rotate to landscape |
| `Fontconfig error … out of memory` on launch | Harmless system warning; `fc-cache -rf` clears it |

---

## 🙌 Credits

This is a front-end and packaging layer. The actual AirPlay implementation is **[UxPlay](https://github.com/FDH2/UxPlay)** (GPLv3), derived from **[RPiPlay](https://github.com/FD-/RPiPlay)** and years of community reverse-engineering. Please star and support them. Full attribution in [CREDITS.md](CREDITS.md).

## 📄 License

**GNU GPL v3** — see [LICENSE](LICENSE). This project is GPLv3 to stay compatible with UxPlay.

## ⚖️ Trademarks

AirPlay®, iPhone®, iPad®, and Mac® are trademarks of Apple Inc. This project is independent and **not affiliated with or endorsed by Apple Inc.**; "AirPlay" is used only to describe compatibility.
