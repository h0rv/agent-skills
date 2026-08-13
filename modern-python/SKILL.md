---
name: modern-python
description: Write and review modern Python 3.13+ with correctness enforced by the type checker and linter. Use whenever writing, refactoring, reviewing, or designing Python code, data models, config objects, public APIs, async code, or tests, including quick scripts. Covers parse-don't-validate, illegal states, sentinels for overloaded None, exhaustive matching, TypeIs and TypeGuard, avoiding casts and dynamic attribute access, dataclasses versus Pydantic and NamedTuple, immutable state, structured concurrency, test strategy, API design, and the uv, ruff, and ty toolchain. This is a hub. Read the linked reference for the topic in play.
---

# Modern Python: correct by construction

The throughline: push every check you can out of runtime and into the type
checker and linter, so a whole class of bug can't be constructed in the
first place, rather than being caught (or missed) later. `cast(...)`,
`# type: ignore`, `getattr`/`hasattr`/`setattr` as a substitute for a real
type, and a defensive `if` guarding a state your own types already rule out
are all the same signal: a type is wrong or missing somewhere upstream. Fix
the type; don't paper over it.

This is a design philosophy, not a linter config — apply the reasoning
behind each reference below to the situation in front of you rather than
pattern-matching the examples literally.

## How to use this skill

This file is a router, not the content. It stays small on purpose so it
doesn't crowd out the actual task — read only the reference file(s) that
match what you're doing right now:

| When you're... | Read |
|---|---|
| Setting up a project, choosing lint/type-check tooling, or seeing a `pip`/`venv`/`black`/`mypy` command | [references/tooling.md](references/tooling.md) — uv, ruff, ty |
| Turning raw input (a dict, JSON, a config file, a request body) into something you can trust | [references/parse-dont-validate.md](references/parse-dont-validate.md) |
| Modeling a value, a record, or a config shape — or choosing dataclass vs. Pydantic vs. NamedTuple vs. TypedDict | [references/data-modeling.md](references/data-modeling.md) |
| A `None`, a magic string/int, or a bool pair means more than one thing | [references/sentinels.md](references/sentinels.md) |
| Modeling a closed set of cases, or writing an `if/elif`/`match` over one | [references/exhaustiveness.md](references/exhaustiveness.md) — typestate, discriminated unions, `assert_never` |
| About to write `cast(...)`, `# type: ignore`, `getattr`, `hasattr`, or `setattr` | [references/type-narrowing.md](references/type-narrowing.md) |
| Deciding whether something should mutate, or noticing a module-level/global/shared value | [references/immutability-and-state.md](references/immutability-and-state.md) |
| Writing a long `if`/`elif` chain or wondering whether a check is still needed | [references/control-flow.md](references/control-flow.md) |
| Designing a function signature, class, or public module surface | [references/api-design.md](references/api-design.md) |
| Writing `asyncio` code, spawning tasks, or reaching for `threading`/`multiprocessing` | [references/concurrency.md](references/concurrency.md) |
| Deciding what still needs a test given how much the type checker already covers | [references/testing.md](references/testing.md) |
| Wondering if there's a more direct modern stdlib/typing way to write something | [references/language-features.md](references/language-features.md) |

## Quick self-check

Enough to hold in your head while coding; the references above are where
each of these unpacks into detail and examples.

- **Is this a boundary?** (external input, a config file, a `dict` from
  `json.loads`) → parse it into a real type once, immediately — don't let
  a raw dict or `Any` travel any further than the point where you first
  touched it. → parse-dont-validate.md
- **Does this `None`, `-1`, or `"unknown"` mean more than one thing here?**
  → it needs a sentinel or a proper type, not another `is None` check three
  call sites downstream. → sentinels.md
- **Is this a dict/tuple/bool-pair two or more places already agree on the
  shape of?** → give it a name. → data-modeling.md
- **Is this `if`/`elif` chain (or bool pair) actually a small closed set of
  cases?** → name them and `match` with `assert_never` at the end. →
  exhaustiveness.md
- **Am I about to write `cast(...)`, `# type: ignore`, `getattr(...)`, or
  `hasattr(...)`?** → that's the type checker telling you the shape is
  wrong, not a formality to silence. → type-narrowing.md
- **Does this function mutate something the caller can still see
  afterward, or touch module/global state?** → decide on purpose, name it
  so it's visible, and be suspicious of anything shared. →
  immutability-and-state.md
- **Am I adding a parameter, alias, or fallback for a caller that doesn't
  exist yet?** → api-design.md
- **Am I firing off a task with `asyncio.gather`/`create_task`, or reaching
  for a thread/lock?** → make sure failure and cancellation are structured,
  not orphaned. → concurrency.md
- **Have I pushed everything I can into the type checker — what's left
  that actually needs a test?** → boundary parsers, runtime invariants,
  and behavior, not shape. → testing.md

These compound: a value modeled as the right type usually also becomes
immutable, exhaustively handled, and safe from shared-state bugs, almost
for free.
