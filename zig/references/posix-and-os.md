# Zig POSIX and OS APIs

This reference targets Zig 0.17.0. Check the project's compiler pin before applying these APIs to older code.

## Files and directories

Prefer `std.Io.File` and `std.Io.Dir` for ordinary filesystem operations. Pass an explicit `std.Io` value to operations and cleanup:

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const file = try std.Io.Dir.cwd().openFile(io, "input.txt", .{});
    defer file.close(io);
}
```

Keep file ownership visible. Do not copy older examples using `std.fs.File` or a `close()` call without `io`. For path helpers, prefer `std.Io.Dir.path` over the deprecated `std.fs.path` alias.

## Sockets and networking

Use `std.Io.net` for normal networking. Check its `IpAddress`, `HostName`, `Stream`, and `Server` APIs in the matching compiler's source. There is no root `std.net` export in 0.17.0.

Pass `io` explicitly. Confirm the exact method and options for the target release rather than copying an older socket tutorial.

## When to use `std.posix`

Use `std.posix` only when the task needs a platform-specific OS boundary. Many former wrappers are absent in 0.17.0, including `openZ`, `write`, `close`, `socket`, `bind`, `listen`, `connect`, `send`, and `recv`. Some wrappers, such as `read` and `setsockopt`, remain. Check declarations before assuming either presence or removal.

Choose the level explicitly:

- Prefer `std.Io` for portable file and network operations.
- Use `std.posix.system` for intentional raw OS calls.

Raw calls do not automatically provide the removed wrappers' Zig error handling. Handle the platform's return values and errors explicitly. Do not recommend `defer std.posix.close(fd)` on this release.

## Processes and subprocesses

Create children with `std.process.spawn(io, options)`. The returned `std.process.Child` is a handle, not the old constructor API. Use `child.wait(io)` and `child.kill(io)` as needed. For captured output, check `std.process.run(gpa, io, options)` and its allocation cleanup requirements.

For application entry points, prefer `pub fn main(init: std.process.Init) !void`. Use `init.io` for I/O, `init.gpa` for general allocation, and `init.minimal` for arguments and environment. `std.process.Init.Minimal` does not provide an `io` field.

For current-directory paths, check:

- `std.process.currentPath(io, buffer)`
- `std.process.currentPathAlloc(io, allocator)`

Pass process state into reusable libraries instead of hiding access to arguments, environment, or the current directory inside helpers.

## Cross-platform boundaries

Keep OS assumptions visible:

- Import target information with `@import("builtin")`.
- Prefer `builtin.target.os.tag` over the deprecated `builtin.os.tag` alias.
- Isolate POSIX and Windows code at module boundaries.
- Check path encoding and permission assumptions explicitly.

For C ABI or syscall-level work, keep the boundary narrow and typed.
