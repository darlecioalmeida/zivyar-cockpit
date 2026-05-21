# Zig 0.16/0.17 APIs — Spider Framework Reference

APIs extraídas do código real do Spider e monitor. Nada teórico — só o que compila e funciona.

---

## 1. I/O — Stream, Reader, Writer

### Inicializar Reader e Writer

Ambos exigem **3 argumentos**: `(stream, io, &buffer)`.

```zig
// ✅ Funciona no 0.16/0.17
// src/core/app.zig:179
var stream_reader = Io.net.Stream.Reader.init(ctx.stream, ctx.io, &read_buf);
var stream_writer = Io.net.Stream.Writer.init(ctx.stream, ctx.io, &write_buf);

// Ou com import "net"
// src/ws/websocket.zig:39,45
self._reader = net.Stream.Reader.init(self.stream, self.io, &self._read_buf);
var sw = net.Stream.Writer.init(self.stream, self.io, &self._write_buf);

// Em testes — socket direto sem stream
// src/ws/hub.zig:333
var reader = net.Stream.Reader.init(.{ .socket = sockets[1] }, io, &read_buf);
```

### Escrever no stream

```zig
// ✅ Funciona
// src/ws/hub.zig:230-235
try writer.writeAll("event: ");
try writer.writeAll(event);
try writer.writeAll("\ndata: ");
try writer.writeAll(data);
try writer.writeAll("\n\n");
try writer.flush();

// Ou pelo sw.interface (stream writer)
// src/ws/websocket.zig:46-47
try sw.interface.writeAll(data);
try sw.interface.flush();
```

### Ler do stream

```zig
// ✅ Funciona — usar reader.interface.readSliceAll
// src/ws/hub.zig:334
try reader.interface.readSliceAll(buf[0..2]);
```

### Reutilizar o Reader (crítico!)

Criar um novo Reader por chamada **perde o buffer interno** e corrompe a leitura.

```zig
// ✅ Correto — um Reader para todo o ciclo de vida
// src/ws/websocket.zig:33-41
_read_buf: [65536]u8 = undefined,
_reader: ?net.Stream.Reader = null,

fn readAll(self: *Server, buf: []u8) !void {
    if (self._reader == null) {
        self._reader = net.Stream.Reader.init(self.stream, self.io, &self._read_buf);
    }
    try self._reader.?.interface.readSliceAll(buf);
}
```

```zig
// ❌ NÃO faça — recriar o Reader por chamada perde dados no buffer
var reader = net.Stream.Reader.init(stream, io, &buf); // cada vez recria!
```

---

## 2. JSON

### Serializar (alocar)

```zig
// ✅ Funciona — std.json.Stringify.valueAlloc
// src/core/context.zig:78
const body = try std.json.Stringify.valueAlloc(self.arena, value, .{});

// src/ws/hub.zig:111
const json = std.json.Stringify.valueAlloc(self.allocator, data, .{}) catch return;
defer self.allocator.free(json);
```

### Serializar (streaming, sem alocar)

```zig
// ✅ Funciona — std.json.Stringify.value (com writer)
// pg_driver_impl/src/types.zig:465
try std.json.Stringify.value(value, .{}, &buf.interface);
```

### O que NÃO usar

```zig
// ❌ std.json.stringify — NÃO EXISTE no 0.16/0.17
try std.json.stringify(value, .{}, writer);

// ❌ std.io.fixedBufferStream — foi REMOVIDO
var fbs = std.io.fixedBufferStream(&buf);

// ❌ std.io (minúsculo) — removido, usar std.Io (I maiúsculo)
const Io = std.Io;  // ✅ correto
```

---

## 3. Sleep / Timers

### std.Io.sleep (dentro do scheduler Io.Threaded)

```zig
// ✅ Funciona — DENTRO de uma thread com Io
// src/drivers/pg/pg.zig:99
try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(delay_ms), .real);

// src/core/app.zig:485-489
std.Io.sleep(
    entry.io,
    std.Io.Duration.fromMilliseconds(@as(i64, @intCast(entry.ms))),
    .real,
) catch {};
```

### Duration helpers

```zig
std.Io.Duration.fromMilliseconds(i64)  // ✅ existe
std.Io.Duration.fromSeconds(i64)       // ✅ existe
.fromNanoseconds(i64)                  // ✅ existe (inferência)
```

### Thread nativa — usar std.Thread.sleep

```zig
// ✅ Funciona em thread nativa
std.Thread.sleep(ns); // ns = u64
```

### O que NÃO usar

