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

# 3. Create 1-click launcher (starts server if needed + opens app window)
echo "Creating helper command (/usr/local/bin/start-code)..."
cat << 'INNER' > /usr/local/bin/start-code
#!/bin/bash
URL="http://127.0.0.1:8080"

if ! curl -fsS "$URL/healthz" >/dev/null 2>&1; then
    if ! pgrep -f "[c]ode-server" >/dev/null 2>&1; then
        echo "Starting code-server in background..."
        mkdir -p ~/.local/share/code-server
        nohup code-server > ~/.local/share/code-server/coder.log 2>&1 &
    fi
    for _ in $(seq 1 20); do
        curl -fsS "$URL/healthz" >/dev/null 2>&1 && break
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
    nohup "$BROWSER" --no-sandbox --test-type --app="$URL" >/dev/null 2>&1 &
else
    nohup xdg-open "$URL" >/dev/null 2>&1 &
fi
INNER
chmod +x /usr/local/bin/start-code

# 4. Create XFCE application menu entry (and update Desktop copy if present)
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

if [ -f ~/Desktop/code-server.desktop ]; then
    cp ~/.local/share/applications/code-server.desktop ~/Desktop/code-server.desktop
    chmod +x ~/Desktop/code-server.desktop
fi

echo "Done! Click the code-server icon or run 'start-code' anytime."
