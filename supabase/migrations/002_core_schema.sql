-- =============================================================================
-- 002_core_schema.sql
--
-- Tenancy, identity and access control, plus the cross-cutting system tables.
--
-- Every business table added in later migrations carries `showroom_id` and is
-- isolated by the Row Level Security policies in 009_rls.sql. The tables here
-- are what those policies resolve against, so nothing else can be created
-- until they exist.
-- =============================================================================

-- =============================================================================
-- showrooms - the tenancy boundary
-- =============================================================================
create table if not exists public.showrooms (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  code            text not null,
  address         text,
  city            text,
  state           text,
  pincode         text,
  phone           text,
  email           text,
  gst_number      text,
  pan_number      text,
  -- Prefix for this showroom's generated document numbers, e.g. 'MUM'.
  invoice_prefix  text,
  logo_url        text,
  status          text not null default 'ACTIVE',
  -- Per-showroom configuration. jsonb so a new toggle needs no migration;
  -- read through the typed getters on ShowroomModel.
  settings        jsonb not null default '{}'::jsonb,

  is_deleted      boolean not null default false,
  deleted_at      timestamptz,
  deleted_by      uuid,
  revision        integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid,
  updated_by      uuid,

  constraint showrooms_code_key unique (code),
  constraint showrooms_status_check
    check (status in ('ACTIVE', 'INACTIVE')),
  constraint showrooms_code_format_check
    check (code ~ '^[A-Z0-9_-]{2,20}$'),
  constraint showrooms_pincode_check
    check (pincode is null or pincode ~ '^[1-9][0-9]{5}$'),
  constraint showrooms_gst_check
    check (gst_number is null or
           gst_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  constraint showrooms_pan_check
    check (pan_number is null or pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$')
);

comment on table public.showrooms is
  'Tenant root. Every business record belongs to exactly one showroom.';

-- =============================================================================
-- roles / permissions
-- =============================================================================
create table if not exists public.roles (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  description     text,
  -- System roles are seeded and resolved by name in is_super_admin() and the
  -- RLS policies, so they must not be renamed or deleted.
  is_system_role  boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint roles_name_key unique (name)
);

create table if not exists public.permissions (
  id           uuid primary key default gen_random_uuid(),
  module       text not null,
  action       text not null,
  description  text,
  created_at   timestamptz not null default now(),

  -- The client addresses permissions as 'module.action'; this guarantees that
  -- key is unique.
  constraint permissions_module_action_key unique (module, action)
);

comment on table public.permissions is
  'Permission catalogue. Mirrors AppPermissions.all on the client; kept in '
  'step by test/unit/permission_catalog_test.dart.';

-- =============================================================================
-- users - the application profile, distinct from auth.users
--
-- auth.users is owned by Supabase and holds the credential. This table holds
-- the business profile, the showroom assignment and the role links. Keeping
-- them separate lets an administrator deactivate a user or change their role
-- without touching the auth system, and lets the RLS helpers resolve
-- authorisation from one place.
-- =============================================================================
create table if not exists public.users (
  id             uuid primary key default gen_random_uuid(),
  auth_user_id   uuid not null,
  -- Home showroom. Null only for a SUPER ADMIN, who is not scoped to one.
  showroom_id    uuid references public.showrooms(id) on delete restrict,
  name           text not null,
  email          text,
  phone          text,
  status         text not null default 'ACTIVE',
  avatar_url     text,
  employee_code  text,
  designation    text,
  last_login_at  timestamptz,

  is_deleted     boolean not null default false,
  deleted_at     timestamptz,
  deleted_by     uuid,
  revision       integer not null default 1,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid,
  updated_by     uuid,

  constraint users_auth_user_id_key unique (auth_user_id),
  constraint users_status_check
    check (status in ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
  constraint users_email_check
    check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

-- Employee code is unique within a showroom, not globally: two showrooms may
-- legitimately both have an "EMP001".
create unique index if not exists users_showroom_employee_code_key
  on public.users (showroom_id, employee_code)
  where employee_code is not null and is_deleted = false;

-- auth.users is created by Supabase Auth before the profile trigger fires, so
-- the FK is added separately and is deferrable to keep signup resilient.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_auth_user_id_fkey'
  ) then
    alter table public.users
      add constraint users_auth_user_id_fkey
      foreign key (auth_user_id) references auth.users(id) on delete cascade
      deferrable initially deferred;
  end if;
end $$;

-- Self-referencing audit columns, added after the table exists.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'showrooms_created_by_fkey'
  ) then
    alter table public.showrooms
      add constraint showrooms_created_by_fkey
      foreign key (created_by) references public.users(id) on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'showrooms_updated_by_fkey'
  ) then
    alter table public.showrooms
      add constraint showrooms_updated_by_fkey
      foreign key (updated_by) references public.users(id) on delete set null;
  end if;
end $$;

-- =============================================================================
-- user_roles / role_permissions / user_showrooms
-- =============================================================================
create table if not exists public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  role_id     uuid not null references public.roles(id) on delete restrict,
  assigned_by uuid references public.users(id) on delete set null,
  created_at  timestamptz not null default now(),

  constraint user_roles_user_role_key unique (user_id, role_id)
);

create table if not exists public.role_permissions (
  id             uuid primary key default gen_random_uuid(),
  role_id        uuid not null references public.roles(id) on delete cascade,
  permission_id  uuid not null
                 references public.permissions(id) on delete cascade,
  created_at     timestamptz not null default now(),

  constraint role_permissions_role_permission_key
    unique (role_id, permission_id)
);

-- Additional showrooms a user may reach beyond their home showroom. A regional
-- manager covering three branches gets two rows here plus their home showroom.
create table if not exists public.user_showrooms (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  showroom_id  uuid not null
               references public.showrooms(id) on delete cascade,
  assigned_by  uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),

  constraint user_showrooms_user_showroom_key unique (user_id, showroom_id)
);

