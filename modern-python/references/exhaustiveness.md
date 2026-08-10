# Closed sets of cases: typestate, discriminated unions, and `assert_never`

## Typestate: split the class instead of guarding a flag

The smell: a class with a `bool` (or optional field) that gates which
methods are safe to call, enforced only by a runtime guard inside each
method.

```python
class Order:
    def __init__(self) -> None:
        self._confirmed = False
        self._items: list[Item] = []
        self._total: Decimal | None = None

    def add_item(self, item: Item) -> None:
        if self._confirmed:
            raise RuntimeError("cannot modify a confirmed order")
        self._items.append(item)

    def total(self) -> Decimal:
        if not self._confirmed:
            raise RuntimeError("order not confirmed yet")
        return self._total  # type: ignore[return-value]  # we "know" this isn't None

    def confirm(self) -> None:
        self._total = compute_total(self._items)
        self._confirmed = True
```

Every method pays a runtime tax guarding a state the *caller* already
knows — they know whether they've called `confirm()` yet — but the class
throws that information away and re-derives it on every call, and the
`# type: ignore` is a symptom of the type system genuinely not knowing
what the runtime guards promise.

The fix: make "not yet confirmed" and "confirmed" two different types,
and make the transition a method that returns the other type.

```python
@dataclass
class OrderDraft:
    _items: list[Item] = field(default_factory=list)

    def add_item(self, item: Item) -> None:
        self._items.append(item)  # no guard needed — this type has no other state

    def confirm(self) -> "ConfirmedOrder":
        return ConfirmedOrder(
            items=tuple(self._items),
            total=compute_total(self._items),
        )

@dataclass(frozen=True)
class ConfirmedOrder:
    items: tuple[Item, ...]
    total: Decimal          # not optional — you can't have one of these without a total

    # no add_item method at all — "already confirmed" isn't a state to guard,
    # it's a type that doesn't have the method
```

"Add an item after confirming" and "read the total before confirming"
stop being bugs you defend against and become code that doesn't
type-check. This scales past two states: model each phase as its own
type, and each valid transition as a method on the *source* type
returning the *destination* type.

## Discriminated unions instead of booleans or raw strings

A boolean is a two-state enum with bad names. Two booleans threaded
together is a four-state enum in disguise, and nothing stops a caller
from constructing the one combination that shouldn't exist. Name the
cases:

```python
class Direction(Enum):
    ASCENDING = auto()
    DESCENDING = auto()
```

The same goes for dispatch on a raw string field pulled out of a dict —
it works right up until a new case is added and the fallback branch
silently swallows it. Model the cases as a discriminated union (a
`Literal` tag, or subclasses of a sealed base) and dispatch with
`match`/`case`, ending in `assert_never` instead of a bare `else`:

```python
type Shape = Circle | Square | Triangle

def area(shape: Shape) -> float:
    match shape:
        case Circle(radius=r):
            return math.pi * r * r
        case Square(side=s):
            return s * s
        case Triangle(base=b, height=h):
            return 0.5 * b * h
        case _:
            assert_never(shape)   # a new Shape variant breaks this line, at type-check time
```

`assert_never` is what makes this earn its keep: `typing.assert_never`
has type `(NoReturn) -> NoReturn`, so the checker verifies every branch
above it has already narrowed the type down to nothing. Add a new variant
to the union anywhere in the codebase, and every `match` that isn't
updated to handle it becomes a type error at the exact call site that
needs attention — instead of a new case quietly falling into the wrong
branch at runtime. This matters most exactly where a silent fallthrough
is dangerous: a permission check that defaults to the more permissive
outcome for a case it doesn't recognize, or a state machine that ignores
an unknown transition. If a wildcard case is genuinely meant to mean
"anything else, treat it as X," write that logic explicitly under its own
name — don't let a bare `else` (or a fallthrough `assert_never` you
silence) stand in for a case you actually intend to handle.

## Pydantic discriminated unions work the same way

```python
class CardPayment(BaseModel):
    kind: Literal["card"] = "card"
    last4: str

class BankPayment(BaseModel):
    kind: Literal["bank"] = "bank"
    routing_number: str

Payment = Annotated[CardPayment | BankPayment, Field(discriminator="kind")]

def charge(payment: Payment) -> None:
    match payment:
        case CardPayment(last4=last4):
            ...
        case BankPayment(routing_number=routing_number):
            ...
        case _:
            assert_never(payment)
```

Pydantic resolves the right variant from `kind` at parse time — there's
no `if payment_dict["kind"] == "card": payment_dict["last4"]` re-deriving
what the discriminator already told you. See
[data-modeling.md](data-modeling.md) for when to reach for Pydantic vs. a
plain dataclass here.

## Interpreter-style dispatch over nested structures

Dispatching over something recursive (an AST, a query filter tree, a
rule engine) tends to accumulate an `if`-chain keyed on a raw dict field,
with a fallback branch that silently does *something* for any shape it
doesn't recognize:

```python
def evaluate(node: dict) -> bool:
    if node["op"] == "and":
        return evaluate(node["left"]) and evaluate(node["right"])
    elif node["op"] == "or":
        return evaluate(node["left"]) or evaluate(node["right"])
    else:
        return True   # silently widens for anything else — including a typo in "op"
```

Model the grammar as a real closed union instead, and let `match` +
`assert_never` force every new node type to be handled where it's
introduced:

```python
@dataclass(frozen=True)
class And:
    left: "Expr"
    right: "Expr"

@dataclass(frozen=True)
class Or:
    left: "Expr"
    right: "Expr"

@dataclass(frozen=True)
class Literal_:
    value: bool

Expr = And | Or | Literal_

def evaluate(node: Expr) -> bool:
    match node:
        case And(left=l, right=r):
            return evaluate(l) and evaluate(r)
        case Or(left=l, right=r):
            return evaluate(l) or evaluate(r)
        case Literal_(value=value):
            return value
        case _:
            assert_never(node)
```

In the dict version, a new node shape you haven't seen yet falls into the
`else` and silently widens with no signal anywhere. In the union version,
a variant that isn't yet in `Expr` doesn't type-check at construction,
and one that's added to the union but not handled in `evaluate` fails at
`assert_never` — the failure mode moves from "wrong behavior in
production" to "a red squiggly line before you ship."
