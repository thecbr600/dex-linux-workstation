#!/usr/bin/env python3
import csv
import statistics
import matplotlib.pyplot as plt

CSV_PATH = "benchmarks/results/snapdragon_s26u_4core_4h_docked_light70.csv"
OUT_PATH = "docs/assets/snapdragon_s26u_4h_telemetry.png"

t_min, soc_t, mem_gb = [], [], []
batt_t_x, batt_t_y = [], []
batt_p_x, batt_p_y = [], []

with open(CSV_PATH, newline="") as f:
    for row in csv.DictReader(f):
        m = float(row["elapsed_sec"]) / 60.0
        t_min.append(m)
        soc_t.append(float(row["soc_temp_c"]))
        mem_gb.append(float(row["mem_used_mb"]) / 1024.0)
        if row["batt_temp_c"] != "N/A":
            batt_t_x.append(m)
            batt_t_y.append(float(row["batt_temp_c"]))
        if row["batt_pct"] != "N/A":
            batt_p_x.append(m)
            batt_p_y.append(float(row["batt_pct"]))

soc_med = statistics.median(soc_t)

plt.style.use("dark_background")
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 7), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
fig.patch.set_facecolor("#0d1117")
for ax in (ax1, ax2):
    ax.set_facecolor("#161b22")
    ax.grid(True, linestyle="--", alpha=0.25, color="#8b949e")

ax1.plot(t_min, soc_t, color="#58a6ff", linewidth=1.3, alpha=0.85, label="SoC Temp (°C)")
ax1.plot(batt_t_x, batt_t_y, color="#3fb950", linewidth=2.0, label="Battery Temp (°C)")
ax1.axhline(soc_med, color="#58a6ff", linestyle=":", alpha=0.6, label=f"SoC Median ({soc_med:.0f}°C)")
ax1.set_ylabel("Temperature (°C)", color="#c9d1d9", fontsize=11)
ax1.set_title("Samsung S26 Ultra (Snapdragon) – 4.26h Soak Test (4 Cores, Docked, Light 70% Profile, 80% PD Bypass)", color="#f0f6fc", fontsize=12, fontweight="bold", pad=12)
ax1.legend(loc="upper right", frameon=True, facecolor="#0d1117", edgecolor="#30363d")
ax1.set_ylim(20, 82)

ax2.plot(t_min, mem_gb, color="#d2a8ff", linewidth=1.6, label="RAM Used (GB)")
ax2.set_ylabel("RAM Used (GB)", color="#d2a8ff", fontsize=11)
ax2.set_xlabel("Elapsed Time (Minutes)", color="#c9d1d9", fontsize=11)
ax2.set_ylim(8.5, 12.5)

ax2_r = ax2.twinx()
ax2_r.plot(batt_p_x, batt_p_y, color="#ffa657", linestyle="--", linewidth=1.8, label="Battery Level (%)")
ax2_r.set_ylabel("Battery (%)", color="#ffa657", fontsize=11)
ax2_r.set_ylim(70, 90)

l1, lb1 = ax2.get_legend_handles_labels()
l2, lb2 = ax2_r.get_legend_handles_labels()
ax2.legend(l1 + l2, lb1 + lb2, loc="upper right", frameon=True, facecolor="#0d1117", edgecolor="#30363d")

plt.tight_layout()
plt.savefig(OUT_PATH, dpi=160)
print(f"[+] Chart gespeichert unter: {OUT_PATH}")
