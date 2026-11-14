#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.shortcuts"

cat << 'INNER' > "$HOME/.shortcuts/DeX Desktop"
#!/data/data/com.termux/files/usr/bin/bash
if pgrep -f "termux.x11" >/dev/null 2>&1 && pgrep -f "xfce4-session" >/dev/null 2>&1; then
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
    exit 0
fi
cd "$HOME" && ./desktop
INNER

cat << 'INNER' > "$HOME/.shortcuts/DeX Mobile"
#!/data/data/com.termux/files/usr/bin/bash
if pgrep -f "termux.x11" >/dev/null 2>&1 && pgrep -f "xfce4-session" >/dev/null 2>&1; then
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1
    exit 0
fi
cd "$HOME" && ./mobile
INNER

chmod +x "$HOME/.shortcuts/DeX Desktop" "$HOME/.shortcuts/DeX Mobile"

echo "Shortcuts created in ~/.shortcuts ('DeX Desktop' & 'DeX Mobile')."
echo "Note: Install Termux:Widget from the same source as Termux (GitHub or F-Droid) and enable 'Display over other apps' for Termux."