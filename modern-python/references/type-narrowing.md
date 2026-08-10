# Fix the type, don't cast or reflect your way around it

## `cast` is a promise, not a proof

`cast(...)` tells the type checker to believe something with no runtime
check behind it — it rots silently if the promise stops being true, and
it papers over the gap without fixing it. Before reaching for one, check
whether the checker can be taught to see the truth instead.

```python
# cast papers over a narrowing gap:
value: str | Awaitable[str]
if isinstance(value, Awaitable):
    resolved = cast(str, await value)   # the false branch is *also* unnarrowed

# TypeIs (PEP 742, Python 3.13) narrows both branches:
def is_awaitable_str(value: str | Awaitable[str]) -> TypeIs[Awaitable[str]]:
    return isinstance(value, Awaitable)

if is_awaitable_str(value):
    resolved = await value      # narrowed to Awaitable[str] here
else:
    resolved = value            # narrowed to str here too — no cast on either side
```

## `TypeGuard` vs. `TypeIs`

Both narrow inside an `if`, but they answer different questions.

`TypeGuard[T]` answers "is this a `T`?" and narrows only the `True`
branch — right for a genuine subset check where the `False` branch
doesn't correspond to a clean opposite type:

```python
def is_all_str(items: list[object]) -> TypeGuard[list[str]]:
    return all(isinstance(x, str) for x in items)

values: list[object] = [...]
if is_all_str(values):
    values  # narrowed to list[str]
else:
    values  # still list[object] — "not all str" isn't a type you can name
```

`TypeIs[T]` answers "is this specifically the `T` member of this union?"
and narrows *both* branches, because the input type minus `T` is itself
nameable — that's the `is_awaitable_str` example above. Rule of thumb: if
the `False` branch has a clean, nameable type, use `TypeIs`; if it
doesn't, use `TypeGuard`.

Neither generalizes cleanly into one fully generic helper:

```python
def is_awaitable[T](value: T | Awaitable[T]) -> TypeIs[Awaitable[T]]:
    return isinstance(value, Awaitable)
```

A checker can't infer `T` here — `T` itself could already be
`Awaitable[something]`, so the union doesn't pin down what `T` is from
the call site alone. Write one concrete guard per type you actually need
to distinguish; it's a few extra lines and it typechecks.

## `getattr`, `hasattr`, and `setattr` defeat the type checker

All three operate on attribute names as strings, which means a typo is a
`str` the checker happily accepts and a `None`/`AttributeError` you find
out about at runtime instead of at review time. `getattr(x, "kind", "default")` or `hasattr(x, "run")` used to figure out what kind of thing
`x` is or what it can do is duck typing standing in for a type that
should just say what it is:

```python
# Stringly-typed dispatch: a typo in "kind" type-checks fine and fails at runtime.
mode = getattr(config, "kind", "default")

# A Protocol, a discriminated union, or a proper base class gives the same
# flexibility with autocomplete and exhaustiveness checking instead of a
# string to typo.
class Configured(Protocol):
    kind: Literal["a", "b"]
```

`getattr(x, name, default)` used as a dict-like default-value trick
(`getattr(obj, "field", None)`) is the same problem as an untyped `.get`
on a dict — see [sentinels.md](sentinels.md) for the typed version of
"give me this or a marker meaning it's absent."

These three aren't always avoidable — implementing `__getattr__`/
`__setattr__` themselves (e.g. a proxy object, an ORM's attribute
machinery), or bridging to a genuinely untyped third-party API that ships
no stubs, are legitimate uses. Even then, keep the dynamic access
isolated to one narrow boundary function that immediately parses the
result into a real type (see [parse-dont-validate.md](parse-dont-validate.md)),
rather than letting `getattr`/`hasattr` calls spread through business
logic.

## Every suppression is a debt marker

`cast(...)`, `# type: ignore`, `# ty: ignore`, and a defensive
`isinstance`/`hasattr` check written "just in case" all say the same
thing: the types don't currently prove what you know to be true. That's
worth fixing at the source rather than normalizing. A defensive check for
a state your own types already rule out isn't extra safety — it's
re-validating something a parse step already proved (see
[parse-dont-validate.md](parse-dont-validate.md)), and it hides the fact
that a type is too loose from anyone reading the signature.

If a suppression is genuinely unavoidable, scope it to the exact line and
the exact rule (`# ty: ignore[invalid-return-type]`, not a bare
`# ty: ignore`), and treat backsliding on suppression count as worth
asking about in review — it's a real signal about whether the types are
modeling the domain correctly, not a vanity metric.

The corollary: validate at the actual system boundary (external input,
files, subprocess output, a third-party response) and trust your own
types everywhere past that point. Code that re-checks its own internal
invariants either has a type that's too loose, or is quietly admitting it
doesn't trust the function that produced the value — in which case, fix
that function's return type instead.
