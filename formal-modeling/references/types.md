# Types are the first formal method

A type checker is a proof tool. It checks a claim about every possible execution
of the program, statically, without running it, with no bound and no sampling.
The claims it can make are narrow, which is exactly why it is fast enough to run
on every save. Everything else in this skill is what you reach for when the
claim you need is outside that narrow set.

Put the methods in one order, from cheapest and most certain to most expensive.

1. The type system. Checked on every line, on every save, for the whole
   codebase.
2. Parsing at the boundary, plus assertions inside. Checked at runtime, on the
   paths that actually run.
3. Property based testing. Checked on generated inputs, against the real code.
4. Model checking. Checked exhaustively inside a bound, against a model.
5. Proof. Checked for all inputs, against the code.

The working rule is to push every check as far down that list as it will go. A
property you moved into a type is a property nobody has to test, model, or
prove, and it cannot come back. That is the same reasoning as the modern Python
skill's version, and it applies to designs as well as to functions.

## What a type can say

| Claim | How |
|---|---|
| This value has this shape | An annotation, checked everywhere it flows |
| These two identifiers cannot be swapped | `NewType`, so an account id is not a reference number |
| This value is one of a closed set | An enum or `Literal` |
| Every case is handled | A union, `match`, and `assert_never` at the end |
| This value was already validated | Parse at the boundary into a distinct type |
| This value cannot change after construction | A frozen dataclass, or an immutable collection type |
| This operation is not available yet | A separate type per state, so the wrong call does not compile |

The last two rows are the ones people miss, and they are the ones that overlap
with model checking. If a value has a different type before and after a step,
then a whole class of ordering bug becomes unwriteable rather than untested.

## What a type cannot say

A type describes one value. It cannot describe a relationship that only exists
at runtime between separate values. None of these fit in a type.

- This payment's reference number belongs to exactly one invoice in the
  database.
- Across every ordering of retries and reversals, no entry is ever posted twice.
- Every row in the old table appears exactly once in the new table.
- No principal can reach a resource in another tenant by any path.

Every one of those is a statement quantified over a whole system, which is what
a model checker takes and a type checker cannot. So the split is clean. Types
constrain each value. Model checking constrains the relationships between them.

## Where they meet

This is the useful part. A model checker tells you which invariant matters, and
the type system is often the right place to make that invariant impossible to
violate.

The Alloy model in [alloy/matching.als](alloy/matching.als) produces one finding
above all others. The matcher must not answer when the evidence is ambiguous.
That finding is a sentence in a document, and documents get ignored. Put it in
the return type instead and it cannot be ignored.

```python
from dataclasses import dataclass
from typing import assert_never


@dataclass(frozen=True)
class Matched:
    invoice_id: str


@dataclass(frozen=True)
class Ambiguous:
    candidate_ids: tuple[str, ...]


@dataclass(frozen=True)
class NoCandidate:
    pass


MatchResult = Matched | Ambiguous | NoCandidate


def post(result: MatchResult) -> str:
    match result:
        case Matched(invoice_id):
            return f"posted to {invoice_id}"
        case Ambiguous(candidates):
            return f"sent to review, {len(candidates)} candidates"
        case NoCandidate():
            return "held"
        case _ as unreachable:
            assert_never(unreachable)
```

Compare that with returning `str | None`. With `str | None`, "no answer" and
"too many answers" are the same value, so the caller cannot treat them
differently and the review queue does not exist. Worse, the next person adds a
fallback that picks the first candidate, and the bug the model found is back.
With three cases and `assert_never`, adding a fourth outcome later is a type
error at every call site, so nobody can quietly drop it.

The other half is not confusing identifiers, which is the other failure mode the
matching model exposes.

```python
from typing import NewType

InvoiceId = NewType("InvoiceId", str)
AccountId = NewType("AccountId", str)
ReferenceNumber = NewType("ReferenceNumber", str)


def find_invoice(account: AccountId, ref: ReferenceNumber) -> InvoiceId | None: ...
```

Every identifier in a matching pipeline is a string, and every one of them is a
different kind of thing. `NewType` costs one line each and it removes a class of
bug that is otherwise found only in production, because the arguments are the
same type and the call still runs.

## The honest caveats

Python's type system is not sound, and treating it as a proof is a mistake.

- Annotations are erased at runtime. Nothing checks them unless you check them.
- `Any` and `cast` are holes, and a single `Any` spreads silently through
  everything it touches.
- A type says nothing about data arriving from outside. A `dict` from
  `json.loads` annotated as a model is a lie until something parses it.

So the type system is a real formal method with real holes, and you close them
the same way every time. Run a strict checker in CI, ban `Any` and `cast` except
at the edges, and parse external input into a real type at the boundary rather
than validating it repeatedly downstream.

## Where to go next

For the Python specifics, which are parse don't validate, illegal states,
sentinels, exhaustiveness, immutability, and the `uv`, `ruff`, and `ty`
toolchain, read the `modern-python` skill. This file only covers where typing
sits relative to the other methods.

When you find a property that will not fit in a type, go up one rung. Try an
assertion or a parser first. If the property is about relationships across many
values or about orderings, that is the point to write a model. Read
[methods.md](methods.md) for the comparison and
[when-to-model.md](when-to-model.md) for whether it is worth it.
