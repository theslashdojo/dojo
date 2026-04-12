#!/usr/bin/env bash
# Setup Sentry SDK for a target platform
# Installs the correct package and creates an initialization file
#
# Required env:
#   SENTRY_DSN       — Sentry project DSN
# Optional env:
#   SENTRY_PLATFORM  — browser|node|react|nextjs (default: node)
#   SENTRY_RELEASE   — Release version identifier

set -euo pipefail

PLATFORM="${SENTRY_PLATFORM:-node}"
DSN="${SENTRY_DSN:?SENTRY_DSN is required — find it in Sentry Settings → Client Keys}"
RELEASE="${SENTRY_RELEASE:-}"

echo "=== Sentry Setup ==="
echo "Platform: ${PLATFORM}"
echo "DSN: ${DSN:0:30}..."

case "$PLATFORM" in
  browser)
    echo "Installing @sentry/browser..."
    npm install @sentry/browser --save

    INSTRUMENT_FILE="src/instrument.js"
    mkdir -p "$(dirname "$INSTRUMENT_FILE")"
    cat > "$INSTRUMENT_FILE" << 'JSEOF'
import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: process.env.SENTRY_RELEASE,
  environment: process.env.SENTRY_ENVIRONMENT || "production",
  tracesSampleRate: 0.2,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
});
JSEOF
    echo "Created ${INSTRUMENT_FILE}"
    echo "Add 'import \"./instrument\";' as the FIRST import in your entry point."
    ;;

  node)
    echo "Installing @sentry/node..."
    npm install @sentry/node --save

    INSTRUMENT_FILE="instrument.js"
    cat > "$INSTRUMENT_FILE" << 'JSEOF'
const Sentry = require("@sentry/node");

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  release: process.env.SENTRY_RELEASE,
  environment: process.env.SENTRY_ENVIRONMENT || "production",
  tracesSampleRate: 0.2,
  sendDefaultPii: true,
});
JSEOF
    echo "Created ${INSTRUMENT_FILE}"
    echo "Add 'require(\"./instrument\");' as the FIRST line in your entry point."
    echo "For ESM: node --import ./instrument.mjs app.mjs"
    ;;

  react)
    echo "Installing @sentry/react..."
    npm install @sentry/react --save

    INSTRUMENT_FILE="src/instrument.js"
    mkdir -p "$(dirname "$INSTRUMENT_FILE")"
    cat > "$INSTRUMENT_FILE" << 'JSEOF'
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: process.env.REACT_APP_SENTRY_DSN,
  release: process.env.REACT_APP_SENTRY_RELEASE,
  environment: process.env.NODE_ENV,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  tracesSampleRate: 0.2,
  replaysOnErrorSampleRate: 1.0,
});
JSEOF
    echo "Created ${INSTRUMENT_FILE}"
    echo "Add 'import \"./instrument\";' as the FIRST import in src/index.js"
    echo "Wrap your app: <Sentry.ErrorBoundary fallback={<p>Error</p>}><App /></Sentry.ErrorBoundary>"
    ;;

  nextjs)
    echo "Running Sentry Next.js wizard (interactive)..."
    echo "This will create sentry.client.config.ts, sentry.server.config.ts,"
    echo "sentry.edge.config.ts, and update next.config.js"
    npx @sentry/wizard@latest -i nextjs
    ;;

  *)
    echo "ERROR: Unknown platform '${PLATFORM}'"
    echo "Supported: browser, node, react, nextjs"
    exit 1
    ;;
esac

echo ""
echo "=== Verification ==="
echo "Add this to any file after initialization to test:"
echo "  Sentry.captureException(new Error('Sentry test — delete me'));"
echo "Then check your Sentry dashboard at https://sentry.io"
