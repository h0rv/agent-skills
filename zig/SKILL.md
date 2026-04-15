---
name: zig
description: Write, review, explain, and update Zig code using current official Zig language and standard-library APIs. Use when Codex needs up-to-date Zig guidance for language features, typing, enums, control flow, allocators, data structures, `std`, `std.posix`, `std.fs`, `std.Io`, testing, `build.zig`, packages, C interop, or cross-platform systems programming.
---

# Zig

Use current official Zig sources, not stale model memory.

This skill snapshot is written against Zig sources current on 2026-04-15:

- latest stable: `0.16.0` released 2026-04-14
- current `master`: use the download page for the exact current dev snapshot

Default to stable `0.16.0` unless the repo clearly pins `master` or a specific dev snapshot.

## Start Here

1. Confirm the target Zig version before editing: check `zig version`, CI, Dockerfiles, `build.zig.zon`, README snippets, and download URLs.
2. Default to stable docs and APIs when the repo does not pin a dev build.
3. If the repo targets `master`, use the exact dev snapshot when possible; do not assume `master` APIs from memory.
4. Match the repo's style, but prefer current non-deprecated APIs when the codebase is already on current Zig.
5. Treat allocators, ownership, sentinels, alignment, and error sets as semantic design choices.

## Workflow

### 1. Classify the task first

Sort the task into one or more of these buckets:

- language and typing
- enums, tagged unions, and control flow
- allocators, containers, and ownership
- strings, slices, pointers, and alignment
- `std` modules such as `mem`, `fmt`, `json`, `testing`, and `Random`
- `std.fs`, `std.Io`, `std.process`, `std.net`, and `std.posix`
- `build.zig` or package/import wiring
- C interop or cross-platform OS work

### 2. Load only the matching reference

- Read [references/version-policy.md](references/version-policy.md) first when the target Zig version is unclear.
- Read [references/language-core.md](references/language-core.md) for typing, enums, tagged unions, control flow, `comptime`, and builtin usage.
- Read [references/stdlib-and-containers.md](references/stdlib-and-containers.md) for allocators, `ArrayList`, maps, enum collections, strings, formatting, JSON, and testing helpers.
- Read [references/posix-and-os.md](references/posix-and-os.md) for `std.posix`, file descriptors, sockets, child processes, `std.net`, and cross-platform boundaries.
- Read [references/build-and-interop.md](references/build-and-interop.md) for `build.zig`, modules, dependencies, tests, and C interop.

## Default Review Heuristics

- Check whether version-specific assumptions are explicit and current.
- Check whether pointer, slice, sentinel, and alignment types match what the callee actually expects.
- Check whether error sets, optionals, and tagged unions are modeled explicitly instead of being flattened into magic values.
- Check whether `switch`, `for`, `while`, labeled blocks, `defer`, and `errdefer` are being used idiomatically rather than imitating C or Rust control flow.
- Check whether container ownership and allocator lifetime are obvious at the call site.
- Check whether `std.mem`, `std.fmt`, `std.json`, `std.testing`, and `std.posix` helpers already solve the problem before inventing custom utilities.
- Check whether the code should use `std.net` or higher-level `std` APIs before dropping to raw `std.posix`.
- Check whether `build.zig` is using current `std.Build` patterns instead of cargo-like or cmake-like abstractions.

## Reference Map

- Read [references/version-policy.md](references/version-policy.md) for the current stable-vs-master rule and official source order.
- Read [references/language-core.md](references/language-core.md) for typing, enums, unions, error handling, `comptime`, and control flow.
- Read [references/stdlib-and-containers.md](references/stdlib-and-containers.md) for allocators, collections, common std helpers, and testing utilities.
- Read [references/posix-and-os.md](references/posix-and-os.md) for `std.posix`, file descriptors, sockets, and OS-facing APIs.
- Read [references/build-and-interop.md](references/build-and-interop.md) for `build.zig`, modules, dependencies, tests, and C interop.
- Read [references/official-sources.md](references/official-sources.md) when you need the exact upstream doc or release-note entry.
