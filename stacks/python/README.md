# Python

The gate:

```bash
ruff check . && ruff format --check . && python -m pytest -q
```

- **Ruff for lint and format.** One fast tool. See `ruff.toml`.
- **Types:** run a type checker (`pyright` or `mypy --strict`) on new packages from the first commit.
  Adding it later to untyped code is slow; put it in `check.sh` only when it passes.
- **A suppression carries its reason:** `# noqa: E501 - URL` and `# type: ignore[arg-type]  # reason`.
  Ruff's `PGH003` and `PGH004` reject the bare forms.
- **No network in unit tests.** Mark the tests that need a service and leave them out of the gate.
- **Settings are parsed once,** into a frozen dataclass, at start-up. Code below that takes the
  object, not `os.environ`.
