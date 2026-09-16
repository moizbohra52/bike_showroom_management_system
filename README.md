# Bike Showroom Management System

Multi-showroom sales, service, finance and accounting platform built with
Flutter, GetX, Dio and Supabase. Targets Android, iOS, Web and Windows from one
codebase.

---

## Build status

| Target  | Status | Notes |
| ------- | ------ | ----- |
| Web | Verified | `flutter build web --release` succeeds, no warnings |
| Android | Verified | Debug and release APKs build; release runs through R8 |
| Windows | **Not verified here** | Needs the MSVC "Desktop development with C++" workload; this machine has only SQL Server Management Studio, which Flutter misreports as Visual Studio |
| iOS | **Not verifiable here** | Requires macOS and Xcode |

Static analysis is completely clean (`dart analyze` — no issues at all) under a
strict ruleset, and the test suite
passes (172 tests, plus four live-server integration suites under
`test/integration/` that are skipped unless pointed at a running backend —
see `supabase/tests/README.md`, or `tools/local_backend/` to bring one up with
no Supabase account).

---

## Quick start

### 1. Prerequisites

- Flutter 3.44+ / Dart 3.12+
- A Supabase project
- A Firebase project (for push notifications)
- For Android: JDK 17 or 21 preferred (see *Known toolchain issues*)
- For Windows: Visual Studio with the **Desktop development with C++** workload

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure the backend

No secret is committed to this repository. Everything is injected at build time
with `--dart-define`:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>
```

Both values are on the Supabase dashboard under **Project Settings → API**.

> **Use the publishable (anon) key, never the service-role key.**
> The anon key carries no privileges of its own — every request it makes is
> still filtered by Row Level Security. A service-role key bypasses RLS
> entirely and would expose every showroom's data to every user.
> `SupabaseConfig.initialise()` inspects the key's `role` claim and **refuses
> to boot** if it looks like a service-role key.

Optional defines:

| Define | Default | Purpose |
| ------ | ------- | ------- |
| `APP_ENV` | `development` | `development` \| `staging` \| `production` |
| `API_BASE_URL` | Supabase REST URL | A companion REST service for Dio |
| `ENABLE_LOGGING` | `true` | Master switch for the logger |
| `ENABLE_NETWORK_LOGGING` | `false` | Logs request/response bodies. Never enabled in production — payloads contain customer data |
| `ENABLE_REALTIME` | `true` | Supabase realtime subscriptions |
| `ENABLE_OFFLINE_MODE` | `true` | Local cache and sync queue |
| `ENABLE_CRASH_REPORTING` | `true` | Forwards error-level logs to the crash sink |

A build missing `SUPABASE_URL` or `SUPABASE_ANON_KEY` does not start with a
broken screen — it shows an explicit configuration-failure page naming the
missing keys. That page is what an IDE's bare Run button produces, because it
launches `main.dart` with no defines at all. Use a launch configuration from
[`.vscode/launch.json`](.vscode/launch.json), or group the defines into a file
and pass it in one argument:

```bash
flutter run --dart-define-from-file=dart_defines/local.json
```

### 4. Run

```bash
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run              # Attached device
```

---

## Running without a Supabase account

If you do not have a Supabase project yet — or cannot install Docker Desktop to
use `supabase start` — the repository ships a local stand-in so the app can be
run end to end today:

```powershell
.\tools\local_backend\start.ps1 -Init
```

That brings up PostgreSQL, applies every migration, starts PostgREST, and
serves a Supabase-compatible origin on `http://127.0.0.1:54321`.

Then launch the app with the matching build configuration — in VS Code press
**F5** and pick *Web - Chrome (local backend)*, or from a terminal:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines/local.json
```

Create the first administrator (the profile trigger deliberately assigns no
role, so promotion is an explicit step):

```powershell
python tools\local_backend\gateway.py create-user you@example.com "Passw0rd!" --super-admin
```

Only the identity service is emulated. The schema, the RLS policies, the
accounting transactions and the RPCs are the real ones, so this exercises the
parts most likely to be wrong. Storage, Realtime and Edge Functions are not
available and return `501` — run with
`--dart-define=ENABLE_REALTIME=false`.

**It is not a deployment target.** No email, no rate limiting, no MFA, and a
signing secret committed to this repository; it binds to loopback only. See
[`tools/local_backend/README.md`](tools/local_backend/README.md) for the full
picture and `docs/DEPLOYMENT.md` for the real thing.

---

## Verify locally

```bash
dart analyze                  # must report zero issues
dart format --output=none --set-exit-if-changed lib test
flutter test                  # unit + widget tests
flutter build web --release
flutter build apk --release
```

---

## Project layout

```
lib/
├── config/       app, environment, theme, route and Supabase configuration
├── core/         constants, enums, errors, network, utils, validators
├── common/       shared widgets, controllers, models, layouts
├── features/     one folder per business module, each with
│                 models / controllers / repositories / services /
│                 bindings / views / widgets
├── services/     long-lived singletons (auth, storage, sync, local DB, ...)
├── routes/       route table and middleware guards
└── main.dart

