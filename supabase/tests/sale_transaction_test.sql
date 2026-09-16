-- =============================================================================
-- End-to-end sale transaction test
--
-- Exercises create_sale_transaction() against real data and asserts every
-- downstream effect the specification requires, then proves the two properties
-- that matter most:
--
--   * the ledger balances (debits = credits) after the whole flow
--   * a failure leaves nothing behind (atomicity)
--
-- Run with:
--   psql -d bsms -v ON_ERROR_STOP=1 -f supabase/tests/sale_transaction_test.sql
-- =============================================================================

\set QUIET on

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
do $$
declare
  v_showroom uuid;
  v_brand    uuid;
  v_product  uuid;
  v_customer uuid;
  v_auth     uuid := '44444444-4444-4444-4444-444444444444';
  v_user     uuid;
  v_finco    uuid;
begin
  -- Clean slate.
  --
  -- `session_replication_role = replica` suspends user triggers for this
  -- session. Required because guard_no_financial_delete() refuses DELETE on
  -- stock_movements and payments by design - that guard working is itself one
  -- of the things under test, so the fixture teardown has to step around it
  -- rather than the guard being weakened.
  perform set_config('session_replication_role', 'replica', false);
  delete from public.accounting_entries where transaction_id in (
    select t.id from public.accounting_transactions t
    join public.showrooms s on s.id = t.showroom_id where s.code = 'SALETEST');
  delete from public.accounting_transactions where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.payments where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.invoice_items where invoice_id in (
    select id from public.invoices where showroom_id in (
      select id from public.showrooms where code = 'SALETEST'));
  delete from public.invoices where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.emi_schedules where loan_id in (
    select id from public.loans where showroom_id in (
      select id from public.showrooms where code = 'SALETEST'));
  delete from public.loans where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.sale_items where sale_id in (
    select id from public.sales where showroom_id in (
      select id from public.showrooms where code = 'SALETEST'));
  delete from public.sales where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.vehicle_free_services where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.warranties where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.customer_vehicles where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.stock_movements where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.inventory where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.customers where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.audit_logs where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.document_sequences where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.accounts where showroom_id in (
    select id from public.showrooms where code = 'SALETEST');
  delete from public.user_roles where user_id in (
    select id from public.users where auth_user_id = v_auth);
  delete from public.users where auth_user_id = v_auth;
  delete from auth.users where id = v_auth;
  delete from public.showrooms where code = 'SALETEST';
  delete from public.products where name = 'Test Rider 350';
  delete from public.brands where name = 'TestMoto';
  delete from public.finance_companies where code = 'TESTFIN';
  delete from public.free_service_plans where name like 'Test Free%';

  -- Triggers back on BEFORE any fixture is created. The showroom insert must
  -- fire trg_showroom_provision_accounts, otherwise the branch has no chart of
  -- accounts and the first ledger posting fails.
  perform set_config('session_replication_role', 'origin', false);

  -- Showroom. The trigger provisions its chart of accounts automatically.
  insert into public.showrooms (name, code, status, settings)
  values ('Sale Test Showroom', 'SALETEST', 'ACTIVE',
          '{"discount_approval_threshold": 5}'::jsonb)
  returning id into v_showroom;

  -- on_auth_user_created creates the profile; the fixture completes it.
  insert into auth.users (id, email) values (v_auth, 'sale@test.local');
  update public.users
  set showroom_id = v_showroom, name = 'Sale Tester', status = 'ACTIVE'
  where auth_user_id = v_auth
  returning id into v_user;

  insert into public.user_roles (user_id, role_id)
  select v_user, id from public.roles where name = 'SHOWROOM MANAGER';

  -- A second user holding SALES STAFF, which by design has sales.create but
  -- neither sales.approve nor sales.discount. Test 3 uses this rather than
  -- stripping permissions at runtime: a user cannot edit role_permissions
  -- without roles.manage, so an in-test DELETE is silently refused by RLS and
  -- the test would pass vacuously.
  insert into auth.users (id, email)
  values ('55555555-5555-5555-5555-555555555555', 'staff@test.local');

  update public.users
  set showroom_id = v_showroom, name = 'Sales Staffer', status = 'ACTIVE'
  where auth_user_id = '55555555-5555-5555-5555-555555555555'
  returning id into v_user;

  insert into public.user_roles (user_id, role_id)
  select v_user, id from public.roles where name = 'SALES STAFF';

  insert into public.brands (name) values ('TestMoto') returning id into v_brand;

  insert into public.products (
    brand_id, name, model, variant, category, engine_cc, fuel_type,
    base_price, selling_price, tax_rate, warranty_months, hsn_code
  ) values (
    v_brand, 'Test Rider 350', 'TR350', 'Standard', 'MOTORCYCLE', 349,
    'PETROL', 150000, 180000, 18, 24, '87112019'
  ) returning id into v_product;

  -- Three free services, the usual manufacturer schedule.
  insert into public.free_service_plans
    (product_id, service_number, name, validity_days, validity_km)
  values
    (v_product, 1, 'Test Free Service 1', 60, 1000),
    (v_product, 2, 'Test Free Service 2', 180, 5000),
    (v_product, 3, 'Test Free Service 3', 365, 10000);

  insert into public.inventory (
    showroom_id, product_id, stock_code, chassis_number, engine_number,
    model_year, purchase_date, purchase_price, status
  ) values (
    v_showroom, v_product, 'SALETEST-STK-001',
    'MBLTEST123456789', 'ENGTEST12345', 2026, current_date - 30,
    150000, 'AVAILABLE'
  );

  insert into public.customers
    (showroom_id, customer_code, name, phone, email, city)
  values
    (v_showroom, 'SALETEST-CUST-1', 'Test Buyer', '9876500001',
     'buyer@test.local', 'Mumbai')
  returning id into v_customer;

  insert into public.finance_companies (name, code)
  values ('Test Finance Ltd', 'TESTFIN') returning id into v_finco;

  raise notice 'Fixtures ready (showroom %)', v_showroom;
