# Structure data, don't shuttle it around as dicts and tuples

A `dict` or a bare `tuple` passed between a handful of functions is
usually a type that hasn't been written yet. The moment two or more
functions agree on the same set of keys or the same tuple shape, that
agreement belongs in a named type — not in each function's memory of
"the third element is the y-coordinate." The payoff isn't cosmetic: a
typo'd key becomes a type-checker error instead of a `KeyError` at
runtime, and every call site gets autocomplete instead of grep.

```python
# A tuple that only means something because everyone remembers the order.
def midpoint(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]: ...

# The shape is the type, and conversions are named.
@dataclass(frozen=True)
class Point:
    x: float
    y: float

    def midpoint(self, other: "Point") -> "Point":
        return Point((self.x + other.x) / 2, (self.y + other.y) / 2)
```

## Choosing a container: a quick decision framework

| Situation | Reach for |
|---|---|
| Data is arriving from outside the type system's reach — a request body, a config file, a third-party JSON payload, an env var | **Pydantic `BaseModel`** (or `pydantic-settings` for process config) |
| A value type built from data you already have as typed Python objects, never touches a validation boundary, and doesn't need serialization | **`@dataclass(frozen=True)`** |
| The same, but performance/memory matters (many instances, a hot loop) | **`@dataclass(frozen=True, slots=True)`** |
| A small, fixed-shape record that benefits from also acting like a tuple (unpacking, indexing, drop-in compatibility with tuple-based APIs) | **`NamedTuple`** |
| The value must literally remain a `dict` at some boundary you don't control (a framework or serialization format that requires it), but you still want static shape-checking | **`TypedDict`** |

### Pydantic: validation and shape declared together

Pydantic is parse-don't-validate as a library. Validation is declared
once on the model instead of imperative `if`-checks scattered at the call
site, coercion and validation happen together, and serialization comes
for free (`model.model_dump()`) instead of a hand-written `to_dict`.
`pydantic-settings` extends the same idea to process configuration —
validate every setting once at startup instead of discovering a bad env
var three requests in.

```python
class ServiceSettings(BaseSettings):
    model_config = SettingsConfigDict(frozen=True)

    api_base_url: HttpUrl
    request_timeout_seconds: float = 30.0
    max_retries: int = 3
```

Reach for a real type before reaching for a validator: `HttpUrl` above
already rejects a malformed URL without any hand-written check, which is
the point of parse-don't-validate — let the shape of the field do the
work. `@field_validator`/`@model_validator` are for the invariants a
field's type genuinely can't express on its own:

```python
class DateRange(BaseModel):
    model_config = ConfigDict(frozen=True)

    start: date
    end: date

    @model_validator(mode="after")
    def check_ordered(self) -> "DateRange":
        if self.start > self.end:
            raise ValueError(f"start ({self.start}) must not be after end ({self.end})")
        return self
```

`@field_validator` runs per-field, for coercion or checks a bare type
annotation can't capture (e.g. "this string must be uppercase");
`@model_validator(mode="after")` runs once the whole model is built, for
cross-field invariants like the ordering check above that depend on more
than one field at once. Either way, the model stays frozen and the
validator only ever runs at construction time — it's still one parse
step, not validation sprinkled through the code that uses the model
afterward.

### `@dataclass(frozen=True, slots=True)`: when Pydantic's cost isn't worth paying

Pydantic isn't free: every model does validation work on construction and
carries a `__dict__` unless configured otherwise, which matters once
you're building millions of small internal value objects rather than
handling a per-request boundary. When the data is already trustworthy
(you built it from typed values, it's not arriving from outside), a plain
frozen, slotted dataclass is lighter:

```python
@dataclass(frozen=True, slots=True)
class Money:
    amount: Decimal
    currency: str

    def plus(self, other: "Money") -> "Money":
        if other.currency != self.currency:
            raise ValueError("currency mismatch")
        return Money(self.amount + other.amount, self.currency)
```

`frozen=True` makes it hashable and safe to use as a dict key or set
member, and guarantees an instance's fields can't drift after
construction — `plus()` returns a *new* `Money` rather than mutating
`self`. `slots=True` removes the per-instance `__dict__`, which
meaningfully cuts memory for high-volume objects and slightly speeds up
attribute access — the trade-off is you can no longer assign arbitrary
new attributes at runtime, and `functools.cached_property` stops working
as a drop-in: it normally caches its result by writing into
`instance.__dict__`, which a slotted class doesn't have. Adding a slot
*named after the property* doesn't fix it — it raises `ValueError` at
class-creation time because the slot descriptor and the property
descriptor collide on the same name. The real options are giving the
class back a `__dict__` slot (`__slots__ = (..., "__dict__")`, which
gives up most of the memory savings that were the point) or computing
the value once in `__post_init__` and storing it as a plain field
instead of using `cached_property` at all. Given that, reach for
`cached_property` on ordinary (non-slotted) classes, and on a slotted one
just compute eagerly. Everything here is a trade-off: default to
Pydantic for anything crossing a real boundary, and drop to a frozen,
slotted dataclass once you've established the object is purely internal
and the allocation volume or memory footprint actually matters — not
preemptively.

### Validating a dataclass: `__post_init__`

A plain (non-Pydantic) dataclass doesn't run validation on construction
by default — `__post_init__` is where an invariant that can't be
expressed by the field types alone gets checked:

```python
@dataclass(frozen=True)
class Range:
    start: float
    end: float

    def __post_init__(self) -> None:
        if self.start > self.end:
            raise ValueError(f"start ({self.start}) must not exceed end ({self.end})")
```

For a *computed* field on a frozen dataclass, normal attribute
assignment is blocked by design — `frozen=True` overrides `__setattr__`
to raise. Setting a derived field in `__post_init__` needs the
`object.__setattr__` escape hatch, used deliberately and only there:

```python
@dataclass(frozen=True)
class Rectangle:
    width: float
    height: float
    area: float = field(init=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "area", self.width * self.height)
```

This is the one place bypassing `frozen` is the right call — it's
completing construction, not mutating an already-built value — but it
should stay contained to `__post_init__` and not spread anywhere else in
the class.

### `NamedTuple`: lightweight and already immutable

```python
class Range(NamedTuple):
    start: float
    end: float

    def contains(self, value: float) -> bool:
        return self.start <= value <= self.end
```

Good for small, genuinely tuple-like records — it's immutable by
construction, unpacks and indexes like a tuple, and supports methods.
Reach for a dataclass instead once the type has more than a couple of
fields or the tuple-like behavior (unpacking, indexing) isn't actually
used anywhere.

### Avoid duck-typed dispatch on a dict's contents

If you catch yourself writing `x.get("type")` or checking which keys are
present in a dict to figure out what kind of thing `x` is, that's the
same problem as `getattr` duck typing (see
[type-narrowing.md](type-narrowing.md)) — a discriminated union or a
`Protocol` gives the same flexibility with autocomplete and exhaustiveness
checking instead of a string to typo.
