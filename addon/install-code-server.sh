#!/bin/bash
set -e

echo "=== Installing and Configuring code-server ==="

# 1. Install code-server if missing
if ! command -v code-server &>/dev/null; then
    echo "Installing code-server via official installer..."
    curl -fsSL https://code-server.dev/install.sh | sh
else
    echo "code-server is already installed."
fi

# 2. Configure code-server (no password, local loopback)
echo "Configuring code-server settings..."
mkdir -p ~/.config/code-server
cat << 'INNER' > ~/.config/code-server/config.yaml
bind-addr: 127.0.0.1:8080
auth: none
cert: false
INNER

# 3. Create 1-click launcher (detached server start + dedicated app window)
echo "Creating helper command (/usr/local/bin/start-code)..."
cat << 'INNER' > /usr/local/bin/start-code
#!/bin/bash
URL="http://127.0.0.1:8080"

port_open() {
    (echo > /dev/tcp/127.0.0.1/8080) >/dev/null 2>&1
}

if ! port_open; then
    mkdir -p ~/.local/share/code-server
    setsid code-server --bind-addr 127.0.0.1:8080 --auth none > ~/.local/share/code-server/coder.log 2>&1 < /dev/null &
    for _ in $(seq 1 60); do
        port_open && break
        sleep 0.25
    done
fi

BROWSER=""
for bin in chromium chromium-browser google-chrome brave-browser; do
    if command -v "$bin" >/dev/null 2>&1; then
        BROWSER="$bin"
        break
    fi
done

if [ -n "$BROWSER" ]; then
    setsid "$BROWSER" \
        --user-data-dir="$HOME/.config/chromium-code-server" \
        --no-sandbox \
        --test-type \
        --app="$URL" >/dev/null 2>&1 < /dev/null &
else
    setsid xdg-open "$URL" >/dev/null 2>&1 < /dev/null &
fi
INNER
chmod +x /usr/local/bin/start-code

# 4. Create/update XFCE application menu entry & any Desktop launcher
mkdir -p ~/.local/share/applications
cat << 'INNER' > ~/.local/share/applications/code-server.desktop
[Desktop Entry]
Type=Application
Name=code-server
Comment=Run VS Code in app window
Exec=/usr/local/bin/start-code
Icon=utilities-terminal
Terminal=false
Categories=Development;
INNER

for f in ~/Desktop/*code*.desktop ~/Desktop/*Code*.desktop; do
    if [ -f "$f" ]; then
        cp ~/.local/share/applications/code-server.desktop "$f"
        chmod +x "$f"
    fi
done

echo "Done! Click the code-server icon or run 'start-code' anytime."
