-- =============================================================================
-- 016_role_permission_management.sql
--
-- Adds the one RPC the role-permission-matrix screen needs: an atomic
-- replace of a role's whole permission set.
--
-- Phase 2 (the database) was completed and verified before Phase 3 (the
-- client screens) began. This migration is a legitimate, expected addition
-- driven by a real client need discovered while building the role editor,
-- not a revision of anything already shipped - the numbering continues
-- forward rather than editing 008_roles_permissions.sql after the fact.
-- =============================================================================

-- Replaces every permission grant for a role in one transaction.
--
-- A naive client-side "delete all, then insert the selected ones" is two
-- separate requests: if the second fails after the first succeeds, the role
-- is left holding zero permissions until someone retries. Wrapping both
-- sides in one PL/pgSQL function makes the replace atomic.
--
-- Being SECURITY DEFINER, this function bypasses RLS entirely as the table
-- owner - which is exactly why it performs its OWN authorisation check
-- rather than relying on the role_permissions policies to catch a caller who
-- should not be here. A SECURITY DEFINER function is a hole punched through
-- RLS on purpose, and every hole must guard itself.
create or replace function public.set_role_permissions(
  p_role_id        uuid,
  p_permission_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role  public.roles%rowtype;
  v_count integer;
begin
  if not public.has_permission('roles', 'manage') then
    raise exception 'You do not have permission to manage role permissions'
      using errcode = 'P0001';
  end if;

  select * into v_role from public.roles where id = p_role_id;
  if not found then
    raise exception 'Role not found' using errcode = 'P0001';
  end if;

  -- A super admin's authority comes from is_super_admin(), not from rows in
  -- role_permissions - editing this role's grants here would be a no-op that
  -- looks like it did something, so it is refused outright rather than left
  -- to quietly have no effect.
  if v_role.name = 'SUPER ADMIN' then
    raise exception
      'SUPER ADMIN implicitly holds every permission and cannot be edited'
      using errcode = 'P0001';
  end if;

  delete from public.role_permissions where role_id = p_role_id;

  insert into public.role_permissions (role_id, permission_id)
  select p_role_id, permission_id
  from unnest(p_permission_ids) as permission_id
  -- Silently drops an id that does not exist in the catalogue rather than
  -- failing the whole replace over one bad id from a stale client cache.
  where exists (
    select 1 from public.permissions p where p.id = permission_id
  )
  on conflict (role_id, permission_id) do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.set_role_permissions(uuid, uuid[]) is
  'Atomically replaces every permission grant for a role. Used by the role '
  'editor so a partial failure never leaves a role holding zero permissions.';
