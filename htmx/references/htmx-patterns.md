# HTMX Patterns

## Contents

- Fit check
- Default toolbox
- Locality rules
- Endpoint shape
- Common patterns
- Review anti-patterns
- Primary sources

## Fit check

Prefer htmx when the UI has clear HTML boundaries:

- CRUD screens
- Tables, lists, feeds, and detail panels
- Search, filters, sort, and pagination
- Inline edit and validation
- Notifications, logs, and job status

Treat htmx as a poor default for:

- High-frequency pointer or animation updates
- Spreadsheet-like dependency graphs
- Complex canvas or map interactions
- Thick offline clients

In mixed systems, keep the large, ordinary parts of the UI server-rendered and isolate the exceptional interactive area.

## Default toolbox

Use a small set of attributes first:

- `hx-boost="true"` for progressive enhancement of links and forms
- `hx-get` and `hx-post` for local interactions
- `hx-target` for explicit ownership of updates
- `hx-swap` for simple replacement strategy
- `hx-trigger` for user or timer driven requests
- `hx-indicator` for in-flight feedback
- `hx-sync` for races and overlap

Avoid reaching for many extensions or custom JavaScript up front.

## Locality rules

Prefer markup where the behavior is obvious on inspection.

Good:

- The element shows its own request, target, and trigger.
- Parent inheritance is used sparingly and only when it stays nearby and readable.

Usually worse:

- A custom helper or wrapper that hides the real `hx-get`, `hx-post`, `hx-target`, or `hx-trigger`
- Client-side orchestration that makes you jump across files to understand one button

If an element's behavior stops being obvious from the markup, step back and simplify.

## Endpoint shape

Design endpoints around UI regions.

Good:

- `/contacts/table`
- `/contacts/42/details`
- `/orders/42/status-panel`
- `/jobs/abc/log`

Usually worse:

- One generic JSON endpoint plus client templates
- A large page endpoint reused for tiny partial swaps without stable fragment control

Return the fragment the target needs. If the list and its count change together, return them together.

## Common patterns

### Progressive navigation

Prefer real links and forms, then boost them:

```html
<main hx-boost="true">
  <a href="/contacts?page=2">Next</a>

  <form action="/contacts" method="get">
    <input type="search" name="q">
  </form>
</main>
```

Add `hx-push-url="true"` only when the updated state should be preserved in navigation history.

### Active search

Debounce input. Cancel stale in-flight requests.

```html
<input
  type="search"
  name="q"
  hx-get="/contacts/search"
  hx-trigger="input changed delay:500ms, search"
  hx-target="#results"
  hx-sync="this:replace">
```

Return the table body or result region directly.

### Inline edit

Swap a bounded row, card, or detail block instead of mutating many disjoint elements.

```html
<button
  hx-get="/contacts/42/edit"
  hx-target="#contact-42"
  hx-swap="outerHTML">
  Edit
</button>
```

### Validation and submit races

Use `hx-sync` when validation and submit can overlap.

```html
<form hx-post="/articles" hx-sync="this:replace">
  <input
    name="title"
    hx-post="/articles/validate-title"
    hx-trigger="change"
    hx-sync="closest form:abort">
  <button type="submit">Save</button>
</form>
```

### Cross-region updates

Prefer region design that keeps related state together. If a count belongs to a list, render the count inside the same fragment.

Only after that should you consider headers, client events, or out-of-band swaps.

### Swap defaults

Prefer boring swaps:

- Use the default `innerHTML` when replacing contents inside a stable container.
- Use `hx-swap="outerHTML"` when replacing the whole row, card, form, or panel.

Do not vary swap strategies casually. Stable target plus predictable swap is easier to reason about and debug.

## Review anti-patterns

Flag these early:

- Turning simple server-rendered UI into a client-side state machine
- Returning JSON for a page that only one HTML client consumes
- Scattering one element's behavior across templates, controllers, and custom front-end stores
- Tiny endpoints and tiny swaps everywhere with no stable ownership boundaries
- Wrapping HTMX in a helper layer that hides locality of behavior
- Using htmx where a normal link or form is clearer
- Using `hx-trigger` timers where the user action or page load is enough

## Primary sources

- HTMX docs: https://htmx.org/docs/
- `hx-boost`: https://htmx.org/attributes/hx-boost/
- `hx-trigger`: https://htmx.org/attributes/hx-trigger/
- `hx-sync`: https://htmx.org/attributes/hx-sync/
- Active search example: https://htmx.org/examples/active-search/
- 10 tips for SSR and HDA apps: https://htmx.org/essays/10-tips-for-SSR-HDA-apps/
- Locality of Behaviour: https://htmx.org/essays/locality-of-behaviour/
- When to use hypermedia: https://htmx.org/essays/when-to-use-hypermedia/
