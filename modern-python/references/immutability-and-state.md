# Immutability by default; make mutation an event, not ambient risk

Default new data types to frozen — `@dataclass(frozen=True)`, and note
that Pydantic models are mutable *by default*, so set `model_config = ConfigDict(frozen=True)` explicitly when a model represents a value
rather than an entity being edited in place. Prefer tuples over lists for
collections whose size shouldn't change, and `Final` for module-level
constants.

A method that "changes" a value should return a new instance rather than
mutating `self`:

```python
@dataclass(frozen=True, slots=True)
class Money:
    amount: Decimal
    currency: str

    def times(self, factor: Decimal) -> "Money":   # not scale(), which sounds in-place
        return Money(self.amount * factor, self.currency)
```

This isn't dogma for its own sake — a value you can't mutate can't be
aliased into a bug where two places think they own it and stomp on each
other's changes.

## Mutation is sometimes right — make it visibly deliberate

Mutation is the correct tool sometimes: an ORM row being updated inside a
transaction, an accumulator in a hot loop, a builder object being filled
in before it's finalized (see the typestate pattern in
[exhaustiveness.md](exhaustiveness.md)). The goal isn't to eliminate
mutation, it's to make it obvious from the name and the signature, not
something a reader has to trace the body to discover:

- Follow the convention a reader already expects — `sort` mutates,
  `sorted` returns a new list; match that pattern (`update_status` vs.
  `with_status`) rather than inventing your own.
- If a function takes an object and mutates it in place, say so with a
  type that reflects it (accepting `MutableSequence` rather than a
  generic `Sequence`) instead of leaving it to be discovered by reading
  the body.
- Prefer a dedicated builder type (per the typestate pattern) over a
  function that mutates the object handed to it and *also* returns it —
  that leaves callers unsure whether the original is still safe to use.

## Shared mutable global state is the case to actively design away

This is a stronger claim than "avoid mutation" — it's specifically about
state that more than one logically independent caller can see or touch
at once: a module-level cache dict, a lazily-initialized global instance,
a class-level mutable default argument. These mean two things that have
no business knowing about each other (two requests, two worker tasks, two
callers using the same library independently) can observe or clobber each
other's state with nothing in either call site's signature revealing the
coupling.

```python
# Two callers can silently interfere with each other through this.
_cache: dict[str, Result] = {}

def compute(key: str) -> Result:
    if key not in _cache:
        _cache[key] = _expensive(key)
    return _cache[key]

# The state is explicit, constructed, and owned by whoever holds the instance.
@dataclass
class Cache:
    _entries: dict[str, Result] = field(default_factory=dict)

    def compute(self, key: str) -> Result:
        if key not in self._entries:
            self._entries[key] = _expensive(key)
        return self._entries[key]
```

Prefer an instance you construct and pass around (dependency injection)
over a module-level global, even when "there's only ever one of these in
practice" — concurrency bugs are exactly the ones that only show up once
there turn out to be two, whether that's two threads, two async tasks
sharing an event loop, or two processes.

If a lock is guarding a module-level or class-level global, ask first
whether the thing being locked should have been constructed per-instance
instead. A lock treats the symptom — it serializes access to a piece of
state that shouldn't have been shared in the first place. Isolating the
state removes the disease, along with the deadlock risk a lock adds once
the code is running under concurrent or async execution, where blocking
has sharper edges than it does in a single-threaded script.
