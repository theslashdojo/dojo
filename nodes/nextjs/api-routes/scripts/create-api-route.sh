#!/usr/bin/env bash
set -euo pipefail

# Creates a new API route (App Router Route Handler or Pages Router API Route)
# Usage: ROUTE_PATH=posts/[id] METHODS=GET,POST,DELETE ROUTER=app ./create-api-route.sh

ROUTE_PATH="${ROUTE_PATH:?ROUTE_PATH is required (e.g., 'posts' or 'posts/[id]')}"
METHODS="${METHODS:-GET,POST}"
ROUTER="${ROUTER:-app}"
PROJECT_DIR="${PROJECT_DIR:-.}"

IFS=',' read -ra METHOD_ARRAY <<< "$METHODS"

if [ "$ROUTER" = "app" ]; then
  # App Router: Route Handlers
  APP_DIR=""
  if [ -d "$PROJECT_DIR/src/app" ]; then
    APP_DIR="$PROJECT_DIR/src/app"
  elif [ -d "$PROJECT_DIR/app" ]; then
    APP_DIR="$PROJECT_DIR/app"
  else
    echo "Error: No app/ directory found" >&2
    exit 1
  fi

  TARGET_DIR="$APP_DIR/api/$ROUTE_PATH"
  mkdir -p "$TARGET_DIR"
  TARGET_FILE="$TARGET_DIR/route.ts"

  if [ -f "$TARGET_FILE" ]; then
    echo "File already exists: $TARGET_FILE" >&2
    exit 1
  fi

  # Check if route has dynamic segments
  HAS_PARAMS=false
  echo "$ROUTE_PATH" | grep -q '\[' && HAS_PARAMS=true

  {
    echo "import { NextRequest, NextResponse } from 'next/server'"
    echo ""

    for METHOD in "${METHOD_ARRAY[@]}"; do
      METHOD=$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')

      if [ "$HAS_PARAMS" = true ]; then
        cat << HANDLER

export async function $METHOD(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params

  // TODO: Implement $METHOD handler
  return NextResponse.json({ method: '$METHOD', id })
}
HANDLER
      else
        cat << HANDLER

export async function $METHOD(request: NextRequest) {
  // TODO: Implement $METHOD handler
  return NextResponse.json({ method: '$METHOD' })
}
HANDLER
      fi
    done
  } > "$TARGET_FILE"

  echo "Created Route Handler: $TARGET_FILE"
  echo "Endpoint: /api/$ROUTE_PATH"
  echo "Methods: ${METHODS}"

else
  # Pages Router: API Routes
  PAGES_DIR=""
  if [ -d "$PROJECT_DIR/src/pages" ]; then
    PAGES_DIR="$PROJECT_DIR/src/pages"
  elif [ -d "$PROJECT_DIR/pages" ]; then
    PAGES_DIR="$PROJECT_DIR/pages"
  else
    echo "Error: No pages/ directory found" >&2
    exit 1
  fi

  TARGET_FILE="$PAGES_DIR/api/$ROUTE_PATH.ts"
  mkdir -p "$(dirname "$TARGET_FILE")"

  if [ -f "$TARGET_FILE" ]; then
    echo "File already exists: $TARGET_FILE" >&2
    exit 1
  fi

  ALLOWED=$(printf '%s' "${METHOD_ARRAY[*]}" | tr ' ' ', ')

  cat > "$TARGET_FILE" << EOF
import type { NextApiRequest, NextApiResponse } from 'next'

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  switch (req.method) {
$(for METHOD in "${METHOD_ARRAY[@]}"; do
    METHOD=$(echo "$METHOD" | tr '[:lower:]' '[:upper:]')
    echo "    case '$METHOD':"
    echo "      // TODO: Implement $METHOD handler"
    echo "      return res.status(200).json({ method: '$METHOD' })"
done)
    default:
      res.setHeader('Allow', ['$ALLOWED'])
      return res.status(405).end(\`Method \${req.method} Not Allowed\`)
  }
}
EOF

  echo "Created API Route: $TARGET_FILE"
  echo "Endpoint: /api/$ROUTE_PATH"
  echo "Methods: ${METHODS}"
fi
