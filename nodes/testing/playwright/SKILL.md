---
name: playwright
description: Write and run cross-browser end-to-end tests with Playwright. Use when testing web UI flows, browser automation, or visual regression in Chromium/Firefox/WebKit.
---

# Playwright End-to-End Testing

Playwright drives Chromium, Firefox, and WebKit with a single API. Tests auto-wait for elements, intercept network requests, compare screenshots, and run in parallel across browser/device configurations.

## When to Use

- Testing web application flows end-to-end (login, checkout, dashboards)
- Automating browser interactions (form fills, navigation, file uploads)
- Visual regression testing (screenshot comparison across deploys)
- Cross-browser verification (Chromium, Firefox, WebKit, mobile viewports)
- Mocking API responses for frontend-only testing
- Recording user actions as test code with codegen
- Debugging test failures with trace viewer

## When NOT to Use

- Unit testing pure functions or business logic (use Jest/Vitest/pytest)
- API-only testing with no browser UI (use supertest or httpx)
- Load testing or performance benchmarks (use k6, Artillery, or Locust)
- Testing native mobile apps (use Appium or Detox)

## Workflow

1. Install: `npm init playwright@latest` or `npm install -D @playwright/test`
2. Install browsers: `npx playwright install --with-deps`
3. Configure: edit `playwright.config.ts` (baseURL, projects, retries, trace)
4. Write tests in `tests/*.spec.ts` using `test()` and `expect()`
5. Run: `npx playwright test`
6. Debug: `npx playwright test --ui` or inspect traces
7. CI: install browsers, run headless, upload report artifact

## Quick Reference

### CLI Commands

```bash
npx playwright test                          # run all tests
npx playwright test tests/login.spec.ts      # run one file
npx playwright test --grep "checkout"        # filter by name
npx playwright test --project=chromium       # single browser
npx playwright test --headed                 # visible browser
npx playwright test --ui                     # interactive UI mode
npx playwright test --update-snapshots       # update visual references
npx playwright codegen https://example.com   # record test actions
npx playwright show-report                   # open HTML report
npx playwright show-trace trace.zip          # open trace viewer
npx playwright install --with-deps           # install browsers + OS deps
```

### Config Essentials

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'blob' : 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

## Code Examples

### Navigation and Basic Assertions

```typescript
import { test, expect } from '@playwright/test';

test('homepage loads correctly', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/My App/);
  await expect(page.getByRole('heading', { name: 'Welcome' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Get Started' })).toBeEnabled();
});
```

### Form Interaction

```typescript
test('register new user', async ({ page }) => {
  await page.goto('/register');
  await page.getByLabel('Full name').fill('Alice Johnson');
  await page.getByLabel('Email').fill('alice@example.com');
  await page.getByLabel('Password').fill('Str0ng!Pass');
  await page.getByLabel('Country').selectOption('US');
  await page.getByLabel('I agree to the terms').check();
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByText('Account created')).toBeVisible();
});
```

### Locator Strategies

```typescript
// BEST: role-based (most resilient to refactors)
page.getByRole('button', { name: 'Submit' });
page.getByRole('heading', { name: 'Dashboard' });
page.getByRole('link', { name: 'Settings' });

// GOOD: semantic locators
page.getByLabel('Email');
page.getByPlaceholder('Search...');
page.getByText('Welcome back');

// OK: test ID (explicit contract)
page.getByTestId('nav-menu');

// LAST RESORT: CSS/XPath
page.locator('.card-container .title');

// Filtering and chaining
page.getByRole('listitem').filter({ hasText: 'Product A' });
page.getByRole('listitem').nth(0);
```

### Assertions

```typescript
// Visibility
await expect(page.getByText('Success')).toBeVisible();
await expect(page.getByText('Error')).not.toBeVisible();

// Text
await expect(page.getByRole('heading')).toHaveText('Dashboard');
await expect(page.getByRole('heading')).toContainText('Dash');

// Count
await expect(page.getByRole('listitem')).toHaveCount(5);

// Form state
await expect(page.getByLabel('Email')).toHaveValue('user@test.com');
await expect(page.getByRole('button')).toBeEnabled();
await expect(page.getByLabel('Newsletter')).toBeChecked();

// Page-level
await expect(page).toHaveTitle('Dashboard');
await expect(page).toHaveURL(/\/dashboard/);

// Soft (non-blocking, reports at end)
await expect.soft(page.getByText('Beta')).toBeVisible();
```

### Network Mocking

