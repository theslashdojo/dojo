---
name: pytest
description: Write and run Python tests with pytest. Use when a project has pytest in requirements/pyproject.toml, conftest.py files, or test_*.py files.
---

# pytest

The de facto Python testing framework. Plain assert statements, fixture-based dependency injection, parametrize for data-driven tests, and a rich plugin ecosystem.

## When to Use

- Project has `pytest` in `requirements.txt`, `pyproject.toml`, or `setup.cfg`
- Test files follow `test_*.py` or `*_test.py` naming
- `conftest.py` files exist in the project
- Writing new unit tests, integration tests, or async tests for Python code
- Running an existing test suite and interpreting results
- Adding coverage reporting, parallel execution, or custom markers
- Migrating from unittest to pytest

## Workflow

1. **Detect**: check for `pytest` in dependencies and `conftest.py` / `test_*.py` files
2. **Install**: `pip install pytest` plus needed plugins (pytest-cov, pytest-asyncio, pytest-mock, pytest-xdist)
3. **Write tests**: plain `assert` statements, use fixtures for setup/teardown
4. **Configure**: add `[tool.pytest.ini_options]` to `pyproject.toml`
5. **Run**: `pytest -v --tb=short` for development, `pytest --cov=src -n auto` for CI
6. **Iterate**: use `pytest --lf` to rerun failures, `pytest -k "name"` to focus

## Quick Reference

```bash
pytest                              # run all tests
pytest tests/test_api.py            # run one file
pytest tests/test_api.py::test_get  # run one test
pytest -k "login or logout"         # filter by name
pytest -m "not slow"                # filter by marker
pytest -x                           # stop on first failure
pytest -v --tb=short                # verbose, short tracebacks
pytest --co                         # collect only, don't run
pytest --lf                         # rerun last failures
pytest --ff                         # failures first
pytest -n auto                      # parallel (xdist)
pytest --cov=src                    # coverage report
pytest --cov=src --cov-fail-under=80  # enforce threshold
pytest --durations=10               # show slowest tests
pytest -s                           # show print output
```

## Writing Tests

### Basic Assertions

```python
import pytest

def test_addition():
    assert 1 + 1 == 2

def test_string_operations():
    result = "hello world"
    assert result.startswith("hello")
    assert len(result) == 11

def test_dict_contents():
    data = {"status": "ok", "count": 5}
    assert data["status"] == "ok"
    assert data["count"] > 0

def test_exception():
    with pytest.raises(ValueError, match="must be positive"):
        validate_age(-1)

def test_approximate():
    assert 0.1 + 0.2 == pytest.approx(0.3)
```

### Fixtures

```python
import pytest

@pytest.fixture
def sample_user():
    return {"id": 1, "name": "Alice", "email": "alice@test.com"}

@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.rollback()
    session.close()

def test_user_lookup(db_session, sample_user):
    db_session.add(User(**sample_user))
    found = db_session.query(User).filter_by(id=1).first()
    assert found.name == "Alice"
```

### Yield Fixtures with Teardown

```python
@pytest.fixture(scope="module")
def server():
    proc = start_test_server(port=8765)
    yield "http://localhost:8765"
    proc.terminate()
    proc.wait()

@pytest.fixture
def temp_config(tmp_path):
    config = tmp_path / "config.toml"
    config.write_text('[app]\nname = "test"\ndebug = true')
    yield config
    # tmp_path auto-cleans; no manual teardown needed
```

### Fixture Scopes

```python
@pytest.fixture(scope="session")
def database_engine():
    """Created once for the entire test session."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()

@pytest.fixture(scope="function")  # default
def clean_table(database_engine):
    """Runs before and after each test."""
    yield database_engine
    database_engine.execute("DELETE FROM users")
```

### Fixture Factories

```python
@pytest.fixture
def make_user():
    users = []
    def _factory(name="Alice", role="user"):
        user = User(name=name, role=role)
        users.append(user)
        return user
    yield _factory
    for u in users:
        u.delete()

def test_admin_access(make_user):
    admin = make_user("Bob", role="admin")
    regular = make_user("Carol", role="user")
    assert admin.can_manage(regular)
```

### Built-in Fixtures

```python
def test_with_tmp_path(tmp_path):
    f = tmp_path / "output.json"
    f.write_text('{"result": true}')
    assert f.exists()

def test_with_monkeypatch(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "sqlite:///:memory:")
    monkeypatch.setattr("myapp.config.DEBUG", True)
    assert os.environ["DATABASE_URL"].startswith("sqlite")

def test_captured_output(capsys):
    print("hello from test")
    captured = capsys.readouterr()
    assert "hello" in captured.out

def test_logging(caplog):
    import logging
    with caplog.at_level(logging.WARNING):
        logging.warning("low disk space")
    assert "low disk" in caplog.text
```

### conftest.py — Shared Fixtures

