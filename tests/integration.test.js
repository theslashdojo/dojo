/**
 * Dojo Registry Integration Tests
 *
 * Run with: node --test tests/integration.test.js
 * Requires server running at REGISTRY_URL (default: http://localhost:3000)
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

const REGISTRY = process.env.REGISTRY_URL || 'http://localhost:3000';

async function api(path, opts = {}) {
  const { headers, ...rest } = opts;
  const res = await fetch(`${REGISTRY}${path}`, {
    ...rest,
    headers: { 'Content-Type': 'application/json', ...(headers || {}) }
  });
  return { status: res.status, data: await res.json() };
}

describe('Registry Index', () => {
  it('GET /v1 returns registry metadata', async () => {
    const { status, data } = await api('/v1');
    assert.equal(status, 200);
    assert.equal(data.registry, 'dojo');
    assert.ok(data.total_skills > 0, 'Should have loaded nodes');
    assert.ok(data.ecosystems.length > 0, 'Should list ecosystems');
  });
});

describe('Skill Resolution', () => {
  it('GET /v1/resolve finds skills by natural language', async () => {
    const { data } = await api('/v1/resolve?need=deploy+smart+contract');
    assert.ok(data.results.length > 0, 'Should find matching skills');
    assert.ok(data.results[0].score > 0, 'Results should have scores');
    assert.ok(data.results[0].uri.includes('deploy') || data.results[0].uri.includes('contract'));
  });

  it('GET /v1/resolve filters by tags', async () => {
    const { data } = await api('/v1/resolve?need=storage&tags=s3,aws');
    assert.ok(data.results.some(r => r.uri.startsWith('aws/')));
  });

  it('GET /v1/resolve filters by type', async () => {
    const { data } = await api('/v1/resolve?need=openai&type=ecosystem');
    for (const r of data.results) {
      assert.equal(r.skill.type, 'ecosystem');
    }
  });

  it('GET /v1/resolve returns empty for nonsense', async () => {
    const { data } = await api('/v1/resolve?need=xyzzy123nonexistent');
    assert.equal(data.results.length, 0);
  });

  it('GET /v1/resolve finds the native transaction skill for ethereum send flows', async () => {
    const { data } = await api('/v1/resolve?need=send%20an%20ethereum%20transaction');
    assert.ok(data.results.length > 0, 'Should find a transaction skill');
    assert.equal(data.results[0].uri, 'ethereum/transactions/send');
    assert.ok(Array.isArray(data.query_variants));
    assert.ok(data.query_variants.length >= 2, 'Should expose expanded query variants');
  });
});

describe('Skill Retrieval', () => {
  it('GET /v1/skills/openai returns the openai ecosystem', async () => {
    const { status, data } = await api('/v1/skills/openai');
    assert.equal(status, 200);
    assert.equal(data.skill.name, 'openai');
    assert.equal(data.skill.type, 'ecosystem');
    assert.ok(data.children.length > 0, 'Should have children');
  });

  it('GET /v1/skills/openai/chat returns full ancestry', async () => {
    const { data } = await api('/v1/skills/openai/chat');
    assert.equal(data.skill.uri, 'openai/chat');
    assert.ok(data.ancestors.length >= 1, 'Should have openai ancestor');
    assert.equal(data.ancestors[0].uri, 'openai');
  });

  it('GET /v1/skills/nonexistent returns 404', async () => {
    const { status } = await api('/v1/skills/nonexistent/thing');
    assert.equal(status, 404);
  });

  it('GET /v1/skills/dojo/validate exposes subs and context children', async () => {
    const { status, data } = await api('/v1/skills/dojo/validate');
    assert.equal(status, 200);
    assert.equal(data.skill.uri, 'dojo/validate');
    assert.ok(data.children.some(child => child.uri === 'dojo/validate/schema'));
    assert.ok(data.children.some(child => child.uri === 'dojo/validate/checklist'));
  });

  it('GET /v1/skills/ethereum/transactions/send exposes executable metadata', async () => {
    const { status, data } = await api('/v1/skills/ethereum/transactions/send');
    assert.equal(status, 200);
    assert.equal(data.skill.uri, 'ethereum/transactions/send');
    assert.equal(data.execution.can_execute, true);
    assert.ok(data.execution.required_env.includes('RPC_URL'));
    assert.ok(data.execution.required_env.includes('PRIVATE_KEY'));
  });
});

describe('Search', () => {
  it('GET /v1/search finds skills by keyword', async () => {
    const { data } = await api('/v1/search?q=token');
    assert.ok(data.results.length > 0);
    assert.ok(data.total > 0);
  });

  it('GET /v1/search filters by ecosystem', async () => {
    const { data } = await api('/v1/search?q=deploy&eco=openai');
    for (const r of data.results) {
      assert.ok(r.uri.startsWith('openai/'), `${r.uri} should be in openai`);
    }
  });

  it('GET /v1/search respects limit', async () => {
    const { data } = await api('/v1/search?q=deploy&limit=2');
    assert.ok(data.results.length <= 2);
  });

  it('GET /v1/search matches aliases from knowledge nodes', async () => {
    const { data } = await api('/v1/search?q=how%20to%20contribute%20to%20dojo');
    assert.ok(data.results.some(r => r.uri === 'dojo/contributing'));
  });

  it('GET /v1/search matches section and body text', async () => {
    const { data } = await api('/v1/search?q=local%20registry%20smoke%20test');
    assert.ok(
      data.results.some(r => ['dojo/publish/local', 'dojo/contributing'].includes(r.uri))
    );
  });

  it('GET /v1/search returns excerpts for ethereum transaction phrasing', async () => {
    const { data } = await api('/v1/search?q=send%20an%20ethereum%20transaction&mode=do&executable=true');
    assert.ok(data.results.some(r => r.uri === 'ethereum/transactions/send'));
    const match = data.results.find(r => r.uri === 'ethereum/transactions/send');
    assert.ok(match.excerpt, 'Should include an excerpt for agent explanations');
    assert.ok(match.routes.bundle, 'Should include bundle route metadata');
  });

  it('GET /v1/discover groups learn and do paths for agent navigation', async () => {
    const { status, data } = await api('/v1/discover?q=how%20do%20i%20validate%20a%20dojo%20node&current_context=dojo');
    assert.equal(status, 200);
    assert.ok(data.best_match);
    assert.ok(data.learn_first.length > 0);
    assert.ok(data.then_do.length > 0);
  });
});

describe('Ecosystem Tree', () => {
  it('GET /v1/tree/openai returns full tree', async () => {
    const { data } = await api('/v1/tree/openai');
    assert.equal(data.name, 'openai');
    assert.ok(data.skills.length > 0, 'Should have child standards');
  });

  it('GET /v1/tree/nonexistent returns 404', async () => {
    const { status } = await api('/v1/tree/nonexistent');
    assert.equal(status, 404);
  });

  it('GET /v1/tree/dojo includes context, standard, and skill children', async () => {
    const { status, data } = await api('/v1/tree/dojo');
    assert.equal(status, 200);
    const childTypes = new Set((data.skills || []).map(child => child.type));
    assert.ok(childTypes.has('context'));
    assert.ok(childTypes.has('standard'));
    assert.ok(childTypes.has('skill'));
  });
});

describe('Knowledge Layer', () => {
  it('GET /v1/ecosystems lists live ecosystems', async () => {
    const { status, data } = await api('/v1/ecosystems');
    assert.equal(status, 200);
    assert.ok(Array.isArray(data.ecosystems));
    assert.equal(data.ecosystems[0].uri, 'dojo');
  });

  it('GET /v1/learn/dojo returns body and sections', async () => {
    const { status, data } = await api('/v1/learn/dojo');
    assert.equal(status, 200);
    assert.equal(data.node.uri, 'dojo');
    assert.ok(data.node.body);
    assert.ok(data.node.sections.length > 0);
  });

  it('GET /v1/learn/dojo/knowledge includes executable follow-up in reading path', async () => {
    const { status, data } = await api('/v1/learn/dojo/knowledge');
    assert.equal(status, 200);
    assert.ok(data.reading_path.some(step => step.uri === 'dojo/api/query' && step.type === 'then_do'));
  });

  it('GET /v1/learn/dojo supports explicit section lookup', async () => {
    const { status, data } = await api('/v1/learn/dojo?section=workflow-map');
    assert.equal(status, 200);
    assert.equal(data.focused_section.id, 'workflow-map');
  });

  it('GET /v1/learn/dojo/api supports question-focused section lookup', async () => {
    const { status, data } = await api('/v1/learn/dojo/api?question=where%20is%20the%20bundle%20route');
    assert.equal(status, 200);
    assert.ok(data.relevant_sections.some(section => section.id === 'bundle-route'));
  });

  it('GET /v1/backlinks/dojo/spec returns backlinks', async () => {
    const { status, data } = await api('/v1/backlinks/dojo/spec');
    assert.equal(status, 200);
    assert.ok(data.backlinks.some(link => link.from === 'dojo'));
  });

  it('GET /v1/graph/dojo/spec returns a local graph', async () => {
    const { status, data } = await api('/v1/graph/dojo/spec?depth=1');
    assert.equal(status, 200);
    assert.equal(data.center, 'dojo/spec');
    assert.ok(data.nodes.some(node => node.uri === 'dojo/spec'));
    assert.ok(data.edges.length > 0);
  });

  it('GET /v1/alias resolves knowledge aliases', async () => {
    const { status, data } = await api('/v1/alias/how%20to%20contribute%20to%20dojo');
    assert.equal(status, 200);
    assert.equal(data.uri, 'dojo/contributing');
  });

  it('GET /v1/bundle/* returns portable packages for executable dojo nodes', async () => {
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
      assert.equal(data.entrypoints.skill_md, 'SKILL.md');
      assert.ok(data.entrypoints.agents.includes('agents/openai.yaml'));
      assert.ok(data.entrypoints.scripts.includes(bundle.script));
      if (bundle.reference) {
        assert.ok(data.entrypoints.references.includes(bundle.reference));
      }
    }
  });

  it('POST /v1/agent/learn uses rich knowledge content', async () => {
    const { status, data } = await api('/v1/agent/learn', {
      method: 'POST',
      body: JSON.stringify({
        question: 'how do i run a local registry smoke test before publishing',
        current_context: ['dojo']
      })
    });
    assert.equal(status, 200);
    assert.ok(
      data.answer_nodes.some(node =>
        ['dojo/contributing', 'dojo/validate/checklist', 'dojo/publish/local'].includes(node.uri)
      )
    );
  });

  it('POST /v1/agent/learn includes excerpts and context-aware ethereum guidance', async () => {
    const { status, data } = await api('/v1/agent/learn', {
      method: 'POST',
      body: JSON.stringify({
        question: 'how do i estimate gas before sending eth',
        current_context: ['ethereum/transactions/send']
      })
    });

    assert.equal(status, 200);
    assert.ok(data.answer_nodes.some(node => node.uri === 'ethereum/gas'));
    const gasNode = data.answer_nodes.find(node => node.uri === 'ethereum/gas');
    assert.ok(gasNode.excerpt);
  });
});

describe('Agent Ask', () => {
  it('POST /v1/agent/ask returns recommendation', async () => {
    const { data } = await api('/v1/agent/ask', {
      method: 'POST',
      body: JSON.stringify({
        message: 'I need to deploy a Solidity contract to Base chain',
        agent_context: { capabilities: ['javascript'], has_env: ['RPC_URL'] }
      })
    });
    assert.ok(data.recommendation, 'Should return a recommendation');
    assert.ok(data.explanation, 'Should explain the recommendation');
    assert.ok(data.install, 'Should include install command');
    assert.ok(data.skill, 'Should include the full node manifest');
  });

  it('POST /v1/agent/ask identifies missing env', async () => {
    const { data } = await api('/v1/agent/ask', {
      method: 'POST',
      body: JSON.stringify({
        message: 'deploy a contract',
        agent_context: { capabilities: ['javascript'], has_env: [] }
      })
    });
    if (data.missing_env) {
      assert.ok(data.missing_env.length > 0, 'Should flag missing env vars');
    }
  });

  it('POST /v1/agent/ask recommends the native transaction skill for send eth requests', async () => {
    const { data } = await api('/v1/agent/ask', {
      method: 'POST',
      body: JSON.stringify({
        message: 'send an ethereum transaction',
        agent_context: { capabilities: ['javascript'], has_env: ['RPC_URL', 'PRIVATE_KEY'] }
      })
    });

    assert.equal(data.recommendation, 'ethereum/transactions/send');
    assert.equal(data.ready, true);
    assert.ok(data.recommendation_node.excerpt || data.explanation);
  });
});

describe('Publish', () => {
  it('POST /v1/skills without auth returns 401', async () => {
    const { status } = await api('/v1/skills', {
      method: 'POST',
      body: JSON.stringify({
        name: 'test', version: '0.1.0', uri: 'test/skill',
        type: 'skill', context: 'test', info: 'test', tags: ['test'],
        parent: 'test'
      })
    });
    assert.equal(status, 401);
  });

  it('POST /v1/skills with auth publishes', async () => {
    const suffix = Date.now();
    const uri = `test/integration-test-${suffix}`;
    const { status, data } = await api('/v1/skills', {
      method: 'POST',
      headers: { Authorization: 'Bearer test-token' },
      body: JSON.stringify({
        name: `integration-test-${suffix}`, version: `0.0.${suffix}`,
        uri, type: 'skill',
        context: 'Integration test skill', info: 'Created by tests',
        tags: ['test'], parent: 'test'
      })
    });
    assert.equal(status, 201);
    assert.equal(data.uri, uri);
  });
});

describe('Manifest Validation', () => {
  it('all live node manifests have required fields', async () => {
    const { data } = await api('/v1');
    const required = ['name', 'version', 'uri', 'type', 'context', 'tags'];

    for (const eco of data.ecosystems) {
      const { data: skill } = await api(`/v1/skills/${eco.uri}`);
      for (const field of required) {
        assert.ok(
          skill.skill[field] !== undefined,
          `${eco.uri} missing field: ${field}`
        );
      }
    }
  });
});
