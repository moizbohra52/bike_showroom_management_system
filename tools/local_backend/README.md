# Local development backend

Runs the application with **no Supabase account and no API keys**, against a
real PostgreSQL database with this project's real migrations, RLS policies and
RPCs applied.

> **Development only.** The identity service here is an emulation, not Supabase
> Auth. It sends no email, enforces no rate limit, has no MFA, and signs tokens
> with a development secret that lives in this repository. It binds to the
> loopback interface and refuses to do otherwise. For anything real, use a
> Supabase project — see [`docs/DEPLOYMENT.md`](../../docs/DEPLOYMENT.md).

---

## Why it exists

Supabase is three services behind one origin. The Flutter client assumes that
layout and cannot be pointed at a bare database:

```
                     ┌─ /auth/v1/*      GoTrue      ─┐
Flutter ── origin ───┼─ /rest/v1/*      PostgREST   ─┼── PostgreSQL
                     └─ /storage/v1/*   Storage     ─┘
```

Normally you get that origin from a Supabase cloud project (needs an account)
or from `supabase start` (needs Docker Desktop). When neither is available,
`gateway.py` provides the same origin on `http://127.0.0.1:54321`: it answers
`/auth/v1` itself and forwards `/rest/v1` to a local PostgREST.

What is genuine: the schema, every constraint, all 157 RLS policies, the
double-entry accounting transactions, the permission model. What is emulated:
only the issuing of tokens. That split is the point — the parts that are easy
to get wrong are the real ones.

What is **not** available: Storage (file uploads), Realtime, and Edge
Functions. Those endpoints return `501` with an explanatory message rather than
failing obscurely. Run with `--dart-define=ENABLE_REALTIME=false`.

---

## Prerequisites

- Python 3.9+ on `PATH` (standard library only — nothing to install)
- A `.localdev/` directory containing:

```
.localdev/
├── pg/pgsql/bin/…      PostgreSQL 17 binaries (the zipped Windows build)
├── pgdata/             an initialised cluster
└── postgrest/          postgrest.exe
```

`.localdev/` is git-ignored. To build it from scratch:

```powershell
# PostgreSQL — "Windows x86-64 binaries" zip from
# https://www.enterprisedb.com/download-postgresql-binaries
Expand-Archive postgresql-17.2-1-windows-x64-binaries.zip -DestinationPath .localdev\pg

# PostgREST — the Windows release from
# https://github.com/PostgREST/postgrest/releases
Expand-Archive postgrest-v16.3-windows-x64.zip -DestinationPath .localdev\postgrest

# Initialise the cluster (trust auth is fine: loopback only, no real data)
.localdev\pg\pgsql\bin\initdb.exe -D .localdev\pgdata -U postgres -A trust -E UTF8
```

---

## Start

```powershell
# First run: also create the database and apply every migration
.\tools\local_backend\start.ps1 -Init

# Later runs
.\tools\local_backend\start.ps1
```

`-Init` drops and rebuilds `bsms_dev`, applies
`supabase/tests/00_supabase_shim.sql` (the stand-in for the `auth`/`storage`
schemas and the `anon`/`authenticated` roles that Supabase provides), then
every file in `supabase/migrations/` in filename order.

Stop everything with `.\tools\local_backend\stop.ps1`.

---

## Running the app

The backend values are **compiled into** the Flutter build, so they have to be
supplied at launch. A build that omits them stops on a "This build is not
configured" screen naming the missing keys — which is exactly what the IDE's
bare Run button produces.

They live in [`dart_defines/local.json`](../../dart_defines/local.json):

```bash
flutter run -d chrome --dart-define-from-file=dart_defines/local.json
```

In VS Code, press **F5** and pick a configuration from
[`.vscode/launch.json`](../../.vscode/launch.json) — each one already passes
that file. Don't use *Run Without Debugging* on a bare `main.dart`; it skips
the launch configuration and therefore the defines.

On an **Android emulator or handset**, `127.0.0.1` means the device itself and
the gateway binds to the workstation's loopback only. Forward the port instead
of re-binding it:

```bash
adb reverse tcp:54321 tcp:54321
```

---

## Accounts

The profile trigger (`015_auth_triggers.sql`) deliberately gives a new account
**no role and no showroom** — provisioning is an explicit administrative act,
not a side effect of signing up. So the first administrator has to be promoted
once:

```powershell
python tools\local_backend\gateway.py create-user you@example.com "Passw0rd!" --super-admin
```

Other commands:

| Command | Purpose |
| ------- | ------- |
| `create-user EMAIL PASSWORD [--name N] [--super-admin]` | Create an account |
| `set-password EMAIL PASSWORD` | Reset a password (no email is sent, so this replaces the recovery flow) |
| `list-users` | Show every account with its profile, roles and showroom |
| `print-keys` | Print the anon key for `--dart-define` |
| `serve` | Run the gateway in the foreground |

Demo data (two showrooms — one branch would hide tenancy bugs):

```powershell
.localdev\pg\pgsql\bin\psql.exe -h 127.0.0.1 -p 55432 -U postgres -d bsms_dev -f tools\local_backend\seed_demo.sql
```

---

## Configuration

Every value is an environment variable with a working default:

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `BSMS_PGDATABASE` | `bsms_dev` | Database name |
| `BSMS_PGPORT` | `55432` | PostgreSQL port (deliberately not 5432, so it cannot collide with an installed server) |
| `BSMS_POSTGREST_PORT` | `3010` | PostgREST port |
| `BSMS_GATEWAY_PORT` | `54321` | The origin the app talks to |
| `BSMS_JWT_SECRET` | a fixed development string | **Must match PostgREST's `jwt-secret`** |
| `BSMS_PSQL` | `.localdev/pg/pgsql/bin/psql.exe` | Path to `psql` |

If the gateway and PostgREST disagree about the secret, every authenticated
request silently falls back to the anonymous role and RLS hides everything —
the symptom is a working login followed by empty screens.

---

## Moving to a real Supabase project

Nothing in the application knows this gateway exists; it is selected entirely
by `--dart-define=SUPABASE_URL`. Point that at a Supabase project instead and
the same build runs against it, with Storage and Realtime working. The
migrations are the same files.

See [`docs/DEPLOYMENT.md`](../../docs/DEPLOYMENT.md).
