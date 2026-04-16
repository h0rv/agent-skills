# Version Policy

This skill is pinned to official sources current on 2026-04-16.

## Defaults

- Treat Elixir `1.19` as the default stable target when a repo does not pin a different version.
- Treat the current stable Elixir docs as `v1.19.5`, while remembering the user asked for the `1.19` line introduced by `v1.19.0` on 2025-10-16.
- Treat OTP `26`, `27`, and `28` as the supported Erlang range for Elixir `1.19`.
- Treat Phoenix `1.8.5` and LiveView `1.1.28` as the current default web stack unless the repo pins older majors or minors.

## Version Selection Rules

1. Check `mix.exs`, `mix.lock`, `.tool-versions`, `Dockerfile*`, CI, release config, and editor settings first.
2. If the repo pins older Phoenix or LiveView versions, follow the repo instead of forcing 1.8 or 1.1 conventions.
3. If the repo does not pin patch versions, use current stable patch docs for the pinned minor line.
4. Prefer current stable docs and changelogs over blog posts, tutorials, and random examples.
5. Use `main` or release-candidate docs only when the repo clearly targets them.

## Current Versions To Assume When Unpinned

- Elixir docs: `1.19.5`
- Phoenix: `1.8.5`
- Phoenix LiveView: `1.1.28`
- Plug: `1.19.1`
- Ecto / Ecto SQL: `3.13.5`
- Phoenix.Ecto: `4.7.0`
- Phoenix LiveDashboard: `0.8.7`
- telemetry: `1.4.1`
- Bandit: `1.10.4`

## What To Verify Before Making Changes

- Language syntax or warning behavior that changed in Elixir `1.19`
- OTP compatibility constraints, especially regex handling on OTP `28+`
- Phoenix structure changes between `1.7` and `1.8`
- LiveView navigation and component APIs
- Formatter config and migration formatting
- Editor guidance that still assumes ElixirLS instead of Expert

If the version surface is still unclear, open [official-sources.md](official-sources.md) and follow the upstream docs in that order.
