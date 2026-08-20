# The rest of the toolbox

Alloy is the default in this skill because it is small, it is one jar, and the
counterexamples are readable. It is not always the right tool. This file is a
map, not a tutorial. Follow the links when one of these is the fit.

## Choosing

| The question is | Use |
|---|---|
| Does this structure or rule ever admit a case it should not | Alloy |
| Does this protocol hold up under every interleaving and failure, with rich state such as sequences and nested records | TLA+ with the TLC checker |
| Same, but I would rather write state machines than mathematics | P, or Quint |
| Is this specific function correct for every input, with no bound at all | Lean, or Dafny |
| Do these numeric constraints have a solution, or is this arithmetic reachable | An SMT solver, e.g. Z3 |
| Does the running Python code hold this property | Hypothesis, or CrossHair |
| Does the running code do what the model said | Trace validation, or a reference model in a test |

## Where Alloy runs out

Amazon evaluated Alloy first and moved to TLA+. Their reason is specific and
still true. They wrote that they "could not find a practical way in Alloy to
represent rich data structures such as dynamic sequences containing nested
records with multiple fields", and that "several of the real-world
specifications we have written in TLA+ would have been infeasible or impossible
in Alloy". They also liked Alloy's model, which is traces over states made of
sets and relations, and Alloy 6 has since added the temporal logic they wanted.
The data structure limit remains.

Use Alloy for relations and identity. Use TLA+ for queues of records with
fields, for message histories, and for arithmetic over state.

## TLA+ and PlusCal

TLA+ is Leslie Lamport's specification language. TLC is its model checker, and
it explores the reachable state space rather than solving a bounded constraint
problem, which is why it handles long behaviors well. PlusCal is a more
imperative syntax that compiles to TLA+, and it is easier to write for anything
that looks like an algorithm. TLAPS proves TLA+ theorems when checking is not
enough. Apalache is a symbolic checker built on an SMT solver, which handles
larger state than TLC on some problems.

Start with the [TLA+ home page](https://lamport.azurewebsites.net/tla/tla.html)
and the [tlaplus repository](https://github.com/tlaplus/tlaplus). The tools ship
as a single jar, and there is a Visual Studio Code extension.

## P and Quint

[P](https://p-org.github.io/P/) models a system as communicating state
machines and checks it by exploring message interleavings and failures. AWS uses
it on S3, EBS, DynamoDB, MemoryDB, Aurora, EC2, and IoT. If your design is
already drawn as boxes sending messages, P is a shorter path than TLA+.

[Quint](https://quint.sh/) is TLA+ semantics with a syntax closer to a
programming language, plus a simulator and a type checker. `quint run` samples
executions, and `quint verify` model checks with Apalache. It needs a JDK.

## Lean and Dafny, for verifying an implementation

Both remove the bound entirely, at a much higher cost per line.

[Lean 4](https://lean-lang.org/) is a functional language and a proof
assistant. You write the program and prove theorems about it, with no bound on
input size. AWS built the Cedar authorization language this way, modeling and
proving the evaluator, authorizer, and validator in Lean, and they call the
practice verification guided development. See
[Lean and Cedar](https://lean-lang.org/use-cases/cedar/) and the
[AWS post](https://aws.amazon.com/blogs/opensource/lean-into-verified-software-development/).
The learning curve is the real cost, and it is the steepest on this page.

[Dafny](https://dafny.org/) is a language with preconditions,
postconditions, loop invariants, and termination checks built in, verified by an
SMT solver as you write. It compiles to C#, Java, JavaScript, Go, and Python. It
is the shortest path to a verified implementation of one algorithm.

Neither is a good fit for exploring a design. Use Alloy or TLA+ to find out what
the design should be, then use these only where correctness of a specific
function is worth the effort.

## SMT solvers

An SMT solver answers whether a set of constraints over integers, reals, arrays,
and bit vectors has a solution. Alloy uses a SAT solver underneath and its
integers are small and wrap around, so arithmetic properties are exactly where
you should stop using Alloy and call a solver directly.

[Z3](https://github.com/Z3Prover/z3) has a Python package, `z3-solver`, and it
is the practical choice for a question such as whether a set of allocation
rules can distribute a payment so the parts do not sum to the whole.
[cvc5](https://cvc5.github.io/) is the other main option.

## Checking the code, not the design

A model is a claim about a design. These are the ways to connect it to what
actually runs.

Write the model as an executable reference and compare. Amazon S3's storage node
work built simple reference implementations as the specification and compared
the real implementation against them, which kept 16 issues out of production
including crash consistency and concurrency bugs. Non specialists on the team
could extend the checks. See
[Bornholt et al., SOSP 2021](https://www.amazon.science/publications/using-lightweight-formal-methods-to-validate-a-key-value-storage-node-in-amazon-s3).

In Python, that comparison is a stateful property based test.
[Hypothesis](https://hypothesis.readthedocs.io/en/latest/stateful.html) has
`RuleBasedStateMachine`, covered in full in
[hypothesis/guide.md](hypothesis/guide.md), where `@rule` methods are the events, `Bundle` carries values between them, and
`@invariant` methods check a property after every step.
Keep a simple model of the state next to the real object and assert they agree.
This is the same shape as an Alloy behavioral model, run against the real code.

```python
class MatcherComparison(RuleBasedStateMachine):
    @rule(line=lines)
    def match(self, line):
        assert real_matcher(line) == self.model_match(line)
```

[CrossHair](https://crosshair.readthedocs.io/en/latest/introduction.html)
goes further for pure functions. It runs your Python with symbolic values and an
SMT solver, so it finds counterexamples rather than sampling for them.
`crosshair check` verifies contracts, `crosshair diffbehavior` reports where two
functions differ, which is the tool to reach for when a refactor is supposed to
change nothing.

Trace validation goes the other direction. Instrument the running program to log
the values of the specification's variables, then have the checker confirm the
recorded trace is a behavior the specification allows. Applied to several
distributed programs, it found a mismatch between specification and
implementation in every case. See
[Cirstea et al., SEFM 2024](https://arxiv.org/abs/2404.16075).

The cheapest version of all of this is a unit test. When a check produces a
counterexample that turns out to be a real bug, write that exact case as a test
in the real code before you fix it.
