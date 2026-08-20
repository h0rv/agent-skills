# Running Alloy

Alloy 6.2.0 is one Java jar. It needs Java 17 or later. Everything below was
run on macOS with Alloy 6.2.0 and OpenJDK 21.

## Install

```sh
brew install openjdk@21
export PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH

mkdir -p ~/.local/share/alloy
curl -sL -o ~/.local/share/alloy/alloy.jar \
  https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v6.2.0/org.alloytools.alloy.dist.jar
```

A shell alias keeps the rest of this file short.

```sh
alias alloy='java -jar ~/.local/share/alloy/alloy.jar'
```

## Run a model

```sh
alloy exec -f -t text model.als        # run every command in the file
alloy exec -f -c v1_is_sound model.als # run one command by name
alloy commands model.als               # list the commands without running them
```

Each line of output names the command and its result.

```
00. check v1_is_sound              0    1/1     SAT
01. check v2_is_sound              0       UNSAT
```

SAT and UNSAT mean the opposite things for the two kinds of command, and this
is the single most common source of confusion.

| Command | SAT means | UNSAT means |
|---|---|---|
| `check` | a counterexample was found, so the assertion is false | no counterexample inside the bound, so the assertion held |
| `run` | an instance was found, so the situation is possible | no instance, so either the situation is impossible or the model contradicts itself |

## Flags worth knowing

| Flag | What it does |
|---|---|
| `-c, --command` | Run one command by name, by index, or by a wildcard |
| `-t, --type` | Output format, one of `none`, `text`, `table`, `json`, `xml`. `table` is the default |
| `-o, --output` | Directory for the solution files. The default is a directory named after the file |
| `-f, --force` | Overwrite that directory if it already has files in it |
| `-r, --repeat` | Ask for more than one solution. `0` means as many as exist |
| `-s, --solver` | Pick a solver. The default is `sat4j` |
| `-q, --quiet` | Drop the progress output |
| `-n, --nooverflow` | Only report instances where no integer arithmetic overflowed |

`alloy solvers` lists what is available. The bundled ids include `sat4j`,
`sat4j.light`, `minisat`, `glucose`, and `lingeling.parallel`. If a check is
slow, try `glucose` before you shrink the bound.

## Reading the counterexample

`exec` writes one file per solution into the output directory, plus a
`receipt.json` with every solution in machine readable form. A text solution
lists each signature and each field as a set of tuples.

```
this/Invoice={Invoice$0, Invoice$1}
this/Invoice<:vendor={Invoice$0->Vendor$1, Invoice$1->Vendor$0}
this/Invoice<:account={Invoice$0->Account$0, Invoice$1->Account$0}
this/Invoice<:ref={Invoice$0->Ref$0, Invoice$1->Ref$0}
this/Payment<:truth={Payment$0->Invoice$0}
skolem $sound_p={Payment$0}
skolem $sound_i={Invoice$1}
```

Read it as a story. There are two invoices on the same account carrying the
same reference number. The payment really belongs to `Invoice$0`. The
`skolem` lines name the values that make the assertion fail, so they point at
the pair the rule got wrong.

For a behavioral model each state is printed in order, and the state marked
`(loop)` is where the trace starts repeating.

```
------State 0-------
this/posted={}
------State 1-------
this/posted={Line$0}
------State 2 (loop)-------
this/posted={}
this/reversed={Line$0}
------State 3-------
this/posted={Line$0}
this/reversed={Line$0}
```

## Continuous integration

Put `expect 0` or `expect 1` on every command. `exec` exits with status 1 when a
result contradicts its expectation, so a broken invariant fails the build with
no extra scripting.

```sh
alloy exec -f -t none model.als || exit 1
```

`expect 1` on a `check` is not a mistake. It records a counterexample you know
about and want to be told about if it ever disappears.

## The visualizer

The graphical interface draws instances as graphs, which is much easier to read
than tuples for anything with more than three signatures.

```sh
alloy gui model.als
```

In the visualizer, Magic Layout draws a sensible default, and File then Export
To then Predicate turns the instance on screen into Alloy code that pins that
exact instance. That exported predicate is how you turn a counterexample into a
regression test.

## Editor support

The jar embeds a language server, so any editor that speaks LSP can use it.

```sh
alloy lsp
```

## Unbounded checking

By default a behavioral check explores traces up to a fixed number of steps.
Writing `for 1.. steps` asks for complete model checking with no bound on trace
length. That path uses an external tool, Electrod, driving NuSMV or nuXmv, and
both must be installed separately. Before reaching for it, try the inductive
invariant approach in
[behavior.md](behavior.md), which gets unbounded confidence about
trace length from two short bounded checks.
