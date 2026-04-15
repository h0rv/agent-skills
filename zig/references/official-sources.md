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
  - standard-library docs for `std.posix`, `std.process`, `std.fs`, and `std.net`
- `build.zig`:
  - language reference build section plus `std.Build` source
- deprecated or recently changed APIs:
  - the release notes for the exact version boundary involved

## Source URLs

- https://ziglang.org/download/
- https://ziglang.org/documentation/0.16.0/
- https://ziglang.org/news/0.16.0-released/
- https://ziglang.org/download/0.16.0/release-notes.html

## Current version note

As of 2026-04-15:

- latest stable is `0.16.0`, released on 2026-04-14
- use the official download page to resolve the exact current `master` snapshot
