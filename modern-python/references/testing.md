# What "correct by construction" still leaves for tests

Pushing checks into the type checker eliminates a whole *category* of
test — you don't need a test asserting a function returns the type its
signature already says it returns, or that a Pydantic model enforces its
configured validation policy, because `ty`/Pydantic already guarantee
that for free. Pydantic's default (lax) mode is coercive, not
type-rejecting — an `int` field accepts `"123"` — so keep tests around
the boundary: what gets coerced, what gets rejected, and what strict
mode would change about that. It doesn't eliminate testing altogether — it should
redirect testing effort toward the things a type genuinely can't verify:
behavior, business-logic correctness, and the runtime invariants that
live inside a parse step rather than in a type signature.

## Where a test still earns its keep

- **The parse/boundary function itself.** The function that turns raw,
  untyped data into your real type (see
  [parse-dont-validate.md](parse-dont-validate.md)) is exactly where
  invalid input meets code — `ty` can verify the function's *signature*,
  but not that its logic actually rejects what it should reject and
  accepts what it should accept. This is the highest-value place to put
  direct tests, including deliberately malformed/adversarial inputs.

- **Runtime invariants inside `__post_init__` or a `@model_validator`**
  (see [data-modeling.md](data-modeling.md)) — these are business rules
  checked at runtime, not something the type system verifies, so they
  need their own tests the same way any other runtime logic would.

- **Truthiness/equality invariants a refactor could silently break.**
  The sentinel-truthiness pattern from [sentinels.md](sentinels.md)
  generalizes: any time correctness depends on a value's truthiness,
  identity, or equality behavior rather than just its type, write a test
  asserting that behavior directly.

  ```python
  def test_not_registered_sentinel_is_truthy() -> None:
      assert bool(NOT_REGISTERED) is True
      assert NOT_REGISTERED  # the exact form an accidental `if not x:` would hit
  ```

  Nothing about `NOT_REGISTERED`'s *type* would catch a future change
  that made it falsy — only a test that exercises the actual behavior
  does.

- **Discriminated-union dispatch, for logic correctness rather than
  exhaustiveness.** `assert_never` (see
  [exhaustiveness.md](exhaustiveness.md)) guarantees every variant is
  *handled* — it says nothing about whether it's handled *correctly*. A
  test that constructs a representative instance of each variant and
  checks it produces the right result still catches "right variant,
  wrong branch logic" bugs that exhaustiveness checking can't.

- **Behavioral and numeric correctness generally.** A type proves shape;
  it doesn't prove the formula, the off-by-one, or the business rule is
  right.

## Property-based testing for parse functions

Boundary parsers are a strong fit for property-based testing (e.g. with
Hypothesis) precisely because they're supposed to handle the *entire*
space of possible raw input, and a handful of hand-picked examples tends
to under-sample the edges that actually break things — empty
collections, unicode, extreme or negative numbers, deeply nested
structures:

```python
from hypothesis import given, strategies as st

@given(st.lists(st.text()))
def test_parse_non_empty_round_trips(items: list[str]) -> None:
    if not items:
        return
    parsed = parse_non_empty(items)
    assert tuple(parsed) == tuple(items)
```

A round-trip property (`parse(serialize(x)) == x`, or "every input this
parser accepts satisfies invariant X") generated over hundreds of cases
finds edge-case failures that a fixed list of examples written by hand
tends to miss, because the examples a person thinks to write are usually
the cases they already know work.

## Don't spend the budget re-testing the type checker

A test that constructs a dataclass and asserts a field holds the type its
annotation says it holds, or that passing a string where an `int` is
expected fails, isn't earning anything `ty` doesn't already guarantee at
every call site, continuously, for free. Every test written to check
something the type system already enforces is a test *not* written for
the boundary logic, invariant, or behavior that the type system can't
see — spend the budget there instead.
