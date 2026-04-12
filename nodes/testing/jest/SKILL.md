---
name: jest
description: Write and run JavaScript/TypeScript tests with Jest. Use when a project has jest in devDependencies, jest.config.* files, or *.test.js/ts files.
---

# Jest Testing

Jest is the standard test runner for JavaScript and TypeScript. This skill covers writing tests, mocking, snapshots, coverage, and running tests in CI.

## When to Use

Activate this skill when:

- The project has `jest` in `devDependencies` or `dependencies`
- Files matching `jest.config.*` exist in the project root
- Test files use `*.test.js`, `*.test.ts`, `*.spec.js`, or `*.spec.ts` patterns
- The user asks to write or run JavaScript/TypeScript tests
- A `__tests__/` directory exists
- The `package.json` has a `"test"` script that invokes `jest`
- Snapshot files (`*.snap`) exist in `__snapshots__/` directories
- The user mentions Jest, describe/it/expect, jest.mock, or jest.fn

Do NOT use this skill when:

- The project uses Vitest (`vitest.config.*` or `import { describe } from 'vitest'`) -- use the vitest skill instead
- The project uses Mocha, Jasmine, or another JS test runner
- The tests are for Python (use pytest skill) or another language
- The user needs browser E2E testing (use Playwright skill)

## Workflow

### 1. Initialize (if Jest is not set up)

```bash
# Install Jest
npm install --save-dev jest

# For TypeScript projects
npm install --save-dev jest @types/jest ts-jest
# OR with SWC (faster, no type checking)
npm install --save-dev jest @types/jest @swc/jest @swc/core

# Create config
npx ts-jest config:init  # for ts-jest
# OR create jest.config.js manually
```

Minimal `jest.config.js` for TypeScript:

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
};
```

Minimal `jest.config.js` for SWC:

```javascript
module.exports = {
  transform: {
    '^.+\\.(t|j)sx?$': '@swc/jest',
  },
  testEnvironment: 'node',
};
```

### 2. Write Tests

Follow the describe/it/expect pattern:

```typescript
import { calculateTotal } from './billing';

describe('calculateTotal', () => {
  it('sums item prices', () => {
    const items = [{ price: 10 }, { price: 20 }, { price: 30 }];
    expect(calculateTotal(items)).toBe(60);
  });

  it('applies discount', () => {
    const items = [{ price: 100 }];
    expect(calculateTotal(items, { discount: 0.1 })).toBe(90);
  });

  it('returns 0 for empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });

  it('throws on negative prices', () => {
    const items = [{ price: -5 }];
    expect(() => calculateTotal(items)).toThrow('Negative price');
  });
});
```

### 3. Run Tests

```bash
npx jest                          # run all tests
npx jest user-service             # run tests matching pattern
npx jest --watch                  # interactive watch mode
npx jest --coverage               # generate coverage report
npx jest --verbose                # show individual test results
npx jest --bail                   # stop on first failure
npx jest -u                       # update snapshots
npx jest --testPathPattern='api'  # filter by file path
npx jest --testNamePattern='auth' # filter by test name
```

### 4. Review Coverage

```bash
npx jest --coverage
# Terminal output shows per-file coverage table
# HTML report generated at coverage/lcov-report/index.html
```

Enforce thresholds in `jest.config.js`:

```javascript
module.exports = {
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 80, statements: 80 },
  },
};
```

## Quick Reference

### Common Commands

| Command | Purpose |
|---------|---------|
| `npx jest` | Run all tests |
| `npx jest --watch` | Watch mode (re-run on changes) |
| `npx jest --watchAll` | Watch all files (not just git-changed) |
| `npx jest --coverage` | Run with coverage report |
| `npx jest --verbose` | Show each test name |
| `npx jest --bail` | Stop on first failure |
| `npx jest -u` | Update snapshots |
| `npx jest path/to/file` | Run specific file |
| `npx jest -t "test name"` | Run tests matching name |
| `npx jest --forceExit` | Force exit after tests (use sparingly) |
| `CI=true npx jest` | CI mode: no watch, fail on console.error |

### Core Matchers

```typescript
// Equality
expect(value).toBe(primitive);          // === strict
expect(obj).toEqual(otherObj);          // deep equality
expect(obj).toStrictEqual(otherObj);    // deep + undefined props

// Truthiness
expect(value).toBeTruthy();
expect(value).toBeFalsy();
expect(value).toBeNull();
expect(value).toBeUndefined();
expect(value).toBeDefined();

// Numbers
expect(num).toBeGreaterThan(3);
expect(num).toBeLessThanOrEqual(10);
expect(0.1 + 0.2).toBeCloseTo(0.3);

