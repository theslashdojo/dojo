---
name: playwright
description: Automate browsers with Playwright for web testing, research, screenshots, scraping, auth flows, network inspection, API checks, and coding-agent page control.
---

# Playwright

Use this skill when an agent needs to drive a real browser, inspect a web app, write or run end-to-end tests, capture screenshots, preserve login state, intercept network calls, download files, debug traces, or perform authenticated HTTP checks with Playwright.

## Choose The Surface

- `@playwright/test`: default for application tests. It provides fixtures, assertions, projects, retries, reports, tracing, screenshots, and CI integration.
- `playwright`: library mode for standalone automation scripts, scraping, screenshots, browser research, and custom workflows.
- `@playwright/cli`: coding-agent CLI that keeps browser sessions alive and exposes page snapshots with stable element refs.

## Install

```bash
# Existing test project
nodes/playwright/scripts/install-playwright.sh test chromium firefox webkit

# Standalone browser automation scripts
nodes/playwright/scripts/install-playwright.sh library chromium

# Coding-agent browser CLI
nodes/playwright/scripts/install-playwright.sh agent-cli
```

Equivalent manual commands:

```bash
npm init playwright@latest
npm install -D @playwright/test
npx playwright install --with-deps chromium firefox webkit

npm install -D playwright
npx playwright install chromium

npm install -g @playwright/cli@latest
```

Useful browser-install environment variables:

```bash
export HTTPS_PROXY=http://proxy.internal:8080
export PLAYWRIGHT_DOWNLOAD_HOST=https://artifacts.example.com/playwright
export PLAYWRIGHT_BROWSERS_PATH=.cache/ms-playwright
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
```

## Browser Automation

Use library mode when you need a deterministic script instead of a test runner:

```bash
nodes/playwright/scripts/browser-capture.mjs https://playwright.dev \
  --browser chromium \
  --screenshot artifacts/playwright.png \
  --html artifacts/playwright.html \
  --text artifacts/playwright.txt \
  --wait-until networkidle \
  --viewport 1440x900
```

Minimal script:

```javascript
import { chromium } from 'playwright';

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
const page = await context.newPage();
await page.goto('https://example.com', { waitUntil: 'load' });
await page.screenshot({ path: 'example.png', fullPage: true });
console.log(await page.title());
await browser.close();
```

Block noisy resources when researching pages:

```javascript
await context.route('**/*.{png,jpg,jpeg,gif,webp,svg}', route => route.abort());
await context.route('**/*analytics*', route => route.abort());
await page.goto('https://example.com');
```

## Tests

```typescript
import { test, expect } from '@playwright/test';

test('login opens dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill(process.env.E2E_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

Run tests through the wrapper:

```bash
nodes/playwright/scripts/run-tests.sh
PLAYWRIGHT_PROJECT=chromium nodes/playwright/scripts/run-tests.sh tests/login.spec.ts
PLAYWRIGHT_HEADED=1 PLAYWRIGHT_GREP=checkout nodes/playwright/scripts/run-tests.sh
PLAYWRIGHT_UPDATE_SNAPSHOTS=1 nodes/playwright/scripts/run-tests.sh
```

Recommended config:

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['html'], ['github']] : 'html',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } }
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI
  }
});
```

## Agent CLI

The Playwright CLI for coding agents returns page snapshots with element refs, reducing token-heavy HTML dumps.

```bash
nodes/playwright/scripts/playwright-agent-cli.sh open https://demo.playwright.dev/todomvc/ --headed
nodes/playwright/scripts/playwright-agent-cli.sh snapshot
nodes/playwright/scripts/playwright-agent-cli.sh click e15
nodes/playwright/scripts/playwright-agent-cli.sh fill e21 "Buy groceries"
nodes/playwright/scripts/playwright-agent-cli.sh press Enter
nodes/playwright/scripts/playwright-agent-cli.sh screenshot --filename=todo.png
```

Use named persistent sessions for long tasks:

```bash
PLAYWRIGHT_CLI_SESSION=research nodes/playwright/scripts/playwright-agent-cli.sh open https://example.com --persistent
PLAYWRIGHT_CLI_SESSION=research nodes/playwright/scripts/playwright-agent-cli.sh state-save .auth/research.json
PLAYWRIGHT_CLI_SESSION=research nodes/playwright/scripts/playwright-agent-cli.sh network
PLAYWRIGHT_CLI_SESSION=research nodes/playwright/scripts/playwright-agent-cli.sh close
```

## Locators