```python
# tests/conftest.py — available to ALL tests
import pytest

@pytest.fixture(autouse=True)
def isolate_env(monkeypatch):
    monkeypatch.setenv("ENV", "test")
    monkeypatch.delenv("API_KEY", raising=False)

@pytest.fixture(scope="session")
def app():
    return create_app(testing=True)

@pytest.fixture
def client(app):
    return app.test_client()
```

```python
# tests/integration/conftest.py — only for tests/integration/
import pytest

@pytest.fixture(scope="module")
def live_db():
    conn = connect_to_test_db()
    yield conn
    conn.close()
```

### Parametrize

```python
@pytest.mark.parametrize("input_val,expected", [
    ("hello", "HELLO"),
    ("World", "WORLD"),
    ("", ""),
    ("123abc", "123ABC"),
])
def test_uppercase(input_val, expected):
    assert input_val.upper() == expected

# With readable IDs
@pytest.mark.parametrize("code,ok", [
    (200, True),
    (404, False),
    (500, False),
], ids=["success", "not-found", "server-error"])
def test_status(code, ok):
    assert is_success(code) == ok

# Cross-product
@pytest.mark.parametrize("method", ["GET", "POST"])
@pytest.mark.parametrize("path", ["/api/users", "/api/items"])
def test_endpoint_exists(client, method, path):
    resp = client.open(path, method=method)
    assert resp.status_code != 404

# With marks inside parametrize
@pytest.mark.parametrize("n,expected", [
    (1, 1),
    (5, 120),
    pytest.param(-1, None, marks=pytest.mark.xfail(raises=ValueError)),
])
def test_factorial(n, expected):
    assert factorial(n) == expected
```

### Async Testing

```python
import pytest
import httpx

@pytest.mark.asyncio
async def test_async_endpoint():
    async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
        resp = await client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

# Async fixture
@pytest.fixture
async def async_db():
    conn = await asyncpg.connect("postgresql://localhost/testdb")
    yield conn
    await conn.close()

@pytest.mark.asyncio
async def test_db_query(async_db):
    rows = await async_db.fetch("SELECT count(*) FROM users")
    assert rows[0]["count"] >= 0
```

Set `asyncio_mode = "auto"` in `pyproject.toml` to drop `@pytest.mark.asyncio` everywhere.

### Markers

```python
@pytest.mark.slow
def test_large_dataset():
    process(generate_data(1_000_000))

@pytest.mark.skip(reason="Pending API deployment")
def test_external_api():
    ...

@pytest.mark.skipif(
    sys.platform == "win32",
    reason="Unix-only feature"
)
def test_unix_signals():
    ...

@pytest.mark.xfail(reason="Bug #789, fix in progress")
def test_known_bug():
    assert broken_function() == "correct"
```

Register in config:

```toml
[tool.pytest.ini_options]
markers = [
    "slow: long-running tests",
    "integration: requires external services",
]
```

```bash
pytest -m "not slow"                    # skip slow
pytest -m "integration"                 # only integration
pytest -m "not integration and not slow"  # fast unit tests
```

### Coverage

```bash
pytest --cov=src --cov-report=term-missing
pytest --cov=src --cov-report=html --cov-branch
pytest --cov=src --cov-fail-under=80
```

```toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*"]
branch = true

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.",
]
```

## Edge Cases

- **conftest.py scoping**: a conftest in `tests/` is global to all tests; one in `tests/api/` is local to that subdirectory. Fixtures in a child conftest can override parent fixtures of the same name.
- **Fixture ordering**: fixtures are resolved by dependency graph, not by parameter order. If fixture A depends on B, B is created first regardless of argument position.
- **Scope mismatch**: a function-scoped fixture cannot request a narrower scope. A session fixture cannot use a function fixture — pytest raises a `ScopeMismatch` error.
- **Parametrize + fixtures**: use `indirect=True` to route parametrized values through a fixture: `@pytest.mark.parametrize("db", ["sqlite", "pg"], indirect=True)`.
- **Parametrize + marks**: embed marks in parameter sets with `pytest.param(val, marks=pytest.mark.xfail)` for individual case handling.
- **Parallel + session fixtures**: with `pytest-xdist`, session-scoped fixtures are created once per worker process, not once globally. Use file locks for truly shared resources.
- **Async fixture scope**: in pytest-asyncio 0.23+, async fixtures default to function scope for the event loop. Use `loop_scope="session"` for session-scoped async fixtures.
- **conftest.py in project root**: placing conftest.py at the project root (not in tests/) can interfere with installed packages. Keep it inside `tests/`.
- **Test isolation**: tests must not depend on execution order. If tests share mutable state (module-level variables, class attributes), parallel and randomized runs will fail intermittently.
- **Coverage with async**: `pytest-cov` works with async code but may undercount branches in heavily concurrent code. Use `--cov-branch` explicitly.
- **Fixture finalization order**: teardown runs in reverse dependency order. If fixture A depends on B, A tears down before B.
- **monkeypatch scope**: `monkeypatch` is function-scoped by default. For module/session scope patching, use `monkeypatch.context()` or create a custom fixture.
