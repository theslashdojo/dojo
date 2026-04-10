const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { setTimeout: delay } = require('node:timers/promises');
const { ethers } = require('ethers');

const {
  buildNativeTransaction,
  sendNativeTransaction
} = require('../scripts/send-native-transaction.js');

const HARDHAT_PORT = 8546;
const RPC_URL = `http://127.0.0.1:${HARDHAT_PORT}`;
const SENDER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const RECIPIENT_ADDRESS = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';

let hardhatNode;

async function waitForRpc(url, attempts = 40) {
  const provider = new ethers.providers.JsonRpcProvider(url);
  let lastError;

  for (let index = 0; index < attempts; index += 1) {
    try {
      await provider.getBlockNumber();
      return;
    } catch (error) {
      lastError = error;
      await delay(500);
    }
  }

  throw lastError || new Error('RPC never became ready');
}

test.before(async () => {
  hardhatNode = spawn('npx', ['hardhat', 'node', '--hostname', '127.0.0.1', '--port', String(HARDHAT_PORT)], {
    cwd: '/workspaces/Contracts',
    stdio: ['ignore', 'pipe', 'pipe']
  });

  await waitForRpc(RPC_URL);
});

test.after(async () => {
  if (!hardhatNode) return;
  hardhatNode.kill('SIGTERM');
  await delay(500);
});

test('buildNativeTransaction prepares an EIP-1559 transfer', async () => {
  const built = await buildNativeTransaction({
    rpc_url: RPC_URL,
    private_key: SENDER_PRIVATE_KEY,
    to: RECIPIENT_ADDRESS,
    value_eth: '0.01',
    dry_run: true
  });

  assert.equal(built.tx.to, RECIPIENT_ADDRESS);
  assert.equal(built.tx.chainId, 31337);
  assert.equal(built.tx.value.toString(), ethers.utils.parseEther('0.01').toString());
  assert.ok(built.tx.gasLimit.gte(ethers.BigNumber.from('21000')));
  assert.ok(built.tx.maxFeePerGas || built.tx.gasPrice);
});

test('sendNativeTransaction broadcasts and returns a confirmed receipt', async () => {
  const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
  const before = await provider.getBalance(RECIPIENT_ADDRESS);

  const result = await sendNativeTransaction({
    rpc_url: RPC_URL,
    private_key: SENDER_PRIVATE_KEY,
    to: RECIPIENT_ADDRESS,
    value_eth: '0.015',
    wait_for_receipt: true
  });

  const after = await provider.getBalance(RECIPIENT_ADDRESS);

  assert.equal(result.status, 'success');
  assert.equal(result.to.toLowerCase(), RECIPIENT_ADDRESS.toLowerCase());
  assert.equal(result.chain_id, 31337);
  assert.ok(result.hash.startsWith('0x'));
  assert.ok(Number.isInteger(result.block_number));
  assert.equal(
    after.sub(before).toString(),
    ethers.utils.parseEther('0.015').toString()
  );
});
