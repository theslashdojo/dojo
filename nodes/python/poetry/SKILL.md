---
name: poetry
description: Manage Python project dependencies, builds, and publishing with Poetry — use when creating Python projects, managing dependency groups, building wheels, or publishing to PyPI
---

# Poetry — Python Dependency Management

Poetry replaces pip, setuptools, and virtualenv with a single coherent tool. It uses `pyproject.toml` for project metadata and dependency declarations, and `poetry.lock` for deterministic reproducible installs.

## When to Use

- Creating a new Python project from scratch
- Managing dependencies with version constraints and groups
- Building and publishing packages to PyPI or private registries
- Generating requirements.txt for pip-based deployment environments
- Running scripts or tests inside a managed virtual environment

## Workflow

1. Create project: `poetry new my-project` or `poetry init` in an existing directory
2. Add dependencies: `poetry add requests` and `poetry add --group dev pytest`
3. Write code in the generated package directory
4. Run and test: `poetry run pytest` or `poetry shell` then `pytest`
5. Build: `poetry build` produces sdist and wheel in `dist/`
6. Publish: `poetry publish` uploads to PyPI

## Project Setup

### Scaffold a New Project

```bash
poetry new my-project
```

This creates:

```
my-project/
  pyproject.toml
  README.md
  my_project/
    __init__.py
  tests/
    __init__.py
```

### Initialize in an Existing Directory

```bash
cd existing-project
poetry init
```

Walks through an interactive prompt to generate `pyproject.toml`.

### Select Python Interpreter

```bash
poetry env use python3.12
poetry env use /usr/bin/python3.12
```

### Inspect Environment

```bash
poetry env info
poetry env info --path       # just the venv path
poetry env list              # list all envs for this project
```

## Dependency Management

### Adding Dependencies

```bash
# Runtime dependency
poetry add requests

# With version constraint
poetry add 'requests^2.31'
poetry add 'flask>=3.0,<4.0'

# Dev dependency
poetry add --group dev pytest

# Docs group
poetry add --group docs sphinx

# From git
poetry add git+https://github.com/user/repo.git

# From local path
poetry add ../my-local-lib/
```

### Removing Dependencies

```bash
poetry remove requests
poetry remove --group dev pytest
```

### Installing from Lock File

```bash
# Install everything (all groups)
poetry install

# Skip dev group
poetry install --without dev

# Only specific groups
poetry install --only main

# Sync: remove packages not in lock file
poetry install --sync
```

### Updating Dependencies

```bash
# Update all within version constraints
poetry update

# Update specific package
poetry update requests

# Regenerate lock file without installing
poetry lock
```

### Inspecting Dependencies

```bash
# Flat list of installed packages
poetry show

# Dependency tree
poetry show --tree

# Details for one package
poetry show requests

# Check for outdated packages
poetry show --outdated
```

### Exporting for pip

```bash
# Standard requirements.txt
poetry export -f requirements.txt --output requirements.txt

# Include dev dependencies
poetry export -f requirements.txt --with dev --output requirements-dev.txt

# Without hashes (some CI systems need this)
poetry export -f requirements.txt --without-hashes --output requirements.txt
```

## Running Code in the Virtual Environment

```bash
# Run a single command
poetry run python script.py
poetry run pytest -v
poetry run mypy my_project/

# Activate the shell
poetry shell
# Now python, pytest, etc. use the venv directly
```

## pyproject.toml Reference

```toml
[tool.poetry]
name = "my-project"
version = "0.1.0"
description = "A short description of the project"
authors = ["Your Name <you@example.com>"]
license = "MIT"
readme = "README.md"
homepage = "https://example.com"
repository = "https://github.com/user/my-project"
keywords = ["example", "poetry"]
packages = [{include = "my_project"}]

[tool.poetry.dependencies]
python = "^3.10"
requests = "^2.31"
pydantic = ">=2.0,<3.0"
optional-dep = {version = "^1.0", optional = true}

[tool.poetry.group.dev.dependencies]
pytest = "^8.0"
mypy = "^1.8"
ruff = "^0.3"

[tool.poetry.group.docs.dependencies]
sphinx = "^7.0"

[tool.poetry.extras]
all = ["optional-dep"]

[tool.poetry.scripts]
my-cli = "my_project.cli:main"

[[tool.poetry.source]]
name = "private"
url = "https://private.pypi.org/simple/"
priority = "supplemental"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

### Key Sections

- `[tool.poetry]` -- project metadata (name, version, authors, etc.)
- `[tool.poetry.dependencies]` -- runtime dependencies including the Python version constraint
- `[tool.poetry.group.<name>.dependencies]` -- grouped dependencies (dev, test, docs)
- `[tool.poetry.scripts]` -- console entry points (creates CLI commands on install)
- `[tool.poetry.extras]` -- optional dependency sets installable with `pip install my-project[all]`
- `[[tool.poetry.source]]` -- private or supplemental package registries
- `[build-system]` -- always `poetry-core` for Poetry projects

## Version Constraints

| Syntax | Meaning | Example |
|--------|---------|---------|
| `^1.2.3` | `>=1.2.3, <2.0.0` | Caret: allow minor and patch updates |
| `~1.2.3` | `>=1.2.3, <1.3.0` | Tilde: allow only patch updates |
| `>=1.0,<2.0` | Explicit range | Full control over bounds |
| `*` | Any version | Unconstrained |
| `==1.2.3` | Exact pin | No updates allowed |
| `^0.2.3` | `>=0.2.3, <0.3.0` | Caret on 0.x is more restrictive |

The caret (`^`) is the default and recommended constraint. It allows updates that do not change the leftmost non-zero digit.

## poetry.lock

The lock file records the exact resolved versions, hashes, and dependency graph. It ensures every install is identical.

- **Always commit `poetry.lock`** for applications (reproducible deploys)
- For libraries, committing it is optional (consumers resolve their own versions)
- Regenerate with `poetry lock` after manual pyproject.toml edits
- Never edit `poetry.lock` by hand

## Configuration

### Project-Level (poetry.toml)

Create `poetry.toml` in the project root:

```toml
[virtualenvs]
in-project = true
create = true
prefer-active-python = true
```

### Global Configuration

```bash
poetry config virtualenvs.in-project true
poetry config cache-dir /custom/cache/path

