# Concurrency: structured async, and threading when sync is required

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

If nothing in a critical section awaits, no lock is needed — the event
loop can't switch tasks mid-block. The moment an `await` is inside it,
assume interleaving is possible.

## Threading and multiprocessing, for when sync code is what you have

Plain CPython threads don't give parallelism for CPU-bound pure-Python
code — the GIL means only one thread runs Python bytecode at a time —
but they're the right tool for I/O-bound blocking work you can't easily
make async (a blocking third-party client library, blocking file I/O).

Bridging a blocking call *from* async code: prefer `asyncio.to_thread`
over managing an executor by hand — it's the direct, modern way to run a
blocking function without stalling the event loop:

```python
result = await asyncio.to_thread(blocking_call, arg)
```

Running a pool of threads from sync code: use
`concurrent.futures.ThreadPoolExecutor` as a context manager so shutdown
is guaranteed, rather than creating and forgetting to join threads by
hand:

```python
with ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(blocking_call, items))
```

For genuine CPU-bound parallelism, threads don't help — reach for
`concurrent.futures.ProcessPoolExecutor` or `multiprocessing` instead,
and budget for the real costs that come with it: arguments and results
must be picklable, and process startup plus inter-process data transfer
carries real overhead, so it pays off for chunky work, not many tiny
calls. Free-threaded CPython (PEP 703, an optional build without the
GIL) is a newer option that removes the GIL's constraint on
thread-based CPU parallelism — it's progressed from experimental toward
officially supported in recent releases, but check its current status
and your dependencies' C-extension compatibility before relying on it in
production, since this is a fast-moving area.

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
