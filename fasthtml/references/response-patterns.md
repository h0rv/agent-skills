# Response Patterns

Use this reference when handlers return the wrong shape, redirects break under HTMX, or a task mixes partial and full-page rendering.

## What Handlers Can Return

FastHTML handlers commonly return:

- `FT` objects
- tuples of `FT` objects
- Starlette `Response` subclasses
- mappings, which FastHTML JSON-encodes
- strings

Prefer `FT` objects or tuples for HTML-first app code.

## Page vs Fragment Behavior

FastHTML automatically decides whether to produce a full HTML page or an HTML fragment.

- normal browser request: FastHTML wraps content into a page when needed
- HTMX request: FastHTML returns the partials directly

Use `Titled(...)` when you want a title plus normal page content.

## Redirect Rule

Prefer:

```python
return Redirect("/login")
```

`Redirect(...)` is HTMX-aware. In FastHTML core it becomes an HTMX redirect header for HTMX requests and a normal `RedirectResponse` for non-HTMX requests.

Use `RedirectResponse(...)` only when the repo is intentionally staying close to Starlette or when exact Starlette redirect semantics are required.

## Response Control

Return a Starlette response directly when you need exact behavior:

```python
return FileResponse(path)
return HTMLResponse(html)
return JSONResponse(data)
```

FastHTML leaves those responses alone.

## Headers And Side Effects

FastHTML can return `HttpHeader` values and background tasks alongside content. Use that only when the task actually needs response-level behavior; do not introduce it for normal page rendering.

## Full HTML Control

Return an explicit `Html(...)` tree when the task needs full-document control. Otherwise let FastHTML assemble the page or fragment automatically.
