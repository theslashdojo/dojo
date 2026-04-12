#!/bin/bash
set -e

PROJECT_NAME="${PROJECT_NAME:-my-project}"
DEPS="${DEPENDENCIES:-}"

echo "Creating project: $PROJECT_NAME"
uv init "$PROJECT_NAME"
cd "$PROJECT_NAME"

if [ -n "$DEPS" ]; then
  echo "Adding dependencies: $DEPS"
  IFS=',' read -ra DEP_ARRAY <<< "$DEPS"
  for dep in "${DEP_ARRAY[@]}"; do
    dep=$(echo "$dep" | xargs)
    if [ -n "$dep" ]; then
      uv add "$dep"
    fi
  done
fi

echo "Adding dev dependencies: pytest, ruff"
uv add --dev pytest ruff

echo "Syncing environment..."
uv sync

PYTHON_VERSION=$(uv run python --version 2>&1)
echo ""
echo "Project created: $(pwd)"
echo "Python version: $PYTHON_VERSION"
echo "Lockfile: uv.lock"
echo "Virtual env: .venv/"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  uv run python hello.py"
echo "  uv add <package>"
