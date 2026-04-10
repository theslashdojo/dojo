const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, mkdirSync, writeFileSync } = require('fs');
const { join } = require('path');
const { tmpdir } = require('os');

const {
  normalizeCliOptions,
  parseCliArgs,
  runCli,
  validate
} = require('../scripts/validate-node.js');

function writeManifest(rootDir, relativePath, manifest) {
  const filePath = join(rootDir, relativePath, 'node.json');
  mkdirSync(join(rootDir, relativePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(manifest, null, 2));
  return filePath;
}

test('validate accepts a spec-aligned node with knowledge content', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-validate-'));

  writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem for validation tests.',
    parent: null,
    tags: ['sample'],
    body: '# Sample\n\nLinks to [[sample/spec#manifest-core]].',
    sections: [
      { id: 'overview', title: 'Overview', body: 'Enough detail to count as a section for testing.', tags: ['overview'] }
    ],
    aliases: ['sample ecosystem', 'validation sample'],
    triggers: ['sample ecosystem', 'validate sample'],
    links: [{ uri: 'sample/spec#manifest-core', context: 'Spec section link' }],
    related: [{ uri: 'sample/spec', relation: 'see-also', note: 'Spec companion' }],
    repository: 'https://example.com/sample',
    created: '2026-04-05T00:00:00Z',
    updated: '2026-04-09T00:00:00Z',
    status: 'published'
  });

  const path = writeManifest(rootDir, 'sample/spec', {
    name: 'spec',
    version: '1.0.0',
    uri: 'sample/spec',
    type: 'skill',
    context: 'Spec skill',
    info: 'Executable node for validation tests.',
    parent: 'sample',
    tags: ['sample', 'spec'],
    aliases: ['sample spec', 'spec node'],
    triggers: ['run sample spec', 'sample spec'],
    body: '# Spec\n\nUse [[sample/spec#details]] and then [[sample/spec/check]]. This validation fixture deliberately carries enough explanatory text to satisfy the strict knowledge threshold, demonstrate realistic long-form guidance, and show that a strong executable node can both teach the workflow and point to the next concrete action.',
    sections: [
      { id: 'details', title: 'Details', body: 'Detailed section text that is comfortably over sixty characters.', tags: ['details'] },
      { id: 'workflow', title: 'Workflow', body: 'Another detailed section explaining the workflow and next steps.', tags: ['workflow'] }
    ],
    links: [{ uri: 'sample/spec/check#steps', context: 'Executable follow-up' }],
    related: [{ uri: 'sample', relation: 'prerequisite', note: 'Lives under the sample ecosystem' }],
    scripts: [{ id: 'run-spec', name: 'Run Spec', lang: 'javascript', entry: './scripts/run-spec.js' }],
    schema: { input: { type: 'object' }, output: { type: 'object' } },
    repository: 'https://example.com/sample',
    created: '2026-04-05T00:00:00Z',
    updated: '2026-04-09T00:00:00Z',
    status: 'published'
  });

  writeManifest(rootDir, 'sample/spec/check', {
    name: 'check',
    version: '1.0.0',
    uri: 'sample/spec/check',
    type: 'sub',
    context: 'Check sub-skill',
    info: 'Child executable node used as a follow-up link target.',
    parent: 'sample/spec',
    tags: ['sample', 'check'],
    aliases: ['sample check', 'check step'],
    triggers: ['check sample', 'sample follow-up'],
    body: '# Check\n\nDetailed text with [[sample/spec#workflow]].',
    sections: [
      { id: 'steps', title: 'Steps', body: 'Detailed steps for the sub-skill so section addressing is meaningful.', tags: ['steps'] }
    ],
    links: [{ uri: 'sample/spec#workflow', context: 'Back to the workflow section' }],
    related: [{ uri: 'sample/spec', relation: 'implements', note: 'Implements the spec workflow' }],
    scripts: [{ id: 'run-check', name: 'Run Check', lang: 'javascript', entry: './scripts/run-check.js' }],
    schema: { input: { type: 'object' }, output: { type: 'object' } },
    repository: 'https://example.com/sample',
    created: '2026-04-05T00:00:00Z',
    updated: '2026-04-09T00:00:00Z',
    status: 'published'
  });

  const result = validate({ path, rootDir, strict: true, requireKnowledge: true });

  assert.equal(result.valid, true);
  assert.deepEqual(result.errors, []);
  assert.equal(result.warnings.length, 0);
  assert.equal(result.summary.type, 'skill');
});

