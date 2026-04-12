---
name: vitest
description: Write and run tests with Vitest, the Vite-native test framework. Use when a project uses Vite, has vitest in devDependencies, or vitest.config.* files.
---

# Vitest — Vite-Native Test Framework

Vitest is the test framework built on Vite. It gives you native ESM, TypeScript, and JSX transforms with zero config, a Jest-compatible API, and watch mode powered by Vite's HMR.

## When to Use

- Project uses Vite as its build tool
- `vitest` is in devDependencies or `vitest.config.ts` exists
- New TypeScript/JavaScript project that needs unit tests (prefer Vitest over Jest for new projects)
- Migrating from Jest and want native ESM/TypeScript support without babel or ts-jest
- Need fast watch mode with HMR-based selective re-runs
- Monorepo with multiple test configurations (workspace mode)
- Component testing in a real browser (browser mode)

## When NOT to Use

- Python projects -- use pytest instead
- E2E browser testing of full user flows -- use Playwright
- Project locked to Jest with deep custom transforms and no Vite
- Node.js-only project with no TypeScript and no ESM -- Jest works fine

## Workflow

1. Install: `npm install -D vitest`
2. Create config: `vitest.config.ts` or add `test` block to `vite.config.ts`
3. Write tests: `src/**/*.test.ts` using `describe`, `it`, `expect` from `vitest`
4. Run: `npx vitest` (watch mode) or `npx vitest run` (single pass for CI)
5. Add coverage: `npm install -D @vitest/coverage-v8` then `npx vitest run --coverage`
6. CI: use `npx vitest run` (exits with non-zero on failure)

## Quick Reference

### Installation

```bash
# Core
npm install -D vitest

# Coverage (pick one)
npm install -D @vitest/coverage-v8
npm install -D @vitest/coverage-istanbul

# DOM environments (pick one)
npm install -D jsdom
npm install -D happy-dom

# UI dashboard
npm install -D @vitest/ui

# Browser mode
npm install -D @vitest/browser playwright
```

### CLI Commands

```bash
npx vitest                        # watch mode
npx vitest run                    # single run (CI)
npx vitest run src/utils          # filter by path
npx vitest run --coverage         # with coverage
npx vitest --ui                   # browser dashboard
npx vitest bench                  # benchmarks
npx vitest typecheck              # type assertions
npx vitest run --reporter=json    # JSON output
npx vitest run --changed HEAD~1   # only changed tests
npx vitest run --update           # update snapshots
npx vitest run --bail 3           # stop after 3 failures
npx vitest list                   # list test files
npx vitest --project unit         # specific workspace project
```

### Watch Mode Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `a` | Re-run all tests |
| `f` | Re-run only failed tests |
| `u` | Update snapshots |
| `p` | Filter by filename |
| `t` | Filter by test name |
| `q` | Quit |

## Configuration

### vitest.config.ts (standalone)

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.{test,spec}.{ts,tsx,js,jsx}'],
    exclude: ['node_modules', 'dist', 'e2e'],
    environment: 'node',            // or 'jsdom', 'happy-dom'
    globals: true,                   // no need to import describe/it/expect
    setupFiles: ['./src/test/setup.ts'],
    testTimeout: 10000,
    pool: 'threads',                 // 'threads', 'forks', 'vmThreads'
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.test.ts', 'src/**/*.d.ts'],
      thresholds: { lines: 80, branches: 75, functions: 80, statements: 80 },
    },
  },
});
```

### Inside vite.config.ts

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test/setup.ts',
  },
});
```

### Per-file Environment Override

```typescript
// @vitest-environment jsdom
import { it, expect } from 'vitest';

it('uses the DOM', () => {
  const div = document.createElement('div');
  expect(div.tagName).toBe('DIV');
});
```

## Writing Tests

### Basic Test Structure

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest';

describe('Calculator', () => {
  let calc: Calculator;

  beforeEach(() => {
    calc = new Calculator();
  });

  it('adds numbers', () => {
    expect(calc.add(2, 3)).toBe(5);
  });

  it('throws on divide by zero', () => {
    expect(() => calc.divide(1, 0)).toThrow('Division by zero');
  });
});
```

### Async Tests

```typescript
it('fetches users', async () => {
  const users = await fetchUsers();
  expect(users).toHaveLength(3);
});

it('rejects on error', async () => {
  await expect(fetchBadUrl()).rejects.toThrow('Not Found');
});
```

### Data-Driven Tests (each)

```typescript
it.each([
  { input: 1, expected: 2 },
  { input: 2, expected: 4 },
  { input: 0, expected: 0 },
])('doubles $input to $expected', ({ input, expected }) => {
  expect(input * 2).toBe(expected);
});

