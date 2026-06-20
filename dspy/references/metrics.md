# Metrics and verifiable-domain optimization

The metric is the objective. Optimizer quality is bounded by metric quality, so design it before spending a budget. Docs: `https://dspy.ai/learn/evaluation/metrics/`.

## The contract

A metric is a callable. The argument signature and return type depend on how it is used:

- **Evaluation** (`dspy.Evaluate`): `metric(example, pred, trace=None)` returning `float | int | bool`. `bool` aggregates to a percentage, numeric to a mean. By convention scores are 0.0-1.0, higher is better.
- **GEPA**: `metric(gold, pred, trace=None, pred_name=None, pred_trace=None)` returning `dspy.Prediction(score=float, feedback=str)` or `{"score": float, "feedback": str}`. The score is averaged; the feedback drives reflection and is ignored by `Evaluate`.

Write one metric that returns the rich form and works for both; `Evaluate` reads `.score` and ignores `.feedback`.

## Field-level scoring with partial credit

For structured output, score per field so the optimizer gets a smooth signal instead of all-or-nothing:

```python
FIELDS = ["total", "invoice_date", "vendor", "line_count"]

def metric(gold, pred, trace=None, pred_name=None, pred_trace=None):
    hits, notes = 0, []
    for f in FIELDS:
        want, got = getattr(gold, f, None), getattr(pred, f, None)
        if normalize(f, got) == normalize(f, want):
            hits += 1
        else:
            notes.append(f"{f}: got {got!r}, expected {want!r}")
    score = hits / len(FIELDS)
    fb = "all fields correct" if not notes else "; ".join(notes)
    return dspy.Prediction(score=score, feedback=fb)
```

`normalize` is where verifiable-domain knowledge lives: canonicalize numbers (strip currency symbols, round cents), dates (parse to ISO), codes (uppercase, strip separators), and strings (case, whitespace) so that cosmetic differences do not count as errors. Getting normalization right matters more than the optimizer choice.

## Feedback that actually drives extraction

Vague feedback ("some fields were wrong") wastes the reflection budget. Specific feedback is what the reflector converts into better instructions. Tell it the failure mode, not just the diff:

- Out-of-range or implausible numeric value, and the plausible range.
- Wrong format (expected ISO date, got `MM/DD/YY`).
- A code that does not exist in the reference table (likely hallucination or OCR corruption), and where the valid set lives.
- A total that does not equal the sum of its parts (arithmetic consistency failure), with the two numbers.
- Invalid JSON or a schema violation, with the parser error string.

GEPA can consume any of these textual signals. In a verifiable domain you can generate them mechanically (range checks, checksum/arithmetic validation, set membership, schema validation), which makes the feedback cheap and reliable.

## The verifiable-domain loop

When ground truth exists, prompt-writing becomes a closed loop with no human in the inner cycle:

1. Score every candidate prompt automatically against ground truth.
2. Emit per-field feedback explaining each miss.
3. Let GEPA reflect and rewrite the instructions.
4. Select on held-out val, repeat.
5. Keep humans in the **outer** loop: seed with an expert prompt, and review the evolved instructions before promoting them.

This turns prompt authoring from a hand-craft into an optimization problem. The prerequisites are exactly: a verifiable objective, trustworthy ground truth, and guidance expressed as optimizable instructions.

## LLM-as-judge metrics

When correctness is not exactly checkable (summaries, free text), a metric can itself be a DSPy program that asks a model to judge the output and return a score plus a critique. This composes naturally: the judge's critique becomes GEPA's feedback. Keep judge metrics for genuinely subjective fields; prefer mechanical checks wherever the domain allows, because they are cheaper, deterministic, and not gameable.

## Avoid these metric mistakes

- A metric that returns the same score regardless of the prompt cannot optimize anything; check that it discriminates across candidates before a long run.
- All-or-nothing scoring on multi-field output gives a flat landscape; use partial credit.
- Normalization bugs that mark correct answers wrong will teach the optimizer to chase noise.
- Leaking the gold answer into the prediction path inflates scores and produces a prompt that fails in production.
