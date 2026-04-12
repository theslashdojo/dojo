---
name: pip
description: Install, manage, and audit Python packages with pip — use when adding dependencies, creating requirements files, or configuring package sources
---

# pip — Python Package Installer

pip is the default package installer for Python. It downloads packages from the Python Package Index (PyPI) and installs them into the active Python environment. Always use pip inside a virtual environment.

## When to Use

- Installing Python packages from PyPI or a private registry
- Creating or installing from a requirements.txt file
- Freezing the current environment for reproducible builds
- Upgrading or removing installed packages
- Configuring pip to use a private or corporate registry
- Auditing dependencies for known security vulnerabilities
- Installing a local package in editable/development mode

## Workflow

1. Create and activate a virtual environment: `python -m venv .venv && source .venv/bin/activate`
2. Install packages: `pip install requests flask`
3. Freeze dependencies: `pip freeze > requirements.txt`
4. Pin versions in requirements.txt for reproducibility
5. Audit: `pip-audit` to check for vulnerabilities
6. Deploy: `pip install -r requirements.txt` in the target environment

## Key Commands

```bash
# Install packages
pip install requests                      # latest from PyPI
pip install requests==2.31.0              # exact version
pip install "requests>=2.28.0"            # minimum version
pip install "requests~=2.31.0"            # compatible release (>=2.31.0, <2.32.0)
pip install "fastapi[standard]"           # with extras
pip install requests flask sqlalchemy     # multiple at once

# Install from files
pip install -r requirements.txt           # from requirements file
pip install -r requirements.txt -c constraints.txt  # with constraints
pip install -e .                          # editable local install
pip install -e ".[dev,test]"              # editable with extras

# Upgrade and remove
pip install --upgrade requests            # upgrade to latest
pip install -U pip setuptools wheel       # upgrade pip itself
pip uninstall requests                    # remove a package
pip uninstall -y requests                 # skip confirmation

# Install to specific locations
pip install --user requests               # user site-packages
pip install --target ./lib requests       # custom directory

# Inspect packages
pip list                                  # all installed packages
pip list --outdated                       # packages with newer versions
pip list --format=json                    # JSON output
pip show requests                         # package details and location
pip index versions requests               # available versions on PyPI

# Freeze and verify
pip freeze > requirements.txt             # export pinned versions
pip check                                 # verify dependency compatibility
```

## requirements.txt Format

```text
# Exact pins — use for reproducible production builds
requests==2.31.0
flask==3.0.0
sqlalchemy==2.0.23

# Minimum version
requests>=2.28.0

# Compatible release (>=2.31.0, <2.32.0)
requests~=2.31.0

# Version range with exclusion
requests>=2.28.0,!=2.30.0

# Extras
fastapi[standard]==0.104.1
uvicorn[standard]==0.24.0

# Editable local package
-e .

# Include another requirements file
-r requirements-base.txt

# Apply constraints (pins transitive deps without declaring direct deps)
-c constraints.txt

# Hash-pinned for supply-chain security
requests==2.31.0 \
    --hash=sha256:942c5a758f98d790eaed1a29cb6eefc7f0edf3fcb0fce8afe0f44769042b5a04
```

### Pinning Strategy

| Specifier | Meaning | Use Case |
|-----------|---------|----------|
| `==2.31.0` | Exact version | Production deployments, CI |
| `>=2.28.0` | Minimum version | Library dependencies |
| `~=2.31.0` | Compatible release (patch updates only) | Balance stability and fixes |
| `>=2.28,<3.0` | Bounded range | When you need a floor and ceiling |
| `!=2.30.0` | Exclude a version | Known-bad releases |

### Constraints Files

Constraints files pin versions of transitive dependencies without declaring them as direct requirements. This separates "what to install" from "what versions to use."

```bash
# constraints.txt
urllib3==2.1.0
certifi==2023.11.17
charset-normalizer==3.3.2
idna==3.6

# Install with constraints
pip install -r requirements.txt -c constraints.txt
```

## pip Configuration

### pip.conf (Linux/macOS) / pip.ini (Windows)

```ini
# Location precedence:
#   1. Command-line flags (highest)
#   2. Environment variables (PIP_*)
#   3. Per-virtualenv: <venv>/pip.conf
#   4. User: ~/.config/pip/pip.conf (Linux) or ~/Library/Application Support/pip/pip.conf (macOS)
#   5. Global: /etc/pip.conf

[global]
index-url = https://pypi.org/simple
extra-index-url = https://private.registry.example.com/simple/
trusted-host = private.registry.example.com
timeout = 60
require-virtualenv = true

[install]
no-deps = false
compile = true
```

### Private Registries

