# Dex-Linux-Workstation

A robust, low-latency Debian 13 (Trixie) desktop environment running natively on Android via Termux, PRoot, and Termux-X11. 

No VNC, no root required, and full audio support. Tested and optimized for modern flagship hardware (e.g., Samsung Galaxy S25/S26 Ultra, Galaxy Tab S10 Ultra), this project demonstrates a seamless, hardware-accelerated Linux desktop experience—achieving what the defunct official Linux on DeX project originally promised.

**Proof of Concept Video:** [Watch on YouTube](https://youtu.be/3X4EliaiAoY?is=9dkTdEM-_ZWulJTe)

---

## Quick Start (2-Step Modular Installation)

Run completely in user space via **Termux** (Ensure you installed Termux from F-Droid or GitHub Releases, *not* Google Play).

### Step 1: Base System Setup
Sets up a lean, low-latency Debian 13 (Trixie) XFCE desktop environment with native Termux-X11 rendering and synchronized PulseAudio TCP sound:

```bash
pkg update -y && pkg install curl -y && curl -sSL https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh | bash
```

### Step 2: Hardware GPU Acceleration Add-on (Universal)
Enables full 3D hardware acceleration via our automated VirGL/virpipe bridge. Automatically updates start scripts (`~/desktop` and `~/mobile`) and disables window compositing for tear-free 1440p/4K external display workflows:

```bash
curl -sSL https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/install-gpu.sh | bash
```

---

## Validated Hardware Architecture (Hardware-Agnostic GPU)

Unlike traditional setups relying strictly on Qualcomm Turnip/Zink drivers, this stack operates hardware-agnostically across different mobile GPU architectures via an optimized Android EGL/VirGL bridge.

| Metric | Qualcomm Snapdragon 8 Elite | MediaTek Dimensity 9300+ |
| :--- | :--- | :--- |
| **GPU Architecture** | Adreno 840 | ARM Immortalis-G720 MC12 |
| **Validated Device** | Samsung Galaxy S25/S26 Ultra | Samsung Galaxy Tab S10 Ultra |
| **glmark2 Score** | **186 FPS** (Uncapped) | **112 FPS** (120Hz Surface Sync) |
| **Average FrameTime** | ~5.0 ms | ~8.3 ms |
| **3D Engine Test** | Native 3D / Neverball / 1440p MPV | Native 3D / Stable TBDR Pipeline |

---

## Real-World Efficiency & Battery Benchmarks

A common criticism of running full desktop environments on mobile devices is aggressive battery drain and thermal throttling. We profiled the complete stack on a **Samsung Galaxy S26 Ultra** (Snapdragon 8 Elite, 5,000 mAh battery) under real-world daily driver conditions.

To push efficiency to the absolute limit, all tests were conducted with Android’s system-level **Power Saver Mode enabled (CPU hard-capped at 70%)**.

| Metric | Profiled Value | Operational Context |
| :--- | :--- | :--- |
| **Active Mixed Workflow** | **~3.4% / hour** (~170 mA / 0.65W) | Alternating between Android apps & desktop tasks (Terminal, Chromium, XFCE) |
| **Background Standby Idle** | **~1.0 - 1.5% / hour** (~60-80 mA) | Termux-X11, VirGL socket & PulseAudio actively running in background (Display off) |
| **Thermal Profile** | **Hand-warm (<35°C)** | Zero chassis hotspots; passive cooling remains fully effective |
| **Estimated Working Runtime** | **25+ hours** | Continuous mixed operation on a single 100% battery charge |

### Why It Runs So Cool
* **Hardware Offloading vs. CPU Brute-Force:** Traditional mobile Linux setups rely on CPU software rasterizers (`llvmpipe`), pegging high-power Prime Cores at 100%. The VirGL bridge offloads drawing primitives directly to the mobile GPU's dedicated rasterizer pipelines, leaving the CPU in low-power idle states.
* **Passive Socket Polling:** Termux-X11 and the VirGL daemon communicate over UNIX sockets utilizing standard Linux `epoll`/`poll` mechanisms. When the display is idle or the screen is turned off, IPC threads block cleanly—preventing aggressive wake-lock loops and allowing the Android kernel to gate inactive cores.

---

## Crucial Step: Disable Android Child Process Restrictions

Starting with Android 12, Google enforces an aggressive **Phantom Process Killer** that limits background child processes to a maximum of 32. Heavy multitasking (multiple Chromium tabs, compilers, background services) will inevitably trigger this kill-switch if left unconfigured.

To ensure permanent container stability, disable this limit:

### Method 1: Developer Options (Recommended for One UI)
1. Navigate to **Settings** > **Developer options**.
2. Scroll to the **Apps** section.
3. Enable **Disable child process restrictions**.
4. Set the **Battery** usage for both **Termux** and **Termux-X11** to **Unrestricted**.

### Method 2: ADB Shell (One-time command)
If the toggle is not visible on your build, run this command once via ADB:

```bash
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell settings put global settings_enable_monitor_phantom_procs false
```

---

## The Stack

* **OS Environment:** Android (Samsung One UI)
* **Container:** PRoot via `proot-distro`
* **Linux Distribution:** Debian 13 (Trixie) arm64
* **Display Protocol:** Termux-X11 / XFCE4
* **Audio Routing:** PulseAudio (TCP Module)

### Key Advantages Over Traditional Methods
* **Debian 13 (Trixie):** Built on the modern testing branch. Offers up-to-date packages and security standards, moving past the aging Debian 11/12 builds typically found in mobile setups.
* **Termux-X11 Display Server:** We bypass VNC completely. Termux-X11 renders directly using Android's native graphics layers, eliminating input lag and choppy frame rates.
* **PulseAudio TCP Bridge:** Sound works out-of-the-box via a local network bridge, allowing synchronized audio playback in browser and desktop apps.
* **Zero Root / Knox-Friendly:** Runs entirely in user space. Your device warranty remains intact and security mechanisms like Samsung Knox are completely untouched.

---

## Core Implementation Details

### 1. Audio Routing via TCP
To get native sound from the PRoot container to the Android host, we use a TCP bridge in Termux before booting the container:
```bash
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
```
Inside Debian, the `PULSE_SERVER` environment variable is simply set to `127.0.0.1`.

### 2. Chromium Wrapper Script (Hardware & RAM Optimization)
Running Chromium in a PRoot container typically results in sandbox crashes or massive memory leaks. We utilize a custom wrapper located at `/usr/local/bin/chromium` to intercept the standard XFCE menu shortcut. This applies all necessary memory limits and display flags silently:

```bash
#!/bin/bash 
exec /usr/lib/chromium/chromium \
  --no-sandbox \
  --test-type \
  --disable-dev-shm-usage \
  --ozone-platform=x11 \
  --disable-gpu \
  --disable-software-rasterizer \
  --no-default-browser-check \
  --disable-background-networking \
  --disable-component-update \
  --disable-pings \
  --media-router=0 \
  --renderer-process-limit=2 \
  --js-flags="--max-old-space-size=512" \
  --disk-cache-size=1048576 \
  --media-cache-size=1048576 \
  "$@"
```
*Note: The `--test-type` flag suppresses the standard `--no-sandbox` yellow warning bar, keeping the UI entirely clean for daily driving.*

---

## Scope & Support Policy

This project is an opinionated proof-of-concept and deployment blueprint designed to demonstrate true desktop replacement capabilities on **modern flagship mobile hardware**. 

### Hardware Baseline
- **SoC:** Modern ARM64 flagship architecture (Snapdragon 8 Gen series, MediaTek Dimensity 9000 series, or equivalent).
- **RAM:** Minimum 12 GB (16 GB strongly recommended for multitasking).
- **Storage:** UFS 3.1 / UFS 4.0 storage (PRoot container performance scales heavily with random I/O).

### Non-Negotiable Support Boundaries
- **No Legacy / Budget Device Support:** We will not triage, optimize, or provide personal troubleshooting for low-tier, budget, or legacy hardware. Issues regarding performance drops on sub-spec hardware will be closed without debate.
- **Debian 13 (Trixie) Only:** This repository focuses strictly on a hardened, stable Debian baseline. Requests to port or debug alternate distributions (Ubuntu, Arch, Kali, etc.) are out of scope. If you want a different distro, feel free to fork the codebase.
- **Not a General Help Desk:** GitHub Issues are strictly reserved for reproducible bugs in the deployment script and environment architecture—not general Linux command-line tutoring.

---

## Contributing

Pull requests and technical discussions are explicitly encouraged around:
1. **Hardware-Accelerated Rendering (GPU):** Further optimizing `virglrenderer` bridges or reducing IPC overhead.
2. **PRoot Overhead Reduction:** Syscall filtering, seccomp optimizations, and native IO speedups.
3. **Background Storage Sync:** Native, low-overhead sync routines (e.g., automated `rclone bisync` daemon configurations).

Feel free to open issues or submit pull requests if you find ways to further push the boundaries of mobile workstation architecture.
