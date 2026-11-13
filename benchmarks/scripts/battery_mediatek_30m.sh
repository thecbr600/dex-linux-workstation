#!/usr/bin/env bash
set -euo pipefail

PLATFORM="mediatek_tabs10u"
TEST_NAME="battery_30m"
WORKERS="${1:-2}"   # Standard: 2 Burst-Worker (realistische Desktop-Last); 0 = reiner Idle-Test
DURATION=1800      # 30 Minuten
INTERVAL=30        # Alle 15 Sekunden loggen
OUT_FILE="benchmarks/results/${PLATFORM}_${TEST_NAME}.csv"

mkdir -p benchmarks/results
PIDS=()

cleanup() {
  for pid in ${PIDS[@]+"${PIDS[@]}"}; do
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

read_soc_temp() {
  local max_t=0 raw val
  for z in /sys/class/thermal/thermal_zone*/temp; do
    raw=$(cat "$z" 2>/dev/null || echo "")
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      (( raw > 1000 )) && val=$(( raw / 1000 )) || val=$raw
      if (( val >= 20 && val <= 115 && val > max_t )); then
        max_t=$val
      fi
    fi
  done
  (( max_t > 0 )) && echo "$max_t" || echo "N/A"
}

read_batt_status() {
  cat /sys/class/power_supply/battery/status 2>/dev/null || echo "N/A"
}

read_batt_pct() {
  cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "N/A"
}

read_batt_temp() {
  awk '{printf "%.1f", $1/10}' /sys/class/power_supply/battery/temp 2>/dev/null || echo "N/A"
}

read_voltage_v() {
  awk '{
    v = $1 + 0;
    if (v > 100000) v = v / 1000000.0;
    else if (v > 1000) v = v / 1000.0;
    printf "%.3f", v;
  }' /sys/class/power_supply/battery/voltage_now 2>/dev/null || echo "N/A"
}

read_current_ma() {
  awk '{
    c = ($1 < 0) ? -$1 : $1;
    if (c > 10000) c = c / 1000.0;
    printf "%.1f", c;
  }' /sys/class/power_supply/battery/current_now 2>/dev/null || echo "N/A"
}

calc_power_w() {
  local v="$1" c="$2"
  if [[ "$v" != "N/A" && "$c" != "N/A" ]]; then
    awk -v v="$v" -v c="$c" 'BEGIN { printf "%.2f", (v * c) / 1000.0 }'
  else
    echo "N/A"
  fi
}

STATUS_INIT=$(read_batt_status)
if [[ "$STATUS_INIT" == "Charging" || "$STATUS_INIT" == "Full" ]]; then
  echo "[!] Hinweis: Netzteil scheint angeschlossen zu sein (Status: ${STATUS_INIT}). Für echte Akku-Werte bitte abziehen!"
fi

echo "timestamp,elapsed_sec,workers,batt_status,batt_pct,voltage_v,current_ma,power_w,batt_temp_c,soc_temp_c,load_1m,mem_used_mb" > "$OUT_FILE"
echo "[*] Starte 30m-Akku-Test ${PLATFORM} (Workers: ${WORKERS}) -> ${OUT_FILE}"

if (( WORKERS > 0 )); then
  for _ in $(seq 1 "$WORKERS"); do
    (
      while true; do
        timeout 3s sha256sum /dev/zero >/dev/null 2>&1 || true
        sleep 7
      done
    ) &
    PIDS+=($!)
  done
fi

START_TS=$(date +%s)
START_PCT=$(read_batt_pct)

while true; do
  NOW_TS=$(date +%s)
  ELAPSED=$(( NOW_TS - START_TS ))
  (( ELAPSED > DURATION )) && break

  TS_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  BATT_S=$(read_batt_status)
  BATT_P=$(read_batt_pct)
  VOLT_V=$(read_voltage_v)
  CURR_MA=$(read_current_ma)
  POW_W=$(calc_power_w "$VOLT_V" "$CURR_MA")
  BATT_T=$(read_batt_temp)
  SOC_T=$(read_soc_temp)
  LOAD_1M=$(awk '{print $1}' /proc/loadavg)
  MEM_MB=$(free -m | awk '/^Mem:/ {print $3}')

  echo "${TS_ISO},${ELAPSED},${WORKERS},${BATT_S},${BATT_P},${VOLT_V},${CURR_MA},${POW_W},${BATT_T},${SOC_T},${LOAD_1M},${MEM_MB}" >> "$OUT_FILE"
  printf "\r[%4ds / %4ds] Akku: %s%% (%s, %sV, %sW) | Temp: %s°C (SoC %s°C) | Load: %s   " \
    "$ELAPSED" "$DURATION" "$BATT_P" "$BATT_S" "$VOLT_V" "$POW_W" "$BATT_T" "$SOC_T" "$LOAD_1M"

  sleep "$INTERVAL"
done

END_PCT=$(read_batt_pct)
echo -e "\n[+] Akku-Test fertig! Start: ${START_PCT}% -> Ende: ${END_PCT}% | CSV: ${OUT_FILE}"
