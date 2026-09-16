-- =============================================================================
-- 009_rls.sql
--
-- Row Level Security. This is the actual authorisation boundary.
--
-- -----------------------------------------------------------------------------
-- The model
-- -----------------------------------------------------------------------------
-- Two independent questions are asked of every row:
--
--   1. Tenancy  - can_access_showroom(showroom_id): is this row inside a
--                 showroom the caller is assigned to?
--   2. Capability - has_permission(module, action): may the caller perform
--                 this kind of operation at all?
--
-- Both must hold. Separating them means a SALES MANAGER at branch A cannot
-- read branch B's sales even though they hold `sales.view`, and a TECHNICIAN
-- at branch A cannot create a sale even though they are inside branch A.
--
-- The Flutter client caches an equivalent permission set to decide what to
-- render. That cache is not trusted here: a tampered client issuing a
-- forbidden query simply gets zero rows or a 42501.
--
-- -----------------------------------------------------------------------------
-- Why FORCE ROW LEVEL SECURITY is deliberately NOT set
-- -----------------------------------------------------------------------------
-- The authorisation helpers are SECURITY DEFINER and run as the table owner.
-- Owners are exempt from RLS unless FORCE is set. Setting FORCE would make
-- those helpers subject to the very policies that call them, producing
-- infinite recursion. The owner role is not used by the application at
-- runtime - PostgREST connects as `authenticated` or `anon` - so this exempts
-- nothing that matters.
-- =============================================================================

-- =============================================================================
-- Enable RLS everywhere
--
-- Enabled on every table without exception. A table with RLS enabled and no
-- policy denies all access, which is the correct default: forgetting to write
-- a policy fails closed rather than exposing data.
-- =============================================================================
do $$
declare
  v_table text;
begin
  for v_table in
    select table_name
    from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'
  loop
    execute format(
      'alter table public.%I enable row level security', v_table
    );
  end loop;
end $$;

-- Drops every existing policy so this migration can be re-run cleanly.
do $$
declare
  v_policy record;
begin
  for v_policy in
    select schemaname, tablename, policyname
    from pg_policies where schemaname = 'public'
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      v_policy.policyname, v_policy.schemaname, v_policy.tablename
    );
  end loop;
end $$;

-- =============================================================================
-- Showroom-scoped business tables
--
-- Generated from a table -> module map. Generating them guarantees all four
-- verbs are covered on every table: a hand-written set is exactly where a
-- missing UPDATE policy hides, and a missing policy on a table with RLS
-- enabled silently breaks the feature instead of failing review.
-- =============================================================================
do $$
declare
  v_map    record;
  v_tables constant jsonb := jsonb_build_object(
    'customers',           'customers',
    'customer_vehicles',   'vehicles',
    'inventory',           'inventory',
    -- stock_transfers is deliberately absent: it has from_showroom_id and
    -- to_showroom_id rather than a single showroom_id, and both ends must see
    -- the transfer. Its policies are written explicitly below.
    'sales',               'sales',
    'invoices',            'billing',
    'payments',            'payments',
    'loans',               'finance',
    'purchases',           'purchases',
    'expenses',            'expenses',
    'service_records',     'service',
    'vehicle_free_services', 'service',
    'warranties',          'warranty',
    'warranty_claims',     'warranty',
    'insurance_policies',  'insurance',
    'reminders',           'reminders',
    'accounts',            'accounting',
    'accounting_transactions', 'accounting',
    'attachments',         'documents'
  );
