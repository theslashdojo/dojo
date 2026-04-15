import test from 'node:test';
import assert from 'node:assert/strict';

import { Dojo } from './index.js';

test('need falls back to localhost when the default registry is unavailable', async () => {
  const originalFetch = global.fetch;
  const calls = [];

  global.fetch = async (url) => {
    calls.push(url);

    if (String(url).startsWith('https://slashdojo.com')) {
      return {
        ok: false,
        status: 404,
        async json() {
          return { error: 'not found' };
        }
      };
    }

    if (String(url).startsWith('http://localhost:3000')) {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            results: [
              {
                uri: 'ethereum/transactions/send',
                skill: {
                  uri: 'ethereum/transactions/send',
                  scripts: []
                }
              }
            ]
          };
        }
      };
    }

    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const client = new Dojo({ envKeys: [] });
    const skill = await client.need('send eth');

    assert.equal(skill.uri, 'ethereum/transactions/send');
    assert.equal(client.registry, 'http://localhost:3000');
    assert.equal(calls.length, 2);
    assert.match(calls[0], /^https:\/\/slashdojo\.com\/v1\/resolve\?/);
    assert.match(calls[1], /^http:\/\/localhost:3000\/v1\/resolve\?/);
  } finally {
    global.fetch = originalFetch;
  }
});

test('_checkEnv treats provided input fields as satisfying required env keys', () => {
  const client = new Dojo({ registry: 'http://registry.test', envKeys: [] });
  const missing = client._checkEnv({
    env: {
      RPC_URL: { required: true },
      PRIVATE_KEY: { required: true }
    }
  }, {
    rpc_url: 'http://rpc.local',
    privateKey: '0xabc123'
  });

  assert.deepEqual(missing, []);
});

test('run executes JavaScript entry scripts from registry bundles', async () => {
  const originalFetch = global.fetch;

  global.fetch = async (url) => {
    if (String(url) === 'http://registry.test/v1/skills/example/hello') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            skill: {
              uri: 'example/hello',
              scripts: [
                {
                  id: 'hello',
                  lang: 'javascript',
                  entry: './scripts/hello.js'
                }
              ]
            }
          };
        }
      };
    }

    if (String(url) === 'http://registry.test/v1/bundle/example/hello') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            uri: 'example/hello',
            files: [
              {
                path: 'scripts/hello.js',
                kind: 'script',
                content: [
                  "const jsonIndex = process.argv.indexOf('--json');",
                  "const input = JSON.parse(process.argv[jsonIndex + 1]);",
                  "process.stdout.write(JSON.stringify({ greeting: `hello ${input.name}` }));"
                ].join('\n')
              }
            ]
          };
        }
      };
    }

    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const client = new Dojo({ registry: 'http://registry.test', envKeys: [] });
    const result = await client.run('example/hello', { name: 'Ada' });

    assert.deepEqual(result, { greeting: 'hello Ada' });
  } finally {
    global.fetch = originalFetch;
  }
});

test('run executes bash entry scripts with schema-derived arguments', async () => {
  const originalFetch = global.fetch;

  global.fetch = async (url) => {
    if (String(url) === 'http://registry.test/v1/skills/example/search') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            skill: {
              uri: 'example/search',
              scripts: [
                {
                  id: 'search',
                  lang: 'bash',
                  entry: './scripts/search.sh'
                }
              ],
              schema: {
                input: {
                  type: 'object',
                  properties: {
                    query: { type: 'string' },
                    limit: { type: 'integer' }
                  },
                  required: ['query']
                }
              }
            }
          };
        }
      };
    }

    if (String(url) === 'http://registry.test/v1/bundle/example/search') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            uri: 'example/search',
            files: [
              {
                path: 'scripts/search.sh',
                kind: 'script',
                content: [
                  '#!/usr/bin/env bash',
                  'set -euo pipefail',
                  'query="$1"',
                  'limit=""',
                  'while [[ $# -gt 0 ]]; do',
                  '  case "$1" in',
                  '    --limit) limit="$2"; shift 2 ;;',
                  '    *) shift ;;',
                  '  esac',
                  'done',
                  'printf \'{"query":"%s","limit":"%s"}\\n\' "$query" "$limit"'
                ].join('\n')
              }
            ]
          };
        }
      };
    }

    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const client = new Dojo({ registry: 'http://registry.test', envKeys: [] });
    const result = await client.run('example/search', { query: 'dojo', limit: 2 });

    assert.deepEqual(result, { query: 'dojo', limit: '2' });
  } finally {
    global.fetch = originalFetch;
  }
});

test('run materializes parent bundles for entry script shared files', async () => {
  const originalFetch = global.fetch;

  global.fetch = async (url) => {
    if (String(url) === 'http://registry.test/v1/skills/example/parent/child') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            skill: {
              uri: 'example/parent/child',
              scripts: [
                {
                  id: 'child',
                  lang: 'javascript',
                  entry: './scripts/child.js'
                }
              ]
            }
          };
        }
      };
    }

    if (String(url) === 'http://registry.test/v1/bundle/example/parent') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            uri: 'example/parent',
            source: { source_path: 'example/parent' },
            files: [
              {
                path: 'scripts/lib.js',
                kind: 'script',
                content: "module.exports = { value: 'shared parent code' };\n"
              }
            ]
          };
        }
      };
    }

    if (String(url) === 'http://registry.test/v1/bundle/example/parent/child') {
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            uri: 'example/parent/child',
            source: { source_path: 'example/parent/child' },
            files: [
              {
                path: 'scripts/child.js',
                kind: 'script',
                content: [
                  "const shared = require('../../scripts/lib.js');",
                  'process.stdout.write(JSON.stringify({ value: shared.value }));'
                ].join('\n')
              }
            ]
          };
        }
      };
    }

    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const client = new Dojo({ registry: 'http://registry.test', envKeys: [] });
    const result = await client.run('example/parent/child', {});

    assert.deepEqual(result, { value: 'shared parent code' });
  } finally {
    global.fetch = originalFetch;
  }
});