// Strings
expect(str).toMatch(/pattern/);
expect(str).toContain('substring');

// Arrays
expect(arr).toContain(item);
expect(arr).toHaveLength(3);
expect(arr).toContainEqual({ id: 1 });

// Objects
expect(obj).toMatchObject({ key: 'value' });
expect(obj).toHaveProperty('nested.key', 'value');

// Errors
expect(() => fn()).toThrow();
expect(() => fn()).toThrow('message');
expect(() => fn()).toThrow(TypeError);

// Async
await expect(promise).resolves.toBe(value);
await expect(promise).rejects.toThrow('error');

// Mocks
expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledWith(arg1, arg2);
expect(mockFn).toHaveBeenCalledTimes(3);

// Negation
expect(value).not.toBe(other);
```

### Mock Cheat Sheet

```typescript
// Create mock function
const mock = jest.fn();
const mockWithReturn = jest.fn().mockReturnValue(42);
const mockAsync = jest.fn().mockResolvedValue({ data: 'ok' });

// Mock a module
jest.mock('./module');                    // auto-mock all exports
jest.mock('./module', () => ({            // custom factory
  myFn: jest.fn().mockReturnValue(true),
}));
jest.mock('./module', () => ({            // partial mock
  ...jest.requireActual('./module'),
  onlyThisFn: jest.fn(),
}));

// Spy on existing method
const spy = jest.spyOn(obj, 'method');
spy.mockReturnValue('mocked');
// ... test ...
spy.mockRestore();

// Timer mocks
jest.useFakeTimers();
jest.advanceTimersByTime(1000);
jest.runAllTimers();
jest.useRealTimers();
```

## Mocking Patterns

### Mocking a Dependency

When the module under test imports another module:

```typescript
// service.ts
import { db } from './database';
export async function getUsers() {
  return db.query('SELECT * FROM users');
}

// service.test.ts
import { getUsers } from './service';
import { db } from './database';

jest.mock('./database');
const mockedDb = db as jest.Mocked<typeof db>;

beforeEach(() => {
  mockedDb.query.mockResolvedValue([{ id: 1, name: 'Alice' }]);
});

it('returns users from database', async () => {
  const users = await getUsers();
  expect(users).toEqual([{ id: 1, name: 'Alice' }]);
  expect(mockedDb.query).toHaveBeenCalledWith('SELECT * FROM users');
});
```

### Mocking Fetch / HTTP

```typescript
// Using jest.spyOn on global fetch
beforeEach(() => {
  jest.spyOn(global, 'fetch').mockResolvedValue({
    ok: true,
    json: async () => ({ data: 'test' }),
  } as Response);
});

afterEach(() => {
  jest.restoreAllMocks();
});

it('fetches data', async () => {
  const result = await fetchData('/api/items');
  expect(fetch).toHaveBeenCalledWith('/api/items', expect.any(Object));
  expect(result).toEqual({ data: 'test' });
});
```

### Mocking Classes

```typescript
jest.mock('./api-client');
import { ApiClient } from './api-client';

const MockedApiClient = ApiClient as jest.MockedClass<typeof ApiClient>;

beforeEach(() => {
  MockedApiClient.mockClear();
  MockedApiClient.prototype.get.mockResolvedValue({ status: 200 });
});

it('uses api client', () => {
  const service = new ServiceUnderTest();
  // ApiClient constructor and methods are all mocked
});
```

## Async Test Patterns

```typescript
// async/await (most common)
it('fetches user', async () => {
  const user = await getUser(1);
  expect(user.name).toBe('Alice');
});

// Promise .resolves / .rejects
it('resolves with data', async () => {
  await expect(getUser(1)).resolves.toMatchObject({ name: 'Alice' });
});

it('rejects for missing user', async () => {
  await expect(getUser(999)).rejects.toThrow('Not found');
});

// Testing callbacks (use done parameter)
it('calls back with data', (done) => {
  fetchWithCallback('/api', (err, data) => {
    try {
      expect(err).toBeNull();
      expect(data).toBeDefined();
      done();
    } catch (e) {
      done(e);
    }
  });
});
```

## Snapshot Testing Workflow

1. Write the test with `toMatchSnapshot()` or `toMatchInlineSnapshot()`
2. Run tests -- Jest creates the initial snapshot
3. On subsequent runs, Jest compares against the stored snapshot
4. If the output changed intentionally, run `npx jest -u` to update
5. Review snapshot diffs in pull requests

```typescript
it('renders component', () => {
  const tree = renderer.create(<Button label="Click me" />).toJSON();
  expect(tree).toMatchSnapshot();
});

