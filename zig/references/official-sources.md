# Zig Official Sources

Use these primary sources in this order:

1. the repo's actual Zig version
2. the official Zig download page
3. the matching language reference
4. the matching standard-library docs
5. release notes only when recent changes or deprecations matter
6. the local std source from the same Zig version when exact signatures matter

## What to read for common tasks

- language syntax, typing, enums, tagged unions, control flow:
  - Zig language reference for the matching version
- allocators, collections, strings, formatting, testing:
  - standard-library docs plus local std source
- `std.posix`, sockets, file descriptors, process helpers:
  - standard-library docs and matching source for `std.Io.File`, `std.Io.Dir`, `std.Io.net`, `std.process`, and `std.posix`
- `build.zig`:
  - language reference build section plus `std.Build` source
- deprecated or recently changed APIs:
  - the release notes for the exact version boundary involved

## Source URLs

- https://ziglang.org/download/
- https://ziglang.org/download/index.json
- https://ziglang.org/documentation/0.17.0/
- https://ziglang.org/documentation/0.17.0/std/
- https://ziglang.org/download/0.17.0/release-notes.html
- https://ziglang.org/download/0.17.0/release-notes.html#SafeAllocator-Introduced
- https://ziglang.org/download/0.17.0/release-notes.html#C-Translation-Moving-to-External-Package
- https://ziglang.org/download/0.17.0/release-notes.html#Language-Changes

## Current version note

As checked on 2026-11-01:

- latest stable is `0.17.0`, released on 2026-10-01
- `master` is `0.18.0-dev.828+9da287565`, dated 2026-10-31

Use the official download index to resolve newer stable releases and exact development snapshots. Use the project's pinned compiler even when it is older than this snapshot.
