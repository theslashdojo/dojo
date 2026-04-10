const { ethers } = require('ethers');

function pick(...values) {
  return values.find(value => value !== undefined && value !== null && value !== '');
}

function toBoolean(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  if (typeof value === 'boolean') return value;
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  return fallback;
}

function toInteger(value, field, fallback) {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) throw new Error(`${field} must be an integer`);
  return parsed;
}

function normalizeHex(value) {
  if (!value) return undefined;
  return String(value).startsWith('0x') ? String(value) : `0x${String(value)}`;
}

function parseWei(input) {
  const valueWei = pick(input.value_wei, input.valueWei);
  if (valueWei !== undefined) return ethers.BigNumber.from(String(valueWei));

  const valueEth = pick(input.value_eth, input.valueEth, input.amount_eth, input.amountEth, '0');
  return ethers.utils.parseEther(String(valueEth));
}

function parseGwei(value) {
  if (value === undefined || value === null || value === '') return undefined;
  return ethers.utils.parseUnits(String(value), 'gwei');
}

async function buildNativeTransaction(input = {}) {
  const rpcUrl = pick(input.rpc_url, input.rpcUrl, process.env.RPC_URL);
  const privateKey = pick(input.private_key, input.privateKey, process.env.PRIVATE_KEY);
  const to = pick(input.to, input.recipient);

  if (!rpcUrl) throw new Error('rpc_url or RPC_URL is required');
  if (!privateKey) throw new Error('private_key or PRIVATE_KEY is required');
  if (!to) throw new Error('to is required');

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const network = await provider.getNetwork();

  const tx = {
    to,
    value: parseWei(input),
    nonce: toInteger(pick(input.nonce), 'nonce', await provider.getTransactionCount(wallet.address, 'pending')),
    chainId: toInteger(pick(input.chain_id, input.chainId), 'chain_id', network.chainId)
  };

  const data = normalizeHex(pick(input.data));
  if (data) tx.data = data;

  const gasLimit = pick(input.gas_limit, input.gasLimit);
  if (gasLimit !== undefined) {
    tx.gasLimit = ethers.BigNumber.from(String(gasLimit));
  } else {
    const estimated = await provider.estimateGas({ ...tx, from: wallet.address });
    const multiplier = Number(pick(input.gas_limit_multiplier, input.gasLimitMultiplier, 1.15));
    const basisPoints = Number.isFinite(multiplier) && multiplier > 0 ? Math.round(multiplier * 100) : 115;
    tx.gasLimit = estimated.mul(basisPoints).div(100);
  }

  const explicitGasPrice = parseGwei(pick(input.gas_price_gwei, input.gasPriceGwei));
  const explicitMaxFee = parseGwei(pick(input.max_fee_per_gas_gwei, input.maxFeePerGasGwei));
  const explicitMaxPriority = parseGwei(
    pick(input.max_priority_fee_per_gas_gwei, input.maxPriorityFeePerGasGwei)
  );
  const feeData = await provider.getFeeData();

  if (explicitGasPrice) {
    tx.gasPrice = explicitGasPrice;
  } else if (explicitMaxFee || explicitMaxPriority || (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas)) {
    tx.type = 2;
    tx.maxFeePerGas = explicitMaxFee || feeData.maxFeePerGas;
    tx.maxPriorityFeePerGas = explicitMaxPriority || feeData.maxPriorityFeePerGas || ethers.utils.parseUnits('1.5', 'gwei');
  } else if (feeData.gasPrice) {
    tx.gasPrice = feeData.gasPrice;
  }

  return {
    provider,
    wallet,
    network,
    tx
  };
}

async function sendNativeTransaction(input = {}) {
  const { wallet, network, tx } = await buildNativeTransaction(input);
  const dryRun = toBoolean(pick(input.dry_run, input.dryRun), false);

  const summary = {
    from: wallet.address,
    to: tx.to,
    chain_id: tx.chainId,
    network_name: network.name,
    nonce: tx.nonce,
    value_wei: tx.value.toString(),
    gas_limit: tx.gasLimit.toString(),
    gas_price_wei: tx.gasPrice ? tx.gasPrice.toString() : undefined,
    max_fee_per_gas_wei: tx.maxFeePerGas ? tx.maxFeePerGas.toString() : undefined,
    max_priority_fee_per_gas_wei: tx.maxPriorityFeePerGas ? tx.maxPriorityFeePerGas.toString() : undefined
  };

  if (dryRun) {
    return {
      ...summary,
      dry_run: true,
      status: 'prepared'
    };
  }

  const response = await wallet.sendTransaction(tx);
  const waitForReceipt = toBoolean(pick(input.wait_for_receipt, input.waitForReceipt), true);
  const confirmations = toInteger(pick(input.confirmations), 'confirmations', 1);

  if (!waitForReceipt) {
    return {
      ...summary,
      hash: response.hash,
      status: 'broadcast'
    };
  }

  const receipt = await response.wait(confirmations);
  return {
    ...summary,
    hash: response.hash,
    status: receipt.status === 1 ? 'success' : 'failed',
    block_number: receipt.blockNumber,
    gas_used: receipt.gasUsed.toString()
  };
}

module.exports = {
  buildNativeTransaction,
  sendNativeTransaction
};
