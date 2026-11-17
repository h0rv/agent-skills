# Reach for these first, within the project's Python version

A quick-reference table — pull this up when reaching for an older idiom
and wondering if there's now a more direct way to say it.

The skill's baseline is 3.13+. Features below carry a minimum version
where newer; do not silently raise a library's minimum Python version.
Check type-checker/stub support as well as runtime availability.

## Baseline idioms

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
| `functools.cached_property` | Memoizing a property on the instance, not exactly-once initialization under concurrency — requires an instance `__dict__`; for slotted dataclasses, compute and store eagerly (see [data-modeling.md](data-modeling.md)) |
| `match`/`case` | Structural destructuring plus exhaustiveness, in place of `isinstance` chains — see [exhaustiveness.md](exhaustiveness.md) and [control-flow.md](control-flow.md) |
| `X | None` | Over `Optional[X]` — same meaning, no import, and reads left-to-right |
| `list[X]`, `dict[K, V]` | Over `List[X]`, `Dict[K, V]` from `typing` — the builtins have supported generics since 3.9 |

`ruff`'s `UP` (pyupgrade) rule set nudges code toward most of this
automatically — see [tooling.md](tooling.md).

## Python 3.14

| Feature | Use it for / constraint |
|---|---|
| Deferred annotations; `annotationlib` (PEPs 649/749) | Forward references without quoted annotations by default. `from __future__ import annotations` retains stringized behavior; use `annotationlib.get_annotations` with an intentional format for introspection. Evaluating annotations can execute code; this is not safe parsing of untrusted annotations. |
| Template strings, `t"..."` (PEP 750) | Passing a structured template to a processor that controls interpolation. They produce `string.templatelib.Template`, not `str`, and do not escape SQL/HTML automatically. Keep parameterized SQL and the framework's escaping. |
| Supported optional free-threading; `InterpreterPoolExecutor`; `concurrent.interpreters` | CPU parallelism with different ownership contracts, not automatic multicore `asyncio` — see [runtime-parallelism.md](runtime-parallelism.md). |
| `Thread(context=...)`; context-aware warning filters | Explicit context propagation and safe warning capture; defaults differ between conventional and free-threaded builds — see [runtime-parallelism.md](runtime-parallelism.md). |
| `Executor.map(..., buffersize=...)` | Bounding outstanding work/results, not just worker count — see [concurrency.md](concurrency.md). |
| `map(..., strict=True)` | Rejecting mismatched iterable lengths, like `zip(..., strict=True)`; the mismatch is detected during consumption. |
| `compression.zstd` | Zstandard compression through the stdlib; check availability on the deployed build. |

See the [3.14 release notes](https://docs.python.org/3.14/whatsnew/3.14.html)
and their porting section, especially the process start-method change.

## Python 3.15

| Feature | Use it for / constraint |
|---|---|
| Built-in `sentinel` (PEP 661) | Named identity markers with typing support; pickling requires an importable module/name — see [sentinels.md](sentinels.md). |
| Built-in `frozendict` (PEP 814) | An immutable mapping, not a `dict` subclass. Contents are not recursively frozen; hashability requires hashable keys/values. Accept `Mapping` in read-only APIs rather than assuming concrete `dict`. |
| `TypedDict(closed=True)` / `extra_items=...` (PEP 728) | Statically describing forbidden or typed extra keys; still not a runtime parser/validator. |
| `typing.TypeForm` (PEP 747) | Typing APIs that accept type expressions, including unions and parameterized types, rather than only class objects (`type[T]`). It does not validate data by itself. |
| UTF-8 default (PEP 686) | Predictable default text encoding; still specify `encoding=` for a file/protocol contract, especially for locale-encoded legacy data. |
| Unpacking in comprehensions (PEP 798) | Direct flattening such as `[*group for group in groups]`; use when clearer than nested `for` clauses, not just because it is new. |
| `asyncio.TaskGroup.cancel()` | Explicit early termination of owned tasks — cancellation remains cooperative. |
| `abi3t`; interpreter finalization/attachment APIs (PEPs 803/788) | Native-extension and embedding work — see [runtime-parallelism.md](runtime-parallelism.md); not automatic wheel compatibility. |
| `profiling.sampling` (PEP 799); upgraded experimental JIT | Sampling real workloads and evaluating an optional performance feature. JIT availability/state and GIL state are separate; do not promise a speedup or assume both configurations can be combined on the target build. |

3.15 also adds explicit lazy imports (PEP 810). Their availability is not
a reason to defer imports: prefer ordinary static, eager imports, and fix
cycles through module boundaries rather than lazy loading or string-named
lookups. Deferral changes initialization, failure timing, and the thread
that first executes a module's code.

See the [3.15 release notes](https://docs.python.org/3.15/whatsnew/3.15.html)
and the versioned API docs before adopting a feature; a PEP alone is not
evidence of the final shipped interface.
