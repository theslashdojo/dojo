#!/usr/bin/env node
// Run shell commands with configurable execution mode
// Usage: node run-command.js [--mode exec|spawn] <command> [args...]
// Supports: timeout, cwd, env vars, shell selection

import { exec, execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

const USAGE = `Usage: node run-command.js [options] <command> [args...]

Options:
  --mode <exec|spawn>   Execution mode (default: spawn)
  --cwd <dir>           Working directory
  --timeout <ms>        Timeout in milliseconds (0 = none)
  --shell               Force shell execution (default for exec mode)
  --no-shell            Disable shell execution
  --env KEY=VALUE       Set environment variable (repeatable)
  --json                Output result as JSON on exit
  --help                Show this help message

Modes:
  exec    Buffers all output, returns when complete. Best for short commands.
  spawn   Streams output in real time. Best for long-running or large-output commands.

Examples:
  node run-command.js git status --short
  node run-command.js --mode exec --timeout 5000 npm test
  node run-command.js --cwd /tmp ls -la
  node run-command.js --env NODE_ENV=production npm run build`;

// Parse arguments
const rawArgs = process.argv.slice(2);

if (rawArgs.length === 0 || rawArgs.includes('--help') || rawArgs.includes('-h')) {
  console.log(USAGE);
  process.exit(0);
}

let mode = 'spawn';
let cwd = process.cwd();
let timeout = 0;
let shellOverride = undefined;
let jsonOutput = false;
const extraEnv = {};
const commandArgs = [];

let i = 0;
while (i < rawArgs.length) {
  const arg = rawArgs[i];
  if (arg === '--mode' && i + 1 < rawArgs.length) {
    mode = rawArgs[++i];
    if (mode !== 'exec' && mode !== 'spawn') {
      console.error(`Error: mode must be "exec" or "spawn", got "${mode}"`);
      process.exit(1);
    }
  } else if (arg === '--cwd' && i + 1 < rawArgs.length) {
    cwd = rawArgs[++i];
  } else if (arg === '--timeout' && i + 1 < rawArgs.length) {
    timeout = parseInt(rawArgs[++i], 10);
    if (isNaN(timeout) || timeout < 0) {
      console.error('Error: timeout must be a non-negative integer');
      process.exit(1);
    }
  } else if (arg === '--shell') {
    shellOverride = true;
  } else if (arg === '--no-shell') {
    shellOverride = false;
  } else if (arg === '--json') {
    jsonOutput = true;
  } else if (arg === '--env' && i + 1 < rawArgs.length) {
    const pair = rawArgs[++i];
    const eqIndex = pair.indexOf('=');
    if (eqIndex === -1) {
      console.error(`Error: --env value must be KEY=VALUE, got "${pair}"`);
      process.exit(1);
    }
    extraEnv[pair.slice(0, eqIndex)] = pair.slice(eqIndex + 1);
  } else if (arg.startsWith('--')) {
    // Once we encounter the command, stop parsing flags
    commandArgs.push(arg);
  } else {
    // First non-flag argument starts the command
    commandArgs.push(...rawArgs.slice(i));
    break;
  }
  i++;
}

if (commandArgs.length === 0) {
  console.error('Error: no command specified');
  console.error('Run with --help for usage information');
  process.exit(1);
}

const command = commandArgs[0];
const args = commandArgs.slice(1);

const env = { ...process.env, ...extraEnv };
const useShell = shellOverride !== undefined
  ? shellOverride
  : mode === 'exec';

async function runExec() {
  // In exec mode, join command and args into a shell string
  const fullCommand = [command, ...args].join(' ');
  const startTime = Date.now();

  try {
    const { stdout, stderr } = await execAsync(fullCommand, {
      cwd,
      timeout: timeout || undefined,
      maxBuffer: 50 * 1024 * 1024, // 50MB
      env,
    });

    if (stdout) process.stdout.write(stdout);
    if (stderr) process.stderr.write(stderr);

    if (jsonOutput) {
      console.log(JSON.stringify({
        exitCode: 0,
        signal: null,
        duration: Date.now() - startTime,
        stdoutBytes: Buffer.byteLength(stdout),
        stderrBytes: Buffer.byteLength(stderr),
      }, null, 2));
    }

    process.exit(0);
  } catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);

    const exitCode = err.code ?? 1;
    const signal = err.signal ?? null;

    if (jsonOutput) {
      console.log(JSON.stringify({
        exitCode,
        signal,
        duration: Date.now() - startTime,
        error: err.message,
      }, null, 2));
    } else if (signal) {
      console.error(`\nProcess killed by signal: ${signal}`);
    } else {
      console.error(`\nProcess exited with code: ${exitCode}`);
    }

    process.exit(typeof exitCode === 'number' ? exitCode : 1);
  }
}

async function runSpawn() {
  const startTime = Date.now();
  let stdout = '';
  let stderr = '';

  const child = spawn(command, args, {
    cwd,
    env,
    shell: useShell,
    timeout: timeout || undefined,
    stdio: ['inherit', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (data) => {
    stdout += data.toString();
    process.stdout.write(data);
  });

  child.stderr.on('data', (data) => {
    stderr += data.toString();
    process.stderr.write(data);
  });

  child.on('error', (err) => {
    if (err.code === 'ENOENT') {
      console.error(`Error: command not found — "${command}"`);
      console.error('Check that the binary is installed and available in PATH.');
    } else if (err.code === 'EACCES') {
      console.error(`Error: permission denied — "${command}"`);
    } else {
      console.error(`Error: ${err.message}`);
    }

    if (jsonOutput) {
      console.log(JSON.stringify({
        exitCode: 1,
        signal: null,
        duration: Date.now() - startTime,
        error: err.message,
        errorCode: err.code,
      }, null, 2));
    }

    process.exit(1);
  });

  child.on('close', (code, signal) => {
    if (jsonOutput) {
      console.log(JSON.stringify({
        exitCode: code,
        signal: signal || null,
        duration: Date.now() - startTime,
        stdoutBytes: Buffer.byteLength(stdout),
        stderrBytes: Buffer.byteLength(stderr),
      }, null, 2));
    } else if (signal) {
      console.error(`\nProcess killed by signal: ${signal}`);
    } else if (code !== 0) {
      console.error(`\nProcess exited with code: ${code}`);
    }

    process.exit(code ?? 1);
  });
}

if (mode === 'exec') {
  runExec();
} else {
  runSpawn();
}
