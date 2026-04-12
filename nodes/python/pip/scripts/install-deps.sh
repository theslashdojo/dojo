#!/usr/bin/env bash
set -euo pipefail

# Install Python packages from a requirements.txt file inside the active virtual environment.
# Usage: ./install-deps.sh [requirements_file] [packages...]
#
# Environment variables:
#   REQUIREMENTS_FILE - Path to requirements.txt (default: requirements.txt)
#   PACKAGES          - Comma-separated list of packages to install
#   PIP_INDEX_URL     - Override the default PyPI index URL
#   PIP_EXTRA_INDEX_URL - Additional package index URLs

REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-requirements.txt}"
PACKAGES="${PACKAGES:-}"

# Check we're in a virtual environment
if [ -z "${VIRTUAL_ENV:-}" ]; then
    # Try to activate .venv if it exists
    if [ -f ".venv/bin/activate" ]; then
        echo "No active venv detected. Activating .venv..."
        # shellcheck disable=SC1091
        source .venv/bin/activate
    else
        echo "ERROR: No virtual environment active and no .venv found."
        echo "Create one with: python3 -m venv .venv && source .venv/bin/activate"
        exit 1
    fi
fi

echo "Using Python: $(which python)"
echo "pip version: $(pip --version)"
echo ""

# Upgrade pip first
pip install --upgrade pip --quiet

# Install from requirements file if it exists
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Installing from $REQUIREMENTS_FILE..."
    pip install -r "$REQUIREMENTS_FILE"
    echo ""
fi

# Install individual packages if specified
if [ -n "$PACKAGES" ]; then
    echo "Installing packages: $PACKAGES"
    IFS=',' read -ra PKG_ARRAY <<< "$PACKAGES"
    for pkg in "${PKG_ARRAY[@]}"; do
        pkg=$(echo "$pkg" | xargs)  # trim whitespace
        if [ -n "$pkg" ]; then
            pip install "$pkg"
        fi
    done
    echo ""
fi

# Also accept packages as positional arguments
if [ $# -gt 0 ]; then
    # If first arg looks like a file, treat as requirements
    if [ -f "$1" ]; then
        echo "Installing from $1..."
        pip install -r "$1"
    else
        echo "Installing packages: $*"
        pip install "$@"
    fi
    echo ""
fi

# Show what was installed
echo "=== Installed packages ==="
pip list --format=columns

# Check for dependency conflicts
echo ""
echo "=== Dependency check ==="
pip check && echo "No conflicts found." || echo "WARNING: Dependency conflicts detected!"