begin
  for v_map in select key as tbl, value #>> '{}' as module
               from jsonb_each(v_tables)
  loop
    -- SELECT
    execute format($f$
      create policy %1$s_select on public.%1$I
        for select to authenticated
        using (
          public.can_access_showroom(showroom_id)
          and public.has_permission(%2$L, 'view')
        )
    $f$, v_map.tbl, v_map.module);

    -- INSERT. WITH CHECK only: there is no existing row to test.
    execute format($f$
      create policy %1$s_insert on public.%1$I
        for insert to authenticated
        with check (
          public.can_access_showroom(showroom_id)
          and public.has_permission(%2$L, 'create')
        )
    $f$, v_map.tbl, v_map.module);

    -- UPDATE. USING tests the row as it is; WITH CHECK tests it as it will
    -- be. Both are required: without WITH CHECK a user could move a row into
    -- another showroom by editing showroom_id, escaping their tenancy.
    execute format($f$
      create policy %1$s_update on public.%1$I
        for update to authenticated
        using (
          public.can_access_showroom(showroom_id)
          and public.has_permission(%2$L, 'edit')
        )
        with check (
          public.can_access_showroom(showroom_id)
        )
    $f$, v_map.tbl, v_map.module);

    -- DELETE. Most financial tables additionally have a trigger that refuses
    -- DELETE outright; this policy governs the tables where a hard delete is
    -- legitimate (a draft, an attachment, a reminder).
    execute format($f$
      create policy %1$s_delete on public.%1$I
        for delete to authenticated
        using (
          public.can_access_showroom(showroom_id)
          and public.has_permission(%2$L, 'delete')
        )
    $f$, v_map.tbl, v_map.module);
  end loop;
end $$;

-- =============================================================================
-- stock_transfers
--
-- A transfer spans two showrooms and both ends have a legitimate interest: the
-- sender needs to track what has left, the receiver needs to know what is
-- arriving. Visibility is therefore granted if the caller can access EITHER
-- end.
--
-- Creating a transfer requires access to the source showroom - you can only
-- send stock you hold. Receiving is an update, and is restricted to the
-- destination, so a sender cannot mark their own shipment as received.
-- =============================================================================
create policy stock_transfers_select on public.stock_transfers
  for select to authenticated
  using (
    (public.can_access_showroom(from_showroom_id)
     or public.can_access_showroom(to_showroom_id))
    and public.has_permission('inventory', 'view')
  );

create policy stock_transfers_insert on public.stock_transfers
  for insert to authenticated
  with check (
    public.can_access_showroom(from_showroom_id)
    and public.has_permission('inventory', 'transfer')
  );

create policy stock_transfers_update on public.stock_transfers
  for update to authenticated
  using (
    (public.can_access_showroom(from_showroom_id)
     or public.can_access_showroom(to_showroom_id))
    and public.has_permission('inventory', 'transfer')
  )
  with check (
    public.can_access_showroom(from_showroom_id)
    or public.can_access_showroom(to_showroom_id)
  );

-- =============================================================================
-- showrooms
--
-- Scoped by its own id rather than a showroom_id column.
-- =============================================================================
create policy showrooms_select on public.showrooms
  for select to authenticated
  using (public.can_access_showroom(id));

create policy showrooms_insert on public.showrooms
  for insert to authenticated
  with check (public.has_permission('showroom', 'create'));

create policy showrooms_update on public.showrooms
  for update to authenticated
  using (
    public.can_access_showroom(id)
    and public.has_permission('showroom', 'edit')
  )
  with check (public.can_access_showroom(id));

create policy showrooms_delete on public.showrooms
  for delete to authenticated
  using (public.has_permission('showroom', 'delete'));

-- =============================================================================
-- users
--
-- A user may always read their own profile, even without `users.view`. Without
-- this the application could not render the signed-in user's own name, and
-- current_user_context() would be the only way to see yourself.
-- =============================================================================
create policy users_select on public.users
  for select to authenticated
  using (
    auth_user_id = auth.uid()
    or (
      public.has_permission('users', 'view')
      and (
        public.is_super_admin()
        or showroom_id in (select public.accessible_showroom_ids())
      )
    )
  );

create policy users_insert on public.users
  for insert to authenticated
  with check (
    public.has_permission('users', 'create')
    and (showroom_id is null or public.can_access_showroom(showroom_id))
  );

