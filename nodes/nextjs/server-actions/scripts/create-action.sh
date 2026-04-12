#!/usr/bin/env bash
set -euo pipefail

# Creates a server action file with form handling and revalidation
# Usage: ACTION_NAME=createPost REVALIDATE_PATH=/blog PROJECT_DIR=. ./create-action.sh

ACTION_NAME="${ACTION_NAME:?ACTION_NAME is required (e.g., 'createPost')}"
REVALIDATE_PATH="${REVALIDATE_PATH:-}"
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

TARGET_FILE="$APP_DIR/actions.ts"

# If actions.ts exists, append to it; otherwise create it
if [ -f "$TARGET_FILE" ]; then
  # Check if 'use server' already present
  if ! head -1 "$TARGET_FILE" | grep -q "'use server'"; then
    echo "Warning: $TARGET_FILE exists but doesn't start with 'use server'" >&2
  fi

  # Append the new action
  {
    echo ""
    echo "export async function $ACTION_NAME(formData: FormData) {"
    echo "  // TODO: Validate inputs"
    echo "  const data = Object.fromEntries(formData)"
    echo ""
    echo "  // TODO: Perform mutation"
    echo "  // await db.model.create({ data })"
    if [ -n "$REVALIDATE_PATH" ]; then
      echo ""
      echo "  revalidatePath('$REVALIDATE_PATH')"
    fi
    echo "}"
  } >> "$TARGET_FILE"

  echo "Appended action '$ACTION_NAME' to $TARGET_FILE"
else
  # Create new actions file
  {
    echo "'use server'"
    echo ""
    echo "import { revalidatePath } from 'next/cache'"
    echo "import { redirect } from 'next/navigation'"
    echo ""
    echo "export async function $ACTION_NAME(formData: FormData) {"
    echo "  // TODO: Validate inputs"
    echo "  const data = Object.fromEntries(formData)"
    echo ""
    echo "  // TODO: Perform mutation"
    echo "  // await db.model.create({ data })"
    if [ -n "$REVALIDATE_PATH" ]; then
      echo ""
      echo "  revalidatePath('$REVALIDATE_PATH')"
    fi
    echo "}"
  } > "$TARGET_FILE"

  echo "Created: $TARGET_FILE"
fi

echo "Action: $ACTION_NAME"
[ -n "$REVALIDATE_PATH" ] && echo "Revalidates: $REVALIDATE_PATH"
