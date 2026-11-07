#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[*] thecbr600 — Initialisiere Hardware-GPU-Beschleunigung (VirGL)..."

# 1. Termux-Host: Paket für virglrenderer installieren
echo "[+] Installiere Termux-Host-Pakete..."
pkg update -y > /dev/null 2>&1 || true
pkg install -y virglrenderer-android

# 2. Debian-Container konfigurieren
echo "[+] Konfiguriere PRoot-Debian (Mesa-Treiber & Profile)..."
proot-distro login debian --shared-tmp -- bash -c '
    # Paketquellen aktualisieren und Treiber installieren
    apt update
    apt install -y mesa-utils libgl1-mesa-dri

    # Systemweites GPU-Profil anlegen
    cat << "PROFILE_EOF" > /etc/profile.d/dex-gpu.sh
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
export MESA_GLES_VERSION_OVERRIDE=3.0
export PATH="$PATH:/usr/games"
PROFILE_EOF
    chmod +x /etc/profile.d/dex-gpu.sh

    # PATH absichern
    if ! grep -q "/usr/games" ~/.bashrc; then
        echo "export PATH=\"\$PATH:/usr/games\"" >> ~/.bashrc
    fi

    # XFCE-Compositing dauerhaft deaktivieren (verhindert Vollbild-Flackern)
    if command -v xfconf-query >/dev/null 2>&1; then
        dbus-launch xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
    fi
'

# 3. Startskripte auf dem Host aktualisieren
echo "[+] Aktualisiere ~/desktop und ~/mobile mit GPU-Unterstützung..."

cat << 'EOF_MOBILE' > ~/mobile
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
pkill -f proot 2>/dev/null
pkill -f termux-x11 2>/dev/null
pkill -f pulseaudio 2>/dev/null
pkill -f virgl_test_server_android 2>/dev/null
rm -rf $TMPDIR/.X11-unix/X0 2>/dev/null
sleep 1

pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
virgl_test_server_android &>/dev/null &
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 -ac &>/dev/null &
sleep 2

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity

proot-distro login debian --shared-tmp -- bash -c '
export DISPLAY=:0
export PULSE_SERVER=tcp:127.0.0.1:4713
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
xfconf-query -c xsettings -p /Xft/DPI -s 150 2>/dev/null
dbus-launch --exit-with-session xfce4-session
'

pulseaudio --kill 2>/dev/null
pkill -f virgl_test_server_android 2>/dev/null
termux-wake-unlock
EOF_MOBILE

cat << 'EOF_DESKTOP' > ~/desktop
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
pkill -f proot 2>/dev/null
pkill -f termux-x11 2>/dev/null
pkill -f pulseaudio 2>/dev/null
pkill -f virgl_test_server_android 2>/dev/null
rm -rf $TMPDIR/.X11-unix/X0 2>/dev/null
sleep 1

pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
virgl_test_server_android &>/dev/null &
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 -ac &>/dev/null &
sleep 2

am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity

proot-distro login debian --shared-tmp -- bash -c '
export DISPLAY=:0
export PULSE_SERVER=tcp:127.0.0.1:4713
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
xfconf-query -c xsettings -p /Xft/DPI -s 96 2>/dev/null
dbus-launch --exit-with-session xfce4-session
'

pulseaudio --kill 2>/dev/null
pkill -f virgl_test_server_android 2>/dev/null
termux-wake-unlock
EOF_DESKTOP

chmod +x ~/mobile ~/desktop

echo "======================================================="
echo "[✓] GPU-Add-on erfolgreich installiert und konfiguriert!"
echo "    Starte deine Session neu mit ./desktop oder ./mobile"
echo "======================================================="
