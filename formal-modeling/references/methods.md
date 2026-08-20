# Property based testing, model checking, and proof

These three names get used as if they were the same activity. They are not.
They differ in what you write, what the tool runs it against, and what a pass
actually tells you. Pick by which of those three you need.

## The short version

Property based testing runs the real code on many generated inputs and checks a
rule after each run. A pass means the rule held for the inputs that were tried.

Model checking runs a separate description of the design through a solver that
searches every case up to a size you set. A pass means no case inside that size
breaks the property.

Proof, which is what "formal verification" usually means, is a mathematical
argument that a program satisfies a statement for every input, with no size
limit. A pass means the statement is true, given the definitions you wrote.

Each one is stronger than the one above it, and each one asks more of you.

## Side by side

| | Property based testing | Model checking | Proof |
|---|---|---|---|
| What you write | A property, plus a way to generate inputs | A separate model of the design | A specification, plus a proof |
| What it runs against | The real code | The model, not the code | The real code, or a model you then implement |
| What a pass means | No failure in the cases tried | No failure up to the bound | True for all inputs |
| What a failure gives you | A shrunk failing input | A counterexample, or a trace of steps | A stuck proof, which is a hint |
| What you have to write | A property and a generator, so tens of lines | A model of the design, usually under a few hundred lines | A specification and a proof, where the proof is normally the larger part |
| Main risk | The generator never produces the bad case | The model does not match the code | The specification is wrong |
| Tools | Hypothesis, fast-check, proptest | Alloy, TLA+ with TLC, P, Quint | Lean, Dafny, Rocq |

The row that matters most is the third one. Property based testing and proof
both talk about the real code. Model checking does not. That is the trade it
makes, and it is why model checking is fast enough to use on a design you have
not built yet.

## Property based testing

You state a rule that should hold for every input, and the library generates
inputs and tries to break it. When it finds a failure it shrinks the input to
the smallest version that still fails, which usually makes the cause obvious.

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sort_keeps_every_element(xs):
    assert sorted(sorted(xs)) == sorted(xs)
    assert len(sorted(xs)) == len(xs)
