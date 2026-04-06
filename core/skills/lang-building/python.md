# Python Implementation Patterns

Language-specific patterns for Python projects. Loaded by sw-build into agent context.

## Idioms

### Context Managers
- Use `with` statements for all resource management (files, connections, locks).
- Implement `__enter__` / `__exit__` or use `@contextmanager` decorator for custom resources.
- Prefer `contextlib.suppress(ExceptionType)` over bare `try/except/pass`.

### Type Hints
- Use type hints on all public functions. Use `from __future__ import annotations` for forward references.
- Prefer `str | None` over `Optional[str]` (Python 3.10+). Use `Union` only when supporting older versions.
- Use `TypeAlias` for complex types. Use `Protocol` for structural subtyping (duck typing with types).
- Use `TypeVar` for generics. Prefer `bound=` over unconstrained type vars.

### Decorators
- Use `@functools.wraps(fn)` in all decorator implementations to preserve metadata.
- Use `@property` for computed attributes that look like data access.
- Use `@classmethod` for alternative constructors, `@staticmethod` only when the method has no class/instance dependency.
- Use `@dataclass` or `@dataclass(frozen=True)` for data containers instead of manual `__init__`.

### Error Handling
- Raise specific exceptions, not bare `Exception`. Define domain exceptions inheriting from a base.
- Use `try/except` at the boundary, not around every operation. Let exceptions propagate naturally.
- Never catch `BaseException` — it swallows `KeyboardInterrupt` and `SystemExit`.
- Use `raise ... from err` to chain exceptions and preserve tracebacks.

## Type Patterns

- Use `dataclasses` or Pydantic `BaseModel` for structured data. Pydantic for validation at boundaries.
- Use `Enum` for fixed sets of values. Use `StrEnum` when string serialization matters.
- Use `TypedDict` for dictionary shapes at API boundaries. Use `NotRequired[]` for optional keys.
- Use `ABC` and `@abstractmethod` for interface contracts when duck typing is insufficient.

## Framework Conventions

### FastAPI
- Use dependency injection via `Depends()` for shared resources (database sessions, auth).
- Define request/response models as Pydantic `BaseModel`. Use `Field()` for validation.
- Use `HTTPException` with specific status codes. Define custom exception handlers for domain errors.
- Use `BackgroundTasks` for non-blocking side effects, not threads.

### Django
- Use model managers for query encapsulation. Avoid raw SQL unless performance-critical.
- Use `select_related()` and `prefetch_related()` to avoid N+1 queries.
- Use Django's `transaction.atomic()` for multi-step operations. Never mix ORM and raw SQL in the same transaction.
- Use `django.conf.settings` for configuration, never `os.environ` directly in app code.

### pytest
- Use fixtures for setup/teardown. Use `conftest.py` for shared fixtures.
- Use `@pytest.mark.parametrize` for data-driven tests. Use `@pytest.fixture(params=...)` for fixture variants.
- Use `tmp_path` fixture for temporary files. Use `monkeypatch` for environment and attribute patching.

## Anti-Patterns

- **Mutable default arguments**: Never `def f(items=[])`. Use `def f(items=None): items = items or []`.
- **Bare except**: Never `except:` — always catch specific exceptions.
- **Global imports side effects**: Never import modules that perform side effects (network calls, file I/O) at import time.
- **String formatting for SQL**: Never use f-strings or `.format()` for SQL queries. Use parameterized queries.
- **Circular imports**: Restructure modules to break cycles. Use `TYPE_CHECKING` guard for type-only imports.
- **Deep inheritance**: Prefer composition over deep class hierarchies. Use mixins sparingly.