// Use property matchers for dynamic values
it('creates record', () => {
  const record = createRecord('test');
  expect(record).toMatchSnapshot({
    id: expect.any(String),
    timestamp: expect.any(Number),
  });
});
```

Best practices:

- Commit `.snap` files to version control
- Keep snapshots small and focused
- Prefer `toMatchInlineSnapshot()` for short values
- Review snapshot changes carefully in code review
- Delete stale snapshots with `npx jest --ci` (fails on new snapshots)

## Edge Cases and Gotchas

### ESM Support

Jest's ESM support is experimental. If you see `SyntaxError: Cannot use import statement`:

```javascript
// Option 1: Use ts-jest or @swc/jest to transform imports
// Option 2: Set transform to handle .mjs files
// Option 3: Use experimental ESM mode
// In package.json or jest.config:
// NODE_OPTIONS=--experimental-vm-modules npx jest
```

For projects using ESM heavily, consider switching to Vitest.

### Timer Mocking Pitfalls

```typescript
// Always pair useFakeTimers with useRealTimers
beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

// Be careful with Promises + fake timers
it('handles async with timers', async () => {
  const promise = delayedFetch(); // starts a setTimeout internally
  jest.advanceTimersByTime(5000);
  const result = await promise;   // NOW await the result
  expect(result).toBeDefined();
});

// Use modern fake timers (default in Jest 27+)
jest.useFakeTimers({ legacyFakeTimers: false });
```

### Module Resolution Issues

```javascript
// jest.config.js - fix common resolution issues
module.exports = {
  // Map TypeScript path aliases
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@tests/(.*)$': '<rootDir>/tests/$1',
  },
  // Mock static assets
  moduleNameMapper: {
    '\\.(css|less|scss)$': 'identity-obj-proxy',
    '\\.(jpg|jpeg|png|svg)$': '<rootDir>/tests/__mocks__/fileMock.js',
  },
};
```

### jest.mock Hoisting

`jest.mock()` calls are hoisted to the top of the file. This means:

```typescript
// This WORKS -- jest.mock is hoisted above the import
import { thing } from './module';
jest.mock('./module');

// This DOES NOT WORK -- variables aren't hoisted
const mockValue = 'test';
jest.mock('./module', () => ({
  thing: mockValue, // ERROR: mockValue is not defined
}));

// FIX: use jest.mock with inline values or doMock
jest.mock('./module', () => ({
  thing: 'test', // inline the value
}));

// OR use doMock (not hoisted)
let mockValue: string;
beforeEach(() => {
  mockValue = 'test';
  jest.doMock('./module', () => ({ thing: mockValue }));
});
```

### Memory Leaks in Tests

```javascript
// jest.config.js -- detect and mitigate leaks
module.exports = {
  // Log leaked handles
  detectOpenHandles: true,
  // Force exit after all tests complete (escape hatch)
  forceExit: false, // prefer fixing the leak over forcing exit
  // Limit workers to reduce memory
  maxWorkers: '50%',
};
```

### CI-Specific Configuration

```javascript
// jest.config.js
module.exports = {
  ...(process.env.CI && {
    // In CI: run sequentially for stability
    maxWorkers: 1,
    // Fail on new snapshots (must be committed beforehand)
    ci: true,
    // Add JUnit reporter for CI integration
    reporters: ['default', ['jest-junit', {
      outputDirectory: 'test-results',
      outputName: 'junit.xml',
    }]],
  }),
};
```

### Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot find module` | Missing module or wrong path | Check moduleNameMapper, install dependency |
| `SyntaxError: Unexpected token` | Missing transform for file type | Add transform for .ts, .tsx, .jsx, .mjs |
| `Your test suite must contain at least one test` | Empty test file or wrong testMatch | Check file naming and testMatch config |
| `Exceeded timeout of 5000ms` | Async test not resolving | Increase timeout or fix async logic |
| `ReferenceError: describe is not defined` | Jest globals not available | Check testEnvironment or add @jest/globals import |

## Project Setup Checklist

1. Install: `npm i -D jest @types/jest` (+ `ts-jest` or `@swc/jest` for TS)
2. Config: Create `jest.config.js` with environment, transform, and path mappings
3. Scripts: Add `"test": "jest"`, `"test:watch": "jest --watch"`, `"test:cov": "jest --coverage"` to package.json
4. First test: Create `src/example.test.ts` with a simple describe/it/expect
5. Run: `npx jest` to verify setup
6. CI: Add `CI=true npx jest --coverage` to pipeline
7. Coverage: Set `coverageThreshold` in config once baseline is established
