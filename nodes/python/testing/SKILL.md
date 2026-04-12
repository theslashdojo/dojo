---
name: testing
description: Write and run Python tests with pytest — use when writing unit tests, integration tests, testing async code, or setting up test infrastructure
---

# Python Testing with pytest

pytest is the standard Python testing framework. Use it for unit tests, integration tests, async tests, and any automated verification of Python code.

## When to Use

- Writing unit tests for functions, classes, or modules
- Testing async code (API clients, event loops, coroutines)
- Setting up shared test fixtures and factories
- Mocking external services, APIs, or databases
- Measuring code coverage
- Running tests in CI/CD pipelines

## Quick Start

Install pytest and common plugins:

```bash
pip install pytest pytest-asyncio pytest-cov pytest-xdist
```

Run tests:

```bash
pytest                          # run all tests
pytest tests/test_api.py        # run one file
pytest -k "test_login"          # run by name pattern
pytest -x                       # stop on first failure
pytest -v --tb=short            # verbose, short tracebacks
pytest -n auto                  # parallel (xdist)
pytest --cov=src                # with coverage
```

## Writing Tests

### Basic Tests

```python
import pytest

def test_addition():
    assert 1 + 1 == 2

def test_string_methods():
    s = "hello world"
    assert s.upper() == "HELLO WORLD"
    assert s.split() == ["hello", "world"]

def test_exception():
    with pytest.raises(ValueError, match="invalid"):
        raise ValueError("invalid input")
```

pytest uses plain `assert` statements. On failure, it shows detailed comparisons automatically.

### Parametrize

Run the same test with multiple inputs:

```python
@pytest.mark.parametrize("input,expected", [
    (1, 2),
    (2, 4),
    (3, 6),
    (0, 0),
    (-1, -2),
])
def test_double(input, expected):
    assert input * 2 == expected
```

Multiple parametrize decorators create a cross-product:

```python
@pytest.mark.parametrize("x", [1, 2])
@pytest.mark.parametrize("y", [10, 20])
def test_multiply(x, y):
    assert x * y > 0  # runs 4 times: (1,10), (1,20), (2,10), (2,20)
```

### Test Discovery

pytest finds tests automatically by convention:

- Files: `test_*.py` or `*_test.py`
- Functions: prefixed with `test_`
- Classes: prefixed with `Test` (no `__init__` method)
- Directory: defaults to current dir, configure with `testpaths`

## Fixtures

Fixtures provide reusable setup, teardown, and dependency injection.

### Basic Fixtures

```python
import pytest

@pytest.fixture
def sample_user():
    return {"id": 1, "name": "Alice", "email": "alice@example.com"}

def test_user_name(sample_user):
    assert sample_user["name"] == "Alice"

def test_user_email(sample_user):
    assert "@" in sample_user["email"]
```

### Yield Fixtures (Setup + Teardown)

```python
@pytest.fixture
def client():
    app = create_app(testing=True)
    with app.test_client() as client:
        yield client
    # teardown runs after yield

@pytest.fixture(scope="session")
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()
```

### Fixture Scopes

| Scope | Lifetime | Use Case |
|-------|----------|----------|
| `function` | Per test (default) | Mutable state, isolated setup |
| `class` | Per test class | Shared across methods in a class |
| `module` | Per test file | Expensive setup shared in a file |
| `package` | Per test package | Shared across a test directory |
| `session` | Entire test run | Database connections, server startup |

### Built-in Fixtures

```python
def test_temp_files(tmp_path):
    f = tmp_path / "data.txt"
    f.write_text("hello")
    assert f.read_text() == "hello"

def test_env_var(monkeypatch):
    monkeypatch.setenv("API_KEY", "test-key")
    assert os.environ["API_KEY"] == "test-key"

def test_output(capsys):
    print("hello")
    captured = capsys.readouterr()
    assert captured.out == "hello\n"
```

### conftest.py

Shared fixtures go in `conftest.py`. pytest loads it automatically -- no imports needed.

```python
# tests/conftest.py
import pytest

@pytest.fixture(autouse=True)
def clean_env(monkeypatch):
    """Reset environment for every test."""
    monkeypatch.setenv("ENV", "test")
    monkeypatch.delenv("API_KEY", raising=False)

@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}

@pytest.fixture
def mock_response():
    return {"status": "ok", "data": []}
```

Conftest files cascade: fixtures in `tests/conftest.py` are available to all tests; fixtures in `tests/api/conftest.py` are available only to tests in `tests/api/`.

## Async Testing

Install `pytest-asyncio` and mark async tests:

```python
import pytest
import httpx

@pytest.mark.asyncio
async def test_async_fetch():
    async with httpx.AsyncClient() as client:
        resp = await client.get("https://api.example.com/health")
        assert resp.status_code == 200

@pytest.mark.asyncio
async def test_concurrent_requests():
    async with httpx.AsyncClient() as client:
        responses = await asyncio.gather(
            client.get("https://api.example.com/a"),
            client.get("https://api.example.com/b"),
        )
        assert all(r.status_code == 200 for r in responses)
```

### Async Fixtures

```python
@pytest.fixture
async def async_client():
    async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
        yield client

@pytest.mark.asyncio
async def test_api(async_client):
    resp = await async_client.get("/api/items")
    assert resp.status_code == 200
```

### Auto Mode

Set `asyncio_mode = "auto"` in config to skip the `@pytest.mark.asyncio` decorator:

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

With auto mode, any `async def test_*` function is treated as an async test automatically.

## Mocking

Use `unittest.mock` from the standard library. It integrates well with pytest.

### Basic Mocking

