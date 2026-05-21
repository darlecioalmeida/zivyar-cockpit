# Spider Framework — SKILL.md

Spider is a web framework for Zig `0.17.0-dev`. This skill describes the codebase, architecture, patterns, and common mistakes to avoid when working on Spider or a Spider-based application.

**Repository:** `~/repos/zig/web/spider/` (branch `new_templates`)  
**Starter kit:** `~/repos/zig/web/spider/examples/spiderstack/`  
**Zig version:** `0.17.0-dev` — always tracks Zig master before each release.

---

## Project Structure

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
src/
├── spider.zig              — public API, all re-exports
├── main.zig                — dev test server (not installed)
├── core/
│   ├── app.zig             — Server, workers, handleConnection, listen
│   ├── context.zig         — Ctx, Response, ResponseOptions, ViewsConfig
│   └── database.zig        — Database vtable, DatabaseCtx, DriverType
├── routing/
│   ├── router.zig          — Trie router with dynamic params
│   └── group.zig           — Route groups
├── render/
│   ├── template.zig        — Template engine (parser + renderer)
│   └── views.zig           — ViewsIndex, buildIndex, normalizeName
├── ws/
│   ├── websocket.zig       — WebSocket Server, Frame (RFC 6455)
│   └── hub.zig             — Broadcast hub
├── drivers/
│   ├── pg/pg.zig           — PostgreSQL (pg.zig wire protocol, no libpq)
│   ├── mysql/              — MySQL (native wire protocol)
│   └── sqlite/             — SQLite (review pending, do not use yet)
├── modules/
│   ├── auth/auth.zig       — JWT, cookies, Auth middleware
│   ├── static.zig          — Static file serving from ./public/
│   ├── livereload.zig      — Live reload WebSocket (dev only)
│   └── dashboard.zig       — Metrics dashboard
├── internal/
│   ├── config.zig          — Config struct, Env enum, fromRoot()
│   ├── env.zig             — .env loader via C getenv/setenv
│   ├── logger.zig          — Colored console logger
│   ├── metrics.zig         — Atomic metrics
│   └── buffer_pool.zig     — Buffer pool
├── binding/
│   ├── form.zig            — URL-encoded form parser
│   └── form_parser.zig     — Typed struct binding
├── providers/
│   ├── jwks.zig            — JWKS auth core (RS256 verify, JwksAuth, qualquer OIDC)
│   ├── google.zig          — Google OAuth2 (stateless)
│   ├── clerk.zig           — Clerk wrapper sobre jwks.zig
│   └── keycloak.zig        — Keycloak wrapper sobre jwks.zig
├── generate_templates.zig  — CLI: scans src/, generates embedded_templates.zig
└── build_helpers.zig       — build.zig helper module
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Architecture

### Request lifecycle

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
TCP accept → worker thread
    → conn_arena created
        → req_arena created (= c.arena)
        → headers copied to Ctx._headers BEFORE body read
        → body read into Ctx.body
        → static files checked first
        → router.match() → handler + params
        → middleware chain (threadlocal, safe with Io.Threaded)
        → handler(c) → Response
        → inject live reload script if dev + text/html
        → request.respond()
    → req_arena reset
→ keep-alive loop
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Memory hierarchy

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
page_allocator
└── smp_allocator (workers, pool, long-lived)
    └── conn_arena (per connection)
        └── req_arena = c.arena (per request — reset after each request)
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**Rule:** Always allocate in `c.arena`. Never store pointers to `c.arena` data beyond the request. Never use `page_allocator` in hot paths.

---

## Handler signature

```zig
fn myHandler(c: *spider.Ctx) !spider.Response {
    return c.json(.{ .ok = true }, .{});
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**NEVER** use the old signature `fn(alloc: std.mem.Allocator, req: *Request) !Response` — that was Spider v0.2.

---

## Ctx API

```zig
// Responses
c.json(value: anytype, opts: ResponseOptions) !Response
c.text(content: []const u8, opts: ResponseOptions) !Response
c.html(content: []const u8, opts: ResponseOptions) !Response
c.render(tmpl: []const u8, data: anytype, opts: ResponseOptions) !Response  // raw template string
c.view(name: []const u8, data: anytype, opts: ResponseOptions) !Response     // by name (embed or runtime)
c.redirect(url: []const u8) !Response

// Request reading
c.param(name: []const u8) ?[]const u8       // URL param: /users/:id
c.query(name: []const u8) ?[]const u8       // query string: ?q=value
c.header(name: []const u8) ?[]const u8      // request header (case-insensitive)
c.cookie(name: []const u8) ?[]const u8      // cookie value
c.getBody() ?[]const u8                     // raw body
c.bodyJson(comptime T: type) !T             // parse JSON body
c.parseForm(comptime T: type) !T            // parse URL-encoded form

// Cookies
c.setCookie(name, value, opts: CookieOptions) ![]const u8
c.withCookie(name, value, opts: CookieOptions) !ResponseOptions

// HTMX
c.isHtmx() bool      // HX-Request header present
c.isBoosted() bool   // HX-Boosted header present

// Database
c.db() DatabaseCtx   // requires server.db(driver) in setup

// Misc
c.arena              // per-request allocator
c.getPath() []const u8
c.getMethod() []const u8
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### ResponseOptions

```zig
pub const ResponseOptions = struct {
    status: std.http.Status = .ok,
    headers: []const [2][]const u8 = &.{},
    cookies: []const [2][]const u8 = &.{},
};
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Setting headers at runtime (arena allocation required)

```zig
// CORRECT — allocate in arena
const headers = try c.arena.alloc([2][]const u8, 1);
headers[0] = .{ "Set-Cookie", cookie_value };
return c.json(.{ .ok = true }, .{ .headers = headers });

// WRONG — stack allocation causes dangling pointer
return c.json(.{ .ok = true }, .{
    .headers = &.{.{ "Set-Cookie", cookie_value }},  // ← dangling pointer!
});
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Server API

```zig
var server = spider.app();               // reads spider.config.zig via @import("root")
defer server.deinit();

server
    .use(middlewareFn)                   // global middleware
    .useAt("/api/*", middlewareFn)       // path-scoped middleware
    .onError(errorHandlerFn)             // global error handler
    .db(driver.database())               // register database
    .get("/", homeHandler)
    .post("/users", createHandler)
    .get("/users/:id", getHandler)
    .group("/admin", &.{authMw}, registerFn)
    .listen(3000) catch {};
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Middleware signature

```zig
fn myMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    // before
    const res = try next(c);
    // after
    return res;
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Error handler signature

```zig
fn myErrorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    return c.json(.{ .error = @errorName(err) }, .{ .status = .internal_server_error });
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Route groups

```zig
fn adminRoutes(s: *spider.Server, prefix: []const u8, mws: []const spider.MiddlewareFn) void {
    s.addRoute(.GET, "/admin/users", mws, usersHandler);
    s.addRoute(.POST, "/admin/users", mws, createHandler);
}

server.group("/admin", &.{authMiddleware}, adminRoutes);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Template System

### Syntax

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
{ variable }                          — interpolation
{ object.field }                      — nested field
{ expr ?? "default" }                 — coalescing operator (use default if falsy/empty)
if (condition) { ... }                — conditional
if (condition) { ... } else { ... }   — if/else
if (cond) { ... } else if (cond2) { ... } else { ... }  — else if chaining
for (iterable) |capture| { ... }      — loop (capture is the loop variable)
<ComponentName prop="{ value }" />    — component (uppercase first letter)
<ComponentName>slot content</ComponentName>  — component with slot
{ slot }                              — slot placeholder in component template
{ slot_header }                       — named slot
extends "layout"                      — layout inheritance (FIRST LINE of template)
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Condition syntax
Conditions support comparison operators and truthy/falsy evaluation:
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
if (x == "foo") { ... }              — equality
if (x != "bar") { ... }              — inequality
if (x > 10) { ... }                 — greater than
if (x >= 10) { ... }                — greater or equal
if (x < 10) { ... }                 — less than
if (x <= 10) { ... }                — less or equal
if (user) { ... }                    — truthy check (non-empty string, true boolean)
if (items.len > 0) { ... }          — .len on lists
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

Quoted strings as body content (e.g., `if (x) { "my-class" } else { "other" }`) are emitted as plain text without quotes.

`<script>` blocks are skipped entirely — no template syntax is processed inside them.

### Template modes

**Embed mode** — compiled into binary. Dev declares in `main.zig`:

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

Spider detects via `@hasDecl(@import("root"), "spider_templates")` — zero build config needed.

**Runtime mode** — reads from disk. Zero config — just don't declare `spider_templates`.

`generate_templates.zig` scans `src/` recursively for `.html`/`.md` and generates `embedded_templates.zig`. Run automatically on `zig build`.

### Name normalization

`features/auth/views/login.html` → `auth_login`  
`shared/templates/layout.html` → `layout`  
`shared/templates/partials/topbar.html` → `partials_topbar`  
`shared/templates/site-nav.html` → `site_nav` (hyphens `-` replaced with `_`)

Rules: strip extension, use segment after `views/` or `templates/`, replace `/` and `-` with `_`.

### Component lookup (PascalCase → snake_case)
When using a component in a template with PascalCase (e.g., `<SiteNav />`), the template engine:
1. First tries direct lookup of `SiteNav` in the components map
2. If not found, converts PascalCase to snake_case (`SiteNav` → `site_nav`) and retries
3. This allows `<SiteNav />` to match `site_nav` (from `site-nav.html`)

Example: `shared/templates/site-nav.html` normalizes to `site_nav` (field name in `EmbeddedTemplates`). Using `<SiteNav />` in any template resolves to this component.

### Layout per Route
Spider supports multiple layouts for different routes. Each layout is a template that uses `{ slot }` for content injection.

1. **Create a custom layout**: Place it in `shared/templates/` (or any `templates/` directory). Example: `shared/templates/layout_docs.html` → normalizes to `layout_docs`.
2. **Use `extends` in templates**: First line of a template must be `extends "layout_name"` to use a custom layout. Example for docs pages:
   ```html
   extends "layout_docs"
   <h1>Docs Page</h1>
   ```
3. **Layout with components**: Include components like `<SiteNav />` directly in the layout template (no need to pass via context).

Example structure:
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
src/
├── shared/templates/
│   ├── layout.html          → layout (default)
│   ├── layout_docs.html     → layout_docs (docs-specific)
│   └── site-nav.html        → site_nav (component)
└── features/docs/views/
    └── quickstart.html      → starts with `extends "layout_docs"`
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### c.view() example

```zig
// handler
fn usersHandler(c: *spider.Ctx) !spider.Response {
    const users = try spider.pg.query(User, c.arena, "SELECT name, email FROM users", .{});
    return c.view("users/index", .{ .users = users }, .{});
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
// views/users/index.html
extends "layout"
<h1>Users</h1>
for (users) |user| {
    <li>{ user.name } — { user.email }</li>
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
// views/layout.html
<html>
<body>
{ slot }
</body>
</html>
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Template Engine Internals (Maintenance Reference)

#### Core Data Structures
- `Value` union: Represents dynamic values from render context. Variants: `string`, `boolean`, `list` (of Values), `object` (StringHashMapUnmanaged of Values).
- `Node` union enum (AST nodes):
  - `text`: Literal text
  - `interpolation`: `{ expr }`
  - `interpolation_with_default`: `{ expr ?? "default" }`
  - `if_node`: `{ condition, then_body, else_body }` (else_body may contain nested if_node for else if chains)
  - `for_node`: `{ iterable, capture, body }`
  - `component`: `{ name, props, self_closing, slot_content }`
  - `slot`: Placeholder for slot content

#### Parser (`Parser` struct)
Key methods:
| Method | Purpose |
|--------|---------|
| `parse()` | Top-level parse: detects `extends`, then processes tokens sequentially |
| `parseIf()` | Handles `if`/`else`/`else if` (else if is nested as an `if_node` inside `else_body`) |
| `parseFor()` | Parses `for (iterable) |capture| { ... }` |
| `parseInterpolation()` | Handles `{ expr }` and `{ expr ?? "default" }` |
| `parseComponent()` | Parses PascalCase components |
| `parseText()` | Literal text, **skips `<script>` blocks entirely** |
| `parseTextNodes()` | Recursive parse for bodies of `if`/`for` blocks |

#### Renderer (`renderNode`)
Routes AST nodes to rendering logic:
- `if_node`: Evaluates condition via `evalBool()`, renders `then_body` or `else_body` (supports nested else if)
- `for_node`: Iterates over list values, creates per-item context with capture variable
- `component`: Looks up component template, falls back to snake_case name (e.g., `MyComponent` → `my_component`), merges props/slot into context

#### Value Resolution
- `resolveValue(ctx, expr)`: Handles dot notation (`obj.field`) by first resolving the parent object, then looking up the field
- `evalBool(expr)`: Evaluates conditions, supports comparison operators (`==`, `!=`, `<`, `<=`, `>`, `>=`) and `.len` on lists

#### Memory Management
- Render context uses `c.arena` (per-request allocator) for all allocations
- `freeNode()` / `freeValue()` handle recursive deallocation of AST and context values
- Component slot content and props are duplicated into the component's render context

#### Known Issues for Maintenance
1. **`else if` nesting**: Represented as `else_body` containing a single-element `[]Node` with an `if_node`. This works but is non-obvious for new maintainers.
2. **Recursive `parseTextNodes()`**: Deeply nested `else if` chains may hit stack limits in extreme cases (uses full recursion instead of iteration).
3. **`<script>` block skipping**: Only skips top-level `<script>` tags; does not handle malformed HTML or nested `<script>` tags.
4. **`resolveLen()` uses `page_allocator`**: Temporary values in condition evaluation use `std.heap.page_allocator` instead of the per-request arena, which is non-ideal for hot paths.

---

## Database

### PostgreSQL (recommended)

**Two ways to configure:**

1. **Pass data directly** to `spider.pg.init()`:
```zig
try spider.pg.init(allocator, io, .{
    .host = "localhost",
    .port = 5432,
    .user = "spider",
    .password = "spider",
    .database = "myapp",
    .pool_size = 10,
});
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

2. **No config needed** — Spider auto-reads from `.env` files (`.env` → `.env.{SPIDER_ENV}` → `.env.local`):
```zig
try spider.pg.init(allocator, io, .{}); // reads PG_HOST, PG_PORT, PG_USER, PG_PASSWORD, PG_DB automatically
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```zig
// Register database driver (needed for c.db())
server.db(spider.pg.PgDriver.database());

defer spider.pg.deinit();
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**Query patterns:**

