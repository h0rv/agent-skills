---
name: formal-modeling
description: Check a design with a model checker instead of guessing, using Alloy 6 first and TLA+, Lean, Dafny, property based testing, or an SMT solver when Alloy is the wrong fit. Use whenever correctness is the point rather than the code, e.g. matching or deduplication rules that must not produce a false positive, a state machine or workflow with retries and reversals, a data migration, a permission or authorization model, an invariant that must hold over every ordering of events, a protocol between services, or any question of the form "can this ever happen" or "is this always true". Also use whenever the user mentions Alloy, TLA+, PlusCal, TLC, Lean, Dafny, Z3, SMT, SAT, model checking, formal methods, formal verification, property based testing, Hypothesis, invariants, or proving a property, or asks how these methods differ, which one fits a problem, or how type systems relate to formal methods, and use it before writing a tricky algorithm rather than after the bug reaches production.
---

# Formal modeling: check the design before you build it

A model is a small description of what a system is allowed to do, written in a
language a solver can search. You state a property. The solver then searches
every case inside a bound you set and either finds a case that breaks the
property or reports that none exists. A test checks the cases you thought of. A
model checker checks the cases you did not.

This skill is a router. Start with Alloy 6, which is the default tool here.
Read the reference for the topic in front of you rather than reading everything.

## Why this is worth doing

Formal modeling used to need a specialist. It does not any more, because you can
write the model. The cost of learning a language like Alloy used to be the whole
barrier. Running one more check is now cheap enough that checking a design can
be a normal part of the work.

The evidence that it finds real bugs is not new.

- Amazon reported using TLA+ on seven teams. On DynamoDB's replication system a
  model check found a bug that could lose data, and the shortest trace that
  showed the bug was 35 steps long. The paper says that bug "had passed
  unnoticed through extensive design reviews, code reviews, and testing".
  Their production specifications ran from 102 to 939 lines. See
  [Newcombe et al., How Amazon Web Services Uses Formal Methods, 2015](https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf).
- Pamela Zave modeled the Chord protocol in about 100 lines of Alloy and found
  that no published version of Chord was correct. See
  [Using lightweight modeling to understand Chord, 2012](https://dl.acm.org/doi/10.1145/2185376.2185383).
- Amazon S3 used lightweight formal methods on a storage node and kept 16
  issues out of production, including crash consistency and concurrency bugs.
  See [Bornholt et al., SOSP 2021](https://www.amazon.science/publications/using-lightweight-formal-methods-to-validate-a-key-value-storage-node-in-amazon-s3).

## When to reach for a model

The signal is that the design has more cases than you can hold in your head,
and that being wrong is expensive.

| Situation | Why a model helps |
|---|---|
| A matching, linking, or deduplication rule that must not produce a false positive | The solver finds the pair of records that satisfies your rule and is still the wrong answer |
| A workflow with retries, reversals, timeouts, or partial failure | The solver tries every interleaving, including the ones your tests never run |
| A data migration or backfill | The solver checks that the new shape still holds every record the old shape held |
| A permission or authorization model | The solver looks for a path to a resource that no rule was meant to allow |
| Two services that must agree on state | The solver finds the ordering where they disagree |
| A rule you are about to make stricter or looser | The solver tells you exactly which cases changed |

## When not to reach for a model

- The question is about performance, latency, or load. A model says nothing
  about timing. Amazon called this out directly as the class of problem formal
  specification did not help them with.
- The bug is in the code and not in the design. A model checks the design you
  wrote down. See [references/other-tools.md](references/other-tools.md) for
  ways to tie a model to running code.
- The rule is small enough to enumerate by hand, and you already did.
- Nobody will read the model again. Nobody trusts a model that does not live in
  the repository and does not run in continuous integration.

## The loop

1. Write the property in one plain sentence before you write any Alloy. If you
   cannot say it, the model will not help you yet.
2. Model the smallest thing that can break the property. Leave out every field
   the property does not mention.
3. Write down the assumptions about the world as named predicates, not as facts
   buried in the model. An assumption you can name is an assumption a reviewer
   can reject.
4. Run the check. Read the counterexample as a concrete story about real
   records. If it is not a story you believe, your model is wrong, not the
   design.
5. Fix the design or fix the assumption, then run again.
6. Add a `run` command that proves the rule can still fire. A rule that never
   fires satisfies every safety property.
7. Commit the model next to the code it describes, with `expect 0` or
   `expect 1` on every command, and run it in continuous integration.

## Where to read next

| When you are... | Read |
|---|---|
| Deciding between property based testing, model checking, and proof, or explaining the difference | [references/methods.md](references/methods.md) |
| Asking where the type system fits, or whether a property belongs in a type instead | [references/types.md](references/types.md) |
| Deciding whether to model at all, or how big to make the bound | [references/when-to-model.md](references/when-to-model.md) |
| Installing Alloy, running it from a terminal, or wiring it into CI | [references/alloy/setup.md](references/alloy/setup.md) |
| Writing the static part of a model, which is signatures, fields, facts, and checks | [references/alloy/structure.md](references/alloy/structure.md) |
| Modeling change over time, which is `var`, `always`, `eventually`, and traces | [references/alloy/behavior.md](references/alloy/behavior.md) |
| Looking for a known shape, e.g. matching rules, migrations, or state machines | [references/alloy/patterns.md](references/alloy/patterns.md) |
| Reading a full example end to end, from a wrong rule to a checked one | [references/alloy/walkthrough.md](references/alloy/walkthrough.md) |
| Property based testing real Python code, with `@given` or a stateful machine | [references/hypothesis/guide.md](references/hypothesis/guide.md) |
| Finding that Alloy is the wrong tool, or reaching for TLA+, Lean, Dafny, or an SMT solver | [references/other-tools.md](references/other-tools.md) |

Each tool directory holds its own runnable code, and reading that first is
usually faster than reading the prose. `references/alloy/matching.als` checks a
payment matching rule for false positives, `references/alloy/posting.als` checks
a ledger workflow where entries can be reversed, and
`references/hypothesis/test_matching.py` tests the same two rules against real
Python.

## Quick self-check

- Did I state the property before writing the model?
- Are my assumptions named predicates that appear in the assertion, so a reader
  can see what the result depends on?
- Does UNSAT here mean what I think it means? It means no counterexample exists
  inside the bound, and nothing about cases larger than the bound.
- Did I check that the rule can still fire, and that the model is not
  contradictory?
- Is the counterexample a story I can retell using real records?
- Does every command carry an `expect` annotation, so continuous integration
  fails when a result changes?
