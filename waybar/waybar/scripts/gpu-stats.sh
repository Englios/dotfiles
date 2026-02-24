#!/bin/bash

# GPU stats using nvidia-smi
# Outputs JSON for waybar custom module
# Fields: utilization%, temperature°C, memory_used MB, memory_total MB

DATA=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null)

if [[ -z "$DATA" ]]; then
    echo '{"text": "󰢩 N/A", "tooltip": "nvidia-smi unavailable", "class": "unavailable"}'
    exit 0
fi

GPU_UTIL=$(echo "$DATA" | awk -F', ' '{print $1}' | tr -d ' ')
GPU_TEMP=$(echo "$DATA" | awk -F', ' '{print $2}' | tr -d ' ')
MEM_USED=$(echo "$DATA" | awk -F', ' '{print $3}' | tr -d ' ')
MEM_TOTAL=$(echo "$DATA" | awk -F', ' '{print $4}' | tr -d ' ')

# Convert MB to GB (rounded to 1 decimal)
MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/1024}")
MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024}")

# Determine class based on utilization
if [[ "$GPU_UTIL" -ge 80 ]]; then
    CLASS="critical"
elif [[ "$GPU_UTIL" -ge 50 ]]; then
    CLASS="high"
elif [[ "$GPU_UTIL" -ge 20 ]]; then
    CLASS="medium"
else
    CLASS="low"
fi

TEXT="󰢩 ${GPU_UTIL}%  ${GPU_TEMP}°C"
TOOLTIP="GPU Utilization: ${GPU_UTIL}%\nTemperature: ${GPU_TEMP}°C\nVRAM: ${MEM_USED_GB}G / ${MEM_TOTAL_GB}G"

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\"}"
