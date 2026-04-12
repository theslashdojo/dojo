/**
 * Sentry Error Capture Demo
 *
 * Demonstrates captureException, captureMessage, breadcrumbs,
 * user identification, tags, context, and scoped capture.
 *
 * Required env: SENTRY_DSN
 *
 * Usage:
 *   SENTRY_DSN=https://...@sentry.io/... npx tsx capture-errors.ts
 */

import * as Sentry from "@sentry/node";

// --- Initialize Sentry ---
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: "capture-demo@1.0.0",
  environment: "development",
  tracesSampleRate: 1.0,
  debug: true,
});

// --- Set global user context ---
Sentry.setUser({
  id: "user-42",
  email: "demo@example.com",
  username: "demo-user",
});

// --- Set global tags ---
Sentry.setTag("demo", "capture-errors");
Sentry.setTag("node_version", process.version);

// --- Add a custom breadcrumb ---
Sentry.addBreadcrumb({
  category: "demo",
  message: "Starting capture demo",
  level: "info",
  data: { timestamp: new Date().toISOString() },
});

// --- captureMessage with severity ---
const messageId = Sentry.captureMessage(
  "Capture demo: informational message",
  "info"
);
console.log(`captureMessage event ID: ${messageId}`);

// --- captureException with inline enrichment ---
try {
  // Simulate an error
  JSON.parse("{ invalid json }");
} catch (err) {
  const errorId = Sentry.captureException(err, {
    tags: { operation: "json-parse", source: "demo" },
    extra: { input: "{ invalid json }" },
    level: "error",
  });
  console.log(`captureException event ID: ${errorId}`);
}

// --- Scoped capture with withScope ---
Sentry.withScope((scope) => {
  scope.setTag("scoped", "true");
  scope.setLevel("warning");
  scope.setContext("demo-context", {
    step: "withScope demo",
    purpose: "demonstrate scoped capture",
  });
  scope.setExtra("scoped_extra", "this only appears on this event");

  Sentry.captureMessage("Capture demo: scoped warning message");
});

// --- Simulate an async error ---
async function fetchData(url: string): Promise<string> {
  Sentry.addBreadcrumb({
    category: "http",
    message: `Fetching ${url}`,
    level: "info",
  });

  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    return await response.text();
  } catch (err) {
    Sentry.captureException(err, {
      tags: { url, operation: "fetch" },
    });
    throw err;
  }
}

// Run the async demo (intentionally fetching a bad URL)
fetchData("https://httpstat.us/500")
  .catch(() => console.log("Async error captured by Sentry"))
  .finally(async () => {
    // Flush events before exit
    await Sentry.close(5000);
    console.log("All events flushed. Check your Sentry dashboard.");
  });
