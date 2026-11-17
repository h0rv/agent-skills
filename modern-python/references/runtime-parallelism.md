# CPU parallelism: choose the runtime, then the ownership model

The GIL is a property of an interpreter configuration, not an inherent
limit of Python. Free-threading and an own-GIL subinterpreter solve
different problems. Neither makes shared application state correct by
construction: types describe values, not which thread owns them.

Read [concurrency.md](concurrency.md) for task lifetimes, cancellation,
and async/thread handoffs. Use this reference when choosing or debugging
CPU execution, native extensions, or embedding.

## Keep the execution boundaries separate

| Execution model | CPU-bound Python bytecode | State and failure boundary |
|---|---|---|
| One `asyncio` loop on one thread | One thread executes callbacks/tasks, even on a free-threaded build | Tasks share interpreter state; `await` permits interleaving |
| Threads in one GIL-enabled interpreter | Serialized by that interpreter's GIL; native code that releases it can still parallelize | Shared Python objects and process; explicit synchronization |
| Threads in one free-threaded interpreter, GIL disabled | Can run on multiple cores | Shared Python objects and process; races and contention remain |
| Own-GIL interpreters on separate threads | Can run on multiple cores without a free-threaded build | Separate Python runtime/module state; same OS process and native-crash boundary |
| Separate processes | Can run on multiple cores | Separate address spaces; serialization/IPC and startup costs; a worker crash can still break its pool |

An interpreter is an execution context, not a thread. Creating one does
not schedule concurrent work. A thread is not an event loop, and a
subinterpreter is neither a security sandbox nor native-crash isolation.
None of these choices supplies distribution, durable work, or retries.

## Version and build are part of the contract

| CPython | Relevant support |
|---|---|
| 3.13 | Experimental optional free-threaded build (PEP 703) |
| 3.14 | Free-threading is officially supported (PEP 779), still optional and not the default build; `InterpreterPoolExecutor` and `concurrent.interpreters` enter the stdlib |
| 3.15 | Free-threading remains a distinct build; adds the `abi3t` Stable ABI and C APIs protecting interpreter attachment/finalization |

Own-GIL interpreter configuration has existed in the C API since 3.12
(PEP 684); the high-level Python APIs above require 3.14. Do not translate
"supported" into "every dependency works" or "every workload is faster."
Confirm the target minor/patch version and the project's supported range
before using a newer API. See the versioned [3.14 release notes][new314]
and [3.15 release notes][new315], not recollection of a pre-release PEP.

## Verify live GIL state after the application's imports

Build capability and current execution mode are separate facts. For
CPython 3.13+, run this in the actual application process, after its
normal dependency imports (and again after any later plugin imports):

```python
import sys
import sysconfig

print(sys.version)
print("free-threaded build:", sysconfig.get_config_var("Py_GIL_DISABLED") == 1)
print("GIL enabled now:", sys._is_gil_enabled())
```

`python -VV` also identifies the build. A `3.14t`/`3.15t` executable or a
`cp314t`/`cp315t` wheel tag indicates a free-threaded build, **not** proof
that the GIL is disabled. An unsupported C extension can enable the GIL
at import time with a warning. `PYTHON_GIL=1` / `-X gil=1` can enable it
explicitly. `PYTHON_GIL=0` / `-X gil=0` can force it to stay disabled on a
free-threaded build, but do not make an unsafe extension safe. Do not
suppress the warning or force no-GIL as a compatibility fix. The runtime
flag cannot turn a conventional build into a free-threaded one.

Use separate environments and matching native artifacts for conventional
and free-threaded builds. With uv, select explicitly, for example
`uv python install 3.14t` and `uv run --python 3.14t ...`; pin the patch
version for a reproducible comparison. Check transitive native
dependencies too. Ordinary `abi3` extensions are not interchangeable with
free-threaded binaries. In 3.15, `abi3t` is a separate Stable ABI requiring
an intentional migration, not automatic compatibility for old wheels.
See the [free-threading HOWTO][free-threading] and [Stable ABI docs][abi].