supabase/migrations/   ordered, executable SQL migrations
docs/                  architecture, database, RBAC, deployment, testing
```

Data always flows `Controller → Repository → Service → Supabase / Local DB`.
A view never touches Dio or Supabase directly.

---

## Security model

Authorization is enforced in five layers, and the Flutter client is only the
outermost and least trusted of them:

```
Flutter UI (hides what you cannot use)
        +
GetX permission checks (fail fast with a clear message)
        +
Supabase Row Level Security (the actual boundary)
        +
Database constraints (uniqueness, checks, foreign keys)
        +
Server-side transactions (atomic, validated business operations)
```

Every permission check in the client is a *projection* of server-side
authority, cached so the UI can decide what to draw. Patching the client to
show a hidden button produces a request that fails with a 403 — it does not
grant access. Consequently:

- Permissions and roles are resolved in **one** `current_user_context()` call,
  not a chain of client queries. Doing it client-side would require RLS
  policies that themselves need the user's context, which is how recursive
  policy evaluation deadlocks.
- The showroom selected in the switcher is a UI preference. It is re-validated
  against the user's assignments on every sign-in, and `can_access_showroom()`
  independently rejects any query for a showroom the user cannot see.
- Passwords are never persisted. The only retained credential is Supabase's
  refresh token, held in the platform secure store.
- The logger redacts bearer tokens, JWTs, signed-URL query parameters and a
  list of sensitive field names at every nesting depth — unconditionally, not
  only in production.

---

## Known toolchain issues

### Android: Kotlin incremental cache

On JDK 18 the Kotlin build-tools API fails plugin compilation with
`Could not close incremental caches`. `android/gradle.properties` therefore
sets:

```properties
kotlin.incremental=false
kotlin.compiler.execution.strategy=in-process
```

Incremental compilation is a rebuild-speed optimisation only, so disabling it
is safe. **Remove both lines once the project standardises on JDK 17 or 21**,
which do not exhibit the fault.

### Android: plugin `compileSdk`

`flutter_plugin_android_lifecycle` publishes AAR metadata requiring API 36,
while its consumers (`image_picker`, `file_picker`) still declare an older
`compileSdk`, so their `checkAarMetadata` task fails. `android/build.gradle.kts`
raises `compileSdk` to 36 across all plugin subprojects. Remove once the
plugins ship with 36 or later.

### Android: core library desugaring

`flutter_local_notifications` uses `java.time` to schedule reminders, so
`isCoreLibraryDesugaringEnabled` is on and `desugar_jdk_libs` is a dependency.
This is required, not a workaround.

---

## Implementation status

The specification defines an eleven-phase delivery sequence. Current state:

**Phase 1 — Foundation: complete and verified.**

Flutter project for all four platforms, strict analysis clean, design system,
domain enums, permission catalogue, error hierarchy and mapper, redacting
logger, exact-decimal money arithmetic, EMI calendar arithmetic, validators,
Dio interceptor stack, connectivity, three-tier storage, swappable local
database, auth service, session/RBAC controller, route guards, auth screens.
**86 Dart tests pass.**

**Phase 2 — Database: complete and verified.**

18 migrations covering 46 tables, 18 reporting views, 236 indexes, 69
functions, 100 triggers, 157 RLS policies and 9 storage buckets.

All of it executed against a real PostgreSQL 17 database:

- every migration applies cleanly to a **brand-new database**, in order
- every migration is **idempotent** (applied twice, no errors)
- the permission catalogue is a **byte-for-byte match** with the Dart client
  (122 permissions, verified by diff)
- **22/22 SQL assertions pass**, including multi-tenant isolation and a full
  end-to-end sale with a balanced ledger

**Phase 3 — Showroom / User / Role management: complete and verified.**

- Generic `SupabaseRepository<T>` base (pagination, search, sort, filters,
  soft delete, optimistic-concurrency `update`, RPC) that every feature
  repository builds on
- Generic `ListController<T>` base for every paginated list screen
- The permission-aware navigation shell (§37): sidebar + top bar on desktop,
  drawer + bottom nav on mobile, built from one shared menu source
- Showrooms: list, create, edit
- Roles: list, create/rename custom roles, and a permission-matrix editor
  backed by a new atomic `set_role_permissions()` RPC (`016_role_permission_
  management.sql`) so a partial save can never leave a role holding zero
  permissions
- Users: list, edit profile, deactivate/reactivate, and a role/showroom
  assignment screen — the "controlled onboarding" step §83 requires after the
  auth trigger creates a bare profile
- An `invite-user` Supabase Edge Function (`supabase/functions/invite-user/`)
  so an administrator can create an account for someone else without the
  service-role key ever reaching the Flutter client — written in full,
  **not verified by execution** (no Deno runtime available here; flagged
  honestly, the same way the Windows/iOS build gap is)

Verified against a **live PostgREST server**, not just `psql`: a Dart
integration suite (`test/integration/`, skipped by default, real HTTP against
a real PostgREST + PostgreSQL instance) proves `SupabaseRepository`'s
generated query chains actually work end to end — paginated list with an
exact count, create, getById, substring search, an optimistic-concurrency
update that both succeeds and correctly refuses a stale revision, a soft
delete that's hidden by default and recoverable, and RLS refusing a showroom
the caller can't reach. **8/8 pass.** Two real bugs were only caught this
way (see `supabase/tests/README.md`): PostgREST only populates the JSON
`request.jwt.claims` GUC, not the per-claim style some docs describe; and a
custom GUC resets to `''`, not `NULL`, after a transaction that touched it
ends — a distinction that matters for exactly the kind of defensive parsing
`auth.uid()` needs. **92 Dart tests pass** (up from 86); analyzer clean.

**Phase 4 — Products, inventory, customers, vehicles: complete and verified.**

- **Products**: the shared catalogue — brands, products with colour and image
  children, a category filter, and a colour editor that retires rather than
  deletes (units in stock and past sales still reference the colour). The
  catalogue is deliberately *not* showroom-scoped: a Honda is a Honda at every
  branch, and duplicating it per branch would break group-wide stock reports.
- **Inventory**: one row per physical machine, scoped to a branch. Stock-code
  allocation through `next_document_number`, a status summary that doubles as
  a filter, an ageing-stock warning, and status changes routed through the
  `adjust_inventory` RPC so the transition is validated and the reason
  recorded — never a bare `UPDATE status`.
- **Stock history**: the movement ledger, branch-wide or per unit. Read-only
  by construction; rows come from the `record_stock_movement` trigger.
- **Customers**: branch-scoped, with customer-code allocation, an advisory
  duplicate-phone check before a second record is created, and a GST number
  required for corporate/dealer/government buyers only.
- **Vehicles**: customer-owned machines, kept distinct from `inventory` so a
  vehicle the showroom never sold can still be serviced. Warranty dates fill
  from the product's own warranty period, and a lapsed or lapsing insurance
  policy is coloured on the list row.

Two real defects were found and fixed on the way:

- `ListController.onInit()` called `GetxController.refresh()` — a widget
  rebuild — instead of `reload()`. **Every list screen in the application
  opened empty** and stayed empty until the user happened to search, sort or
  change page. Phases 1–3 shipped with this; a regression test now covers it.
- `PermissionMiddleware` could only require one permission, and the form
  routes named `<module>.create`. SERVICE MANAGER holds `customers.edit`
  without `customers.create`, so tapping Edit bounced them to the dashboard.
  The middleware now accepts `anyOfPermissions`, and the Phase 4 form routes
  use it.

**119 Dart tests pass** (up from 92), analyzer clean, release web build green.
A second live-server suite (`test/integration/catalogue_repositories_
integration_test.dart`, **14/14**) exercises what a unit test cannot falsify:
the multi-level PostgREST embeds each repository declares, the two RPCs stock
intake depends on, and each model against the exact JSON a real server
returns. That suite caught three mismatches between the client and the
database that unit tests with hand-written fixtures had happily accepted —
`AppValidators.hexColor` accepts `#ABC` while `product_colors_hex_check` does
not; `adjust_inventory` requires a five-character reason where the dialog
asked for three; and it writes that reason to the unit's own notes, not to the
movement row the UI claimed.

