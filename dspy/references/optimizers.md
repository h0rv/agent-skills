# Optimizers and the fine-tuning decision

DSPy optimizers (historically "teleprompters") take a program, a metric, and a trainset, and return a compiled program with better prompts and/or demos. Docs: `https://dspy.ai/learn/optimization/optimizers/`.

## The lineup

- **BootstrapFewShot**: generates few-shot demonstrations by running the program and keeping examples the metric accepts. Cheap, fast, demo-only (does not rewrite instructions). Try it first; it is often a strong baseline and tells you whether the task is demo-limited.
- **BootstrapFewShotWithRandomSearch**: the above plus random search over demo sets. More compute, better demos.
- **MIPROv2**: jointly searches instructions and few-shot demos using bayesian optimization over proposed candidates. Strong general-purpose optimizer. GEPA reported beating it by over 10% on its benchmarks, but MIPROv2 remains a solid choice and is well documented.
- **GEPA**: reflective instruction rewriting from textual feedback, Pareto selection. Best when the metric can explain failures and you want a single high-quality instruction set, especially to lift a cheap model. See gepa.md.
- **BootstrapFinetune**: distills a DSPy program into fine-tuned weights instead of prompts. The bridge from prompt optimization to fine-tuning.

## Choosing

- Start with BootstrapFewShot to get a baseline cheaply.
- If instructions clearly need to change (the model misunderstands the task, not just lacks examples), use GEPA or MIPROv2.
- Use GEPA when you can produce explanatory feedback and want the reflective edge or a cheap-model lift; use MIPROv2 when feedback is only a scalar score or you want its demo+instruction joint search.
- Use BootstrapFinetune when prompting has plateaued and you need capability or latency that prompts cannot deliver.

## Train/val sizing

- BootstrapFewShot works with tens of examples.
- MIPROv2 benefits from more (often a couple hundred) to make its search meaningful.
- GEPA is sample-efficient and works with very small sets, but the val set still needs enough examples to make candidate selection trustworthy; too small a val set overfits the selection.
- Always keep a held-out test set the optimizer never sees, and report final numbers on it. Optimizing and reporting on the same data inflates results.

## Prompt optimization vs fine-tuning (LoRA)

These solve different problems. Reach for prompt optimization first; it is cheaper, faster to iterate, portable across models, and easy to inspect and revert.

Prompt optimization wins when:

- The base model can already do the task with the right instructions and examples; it just needs steering.
- You want to keep using a hosted model and swap models freely.
- You need the result to be auditable and human-reviewable (instructions are readable; weights are not).
- Iteration speed matters; a GEPA/MIPROv2 run is minutes-to-hours, not a training job.

Fine-tuning (including LoRA) wins when:

- The model lacks the capability or format adherence at any prompt, or needs a domain/style it was not trained on.
- You have a large, high-quality labeled set.
- You need the lowest possible inference cost and latency on a self-hosted small model, and prompt length itself is a cost driver (a fine-tuned model needs fewer instruction tokens).
- You need to internalize behavior that is too large to fit in a prompt.

## They compose

The strongest pattern is to use them together rather than choosing once:

1. Optimize the prompt first (GEPA/MIPROv2) to define the best achievable behavior.
2. Use the optimized program to generate high-quality outputs (a distillation set).
3. Fine-tune a smaller/cheaper model on those outputs (BootstrapFinetune, or an external LoRA run).
4. Optionally re-optimize a shorter prompt for the fine-tuned model.

The optimized prompt becomes the teacher and the distillation target. This gives you the capability transfer of fine-tuning with the data quality of an optimized teacher, and ends at a cheap model with a short prompt. Prove each step on held-out data before promoting it.
