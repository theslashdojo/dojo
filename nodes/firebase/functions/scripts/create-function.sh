#!/usr/bin/env bash
# Create a Firebase Cloud Function with v2 API boilerplate for the specified trigger type.
# Usage: ./create-function.sh --name <name> --trigger <type> [--region <region>] [--runtime <runtime>]
#   or:  FUNCTION_NAME=myFunc TRIGGER=http ./create-function.sh
set -euo pipefail

# ─── Parse arguments ────────────────────────────────────────────────────────────

FUNCTION_NAME="${FUNCTION_NAME:-}"
TRIGGER="${TRIGGER:-http}"
REGION="${REGION:-us-central1}"
RUNTIME="${RUNTIME:-nodejs20}"
DEPLOY="${DEPLOY:-false}"
FUNCTIONS_DIR="${FUNCTIONS_DIR:-functions}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       FUNCTION_NAME="$2"; shift 2 ;;
    --trigger)    TRIGGER="$2";       shift 2 ;;
    --region)     REGION="$2";        shift 2 ;;
    --runtime)    RUNTIME="$2";       shift 2 ;;
    --deploy)     DEPLOY="true";      shift   ;;
    --dir)        FUNCTIONS_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: create-function.sh --name <name> --trigger <type> [options]"
      echo ""
      echo "Options:"
      echo "  --name <name>       Function name (required, camelCase recommended)"
      echo "  --trigger <type>    Trigger type: http|callable|firestore|auth|storage|schedule"
      echo "  --region <region>   Deployment region (default: us-central1)"
      echo "  --runtime <rt>      Runtime: nodejs20|python312 (default: nodejs20)"
      echo "  --deploy            Deploy immediately after creation"
      echo "  --dir <path>        Functions directory (default: functions)"
      echo ""
      echo "Environment variables: FUNCTION_NAME, TRIGGER, REGION, RUNTIME, DEPLOY, FUNCTIONS_DIR"
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FUNCTION_NAME" ]]; then
  echo "ERROR: --name is required." >&2
  echo "Usage: create-function.sh --name <name> --trigger <type>" >&2
  exit 1
fi

# Validate trigger type
case "$TRIGGER" in
  http|callable|firestore|auth|storage|schedule) ;;
  *)
    echo "ERROR: Invalid trigger type '$TRIGGER'. Use: http, callable, firestore, auth, storage, schedule" >&2
    exit 1
    ;;
esac

# Validate runtime
case "$RUNTIME" in
  nodejs20|python312) ;;
  *)
    echo "ERROR: Unsupported runtime '$RUNTIME'. Use: nodejs20, python312" >&2
    exit 1
    ;;
esac

# ─── Verify prerequisites ───────────────────────────────────────────────────────

if ! command -v firebase &>/dev/null; then
  echo "ERROR: firebase CLI is not installed. Run: npm install -g firebase-tools" >&2
  exit 1
fi

# ─── Ensure functions directory exists ───────────────────────────────────────────

if [[ ! -d "$FUNCTIONS_DIR" ]]; then
  echo "Functions directory '$FUNCTIONS_DIR' not found."
  echo "Run 'firebase init functions' first to create it."
  exit 1
fi

SRC_DIR="${FUNCTIONS_DIR}/src"
mkdir -p "$SRC_DIR"

# ─── Python runtime ─────────────────────────────────────────────────────────────

if [[ "$RUNTIME" == "python312" ]]; then
  FUNC_FILE="${FUNCTIONS_DIR}/main.py"

  # Ensure requirements.txt has firebase-functions
  REQ_FILE="${FUNCTIONS_DIR}/requirements.txt"
  if [[ ! -f "$REQ_FILE" ]]; then
    echo "firebase-functions>=0.1.0" > "$REQ_FILE"
    echo "firebase-admin>=6.0.0" >> "$REQ_FILE"
    echo "Created $REQ_FILE"
  fi

  case "$TRIGGER" in
    http)
      cat >> "$FUNC_FILE" << PYEOF

