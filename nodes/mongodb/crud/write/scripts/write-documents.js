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

function normalize(result, action) {
  return {
    action,
    acknowledged: result.acknowledged,
    insertedId: result.insertedId,
    insertedCount: result.insertedCount,
    insertedIds: result.insertedIds,
    matchedCount: result.matchedCount,
    modifiedCount: result.modifiedCount,
    deletedCount: result.deletedCount,
    upsertedCount: result.upsertedCount,
    upsertedId: result.upsertedId,
    upsertedIds: result.upsertedIds
  };
}

(async () => {
  const input = await readInput("WRITE_INPUT_JSON");
  const uri = process.env.MONGODB_URI || input.uri;
  if (!uri) throw new Error("Set MONGODB_URI or include uri in the input payload.");

  const result = await withClient(uri, async (client) => {
    const db = client.db(input.database);
    const collection = db.collection(input.collection);
    const options = input.options ?? {};
    switch (input.action) {
      case "insertOne":
        return normalize(await collection.insertOne(input.document ?? {}, options), "insertOne");
      case "insertMany":
        return normalize(await collection.insertMany(input.documents ?? [], options), "insertMany");
      case "updateOne":
        return normalize(await collection.updateOne(input.filter ?? {}, input.update ?? {}, options), "updateOne");
      case "updateMany":
        return normalize(await collection.updateMany(input.filter ?? {}, input.update ?? {}, options), "updateMany");
      case "replaceOne":
        return normalize(await collection.replaceOne(input.filter ?? {}, input.document ?? {}, options), "replaceOne");
      case "deleteOne":
        return normalize(await collection.deleteOne(input.filter ?? {}, options), "deleteOne");
      case "deleteMany":
        return normalize(await collection.deleteMany(input.filter ?? {}, options), "deleteMany");
      case "bulkWrite":
        return normalize(await collection.bulkWrite(input.operations ?? [], options), "bulkWrite");
      default:
        throw new Error(`Unsupported action: ${input.action}`);
    }
  });

  print(result);
})().catch(fail);
