#!/usr/bin/env bash
set -euo pipefail

# Creates a middleware.ts with auth guard and matcher config
# Usage: PROTECTED_PATHS=/dashboard,/settings AUTH_COOKIE=session LOGIN_PATH=/login ./create-middleware.sh

PROTECTED_PATHS="${PROTECTED_PATHS:-/dashboard}"
AUTH_COOKIE="${AUTH_COOKIE:-session}"
LOGIN_PATH="${LOGIN_PATH:-/login}"
PROJECT_DIR="${PROJECT_DIR:-.}"

# Determine target location
TARGET_FILE=""
if [ -d "$PROJECT_DIR/src" ]; then
  TARGET_FILE="$PROJECT_DIR/src/middleware.ts"
else
  TARGET_FILE="$PROJECT_DIR/middleware.ts"
fi

if [ -f "$TARGET_FILE" ]; then
  echo "middleware.ts already exists at $TARGET_FILE" >&2
  echo "Remove it first or edit manually." >&2
  exit 1
fi

# Build matcher array from protected paths
IFS=',' read -ra PATHS <<< "$PROTECTED_PATHS"
MATCHER_ENTRIES=""
for path in "${PATHS[@]}"; do
  path=$(echo "$path" | xargs)  # trim whitespace
  MATCHER_ENTRIES="$MATCHER_ENTRIES    '${path}/:path*',\n"
done

cat > "$TARGET_FILE" << EOF
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('${AUTH_COOKIE}')?.value

  if (!token) {
    const loginUrl = new URL('${LOGIN_PATH}', request.url)
    loginUrl.searchParams.set('callbackUrl', request.nextUrl.pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Add security headers
  const response = NextResponse.next()
  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-Content-Type-Options', 'nosniff')

  return response
}

export const config = {
  matcher: [
$(printf "$MATCHER_ENTRIES")  ],
}
EOF

echo "Created: $TARGET_FILE"
echo "Protected paths: $PROTECTED_PATHS"
echo "Auth cookie: $AUTH_COOKIE"
echo "Login redirect: $LOGIN_PATH"
