# App Patterns

Use this reference for project shape, rendering style, and current idiomatic FastHTML choices.

## Baseline App Shape

Prefer this default:

```python
from fasthtml.common import *

app, rt = fast_app()

def item_row(item):
    return Li(item.name)

@rt
def index():
    return Titled("Items", Ul(map(item_row, items)))

serve()
```

## Current Best Practices

These come from the official best-practices doc and current source:

- Prefer `@rt` and function-name routes.
- Prefer `index()` for `/`.
- Prefer query params over path params for many HTMX handlers.
- Prefer GET/POST as the default verb set.
- Prefer route-function references and `.to(...)` over string paths.
- Prefer `db.create(MyClass)` over manual table creation.
- Prefer return-value chaining from fastlite `insert()` and `update()`.
- Prefer semantic HTML and Pico defaults before writing custom CSS.
- Prefer `serve()` directly; no `if __name__ == "__main__"` wrapper is needed.
- Prefer iterables like `map(...)` directly; FastHTML accepts them.

## Fastlite Pattern

For small and medium apps, start here:

```python
from fasthtml.common import *

db = database("data/app.db")

class Todo:
    id: int
    title: str
    done: bool

todos = db.create(Todo, transform=True)
```

Notes:

- `db.create(...)` is idempotent.
- `id` is the implicit primary key unless another `pk` is provided.
- `transform=True` is the lightweight migration path when schema drift is expected.

## Rendering Pattern

Extract tiny helpers early:

```python
def todo_li(todo):
    return Li(
        AX(todo.title, show.to(id=todo.id), "current"),
        id=f"todo-{todo.id}",
    )
```

Use `__ft__` only when rendering the object directly is clearly a net simplification:

```python
@patch
def __ft__(self: Todo):
    return todo_li(self)
```

## HTMX Pattern

Use route functions and HTMX together:

```python
@rt
def create(todo: TodoForm):
    return todos.insert(todo)

Form(
    Group(Input(name="title"), Button("Add")),
    hx_post=create,
    target_id="todo-list",
    hx_swap="afterbegin",
)
```

Prefer the modern event-attribute spelling:

```python
hx_on__after_request="this.reset()"
```

## Beforeware Pattern

Use Beforeware for auth and request-scoped setup:

```python
def before(req, sess):
    auth = req.scope["auth"] = sess.get("auth")
    if not auth: return RedirectResponse("/login", status_code=303)

app = FastHTML(before=Beforeware(before, skip=["/login"]))
rt = app.route
```

## Divergence Warning

The official repos still contain useful older examples that use:

- explicit string paths
- path params where query params are now preferred
- `PUT` and `DELETE`

Do not "fix" an existing codebase just because the example differs. Follow the local app's conventions when editing. Use the current best-practices doc when creating new code or when the user asks for idiomatic FastHTML.
