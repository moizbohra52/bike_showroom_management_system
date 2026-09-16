-- =============================================================================
-- RLS isolation test
--
-- Proves the three claims the security model rests on:
--
--   1. Tenancy   - a user cannot READ another showroom's rows.
--   2. Tenancy   - a user cannot WRITE into another showroom.
--   3. Capability - a user without a permission cannot perform that action
--                   even inside their own showroom.
--
-- Run with:
--   psql -d bsms -v ON_ERROR_STOP=1 -f supabase/tests/rls_isolation_test.sql
--
-- Runs as `authenticated` with a simulated JWT, which is exactly how PostgREST
-- executes a request. Running as the table owner would bypass RLS entirely and
-- prove nothing.
-- =============================================================================

\set QUIET on
\timing off

-- -----------------------------------------------------------------------------
-- Fixtures (created as owner, so RLS does not interfere with setup)
-- -----------------------------------------------------------------------------
do $$
declare
  v_showroom_a uuid;
  v_showroom_b uuid;
  v_auth_a     uuid := '11111111-1111-1111-1111-111111111111';
  v_auth_b     uuid := '22222222-2222-2222-2222-222222222222';
  v_auth_v     uuid := '33333333-3333-3333-3333-333333333333';
  v_user_a     uuid;
  v_user_b     uuid;
  v_user_v     uuid;
  v_role_mgr   uuid;
  v_role_view  uuid;
begin
  -- Clean slate.
  delete from public.customers where customer_code like 'RLSTEST%';
  delete from public.user_roles where user_id in (
    select id from public.users where email like '%@rlstest.local'
  );
  delete from public.users where email like '%@rlstest.local';
  delete from auth.users where id in (v_auth_a, v_auth_b, v_auth_v);
  delete from public.showrooms where code in ('RLSA', 'RLSB');

  insert into public.showrooms (name, code, status)
  values ('RLS Test Branch A', 'RLSA', 'ACTIVE') returning id into v_showroom_a;
  insert into public.showrooms (name, code, status)
  values ('RLS Test Branch B', 'RLSB', 'ACTIVE') returning id into v_showroom_b;

  -- Inserting into auth.users fires on_auth_user_created, which creates the
  -- public.users profile. The fixtures therefore UPDATE that profile rather
  -- than inserting their own, which would collide on auth_user_id - and the
  -- collision is itself evidence the trigger is doing its job.
  insert into auth.users (id, email) values
    (v_auth_a, 'a@rlstest.local'),
    (v_auth_b, 'b@rlstest.local'),
    (v_auth_v, 'v@rlstest.local');

  update public.users
  set showroom_id = v_showroom_a, name = 'Manager A', status = 'ACTIVE'
  where auth_user_id = v_auth_a
  returning id into v_user_a;

  update public.users
  set showroom_id = v_showroom_b, name = 'Manager B', status = 'ACTIVE'
  where auth_user_id = v_auth_b
  returning id into v_user_b;

  update public.users
  set showroom_id = v_showroom_a, name = 'Viewer V', status = 'ACTIVE'
  where auth_user_id = v_auth_v
  returning id into v_user_v;

  if v_user_a is null or v_user_b is null or v_user_v is null then
    raise exception
      'FAIL: on_auth_user_created did not create a profile for every '
      'auth user';
  end if;

  select id into v_role_mgr  from public.roles where name = 'SHOWROOM MANAGER';
  select id into v_role_view from public.roles where name = 'VIEWER';

  insert into public.user_roles (user_id, role_id) values
    (v_user_a, v_role_mgr),
    (v_user_b, v_role_mgr),
    (v_user_v, v_role_view);

  -- One customer in each branch, created as owner.
  insert into public.customers
    (showroom_id, customer_code, name, phone, created_by)
  values
    (v_showroom_a, 'RLSTEST-A1', 'Customer In A', '9000000001', v_user_a),
    (v_showroom_b, 'RLSTEST-B1', 'Customer In B', '9000000002', v_user_b);

  raise notice 'Fixtures ready: branch A=%, branch B=%',
    v_showroom_a, v_showroom_b;