Prefer locators that match how users perceive the page:

```typescript
page.getByRole('button', { name: 'Submit' });
page.getByLabel('Email address');
page.getByPlaceholder('Search');
page.getByText('Welcome back');
page.getByTestId('cart-total');
page.locator('article').filter({ hasText: 'Playwright' }).getByRole('link');
```

Priority:

1. `getByRole` with accessible name.
2. `getByLabel` for inputs.
3. `getByText` and `getByPlaceholder`.
4. `getByTestId` as an explicit app contract.
5. CSS or XPath only when semantic locators are impossible.

Playwright actions and web-first assertions auto-wait. Do not add arbitrary sleeps unless debugging a race you can then replace with a locator, URL, response, or assertion wait.

## Authentication

Create authenticated state once and reuse it:

```typescript
// tests/auth.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.E2E_EMAIL!);
  await page.getByLabel('Password').fill(process.env.E2E_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/dashboard/);
  await page.context().storageState({ path: authFile });
});
```

```typescript
// playwright.config.ts
projects: [
  { name: 'setup', testMatch: /.*\.setup\.ts/ },
  {
    name: 'chromium',
    dependencies: ['setup'],
    use: { storageState: 'playwright/.auth/user.json' }
  }
]
```

Add `playwright/.auth/` to `.gitignore`; storage state can contain cookies and bearer tokens.

## Network

Inspect, wait for, modify, or block requests:

```typescript
await page.route('**/api/products', async route => {
  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify([{ id: 'p1', name: 'Widget' }])
  });
});

const responsePromise = page.waitForResponse('**/api/products');
await page.getByRole('button', { name: 'Refresh' }).click();
const response = await responsePromise;
expect(response.status()).toBe(200);
```

Modify an upstream response:

```typescript
await page.route('**/api/me', async route => {
  const response = await route.fetch();
  const json = await response.json();
  json.role = 'admin';
  await route.fulfill({ response, body: JSON.stringify(json) });
});
```

## Screenshots And Downloads

```typescript
await page.screenshot({ path: 'page.png', fullPage: true });
await page.locator('[data-testid=chart]').screenshot({ path: 'chart.png' });
await expect(page).toHaveScreenshot('dashboard.png', {
  fullPage: true,
  mask: [page.locator('[data-testid=clock]')]
});
```

Downloads are event-driven:

```typescript
const downloadPromise = page.waitForEvent('download');
await page.getByRole('button', { name: 'Export CSV' }).click();
const download = await downloadPromise;
await download.saveAs(`artifacts/${download.suggestedFilename()}`);
```

## API Testing

Use Playwright request contexts for authenticated API checks that share storage state with browser tests:

```bash
nodes/playwright/scripts/api-request.mjs https://api.example.com/v1/me \
  -H "Authorization: Bearer $API_TOKEN" \
  --fail \
  -o artifacts/me.json
```

```typescript
import { test, expect } from '@playwright/test';

test('health endpoint', async ({ request }) => {
  const response = await request.get('/api/health');
  expect(response.ok()).toBeTruthy();
  await expect(response).toBeOK();
});
```

## Traces And Debugging

Use traces before adding console logs:

```typescript
use: {
  trace: 'on-first-retry',
  screenshot: 'only-on-failure',
  video: 'retain-on-failure'
}
```

```bash
npx playwright test --trace on
nodes/playwright/scripts/open-trace.sh test-results/login/trace.zip
PWDEBUG=1 npx playwright test tests/login.spec.ts
npx playwright test --debug
npx playwright show-report
```

Trace viewer includes the action timeline, DOM snapshots, network activity, console messages, screenshots, and test source context.

## CI

```yaml
name: Playwright
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

## Edge Cases

- Missing browsers: run `npx playwright install --with-deps`; in CI, do it after package install.
- Corporate proxy: set `HTTPS_PROXY` before browser installation.
- Internal browser mirror: set `PLAYWRIGHT_DOWNLOAD_HOST`.
- Auth state committed by accident: rotate credentials and remove `playwright/.auth/*` from history.
- Flaky element interaction: prefer `getByRole` plus `expect(locator).toBeVisible()` or `toBeEnabled()` over `waitForTimeout`.
- Service workers hiding network mocks: disable them in context options when the app has aggressive service worker caching.
- Downloads in remote browsers: call `download.saveAs()` before the context closes.
- Visual diffs: mask dynamic regions, fix viewport and locale, and update snapshots intentionally.

For deeper examples and official links, see `references/playwright-official-docs.md`.
