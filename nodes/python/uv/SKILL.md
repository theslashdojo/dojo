---
name: uv
description: Ultra-fast Python package and project management with uv — use when creating Python projects, installing packages, managing Python versions, or running tools
---

# uv — Fast Python Package Manager

uv is Astral's ultra-fast Python package and project manager, written in Rust. It replaces pip, pip-tools, virtualenv, poetry, and pyenv with a single tool that is 10-100x faster.

## When to Use

- Creating a new Python project from scratch
- Adding, removing, or updating dependencies
- Installing packages faster than pip
- Managing Python versions without pyenv
- Running CLI tools without permanent installation (like npx)
- Building and publishing packages to PyPI
- Working with monorepo workspaces
- Migrating from pip/poetry to a faster workflow

## Installation

```bash
# Standalone installer (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Via pip (if Python is already installed)
pip install uv

# Via Homebrew (macOS/Linux)
brew install uv

# Verify installation
uv --version
```

## Workflow: New Project

```bash
# 1. Create project (generates pyproject.toml, .python-version, README.md)
uv init my-project
cd my-project

# 2. Add dependencies
uv add requests httpx pydantic
uv add --dev pytest ruff mypy

# 3. Write code
cat > main.py << 'PY'
import requests

def fetch(url: str) -> dict:
    return requests.get(url).json()

if __name__ == "__main__":
    data = fetch("https://httpbin.org/json")
    print(data)
PY

# 4. Run
uv run python main.py

# 5. Test
uv run pytest
```

uv handles everything: creates `.venv`, resolves dependencies, writes `uv.lock`, and runs your code.

## Workflow: Existing Project with requirements.txt

```bash
# Option A: Migrate to uv project format
uv init
uv add $(cat requirements.txt | grep -v '^#' | tr '\n' ' ')
uv sync

# Option B: Use pip-compatible interface (no migration)
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

## Project Management Commands

### Creating Projects

```bash
# Application project (default)
uv init my-app

# Library project (src layout)
uv init --lib my-lib

# Initialize in current directory
uv init
```

### Managing Dependencies

```bash
# Add a dependency
uv add requests
uv add "httpx>=0.27"

# Add dev dependency
uv add --dev pytest pytest-asyncio

# Add optional dependency group
uv add --optional docs sphinx

# Remove a dependency
uv remove requests

# Update a specific package
uv lock --upgrade-package requests

# Update all packages
uv lock --upgrade
```

### Lock and Sync

```bash
# Resolve dependencies and generate uv.lock
uv lock

# Sync .venv to match uv.lock
uv sync

# Sync including all extras
uv sync --all-extras

# Sync without dev dependencies (e.g., production)
uv sync --no-dev
```

Always commit `uv.lock` to version control. It ensures reproducible installs across machines and platforms.

### Running Commands

```bash
# Run a Python script
uv run python script.py

# Run a module
uv run python -m http.server 8000

# Run pytest
uv run pytest -v --tb=short

# Run with environment file
uv run --env-file .env python main.py
```

`uv run` auto-creates the environment and installs dependencies on first use.

## pip-Compatible Interface

For projects that use `requirements.txt` or need a pip drop-in:

```bash
# Install packages
uv pip install requests flask sqlalchemy

# Install from requirements file
uv pip install -r requirements.txt

# Compile locked requirements (like pip-compile from pip-tools)
uv pip compile requirements.in -o requirements.txt

# Sync environment to match requirements exactly
uv pip sync requirements.txt

# List installed packages
uv pip list

# Show package details
uv pip show requests

# Freeze current environment
uv pip freeze > requirements.txt

# Uninstall
uv pip uninstall requests
```

## Virtual Environments

```bash
# Create a virtual environment (10-100x faster than python -m venv)
uv venv

# Create with a specific Python version
uv venv --python 3.12

# Create at a custom path
uv venv /path/to/env

# Activate (standard activation, same as any venv)
source .venv/bin/activate    # Linux/macOS
.venv\Scripts\activate       # Windows

# Deactivate
deactivate
```

## Python Version Management

uv replaces pyenv for installing and managing Python versions:

```bash
# Install a Python version
uv python install 3.12

# Install multiple versions
uv python install 3.11 3.12 3.13

# List all available versions
uv python list

# List only installed versions
uv python list --only-installed

# Pin project to a specific version (writes .python-version)
uv python pin 3.12

# Uninstall a version
uv python uninstall 3.11
```

## Tool Management (like pipx/npx)

```bash
# Install a CLI tool globally
uv tool install ruff
uv tool install black
uv tool install httpie

# Run a tool without installing (ephemeral)
uv tool run black .
uv tool run ruff check .

# uvx — shorthand for uv tool run
uvx ruff check .
uvx black --check .
uvx pytest --version
uvx cowsay "hello from uv"

# List installed tools
uv tool list

# Upgrade a tool
uv tool upgrade ruff

# Uninstall a tool
uv tool uninstall ruff
```

`uvx` is the Python equivalent of `npx` — run any PyPI package as a CLI tool without permanent installation.

## Building and Publishing

```bash
# Build sdist and wheel
uv build