describe.each([
  { env: 'development', debug: true },
  { env: 'production', debug: false },
])('in $env mode', ({ env, debug }) => {
  it(`debug is ${debug}`, () => {
    expect(getConfig(env).debug).toBe(debug);
  });
});
```

### Snapshot Testing

```typescript
it('matches snapshot', () => {
  expect(renderConfig({ mode: 'prod' })).toMatchSnapshot();
});

it('matches inline snapshot', () => {
  expect(formatName('alice')).toMatchInlineSnapshot(`"Alice"`);
});
```

Update snapshots: `npx vitest run --update` or press `u` in watch mode.

## Mocking with vi

### Mock Functions

```typescript
import { vi, it, expect } from 'vitest';

const fn = vi.fn();
fn('a'); fn('b');
expect(fn).toHaveBeenCalledTimes(2);
expect(fn).toHaveBeenCalledWith('a');

// Return values
const mock = vi.fn()
  .mockReturnValueOnce('first')
  .mockReturnValue('default');

// Async
const asyncMock = vi.fn().mockResolvedValue({ ok: true });
```

### Module Mocking

```typescript
import { vi, it, expect } from 'vitest';
import { getUser } from './api';
import { fetchFromDB } from './db';

vi.mock('./db', () => ({
  fetchFromDB: vi.fn().mockResolvedValue({ id: 1, name: 'Alice' }),
}));

it('uses mocked db', async () => {
  const user = await getUser(1);
  expect(user.name).toBe('Alice');
  expect(fetchFromDB).toHaveBeenCalledWith(1);
});
```

`vi.mock()` is auto-hoisted to the top of the file.

### Spies

```typescript
const obj = { greet: (n: string) => `Hi ${n}` };
const spy = vi.spyOn(obj, 'greet');
obj.greet('Alice');
expect(spy).toHaveBeenCalledWith('Alice');
spy.mockRestore(); // restore original
```

### Stubbing Globals

```typescript
import { vi, afterEach } from 'vitest';

afterEach(() => vi.unstubAllGlobals());

vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
  ok: true,
  json: () => Promise.resolve({ data: 'test' }),
}));
```

### Fake Timers

```typescript
import { vi, it, expect, beforeEach, afterEach } from 'vitest';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

it('advances timers', () => {
  const fn = vi.fn();
  setTimeout(fn, 5000);
  vi.advanceTimersByTime(5000);
  expect(fn).toHaveBeenCalledOnce();
});
```

### Cleanup Pattern

```typescript
import { afterEach, vi } from 'vitest';

afterEach(() => {
  vi.restoreAllMocks();    // restore spies and mocked implementations
  vi.unstubAllGlobals();   // restore stubbed globals
});
```

## Coverage Setup

```bash
npm install -D @vitest/coverage-v8
npx vitest run --coverage
```

Config:

```typescript
test: {
  coverage: {
    provider: 'v8',
    reporter: ['text', 'html', 'lcov'],
    include: ['src/**/*.ts'],
    exclude: ['src/**/*.test.ts', 'src/**/*.d.ts', 'src/test/**'],
    thresholds: { lines: 80, branches: 75, functions: 80, statements: 80 },
  },
}
```

| Provider | Package | Characteristics |
|----------|---------|----------------|
| V8 | `@vitest/coverage-v8` | Fast, uses V8 engine counters, good for most projects |
| Istanbul | `@vitest/coverage-istanbul` | Traditional instrumentation, more accurate branch coverage |

## Workspace / Monorepo

```typescript
// vitest.workspace.ts
import { defineWorkspace } from 'vitest/config';

export default defineWorkspace([
  'packages/*/vitest.config.ts',
  {
    test: {
      name: 'server',
      include: ['server/**/*.test.ts'],
      environment: 'node',
    },
  },
  {
    test: {
      name: 'client',
      include: ['client/**/*.test.ts'],
      environment: 'jsdom',
    },
  },
]);
```

```bash
npx vitest                   # run all projects
npx vitest --project server  # run only server tests
```

## Migration from Jest

### Step-by-step

1. `npm install -D vitest @vitest/coverage-v8`
2. `npm uninstall jest ts-jest babel-jest @types/jest`
3. Delete `jest.config.js` / `jest.config.ts`
4. Create `vitest.config.ts` with `globals: true` (to avoid changing all test files)
5. Find-and-replace `jest.` with `vi.` in test files
6. If not using globals, add `import { describe, it, expect, vi } from 'vitest'` to each test file
7. Update package.json: `"test": "vitest run"`, `"test:watch": "vitest"`
8. Run `npx vitest run` and fix any remaining issues

### Search-and-Replace Map

| Jest | Vitest |
|------|--------|
| `jest.fn()` | `vi.fn()` |
| `jest.mock(...)` | `vi.mock(...)` |
| `jest.spyOn(...)` | `vi.spyOn(...)` |
| `jest.useFakeTimers()` | `vi.useFakeTimers()` |
| `jest.advanceTimersByTime(n)` | `vi.advanceTimersByTime(n)` |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` |
| `jest.resetAllMocks()` | `vi.resetAllMocks()` |
| `jest.restoreAllMocks()` | `vi.restoreAllMocks()` |
| `jest.requireActual(...)` | `vi.importActual(...)` |
| `@jest/globals` | `vitest` |

