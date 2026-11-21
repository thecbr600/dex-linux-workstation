#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [ ! -d "/data/data/com.termux/files/usr" ]; then
  echo "Bitte dieses Skript direkt in der Termux-App (nicht in Debian PRoot) ausfuehren."
  exit 1
fi

REPO_RAW="${DEX_REPO_RAW:-https://raw.githubusercontent.com/thecbr600/dex-linux-workstation/main/addon/dex-ai}"
MODEL_URL="${DEX_MODEL_URL:-https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q5_K_M.gguf}"

echo "[1/5] Installiere Termux-Pakete (Vulkan, Build-Tools, Python, API)..."
pkg update -y
pkg install -y python curl git cmake ninja clang vulkan-headers vulkan-loader-android shaderc termux-api

echo "[2/5] Pruefe/kompiliere llama-server mit Adreno-Vulkan-Support..."
if [ ! -x "$HOME/llama.cpp/build/bin/llama-server" ]; then
  [ -d "$HOME/llama.cpp/.git" ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$HOME/llama.cpp"
  cmake -S "$HOME/llama.cpp" -B "$HOME/llama.cpp/build" -G Ninja -DGGML_VULKAN=ON -DLLAMA_CURL=OFF -DBUILD_SHARED_LIBS=OFF
  cmake --build "$HOME/llama.cpp/build" --target llama-server -j"$(nproc)"
fi

echo "[3/5] Installiere dex-daemon und CLI-Werkzeuge..."
mkdir -p "$HOME/dex-agent" "$HOME/bin" "$HOME/models"
curl -fsSL "$REPO_RAW/dex-agent/dex_daemon.py" -o "$HOME/dex-agent/dex_daemon.py"
curl -fsSL "$REPO_RAW/bin/dex-ctl" -o "$HOME/bin/dex-ctl"
curl -fsSL "$REPO_RAW/bin/dex-ide" -o "$HOME/bin/dex-ide"
chmod +x "$HOME/dex-agent/dex_daemon.py" "$HOME/bin/dex-ctl" "$HOME/bin/dex-ide"
grep -qxF 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"

echo "[4/5] Lade oeffentliches Basismodell (Qwen3-4B Q5_K_M) von Hugging Face..."
if [ ! -f "$HOME/models/dex-qwen3-4b-Q5_K_M.gguf" ] && [ ! -f "$HOME/models/Qwen3-4B-Q5_K_M.gguf" ]; then
  curl -fL --retry 3 -C - "$MODEL_URL" -o "$HOME/models/Qwen3-4B-Q5_K_M.gguf"
fi

echo "[5/5] Konfiguriere Autostart & DeX-AI Desktop-App..."
for s in "$HOME/mobile" "$HOME/desktop"; do
  if [ -f "$s" ] && ! grep -q "dex-ctl start" "$s"; then
    sed -i '/proot-distro login/i "$HOME/bin/dex-ctl" start >/dev/null 2>&1 || true' "$s"
  fi
done

proot-distro login debian --shared-tmp -- bash -c '
  DEBIAN_FRONTEND=noninteractive apt-get purge -y webext-ublock-origin-chromium 2>/dev/null || true
  rm -rf /usr/share/chromium/extensions/ublock-origin /etc/chromium.d/*ublock*
  mkdir -p /root/Desktop /usr/share/applications
  cat << "EUI" > /usr/local/bin/dex-ai-ui
#!/usr/bin/env bash
exec chromium --no-sandbox --test-type --disable-extensions --ozone-platform=x11 --disable-dev-shm-usage --user-data-dir=/root/.config/chromium-dex-ai --app="http://127.0.0.1:8080" "$@"
EUI
  chmod +x /usr/local/bin/dex-ai-ui
  cat << "EDESK" > "/root/Desktop/DeX AI.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=DeX AI
Comment=Lokale Qwen3-4B KI-Workstation
Exec=/usr/local/bin/dex-ai-ui
Icon=applications-science
Terminal=false
Categories=Development;Utility;
EDESK
  cp -f "/root/Desktop/DeX AI.desktop" /usr/share/applications/dex-ai.desktop
  chmod +x "/root/Desktop/DeX AI.desktop" /usr/share/applications/dex-ai.desktop
  SHA=$(sha256sum "/root/Desktop/DeX AI.desktop" | awk "{print \$1}")
  gio set -t string "/root/Desktop/DeX AI.desktop" metadata::xfce-exe-checksum "$SHA" 2>/dev/null || true
  gio set -t string "/root/Desktop/DeX AI.desktop" metadata::trusted true 2>/dev/null || true
'

"$HOME/bin/dex-ctl" start
echo "DeX AI Add-on erfolgreich installiert! Starte ./desktop und klicke auf das 'DeX AI'-Icon."
