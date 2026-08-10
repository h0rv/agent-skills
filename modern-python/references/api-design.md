# API surface: ergonomic, precise, and free of ceremony against a hypothetical

## The boolean trap and keyword-only arguments

A lone positional `True`/`False` at a call site is unreadable and a
classic transposition bug:

```python
create_user("robby", True, False)   # what do these even mean at the call site?

create_user("robby", is_admin=True, send_welcome_email=False)  # readable, and a
                                                                 # keyword typo is
                                                                 # a TypeError
```

Make boolean parameters (and generally anything past the first one or two
positional arguments) keyword-only with `*`. If a function grows more
than one boolean parameter, consider whether it's actually describing a
small set of modes better expressed as a single `Enum`/`Literal`
parameter than as independent flags that can combine in ways that don't
make sense together (see [exhaustiveness.md](exhaustiveness.md)).

## Explicit mode over silent fallback

When a function can resolve a value from more than one source — a cached
value vs. a fresh fetch, a local registry vs. a remote lookup — make the
caller pick the mode explicitly through a required parameter rather than
having the function silently try one and fall back to the other:

```python
# Which path actually served this call? The caller (and the reader) can't tell.
def get_price(sku: str) -> Decimal:
    if cached := _cache.get(sku):
        return cached
    return _fetch_from_upstream(sku)

# The caller states the mode; nothing is inferred silently.
class PriceSource(Enum):
    CACHED = auto()
    FRESH = auto()

def get_price(sku: str, source: PriceSource) -> Decimal:
    match source:
        case PriceSource.CACHED:
            return _cache[sku]
        case PriceSource.FRESH:
            return _fetch_from_upstream(sku)
        case _:
            assert_never(source)
```

Silent fallback hides exactly the information you need when a call
returns something unexpected: which path actually served it.

## Typed exceptions over string matching

```python
# Fragile: renaming the error message breaks this silently.
try:
    decode(payload)
except Exception as e:
    if "malformed" in str(e):
        ...

# A typo in the exception name is a NameError, not a silent no-op.
class MalformedPayloadError(Exception): ...

try:
    decode(payload)
except MalformedPayloadError:
    ...
```

## Return the most precise type you can

Prefer a specific dataclass, a `Literal` union, or `SomeType | None` over
`dict`, `Any`, or a bare `bool` when a richer result would tell the
caller more. A `TypedDict`, dataclass, or Pydantic model documents a
shape *and* gets checked at the type level; a raw dict passed around as a
public interface does neither.

## Don't build ceremony against a caller that doesn't exist yet

An explicit `__all__` that only formalizes what's already true by
convention (no leading underscore means public), or a module-level alias
kept around purely so an old import path still resolves, is one more
thing to keep in sync for no behavioral benefit. If nothing outside the
module actually needs the indirection today, remove it and fix the call
sites directly rather than pre-building a compatibility seam for a break
that hasn't happened. This is the same instinct as parse-don't-validate
applied to the API surface itself (see
[parse-dont-validate.md](parse-dont-validate.md)): prefer the version
with fewer things that could drift out of sync over one padded for a
hypothetical future caller.

Likewise, resist adding a parameter, hook, or abstraction point for a
case nobody has asked for yet. A config-driven design (see
[control-flow.md](control-flow.md)) should still start from real, current
variation, not variation you're anticipating — YAGNI applies to type
design as much as to code.