test('validate flags broken parent relationships', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-validate-'));

  writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem for validation tests.',
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
    info: 'Context node used as an invalid parent.',
    parent: 'sample',
    tags: ['sample', 'docs']
  });

  const path = writeManifest(rootDir, 'sample/docs/check', {
    name: 'check',
    version: '1.0.0',
    uri: 'sample/docs/check',
    type: 'sub',
    context: 'Broken sub node',
    info: 'This should fail because the parent is not a skill.',
    parent: 'sample/docs',
    tags: ['sample', 'broken'],
    scripts: [{ id: 'run-check', name: 'Run Check', lang: 'javascript', entry: './scripts/run-check.js' }],
    schema: { input: { type: 'object' }, output: { type: 'object' } }
  });

  const result = validate({ path, rootDir });

  assert.equal(result.valid, false);
  assert.ok(result.errors.includes('sub nodes must have a skill parent'));
});

test('validate warns when section-target references point to missing sections', () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-validate-'));

  writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem for validation tests.',
    parent: null,
    tags: ['sample']
  });

  writeManifest(rootDir, 'sample/spec', {
    name: 'spec',
    version: '1.0.0',
    uri: 'sample/spec',
    type: 'context',
    content_type: 'reference',
    context: 'Reference node',
    info: 'Reference node with one valid section.',
    parent: 'sample',
    tags: ['sample', 'spec'],
    sections: [
      { id: 'manifest-core', title: 'Manifest core', body: 'Detailed section text that is comfortably over sixty characters.', tags: ['manifest'] }
    ]
  });

  const path = writeManifest(rootDir, 'sample/docs', {
    name: 'docs',
    version: '1.0.0',
    uri: 'sample/docs',
    type: 'context',
    content_type: 'guide',
    context: 'Docs node',
    info: 'This node links to [[sample/spec#missing-section]] and should warn.',
    parent: 'sample',
    tags: ['sample', 'docs'],
    links: [{ uri: 'sample/spec#missing-section', context: 'Broken section link' }]
  });

  const result = validate({ path, rootDir });

  assert.equal(result.valid, true);
  assert.ok(result.warnings.some((warning) => warning.includes('link references unknown section: sample/spec#missing-section')));
  assert.ok(result.warnings.some((warning) => warning.includes('wiki-link in info references unknown section: sample/spec#missing-section')));
});

test('normalizeCliOptions parses strict validation flags', () => {
  const options = normalizeCliOptions(parseCliArgs([
    '/tmp/node.json',
    '--root-dir', '/tmp/nodes',
    '--strict', 'true',
    '--require-knowledge', 'true'
  ]));

  assert.deepEqual(options, {
    path: '/tmp/node.json',
    rootDir: '/tmp/nodes',
    root_dir: '/tmp/nodes',
    strict: true,
    requireKnowledge: true,
    require_knowledge: 'true'
  });
});

test('runCli emits JSON validation results', async () => {
  const rootDir = mkdtempSync(join(tmpdir(), 'dojo-validate-cli-'));
  const path = writeManifest(rootDir, 'sample', {
    name: 'sample',
    version: '1.0.0',
    uri: 'sample',
    type: 'ecosystem',
    context: 'Sample ecosystem',
    info: 'Root ecosystem for CLI validation tests.',
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
  assert.equal(payload.summary.uri, 'sample');
});
