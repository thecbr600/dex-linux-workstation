#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

PLATFORM="snapdragon_s26u"
TEST_NAME="4core_5h_docked_light70"
CORES=4
DURATION=18000  # 5 Stunden (600 Messpunkte)
INTERVAL=30
OUT_FILE="benchmarks/results/${PLATFORM}_${TEST_NAME}.csv"

mkdir -p benchmarks/results
PIDS=()
STRESS_PID=""

cleanup() {
  if [[ -n "$STRESS_PID" ]]; then
    pkill -P "$STRESS_PID" 2>/dev/null || true
    kill "$STRESS_PID" 2>/dev/null || true
  fi
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

read_soc_temp() {
  local max_t=0 raw val ztype
  for zdir in /sys/class/thermal/thermal_zone*; do
    [[ -r "$zdir/temp" ]] || continue
    ztype=$(cat "$zdir/type" 2>/dev/null || echo "")
    if [[ "$ztype" =~ ^cpu-[0-9]+- ]]; then
      raw=$(cat "$zdir/temp" 2>/dev/null || echo "")
      if [[ "$raw" =~ ^[0-9]+$ ]]; then
        (( raw > 1000 )) && val=$(( raw / 1000 )) || val=$raw
        if (( val >= 20 && val < 105 && val > max_t )); then
          max_t=$val
        fi
      fi
    fi
  done
  if (( max_t == 0 )); then
    for z in /sys/class/thermal/thermal_zone*/temp; do
      raw=$(cat "$z" 2>/dev/null || echo "")
      if [[ "$raw" =~ ^[0-9]+$ ]]; then
        (( raw > 1000 )) && val=$(( raw / 1000 )) || val=$raw
        if (( val >= 20 && val < 105 && val > max_t )); then
          max_t=$val
        fi
      fi
    done
  fi
  (( max_t > 0 )) && echo "$max_t" || echo "N/A"
}

read_batt_temp() {
  if [[ -r /tmp/dex-battery.json ]]; then
    python3 -c 'import json; print(json.load(open("/tmp/dex-battery.json")).get("temperature", "N/A"))' 2>/dev/null || echo "N/A"
  elif [[ -r /sys/class/power_supply/battery/temp ]]; then
    awk '{printf "%.1f", $1/10}' /sys/class/power_supply/battery/temp 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

read_batt_pct() {
  if [[ -r /tmp/dex-battery.json ]]; then
    python3 -c 'import json; print(json.load(open("/tmp/dex-battery.json")).get("percentage", "N/A"))' 2>/dev/null || echo "N/A"
  elif [[ -r /sys/class/power_supply/battery/capacity ]]; then
    cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "N/A"
  else
    echo "N/A"
  fi
}

start_fallback_load() {
  for _ in $(seq 1 "$CORES"); do
    sha256sum /dev/zero >/dev/null 2>&1 &
    PIDS+=($!)
  done
}

echo "timestamp,elapsed_sec,cores,load_1m,soc_temp_c,batt_temp_c,batt_pct,mem_used_mb" > "$OUT_FILE"
echo "[*] Starte ${PLATFORM} (${TEST_NAME}) [5h / ${CORES} Cores] -> ${OUT_FILE}"

if command -v stress-ng >/dev/null 2>&1; then
  stress-ng --cpu "$CORES" --cpu-method matrixprod --timeout "${DURATION}s" --quiet &
  STRESS_PID=$!
  sleep 1
  if ! kill -0 "$STRESS_PID" 2>/dev/null; then
    STRESS_PID=""
    start_fallback_load
  fi
else
  start_fallback_load
fi

START_TS=$(date +%s)
while true; do
  NOW_TS=$(date +%s)
  ELAPSED=$(( NOW_TS - START_TS ))
  (( ELAPSED > DURATION )) && break

  TS_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  LOAD_1M=$(awk '{print $1}' /proc/loadavg)
  SOC_T=$(read_soc_temp)
  BATT_T=$(read_batt_temp)
  BATT_P=$(read_batt_pct)
  MEM_MB=$(free -m | awk '/^Mem:/ {print $3}')

  echo "${TS_ISO},${ELAPSED},${CORES},${LOAD_1M},${SOC_T},${BATT_T},${BATT_P},${MEM_MB}" >> "$OUT_FILE"
  printf "\r[%5ds / %5ds] Load: %s | SoC: %s°C | Akku: %s°C (%s%%) | RAM: %s MB   " \
    "$ELAPSED" "$DURATION" "$LOAD_1M" "$SOC_T" "$BATT_T" "$BATT_P" "$MEM_MB"

  sleep "$INTERVAL"
done

echo -e "\n[+] Fertig! Ergebnisse gespeichert unter: ${OUT_FILE}"
