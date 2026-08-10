# Disambiguate `None` (and other overloaded values) with sentinels

`None` is a fine "absent" marker exactly as long as it means one thing in
a given context. It stops being fine the moment it's overloaded — the
classic case is a function argument where `None` needs to mean both
"caller didn't pass this" and "caller explicitly passed `None`," or a
lookup where `None` means both "this key legitimately isn't present"
(benign, keep going) and "the thing that should have loaded didn't"
(a bug, should raise). Squinting at an `Optional` return or a default
argument and asking "wait, could this `None` mean two different things?"
catches real bugs before they ship. See the [Python sentinel object
pattern](https://python-patterns.guide/python/sentinel-object/) for the
canonical treatment.

## The default case: a unique object, compared by identity

```python
_UNSET = object()

def get(self, key: str, default: object = _UNSET) -> object:
    value = self._data.get(key, _UNSET)
    if value is _UNSET:
        if default is _UNSET:
            raise KeyError(key)
        return default
    return value
```

This distinguishes "no default was given" from "the default is `None`,"
which a plain `default: object | None = None` signature can't. Always
compare a sentinel with `is`, never `==` — equality comparison defeats
the whole point and turns it back into a sentinel *value*, which some
unrelated piece of real data could accidentally collide with.

## When the sentinel needs to type-narrow, use a single-member enum

A bare `object()` sentinel works at runtime but is awkward for a type
checker to narrow cleanly out of a union. When you want `is` checks to
narrow a `Literal`-style type the way an `Enum` member does, back the
sentinel with a single-member `Enum` instead:

```python
class _NotRegisteredType(Enum):
    TOKEN = object()

NOT_REGISTERED = _NotRegisteredType.TOKEN

def handler_for(name: str) -> Handler | _NotRegisteredType:
    """Never returns None: a name is either registered, or explicitly not
    registered. A registry that failed to initialize is a bug, and raises
    instead of returning here."""
    return _registry().handlers.get(name, NOT_REGISTERED)
```

The two failure modes this separates — "not registered" (expected,
handle it) vs. "registry didn't load" (a bug, let it raise) — were
previously both spellable as `None`, which meant a caller checking
`if handler is None` couldn't tell which case they were in.

If a sentinel could plausibly be mistaken for falsy (someone writes
`if not result:` instead of `if result is NOT_REGISTERED:`), and the
sentinel is meant to be truthy, write a test asserting that directly:

```python
def test_not_registered_sentinel_is_truthy() -> None:
    assert bool(NOT_REGISTERED) is True
    assert NOT_REGISTERED  # the exact form an accidental `if not x:` would hit
```

Without this test, a later refactor of the sentinel's implementation
could make it falsy by accident (e.g. backing it with an empty container),
and every `if not result:` call site would silently start treating "not
registered" the same as the error case it was invented to distinguish —
exactly the bug the sentinel exists to prevent.

## `Literal` as an in-band tag for "this also means something special"

For a value that's usually one type but can also explicitly mean
something else — "usually a number, but can also mean *use the default*"
— resist a magic value compared by `==` (`-1`, `""`, `"default"` typed as
a plain `str`) and put both cases in the type itself:

```python
type Timeout = float | Literal["default"]

def with_timeout(value: Timeout) -> float:
    if value == "default":
        return DEFAULT_TIMEOUT_SECONDS
    return value
```

Every consumer's type checker now forces them to handle both cases, and
the tag can't collide with a real value the way a bare `-1` could if a
caller happened to pass exactly `-1` as a genuine timeout.

See [exhaustiveness.md](exhaustiveness.md) for the fuller version of this
idea once there are more than two cases — that's a discriminated union
with `match`/`assert_never`, not a two-way `if`.
