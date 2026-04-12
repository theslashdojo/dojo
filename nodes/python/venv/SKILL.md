---
name: venv
description: Create and manage Python virtual environments — use when isolating project dependencies, setting up development environments, or configuring CI
---

# venv — Python Virtual Environments

The `venv` module is Python's built-in tool (stdlib since 3.3) for creating isolated environments. Each venv gets its own `python` binary, `pip`, and `site-packages` directory, keeping project dependencies separate from the system Python and from each other.

## When to Use

- Starting any new Python project
- Isolating dependencies so projects don't conflict with each other
- Setting up a reproducible development environment
- Configuring CI/CD pipelines that need clean installs
- Testing against a specific set of package versions
- Avoiding permission issues with system Python (`pip install --user` workarounds)

## Workflow

1. Create the venv
2. Activate it
3. Install dependencies with pip
4. Work on your project
5. Deactivate when done

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# ... do work ...
deactivate
```

## Key Commands

### Creating a Virtual Environment

```bash
# Standard creation
python3 -m venv .venv

# Use a specific Python version (the venv inherits the creating interpreter)
python3.12 -m venv .venv

# Upgrade pip and setuptools to latest during creation
python3 -m venv --upgrade-deps .venv

# Allow access to system-wide installed packages
python3 -m venv --system-site-packages .venv

# Create without pip (for environments managed by external tools)
python3 -m venv --without-pip .venv

# Destroy and recreate an existing venv
python3 -m venv --clear .venv

# Combine flags
python3 -m venv --upgrade-deps --system-site-packages .venv
```

### Activating

```bash
# Linux / macOS (bash, zsh)
source .venv/bin/activate

# Linux / macOS (fish)
source .venv/bin/activate.fish

# Linux / macOS (csh, tcsh)
source .venv/bin/activate.csh

# Windows (cmd.exe)
.venv\Scripts\activate.bat

# Windows (PowerShell)
.venv\Scripts\Activate.ps1
```

After activation:
- The shell prompt shows `(.venv)` as a prefix
- `which python` points to `.venv/bin/python`
- `pip install` puts packages in `.venv/lib/pythonX.Y/site-packages/`
- The `VIRTUAL_ENV` environment variable is set to the venv's absolute path

### Deactivating

```bash
deactivate
```

This restores `PATH`, unsets `VIRTUAL_ENV`, and returns your shell to normal.

### Running Without Activating

You do not need to activate a venv to use it. Run binaries directly:

```bash
.venv/bin/python script.py
.venv/bin/pip install requests
.venv/bin/pytest
```

This is useful in scripts, cron jobs, and CI where activation is unnecessary overhead.

## How Venvs Work

### Directory Structure

```
.venv/
  pyvenv.cfg                  # Venv configuration file
  bin/                        # Linux/macOS executables (Scripts/ on Windows)
    python -> /usr/bin/python3.12   # Symlink to base interpreter
    python3 -> python               # Convenience symlink
    pip                             # Pip installed inside the venv
    activate                        # Bash activation script
    activate.fish                   # Fish activation script
    activate.csh                    # C-shell activation script
  lib/
    python3.12/
      site-packages/           # All installed packages land here
  include/                     # C header files for compiling extensions
```

### pyvenv.cfg

This plain-text config file at the venv root records how the venv was created:

```ini
home = /usr/bin
include-system-site-packages = false
version = 3.12.0
executable = /usr/bin/python3.12
command = /usr/bin/python3.12 -m venv .venv
```

- `home`: directory containing the base Python interpreter
- `include-system-site-packages`: whether `--system-site-packages` was used
- `version`: Python version
- `executable`: absolute path to the base interpreter
- `command`: the exact command used to create this venv

### The VIRTUAL_ENV Variable

When a venv is activated, the `VIRTUAL_ENV` environment variable is set:

```bash
echo $VIRTUAL_ENV
# /home/user/project/.venv
```

Many tools (pip, poetry, pytest) check this variable to detect they are running inside a venv. You can also use it in scripts:

```python
import os
venv = os.environ.get("VIRTUAL_ENV")
if venv:
    print(f"Running inside venv: {venv}")
else:
    print("No venv active")
