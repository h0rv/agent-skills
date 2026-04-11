---
name: fasthtml
description: Build, refactor, and review FastHTML applications using current idiomatic patterns from the official FastHTML docs, source, and examples. Use when working on `python-fasthtml` apps, `fasthtml.common` imports, `fast_app()` setup, HTMX-driven HTML responses, `FT` components, route handlers, Beforeware, fastlite integration, or route/function signatures that depend on FastHTML's runtime parameter binding and type reflection.
---

# FastHTML

Follow current FastHTML conventions, not FastAPI, Django, or SPA conventions. Keep code small, HTML-first, and signature-driven.

## Start Here

1. Match the repo's existing style first.
2. Default to `from fasthtml.common import *` unless the repo already uses explicit imports.
3. Default to `app, rt = fast_app()` and `@rt` handlers unless the repo already uses `FastHTML()` or verb-specific decorators.
4. Prefer `index()` for `/`, function-name routes for the rest, and route function references instead of hard-coded URLs.
5. Keep route handlers as plain functions with accurate annotations. FastHTML inspects signatures at runtime.

## Default Build Pattern

Use this shape unless the local app clearly uses another pattern:

```python
from fasthtml.common import *

app, rt = fast_app()

@rt
def index():
    return Titled("App", P("Hello"))

@rt
def save(name: str):
    return P(f"Saved {name}")

serve()
```

## Routing Rules

- Prefer `@rt` without a path argument. Function names become routes; `index` maps to `/`.
- If you need verb-specific handlers on one path, use `@rt("/path") def get(...)`, `@rt("/path") def post(...)`, or `@app.get(...)` and `@app.post(...)`.
- Do not assume bare `@rt` plus a function named `get` or `post` makes a method-specific route. Without an explicit path or explicit decorator method, bare `@rt` produces a function-name route with FastHTML's default GET/POST behavior.
- Prefer GET for reads and POST for mutations. Older examples still show `PUT` and `DELETE`; follow existing code when editing, but default new code to GET/POST.
- Prefer query parameters for internal HTMX flows unless path semantics are genuinely clearer.
- Use route function objects in `href`, `action`, `hx_get`, and `hx_post`. Use `.to(...)` when arguments are needed.
- Do not hard-code URLs that can be expressed as `handler` or `handler.to(...)`.
- When using `APIRouter`, avoid naming handlers `get`, `post`, `put`, and similar if you need to reference them later through router route functions.

## Handler And Typing Rules

- Annotate every user-provided parameter you expect FastHTML to bind.
- Treat missing annotations as a bug unless the parameter is a FastHTML special name such as `req`, `request`, `sess`, `session`, `htmx`, `app`, `auth`, `state`, `data`, or `body`.
- Use dataclasses, fastlite-generated dataclasses/flexiclasses, `TypedDict`, or small custom classes for structured form bodies.
- Use `list[T]`, not bare `list`, for repeated inputs.
- Keep form field names aligned with handler parameter names or structured-body field names.
- Remember that `dict` captures raw body data, while `TypedDict` and typed classes trigger conversion.

Read [handlers-and-typing.md](/home/h0rv/projects/agent-skills/fasthtml/references/handlers-and-typing.md) whenever the task touches route signatures, form binding, query params, cookies, headers, dataclasses, `TypedDict`, or router route functions.

## Response Rules

- Return `FT` objects or tuples of `FT` objects for normal HTML flows.
- Return Starlette response objects directly when you need exact response control.
- Prefer `Redirect(...)` when the redirect should work for both HTMX and non-HTMX requests.
- Use `RedirectResponse(...)` only when the repo already does so intentionally or the response semantics need to stay purely Starlette.
- Use `Titled(...)` when you need a page title plus a containerized body.

Read [response-patterns.md](/home/h0rv/projects/agent-skills/fasthtml/references/response-patterns.md) when a task involves fragments vs full pages, redirects, headers, or custom response behavior.

## App Structure Rules

- Keep apps flat until complexity justifies extraction.
- Start with small helper functions for repeated UI fragments.
- Add `__ft__` methods to domain objects only when rendering the object directly is clearly useful.
- Prefer `db.create(MyRowClass)` over manual table creation when using fastlite.
- Let `Titled(...)` handle the page container unless you need a different body structure.
- Use Pico's default styling first; add extra CSS only when the default HTML semantics are not enough.
- Use modern HTMX event attrs such as `hx_on__after_request`.

Read [app-patterns.md](/home/h0rv/projects/agent-skills/fasthtml/references/app-patterns.md) for preferred project shape, fastlite usage, rendering helpers, and current best-practice guidance.

## Source Selection

- Prefer the official best-practices doc over older example code when they disagree.
- Use the official concise guide and `llms-ctx.txt` for broad framework behavior.
- Use the official example repos for app shape and composition patterns.
- Use the library source when behavior depends on runtime binding details.
- Use the response docs or `core.py` when redirect or render behavior is unclear.

Open [official-sources.md](/home/h0rv/projects/agent-skills/fasthtml/references/official-sources.md) for the exact docs, repos, and example files to consult.
