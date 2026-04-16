# Data And Tooling

## Ecto Rules

- Remember the split: `Ecto.Repo` talks to the data store, `Ecto.Schema` maps data, `Ecto.Query` composes queries, and `Ecto.Changeset` filters and validates changes.
- Use `cast/4` for external data and `change/2` or `put_change/3` for internal data.
- Keep constraints and validation boundaries explicit.
- Use repo functions and query composition before raw SQL, unless the task truly needs adapter-specific SQL.

## Hex And Dependencies

- Use Hex package metadata, docs, and locked dependency versions as the source of truth for package selection and APIs.
- Check `mix.exs`, `mix.lock`, and any version constraints before suggesting upgrades or new dependencies.
- Prefer existing dependencies already in the repo before adding adjacent packages from the same ecosystem.
- When package docs matter, prefer package docs on HexDocs and package metadata on hex.pm over blog posts or copied snippets.

## Ecto SQL Rules

- Use `mix ecto.gen.migration`, `mix ecto.migrate`, `mix ecto.rollback`, and `mix ecto.migrations` for migration workflows.
- Prefer reversible `change/0` migrations when possible.
- Use migration formatter rules for `priv/*/migrations` in projects that use `ecto_sql`.
- Route SQL helper calls through the repo unless you specifically need direct `Ecto.Adapters.SQL` access.

## Plug Rules

- `Plug.init/1` may run at compile time, so do not put runtime-only state there.
- Treat `Plug.Conn` as the canonical request and response state container.
- Use module plugs for reusable pipeline units and function plugs for small local concerns.

## Phoenix.Ecto, Telemetry, And Ops

- Use `Phoenix.Ecto` integration where forms or rendering protocols already depend on it.
- Use `:telemetry` for instrumentation events instead of bespoke callback registries.
- Use LiveDashboard for real-time Phoenix and BEAM inspection in development and controlled ops environments.

## Bandit

- Bandit is a current, fully supported HTTP server for Plug and Phoenix.
- If a Phoenix app already uses Bandit, keep its endpoint adapter and server config intact.
- Do not migrate Cowboy to Bandit implicitly; follow the repo unless the task is about server choice or upgrade work.

## Expert

- Prefer Expert for current Elixir LSP guidance. It is the official Elixir language server implementation.
- Expert is still working toward its first release, so installation docs and editor support may still be moving.
- For manual setup, remember the server is typically started with `--stdio` when the editor does not do it automatically.
- Do not rewrite a user's editor setup from ElixirLS to Expert unless the task is explicitly about editor or tooling migration.

## Tooling Review Heuristics

- Prefer official docs, Mix tasks, and built-in tooling before shell glue.
- Keep formatter, linter, and test commands aligned with the repo's aliases and CI.
- Treat editor and LSP config as user environment unless the task explicitly includes it.
