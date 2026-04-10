const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, mkdirSync, writeFileSync } = require('fs');
const { join } = require('path');
const { tmpdir } = require('os');

const {
  normalizeCliOptions,
  parseCliArgs,
  runCli,
  validateSchema
} = require('../scripts/schema-only.js');

function writeManifest(rootDir, relativePath, manifest) {
  const filePath = join(rootDir, relativePath, 'node.json');
  mkdirSync(join(rootDir, relativePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(manifest, null, 2));
  return filePath;
}

test('validateSchema catches invalid hierarchy and metadata', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-schema-'));

  writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem.',
    parent: null,
    tags: ['sample']
  });

  writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.0.0',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'reference',
    context: 'Docs context',
    info: 'Used as a bad parent for a sub node.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const path = writeManifest(rootDir, 'sample/docs/check', {
    name: 'check',
    version: '1.0',
    uri: 'sample/docs/check',
    type: 'sub',
    context: 'Broken sub',
    info: 'This manifest is intentionally invalid.',
    parent: 'sample/docs',
    tags: ['sample', 'broken'],
    scripts: [{ id: 'run-check', name: 'Run Check', lang: 'javascript', entry: './scripts/run-check.js' }],
    schema: { input: { type: 'object' }, output: { type: 'object' } }
  });

  const result = validateSchema({ path, rootDir });

  assert.equal(result.valid, false);
  assert.ok(result.errors.includes('version must be valid semver'));
  assert.ok(result.errors.includes('sub nodes must have a skill parent'));
  assert.ok(result.warnings.some((warning) => warning.includes('repository')));
});

test('normalizeCliOptions accepts path and root dir', () => {
  const options = normalizeCliOptions(parseCliArgs([
    '/tmp/node.json',
    '--root-dir', '/tmp/nodes'
  ]));

  assert.deepEqual(options, {
    path: '/tmp/node.json',
    rootDir: '/tmp/nodes',
    root_dir: '/tmp/nodes'
  });
});

test('runCli emits JSON for schema validation', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-schema-cli-'));
  const path = writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem.',
    parent: null,
    tags: ['sample']
  });

  const stdout = { chunks: [], write(chunk) { this.chunks.push(chunk); } };
  const stderr = { chunks: [], write(chunk) { this.chunks.push(chunk); } };

  const exitCode = await runCli([path, '--root-dir', rootDir], stdout, stderr);
  assert.equal(exitCode, 0);
  assert.equal(stderr.chunks.length, 0);

  const payload = JSON.parse(stdout.chunks.join(''));
  assert.equal(payload.valid, true);
  assert.deepEqual(payload.errors, []);
});
