const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { execFile } = require('node:child_process');
const { mkdtempSync, mkdirSync, writeFileSync } = require('node:fs');
const { join } = require('node:path');
const { tmpdir } = require('node:os');

const PUBLISH_NODE = '/workspaces/Contracts/dojo/nodes/dojo/publish/scripts/publish-node.sh';
const PUBLISH_REGISTRY = '/workspaces/Contracts/dojo/nodes/dojo/publish/registry/scripts/publish-registry.sh';
const REHEARSE_RELEASE = '/workspaces/Contracts/dojo/nodes/dojo/publish/local/scripts/rehearse-release.sh';

function writeManifest(rootDir, relativePath, manifest) {
  const filePath = join(rootDir, relativePath, 'node.json');
  mkdirSync(join(rootDir, relativePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(manifest, null, 2));
  return filePath;
}

function runScript(scriptPath, args, env = {}) {
  return new Promise((resolve, reject) => {
    execFile(
      'bash',
      [scriptPath, ...args],
      {
        env: { ...process.env, ...env },
        encoding: 'utf8'
      },
      (error, stdout, stderr) => {
        if (error) {
          error.stdout = stdout;
          error.stderr = stderr;
          reject(error);
          return;
        }
        resolve(stdout.trim());
      }
    );
  });
}

async function startJsonServer(handler) {
  const server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  return {
    server,
    url: `http://127.0.0.1:${address.port}`
  };
}

test('publish-node dry run returns a structured preview', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-publish-'));
  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.2.3',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'guide',
    context: 'Sample docs node',
    info: 'Sample manifest used for publish dry-run tests.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const output = await runScript(PUBLISH_NODE, [path], { DOJO_DRY_RUN: 'true' });
  const data = JSON.parse(output);

  assert.deepEqual(data, {
    published: false,
    status: 'dry-run',
    uri: 'sample/docs',
    version: '1.2.3',
    next: 'Run dojo/publish/local, then dojo/publish/registry'
  });
});

test('publish-registry normalizes successful live responses', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-publish-'));
  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.2.3',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'guide',
    context: 'Sample docs node',
    info: 'Sample manifest used for publish tests.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const { server, url } = await startJsonServer((req, res) => {
    if (req.method === 'POST' && req.url === '/v1/skills') {
      res.writeHead(201, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ uri: 'sample/docs', version: '1.2.3' }));
      return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'not found' }));
  });

  try {
    const output = await runScript(PUBLISH_REGISTRY, [path, url, 'false'], { DOJO_TOKEN: 'test-token' });
    const data = JSON.parse(output);

    assert.deepEqual(data, {
      published: true,
      status: 'published',
      uri: 'sample/docs',
      version: '1.2.3'
    });
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('rehearse-release returns structured route checks', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-publish-'));
  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.2.3',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'guide',
    context: 'Sample docs node',
    info: 'Sample manifest used for rehearsal tests.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const { server, url } = await startJsonServer((req, res) => {
    const okRoutes = new Set([
      '/v1/search?q=docs',
      '/v1/tree/sample',
      '/v1/skills/sample/docs',
      '/v1/learn/sample/docs',
      '/v1/bundle/sample/docs'
    ]);
    if (req.method === 'GET' && okRoutes.has(req.url)) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true }));
      return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'not found' }));
  });

  try {
    const output = await runScript(REHEARSE_RELEASE, [path, 'sample/docs', 'sample', url]);
    const data = JSON.parse(output);

    assert.equal(data.passed, true);
    assert.equal(data.checks.length, 5);
    assert.deepEqual(
      data.checks.map((check) => check.name),
      ['search', 'tree', 'skill', 'learn', 'bundle']
    );
    for (const check of data.checks) {
      assert.equal(check.status, 200);
      assert.ok(check.url.startsWith(url));
    }
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
