---
name: transform
description: Transform, coerce, and pipe data through Zod schemas — use when reshaping validated data, coercing types, setting defaults, or building schema pipelines
---

# Zod Transforms

Reshape, coerce, and pipe validated data through Zod schema chains.

## When to Use

- Converting data from one shape to another after validation (snake_case → camelCase)
- Coercing string inputs to numbers, booleans, or dates (env vars, form data, URL params)
- Setting default values for optional fields
- Building multi-step validation pipelines where output of one schema feeds into another
- Creating nominal/branded types for type-safe IDs
- Making schemas produce deeply readonly types

## Workflow

1. **Identify the input and output shapes** — do they differ? If yes, you need transforms
2. **Choose the right tool**:
   - Input needs type conversion? → `z.coerce` or `.preprocess()`
   - Output needs reshaping? → `.transform()`
   - Need to validate the transformed output? → `.pipe()`
   - Need fallback for undefined? → `.default()`
   - Need fallback for invalid? → `.catch()`
   - Need nominal types? → `.brand()`
3. **Chain transforms** — they compose: `.transform(step1).transform(step2).pipe(finalValidator)`
4. **Extract types** — use `z.input<>` for pre-transform type, `z.output<>` / `z.infer<>` for post-transform type

## Tool Selection Guide

| Need | Tool | Example |
|------|------|---------|
| String → number | `z.coerce.number()` | PORT from env |
| String → boolean | `z.coerce.boolean()` | DEBUG flag |
| String → Date | `z.coerce.date()` | Timestamp from API |
| Reshape object | `.transform(obj => ({...}))` | snake_case → camelCase |
| Compute derived field | `.transform(obj => ({...obj, fullName: ...}))` | Concatenate fields |
| Validate after transform | `.transform(fn).pipe(schema)` | Parse string to int, validate range |
| Clean input before validation | `z.preprocess(fn, schema)` | Trim strings, split CSVs |
| Fallback for undefined | `.default(value)` | Default port 3000 |
| Fallback for invalid | `.catch(value)` | Catch and use fallback |
| Nominal type | `.brand<"Name">()` | UserId vs OrderId |
| Immutable output | `.readonly()` | Frozen config objects |

## Common Patterns

### Environment Variable Parsing
```typescript
const env = z.object({
  PORT: z.coerce.number().int().positive().default(3000),
  DEBUG: z.coerce.boolean().default(false),
  DATABASE_URL: z.string().url(),
}).parse(process.env);
```

### API Response Normalization
```typescript
const User = z.object({
  first_name: z.string(),
  last_name: z.string(),
}).transform(({ first_name, last_name }) => ({
  firstName: first_name,
  lastName: last_name,
}));
```

### String-to-Number with Validation
```typescript
const Port = z.string()
  .transform(Number)
  .pipe(z.number().int().min(1).max(65535));
```

## Edge Cases

- **z.coerce.boolean()**: Uses `Boolean()` — empty string `""` becomes `false`, `"false"` becomes `true` (it's a non-empty string). For string-to-boolean, use `.transform()` instead
- **Async transforms**: Must use `.parseAsync()` / `.safeParseAsync()` — synchronous parse will throw
- **Default vs catch**: `.default()` fires on `undefined` input only; `.catch()` fires on any validation failure
- **Transform errors**: If a `.transform()` function throws, the error becomes a ZodError issue
- **Ordering**: Validation runs first, then transform, then pipe validation. A failed initial validation skips the transform entirely

## Script

The `transform-data.ts` script demonstrates Zod transform pipelines:

```bash
npx tsx scripts/transform-data.ts --input '{"first_name":"Alice","last_name":"Smith"}' --transform 'snakeToCamel'
```
