# Zig Language Core

## Contents

- typing and coercions
- pointers, slices, and sentinels
- enums and tagged unions
- control flow
- errors, optionals, and cleanup
- comptime and generic style

## Typing and coercions

Prefer explicit types when they communicate ownership, alignment, ABI intent, or public API shape. Let inference carry obvious locals, but annotate exported functions, struct fields, allocators, and cross-module boundaries.

Key areas to check:

- integer width and signedness
- optional vs error-union vs tagged-union modeling
- slice vs pointer vs array
- sentinel-terminated values such as `[:0]const u8`
- `extern`, `packed`, and ABI-facing layouts

Prefer exact builtins for conversions:

- `@intCast`
- `@floatFromInt`
- `@intFromFloat`
- `@ptrCast`
- `@alignCast`
- `@bitCast`
- `@enumFromInt`
- `@intFromEnum`

Do not rely on clever coercions when crossing API boundaries.

## Pointers, slices, and sentinels

Distinguish carefully between:

- `*T`
- `[*]T`
- `[]T`
- `[:0]T`
- `?*T`
- `?[]const u8`

Review these questions before editing:

- Does the callee want one item, many items, or a length-tracked slice?
- Is the data mutable?
- Is there a sentinel contract?
- Is alignment part of the type?
- Is a C pointer more appropriate than a Zig slice at this boundary?

For strings, default to `[]const u8`. Use sentinel-terminated forms only when the callee genuinely requires them.

## Enums and tagged unions

Use enums when the set of values is closed and small. Use tagged unions when each case carries different payload data.

Prefer:

- `std.EnumArray`
- `std.EnumMap`
- `std.EnumSet`

When an enum is used as a dispatch key, `switch` is usually the right surface.

Tagged-union review rules:

- prefer `union(enum)` for sum types
- switch on the union tag instead of manual tag integers
- keep payload capture types obvious
- avoid parallel tag-plus-payload structs when a tagged union models the domain directly

## Control flow

Use Zig control flow directly rather than forcing another language's style onto it.

Reach first for:

- `switch` for exhaustive branching on enums, tagged unions, and small value spaces
- `if` for binary decisions and optional or error capture
- `while` for iterator-style loops or state machines
- `for` for slices, arrays, and collections
- labeled blocks for local expression-oriented branching

Examples of idiomatic control-flow surfaces:

- `if (maybe_value) |value| { ... } else { ... }`
- `if (fallible()) |value| { ... } else |err| { ... }`
- `switch (tag) { .a => ..., .b => ... }`
- `const result = blk: { ... break :blk value; };`

Avoid deeply nested conditionals when a `switch` or local helper would make the state machine explicit.

## Errors, optionals, and cleanup

Use the language features directly:

- `try`
- `catch`
- `orelse`
- `defer`
- `errdefer`

Model absence with optionals and failures with error unions. Do not collapse both into sentinel integers or nullable booleans.

Review cleanup paths carefully:

- `defer` for unconditional cleanup
- `errdefer` for rollback on failure only
- allocate and free in clearly paired scopes

## Comptime and generic style

Use `comptime` to express compile-time parameters and specialization, not as a substitute for runtime design.

Prefer:

- `comptime T: type`
- `anytype` for local forwarding helpers
- `@TypeOf(...)` when the inferred type is part of the logic
- `@hasDecl` and `@hasField` for compatibility or generic feature detection
- `@import("builtin")` for target and mode information

Keep generic APIs narrow. If a function only needs one concrete capability, do not over-generalize it immediately.
