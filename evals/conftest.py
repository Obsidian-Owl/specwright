"""Pytest configuration for eval framework tests."""


def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line(
        "markers",
        "integration: marks tests that invoke real external processes (claude CLI, git). "
        "Skipped by default. Run with: pytest -m integration",
    )