end $$;

\set QUIET off

-- =============================================================================
-- Test 1: a cash sale creates every downstream record
-- =============================================================================
\echo '--- Test 1: cash sale, full cascade ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

  do $$
  declare
    v_showroom  uuid;
    v_customer  uuid;
    v_inventory uuid;
    v_result    jsonb;
    v_sale_id   uuid;
    v_debit     numeric;
    v_credit    numeric;
    v_count     int;
    v_status    text;
  begin
    select id into v_showroom from public.showrooms where code = 'SALETEST';
    select id into v_customer from public.customers
      where customer_code = 'SALETEST-CUST-1';
    select id into v_inventory from public.inventory
      where stock_code = 'SALETEST-STK-001';

    v_result := public.create_sale_transaction(jsonb_build_object(
      'showroom_id',    v_showroom,
      'customer_id',    v_customer,
      'sale_type',      'CASH',
      'paid_amount',    50000,
      'payment_method', 'UPI',
      'payment_reference', 'UPI-TEST-0001',
      'other_charges',  12000,
      'items', jsonb_build_array(jsonb_build_object(
        'inventory_id', v_inventory,
        'quantity',     1,
        'unit_price',   180000,
        'discount',     5000,
        'tax_rate',     18
      ))
    ));

    v_sale_id := (v_result ->> 'sale_id')::uuid;
    raise notice 'Sale created: %', v_result ->> 'sale_number';

    -- ------------------------------------------------------------ totals
    -- 180000 - 5000 = 175000 taxable; GST 18% = 31500; + 12000 charges
    -- => 218500
    if (v_result ->> 'total_amount')::numeric <> 218500 then
      raise exception 'FAIL: total is % (expected 218500)',
        v_result ->> 'total_amount';
    end if;
    raise notice 'PASS: total computed server-side = 218500.00';

    if (v_result ->> 'outstanding')::numeric <> 168500 then
      raise exception 'FAIL: outstanding is % (expected 168500)',
        v_result ->> 'outstanding';
    end if;
    raise notice 'PASS: outstanding after 50000 paid = 168500.00';

    -- --------------------------------------------------------- stock sold
    select status into v_status from public.inventory where id = v_inventory;
    if v_status <> 'SOLD' then
      raise exception 'FAIL: stock status is % (expected SOLD)', v_status;
    end if;
    raise notice 'PASS: stock allocated (status = SOLD)';

    -- ------------------------------------------------------ stock movement
    select count(*) into v_count from public.stock_movements
      where inventory_id = v_inventory
        and movement_type = 'SALE_ALLOCATION';
    if v_count <> 1 then
      raise exception 'FAIL: % sale-allocation movements (expected 1)', v_count;
    end if;
    raise notice 'PASS: stock movement recorded by trigger';

    -- ------------------------------------------------------ customer vehicle
    if v_result ->> 'vehicle_id' is null then
      raise exception 'FAIL: no customer vehicle was created';
    end if;
    raise notice 'PASS: customer vehicle registered';

    -- -------------------------------------------------------------- invoice
    select count(*) into v_count from public.invoices
      where sale_id = v_sale_id and status in ('ISSUED', 'PARTIALLY_PAID');
    if v_count <> 1 then
      raise exception 'FAIL: % issued invoices (expected 1)', v_count;
    end if;
    raise notice 'PASS: invoice issued (%)', v_result ->> 'invoice_number';

    select count(*) into v_count from public.invoice_items
      where invoice_id = (v_result ->> 'invoice_id')::uuid;
    if v_count <> 1 then
      raise exception 'FAIL: % invoice items (expected 1)', v_count;
    end if;
    raise notice 'PASS: invoice line items copied';

    -- ------------------------------------------------------------- warranty
    select count(*) into v_count from public.warranties
      where vehicle_id = (v_result ->> 'vehicle_id')::uuid;
    if v_count <> 1 then
      raise exception 'FAIL: % warranties (expected 1)', v_count;
    end if;
    raise notice 'PASS: 24-month warranty created';

    -- -------------------------------------------------------- free services
    select count(*) into v_count from public.vehicle_free_services
      where vehicle_id = (v_result ->> 'vehicle_id')::uuid;
    if v_count <> 3 then
      raise exception 'FAIL: % free services (expected 3)', v_count;
    end if;
    raise notice 'PASS: 3 free services scheduled';

    -- --------------------------------------------------------------- payment
    select count(*) into v_count from public.payments
      where sale_id = v_sale_id and status = 'COMPLETED';
    if v_count <> 1 then
      raise exception 'FAIL: % payments (expected 1)', v_count;
    end if;
    raise notice 'PASS: initial payment recorded';

    -- ------------------------------------------------------- LEDGER BALANCE
    -- The property the whole accounting design rests on.
    select coalesce(sum(e.debit), 0), coalesce(sum(e.credit), 0)
    into v_debit, v_credit
    from public.accounting_entries e
    join public.accounting_transactions t on t.id = e.transaction_id
    where t.showroom_id = v_showroom;

    if abs(v_debit - v_credit) > 0.01 then
      raise exception
        'FAIL: ledger is unbalanced - debits %, credits %', v_debit, v_credit;
    end if;

    if v_debit = 0 then
      raise exception 'FAIL: no ledger entries were posted';
    end if;

    -- RAISE has no printf-style specifiers, so the rounding is done by the
    -- expression rather than by a format string.
    raise notice
      'PASS: ledger balances - debits % = credits %',
      round(v_debit, 2), round(v_credit, 2);
  end $$;
