---
name: transactions
description: >
  Execute MongoDB session-backed ACID transactions when a workflow must change multiple documents or collections atomically.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# Transactions Skill

Use this skill only when a single-document atomic write is not sufficient.

## Inputs

- `MONGODB_URI` to a replica set or sharded cluster
- `TRANSACTION_INPUT_JSON` or stdin with an ordered `operations` array

## Example

```bash
export TRANSACTION_INPUT_JSON='{"database":"bank","operations":[{"type":"updateOne","collection":"checking_accounts","filter":{"account_id":"9876"},"update":{"$inc":{"amount":-100}}},{"type":"updateOne","collection":"savings_accounts","filter":{"account_id":"9876"},"update":{"$inc":{"amount":100}}}],"transactionOptions":{"readPreference":"primary","readConcern":{"level":"local"},"writeConcern":{"w":"majority"}}}'
node ./scripts/run-transaction.js
```

## Workflow

1. Confirm the deployment is not a standalone `mongod`.
2. Keep the transaction callback free of side effects outside MongoDB so retries are safe.
3. Pass the same session to every operation in the transaction.
4. End the session and inspect the per-step results after commit.

## Edge Cases

- Do not run parallel operations inside the same transaction.
- Transactions add overhead; remodel the data if one atomic document write can replace them.
- Collection validators still apply inside a transaction.
