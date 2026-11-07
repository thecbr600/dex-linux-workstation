```bash
cat << 'EOF' > ~/install-gpu.sh
#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[*] thecbr600 — Initialisiere Hardware-GPU-Beschleunigung (VirGL)..."

# 1. Termux-Host: Paket für virglrenderer installieren
echo "[+] Prüfe Termux-Host-Pakete..."
pkg update -y > /dev/null 2>&1
pkg install -y virglrenderer-android

# 2. Debian-Container konfigurieren
echo "[+] Konfiguriere PRoot-Debian (Mesa-Treiber & Profile)..."
proot-distro login debian --shared-tmp -- bash -c '
    # Paketquellen aktualisieren und Treiber installieren
    apt update -y
    apt install -y mesa-utils libgl1-mesa-dri

    # Systemweites GPU-Profil anlegen
    cat << "PROFILE_EOF" > /etc/profile.d/dex-gpu.sh
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
export MESA_GLES_VERSION_OVERRIDE=3.0
export PATH="$PATH:/usr/games"
PROFILE_EOF
    chmod +x /etc/profile.d/dex-gpu.sh

    # PATH auch für Root-Shells absichern
    if ! grep -q "/usr/games" ~/.bashrc; then
        echo "export PATH=\"\$PATH:/usr/games\"" >> ~/.bashrc
    fi

    # XFCE-Compositing deaktivieren (verhindert Vollbild-Flackern auf Monitoren)
    if command -v xfconf-query >/dev/null 2>&1; then
        xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
    fi
'

echo "======================================================="
echo "[✓] GPU-Add-on erfolgreich installiert und konfiguriert!"
echo "    Starte deine Session neu mit ./desktop oder ./mobile"
echo "======================================================="
EOF

chmod +x ~/install-gpu.sh