# Build only wheel
uv build --wheel

# Build only sdist
uv build --sdist

# Publish to PyPI
uv publish

# Publish with explicit token
uv publish --token $PYPI_TOKEN

# Publish to a custom index
uv publish --publish-url https://upload.pypi.org/legacy/
```

## pyproject.toml Reference

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "A Python project managed by uv"
requires-python = ">= 3.11"
dependencies = [
    "requests>=2.31",
    "httpx>=0.27",
    "pydantic>=2.0",
]

[project.optional-dependencies]
docs = ["sphinx>=7.0", "sphinx-rtd-theme"]

[project.scripts]
my-cli = "my_project.cli:main"

# uv-specific configuration
[tool.uv]
dev-dependencies = [
    "pytest>=8.0",
    "ruff>=0.6",
    "mypy>=1.10",
]

# Workspace for monorepos
[tool.uv.workspace]
members = ["packages/*", "apps/*"]

# Override dependency sources
[tool.uv.sources]
my-lib = { path = "../my-lib", editable = true }
```

## Workspaces (Monorepos)

For projects with multiple packages:

```
my-workspace/
  pyproject.toml              # Root with [tool.uv.workspace]
  uv.lock                     # Single lockfile for all packages
  packages/
    core/
      pyproject.toml
      src/core/...
    api/
      pyproject.toml
      src/api/...
```

```toml
# Root pyproject.toml
[tool.uv.workspace]
members = ["packages/*"]
```

```bash
# Sync entire workspace
uv sync

# Run in a specific package
uv run --package core pytest

# Add dependency to a specific package
cd packages/api && uv add fastapi
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `UV_CACHE_DIR` | Override cache directory location |
| `UV_PYTHON` | Default Python interpreter path |
| `UV_INDEX_URL` | Override default package index (PyPI) |
| `UV_EXTRA_INDEX_URL` | Additional package indexes to search |
| `UV_SYSTEM_PYTHON` | Allow using system Python (set to `1`) |
| `UV_LINK_MODE` | Install strategy: `copy` or `hardlink` |
| `UV_NO_CACHE` | Disable caching entirely |
| `UV_NATIVE_TLS` | Use system TLS instead of bundled rustls |
| `UV_COMPILE_BYTECODE` | Compile `.pyc` files during install |

## Resolution Strategies

```bash
# Default: highest compatible versions
uv lock

# Lowest compatible versions (test minimum bounds for libraries)
uv lock --resolution lowest

# Override a specific package version
uv add --override "numpy<2.0"

# Exclude a package
uv add --exclude "botocore"
```

## Common Patterns

### CI/CD Pipeline

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies from lockfile (deterministic, fast)
uv sync --frozen --no-dev

# Run tests
uv sync --frozen
uv run pytest
```

Use `--frozen` in CI to fail if `uv.lock` is out of date rather than silently updating it.

### Docker

```dockerfile
FROM python:3.12-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy project files
COPY pyproject.toml uv.lock ./

# Install dependencies (cached layer)
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ src/

CMD ["uv", "run", "python", "-m", "my_app"]
```

### Private Package Index

```bash
# Use a private index
uv add --index-url https://pypi.company.com/simple/ private-package

# Or set via environment
export UV_EXTRA_INDEX_URL=https://pypi.company.com/simple/
uv add private-package
```

### Running Scripts with Inline Dependencies

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "rich"]
# ///

import requests
from rich import print

data = requests.get("https://httpbin.org/json").json()
print(data)
```

```bash
# uv reads the inline metadata and installs dependencies automatically
uv run script.py
```

## Edge Cases

- `uv sync` removes packages not in the lockfile. Use `uv pip install` for ad-hoc additions that bypass the lockfile.
- `uv.lock` is platform-aware. It records markers so the same lockfile works on Linux, macOS, and Windows.
- `uv run` creates `.venv` if it does not exist. It does not activate it in your shell — it runs the command directly.
- `uv add` modifies `pyproject.toml` and `uv.lock` atomically. If resolution fails, neither file is changed.
- When using `uv pip` commands, uv operates on the active virtual environment (or `--python` target), not the project lockfile.
- `uvx` creates isolated temporary environments per tool invocation. Use `uv tool install` for tools you run frequently.
- The global cache (`~/.cache/uv` on Linux, `~/Library/Caches/uv` on macOS) can be shared across projects. Use `uv cache clean` to free space.
- `uv python install` downloads standalone Python builds from Astral's registry. These are separate from system Python and do not require admin privileges.

## Comparison: uv vs pip vs poetry

| Feature | uv | pip | poetry |
|---------|-----|-----|--------|
| Install speed | 10-100x fastest | Baseline | Similar to pip |
| Lockfile | `uv.lock` (auto) | Manual `freeze` | `poetry.lock` (auto) |
| Venv management | Built-in | Separate (venv) | Built-in |
| Python versions | Built-in | No | No |
| Tool runner (npx) | `uvx` | No | No |
| Build & publish | Built-in | Separate (build, twine) | Built-in |
| pip compatibility | `uv pip` interface | Native | No |
| Language | Rust | Python | Python |
