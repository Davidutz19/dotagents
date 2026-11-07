#!/usr/bin/env bash
# goodnight-claude: snapshot CPU, RAM, swap and disk, and give a verdict.
#
#   resources.sh   print one status line plus the top memory users, exit with:
#     0  ok        keep the current parallelism
#     10 high      start no new build or delegate until it drops back to ok
#     20 critical  free the resource named in reason=, then re-check
#
# reason= lists what tripped the verdict: mem, load, disk (or none).
#
# Thresholds (env): GN_MEM_HIGH=20 GN_MEM_CRIT=10 (percent of RAM available),
# GN_LOAD_HIGH=1.0 GN_LOAD_CRIT=1.5 (1-minute load per core),
# GN_DISK_MIN_GB=15 GN_DISK_CRIT_GB=5 (free space under $HOME).
set -uo pipefail

MEM_HIGH="${GN_MEM_HIGH:-20}"
MEM_CRIT="${GN_MEM_CRIT:-10}"
LOAD_HIGH="${GN_LOAD_HIGH:-1.0}"
LOAD_CRIT="${GN_LOAD_CRIT:-1.5}"
DISK_MIN_GB="${GN_DISK_MIN_GB:-15}"
DISK_CRIT_GB="${GN_DISK_CRIT_GB:-5}"

cores="$(nproc)"
load1="$(cut -d' ' -f1 /proc/loadavg)"
mem_total="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
mem_avail="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
swap_total="$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)"
swap_free="$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)"
mem_pct=$(( mem_avail * 100 / mem_total ))
swap_used_mb=$(( (swap_total - swap_free) / 1024 ))
disk_gb="$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')"
load_per_core="$(awk -v l="$load1" -v c="$cores" 'BEGIN {printf "%.2f", l / c}')"

gt() { awk -v a="$1" -v b="$2" 'BEGIN {exit !(a > b)}'; }

# Collect the reasons for one level. Critical wins over high.
high=() crit=()
(( mem_pct < MEM_CRIT )) && crit+=(mem)
(( mem_pct < MEM_HIGH )) && high+=(mem)
gt "$load_per_core" "$LOAD_CRIT" && crit+=(load)
gt "$load_per_core" "$LOAD_HIGH" && high+=(load)
(( disk_gb < DISK_CRIT_GB )) && crit+=(disk)
(( disk_gb < DISK_MIN_GB )) && high+=(disk)

if (( ${#crit[@]} )); then
  verdict=critical; code=20; reason="$(IFS=,; echo "${crit[*]}")"
elif (( ${#high[@]} )); then
  verdict=high; code=10; reason="$(IFS=,; echo "${high[*]}")"
else
  verdict=ok; code=0; reason=none
fi

echo "verdict=$verdict reason=$reason mem_available=${mem_pct}% load_per_core=$load_per_core cores=$cores swap_used=${swap_used_mb}MB disk_free=${disk_gb}GB"
ps -eo rss=,pid=,comm= --sort=-rss | head -5 | awk '{printf "  top-mem %5d MB  pid %-7s %s\n", $1/1024, $2, $3}'
exit "$code"
