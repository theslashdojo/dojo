#!/usr/bin/env node
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { parseArgs } from 'node:util';

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    url: { type: 'string' },
    browser: { type: 'string', default: 'chromium' },
    headed: { type: 'boolean', default: false },
    'output-dir': { type: 'string', default: 'playwright-artifacts' },
    screenshot: { type: 'string' },
    html: { type: 'string' },
    text: { type: 'string' },
    selector: { type: 'string' },
    'wait-until': { type: 'string', default: 'load' },
    timeout: { type: 'string', default: '30000' },
    viewport: { type: 'string', default: '1280x720' },
    'storage-state': { type: 'string' },
    'user-agent': { type: 'string' },
    block: { type: 'string', multiple: true },
    'full-page': { type: 'boolean', default: true }
  }
});

const targetUrl = values.url || positionals[0];
if (!targetUrl) {
  console.error('Usage: browser-capture.mjs <url> [--browser chromium] [--screenshot out.png] [--html out.html] [--text out.txt]');
  process.exit(2);
}

let playwright;
try {
  playwright = await import('playwright');
} catch {
  console.error('The "playwright" package is required. Install it with: npm install -D playwright && npx playwright install');
  process.exit(1);
}

const browserType = playwright[values.browser];
if (!browserType) {
  console.error(`Unknown browser "${values.browser}". Use chromium, firefox, or webkit.`);
  process.exit(2);
}

const [widthRaw, heightRaw] = String(values.viewport).split('x');
const width = Number(widthRaw);
const height = Number(heightRaw);
if (!Number.isInteger(width) || !Number.isInteger(height)) {
  console.error(`Invalid viewport "${values.viewport}". Use WIDTHxHEIGHT, for example 1280x720.`);
  process.exit(2);
}

const outputDir = resolve(values['output-dir']);
await mkdir(outputDir, { recursive: true });

const safeName = new URL(targetUrl).hostname.replace(/[^a-zA-Z0-9.-]+/g, '_');
const screenshotPath = resolve(values.screenshot || `${outputDir}/${safeName}.png`);
const htmlPath = values.html ? resolve(values.html) : null;
const textPath = values.text ? resolve(values.text) : null;

const browser = await browserType.launch({ headless: !values.headed });
const context = await browser.newContext({
  viewport: { width, height },
  storageState: values['storage-state'],
  userAgent: values['user-agent']
});

for (const pattern of values.block || []) {
  await context.route(pattern, route => route.abort());
}

const page = await context.newPage();
const consoleMessages = [];
const responses = [];

page.on('console', msg => {
  consoleMessages.push({ type: msg.type(), text: msg.text() });
});

page.on('response', response => {
  const request = response.request();
  const type = request.resourceType();
  if (['document', 'xhr', 'fetch'].includes(type)) {
    responses.push({
      status: response.status(),
      method: request.method(),
      resourceType: type,
      url: response.url()
    });
  }
});

let navigationResponse;
try {
  navigationResponse = await page.goto(targetUrl, {
    waitUntil: values['wait-until'],
    timeout: Number(values.timeout)
  });
} catch (error) {
  await browser.close();
  console.error(`Navigation failed: ${error.message}`);
  process.exit(1);
}

if (values.selector) {
  await page.locator(values.selector).first().waitFor({ timeout: Number(values.timeout) });
  await page.locator(values.selector).first().screenshot({ path: screenshotPath });
} else {
  await page.screenshot({ path: screenshotPath, fullPage: values['full-page'] });
}

if (htmlPath) {
  await mkdir(dirname(htmlPath), { recursive: true });
  await writeFile(htmlPath, await page.content(), 'utf8');
}

let bodyText = '';
try {
  bodyText = await page.locator('body').innerText({ timeout: 5000 });
  if (textPath) {
    await mkdir(dirname(textPath), { recursive: true });
    await writeFile(textPath, bodyText, 'utf8');
  }
} catch {
  bodyText = '';
}

const links = await page.locator('a[href]').evaluateAll(anchors =>
  anchors.slice(0, 100).map(anchor => ({
    text: (anchor.textContent || '').trim().slice(0, 120),
    href: anchor.href
  }))
);

const summary = {
  requestedUrl: targetUrl,
  finalUrl: page.url(),
  title: await page.title(),
  status: navigationResponse ? navigationResponse.status() : null,
  screenshot: screenshotPath,
  html: htmlPath,
  text: textPath,
  viewport: { width, height },
  console: consoleMessages.slice(-50),
  responses: responses.slice(-100),
  links,
  textPreview: bodyText.replace(/\s+/g, ' ').trim().slice(0, 1000)
};

await browser.close();
console.log(JSON.stringify(summary, null, 2));