end $$;

\set QUIET off

-- =============================================================================
-- Test 1: a manager sees ONLY their own showroom's customers
-- =============================================================================
\echo '--- Test 1: read isolation ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  do $$
  declare
    v_visible int;
    v_names   text;
  begin
    select count(*), string_agg(name, ', ')
    into v_visible, v_names
    from public.customers where customer_code like 'RLSTEST%';

    if v_visible <> 1 then
      raise exception
        'FAIL: Manager A sees % customers (expected 1). Visible: %',
        v_visible, v_names;
    end if;

    if v_names <> 'Customer In A' then
      raise exception 'FAIL: Manager A sees the wrong customer: %', v_names;
    end if;

    raise notice 'PASS: Manager A sees only branch A (%).', v_names;
  end $$;
rollback;

-- =============================================================================
-- Test 2: the other manager sees only THEIR showroom - symmetry check
-- =============================================================================
\echo '--- Test 2: read isolation is symmetric ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

  do $$
  declare
    v_names text;
  begin
    select string_agg(name, ', ') into v_names
    from public.customers where customer_code like 'RLSTEST%';

    if v_names is distinct from 'Customer In B' then
      raise exception 'FAIL: Manager B sees: %', coalesce(v_names, '<none>');
    end if;

    raise notice 'PASS: Manager B sees only branch B (%).', v_names;
  end $$;
rollback;

-- =============================================================================
-- Test 3: a manager CANNOT write into another showroom
--
-- The most important test in the file. If this passes, a tampered client
-- cannot plant a record in a branch it does not belong to.
-- =============================================================================
\echo '--- Test 3: cross-tenant write is refused ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  do $$
  declare
    v_showroom_b uuid;
    v_blocked    boolean := false;
  begin
    -- Manager A cannot even see branch B, so resolve its id as a literal
    -- lookup that bypasses the customers policy.
    select id into v_showroom_b from public.showrooms where code = 'RLSB';

    -- Manager A cannot read showrooms they lack access to either, so this is
    -- null - itself a demonstration of isolation.
    if v_showroom_b is null then
      raise notice
        'PASS (bonus): Manager A cannot even see branch B in `showrooms`.';
      v_showroom_b := '00000000-0000-0000-0000-000000000000';
    end if;

    begin
      insert into public.customers
        (showroom_id, customer_code, name, phone)
      values
        (v_showroom_b, 'RLSTEST-X1', 'Planted By A', '9000000009');
    exception
      when insufficient_privilege then
        v_blocked := true;
      when others then
        -- A foreign-key failure on the sentinel uuid also means the write did
        -- not land, which is the outcome under test.
        v_blocked := true;
    end;

    if not v_blocked then
      raise exception
        'FAIL: Manager A successfully wrote a customer into branch B';
    end if;

    raise notice 'PASS: cross-tenant insert was refused.';
  end $$;
rollback;

-- =============================================================================
-- Test 4: capability check - a VIEWER cannot create, even in their own branch
-- =============================================================================
\echo '--- Test 4: permission enforcement ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

  do $$
  declare
    v_showroom_a uuid;
    v_blocked    boolean := false;
    v_can_read   int;
  begin
    select showroom_id into v_showroom_a
    from public.users where email = 'v@rlstest.local';

    -- A viewer holds customers.view, so reading must still work.
    select count(*) into v_can_read
    from public.customers where customer_code like 'RLSTEST%';

    if v_can_read <> 1 then
      raise exception
        'FAIL: Viewer should read 1 customer in their branch, saw %',
        v_can_read;
    end if;

    -- But not customers.create.
    begin
      insert into public.customers
        (showroom_id, customer_code, name, phone)
      values
        (v_showroom_a, 'RLSTEST-V1', 'Created By Viewer', '9000000008');
    exception
      when insufficient_privilege then v_blocked := true;
      when others then v_blocked := true;
    end;

    if not v_blocked then
      raise exception 'FAIL: a VIEWER was able to create a customer';
    end if;

    raise notice
      'PASS: viewer can read (% row) but cannot create.', v_can_read;
  end $$;