```

### How Activation Works

Activation is purely a shell convenience. It does three things:

1. Prepends `.venv/bin` to `PATH` so `python` and `pip` resolve to the venv copies
2. Sets `VIRTUAL_ENV` to the venv's absolute path
3. Modifies the shell prompt to show `(.venv)`

No system files are modified. No root/admin permissions are needed.

## Integration with pip

After activating, `pip` is the venv's pip:

```bash
source .venv/bin/activate
pip install requests flask pytest
pip freeze > requirements.txt
pip install -r requirements.txt
```

See [[python/pip]] for full pip usage, including constraints files, extras, and editable installs.

## Integration with Poetry

Poetry manages venvs automatically. To make it use an in-project `.venv`:

```bash
poetry config virtualenvs.in-project true
poetry install
```

Poetry creates the venv, installs dependencies from `pyproject.toml` / `poetry.lock`, and activates automatically when you run `poetry shell` or `poetry run`.

See [[python/poetry]] for full details.

## Integration with uv

uv is a fast Rust-based Python package manager that can also create venvs:

```bash
# Create a venv with uv
uv venv .venv

# Install packages into the venv
uv pip install -r requirements.txt

# uv respects VIRTUAL_ENV — activate first, or use the --python flag
source .venv/bin/activate
uv pip install flask
```

See [[python/uv]] for full details.

## Best Practices

### Naming Convention

Use `.venv` (with the leading dot). This is the most widely recognized convention and is hidden by default on Linux/macOS. Other common names are `venv` and `env`, but `.venv` is preferred.

### .gitignore

Always ignore venv directories. Add these lines to your `.gitignore`:

```gitignore
# Virtual environments
.venv/
venv/
env/
```

Never commit a virtual environment. It contains platform-specific binaries and can be hundreds of megabytes.

### One Venv Per Project

Create the venv inside the project root. This keeps it associated with the project and makes it obvious which Python belongs where.

```
my-project/
  .venv/         # This project's venv
  src/
  tests/
  requirements.txt
  .gitignore
```

### Recreate, Don't Repair

If a venv breaks (wrong Python version, corrupted packages, upgrade issues):

```bash
python3 -m venv --clear .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`--clear` deletes the venv contents and creates fresh. This is faster and more reliable than debugging a broken environment.

### Pin Your Python Version

A venv is tied to the Python interpreter that created it. If you upgrade Python (e.g., 3.11 to 3.12), your existing venvs may break. Recreate them with the new interpreter.

### Use --upgrade-deps

The pip bundled with `venv` can be outdated. Always use `--upgrade-deps` to start with the latest pip:

```bash
python3 -m venv --upgrade-deps .venv
```

Or upgrade pip manually after creation:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
```

## virtualenv vs venv

`virtualenv` is the older, third-party tool that predates `venv`. Key differences:

| Aspect | venv | virtualenv |
|--------|------|------------|
| Source | Standard library (3.3+) | `pip install virtualenv` |
| Speed | Standard | Faster (caches seed packages) |
| Python targeting | Only the running version | Can create for other installed versions |
| Feature set | Minimal, covers common cases | Rich plugins, config, discovery |
| Relocatable | No | Partial support |
| Recommendation | Default choice for most users | When you need advanced features |

For most projects, `venv` is sufficient. Use `virtualenv` if you need to create environments for different Python versions or want its plugin ecosystem.

## Edge Cases

### Venv on Systems Without ensurepip

Some Linux distributions ship Python without `ensurepip` (e.g., Debian/Ubuntu). Creation may fail:

```
Error: Command '['.venv/bin/python', '-m', 'ensurepip', ...]' returned non-zero exit status 1
```

Fix by installing the `python3-venv` package:

```bash
sudo apt install python3-venv     # Debian/Ubuntu
sudo apt install python3.12-venv  # For a specific version
```

Or create without pip and install it manually:

```bash
python3 -m venv --without-pip .venv
source .venv/bin/activate
curl -sS https://bootstrap.pypa.io/get-pip.py | python
```

### Windows Execution Policy

On Windows, PowerShell may block activation:

```
.venv\Scripts\Activate.ps1 cannot be loaded because running scripts is disabled
```

Fix with:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Venvs and Docker

In Docker containers, venvs are optional since the container already provides isolation. However, they are still useful in multi-stage builds:

```dockerfile
FROM python:3.12-slim
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

Using a venv in Docker keeps your app packages cleanly separated from system Python packages.

### Venvs and CI/CD

In CI, you often do not need to activate. Just call the venv's binaries directly:

```yaml
# GitHub Actions example
- run: |
    python -m venv .venv
    .venv/bin/pip install -r requirements.txt
    .venv/bin/pytest
```

### Symlinks vs Copies

By default, `venv` creates symlinks to the base Python interpreter. On some systems (notably older Windows), you may need copies instead:

```bash
python -m venv --copies .venv
```

### Multiple Python Versions

To test against multiple Python versions, create separate venvs:

```bash
python3.11 -m venv .venv-3.11
python3.12 -m venv .venv-3.12
python3.13 -m venv .venv-3.13
```

Or use `tox` or `nox` which automate multi-version testing with venvs.
