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

function normalizeWriteResult(operation, result) {
  return {
    operation,
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
  const input = await readInput("CRUD_INPUT_JSON");
  const uri = process.env.MONGODB_URI || input.uri;
  if (!uri) throw new Error("Set MONGODB_URI or include uri in the input payload.");

  const result = await withClient(uri, async (client) => {
    const db = client.db(input.database);
    const collection = db.collection(input.collection);
    const options = input.options ?? {};
    switch (input.operation) {
      case "find": {
        const cursor = collection.find(input.filter ?? {}, options);
        const documents = await cursor.toArray();
        return { operation: "find", count: documents.length, documents };
      }
      case "findOne": {
        const document = await collection.findOne(input.filter ?? {}, options);
        return { operation: "findOne", count: document ? 1 : 0, document, documents: document ? [document] : [] };
      }
      case "insertOne":
        return normalizeWriteResult("insertOne", await collection.insertOne(input.document ?? {}, options));
      case "insertMany":
        return normalizeWriteResult("insertMany", await collection.insertMany(input.documents ?? [], options));
      case "updateOne":
        return normalizeWriteResult("updateOne", await collection.updateOne(input.filter ?? {}, input.update ?? {}, options));
      case "updateMany":
        return normalizeWriteResult("updateMany", await collection.updateMany(input.filter ?? {}, input.update ?? {}, options));
      case "replaceOne":
        return normalizeWriteResult("replaceOne", await collection.replaceOne(input.filter ?? {}, input.document ?? {}, options));
      case "deleteOne":
        return normalizeWriteResult("deleteOne", await collection.deleteOne(input.filter ?? {}, options));
      case "deleteMany":
        return normalizeWriteResult("deleteMany", await collection.deleteMany(input.filter ?? {}, options));
      case "bulkWrite":
        return normalizeWriteResult("bulkWrite", await collection.bulkWrite(input.operations ?? [], options));
      case "countDocuments":
        return { operation: "countDocuments", count: await collection.countDocuments(input.filter ?? {}, options) };
      default:
        throw new Error(`Unsupported operation: ${input.operation}`);
    }
  });

  print(result);
})().catch(fail);
