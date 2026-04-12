---
name: processes
description: Launch, monitor, signal, and terminate system processes from the shell. Use when starting servers, managing background tasks, finding what's using a port, or killing hung processes.
---

# Processes

Manage the full lifecycle of system processes — launch, monitor, signal, and terminate.

## When to Use

- Starting a development server or background worker
- Finding which process is using a specific port
- Killing a hung or runaway process
- Running tasks in the background
- Waiting for a service to become ready
- Monitoring system resource usage
- Cleaning up child processes on script exit

## Workflow

1. Launch the process (foreground, background, or detached)
2. Capture the PID (`$!` for background, `$$` for current shell)
3. Monitor with `ps`, `pgrep`, or `lsof` as needed
4. Send appropriate signal: SIGTERM first (graceful), SIGKILL as last resort
5. Verify process terminated with `kill -0 $pid` or `wait $pid`
6. Use `trap` to ensure cleanup on script exit

## Quick Reference

### Launch
```bash
command &                         # Background
nohup command > log.txt 2>&1 &   # Survive terminal close
timeout 30 command                # Auto-kill after 30s
```

### Find
```bash
ps aux | grep '[n]ode'            # Find by name
pgrep -f 'node server'           # PID by pattern
lsof -i :3000                    # What's on port 3000
ss -tlnp | grep :3000            # Socket stats
```

### Signal
```bash
kill $pid                         # SIGTERM (graceful)
kill -9 $pid                      # SIGKILL (force)
kill -HUP $pid                    # Reload config
pkill -f 'node server'           # Kill by pattern
```

### Job Control
```bash
# Ctrl-Z                         # Suspend foreground
bg %1                             # Resume in background
fg %1                             # Bring to foreground
disown %1                         # Detach from shell
jobs -l                           # List jobs with PIDs
wait $pid                         # Block until done
```

### Common Agent Patterns

```bash
# Start server and wait for ready
node server.js &
server_pid=$!
trap "kill $server_pid 2>/dev/null" EXIT

for i in $(seq 1 30); do
  ss -tlnp | grep -q ':3000' && break
  sleep 1
done

# Graceful kill with escalation
kill "$pid" 2>/dev/null
for i in $(seq 1 10); do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.5
done
kill -0 "$pid" 2>/dev/null && kill -9 "$pid"

# Check port before starting
if lsof -i :3000 -t &>/dev/null; then
  echo "Port 3000 in use" >&2
  exit 1
fi
```

## Edge Cases

- `kill -9` cannot be caught — use only as last resort after SIGTERM fails
- Background processes in a script die when the script exits unless `disown`ed or `nohup`ed
- `$!` only holds the PID of the most recent background command
- `wait` without arguments waits for ALL background jobs
- `pkill` matches process names (15 chars max by default) — use `-f` for full command line
- `lsof` may require root/sudo for processes owned by other users
- Zombie processes (defunct) can't be killed — their parent must `wait()` for them
- Process groups: `kill -- -$pgid` kills all processes in a group
