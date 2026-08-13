# Reach for these first (Python 3.12+)

A quick-reference table — pull this up when reaching for an older idiom
and wondering if there's now a more direct way to say it.

| Feature | Use it for |
|---|---|
| `type X = ...` (PEP 695) | Type aliases, including generic ones (`type Pair[T] = tuple[T, T]`) — replaces `TypeAlias` |
| `class Box[T]: ...` / `def first[T](...)` (PEP 695) | Generic classes/functions without importing `TypeVar` |
| `Self` | Methods that return an instance of the calling class (builders, `__enter__`, fluent APIs) |
| `@typing.override` | Marking a method as intentionally overriding a base class — catches typos when the base signature changes |
| `typing.assert_never` | Exhaustiveness checking — see [exhaustiveness.md](exhaustiveness.md) |
| `TypeIs` (PEP 742, 3.13) | Symmetric type narrowing — see [type-narrowing.md](type-narrowing.md) |
| `enum.StrEnum` | String enums without the `class X(str, Enum)` double-inheritance dance |
| `asyncio.TaskGroup` / `asyncio.timeout` (3.11+) | Structured concurrency — over `asyncio.gather`/`wait_for` — see [concurrency.md](concurrency.md) |
| `except*` / `ExceptionGroup` | Handling multiple concurrent failures individually instead of only the first — see [concurrency.md](concurrency.md) |
| `asyncio.to_thread` | Running a blocking call from async code without stalling the event loop — see [concurrency.md](concurrency.md) |
| `tomllib` | Reading TOML config from the stdlib, no dependency needed |
| `Annotated[T, ...]` | Attaching validation/metadata to a type without a wrapper class (Pydantic `Field`, dependency-injection markers) |
| `dataclasses.KW_ONLY` | Forcing keyword-only fields partway through a dataclass without a `*` splitting inheritance awkwardly |
| `functools.cached_property` | A property computed once and memoized on the instance — requires an instance `__dict__`; for slotted dataclasses, keep `__dict__` or compute and store the value eagerly (see [data-modeling.md](data-modeling.md)) |
| `match`/`case` | Structural destructuring plus exhaustiveness, in place of `isinstance` chains — see [exhaustiveness.md](exhaustiveness.md) and [control-flow.md](control-flow.md) |
| `X | None` | Over `Optional[X]` — same meaning, no import, and reads left-to-right |
| `list[X]`, `dict[K, V]` | Over `List[X]`, `Dict[K, V]` from `typing` — the builtins have supported generics since 3.9 |

`ruff`'s `UP` (pyupgrade) rule set nudges code toward most of this
automatically — see [tooling.md](tooling.md).
