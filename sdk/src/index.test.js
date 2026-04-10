import test from 'node:test';
import assert from 'node:assert/strict';

import { Dojo } from './index.js';

test('need falls back to localhost when the default registry is unavailable', async () => {
  const originalFetch = global.fetch;
  const calls = [];

  global.fetch = async (url) => {
    calls.push(url);

    if (String(url).startsWith('https://api.dojo.dev')) {
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
    assert.match(calls[0], /^https:\/\/api\.dojo\.dev\/v1\/resolve\?/);
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
