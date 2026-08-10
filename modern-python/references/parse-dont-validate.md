# Parse, don't validate

Validating checks that data is shaped correctly and then throws that
knowledge away — the caller gets back the same loosely-typed thing it
passed in, so every downstream function has to wonder about it and
re-check it again. Parsing checks *once* and returns a type that carries
the guarantee in its shape, so nothing downstream can even compile if it
skips the check. See [Parse, Don't
Validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/)
for the canonical writeup — it's framed around Haskell, but the principle
ports directly to Python's type system.

```python
# Validating: the check happens, but the return type still allows the bad case.
def check_non_empty(items: list[str]) -> None:
    if not items:
        raise ValueError("items cannot be empty")

def process(items: list[str]) -> str:
    check_non_empty(items)   # nothing stops a caller from skipping this
    return items[0]           # still typed as possibly-empty; no static help here

# Parsing: the check happens once, and the result *is* the proof.
type NonEmpty[T] = tuple[T, *tuple[T, ...]]  # first element always present

def parse_non_empty[T](items: list[T]) -> NonEmpty[T]:
    if not items:
        raise ValueError("items cannot be empty")
    return (items[0], *items[1:])

def process(items: NonEmpty[str]) -> str:
    return items[0]   # no check needed — the type already proves it
```

## Push the parse to the boundary

The practical form of this in a service: parse the raw request body,
config dict, or third-party API response into a Pydantic model or
dataclass **immediately**, at the boundary where it enters your system,
and never let the untyped shape (`dict`, `Any`, raw JSON) travel any
further than that first function. Every function past the boundary takes
the model, not the dict, so it never re-derives what the boundary already
proved.

Don't scatter `if x is None` / `if not isinstance(...)` checks through
business logic for a condition the boundary already ruled out — that's
"shotgun parsing," where ad hoc checks are sprinkled through processing
code instead of concentrated at one entry point, and it means invalid
input can be *partially* processed before anything notices something's
wrong.

## When a function is awkward to type, look at the data first

If a function is hard to give a precise type, that's usually a sign the
*data representation* handed to it is wrong, not that the function needs
a broader type or an `Any` escape hatch. Reshape the input first (parse it
into a real type), and the function's signature often becomes obvious.

See [data-modeling.md](data-modeling.md) for choosing what to parse
*into* (Pydantic vs. dataclass vs. NamedTuple vs. TypedDict), and
[exhaustiveness.md](exhaustiveness.md) for the "typestate" version of this
idea — splitting a type by *phase* the same way this splits by *shape*.
