📱 Dex-Linux-Workstation

A robust, low-latency Debian 13 (Trixie) desktop environment running natively on Android via Termux, PRoot, and Termux-X11. 
No VNC, no root required, and full audio support.Tested and optimized for the Samsung Galaxy S26 Ultra (16GB RAM), this project demonstrates a seamless, hardware-accelerated Linux desktop experience—achieving what the defunct official Linux on DeX project originally promised.

🎥 Video ProofWatch the Unedited Screen Capture on YouTube --> https://www.youtube.com/watch?v=_Ej4hRKVolw  (Demonstrates a cold boot from the Termux terminal, live YouTube music streaming via Chromium, and multitasking with GIMP and LibreOffice at 60 FPS)

🚀 Key Advantages Over Traditional MethodsDebian 13 (Trixie): Built on the modern testing branch. This offers up-to-date packages and security standards, moving past the aging Debian 11/12 builds typically found in mobile setups.
Termux-X11 Display Server: We bypass VNC completely. Termux-X11 renders directly using Android's native graphics layers, eliminating input lag and choppy frame rates.PulseAudio TCP Bridge: Sound works out-of-the-box via a local network bridge, allowing synchronized audio playback in browser and desktop apps.

Zero Root / Knox-Friendly: Runs entirely in user space. Your device warranty remains intact and security mechanisms like Samsung Knox are completely untouched.

🛠️ The StackComponentTechnology UsedOS EnvironmentAndroid (Samsung One UI)ContainerPRoot via proot-distroLinux DistributionDebian 13 (Trixie) arm64Display ProtocolTermux-X11 / XFCE4Audio RoutingPulseAudio (TCP Module)

⚙️ Core Implementation Details1. Audio Routing via TCPTo get native sound from the PRoot container to the Android host, we use a TCP bridge in Termux before booting the container:pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

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

🤝 ContributingFeel free to open issues or submit pull requests if you find ways to further optimize the PRoot syscall overhead or improve hardware acceleration routing.
