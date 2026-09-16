# Database

PostgreSQL, running on Supabase. 46 tables, 18 reporting views, 236 indexes,
69 functions, 100 triggers, 157 RLS policies, 9 storage buckets.

Every migration in `supabase/migrations/` has been executed against a clean
PostgreSQL 17 database, in order, twice (to prove idempotency), and the two SQL
test suites pass 22/22 assertions against the result.

---

## Applying the migrations

```bash
# Supabase CLI, against a linked project
supabase db push

# or directly
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/001_extensions.sql
# ... in filename order
```

They run in lexical filename order and are safe to re-run: every object uses
`create ... if not exists` or `create or replace`, and every seed uses
`on conflict do nothing` / `do update`.

### After the first deploy

The migrations deliberately create **no showroom and no user**. A migration
that created a showroom would put fictional data into production, and one that
created an administrator would put a known credential in source control.

1. Create the first account through Supabase Auth (dashboard or `signUp`).
2. Promote it, from the Supabase SQL editor:

   ```sql
   select public.bootstrap_super_admin('you@yourcompany.com');
   ```

   This refuses to run once a SUPER ADMIN exists, so it cannot become a
   standing privilege-escalation path.
3. Sign in. Create showrooms, then onboard the rest of the team from Settings.

---

## Migration files

| File | Contents |
| ---- | -------- |
| `001_extensions.sql` | pgcrypto, pg_trgm, unaccent, btree_gist; the `money_amount` / `percentage` domains; phone, financial-year and month-arithmetic helpers |
| `002_core_schema.sql` | showrooms, users, roles, permissions, assignments, device tokens, document sequences, attachments, audit logs |
| `003_business_schema.sql` | brands, products, colours, images, inventory, stock transfers and movements, customers, vehicles, sales, invoices, payments |
| `004_finance_service_schema.sql` | finance companies, loans, EMI schedules, suppliers, purchases, expenses, service records, free-service plans, warranty, insurance, reminders, notifications, chart of accounts |
| `005_indexes.sql` | 236 indexes: foreign keys, showroom-led composites, partial indexes for open work, GIN trigram indexes for search |
| `006_functions.sql` | authorisation helpers, `current_user_context()`, document numbering, EMI mathematics, the accounting primitive |
| `006b_transaction_functions.sql` | the atomic business operations (sale, payment, service, purchase, expense, transfer) |
| `007_triggers.sql` | timestamps, revisions, provenance, audit logging, safety interlocks |
| `008_roles_permissions.sql` | 13 roles, 122 permissions, 654 grants |
| `009_rls.sql` | 157 Row Level Security policies |
| `010_storage.sql` | 9 buckets and their object policies |
| `011_reporting_views.sql` | 18 reporting views, dashboard and trend functions, global search |
| `012_reminders.sql` | reminder generators, dispatch, nightly maintenance job |
| `013_accounting.sql` | balance invariant, per-showroom chart of accounts, P&L |
| `014_seed_data.sql` | settings, brands, default free-service plan, finance companies |
| `015_auth_triggers.sql` | auth-to-profile bridge, administrator bootstrap |

`006b` is a continuation of `006`, split for file size; lexical ordering places
it correctly between `006` and `007`.

---

## Core relationships

```
SHOWROOM (tenancy root)
   │
   ├── users ──── user_roles ──── roles ──── role_permissions ──── permissions
   │      └────── user_showrooms  (access beyond the home branch)
   │
   ├── customers
   │      └── customer_vehicles ─┬── warranties
   │                             ├── insurance_policies
   │                             ├── vehicle_free_services
   │                             └── service_records ── service_items
   │
   ├── inventory ──┬── stock_movements   (append-only ledger)
   │               └── stock_transfers   (between two showrooms)
   │
   ├── sales ── sale_items
   │      └── invoices ── invoice_items
   │             └── payments
   │
   ├── loans ── emi_schedules
   ├── purchases ── purchase_items
   ├── expenses
   ├── reminders / notifications
   └── accounting_transactions ── accounting_entries
```

The customer lifecycle runs
`customer → vehicle → sale → invoice → payment → loan → EMI → service →
warranty → insurance → reminders`, and each step is a foreign key, not a copy:
a customer's name exists in exactly one row.

---

## Design decisions

### Enum values are CHECK constraints, not native enum types

Adding a value to a native PostgreSQL enum cannot run inside a transaction on
older servers, which breaks migration atomicity. A CHECK list is also directly
diffable against the Dart enum declarations, and
`test/unit/permission_catalog_test.dart` plus a SQL cross-check keep the two
vocabularies aligned.

### Money is `numeric(14,2)`, never float

`numeric` is exact. Float arithmetic drifts, and the ledger asserts
`debits = credits` — a drifting sum would fail that assertion at random.

### Document numbers use a locked counter, not a sequence