# --- ${FUNCTION_NAME} (HTTP) ---
from firebase_functions import https_fn

@https_fn.on_request(region="${REGION}")
def ${FUNCTION_NAME}(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function."""
    name = req.args.get("name", "World")
    return https_fn.Response(f"Hello, {name}!")
PYEOF
      ;;
    firestore)
      cat >> "$FUNC_FILE" << PYEOF

# --- ${FUNCTION_NAME} (Firestore trigger) ---
from firebase_functions.firestore_fn import (
    on_document_created,
    Event,
    DocumentSnapshot,
)

@on_document_created(document="collection/{docId}", region="${REGION}")
def ${FUNCTION_NAME}(event: Event[DocumentSnapshot]) -> None:
    """Triggered when a document is created."""
    data = event.data.to_dict()
    doc_id = event.params["docId"]
    print(f"Document created {doc_id}: {data}")
PYEOF
      ;;
    auth)
      cat >> "$FUNC_FILE" << PYEOF

# --- ${FUNCTION_NAME} (Auth trigger) ---
from firebase_functions.identity_fn import (
    before_user_created,
    AuthBlockingEvent,
)
from firebase_functions import identity_fn

@identity_fn.on_user_created(region="${REGION}")
def ${FUNCTION_NAME}(event: identity_fn.AuthEvent) -> None:
    """Triggered when a new user is created."""
    print(f"New user: {event.data.uid}, email: {event.data.email}")
PYEOF
      ;;
    *)
      echo "ERROR: Python runtime currently supports http, firestore, and auth triggers." >&2
      echo "Use nodejs20 runtime for callable, storage, and schedule triggers." >&2
      exit 1
      ;;
  esac

  echo "Appended Python function '${FUNCTION_NAME}' to ${FUNC_FILE}"

  if [[ "$DEPLOY" == "true" ]]; then
    echo "Deploying function ${FUNCTION_NAME}..."
    firebase deploy --only "functions:${FUNCTION_NAME}"
  fi
  exit 0
fi

# ─── TypeScript runtime (nodejs20) ──────────────────────────────────────────────

INDEX_FILE="${SRC_DIR}/index.ts"

# Create index.ts if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
  cat > "$INDEX_FILE" << 'TSEOF'
// Cloud Functions for Firebase — v2 API
// Each exported function is deployed as a separate Cloud Function.
// Deploy with: firebase deploy --only functions
TSEOF
  echo "Created $INDEX_FILE"
fi

# Ensure package.json has firebase-functions
PKG_FILE="${FUNCTIONS_DIR}/package.json"
if [[ ! -f "$PKG_FILE" ]]; then
  cat > "$PKG_FILE" << PKGEOF
{
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "firebase-functions-test": "^3.0.0"
  },
  "private": true
}
PKGEOF
  echo "Created $PKG_FILE"
fi

# Ensure tsconfig.json exists
TSCONFIG_FILE="${FUNCTIONS_DIR}/tsconfig.json"
if [[ ! -f "$TSCONFIG_FILE" ]]; then
  cat > "$TSCONFIG_FILE" << 'TSCEOF'
{
  "compilerOptions": {
    "module": "commonjs",
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "outDir": "lib",
    "sourceMap": true,
    "strict": true,
    "target": "es2022",
    "esModuleInterop": true
  },
  "compileOnSave": true,
  "include": ["src"]
}
TSCEOF
  echo "Created $TSCONFIG_FILE"
fi

# ─── Generate function boilerplate ──────────────────────────────────────────────

echo "" >> "$INDEX_FILE"

case "$TRIGGER" in
  http)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (HTTP) ---
import { onRequest } from "firebase-functions/v2/https";

export const ${FUNCTION_NAME} = onRequest(
  { region: "${REGION}", cors: true },
  (req, res) => {
    const name = req.query.name || "World";
    res.json({ message: \`Hello, \${name}!\` });
  }
);
TSEOF
    echo "Generated HTTP function '${FUNCTION_NAME}'"
    ;;

  callable)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (Callable) ---
import { onCall, HttpsError } from "firebase-functions/v2/https";

export const ${FUNCTION_NAME} = onCall(
  { region: "${REGION}" },
  (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const uid = request.auth.uid;
    const data = request.data;

    // Your logic here
    return { result: \`Processed by \${uid}\`, data };
  }
);
TSEOF
    echo "Generated callable function '${FUNCTION_NAME}'"
    ;;

  firestore)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (Firestore trigger) ---
import { onDocumentCreated } from "firebase-functions/v2/firestore";

export const ${FUNCTION_NAME} = onDocumentCreated(
  { document: "collection/{docId}", region: "${REGION}" },
  (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data in event");
      return;
    }

    const data = snapshot.data();
    const docId = event.params.docId;
    console.log(\`Document created \${docId}:\`, data);

    // Your logic here — send notification, update aggregates, etc.
    return snapshot.ref.update({ processedAt: new Date().toISOString() });
  }
);
TSEOF
    echo "Generated Firestore trigger function '${FUNCTION_NAME}'"
    echo "NOTE: Update the document path 'collection/{docId}' to match your collection."
    ;;

  auth)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (Auth trigger) ---
import { onAuthUserCreated } from "firebase-functions/v2/identity";

export const ${FUNCTION_NAME} = onAuthUserCreated(
  { region: "${REGION}" },
  (event) => {
    const user = event.data;
    console.log(\`New user signed up: \${user.uid}, email: \${user.email}\`);

    // Your logic here — create profile doc, send welcome email, etc.
  }
);
TSEOF
    echo "Generated Auth trigger function '${FUNCTION_NAME}'"
    ;;

  storage)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (Storage trigger) ---
import { onObjectFinalized } from "firebase-functions/v2/storage";

export const ${FUNCTION_NAME} = onObjectFinalized(
  { region: "${REGION}" },
  (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;
    const fileSize = event.data.size;
    const bucket = event.data.bucket;

    console.log(\`File uploaded: gs://\${bucket}/\${filePath}\`);
    console.log(\`Type: \${contentType}, Size: \${fileSize} bytes\`);

    if (!contentType?.startsWith("image/")) {
      console.log("Not an image, skipping processing.");
      return;
    }

    // Your logic here — generate thumbnail, extract metadata, etc.
  }
);
TSEOF
    echo "Generated Storage trigger function '${FUNCTION_NAME}'"
    ;;

  schedule)
    cat >> "$INDEX_FILE" << TSEOF

// --- ${FUNCTION_NAME} (Scheduled) ---
import { onSchedule } from "firebase-functions/v2/scheduler";

export const ${FUNCTION_NAME} = onSchedule(
  { schedule: "every 5 minutes", region: "${REGION}", timeoutSeconds: 300 },
  async (event) => {
    console.log("Scheduled function running at:", new Date().toISOString());

    // Your logic here — cleanup, sync, report generation, etc.
  }
);
TSEOF
    echo "Generated scheduled function '${FUNCTION_NAME}'"
    echo "NOTE: Update the schedule expression as needed (e.g., 'every day 02:00', '0 9 * * 1')."
    ;;
esac

echo ""
echo "Function added to: ${INDEX_FILE}"
echo ""
echo "Next steps:"
echo "  cd ${FUNCTIONS_DIR} && npm install    # Install dependencies"
echo "  npm run build                          # Compile TypeScript"
echo "  firebase emulators:start --only functions   # Test locally"
echo "  firebase deploy --only functions:${FUNCTION_NAME}  # Deploy"

# ─── Deploy if requested ────────────────────────────────────────────────────────

if [[ "$DEPLOY" == "true" ]]; then
  echo ""
  echo "Building and deploying ${FUNCTION_NAME}..."
  cd "$FUNCTIONS_DIR" && npm install && npm run build && cd ..
  firebase deploy --only "functions:${FUNCTION_NAME}"
fi
