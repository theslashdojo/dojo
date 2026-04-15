#!/usr/bin/env node
const process = require("node:process");
const { MongoClient } = require("mongodb");
const { EJSON } = require("bson");

async function readInput(envVar) {
  if (process.env[envVar]) {
    return EJSON.parse(process.env[envVar]);
  }
  if (!process.stdin.isTTY) {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    const text = Buffer.concat(chunks).toString("utf8").trim();
    if (text) return EJSON.parse(text);
  }
  throw new Error(`Provide ${envVar} or JSON on stdin.`);
}

function print(value) {
  console.log(EJSON.stringify(value, null, 2, { relaxed: true }));
}

async function withClient(uri, fn) {
  const client = new MongoClient(uri);
  await client.connect();
  try {
    return await fn(client);
  } finally {
    await client.close();
  }
}

function fail(error) {
  print({ error: { name: error.name, message: error.message, code: error.code } });
  process.exit(1);
}

function normalize(result, type, collection) {
  return {
    type,
    collection,
    acknowledged: result.acknowledged,
    insertedId: result.insertedId,
    matchedCount: result.matchedCount,
    modifiedCount: result.modifiedCount,
    deletedCount: result.deletedCount,
    upsertedId: result.upsertedId
  };
}

(async () => {
  const input = await readInput("TRANSACTION_INPUT_JSON");
  const uri = process.env.MONGODB_URI || input.uri;
  if (!uri) throw new Error("Set MONGODB_URI or include uri in the input payload.");

  const result = await withClient(uri, async (client) => {
    const session = client.startSession();
    const results = [];
    try {
      await session.withTransaction(async () => {
        for (const step of input.operations ?? []) {
          const db = client.db(step.database ?? input.database);
          const collection = db.collection(step.collection);
          const options = { ...(step.options ?? {}), session };
          switch (step.type) {
            case "insertOne":
              results.push(normalize(await collection.insertOne(step.document ?? {}, options), step.type, step.collection));
              break;
            case "updateOne":
              results.push(normalize(await collection.updateOne(step.filter ?? {}, step.update ?? {}, options), step.type, step.collection));
              break;
            case "updateMany":
              results.push(normalize(await collection.updateMany(step.filter ?? {}, step.update ?? {}, options), step.type, step.collection));
              break;
            case "replaceOne":
              results.push(normalize(await collection.replaceOne(step.filter ?? {}, step.document ?? {}, options), step.type, step.collection));
              break;
            case "deleteOne":
              results.push(normalize(await collection.deleteOne(step.filter ?? {}, options), step.type, step.collection));
              break;
            case "deleteMany":
              results.push(normalize(await collection.deleteMany(step.filter ?? {}, options), step.type, step.collection));
              break;
            default:
              throw new Error(`Unsupported transaction step type: ${step.type}`);
          }
        }
      }, input.transactionOptions ?? {});
      return { committed: true, results };
    } finally {
      await session.endSession();
    }
  });

  print(result);
})().catch(fail);