```zig
// Via spider.pg (direct module usage)
const users = try spider.pg.query(User, c.arena, "SELECT id, name FROM users", .{});
const user = try spider.pg.queryOne(User, c.arena, "SELECT id, name FROM users WHERE id = $1", .{id});
try spider.pg.exec("DELETE FROM users WHERE id = $1", .{id});

// Via c.db() (preferred — requires server.db() registration)
const users = try c.db().query(User, "SELECT id, name FROM users", .{});
try c.db().exec("DELETE FROM users WHERE id = $1", .{id});
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**Note:** COUNT(*) returns BIGINT (OID 20) — use `i64`, not `i32`.

### MySQL

```zig
try spider.mysql.init(allocator, io, .{
    .host = "127.0.0.1",
    .port = 3306,
    .database = "myapp",
    .user = "root",
    .password = "",
    .pool_size = 25,
});
defer spider.mysql.deinit();
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Database vtable

```zig
pub const Database = struct {
    ptr: *anyopaque,
    exec_fn: *const fn(*anyopaque, []const u8) anyerror!void,
    deinit_fn: *const fn(*anyopaque) void,
    driver_type: DriverType,
};
pub const DriverType = enum { postgresql, mysql };

// DatabaseCtx.query() dispatches by driver_type — no vtable needed for comptime T
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Auth

```zig
// JWT sign
const token = try spider.auth.jwtSign(c.arena, .{
    .sub = user.id,        // i32 or []const u8
    .email = user.email,
    .name = user.name,
    .exp = now + 86400,    // i64
}, secret);

// JWT verify
const Claims = struct { sub: i32, email: []const u8, name: []const u8, exp: i64 };
const claims = try spider.auth.jwtVerify(Claims, c.arena, token, secret);

// Cookies
const cookie = try spider.auth.cookieSet(c.arena, token);
const cleared = try spider.auth.cookieClear(c.arena);

// Auth middleware
var gAuth = spider.auth.Auth.init(.{
    .secret = spider.env.getOr("JWT_SECRET", "changeme"),
    .public_paths = &.{ "/login", "/auth/*" },
    .redirect_to = "/login",
    .secure_cookie = false,  // true in production
});
server.group("/dashboard", &.{gAuth.asFn()}, dashRoutes);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

Auth middleware injects into `c.params`:
- `_user_id` — JWT `sub` field as string
- `_user_email` — JWT `email` field
- `_user_name` — JWT `name` field

---

## Environment

```zig
// .env loaded automatically by spider.app() in order:
// 1. .env (base)
// 2. .env.{SPIDER_ENV} (development/production/test)
// 3. .env.local (highest priority)

spider.env.get("KEY")                     // ?[]const u8
spider.env.getOr("KEY", "default")        // []const u8
spider.env.getInt(u16, "PORT", 3000)      // T
spider.env.getBool("DEBUG", false)        // bool
spider.env.load(allocator, ".env.test")   // manual load
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## WebSocket — Hub, Broadcast, and Pub/Sub

This section covers the complete WebSocket implementation in Spider: the `Hub` (connection manager), the `websocket.Server` (RFC 6455 protocol), state injection via `spider.app()`, and the correct usage patterns in features.

---

### General Architecture

```
browser ──── ws handshake ────► handler(c, hub) ──► hub.add(conn)
                                                         │
broadcastLoop (thread) ──► hub.broadcast(html) ─────────┘
                        or hub.broadcastToChannel(room, msg)
```

The `Hub` lives in `main.zig`, is injected into handlers via `spider.app(.{ .hub = &hub })`, and the broadcast thread runs in parallel with the server.

---

### Hub (`src/ws/hub.zig`)

#### Struct and Connection

```zig
pub const Hub = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    mutex: std.Io.Mutex,
    connections: std.ArrayListUnmanaged(Connection) = .empty,

    pub const Connection = struct {
        id: u64,
        stream: net.Stream,
        channel: []const u8 = "",  // "" = no channel (global broadcast)
    };
};
```

#### Full API

```zig
// Initialization
var hub = Hub.init(allocator, io);
defer hub.deinit();

// Connection management
try hub.add(.{ .id = conn_id, .stream = c._stream });                       // error.DuplicateId
try hub.add(.{ .id = conn_id, .stream = c._stream, .channel = "room" });    // pub/sub
hub.remove(conn_id);   // safe if id does not exist
hub.count()            // usize — acquires mutex internally

// Sending
hub.broadcast(message);                   // sends to ALL clients
hub.broadcastToChannel(channel, message); // sends only to matching channel
```

#### Guaranteed Behaviors

- `add` rejects duplicate ids with `error.DuplicateId` — generate unique IDs with `std.Io.random`
- `broadcast` and `broadcastToChannel` take a **snapshot** before iterating — never hold the mutex during I/O
- Dead connections (send failure) are **automatically removed** after broadcast
- `channel = ""` means no channel — `broadcast` sends to everyone, `broadcastToChannel` filters by string equality

#### Internal Pattern: Snapshot + Dead List

```zig
// broadcast takes snapshot with mutex, releases mutex, sends without mutex
self.mutex.lock(self.io) catch return;
var snapshot: std.ArrayListUnmanaged(Connection) = .empty;
for (self.connections.items) |conn| { snapshot.append(...) catch {}; }
self.mutex.unlock(self.io);  // ← release before iterating

// collect dead connections, remove later with mutex re-acquired
var dead: std.ArrayListUnmanaged(u64) = .empty;
for (snapshot.items) |conn| {
    self.sendText(conn.stream, message) catch {
        dead.append(self.allocator, conn.id) catch {};
    };
}
// re-acquire mutex only for removal
```

---

### WebSocket Server (`src/ws/websocket.zig`)

#### Initialization and Usage

```zig
var server = spider.websocket.Server.init(c._stream, c._io, c.arena);

// Handshake — always check the return value
if (!try server.handshake(c.arena, &c._headers)) {
    return c.text("", .{});
}

// Read loop — readFrame blocks until data arrives
while (true) {
    const frame = server.readFrame(c.arena) catch break;
    const f = frame orelse break;  // null = client disconnected
    if (f.opcode != .text) continue;
    // f.payload contains the message bytes
}

// Sending
try server.sendText("message");
try server.writeFrame(.text, payload);
try server.sendClose(1000);
```

#### Frame

```zig
pub const Frame = struct {
    fin: bool,
    opcode: Opcode,
    masked: bool,
    payload: []const u8,

    pub const Opcode = enum(u4) {
        continuation = 0x0,
        text = 0x1,
        binary = 0x2,
        close = 0x8,
        ping = 0x9,
        pong = 0xA,
    };
};
```

Ping/pong and close are handled automatically by `readFrame` — they never reach the handler.

#### CRITICAL: Reader Must Be Reused

`net.Stream.Reader` maintains internal buffer state (`seek`, `end`). Creating a new reader on every call discards data already read from the socket that remains in the internal buffer — causing **eternal blocking** on the next `readAll`.

```zig
// WRONG — new reader per call, discards buffered data
fn readAll(self: *Server, buf: []u8) !void {
    var sr = net.Stream.Reader.init(self.stream, self.io, &self._read_buf);
    try sr.interface.readSliceAll(buf); // ← previous data lost
}

// CORRECT — reader as a field, initialized once
_reader: ?net.Stream.Reader = null,

fn readAll(self: *Server, buf: []u8) !void {
    if (self._reader == null) {
        self._reader = net.Stream.Reader.init(self.stream, self.io, &self._read_buf);
    }
    try self._reader.?.interface.readSliceAll(buf);
}
```

**General rule:** any `Reader` or `Writer` over a stream in Zig 0.17 must be created **once** and reused for the entire connection.

**Bug symptom:** handshake succeeds (101), `readyState=1` in the browser, but `readFrame` blocks forever even after the client sends data. The cause is always a recreated reader.

---

### State Injection: `spider.app(.{ ... })`

#### The Problem Without Injection

The router only accepts `fn(*Ctx) !Response`. To pass shared state (Hub, custom DB, etc.) without global variables, Spider uses a generic `Server(T)`.

#### API

```zig
// Without state — same as always, zero breaking change
var server = spider.app();
server.get("/", home.index);
pub fn handler(c: *spider.Ctx) !spider.Response { ... }

// With one state
var hub = Hub.init(allocator, io);
var server = spider.app(.{ .hub = &hub });
server.get("/system/ws", system.ws.handler);
pub fn handler(c: *spider.Ctx, hub: *Hub) !spider.Response { ... }

// With multiple states
var server = spider.app(.{ .hub = &hub, .cache = &cache });
pub fn handler(c: *spider.Ctx, hub: *Hub, cache: *Cache) !spider.Response { ... }
```

#### How It Works Internally

`app(.{ .hub = &hub })` returns `Server(@TypeOf(.{ .hub = &hub }))`. The decoration type is known at **comptime**. `get()` calls `buildWrapper(handler, T)` which:

1. Inspects the handler's params via `@typeInfo`
2. For each extra param (after `*Ctx`), finds the matching field in `T` with `findFieldName` by type
3. Generates a wrapper `fn(*Ctx) !Response` that extracts fields via `@field(decos, name)`
4. Registers the wrapper in the router — `runChain` and middleware never see the original signature

```zig
// buildWrapper — generated at comptime by get()/post()
const W = struct {
    pub fn call(ctx: *Ctx) anyerror!Response {
        const decos: *const T = @ptrCast(@alignCast(ctx._decorations.?));
        const f0 = comptime findFieldName(T, extra[0].type.?);
        return handler(ctx, @field(decos, f0));  // zero overhead, no manual cast
    }
};
```

#### Comptime Error If Type Was Not Decorated

```zig
// If handler requests *Cache but app() does not have .cache = &cache:
// comptime error — never at runtime
// "handler requires type `*Cache` which was not provided to spider.app()"
```

#### Limitations

- Match is **by type**, not by name — `@typeInfo().@"fn".params[i].name` does not exist in Zig 0.17
- Two fields of the same type in the same struct cause ambiguity — use an intermediate struct
- Supports up to 4 extra params (beyond `*Ctx`) — sufficient for any real case
- `spider.pg` (framework DB) remains global — no injection needed

---

### Full Pattern: System Monitor (broadcast)

**`src/main.zig`** — clean orchestration, no globals:

```zig
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var hub = Hub.init(allocator, io);
    defer hub.deinit();

    // Broadcast thread — feature responsibility, not main's
    const t = try std.Thread.spawn(.{}, system.ws.broadcastLoop, .{ &hub, io, allocator });
    t.detach();

    var server = spider.app(.{ .hub = &hub });
    defer server.deinit();

    server
        .get("/system/ws", system.ws.handler)
        .listen(.{ .port = 3000, .host = "0.0.0.0" }) catch |err| return err;
}
```

**`src/features/system/ws.zig`** — handler and broadcastLoop in the same feature:

```zig
pub fn handler(c: *spider.Ctx, hub: *Hub) !spider.Response {
    var server = spider.websocket.Server.init(c._stream, c._io, c.arena);
    if (!try server.handshake(c.arena, &c._headers)) return c.text("", .{});

    var rand_buf: [8]u8 = undefined;
    std.Io.random(c._io, &rand_buf);
    const conn_id = std.mem.readInt(u64, &rand_buf, .little);

    try hub.add(.{ .id = conn_id, .stream = c._stream });
    defer hub.remove(conn_id);

    // Keep connection alive — broadcastLoop sends data
    while (true) {
        const frame = server.readFrame(c.arena) catch break;
        if (frame == null) break;
    }
    return c.text("", .{});
}

pub fn broadcastLoop(hub: *Hub, io: std.Io, allocator: std.mem.Allocator) void {
    while (true) {
        std.Io.sleep(io, std.Io.Duration.fromMilliseconds(3000), .real) catch {};
        const info = system_info.read(io, allocator) catch continue;
        const html = formatOobHtml(&info, allocator) catch continue;
        hub.broadcast(html);
    }
}
```

**Rule:** `broadcastLoop` lives in the feature (`system/ws.zig`), not in `main.zig`. `main` only spawns the thread.

---

### Full Pattern: Chat (pub/sub by channel)

**`src/features/chat/ws.zig`**:

```zig
pub fn handler(c: *spider.Ctx, hub: *Hub) !spider.Response {
    const room = c.params.get("room") orelse
        return c.text("room required", .{ .status = .bad_request });

    var server = spider.websocket.Server.init(c._stream, c._io, c.arena);
    if (!try server.handshake(c.arena, &c._headers)) return c.text("", .{});

    var rand_buf: [8]u8 = undefined;
    std.Io.random(c._io, &rand_buf);
    const conn_id = std.mem.readInt(u64, &rand_buf, .little);

    try hub.add(.{ .id = conn_id, .stream = c._stream, .channel = room });
    defer hub.remove(conn_id);

    while (true) {
        const frame = server.readFrame(c.arena) catch break;
        const f = frame orelse break;
        if (f.opcode != .text) continue;

        const msg = try std.fmt.allocPrint(c.arena,
            \\<p>[{s}] {s}</p>
        , .{ room, f.payload });

        hub.broadcastToChannel(room, msg);
    }
    return c.text("", .{});
}
```

**Route in `main.zig`:**

```zig
.get("/chat/:room/ws", features.chat.ws.handler)
```

**Broadcast vs Pub/Sub:**

| | `hub.broadcast(msg)` | `hub.broadcastToChannel(room, msg)` |
|---|---|---|
| Recipients | All clients | Only clients with `channel == room` |
| Use case | Dashboard, metrics | Per-room chat, per-user notifications |
| `channel` in `add` | Not important | Required |

---

### HTMX OOB with WebSocket

To update specific page elements without reloading, use `hx-swap-oob` on elements sent by the server. The target must be `<tbody>`, not `<div>`, for valid table HTML:

```zig
// CORRECT — <tbody> as OOB root
\\<tbody hx-swap-oob="innerHTML:#memory-card-body">
\\    <tr><td>Total</td><td>{} MB</td></tr>
\\</tbody>

