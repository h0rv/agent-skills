# Minimize control flow; let the type do the work

Every `if` is a branch a reader has to hold in their head and a path a
test has to cover. A lot of `if`s exist only to compensate for a type
that isn't precise enough yet — once `None` can't mean two different
things (see [sentinels.md](sentinels.md)), once a dict is a dataclass
with known fields (see [data-modeling.md](data-modeling.md)), once a bool
pair is an enum (see [exhaustiveness.md](exhaustiveness.md)), the
defensive check protecting against the case the type now excludes can be
deleted outright, not just moved somewhere else.

In roughly increasing order of how much structure to reach for:

- **An early return / guard clause** over nesting the rest of a function
  inside an `if`. A function that returns early on each invalid case and
  handles the valid case unindented at the end is easier to read than one
  where the valid case is buried three levels deep.
- **A `match` over cases, or a dict mapping case → handler**, over an
  `if/elif/elif` chain — especially once the cases are a discriminated
  union or enum, where `match` also gets exhaustiveness checking for free
  (see [exhaustiveness.md](exhaustiveness.md)).
- **No check at all**, when the type already guarantees the condition
  can't happen. This is the actual payoff of the sections above, and it's
  worth deleting the now-redundant `if` rather than leaving it in as
  inert insurance — a check that can never be true just makes the reader
  wonder if it can.

## Declarative and data-driven over imperative, where it removes a bug class

A long `if`/`elif` chain checking string or enum equality is usually a
dispatch table wearing a disguise:

```python
if event.kind == "created":
    handle_created(event)
elif event.kind == "updated":
    handle_updated(event)
elif event.kind == "deleted":
    handle_deleted(event)
```

```python
_HANDLERS: dict[EventKind, Callable[[Event], None]] = {
    EventKind.CREATED: handle_created,
    EventKind.UPDATED: handle_updated,
    EventKind.DELETED: handle_deleted,
}

def dispatch(event: Event) -> None:
    _HANDLERS[event.kind](event)
```

The same instinct applies to configuration: express it as data (a
dataclass or Pydantic settings object, a declarative registry) rather
than logic that reconstructs the same decision from scattered
conditionals or ad hoc env-var lookups spread across the codebase.

This isn't about eliminating control flow for its own sake — a guard
clause with an early return is more readable than nesting, and a
comprehension is clearer than a manual accumulator loop, but forcing a
genuinely imperative algorithm into a contrived declarative shape just to
avoid a loop makes it worse, not better. Reach for a declarative
structure when it removes a class of bug (an unhandled case, a state
combination that shouldn't exist), not as a style mandate applied
everywhere uniformly.
