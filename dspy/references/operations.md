# Operations: models, saving, observability, gotchas

## Model wiring (LiteLLM)

DSPy talks to models through LiteLLM, so models are `provider/model-id` strings:

```python
import dspy

dspy.configure(lm=dspy.LM("openai/gpt-5-mini", temperature=0, max_tokens=4000))

# other providers (verify current ids against the provider):
dspy.LM("anthropic/claude-haiku-4-5")
dspy.LM("vertex_ai/gemini-2.5-flash")
dspy.LM("openai/gpt-oss-120b", api_base="http://localhost:8000/v1")   # self-hosted, OpenAI-compatible
```

Per-module overrides let one program mix models (cheap task LM, strong reflection LM):

```python
extract.set_lm(dspy.LM("anthropic/claude-haiku-4-5"))
```

Model ids and pricing move; confirm against provider docs before quoting either.

### Regulated or private data

For data that cannot leave a boundary (PHI, PII, contractual data residency), run the task LM behind that boundary: a self-hosted open model with an OpenAI-compatible endpoint, or a vendor under the appropriate agreement and region. The reflection LM sees training traces too, so it must satisfy the same constraint. Optimization (a GEPA/MIPROv2 run) reads real examples, so treat the optimizer run as in-scope for any data-handling policy, not just production inference.

## Saving and versioning compiled programs

An optimized program is a build artifact. Persist it; do not paste the evolved prompt back into source by hand.

```python
optimized.save("artifacts/extract.json")              # state only (prompts, demos)
loaded = dspy.ChainOfThought(ExtractInvoice)
loaded.load("artifacts/extract.json")

optimized.save("artifacts/extract/", save_program=True)   # whole program + metadata
loaded = dspy.load("artifacts/extract/")
```

State-only JSON is diffable and reviewable, which is what you want for human sign-off on evolved instructions and for tracking changes over time. Keep the artifact under version control, record which model and dataset produced it, and re-optimize as a deliberate step rather than editing the artifact.

## Observability

- **MLflow**: native DSPy autologging traces prompts, predictions, and optimization runs.
- **Logfire**: `logfire.instrument_dspy()` captures DSPy calls as spans (verify the exact call against current Logfire docs).
- During development, `dspy.inspect_history(n=...)` prints the last prompts and completions, which is the fastest way to see what the optimizer actually produced and what the model received.

Inspecting the real prompt sent to the model is the single most useful debugging habit; most "the optimizer did nothing" reports are visible immediately in the history.

## Caching

DSPy caches LM calls by default, which makes re-runs cheap and reproducible but can hide changes during development. If results look stale after a code change, suspect the cache. Configure or disable it when you need fresh calls.

## Common failure modes

- **Non-discriminating metric**: returns near-identical scores across candidates, so the optimizer has no gradient. Verify the metric separates good from bad outputs before a long run.
- **Weak reflection LM**: produces vague instruction rewrites; GEPA stalls. Upgrade the reflection LM before raising the budget.
- **Tiny val set**: candidate selection overfits and the "best" prompt does not generalize. Grow the val set or hold out a real test set.
- **Optimizing the wrong surface**: putting the guidance you want improved into field `desc` instead of the docstring; optimizers will not touch it. Move it into the instructions.
- **Reporting on training data**: inflated numbers. Always report on held-out data.
- **Budget burned on the expensive LM**: a heavy run with a frontier reflection LM is the main cost. Start with `auto="light"` to confirm the setup works, then scale up.
- **Cache masking changes**: see Caching above.
