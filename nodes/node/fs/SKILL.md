---
name: node-fs
description: Read, write, and manage files and directories with Node.js fs/promises API — use when performing any file system operation in JavaScript or TypeScript
---

# Node.js File System

Work with files and directories using the modern `fs/promises` API and the `path` module for cross-platform path construction.

## When to Use

- Reading configuration files, data files, or source code
- Writing generated code, build output, or log files
- Creating directory structures for new projects or outputs
- Listing directory contents for discovery or processing
- Checking file existence or inspecting metadata (size, timestamps)
- Copying, moving, or deleting files and directories
- Watching files for changes during development
- Creating temporary files and directories for intermediate processing

## Workflow

1. Import from `node:fs/promises` (always prefer the promises API over callbacks)
2. Build paths with `path.join()` or `path.resolve()` — never concatenate with `/`
3. Create parent directories before writing: `mkdir(dir, { recursive: true })`
4. Handle errors by code: `ENOENT` (not found), `EACCES` (permission denied), `EISDIR` (is a directory)
5. Use streams (`createReadStream` / `createWriteStream`) for files over 100MB
6. Clean up temporary directories in a `finally` block

## Key APIs

```javascript
import {
  readFile, writeFile, appendFile,
  readdir, mkdir, rm, cp, rename,
  stat, lstat, access, constants,
  mkdtemp, watch
} from 'node:fs/promises';
import { createReadStream, createWriteStream } from 'node:fs';
import { join, resolve, dirname, basename, extname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

// ESM __dirname equivalent
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
```

### Reading

```javascript
// String content
const text = await readFile('config.json', 'utf-8');

// Binary buffer
const buf = await readFile('image.png');

// Stream large files
const stream = createReadStream('huge.log', { encoding: 'utf-8' });
for await (const chunk of stream) {
  process.stdout.write(chunk);
}
```

### Writing

```javascript
// Create parents, then write
await mkdir(dirname('out/data/result.json'), { recursive: true });
await writeFile('out/data/result.json', JSON.stringify(data, null, 2));

// Append
await appendFile('app.log', `${new Date().toISOString()} event\n`);

// Atomic write (write temp, then rename)
import { randomUUID } from 'node:crypto';
const tmp = `config.json.${randomUUID()}.tmp`;
await writeFile(tmp, JSON.stringify(cfg, null, 2));
await rename(tmp, 'config.json');
```

### Directory Operations

```javascript
// Create nested directories
await mkdir('src/components/ui', { recursive: true });

// List with type info
const entries = await readdir('src', { withFileTypes: true });
const dirs = entries.filter(e => e.isDirectory()).map(e => e.name);

// Recursive listing (Node 20+)
const all = await readdir('src', { withFileTypes: true, recursive: true });

// Copy tree and remove
await cp('src', 'backup/src', { recursive: true });
await rm('dist', { recursive: true, force: true });
```

### Existence and Metadata

```javascript
// Check existence (idiomatic pattern)
try {
  await access('config.json');
} catch {
  // does not exist
}

// Get file stats
const info = await stat('package.json');
console.log(info.size, info.mtime, info.isFile());
```

### Temporary Files

```javascript
const tmpDir = await mkdtemp(join(tmpdir(), 'myapp-'));
try {
  await writeFile(join(tmpDir, 'temp.json'), data);
  // work with temp files
} finally {
  await rm(tmpDir, { recursive: true, force: true });
}
```

## Safety Rules

1. **Always use `path.join()`** — never concatenate paths with string `+` and `/`
2. **Create parent directories** before writing with `mkdir(dir, { recursive: true })`
3. **Specify encoding explicitly** — `readFile(path, 'utf-8')` returns a string; without encoding it returns a Buffer
4. **Handle ENOENT gracefully** — check for file existence before operations or catch the error by code
5. **Never use sync functions in async code** — `readFileSync` blocks the event loop and kills server throughput
6. **Use streams for large files** — `createReadStream`/`createWriteStream` for files over 100MB to avoid OOM
7. **Atomic writes for critical files** — write to a temp file then `rename` to prevent corruption on crash
8. **Clean up temp directories** in `finally` blocks so they do not accumulate

## Edge Cases

- `readFile` without encoding returns a `Buffer`, not a string — forgetting `'utf-8'` is a common bug
- `readdir` returns name strings by default — use `{ withFileTypes: true }` for Dirent objects with type methods
- `rm` needs `{ recursive: true }` for directories; add `{ force: true }` to suppress ENOENT errors
- `rename` fails across filesystem boundaries (e.g., `/tmp` to `/home`) — use `cp` + `rm` instead
- `stat` follows symlinks — use `lstat` to inspect the symlink itself without resolving
- `watch` behavior varies across operating systems — use `chokidar` for production file watching
- File permissions on Windows are limited — `mode` bits from `stat` are not fully meaningful
- `readdir` with `{ recursive: true }` requires Node 20+ — older versions need manual recursion
