-- =============================================================================
-- 015_auth_triggers.sql
--
-- Bridges Supabase Auth to the application profile.
--
-- -----------------------------------------------------------------------------
-- What this trigger does, and deliberately does not, do
-- -----------------------------------------------------------------------------
-- When a row appears in `auth.users`, a matching row is created in
-- `public.users` so the person has a profile. That is all.
--
-- It does NOT assign a role, and it does NOT assign a showroom. Doing either
-- automatically would mean anyone who can reach the signup endpoint grants
-- themselves access to a showroom's data. Provisioning is an explicit,
-- permission-guarded act performed by an administrator.
--
-- The consequence is intentional: a newly created account can authenticate but
-- has no role and no showroom, so `current_user_context()` reports it as
-- unprovisioned and the client shows the blocked-account screen. That is the
-- correct outcome for a half-finished onboarding, and far better than dropping
-- the user onto a dashboard where every query fails.
-- =============================================================================

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_name          text;
  v_phone         text;
  v_showroom_id   uuid;
  v_employee_code text;
begin
  -- An administrator creating a user through the admin API can pass these in
  -- `raw_user_meta_data`, which lets a single call both create the credential
  -- and pre-fill the profile. Nothing security-relevant is taken from it.
  v_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    -- Fall back to the local part of the email so the profile is never
    -- nameless; the administrator corrects it during onboarding.
    initcap(replace(split_part(coalesce(new.email, 'user'), '@', 1), '.', ' '))
  );

  v_phone := public.normalise_phone(
    new.raw_user_meta_data ->> 'phone'
  );

  v_employee_code := nullif(
    btrim(new.raw_user_meta_data ->> 'employee_code'), ''
  );

  -- A showroom may be suggested in the metadata, but it is accepted only if
  -- it actually exists. A forged id therefore yields an unassigned profile
  -- rather than an error or a wrong assignment.
  v_showroom_id := (
    select s.id from public.showrooms s
    where s.id = nullif(new.raw_user_meta_data ->> 'showroom_id', '')::uuid
      and s.is_deleted = false
  );

  insert into public.users (
    auth_user_id, showroom_id, name, email, phone, employee_code, status
  ) values (
    new.id,
    v_showroom_id,
    v_name,
    lower(btrim(new.email)),
    v_phone,
    v_employee_code,
    -- ACTIVE only describes the profile record. Without a role the user still
    -- cannot reach anything, because every RLS policy requires a permission.
    'ACTIVE'
  )
  on conflict (auth_user_id) do nothing;

  return new;
exception
  when others then
    -- A failure here must never block account creation: the person would be
    -- left with a credential and no way to obtain a profile. The profile can
    -- be created later by an administrator, so the error is logged and signup
    -- is allowed to proceed.
    raise warning
      'Could not create the application profile for auth user %: %',
      new.id, sqlerrm;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- =============================================================================
-- Keep the profile email in step with the credential
--
-- A user who changes their sign-in email would otherwise leave a stale address
-- on their profile, which is what invoices and notifications are addressed
-- from.
-- =============================================================================
create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  if new.email is distinct from old.email then
    update public.users
    set email = lower(btrim(new.email)), updated_at = now()
    where auth_user_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of email on auth.users
  for each row execute function public.handle_auth_user_updated();

-- =============================================================================
-- Deactivate, never delete
--
-- When an auth user is removed, the profile is marked INACTIVE rather than
-- deleted. Their name is attached to sales, invoices and audit entries that
-- must remain intact and attributable; deleting the row would either break
-- those references or blank out the audit trail.
-- =============================================================================
create or replace function public.handle_auth_user_deleted()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  update public.users
  set status = 'INACTIVE',
      is_deleted = true,
      deleted_at = now(),
      updated_at = now()
  where auth_user_id = old.id;

  -- Their push tokens stop being valid immediately.
  update public.device_tokens
  set is_active = false, updated_at = now()
  where user_id in (
    select id from public.users where auth_user_id = old.id
  );

  return old;