rollback;

-- =============================================================================
-- Test 2: selling an already-sold unit is refused
-- =============================================================================
\echo '--- Test 2: double-sale prevention ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

  do $$
  declare
    v_showroom  uuid;
    v_customer  uuid;
    v_inventory uuid;
    v_payload   jsonb;
    v_blocked   boolean := false;
  begin
    select id into v_showroom from public.showrooms where code = 'SALETEST';
    select id into v_customer from public.customers
      where customer_code = 'SALETEST-CUST-1';
    select id into v_inventory from public.inventory
      where stock_code = 'SALETEST-STK-001';

    v_payload := jsonb_build_object(
      'showroom_id', v_showroom, 'customer_id', v_customer,
      'sale_type', 'CASH', 'paid_amount', 0,
      'items', jsonb_build_array(jsonb_build_object(
        'inventory_id', v_inventory, 'quantity', 1,
        'unit_price', 180000, 'tax_rate', 18))
    );

    perform public.create_sale_transaction(v_payload);

    -- The same unit, a second time.
    begin
      perform public.create_sale_transaction(v_payload);
    exception when others then
      v_blocked := true;
      raise notice 'Second sale refused: %', sqlerrm;
    end;

    if not v_blocked then
      raise exception 'FAIL: the same vehicle was sold twice';
    end if;

    raise notice 'PASS: selling an already-sold unit was refused';
  end $$;
