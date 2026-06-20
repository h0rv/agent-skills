---
name: dspy
description: Build, optimize, debug, and explain DSPy programs and GEPA prompt optimization. Use whenever the task involves DSPy (signatures, modules, Predict/ChainOfThought/ReAct, optimizers/teleprompters), GEPA, MIPROv2, BootstrapFewShot, BootstrapFinetune, reflective or evolutionary prompt optimization, automatically tuning prompts against a metric, or moving a task from an expensive frontier model to a cheaper/faster one (Haiku, GPT-5 mini, Gemini Flash) without losing accuracy. Also use for structured-extraction tasks in verifiable domains where ground truth exists and prompt-writing should be put in an automated optimization loop instead of hand-authored, and for questions about when prompt optimization beats fine-tuning.
---

# dspy

DSPy is a framework for programming language models instead of prompting them by hand. You declare the task as a typed **signature**, run it with a **module**, and let an **optimizer** rewrite the prompts (and pick few-shot examples) automatically by scoring against a **metric**. GEPA is the reflective-evolutionary optimizer in that ecosystem and is usually the highest-leverage one for verifiable domains.

As of 2026-06, DSPy and GEPA APIs are evolving (GEPA was accepted at ICLR 2026). Verify against `https://dspy.ai/` and `https://github.com/gepa-ai/gepa` before making version-sensitive recommendations.

## Start Here

1. Inspect the local project first: is DSPy already configured (`dspy.configure(lm=...)`), what models are wired, is there a dataset and a scoring function, and is anyone hand-writing prompts that could be optimized instead.
2. Decide what is actually being asked: writing a DSPy program, choosing/running an optimizer, debugging why optimization did not help, or porting a working prompt to a cheaper model. The optimizer choice and the metric design follow from this.
3. Express the task as a signature, not a prompt string. Put the task guidance in the signature **docstring**, because that is the surface GEPA and the instruction optimizers rewrite (see Optimizable Surface below).
4. Pick a module: `dspy.Predict` for direct mapping, `dspy.ChainOfThought` when intermediate reasoning helps, `dspy.ReAct` when the task needs tools.
5. Write a metric. For GEPA it must return a score **and** natural-language feedback. The feedback is what makes reflective optimization work, so invest here.
6. Optimize with a small train/val split, then evaluate the compiled program on held-out data and save it. Treat optimized prompts as versioned build artifacts, not source you edit by hand.

## Core Program Shape

```python
import dspy

dspy.configure(lm=dspy.LM("openai/gpt-5-mini", temperature=0))

class ExtractInvoice(dspy.Signature):
    """Extract the invoice fields from the document text.

    This docstring is the task instructions. It is what the optimizer rewrites.
    Put domain guidance, edge cases, and disambiguation rules here, not in code.
    """
    document: str = dspy.InputField()
    total: float = dspy.OutputField(desc="grand total in dollars")
    invoice_date: str = dspy.OutputField(desc="ISO 8601 date")

extract = dspy.ChainOfThought(ExtractInvoice)
pred = extract(document=text)        # pred.total, pred.invoice_date
```

Signatures can be the inline string form (`"document -> total: float, invoice_date: str"`) for quick work, but the class form is what you want for anything you will optimize, because only the class form carries a docstring and field metadata.

## The Optimizable Surface

This is the single most important fact for optimization design:

**GEPA and the DSPy instruction optimizers rewrite the signature docstring (the instructions). They do not touch field names, field `desc`, or prefixes.**

Field names and descriptions are the program's public interface (`pred.total`, downstream lookups), so optimizers leave them stable. The practical consequence: **any guidance you want the optimizer to be able to improve must live in the docstring/instructions**, not in Pydantic field descriptions. Field `desc` is changed only manually via the `with_updated_fields` API. If you are building per-variant prompt sets (one tuned instruction block per document format, per tenant, per language), encode each variant in the optimizable instructions and compile one program per variant, or one program with variant-conditioned instructions.

This docstring-only surface is a DSPy property, not a universal one. Other frameworks expose a wider optimization target: see Framework vs Method below.

## GEPA in One Paragraph

GEPA runs the program, captures execution traces (reasoning, tool calls, tool outputs, even reward-function internals like parse errors), and feeds them to a **reflection LM** that diagnoses failures in natural language and rewrites the instructions. It keeps a **Pareto frontier** of candidates (each candidate is the best on at least one example, sampled proportional to coverage) rather than evolving only the single global best, so complementary strategies survive instead of collapsing into a local optimum. The repo frames the textual feedback as "the text-optimization analogue of a gradient." It works with very small datasets (as few as a handful of examples) and reaches strong results with far fewer rollouts than RL methods.

Minimal call:

```python
metric = make_feedback_metric()   # returns dspy.Prediction(score=, feedback=)

optimized = dspy.GEPA(
    metric=metric,
    auto="medium",                              # light | medium | heavy
    reflection_lm=dspy.LM("openai/gpt-5", temperature=1.0, max_tokens=32000),
).compile(student=extract, trainset=trainset, valset=valset)

optimized.save("optimized_extract.json")
```

Use a **strong reflection LM even when the task LM is cheap**. The whole point is to let a smart model reflect its way to a prompt that makes a cheap model perform well. Set the task LM (the one being optimized) to your cheap target via `dspy.configure(lm=...)` or per-module `.set_lm(...)`.

Read [references/gepa.md](references/gepa.md) for the algorithm in depth, `auto` budgets, merge behavior, the published benchmark numbers and their honest caveats, and tuning advice.

## Metrics And Feedback

