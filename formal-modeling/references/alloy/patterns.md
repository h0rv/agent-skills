# Patterns that keep coming up

## Separate what is true from what the code can see

This is the most useful idea in the whole skill. Model reality as one relation
and the code's answer as another, then assert a relationship between them.

```alloy
sig Payment {
  reportedRef : lone Ref,          // what the sender sent us
  truth       : lone Invoice         // the invoice this payment is really for
}

fun matched : Payment -> Invoice { ... }   // what our rule computes

pred sound    [m : Payment -> Invoice] { all r : Payment, c : Invoice | r->c in m implies c = r.truth }
pred complete [m : Payment -> Invoice] { all r : Payment | some r.truth implies r.truth in r.m }
```

`truth` is not a column in any database. It exists only in the model, and it is
what lets you say "wrong answer" at all. Without it you can only check that the
rule is self consistent, which is not the property anyone cares about.

Once you have it, the two failure directions have names. Soundness failing is a
false positive, which is a link that should not exist. Completeness failing is a
false negative, which is a link that is missing. Check both, in separate
assertions, because almost every fix to one costs you some of the other and you
want the solver to tell you how much.

## Refuse to answer when the evidence is ambiguous

The single most common fix for a false positive is to make the rule decline
rather than guess.

```alloy
fun matched : Payment -> Invoice {
  { r : Payment, c : Invoice | c in candidates[r] and one candidates[r] }
}
```

`one candidates[r]` says there is exactly one candidate. This converts a wrong
answer into no answer, which is usually the right trade when a wrong link moves
money. The check for completeness then tells you exactly which real pairs you
gave up, and that set is your work queue for a human review path.

## Write assumptions as named predicates

```alloy
pred no_foreign_refs {
  all r : Payment | no r.truth implies no (r.reportedRef & Invoice.ref)
}

assert v2_is_sound { no_foreign_refs implies sound[matched] }
check v2_is_sound for 6 expect 0
```

The same property with the assumption in a `fact` would pass and tell you
nothing. Written this way the result reads as "the rule is sound as long as a
reference number of ours never shows up on a payment for an invoice we did
not issue", which is a sentence someone who knows the counterparties can confirm or
deny. When an assumption turns out to be false, you already know which check to
rerun.

Check the same property without the assumption too, with `expect 1`. That
records that the assumption is load bearing, and warns you if a later change
makes it irrelevant.

## Prove the rule can still fire

```alloy
run can_match { some matched } for 4 expect 1
```

An empty relation satisfies every safety property. A model that contradicts
itself makes every `check` pass. Both failures look exactly like success, so
every model needs at least one `run` with `expect 1`. If a `check` result
surprises you by passing, this is the first thing to test.

## Pin a concrete case as a regression test

When a counterexample turns out to be a real bug, freeze it. Quantify the exact
atoms, fix every signature and every field, and give the command an `expect`.

```alloy
run collision_case {
  some disj i0, i1 : Invoice, p0 : Payment, a0 : Account, r0 : Ref {
    Invoice = i0 + i1
    Payment = p0
    account = i0->a0 + i1->a0
    ref     = i0->r0 + i1->r0
    reportedAccount = p0->a0
    reportedRef     = p0->r0
    truth   = p0->i0
    no matched
  }
} for 2 Invoice, 1 Payment, 1 Account, 1 Ref, 1 Vendor expect 1
```

`disj` is what forces the variables onto different atoms. In the visualizer,
File then Export To then Predicate writes this block for you from whatever
instance is on screen, which is much faster than typing it.

## Migrations

Model both shapes and the mapping between them, then check that the mapping
loses nothing and invents nothing.

```alloy
sig OldRow {}
sig NewRow {}
one sig Migration {
  maps : OldRow -> NewRow
}

assert every_row_arrives    { all o : OldRow | one o.(Migration.maps) }
assert nothing_is_invented  { all n : NewRow | some (Migration.maps).n }
assert no_row_is_duplicated { all disj o1, o2 : OldRow | no (o1.(Migration.maps) & o2.(Migration.maps)) }
```

Then add whatever the old shape guaranteed and check that the new shape still
guarantees it. The bugs this finds are the ones where two old rows collapse into
one new row because the new key is not as unique as you assumed.

## Workflows with retries and reversals

Model the states, the events, and the guards, then assert the thing that must
never happen twice. `posting.als` is this pattern in full. The general
shape is in [behavior.md](behavior.md), and the property is usually
one of these.

- An action never happens twice for the same subject.
- A subject never ends up in two states at once.
- Every state that is entered can be left, so nothing gets stuck.
- After a reversal the system is back where it started, or it is provably not,
  which is often the real finding.

## Permission and reachability models

Use transitive closure. The property is almost always that a set of resources
is unreachable from a set of principals.

```alloy
sig Tenant {}
abstract sig Node { grants : set Node }
sig Principal extends Node { owner : one Tenant }
sig Group     extends Node {}
sig Resource  extends Node { holder : one Tenant }

assert no_cross_tenant_access {
  all p : Principal, r : Resource |
    r in p.^grants implies r.holder = p.owner
}
check no_cross_tenant_access for 5 expect 1
```

Closure only works on a relation whose two columns are the same type, which is
why principals, groups, and resources all extend one signature here. If you
declare `grants : Principal -> Resource` instead, Alloy warns that the closure
is redundant, because a path can never be longer than one hop.

The counterexamples here tend to be two hop paths through a shared group that
nobody drew on the whiteboard.

## Debugging a model

| Symptom | Likely cause |
|---|---|
| Every `check` passes, including ones you expected to fail | The model contradicts itself. Add a `run` with `expect 1` and see if it is SAT |
| A counterexample makes no sense as a real record | A missing fact. Write the constraint that rules it out, and ask whether the code enforces it |
| A behavioral counterexample changes a relation nothing touched | A missing frame condition in one of the event predicates |
| A counterexample keeps appearing with an impossible starting state | You are checking an inductive step from an unreachable state. Strengthen the invariant |
| The check does not come back | Drop the bound, drop the Int bitwidth, or split one assertion into several |
| UNSAT at every bound you try, and you do not believe it | Check the negation. `check { not P }` should be SAT. If both are UNSAT the model is empty |

## Keep the model small

Every field you add multiplies the search. Include only what the property
mentions. A matching model does not need the service date, the charge amount, or
the counterparty name unless the rule reads them. When you need a second property, it
is usually better to write a second small model than to grow the first one.
