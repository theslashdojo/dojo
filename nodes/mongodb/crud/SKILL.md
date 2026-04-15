---
name: crud
description: >
  Run MongoDB CRUD work through the official Node.js driver when you need structured reads, writes, bulk operations, and machine-friendly JSON results.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
---

# CRUD Skill

Use this skill for normal document lifecycle work.

## Inputs

- `MONGODB_URI` for connectivity
- `CRUD_INPUT_JSON` or stdin for the operation payload

The payload must include `database`, `collection`, and `operation`.

## Example: Find

```bash
export MONGODB_URI="mongodb://user:pass@localhost:27017/app?authSource=admin"
export CRUD_INPUT_JSON='{"database":"app","collection":"users","operation":"find","filter":{"active":true},"options":{"projection":{"email":1,"role":1},"sort":{"createdAt":-1},"limit":10}}'
node ./scripts/run-crud.js
```

## Example: Update with Upsert

```bash
export CRUD_INPUT_JSON='{"database":"app","collection":"users","operation":"updateOne","filter":{"email":"ops@example.com"},"update":{"$set":{"role":"admin"}},"options":{"upsert":true}}'
node ./scripts/run-crud.js
```

## Workflow

1. Start from [[mongodb/auth]].
2. Use `find` or `findOne` for reads, or one of the write operations for mutations.
3. Inspect the result counts instead of assuming the mutation did what you expected.
4. Escalate to [[mongodb/transactions]] only when multi-document atomicity is required.

## Edge Cases

- Extended JSON is supported so you can pass ObjectIds and dates safely.
- `find()` returns bounded results here because the script materializes them; do not use it for unbounded full-collection exports.
- Bulk writes can partially succeed depending on `ordered` behavior.