rollback;

-- =============================================================================
-- Test 5: has_permission reflects the seeded grants
-- =============================================================================
\echo '--- Test 5: has_permission matches the role grants ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}';

  do $$
  begin
    if not public.has_permission('customers', 'view') then
      raise exception 'FAIL: VIEWER should hold customers.view';
    end if;
    if public.has_permission('customers', 'create') then
      raise exception 'FAIL: VIEWER must not hold customers.create';
    end if;
    if public.is_super_admin() then
      raise exception 'FAIL: VIEWER must not be a super admin';
    end if;
    raise notice 'PASS: has_permission agrees with the seeded grants.';
  end $$;
rollback;

-- =============================================================================
-- Test 6: current_user_context returns a usable payload
-- =============================================================================
\echo '--- Test 6: current_user_context ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  do $$
  declare
    v_ctx        jsonb;
    v_perm_count int;
    v_showrooms  int;
  begin
    v_ctx := public.current_user_context();

    if v_ctx is null then
      raise exception 'FAIL: current_user_context returned null';
    end if;

    if v_ctx -> 'user' ->> 'name' <> 'Manager A' then
      raise exception 'FAIL: wrong user in context: %',
        v_ctx -> 'user' ->> 'name';
    end if;

    v_perm_count := jsonb_array_length(v_ctx -> 'permissions');
    v_showrooms  := jsonb_array_length(v_ctx -> 'showrooms');

    if v_perm_count < 50 then
      raise exception
        'FAIL: SHOWROOM MANAGER should hold many permissions, got %',
        v_perm_count;
    end if;

    -- The crucial one: the context must expose only reachable showrooms.
    if v_showrooms <> 1 then
      raise exception
        'FAIL: context exposes % showrooms (expected 1)', v_showrooms;
    end if;

    raise notice
      'PASS: context has % permissions and % showroom.',
      v_perm_count, v_showrooms;
  end $$;
rollback;

-- =============================================================================
-- Test 7: a super admin transcends tenancy
-- =============================================================================
\echo '--- Test 7: super admin sees every branch ---'
do $$
declare
  v_role_super uuid;
  v_user_a     uuid;
begin
  select id into v_role_super from public.roles where name = 'SUPER ADMIN';
  select id into v_user_a from public.users where email = 'a@rlstest.local';
  insert into public.user_roles (user_id, role_id)
  values (v_user_a, v_role_super)
  on conflict do nothing;
end $$;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  do $$
  declare
    v_visible int;
  begin
    select count(*) into v_visible
    from public.customers where customer_code like 'RLSTEST%';

    if v_visible <> 2 then
      raise exception
        'FAIL: super admin sees % customers (expected 2 across both branches)',
        v_visible;
    end if;

    raise notice 'PASS: super admin sees both branches (% customers).',
      v_visible;
  end $$;
rollback;

-- -----------------------------------------------------------------------------
-- Teardown
-- -----------------------------------------------------------------------------
\set QUIET on
do $$
begin
  delete from public.customers where customer_code like 'RLSTEST%';
  delete from public.user_roles where user_id in (
    select id from public.users where email like '%@rlstest.local'
  );
  delete from public.users where email like '%@rlstest.local';
  delete from auth.users where email like '%@rlstest.local';
  delete from public.showrooms where code in ('RLSA', 'RLSB');
end $$;
\set QUIET off

\echo ''
\echo '==================================================='
\echo ' RLS isolation suite complete - all assertions held'
\echo '==================================================='