-- A user may edit their own profile (name, phone, avatar). Privilege fields -
-- status and showroom_id - are protected by the trigger below, not by this
-- policy, because a policy cannot express "these columns but not those".
create policy users_update on public.users
  for update to authenticated
  using (
    auth_user_id = auth.uid()
    or (
      public.has_permission('users', 'edit')
      and (
        public.is_super_admin()
        or showroom_id in (select public.accessible_showroom_ids())
      )
    )
  )
  with check (
    auth_user_id = auth.uid()
    or public.has_permission('users', 'edit')
  );

create policy users_delete on public.users
  for delete to authenticated
  using (public.has_permission('users', 'delete'));

-- Stops a user escalating themselves by editing their own privilege columns.
--
-- The UPDATE policy above lets a user edit their own row so they can change
-- their name or avatar. Without this guard that same policy would let them set
-- status = 'ACTIVE' on a suspended account, or move themselves to another
-- showroom.
create or replace function public.guard_user_privilege_columns()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  -- No JWT means there is no "self" to protect: this is a server-side
  -- context - a migration, a scheduled job, an admin script run from the SQL
  -- editor, or a SECURITY DEFINER function. Such callers are already trusted
  -- by virtue of their database privileges, and blocking them here would make
  -- legitimate administration impossible.
  if auth.uid() is null then
    return new;
  end if;

  -- An administrator with users.edit may change anything.
  if public.has_permission('users', 'edit') then
    return new;
  end if;

  -- Editing someone else's row is already blocked by the policy; this is the
  -- self-edit path.
  if new.status is distinct from old.status
     or new.showroom_id is distinct from old.showroom_id
     or new.auth_user_id is distinct from old.auth_user_id
     or new.employee_code is distinct from old.employee_code then
    raise exception
      'You cannot change your own status, showroom or employee code'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_users_privilege_guard on public.users;
create trigger trg_users_privilege_guard
  before update on public.users
  for each row execute function public.guard_user_privilege_columns();

-- =============================================================================
-- Roles, permissions and assignments
--
-- Readable by any authenticated user: the client needs the catalogue to render
-- a permission matrix, and knowing that a permission exists grants nothing.
-- Writing requires roles.manage.
-- =============================================================================
create policy roles_select on public.roles
  for select to authenticated using (true);

create policy roles_insert on public.roles
  for insert to authenticated
  with check (public.has_permission('roles', 'manage'));

-- System roles are resolved by name by is_super_admin() and the policies
-- above. Renaming one would silently sever authorisation for every user
-- holding it, so it is refused outright.
create policy roles_update on public.roles
  for update to authenticated
  using (public.has_permission('roles', 'manage') and is_system_role = false)
  with check (public.has_permission('roles', 'manage'));

create policy roles_delete on public.roles
  for delete to authenticated
  using (public.has_permission('roles', 'manage') and is_system_role = false);

create policy permissions_select on public.permissions
  for select to authenticated using (true);

-- The permission catalogue is seeded by migration and mirrored in Dart. It is
-- never written at runtime, so no write policy exists.

create policy role_permissions_select on public.role_permissions
  for select to authenticated using (true);

create policy role_permissions_insert on public.role_permissions
  for insert to authenticated
  with check (public.has_permission('roles', 'manage'));

create policy role_permissions_delete on public.role_permissions
  for delete to authenticated
  using (public.has_permission('roles', 'manage'));

-- Role assignment is the highest-privilege operation in the system: it is how
-- one becomes an administrator. It requires users.assign, and a non-super-admin
-- may not grant SUPER ADMIN.
create policy user_roles_select on public.user_roles
  for select to authenticated
  using (
    user_id = public.current_user_id()
    or public.has_permission('users', 'view')
  );

create policy user_roles_insert on public.user_roles
  for insert to authenticated
  with check (
    public.has_permission('users', 'assign')
    and (
      public.is_super_admin()
      or role_id not in (select id from public.roles where name = 'SUPER ADMIN')
    )
  );

