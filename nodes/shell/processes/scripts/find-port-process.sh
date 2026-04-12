#!/usr/bin/env bash
set -euo pipefail

# Find which process is listening on a given TCP port.
# Usage: ./find-port-process.sh <port>
#
# Outputs JSON with PID, command, user, and protocol information.

PORT="${1:?Usage: $0 <port>}"

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "{\"error\":\"Invalid port number: $PORT\",\"processes\":[]}" >&2
  exit 1
fi

processes=()

# Try ss first (modern, most reliable)
if command -v ss &>/dev/null; then
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      # Parse ss -tlnp output: pid and process name
      if [[ "$line" =~ users:\(\(\"([^\"]+)\",pid=([0-9]+) ]]; then
        proc_name="${BASH_REMATCH[1]}"
        pid="${BASH_REMATCH[2]}"
        user=$(ps -o user= -p "$pid" 2>/dev/null || echo "unknown")
        cmdline=$(ps -o args= -p "$pid" 2>/dev/null || echo "$proc_name")
        processes+=("{\"pid\":$pid,\"command\":\"$cmdline\",\"user\":\"$user\",\"process\":\"$proc_name\"}")
      fi
    fi
  done < <(ss -tlnp "sport = :$PORT" 2>/dev/null || true)
fi

# Fall back to lsof if ss found nothing
if [[ ${#processes[@]} -eq 0 ]] && command -v lsof &>/dev/null; then
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      # Parse lsof output fields
      proc_name=$(echo "$line" | awk '{print $1}')
      pid=$(echo "$line" | awk '{print $2}')
      user=$(echo "$line" | awk '{print $3}')
      cmdline=$(ps -o args= -p "$pid" 2>/dev/null || echo "$proc_name")
      processes+=("{\"pid\":$pid,\"command\":\"$cmdline\",\"user\":\"$user\",\"process\":\"$proc_name\"}")
    fi
  done < <(lsof -i :"$PORT" -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2 || true)
fi

# Fall back to /proc/net/tcp (no tools needed, Linux only)
if [[ ${#processes[@]} -eq 0 ]] && [[ -f /proc/net/tcp ]]; then
  hex_port=$(printf '%04X' "$PORT")
  while IFS= read -r line; do
    if [[ "$line" == *":$hex_port "* ]]; then
      # Extract inode and find PID
      inode=$(echo "$line" | awk '{print $10}')
      if [[ "$inode" != "0" ]]; then
        for pid_dir in /proc/[0-9]*/fd; do
          pid="${pid_dir#/proc/}"
          pid="${pid%/fd}"
          if ls -la "$pid_dir" 2>/dev/null | grep -q "socket:\\[$inode\\]"; then
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "unknown")
            user=$(stat -c '%U' "/proc/$pid" 2>/dev/null || echo "unknown")
            processes+=("{\"pid\":$pid,\"command\":\"$cmdline\",\"user\":\"$user\",\"process\":\"\"}")
            break
          fi
        done
      fi
    fi
  done < /proc/net/tcp
fi

# Output JSON
printf '{"port":%d,"listening":%s,"processes":[' "$PORT" \
  "$( [[ ${#processes[@]} -gt 0 ]] && echo "true" || echo "false" )"

first=true
for proc in "${processes[@]}"; do
  [[ "$first" != true ]] && printf ','
  first=false
  printf '%s' "$proc"
done

printf ']}\n'