end;
$$;

drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  before delete on auth.users
  for each row execute function public.handle_auth_user_deleted();

-- The FK from users.auth_user_id is ON DELETE CASCADE, which would remove the
-- profile the trigger above just preserved. Relaxing it to SET NULL keeps the
-- profile and its history while severing the credential link.
do $$
begin
  if exists (
    select 1 from pg_constraint where conname = 'users_auth_user_id_fkey'
  ) then
    alter table public.users drop constraint users_auth_user_id_fkey;
  end if;

  alter table public.users
    add constraint users_auth_user_id_fkey
    foreign key (auth_user_id) references auth.users(id)
    on delete set null
    deferrable initially deferred;
end $$;

-- auth_user_id must now be nullable, since a deleted credential leaves the
-- profile behind with no auth row to point at.
alter table public.users alter column auth_user_id drop not null;

-- =============================================================================
-- Administrator bootstrap
--
-- Promotes an existing account to SUPER ADMIN. Used once per deployment to
-- create the first administrator, who then onboards everyone else through the
-- application.
--
-- Deliberately keyed on an email that must ALREADY exist in auth.users: this
-- function cannot create a credential, so it cannot be used to manufacture an
-- administrator out of nothing. Run it from the SQL editor as the project
-- owner; it is not reachable by an application client, whose `authenticated`
-- role has no way to satisfy the guard below.
-- =============================================================================
create or replace function public.bootstrap_super_admin(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_auth_id  uuid;
  v_user_id  uuid;
  v_role_id  uuid;
  v_existing integer;
begin
  -- Refuse once an administrator exists. After that, promotion happens
  -- through the application's user management, which is audited; leaving this
  -- open would be a permanent privilege-escalation path.
  select count(*) into v_existing
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where r.name = 'SUPER ADMIN';

  if v_existing > 0 and not public.is_super_admin() then
    raise exception
      'A super admin already exists. Assign further administrators through '
      'the application.'
      using errcode = 'P0001';
  end if;

  select id into v_auth_id
  from auth.users where lower(email) = lower(btrim(p_email));

  if v_auth_id is null then
    raise exception
      'No account exists for %. Create the user in Supabase Auth first.',
      p_email
      using errcode = 'P0001';
  end if;

  select id into v_user_id
  from public.users where auth_user_id = v_auth_id;

  -- The profile trigger should have created this, but a project that had the
  -- trigger added after the account was created will not have one.
  if v_user_id is null then
    insert into public.users (auth_user_id, name, email, status)
    values (
      v_auth_id,
      initcap(replace(split_part(p_email, '@', 1), '.', ' ')),
      lower(btrim(p_email)),
      'ACTIVE'
    )
    returning id into v_user_id;
  end if;

  select id into v_role_id from public.roles where name = 'SUPER ADMIN';

  insert into public.user_roles (user_id, role_id)
  values (v_user_id, v_role_id)
  on conflict (user_id, role_id) do nothing;

  update public.users
  set status = 'ACTIVE', is_deleted = false, updated_at = now()
  where id = v_user_id;

  return jsonb_build_object(
    'user_id', v_user_id,
    'auth_user_id', v_auth_id,
    'email', lower(btrim(p_email)),
    'role', 'SUPER ADMIN',
    'message', 'Super admin assigned. Sign in and onboard the rest of the '
               'team from Settings.'
  );
end;
$$;

comment on function public.bootstrap_super_admin(text) is
  'One-time promotion of an existing auth account to SUPER ADMIN. Refuses '
  'once an administrator exists. Run from the Supabase SQL editor.';

-- Not reachable by application clients: only the project owner, running in
-- the SQL editor, should be able to mint the first administrator.
revoke execute on function public.bootstrap_super_admin(text)
  from anon, authenticated;