create policy user_roles_delete on public.user_roles
  for delete to authenticated
  using (
    public.has_permission('users', 'assign')
    and (
      public.is_super_admin()
      or role_id not in (select id from public.roles where name = 'SUPER ADMIN')
    )
  );

create policy user_showrooms_select on public.user_showrooms
  for select to authenticated
  using (
    user_id = public.current_user_id()
    or public.has_permission('users', 'view')
  );

create policy user_showrooms_insert on public.user_showrooms
  for insert to authenticated
  with check (
    public.has_permission('users', 'assign')
    and public.can_access_showroom(showroom_id)
  );

create policy user_showrooms_delete on public.user_showrooms
  for delete to authenticated
  using (
    public.has_permission('users', 'assign')
    and public.can_access_showroom(showroom_id)
  );

-- =============================================================================
-- Global catalogue tables
--
-- Shared across showrooms, so tenancy does not apply; capability does.
-- =============================================================================
do $$
declare
  v_map    record;
  v_tables constant jsonb := jsonb_build_object(
    'brands',             'products',
    'products',           'products',
    'suppliers',          'suppliers',
    'finance_companies',  'finance',
    'expense_categories', 'expenses',
    'free_service_plans', 'service'
  );
begin
  for v_map in select key as tbl, value #>> '{}' as module
               from jsonb_each(v_tables)
  loop
    execute format($f$
      create policy %1$s_select on public.%1$I
        for select to authenticated
        using (public.has_permission(%2$L, 'view'))
    $f$, v_map.tbl, v_map.module);

    execute format($f$
      create policy %1$s_insert on public.%1$I
        for insert to authenticated
        with check (public.has_permission(%2$L, 'create'))
    $f$, v_map.tbl, v_map.module);

    execute format($f$
      create policy %1$s_update on public.%1$I
        for update to authenticated
        using (public.has_permission(%2$L, 'edit'))
        with check (public.has_permission(%2$L, 'edit'))
    $f$, v_map.tbl, v_map.module);

    execute format($f$
      create policy %1$s_delete on public.%1$I
        for delete to authenticated
        using (public.has_permission(%2$L, 'delete'))
    $f$, v_map.tbl, v_map.module);
  end loop;
end $$;

-- finance_companies and expense_categories have no 'delete' permission in the
-- catalogue, so those policies reference an action that is never granted -
-- which is the intended outcome: they are deactivated, not deleted.

-- =============================================================================
-- Child tables
--
-- Authorised through their parent. Re-deriving the showroom from the parent
-- rather than duplicating showroom_id onto the child keeps a single source of
-- truth: a line item can never disagree with its document about which
-- showroom it belongs to.
-- =============================================================================
do $$
declare
  v_child record;
  -- child table, parent table, fk column, module
  v_children constant jsonb := jsonb_build_array(
    jsonb_build_array('sale_items',        'sales',            'sale_id',     'sales'),
    jsonb_build_array('invoice_items',     'invoices',         'invoice_id',  'billing'),
    jsonb_build_array('purchase_items',    'purchases',        'purchase_id', 'purchases'),
    jsonb_build_array('service_items',     'service_records',  'service_id',  'service')
  );
  v_row jsonb;