-- =============================================================================
-- device_tokens - FCM registration, one row per device per user
-- =============================================================================
create table if not exists public.device_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  device_token  text not null,
  platform      text not null default 'UNKNOWN',
  device_name   text,
  device_id     text,
  is_active     boolean not null default true,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint device_tokens_token_key unique (device_token),
  constraint device_tokens_platform_check
    check (platform in
      ('ANDROID', 'IOS', 'WEB', 'WINDOWS', 'MACOS', 'LINUX', 'UNKNOWN'))
);

comment on table public.device_tokens is
  'FCM tokens. A token is globally unique because the same device may be '
  'handed to a different user, and the token must then move with the person '
  'currently signed in rather than being duplicated.';

-- =============================================================================
-- document_sequences - gap-free, per-showroom document numbering
--
-- A PostgreSQL sequence cannot be used here: sequences are not transactional,
-- so a rolled-back sale would burn an invoice number and leave a gap. Tax
-- authorities expect invoice numbers to be contiguous within a financial year,
-- so the counter is a row that is locked and incremented inside the same
-- transaction as the document it numbers.
-- =============================================================================
create table if not exists public.document_sequences (
  id              uuid primary key default gen_random_uuid(),
  showroom_id     uuid not null
                  references public.showrooms(id) on delete cascade,
  document_type   text not null,
  financial_year  text not null,
  prefix          text,
  current_value   bigint not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint document_sequences_key
    unique (showroom_id, document_type, financial_year),
  constraint document_sequences_type_check
    check (document_type in
      ('SALE', 'INVOICE', 'PAYMENT', 'PURCHASE', 'SERVICE', 'EXPENSE',
       'LOAN', 'CUSTOMER', 'STOCK', 'TRANSFER', 'CLAIM', 'JOURNAL')),
  constraint document_sequences_value_check check (current_value >= 0)
);

-- =============================================================================
-- app_settings - global configuration, not showroom specific
-- =============================================================================
create table if not exists public.app_settings (
  id          uuid primary key default gen_random_uuid(),
  key         text not null,
  value       jsonb not null default '{}'::jsonb,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.users(id) on delete set null,

  constraint app_settings_key_key unique (key)
);

-- =============================================================================
-- attachments - uploaded files, linked polymorphically
-- =============================================================================
create table if not exists public.attachments (
  id           uuid primary key default gen_random_uuid(),
  showroom_id  uuid not null
               references public.showrooms(id) on delete cascade,
  entity_type  text not null,
  entity_id    uuid not null,
  bucket       text not null,
  file_name    text not null,
  file_path    text not null,
  file_url     text,
  file_type    text,
  file_size    bigint,
  uploaded_by  uuid references public.users(id) on delete set null,

  is_deleted   boolean not null default false,
  deleted_at   timestamptz,
  deleted_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),

  constraint attachments_entity_type_check
    check (entity_type in
      ('CUSTOMER', 'VEHICLE', 'SALE', 'INVOICE', 'PAYMENT', 'PURCHASE',
       'EXPENSE', 'SERVICE', 'WARRANTY', 'INSURANCE', 'PRODUCT',
       'SHOWROOM', 'USER', 'LOAN')),
  constraint attachments_size_check
    check (file_size is null or file_size >= 0)
);

comment on column public.attachments.file_path is
  'Storage object path. Always <showroom_id>/<entity_type>/<entity_id>/<file>, '
  'because the storage RLS policies match on the first path segment.';

-- =============================================================================
-- audit_logs - append-only trail
--
-- Deliberately has no update or delete policy in 009_rls.sql. The point of an
-- audit trail is that it survives the deletion of what it describes, so rows
-- here outlive cancelled sales and deactivated users.
-- =============================================================================
create table if not exists public.audit_logs (
  id           uuid primary key default gen_random_uuid(),
  -- Deliberately NOT foreign keys.
  --
  -- An audit entry is a historical snapshot, not a live relationship. Two
  -- problems follow from constraining it:
  --   * ON DELETE SET NULL erases the attribution on exactly the entries that
  --     matter most - those describing a user or showroom that was removed.
  --   * The audit trigger fires DURING a delete, so auditing the removal of a
  --     showroom would insert a row referencing the record being deleted and
  --     fail, taking the whole delete with it.
  --
  -- The identifiers are therefore kept as plain uuids, and old_data holds the
  -- full row, so the entry stays readable even after its subject is gone.
  showroom_id  uuid,
  user_id      uuid,
  module       text,
  action       text not null,
  table_name   text,
  record_id    uuid,
  old_data     jsonb,
  new_data     jsonb,
  ip_address   inet,
  user_agent   text,
  created_at   timestamptz not null default now(),

  constraint audit_logs_action_check
    check (action in
      ('CREATE', 'UPDATE', 'DELETE', 'CANCEL', 'APPROVE', 'REJECT',
       'PAYMENT', 'REFUND', 'REVERSE', 'LOGIN', 'LOGOUT', 'LOGIN_FAILED',
       'STOCK_TRANSFER', 'STOCK_ADJUSTMENT', 'EXPORT', 'PRINT',
       'PERMISSION_CHANGE'))
);

comment on table public.audit_logs is
  'Append-only historical record. Retained even when the subject is removed, '
  'which is why showroom_id and user_id are unconstrained uuids.';

-- Removes the foreign keys from a database created before this change.
do $$
begin
  alter table public.audit_logs
    drop constraint if exists audit_logs_showroom_id_fkey;
  alter table public.audit_logs
    drop constraint if exists audit_logs_user_id_fkey;
end $$;
