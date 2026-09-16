# Architecture

## Layering

```
        ┌──────────────────────────────────────────┐
        │  Views (widgets)                         │
        │  no business logic, no Dio, no Supabase  │
        └────────────────┬─────────────────────────┘
                         │ Obx / GetBuilder
        ┌────────────────▼─────────────────────────┐
        │  Controllers (GetX)                      │
        │  reactive state, orchestration, guards   │
        └────────────────┬─────────────────────────┘
                         │
        ┌────────────────▼─────────────────────────┐
        │  Repositories                            │
        │  decide remote vs local vs cache vs queue│
        └───────┬──────────────────────┬───────────┘
                │                      │
     ┌──────────▼─────────┐  ┌─────────▼──────────┐
     │ Remote service     │  │ Local service      │
     │ Supabase / ApiClient│  │ LocalDatabase      │
     └──────────┬─────────┘  └─────────┬──────────┘
                │                      │
                └──────────┬───────────┘
                           │
                    ┌──────▼──────┐
                    │ Sync layer  │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │ Supabase                │
              │ Auth · PostgreSQL · RLS │
              │ Storage · RPC           │
              └─────────────────────────┘
```

A view that needs data reads it from a controller. A controller that needs data
asks a repository. The repository is the only layer that knows whether the
answer came from the network, the local cache, or a queued draft — which is
what makes offline mode possible without every screen knowing about it.

## Feature-based organisation

Each business module owns its full vertical:

```
features/<module>/
├── models/         immutable data classes, fromJson / toJson
├── controllers/    GetX controllers, reactive state
├── repositories/   data-source decisions
├── services/       module-specific remote/local access
├── bindings/       dependency registration for the module's routes
├── views/          screens
└── widgets/        widgets used only by this module
```

Feature-specific logic never moves into `common/` or `core/`. A widget shared
by exactly two features stays in the more-owning feature until a third needs
it; premature promotion to `common/` is how shared folders become dumping
grounds.

## Dependency injection

Two tiers, with different lifetimes:

- **Permanent services**, registered once in `AppConfig.initialiseServices()`:
  `StorageService`, `LocalDatabaseService`, `ConnectivityService`,
  `AuthService`, `ApiClient`, `ThemeController`, `SessionController`.
  Registration order is load-bearing and documented in that file — the local
  database needs the cipher key from storage, the API client needs both the
  auth token provider and connectivity.
- **Feature controllers**, registered by a `Bindings` class attached to the
  route. They are created on navigation and disposed on exit, so a list screen
  with a large page of rows does not stay in memory after the user leaves.

Dependencies are passed to constructors rather than resolved with `Get.find()`
inside a class. That keeps every controller constructible in a test without a
populated container.

## Key decisions and why

### Money is computed with `Decimal`, not `double`

Binary floating point cannot represent `0.1`, so accumulating line totals in
`double` drifts — `0.1 * 3` is `0.30000000000000004`. On an invoice with a
percentage discount and GST that drift becomes a visible one-paisa mismatch
between the line items and the total, and an unbalanced journal entry.

`MoneyUtil` therefore runs every computation through `Decimal` and rounds only
at the boundary. `MoneyUtil.distribute` exists because naive division loses a
paisa: splitting ₹100 three ways gives three ₹33.33s, so the residue is spread
across the leading instalments — the same rule the EMI schedule uses
server-side.

Client-side arithmetic is for showing a correct running total while the user
types. It is **not** the system of record: `create_sale_transaction()` and
`complete_service()` recompute every figure in `numeric` before writing.

### Authorization is resolved in one server call

`current_user_context()` walks
`auth.uid() → users → user_roles → roles → role_permissions → permissions →
accessible showrooms` in a single security-definer function.

Doing this as five client queries would mean each query is subject to RLS
policies that themselves need the caller's role and showroom context — which
is exactly how recursive policy evaluation deadlocks. The security-definer
function breaks the cycle, and it is also one round trip instead of five on a
showroom's mobile connection.

### `PermissionSet` is backed by a `Set`

Permission checks run on almost every rebuild: every navigation item, every
action button, every table row menu. `List.contains` over ~120 entries is O(n)
and would execute thousands of times per frame on a desktop data table. The
`Set` makes each check O(1). A super admin is a flag rather than an enumerated
list, so adding a permission does not require re-seeding existing super admins.

### Retries are restricted to idempotent requests

A retried `POST /payments` could take a customer's money twice. The retry
interceptor therefore retries `GET`/`HEAD`/`OPTIONS` freely, and retries a
mutation only when the caller explicitly marks it idempotent — which
repositories do only for RPCs carrying a client-generated key the database
de-duplicates on. Backoff is exponential with jitter, because when a showroom's
connection returns, every queued request would otherwise retry in lockstep.