begin
  for v_row in select * from jsonb_array_elements(v_children) loop
    v_child := row(
      v_row ->> 0, v_row ->> 1, v_row ->> 2, v_row ->> 3
    );

    execute format($f$
      create policy %1$s_select on public.%1$I
        for select to authenticated
        using (exists (
          select 1 from public.%2$I p
          where p.id = public.%1$I.%3$I
            and public.can_access_showroom(p.showroom_id)
            and public.has_permission(%4$L, 'view')
        ))
    $f$, v_row ->> 0, v_row ->> 1, v_row ->> 2, v_row ->> 3);

    execute format($f$
      create policy %1$s_insert on public.%1$I
        for insert to authenticated
        with check (exists (
          select 1 from public.%2$I p
          where p.id = %3$I
            and public.can_access_showroom(p.showroom_id)
            and public.has_permission(%4$L, 'create')
        ))
    $f$, v_row ->> 0, v_row ->> 1, v_row ->> 2, v_row ->> 3);

    execute format($f$
      create policy %1$s_update on public.%1$I
        for update to authenticated
        using (exists (
          select 1 from public.%2$I p
          where p.id = public.%1$I.%3$I
            and public.can_access_showroom(p.showroom_id)
            and public.has_permission(%4$L, 'edit')
        ))
        with check (exists (
          select 1 from public.%2$I p
          where p.id = %3$I
            and public.can_access_showroom(p.showroom_id)
        ))
    $f$, v_row ->> 0, v_row ->> 1, v_row ->> 2, v_row ->> 3);

    execute format($f$
      create policy %1$s_delete on public.%1$I
        for delete to authenticated
        using (exists (
          select 1 from public.%2$I p
          where p.id = public.%1$I.%3$I
            and public.can_access_showroom(p.showroom_id)
            and public.has_permission(%4$L, 'edit')
        ))
    $f$, v_row ->> 0, v_row ->> 1, v_row ->> 2, v_row ->> 3);
  end loop;
end $$;

-- emi_schedules: authorised through the loan.
create policy emi_schedules_select on public.emi_schedules
  for select to authenticated
  using (exists (
    select 1 from public.loans l
    where l.id = emi_schedules.loan_id
      and public.can_access_showroom(l.showroom_id)
      and public.has_permission('emi', 'view')
  ));

create policy emi_schedules_insert on public.emi_schedules
  for insert to authenticated
  with check (exists (
    select 1 from public.loans l
    where l.id = loan_id
      and public.can_access_showroom(l.showroom_id)
      and public.has_permission('emi', 'create')
  ));

create policy emi_schedules_update on public.emi_schedules
  for update to authenticated
  using (exists (
    select 1 from public.loans l
    where l.id = emi_schedules.loan_id
      and public.can_access_showroom(l.showroom_id)
      and (public.has_permission('emi', 'edit')
           or public.has_permission('emi', 'payment'))
  ))
  with check (exists (
    select 1 from public.loans l
    where l.id = loan_id and public.can_access_showroom(l.showroom_id)
  ));

-- accounting_entries: authorised through the transaction.
create policy accounting_entries_select on public.accounting_entries
  for select to authenticated
  using (exists (
    select 1 from public.accounting_transactions t
    where t.id = accounting_entries.transaction_id
      and public.can_access_showroom(t.showroom_id)
      and public.has_permission('accounting', 'view')
  ));

create policy accounting_entries_insert on public.accounting_entries
  for insert to authenticated
  with check (exists (
    select 1 from public.accounting_transactions t
    where t.id = transaction_id
      and public.can_access_showroom(t.showroom_id)
      and public.has_permission('accounting', 'create')
  ));

-- No UPDATE or DELETE policy: a posted ledger line is immutable. Corrections
-- are made by posting a reversing transaction, which is the accounting
-- convention and keeps the audit trail complete.

-- product_colors / product_images: authorised through the product.
create policy product_colors_select on public.product_colors
  for select to authenticated
  using (public.has_permission('products', 'view'));

create policy product_colors_write on public.product_colors
  for all to authenticated
  using (public.has_permission('products', 'edit'))
  with check (public.has_permission('products', 'edit'));

create policy product_images_select on public.product_images
  for select to authenticated
  using (public.has_permission('products', 'view'));

create policy product_images_write on public.product_images
  for all to authenticated
  using (public.has_permission('products', 'edit'))
  with check (public.has_permission('products', 'edit'));

-- =============================================================================
-- Stock movements - append-only ledger
-- =============================================================================
create policy stock_movements_select on public.stock_movements
  for select to authenticated
  using (
    public.can_access_showroom(showroom_id)
    and public.has_permission('inventory', 'view')
  );

