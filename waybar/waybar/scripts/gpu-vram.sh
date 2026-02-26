#!/bin/bash

# GPU VRAM stats using nvidia-smi
# Outputs JSON for waybar custom module
# Fields: memory_used MiB, memory_total MiB

DATA=$(nvidia-smi --query-gpu=memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null)

if [[ -z "$DATA" ]]; then
    echo '{"text": "󰍛 N/A", "tooltip": "nvidia-smi unavailable", "class": "unavailable"}'
    exit 0
fi

MEM_USED=$(echo "$DATA" | awk -F', ' '{print $1}' | tr -d ' ')
MEM_TOTAL=$(echo "$DATA" | awk -F', ' '{print $2}' | tr -d ' ')

# Convert MiB to GB (rounded to 1 decimal)
MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED/1024}")
MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL/1024}")

# Percentage for class
MEM_PCT=$(awk "BEGIN {printf \"%d\", ($MEM_USED/$MEM_TOTAL)*100}")

# Determine class based on VRAM usage percentage
if [[ "$MEM_PCT" -ge 80 ]]; then
    CLASS="critical"
elif [[ "$MEM_PCT" -ge 50 ]]; then
    CLASS="high"
else
    CLASS="normal"
fi

TEXT="󰍛 ${MEM_USED_GB}/${MEM_TOTAL_GB}G"
TOOLTIP="VRAM: ${MEM_USED} / ${MEM_TOTAL} MiB (${MEM_PCT}%)"

echo "{\"text\": \"${TEXT}\", \"tooltip\": \"${TOOLTIP}\", \"class\": \"${CLASS}\", \"percentage\": ${MEM_PCT}}"
