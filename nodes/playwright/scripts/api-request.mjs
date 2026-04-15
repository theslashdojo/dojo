#!/usr/bin/env node
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { parseArgs } from 'node:util';

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    method: { type: 'string', short: 'X', default: 'GET' },
    header: { type: 'string', short: 'H', multiple: true },
    data: { type: 'string', short: 'd' },
    output: { type: 'string', short: 'o' },
    'base-url': { type: 'string' },
    'storage-state': { type: 'string' },
    timeout: { type: 'string', default: '30000' },
    fail: { type: 'boolean', default: false }
  }
});

const url = positionals[0];
if (!url) {
  console.error('Usage: api-request.mjs <url> [-X METHOD] [-H "Name: value"] [-d body] [-o response.json] [--fail]');
  process.exit(2);
}

let request;
try {
  ({ request } = await import('@playwright/test'));
} catch {
  console.error('The "@playwright/test" package is required. Install it with: npm install -D @playwright/test');
  process.exit(1);
}

const headers = {};
for (const header of values.header || []) {
  const splitAt = header.indexOf(':');
  if (splitAt === -1) {
    console.error(`Invalid header "${header}". Use "Name: value".`);
    process.exit(2);
  }
  headers[header.slice(0, splitAt).trim()] = header.slice(splitAt + 1).trim();
}

const context = await request.newContext({
  baseURL: values['base-url'],
  extraHTTPHeaders: headers,
  storageState: values['storage-state']
});

const response = await context.fetch(url, {
  method: values.method.toUpperCase(),
  data: values.data,
  timeout: Number(values.timeout)
});

const body = await response.text();
const outputPath = values.output ? resolve(values.output) : null;
if (outputPath) {
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, body, 'utf8');
}

const result = {
  url: response.url(),
  status: response.status(),
  ok: response.ok(),
  headers: response.headers(),
  output: outputPath,
  bodyPreview: body.slice(0, 2000)
};

await context.dispose();
console.log(JSON.stringify(result, null, 2));

if (values.fail && !response.ok()) {
  process.exit(1);
}