### A single shared session refresh

A dashboard issues a dozen parallel requests. If the access token has expired
they all 401 at once, and refreshing per-request would fire a dozen refresh
calls — several of which get rejected as the refresh token rotates, signing the
user out spuriously. `AuthInterceptor` shares one in-flight refresh future
across all waiters.

### The local database is behind an interface

`LocalDatabase` is an abstract interface with a Hive implementation and an
in-memory implementation. Feature code depends only on the interface, so the
engine can be replaced without touching a repository, and repositories are
testable against the fake. Records are stored as plain
`Map<String, Object?>` — the same JSON shape the network returns — so no
adapter registration or code generation is needed and a schema change does not
require migrating the local store.

A corrupt box is deleted and recreated rather than propagated: the local store
is a cache and a replayable queue, so losing it is recoverable, whereas
refusing to start is not.

### Local storage is split three ways by sensitivity

- `SharedPreferences` — UI preferences only. It is a plain file, readable by
  anything running as the same user.
- Platform secure store — the Supabase refresh token, the FCM token, and the
  Hive cipher key. Passwords are never stored in any tier.
- Hive — cached business data and the sync queue, with boxes holding customer
  or financial data opened under a cipher.

Putting a token in the wrong tier is a real vulnerability, so the sensitive API
is a separate, narrow set of methods rather than a flag on a general setter.

### `JsonReader` guards every field read

Rows arrive from three sources with subtly different typing, and a direct cast
that works against one fails against another:

- PostgREST encodes `numeric` as a **string** to avoid JSON precision loss, so
  `row['total_amount'] as double` throws.
- `int` and `double` are interchangeable in JSON.
- Hive returns `Map<dynamic, dynamic>` after a disk round trip.
- An embedded PostgREST relation is a list for a to-many join but an object
  for a to-one join.

Reading through `JsonReader` means one malformed field yields a null or a
default instead of an exception that takes down a whole list screen.

### Errors are normalised at the repository boundary

Nothing above a repository ever sees a `DioException` or a
`PostgrestException`. `ErrorMapper` is the only place that knows about SQLSTATE
codes and HTTP statuses, and it translates them into an `AppException`
hierarchy that carries a user-safe message, a retryability flag, and optional
per-field errors so a server-side validation failure lands on the right form
field.

Business rules raised by our own PL/pgSQL with `RAISE EXCEPTION` (SQLSTATE
`P0001`) are passed through verbatim, because those functions author their
messages for end users.

### Route guards are declarative

`AppRoutes.routePermissions` maps each route to the permission that guards it,
and `PermissionMiddleware` consults that map. Keeping it as data rather than
scattering checks through widgets means a deep link and a typed web URL go
through exactly the same check as a tap. When a guard rejects, it redirects to
a route the user *can* open rather than bouncing them between blocked screens.

### Sync conflicts are never auto-resolved

Every table carries a `revision` counter maintained by a trigger. When a queued
offline change targets a row whose server revision has moved, the queue entry
is parked as `CONFLICT` and surfaced for a human decision. Silently overwriting
a financial record with a stale local copy is not an acceptable default.

## Responsive strategy

Breakpoints are resolved from **layout constraints**, not `MediaQuery.size`,
because on desktop and web the app can sit in a split pane far narrower than
the display — a data table crammed into 500px needs the mobile treatment
regardless of monitor size.

`AppResponsiveLayout` takes per-breakpoint builders and runs only the selected
one, so an expensive desktop data grid is never constructed on a phone.

| Class | Width | Shell |
| ----- | ----- | ----- |
| mobile | < 640 | bottom navigation, drawer, card lists |
| tablet | < 1024 | drawer, compact tables |
| desktop | < 1600 | sidebar, top bar, breadcrumbs, data tables |
| large desktop | ≥ 1600 | as desktop, wider content cap |

Content is capped at 1440px and centred: a form stretched across a 2560px
monitor is unusable because the eye cannot track from a label on the far left
to its field on the far right.

## Error and log handling at startup

`main()` wraps the application in `runZonedGuarded` so an asynchronous error
escaping a `Future` is still reported — Flutter's own handler only covers
errors raised inside the framework. `FlutterError.onError` and
`PlatformDispatcher.instance.onError` are both routed into `AppLogger`.

A build that is not configured, or one whose anon key looks like a service-role
key, renders a dedicated failure screen that depends on nothing but Flutter
itself — so it still displays when service initialisation is precisely what
failed.
