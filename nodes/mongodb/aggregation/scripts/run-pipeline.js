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

(async () => {
  const input = await readInput("AGGREGATION_INPUT_JSON");
  const uri = process.env.MONGODB_URI || input.uri;
  if (!uri) throw new Error("Set MONGODB_URI or include uri in the input payload.");

  const result = await withClient(uri, async (client) => {
    const db = client.db(input.database);
    const collection = db.collection(input.collection);
    const pipeline = input.pipeline ?? [];
    const options = input.options ?? {};
    const cursor = collection.aggregate(pipeline, options);
    if (input.explain) {
      return { explain: await cursor.explain(input.explainVerbosity ?? "executionStats") };
    }
    const documents = await cursor.toArray();
    return { count: documents.length, documents };
  });

  print(result);
})().catch(fail);
