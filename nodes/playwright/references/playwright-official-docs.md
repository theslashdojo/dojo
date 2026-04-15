# Playwright Official Documentation Map

Use these official docs when refreshing this ecosystem.

- Installation and getting started: https://playwright.dev/docs/intro
- Playwright Library mode: https://playwright.dev/docs/library
- Browser binaries and install behavior: https://playwright.dev/docs/browsers
- Coding-agent CLI: https://playwright.dev/docs/getting-started-cli
- Locators: https://playwright.dev/docs/locators
- Auto-waiting and actionability: https://playwright.dev/docs/actionability
- Authentication and storage state: https://playwright.dev/docs/auth
- Network interception: https://playwright.dev/docs/network
- Mock APIs: https://playwright.dev/docs/mock
- Screenshots: https://playwright.dev/docs/screenshots
- Downloads: https://playwright.dev/docs/downloads
- API testing: https://playwright.dev/docs/api-testing
- Trace viewer: https://playwright.dev/docs/trace-viewer-intro
- Continuous integration: https://playwright.dev/docs/ci
- Playwright API reference: https://playwright.dev/docs/api/class-playwright

## Notes For Agents

- Prefer `@playwright/test` for application test suites and `playwright` for standalone scripts.
- Playwright browser binaries are separate from npm package installation. Install them explicitly with `npx playwright install`.
- `--with-deps` installs Linux system dependencies and is the safest CI/default install path.
- The coding-agent CLI exposes stable element refs from page snapshots; use it for iterative browser control when a live page must be manipulated across turns.
- Storage state files are secrets if they contain authenticated cookies or localStorage tokens.
- Use official docs before relying on a Stack Overflow answer; Playwright changes quickly and the docs track current CLI and API behavior.
