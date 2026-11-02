# Zig Version Policy

Use official Zig sources first.

This skill snapshot was checked against official Zig sources on 2026-11-01:

- latest stable release: `0.17.0`, released 2026-10-01
- current `master`: `0.18.0-dev.828+9da287565`, dated 2026-10-31

Resolve newer releases and development snapshots through https://ziglang.org/download/index.json. Treat these values as a dated snapshot, not a permanent claim about the latest release.

## Default rule

Default to stable `0.17.0` for new code. Honor the repo's existing compiler pin, including older releases, unless the user asks for an upgrade.

Signals that a repo targets something other than stable:

- CI or Docker image installs a dev tarball
- docs mention `master`, nightly, or a specific dev hash
- code already uses APIs not present in stable
- failure messages or `builtin.zig_version` disagree with `0.17.0`

## Source order

Use sources in this order:

1. the repo's pinned Zig version
2. the official download page for release and docs links
3. the matching language reference
4. the matching standard-library docs or local std source from the same Zig version
5. release notes when behavior changed recently or the code uses deprecated APIs

## Practical rules

- If the repo version is not obvious, say which version you are assuming.
- Prefer feature detection such as `@hasDecl` or `@hasField` over version checks when supporting multiple Zig versions.
- Do not mix stable and `master` examples in the same patch unless the repo explicitly does that.
- Use `zig env` to locate the installed compiler's library directory. Treat that version's std source as authoritative for exact signatures.
- Verify examples with the target compiler using `zig test`, `zig build`, or `zig run`. A version-number edit alone does not verify an API migration.