## Shared memory: isolate first, synchronize the invariant second

Prefer worker-local mutable state and immutable messages/results. Frozen
dataclasses, tuples, and 3.15's `frozendict` are only shallowly immutable:
their contents can still reference mutable objects. `Final` is a static
rebinding restriction, not a lock or runtime immutability.

Built-in container locking protects the container's integrity, not an
application transaction. `counts[key] += 1`, check-then-insert, and
read/compute/write sequences need a lock covering the whole invariant,
even if individual operations are documented as atomic. This applies
with the GIL too: callbacks and native calls can release it. Do not infer
correctness from bytecode inspection or from a race not reproducing.

Other traps worth checking explicitly:

- Do not hand one iterator or generator to several workers for concurrent
  `next()` calls; partition input or use a synchronized queue.
- `functools.cache`/`lru_cache` keep cache structures coherent but may
  compute the same miss concurrently. `cached_property` does not promise
  exactly-once evaluation; since 3.12 it has no internal getter lock.
  Put synchronization around non-idempotent initialization, or do it
  before publishing the object.
- Do not inspect another running thread's `frame.f_locals`; the
  free-threading HOWTO warns this can crash the interpreter.
- In 3.14+, `Thread(context=...)` makes `ContextVar` propagation explicit.
  Free-threaded builds default to inheriting context; conventional builds
  default to an empty context. Use `context=Context()` for no inheritance
  or a fresh `copy_context()` for each thread when inheritance is wanted.
  A context copy does not deep-copy mutable values held by its variables.
- `warnings.catch_warnings()` is concurrency-safe only with
  `context_aware_warnings` enabled (default on free-threaded builds, off
  on conventional builds). Do not assume identical defaults across builds.

Use `threading.Lock` for cross-thread invariants, not `asyncio.Lock`.
Keep critical sections short and define a consistent lock order. Check
the exact release's [thread-safety guarantees][thread-safety] rather than
generalizing a guarantee for one container operation to all operations.

## Own-GIL interpreters: isolation is the benefit and the constraint

For independent CPU jobs on 3.14+, consider
`concurrent.futures.InterpreterPoolExecutor`: each worker thread runs in
its own interpreter with its own GIL. Imports, module globals, and
initialization are per interpreter. A global cache or singleton in the
caller is not the worker's cache or singleton.

The executor pickles the callable, arguments, results, and initializer
data. Use importable module-level functions and serializable values,
not closures, live event loops, locks, or interpreter-local object
handles. Budget for imports, initialization, and serialization; batch
small jobs. Never deserialize untrusted pickle data.

The lower-level `concurrent.interpreters` API also offers explicit
interpreter lifetimes and cross-interpreter queues. Its transfer rules
are not identical to the executor's: some immutable values are shared or
copied efficiently, and `memoryview` can expose shared mutable backing
memory. Deliberate sharing still needs a protocol and synchronization.
Bound queues and close/join owned resources; creating an interpreter
alone does not create a worker thread.

**Free-threading support and subinterpreter support are independent
extension contracts.** Test imports and real calls inside the target
interpreter. A package working on `3.14t` in the main interpreter says
nothing about its support for own-GIL subinterpreters. If it rejects the
mode, report that incompatibility; do not silently run in a different
mode. Prefer processes when the required dependency cannot meet the
interpreter contract or a separate address space is necessary.

See [InterpreterPoolExecutor][executors] and
[concurrent.interpreters][interpreters] for the distinct APIs.

## Native extensions and embedded runtimes

Declaring support is the *last* step of an audit, not the fix itself.
For extension work, read the [free-threading C API guide][extensions]:

- Audit native globals, caches, callback lifetimes, and borrowed
  references into concurrently mutable containers. Use strong-reference
  APIs such as `PyList_GetItemRef` / `PyDict_GetItemRef` where appropriate.
  Direct struct access and unchecked macros do not acquire locks.
