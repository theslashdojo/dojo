#!/usr/bin/env bash
set -euo pipefail

# Creates a new App Router route with optional layout, loading, and error files
# Usage: ROUTE_PATH=blog/[slug] PROJECT_DIR=. ./create-route.sh

ROUTE_PATH="${ROUTE_PATH:?ROUTE_PATH is required (e.g., 'blog/[slug]')}"
PROJECT_DIR="${PROJECT_DIR:-.}"

# Determine app directory
APP_DIR=""
if [ -d "$PROJECT_DIR/src/app" ]; then
  APP_DIR="$PROJECT_DIR/src/app"
elif [ -d "$PROJECT_DIR/app" ]; then
  APP_DIR="$PROJECT_DIR/app"
else
  echo "Error: No app/ directory found in $PROJECT_DIR" >&2
  exit 1
fi

TARGET_DIR="$APP_DIR/$ROUTE_PATH"
mkdir -p "$TARGET_DIR"

CREATED_FILES=()

# Create page.tsx
if [ ! -f "$TARGET_DIR/page.tsx" ]; then
  # Derive a component name from the route
  COMPONENT_NAME=$(echo "$ROUTE_PATH" | sed 's/\[.*\]//g; s/[^a-zA-Z]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' | tr -d ' ')
  [ -z "$COMPONENT_NAME" ] && COMPONENT_NAME="Route"
  COMPONENT_NAME="${COMPONENT_NAME}Page"

  # Check if route has dynamic segments
  if echo "$ROUTE_PATH" | grep -q '\['; then
    cat > "$TARGET_DIR/page.tsx" << 'PAGEOF'
export default async function COMPONENT_NAME({
  params,
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params

  return (
    <div>
      <h1>COMPONENT_NAME</h1>
      <p>Slug: {slug}</p>
    </div>
  )
}
PAGEOF
    sed -i "s/COMPONENT_NAME/$COMPONENT_NAME/g" "$TARGET_DIR/page.tsx"
  else
    cat > "$TARGET_DIR/page.tsx" << PAGEOF
export default function $COMPONENT_NAME() {
  return (
    <div>
      <h1>$COMPONENT_NAME</h1>
    </div>
  )
}
PAGEOF
  fi
  CREATED_FILES+=("$TARGET_DIR/page.tsx")
fi

# Create layout.tsx if WITH_LAYOUT is set
if [ "${WITH_LAYOUT:-false}" = "true" ] && [ ! -f "$TARGET_DIR/layout.tsx" ]; then
  cat > "$TARGET_DIR/layout.tsx" << 'EOF'
export default function Layout({
  children,
}: {
  children: React.ReactNode
}) {
  return <section>{children}</section>
}
EOF
  CREATED_FILES+=("$TARGET_DIR/layout.tsx")
fi

# Create loading.tsx if WITH_LOADING is set
if [ "${WITH_LOADING:-false}" = "true" ] && [ ! -f "$TARGET_DIR/loading.tsx" ]; then
  cat > "$TARGET_DIR/loading.tsx" << 'EOF'
export default function Loading() {
  return <div>Loading...</div>
}
EOF
  CREATED_FILES+=("$TARGET_DIR/loading.tsx")
fi

# Create error.tsx if WITH_ERROR is set
if [ "${WITH_ERROR:-false}" = "true" ] && [ ! -f "$TARGET_DIR/error.tsx" ]; then
  cat > "$TARGET_DIR/error.tsx" << 'EOF'
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={() => reset()}>Try again</button>
    </div>
  )
}
EOF
  CREATED_FILES+=("$TARGET_DIR/error.tsx")
fi

echo "Created files:"
for f in "${CREATED_FILES[@]}"; do
  echo "  $f"
done