```bash
# Use a private index as default
pip install --index-url https://private.registry.example.com/simple/ my-package

# Add an extra index alongside PyPI
pip install --extra-index-url https://private.registry.example.com/simple/ my-package

# Trust a host without TLS verification (internal only)
pip install --trusted-host private.registry.example.com \
    --index-url http://private.registry.example.com/simple/ my-package

# Authenticate with a token in the URL
pip install --index-url https://__token__:${REGISTRY_TOKEN}@private.registry.example.com/simple/ my-package

# Set in pip.conf for persistence
# [global]
# index-url = https://private.registry.example.com/simple/
# extra-index-url = https://pypi.org/simple
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `PIP_INDEX_URL` | Override the default package index URL |
| `PIP_EXTRA_INDEX_URL` | Additional package index URLs (space-separated) |
| `PIP_NO_CACHE_DIR` | Disable pip cache when set to `1` |
| `PIP_REQUIRE_VIRTUALENV` | Refuse to install outside a virtual environment when set to `1` |
| `PIP_TRUSTED_HOST` | Skip TLS verification for specified hosts |
| `PIP_TIMEOUT` | Network timeout in seconds |
| `PIP_CONFIG_FILE` | Path to a custom pip configuration file |

```bash
# Example: enforce virtualenv-only installs
export PIP_REQUIRE_VIRTUALENV=1

# Example: use a corporate registry
export PIP_INDEX_URL=https://private.registry.example.com/simple/
export PIP_EXTRA_INDEX_URL=https://pypi.org/simple

# Example: disable cache in CI
export PIP_NO_CACHE_DIR=1
```

## Security

### Hash-Checking Mode

Lock down exactly which package artifacts are allowed. When `--require-hashes` is used, every requirement must include at least one `--hash` entry.

```bash
# Install with hash verification
pip install --require-hashes -r requirements.txt

# Generate a hash for a downloaded package
pip hash ./downloads/requests-2.31.0.tar.gz
```

```text
# requirements.txt with hashes
requests==2.31.0 \
    --hash=sha256:942c5a758f98d790eaed1a29cb6eefc7f0edf3fcb0fce8afe0f44769042b5a04
certifi==2023.11.17 \
    --hash=sha256:e036ab49d5b79556f99cfc2d9320b34cfbe5be05c5871b51de9329f0603b0474
```

### pip-audit

Scan installed packages against known vulnerability databases (OSV, PyPI advisory).

```bash
# Install pip-audit
pip install pip-audit

# Audit the current environment
pip-audit

# Audit a requirements file without installing
pip-audit -r requirements.txt

# Auto-fix by upgrading vulnerable packages
pip-audit --fix

# Output as JSON for CI integration
pip-audit --format=json
pip-audit --format=json --output=audit-results.json
```

## Cache Management

```bash
# Show cache directory location
pip cache dir

# List cached packages
pip cache list

# List cached versions of a specific package
pip cache list requests

# Purge the entire cache
pip cache purge

# Remove a specific package from cache
pip cache remove requests

# Install without using cache (useful in CI)
pip install --no-cache-dir requests
```

## Safety Rules

1. **Always use a virtual environment** -- never install into the system Python (`PIP_REQUIRE_VIRTUALENV=1`)
2. **Pin versions in production** -- use `==` in requirements.txt for reproducible builds
3. **Use constraints files for transitive deps** -- separate what you install from the versions you allow
4. **Run pip-audit regularly** -- check for known vulnerabilities in your dependency tree
5. **Use --require-hashes in high-security contexts** -- verify package integrity on every install
6. **Never use sudo with pip** -- fix your environment instead
7. **Upgrade pip itself regularly** -- `pip install -U pip` to get the latest resolver and security fixes
8. **Review before installing** -- use `pip install --dry-run <pkg>` to see what would be installed
9. **Never commit credentials in pip.conf** -- use environment variables for registry tokens

## Edge Cases

- **Dependency conflicts**: pip's resolver may fail when two packages require incompatible versions of the same dependency. Use `pip check` to diagnose, then pin a compatible version in constraints.txt.
- **Editable install not updating**: after changing `setup.py` or `pyproject.toml` metadata (entry points, package name), re-run `pip install -e .` to pick up the changes.
- **pip install succeeds but import fails**: the package name on PyPI may differ from the import name (e.g., `pip install Pillow` but `import PIL`). Use `pip show <pkg>` to see the installed location.
- **Hash mismatch with --require-hashes**: regenerate hashes when upgrading. Different sdist and wheel artifacts produce different hashes.
- **SSL certificate errors with private registries**: use `--trusted-host` for internal registries or install the CA certificate into the system trust store.
- **pip install hangs**: check network connectivity and proxy settings. Set `PIP_TIMEOUT` to a lower value to fail fast.
- **Multiple Python versions**: use `python3.11 -m pip install` instead of bare `pip` to target a specific interpreter.
- **pip freeze includes editable installs**: these show as `-e git+...` entries which may not be portable. Maintain requirements.txt manually for shared projects.
- **Conflicting global and user installs**: use `pip list --user` to see user-installed packages. Prefer virtual environments over `--user` installs.
