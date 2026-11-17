# Concurrency: structured lifetimes and deliberate parallelism

The theme from [immutability-and-state.md](immutability-and-state.md)
applies hardest here: concurrency bugs are the ones that only show up
once there are two of something running at once, and both `asyncio` and
`threading` give you sharp, specific ways to create exactly that
scenario if state isn't handled deliberately.

## Prefer `asyncio.TaskGroup` over `asyncio.gather`

Both run coroutines concurrently, but they fail differently, and the
difference matters. With `asyncio.gather(*aws)` (default settings), if
one awaitable raises, the exception propagates immediately — but the
*other* awaitables are **not** cancelled; they keep running in the
background, unobserved, until they finish or the process exits. That's
an orphaned task, not a clean failure.

```python
# One failure here doesn't stop the others — they keep running unattended.
results = await asyncio.gather(fetch_a(), fetch_b(), fetch_c())
```

`asyncio.TaskGroup` (3.11+) is structured concurrency: every task
created inside the `async with` block is scoped to that block and cannot
outlive it. If one task raises, the group cancels every other task in
the group, waits for them to actually finish cancelling, and only then
raises — as an `ExceptionGroup`/`BaseExceptionGroup` wrapping every error
that occurred, not just the first one:

```python
async def fetch_all() -> tuple[A, B, C]:
    async with asyncio.TaskGroup() as tg:
        task_a = tg.create_task(fetch_a())
        task_b = tg.create_task(fetch_b())
        task_c = tg.create_task(fetch_c())
    return task_a.result(), task_b.result(), task_c.result()
```

Handle the aggregated failure with `except*` instead of `except`, which
matches against the individual exception types inside the group:

```python
try:
    await fetch_all()
except* ConnectionError as eg:
    for exc in eg.exceptions:
        log.warning("fetch failed: %s", exc)
```

Pair `TaskGroup` with `asyncio.timeout()` (3.11+) for a cancellation
deadline that composes cleanly with the group, rather than wrapping
individual calls in `asyncio.wait_for`:

```python
async with asyncio.timeout(10), asyncio.TaskGroup() as tg:
    ...
```

Cancellation is cooperative: use `try/finally` for cleanup and normally
re-raise `CancelledError` after catching it. A timeout is not a hard kill
of synchronous or native work. On 3.15+, `TaskGroup.cancel()` also allows
explicit early termination; do not assume that method exists on 3.14.

## Never create a task and let go of it

`asyncio.create_task(coro())` returns a `Task`, and the event loop only
holds a *weak* reference to it. If nothing else holds a strong reference,
the task can be garbage-collected mid-execution — silently, with no
error. Even when a task does run to completion unobserved, an exception
it raised is only ever reported as a "Task exception was never
retrieved" warning logged at garbage-collection time, easy to miss in
practice. Either await it, put it in a `TaskGroup`, or keep an explicit
reference (commonly a module- or instance-level `set` that discards the
task via a done-callback) — a coroutine you fire and never track is a
bug waiting to be noticed only when it matters.

## Shared state still needs synchronization inside `asyncio`, at `await` points

A single-threaded event loop doesn't mean shared mutable state is safe by
default — a race is still possible any time two tasks can interleave
across an `await`. Reading a value, awaiting something, then writing the
value back leaves a window for another task to run in between:

```python
# Two tasks can both read the old value before either writes the new one.
async def increment() -> None:
    current = counter["value"]
    await something_that_yields()
    counter["value"] = current + 1
```

`asyncio.Lock` protects exactly this — a critical section that spans an
`await` — the same way `threading.Lock` protects a critical section
across threads:

```python
async def increment() -> None:
    async with _lock:
        current = counter["value"]
        await something_that_yields()
        counter["value"] = current + 1
```

If nothing in a critical section awaits, other tasks on that same event
loop cannot interleave with it. This is not protection from other
threads or reentrant callbacks. The moment an `await` is inside it,
assume task interleaving is possible. One event loop still runs on one
thread even with the GIL disabled; free-threading does not make its tasks
automatically execute on multiple cores.

## Offload blocking work; choose CPU execution explicitly

Threads work well for blocking I/O you cannot make async. For CPU-bound
Python, the runtime matters: threads in one GIL-enabled interpreter
serialize Python bytecode; threads in a free-threaded interpreter with
the GIL disabled can execute it on multiple cores. Native libraries can
also release the GIL. Do not turn a constraint of one configuration into
a blanket claim about Python.

Bridging a blocking call *from* async code: prefer `asyncio.to_thread`
over managing an executor by hand — it's the direct, modern way to run a
blocking function without stalling the event loop:

```python
result = await asyncio.to_thread(blocking_call, arg)
```

`to_thread` propagates the caller's `ContextVar` context. Cancelling its
await does **not** stop a function already running in a worker thread.
For long-running work, own its lifetime, use a cooperative stop signal,
and arrange shutdown; a surrounding `TaskGroup` does not join an
otherwise untracked worker function when its awaiting task is cancelled.

Running a pool of threads from sync code: use
`concurrent.futures.ThreadPoolExecutor` as a context manager so shutdown
is guaranteed, rather than creating and forgetting to join threads by
hand:

```python
with ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(blocking_call, items))
```

For CPU work, choose among free-threaded threads, own-GIL
`InterpreterPoolExecutor` (3.14+), and `ProcessPoolExecutor` deliberately.
Their sharing, extension-compatibility, serialization, and crash
boundaries differ. Read [runtime-parallelism.md](runtime-parallelism.md)
before selecting one or claiming scalability.

Bound outstanding work as well as worker count. In 3.14+,
`Executor.map(..., buffersize=...)` limits submitted work whose results
have not been yielded; the default still eagerly collects input.
Executor context managers wait for running work on exit, but do not
provide TaskGroup-style sibling cancellation. A future's cancellation
or timeout does not terminate a running call.

For process pools, use importable module-level callables, picklable
arguments/results, and an `if __name__ == "__main__":` entry guard.
In 3.14, `fork` is no longer the default start method anywhere: supported
POSIX systems normally use `forkserver`, while Windows/macOS use `spawn`.
Do not depend on inherited mutable globals or request `fork` merely to
hide initialization bugs in a multithreaded process. See the
[process-pool docs](https://docs.python.org/3.14/library/concurrent.futures.html#processpoolexecutor).

## Locking: same rule as everywhere else — isolate first, lock second

Everything in [immutability-and-state.md](immutability-and-state.md)
about preferring isolated, per-instance state over a shared mutable
global applies here without modification: a lock (`threading.Lock`,
`asyncio.Lock`) is for state that's genuinely shared on purpose, not a
patch for state that should have been constructed per-task or
per-instance in the first place. When a lock is the right tool, always
acquire it through the context-manager form (`with lock:` /
`async with lock:`) so it releases even if the critical section raises —
manual `acquire()`/`release()` pairs are one raised exception away from
a permanently held lock.

Finally, don't reach for `queue.Queue` (thread-safe, blocking) and
`asyncio.Queue` (async-safe, not thread-safe) interchangeably — mixing a
thread and a coroutine through the wrong one of these is a common source
of either a deadlock or a lock that silently does nothing. Handing data
from a thread into the event loop needs `loop.call_soon_threadsafe` or
`asyncio.run_coroutine_threadsafe`, not a plain `asyncio.Queue.put`
called from off the event loop's thread.