-- Written by the inventory trigger, which runs SECURITY DEFINER; this policy
-- covers a direct insert from a server-side function.
create policy stock_movements_insert on public.stock_movements
  for insert to authenticated
  with check (public.can_access_showroom(showroom_id));

-- =============================================================================
-- Notifications and device tokens - personal to the recipient
-- =============================================================================
create policy notifications_select on public.notifications
  for select to authenticated
  using (
    user_id = public.current_user_id()
    or (
      public.can_access_showroom(showroom_id)
      and public.has_permission('notifications', 'view')
    )
  );

create policy notifications_insert on public.notifications
  for insert to authenticated
  with check (
    public.has_permission('notifications', 'create')
    and (showroom_id is null or public.can_access_showroom(showroom_id))
  );

-- Marking as read is the only update a recipient makes.
create policy notifications_update on public.notifications
  for update to authenticated
  using (user_id = public.current_user_id())
  with check (user_id = public.current_user_id());

create policy notifications_delete on public.notifications
  for delete to authenticated
  using (user_id = public.current_user_id());

-- A device token is a credential for pushing to a specific handset. Only its
-- owner may read or write it.
create policy device_tokens_all on public.device_tokens
  for all to authenticated
  using (user_id = public.current_user_id())
  with check (user_id = public.current_user_id());

-- =============================================================================
-- Audit logs - readable, never writable from the client
-- =============================================================================
create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (
    public.has_permission('audit', 'view')
    and (
      showroom_id is null
      or public.can_access_showroom(showroom_id)
    )
  );

-- No INSERT/UPDATE/DELETE policy. Rows are written exclusively by the
-- SECURITY DEFINER audit trigger, which bypasses RLS as the table owner. A
-- client cannot forge, alter or erase an audit entry.

-- =============================================================================
-- Supporting tables
-- =============================================================================
create policy document_sequences_select on public.document_sequences
  for select to authenticated
  using (public.can_access_showroom(showroom_id));

-- Counters are advanced only by next_document_number(), which is SECURITY
-- DEFINER. Allowing a client to write here would let it mint duplicate or
-- out-of-order invoice numbers.

create policy app_settings_select on public.app_settings
  for select to authenticated using (true);

create policy app_settings_update on public.app_settings
  for update to authenticated
  using (public.has_permission('settings', 'manage'))
  with check (public.has_permission('settings', 'manage'));

-- =============================================================================
-- Grants
--
-- RLS filters rows; table grants decide whether the role may attempt the verb
-- at all. Both are needed - RLS alone on a table with no GRANT yields a
-- permission-denied error rather than an empty result.
-- =============================================================================
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete
  on all tables in schema public to authenticated;

-- The anon role reaches nothing: every screen in this application requires a
-- signed-in user, so there is no public surface to expose.
revoke all on all tables in schema public from anon;

grant execute on all functions in schema public to authenticated;
grant execute on all functions in schema public to service_role;

-- Future tables inherit the same grants, so a table added by a later migration
-- is not accidentally unreachable.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;

-- =============================================================================
-- Verification
-- =============================================================================
do $$
declare
  v_unprotected text;
  v_policyless  text;
begin
  -- Any table with RLS disabled would be fully readable by every signed-in
  -- user, across every showroom.
  select string_agg(c.relname, ', ')
  into v_unprotected
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity = false;

  if v_unprotected is not null then
    raise exception 'RLS is not enabled on: %', v_unprotected;
  end if;

  -- A table with RLS enabled but no policy denies everything, which breaks
  -- the feature silently. Worth failing the migration over.
  select string_agg(c.relname, ', ')
  into v_policyless
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and not exists (
      select 1 from pg_policies p
      where p.schemaname = 'public' and p.tablename = c.relname
    );

  if v_policyless is not null then
    raise warning 'Tables with RLS enabled but no policy: %', v_policyless;
  end if;

  raise notice 'RLS enabled on all tables; % policies defined',
    (select count(*) from pg_policies where schemaname = 'public');
end $$;
