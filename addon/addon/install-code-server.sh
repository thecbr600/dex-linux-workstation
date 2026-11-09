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
cat << 'EOF' > ~/.config/code-server/config.yaml
bind-addr: 127.0.0.1:8080
auth: none
cert: false
EOF

# 3. Create background launcher helper
echo "Creating helper command (/usr/local/bin/start-code)..."
cat << 'EOF' > /usr/local/bin/start-code
#!/bin/bash
if pgrep -f "code-server" > /dev/null; then
    echo "code-server is already running at http://127.0.0.1:8080"
else
    echo "Starting code-server in background..."
    mkdir -p ~/.local/share/code-server
    nohup code-server > ~/.local/share/code-server/coder.log 2>&1 &
    sleep 2
    if pgrep -f "code-server" > /dev/null; then
        echo "code-server started successfully! Open http://127.0.0.1:8080"
    else
        echo "Failed to start code-server. Check ~/.local/share/code-server/coder.log"
    fi
fi
EOF
chmod +x /usr/local/bin/start-code

# 4. Create XFCE application menu entry
mkdir -p ~/.local/share/applications
cat << 'EOF' > ~/.local/share/applications/code-server.desktop
[Desktop Entry]
Type=Application
Name=code-server
Comment=Run VS Code in browser
Exec=/usr/local/bin/start-code
Icon=utilities-terminal
Terminal=true
Categories=Development;
EOF

echo "Done! You can now start the editor anytime with 'start-code'."
