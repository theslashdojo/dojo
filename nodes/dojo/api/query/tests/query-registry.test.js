const test = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizeCliOptions,
  parseCliArgs,
  query,
  runCli
} = require('../scripts/query-registry.js');

test('query builds search URLs with filters', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { ok: true };
      }
    };
  };

  const result = await query({
    operation: 'search',
    base_url: 'http://registry.test',
    q: 'dojo validation',
    eco: 'dojo',
    type: 'skill',
    tags: ['validate', 'knowledge'],
    mode: 'learn',
    executable: false,
    limit: 5,
    offset: 2
  });

  assert.equal(result.status, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /^http:\/\/registry\.test\/v1\/search\?/);
  assert.match(calls[0].url, /q=dojo\+validation/);
  assert.match(calls[0].url, /eco=dojo/);
  assert.match(calls[0].url, /type=skill/);
  assert.match(calls[0].url, /tags=validate%2Cknowledge/);
  assert.match(calls[0].url, /mode=learn/);
  assert.match(calls[0].url, /executable=false/);
  assert.match(calls[0].url, /limit=5/);
  assert.match(calls[0].url, /offset=2/);
});

test('query sends POST bodies for agent_learn', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { answer_nodes: [] };
      }
    };
  };

  const result = await query({
    operation: 'agent_learn',
    base_url: 'http://registry.test',
    question: 'how do i validate a dojo node',
    current_context: ['dojo']
  });

  assert.equal(result.method, 'POST');
  assert.equal(calls[0].options.method, 'POST');
  assert.equal(calls[0].options.headers['Content-Type'], 'application/json');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    question: 'how do i validate a dojo node',
    current_context: ['dojo']
  });
});

test('query supports discover with current context', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { best_match: null };
      }
    };
  };

  await query({
    operation: 'discover',
    base_url: 'http://registry.test',
    q: 'how do i validate dojo nodes',
    current_context: ['dojo', 'dojo/api'],
    limit: 4
  });

  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'http://registry.test/v1/discover?q=how+do+i+validate+dojo+nodes&limit=4&current_context=dojo%2Cdojo%2Fapi'
  );
});

test('query supports registry index and trims base URLs', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { registry: 'dojo' };
      }
    };
  };

  const result = await query({
    operation: 'index',
    base_url: 'http://registry.test/'
  });

  assert.equal(result.status, 200);
  assert.equal(calls[0].url, 'http://registry.test/v1');
  assert.equal(result.url, 'http://registry.test/v1');
});

test('query passes depth through tree requests', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { uri: 'dojo' };
      }
    };
  };

  await query({
    operation: 'tree',
    base_url: 'http://registry.test',
    uri: 'dojo',
    depth: 2
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/tree/dojo?depth=2');
});

test('query passes question through learn requests', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { relevant_sections: [] };
      }
    };
  };

  await query({
    operation: 'learn',
    base_url: 'http://registry.test',
    uri: 'dojo/api',
    question: 'how do i discover skills'
  });

  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    'http://registry.test/v1/learn/dojo/api?question=how+do+i+discover+skills'
  );
});

test('query passes execution filters through resolve requests', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { results: [] };
      }
    };
  };

  await query({
    operation: 'resolve',
    base_url: 'http://registry.test',
    need: 'send eth transaction',
    mode: 'do',
    executable: true,
    limit: 3
  });

  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /need=send\+eth\+transaction/);
  assert.match(calls[0].url, /mode=do/);
  assert.match(calls[0].url, /executable=true/);
});

test('query fetches bundles for a uri', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { entrypoints: { manifest: 'node.json' } };
      }
    };
  };

  const result = await query({
    operation: 'bundle',
    base_url: 'http://registry.test',
    uri: 'dojo/skill'
  });

  assert.equal(result.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/bundle/dojo/skill');
});

test('query sends POST bodies for agent_ask', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { recommendation: 'dojo/validate' };
      }
    };
  };

  const result = await query({
    operation: 'agent_ask',
    base_url: 'http://registry.test',
    message: 'validate this manifest',
    agent_context: { capabilities: ['javascript'], has_env: ['DOJO_TOKEN'] }
  });

  assert.equal(result.method, 'POST');
  assert.equal(calls[0].url, 'http://registry.test/v1/agent/ask');
  assert.equal(calls[0].options.method, 'POST');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    message: 'validate this manifest',
    agent_context: { capabilities: ['javascript'], has_env: ['DOJO_TOKEN'] }
  });
});

test('normalizeCliOptions supports structured JSON input', () => {
  const parsed = parseCliArgs([
    '--json',
    '{"operation":"agent_learn","question":"find info in dojo","current_context":["dojo"],"limit":"2"}'
  ]);

  const options = normalizeCliOptions(parsed);

  assert.deepEqual(options, {
    operation: 'agent_learn',
    question: 'find info in dojo',
    current_context: ['dojo'],
    limit: 2
  });
});

test('runCli prints JSON for CLI callers', async () => {
  const calls = [];
  const stdout = { chunks: [], write(chunk) { this.chunks.push(chunk); } };
  const stderr = { chunks: [], write(chunk) { this.chunks.push(chunk); } };

  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { entrypoints: { manifest: 'node.json' } };
      }
    };
  };

  const exitCode = await runCli([
    'bundle',
    '--base-url', 'http://registry.test/',
    '--uri', 'dojo/skill'
  ], stdout, stderr);

  assert.equal(exitCode, 0);
  assert.equal(stderr.chunks.length, 0);
  assert.equal(calls[0].url, 'http://registry.test/v1/bundle/dojo/skill');
  const payload = JSON.parse(stdout.chunks.join(''));
  assert.equal(payload.status, 200);
  assert.equal(payload.data.entrypoints.manifest, 'node.json');
});

test('query rejects unsupported operations', async () => {
  await assert.rejects(() => query({ operation: 'unknown' }), /Unsupported operation/);
});
