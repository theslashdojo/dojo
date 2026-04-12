---
name: validation
description: Validate and constrain data with Zod — use when adding validators, custom refinements, handling errors, or choosing between parse and safeParse
---

# Zod Validation

Validate unknown data against Zod schemas with built-in validators, custom refinements, and structured error handling.

## When to Use

- Adding length, range, format, or pattern constraints to schema fields
- Writing custom validation logic (cross-field validation, async checks)
- Deciding between `.parse()` (throws) and `.safeParse()` (returns result)
- Handling and formatting validation errors for UIs or API responses
- Setting up custom error messages or global error maps

## Workflow

1. **Define the schema shape** (see `zod/schemas`)
2. **Add built-in validators** — `.min()`, `.max()`, `.email()`, `.int()`, `.positive()`, etc.
3. **Add custom refinements** — `.refine()` for simple checks, `.superRefine()` for complex/cross-field validation
4. **Choose the parsing mode** — `.parse()` for throw-on-error, `.safeParse()` for result objects
5. **Format errors** — `.flatten()` for form UIs, `.format()` for nested error objects

## Built-in Validators Quick Reference

### Strings
`.min(n)` `.max(n)` `.length(n)` `.email()` `.url()` `.uuid()` `.cuid()` `.cuid2()` `.ulid()` `.regex(re)` `.includes(str)` `.startsWith(str)` `.endsWith(str)` `.datetime()` `.ip()` `.emoji()` `.trim()` `.toLowerCase()` `.toUpperCase()`

### Numbers
`.gt(n)` `.gte(n)` `.lt(n)` `.lte(n)` `.int()` `.positive()` `.nonnegative()` `.negative()` `.nonpositive()` `.multipleOf(n)` `.finite()` `.safe()`

### Arrays
`.nonempty()` `.min(n)` `.max(n)` `.length(n)`

### Dates
`.min(date)` `.max(date)`

## Custom Validation Decision Tree

- **Simple boolean check** → `.refine((val) => check, "message")`
- **Multiple independent checks** → chain `.refine()` calls
- **Cross-field object validation** → `.superRefine((data, ctx) => { ctx.addIssue(...) })`
- **Async validation (DB lookup, API call)** → `.refine(async (val) => ..., { message })` + use `.parseAsync()`
- **Conditional validation** → `.superRefine()` with `if` branches and `ctx.addIssue()`

## Error Handling Guide

```typescript
const result = schema.safeParse(data);
if (!result.success) {
  // For form UIs: flat field → error mapping
  result.error.flatten();
  // { formErrors: string[], fieldErrors: { [field]: string[] } }

  // For nested structures: matches schema shape
  result.error.format();
  // { fieldName: { _errors: string[] }, nested: { field: { _errors: [...] } } }

  // Raw issues array
  result.error.issues;
  // [{ code, path, message, ... }]
}
```

## Edge Cases

- **Async refinements require async parsing**: If any `.refine()` returns a Promise, you MUST use `.parseAsync()` or `.safeParseAsync()` — synchronous `.parse()` will throw
- **Refinement ordering**: `.refine()` calls run in order; later refinements only run if earlier ones pass
- **superRefine early abort**: Call `ctx.addIssue()` then `return z.NEVER` to stop further validation
- **Error messages on base types**: Use `z.string({ required_error: "...", invalid_type_error: "..." })` for type-level messages, not `.refine()`

## Script

The `validate-data.ts` script validates JSON data against a Zod schema:

```bash
echo '{"name":"Alice","email":"bad"}' | npx tsx scripts/validate-data.ts --schema 'z.object({ name: z.string(), email: z.string().email() })'
```