**Not included**: product image *upload*. The model, repository and display
path exist, so a product that already has images renders everywhere; the
upload UI needs the storage layer and arrives with Phase 9.

**Phase 5 — Sales, billing, payments, finance, EMI: complete and verified.**

Every write in this phase is a **server-side transaction**, never an insert
from the client:

- **Sales**: `create_sale_transaction` prices each line from the catalogue,
  locks the unit `FOR UPDATE` so two salespeople cannot sell the same bike,
  allocates the stock, registers the customer's vehicle, raises the invoice,
  posts the balanced accounting entries, records the down payment and — for a
  financed sale — builds the loan and its whole EMI schedule. All of it in one
  transaction. The create screen's totals are a **preview**; the server
  recomputes them, so a tampered form cannot set its own price.
- **Billing**: invoices, laid out as they print, with the GST breakdown per
  line and the total in words. Read-only by construction — an issued invoice
  is immutable, and `guard_invoice_immutability` enforces it.
- **Payments**: `record_payment` refuses a non-cash tender with no reference
  (it could never be reconciled) and refuses an overpayment rather than
  leaving a negative balance. Reversal writes a **contra** row and keeps the
  original: the customer holds a receipt for it.
- **Finance**: financiers, loans, and a details screen showing the schedule
  and the cost of credit — which on a FLAT agreement is markedly higher than
  the nominal rate suggests.
