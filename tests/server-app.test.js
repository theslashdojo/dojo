const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

let server;
let baseUrl;
const SERVER_ENTRY = path.resolve(__dirname, '../server/src/server.js');

before(async () => {
  const { createApp, SkillStore, DEFAULT_MANIFEST_DIRS } = await import('../server/src/server.js');
  const { app } = createApp({
    store: new SkillStore(DEFAULT_MANIFEST_DIRS),
    serveStatic: false
  });

  server = await new Promise(resolve => {
    const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
  });

  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (!server) return;
  await new Promise((resolve, reject) => server.close(error => (error ? reject(error) : resolve())));
});

async function api(path, options = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options
  });

  return {
    status: res.status,
    data: await res.json()
  };
}

test('search exposes reasons and execution metadata for native ETH send', async () => {
  const { status, data } = await api('/v1/search?q=send%20eth&mode=do&executable=true');

  assert.equal(status, 200);
  assert.ok(data.results.length > 0);
  assert.equal(data.results[0].uri, 'ethereum/transactions/send');
  assert.ok(Array.isArray(data.results[0].reasons));
  assert.ok(data.results[0].reasons.length > 0);
  assert.equal(data.results[0].execution.can_execute, true);
  assert.ok(data.results[0].execution.required_env.includes('RPC_URL'));
  assert.equal(data.results[0].routes.bundle, '/v1/bundle/ethereum/transactions/send');
});

test('index exposes discover and bundle routes', async () => {
  const { status, data } = await api('/v1');

  assert.equal(status, 200);
  assert.equal(data.routes.discover, '/v1/discover');
  assert.equal(data.routes.bundle, '/v1/bundle/*');
});

test('server auto-start detection supports PM2 exec paths', async () => {
  const { shouldAutoStart } = await import('../server/src/server.js');

  assert.equal(shouldAutoStart(SERVER_ENTRY), true);
  assert.equal(shouldAutoStart('/tmp/not-the-server.js', SERVER_ENTRY), true);
  assert.equal(shouldAutoStart('/tmp/not-the-server.js', '/tmp/also-not-the-server.js'), false);
});

test('discover returns learn-first and then-do guidance', async () => {
  const { status, data } = await api('/v1/discover?q=how%20do%20i%20validate%20a%20dojo%20node&current_context=dojo');

  assert.equal(status, 200);
  assert.ok(data.best_match);
  assert.ok(Array.isArray(data.learn_first));
  assert.ok(Array.isArray(data.then_do));
  assert.ok(data.learn_first.length > 0);
  assert.ok(data.then_do.length > 0);
  assert.ok(data.learn_first[0].sections);
  assert.ok(data.then_do[0].execution.can_execute);
});

test('learn with question returns relevant sections', async () => {
  const { status, data } = await api('/v1/learn/dojo/api?question=where%20is%20the%20bundle%20route');

  assert.equal(status, 200);
  assert.ok(Array.isArray(data.relevant_sections));
  assert.ok(data.relevant_sections.some(section => section.id === 'bundle-route'));
});

test('bundle returns portable packages for executable dojo nodes', async () => {
  const bundles = [
    { uri: 'dojo/authoring', script: 'scripts/create-node.sh' },
    { uri: 'dojo/skill', script: 'scripts/use-dojo-skill.js', reference: 'references/workflows.md' },
    { uri: 'dojo/api/query', script: 'scripts/query-registry.js', reference: 'references/operations.md' },
    { uri: 'dojo/validate', script: 'scripts/validate-node.js', reference: 'references/checks.md' },
    { uri: 'dojo/validate/schema', script: 'scripts/schema-only.js' },
    { uri: 'dojo/validate/knowledge', script: 'scripts/knowledge-only.js' },
    { uri: 'dojo/publish', script: 'scripts/publish-node.sh', reference: 'references/release-flow.md' },
    { uri: 'dojo/publish/local', script: 'scripts/rehearse-release.sh' },
    { uri: 'dojo/publish/registry', script: 'scripts/publish-registry.sh' }
  ];

  for (const bundle of bundles) {
    const { status, data } = await api(`/v1/bundle/${bundle.uri}`);

    assert.equal(status, 200);
    assert.equal(data.uri, bundle.uri);
    assert.equal(data.entrypoints.manifest, 'node.json');
    assert.equal(data.entrypoints.skill_md, 'SKILL.md');
    assert.ok(data.entrypoints.agents.includes('agents/openai.yaml'));
    assert.ok(data.entrypoints.scripts.includes(bundle.script));
    if (bundle.reference) {
      assert.ok(data.entrypoints.references.includes(bundle.reference));
    }
    assert.ok(data.files.some(file => file.path === 'SKILL.md'));
  }
});

test('agent ask recommends the send skill with readiness details', async () => {
  const { status, data } = await api('/v1/agent/ask', {
    method: 'POST',
    body: JSON.stringify({
      message: 'send eth to another address on base',
      agent_context: { capabilities: ['javascript'], has_env: [] }
    })
  });

  assert.equal(status, 200);
  assert.equal(data.recommendation, 'ethereum/transactions/send');
  assert.equal(data.recommendation_node.execution.can_execute, true);
  assert.ok(data.required_input_fields.includes('to'));
  assert.ok(data.missing_env.includes('RPC_URL'));
  assert.ok(data.missing_env.includes('PRIVATE_KEY'));
});

test('agent learn finds nonce-oriented transaction guidance', async () => {
  const { status, data } = await api('/v1/agent/learn', {
    method: 'POST',
    body: JSON.stringify({
      question: 'how do i handle nonce when sending eth',
      current_context: ['ethereum']
    })
  });

  assert.equal(status, 200);
  assert.ok(data.answer_nodes.length > 0);
  assert.ok(
    data.answer_nodes.some(node =>
      (node.sections || []).some(section => section.id.includes('nonce'))
    )
  );
});

test('agent learn can route dojo information-finding prompts to the dojo skill', async () => {
  const { status, data } = await api('/v1/agent/learn', {
    method: 'POST',
    body: JSON.stringify({
      question: 'how do i find info in dojo',
      current_context: ['dojo']
    })
  });

  assert.equal(status, 200);
  assert.ok(data.answer_nodes.some(node => node.uri === 'dojo/skill'));
});
