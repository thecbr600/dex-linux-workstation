#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [ ! -d "/data/data/com.termux/files/usr" ]; then
  echo "Bitte dieses Skript direkt in der Termux-App (nicht in Debian PRoot) ausfuehren."
  exit 1
fi

REPO_RAW="${DEX_REPO_RAW:-https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/dex-doctor}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" 2>/dev/null && pwd || true)"

echo "[1/3] Installiere dex-doctor im Termux-Host..."
mkdir -p "$HOME/bin"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/bin/dex-doctor" ]; then
  cp -f "$SCRIPT_DIR/bin/dex-doctor" "$HOME/bin/dex-doctor"
else
  curl -fsSL "$REPO_RAW/bin/dex-doctor" -o "$HOME/bin/dex-doctor"
fi
chmod +x "$HOME/bin/dex-doctor"
grep -qxF 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"

echo "[2/3] Installiere dex-doctor in PRoot-Debian..."
if command -v proot-distro >/dev/null 2>&1 && proot-distro login debian -- true >/dev/null 2>&1; then
  proot-distro login debian --shared-tmp -- bash -c '
    cp -f /data/data/com.termux/files/home/bin/dex-doctor /usr/local/bin/dex-doctor
    chmod +x /usr/local/bin/dex-doctor
  '
else
  echo "Hinweis: Debian PRoot-Container nicht gefunden, ueberspringe Container-Installation."
fi

echo "[3/3] Fuehre ersten Preflight-Check aus..."
"$HOME/bin/dex-doctor" || true
echo "DeX Doctor Add-on erfolgreich installiert! Nutze 'dex-doctor' oder 'dex-doctor --fix' in Termux und Debian."