A DSPy metric is a callable. For plain evaluation it can return a `float`/`bool`. For GEPA it must accept five arguments and return both a score and feedback:

```python
def metric(gold, pred, trace=None, pred_name=None, pred_trace=None):
    score, notes = 0.0, []
    if pred.total == gold.total:
        score += 0.5
    else:
        notes.append(f"total wrong: got {pred.total}, expected {gold.total}")
    if pred.invoice_date == gold.invoice_date:
        score += 0.5
    else:
        notes.append(f"invoice_date wrong: got {pred.invoice_date}, expected {gold.invoice_date}")
    return dspy.Prediction(score=score, feedback="; ".join(notes) or "all fields correct")
```

The feedback channel is read only by GEPA's reflective loop; `dspy.Evaluate` ignores it and aggregates the score alone. GEPA can consume **any** textual signal, not just scalar reward: validation logs, stack traces, failed JSON parses, schema/constraint violations, error strings. In a verifiable domain this is your advantage. Spend the feedback budget telling the optimizer *which field was wrong and why* (out of range, wrong format, hallucinated code not in the reference table), because specific feedback is what the reflector turns into better instructions.

Read [references/metrics.md](references/metrics.md) for field-level scoring patterns, partial credit, feedback that drives extraction, and verifiable-domain design (the loop where ground truth scores every candidate prompt automatically).

## Picking An Optimizer

- **GEPA**: reflective instruction rewriting from textual feedback. Best default when you have a metric that can explain failures and you want a single high-quality prompt, especially to make a cheaper model competitive.
- **MIPROv2**: bayesian search over instructions plus few-shot demo selection. Strong general optimizer; GEPA reported beating it by over 10% on its benchmarks (categorical/text/math tasks).
- **BootstrapFewShot / BootstrapFewShotWithRandomSearch**: cheap, fast, demo-only. Good first thing to try; often a surprisingly strong baseline.
- **BootstrapFinetune**: distills a DSPy program into fine-tuned model weights. This is the bridge to fine-tuning, including using an optimized prompt's outputs as a distillation target.

Read [references/optimizers.md](references/optimizers.md) for how each works, train/val sizing, and the prompt-optimization-vs-fine-tuning (LoRA) decision and how they compose.

## Cheaper Models Without Losing Accuracy

The core thesis: a prompt optimized **for a specific small model** can let that model match or beat a frontier model running with high reasoning, at a fraction of the cost. The most extraction-relevant public evidence is the Databricks case study, where a GEPA-optimized open-source model surpassed Claude Sonnet 4 and Opus 4.1 on an information-extraction benchmark at far lower serving cost (a vendor benchmark, so treat the exact multiples as directional). To do this:

1. Set the **task LM** to the cheap target (`anthropic/claude-haiku-*`, `openai/gpt-5-mini`, `vertex_ai/gemini-*-flash`). Verify current model ids against the provider.
2. Set the **reflection LM** to a strong model.
3. Optimize and measure on held-out data. Report accuracy, cost, and latency together, because the win is the combination, not accuracy alone.

Be honest about transfer: GEPA's headline academic gains were measured on categorical, text, and math-reasoning tasks, not dense numeric extraction. For numeric or code-heavy domains, prove the lift on your own held-out set before trusting it.

## Framework vs Method

DSPy is two separable things: an authoring framework (signatures, modules, programming instead of prompting) and an optimization method (compile prompts against a metric; GEPA reflective optimization). In the agentic era the authoring framework competes with imperative agent frameworks (Pydantic AI, LangGraph, OpenAI Agents SDK) and is often not the one teams pick, because they want explicit control over the tool loop. The optimization method is the durable, high-leverage part, and it has been unbundled from the framework: GEPA ships as a standalone `gepa` package usable against any system.

Optimization matters more in the agentic era, not less: there are more prompts per system (planner, tools, subagents, per-format instructions), errors compound across steps so small per-step gains add up, GEPA reflects on full trajectories (tool calls and outputs, not just single answers), and re-optimizing is cheaper than re-hand-tuning every time you swap models. The precondition is unchanged: you need ground truth and a metric. Where you have them, optimize; where you do not, the method has little to grip.

The practical guidance: take the method, do not force the framework. If you already build agents in another framework, optimize them in place rather than porting to DSPy. Reach for the full DSPy stack when you want multi-module joint optimization or its deeper optimizer implementations.

Read [references/pydantic-ai.md](references/pydantic-ai.md) for optimizing Pydantic AI agents with GEPA via `agent.override(spec=...)`, packaging an optimizer as a Capability, and the wider optimization surface (instructions, capabilities, model settings) that an AgentSpec exposes beyond DSPy's docstring-only target.

## Operations

Read [references/operations.md](references/operations.md) for: model wiring via LiteLLM (provider/model id strings, Vertex/Anthropic/OpenAI, self-host for regulated data), saving and versioning compiled programs, observability (MLflow, Logfire `instrument_dspy`), caching, and the common failure modes (a metric that does not discriminate, a too-weak reflection LM, overfitting to a tiny val set, optimizing the wrong surface).

## Source Selection

- Prefer `https://dspy.ai/` for current API behavior, optimizer docs, and tutorials.
- Prefer `https://github.com/gepa-ai/gepa` for GEPA internals, the standalone `gepa.optimize` API, and the FAQ.
- Prefer the GEPA paper `https://arxiv.org/abs/2507.19457` for the algorithm and benchmark methodology (read the task list before quoting numbers).
- Prefer provider docs for current model ids and pricing.
- Avoid quoting prompt-optimization gain figures without naming the task they were measured on; the numbers do not transfer uniformly across task types.
