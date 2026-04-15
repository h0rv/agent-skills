# Zig Version Policy

Use official Zig sources first.

This skill snapshot is pinned to the official Zig state visible on 2026-04-15:

- latest stable release: `0.16.0` released 2026-04-14
- current `master`: check the official download page for the exact dev snapshot before relying on it

## Default rule

Default to stable `0.16.0` unless the repo clearly targets `master` or a specific dev snapshot.

Signals that a repo targets something other than stable:

- CI or Docker image installs a dev tarball
- docs mention `master`, nightly, or a specific dev hash
- code already uses APIs not present in stable
- failure messages or `builtin.zig_version` disagree with `0.16.0`

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
- If the repo uses local `zig` `0.16.0`, treat that local std source as authoritative for exact signatures.
