const test = require('node:test');
const assert = require('node:assert/strict');

const {
  useDojoSkill,
  parseCliArgs,
  normalizeCliOptions,
  runCli
} = require('../scripts/use-dojo-skill.js');

test('useDojoSkill calls discover with current context', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { learn_first: [], then_do: [] };
      }
    };
  };

  await useDojoSkill({
    operation: 'discover',
    base_url: 'http://registry.test',
    q: 'how do i query dojo',
    current_context: ['dojo']
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/discover?q=how+do+i+query+dojo&current_context=dojo');
  assert.equal(calls[0].options.method, 'GET');
});

test('useDojoSkill calls learn with question', async () => {
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

  await useDojoSkill({
    operation: 'learn',
    base_url: 'http://registry.test',
    uri: 'dojo/api',
    question: 'where is the bundle route'
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/learn/dojo/api?question=where+is+the+bundle+route');
});

test('useDojoSkill searches learn-heavy nodes with filters', async () => {
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

  await useDojoSkill({
    operation: 'search',
    base_url: 'http://registry.test',
    q: 'dojo knowledge layer',
    ecosystem: 'dojo',
    type: 'context',
    tags: ['knowledge', 'graph'],
    mode: 'learn',
    limit: 2
  });

  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /^http:\/\/registry\.test\/v1\/search\?/);
  assert.match(calls[0].url, /q=dojo\+knowledge\+layer/);
  assert.match(calls[0].url, /eco=dojo/);
  assert.match(calls[0].url, /type=context/);
  assert.match(calls[0].url, /tags=knowledge%2Cgraph/);
  assert.match(calls[0].url, /mode=learn/);
  assert.match(calls[0].url, /limit=2/);
});

test('useDojoSkill fetches bundles', async () => {
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

  await useDojoSkill({
    operation: 'bundle',
    base_url: 'http://registry.test',
    uri: 'dojo/skill'
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/bundle/dojo/skill');
});

test('useDojoSkill calls agent_learn for answer-first knowledge lookup', async () => {
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

  await useDojoSkill({
    operation: 'agent_learn',
    base_url: 'http://registry.test',
    question: 'what is the dojo knowledge layer',
    current_context: ['dojo']
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/agent/learn');
  assert.equal(calls[0].options.method, 'POST');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    question: 'what is the dojo knowledge layer',
    current_context: ['dojo']
  });
});

test('useDojoSkill accepts need as a fallback prompt field for agent_learn', async () => {
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

  await useDojoSkill({
    operation: 'agent_learn',
    base_url: 'http://registry.test',
    need: 'find info in dojo'
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/agent/learn');
  assert.equal(calls[0].options.method, 'POST');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    question: 'find info in dojo',
    current_context: []
  });
});

test('useDojoSkill inspects graph neighborhoods directly', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { nodes: [] };
      }
    };
  };

  await useDojoSkill({
    operation: 'graph',
    base_url: 'http://registry.test',
    uri: 'dojo/knowledge',
    depth: 2
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/graph/dojo/knowledge?depth=2');
});

test('useDojoSkill proxies lower-level operations through query mode', async () => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { uri: 'dojo/knowledge' };
      }
    };
  };

  await useDojoSkill({
    operation: 'query',
    base_url: 'http://registry.test',
    query_options: {
      operation: 'alias',
      alias: 'dojo knowledge layer'
    }
  });

  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/alias/dojo%20knowledge%20layer');
});

test('normalizeCliOptions converts common CLI fields into skill options', () => {
  const parsed = parseCliArgs([
    'agent_learn',
    '--base-url', 'http://registry.test/',
    '--question', 'find info in dojo',
    '--current-context', 'dojo,dojo/api',
    '--tags', 'knowledge,graph',
    '--executable', 'false',
    '--limit', '3',
    '--agent-context', '{"capabilities":["http"],"has_env":["DOJO_REGISTRY_URL"]}'
  ]);

  const options = normalizeCliOptions(parsed);

  assert.deepEqual(options, {
    operation: 'agent_learn',
    base_url: 'http://registry.test/',
    question: 'find info in dojo',
    current_context: ['dojo', 'dojo/api'],
    tags: ['knowledge', 'graph'],
    executable: false,
    limit: 3,
    agent_context: {
      capabilities: ['http'],
      has_env: ['DOJO_REGISTRY_URL']
    }
  });
});

test('runCli prints JSON for direct answer-first lookups', async () => {
  const calls = [];
  const stdout = { chunks: [], write(chunk) { this.chunks.push(chunk); } };
  const stderr = { chunks: [], write(chunk) { this.chunks.push(chunk); } };

  global.fetch = async (url, options = {}) => {
    calls.push({ url, options });
    return {
      status: 200,
      async json() {
        return { answer_nodes: [{ uri: 'dojo', title: 'Dojo' }] };
      }
    };
  };

  const result = await runCli([
    'agent_learn',
    '--base-url', 'http://registry.test',
    '--question', 'find info in dojo',
    '--current-context', 'dojo'
  ], { stdout, stderr });

  assert.equal(stderr.chunks.length, 0);
  assert.equal(result.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'http://registry.test/v1/agent/learn');
  assert.deepEqual(JSON.parse(calls[0].options.body), {
    question: 'find info in dojo',
    current_context: ['dojo']
  });
  const printed = JSON.parse(stdout.chunks.join(''));
  assert.equal(printed.status, 200);
  assert.deepEqual(printed.data.answer_nodes, [{ uri: 'dojo', title: 'Dojo' }]);
});
