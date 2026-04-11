# Handlers And Typing

Use this reference when route signatures, request binding, or route function generation are the risky part of the task.

## Core Rule

FastHTML binds handler parameters by inspecting the function signature at runtime. Preserve that signature.

- Keep handlers plain.
- Avoid wrappers that hide annotations or rename parameters.
- If a decorator is unavoidable, preserve the original signature.

## Preferred Route Style

```python
from dataclasses import dataclass
from fasthtml.common import *

app, rt = fast_app()

@dataclass
class TodoForm:
    id: int | None = None
    title: str = ""
    done: bool = False

@rt
def index():
    return Form(action=save)(
        Input(name="title"),
        CheckboxX(id="done", label="Done"),
        Button("Save"),
    )

@rt
def save(todo: TodoForm):
    return P(todo.title)
```

Prefer handler references such as `action=save` or `hx_post=save.to(id=3)` over string paths.

## Method Selection

This is a common source of broken code.

- `@rt` with no explicit path gives a function-name route and FastHTML's default GET/POST behavior.
- `@rt("/items") def get(...)` and `@rt("/items") def post(...)` create verb-specific handlers on the same path.
- `@app.get("/items")` and `@app.post("/items")` are the clearest explicit form when method separation matters.

Prefer this when one path has separate read and write handlers:

```python
@rt("/")
def get():
    return Titled("Todos", Form(action=post)(Input(name="title"), Button("Add")))

@rt("/")
def post(title: str):
    return Li(title)
```

Prefer this when you want function-name routes with default GET/POST:

```python
@rt
def save(title: str):
    return P(title)
```

Do not mix these mental models.

## Binding Order

For normal annotated parameters, FastHTML checks these sources in this order:

1. path params
2. cookies
3. headers
4. query params
5. form or JSON body data

If nothing matches and there is no default, FastHTML raises a 400 for HTTP requests.

## Special Names

Unannotated parameters are only meaningful when they are recognized special names. The important ones are:

- `req` or `request`: request/websocket object
- `sess` or `session`: session dict
- `scope`
- `data`: parsed request body data
- `htmx`: HTMX headers object
- `app`
- `state`
- `auth`
- `body`

Do not rely on unannotated names for user input. FastHTML warns and ignores them.

## Structured Body Types

FastHTML treats these as body-bound structured types:

- dataclasses
- fastlite/flexiclass row types
- `TypedDict`
- namedtuples
- custom classes with annotations
- classes implementing `__from_request__`

Use them when multiple fields belong together.

### Prefer These Shapes

```python
from dataclasses import dataclass
from typing import TypedDict

@dataclass
class LoginForm:
    name: str
    pwd: str

class FilterArgs(TypedDict):
    page: int
    q: str
```

### Important Differences

- `dict` captures the whole parsed body but values stay stringly typed.
- `TypedDict` uses field annotations for conversion.
- dataclasses and typed classes construct an instance from matching fields.
- `list[int]` converts repeated values; bare `list` is ignored.

## Route Functions

Decorating a handler with `@rt` returns a local route-function wrapper:

- the function itself can be used in attrs like `href`, `action`, `hx_get`, `hx_post`
- `.to(...)` builds a query-string URL
- `index` becomes `/`
- other handler names become `/<name>`

Prefer this:

```python
@rt
def profile(email: str):
    ...

Form(action=profile)(...)
Button("Open", hx_get=profile.to(email="a@example.com"))
```

Not this:

```python
Form(action="/profile")(...)
Button("Open", hx_get=f"/profile?email={email}")
```

Remember that these route-function conveniences come from the wrapped function returned by the decorator. Preserve and reuse that wrapped binding.

## APIRouter Gotcha

`APIRouter` stores wrapped route functions for discovery, but handlers literally named `get`, `post`, and similar are not exposed there. If code needs `router.some_handler.to(...)`, use semantic handler names such as `index`, `save`, `edit`, or `show`.

## Query Params vs Path Params

Current FastHTML best-practice guidance prefers query params for many internal HTMX flows:

```python
@rt
def toggle(id: int): ...
```

Prefer path params when the route is externally meaningful, already established in the repo, or required by Starlette-style routing such as static files.

## When Things Go Wrong

Check these first:

- missing annotation on a handler param
- mismatched form field name
- bare `list` instead of `list[T]`
- string URL used where `handler` or `handler.to(...)` should be used
- older example code copied blindly into a codebase using newer `@rt` conventions
