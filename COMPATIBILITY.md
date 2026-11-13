# Tested & Supported Devices

This list tracks Samsung Galaxy devices (and other Android hardware) verified to work with **DeX Linux Workstation**.

> **Want to add your device?**  
> If you have successfully run `setup.sh` on your device, feel free to open a Pull Request or an Issue with your device details!

## Verified Hardware

| Device | SoC / GPU | DeX Mode | Status | Tested Add-ons & Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Samsung Galaxy S26 Ultra** | Qualcomm Snapdragon (Adreno) | Wired & Wireless | ✅ Verified | Full workstation setup, GPU acceleration, `code-server`, benchmark suite |
| **Samsung Galaxy Tab S10 Ultra** | MediaTek Dimensity 9300+ (Immortalis-G720) | On-Device & External | ✅ Verified | Base setup + GPU extension verified; 30m / 5h thermal benchmarks in progress |

## Hardware Requirements

To ensure a smooth desktop experience without Android's Low Memory Killer (LMK) terminating background sessions, devices should meet the following baseline:

- **Architecture:** `aarch64` / `arm64-v8a` (Android 12+)
- **RAM:** **12 GB minimum** (16 GB+ recommended for heavy browser, IDE, and multi-container workloads)
- **Storage:** ~6–8 GB free internal space for Termux, Debian/Ubuntu PRoot, and desktop packages
- **Apps:** Official GitHub builds of **Termux** and **Termux:X11** (see `README.md`)

## Contribution Template

Copy and paste this row when submitting a Pull Request:

```markdown
| **Device Name** | SoC (GPU) | Wired / Wireless / Tablet | ✅ Verified | Notes (e.g. Android version, add-ons used) |