```python
from unittest.mock import patch, MagicMock

def test_with_mock():
    with patch("myapp.services.fetch_data") as mock_fetch:
        mock_fetch.return_value = {"status": "ok"}
        result = process_data()
        assert result["status"] == "ok"
        mock_fetch.assert_called_once()

def test_mock_object():
    mock_db = MagicMock()
    mock_db.query.return_value = [{"id": 1}]
    results = get_users(db=mock_db)
    assert len(results) == 1
    mock_db.query.assert_called_once_with("SELECT * FROM users")
```

### Async Mocking

```python
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_async_service():
    mock_client = AsyncMock()
    mock_client.send.return_value = {"response": "hello"}
    result = await process(mock_client)
    assert result == "hello"
    mock_client.send.assert_awaited_once()

@pytest.mark.asyncio
async def test_patch_async():
    with patch("myapp.client.fetch", new_callable=AsyncMock) as mock_fetch:
        mock_fetch.return_value = {"data": [1, 2, 3]}
        result = await get_items()
        assert result == [1, 2, 3]
```

### Side Effects

```python
def test_side_effect_exception():
    with patch("myapp.api.call") as mock_call:
        mock_call.side_effect = ConnectionError("timeout")
        with pytest.raises(ConnectionError):
            make_request()

def test_side_effect_sequence():
    with patch("myapp.api.call") as mock_call:
        mock_call.side_effect = [{"page": 1}, {"page": 2}, StopIteration]
        assert make_request()["page"] == 1
        assert make_request()["page"] == 2
```

### Patch Decorator

```python
@patch("myapp.services.send_email")
@patch("myapp.services.fetch_user")
def test_registration(mock_fetch, mock_email):
    mock_fetch.return_value = None  # user doesn't exist
    mock_email.return_value = True
    result = register_user("alice@example.com")
    assert result.success
    mock_email.assert_called_once()
```

Note: when stacking `@patch` decorators, the bottommost decorator corresponds to the first argument.

### Patching Target

Patch where an object is looked up, not where it is defined:

```python
# myapp/services.py
from myapp.utils import send_email  # imported into services

# CORRECT: patch where it's used
@patch("myapp.services.send_email")

# WRONG: patching the original location won't affect the import
@patch("myapp.utils.send_email")
```

## Markers

### Custom Markers

Define markers in config and apply them to tests:

```python
@pytest.mark.slow
def test_heavy_computation():
    result = compute_large_dataset()
    assert result is not None

@pytest.mark.integration
def test_database_write():
    db.insert({"key": "value"})
    assert db.get("key") == "value"
```

Run or skip by marker:

```bash
pytest -m "not slow"            # skip slow tests
pytest -m "integration"         # only integration tests
pytest -m "not integration"     # skip integration tests
```

### Built-in Markers

```python
@pytest.mark.skip(reason="Not implemented yet")
def test_future_feature():
    ...

@pytest.mark.skipif(sys.platform == "win32", reason="Unix only")
def test_unix_permissions():
    ...

@pytest.mark.xfail(reason="Known bug #123")
def test_known_issue():
    ...
```

## Configuration

### pyproject.toml

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --tb=short --strict-markers"
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: integration tests requiring external services",
]
filterwarnings = [
    "error",
    "ignore::DeprecationWarning",
]
```

### Coverage Configuration

```toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/migrations/*"]

[tool.coverage.report]
fail_under = 80
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.",
]
```

Run coverage:

```bash
pytest --cov=src --cov-report=term-missing   # terminal report
pytest --cov=src --cov-report=html           # HTML report in htmlcov/
pytest --cov=src --cov-report=xml            # XML for CI tools
```

## unittest (Standard Library)

pytest runs `unittest.TestCase` subclasses, but for codebases that use unittest directly:

```python
import unittest

class TestMath(unittest.TestCase):
    def setUp(self):
        self.calc = Calculator()

    def test_add(self):
        self.assertEqual(self.calc.add(1, 2), 3)

    def test_divide_by_zero(self):
        with self.assertRaises(ZeroDivisionError):
            self.calc.divide(1, 0)

    def tearDown(self):
        self.calc.reset()

if __name__ == "__main__":
    unittest.main()
```

Key differences from pytest: use `self.assertEqual` instead of `assert`, use `setUp`/`tearDown` instead of fixtures, tests must be methods on a class.

## Edge Cases and Gotchas

- **Patch target**: Always patch where the name is looked up, not where it is defined. If `services.py` does `from utils import send_email`, patch `services.send_email`, not `utils.send_email`.
- **Fixture scope mismatch**: A function-scoped fixture cannot depend on a narrower scope. Broader scopes (session, module) can only use fixtures of equal or broader scope.
- **Async fixture cleanup**: Use `async with` and `yield` together carefully. Ensure async teardown completes before the event loop closes.
- **Parametrize IDs**: Use the `ids` parameter for readable test names: `@pytest.mark.parametrize("x", [1, 2], ids=["one", "two"])`.
- **conftest.py location**: Place in the test root. A conftest in the project root may interfere with installed packages.
- **Test isolation**: Tests should not depend on execution order. Use fixtures for state, not module-level variables.
- **Coverage with async**: `pytest-cov` works with async code but may undercount branches in heavily concurrent code. Use `--cov-branch` for branch coverage.

## Project Layout

```
project/
  pyproject.toml
  src/
    myapp/
      __init__.py
      services.py
      models.py
  tests/
    conftest.py           # shared fixtures
    test_services.py
    test_models.py
    integration/
      conftest.py         # integration-specific fixtures
      test_api.py
```