// WRONG — <div> cannot contain <tr> directly
\\<div hx-swap-oob="innerHTML:#memory-card-body">
\\    <tr>...</tr>
\\</div>
```

On the frontend, process OOB messages from WebSocket:

```javascript
const ws = new WebSocket('ws://' + location.host + '/system/ws');
ws.onmessage = function(e) {
    htmx.swap(document.body, e.data, { swapStyle: 'none' });
};
ws.onclose = function() {
    setTimeout(function() { location.reload(); }, 3000);
};
```

---

### Hub Tests in Zig 0.17

#### makeSocketPair — Real Sockets Without a Network

```zig
// Socket.createPair does NOT work — Family only has .ip4/.ip6
// Use posix.system.socketpair with AF_UNIX directly
fn makeSocketPair() ![2]net.Socket {
    var fds: [2]posix.fd_t = undefined;
    const rc = posix.system.socketpair(
        posix.AF.UNIX,
        posix.SOCK.STREAM | posix.SOCK.CLOEXEC,
        0,
        &fds,
    );
    if (rc != 0) return error.Unexpected;
    return .{
        net.Socket{ .handle = fds[0], .address = .{ .ip4 = .{ .bytes = .{0} ** 4, .port = 0 } } },
        net.Socket{ .handle = fds[1], .address = .{ .ip4 = .{ .bytes = .{0} ** 4, .port = 0 } } },
    };
}
// Note: address filled as ip4 even though AF_UNIX — works because
// the address is not used on already-connected sockets
```

#### Standard Test Setup

```zig
var threaded = std.Io.Threaded.init_single_threaded;
const io = threaded.io();
const sockets = try makeSocketPair();
defer sockets[0].close(io);
defer sockets[1].close(io);
var hub = Hub.init(testing.allocator, io);
defer hub.deinit();
```

#### Simulating a Dead Connection

```zig
// shutdown(.send) instead of close() — avoids EBADF panic in Threaded
try (net.Stream{ .socket = sockets[0] }).shutdown(io, .send);
hub.broadcast("any");
try testing.expectEqual(@as(usize, 0), hub.count()); // automatically removed
```

#### Verifying Received WS Frame

```zig
// Text frame: byte[0] = 0x81 (FIN + opcode text), byte[1] = length
var buf: [64]u8 = undefined;
var read_buf: [256]u8 = undefined;
var reader = net.Stream.Reader.init(.{ .socket = sockets[1] }, io, &read_buf);
try reader.interface.readSliceAll(buf[0..2]);
try testing.expectEqual(@as(u8, 0x81), buf[0]);
try testing.expectEqual(@as(u8, msg.len), buf[1]);
try reader.interface.readSliceAll(buf[0..msg.len]);
try testing.expectEqualStrings(msg, buf[0..msg.len]);
```

#### Test Coverage (11 tests)

| # | Test | What it covers |
|---|---|---|
| 1 | init and deinit | lifecycle, count = 0 |
| 2 | add increases count | add() works |
| 3 | remove decreases count | remove() works |
| 4 | remove nonexistent id does not crash | safe remove |
| 5 | broadcast writes valid WS frame | correct protocol |
| 6 | broadcast removes dead connection | automatic cleanup |
| 7 | broadcast delivers to all connections | everyone receives |
| 8 | add duplicate id returns error | DuplicateId |
| 9 | broadcastToChannel delivers only to matching channel | correct pub/sub |
| 10 | broadcast still delivers to all regardless of channel | broadcast ignores channel |
| 11 | broadcastToChannel removes dead connection | cleanup on channel |

---

### Connection ID Generation

Always use `std.Io.random` — do not use `std.crypto.random.int` which may not be available in all contexts:

```zig
var rand_buf: [8]u8 = undefined;
std.Io.random(c._io, &rand_buf);
const conn_id = std.mem.readInt(u64, &rand_buf, .little);
```

---

### Checklist When Implementing WebSocket in Spider

- [ ] Handler uses `c.params.get("param")` (not `c.param("param")`) for route params
- [ ] `server.handshake` checked with `if (!try ...)` — return early on failure
- [ ] `hub.add` called after handshake, `defer hub.remove` immediately after
- [ ] Read loop uses `catch break` and `orelse break` to exit cleanly
- [ ] `broadcastLoop` lives in the feature (`ws.zig`), not in `main.zig`
- [ ] Thread spawned with `.detach()` so it doesn't block main
- [ ] OOB uses `<tbody>` as root, not `<div>`, when the target is `<tbody>`
- [ ] Frontend uses `htmx.swap(document.body, e.data, { swapStyle: 'none' })` for OOB
- [ ] `net.Stream.Reader` created once and reused — never recreated per call

---

## Configuration

Spider reads configuration from `spider.config.zig` in the project root. This file is automatically detected and imported as anonymous module `"spider_config"` into the `spider` module.

### spider.config.zig structure

```zig
const spider = @import("spider");

pub const config = spider.Config{
    .port = 3000,
    .host = "127.0.0.1",
    .views_dir = "./views",
    .layout = "layout",
    .static_dir = "./public",
    .env = .development,
    .workers = null,  // auto = CPU count
};
```

### Issue: `spider.config.zig` cannot import `spider`

When `spider.config.zig` uses `const spider = @import("spider");`, it may fail with:

```
spider.config.zig:1:24: error: no module named 'spider' available within module 'spider_config'
const spider = @import("spider");
```

**Root cause:** The `spider` module is not automatically visible inside the `spider_config` module. The project's `build.zig` must explicitly pass the `spider` module as an import to the config module.

### Solution: Properly register in `build.zig`

In your project's `build.zig`, when registering `spider.config.zig` as an anonymous import, include the `.imports` field:

```zig
const spider_dep = b.dependency("spider", .{ .target = target });
const spider_mod = spider_dep.module("spider");

// Override Spider's default config with project's own
const config_exists = blk: {
    std.Io.Dir.cwd().access(b.graph.io, "spider.config.zig", .{}) catch break :blk false;
    break :blk true;
};
if (config_exists) {
    spider_mod.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });
}
```

This makes the `spider` module available inside `spider.config.zig`, allowing `@import("spider")` to succeed.

### How Spider reads config

Spider's internal `config.zig` uses:

```zig
pub fn fromRoot() Config {
    return @import("spider_config").config;
}
```

The anonymous import `spider_config` points to the project's `spider.config.zig` file (or the default fallback from Spider's own config).

### Environment Variables (.env)

Spider automatically loads environment variables from `.env` files. For database configuration, create a `.env` file:

```
PG_HOST=localhost
PG_PORT=5432
PG_USER=spider
PG_PASSWORD=spider
PG_DB=myapp
```

**Important:** The CLI creates `.env.example` automatically, but does NOT create `.env`. You must manually copy it:
```bash
cp .env.example .env
```

This is read by `spider.pg.init()` when using the no-config method.

---

## Zig 0.17 Patterns — CRITICAL

These are the most common mistakes. Always use exactly these patterns.

### JSON stringify

```zig
// CORRECT
const body = try std.json.Stringify.valueAlloc(arena, value, .{});

// WRONG — does not exist in 0.17
const body = try std.json.stringify(value, .{}, writer);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Timestamp

```zig
// CORRECT
var ts: std.os.linux.timespec = undefined;
_ = std.os.linux.clock_gettime(.REALTIME, &ts);
const now: i64 = ts.sec;

// WRONG — removed in 0.16
const now = std.time.timestamp();
const now = std.time.nanoTimestamp();
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Random

```zig
// CORRECT
var prng = std.Random.DefaultPrng.init(@intCast(std.Thread.getCurrentId()));
const rand = prng.random();
const id = rand.intRangeAtMost(u32, 1, 10000);

// WRONG — removed in 0.16
std.crypto.random.int(u32)
std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()))
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### File read

```zig
// CORRECT
var threaded = std.Io.Threaded.init_single_threaded;
const io = threaded.io();
const content = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(512 * 1024));

// WRONG — old API
const content = try std.fs.cwd().readFileAlloc(allocator, path, 512 * 1024);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Stream I/O

```zig
// CORRECT — Zig 0.17 Stream Reader/Writer
var read_buf: [65536]u8 = undefined;
var write_buf: [4096]u8 = undefined;
var sr = std.Io.net.Stream.Reader.init(stream, io, &read_buf);
var sw = std.Io.net.Stream.Writer.init(stream, io, &write_buf);
const reader = &sr.interface;
const writer = &sw.interface;

try reader.readSliceAll(buf);         // read exact N bytes
const byte = try reader.takeByte();   // read 1 byte
const val = try reader.takeInt(u32, .little);  // read int
try writer.writeAll(data);
try writer.flush();

// Fixed buffer reader (for parsing byte slices)
var fbs = std.Io.Reader.fixed(payload);
const b = try fbs.takeByte();

// WRONG — old API
reader.readByte()
reader.readNoEof(buf)
reader.readInt(u32, .little)
std.io.fixedBufferStream(buf)
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### HMAC SHA256

```zig
// CORRECT
std.crypto.auth.hmac.sha2.HmacSha256.create(&out, input, secret);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### SHA1 (WebSocket)

```zig
var sha1 = std.crypto.hash.Sha1.init(.{});
sha1.update(data);
var digest: [20]u8 = undefined;
sha1.final(&digest);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Base64

```zig
// URL-safe no-pad (JWT)
const encoded = std.base64.url_safe_no_pad.Encoder.encode(buf, data);
const len = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(input) catch return error.Invalid;
try std.base64.url_safe_no_pad.Decoder.decode(&buf, input);

// Standard (WebSocket handshake)
const encoded = std.base64.standard.Encoder.encode(buf, data);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### ArrayList

```zig
// CORRECT — ArrayListUnmanaged (preferred in Spider)
var list: std.ArrayListUnmanaged(T) = .empty;
defer list.deinit(allocator);
try list.append(allocator, item);
try list.appendSlice(allocator, slice);
return try list.toOwnedSlice(allocator);

// CORRECT — ArrayList (when allocator is stored)
var list = std.ArrayList(T).init(allocator);
defer list.deinit();
try list.append(item);

// WRONG — common mistake
var list = std.ArrayList(T){};          // missing allocator
var list: std.ArrayList(T) = .empty;    // .empty exists but .init() is preferred
list.append(item)                       // missing allocator for Unmanaged
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Environment variables

```zig
// CORRECT — use Spider's env.zig which wraps C getenv/setenv
spider.env.getOr("KEY", "default")
spider.env.get("KEY")

// WRONG — removed from std in 0.16/0.17
std.posix.getenv("KEY")
std.process.getEnvVarOwned(allocator, "KEY")
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### ColumnFlags (MySQL protocol)

```zig
// CORRECT — exactly 14 fields + 2 padding bits = u16
pub const ColumnFlags = packed struct(u16) {
    NOT_NULL: bool = false,
    // ... 13 more bool fields
    _padding: u2 = 0,
};
// WRONG — more than 16 bits total causes silent corruption
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Build System

### build.zig dependencies

```zig
const pacman_dep = b.dependency("pacman", .{});   // HTTP client
const pg_dep = b.dependency("pg", .{ .target = target, .optimize = optimize });  // PG wire protocol
const tc_env = b.addTranslateC(.{ .root_source_file = b.path("includes/env.h") });  // C getenv

const mod = b.addModule("spider", .{
    .root_source_file = b.path("src/spider.zig"),
    .link_libc = true,  // required for C getenv/setenv
    .imports = &.{
        .{ .name = "pacman", .module = pacman_dep.module("pacman") },
        .{ .name = "c_env", .module = c_env },
        .{ .name = "pg", .module = pg_dep.module("pg") },
    },
});
// NO libpq — uses native wire protocol via pg.zig
// NO libsqlite3 currently active
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### SpiderStack build.zig

```zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");
gen.addArg("src/embedded_templates.zig");
exe.step.dependOn(&gen.step);

// optional — register spider.config.zig
if (b.pathExists("spider.config.zig")) {
    exe.root_module.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
    });
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Commands

```bash
zig build                              # build
zig build run                          # run dev server
zig build test                         # run tests
zig build run -Doptimize=ReleaseFast   # production build

# development with live reload
watchexec -r -e zig,html,css -- zig build run

# incremental watch (no C FFI — pure Zig projects only)
zig build run -fincremental --watch
# NOTE: -fincremental fails with C FFI (libpq, libsqlite3, libc translate-c)
# Spider uses c_env (translate-c) so -fincremental may fail
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Key Design Decisions

**`threadlocal` for middleware chain** — safe with `Io.Threaded` (blocking OS threads). If migrating to `Io.Evented`, move chain state to `Ctx._chain`.

**`smp_allocator` for workers** — `DebugAllocator` has internal state that causes dangling pointers when the Server struct is copied. `smp_allocator` is stateless.

**Headers copied before body read** — `request.iterateHeaders()` fails after body is read. All headers are copied to `Ctx._headers` map in `handleConnection()` before any body reading.

**`@import("root")` + `@hasDecl` for embed detection** — same pattern as `std_options` in Zig stdlib. Proven in `seven/` POC that embed and runtime produce byte-identical results.

**`comptime T` in database query** — vtable cannot hold `comptime T` functions. `DatabaseCtx.query()` dispatches by `driver_type` enum at runtime, calls driver directly via `@ptrCast`.

**No libpq** — PostgreSQL uses `pg.zig` (karlseguin) native wire protocol. Enables `-fincremental` (when no other C FFI present).

---

## Static Files

`./public/` served automatically at `/` — no configuration needed.

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
public/css/app.css    → GET /css/app.css
public/logo.png       → GET /logo.png
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

Path traversal (`../../etc/passwd`) blocked automatically. URL-encoded traversal (`%2e%2e`) blocked by Zig HTTP stack before reaching Spider.

---

## Live Reload (dev only)

Injected automatically when `config.env == .development`:
- `/_spider/reload` WebSocket endpoint registered
- Script injected before `</body>` in all HTML responses
- Browser reconnects after server restart → `location.reload()`

```bash
watchexec -r -e zig,html,css -- zig build run
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Google OAuth

