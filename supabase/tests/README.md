# SQL and integration tests

Two kinds of test live here, both exercising the real backend rather than a
mock:

| Kind | File(s) | What it proves |
| ---- | ------- | --------------- |
| SQL | `rls_isolation_test.sql`, `sale_transaction_test.sql` | The database itself: RLS isolation, atomic transactions, the ledger balance invariant |
| Dart integration | `../../test/integration/*.dart` | `SupabaseRepository`'s generated PostgREST query chains, against a live server |

Both require a local PostgreSQL with every migration in `supabase/migrations/`
applied. **Never point either at production** — the SQL tests create and
delete showrooms; the Dart tests create and delete customers.

---

## 1. A local PostgreSQL with the schema

Any PostgreSQL 15+ works. `initdb`, start it, then:

```bash
psql -d yourdb -v ON_ERROR_STOP=1 -f supabase/tests/00_supabase_shim.sql
for f in supabase/migrations/*.sql; do
  psql -d yourdb -v ON_ERROR_STOP=1 -f "$f"
done
```

`00_supabase_shim.sql` is **not** part of the application migrations — it
stands in for the parts of a Supabase project that exist before any migration
runs: the `auth`/`storage` schemas, the `anon`/`authenticated`/`service_role`
roles, and `auth.uid()` / `auth.role()` / `auth.email()`. On a real Supabase
project all of this already exists; the shim exists only so the migrations
(which call `auth.uid()` throughout) have something to call locally.

```sql
-- supabase/tests/00_supabase_shim.sql
create schema if not exists auth;
create schema if not exists storage;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Reads the JSON claims GUC PostgREST actually sets. Confirmed empirically
-- against PostgREST 16.3: it populates ONLY `request.jwt.claims` (one JSON
-- blob), not the older per-claim `request.jwt.claim.sub` style some docs
-- describe. Real Supabase's own auth.uid() reads the same GUC.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid;
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '')::text;
$$;
create or replace function auth.email() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'email', '')::text;
$$;

create table if not exists storage.buckets (
  id text primary key, name text not null, public boolean default false,
  file_size_limit bigint, allowed_mime_types text[], created_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets(id),
  name text, owner uuid, metadata jsonb, created_at timestamptz default now()
);
create or replace function storage.foldername(name text) returns text[]
  language sql immutable as $$ select string_to_array(name, '/'); $$;
alter table storage.objects enable row level security;

grant usage on schema auth, storage to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant select on auth.users to anon, authenticated, service_role;
```

## 2. Run the SQL suites

```bash
psql -d yourdb -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation_test.sql
psql -d yourdb -v ON_ERROR_STOP=1 -f supabase/tests/sale_transaction_test.sql
```

Both create their own fixtures and tear them down; safe to re-run.

## 3. Run PostgREST for the Dart integration suite

The Dart suite talks HTTP to a real PostgREST, not to `psql`. PostgREST
serves at its own root; `package:supabase`'s client always requests
`<url>/rest/v1/...`, so a one-line path-stripping reverse proxy sits in
front of it. Any language can write this proxy — the sketch below is Python
because it needs no extra dependency.

```conf
# postgrest.conf
db-uri = "postgres://postgres@127.0.0.1:5432/yourdb"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "pick-any-secret-at-least-32-characters-long"
server-port = 3010
```

```bash
postgrest postgrest.conf &
python proxy.py 3011   # strips /rest/v1, forwards to 127.0.0.1:3010
```

A minimal path-stripping proxy (adjust `TARGET`/`PREFIX` as needed):

```python
import http.server, socketserver, sys, urllib.request, urllib.error

TARGET, PREFIX = "http://127.0.0.1:3010", "/rest/v1"

class Handler(http.server.BaseHTTPRequestHandler):
    def _forward(self):
        path = self.path[len(PREFIX):] or "/" if self.path.startswith(PREFIX) else self.path
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0) or None
        req = urllib.request.Request(TARGET + path, data=data, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req) as r:
                self._reply(r.status, r.getheaders(), r.read())
        except urllib.error.HTTPError as e:
            self._reply(e.code, e.headers.items(), e.read())
    def _reply(self, status, headers, body):
        self.send_response(status)
        for k, v in headers:
            if k.lower() not in ("transfer-encoding", "content-length", "connection"):
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
    do_GET = do_POST = do_PATCH = do_DELETE = do_PUT = do_HEAD = _forward
    def log_message(self, *a): pass

socketserver.ThreadingTCPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
```

Then create a fixture (a showroom, and a user in it holding a role with full
`customers.*` permissions — `SHOWROOM MANAGER` works):

```sql
insert into public.showrooms (name, code, status) values ('Test', 'ITEST', 'ACTIVE')
  returning id; -- note this
insert into auth.users (id, email) values ('<any-uuid>', 'it@test.local');
update public.users set showroom_id = '<showroom-id-above>', status = 'ACTIVE'
  where auth_user_id = '<any-uuid>';
insert into public.user_roles (user_id, role_id)
  select id, (select id from roles where name = 'SHOWROOM MANAGER')
  from public.users where auth_user_id = '<any-uuid>';
```

## 4. Run the Dart suite

```bash
SUPABASE_TEST_URL=http://127.0.0.1:3011 \
SUPABASE_TEST_JWT_SECRET=pick-any-secret-at-least-32-characters-long \
SUPABASE_TEST_SUB=<any-uuid from above> \
SUPABASE_TEST_SHOWROOM_ID=<showroom-id from above> \
  flutter test test/integration/
```

Without those four variables the suite reports itself skipped and
`flutter test` (run normally, with no server) is unaffected — this is what
keeps the integration suite out of everyone's everyday inner loop while still
being a real, runnable check of the wire format whenever the backend changes.

## What this combination has actually verified

- Every migration applies cleanly to a brand-new database, and again
  idempotently, in order (§ `DATABASE.md`).
- 8/8 RLS isolation assertions and 14/14 sale-transaction assertions, run as
  `psql` executing SQL directly.
- 8/8 assertions in the Dart integration suite, run as real HTTP requests
  through real PostgREST against the same database: paginated `list()` with
  an exact count, `create()`, `getById()`, substring search, an
  optimistic-concurrency `update()` that both succeeds and correctly refuses
  a stale revision, a soft `delete()` that is hidden by default and
  recoverable with `includeDeleted: true`, and RLS refusing a showroom the
  caller cannot reach.
