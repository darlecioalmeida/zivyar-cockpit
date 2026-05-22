# Spider Framework Patch — POST request crash (SIGABRT on macOS)

## Issue

All POST requests crash with `SIGABRT` during `request.respond()`.

**Stack trace:**
```
app.zig:353 → request.respond() → Io/Threaded.zig → _pthread_cond_broadcast
```

The crash only affects POST requests. GET requests work normally.

**Environment:**
- Spider 0.4.0 (commit `728058e6505b2202f0d0494864f650cc29749f1b`)
- Zig 0.17.0-dev.93+76174e1bc
- macOS (Darwin)

## Root cause

The `handleConnection` function reads the POST body **before** calling the route handler and `request.respond()`:

```zig
const body: ?[]const u8 = blk: {
    const cl = request.head.content_length orelse break :blk null;
    if (cl == 0) break :blk null;
    const target_copy = arena.dupe(u8, target) catch break :blk null;
    var body_io_buf: [4096]u8 = undefined;
    const body_reader = request.readerExpectNone(&body_io_buf);
    request.head.target = target_copy;
    break :blk body_reader.readAlloc(arena, cl) catch null;
};
```

Two problems:

1. **No cleanup on partial read**: If `readAlloc` fails (e.g. connection error, premature EOF), the HTTP reader state machine is left in an inconsistent state (e.g. `.body_remaining_content_length`). When `request.respond()` is called afterwards, its internal `discardBody()` encounters a state it doesn't expect, which can corrupt the underlying IO threading primitives.

2. **Inconsistent reader state**: After reading the full body, the HTTP reader state transitions to `.ready`. However, in edge cases (e.g. the body was fully buffered but the reader's content-length tracking didn't reset properly), the state may remain in `.body_remaining_content_length` or another intermediate state. This causes `discardBody()` to attempt further reads/writes on the stream during `respond()`, racing with the threaded IO's internal signal handling mechanism.

On macOS, this manifests as `_pthread_cond_broadcast` SIGABRT because a pthread condition variable internal to libSystem's IO path gets corrupted by the race.

## Fix

Two changes in `src/core/app.zig` → `handleConnection()`:

### 1. Proper body read error recovery

When `readAlloc` fails, discard any remaining body bytes so the reader state machine is clean:

```zig
const result = body_reader.readAlloc(arena, cl) catch blk2: {
    _ = body_reader.discardRemaining() catch {};
    break :blk2 null;
};
```

### 2. Force reader state to `.ready`

After body reading (success or failure), explicitly ensure the HTTP reader state is valid before calling `respond()`:

```zig
if (request.server.reader.state != .ready and
    request.server.reader.state != .closing)
{
    request.server.reader.state = .ready;
}
```

## Patch

See `app.zig.patch` for the unified diff.

## Files affected

- `src/core/app.zig` — `handleConnection()` function, body reading block (~lines 211-227)
