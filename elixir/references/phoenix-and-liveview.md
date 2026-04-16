# Phoenix And LiveView

## Phoenix 1.8 Defaults

- Prefer HEEx and function components for HTML work.
- Prefer `~p` verified routes over old route helpers.
- Prefer the current Phoenix 1.8 layout structure. Older nested-layout patterns are discouraged in new apps.
- Keep `plug_init_mode` at `:runtime` in development when the project follows current Phoenix guidance.

## Rendering Rules

- Treat function components as the default HTML abstraction for controllers, templates, layouts, and LiveViews.
- Use LiveComponents only when you need state or lifecycle inside the parent LiveView process.
- Use a nested LiveView only when you need a separate process boundary, session boundary, or independent lifecycle.
- Keep HEEx markup and assigns obvious at the call site.

## Routing Rules

- Prefer compile-time checked `~p` routes.
- Use `mix phx.routes` when route shape is unclear.
- Keep routers explicit. Avoid helper indirection when a plain scope or pipeline is enough.
- Follow the repo's controller or LiveView split instead of forcing everything into one side.

## LiveView Rules

- Remember the lifecycle: regular HTTP render first, then connected LiveView state.
- Reach first for `mount/3`, `handle_params/3`, `handle_event/3`, and `handle_info/2`.
- Keep assigns small and intentional.
- Use `push_patch/2` for navigation within the current LiveView and `push_navigate/2` for another LiveView in the same `live_session`.
- Use `redirect/2` when a full page load is actually intended.
- Prefer `Phoenix.LiveView.JS` for small client interactions before custom JavaScript.

## Current Phoenix Review Heuristics

- Replace stale `Routes.foo_path(...)` guidance with `~p` when the repo is on current Phoenix.
- Replace view-helper assumptions with function-component and HEEx conventions when the repo is already on Phoenix 1.7 or later.
- Do not rewrite older apps to 1.8 structure unless the task is a migration.
- Keep controllers, components, contexts, and LiveViews in their existing ownership boundaries.

## Practical Source Order

1. Phoenix guides for routing, components, and request lifecycle
2. `Phoenix.Component`, `Phoenix.Controller`, and `Phoenix.VerifiedRoutes`
3. LiveView docs for lifecycle, bindings, uploads, and JS commands
4. Project generators and existing app code for local style