```

Use it when the code exists and you can say what should always be true about
its output. For the Python details and a runnable example, read
[hypothesis/guide.md](hypothesis/guide.md). It is the cheapest of the three and it should be the default for
anything with a clear input and output.

Its stateful form is closer to model checking than most people realize. A
`RuleBasedStateMachine` generates sequences of operations and checks an
invariant after each one, so you are exploring orderings, against the real
object, without a bound. What you lose is exhaustiveness. It samples orderings
rather than covering them.

## Model checking

You write a model, which is a description of the states the system can be in
and the ways it can move between them. Then you state a property, and the
checker searches. Alloy solves a constraint problem with a SAT solver. TLC walks
the reachable states. Either way it covers everything inside the bound you gave,
which is why it finds cases no person would think to try.

The reason to use it before the code exists is that a design bug found in a
model is a change to one file, and the same bug found after two services depend
on it is a change to a contract, a migration, and both call sites.

The catch is the gap between the model and the code. Nothing enforces it. See
[other-tools.md](other-tools.md) for the three ways to narrow it, which are a
reference model compared in tests, trace validation, and turning every
counterexample into a unit test.

## Proof

You write down what the program must satisfy and then prove it, with a tool that
checks every step of the argument. There is no bound, no sampling, and no gap
between the model and the code, because the thing you proved something about is
the thing that runs.

Two tools are worth knowing. Dafny is a programming language with
preconditions, postconditions, and loop invariants built in, and an SMT solver
checks them as you type. It is the shortest path to a verified version of one
function. Lean is a functional language and a proof assistant, where you write
the proofs yourself and get much more expressive power in return.

The cost is real and it is mostly in the specification, not the proof. Writing
down exactly what "correct" means for a nontrivial function is the hard part,
and a proof of the wrong statement is worth nothing.

## What sits underneath all of them

SAT solvers answer whether a set of true or false variables can be assigned to
satisfy a formula. SMT solvers do the same over integers, arrays, and bit
vectors as well. They are the engine, not the method. Alloy compiles to SAT,
Dafny and CrossHair and Apalache all call an SMT solver, and Z3 is the one you
would call yourself for a question that is purely about arithmetic.

A type checker belongs on this page too, and it is the cheapest tool here. It
proves a narrow class of claim about every line of the codebase, on every save.
Anything you can push into a type is a property you never have to test, model,
or prove. See [types.md](types.md) for where it fits and where it runs out.

## Industry examples

- Authorization, proved in Lean. AWS built Cedar, its authorization policy
  language, using what they call verification guided development. They modeled
  the evaluator, the authorizer, and the validator in Lean and proved
  correctness and security properties about them, and the Cedar symbolic
  compiler is itself written in Lean. See
  [Lean and Cedar](https://lean-lang.org/use-cases/cedar/) and the
  [AWS post](https://aws.amazon.com/blogs/opensource/lean-into-verified-software-development/).
  This is the right shape for authorization, because the rules are small, the
  cost of a wrong answer is a security incident, and the same engine runs
  everywhere.
- Replication, model checked in TLA+. On DynamoDB, a model check found a bug
  that could lose data, and the shortest trace showing it was 35 steps. That bug
  had already survived design reviews, code reviews, and extensive fault
  injection testing. Seven teams at Amazon were using TLA+ when the paper was
  written. See
  [Newcombe et al., 2015](https://lamport.azurewebsites.net/tla/formal-methods-amazon.pdf).
- A published protocol, model checked in Alloy. Pamela Zave modeled Chord in
  about 100 lines and found that no published version was correct, checking
  networks of five to eight members. See
  [Zave, 2012](https://dl.acm.org/doi/10.1145/2185376.2185383).
- A storage node, checked against reference models. Amazon S3 compared a
  production key value storage node against simple executable reference models,
  driven by generated operation sequences. That kept 16 issues out of
  production, including crash consistency and concurrency bugs, and engineers
  who were not formal methods specialists extended the checks as the system
  changed. See
  [Bornholt et al., SOSP 2021](https://www.amazon.science/publications/using-lightweight-formal-methods-to-validate-a-key-value-storage-node-in-amazon-s3).
- Distributed systems as state machines, model checked in P. AWS uses P on S3,
  EBS, DynamoDB, MemoryDB, Aurora, EC2, and IoT. See
  [the P documentation](https://p-org.github.io/P/).
- Two long running proofs, for scale. The seL4 microkernel was proved correct
  against its specification in Isabelle, and the CompCert C compiler was proved
  to preserve program behavior in Coq. Both are large specialist projects whose
  proofs are far bigger than the programs they verify. They are the reason
  formal verification got its reputation for being impractical, and they are not
  the shape of work described anywhere else on this page.

Notice the pattern. The proofs went to small components where the same code runs
everywhere and a wrong answer is severe. The model checking went to designs with
many orderings and failure modes. The property based testing went to a large
existing implementation where a reference model was easier to write than a
proof.

## Choosing

| The problem | Reach for |
|---|---|
| I have code and a rule that should always hold about its output | Property based testing |
| I have code and a rule about sequences of operations | Stateful property based testing |
| I am designing something with orderings, retries, or failure modes | Model checking |
| I am designing a rule that must never produce a wrong answer | Model checking, with soundness and completeness as separate properties |
| One small function must be right for every input, forever | Proof, in Dafny or Lean |
| The question is purely arithmetic, e.g. can these amounts fail to balance | An SMT solver directly |
| I want to stop a class of bug in all code, not one place | The type system, see [types.md](types.md) |

They combine. Model check the design, property test the implementation against a
reference model derived from that design, prove only the one function whose
failure you cannot tolerate, and push everything you can into types so that none
of the above has to cover it.

## Why this is worth learning now

The barrier was never that these methods do not work. The evidence above is a
decade old. The barrier was that each one needs a language and a set of idioms
unlike normal programming, the error messages assume you know the theory, and
the payoff only arrives once you can express a real property.

An agent can write the model, run the checker, and read the counterexample back
to you. What it cannot supply is the property and the domain knowledge, which
are the parts you already have. So the useful split is that you decide what must
never happen and which assumptions about the world are safe, and the agent
handles the syntax and the loop.

Two things to keep doing yourself, because they are where a wrong result hides.
Read the property, and read the assumptions. If those two are right, a passing
check means something. If they are not, it means nothing at all, and it will
still look like a pass.
