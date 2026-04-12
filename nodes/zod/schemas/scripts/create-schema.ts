#!/usr/bin/env npx tsx
/**
 * create-schema.ts — Generate a Zod schema from a JSON shape description
 *
 * Usage:
 *   npx tsx create-schema.ts --name UserSchema --shape '{"name":"string","email":"email","age":"number?","role":"enum:admin,user,guest","tags":"string[]"}'
 *
 * Type codes:
 *   string, number, boolean, date, bigint — primitives
 *   email, url, uuid, cuid, ip, datetime  — string validators
 *   enum:a,b,c                             — string enum
 *   Append ? for optional (e.g. number?)
 *   Append [] for array (e.g. string[])
 *
 * Output: TypeScript code for the Zod schema and inferred type
 */

import { z } from "zod";

const ArgsSchema = z.object({
  name: z.string().min(1).regex(/^[A-Z][a-zA-Z0-9]*$/),
  shape: z.string().transform((s) => JSON.parse(s) as Record<string, string>),
  strict: z.coerce.boolean().default(false),
});

function parseArgs(): z.infer<typeof ArgsSchema> {
  const args = process.argv.slice(2);
  const parsed: Record<string, string> = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace(/^--/, "");
    const val = args[i + 1];
    if (key && val) parsed[key] = val;
  }

  return ArgsSchema.parse(parsed);
}

function typeCodeToZod(code: string): string {
  const isOptional = code.endsWith("?");
  const isArray = code.endsWith("[]");
  let base = code.replace(/[?\[\]]+$/, "");

  let zodExpr: string;

  if (base.startsWith("enum:")) {
    const values = base
      .slice(5)
      .split(",")
      .map((v) => `"${v.trim()}"`)
      .join(", ");
    zodExpr = `z.enum([${values}])`;
  } else {
    const primitiveMap: Record<string, string> = {
      string: "z.string()",
      number: "z.number()",
      boolean: "z.boolean()",
      date: "z.date()",
      bigint: "z.bigint()",
      email: 'z.string().email()',
      url: 'z.string().url()',
      uuid: 'z.string().uuid()',
      cuid: 'z.string().cuid()',
      ip: 'z.string().ip()',
      datetime: 'z.string().datetime()',
    };

    zodExpr = primitiveMap[base];
    if (!zodExpr) {
      console.error(`Unknown type code: ${base}`);
      process.exit(1);
    }
  }

  if (isArray) zodExpr = `z.array(${zodExpr})`;
  if (isOptional) zodExpr += ".optional()";

  return zodExpr;
}

function generateSchema(
  name: string,
  shape: Record<string, string>,
  strict: boolean
): string {
  const fields = Object.entries(shape)
    .map(([key, typeCode]) => `  ${key}: ${typeCodeToZod(typeCode)},`)
    .join("\n");

  const modifier = strict ? ".strict()" : "";

  return `import { z } from "zod";

const ${name} = z.object({
${fields}
})${modifier};

type ${name} = z.infer<typeof ${name}>;

export { ${name} };
export type { ${name} as ${name}Type };
`;
}

// Main
const config = parseArgs();
const code = generateSchema(config.name, config.shape, config.strict);
console.log(code);
