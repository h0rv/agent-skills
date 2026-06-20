# GEPA in depth

GEPA (Genetic-Evolutionary Prompt Adaptation, sometimes read as Reflective Prompt Evolution) is a prompt optimizer that uses natural-language reflection on execution traces instead of gradients or scalar-only reward. Paper: `https://arxiv.org/abs/2507.19457` (ICLR 2026). Code: `https://github.com/gepa-ai/gepa`. DSPy wrapper: `https://dspy.ai/api/optimizers/GEPA/overview/`.

## Table of contents

- How the loop works
- What it needs
- The DSPy API and the standalone API
- `auto` budgets
- Pareto frontier and merge
- Benchmark claims and their caveats
- Tuning and when GEPA is the wrong choice

## How the loop works

1. **Rollout**: run the current candidate program on sampled training examples. Capture full traces: the reasoning chain, any tool calls and their outputs, the final prediction, and signals from the metric (score plus feedback, including error strings and failed parses).
2. **Reflect**: hand those traces to a reflection LM with a prompt that asks it to diagnose what went wrong and propose a revised instruction block. The textual feedback is the optimization signal; the repo calls it Actionable Side Information (ASI), the text analogue of a gradient.
3. **Mutate**: apply the proposed instruction rewrite to produce a new candidate. Only the signature docstring/instructions change; field names and descriptions are left intact.
4. **Select**: evaluate candidates and keep a Pareto frontier rather than a single best, so candidates that win on different slices of the data all survive and can be combined.
5. Repeat until the metric-call budget is exhausted.

## What it needs

- A **metric that returns score and feedback** (`dspy.Prediction(score=, feedback=)` or `{"score": float, "feedback": str}`), accepting `(gold, pred, trace, pred_name, pred_trace)`.
- A **train set and a val set**. Both can be small; GEPA is designed to be sample-efficient and works with a handful of examples, though more val data gives a more trustworthy selection signal.
- A **reflection LM**, usually stronger than the task LM. This is the model doing the diagnosing and rewriting.
- A **seed program**. The starting instructions matter: seed GEPA with a good hand-written prompt and it improves from there rather than starting cold. This is how expert knowledge and automated optimization coexist.

## The DSPy API

```python
optimized = dspy.GEPA(
    metric=metric,
    auto="medium",                 # or set max_metric_calls explicitly
    reflection_lm=dspy.LM("openai/gpt-5", temperature=1.0, max_tokens=32000),
    # reflection_minibatch_size=3,
    # candidate_selection_strategy="pareto",
    # track_stats=True,            # keep detailed optimization history
).compile(student=program, trainset=trainset, valset=valset)
```

The reflection LM commonly wants a high temperature and a large `max_tokens`, because it is writing and revising long instruction blocks, not answering the task.

## The standalone API

GEPA exists outside DSPy and can optimize any text component, not only DSPy signatures:

```python
import gepa

result = gepa.optimize(
    seed_candidate=seed,           # dict of named text components to evolve
    trainset=trainset,
    valset=valset,
    task_lm="openai/gpt-5-mini",
    reflection_lm="openai/gpt-5",
    max_metric_calls=300,
)
result.best_candidate            # the evolved text components
```

Use the standalone form when the thing you are optimizing is a prompt or instruction file that is not wrapped in a DSPy module.

## `auto` budgets

`auto="light" | "medium" | "heavy"` sets how many metric calls GEPA spends. Light is for a quick signal, heavy for a final optimization run. If you need control, set `max_metric_calls` directly. Cost scales with this budget times the price of the task LM and the reflection LM, so a heavy run with an expensive reflection LM is the main cost lever to watch.

## Pareto frontier and merge

GEPA keeps the set of candidates where each is best on at least one evaluation instance, and samples parents proportional to how many instances they cover. This preserves complementary strategies (one candidate good at edge case A, another at edge case B) instead of letting a single average-best candidate dominate and erase them. Some configurations also merge complementary candidates. The effect is robustness: the optimizer escapes local optima that single-best hill climbing falls into.

## Benchmark claims and their caveats

From the paper and repo, on the authors' six tasks:

- Beats GRPO (an RL method) by ~6% on average and up to 20%, using up to ~35x fewer rollouts (100-500 evaluations vs 5,000-25,000+). "Up to 35x" is a best case and counts rollouts, not wall-clock latency.
- Beats MIPROv2 by over 10% (for example +12% on AIME-2025; +13% aggregate vs MIPROv2's +5.6%).

Caveats to state plainly when citing these:

- The benchmarks are categorical, text, and math-reasoning tasks (HotpotQA, IFBench, HoVer, PUPA, AIME-2025). They are **not** dense numeric structured extraction. Transfer to dollar amounts, codes, and other numeric fields is plausible but unverified by the paper.
- The results are the authors' own and not independently replicated at the time of writing.
- AIME-2025 is only 30 problems; small benchmarks have wide error bars.

The strongest extraction-relevant evidence is the Databricks case study (a GEPA-optimized open model beating Claude Sonnet 4 and Opus 4.1 on an information-extraction benchmark at much lower cost), but it is a vendor benchmark with cost estimated from list pricing, so treat the exact multiples as directional.

Do not cite a specific "cheap model 62% -> 89%" lift attributed to the DSPy homepage; that claim does not check out.

## Tuning and when GEPA is the wrong choice

- If the metric cannot explain *why* an answer is wrong, GEPA loses most of its advantage over MIPROv2. Fix the feedback before spending a large budget.
- If a too-weak reflection LM produces vague rewrites, results stall. Upgrade the reflection LM before increasing the budget.
- If accuracy is already saturated and the goal is purely cost, try BootstrapFewShot on the cheap model first; it may be enough and is far cheaper to run.
- GEPA optimizes instructions. If the real problem is missing capability (the model cannot do the task at any prompt), prompt optimization will not save it; consider fine-tuning (see optimizers.md).