- **EMI collections**: overdue / due-soon / all-outstanding views with
  one-tap collection. `emi_schedules` has no `showroom_id`, so tenancy is
  applied through `loans!inner(...)` and a `loans.showroom_id` filter, exactly
  as the RLS policy reads it.

**153 Dart tests pass** (up from 123). A third live-server suite
(`test/integration/transaction_repositories_integration_test.dart`, **12/12**)
runs the whole money path against a real server: a cash sale totalling
correctly and moving the unit to SOLD, every embed resolving (`sales`
references `users` four times, so the salesperson embed must name its foreign
key or PostgREST rejects the request outright), a payment moving the invoice
balance, a cheque without a reference being refused, an overpayment being
refused, a reversal restoring the balance while keeping the receipt, a
financed sale whose 24-instalment schedule amortises to exactly the principal,
branch filtering through the embedded loan, a cancellation returning the unit
to stock, and the trial balance still summing debits to credits afterwards.

Across all three live suites: **34/34**.

**Phase 6 — Purchases, expenses, accounting: complete and verified.**

The other side of the same ledger a sale posts to:

- **Purchases**: `create_purchase_transaction` raises the order and posts the
  payable; **receiving is a separate act** through `receive_purchase`, because
  ordering and delivery happen days apart and the chassis numbers are not
  known until the lorry arrives. The receiving screen expands each line's
  quantity into that many chassis/engine entries and requires all of them —
  the RPC marks the whole order RECEIVED and refuses a second attempt, so a
  half-entered consignment would strand the remaining machines.
- **Suppliers**: shared across branches, like brands and financiers, so one
  distributor's payable balance is not fragmented per showroom.
- **Expenses**: `create_expense_transaction` posts the double-entry pair
  against the category's account. Approval enforces **separation of duties** —
  you cannot approve an expense you recorded — with an explicit super-admin
  exemption the client now mirrors exactly.
- **Accounting**: the chart of accounts (identical codes at every branch, which
  is what lets branch figures be summed), the journal with every posting and
  its lines, and the trial balance, which states plainly whether debits equal
  credits rather than leaving the reader to add up.

### A real defect this phase found

`receive_purchase` credited the supplier with the purchase's **full total**
while debiting only the goods and the tax. `other_charges` was on the credit
side and nowhere on the debit side, so any consignment with freight was
**impossible to receive**: `assert_ledger_balanced` refused the transaction and
rolled the whole thing back with

```
Accounting entry is not balanced: debits 192000.00, credits 194000.00
```

A purchase with no freight balanced by coincidence, which is why it survived
until one with freight was actually received.
[`017_fix_purchase_receipt_balance.sql`](supabase/migrations/017_fix_purchase_receipt_balance.sql)
adds the missing debit to `5104 Transport Expense`. It is **expensed rather
than capitalised into `1004 Inventory` deliberately**: `inventory.purchase_price`
is what cost of goods sold is derived from, so account 1004 must stay equal to
the sum of per-unit costs or the asset account and the stock ledger drift apart
permanently.

**172 Dart tests pass** (up from 153), and a fourth live-server suite
(`test/integration/ledger_repositories_integration_test.dart`, **11/11**) runs
the purchase-to-ledger path end to end — including the freight case that used
to fail. All 18 migrations still apply cleanly, in order, to a brand-new
database.

Across all four live suites: **45/45**.

**Phases 7–11 — outstanding.**

7. Service, warranty, insurance screens
8. Reminders, notifications, FCM wiring
9. Reports, PDF, Excel/CSV export
10. Offline sync and conflict resolution
11. Full test matrix, optimisation, security audit, deployment

The server contract is fixed and proven, and the repository/list-controller
base plus the navigation shell mean each remaining feature is now a smaller
increment than the last one was. Money now flows end to end and balances:
bought, received, sold, invoiced, collected, financed, expensed and
reconciled, with the trial balance to prove it.

---

## Documentation

| File | Contents |
| ---- | -------- |
| `docs/ARCHITECTURE.md` | Layering, data flow, state management, key decisions |
| `docs/DATABASE.md` | Schema, relationships, indexes, constraints |
| `docs/RBAC.md` | Roles, permissions, RLS helper functions |
| `docs/OFFLINE_SYNC.md` | Queue, conflict rules, replay |
| `docs/DEPLOYMENT.md` | Per-platform builds, CI secrets, migrations |
| `docs/API.md` | RPC contracts |
| `docs/TESTING.md` | Test strategy and how to run each layer |