PostgreSQL sequences are non-transactional: a rolled-back sale would consume
an invoice number and leave a permanent gap. Tax authorities expect invoice
numbers to be contiguous within a financial year, so `next_document_number()`
locks a row in `document_sequences` with `FOR UPDATE` inside the caller's
transaction. A rollback returns the number to the pool.

The trade is throughput on a counter touched once per document, in exchange for
a statutory property. That is the right way round.

### Chassis and engine numbers are globally unique

Not per showroom. These identify a vehicle nationally; a duplicate almost
always means the same bike was entered twice. Customer phone numbers, by
contrast, are unique *per showroom*, because two branches may legitimately
serve the same person.

### `audit_logs` has no foreign keys

An audit entry is a historical snapshot. `ON DELETE SET NULL` would erase the
attribution on exactly the entries that matter most, and the audit trigger
firing *during* a delete would insert a row referencing the record being
deleted — failing the delete. The identifiers are plain uuids and `old_data`
holds the whole row.

### Financial rows cannot be deleted

`guard_no_financial_delete()` refuses `DELETE` on payments, accounting
transactions and entries, audit logs, stock movements and EMI schedules.
Cancellation and reversal states exist so deletion is never needed, and a
reversal writes a mirror-image journal rather than editing history.

### Issued invoices are immutable

`guard_invoice_immutability()` blocks any change to the amounts, number,
customer or date of an invoice that has left `DRAFT`, and
`guard_invoice_items_immutability()` blocks line-item changes. Corrections go
through cancellation or a credit note. A tax invoice that silently changes
after issue is a compliance problem and desynchronises every printed copy.

### Business logic lives in RPCs, not triggers

Triggers here do mechanical bookkeeping (timestamps, revisions, provenance,
audit, stock movements) and enforce interlocks. They never compute a total or
post to the ledger.

A sale touches eleven tables. As a cascade of triggers it would be a sequence
of invisible side effects firing in an order nobody can see. As
`create_sale_transaction()` it is one readable function that either commits
completely or leaves nothing behind — which `sale_transaction_test.sql` proves
by engineering a failure at the loan step and asserting that the sale, invoice,
stock allocation and ledger postings written before it do not survive.

---

## Security model

### Two independent questions per row

```
can_access_showroom(showroom_id)   -- is this row in a branch I'm assigned to?
has_permission(module, action)     -- may I do this kind of thing at all?
```

Both must hold. A SALES MANAGER at branch A cannot read branch B's sales even
holding `sales.view`; a TECHNICIAN at branch A cannot create a sale even though
they are inside branch A.

### SECURITY DEFINER and RLS recursion

The authorisation helpers read `users`, `user_roles` and `role_permissions` —
tables whose own RLS policies call those same helpers. Evaluating a policy
would re-enter the policy.

`SECURITY DEFINER` breaks the cycle: the function runs as the table owner, and
an owner is exempt from that table's RLS unless `FORCE ROW LEVEL SECURITY` is
set. This schema deliberately never sets `FORCE`. The owner role is not used by
the application at runtime — PostgREST connects as `authenticated` — so nothing
that matters is exempted.

Every `SECURITY DEFINER` function pins `search_path`. Without that, a caller
could create a malicious `users` table in a schema earlier on their own
`search_path` and the definer-rights function would read it — a real
privilege-escalation route.

### Views must set `security_invoker`

A view executes with its **owner's** privileges by default. Because these views
are owned by an RLS-exempt role, a default view would return every showroom's
rows to any caller — a complete tenancy bypass, invisible until someone notices
another branch's figures on their dashboard.

Every view sets `with (security_invoker = true)`, and `011_reporting_views.sql`
**fails the migration** if any view is missing it.

### Verified, not assumed

`supabase/tests/rls_isolation_test.sql` runs as `authenticated` with a
simulated JWT — exactly how PostgREST executes a request — and proves:

| Assertion | Result |
| --------- | ------ |
| Manager A sees only branch A's customers | pass |
| Manager B sees only branch B's (symmetric) | pass |
| Manager A cannot see branch B in `showrooms` at all | pass |
| Manager A cannot write a customer into branch B | pass |
| A VIEWER can read but cannot create | pass |
| `has_permission` matches the seeded grants | pass |
| `current_user_context` exposes only reachable showrooms | pass |
| A SUPER ADMIN sees both branches | pass |

Running as the table owner would bypass RLS and prove nothing, which is why the
suite sets the role explicitly.

---

## Accounting

