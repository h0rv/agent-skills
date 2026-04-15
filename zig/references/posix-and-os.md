# Zig POSIX And OS APIs

## Contents

- when to use `std.posix`
- files and descriptors
- sockets and networking
- processes and subprocesses
- cross-platform boundaries

## When to use `std.posix`

Use `std.posix` for low-level OS-facing work where file descriptors, permissions, signals, sockets, and syscall-shaped APIs are the right abstraction.

Prefer higher-level `std` modules first when they fit:

- `std.fs` for ordinary file work
- `std.Io` for current I/O interfaces
- `std.net` for common networking flows
- `std.process.Child` for subprocess management

In Zig 0.16.0, many awkward medium-level `std.posix` and `std.os.windows` helpers were removed. When code hits that boundary, choose a direction explicitly:

- go higher to `std.Io`
- go lower to `std.posix.system`

Use `std.posix` when the task is truly OS-level or descriptor-oriented.

## Files and descriptors

Common low-level entry points include:

- `std.posix.openZ`
- `std.posix.read`
- `std.posix.write`
- `std.posix.close`

Review rules:

- keep descriptor ownership obvious
- `defer std.posix.close(fd)` once ownership is established
- prefer Zig errors over manual errno plumbing
- use `std.fs.File` when a file object is a better fit than a raw descriptor

## Sockets and networking

Current `std.posix` exposes direct socket APIs such as:

- `std.posix.socket`
- `std.posix.bind`
- `std.posix.listen`
- `std.posix.connect`
- `std.posix.send`
- `std.posix.recv`
- `std.posix.setsockopt`

Use `std.net` first for higher-level client/server code. Use `std.posix` when you need exact socket options, descriptor control, or OS-specific networking behavior.

## Processes and subprocesses

For spawning and managing child processes, prefer `std.process.Child`.

For process-wide helpers, use `std.process` intentionally. In Zig 0.16.0, environment variables and argv are no longer treated as ambient global state. Prefer:

- `pub fn main(init: std.process.Init) !void`
- `pub fn main(init: std.process.Init.Minimal) !void`

For current-directory access, prefer:

- `std.process.currentPath(io, buffer)`
- `std.process.currentPathAlloc(io, allocator)`

When writing reusable libraries, avoid hiding process state deep inside helpers if the caller can pass the needed path, env, or argv data explicitly.

## Cross-platform boundaries

Keep OS assumptions visible:

- gate platform-specific code with `@import("builtin")`
- prefer `builtin.os.tag` checks at clear module boundaries
- isolate `std.posix` code from Windows-specific logic rather than interleaving both everywhere
- validate path, encoding, and permission assumptions explicitly

For C ABI or syscall-level work, keep the boundary narrow and typed.