```zig
// ❌ std.time.sleep — removido no 0.12
std.time.sleep(100 * std.time.ns_per_ms);

// ❌ std.c.nanosleep — funciona mas é sujo, preferir os acima
_ = std.c.nanosleep(&req, null);
```

---

## 4. ArrayList

### std.ArrayListUnmanaged

```zig
// ✅ Inicializar
// src/ws/hub.zig:9
connections: std.ArrayListUnmanaged(Connection) = .empty,

// src/ws/hub.zig:70
var snapshot: std.ArrayListUnmanaged(Connection) = .empty;

// src/binding/form.zig:84
var arr = std.ArrayListUnmanaged([]const u8){ .items = &.{}, .capacity = 0 };
```

```zig
// ✅ Append
// src/ws/hub.zig:37
try self.connections.append(self.allocator, conn);
// OU se não quiser propagar erro:
snapshot.append(self.allocator, conn) catch {};
```

```zig
// ✅ Deinit
// src/ws/hub.zig:28
self.connections.deinit(self.allocator);

// Sempre com defer:
// src/ws/hub.zig:71
defer snapshot.deinit(self.allocator);
```

```zig
// ✅ Remove por índice
// src/ws/hub.zig:56
_ = self.connections.orderedRemove(i);
```

```zig
// ✅ ToOwnedSlice
// src/drivers/pg/pg.zig:238
return try items.toOwnedSlice(arena);
```

```zig
// ✅ Writer para JSON (com allocator)
// src/ws/sse.zig:15 (usando valueAlloc em vez de writer)
const json = try std.json.Stringify.valueAlloc(self.arena, data, .{});
```

---

## 5. Threads

### Spawn

```zig
// ✅ Funciona
// src/core/app.zig:689
const t = std.Thread.spawn(.{}, intervalLoop, .{entry.*}) catch continue;

// Com stack size customizado
// pg_driver_impl/src/pool.zig:356
self.thread = try Thread.spawn(.{ .stack_size = 1024 * 1024 }, Reconnector.run, .{self});
```

### Detach (fire-and-forget)

```zig
// ✅ Funciona
// src/core/app.zig:690
t.detach();
```

### Join (aguardar término)

```zig
// ✅ Funciona
// src/core/app.zig:726
for (threads) |t| t.join();
```

### Passar estado

```zig
// ✅ Struct como argumento
// src/core/app.zig:427-435 + 689
const IntervalEntry = struct {
    hub: *Hub,
    ms: u64,
    callback: *const fn (*Hub) void,
    io: std.Io,
};

fn intervalLoop(entry: IntervalEntry) void {
    while (true) {
        std.Io.sleep(entry.io, ..., .real) catch {};
        entry.callback(entry.hub);
    }
}

// Spawn:
const t = std.Thread.spawn(.{}, intervalLoop, .{entry.*}) catch continue;
```

### ⚠️ Threads nativas NÃO devem usar std.Io.sleep com Io local

```zig
// ❌ ERRADO — Io local com init_single_threaded pode ser dangling
fn intervalLoop(entry: IntervalEntry) void {
    var threaded = std.Io.Threaded.init_single_threaded; // local!
    const io = threaded.io();
    while (true) {
        std.Io.sleep(io, ..., .real) catch {}; // io pode ser inválido
    }
}
```

```zig
// ✅ Correto — receber Io de fora (vindo do listen())
fn intervalLoop(entry: IntervalEntry) void {
    while (true) {
        std.Io.sleep(entry.io, ..., .real) catch {};
        entry.callback(entry.hub);
    }
}
```

---

## 6. Io.Threaded

### init_single_threaded (testes / modo single)

```zig
// ✅ Funciona — sem allocator, sem thread pool
// src/ws/hub.zig:278 (todos os testes)
var threaded = std.Io.Threaded.init_single_threaded;
const io = threaded.io();
```

### .init(allocator, .{}) (produção, multi-thread)

```zig
// ✅ Funciona — usa thread pool
// src/core/app.zig:677
var threaded: Io.Threaded = .init(gpa, .{});
defer threaded.deinit();
const io = threaded.io();
```

### Lifetime — o Threaded deve viver enquanto o Io for usado

```zig
// ✅ Correto — Threaded vive no Server
// src/core/app.zig:515
ws_threaded: ?std.Io.Threaded = null,

pub fn ws(self: *Self, path: ..., ...) *Self {
    self.ws_threaded = std.Io.Threaded.init_single_threaded;
    self.ws_hub = Hub.init(std.heap.smp_allocator, self.ws_threaded.?.io());
    // ...
}
```

---

## 7. Tempo e timestamps

### std.Io.Clock.now (a única forma)

