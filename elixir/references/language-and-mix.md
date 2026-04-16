# Language And Mix

## Elixir 1.19 Defaults

- Use Elixir `1.19` stable docs, not `main`, unless the repo clearly targets `main` or a release candidate.
- Treat new compiler and type warnings as real signal, not noise.
- Prefer documented stdlib and Mix features over custom wrappers or shell scripts.

## Elixir 1.19 Changes Worth Remembering

- Elixir `1.19.0` added protocol type checking and anonymous-function type inference. Older guidance that assumes those warnings do not exist is stale.
- Elixir `1.19.0` added shell docs lookup with `mix help Mod`, `mix help Mod.fun`, `mix help Mod.fun/arity`, and `mix help app:package`.
- Elixir `1.19.0` added `MIX_OS_DEPS_COMPILE_PARTITION_COUNT` for parallel dependency compilation across OS processes.
- Elixir `1.19.0` plus OTP `28+` means regexes can no longer be used as default struct field values. Initialize them in constructors or functions instead.

## Mix And Formatter Rules

- Prefer `mix test`, `mix format`, `mix xref`, `mix credo`, and project aliases before inventing custom task runners.
- Keep `.formatter.exs` current. Elixir `1.19` adds `:excludes` support.
- Treat `mix format --migrate` as an AST-changing operation. Run it in a separate commit and review the diff.
- Format migrations with Ecto's formatter rules when the project uses `ecto_sql`.
- Use formatter plugins only when the repo already depends on them or the task explicitly needs them.

## ExUnit And IEx

- Use ExUnit as the default testing layer. Add coverage in the smallest scope that proves the change.
- Prefer doctests only when the docs are already authoritative and stable.
- Use `iex -S mix` for local inspection, route checks, and quick verification in app context.
- Remember that Elixir `1.19` changed IEx prompts to support multi-line prompts, so older prompt-specific advice may be stale.

## Deprecations To Catch In Reviews

- Move CLI configuration out of `def project` and into `def cli`.
- Use `+` instead of `,` to separate tasks in `mix do`.
- Prefer Logger's `:default_handler` configuration over `:backends`.
- Prefer `:on_conflict` for `File.cp/3` and `File.cp_r/3` conflicts instead of callback arguments.
- Use `<%!-- ... --%>` or `<% # ... %>` for EEx comments, not `<%# ... %>`.
- Use `~c"..."` for new charlists instead of single-quoted charlists.

## Review Habits

- Prefer plain functions, pattern matching, and small modules before macros.
- Use macros only when the abstraction needs compile-time behavior or syntax extension.
- Prefer explicit data flow over dynamic metaprogramming when both are viable.
- Reach for stdlib modules first: `Enum`, `Stream`, `Map`, `Keyword`, `Task`, `Registry`, `DynamicSupervisor`, `GenServer`, `Supervisor`, `OptionParser`, `Date`, `Time`, and `URI`.
