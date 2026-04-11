#!/usr/bin/env node
// File operations utility using Node.js fs/promises
// Usage: node file-operations.js <operation> <path> [content]
// Operations: read, write, append, list, stat, mkdir, exists, copy, remove

import { readFile, writeFile, appendFile, readdir, mkdir, stat, access, cp, rm, rename } from 'node:fs/promises';
import { join, resolve, dirname, basename, extname } from 'node:path';

const USAGE = `Usage: node file-operations.js <operation> <path> [content] [options]

Operations:
  read    <path>                    Read file contents to stdout
  write   <path> <content>          Write content to file (creates parent dirs)
  append  <path> <content>          Append content to file
  list    <path> [--recursive]      List directory contents
  stat    <path>                    Show file metadata as JSON
  mkdir   <path>                    Create directory (recursive)
  exists  <path>                    Check if file or directory exists
  copy    <src> <dest>              Copy file or directory
  remove  <path> [--force]          Remove file or directory

Options:
  --recursive    Recursive listing or removal
  --force        Force removal (ignore missing)
  --json         Output as JSON (for list and stat)`;

const args = process.argv.slice(2);
const operation = args[0];
const targetPath = args[1];

if (!operation || !targetPath || args.includes('--help') || args.includes('-h')) {
  console.log(USAGE);
  process.exit(operation ? 0 : 1);
}

const flags = new Set(args.filter(a => a.startsWith('--')));
const positional = args.filter(a => !a.startsWith('--'));
const resolvedPath = resolve(targetPath);
const asJson = flags.has('--json');

async function main() {
  switch (operation) {
    case 'read': {
      const content = await readFile(resolvedPath, 'utf-8');
      process.stdout.write(content);
      if (!content.endsWith('\n')) process.stdout.write('\n');
      break;
    }

    case 'write': {
      const content = positional.slice(2).join(' ');
      if (!content) {
        console.error('Error: write operation requires content argument');
        process.exit(1);
      }
      await mkdir(dirname(resolvedPath), { recursive: true });
      await writeFile(resolvedPath, content, 'utf-8');
      console.error(`Written ${Buffer.byteLength(content, 'utf-8')} bytes to ${resolvedPath}`);
      break;
    }

    case 'append': {
      const content = positional.slice(2).join(' ');
      if (!content) {
        console.error('Error: append operation requires content argument');
        process.exit(1);
      }
      await appendFile(resolvedPath, content, 'utf-8');
      console.error(`Appended ${Buffer.byteLength(content, 'utf-8')} bytes to ${resolvedPath}`);
      break;
    }

    case 'list': {
      const recursive = flags.has('--recursive');
      const entries = await readdir(resolvedPath, { withFileTypes: true, recursive });
      const results = entries.map(entry => {
        const type = entry.isDirectory() ? 'dir' : entry.isSymbolicLink() ? 'link' : 'file';
        const entryPath = entry.parentPath
          ? join(entry.parentPath, entry.name)
          : entry.name;
        return { name: entryPath, type };
      });

      if (asJson) {
        console.log(JSON.stringify(results, null, 2));
      } else {
        for (const entry of results) {
          console.log(`${entry.type}\t${entry.name}`);
        }
      }
      break;
    }

    case 'stat': {
      const info = await stat(resolvedPath);
      const result = {
        path: resolvedPath,
        basename: basename(resolvedPath),
        extname: extname(resolvedPath),
        size: info.size,
        isFile: info.isFile(),
        isDirectory: info.isDirectory(),
        isSymbolicLink: info.isSymbolicLink(),
        created: info.birthtime.toISOString(),
        modified: info.mtime.toISOString(),
        accessed: info.atime.toISOString(),
        permissions: '0' + (info.mode & 0o777).toString(8),
      };
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'mkdir': {
      await mkdir(resolvedPath, { recursive: true });
      console.log(`Created directory: ${resolvedPath}`);
      break;
    }

    case 'exists': {
      try {
        await access(resolvedPath);
        const info = await stat(resolvedPath);
        const type = info.isDirectory() ? 'directory' : info.isSymbolicLink() ? 'symlink' : 'file';
        console.log(`exists (${type}): ${resolvedPath}`);
        process.exit(0);
      } catch {
        console.log(`not found: ${resolvedPath}`);
        process.exit(1);
      }
      break;
    }

    case 'copy': {
      const dest = positional[2];
      if (!dest) {
        console.error('Error: copy operation requires a destination path');
        process.exit(1);
      }
      const resolvedDest = resolve(dest);
      await mkdir(dirname(resolvedDest), { recursive: true });
      await cp(resolvedPath, resolvedDest, { recursive: true });
      console.log(`Copied ${resolvedPath} -> ${resolvedDest}`);
      break;
    }

    case 'remove': {
      const force = flags.has('--force');
      const recursive = flags.has('--recursive');
      await rm(resolvedPath, { recursive: recursive || true, force });
      console.log(`Removed: ${resolvedPath}`);
      break;
    }

    default:
      console.error(`Unknown operation: ${operation}`);
      console.error(`Run with --help for usage information`);
      process.exit(1);
  }
}

main().catch((err) => {
  if (err.code === 'ENOENT') {
    console.error(`Error: not found — ${resolvedPath}`);
  } else if (err.code === 'EACCES') {
    console.error(`Error: permission denied — ${resolvedPath}`);
  } else if (err.code === 'EISDIR') {
    console.error(`Error: is a directory — ${resolvedPath}`);
  } else if (err.code === 'ENOTDIR') {
    console.error(`Error: not a directory — ${resolvedPath}`);
  } else if (err.code === 'ENOTEMPTY') {
    console.error(`Error: directory not empty — ${resolvedPath}`);
  } else {
    console.error(`Error [${err.code || 'UNKNOWN'}]: ${err.message}`);
  }
  process.exit(1);
});