```zig
const config = spider.google.GoogleConfig{
    .client_id     = spider.env.getOr("GOOGLE_CLIENT_ID", ""),
    .client_secret = spider.env.getOr("GOOGLE_CLIENT_SECRET", ""),
    .redirect_uri  = spider.env.getOr("GOOGLE_REDIRECT_URI", ""),
};

fn loginHandler(c: *spider.Ctx) !spider.Response {
    const url = try spider.google.authUrl(c.arena, config);
    return c.redirect(url);
}

fn callbackHandler(c: *spider.Ctx) !spider.Response {
    const code = c.query("code") orelse return c.redirect("/login");
    const profile = try spider.google.fetchProfile(c, code, config);
    // profile.id, profile.email, profile.name, profile.picture
    // allocated in c.arena — freed automatically
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Auth — JWKS / OIDC Providers

Spider tem suporte nativo a qualquer provider OIDC via RS256 + JWKS.
Três níveis de API:

### 1. Genérico — `spider.jwks` (qualquer OIDC)

```zig
var auth = try spider.jwks.JwksAuth.init(allocator, io, .{
    .jwks_url = "https://provider/.well-known/jwks.json",
    .issuer = "https://provider",
});
server.use(auth.middleware());
```

### 2. Clerk (hosted, closed source)

```zig
var auth = try spider.clerk.Clerk.init(allocator, io, .{
    .publishable_key = "pk_test_...",
    .secret_key = "sk_test_...",
});
server.use(auth.middleware());
server.get("/auth/callback", auth.callbackHandler());
```

### 3. Keycloak (open source, self-hosted)

```zig
var auth = try spider.keycloak.Keycloak.init(allocator, io, .{
    .base_url = "https://keycloak.empresa.com",
    .realm = "myrealm",
    .client_id = "spider-app",
    .client_secret = "...",
});
server.use(auth.middleware());
server.get("/auth/callback", auth.callbackHandler());
```

### Claims injetados em `c.params`

| Chave | Origem | Provider |
|-------|--------|----------|
| `_auth_sub` | `sub` claim | Todos |
| `_auth_email` | `email` claim | Todos |
| `_auth_name` | `name` claim | Todos |
| `_auth_iss` | `iss` claim | Todos |

### Como funciona internamente

1. **Boot**: GET `jwks_url` → cache de `PublicKey` por `kid`
2. **Middleware**: verifica RS256 com `std.crypto` (zero deps externas)
3. **JWKS refresh**: lazy — refetch quando `kid` não encontrado no cache
4. **Callback**: troca `code` por token, define cookie `__session`

### Template source files

| File | Purpose |
|------|---------|
| `src/providers/jwks.zig` | Core genérico: JwksConfig, JwksAuth, Claims, JWKS cache, RS256 verify, middleware |
| `src/providers/clerk.zig` | Wrapper Clerk: parseIssuerUrl, callbackHandler, authUrl |
| `src/providers/keycloak.zig` | Wrapper Keycloak: callbackHandler, authUrl |
| `src/spider.zig` | `pub const jwks`, `pub const clerk`, `pub const keycloak` |

---

## Real-World Patterns (from SpiderStack example)

### Project Structure (Feature-based)
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
src/
├── main.zig                    — server setup, route registration
├── root.zig                     — exports (spider_templates for embed mode)
├── embedded_templates.zig      — auto-generated
├── core/
│   ├── config/mod.zig         — app config, middleware, error handling
│   ├── context/base_context.zig — base context for all features
│   ├── db/migrations/          — SQL migration files
│   ├── i18n/                  — internationalization (locales, date/number fmt)
│   └── middleware/            — auth middleware, guards
├── features/
│   ├── home/                  — feature module: controller, presenter, views
│   ├── auth/                  — auth: controller, model, service, repository, views
│   ├── todo/                  — CRUD example: controller, model, repository, views
│   └── movies/                — API integration example
└── shared/
    └── templates/
        ├── layout.html         — base layout with { slot }
        └── partials/          — reusable components (Topbar, Drawer, Sidebar)
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Handler Signature & Patterns
```zig
// Thin controller: delegates to presenter for context building
pub fn index(c: *spider.Ctx) !spider.Response {
    const locale_raw = c.header("Accept-Language") orelse "pt-BR";
    const locale = i18n.localeFromStr(locale_raw);
    const context = try presenter.buildContext(c.arena, c, locale);
    return c.view("home/index", context, .{});
}

// Accessing route params
pub fn update(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i64, c.params.get("id") orelse "", 10);
    // ...
}

