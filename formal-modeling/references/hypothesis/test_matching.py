"""Property based tests for the rules checked in ../alloy/matching.als and
../alloy/posting.als. The Alloy models check the design. These check the code.

Run it:  uv run --with hypothesis --with pytest pytest test_matching.py -q
"""

from dataclasses import dataclass, field

from hypothesis import find, given, strategies as st
from hypothesis.stateful import Bundle, RuleBasedStateMachine, invariant, rule

# --- the code under test -----------------------------------------------------


@dataclass(frozen=True)
class Invoice:
    id: str
    account: str
    ref: str


@dataclass(frozen=True)
class Payment:
    reported_account: str
    reported_ref: str
    truth: str | None  # the invoice this payment is really for


def match_lax(payment: Payment, invoices: list[Invoice]) -> str | None:
    """Rule 1. Take the first candidate."""
    for invoice in invoices:
        if invoice.ref == payment.reported_ref and invoice.account == payment.reported_account:
            return invoice.id
    return None


def match_safe(payment: Payment, invoices: list[Invoice]) -> str | None:
    """Rule 2. Only answer when exactly one candidate exists."""
    candidates = [
        i
        for i in invoices
        if i.ref == payment.reported_ref and i.account == payment.reported_account
    ]
    if len(candidates) != 1:
        return None
    return candidates[0].id


# --- generating a world that obeys the model's assumptions -------------------

OURS = ["r1", "r2", "r3"]
FOREIGN = ["r4", "r5"]
ACCOUNTS = ["a1", "a2"]


@st.composite
def worlds(draw) -> tuple[list[Invoice], Payment]:
    """An invoice list plus one payment.

    Two assumptions from the Alloy model hold by construction here. A payment
    for one of our invoices echoes that invoice's account and reference, and a
    payment for an invoice we never issued carries a reference that is not ours.
    """
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


def is_unsound(matcher, world) -> bool:
    invoices, payment = world
    answer = matcher(payment, invoices)
    return answer is not None and answer != payment.truth


# --- the properties ----------------------------------------------------------


@given(worlds())
def test_safe_matcher_is_never_wrong(world):
    assert not is_unsound(match_safe, world)


def test_lax_matcher_has_a_counterexample():
    """`find` returns a small world that breaks the rule.

    It is the same shape as the Alloy counterexample, which is several invoices
    sharing one account and one reference number. Shrinking is a heuristic, so
    the result is small but not guaranteed minimal. Alloy's counterexample is
    minimal for the bound, and that is one concrete difference between sampling
    and exhaustive search.
    """
    invoices, payment = find(worlds(), lambda w: is_unsound(match_lax, w))
    assert is_unsound(match_lax, (invoices, payment))
    assert payment.truth is not None
    collisions = [
        i for i in invoices if i.account == payment.reported_account and i.ref == payment.reported_ref
    ]
    assert len(collisions) > 1


# --- the same shape as posting.als ------------------------------------------


@dataclass
class Ledger:
    posted: set[str] = field(default_factory=set)
    reversed_: set[str] = field(default_factory=set)

    def post(self, entry: str) -> None:
        if entry in self.posted or entry in self.reversed_:
            raise ValueError("already handled")
        self.posted.add(entry)

    def reverse(self, entry: str) -> None:
        if entry not in self.posted:
            raise ValueError("not posted")
        self.posted.discard(entry)
        self.reversed_.add(entry)


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

    @rule(entry=entries)
    def reverse(self, entry):
        try:
            self.ledger.reverse(entry)
        except ValueError:
            return

    @invariant()
    def nothing_is_posted_twice(self):
        assert all(n <= 1 for n in self.times_posted.values())

    @invariant()
    def posted_and_reversed_are_disjoint(self):
        assert not (self.ledger.posted & self.ledger.reversed_)


TestLedger = LedgerMachine.TestCase
