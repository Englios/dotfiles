#!/bin/bash

# CPU stats using /proc/loadavg and /proc/stat
# Outputs JSON for waybar custom module

CORES=$(nproc)

# Get CPU usage % via /proc/stat (two samples, 200ms apart)
read_cpu_stat() {
    awk '/^cpu /{print $2, $3, $4, $5, $6, $7, $8}' /proc/stat
}

STAT1=$(read_cpu_stat)
sleep 0.2
STAT2=$(read_cpu_stat)

CPU_IDLE1=$(echo "$STAT1" | awk '{print $4}')
CPU_TOTAL1=$(echo "$STAT1" | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')
CPU_IDLE2=$(echo "$STAT2" | awk '{print $4}')
CPU_TOTAL2=$(echo "$STAT2" | awk '{s=0; for(i=1;i<=NF;i++) s+=$i; print s}')

DELTA_IDLE=$((CPU_IDLE2 - CPU_IDLE1))
DELTA_TOTAL=$((CPU_TOTAL2 - CPU_TOTAL1))

if [[ "$DELTA_TOTAL" -eq 0 ]]; then
    CPU_USAGE=0
else
    CPU_USAGE=$(awk "BEGIN {printf \"%d\", (1 - $DELTA_IDLE/$DELTA_TOTAL) * 100}")
fi

# Load average (1min, 5min, 15min)
LOAD=$(awk '{print $1, $2, $3}' /proc/loadavg)
LOAD1=$(echo "$LOAD" | cut -d' ' -f1)
LOAD5=$(echo "$LOAD" | cut -d' ' -f2)
LOAD15=$(echo "$LOAD" | cut -d' ' -f3)

# Determine class based on usage
if [[ "$CPU_USAGE" -ge 80 ]]; then
    CLASS="critical"
elif [[ "$CPU_USAGE" -ge 50 ]]; then
    CLASS="high"
elif [[ "$CPU_USAGE" -ge 20 ]]; then
    CLASS="medium"
else
    CLASS="low"
fi

TEXT=" ${CPU_USAGE}%"
TOOLTIP="CPU Usage: ${CPU_USAGE}%\nCores: ${CORES}\nLoad avg: ${LOAD1} / ${LOAD5} / ${LOAD15} (1m/5m/15m)"

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
