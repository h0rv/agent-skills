---
name: htmx
description: Build or review simple, server-rendered web features with htmx. Use when Codex needs HTML-first interactivity, progressive enhancement, partial page updates, active search, inline editing, forms, pagination, notifications, job status, logs, or live dashboard updates without defaulting to a SPA. Prefer this skill for framework-agnostic HTMX work and for catching anti-patterns such as JSON-plus-client-templating for simple UI flows, scattered client-side state, or using SSE as fake polling instead of true server push.
---

# HTMX

## Overview

Build HTML-first, server-rendered interfaces that stay easy to inspect and easy to change. Prefer plain links, forms, and server-rendered fragments; use htmx to enhance them locally; treat SSE as one tool inside the HTMX toolbox for real one-way push from the server.

## Workflow

### 1. Check fit before choosing tools

Reach for htmx first when the UI is mostly forms, lists, tables, detail panes, search, filters, pagination, CRUD, notifications, logs, or dashboards with bounded updates.

Treat htmx as a weaker fit when the feature is dominated by high-frequency state changes, free-form drag surfaces, spreadsheets, maps, canvas-heavy behavior, rich offline requirements, or deep client-side state graphs. In those cases, isolate the complex area as an island and keep the rest of the page hypermedia-driven.

### 2. Start with plain HTML

Make links and forms work without htmx first whenever practical.

- Keep real `href`, `action`, and `method` values.
- Prefer `hx-boost="true"` for page navigation and ordinary form submissions that should remain progressively enhanced.
- Keep URLs meaningful. Use `hx-push-url` only when the changed state deserves back-button and deep-link support.

### 3. Add htmx locally and keep behavior obvious

Prefer a small default attribute set:

- `hx-get` and `hx-post`
- `hx-target`
- `hx-swap`
- `hx-trigger`
- `hx-indicator`
- `hx-sync`

Default to server-rendered HTML fragments. Do not introduce JSON plus client templating unless a real non-HTML consumer needs that API.

Target stable, bounded regions that the server can re-render cleanly. Favor one obvious swap over multiple small coordinated client updates.

### 4. Pick the right update mechanism

Use the simplest mechanism that matches the problem:

- User action that sends data: normal form submission or htmx request.
- Occasional refresh on a timer: `hx-trigger="every Ns"` polling.
- One-way server push: SSE.
- Two-way streaming or client-to-server push over one channel: WebSockets or normal HTTP requests.

Do not use SSE to imitate polling. If the browser is supposed to ask every few seconds, use polling. If the server already knows when something changed, use SSE.

### 5. Keep the server as the source of truth

Shape endpoints around UI regions, not around abstract client data models.

- Return the HTML the target needs.
- Re-render the count with the list, the toolbar with the table, and the status with the job output when those pieces change together.
- Use small bits of JavaScript only as glue or as an isolated island of interactivity.

### 6. Preserve locality and resist abstraction creep

Keep the behavior visible where it happens.

- Prefer an explicit `hx-*` attribute on the element over a custom helper layer that hides request URLs, targets, or triggers.
- Do not wrap straightforward HTMX flows in bespoke hooks, controllers, or component abstractions unless the codebase already has a proven local pattern.
- Reach for `HX-Trigger`, out-of-band swaps, and custom JavaScript only after a simpler region re-render is clearly not enough.

## HTMX Defaults

Prefer these habits unless the user or codebase clearly wants otherwise:

- Keep behavior close to the element that owns it.
- Prefer specialized UI endpoints over generic front-end data plumbing.
- Prefer region-level re-rendering over many coordinated micro-updates.
- Use `hx-sync` for request races such as search and validation.
- Use `HX-Trigger` or client-side events sparingly for cross-region coordination.
- Reach for out-of-band swaps only after simpler region design fails.

Read [references/htmx-patterns.md](references/htmx-patterns.md) for examples, endpoint patterns, and review heuristics.

## SSE Defaults

Use the htmx SSE extension only when the server has new information to push to the browser.

- Add `hx-ext="sse"` and `sse-connect` on the owning container.
- Use `sse-swap` when the event payload already contains the HTML to swap.
- Use `hx-trigger="sse:event-name"` with `hx-get` only when an SSE event should trigger a follow-up HTTP render.
- Keep connections coarse-grained: one stream per page or logical region is usually enough.
- Use named events for distinct message types.
- Use `sse-close` for finite streams such as job completion.

Do not use SSE for request-response flows, writes, or pseudo-polling loops. If the client needs to send data, use a form, `hx-post`, or another bidirectional mechanism.

Read [references/sse-patterns.md](references/sse-patterns.md) before adding or reviewing SSE behavior.
Read [references/sse-server-checklist.md](references/sse-server-checklist.md) before implementing an SSE endpoint.

## Review Checklist

When implementing or reviewing HTMX and SSE code, verify these points:

- Could this stay a plain link or form with progressive enhancement?
- Is the swap target a bounded region with a stable selector?
- Is the server returning HTML that directly matches the target?
- Is history used only where the changed state should be navigable?
- Is SSE used only for true push, not as a timer or a command bus?
- Does the SSE endpoint send a correct `text/event-stream` response and flush events properly?
- Is JavaScript limited to glue code or a clearly bounded island?
