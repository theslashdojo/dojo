---
name: rules
description: Enable, disable, and configure ESLint rules — set severities, add options, create per-file overrides, and use inline directives. Use when fixing lint violations, adjusting rule strictness, or suppressing rules for specific files.
---

# ESLint Rules

Manage ESLint rule configuration: severities, options, per-file overrides, and inline disable directives.

## When to Use

- Fixing a lint error by adjusting rule severity or options
- Disabling a rule for a specific file or line
- Adding stricter rules to a project
- Setting up per-file overrides (relaxed rules for tests, scripts)
- Finding out what a specific ESLint rule does

## Workflow

1. Identify the rule name from the error message (e.g., `no-unused-vars`)
2. Decide the action: configure in config, override per-file, or disable inline
3. Choose severity: `"off"` to disable, `"warn"` for soft guidance, `"error"` for enforcement
4. Apply rule options if needed (array form: `["error", { option: value }]`)
5. Verify: `npx eslint --print-config <file>` to check resolved rules

## Quick Reference

### Severity Levels

```javascript
rules: {
  "rule-name": "off",    // 0 — disabled
  "rule-name": "warn",   // 1 — warning (exit 0)
  "rule-name": "error",  // 2 — error (exit 1)
}
```

### Rules with Options

```javascript
rules: {
  "no-unused-vars": ["error", {
    argsIgnorePattern: "^_",
    varsIgnorePattern: "^_",
    caughtErrorsIgnorePattern: "^_",
  }],
  quotes: ["error", "double", { allowTemplateLiterals: true }],
  semi: ["error", "always"],
  "max-len": ["warn", { code: 100, ignoreUrls: true }],
}
```

### Inline Directives

```javascript
// Disable for next line
// eslint-disable-next-line no-console
console.log("debug");

// Disable for current line
console.log("debug"); // eslint-disable-line no-console

// Disable for block
/* eslint-disable no-console */
console.log("a");
console.log("b");
/* eslint-enable no-console */

// Disable for entire file (top of file)
/* eslint-disable no-console */

// With explanation (best practice)
// eslint-disable-next-line no-console -- Required for CLI output
console.log(result);
```

### Per-File Overrides

```javascript
export default [
  { rules: { "no-console": "error" } },
  {
    files: ["**/*.test.{js,ts}", "**/*.spec.{js,ts}"],
    rules: { "no-console": "off", "no-unused-expressions": "off" },
  },
  {
    files: ["scripts/**"],
    rules: { "no-console": "off" },
  },
];
```

## Common Patterns

### Underscore-prefixed unused vars

```javascript
"no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }]
```

### Allow console in development

```javascript
"no-console": process.env.NODE_ENV === "production" ? "error" : "warn"
```

### Catch stale disable comments

```javascript
linterOptions: {
  reportUnusedDisableDirectives: "error",
}
```

## Edge Cases

- When using typescript-eslint, disable the base ESLint rule and enable the TS version: turn off `no-unused-vars`, turn on `@typescript-eslint/no-unused-vars`
- Rule options are rule-specific — check the rule's documentation page for available options
- Inline directives should always specify rule names — avoid blanket `/* eslint-disable */`
- Plugin rules use `namespace/rule-name` format: `"react/prop-types"`, `"@typescript-eslint/no-explicit-any"`
- Later config objects in the array override earlier ones for the same rule on matching files