```zig
// ✅ Funciona — retorna Io.Timestamp (struct, não inteiro!)
// src/internal/metrics.zig:49
const now = std.Io.Clock.now(.awake, global_io);

// src/modules/auth/auth.zig:79
const now = std.Io.Clock.now(.real, io);
```

### Extrair segundos do timestamp

```zig
// ✅ Funciona — Timestamp tem .nanoseconds (i128)
// src/modules/auth/auth.zig:80
const now_sec: i64 = @intCast(@divFloor(now.nanoseconds, 1_000_000_000));
```

### Duration entre timestamps

```zig
// ✅ Funciona
// src/internal/metrics.zig:50
const uptime_ns = server_start_time.durationTo(now);
const uptime_sec = @intCast(uptime_ns.toSeconds());
```

### O que NÃO existe

```zig
// ❌ std.time.timestamp() — NÃO EXISTE no 0.16/0.17
const ts = std.time.timestamp();
```

---

## 8. Sockets para testes

### makeSocketPair

```zig
// ✅ Funciona — AF_UNIX, STREAM
// src/ws/hub.zig:265-273
fn makeSocketPair() ![2]net.Socket {
    var fds: [2]posix.fd_t = undefined;
    const rc = posix.system.socketpair(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0, &fds);
    if (rc != 0) return error.Unexpected;
    return .{
        net.Socket{ .handle = fds[0], .address = .{ .ip4 = .{ .bytes = .{0} ** 4, .port = 0 } } },
        net.Socket{ .handle = fds[1], .address = .{ .ip4 = .{ .bytes = .{0} ** 4, .port = 0 } } },
    };
}
```

```zig
// ✅ Uso em teste
// src/ws/hub.zig:288-290
const sockets = try makeSocketPair();
defer sockets[0].close(io);
defer sockets[1].close(io);
```

### shutdown vs close

```zig
// ✅ shutdown(.send) — fecha só a escrita (útil para simular cliente desconectado)
// src/ws/hub.zig:352
try (net.Stream{ .socket = sockets[0] }).shutdown(io, .send);

// ❌ close() fecha tudo de uma vez
sockets[0].close(io); // só usar no defer final
```

---

## 9. std.Io.random

```zig
// ✅ Funciona — preenche buffer com bytes aleatórios
// src/core/app.zig:410
var rand_buf: [8]u8 = undefined;
std.Io.random(ctx._io, &rand_buf);

// src/pg_driver_impl/src/t.zig:41
std.Io.random(io, std.mem.asBytes(&seed));
```

### Converter bytes aleatórios para u64

```zig
// ✅ Funciona
// src/core/app.zig:411 (e 451)
const conn_id = std.mem.readInt(u64, &rand_buf, .little);
```

---

## 10. Erro comum: `Context` vs `context`

O módulo `context.zig` exporta `Ctx`, não `Context`:

```zig
const Ctx = @import("core/context.zig").Ctx;  // ✅ correto
pub fn handler(c: *spider.Ctx) !spider.Response {  // ✅ correto
```

O nome do struct é `Ctx`, não `Context` — `@panic("...")` e logs usam o nome real.

---

## Checklist rápido — o que funciona vs não funciona

| Operação | Funciona? | API correta |
|---|---|---|
| JSON serialize | ✅ | `std.json.Stringify.valueAlloc(alloc, val, .{})` |
| JSON stream | ✅ | `std.json.Stringify.value(val, .{}, &writer.interface)` |
| Escrever no socket | ✅ | `Stream.Writer.init → writeAll + flush` |
| Ler do socket | ✅ | `Stream.Reader.init → interface.readSliceAll` |
| Dormir (dentro do Io) | ✅ | `std.Io.sleep(io, Duration, .real)` |
| Dormir (thread nativa) | ✅ | `std.Thread.sleep(ns)` |
| Timestamp | ✅ | `std.Io.Clock.now(.real, io)` |
| Bytes aleatórios | ✅ | `std.Io.random(io, &buf)` |
| Thread | ✅ | `std.Thread.spawn(.{}, fn, .{args})` |
| Socket pair teste | ✅ | `posix.system.socketpair(AF_UNIX, ...)` |
| **`std.json.stringify`** | ❌ | Não existe — use `Stringify.valueAlloc` |
| **`std.io.xxx`** | ❌ | `std.io` removido — use `std.Io` |
| **`std.io.fixedBufferStream`** | ❌ | Removido — use `valueAlloc` ou `ArrayHashMap` |
| **`std.time.sleep`** | ❌ | Removido — use `std.Io.sleep` ou `std.Thread.sleep` |
| **`std.time.timestamp()`** | ❌ | Não existe — use `std.Io.Clock.now` |