rollback;

-- =============================================================================
-- Test 3: an excessive discount without approval is refused
-- =============================================================================
\echo '--- Test 3: discount authorisation ---'
begin;
  set local role authenticated;
  -- The SALES STAFF user: holds sales.create, lacks sales.approve/discount.
  set local request.jwt.claims = '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}';

  do $$
  declare
    v_showroom  uuid;
    v_customer  uuid;
    v_inventory uuid;
    v_blocked   boolean := false;
  begin
    select id into v_showroom from public.showrooms where code = 'SALETEST';
    select id into v_customer from public.customers
      where customer_code = 'SALETEST-CUST-1';
    select id into v_inventory from public.inventory
      where stock_code = 'SALETEST-STK-001';

    -- Sanity: confirm the fixture really lacks the approval rights, so a
    -- pass below cannot be vacuous.
    if public.has_permission('sales', 'approve')
       or public.has_permission('sales', 'discount') then
      raise exception
        'FAIL: the test fixture unexpectedly holds discount approval rights';
    end if;

    begin
      -- 20% discount against a 5% threshold.
      perform public.create_sale_transaction(jsonb_build_object(
        'showroom_id', v_showroom, 'customer_id', v_customer,
        'sale_type', 'CASH', 'paid_amount', 0,
        'items', jsonb_build_array(jsonb_build_object(
          'inventory_id', v_inventory, 'quantity', 1,
          'unit_price', 180000, 'discount', 36000, 'tax_rate', 18))
      ));
    exception when others then
      v_blocked := true;
      raise notice 'Refused: %', sqlerrm;
    end;

    if not v_blocked then
      raise exception
        'FAIL: a 20 percent discount was accepted without approval rights';
    end if;

    raise notice 'PASS: excessive discount required approval';
  end $$;
rollback;

-- =============================================================================
-- Test 4: atomicity - a failure mid-flow leaves nothing behind
-- =============================================================================
-- Runs with a real JWT and COMMITS, so the assertion afterwards inspects
-- durably-written state rather than a transaction that was going to roll back
-- anyway. The failure is engineered to happen at the LOAN step, after the
-- sale, invoice, stock allocation and ledger postings have already been
-- written - which is precisely the partial state that must not survive.
\echo '--- Test 4: atomicity on failure ---'
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_showroom   uuid;
  v_customer   uuid;
  v_inventory  uuid;
  v_sales_before  int;
  v_sales_after   int;
  v_stock_status  text;
