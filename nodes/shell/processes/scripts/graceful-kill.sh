#!/usr/bin/env bash
set -euo pipefail

# Gracefully kill a process: SIGTERM first, wait for exit, escalate to SIGKILL.
# Usage: ./graceful-kill.sh <pid|pattern> [-t timeout] [-s signal] [-f]
#
# Options:
#   -t <seconds>   Grace period before SIGKILL (default: 10)
#   -s <signal>    Initial signal (default: SIGTERM)
#   -f             Match full command line with pgrep (pattern mode)
#
# If argument is numeric, it's treated as a PID.
# If non-numeric, it's treated as a process name/pattern for pgrep.

TARGET="${1:?Usage: $0 <pid|pattern> [-t timeout] [-s signal] [-f]}"
shift || true

timeout=10
signal="SIGTERM"
full_match=false

while getopts ':t:s:f' opt; do
  case "$opt" in
    t) timeout="$OPTARG" ;;
    s) signal="$OPTARG" ;;
    f) full_match=true ;;
    :) echo "Option -$OPTARG requires an argument" >&2; exit 1 ;;
    ?) echo "Unknown option -$OPTARG" >&2; exit 1 ;;
  esac
done

# Resolve PIDs
pids=()
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
  # Direct PID
  if kill -0 "$TARGET" 2>/dev/null; then
    pids+=("$TARGET")
  else
    echo "{\"success\":false,\"error\":\"Process $TARGET does not exist\"}"
    exit 1
  fi
else
  # Pattern match
  if [[ "$full_match" == true ]]; then
    mapfile -t pids < <(pgrep -f "$TARGET" 2>/dev/null || true)
  else
    mapfile -t pids < <(pgrep "$TARGET" 2>/dev/null || true)
  fi

  if [[ ${#pids[@]} -eq 0 ]]; then
    echo "{\"success\":false,\"error\":\"No processes matching '$TARGET'\"}"
    exit 1
  fi
fi

results=()

for pid in "${pids[@]}"; do
  [[ -z "$pid" ]] && continue

  # Get process info before killing
  cmd=$(ps -o args= -p "$pid" 2>/dev/null || echo "unknown")
  user=$(ps -o user= -p "$pid" 2>/dev/null || echo "unknown")

  # Send initial signal
  if ! kill -"$signal" "$pid" 2>/dev/null; then
    results+=("{\"pid\":$pid,\"command\":\"$cmd\",\"result\":\"already_dead\"}")
    continue
  fi

  echo "Sent $signal to PID $pid ($cmd)" >&2

  # Wait for process to exit
  killed=false
  for (( i=0; i<timeout*2; i++ )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      results+=("{\"pid\":$pid,\"command\":\"$cmd\",\"result\":\"terminated\",\"signal\":\"$signal\"}")
      killed=true
      break
    fi
    sleep 0.5
  done

  # Escalate to SIGKILL if still alive
  if [[ "$killed" != true ]]; then
    if kill -0 "$pid" 2>/dev/null; then
      echo "Process $pid did not exit after ${timeout}s, sending SIGKILL" >&2
      kill -SIGKILL "$pid" 2>/dev/null || true
      sleep 0.5

      if kill -0 "$pid" 2>/dev/null; then
        results+=("{\"pid\":$pid,\"command\":\"$cmd\",\"result\":\"unkillable\",\"signal\":\"SIGKILL\"}")
      else
        results+=("{\"pid\":$pid,\"command\":\"$cmd\",\"result\":\"force_killed\",\"signal\":\"SIGKILL\"}")
      fi
    fi
  fi
done

# Output JSON
printf '{"success":true,"processes":['
first=true
for r in "${results[@]}"; do
  [[ "$first" != true ]] && printf ','
  first=false
  printf '%s' "$r"
done
printf ']}\n'
