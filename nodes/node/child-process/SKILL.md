---
name: node-child-process
description: Spawn child processes, execute shell commands, and orchestrate external CLI tools from Node.js — use when running any external binary or shell command programmatically
---

# Node.js Child Process

Run external programs, shell commands, and CLI tools from Node.js using the `child_process` module.

## When to Use

- Running shell commands (git, npm, docker, curl) from JavaScript
- Invoking build tools, linters, formatters, or test runners programmatically
- Streaming output from long-running processes in real time
- Offloading CPU-intensive work to a forked Node.js worker
- Piping data between multiple processes
- Orchestrating CLI tools in automation scripts

## Decision Tree: exec vs spawn vs fork

1. **Short command, small output, need shell features (pipes, glob)?** -> `exec`
2. **Known binary with arguments, no shell needed?** -> `execFile` (more secure)
3. **Long-running process or large output?** -> `spawn` (streams, no buffering)
4. **Node.js worker with IPC messaging?** -> `fork`
5. **Blocking call in CLI script?** -> `execSync` or `spawnSync`

| Method | Shell | Buffered | Streaming | IPC | Best For |
|--------|-------|----------|-----------|-----|----------|
| `exec` | Yes | Yes | No | No | Simple commands, short output |
| `execFile` | No | Yes | No | No | Direct binary execution (safer) |
| `spawn` | Optional | No | Yes | No | Long-running, large output |
| `fork` | No | No | Yes | Yes | Node.js child with messaging |

## Workflow

1. Choose the right method based on the decision tree above
2. Always pass arguments as an array (not string interpolation) to prevent shell injection
3. Set `cwd` if the command needs a specific working directory
4. Set `timeout` to prevent runaway processes
5. Handle both `error` event (spawn failure) and `close` event (exit code/signal)
6. Use AbortController for cancellation when needed

## Key APIs

### exec (Buffered Shell Command)

```javascript
import { exec } from 'node:child_process';
import { promisify } from 'node:util';

const execAsync = promisify(exec);
const { stdout, stderr } = await execAsync('git status --short', {
  cwd: '/path/to/repo',
  timeout: 10000,
  maxBuffer: 10 * 1024 * 1024,
});
```

### execFile (Safer, No Shell)

```javascript
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
// Arguments are passed directly — no shell injection possible
const { stdout } = await execFileAsync('git', ['log', '--oneline', '-10']);
```

### spawn (Streaming)

```javascript
import { spawn } from 'node:child_process';

// Forward all I/O to parent terminal
const child = spawn('npm', ['run', 'build'], { stdio: 'inherit' });
child.on('close', (code) => process.exit(code));

// Capture output as streams
const proc = spawn('git', ['log', '--oneline']);
let output = '';
proc.stdout.on('data', (chunk) => { output += chunk; });
proc.on('close', (code) => {
  if (code === 0) console.log(output);
});

// AbortController for cancellation
const controller = new AbortController();
const timed = spawn('long-task', [], { signal: controller.signal });
setTimeout(() => controller.abort(), 30000);
```

### fork (Node IPC)

```javascript
import { fork } from 'node:child_process';

const worker = fork('./worker.mjs');
worker.send({ task: 'process', data: items });
worker.on('message', (result) => console.log(result));
```

### stdio Configuration

```javascript
spawn('cmd', [], { stdio: 'inherit' });                    // forward all
spawn('cmd', [], { stdio: 'pipe' });                       // pipe all (default)
spawn('cmd', [], { stdio: ['ignore', 'pipe', 'pipe'] });   // ignore stdin
spawn('cmd', [], { stdio: ['pipe', 'inherit', 'inherit'] });// pipe stdin only
```

## Safety Rules

1. **Never interpolate user input into exec strings** — use `execFile` or `spawn` with an args array instead of `exec('cmd ' + userInput)`
2. **Always set a timeout** — prevent runaway processes with `{ timeout: 30000 }` or AbortController
3. **Handle both error and close events** — `error` fires on spawn failure (ENOENT), `close` fires on exit
4. **Sanitize environment variables** — do not leak secrets to child processes; pass only what is needed
5. **Use SIGTERM before SIGKILL** — give processes a chance to clean up gracefully
6. **Set maxBuffer for exec** — default is 1MB, increase it if you expect large output
7. **Use shell: true only when necessary** — shell execution enables injection and is slower
8. **Validate exit codes** — non-zero exit code means the command failed

## Edge Cases

- **Windows .cmd/.bat files** require `shell: true` to execute — use `cross-spawn` package for consistency
- **ENOENT error** means the binary was not found in PATH — check installation and PATH configuration
- **Zombie processes** can occur if the parent exits without killing children — use `detached: true` and `child.unref()` for background processes, or ensure cleanup on parent exit
- **OOM kills** happen when exec buffers exceed `maxBuffer` — use spawn for large outputs
- **Signals on Windows** are emulated and behave differently — `SIGKILL` works but `SIGTERM` may not
- **Environment inheritance** is automatic — child processes get a copy of `process.env` unless you override with the `env` option
- **Shell differences** between `/bin/sh` (Unix) and `cmd.exe` (Windows) affect command syntax and quoting
- **Process hangs** if child waits for stdin — pass `stdio: ['ignore', 'pipe', 'pipe']` to prevent stdin blocking