begin
  select id into v_showroom from public.showrooms where code = 'SALETEST';
  select id into v_customer from public.customers
    where customer_code = 'SALETEST-CUST-1';
  select id into v_inventory from public.inventory
    where stock_code = 'SALETEST-STK-001';

  select count(*) into v_sales_before
  from public.sales where showroom_id = v_showroom;

  begin
    -- A non-existent finance company makes the loan step fail after the sale,
    -- invoice and stock allocation have already been written.
    perform public.create_sale_transaction(jsonb_build_object(
      'showroom_id', v_showroom, 'customer_id', v_customer,
      'sale_type', 'FINANCE', 'paid_amount', 0,
      'items', jsonb_build_array(jsonb_build_object(
        'inventory_id', v_inventory, 'quantity', 1,
        'unit_price', 180000, 'tax_rate', 18)),
      'loan', jsonb_build_object(
        'finance_company_id', '00000000-0000-0000-0000-000000000000',
        'loan_amount', 180000, 'down_payment', 30000,
        'interest_rate', 9.5, 'tenure_months', 36)
    ));
    raise exception 'FAIL: the deliberately broken sale succeeded';
  exception
    when sqlstate 'P0001' then
      -- Our own raise above would also be P0001; distinguish by message.
      if sqlerrm like 'FAIL:%' then raise; end if;
      raise notice 'Sale failed as designed: %', left(sqlerrm, 80);
    when others then
      raise notice 'Sale failed as designed: %', left(sqlerrm, 80);
  end;

  select count(*) into v_sales_after
  from public.sales where showroom_id = v_showroom;

  select status into v_stock_status
  from public.inventory where id = v_inventory;

  if v_sales_after <> v_sales_before then
    raise exception
      'FAIL: % orphaned sale row(s) survived the failure',
      v_sales_after - v_sales_before;
  end if;

  if v_stock_status <> 'AVAILABLE' then
    raise exception
      'FAIL: stock was left as % after a failed sale', v_stock_status;
  end if;

  raise notice
    'PASS: nothing persisted - sales unchanged (%), stock still AVAILABLE',
    v_sales_after;
end $$;
commit;

-- -----------------------------------------------------------------------------
-- Teardown
-- -----------------------------------------------------------------------------
\set QUIET on
do $$
declare v_showroom uuid;
begin
  select id into v_showroom from public.showrooms where code = 'SALETEST';
  if v_showroom is null then return; end if;

  -- See the note in the fixture block: the delete guards are deliberate, so
  -- teardown suspends triggers rather than the guards being relaxed.
  perform set_config('session_replication_role', 'replica', false);

  delete from public.accounting_entries where transaction_id in (
    select id from public.accounting_transactions
    where showroom_id = v_showroom);
  delete from public.accounting_transactions where showroom_id = v_showroom;
  delete from public.payments where showroom_id = v_showroom;
  delete from public.invoice_items where invoice_id in (
    select id from public.invoices where showroom_id = v_showroom);
  delete from public.invoices where showroom_id = v_showroom;
  delete from public.sale_items where sale_id in (
    select id from public.sales where showroom_id = v_showroom);
  delete from public.sales where showroom_id = v_showroom;
  delete from public.vehicle_free_services where showroom_id = v_showroom;
  delete from public.warranties where showroom_id = v_showroom;
  delete from public.customer_vehicles where showroom_id = v_showroom;
  delete from public.stock_movements where showroom_id = v_showroom;
  delete from public.inventory where showroom_id = v_showroom;
  delete from public.customers where showroom_id = v_showroom;
  delete from public.audit_logs where showroom_id = v_showroom;
  delete from public.document_sequences where showroom_id = v_showroom;
  delete from public.accounts where showroom_id = v_showroom;
  delete from public.user_roles where user_id in (
    select id from public.users where showroom_id = v_showroom);
  delete from public.users where showroom_id = v_showroom;
  delete from auth.users where email in ('sale@test.local', 'staff@test.local');
  delete from public.free_service_plans where name like 'Test Free%';
  delete from public.products where name = 'Test Rider 350';
  delete from public.brands where name = 'TestMoto';
  delete from public.finance_companies where code = 'TESTFIN';
  delete from public.showrooms where id = v_showroom;

  perform set_config('session_replication_role', 'origin', false);
end $$;
\set QUIET off

\echo ''
\echo '======================================================'
\echo ' Sale transaction suite complete - all assertions held'
\echo '======================================================'
