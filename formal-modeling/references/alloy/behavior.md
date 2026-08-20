# Modeling change over time

Alloy 6 added mutable state and linear temporal logic to the language. Before
version 6 you modeled time by hand, usually by adding a `Time` column to every
relation. Do not do that any more. The old idiom is still in older tutorials and
in the `util/ordering` chapters of older books, and it is worse in every way.

An Alloy 6 instance is no longer a single state. It is a trace, which is an
infinite sequence of states that eventually loops. A check searches traces.

## Mutable declarations

```alloy
sig Line {}

var sig posted   in Line {}
var sig reversed in Line {}

sig Client {
  var connected_to : lone Server
}
```

`var` marks a signature or a field as able to change from one state to the next.
Anything without `var` is fixed for the whole trace. Keep the universe of atoms
static and let the relations over it change, because a static universe makes the
search much smaller. In the example above the set of lines never changes, but
which lines are posted does.

`x'` is the value of `x` in the next state. It is only meaningful inside a
formula about a transition.

## Operators

| Operator | Meaning |
|---|---|
| `always F` | F holds now and in every later state |
| `eventually F` | F holds now or in some later state |
| `after F` | F holds in the next state |
| `F until G` | F holds in every state up to the one where G holds, and G does hold |
| `G releases F` | F holds until G holds, or F holds forever |
| `F ; G` | F holds now and G holds next. The same as `F and after G` |
| `before F` | F held in the previous state |
| `historically F` | F held in every earlier state |
| `once F` | F held in some earlier state |
| `F since G` | G held at some point and F has held ever since |

The past operators have no equivalent in most other model checkers, and they
are worth knowing because a guard is often easier to write about the past. For
example, `historically t not in Token.shared` says a share token has never been
used before, which is much shorter than threading a used set through every
event.

## The shape of a behavioral model

Four pieces, always in the same order.

First, the initial state. A plain fact with no temporal operator constrains only
the first state of the trace.

```alloy
fact init {
  no posted
  no reversed
}
```

Second, one predicate per event. Each one has a guard saying when the event can
happen and an effect saying what the next state looks like. Every mutable
relation needs a value in the next state, including the ones the event does not
touch. Those lines are frame conditions, and forgetting one lets the solver
change that relation to anything at all, which produces baffling
counterexamples.

```alloy
pred post_safe [l : Line] {
  l not in posted             // guard
  l not in reversed           // guard
  posted'   = posted + l      // effect
  reversed' = reversed        // frame condition
}
```

Third, a stutter event, which changes nothing. Without it a trace has to keep
doing something forever, so the solver reports liveness failures that are
really just the model refusing to sit still.

```alloy
pred stutter {
  posted'   = posted
  reversed' = reversed
}
```

Fourth, the transition relation, which says every step is one of the events.

```alloy
pred next_safe { (some l : Line | post_safe[l] or reverse[l]) or stutter }
```

Putting that in an assertion as `always next_safe implies P` rather than in a
fact lets one file hold two versions of a rule and check both, which is how
`posting.als` compares a lax rule with a safe one.

## Bounding the trace

```alloy
check safe_never_posts_twice for 3 but 10 steps expect 0
check inv_survives_every_step for 6 but 2 steps expect 0
run something_happens for 2 but 5 steps expect 1
```

`for N steps` means traces of up to N states, and the default is 10. `for M..N
steps` sets both ends. `for 1.. steps` asks for a complete check with no bound
on length, which needs Electrod and NuSMV or nuXmv installed separately.

There is a tension here. Atoms and steps multiply, so a model that checks in a
second at `for 3 but 10 steps` can hang at `for 6 but 20 steps`. Prefer more
atoms with fewer steps for structural properties, and more steps with fewer
atoms for ordering properties.

## Safety, liveness, and fairness

A safety property says nothing bad ever happens. It is violated by a finite
prefix, so a bounded check finds real violations.

```alloy
assert shared_are_accessible {
  always shared.Token in uploaded - trashed
}
```

A liveness property says something good eventually happens. It needs an
assumption that the system keeps making progress, because otherwise the solver
answers with a trace that stutters forever. That assumption is a fairness
condition, and there are three strengths.

```alloy
pred unconditional_fairness { always eventually empty }
pred weak_fairness   { always (always some trashed implies eventually empty) }
pred strong_fairness { (always eventually some trashed) implies always eventually empty }
```

State the property as an implication so the assumption is visible in the result.

```alloy
check property_holds_if_fair {
  weak_fairness implies non_restored_files_will_disappear
} for 4 but 15 steps
```

Most invariants you care about in a data pipeline are safety properties. Reach
for liveness when the question is "does this ever finish", e.g. whether a retry
loop can spin forever.

## Inductive invariants, which is how you escape the step bound

A bounded trace check says nothing about traces longer than the bound. You can
often get an unbounded answer instead, from two checks that are each one or two
steps long.

```alloy
pred inv { no (posted & reversed) }

assert inv_holds_initially { inv }
check inv_holds_initially for 6 but 1 steps expect 0

assert inv_survives_every_step { (inv and next_safe) implies after inv }
check inv_survives_every_step for 6 but 2 steps expect 0
```

If the invariant holds in the first state, and every single step preserves it,
then it holds in every state of every trace of any length. The bound on atoms
still applies, but the bound on trace length is gone. This is also far faster,
so you can raise the atom bound a long way. The Practical Alloy book measured
the induction form at more than a hundred times faster than the unbounded trace
check on the same model.

The catch is that not every true invariant is inductive. If the preservation
check fails, look at the counterexample. If its starting state is one the system
could never actually reach, the fix is to strengthen the invariant until it
excludes that state, then check again. That loop is real work, and Zave's Chord
paper describes it honestly as sometimes failing to converge.

## Making events visible

By default a trace shows you states but not which event caused each transition,
which makes a long trace hard to read. This idiom turns events into derived
relations, which the visualizer then draws on each state. The plain text output
does not print derived functions, so use `alloy gui` when you want this.

```alloy
enum Event { Post, Reverse, Stutter }

fun post_happens : Event -> Line {
  { e : Post, l : Line | post_safe[l] }
}
fun stutter_happens : set Event {
  { e : Stutter | stutter }
}
```

It costs almost nothing at solve time and it is worth adding as soon as a trace
passes about four states.
