#!/usr/bin/env npx tsx
/**
 * validate-data.ts — Validate JSON data against a Zod schema
 *
 * Usage:
 *   echo '{"name":"Alice","email":"bad"}' | npx tsx validate-data.ts --schema 'z.object({ name: z.string(), email: z.string().email() })'
 *
 *   npx tsx validate-data.ts --schema 'z.object({ name: z.string().min(1), age: z.number().int().positive() })' --data '{"name":"","age":-5}'
 *
 * Output: JSON with { success, data?, errors? }
 */

import { z } from "zod";

interface ValidateArgs {
  schema: string;
  data?: string;
}

function parseArgs(): ValidateArgs {
  const args = process.argv.slice(2);
  const parsed: Record<string, string> = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace(/^--/, "");
    const val = args[i + 1];
    if (key && val) parsed[key] = val;
  }

  if (!parsed.schema) {
    console.error("Usage: validate-data.ts --schema '<zod schema>' [--data '<json>']");
    process.exit(1);
  }

  return parsed as ValidateArgs;
}

async function readStdin(): Promise<string> {
  if (process.stdin.isTTY) return "";

  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8").trim();
}

async function main() {
  const config = parseArgs();

  // Get data from --data arg or stdin
  let rawData: string;
  if (config.data) {
    rawData = config.data;
  } else {
    rawData = await readStdin();
    if (!rawData) {
      console.error("No data provided. Use --data or pipe JSON to stdin.");
      process.exit(1);
    }
  }

  // Parse JSON data
  let data: unknown;
  try {
    data = JSON.parse(rawData);
  } catch {
    console.error("Invalid JSON input:", rawData);
    process.exit(1);
  }

  // Evaluate the schema expression
  // The schema string is a Zod expression like "z.object({ name: z.string() })"
  const schemaFn = new Function("z", `return ${config.schema}`);
  const schema = schemaFn(z) as z.ZodTypeAny;

  // Validate
  const result = schema.safeParse(data);

  if (result.success) {
    console.log(
      JSON.stringify(
        {
          success: true,
          data: result.data,
        },
        null,
        2
      )
    );
  } else {
    console.log(
      JSON.stringify(
        {
          success: false,
          errors: result.error.flatten(),
          issues: result.error.issues.map((issue) => ({
            code: issue.code,
            path: issue.path,
            message: issue.message,
          })),
        },
        null,
        2
      )
    );
    process.exit(1);
  }
}

main();
