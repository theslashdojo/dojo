#!/bin/bash
set -e

PROJECT_NAME="${PROJECT_NAME:-my-project}"
DEPS="${DEPENDENCIES:-}"

# Create new project
poetry new "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Configure in-project virtualenv
poetry config virtualenvs.in-project true --local

# Add dependencies if specified
if [ -n "$DEPS" ]; then
  IFS=',' read -ra DEP_ARRAY <<< "$DEPS"
  for dep in "${DEP_ARRAY[@]}"; do
    dep=$(echo "$dep" | xargs)  # trim whitespace
    echo "Adding dependency: $dep"
    poetry add "$dep"
  done
fi

# Add common dev dependencies
poetry add --group dev pytest mypy

# Install everything
poetry install

# Report results
VENV_PATH=$(poetry env info --path)
echo ""
echo "Project created: $(pwd)"
echo "Virtualenv: $VENV_PATH"
echo "Run: cd $PROJECT_NAME && poetry run pytest"
