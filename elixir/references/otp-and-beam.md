# OTP And BEAM

## Start With Ownership

- Identify which process owns the state, mailbox, timers, subscriptions, sockets, or external resource.
- Use a supervised process only when there is real process-owned state or serialization to protect.
- Do not turn every module into a `GenServer`. A plain module plus explicit data is often correct.

## Supervision Rules

- Follow OTP design principles: workers do work, supervisors monitor and restart workers.
- Keep supervision trees explicit and boring.
- Let supervisors manage lifecycle. Do not add ad hoc restart loops inside workers.
- Pick restart strategy and shutdown behavior based on actual failure semantics, not habit.

## GenServer Rules

- Use `GenServer` for coordinated state, resource access, or protocol boundaries.
- Keep the public API small and synchronous only when callers truly need a reply.
- Keep callback state minimal and serializable.
- Avoid long blocking work in `handle_call/3`, `handle_cast/2`, or `handle_info/2`; hand it off to tasks or dedicated workers when needed.
- Prefer clear message shapes and explicit timeout handling.

## Common OTP Tools

- `Supervisor` and `DynamicSupervisor` for process trees
- `Task` and `Task.Supervisor` for async work
- `Registry` for name lookup and dispatch
- ETS for shared in-memory lookup tables when process ownership is too restrictive
- `Phoenix.PubSub` when the task is Phoenix-side fan-out rather than raw Erlang distribution

## BEAM Review Heuristics

- Look for mailbox growth, timer leaks, and unbounded fan-out.
- Check whether work should happen in request processes or in background workers.
- Check whether restart semantics match resource ownership.
- Check whether state could be plain data instead of a long-lived process.
- Check whether a behaviour already exists before inventing a custom process protocol.

## What To Read First

- Read the OTP design-principles overview for supervision-tree structure.
- Read the `gen_server` concepts guide when deciding whether a server process is the right abstraction.
