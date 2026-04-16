---
name: elixir
description: Write, review, explain, and update Elixir code using current Elixir 1.19 and official ecosystem APIs. Use when Codex needs up-to-date guidance for Elixir syntax, stdlib, Mix, ExUnit, IEx, Hex and package workflows, OTP/BEAM behaviours, Phoenix, LiveView, HEEx, Plug, Ecto, Phoenix.HTML, Phoenix.PubSub, telemetry, Bandit, LiveDashboard, Expert LSP, or other current core Elixir and Phoenix libraries, and when older Elixir advice may be stale.
---

# Elixir

Use current official Elixir and ecosystem sources, not stale model memory.

This skill snapshot is written against sources current on 2026-04-16:

- Elixir stable line: `1.19` (stable docs currently `v1.19.5`; `v1.19.0` released 2025-10-16)
- supported OTP for Elixir `1.19`: `26`, `27`, `28`
- Phoenix `1.8.5`
- Phoenix LiveView `1.1.28`
- Plug `1.19.1`
- Ecto and Ecto SQL `3.13.5`
- Phoenix.Ecto `4.7.0`
- LiveDashboard `0.8.7`
- telemetry `1.4.1`
- Expert is the official Elixir LSP and is still working toward its first release

## Start Here

1. Confirm the target versions before editing: check `mix.exs`, `mix.lock`, `.tool-versions`, CI, Dockerfiles, and deployment images.
2. Default to Elixir `1.19` docs and Phoenix `1.8` / LiveView `1.1` docs when the repo does not pin something older.
3. Match the repo's style and upgrade surface. Do not silently rewrite older Phoenix structure into 1.8 generator output unless the task is explicitly a migration.
4. Prefer stdlib, OTP behaviours, and official libraries before new dependencies.
5. Prefer current defaults: HEEx, function components, `~p` verified routes, changesets for external data, modern `.formatter.exs`, and current official tooling guidance. Prefer Expert when the task is explicitly about current editor or LSP setup.

## Workflow

### 1. Classify the task first

Sort the task into one or more of these buckets:

- language, stdlib, macros, types, protocols, or parsing
- Mix, formatting, compilation, testing, docs, or CLI tasks
- OTP / BEAM processes, supervisors, `GenServer`, `Registry`, ETS, distribution, or release behavior
- Plug / Phoenix HTTP, routers, controllers, components, or endpoint config
- LiveView, LiveComponent, HEEx, uploads, JS commands, or navigation
- Ecto schemas, changesets, queries, repos, migrations, or SQL adapters
- tooling such as Hex, Expert, formatter plugins, LiveDashboard, telemetry, or Bandit

### 2. Load only the matching reference

- Read [references/version-policy.md](references/version-policy.md) first when Elixir, OTP, Phoenix, or LiveView versions are unclear.
- Read [references/language-and-mix.md](references/language-and-mix.md) for Elixir 1.19 language changes, stdlib, Mix, formatter, ExUnit, IEx, and deprecations.
- Read [references/otp-and-beam.md](references/otp-and-beam.md) for supervision trees, `GenServer`, process ownership, registries, and BEAM-facing design rules.
- Read [references/phoenix-and-liveview.md](references/phoenix-and-liveview.md) for HEEx, components, `~p`, controllers, routers, LiveView lifecycle, and current Phoenix conventions.
- Read [references/data-and-tooling.md](references/data-and-tooling.md) for `Ecto`, `Ecto.SQL`, `Plug`, `Phoenix.Ecto`, telemetry, Bandit, LiveDashboard, and Expert.
- Read [references/official-sources.md](references/official-sources.md) when you need the exact upstream doc, changelog, or guide.

## Default Review Heuristics

- Check whether the repo pins older Elixir, OTP, Phoenix, or LiveView versions before applying current syntax or APIs.
- Check whether old guidance is leaking in: `Routes.*` helpers instead of `~p`, nested Phoenix layouts, stale EEx comments, old Logger backend config, or outdated `mix do` syntax.
- Check whether external data uses `Ecto.Changeset.cast/4` and internal data uses `change/2`, `put_change/3`, or direct structs.
- Check whether OTP responsibilities are clear: supervisors supervise, `GenServer` owns state, and blocking work is isolated from request paths when needed.
- Check whether Phoenix and LiveView code uses HEEx, function components, and current routing and navigation APIs instead of older view and helper patterns.
- Check whether `.formatter.exs`, `mix format`, and migration formatter rules match current Mix behavior.
- Check whether tooling guidance prefers Expert for current editor and LSP setup, while leaving older ElixirLS setups alone unless the task is explicitly a migration.

## Reference Map

- Read [references/version-policy.md](references/version-policy.md) for version selection and supported compatibility ranges.
- Read [references/language-and-mix.md](references/language-and-mix.md) for Elixir 1.19 language, Mix, formatter, ExUnit, IEx, and deprecation rules.
- Read [references/otp-and-beam.md](references/otp-and-beam.md) for OTP behaviours, supervision, and BEAM process design.
- Read [references/phoenix-and-liveview.md](references/phoenix-and-liveview.md) for Phoenix 1.8 and LiveView 1.1 conventions.
- Read [references/data-and-tooling.md](references/data-and-tooling.md) for Ecto, Plug, telemetry, Bandit, LiveDashboard, and Expert.
- Read [references/official-sources.md](references/official-sources.md) when you need the exact upstream source order or docs URL.
