#!/usr/bin/env bash
set -euo pipefail

# Creates a new Pages Router page with optional data fetching
# Usage: PAGE_NAME=about FETCH_METHOD=static PROJECT_DIR=. ./create-page.sh

PAGE_NAME="${PAGE_NAME:?PAGE_NAME is required (e.g., 'about' or 'blog/[slug]')}"
FETCH_METHOD="${FETCH_METHOD:-none}"
PROJECT_DIR="${PROJECT_DIR:-.}"

# Determine pages directory
PAGES_DIR=""
if [ -d "$PROJECT_DIR/src/pages" ]; then
  PAGES_DIR="$PROJECT_DIR/src/pages"
elif [ -d "$PROJECT_DIR/pages" ]; then
  PAGES_DIR="$PROJECT_DIR/pages"
else
  echo "Error: No pages/ directory found in $PROJECT_DIR" >&2
  exit 1
fi

# Create parent directories if needed
TARGET_FILE="$PAGES_DIR/$PAGE_NAME.tsx"
mkdir -p "$(dirname "$TARGET_FILE")"

if [ -f "$TARGET_FILE" ]; then
  echo "File already exists: $TARGET_FILE" >&2
  exit 1
fi

# Derive component name
COMPONENT_NAME=$(basename "$PAGE_NAME" | sed 's/\[.*\]//g; s/[^a-zA-Z]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' | tr -d ' ')
[ -z "$COMPONENT_NAME" ] && COMPONENT_NAME="Dynamic"
COMPONENT_NAME="${COMPONENT_NAME}Page"

IS_DYNAMIC=false
echo "$PAGE_NAME" | grep -q '\[' && IS_DYNAMIC=true

case "$FETCH_METHOD" in
  static)
    if [ "$IS_DYNAMIC" = true ]; then
      cat > "$TARGET_FILE" << EOF
import type { GetStaticPaths, GetStaticProps, InferGetStaticPropsType } from 'next'

export const getStaticPaths: GetStaticPaths = async () => {
  // TODO: Fetch all valid params
  return {
    paths: [],
    fallback: 'blocking',
  }
}

export const getStaticProps: GetStaticProps = async ({ params }) => {
  // TODO: Fetch data for this page
  return {
    props: { data: {} },
    revalidate: 60,
  }
}

export default function $COMPONENT_NAME({
  data,
}: InferGetStaticPropsType<typeof getStaticProps>) {
  return (
    <div>
      <h1>$COMPONENT_NAME</h1>
    </div>
  )
}
EOF
    else
      cat > "$TARGET_FILE" << EOF
import type { GetStaticProps, InferGetStaticPropsType } from 'next'

export const getStaticProps: GetStaticProps = async () => {
  // TODO: Fetch data for this page
  return {
    props: { data: {} },
    revalidate: 60,
  }
}

export default function $COMPONENT_NAME({
  data,
}: InferGetStaticPropsType<typeof getStaticProps>) {
  return (
    <div>
      <h1>$COMPONENT_NAME</h1>
    </div>
  )
}
EOF
    fi
    ;;
  server)
    cat > "$TARGET_FILE" << EOF
import type { GetServerSideProps, InferGetServerSidePropsType } from 'next'

export const getServerSideProps: GetServerSideProps = async (context) => {
  const { req, res, params, query } = context

  // TODO: Fetch data for this page
  return {
    props: { data: {} },
  }
}

export default function $COMPONENT_NAME({
  data,
}: InferGetServerSidePropsType<typeof getServerSideProps>) {
  return (
    <div>
      <h1>$COMPONENT_NAME</h1>
    </div>
  )
}
EOF
    ;;
  none|*)
    cat > "$TARGET_FILE" << EOF
export default function $COMPONENT_NAME() {
  return (
    <div>
      <h1>$COMPONENT_NAME</h1>
    </div>
  )
}
EOF
    ;;
esac

echo "Created: $TARGET_FILE"
echo "Route: /${PAGE_NAME/\[*\]/:param}"
