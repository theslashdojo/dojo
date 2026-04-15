---
name: send
description: Send native ETH from a private-key wallet through an Ethereum JSON-RPC endpoint.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: ethereum-transactions
allowed-tools: Bash
---

# Send Native ETH

Use this skill when an agent needs to send a native ETH transfer on an EVM-compatible chain.

## Requirements

- `RPC_URL`: JSON-RPC endpoint for the target chain.
- `PRIVATE_KEY`: sender private key with enough native asset for value and gas.
- Input JSON with `to` and `amount_eth`.

## Run

```bash
printf '{"to":"0x0000000000000000000000000000000000000000","amount_eth":"0.001"}' \
  | node scripts/send-eth.js
```

Optional inputs include `chain_id`, `confirmations`, `nonce`, `gas_limit`, `max_fee_per_gas_gwei`, and `max_priority_fee_per_gas_gwei`.

## Notes

Coordinate nonces when sending multiple transactions from the same wallet. A duplicate nonce replaces the earlier pending transaction if the replacement fee is high enough.
