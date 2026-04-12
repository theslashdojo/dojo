#!/bin/bash
set -e

PYTHON_PATH="${PYTHON_PATH:-python3}"
VENV_DIR="${VENV_DIR:-.venv}"

echo "Creating venv with: $PYTHON_PATH -m venv $VENV_DIR"
"$PYTHON_PATH" -m venv --upgrade-deps "$VENV_DIR"

echo "Activating venv..."
source "$VENV_DIR/bin/activate"

PYTHON_VERSION=$(python --version 2>&1)
VENV_PATH=$(cd "$VENV_DIR" && pwd)

echo ""
echo "Virtual environment ready:"
echo "  venv_path: $VENV_PATH"
echo "  python_version: $PYTHON_VERSION"
echo "  python: $(which python)"
echo "  pip: $(pip --version)"
echo ""
echo "To activate manually: source $VENV_DIR/bin/activate"
