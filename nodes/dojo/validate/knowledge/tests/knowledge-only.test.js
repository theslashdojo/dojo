const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, mkdirSync, writeFileSync } = require('fs');
const { join } = require('path');
const { tmpdir } = require('os');

const {
  normalizeCliOptions,
  parseCliArgs,
  runCli,
  validateKnowledge
} = require('../scripts/knowledge-only.js');

function writeManifest(rootDir, relativePath, manifest) {
  const filePath = join(rootDir, relativePath, 'node.json');
  mkdirSync(join(rootDir, relativePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(manifest, null, 2));
  return filePath;
}

test('validateKnowledge accepts strong knowledge content', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-knowledge-'));

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

  writeManifest(rootDir, 'sample/run', {
    name: 'run',
    version: '1.0.0',
    uri: 'sample/run',
    type: 'skill',
    context: 'Executable target',
    info: 'Used as an executable follow-up target.',
    parent: 'sample',
    tags: ['sample', 'run'],
    scripts: [{ id: 'run', name: 'Run', lang: 'javascript', entry: './scripts/run.js' }],
    schema: { input: { type: 'object' }, output: { type: 'object' } }
  });

  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.0.0',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'guide',
    context: 'Docs context',
    info: 'Knowledge-heavy node for tests.',
    parent: 'sample',
    tags: ['sample', 'docs'],
    aliases: ['sample docs', 'sample guide'],
    triggers: ['sample docs', 'read sample guide'],
    body: '# Docs\n\nThis is a sufficiently long body with a wiki-link to [[sample/run]] and enough context to clear the minimum body threshold used by the validator.',
    sections: [
      {
        id: 'overview',
        title: 'Overview',
        body: 'Detailed section content that is long enough to be useful when loaded directly from a learn endpoint.',
        tags: ['overview']
      }
    ],
    links: [
      { uri: 'sample/run', context: 'Executable next step' },
      { uri: 'sample/docs#overview', context: 'Section-level anchor' }
    ],
    related: [{ uri: 'sample/run', relation: 'see-also', note: 'Useful follow-up action' }]
  });

  const result = validateKnowledge({ path, rootDir, minSections: 1, minBodyLength: 120 });

  assert.equal(result.valid, true);
  assert.equal(result.warnings.length, 0);
  assert.equal(result.stats.links, 2);
});

test('validateKnowledge flags thin discovery and graph data', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-knowledge-'));

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

  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.0.0',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'reference',
    context: 'Thin docs context',
    info: 'Not enough detail for a strong learn payload.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const result = validateKnowledge({ path, rootDir });

  assert.equal(result.valid, false);
  assert.ok(result.warnings.some((warning) => warning.includes('aliases')));
  assert.ok(result.warnings.some((warning) => warning.includes('graph dead end')));
});

test('normalizeCliOptions parses knowledge thresholds', () => {
  const options = normalizeCliOptions(parseCliArgs([
    '/tmp/node.json',
    '--root-dir', '/tmp/nodes',
    '--require-aliases', 'false',
    '--min-sections', '2',
    '--min-body-length', '240',
    '--require-executable-link', 'true'
  ]));

  assert.deepEqual(options, {
    path: '/tmp/node.json',
    rootDir: '/tmp/nodes',
    root_dir: '/tmp/nodes',
    requireAliases: false,
    require_aliases: 'false',
    minSections: 2,
    min_sections: '2',
    minBodyLength: 240,
    min_body_length: '240',
    requireExecutableLink: true,
    require_executable_link: 'true'
  });
});

test('runCli emits JSON for knowledge validation', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-knowledge-cli-'));

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

  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.0.0',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'reference',
    context: 'Thin docs context',
    info: 'Not enough detail for a strong learn payload.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const stdout = { chunks: [], write(chunk) { this.chunks.push(chunk); } };
  const stderr = { chunks: [], write(chunk) { this.chunks.push(chunk); } };

  const exitCode = await runCli([path, '--root-dir', rootDir], stdout, stderr);
  assert.equal(exitCode, 0);
  assert.equal(stderr.chunks.length, 0);

  const payload = JSON.parse(stdout.chunks.join(''));
  assert.equal(payload.valid, false);
  assert.ok(payload.warnings.length > 0);
});
