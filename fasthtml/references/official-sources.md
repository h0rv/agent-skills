# Official Sources

This skill was built against the official FastHTML docs and upstream repositories current on 2026-04-11. The cloned repo reported `python-fasthtml` version `0.13.4`.

## Read In This Order

1. Best-practices doc:
   `https://fastht.ml/docs/ref/best_practice.html`
2. Concise guide:
   `https://www.fastht.ml/docs/ref/concise_guide.html`
3. LLM context file:
   `https://www.fastht.ml/docs/llms-ctx.txt`
4. Handler docs:
   `https://www.fastht.ml/docs/ref/handlers.html`
5. Core API:
   `https://fastht.ml/docs/api/core.html`
6. Response types:
   `https://www.fastht.ml/docs/ref/response_types.html`

## Repos

- Main repo: `https://github.com/AnswerDotAI/fasthtml`
- Examples repo: `https://github.com/AnswerDotAI/fasthtml-example`

## High-Value Files

Main repo:

- `examples/adv_app.py`: most complete idiomatic app walkthrough
- `examples/pep8_app.py`: same ideas with explicit imports and more conventional formatting
- `fasthtml/core.py`: authoritative handler-binding and route-wrapper behavior
- `nbs/ref/best_practice.qmd`: current best-practice guidance
- `nbs/ref/response_types.ipynb`: response and redirect behavior
- `nbs/llms-ctx.txt`: compact broad reference for framework behavior

Examples repo:

- `helloworld/main.py`: minimal baseline
- `01_todo_app/main.py`: compact CRUD shape
- `02_chatbot/`: streaming and interaction variants
- `04_sse/`: SSE-specific patterns

## What To Trust When Sources Conflict

Prefer sources in this order:

1. `fasthtml/core.py`
2. best-practices doc
3. concise guide and handler docs
4. `adv_app.py`
5. older examples

That order matters because some examples intentionally preserve older patterns while the docs and source reflect newer recommendations.
