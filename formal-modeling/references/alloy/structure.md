# The static part of an Alloy model

Everything here is about a single state. For change over time read
[behavior.md](behavior.md).

An Alloy model has four kinds of paragraph. Signatures declare the kinds of
thing that exist. Facts constrain what is possible. Predicates and functions
are named, reusable pieces. Commands ask the solver a question.

## Signatures and fields

```alloy
abstract sig Object {}
sig Dir extends Object {}
sig File extends Object {}
one sig Root extends Dir {}

sig Entry {
  object : one Object,
  name   : one Name
}
```

A signature is a set of atoms. An atom has no value of its own, so `Ref$0` means
nothing except that it is one reference number, distinct from `Ref$1`. A
field is a relation, which is a set of tuples. Writing `object : one Object`
inside `sig Entry` declares a relation from `Entry` to `Object` where each entry
has exactly one object.

| Form | Meaning |
|---|---|
| `sig A {}` | A set of atoms named A |
| `one sig A {}` | Exactly one atom, so A behaves as a constant |
| `abstract sig A {}` | A has no atoms of its own, only those of its extensions |
| `sig B extends A {}` | B is a subset of A, and sibling extensions are disjoint |
| `sig B in A {}` | B is a subset of A, and may overlap other subsets |
| `enum Color { Red, Green }` | A fixed set of named, distinct atoms |

Field multiplicities are `one` for exactly one, `lone` for zero or one, `some`
for one or more, and `set` for any number. Use the tightest one that is true.
Every multiplicity you state is a constraint the solver enforces for free, and
every one you leave as `set` is a case you will have to rule out by hand later.

A block after a signature is a signature fact, and its constraints apply to
every atom of that signature with `this` bound to the atom.

## Facts, predicates, functions, assertions

```alloy
fact payment_echoes_the_invoice {
  all r : Payment | some r.truth implies r.reportedRef = r.truth.ref
}

pred ref_is_unique_per_invoice {
  all disj c1, c2 : Invoice | no (c1.ref & c2.ref)
}

fun candidates [r : Payment] : set Invoice {
  { c : Invoice | c.ref = r.reportedRef }
}

assert v2_is_sound {
  no_foreign_refs implies sound[matched_v2]
}
```

A fact always holds, everywhere, in every command. A predicate is a named
formula you choose where to apply. A function returns a relation. An assertion
is a claim you want challenged, and it is only usable in a `check`.

Prefer predicates to facts for anything you are not certain of. A fact is
invisible in the result. A predicate that appears in the assertion tells the
reader exactly what the result depends on, and lets you check the same property
with and without it. The one thing that belongs in a fact is a constraint that
is true by construction, e.g. that a database column is not null.

A function with no parameters is the normal way to define a derived relation,
including the output of the rule you are testing.

```alloy
fun matched : Payment -> Invoice {
  { r : Payment, c : Invoice | c in candidates[r] and one candidates[r] }
}
```

A predicate can take a relation as a parameter, which is how you state one
property once and check several rules against it.

```alloy
pred sound [m : Payment -> Invoice] {
  all r : Payment, c : Invoice | r->c in m implies c = r.truth
}
```

## Operators

Alloy has one kind of value, the relation. A set is a relation with one column
and a scalar is a set with one tuple, so the same operators work on all of them.

| Operator | Name | Note |
|---|---|---|
| `+` `-` `&` | union, difference, intersection | On integers these are still set operators. `1+2` is the set `{1,2}`, not 3 |
| `->` | product | `a->b` builds tuples. Also used to declare a relation type |
| `.` | join | `d.entries` follows the relation forward. `entries.e` follows it backward |
| `[]` | box join | `f[x]` is the same as `x.f`, and reads better for functions |
| `~` | transpose | Reverses every tuple |
| `^` `*` | transitive closure, reflexive transitive closure | Reachability of any depth. Only for binary relations |
| `<:` `:>` | domain, range restriction | `Dir <: entries` keeps only tuples starting in Dir |
| `++` | override | `f ++ x->y` replaces the tuples of f that start at x |
| `#` | cardinality | Gives an integer, so it is bounded by the Int scope |
| `in` `=` | subset, equality | `in` is the workhorse. Multiplicity keywords are about size, `in` is about membership |

Formulas use `no`, `some`, `lone`, and `one` in front of an expression to talk
about its size, e.g. `no candidates[r]` says the set is empty. The same four
words plus `all` work as quantifiers, e.g. `all r : Payment | ...`. Add
`disj` to force the bound variables apart, as in `all disj c1, c2 : Invoice`.

Logical connectives are `not`, `and`, `or`, `implies`, and `iff`, with the
symbol forms `!`, `&&`, `||`, `=>`, `<=>`. A set comprehension is
`{ x : A | formula }`. `let x = expr | formula` names a subexpression.

The most common mistake is reading `.` as field access on an object. It is a
join over sets. `Payment.truth` is the set of all invoices any payment points at,
and `truth.Invoice` is the set of all payments that point at any invoice. That is a
feature, and it is how you ask "which lines point here" without declaring a
back reference.

## Commands and bounds

```alloy
check v2_is_sound for 6 expect 0
check v1_is_sound for 4 but exactly 2 Invoice expect 1
run  v2_can_match for 4 expect 1
run  named_case {} for 3 Object, 2 Name, 2 Entry
```

`for N` bounds every top level signature at N atoms. The default is 3. `but`
overrides one signature, and `exactly` makes the bound precise instead of an
upper limit. Subset signatures and enums cannot take a bound, so constrain their
size with a formula instead.

`expect 0` means you expect UNSAT and `expect 1` means you expect SAT. The
command line tool exits nonzero when the result disagrees, which is what makes
a model file usable as a test.

Choosing a bound is a judgment call. Start at 3 or 4, because a small
counterexample is much easier to read and the search is much faster. Raise it
once the check passes, until it gets slow. Experience across the field is that
small instances find nearly all the bugs, which is why this is worth doing at
all. Zave's Chord analysis, which found bugs no reviewer had, ran on networks of
five to eight members.

## Integers, and why to avoid them

Integers in Alloy are bounded and they wrap around silently. `for 4 Int` means
four bit signed integers, so the range is -8 to 7, and the scope is exact rather
than an upper limit. The overall `for N` does not change it. With the default
bitwidth, `5.plus[1].plus[6]` is -4.

Arithmetic uses functions, not the set operators: `add`, `sub`, `mul`, `div`,
`rem`, `min`, `max` from `util/integer`, or the `plus` and `minus` box forms.
Comparison uses `>`, `<`, `>=`, `<=`. To add up an expression over a set, use
the sum quantifier, e.g. `(sum f : File | f.size)`.

Money and counts are usually the wrong thing to put in a model. If the property
is "the amounts balance", a model with a four bit range will either lie or
explode. Model the identity and the structure, and leave arithmetic to a
property based test over the real code. When you do need integers, keep the
bitwidth as small as the property allows, because the solver turns every integer
into bits.

## Modules

```alloy
open util/integer
open util/ordering[State] as so
open util/relation
```

The standard library includes `util/integer`, `util/relation`,
`util/graph`, `util/boolean`, `util/sequniv`, and `util/ordering`.
`util/ordering[S]` imposes a total order on the atoms of `S` and gives you
`first`, `last`, `next`, and `prev`. In Alloy 6 you rarely need it for time,
because `var` and the temporal operators do that job better. It is still the
right tool for an ordering that is part of the domain, e.g. a priority ranking.