Double-entry, per showroom. Account **codes** are identical across branches
(every branch's cash account is `1001`), which lets the business functions post
by code without knowing which branch they are in, while each branch still
reports its own P&L.

| Range | Type | Examples |
| ----- | ---- | -------- |
| 1xxx | Asset | 1001 Cash, 1002 Bank, 1003 Customer Receivable, 1004 Inventory, 1005 Input Tax Credit |
| 2xxx | Liability | 2001 Supplier Payable, 2002 Tax Payable, 2003 Customer Advance |
| 3xxx | Equity | 3001 Owner Capital, 3002 Retained Earnings |
| 4xxx | Income | 4001 Vehicle Sales, 4002 Service Revenue, 4003 Other Income |
| 5xxx | Expense | 5001 COGS, 5101 Rent, 5103 Salary, 5199 Other |

A showroom's accounts are provisioned automatically by a trigger on insert, so
a branch can never exist in a state where its first sale fails on a missing
account.

### The balance invariant

`assert_ledger_balanced()` is a `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY
DEFERRED`. That is the only mechanism that works: the check must run once,
after all of a transaction's lines are written. A plain `AFTER ROW` trigger
would fire on the first line and fail every time, because a single debit with
no matching credit is never balanced.

Posting for a sale of ₹218,500 with a ₹50,000 UPI payment:

```
Sale     DR 1003 Customer Receivable   218,500
         CR 4001 Sales Revenue         175,000
         CR 2002 Tax Payable            31,500
         CR 4003 Other Income           12,000

Payment  DR 1002 Bank                   50,000
         CR 1003 Customer Receivable    50,000
                                       ─────────
         debits 268,500 = credits 268,500
```

That exact figure is asserted by `sale_transaction_test.sql`.

---

## EMI

```
EMI = P × r × (1+r)^n / ((1+r)^n − 1)
```

`r` is the monthly rate as a fraction, `n` the tenure in months. `numeric ^
numeric` keeps full precision; `float8` would drift over a long tenure and
shift the final instalment by rupees. Zero-rate promotional finance is handled
separately, since the formula divides by zero at `r = 0`. `FLAT` interest is a
different product and is computed on the full principal for the whole tenure.

Verified: ₹1,00,000 at 12% over 12 months → **₹8,884.88**, the textbook figure,
matching explicit arithmetic to the paisa.

The whole schedule is generated at loan creation, so the customer has their
complete plan from day one. Two details matter:

* Due dates use `add_months()`, which **clamps to month end**. A loan starting
  31 January bills on 28 (or 29) February, never 3 March. The client's
  `DateUtil.addMonths` implements the identical rule, and both are tested.
* The **final instalment absorbs accumulated rounding**, so the principal
  column sums to the loan amount exactly and the balance closes at zero.
  Without this the loan ends a few paise short and never closes cleanly.

---

## Reminders

Generated on a schedule at offsets the client also knows
(`AppConstants.emiReminderOffsetDays`): EMI at 7/3/1/0 days, service at 15/7/0,
insurance at 30/15/7/1, warranty at 30/7. Payment reminders run weekly, on
Mondays — an outstanding invoice does not become more urgent every day, and
daily chasing damages the relationship.

Every generator is **idempotent**, relying on the partial unique index
`reminders_dedupe_key` with `ON CONFLICT DO NOTHING`. A scheduler that runs a
job twice is a normal occurrence; duplicate reminders reaching a customer are
worse than none.

`run_daily_maintenance()` is the single scheduled entry point. Order matters
and is explicit: derived statuses are refreshed **before** reminders are
generated, otherwise an instalment that became overdue overnight would not be
picked up until the following day.

It is scheduled with `pg_cron` at 01:30 UTC (07:00 IST) when the extension is
enabled; otherwise the migration leaves a notice and the function should be
called from a scheduled Edge Function.

---

## Storage

| Bucket | Public | Contents |
| ------ | ------ | -------- |
| `product-images` | yes | Catalogue photography |
| `showroom-assets` | yes | Logos and branding |
| `customer-documents` | **no** | Identity and address proof |
| `vehicle-documents` | **no** | Registration, delivery notes |
| `invoice-documents` | **no** | Generated invoice PDFs |
| `service-documents` | **no** | Job cards, inspection photos |
| `insurance-documents` | **no** | Policy documents |
| `warranty-documents` | **no** | Warranty cards, claims |
| `expense-attachments` | **no** | Receipts and bills |

A public Supabase bucket means anyone with the URL can read the object forever,
unauthenticated and unaudited. For a customer's identity document that is
unacceptable, so only marketing material is public and everything else is
reached through short-lived signed URLs.

Every object is stored as `<showroom_id>/<entity_type>/<entity_id>/<filename>`,
and the policies match on the first path segment against
`can_access_showroom()`. **The path convention is load-bearing**, not
cosmetic — `SupabaseConfig.storagePath()` is the only place that composes it.

`010_storage.sql` fails the migration if a bucket holding confidential data is
ever marked public.

---

## Running the tests

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/sale_transaction_test.sql
```

Both create their own fixtures, assert, and clean up after themselves. They are
safe to run against a development database and should **never** be run against
production — they create and delete showrooms.
