-- Local stand-in for the parts of a Supabase project that the migrations
-- depend on. NOT part of the application migrations: on a real Supabase
-- project all of this already exists and is managed by the platform.
create schema if not exists auth;
create schema if not exists storage;
create schema if not exists extensions;

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
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    create role supabase_admin login superuser;
  end if;
end $$;

grant anon, authenticated, service_role to authenticator;
grant usage on schema public to anon, authenticated, service_role;

-- auth.users, matching the columns the migrations actually reference.
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  encrypted_password text,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Matches the actual definitions Supabase's platform installs. PostgREST
-- (confirmed empirically against v16.3 running locally) only sets the single
-- JSON GUC `request.jwt.claims`; the per-claim `request.jwt.claim.X` GUCs
-- this shim used at first are not populated by stock PostgREST, which made
-- every authenticated call see a null uid. Reading the JSON claims blob
-- instead is also what real Supabase's `auth.uid()` does.
--
-- The `nullif(current_setting(...), '')` guard is load-bearing and must
-- wrap the RAW setting, before the `::jsonb` cast - not after. Once a custom
-- GUC has been touched by `SET LOCAL` inside any transaction in the session,
-- Postgres resets it to an empty string (not NULL) when that transaction
-- rolls back or ends; a later statement in the same session then calls
-- `current_setting(..., true)` and gets `''`, and `''::jsonb` raises
-- "invalid input syntax for type json", not a clean NULL. Guarding after the
-- cast (nullif(x::jsonb ->> 'sub', '')) does not help, because the cast has
-- already failed by that point. Confirmed by reproducing it directly: two
-- back-to-back transactions in one psql session, the second reading a GUC
-- only the first had set.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
    ''
  )::uuid;
$$;

create or replace function auth.role() returns text language sql stable as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    ''
  )::text;
$$;

create or replace function auth.email() returns text language sql stable as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email',
    ''
  )::text;
$$;

-- storage.buckets / storage.objects, enough for the storage policies to apply.
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid,
  metadata jsonb,
  created_at timestamptz default now()
);

create or replace function storage.foldername(name text)
returns text[] language sql immutable as $$
  select string_to_array(name, '/');
$$;

alter table storage.objects enable row level security;

-- On a real Supabase project these grants already exist; PostgREST switches
-- to the anon/authenticated role per request (`SET ROLE`), and without USAGE
-- on the auth schema plus EXECUTE on its functions, every call to
-- `auth.uid()` from an application query - which is most of them, since
-- every RLS policy depends on it - fails outright with "permission denied
-- for schema auth" rather than degrading to a null uid.
--
-- Placed at the END of this file, after auth.uid()/role()/email() and
-- storage.foldername() are created: `grant ... on all functions in schema X`
-- only affects functions that already exist at the moment it runs, so
-- granting it earlier would silently grant on nothing. Discovered by running
-- the actual test suites against a genuinely fresh database rather than
-- reusing one that had already accumulated ad-hoc local grants.
grant usage on schema auth, storage to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;
grant select on auth.users to anon, authenticated, service_role;

-- Covers any auth function a later revision of this shim adds, without
-- needing to remember to re-grant it here too.
alter default privileges in schema auth
  grant execute on functions to anon, authenticated, service_role;
