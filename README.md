# Dex-Linux-Workstation

[![GitHub Stars](https://img.shields.io/github/stars/thecbr600/dex-linux-workstation?style=flat&logo=github)](https://github.com/thecbr600/dex-linux-workstation/stargazers)
[![Open Issues](https://img.shields.io/github/issues/thecbr600/dex-linux-workstation?style=flat&logo=github&color=brightgreen)](https://github.com/thecbr600/dex-linux-workstation/issues)
[![Closed Issues](https://img.shields.io/github/issues-closed/thecbr600/dex-linux-workstation?style=flat&logo=github&color=blue)](https://github.com/thecbr600/dex-linux-workstation/issues?q=is%3Aissue+is%3Aclosed)
[![License](https://img.shields.io/github/license/thecbr600/dex-linux-workstation?style=flat)](https://github.com/thecbr600/dex-linux-workstation/blob/main/LICENSE)
![Platform](https://img.shields.io/badge/SoC-Snapdragon%20%7C%20MediaTek-blueviolet?style=flat&logo=android)

A robust, low-latency **Debian 13 (Trixie)** desktop environment running natively on Android via Termux, PRoot, and Termux:X11.

No VNC, no root required (Knox `0x0` intact), and full audio support. Tested and optimized for modern flagship hardware (e.g., Samsung Galaxy S25/S26 Ultra, Galaxy Tab S10 Ultra), delivering the hardware-accelerated desktop workflow the discontinued official *Linux on DeX* originally promised.

* **Proof of Concept Video:** [Watch on YouTube](https://youtu.be/3X4EliaiAoY?is=9dkTdEM-_ZWulJTe)
* **Documentation & Benchmarks:** [Project Wiki](https://github.com/thecbr600/dex-linux-workstation/wiki) | [Compatibility List](COMPATIBILITY.md)

---

## 1. Required Android APKs

Download and install the official GitHub releases (do **not** use the outdated Google Play Store builds, as mismatched signing keys break IPC between Termux and Termux:X11):

* **Termux:** [GitHub Releases](https://github.com/termux/termux-app/releases) (`termux-app_...github-debug_arm64-v8a.apk`)
* **Termux:X11:** [Nightly Releases](https://github.com/termux/termux-x11/releases/tag/nightly) (`termux-x11-universal-debug.apk`)
* **Termux:API *(optional, for benchmark telemetry)*:** [GitHub Releases](https://github.com/termux/termux-api/releases) (`termux-api-app_...github.debug.apk`)

> **Important Android Requirement:** Disable Android's **Phantom Process Killer** (*Settings > Developer options > Disable child process restrictions*) and set battery usage for **Termux** and **Termux:X11** to **Unrestricted**. See the [Android Setup Wiki](https://github.com/thecbr600/dex-linux-workstation/wiki/Android-Setup) for ADB commands and details.

---

## 2. Quick Start (2-Step Modular Installation)

Run completely in user space inside **Termux**:

### Step 1: Base System Setup
Installs Debian 13 (Trixie) with a lean XFCE4 desktop, native Termux:X11 UNIX socket rendering, and PulseAudio TCP sound:
```bash
pkg update -y && pkg install curl -y && curl -sSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh) | bash
```

### Step 2: Hardware GPU Acceleration Add-on (Universal)
Enables 3D hardware acceleration via our VirGL/virpipe bridge, updates `~/desktop` and `~/mobile`, and disables window compositing for tear-free high-resolution external displays:
```bash
curl -sSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/install-gpu.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/install-gpu.sh) | bash
```

---

## 3. Optional Add-ons

Extend your workstation after completing the base setup.

> **Tip:** If you install both **GPU Acceleration** and **Auto-Close X11**, run `autoclose.sh` **last** so the XFCE logout hook is preserved.

* **VS Code Server** — Browser-based VS Code (`code-server`) for local development:
  ```bash
  curl -fsSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/install-code-server.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/install-code-server.sh) | bash
  ```
* **Super Key Mapping** — Maps the hardware Super/Meta key to open the XFCE application menu:
  ```bash
  curl -fsSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/enable-super-key.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/enable-super-key.sh) | bash
  ```
* **Home Screen Shortcuts** *(native Termux)* — Creates 1-tap `DeX Desktop` & `DeX Mobile` icons via `Termux:Widget`:
  ```bash
  curl -fsSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/shortcuts.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/shortcuts.sh) | bash
  ```
* **Auto-Close X11 on Logout** *(native Termux)* — Closes `Termux:X11` and background services automatically when logging out of XFCE:
  ```bash
  curl -fsSL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/autoclose.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/autoclose.sh) | bash
  ```

---

## 4. Deep Dive, Benchmarks & Architecture

All technical documentation, telemetry charts, and troubleshooting guides live in the **[Project Wiki](https://github.com/thecbr600/dex-linux-workstation/wiki)**:

* **[Android Setup & Prerequisites](https://github.com/thecbr600/dex-linux-workstation/wiki/Android-Setup)** — Phantom Process Killer, battery settings, and `Termux:Widget` setup.
* **[Architecture & Stack](https://github.com/thecbr600/dex-linux-workstation/wiki/Architecture)** — PulseAudio TCP bridge, X11 UNIX sockets, and our LMK-safe Chromium wrapper.
* **[Hardware & Benchmarks](https://github.com/thecbr600/dex-linux-workstation/wiki/Hardware-and-Benchmarks)** — Snapdragon 8 Elite vs. MediaTek Dimensity 9300+ (`glmark2`), 32-minute soak test telemetry, and full Redis source build verification.
* **[Troubleshooting & FAQ](https://github.com/thecbr600/dex-linux-workstation/wiki/Troubleshooting-and-FAQ)** — Common PRoot constraints, VPN routing, and CDN cache tips.

---

## 5. Scope & Support Policy

This project is an opinionated blueprint for desktop-replacement workflows on **modern flagship mobile hardware**:

* **Hardware Baseline:** Modern ARM64 flagship SoC (Snapdragon 8 Gen series, MediaTek Dimensity 9000+ series), **12 GB+ RAM** (16 GB recommended), and **UFS 3.1 / 4.0** storage.
* **No Legacy / Budget Support:** Issues regarding performance on sub-spec or legacy devices will be closed without triage.
* **Debian 13 (Trixie) Only:** Alternate distributions (Ubuntu, Arch, Kali) are out of scope.
* **Contributing:** PRs and technical discussions around `virglrenderer` IPC overhead, `seccomp`/PRoot optimizations, and automated storage sync (`rclone`) are welcome.
