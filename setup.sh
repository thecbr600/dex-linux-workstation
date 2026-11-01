#!/bin/bash
set -e

# Verhindert Deep-Sleep während der Installation
termux-wake-lock

echo "===================================================="
echo "  DeX Linux Workstation: Schlüsselfertiger Installer "
echo "  Stabile PRoot/XFCE-Umgebung für ARM64 (Android)  "
echo "===================================================="

echo "[1/5] Aktualisiere Termux-Host & installiere Kernpakete..."
pkg update -y
pkg install x11-repo -y
pkg install termux-x11-nightly pulseaudio proot-distro -y

echo "[2/5] Installiere sauberes Debian 12 (Bookworm)..."
proot-distro install debian

echo "[3/5] Installiere XFCE4 & Produktivitäts-Apps (ohne Plank)..."
proot-distro login debian -- bash -c "apt update -y && apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies chromium gimp libreoffice mpv dbus-x11 sudo wget curl"

echo "[4/5] Konfiguriere Audio-Bridge & Chromium Enterprise-Policy..."
# Debian Audio-Client fest auf lokalen TCP-Port 4713 verdrahten
proot-distro login debian -- bash -c "mkdir -p /etc/pulse && echo 'default-server = tcp:127.0.0.1:4713' > /etc/pulse/client.conf"

# Chromium Enterprise-Policy: Entfernt Infobar dauerhaft ohne Beeinträchtigung von Google-Logins
proot-distro login debian -- bash -c '
mkdir -p /etc/chromium/policies/managed /etc/chromium-browser/policies/managed
echo "{\"CommandLineFlagSecurityWarningsEnabled\": false}" > /etc/chromium/policies/managed/hide_warning.json
cp /etc/chromium/policies/managed/hide_warning.json /etc/chromium-browser/policies/managed/hide_warning.json
'

# Chromium CPU-Rendering-Wrapper scharfstellen
proot-distro login debian -- bash -c 'if [ ! -f /usr/bin/chromium.real ]; then mv /usr/bin/chromium /usr/bin/chromium.real; fi && echo -e "#!/bin/bash\nexec /usr/bin/chromium.real --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage \"\$@\"" > /usr/bin/chromium && chmod +x /usr/bin/chromium'

echo "[5/5] Generiere Startskripte mit robuster Lockfile-Bereinigung..."

# 1. Desktop-Starter (~/desktop)
cat << 'INNER_EOF' > ~/desktop
#!/bin/bash
pkill -9 -f termux-x11 2>/dev/null
pkill -9 -f pulseaudio 2>/dev/null
rm -rf $PREFIX/tmp/.X11-unix $PREFIX/tmp/.X*-lock $PREFIX/tmp/pulse-* 2>/dev/null

pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
termux-x11 :0 &
sleep 2

proot-distro login debian --shared-tmp -- bash -c "export PULSE_SERVER=tcp:127.0.0.1:4713; export DISPLAY=:0; dbus-launch --exit-with-session startxfce4"
INNER_EOF
chmod +x ~/desktop

# 2. Mobile-Starter (~/mobile mit Display-Skalierung)
cat << 'INNER_EOF' > ~/mobile
#!/bin/bash
pkill -9 -f termux-x11 2>/dev/null
pkill -9 -f pulseaudio 2>/dev/null
rm -rf $PREFIX/tmp/.X11-unix $PREFIX/tmp/.X*-lock $PREFIX/tmp/pulse-* 2>/dev/null

pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
termux-x11 :0 -dpi 240 &
sleep 2

proot-distro login debian --shared-tmp -- bash -c "export PULSE_SERVER=tcp:127.0.0.1:4713; export DISPLAY=:0; dbus-launch --exit-with-session startxfce4"
INNER_EOF
chmod +x ~/mobile

echo "===================================================="
echo "✅ Installation erfolgreich abgeschlossen!"
echo "Starte DeX / externer Monitor: ./desktop"
echo "Starte Tablet- / Phone-Display: ./mobile"
echo "===================================================="

