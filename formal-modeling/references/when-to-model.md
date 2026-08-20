# When modeling pays off, and what it cannot do

## The bar

Model when all three of these are true.

1. The design has more cases than you can enumerate in your head. Interleaving,
   partial failure, and identifier collisions all get past a reviewer.
2. Being wrong is expensive or silent. Money moved to the wrong place, data
   deleted, a permission granted, a record merged. Silent is worse than
   expensive, because nobody files the ticket.
3. The property can be stated as a sentence about structure or ordering. "No
   payment is ever linked to the wrong invoice" qualifies. "The report is fast
   enough" does not.

If only the first is true, write a property based test instead. If only the
second, write the invariant as an assertion in the code.

## What it will not do

- Nothing about time, throughput, or load. Amazon named this as the class of
  problem formal specification did not help with. Their example was a
  slowdown causing client retries that add load and cause more slowdown, which
  no logic bug explains and no model predicts.
- Nothing about the code. A model checks the design you wrote down. If the
  production matcher reads a field your model does not have, the check says
  nothing about the production matcher.
- No answer above the bound. A `check` that passes for 6 atoms says nothing
  about 7. In practice that is a much weaker limit than it sounds, and the next
  section says why.
- No help if you cannot state the property. If the requirement is genuinely
  unclear, modeling will expose that, which is useful, but it will not settle
  it.

## Why a small bound is worth trusting

Bounded checking rests on the idea that most bugs show up in small instances,
because a counterexample usually needs two or three of a thing rather than
twenty. The field's experience supports it. Zave found bugs in a published,
award winning protocol by checking networks of five to eight members. The
matching example in this skill finds its bug with two invoices and one
payment.

Practical advice follows from that.

- Start at 3 or 4 atoms. Read the counterexample. A small one is a story you
  can retell.
- Raise the bound after the check passes, until the solve time annoys you. Stop
  there and write the number in a comment.
- If you want an answer with no bound on trace length, use an inductive
  invariant instead of a bigger step count. Two short checks replace an
  unbounded search. See [alloy/behavior.md](alloy/behavior.md).
- Where the bound really does worry you, the honest move is to say so in the
  model. A comment saying which cases were never checked is worth more than a
  passing check nobody has read.

## Effort, measured in lines

The evidence on effort is better than the reputation suggests, and the honest
unit is lines of model.

- Amazon's production TLA+ specifications ran from 102 to 939 lines, and found
  one to three design bugs each. Engineers "from entry level to Principal have
  been able to learn TLA+ from scratch and get useful results", some of them
  without help or training.
- One engineer wrote a specification for an algorithm with a known subtle bug
  that had survived multiple design reviews and code reviews, and had only
  surfaced after months of testing. The model checker found it immediately. It
  then rejected the team's already reviewed fix, and accepted a stronger one.
- Zave's Chord model was about 100 lines for the full protocol with seven
  events.

The models in this skill are under 100 lines each and the whole file checks in
under a second. That is the normal size. If your model is growing past a few
hundred lines, it is probably answering more than one question, and it should be
split.

## The part that changed

The barrier used to be the language. Alloy, TLA+, and Lean are unlike the
languages most engineers use daily, the error messages assume you already know
the theory, and the payoff comes only after you can express a real property. So
the tools stayed with specialists, and the rest of the field treated formal
methods as impractical.

An agent that can write the model removes that barrier. You supply the property
and the domain knowledge, which is the part you already have and the part no
tool can supply. The agent supplies the syntax, the idioms, and the loop of
running the check and reading the counterexample. That makes it reasonable to
model something small that would never have justified learning a new language on
its own, e.g. a single matching rule.

Two cautions follow from that, and they are the whole reason to be careful here.

- A model an agent wrote and nobody read is worse than no model, because a
  passing check reads as evidence. Read the property and the assumptions, even
  if you skim the rest. Those are the two places a wrong model hides.
- A check that passes because the model is contradictory looks the same as a
  check that passes for a good reason. Always include a `run` with `expect 1`.
