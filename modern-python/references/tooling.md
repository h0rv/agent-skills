# Tooling: uv, ruff, ty

Three Rust-based tools, one per job, all fast enough to run on every save
instead of in CI only. Default to this stack for any Python 3.13+ project
unless the project has already standardized on something else — don't mix
in `pip`, `poetry`, `black`, `isort`, `flake8`, or `mypy` alongside them;
each one fully replaces a whole category of older tool, and running both
is wasted config surface and a way for the two to disagree.

## uv — packaging, virtualenvs, Python versions

`uv` replaces `pip`, `pip-tools`, `virtualenv`, `pyenv`, and `poetry`'s
dependency-management role with one tool and one lockfile.

```bash
uv init                      # new project: pyproject.toml + .venv
uv add requests               # add a runtime dependency, updates pyproject.toml + uv.lock
uv add --dev pytest ruff       # add a dev-only dependency
uv remove requests
uv sync                        # install exactly what uv.lock pins, into .venv
uv lock                        # recompute the lockfile after editing pyproject.toml by hand
uv run pytest                  # run inside the project's venv without activating it
uv run python -m mymodule
uv python install 3.13         # manage Python interpreters themselves, not just packages
uv tool install ruff            # install a CLI tool into an isolated env (like pipx)
```

Never `pip install` directly into a `uv`-managed project's venv — it
won't update `uv.lock`, so the next `uv sync` on another machine (or CI)
can silently diverge from what you actually tested against. If a
dependency needs to change, express it through `uv add`/`uv remove` (or
edit `pyproject.toml` and re-run `uv lock`) so the lockfile stays the
single source of truth. Likewise, don't invoke a bare `python script.py`
in a project with a `uv`-managed venv — `uv run script.py` guarantees
you're running against the locked environment rather than whatever
`python` happens to resolve to on `$PATH`.

`pyproject.toml` is the only file to hand-edit; `uv.lock` is generated,
commit it but don't edit it directly.

### `uvx` — run a tool without installing it, like `npx`

`uvx <tool>` (shorthand for `uv tool run <tool>`) runs a CLI tool in a
throwaway, isolated environment built just for that invocation — the
same role `npx` plays for the Node ecosystem. Nothing is added to the
current project, and nothing needs to be pre-installed:

```bash
uvx ruff check .          # run ruff once, even if it isn't installed anywhere
uvx cowsay -t "hi"        # try a tool without polluting any environment
uvx --from black black .  # when the PyPI package name and the command name differ
```

Reach for `uv tool install <tool>` instead (see the `uv tool install`
example above) when a tool is used often enough that paying the resolve
cost on every invocation isn't worth it — `uvx` is for occasional or
one-off use, a persistent `uv tool install` is for something reached for
daily.

### Inline script metadata (PEP 723) — a shareable script with its own dependencies

A single `.py` file can declare its own dependencies in a structured
comment block, so anyone with `uv` installed can run it with zero setup —
no `requirements.txt`, no virtualenv to create by hand, no project to
clone:

```python
# /// script
# requires-python = ">=3.13"
# dependencies = ["requests<3", "rich"]
# ///

import requests
from rich import print

print(requests.get("https://example.com").status_code)
```

`uv add --script my_script.py requests` manages that block for you
(adding/removing/pinning dependencies) rather than hand-editing the
comment. Running it is the same either way:

```bash
uv run my_script.py
```

`uv run` reads the metadata, builds an ephemeral, isolated environment
with exactly those dependencies (cached for reuse across runs of the same
script), and executes the script in it — the recipient never needs to
know or care what's installed globally. A script like this can even be
made directly executable with a shebang, so `./my_script.py` alone does
the right thing on a machine with `uv` on `PATH`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["requests<3"]
# ///
...
```

This is the right tool for a one-off utility, a reproducible repro
case, or anything meant to be copy-pasted and just work — reach for a
full project (`uv init`) once there's more than one file or the
dependencies are shared across scripts.

## ruff — lint and format

`ruff` replaces `flake8` (+ most of its plugin ecosystem), `isort`, and
`black`, implemented in Rust and fast enough to run as a save-on-format
hook rather than a pre-commit-only gate.

```bash
ruff check .              # lint
ruff check . --fix        # lint and auto-fix what's safely fixable
ruff format .             # format (black-compatible output by default)
```

Minimal `pyproject.toml` starting point — enable more rule groups as the
codebase can absorb them, rather than turning everything on at once and
drowning in noise:

```toml
[tool.ruff]
target-version = "py313"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B", "SIM", "RUF"]
# E/F: pyflakes+pycodestyle core, I: import sorting, UP: pyupgrade
# (modernize syntax), B: bugbear (common bug patterns), SIM: simplify,
# RUF: ruff's own additional checks
```

`UP` (pyupgrade) is worth calling out specifically: it's what nudges old
code toward the 3.12+ features this skill's other references assume —
`X | None` over `Optional[X]`, `list[str]` over `List[str]`, `type X = ...`
over `TypeAlias`, and so on.

## ty — type checking

`ty` (Astral's type checker, same team as `ruff` and `uv`) is a fast,
actively-developing option for the same role `mypy --strict` or
`pyright --strict` play — a real type checker only earns the rest of
this skill's philosophy (`assert_never` exhaustiveness, `TypeIs`
narrowing, "no `cast`" as a real goal) when one is actually run and its
output is treated as blocking, not advisory. Whichever checker a project
uses, run it continuously rather than as a pre-commit afterthought, and
let a hard-to-satisfy type error be a signal to reshape the data (see
[parse-dont-validate.md](parse-dont-validate.md)) rather than an obstacle
to route around.

```bash
ty check                  # type-check the project
```

Because `ty` is newer and still evolving faster than `mypy`/`pyright`,
double-check its current suppression-comment syntax and rule names
against its own docs rather than assuming they're stable long-term — the
principle in [type-narrowing.md](type-narrowing.md) (scope every
suppression to the exact line and rule, never a bare or file-level
ignore) applies regardless of which checker's exact syntax that ends up
being.

## Enforcing `uv`-only workflows

If your harness supports intercepting or blocking tool invocations
before they run, it's worth blocking direct `pip install`, `pip3 install`, `python -m pip`, and bare `python <script>` in a
`uv`-managed project (one with a `uv.lock` or `[tool.uv]` in
`pyproject.toml`), redirecting to `uv add`/`uv run` instead — that keeps
an agent (or a human out of habit) from silently drifting a project's
environment out of sync with its lockfile. This is a harness-level
configuration concern rather than something these instructions can
enforce on their own; check whatever interception mechanism your
particular harness provides.