- A free-threading declaration (`Py_mod_gil` / `Py_MOD_GIL_NOT_USED`) is
  separate from per-interpreter-GIL support
  (`Py_mod_multiple_interpreters` /
  `Py_MOD_PER_INTERPRETER_GIL_SUPPORTED`). Multi-phase initialization and
  per-module state help avoid accidental process-global Python objects.
- No GIL does not mean no thread state: native threads must attach to the
  intended interpreter before calling the Python C API and detach around
  blocking work. `PyGILState_Ensure` assumes the main interpreter; it is
  not a generic subinterpreter-attachment API.
- Coordinate shutdown with native callers and callbacks before deleting
  interpreters. 3.15 adds interpreter guards/views and attachment APIs
  protecting against finalization (PEP 788); it soft-deprecates the
  `PyGILState` family. Follow the target version's [thread-state and
  finalization APIs][thread-state] rather than copying a 3.14 embedding
  recipe into 3.15 unchanged.

## Measure the workload, not just the absence of the GIL

Free-threading still has object locks, allocation/GC costs, reference
count traffic, and memory-bandwidth limits. Immutable is not synonymous
with contention-free: threads reading the same mortal Python object can
contend on its reference count. Single-thread overhead and increased
memory use can outweigh parallel gains.

In particular, **code-loading paths can change a CPU microbenchmark**.
In CPython 3.14, explicit `compile()` suppresses code-constant
immortalization; [`runpy.run_path()`][run-path] can use this path. Cold source loads
and cached `.pyc` loads can therefore differ. A shared numeric literal
used in a hot loop may create refcount contention; assigning that literal
to a local variable does not create a worker-owned object. Compare the
real loader and cache state before blaming a scheduler or adding locks.
This is a version-specific implementation detail, not a Python language
guarantee; recheck it on 3.15 and later. Do not ship a marshal round-trip
or private immortalization API as a runtime workaround. See the
[3.14 compiler path][compile-path], [constant handling][constants], and
[gh-130851 history][constant-issue].

For acceptance, record the exact interpreter version/build, live GIL
state after imports, dependency/native build versions, CPU quota/affinity,
worker count, input size, and loader/cache state. Compare one worker
against several on the same build, then conventional against
free-threaded builds. Separate startup/import/serialization from steady
state; report wall time, per-worker `time.thread_time()`, throughput,
latency, and memory. Watch native libraries' own thread pools for
oversubscription. An overlap timestamp or aggregate CPU figure alone
does not establish a throughput improvement.

Test correctness separately: use barriers/events to arrange competing
operations, not sleeps; check lost updates, context leakage, failure
propagation, cancellation, and shutdown. Run in every supported mode,
including actual dependency calls, not only an empty interpreter probe.
A green type checker, one stress run, or a fast microbenchmark is not a
thread-safety proof or full application compatibility.

[new314]: https://docs.python.org/3.14/whatsnew/3.14.html
[new315]: https://docs.python.org/3.15/whatsnew/3.15.html
[free-threading]: https://docs.python.org/3.14/howto/free-threading-python.html
[abi]: https://docs.python.org/3.15/c-api/stable.html
[thread-safety]: https://docs.python.org/3.14/library/threadsafety.html
[executors]: https://docs.python.org/3.14/library/concurrent.futures.html#interpreterpoolexecutor
[interpreters]: https://docs.python.org/3.14/library/concurrent.interpreters.html
[extensions]: https://docs.python.org/3.14/howto/free-threading-extensions.html
[thread-state]: https://docs.python.org/3.15/c-api/init.html
[compile-path]: https://github.com/python/cpython/blob/v3.14.10/Python/bltinmodule.c
[constants]: https://github.com/python/cpython/blob/v3.14.10/Objects/codeobject.c
[run-path]: https://github.com/python/cpython/blob/v3.14.10/Lib/runpy.py
[constant-issue]: https://github.com/python/cpython/issues/130851
