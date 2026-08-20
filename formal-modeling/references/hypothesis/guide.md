# Property based testing in Python with Hypothesis

Hypothesis is the most accessible tool on this page and it runs against your
real code, so it is the right first step for a Python codebase. Written against
Hypothesis 6.165.

The runnable example is [test_matching.py](test_matching.py). It tests the same
two rules that [../alloy/matching.als](../alloy/matching.als) and
[../alloy/posting.als](../alloy/posting.als) check as designs.

```sh
uv run --with hypothesis --with pytest pytest test_matching.py -q
```

## The basic shape

You write a rule that should hold for every input. Hypothesis generates inputs,
runs the test, and when it finds a failure it shrinks the input to the smallest
version that still fails.

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sorting_keeps_every_element(xs):
    assert len(sorted(xs)) == len(xs)
```

The default is 100 examples per test. A failure prints the failing arguments,
and Hypothesis saves it to a local database under `.hypothesis` and replays it
first on the next run, so a failure stays failing until you fix it.

The hard part is never the assertion. It is deciding what is true for every
input. Useful starting points, in rough order of how often they apply:

- A round trip. `decode(encode(x)) == x`.
- Agreement with something simpler. The optimized version equals the obvious
  version.
- An invariant on the output. The total is preserved, the list stays sorted, no
  identifier appears twice.
- It never raises, except for the exceptions you named.
- Idempotence. `f(f(x)) == f(x)`.

## Strategies

| Strategy | Generates |
|---|---|
| `st.integers(min_value=None, max_value=None)` | integers |
| `st.floats(min_value=None, max_value=None, allow_nan=None)` | floats |
| `st.text(min_size=0, max_size=None)` | strings |
| `st.lists(elements, min_size=0, max_size=None, unique=False)` | lists |
| `st.dictionaries(keys, values)` | dicts |
| `st.sets(elements)`, `st.tuples(*strategies)` | sets and tuples |
| `st.sampled_from(values)` | one of the values you list |
| `st.one_of(*strategies)` | a value from any of the strategies |
| `st.just(value)`, `st.none()` | a constant |
| `st.builds(Klass, ...)` | an object, drawing its arguments |
| `st.from_type(SomeType)` | a value inferred from a type annotation |
| `st.dates()`, `st.datetimes()`, `st.uuids()` | dates, times, ids |
| `st.data()` | draw values inside the test body with `data.draw(...)` |

Every strategy has `.map(f)`, `.filter(predicate)`, and `.flatmap(f)`. Prefer
`.map` over `.filter`, because filtering throws away work and a filter that
rejects most values makes the test slow and triggers a health check.

## Generate only legal inputs

This is the technique that decides whether a property based test is useful. If
your generator produces inputs the real system could never produce, you will
spend your time fixing the test. Use `@composite` to build a whole consistent
world in one place.

```python
@st.composite
def worlds(draw):
    count = draw(st.integers(min_value=0, max_value=4))
    invoices = [
        Invoice(id=f"i{n}", account=draw(st.sampled_from(ACCOUNTS)), ref=draw(st.sampled_from(OURS)))
        for n in range(count)
    ]
    if invoices and draw(st.booleans()):
        target = draw(st.sampled_from(invoices))
        payment = Payment(target.account, target.ref, target.id)
    else:
        payment = Payment(draw(st.sampled_from(ACCOUNTS)), draw(st.sampled_from(FOREIGN)), None)
    return invoices, payment
```

The two assumptions from the Alloy model hold here by construction. A payment
for one of our invoices echoes that invoice's fields, and a payment for an
invoice we never issued carries a reference that is not one of ours. That is
the same discipline as writing assumptions as named predicates in Alloy, and it
is worth a comment saying which assumption each line encodes.

Note also that the generator carries a `truth` field that production code never
sees. Giving the test access to the right answer is what lets you assert "the
answer is never wrong" rather than "the answer is self consistent".

## Getting a counterexample on purpose

`find` returns the smallest value it can reach that satisfies a condition, which
is how you assert that a known bad rule really is bad.

```python
from hypothesis import find

invoices, payment = find(worlds(), lambda w: is_unsound(match_lax, w))
```

Shrinking is a heuristic, so this is small but not guaranteed minimal. In the
example, `find` returns three colliding invoices where two would do. Alloy
returns a counterexample that is minimal for the bound. That is a concrete
difference between sampling and exhaustive search, and it is a good reason to
model the design in Alloy even when you also test the code here.

## Stateful testing

This is the part closest to model checking. You declare the operations, and
Hypothesis generates sequences of them and checks your invariants after every
step.

```python
from hypothesis.stateful import Bundle, RuleBasedStateMachine, invariant, rule

