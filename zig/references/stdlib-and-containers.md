# Zig Stdlib And Containers

## Contents

- allocators and ownership
- common containers
- strings and memory helpers
- formatting and parsing
- JSON and serialization
- testing helpers

## Allocators and ownership

Allocator choice is part of the API design.

Common defaults:

- `std.heap.GeneralPurposeAllocator` for ordinary application ownership
- `std.heap.ArenaAllocator` for phase-based allocation
- `std.testing.allocator` in tests
- caller-provided allocator parameters for reusable libraries

Review rules:

- pass allocators explicitly across library boundaries
- make the freeing side obvious
- pair `init` / `deinit`, `alloc` / `free`, and `dupe` / `free`
- prefer borrowed slices when ownership transfer is unnecessary

## Common containers

### `std.ArrayList`

In current stable Zig, `std.ArrayList(T)` is the standard growable contiguous container.

Prefer the allocator-passing default shape:

```zig
const std = @import("std");

var list: std.ArrayList(u8) = .empty;
defer list.deinit(gpa);

try list.append(gpa, 'a');
try list.appendSlice(gpa, "bc");
```

For stack-backed bounded storage, use `initBuffer`:

```zig
const std = @import("std");

var backing: [8]u8 = undefined;
var list = std.ArrayList(u8).initBuffer(&backing);
try list.appendSliceBounded("zig");
```

If you need the allocator-storing compatibility wrapper, use `std.array_list.Managed(T)` intentionally, but prefer the allocator-passing default shape for new code.

### Maps and sets

Use:

- `std.HashMap`
- `std.AutoHashMap`
- `std.StringHashMap`
- `std.ArrayHashMap`
- `std.AutoArrayHashMap`
- `std.StringArrayHashMap`

Choose `HashMap` for general hashed lookup and `ArrayHashMap` when insertion order or dense key/value arrays help the algorithm.

### Struct-of-arrays and enum-indexed collections

Reach for:

- `std.MultiArrayList`
- `std.EnumArray`
- `std.EnumMap`
- `std.EnumSet`

These are often better fits than hand-written parallel arrays or integer-indexed tables.

### Other useful data structures

Also keep these in mind:

- `std.PriorityQueue`
- `std.PriorityDequeue`
- `std.SinglyLinkedList`
- `std.DoublyLinkedList`
- `std.Treap`
- `std.SegmentedList`

Use them when the data structure matches the problem; do not force everything into `ArrayList`.

## Strings and memory helpers

For text and byte work, check `std.mem` before writing custom helpers.

High-signal functions and iterators:

- `std.mem.eql`
- `std.mem.startsWith`
- `std.mem.trim`, `trimStart`, `trimEnd`
- `std.mem.tokenizeScalar`, `tokenizeAny`, `tokenizeSequence`
- `std.mem.splitScalar`, `splitAny`, `splitSequence`
- `std.mem.sort`, `sortUnstable`

Use slices and byte-oriented helpers by default; do not assume Unicode semantics unless the problem requires it.

## Formatting and parsing

Common `std.fmt` entry points:

- `std.fmt.allocPrint`
- `std.fmt.parseInt`
- `std.fmt.parseFloat`

For output, prefer a real writer or `std.debug.print` depending on the need.

Prefer `std.Io` over `std.io`; the 0.16.0 release notes explicitly move users toward `std.Io` and away from the older `std.io` surface.

## JSON and serialization

Check `std.json` before adding a third-party parser. Be explicit about ownership and allocator use when parsing or stringifying JSON values.

## Other common std modules

Also check the standard library before reaching for third-party code in these areas:

- `std.Random`
- `std.time`
- `std.log`
- `std.ascii`
- `std.unicode`
- `std.crypto`

## Testing helpers

Prefer stdlib testing utilities first:

- `std.testing.expect`
- `std.testing.expectEqual`
- `std.testing.expectEqualStrings`
- `std.testing.expectEqualSlices`
- `std.testing.expectError`
- `std.testing.tmpDir`
- `std.testing.allocator`

Review test code for allocator leaks and temp-dir cleanup the same way you would review production code.
