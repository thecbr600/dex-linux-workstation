#!/bin/bash
set -u
export LC_ALL=C

DURATION=1800   # 30 Minuten in Sekunden
INTERVAL=30     # Telemetrie-Intervall in Sekunden
OUT_DIR="$HOME/dex-linux-workstation/benchmarks"
TELEM_CSV="$OUT_DIR/telemetry_30m.csv"
BUILD_CSV="$OUT_DIR/builds_30m.csv"
WORK_DIR="/tmp/redis_soak"

echo "[1/3] Vorbereitung: Redis-Quellcode nach $WORK_DIR klonen..."
rm -rf "$WORK_DIR"
git clone --depth 1 https://github.com/redis/redis.git "$WORK_DIR" >/dev/null 2>&1 || {
    echo "Fehler: Git Clone fehlgeschlagen. WLAN prüfen!"
    exit 1
}

echo "timestamp,elapsed_sec,battery_pct,battery_temp_c,max_soc_temp_c,max_cpu_mhz,load_1m,ram_used_mb" > "$TELEM_CSV"
echo "run_id,timestamp,elapsed_sec,exit_code,real_sec,user_sec,sys_sec" > "$BUILD_CSV"

START_TS=$(date +%s)

sample_telemetry() {
    local now=$(date +"%Y-%m-%d %H:%M:%S")
    local elapsed=$(( $(date +%s) - START_TS ))

    local bat_pct="NA"
    local bat_temp="NA"

    if command -v termux-battery-status >/dev/null 2>&1; then
        local bat_json=$(termux-battery-status 2>/dev/null)
        bat_pct=$(echo "$bat_json" | grep -o '"percentage": [0-9]*' | grep -o '[0-9]*' || echo "NA")
        local bat_temp_raw=$(echo "$bat_json" | grep -o '"temperature": [0-9.]*' | grep -o '[0-9.]*' || echo "NA")
        if [ "$bat_temp_raw" != "NA" ]; then
            bat_temp=$(awk -v t="$bat_temp_raw" 'BEGIN {printf "%.1f", t}')
        fi
    fi

    local max_soc=$(awk '
        {
            v = ($1 > 1000) ? $1/1000.0 : $1;
            if (v > 15 && v < 100 && v > max) max = v;
        }
        END { if (max > 0) printf "%.1f", max; else print "NA" }
    ' /sys/class/thermal/thermal_zone*/temp 2>/dev/null || echo "NA")

    local max_mhz=$(awk '
        {
            m = $1/1000.0;
            if (m > max) max = m;
        }
        END { if (max > 0) printf "%.0f", max; else print "NA" }
    ' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null || echo "NA")

    local load1=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "NA")
    local ram_mb=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{if(t>0) printf "%.0f", (t-a)/1024; else print "NA"}' /proc/meminfo 2>/dev/null || echo "NA")

    echo "$now,$elapsed,$bat_pct,$bat_temp,$max_soc,$max_mhz,$load1,$ram_mb" >> "$TELEM_CSV"
}

echo "[2/3] Starte 30-Sekunden-Telemetrie-Logger im Hintergrund..."
(
    while true; do
        sample_telemetry
        sleep "$INTERVAL"
    done
) &
TELEM_PID=$!

cleanup() {
    kill "$TELEM_PID" 2>/dev/null
    wait "$TELEM_PID" 2>/dev/null
    sample_telemetry
    echo ""
    echo "=========================================="
    echo "Test beendet! Ergebnisse gespeichert unter:"
    echo "  -> $TELEM_CSV"
    echo "  -> $BUILD_CSV"
    echo "=========================================="
}
trap cleanup EXIT INT TERM

echo "[3/3] Starte 30-Minuten Compiler-Dauerlauf ($(nproc) Kerne)..."
cd "$WORK_DIR" || exit 1
RUN_ID=1
TIMEFORMAT="%R,%U,%S"

while [ $(( $(date +%s) - START_TS )) -lt "$DURATION" ]; do
    make distclean >/dev/null 2>&1

    { time make -j"$(nproc)" MALLOC=libc >/dev/null 2>&1; } 2> /tmp/build_time.tmp
    EXIT_CODE=$?

    TIMES=$(cat /tmp/build_time.tmp)
    ELAPSED=$(( $(date +%s) - START_TS ))
    NOW=$(date +"%Y-%m-%d %H:%M:%S")

    echo "$RUN_ID,$NOW,$ELAPSED,$EXIT_CODE,$TIMES" >> "$BUILD_CSV"
    printf "[Run #%02d | %4ds / %ds] Exit: %d | Dauer (real,user,sys): %ss\n" \
        "$RUN_ID" "$ELAPSED" "$DURATION" "$EXIT_CODE" "$TIMES"

    RUN_ID=$((RUN_ID + 1))
done
