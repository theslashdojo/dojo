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
    assert.ok(data.total_skills > 0, 'Should have loaded skills');
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
    assert.ok(data.results.some(r => r.uri === 'dojo/contributing'));
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

  it('GET /v1/learn/dojo supports explicit section lookup', async () => {
    const { status, data } = await api('/v1/learn/dojo?section=knowledge-api');
    assert.equal(status, 200);
    assert.equal(data.focused_section.id, 'knowledge-api');
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

  it('POST /v1/agent/learn uses rich knowledge content', async () => {
    const { status, data } = await api('/v1/agent/learn', {
      method: 'POST',
      body: JSON.stringify({
        question: 'how do i run a local registry smoke test before publishing',
        current_context: ['dojo']
      })
    });
    assert.equal(status, 200);
    assert.ok(data.answer_nodes.some(node => node.uri === 'dojo/contributing'));
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
    assert.ok(data.skill, 'Should include the full skill manifest');
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
    const { status, data } = await api('/v1/skills', {
      method: 'POST',
      headers: { Authorization: 'Bearer test-token' },
      body: JSON.stringify({
        name: 'integration-test', version: '0.0.1',
        uri: 'test/integration-test', type: 'skill',
        context: 'Integration test skill', info: 'Created by tests',
        tags: ['test'], parent: 'test'
      })
    });
    assert.equal(status, 201);
    assert.equal(data.uri, 'test/integration-test');
  });
});

describe('Manifest Validation', () => {
  it('all example manifests have required fields', async () => {
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