# List all config
poetry config --list
```

### Environment Variables

| Variable | Effect |
|----------|--------|
| `POETRY_VIRTUALENVS_IN_PROJECT=true` | Create `.venv` in project root |
| `POETRY_VIRTUALENVS_CREATE=false` | Do not create a virtual environment |
| `POETRY_PYPI_TOKEN_PYPI=pypi-xxx` | PyPI authentication token |
| `POETRY_HTTP_BASIC_PRIVATE_USERNAME` | Username for private registry named "private" |
| `POETRY_HTTP_BASIC_PRIVATE_PASSWORD` | Password for private registry named "private" |

Pattern: `POETRY_<SECTION>_<KEY>` with dots replaced by underscores and uppercased.

## Building and Publishing

### Build

```bash
poetry build
# Produces:
#   dist/my_project-0.1.0.tar.gz   (sdist)
#   dist/my_project-0.1.0-py3-none-any.whl   (wheel)
```

### Publish to PyPI

```bash
# Configure token (one time)
poetry config pypi-token.pypi pypi-XXXXXXXXXXXXXXXX

# Publish
poetry publish

# Build and publish in one step
poetry publish --build
```

### Publish to Private Registry

```bash
# Add the repository
poetry config repositories.private https://private.pypi.org/legacy/

# Set credentials
poetry config http-basic.private username password

# Publish to it
poetry publish --repository private
```

## Private Registries

Add to `pyproject.toml`:

```toml
[[tool.poetry.source]]
name = "private"
url = "https://private.pypi.org/simple/"
priority = "supplemental"
```

Priority options:
- `default` -- use instead of PyPI
- `primary` -- search alongside PyPI
- `supplemental` -- search only if not found on PyPI
- `explicit` -- only for packages that specify this source

## Common Patterns

### CI/CD Install

```bash
# Install with deterministic lock, no dev deps, no interaction
poetry install --without dev --no-interaction --no-ansi
```

### Docker

```dockerfile
FROM python:3.12-slim

WORKDIR /app
RUN pip install poetry

# Copy dependency files first for layer caching
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.create false \
    && poetry install --without dev --no-interaction --no-ansi

COPY . .
CMD ["python", "-m", "my_project"]
```

### Monorepo with Path Dependencies

```toml
[tool.poetry.dependencies]
shared-lib = {path = "../shared-lib", develop = true}
```

### Pre-commit Hook for Lock Consistency

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/python-poetry/poetry
    rev: '1.8.0'
    hooks:
      - id: poetry-check
      - id: poetry-lock
        args: ["--check"]
```

## Edge Cases

- `poetry install --no-dev` is deprecated; use `poetry install --without dev`
- Running `poetry add` also updates `poetry.lock` and installs the package
- If `poetry.lock` is out of sync with `pyproject.toml`, `poetry install` will warn; run `poetry lock` to fix
- `poetry shell` spawns a subshell; use `exit` to leave (not `deactivate`)
- On systems with multiple Python versions, use `poetry env use` to pin the interpreter before `poetry install`
- The `[build-system]` section must use `poetry-core`, not `poetry`, as the build backend
- `poetry export` requires the `poetry-plugin-export` plugin in Poetry 1.8+

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Failed to create virtualenv" | Check `poetry env use python3.x` points to a valid interpreter |
| "SolverProblemError" | Version conflict; review constraints with `poetry show --tree` |
| Lock file out of sync | Run `poetry lock` to regenerate |
| Slow resolution | Add `--no-update` to `poetry lock` to keep existing pins |
| Package not found | Check `[[tool.poetry.source]]` URLs and priority |
| "poetry: command not found" | Install with `pipx install poetry` (recommended) or `pip install poetry` |
