#!/bin/bash
set -e

echo "=== Configuring Caps Lock -> Super Key Mapping ==="

# 1. Create autostart directory and .desktop entry for XFCE
mkdir -p ~/.config/autostart
cat << 'EOF' > ~/.config/autostart/remap-caps.desktop
[Desktop Entry]
Type=Application
Exec=setxkbmap -option caps:super
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Remap Caps to Super
Comment=Remap Caps Lock to Super/Win key to bypass DeX interception
EOF

# 2. Apply immediately to active session if X11 is running
if [ -n "$DISPLAY" ]; then
    setxkbmap -option caps:super 2>/dev/null || true
fi

echo "Done! Caps Lock now permanently acts as the Super/Windows key."
