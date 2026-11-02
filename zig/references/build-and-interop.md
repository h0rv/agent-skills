# Zig Build, Tests, And Interop

## Contents

- `build.zig`
- modules and dependencies
- tests and run steps
- I/O and file handles
- C interop

## `build.zig`

Use current `std.Build` APIs directly. The core building blocks in stable Zig include:

- `b.addExecutable`
- `b.addTest`
- `b.createModule`
- `b.addModule`
- `b.addRunArtifact`
- `b.dependency`

Start from this shape:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_step = b.addRunArtifact(exe);
    _ = run_step;
}
```

Prefer a small, explicit build graph. Do not cargo-cult wrapper layers around `std.Build` unless the repo already has a strong local abstraction.

## Modules and dependencies

Use modules intentionally:

- `b.createModule(...)` for a module value
- `b.addModule(name, ...)` when you want to register it by name on the build graph
- `b.dependency(...)` for dependencies declared in `build.zig.zon`

Keep imports explicit and avoid magical global wiring.

## Tests and run steps

Use `b.addTest(...)` for test artifacts and `b.addRunArtifact(...)` when the build graph should run something.

Pair that with ordinary source-level tests:

```zig
const std = @import("std");

test "parse count" {
    try std.testing.expectEqual(@as(u32, 3), parseCount("3"));
}
```

Use `std.testing.tmpDir` and `std.testing.allocator` when tests need filesystem state or allocation checks.

## I/O and file handles

Current stable Zig exposes `std.Io` as the main I/O surface. Prefer `std.Io` terminology and current file interfaces over the older `std.io` abstractions.

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdout_buf: [1024]u8 = undefined;
    var out = std.Io.File.stdout().writer(init.io, &stdout_buf);
    try out.interface.print("hello\n", .{});
    try out.interface.flush();
}
```

For small debug-style output, `std.debug.print` is still the simplest option.

## C interop

Use Zig's C interop intentionally:

- `@cImport` is removed in Zig `0.17.0`
- `zig translate-c` still exists, but `std.Build.Step.TranslateC` is deprecated
- prefer the official external `translate-c` package for build-system-driven C translation
- narrow the ABI boundary and convert to Zig-native types quickly
- prefer Zig slices, enums, and tagged unions once data crosses the boundary

For 0.17.x, add the matching translator dependency:

```bash
zig fetch --save git+https://codeberg.org/ziglang/translate-c#zig-0.17.x
```

Follow the package's version-matched build example using `@import("translate_c").Translator`, `.c_source_file`, and `translator.mod`. Do not replace `@cImport` with an unverified call to the deprecated build step.

See the [official C translation migration](https://ziglang.org/download/0.17.0/release-notes.html#C-Translation-Moving-to-External-Package).

When the project has substantial C surface area, keep translated declarations isolated in one place instead of sprinkling them across modules.