// Parsing form data into typed struct
pub fn create(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(model.CreateInput);
    // input.field1, input.field2 available
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### HTMX Integration
```zig
// Detect HTMX request
fn isHxRequest(c: *spider.Ctx) bool {
    return c.header("HX-Request") != null;
}

// Return partial view for HTMX, full redirect for regular request
pub fn create(c: *spider.Ctx) !spider.Response {
    const todo = try repository.create(c.arena, input) orelse 
        return c.text("Error", .{});
    
    if (isHxRequest(c)) {
        const context = try presenter.buildItemContext(c.arena, c, todo);
        return c.view("todo/item_todo", context, .{});  // partial HTML
    }
    return c.redirect("/todo");  // full page reload
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Authentication Patterns
```zig
const AppClaims = struct {
    sub: []const u8,      // user UUID
    email: []const u8,
    name: []const u8,
    locale: []const u8,
    exp: i64,
    roles: []const u8,
    permissions: []const u8,
};

// JWT sign with custom claims
fn generateJwt(alloc: std.mem.Allocator, io: std.Io, user: model.User) ![]u8 {
    const jwt_secret = spider.env.getOr("JWT_SECRET", "");
    const now = std.Io.Clock.now(.real, io);
    const exp: i64 = now.toSeconds() + (60 * 60 * 24 * 7); // 7 days
    return try spider.auth.jwtSign(alloc, AppClaims{
        .sub = user.uuid,
        .email = user.email,
        .name = user.name,
        .exp = exp,
        .roles = "",
        .permissions = "",
    }, jwt_secret);
}

// Set auth cookie after login
pub fn handleLogin(c: *spider.Ctx) !spider.Response {
    const token = try generateJwt(c.arena, c._io, user);
    const cookie_value = try spider.auth.cookieSet(c.arena, token);
    
    const headers = try c.arena.alloc([2][]const u8, 2);
    headers[0] = .{ "Location", "/" };
    headers[1] = .{ "Set-Cookie", cookie_value };
    return spider.Response{
        .status = .found,
        .body = null,
        .content_type = "text/plain",
        .headers = headers,
    };
}

// Clear cookie on logout
pub fn logout(c: *spider.Ctx) !spider.Response {
    const cookie_value = try spider.auth.cookieClear(c.arena);
    // redirect with Set-Cookie header...
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Auth Middleware
```zig
// In main.zig
var gAuth = spider.auth.Auth.init(.{
    .secret = spider.env.getOr("JWT_SECRET", "changeme"),
    .public_paths = &.{ "/login", "/auth/*", "/public/*" },
    .redirect_to = "/login",
    .secure_cookie = false,
});
server.group("/dashboard", &.{gAuth.asFn()}, dashRoutes);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### CRUD Operations Pattern
```zig
// LIST
pub fn index(c: *spider.Ctx) !spider.Response {
    const items = try repository.findAll(c.arena);
    defer c.arena.free(items);
    const context = try presenter.buildListContext(c.arena, c, items);
    return c.view("feature/index", context, .{});
}

// CREATE
pub fn create(c: *spider.Ctx) !spider.Response {
    const input = try c.parseForm(model.CreateInput);
    _ = try repository.create(c.arena, input);
    return c.redirect("/feature");
}

// UPDATE
pub fn update(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i64, c.params.get("id") orelse "", 10);
    const updates = try c.parseForm(model.UpdateInput);
    _ = try repository.update(c.arena, id, updates);
    return c.redirect("/feature");
}

// DELETE
pub fn delete(c: *spider.Ctx) !spider.Response {
    const id = try std.fmt.parseInt(i64, c.params.get("id") orelse "", 10);
    try repository.delete(c.arena, id);
    if (isHxRequest(c)) return c.text("", .{});
    return c.redirect("/feature");
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Presenter Pattern (Context Building)
```zig
pub fn buildItemContext(alc: std.mem.Allocator, c: *spider.Ctx, item: model.Item) !@TypeOf(c).Context {
    _ = c;
    return .{
        .item = .{
            .id = item.id,
            .title = try alc.dupe(u8, item.title),
            .done = item.done,
        },
    };
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Template Examples (Real)
```html
<!-- views/home/index.html -->
extends "layout"

<div class="max-w-2xl mx-auto">
    <h1>{ title ?? "Default Title" }</h1>
    <p>{ description ?? "Default description" }</p>
</div>
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```html
<!-- shared/templates/layout.html -->
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
    <title>{ title ?? "SpiderStack" }</title>
    <script src="/htmx.min.js"></script>
</head>
<body>
    <PartialsTopbar />
    <main id="main">
        { slot }  <!-- child template content inserted here -->
    </main>
    <PartialsBottomNav />
</body>
</html>
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Build Configuration (SpiderStack build.zig)
```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Import Spider as dependency
    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    // Core module with spider import
    const core_mod = b.createModule(.{
        .root_source_file = b.path("src/core/mod.zig"),
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });

    // Executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,  // required for PostgreSQL
    });
    exe.root_module.addImport("spider", spider_mod);
    exe.root_module.addImport("core", core_mod);

    // Auto-generate embedded templates
    const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
    gen.addArg("src/");
    gen.addArg("src/embedded_templates.zig");
    exe.step.dependOn(&gen.step);

    // Auto-import spider.config.zig
    exe.root_module.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
    });
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### spider.config.zig (Real Example)
```zig
const spider = @import("spider");

pub const config = spider.Config{
    .views_dir = "./src",       // features/ and shared/ are under src/
    .layout = "layout",         // shared/templates/layout.html
    .env = .development,       // or .production
    .port = 8080,
    .host = "127.0.0.1",
};
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Tailwind CSS Setup

SpiderStack uses Tailwind CSS with DaisyUI for styling. The CSS build is a separate step from `zig build`.

### Installation
```bash
pnpm init
pnpm add -D tailwindcss postcss autoprefixer daisyui
npx tailwindcss init -p  # creates tailwind.config.js and postcss.config.js
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### tailwind.config.js
```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/**/*.{zig,html}",   // scan Zig and HTML files for classes
        "./templates/**/*.zig",
    ],
    theme: {
        extend: {},
    },
    plugins: [
        require('daisyui'),
    ],
    daisyui: {
        themes: ["light", "dark"],
        darkTheme: "dark",
        base: true,
        styled: true,
        utils: true,
    },
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### postcss.config.js
```javascript
module.exports = {
    plugins: {
        tailwindcss: {},
        autoprefixer: {},
    },
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### package.json scripts
```json
{
    "scripts": {
        "build:css": "npx tailwindcss -i ./src/styles.css -o ./public/css/app.css --minify",
        "watch:css": "npx tailwindcss -i ./src/styles.css -o ./public/css/app.css --watch"
    }
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Source CSS (src/styles.css)
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Build Commands
```bash
pnpm run build:css      # one-time build
pnpm run watch:css      # watch mode during development
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

The compiled CSS is output to `public/css/app.css` and served automatically by Spider's static file server.

---

## Template Generator (generate-templates)

Spider includes a tool that scans `src/` for `.html` and `.md` files and generates `embedded_templates.zig` for production builds.

### What it does
- Recursively scans the source directory for template files
- Normalizes names (e.g., `features/auth/views/login.html` → `auth_login`)
- Generates a Zig file with all templates embedded as compile-time strings
- In development, templates are loaded from disk (runtime mode)

### Build Integration
The template generator is automatically invoked by `build.zig`:

```zig
// In build.zig
const gen = b.addRunArtifact(spider_dep.artifact("generate-templates"));
gen.addArg("src/");                    // source directory to scan
gen.addArg("src/embedded_templates.zig");  // output file
exe.step.dependOn(&gen.step);
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Manual Usage
```bash
# Generate embedded templates manually
zig build run -- generate-templates src/ src/embedded_templates.zig

# Or directly
./zig-out/bin/generate-templates src/ src/embedded_templates.zig
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Embed vs Runtime Mode
- **Embed mode**: Declare `spider_templates` in `main.zig`:
  ```zig
  pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
  ```
- **Runtime mode**: Don't declare `spider_templates` — templates load from disk automatically

Detection via `@hasDecl(@import("root"), "spider_templates")` — same pattern as `std_options`.

---

### Environment Variables (.env)
```bash
# Database
PG_HOST=localhost
PG_PORT=5432
PG_USER=spider
PG_PASSWORD=spider
PG_DB=myapp

# Auth
JWT_SECRET=your-secret-key-here
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://localhost:8080/auth/google/callback

# App
SPIDER_ENV=development
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Known TODOs

- MySQL parameter binding not implemented — queries use raw SQL strings
- MySQL `caching_sha2_password` (MySQL 8 default) not implemented
- Template name conflicts (two files normalizing to same name) — dev responsibility
- Queries parallel execution awaits `Io.Evented` stability
- SQLite driver needs review before use
- Graceful shutdown not implemented
- Request timeout not implemented
- TLS — use reverse proxy (Nginx/Caddy) in production

---

## Docker Deployment

Spider uses a native Zig PostgreSQL driver (pg.zig wire protocol) — no libpq dependency. Docker images need no system libraries for database connectivity.

### Embed Mode (recommended for production)

Templates are compiled into the binary — no files needed at runtime. Smallest possible image.

```dockerfile
FROM <zig-image>:master AS builder
WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/zig-out/bin/<app> /app/<app>
COPY --from=builder /app/public /app/public
EXPOSE 3000
CMD ["./<app>"]
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Runtime Mode

Templates are loaded from disk — must be copied into the container.

```dockerfile
FROM <zig-image>:master AS builder
WORKDIR /app
COPY . .
RUN zig build -Doptimize=ReleaseSmall

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/zig-out/bin/<app> /app/<app>
COPY --from=builder /app/public /app/public
COPY --from=builder /app/src /app/src
COPY --from=builder /app/spider.config.zig /app/spider.config.zig
EXPOSE 3000
CMD ["./<app>"]
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**Note:** Never add `libpq-dev`, `libpq5`, or `curl` — Spider's PostgreSQL driver is pure Zig, no C libraries needed.

---

## spider.config.zig — Required for Runtime Mode

Without `spider.config.zig`, Spider uses defaults (`views_dir="./views"`, `port=3000`, `env=development`). The default `views_dir` rarely matches the actual project structure, causing `TemplateNotFound` errors in runtime mode.

**Always create `spider.config.zig` in the project root:**

```zig
const spider = @import("spider");

pub const config = spider.Config{
    .views_dir = "./src",   // must point to where your .html/.md files are
    .layout = "layout",
    .env = .development,    // or .production
    .port = 3000,
    .host = "0.0.0.0",
};
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### How views_dir works in runtime mode

`buildIndex()` in `src/render/views.zig` walks `views_dir` recursively, applying the same name normalization as `generate_templates.zig`. The path passed to `c.view()` is normalized the same way:

| File path (relative to views_dir) | Normalized name | Call with |
|---|---|---|
| `views/bills/index.html` | `bills_index` | `c.view("bills/index", ...)` |
| `shared/templates/layout.html` | `layout` | layout (auto) |
| `shared/templates/Card.html` | `Card` | `c.view("Card", ...)` |

### Runtime mode warnings (src/render/views.zig)

Spider prints warnings to help diagnose configuration issues:

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
[spider] WARNING: views_dir "./views" not found.
[spider]          Templates will not load in runtime mode.
[spider]          Check your spider.config.zig -> views_dir setting.
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
[spider] WARNING: No templates found in "./views".
[spider]          Make sure your .html/.md files are inside views_dir.
[spider]          Check your spider.config.zig -> views_dir setting.
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.
[spider] runtime templates: 5 loaded from "./src"
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## build.zig — Project Build File

### Registering spider.config.zig

For Spider to read `spider.config.zig`, it must be registered as an anonymous import on the `spider_mod`. The Spider `build.zig` provides a default config fallback — projects override it by registering their own.

```zig
const spider_dep = b.dependency("spider", .{ .target = target });
const spider_mod = spider_dep.module("spider");

// Override Spider's default config with the project's spider.config.zig if it exists
const config_exists = blk: {
    std.Io.Dir.cwd().access(b.graph.io, "spider.config.zig", .{}) catch break :blk false;
    break :blk true;
};
if (config_exists) {
    spider_mod.addAnonymousImport("spider_config", .{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Checking file existence in build.zig (Zig 0.17)

**CORRECT — use `b.graph.io` (the build system's own IO instance):**
```zig
std.Io.Dir.cwd().access(b.graph.io, "some_file.zig", .{}) catch break :blk false;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**WRONG — `b.pathExists()` does not exist:**
```zig
if (b.pathExists("some_file.zig")) { ... }  // compile error
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**WRONG — `std.fs.cwd().access()` is the old API:**
```zig
std.fs.cwd().access("some_file.zig", .{}) catch break :blk false;  // old API
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Spider's build.zig — default spider_config fallback

Spider's own `build.zig` registers a default `spider_config` so projects without `spider.config.zig` don't break at compile time:

```zig
const default_cfg = b.addWriteFiles();
const default_cfg_file = default_cfg.add("spider_config.zig",
    \\const spider = @import("spider");
    \\pub const config = spider.Config{};
);
mod.addAnonymousImport("spider_config", .{
    .root_source_file = default_cfg_file,
});
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

---

## Live Reload

Live reload is injected automatically in `env=.development`. In production (`env=.production`) it must be disabled.

### How it works

1. `appWithConfig()` registers `/_spider/reload` WebSocket endpoint (dev only)
2. `handleConnection()` injects the reload script before `</body>` in all HTML responses (dev only)
3. Script connects via WebSocket; on server restart, browser detects disconnect and calls `location.reload()`

### Script (src/modules/livereload.zig)

```javascript
(function() {
  if (window.__spiderReload) return;
  window.__spiderReload = true;
  var port = window.location.port || '80';
  var host = window.location.hostname;
  function connect() {
    var sock = new WebSocket('ws://' + host + ':' + port + '/_spider/reload');
    sock.onopen = function() { console.log('[Spider] live reload ready'); };
    sock.onclose = function() {
      console.log('[Spider] server restarting...');
      setTimeout(tryReconnect, 500);
    };
  }
  function tryReconnect() {
    var test = new WebSocket('ws://' + host + ':' + port + '/_spider/reload');
    test.onopen = function() { window.location.reload(); };
    test.onerror = function() { setTimeout(tryReconnect, 500); };
  }
  connect();
})();
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### TODO — Live reload not disabled in production (known bug)

`spider.config.zig` is currently not being read by Spider's `fromRoot()` correctly — `config.env` always returns `.development` regardless of what is set in the file. As a workaround, the live reload script injection and endpoint registration are commented out in `src/core/app.zig`.

**Files modified (commented out):**
- `appWithConfig()` — endpoint registration
- `handleConnection()` — script injection

---

## Known TODOs (updated)

- MySQL parameter binding not implemented — queries use raw SQL strings
- MySQL `caching_sha2_password` (MySQL 8 default) not implemented
- Template name conflicts (two files normalizing to same name) — dev responsibility
- Queries parallel execution awaits `Io.Evented` stability
- SQLite driver needs review before use
- Graceful shutdown not implemented
- Request timeout not implemented
- TLS — use reverse proxy (Nginx/Caddy) in production
- **`spider.config.zig` not being read** — `fromRoot()` always returns defaults; `config.env`, `views_dir`, and other settings are ignored at runtime
- **Live reload not disabled in production** — depends on the TODO above; currently commented out in `app.zig` as workaround

---

## Embed Mode vs Runtime Mode — Complete Reference

### How Spider detects the mode

In `context.zig`, at compile time:

```zig
const root = @import("root");
const has_embed = @hasDecl(root, "spider_templates"); // comptime
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

`@import("root")` resolves to the executable's root source file (`main.zig`), NOT to Spider's internal `spider.zig`. This is the same pattern as `std_options` in the Zig stdlib.

In `c.view()`:
```zig
if (has_embed) {
    // looks up in EmbeddedTemplates struct
} else {
    // reads from disk (runtime mode)
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Activating embed mode

Declare in `main.zig` (must be `pub`, must be named exactly `spider_templates`):

```zig
pub const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

**Common mistakes that break embed mode:**
```zig
// WRONG — not pub, @hasDecl won't see it
const spider_templates = @import("embedded_templates.zig").EmbeddedTemplates;

// WRONG — wrong name, Spider looks for spider_templates specifically
pub const templates = @import("embedded_templates.zig").EmbeddedTemplates;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

Both mistakes cause `has_embed = false` → Spider falls back to runtime mode → works only if `src/` exists on disk → `TemplateNotFound` when `src/` is absent (e.g. in Docker).

### Name normalization — must be identical in both modes

The name passed to `c.view()` is normalized before lookup:
```zig
// "bills/index" → "bills_index"
// "docs/http-client" → "docs_http_client"
buf[j] = if (c == '/' or c == '-') '_' else c;
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

`generate_templates.zig` must produce the same names. Rules:
- Strip extension
- Use segment after `views/` or `templates/`
- Replace `/` and `-` with `_`

| File | Generated field | Call with |
|---|---|---|
| `features/docs/views/index.html` | `docs_index` | `c.view("docs/index", ...)` |
| `views/bills/index.html` | `bills_index` | `c.view("bills/index", ...)` |
| `shared/templates/layout.html` | `layout` | layout (auto) |
| `shared/templates/site-nav.html` | `site_nav` | `<SiteNav />` |

### Bug fixed — generate_templates.zig wrong normalization

`generate_templates.zig` had a bug where `views/bills/index.html` generated `index` instead of `bills_index`. Caused by: when `views/` was at the root of the path, `dir.len == 0` and returned only the `basename` instead of normalizing the full path after `views/`.

**Fix in `generateFieldName`:**
```zig
if (dir.len == 0) {
    // Normalize full path after views/ — bills/index → bills_index
    var j: usize = 0;
    for (after) |c| {
        if (j >= buffer.len) break;
        buffer[j] = if (c == '/' or c == '-') '_' else c;
        j += 1;
    }
    return buffer[0..j];
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### appWithConfig — buildIndex only in runtime mode

`buildIndex` scans `views_dir` at startup. In embed mode this is unnecessary and causes the server to depend on `src/` being present on disk even after build.

**Fix in `appWithConfig`:**
```zig
pub fn appWithConfig(config: Config) Server {
    var s = Server.init();
    s.config = config;

    // Only scan views_dir in runtime mode — embed mode uses spider_templates compiled into the binary
    if (!has_embed) {
        var threaded = std.Io.Threaded.init_single_threaded;
        const io = threaded.io();
        const views_dir = config.views_dir orelse "src";
        s.views_index = views_mod.buildIndex(io, std.heap.smp_allocator, views_dir) catch null;
    }

    return s;
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### handleConnection — always provide ViewsConfig

`_views` must never be `null` — embed mode needs `ViewsConfig` too (for `io`, `layout`, etc). If `null`, `c.view()` returns `error.ViewsNotConfigured` before reaching the embed logic.

**Fix in `handleConnection`:**
```zig
// Always provide a valid ViewsConfig — embed mode needs it too
const views_cfg: ViewsConfig = .{
    .views_dir = ctx.server.config.views_dir orelse "./views",
    .layout = ctx.server.config.layout,
    .io = ctx.io,
    .arena = arena,
    .mode = if (has_embed) .embed else .runtime,
    .index = views_idx_ptr,
};
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Error handling for TemplateNotFound

Register an error handler to catch `TemplateNotFound` gracefully instead of crashing:

```zig
server.onError(errorHandler);

fn errorHandler(c: *spider.Ctx, err: anyerror) !spider.Response {
    return switch (err) {
        error.TemplateNotFound => c.text(
            try std.fmt.allocPrint(c.arena, "Template not found: {s}", .{c._last_template orelse "unknown"}),
            .{ .status = .not_found },
        ),
        else => c.text(@errorName(err), .{ .status = .internal_server_error }),
    };
}
```

`c._last_template` holds the name of the last template requested — useful for debugging which template triggered the error. Falls back to `"unknown"` if not set.

### Files modified for these fixes

- `src/generate_templates.zig` — fixed `generateFieldName` normalization
- `src/core/app.zig` — `buildIndex` only in runtime mode, `has_embed` comptime, always provide `ViewsConfig`
- `src/core/context.zig` — `has_embed` via `@import("root")` which resolves to user's `main.zig`

---

## spider.config.zig — Fix Final (build.zig correto)

### O problema anterior
`addAnonymousImport` não funcionava porque `spider.config.zig` importa `spider`, mas o módulo anônimo não tinha acesso ao `spider` no seu grafo de imports — causando circular import ou import não encontrado.

### Fix correto — usar `b.createModule` + `addImport`

No `build.zig` do projeto, registrar o `spider_config` como módulo explícito com o `spider` no imports:

```zig
const config_exists = blk: {
    std.Io.Dir.cwd().access(b.graph.io, "spider.config.zig", .{}) catch break :blk false;
    break :blk true;
};
if (config_exists) {
    const spider_config_mod = b.createModule(.{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{
            .{ .name = "spider", .module = spider_mod },
        },
    });
    spider_mod.addImport("spider_config", spider_config_mod);
}
```

### Como o Spider detecta se há config do projeto

Em `app.zig`, usa `@hasDecl(@import("spider_config"), "is_default")`:

```zig
// spider's build.zig registers a default spider_config with is_default = true
// project's spider.config.zig does NOT have is_default — so this check works
if (@hasDecl(@import("spider_config"), "is_default")) {
    std.debug.print("[spider] WARNING: No spider.config.zig found.\n", .{});
}
```

O default `spider_config` do Spider tem `pub const is_default = true`. O `spider.config.zig` do projeto não tem essa declaração — então `@hasDecl` retorna `false` quando o projeto tem seu próprio config.

### `fromRoot()` simplificado

```zig
pub fn fromRoot() Config {
    // spider_config is always available — either project's or Spider's default fallback
    return @import("spider_config").config;
}
```

### Resumo dos fixes aplicados

| Problema | Causa | Fix |
|---|---|---|
| Warning sempre disparava | `@hasDecl(root, "spider_config")` procurava em `main.zig` | `@hasDecl(@import("spider_config"), "is_default")` |
| Config nunca carregava | `fromRoot()` retornava defaults quando `@hasDecl` falhava | `fromRoot()` agora sempre usa `@import("spider_config").config` |
| Circular import | `addAnonymousImport` sem o `spider` no grafo | `b.createModule` explícito com `spider` nos imports |
| `views_dir` ignorado | `appWithConfig` tinha `"src"` hardcoded | Agora usa `config.views_dir orelse "src"` |


---

## Spider CLI — Estado Atual (main branch)

### Comandos implementados e funcionando

```bash
spider new <app_name>              # cria projeto completo
spider new --daisyui <app_name>  # cria projeto com templates DaisyUI (flag oculto)
spider generate feature <name>     # gera feature CRUD completa
spider g feature <name>          # alias para generate
spider migrate                     # aplica migrations pendentes
spider help                        # mostra ajuda
```

### `spider new <app_name>` gera:
```
myapp/
├── build.zig              — com core_mod, features_mod, spider_config
├── build.zig.zon          — spider via zig fetch (main branch)
├── spider.config.zig      — views_dir, layout, env, port, host
├── Dockerfile             — embed mode, sem libpq
├── docker-compose.yml     — PostgreSQL pronto
├── .env.example           — variáveis de ambiente
├── .gitignore
├── bin/
│   ├── tailwindcss        — standalone binary (chmod +x)
│   ├── daisyui.mjs        — DaisyUI plugin
│   └── daisyui-theme.mjs  — DaisyUI themes
├── public/
│   ├── images/logo.png   — Spider logo (auto-included)
│   ├── favicon.png       — Favicon PNG (auto-included)
│   ├── favicon.ico       — Favicon ICO (auto-included)
│   ├── js/alpine.min.js
│   ├── js/htmx.min.js
│   └── css/app.css        — compilado na criação
└── src/
    ├── main.zig           — com spider_templates, DB comentado, errorHandler
    ├── embedded_templates.zig
    ├── core/mod.zig
    ├── features/
    │   ├── mod.zig
    │   └── home/
    │       ├── controller.zig
    │       ├── mod.zig
    │       └── views/index.html  — Dashboard completo
    └── shared/templates/
        ├── layout.html      — Modellar (usa componentes)
        ├── nav-bar.html     — Navbar component
        ├── side-bar.html    — Sidebar component
        ├── mobile-nav.html  — Mobile nav component
        └── toast.html        — Toast component
```

**Com `--daisyui` flag:**
```
myapp/
└── src/shared/templates/
    └── layout.html      — Template layout_daisyui (DaisyUI variant)
```

### `spider generate feature <name>` gera:
```
src/features/<name>/
├── mod.zig
├── model.zig
├── repository.zig
├── presenter.zig
├── controller.zig
└── views/index.html
src/core/db/migrations/<timestamp>_create_<plural>.sql
```

E atualiza automaticamente:
- `src/features/mod.zig` — adiciona `pub const <name> = @import(...)`
- `src/core/db/migrations.zig` — adiciona `@embedFile` da nova migration
- `src/main.zig` — adiciona import e rotas antes do `.listen(`

### Pluralização
```zig
// Se termina em "s" não adiciona outro "s"
// drivers → drivers (não driverss)
// book → books
```

### Mapeamento de ícones (Tabler Icons)
```
users/user/profile  → ti-users
product/products    → ti-package
order/orders        → ti-shopping-cart
post/posts/blog     → ti-file-text
task/tasks/todo     → ti-checkbox
category/categories → ti-tag
report/reports      → ti-chart-bar
setting/settings    → ti-settings
message/messages    → ti-message
payment/payments    → ti-credit-card
default             → ti-list
```

### `spider migrate`
- Lê `.env` para conectar ao banco
- Lista SQLs em `src/core/db/migrations/` ordenados por timestamp
- Cria `schema_migrations` se não existir
- Aplica migrations pendentes idempotentemente
- Segunda execução retorna "Nothing to migrate"

### Estrutura do CLI (`src/cli/`)
```
src/cli/
├── main.zig           — entry point, dispatch de comandos
├── new.zig            — spider new
├── generate.zig       — dispatcher do generate
├── feature.zig        — orquestração do generate feature
├── migrate.zig        — spider migrate
├── downloader.zig     — HTTP download com verificação de status
├── template_engine.zig — capitalize, pluralize, renderTemplate
├── fs_utils.zig       — writeFile, findProjectRoot
├── mod_updater.zig    — updateFeaturesMod
├── migration_updater.zig — updateMigrationsZig
├── routes_updater.zig — updateMainZig
    └── templates/
        ├── build.zig.template
        ├── build.zig.zon.template
        ├── spider.config.zig.template
        ├── main.zig.template
        ├── Dockerfile.template
        ├── docker-compose.yml.template
        ├── env.example.template
        ├── gitignore.template
        ├── layout.html.template           # Standard layout (modular, uses components)
        ├── layout_daisyui.html.template  # DaisyUI variant (activated with --daisyui flag)
        ├── home_index.html.template        # Standard home with dashboard
        ├── home_daisyui_index.html.template
        ├── nav-bar.html.template
        ├── side-bar.html.template
        ├── mobile-nav.html.template
        ├── toast.html.template
        ├── home_controller.zig.template
        └── feature/
            ├── mod.zig.template
            ├── model.zig.template
            ├── repository.zig.template
            ├── presenter.zig.template
            ├── controller.zig.template
            ├── index.html.template
            └── migration.sql.template
        └── assets/
            ├── spider_logo.png
            ├── favicon.png
            └── favicon.ico
```

### findProjectRoot
Sobe a árvore de diretórios até encontrar `build.zig.zon` — permite rodar `spider generate` de qualquer subdiretório do projeto.

### TODOs da CLI
- `spider migrate down` — rollback
- `spider migrate status` — ver pendentes
- `--no-db` flag no generate feature
- GitHub Actions + `install.sh` em spiderme.org
- App shell responsivo no `layout.html.template`
- `layout_updater.zig` — injeta nav ao gerar feature

---

## CLI Publishing — `curl` Install

### Overview
The Spider CLI can be downloaded via `curl` using an install script hosted at `spiderme.org/install.sh`.

### Publishing Structure
1. **GitHub Actions** (`.github/workflows/release.yml`):
   - Triggered on tags `v*`
   - Builds multiple platforms on `ubuntu-latest` (Zig cross-compiles natively):
     - `linux-x86_64` (Intel Linux)
     - `macos-x86_64` (Intel Mac)
     - `macos-aarch64` (Apple Silicon Mac)
   - Creates GitHub Release with attached binaries

2. **Install Script** (`scripts/install.sh`):
   - Auto-detects OS and architecture
   - Downloads correct binary from GitHub Releases
   - Installs to `~/.local/bin` (or `$SPIDER_INSTALL_DIR`)
   - Supports flags: `--version`, `--install-dir`, `--help`
   - Also accepts positional version arg

### For Users (curl install)
```bash
# Quick install (latest)
curl -fsSL https://spiderme.org/install.sh | bash

# Specific version
curl -fsSL https://spiderme.org/install.sh | bash -s -- --version v0.1.0

# Custom install directory
curl -fsSL https://spiderme.org/install.sh | bash -s -- --install-dir /usr/local/bin
```

### Configure spiderme.org
The `install.sh` script must be hosted at `spiderme.org/install.sh` and return the content of `scripts/install.sh` from the repository.

### Download URLs
| Platform | Filename |
|----------|----------|
| Linux x86_64 | `spider-linux-x86_64.tar.gz` |
| macOS x86_64 | `spider-macos-x86_64.tar.gz` |
| macOS aarch64 | `spider-macos-aarch64.tar.gz` |

### Build Manually (for development)
```bash
# Build CLI (from project root, NOT src/cli/)
zig build -Doptimize=ReleaseSafe

# Binary at zig-out/bin/spider
```

### Problems Encountered & Fixes

#### 1. `mlugg/setup-zig@v1` outdated
**Problem:** Action `mlugg/setup-zig@v1` failed on all runners ("Install Zig" step cancelled).
**Fix:** Use `mlugg/setup-zig@v2` (latest is v2.2.1, Jan 2026). The `v1` tag points to an old release.

#### 2. Building from wrong directory
**Problem:** Workflow ran `cd src/cli && zig build`, but `src/cli/build.zig` is a **template** for `spider new` projects, not the CLI itself. It references `b.dependency("spider", ...)` with no corresponding `build.zig.zon`, causing build failure.
**Fix:** Build from the project root (`zig build`), where the root `build.zig` defines the `spider` executable using `src/cli/main.zig` as its source.

#### 3. `spider-dev` causes build failure in CI
**Problem:** The dev test server (`spider-dev`) depends on `translate-c` for `includes/env.h`, which fails in CI with `error: failed to check cache: 'src/main.zig' file_hash FileNotFound`. The `zig build` command builds ALL installed artifacts by default, so `spider-dev` failure cascades to the whole build.
**Fix:** Comment out `b.installArtifact(test_exe)` and the `run` step in `build.zig`. Only build `spider` (CLI) and `generate-templates` by default. The `spider-dev` server is only needed for local dev.

#### 4. macOS runners unreliable
**Problem:** `macos-latest` runners consistently failed the build with "Process completed with exit code 1". Couldn't view logs without admin authentication.
**Fix:** Build ALL targets on `ubuntu-latest`. Zig's cross-compilation produces statically-linked binaries, so a single Linux runner can build for all platforms (linux x86_64, macOS x86_64, macOS aarch64).

#### 5. Release assets empty
**Problem:** GitHub Release was created but had 0 assets. `actions/download-artifact@v4` stores artifacts in subdirectories named after the artifact, so `softprops/action-gh-release` couldn't find the tarballs.
**Fix:** Add `merge-multiple: true` to the `actions/download-artifact@v4` step. This flattens the directory structure so all tarballs are in the current directory.

#### 6. install.sh argument parsing bugs
**Problem:** Original script only used `$1` as positional version arg. When run via `curl ... | bash -s -- --version v0.1.0`, `$1` is `--version`, not the version value. Also: sed regex used `1` instead of `\1`, download URL had double `v` (e.g., `vv0.1.0`) when version came from `get_latest_version()`.
**Fix:** Added `parse_args()` function with proper flag handling (`--version`, `--install-dir`, `--help`). Fixed sed regex. Added `strip_v_prefix()` helper. URL now always uses `v${VERSION}` where VERSION has been stripped of any existing `v` prefix.

#### 7. Creating new tag per test iteration
**Problem:** Workflow is triggered by new `v*` tags. Each CI fix required a new tag (v0.4.1, v0.4.2, v0.4.3...), polluting the tag history.
**Fix:** Delete and recreate the same tag instead:
```bash
git tag -d v0.4.3 && git push --delete origin v0.4.3
git tag v0.4.3 && git push origin v0.4.3
```
This reuses the tag and triggers the workflow with the latest main branch commit.

---

## CSS Stack — Tailwind v4 + DaisyUI + Alpine + HTMX

### Layout Visibility — CSS Media Queries

Commit `050b7c7` fixed layout visibility by replacing Tailwind classes with CSS media queries in `layout.html.template`:

**Before (broken):**
```css
@media (min-width: 1024px) {
    .desktop-aside { display: flex !important; }
    .mobile-only { display: none !important; }
}
```

**After (fixed):**
```css
/* Use CSS media queries directly in style tag */
@media (min-width: 1024px) {
    .desktop-aside { display: flex !important; }
    .mobile-only { display: none !important; }
}
```

This ensures proper visibility of desktop sidebar vs mobile drawer/nav without relying on Tailwind's responsive classes which may conflict with DaisyUI themes.

### {{ }} Passthrough — Alpine.js

**CRÍTICO:** Spider usa `{ ` (brace + espaço) para interpolação. Para passar `{ }` literais ao browser (Alpine.js `x-data`), use `{{ }}`:

```
{ title }         → Spider processa → substitui valor Zig
{{ dark: false }} → Spider ignora → chega como {dark: false} no HTML
```

Regras:
- `x-data` com objeto JS → usar `{{ }}`
- Todas outras expressões Alpine (`@click`, `x-show`, `:bind`) → escrever direto
- Dentro de `<script>` → `{ }` são ignorados pelo parser, sem necessidade de escape

```html
<body x-data="{{dark: false}}" :data-theme="dark ? 'dark' : 'light'">
    <button @click="dark = !dark">toggle</button>
    <span x-show="!dark">🌙</span>
</body>
```

### Alpine — Armadilhas

**`x-data` no `<html>` não funciona** — Alpine carrega com `defer`, o `<html>` já foi parseado. Sempre usar no `<body>`:
```html
<!-- CORRETO -->
<body x-data="{{dark: false}}">

<!-- ERRADO — não funciona com defer -->
<html x-data="{{dark: false}}">
```

**`class="bg-base-100 min-h-screen"` no `<body>` é obrigatório** — sem isso o tema DaisyUI não cobre a página toda.

### DaisyUI
Pure CSS — zero JS próprio. Tema controlado via `data-theme`:
```html
<body data-theme="dark">
<body :data-theme="dark ? 'dark' : 'light'">
```

### HTMX — Padrões Críticos

**HX-Redirect vs redirect():**
```zig
// ERRADO — HTMX injeta página inteira no target
return c.redirect("/items");

// CORRETO — redirect completo da página
const headers = try c.arena.alloc([2][]const u8, 1);
headers[0] = .{ "HX-Redirect", "/items" };
return c.html("", .{ .headers = headers });
```

**Headers — SEMPRE alocar no arena:**
```zig
// CORRETO
const headers = try c.arena.alloc([2][]const u8, 1);
headers[0] = .{ "HX-Trigger", "item-saved" };

// ERRADO — dangling pointer
return c.html("", .{ .headers = &.{.{ "HX-Trigger", "item-saved" }} });
```

**Toast pattern:**
```zig
// Controller
headers[0] = .{ "HX-Trigger", "item-saved" };
return c.html("", .{ .headers = headers });
```
```html
<!-- Template -->
<div x-data="{{show: false}}"
     @item-saved.window="show = true; setTimeout(() => show = false, 3000)"
     x-show="show">
    <div class="alert alert-success">Saved!</div>
</div>
```

### CRUD — Rotas padrão (6 rotas)

```zig
server
    .get("/items", item.controller.index)
    .get("/items/new", item.controller.newForm)
    .get("/items/:id/edit", item.controller.edit)
    .post("/items/create", item.controller.create)
    .post("/items/:id/update", item.controller.update)
    .post("/items/:id/delete", item.controller.delete)
```

---

## Zig 0.17 — Patterns Críticos

### Timestamp — dois métodos

**Via `std.Io.Clock` (cross-platform, idiomático para Zig 0.17):**
```zig
const now = std.Io.Clock.now(.real, io);
const timestamp = @intCast(@divFloor(now.nanoseconds, 1_000_000_000));
```

**Via `std.os.linux` (Linux-only, alternativa):**
```zig
var ts: std.os.linux.timespec = undefined;
_ = std.os.linux.clock_gettime(.REALTIME, &ts);
const now: i64 = ts.sec;
```

Prefira `std.Io.Clock` para código do framework. `std.os.linux` pode ser usado em ferramentas CLI Linux-only.

### JSON stringify
```zig
const body = try std.json.Stringify.valueAlloc(arena, value, .{});
```

### ArrayList
```zig
var list: std.ArrayListUnmanaged(T) = .empty;
defer list.deinit(allocator);
try list.append(allocator, item);
return try list.toOwnedSlice(allocator);
```

### Optional em parseForm
```zig
// SEMPRE usar orelse — nunca passar ?[]const u8 para {s} no fmt
const name = input.name orelse "";

---

## SSE (Server-Sent Events)

SSE é unidirecional (servidor → cliente). WebSocket é bidirecional (cliente ↔ servidor).

| | SSE | WebSocket |
|---|---|---|
| Direção | Servidor → cliente | Bidirecional |
| Casos de uso | Notificações, alertas, feeds, jobs assíncronos | Chat, jogos, colaboração |
| Reconexão | Automática (navegador nativo) | Manual |
| Biblioteca frontend | `EventSource` (nativa, zero dependência) | Nenhuma |

### Setup no Spider

```zig
server.sse("/sse", handler);
// src/core/app.zig:634-642
```

Handler deve receber `*spider.Sse` e retornar `!void`:

```zig
pub fn handler(sse: *spider.Sse) !void {
    _ = sse.wait(); // mantém conexão até cliente desconectar
}
// src/ws/sse.zig
```

### Sse API

```zig
// src/ws/sse.zig:14-27
pub fn send(self: *Sse, event: []const u8, data: anytype) !void

// src/ws/sse.zig:29-31
pub fn join(self: *Sse, channel: []const u8) !void

// src/ws/sse.zig:34-38
pub fn joinUser(self: *Sse, user_id: u64) !void

// src/ws/sse.zig:40-43
pub fn param(self: *Sse, key: []const u8) ?[]const u8

// src/ws/sse.zig:44-49
pub fn wait(self: *Sse) void
```

Exemplo completo:

```zig
fn notifHandler(sse: *spider.Sse) !void {
    // Canal específico (opcional)
    try sse.join("notifications");

    // Envia evento nomeado com JSON
    try sse.send("connected", .{ .status = "ok" });

    // Mantém conexão — sse.send pode ser chamado de handlers HTTP
    sse.wait();
}
```

### Push de handlers HTTP via Hub

```zig
// src/ws/hub.zig:104-108
// Broadcast para todos os clientes SSE
// src/ws/hub.zig:110-114
c.sseHub().emit("alert", .{ .message = "Nova notificação" });

// Canal específico
// src/ws/hub.zig:116-120
c.sseHub().emitTo("notifications", "update", .{ .count = 5 });

// Usuário específico (canal "user:42")
// src/ws/hub.zig:104-108
c.sseHub().notifyUser(user_id, "private", .{ .msg = "segredo" });
```

### Como funciona internamente

`buildSseWrapper` escreve headers HTTP manualmente, depois o handler recebe o `Sse`:

```zig
// src/core/app.zig:431-474
fn buildSseWrapper(comptime handler: fn (*Sse) anyerror!void) Handler {
    const W = struct {
        pub fn call(ctx: *Ctx) anyerror!Response {
            const hub = ctx._sse_hub orelse return ctx.text("", .{});
            // Headers HTTP manuais — sem request.respond()
            try writer.writeAll(
                "HTTP/1.1 200 OK\r\n" ++
                "Content-Type: text/event-stream\r\n" ++
                "Cache-Control: no-cache\r\n" ++
                "Connection: keep-alive\r\n" ++
                "\r\n",
            );
            // Registra conexão no Hub como .sse
            try hub.add(.{ .id = conn_id, .stream = ctx._stream, .type = .sse });
            // Mantém handler no loop do SSE
            handler(&sse) catch {};
            return Response{ .raw = true }; // ← evita request.respond()
        }
    };
    return W.call;
}
```

- `Connection.type = .sse` — Hub detecta e usa `sendSse` em vez de `sendText`
- `Response{ .raw = true }` — sentinel que evita `request.respond()` duplicado
- `hub.broadcast()` envia `event: message\ndata: ...` para conexões SSE

### Formato correto: event e data em linhas separadas

```zig
// CORRETO — duas linhas separadas (src/ws/hub.zig:226-236)
writer.writeAll("event: alert");
writer.writeAll("\ndata: ");
writer.writeAll(json);
writer.writeAll("\n\n");

// ERRADO — embrulhar como JSON envelope
writer.writeAll("data: {\"event\":\"alert\",\"data\":{...}}\n\n");
// O browser NÃO dispara addEventListener("alert") — evento nomeado não funciona
```

### Frontend — zero bibliotecas

```javascript
const source = new EventSource("/sse");

// Evento nomeado — addEventListener com o nome exato
source.addEventListener("alert", (e) => {
    const data = JSON.parse(e.data);
    showToast(data.message);
});

// Evento sem nome (broadcast do Hub com "message")
source.onmessage = (e) => {
    const data = JSON.parse(e.data);
    showToast(data);
};
```

Reconexão automática: o navegador (`EventSource`) reconecta sozinho em caso de queda. Nenhum código adicional necessário.

### Hub — broadcast com tipo misto

Se o Hub tiver conexões WS e SSE simultâneas, `broadcast()` e `broadcastToChannel()` enviam para ambas usando o formato correto:

```zig
// src/ws/hub.zig:81-88
switch (conn.type) {
    .ws => self.sendText(conn.stream, message) catch { ... },
    .sse => self.sendSse(conn.stream, "message", message) catch { ... },
}
```

Porém, `emit()` e `emitTo()` só enviam para SSE (broadcastEvent filtra por `.sse`).

### Checklist SSE

- [ ] `server.sse()` registrado antes do `listen()`
- [ ] Handler chama `sse.wait()` para manter conexão aberta
- [ ] `c.sseHub()` acessível em handlers HTTP
- [ ] Frontend usa `addEventListener` com o nome exato do evento
- [ ] `Response{ .raw = true }` no wrapper — não chamar `request.respond()` após headers SSE

---

## Zig 0.16/0.17 APIs — Referência Rápida

APIs extraídas do código real do Spider. Nada teórico — só o que compila e funciona.

### 1. I/O — Stream, Reader, Writer

Reader e Writer exigem **3 argumentos**: `(stream, io, &buffer)`.

```zig
// ✅ Funciona no 0.16/0.17
// src/core/app.zig:179
var stream_reader = Io.net.Stream.Reader.init(ctx.stream, ctx.io, &read_buf);
var stream_writer = Io.net.Stream.Writer.init(ctx.stream, ctx.io, &write_buf);

// Em testes — socket direto sem stream
// src/ws/hub.zig:333
var reader = net.Stream.Reader.init(.{ .socket = sockets[1] }, io, &read_buf);
```

Ler do stream:

```zig
// ✅ Funciona — usar reader.interface.readSliceAll
// src/ws/hub.zig:334
try reader.interface.readSliceAll(buf[0..2]);
```

**CRÍTICO — Reader deve ser reutilizado:**

```zig
// ✅ Correto — um Reader para todo o ciclo de vida
// src/ws/websocket.zig:37-41
_read_buf: [65536]u8 = undefined,
_reader: ?net.Stream.Reader = null,

fn readAll(self: *Server, buf: []u8) !void {
    if (self._reader == null) {
        self._reader = net.Stream.Reader.init(self.stream, self.io, &self._read_buf);
    }
    try self._reader.?.interface.readSliceAll(buf);
}

// ❌ ERRADO — recriar o Reader por chamada perde o buffer interno
var reader = net.Stream.Reader.init(stream, io, &buf); // cada vez recria!
```

O que NÃO usar:

```zig
// ❌ std.io.fixedBufferStream — foi REMOVIDO no 0.16/0.17
var fbs = std.io.fixedBufferStream(&buf);

// ❌ std.io (minúsculo) — removido, usar std.Io (I maiúsculo)
const Io = std.Io;  // ✅ correto
```

### 2. JSON

```zig
// ✅ Serializar (alocar)
// src/ws/hub.zig:111
const json = std.json.Stringify.valueAlloc(self.allocator, data, .{}) catch return;

// ✅ Serializar (streaming, sem alocar)
// pg_driver_impl/src/types.zig:465
try std.json.Stringify.value(value, .{}, &buf.interface);

// ❌ std.json.stringify — NÃO EXISTE no 0.16/0.17
try std.json.stringify(value, .{}, writer);
```

### 3. Sleep / Timers

Dentro do scheduler Io.Threaded:

```zig
// ✅ Funciona
// src/core/app.zig:485-489
std.Io.sleep(entry.io, std.Io.Duration.fromMilliseconds(ms), .real) catch {};

// Duration helpers
std.Io.Duration.fromMilliseconds(i64)  // ✅ existe
std.Io.Duration.fromSeconds(i64)       // ✅ existe
```

Thread nativa:

```zig
// ✅ Funciona
std.Thread.sleep(ns); // ns = u64
```

O que NÃO usar:

```zig
// ❌ std.time.sleep — removido no 0.12
std.time.sleep(100 * std.time.ns_per_ms);

// ❌ std.time.timestamp() — NÃO EXISTE no 0.16/0.17
const now = std.time.timestamp();

// ❌ std.time.nanoTimestamp() — removido
const now = std.time.nanoTimestamp();
```

### 4. ArrayList

```zig
// ✅ std.ArrayListUnmanaged (preferido no Spider)
// src/ws/hub.zig:9
var list: std.ArrayListUnmanaged(T) = .empty;
defer list.deinit(allocator);
try list.append(allocator, item);
try list.appendSlice(allocator, slice);

// ✅ Remove por índice
// src/ws/hub.zig:56
_ = self.connections.orderedRemove(i);

// ✅ ToOwnedSlice
return try items.toOwnedSlice(arena);

// ❌ ERRO comum — esquecer o allocator
list.append(item);  // falta allocator para Unmanaged
```

### 5. Threads

```zig
// ✅ Spawn
// src/core/app.zig:689
const t = std.Thread.spawn(.{}, intervalLoop, .{entry.*}) catch continue;

// ✅ Detach
t.detach();

// ✅ Join
for (threads) |t| t.join();
```

⚠️ **Threads nativas NÃO devem usar `std.Io.sleep` com Io local:**

```zig
// ❌ ERRADO — Io local pode ser dangling
fn loop(hub: *Hub) void {
    var threaded = std.Io.Threaded.init_single_threaded; // local!
    const io = threaded.io();
    std.Io.sleep(io, .{}, .real) catch {}; // io inválido!
}

// ✅ Correto — receber Io de fora
fn loop(entry: IntervalEntry) void {
    while (true) {
        std.Io.sleep(entry.io, ..., .real) catch {};
        entry.callback(entry.hub);
    }
}
```

### 6. Io.Threaded

```zig
// ✅ init_single_threaded (testes / modo single)
// src/ws/hub.zig:278
var threaded = std.Io.Threaded.init_single_threaded;
const io = threaded.io();

// ✅ .init(allocator, .{}) (produção, multi-thread)
// src/core/app.zig:677
var threaded: Io.Threaded = .init(gpa, .{});
defer threaded.deinit();
const io = threaded.io();
```

O `Threaded` deve viver enquanto o `Io` for usado — guardar como field do Server:

```zig
// src/core/app.zig:515
ws_threaded: ?std.Io.Threaded = null,

pub fn ws(self: *Self, path: ..., ...) *Self {
    self.ws_threaded = std.Io.Threaded.init_single_threaded;
    self.ws_hub = Hub.init(std.heap.smp_allocator, self.ws_threaded.?.io());
}
```

### 7. Tempo e timestamps

```zig
// ✅ std.Io.Clock.now (única forma)
// src/internal/metrics.zig:49
const now = std.Io.Clock.now(.awake, global_io);

// Extrair segundos
// src/modules/auth/auth.zig:80
const now_sec: i64 = @intCast(@divFloor(now.nanoseconds, 1_000_000_000));

// ✅ Duration entre timestamps
const uptime_ns = server_start_time.durationTo(now);
const uptime_sec = @intCast(uptime_ns.toSeconds());
```

### 8. Sockets para testes

```zig
// ✅ makeSocketPair — AF_UNIX, STREAM
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

// shutdown(.send) — fecha só a escrita (simular cliente desconectado)
// src/ws/hub.zig:352
try (net.Stream{ .socket = sockets[0] }).shutdown(io, .send);
```

### 9. std.Io.random

```zig
// ✅ Funciona
// src/core/app.zig:410
var rand_buf: [8]u8 = undefined;
std.Io.random(ctx._io, &rand_buf);

// Converter para u64
const conn_id = std.mem.readInt(u64, &rand_buf, .little);
```

### 10. Erro comum: `Context` vs `context`

O módulo `context.zig` exporta `Ctx`, não `Context`:

```zig
const Ctx = @import("core/context.zig").Ctx;  // ✅ correto
pub fn handler(c: *spider.Ctx) !spider.Response {  // ✅ correto
```

### Checklist rápido — o que funciona vs não funciona

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
| **`std.io.fixedBufferStream`** | ❌ | Removido — use `valueAlloc` ou `ArrayList` |
| **`std.time.sleep`** | ❌ | Removido — use `std.Io.sleep` ou `std.Thread.sleep` |
| **`std.time.timestamp()`** | ❌ | Não existe — use `std.Io.Clock.now` |
```

---

## Middleware — Logger

Spider ships a built-in request logger. Any function with signature
`fn(*Ctx, NextFn) !Response` is a valid middleware — third-party
middlewares work without modifying the framework.

### Usage

```zig
server.use(spider.logger);
```

Activates for all routes. Should be registered before routes.

### Output (dev)

```
GET     /              200  1.2ms
POST    /chat          201  342µs
GET     /nao-existe    404  89µs
GET     /ws            101  open
GET     /sse           200  open
```

- Method left-aligned to 7 characters
- Status color: 2xx green, 3xx blue, 4xx yellow, 5xx red
- Latency auto-formatted: `< 1000ns` → `Xns`, `< 1ms` → `Xµs`, `< 1s` → `Xms`, `>= 1s` → `Xs`
- WebSocket (101) and SSE (`raw=true`) show `open` instead of latency

### Implementation details

- Captures `std.Io.Clock.now(.real, c._io)` before and after `next(c)`
- Calculates latency from nanosecond difference
- Uses `std.debug.print` (stderr) for formatted output
- Unhandled errors (exception in `next(c)`) are logged as 500 + latency before re-raising

### 404 and middleware

404 is generated by `handleConnection` when no route matches. Since
Spider 0.4, 404 also goes through the middleware chain (global + path
middlewares), so the logger captures 404s too.

### Writing your own middleware

```zig
pub fn myMiddleware(c: *spider.Ctx, next: spider.NextFn) !spider.Response {
    // logic before handler
    const resp = try next(c);
    // logic after handler
    return resp;
}

server.use(myMiddleware);
```

---

## `get()` accepts runtime Handler

`get()` and `post()` in `app.zig` now accept both comptime handlers
(with or without decorations via `buildWrapper`) and runtime values of
type `Handler` (`*const fn (*Ctx) anyerror!Response`).

### How it works

```zig
pub fn get(self: *Self, path: []const u8, handler: anytype) *Self {
    const H = if (@TypeOf(handler) == Handler)
        handler               // runtime Handler — use directly
    else
        buildWrapper(handler, T);  // comptime fn with decorations
    self.router.add(.GET, path, H) catch unreachable;
    return self;
}
```

- `comptime` was removed from the `handler` parameter to allow runtime values
- `@TypeOf(handler) == Handler` is resolved at compile time — zero overhead
- When passing a `Handler` directly (e.g. `kc.callbackHandler()`), `buildWrapper`
  is skipped entirely
- Decorations (`fn(*Ctx, *Hub) !Response`) still work — the `else` branch
  runs `buildWrapper` as before

### Practical rule

```zig
// Runtime Handler — works
server.get("/auth/callback", kc.callbackHandler());

// Comptime fn without decorations — works (Handler after coercion)
server.get("/", home.index);

// Comptime fn WITH decorations — works (buildWrapper)
server.get("/system/ws", system.ws.handler);  // handler(c, hub)
```

---

## `auth_skip_paths` — path without query string

The JWKS middleware uses `auth_skip_paths` to skip routes that don't
need authentication (e.g. `/auth/login`, `/auth/callback`).

### Common bug: query string in path

`c.getPath()` returns the HTTP target **with** query string:
```
/auth/callback?state=abc&code=xyz
```

The old comparison (`std.mem.eql(u8, path, "/auth/callback")`) failed
because the path included the query string.

### Fix

In `middlewareFn` in `jwks.zig`:

```zig
const full_path = c.getPath();
const path = if (std.mem.indexOfScalar(u8, full_path, '?')) |q|
    full_path[0..q]
else
    full_path;
for (self.config.auth_skip_paths) |skip| {
    if (std.mem.eql(u8, path, skip)) return next(c);
}
```

### Config

```zig
// In KeycloakConfig or ClerkConfig
.auth_skip_paths = &.{ "/auth/login", "/auth/callback" },
```

```zig
// Direct JwksConfig
pub const JwksConfig = struct {
    ...
    auth_skip_paths: []const []const u8 = &.{},
};
```

---

## Keycloak — double session

Each time `/auth/login` is called, a new `state` is generated
and the user is redirected to Keycloak. If the OIDC flow completes
successfully, the callback exchanges the `code` for tokens, sets the
`__session` cookie, and redirects to `after_callback_path`.

### Loop symptom

```
GET /auth/callback?state=...&code=...  302  4µs
GET /auth/login                         302  9µs
(repeats infinitely)
```

Cause: global middleware intercepts `/auth/callback` because
`c.getPath()` includes the query string and the skip fails to match
(see `auth_skip_paths` section).

### Login handler

```zig
fn loginFn(self: *Keycloak, c: *Ctx) !Response {
    var rand_buf: [8]u8 = undefined;
    std.Io.random(c._io, &rand_buf);
    const state = std.fmt.bytesToHex(rand_buf, .lower);
    const url = try self.authUrl(&state);
    return c.redirect(url);
}
```

### Callback handler

Exchanges `code` for tokens via POST to Keycloak, sets `__session`
cookie, redirects to `/`:

```zig
fn callbackFn(self: *Keycloak, c: *Ctx) !Response {
    const code = c.query("code") orelse
        return c.text("Missing code", .{ .status = .bad_request });
    // POST /realms/{realm}/protocol/openid-connect/token
    // with grant_type=authorization_code, code, client_id, client_secret, redirect_uri
    // On success: sets __session cookie with id_token or access_token
    // Redirect 302 to after_callback_path
}
```

### Logout active session

Via Admin API:

```bash
ADMIN_TOKEN=$(curl -s -X POST .../realms/master/protocol/... \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

USER_ID=$(curl -s .../admin/realms/spider/users?username=testuser \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")

curl -X POST ".../admin/realms/spider/users/$USER_ID/logout" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## Fix `redirect()` dangling pointer

`c.redirect(url)` in `context.zig` was allocating the `Location` header
on the stack:

```zig
// BEFORE — dangling pointer
pub fn redirect(_: *Ctx, url: []const u8) !Response {
    return Response{
        .status = .found,
        .headers = &.{
            .{ "Location", url },  // ← stack pointer
        },
    };
}

// AFTER — arena allocation
pub fn redirect(self: *Ctx, url: []const u8) !Response {
    const hdrs = try self.arena.alloc([2][]const u8, 1);
    hdrs[0] = .{ "Location", url };
    return Response{
        .status = .found,
        .headers = hdrs,
    };
}
```

The same bug existed in:
- `jwks.zig:redirect()` helper (local function) — already uses arena
- `keycloak.zig:callbackFn()` — `.headers = &.{ .{ "Location", ... }, .{ "Set-Cookie", ... } }` → arena fix

### Rule

**Always** allocate runtime custom headers in `c.arena`:

```zig
const hdrs = try c.arena.alloc([2][]const u8, N);
hdrs[0] = .{ "Name", "Value" };
return Response{ .headers = hdrs, ... };
```

Never use `&.{ ... }` for runtime headers — the pointer targets stack
memory that is invalidated after return.

---

## `addRoute` vs `get()`

`addRoute` was used to register runtime `Handler` values before the
automatic type detection. Now `get()` and `post()` accept runtime
`Handler` directly.

### `addRoute` — when to use

- When you need **route-specific middlewares** (not global)
- API:

```zig
pub fn addRoute(
    self: *Self,
    method: std.http.Method,
    path: []const u8,
    middlewares: []const MiddlewareFn,
    handler: Handler,
) void
```

### `get()` — general case

```zig
// Before (addRoute)
server.addRoute(.GET, "/auth/callback", &.{}, kc.callbackHandler());
server.addRoute(.GET, "/auth/login", &.{}, kc.loginHandler());

// After (get)
server.get("/auth/callback", kc.callbackHandler())
      .get("/auth/login", kc.loginHandler());
```

### Differences

| Aspect | `get()` | `addRoute` |
|--------|---------|------------|
| Handler type | `anytype` (runtime or comptime) | `Handler` only |
| Middlewares | Global + path only | Route-specific |
| Chaining | Returns `*Self` | Returns `void` |
| Recommended use | Whenever route-specific middlewares are not needed | When route-specific middlewares are needed |
```

---

## Keycloak — Starting, Configuring, and Logging Out

### Starting Keycloak via Docker

```bash
# Start Keycloak 26+ with default admin user (dev mode)
docker run -d --name keycloak \
  -p 8080:8080 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin \
  quay.io/keycloak/keycloak:latest \
  start-dev
```

Keycloak will be available at `http://localhost:8080`. Admin console at `http://localhost:8080/admin/`.

For production, remove `start-dev` and configure a database with `-e KC_DB=postgres`.

### Configuring Realm, Client and User via Admin REST API

```bash
# 1. Get admin token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# 2. Create realm
curl -s -X POST http://localhost:8080/admin/realms \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm": "spider", "enabled": true}'

# 3. Create a confidential client with Direct Access Grants enabled
curl -s -X POST http://localhost:8080/admin/realms/spider/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "spider-app",
    "enabled": true,
    "publicClient": false,
    "secret": "spider-secret",
    "redirectUris": ["http://localhost:3000/auth/callback"],
    "standardFlowEnabled": true,
    "directAccessGrantsEnabled": true
  }'

# 4. Create a test user
curl -s -X POST http://localhost:8080/admin/realms/spider/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "enabled": true,
    "email": "test@spider.dev",
    "firstName": "Test",
    "lastName": "User",
    "credentials": [{"type": "password", "value": "testpass", "temporary": false}]
  }'
```

### Keycloak Endpoint URLs

All endpoints follow the pattern `{base_url}/realms/{realm}/protocol/openid-connect/{action}`:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| JWKS | `/realms/{realm}/protocol/openid-connect/certs` | Public RSA keys for token verification |
| Authorization | `/realms/{realm}/protocol/openid-connect/auth` | User login page redirect |
| Token | `/realms/{realm}/protocol/openid-connect/token` | Exchange code for tokens, refresh, password grant |
| RP-Initiated Logout | `/realms/{realm}/protocol/openid-connect/logout` | End Keycloak session |
| User Info | `/realms/{realm}/protocol/openid-connect/userinfo` | Fetch authenticated user info |
| OIDC Discovery | `/realms/{realm}/.well-known/openid-configuration` | All endpoints in one JSON |

The `spider.keycloak.Keycloak` wrapper constructs the JWKS, auth, and token URLs automatically from `base_url` and `realm`. Example generated auth URL:

```
http://localhost:8080/realms/spider/protocol/openid-connect/auth?response_type=code&client_id=spider-app&redirect_uri=http://localhost:3000/auth/callback&state=abc123
```

### Double Session — Spider Cookie vs Keycloak Session

There are **two independent sessions**:

1. **Keycloak session** — maintained by Keycloak via its own session cookie (`KEYCLOAK_SESSION` / `KEYCLOAK_IDENTITY`). Created when the user authenticates through the Keycloak login page.
2. **Spider session** — maintained by Spider via the `__session` JWT cookie. Created when the callback handler exchanges the authorization `code` for tokens.

A user can have a valid Keycloak session but no Spider session, or vice versa. The two sessions have independent lifecycles.

### Proper Logout — Invalidate Both Sessions

To fully log out a user you must:

1. **Clear the Spider `__session` cookie** — prevents future Spiderside auth.
2. **Invalidate the Keycloak session** — prevents the user from skipping Spider's login.

Recommended logout handler:

```zig
pub fn logout(c: *spider.Ctx) !spider.Response {
    // 1. Clear Spider cookie
    const cookie_clear = try c.setCookie("__session", "", .{
        .http_only = true, .secure = true,
        .same_site = "Lax", .path = "/", .max_age = 0,
    });

    // 2. Redirect to Keycloak RP-initiated logout
    const id_token_hint = c.params.get("_id_token") orelse "";
    const logout_url = try std.fmt.allocPrint(c.arena,
        "{s}/realms/{s}/protocol/openid-connect/logout?id_token_hint={s}&post_logout_redirect_uri={s}",
        .{ base_url, realm, id_token_hint, "/" },
    );

    const hdrs = try c.arena.alloc([2][]const u8, 2);
    hdrs[0] = .{ "Location", logout_url };
    hdrs[1] = .{ "Set-Cookie", cookie_clear };
    return .{ .status = .found, .body = null, .content_type = "text/plain", .headers = hdrs };
}
```

Alternatively, logout via Admin API (server-side, no id_token needed):

```bash
ADMIN_TOKEN=$(curl -s -X POST ... -d "grant_type=password&client_id=admin-cli&username=admin&password=admin" ...)
USER_ID=$(curl -s ".../admin/realms/spider/users?username=testuser" -H "Bearer $ADMIN_TOKEN" ...)
curl -X POST ".../admin/realms/spider/users/$USER_ID/logout" -H "Authorization: Bearer $ADMIN_TOKEN"
```

### `auth_skip_paths` Is Required

Always set `.auth_skip_paths = &.{ "/auth/login", "/auth/callback" }` in the Keycloak or JWKS config. Without it, the global JWKS middleware intercepts these routes, finds no token, and redirects to `/auth/login` — causing an infinite redirect loop.

---

## JWKS / OIDC — Verification Details

### RS256 Verification with `std.crypto.Certificate.rsa`

The JWKS provider verifies RS256-signed JWTs using only Zig's stdlib crypto — zero external dependencies. The flow:

1. **Decode JWK fields** — `n` (modulus) and `e` (exponent) are base64url-decoded from the JWK entry matching the JWT's `kid`.
2. **Construct RSA public key** using the decoded bytes.
3. **Verify signature** — the JWT header + payload (joined by `.`) are verified against the signature.

```zig
const key = try std.crypto.Certificate.rsa.PublicKey.fromBytes(e_bytes, n_bytes);
// switch on sig.len to handle 128/256/512 at comptime
switch (sig.len) {
    inline 128, 256, 384, 512 => |modulus_len| {
        var sig_arr: [modulus_len]u8 = undefined;
        @memcpy(&sig_arr, sig[0..modulus_len]);
        try rsa.PKCS1v1_5Signature.verify(
            modulus_len, sig_arr, msg, key, std.crypto.hash.sha2.Sha256,
        );
    },
    else => return error.UnsupportedKeySize,
}
```

### The Comptime `modulus_len` Problem

`std.crypto.Certificate.rsa.PublicKey` and `rsa.PKCS1v1_5Signature.verify` require the modulus length (key size in bytes) at **comptime**. JWT key sizes vary by provider (2048-bit = 256 bytes, 4096-bit = 512 bytes, etc.), which is not known until runtime when the JWK is fetched.

**Solution:** Use `inline else => |n|` in the switch — the `inline` keyword causes each branch to be instantiated with `n` as a comptime constant. This generates specialized verification code for each supported key size without runtime overhead.

```zig
var sig_arr: [modulus_len]u8 = undefined;  // modulus_len is comptime here
```

### Lazy JWKS Refresh

When the provider rotates keys, the JWT's `kid` may not be in the local cache. The provider refetches JWKS on demand:

```zig
// In verifyToken:
const jwk = if (self.keys.get(kid)) |entry|
    entry
else {
    try self.fetchJwks();  // refetch on miss
    break :blk self.keys.get(kid) orelse return error.UnknownKey;
};
```

This avoids periodic polling — keys are only refetched when a rotation is detected.

---

## Google OAuth vs JWKS Providers

Google's OAuth2 implementation in `spider.google` differs from the OIDC providers:

| Aspect | `spider.google` | `spider.jwks` / `spider.keycloak` / `spider.clerk` |
|--------|-----------------|------------------------------------------------------|
| Protocol | OAuth2 (stateless) | OIDC (OpenID Connect) |
| Token verification | None (profile fetched via API) | JWT verified locally with JWKS |
| Key type | Not applicable (no JWT verify) | RS256 asymmetric |
| Profile source | Google People/UserInfo API | Decoded from `id_token` claims |
| Use case | "Sign in with Google" button | Full OIDC login flow |

Google's OIDC tokens are also RS256 (not HS256). Google's public JWKS is at `https://www.googleapis.com/oauth2/v3/certs`. You can use `spider.jwks` with this URL for true OIDC integration.

HS256 (symmetric HMAC) is used only by `spider.auth.jwtSign`/`jwtVerify` for Spider's own JWT signing, where both parties share the same secret.

---

## Adding a New Provider (~30 Lines)

To add a new OIDC provider (e.g., GitHub, Microsoft, Okta), create a thin wrapper over `spider.jwks.JwksAuth`:

```zig
// src/providers/microsoft.zig
const spider = @import("../spider.zig");

pub const MicrosoftConfig = struct {
    tenant_id: []const u8,
    client_id: []const u8,
    client_secret: []const u8,
    redirect_uri: []const u8 = "http://localhost:3000/auth/callback",
    login_path: []const u8 = "/auth/login",
};

pub const Microsoft = struct {
    jwks: spider.jwks.JwksAuth,
    config: MicrosoftConfig,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: MicrosoftConfig) !Microsoft {
        const issuer = try std.fmt.allocPrint(allocator,
            "https://login.microsoftonline.com/{s}/v2.0", .{config.tenant_id});
        const jwks_url = try std.fmt.allocPrint(allocator,
            "https://login.microsoftonline.com/{s}/discovery/v2.0/keys", .{config.tenant_id});
        defer allocator.free(jwks_url);

        const jwks_auth = try spider.jwks.JwksAuth.init(allocator, io, .{
            .jwks_url = jwks_url,
            .issuer = issuer,
            .login_path = config.login_path,
            .auth_skip_paths = &.{ config.login_path, "/auth/callback" },
        });
        return Microsoft{ .jwks = jwks_auth, .config = config };
    }

    pub fn deinit(self: *Microsoft) void { self.jwks.deinit(); }
    pub fn middleware(self: *Microsoft) spider.MiddlewareFn { return self.jwks.middleware(); }
};
```

Then export from `spider.zig`:

```zig
pub const microsoft = @import("providers/microsoft.zig");
```

Usage:

```zig
var ms = try spider.microsoft.Microsoft.init(allocator, io, .{
    .tenant_id = "common",
    .client_id = spider.env.getOr("MS_CLIENT_ID", ""),
    .client_secret = spider.env.getOr("MS_CLIENT_SECRET", ""),
});
defer ms.deinit();
server.use(ms.middleware());
```

**Provider checklist:**
1. Find the provider's OIDC discovery document (`/.well-known/openid-configuration`) — it contains all URLs.
2. Create a wrapper struct storing `spider.jwks.JwksAuth`.
3. Configure `auth_skip_paths` to include login and callback paths.
4. Add `loginHandler()` and `callbackHandler()` if the provider supports the standard OIDC flow.
5. Export from `spider.zig`.
```