```typescript
test('mock API and verify UI', async ({ page }) => {
  await page.route('**/api/products', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([
        { id: 1, name: 'Widget', price: 9.99 },
      ]),
    });
  });

  await page.goto('/products');
  await expect(page.getByText('Widget')).toBeVisible();
});

test('mock error response', async ({ page }) => {
  await page.route('**/api/data', (route) =>
    route.fulfill({ status: 500, body: 'Server Error' })
  );
  await page.goto('/data');
  await expect(page.getByText('Failed to load')).toBeVisible();
});

test('modify real response', async ({ page }) => {
  await page.route('**/api/user', async (route) => {
    const response = await route.fetch();
    const json = await response.json();
    json.name = 'Test User';
    await route.fulfill({ response, body: JSON.stringify(json) });
  });
  await page.goto('/profile');
});

test('block analytics', async ({ page }) => {
  await page.route('**/*analytics*', (route) => route.abort());
  await page.goto('/');
});
```

### Visual Testing

```typescript
test('visual comparison', async ({ page }) => {
  await page.goto('/dashboard');

  // Full page screenshot
  await expect(page).toHaveScreenshot('dashboard.png');

  // Element screenshot with tolerance
  await expect(page.locator('.chart')).toHaveScreenshot('chart.png', {
    maxDiffPixelRatio: 0.05,
  });

  // Mask dynamic content
  await expect(page).toHaveScreenshot('stable.png', {
    mask: [page.locator('.timestamp')],
  });
});
```

### Authentication State Reuse

```typescript
// auth.setup.ts — runs once, saves session
import { test as setup } from '@playwright/test';
const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.waitForURL('/dashboard');
  await page.context().storageState({ path: authFile });
});
```

```typescript
// playwright.config.ts — reuse auth state
projects: [
  { name: 'setup', testMatch: /.*\.setup\.ts/ },
  {
    name: 'chromium',
    dependencies: ['setup'],
    use: { storageState: 'playwright/.auth/user.json' },
  },
]
```

### Custom Fixtures (Page Object Model)

```typescript
import { test as base } from '@playwright/test';

class LoginPage {
  constructor(private page: Page) {}
  async login(email: string, password: string) {
    await this.page.getByLabel('Email').fill(email);
    await this.page.getByLabel('Password').fill(password);
    await this.page.getByRole('button', { name: 'Sign in' }).click();
  }
}

const test = base.extend<{ loginPage: LoginPage }>({
  loginPage: async ({ page }, use) => {
    await page.goto('/login');
    await use(new LoginPage(page));
  },
});

test('login via fixture', async ({ loginPage, page }) => {
  await loginPage.login('user@example.com', 'secret');
  await expect(page).toHaveURL('/dashboard');
});
```

### Waiting for Network

```typescript
test('wait for API response after click', async ({ page }) => {
  await page.goto('/dashboard');
  const responsePromise = page.waitForResponse('**/api/data');
  await page.getByRole('button', { name: 'Refresh' }).click();
  const response = await responsePromise;
  expect(response.status()).toBe(200);
});
```

## Edge Cases and Gotchas

### Flaky Tests

- Never use `page.waitForTimeout()` (a sleep) — use auto-waiting assertions instead.
- If a test is flaky, check for race conditions: ensure you await the correct response or UI state before asserting.
- Use `expect(locator).toBeVisible()` instead of checking element existence — visibility implies the element is rendered and actionable.
- Set `retries: 2` in CI config as a safety net, but always investigate the root cause.

### Authentication State

- Always add `playwright/.auth/` to `.gitignore` — it contains session tokens.
- If auth tokens expire during test runs, shorten the token lifetime check or re-authenticate in a global setup with a long-lived token.
- For multiple user roles, create separate setup files (`admin.setup.ts`, `user.setup.ts`) and separate projects with their own `storageState` paths.

### CI Browser Install

- Always run `npx playwright install --with-deps` in CI — the `--with-deps` flag installs OS-level dependencies (fonts, libraries) required by browsers.
- Cache `~/.cache/ms-playwright` between CI runs to speed up browser installation.
- Set `PLAYWRIGHT_BROWSERS_PATH` to control where browsers are stored.
- Use `workers: 1` in CI for consistent results on resource-constrained runners.

### Debugging

- Use `PWDEBUG=1 npx playwright test` to step through tests in the inspector.
- Set `trace: 'on'` temporarily to capture traces for all tests, not just retries.
- Use `page.pause()` inside a test to stop execution and open the inspector at that point.
- Check the trace viewer timeline to see exactly where a test diverges from expectations.

### Timeouts

- Default action timeout: 30 seconds. Override with `actionTimeout` in config.
- Default assertion timeout: 5 seconds. Override with `expect: { timeout: 10000 }`.
- Default test timeout: 30 seconds. Override with `timeout` in config or `test.setTimeout()` per test.
- Navigation timeout: 30 seconds. Override with `navigationTimeout` in config.

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `CI` | Auto-detected in CI; controls `forbidOnly`, `retries`, `workers` |
| `PLAYWRIGHT_BROWSERS_PATH` | Custom browser binary location (for caching) |
| `PWDEBUG` | Set to `1` for step-through debugging |
| `PLAYWRIGHT_TEST_BASE_URL` | Override `baseURL` without editing config |
| `PLAYWRIGHT_HTML_OPEN` | Set to `never` in CI to suppress report opening |