class LedgerMachine(RuleBasedStateMachine):
    entries = Bundle("entries")

    def __init__(self):
        super().__init__()
        self.ledger = Ledger()
        self.times_posted: dict[str, int] = {}

    @rule(target=entries, name=st.text(alphabet="xyz", min_size=1, max_size=2))
    def new_entry(self, name):
        return name

    @rule(entry=entries)
    def post(self, entry):
        try:
            self.ledger.post(entry)
        except ValueError:
            return
        self.times_posted[entry] = self.times_posted.get(entry, 0) + 1

    @invariant()
    def nothing_is_posted_twice(self):
        assert all(n <= 1 for n in self.times_posted.values())

TestLedger = LedgerMachine.TestCase
```

The pieces:

- `@rule` is one operation. Its arguments are drawn from strategies, and
  `target=some_bundle` puts the return value into a bundle.
- `Bundle` carries values between rules, so later operations act on the objects
  earlier operations produced.
- `consumes(bundle)` draws a value and removes it, for anything used once.
- `multiple(a, b)` returns several values into a bundle from one rule, and
  returning `multiple()` with no arguments returns nothing.
- `@initialize` runs exactly once before any rule. With several of them the
  order varies between runs.
- `@precondition(lambda self: ...)` filters a rule out when it does not apply.
  Use it instead of `assume` inside the rule, because rejecting a rule wastes
  the whole run. It cannot read bundles, so keep what it needs on `self`.
- `@invariant()` runs after every step. It also cannot read bundles.
- `settings(stateful_step_count=...)` sets how long the generated sequences are.
  The default is 50.
- Assign `SomeMachine.TestCase` to a module level name so pytest collects it, or
  call `run_state_machine_as_test(SomeMachine)`.

A failure prints as runnable Python, which you can paste into a test file.

```
state = DatabaseComparison()
var1 = state.add_key(k=b'')
var2 = state.add_value(v=var1)
state.save(k=var1, v=var2)
state.delete(k=var1, v=var2)
state.values_agree(k=var1)
state.teardown()
```

The strongest form of this is to keep a simple model of the state next to the
real object and assert they agree after every step. That is exactly what Amazon
S3 did to keep 16 issues out of production, and it is described in
[../other-tools.md](../other-tools.md).

## Settings worth knowing

```python
from hypothesis import HealthCheck, settings

@settings(max_examples=1000, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@given(worlds())
def test_slow_thing(world): ...
```

| Setting | Use it when |
|---|---|
| `max_examples` | The default 100 is not enough. Raise it in a nightly run, not in the fast suite |
| `deadline` | A single case legitimately takes longer than 200 milliseconds. Set it to `None` for anything touching a database |
| `derandomize` | You need the same cases every run. It is already the default in CI |
| `phases` | You want to replay saved failures only, or skip shrinking while iterating |
| `stateful_step_count` | Sequences need to be longer to reach the bug |
| `print_blob` | You want a `@reproduce_failure` blob to paste back |

`@example(...)` pins a specific input that runs before the generated ones, which
is how you keep a bug you already fixed from coming back. `@seed(n)` makes one
run reproducible.

## Two more tools in the box

`hypothesis write` generates a first test for you from a function signature.
It is a starting point, not a finished test.

```sh
hypothesis write --roundtrip json.dumps json.loads
hypothesis write --equivalent old_matcher new_matcher
hypothesis write --idempotent normalize_name
```

`target(observation)` steers the search toward larger values of a number you
report, which helps when the bug only appears at the extremes, e.g. when a
buffer is nearly full.

## What it cannot do

- It samples. Passing means no failure in the cases tried, and it is never a
  proof. For an exhaustive answer inside a bound, model the design in Alloy.
- It only finds what the generator can produce. A blind spot in your strategy
  is a blind spot in your testing, and it is invisible. Read the generator with
  the same care as the assertion.
- Shrinking is a heuristic, so a reported failure is small but not necessarily
  the simplest one.
- It needs the code to exist. Use it after the design settles, not instead of
  settling the design.

Set `HYPOTHESIS_EXPERIMENTAL_OBSERVABILITY=1` to write one JSON line per test
case into `.hypothesis/observed/`, which is how you check what your generator
actually covered rather than assuming.
