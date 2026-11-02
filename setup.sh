#!/bin/bash
set -e

# Prevent deep sleep during setup
termux-wake-lock

echo "===================================================="
echo "  DeX Linux Workstation: Turnkey Installer          "
echo "  Stable PRoot/XFCE Environment for ARM64 (Android) "
echo "===================================================="

echo "[1/5] Updating Termux host & installing core packages..."
pkg update -y
pkg install x11-repo -y
pkg install termux-x11-nightly pulseaudio proot-distro -y

echo "[2/5] Installing Debian 13 (Trixie / Current)..."
proot-distro install debian

echo "[3/5] Installing XFCE4 & productivity apps..."
proot-distro login debian -- bash -c "apt update -y && apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies chromium gimp libreoffice mpv dbus-x11 sudo wget curl"

echo "[4/5] Configuring PulseAudio TCP bridge & Chromium policies..."
# Route container audio to local TCP port 4713
proot-distro login debian -- bash -c "mkdir -p /etc/pulse && echo 'default-server = tcp:127.0.0.1:4713' > /etc/pulse/client.conf"

# Chromium Enterprise Policy: permanently suppress the no-sandbox warning banner
proot-distro login debian -- bash -c '
mkdir -p /etc/chromium/policies/managed /etc/chromium-browser/policies/managed
echo "{\"CommandLineFlagSecurityWarningsEnabled\": false}" > /etc/chromium/policies/managed/hide_warning.json
cp /etc/chromium/policies/managed/hide_warning.json /etc/chromium-browser/policies/managed/hide_warning.json
'

# Chromium CPU rendering wrapper setup
proot-distro login debian -- bash -c 'if [ ! -f /usr/bin/chromium.real ]; then mv /usr/bin/chromium /usr/bin/chromium.real; fi && echo -e "#!/bin/bash\nexec /usr/bin/chromium.real --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage \"\$@\"" > /usr/bin/chromium && chmod +x /usr/bin/chromium'

echo "[5/5] Generating launch scripts with lockfile cleanup..."

# 1. Desktop launcher (~/desktop)
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

# 2. Mobile launcher (~/mobile with display scaling)
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
echo "✅ Setup finished successfully!"
echo "Run for DeX / External Monitor: ./desktop"
echo "Run for Mobile / Tablet Screen: ./mobile"
echo "===================================================="
