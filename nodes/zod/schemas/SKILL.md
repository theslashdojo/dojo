---
name: schemas
description: Define Zod schemas for any data shape — use when creating object schemas, arrays, enums, unions, tuples, records, or recursive types with Zod
---

# Zod Schema Definitions

Define runtime-validated, type-inferred schemas for any data shape using Zod.

## When to Use

- Creating a new data model or interface that needs runtime validation
- Defining API request/response shapes
- Building form validation schemas
- Modeling discriminated unions for events or state machines
- Creating recursive structures (trees, nested comments, JSON)

## Workflow

1. **Identify the data shape** — what fields, types, and constraints does the data have?
2. **Choose the right schema constructors** — `z.object()` for structured data, `z.array()` for lists, `z.enum()` for string unions, `z.discriminatedUnion()` for tagged unions, `z.lazy()` for recursive types
3. **Compose schemas** — use `.extend()`, `.merge()`, `.pick()`, `.omit()`, `.partial()` to derive variants from base schemas
4. **Infer the TypeScript type** — `type MyType = z.infer<typeof MySchema>`
5. **Export both** — the schema (for runtime validation) and the type (for compile-time checking)

## Schema Selection Guide

| Data Shape | Schema Constructor | Example |
|------------|-------------------|---------|
| Structured object | `z.object({...})` | User, Config, APIResponse |
| List of items | `z.array(schema)` | string[], User[] |
| Fixed-length typed array | `z.tuple([s1, s2])` | [number, number] for coordinates |
| String union | `z.enum(["a", "b"])` | Role, Status |
| TypeScript enum | `z.nativeEnum(Enum)` | Direction, LogLevel |
| Tagged union | `z.discriminatedUnion("key", [...])` | Event, APIResult |
| Untagged union | `z.union([s1, s2])` | string | number |
| Dictionary | `z.record(keySchema, valSchema)` | Record<string, number> |
| Exact value | `z.literal("value")` | Literal type |
| Recursive | `z.lazy(() => schema)` | Tree, LinkedList |
| Any JS primitive | `z.string()`, `z.number()`, etc. | string, number, boolean |

## Object Schema Operations

```typescript
const Base = z.object({ id: z.string(), name: z.string() });

Base.extend({ email: z.string().email() })   // add fields
Base.merge(OtherSchema)                       // combine two schemas
Base.pick({ id: true })                       // keep only selected fields
Base.omit({ name: true })                     // remove selected fields
Base.partial()                                // all fields optional
Base.partial({ name: true })                  // selective optional
Base.required()                               // all fields required
Base.passthrough()                            // keep unknown keys
Base.strict()                                 // reject unknown keys
Base.strip()                                  // remove unknown keys (default)
Base.catchall(z.string())                     // validate unknown keys
Base.shape.id                                 // access inner schema
Base.keyof()                                  // z.enum of keys
```

## Edge Cases

- **Recursive types**: Must annotate with `z.ZodType<Interface>` — TypeScript cannot infer circular types
- **z.any() vs z.unknown()**: Prefer `z.unknown()` — `z.any()` disables type checking entirely
- **Empty objects**: `z.object({})` matches any object (strips all keys by default)
- **Passthrough vs strict**: Default is strip mode — unknown keys are silently removed. Use `.strict()` to catch typos in API payloads, `.passthrough()` when you need to forward unknown fields

## Script

The `create-schema.ts` script generates a Zod schema from a JSON shape description:

```bash
npx tsx scripts/create-schema.ts --name UserSchema --shape '{"name":"string","email":"email","age":"number?","role":"enum:admin,user,guest"}'
```

Type codes: `string`, `number`, `boolean`, `date`, `email`, `url`, `uuid`, `enum:a,b,c`. Append `?` for optional, `[]` for array.
