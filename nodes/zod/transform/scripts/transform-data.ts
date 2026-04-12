#!/usr/bin/env npx tsx
/**
 * transform-data.ts — Demonstrate Zod transform pipelines
 *
 * Usage:
 *   npx tsx transform-data.ts --input '{"first_name":"Alice","last_name":"Smith"}' --transform snakeToCamel
 *   npx tsx transform-data.ts --input '{"PORT":"8080","DEBUG":"true","HOST":"localhost"}' --transform env
 *   npx tsx transform-data.ts --input '"42"' --transform stringToNumber
 *
 * Built-in transforms:
 *   snakeToCamel  — Convert snake_case object keys to camelCase
 *   env           — Parse environment-style variables with coercion
 *   stringToNumber — Coerce string to validated number
 *   csvToArray    — Split comma-separated string into trimmed array
 *
 * Output: JSON with { success, input, output, inputType, outputType }
 */

import { z } from "zod";

interface TransformArgs {
  input: string;
  transform: string;
}

function parseArgs(): TransformArgs {
  const args = process.argv.slice(2);
  const parsed: Record<string, string> = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace(/^--/, "");
    const val = args[i + 1];
    if (key && val) parsed[key] = val;
  }

  if (!parsed.input || !parsed.transform) {
    console.error(
      "Usage: transform-data.ts --input '<json>' --transform <name>"
    );
    console.error(
      "Transforms: snakeToCamel, env, stringToNumber, csvToArray"
    );
    process.exit(1);
  }

  return parsed as TransformArgs;
}

function snakeToCamel(str: string): string {
  return str.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
}

// Define transform schemas
const transforms: Record<
  string,
  { schema: z.ZodTypeAny; inputType: string; outputType: string }
> = {
  snakeToCamel: {
    schema: z
      .record(z.string(), z.unknown())
      .transform((obj) =>
        Object.fromEntries(
          Object.entries(obj).map(([k, v]) => [snakeToCamel(k), v])
        )
      ),
    inputType: "Record<string, unknown>",
    outputType: "Record<string, unknown> (camelCase keys)",
  },

  env: {
    schema: z
      .object({
        PORT: z.coerce.number().int().positive().default(3000),
        DEBUG: z.coerce.boolean().default(false),
        HOST: z.string().default("0.0.0.0"),
        NODE_ENV: z
          .enum(["development", "production", "test"])
          .default("development"),
      })
      .passthrough(),
    inputType: "{ PORT?: string; DEBUG?: string; HOST?: string; NODE_ENV?: string }",
    outputType: "{ PORT: number; DEBUG: boolean; HOST: string; NODE_ENV: string }",
  },

  stringToNumber: {
    schema: z
      .string()
      .transform((val) => Number(val))
      .pipe(z.number().finite()),
    inputType: "string",
    outputType: "number",
  },

  csvToArray: {
    schema: z.string().transform((val) =>
      val
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    ),
    inputType: "string",
    outputType: "string[]",
  },
};

function main() {
  const config = parseArgs();

  const entry = transforms[config.transform];
  if (!entry) {
    console.error(`Unknown transform: ${config.transform}`);
    console.error(`Available: ${Object.keys(transforms).join(", ")}`);
    process.exit(1);
  }

  let input: unknown;
  try {
    input = JSON.parse(config.input);
  } catch {
    console.error("Invalid JSON input:", config.input);
    process.exit(1);
  }

  const result = entry.schema.safeParse(input);

  if (result.success) {
    console.log(
      JSON.stringify(
        {
          success: true,
          transform: config.transform,
          input,
          output: result.data,
          inputType: entry.inputType,
          outputType: entry.outputType,
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
          transform: config.transform,
          input,
          errors: result.error.flatten(),
        },
        null,
        2
      )
    );
    process.exit(1);
  }
}

main();
