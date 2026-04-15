#!/usr/bin/env node
import { JsonRpcProvider, Wallet, formatEther, parseEther, parseUnits } from 'ethers';

function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', chunk => {
      data += chunk;
    });
    process.stdin.on('end', () => resolve(data));
    process.stdin.on('error', reject);
  });
}

function optionalBigInt(value, parser = BigInt) {
  if (value === undefined || value === null || value === '') return undefined;
  return parser(String(value));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

const raw = await readStdin();
const input = raw.trim() ? JSON.parse(raw) : {};

if (!process.env.RPC_URL) fail('RPC_URL is required');
if (!process.env.PRIVATE_KEY) fail('PRIVATE_KEY is required');
if (!input.to) fail('input.to is required');
if (!input.amount_eth) fail('input.amount_eth is required');

const provider = new JsonRpcProvider(process.env.RPC_URL);
const wallet = new Wallet(process.env.PRIVATE_KEY, provider);
const network = await provider.getNetwork();
const chainId = Number(network.chainId);

if (input.chain_id !== undefined && Number(input.chain_id) !== chainId) {
  fail(`RPC chain_id ${chainId} does not match requested chain_id ${input.chain_id}`);
}

const tx = {
  to: input.to,
  value: parseEther(String(input.amount_eth))
};

const nonce = optionalBigInt(input.nonce);
if (nonce !== undefined) tx.nonce = Number(nonce);

const gasLimit = optionalBigInt(input.gas_limit);
if (gasLimit !== undefined) tx.gasLimit = gasLimit;

const maxFeePerGas = optionalBigInt(input.max_fee_per_gas_gwei, value => parseUnits(value, 'gwei'));
if (maxFeePerGas !== undefined) tx.maxFeePerGas = maxFeePerGas;

const maxPriorityFeePerGas = optionalBigInt(input.max_priority_fee_per_gas_gwei, value => parseUnits(value, 'gwei'));
if (maxPriorityFeePerGas !== undefined) tx.maxPriorityFeePerGas = maxPriorityFeePerGas;

const response = await wallet.sendTransaction(tx);
const confirmations = input.confirmations === undefined ? 1 : Number(input.confirmations);
const receipt = confirmations > 0 ? await response.wait(confirmations) : null;

console.log(JSON.stringify({
  hash: response.hash,
  from: wallet.address,
  to: response.to,
  value_wei: response.value.toString(),
  value_eth: formatEther(response.value),
  chain_id: chainId,
  nonce: response.nonce,
  status: receipt?.status ?? null,
  block_number: receipt?.blockNumber ?? null,
  confirmations
}, null, 2));
