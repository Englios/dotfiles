# ============================================
# Custom Functions
# ============================================

# ---------------------------
# Memory Monitoring
# ---------------------------

memwatch() {
    if [ -z "$1" ]; then
        echo "Usage: memwatch <process-name>"
        return 1
    fi

    echo "Tracking all processes matching: $1"
    echo "Press Ctrl+C to stop."

    watch -n 2 "
        ps -C $1 -o pid,comm,%mem,%cpu,rss,vsz --no-headers | 
        awk '
        BEGIN {mem=0; cpu=0; rss=0; vsz=0}
        {mem+=\$3; cpu+=\$4; rss+=\$5; vsz+=\$6}
        END {
            printf \"Total %%MEM: %.2f | Total %%CPU: %.2f | Total RSS: %d KB | Total VSZ: %d KB\n\", mem, cpu, rss, vsz
        }'
    "
}

# ---------------------------
# DDC/CI Brightness Control
# ---------------------------

# Internal helpers
_get_brightness() {
  ddcutil --display "$1" getvcp 10 2>/dev/null | awk -F'[=,]' '{print $2}'
}

_set_brightness() {
  sudo ddcutil --display "$1" setvcp 10 "$2"
}

# Parse kwargs helper
_parse_args() {
  DISPLAY=1
  STEP=5
  VALUE=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --display|-d)
        DISPLAY="$2"; shift 2 ;;
      --step|-s)
        STEP="$2"; shift 2 ;;
      --value|-v)
        VALUE="$2"; shift 2 ;;
      *)
        echo "Unknown option: $1"
        return 1 ;;
    esac
  done
}

dim() {
  _parse_args "$@" || return

  local cur=$(_get_brightness "$DISPLAY") || return
  local next=$((cur - STEP))
  [ "$next" -lt 0 ] && next=0

  _set_brightness "$DISPLAY" "$next"
}

bright() {
  _parse_args "$@" || return

  local cur=$(_get_brightness "$DISPLAY") || return
  local next=$((cur + STEP))
  [ "$next" -gt 100 ] && next=100

  _set_brightness "$DISPLAY" "$next"
}

setbright() {
  _parse_args "$@" || return

  if [ -z "$VALUE" ]; then
    echo "Usage: setbright --value <0-100> [--display N]"
    return 1
  fi

  [ "$VALUE" -lt 0 ] && VALUE=0
  [ "$VALUE" -gt 100 ] && VALUE=100

  _set_brightness "$DISPLAY" "$VALUE"
}

ddc-bright-help() {
  cat <<'EOF'
DDCUTIL BRIGHTNESS COMMANDS
===========================

Commands
--------

  dim
    Decrease brightness by step (default: 5)

  bright
    Increase brightness by step (default: 5)

  setbright
    Set absolute brightness value

Arguments (kwargs)
------------------

  --display, -d <N>
      Target display number (default: 1)

  --step, -s <N>
      Step size for dim / bright (default: 5)

  --value, -v <N>
      Absolute brightness value for setbright (0–100)

Examples
--------

  dim
  dim --display 2
  dim --step 10
  dim -d 2 -s 15

  bright
  bright --display 1 --step 20

  setbright --value 30
  setbright --display 2 --value 75

Notes
-----

  • Uses ddcutil VCP code 0x10 (Brightness)
  • Absolute brightness only (monitor does not support relative +/-)
  • Requires sudo unless udev rules are installed

EOF
}

ddc-bright-list() {
  echo "DDCUTIL DISPLAYS & BRIGHTNESS"
  echo "============================="
  echo

  ddcutil detect 2>/dev/null | awk '
    /^Display [0-9]+/ {
      display=$2
      printf "Display %s\n", display
    }
    /Monitor:/ {
      sub(/^[[:space:]]*Monitor:[[:space:]]*/, "", $0)
      printf "  Monitor   : %s\n", $0
    }
    /I2C bus:/ {
      printf "  I2C bus   : %s\n", $3
    }
  '

  echo
  echo "Brightness"
  echo "----------"

  for d in $(ddcutil detect 2>/dev/null | awk "/^Display/ {print \$2}"); do
    val=$(ddcutil --display "$d" getvcp 10 2>/dev/null | awk -F'[=,]' '{print $2}')
    if [ -n "$val" ]; then
      printf "  Display %s : %s%%\n" "$d" "$val"
    else
      printf "  Display %s : (not supported)\n" "$d"
    fi
  done
}
