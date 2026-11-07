proof of concept video here:

https://youtu.be/3X4EliaiAoY?is=9dkTdEM-_ZWulJTe

Dex-Linux-Workstation

A robust, low-latency Debian 13 (Trixie) desktop environment running natively on Android via Termux, PRoot, and Termux-X11. 
No VNC, no root required, and full audio support.Tested and optimized for the Samsung Galaxy S26 Ultra (16GB RAM), this project demonstrates a seamless, hardware-accelerated Linux desktop experience—achieving what the defunct official Linux on DeX project originally promised.

Quick Start (One-Line Installer)

Ensure you have installed **Termux** (from F-Droid or GitHub Releases, *not* Google Play), then run:

pkg update -y && pkg install curl -y && curl -sL [https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh](https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/setup.sh) | bash

for Adreno GPU use this line as a add on:

curl -sSL https://raw.githubusercontent.com/thecbr600/dex-linux/main/addons/install-gpu.sh | bash

Key Advantages Over Traditional MethodsDebian 13 (Trixie): 
Built on the modern testing branch. This offers up-to-date packages and security standards, moving past the aging Debian 11/12 builds typically found in mobile setups.
Termux-X11 Display Server: We bypass VNC completely. Termux-X11 renders directly using Android's native graphics layers, eliminating input lag and choppy frame rates.PulseAudio TCP Bridge: Sound works out-of-the-box via a local network bridge, allowing synchronized audio playback in browser and desktop apps.

Zero Root / Knox-Friendly: Runs entirely in user space. Your device warranty remains intact and security mechanisms like Samsung Knox are completely untouched.

The StackComponentTechnology 
OS EnvironmentAndroid (Samsung One UI)
ContainerPRoot via proot-distro
Linux Distribution Debian 13 (Trixie)arm64
Display ProtocolTermux-X11 / XFCE4
Audio RoutingPulseAudio (TCP Module)

Core Implementation Details 

Audio Routing via TCPTo get native sound from the PRoot container to the Android host, we use a TCP bridge in Termux before booting the container:pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

Inside Debian, the PULSE_SERVER environment variable is simply set to 127.0.0.1.2. Chromium Wrapper Script (Hardware & RAM Optimization)Running Chromium in a PRoot container typically results in sandbox crashes or massive memory leaks. 
We utilize a custom wrapper located at /usr/local/bin/chromium to intercept the standard XFCE menu shortcut. 
This applies all necessary memory limits and display flags silently:
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
Note: The --test-type flag suppresses the standard --no-sandbox yellow warning bar, keeping the UI entirely clean for daily driving.

Contributing Feel free to open issues or submit pull requests if you find ways to further optimize the PRoot syscall overhead or improve hardware acceleration routing.

Scope & Support Policy

This project is an opinionated proof-of-concept and deployment blueprint designed to demonstrate true desktop replacement capabilities on **modern flagship mobile hardware**. 

Hardware Baseline

* **SoC:** Modern ARM64 flagship architecture (Snapdragon 8 Gen series or equivalent).
* **RAM:** Minimum 12 GB (16 GB strongly recommended for multitasking).
* **Storage:** UFS 3.1 / UFS 4.0 storage (PRoot container performance scales heavily with random I/O).

Non-Negotiable Support Boundaries

* **No Legacy / Budget Device Support:** We will not triage, optimize, or provide personal troubleshooting for low-tier, budget, or legacy hardware. Issues regarding performance drops on sub-spec hardware will be closed without debate.
* **Debian 13 (Trixie) Only:** This repository focuses strictly on a hardened, stable Debian baseline. Requests to port or debug alternate distributions (Ubuntu, Arch, Kali, etc.) are out of scope. If you want a different distro, feel free to fork the codebase.
* **Not a General Help Desk:** GitHub Issues are strictly reserved for reproducible bugs in the deployment script and environment architecture—not general Linux command-line tutoring.

High-Impact Contributions Welcome

Pull requests and technical discussions are explicitly encouraged around:
1. **Hardware-Accelerated Rendering (GPU):** Integrating Mesa Turnip/Zink (Vulkan-to-OpenGL translation) or `virglrenderer` bridges to offload desktop rendering from the CPU to the Adreno GPU.
2. **PRoot Overhead Reduction:** Syscall filtering, seccomp optimizations, and native IO speedups.
3. **Background Storage Sync:** Native, low-overhead sync routines (e.g., automated `rclone bisync` daemon configurations).

## ⚠️ Crucial Step: Disable Android Child Process Restrictions

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