### What Just Works

- `describe`, `it`, `test`, `expect` -- same API, same matchers
- `beforeEach`, `afterEach`, `beforeAll`, `afterAll` -- identical
- Snapshot files (`.snap`) -- compatible format
- `it.each` / `describe.each` -- same syntax
- `it.skip`, `it.only`, `it.todo` -- identical

### What Changes

- No `moduleNameMapper` -- use Vite's `resolve.alias` instead
- No `transform` config -- Vite handles all transforms
- `jest.mock()` hoisting is implicit; `vi.mock()` is also hoisted but uses different scoping
- `jest.requireActual` becomes `vi.importActual` (async)
- Timer mocking API is the same but `vi.` prefix

## Type Testing

```typescript
import { expectTypeOf, describe, it } from 'vitest';

describe('type tests', () => {
  it('validates function signature', () => {
    expectTypeOf(sum).toBeFunction();
    expectTypeOf(sum).parameter(0).toBeNumber();
    expectTypeOf(sum).returns.toBeNumber();
  });

  it('validates object shape', () => {
    expectTypeOf<{ name: string; age: number }>()
      .toMatchTypeOf<{ name: string }>();
  });

  it('validates generic types', () => {
    expectTypeOf<string>().toBeString();
    expectTypeOf<number>().not.toBeString();
  });
});
```

Enable: `test.typecheck.enabled: true` in config. Run: `npx vitest typecheck`.

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `VITEST` | `"true"` | Detect Vitest at runtime |
| `VITEST_MODE` | `"run"` / `"watch"` / `"benchmark"` | Current execution mode |
| `VITEST_POOL_ID` | number | Pool thread/fork ID (0-indexed) |
| `VITEST_WORKER_ID` | number | Unique worker ID across all pools |
| `TEST` | `"true"` | Generic test detection |
| `NODE_ENV` | `"test"` | Set by default unless overridden |

## Edge Cases and Gotchas

- **vi.mock hoisting**: `vi.mock()` calls are hoisted above imports. Variables defined before `vi.mock()` are not accessible inside the factory — use `vi.hoisted()` to define mock data that the factory can reference.
- **vi.mock vs vi.doMock**: `vi.mock()` is hoisted; `vi.doMock()` is not. Use `vi.doMock()` when you need dynamic per-test module mocking with `await import()`.
- **globals: true pitfall**: When `globals: true` is set, `vi` is NOT auto-injected — you still need `import { vi } from 'vitest'` for mocking. Only `describe`, `it`, `expect`, lifecycle hooks, and `expectTypeOf` become global.
- **ESM mocking scope**: Mocked modules are cached per test file, not per test. Use `vi.restoreAllMocks()` in `afterEach` to reset state between tests.
- **jsdom limitations**: jsdom does not support navigation, layout, or visual rendering. For tests that need real CSS or real browser APIs, use browser mode.
- **happy-dom vs jsdom**: happy-dom is 2-3x faster but less complete. Use it for simple DOM operations; switch to jsdom for complex component rendering.
- **Snapshot path**: snapshots go to `__snapshots__/` next to the test file. Inline snapshots are written directly into the test source.
- **CI detection**: Vitest auto-detects CI environments and switches to run mode (no watch). Set `CI=true` env var to force this behavior.
- **Coverage with threads pool**: V8 coverage works with threads pool. If coverage numbers look wrong, try `pool: 'forks'` which provides more isolation.
- **Type testing does not run code**: `vitest typecheck` only checks types — runtime assertions in the same file still need a regular `vitest run`.

## package.json Scripts

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui",
    "test:watch": "vitest --watch",
    "test:typecheck": "vitest typecheck"
  }
}
```

## Project Layout

```
project/
  vitest.config.ts          # or test block in vite.config.ts
  src/
    math.ts
    math.test.ts            # co-located test
    utils/
      format.ts
      format.test.ts
  tests/                    # or a dedicated test directory
    integration/
      api.test.ts
    setup.ts                # setup file referenced in config
  coverage/                 # generated coverage output (gitignore this)
```
