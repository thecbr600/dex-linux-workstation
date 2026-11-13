#!/usr/bin/env bash
set -euo pipefail

MARKER="# --- DeX Workstation Auto-Close Hook ---"

patch_launcher() {
    local target="$1"
    if [ ! -f "$target" ]; then
        echo "Skipping $target (not found)."
        return
    fi

    if grep -qF "$MARKER" "$target"; then
        echo "$target already has auto-close enabled."
        return
    fi

    local tmp_file
    tmp_file="$(mktemp)"

    {
        IFS= read -r first_line < "$target"
        printf '%s\n' "$first_line"

        cat << 'HOOK'
# --- DeX Workstation Auto-Close Hook ---
dex_autoclose() {
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
    pkill -9 -f termux-x11 2>/dev/null || true
    pkill -9 -f pulseaudio 2>/dev/null || true
    pkill -9 -f virgl_test_server 2>/dev/null || true
    rm -rf "${PREFIX:-/data/data/com.termux/files/usr}/tmp/.X11-unix" \
           "${PREFIX:-/data/data/com.termux/files/usr}/tmp/.X*-lock" \
           "${PREFIX:-/data/data/com.termux/files/usr}/tmp/pulse-*" 2>/dev/null || true
    am start -a android.intent.action.MAIN -c android.intent.category.HOME >/dev/null 2>&1 || true
}
trap dex_autoclose EXIT
# --- End Auto-Close Hook ---
HOOK

        tail -n +2 "$target"
    } > "$tmp_file"

    mv "$tmp_file" "$target"
    chmod +x "$target"
    echo "Auto-close hook added to $target."
}

patch_launcher "$HOME/desktop"
patch_launcher "$HOME/mobile"

echo "Done! Clicking 'Logout' in XFCE will now automatically close Termux:X11."
