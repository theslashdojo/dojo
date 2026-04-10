const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

const ROOT = resolve(__dirname, '../../../../../../');
const SKILL_PATH = resolve(__dirname, '../skill.json');
const SENDER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const RECIPIENT = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

let hardhatNode;
let skill;
let Dojo;
let hardhatUrl;
let onEarlyExit;

function waitForHardhat(child) {
  return new Promise((resolvePromise, rejectPromise) => {
    const timeout = setTimeout(() => {
      child.off('exit', onEarlyExit);
      rejectPromise(new Error('Timed out waiting for Hardhat node'));
    }, 20000);

    const onData = (chunk) => {
      const text = chunk.toString();
      if (text.includes('Started HTTP and WebSocket JSON-RPC server')) {
        clearTimeout(timeout);
        child.stdout.off('data', onData);
        child.stderr.off('data', onData);
        child.off('exit', onEarlyExit);
        resolvePromise();
      }
    };

    onEarlyExit = (code) => {
      clearTimeout(timeout);
      rejectPromise(new Error(`Hardhat node exited early with code ${code}`));
    };

    child.stdout.on('data', onData);
    child.stderr.on('data', onData);
    child.once('exit', onEarlyExit);
  });
}

before(async () => {
  ({ Dojo } = await import('../../../../../sdk/src/index.js'));
  skill = JSON.parse(readFileSync(SKILL_PATH, 'utf8'));
  const hardhatPort = 18545 + Math.floor(Math.random() * 500);
  hardhatUrl = `http://127.0.0.1:${hardhatPort}`;

  hardhatNode = spawn('npx', ['hardhat', 'node', '--hostname', '127.0.0.1', '--port', String(hardhatPort)], {
    cwd: ROOT,
    stdio: ['ignore', 'pipe', 'pipe']
  });

  await waitForHardhat(hardhatNode);
});

after(async () => {
  if (!hardhatNode || hardhatNode.exitCode !== null) return;

  hardhatNode.stdout?.destroy();
  hardhatNode.stderr?.destroy();
  hardhatNode.kill('SIGTERM');

  await Promise.race([
    new Promise(resolvePromise => hardhatNode.once('exit', () => resolvePromise())),
    new Promise(resolvePromise => setTimeout(resolvePromise, 2000))
  ]);

  if (hardhatNode.exitCode === null) {
    hardhatNode.kill('SIGKILL');
    await new Promise(resolvePromise => hardhatNode.once('exit', () => resolvePromise()));
  }
});

test('send skill broadcasts a native ETH transfer on a local Hardhat node', async () => {
  const client = new Dojo();
  const result = await client.run(skill, {
    rpc_url: hardhatUrl,
    private_key: SENDER_PRIVATE_KEY,
    to: RECIPIENT,
    value_eth: '0.001'
  });

  assert.equal(result.status, 'success');
  assert.equal(result.to.toLowerCase(), RECIPIENT.toLowerCase());
  assert.match(result.tx_hash, /^0x[0-9a-fA-F]{64}$/);
  assert.ok(Number.isInteger(result.block_number));
});
