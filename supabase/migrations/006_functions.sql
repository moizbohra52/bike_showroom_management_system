-- =============================================================================
-- 006_functions.sql
--
-- Server-side functions: authorisation helpers, document numbering, EMI
-- mathematics, the accounting primitive, and the atomic business transactions.
--
-- -----------------------------------------------------------------------------
-- On SECURITY DEFINER and RLS recursion
-- -----------------------------------------------------------------------------
-- The authorisation helpers read `public.users`, `user_roles` and
-- `role_permissions`. Those tables are themselves protected by RLS policies
-- that call these very helpers. Evaluating a policy would therefore re-enter
-- the policy, and PostgreSQL would either recurse infinitely or error.
--
-- SECURITY DEFINER breaks the cycle: the function executes as its owner, and a
-- table's owner is exempt from that table's RLS (provided FORCE ROW LEVEL
-- SECURITY is not set, which this schema deliberately never sets).
--
-- Every SECURITY DEFINER function below pins `search_path`. Without that, a
-- caller could create a malicious `users` table in a schema earlier on their
-- own search_path and the definer-rights function would read it instead -
-- a privilege-escalation route, not a theoretical one.
-- =============================================================================

-- =============================================================================
-- Authorisation helpers
-- =============================================================================

-- Maps the Supabase auth user to the application profile id.
create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select u.id
  from public.users u
  where u.auth_user_id = auth.uid()
    and u.is_deleted = false
  limit 1;
$$;

comment on function public.current_user_id() is
  'public.users.id for the current JWT. SECURITY DEFINER so RLS policies on '
  'users can call it without recursing into themselves.';

-- Whether the caller holds the SUPER ADMIN role.
create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select exists (
    select 1
    from public.users u
    join public.user_roles ur on ur.user_id = u.id
    join public.roles r on r.id = ur.role_id
    where u.auth_user_id = auth.uid()
      and u.is_deleted = false
      and u.status = 'ACTIVE'
      and r.name = 'SUPER ADMIN'
  );
$$;

-- Whether the caller may act within a given showroom.
--
-- This is the tenancy boundary. Every business-table RLS policy calls it, so
-- a user can never read or write another showroom's rows regardless of what
-- the client sends.
create or replace function public.can_access_showroom(p_showroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select
    case
      when p_showroom_id is null then false
      when public.is_super_admin() then true
      else exists (
        select 1
        from public.users u
        where u.auth_user_id = auth.uid()
          and u.is_deleted = false
          and u.status = 'ACTIVE'
          and (
            u.showroom_id = p_showroom_id
            or exists (
              select 1
              from public.user_showrooms us
              where us.user_id = u.id
                and us.showroom_id = p_showroom_id
            )
          )
      )
    end;
$$;

-- Whether the caller holds `module.action`.
--
-- The client caches an equivalent permission set to decide what to render;
-- this is the check that actually governs access, invoked from RLS policies.
create or replace function public.has_permission(
  p_module text,
  p_action text
)
returns boolean
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select
    case
      when public.is_super_admin() then true
      else exists (
        select 1
        from public.users u
        join public.user_roles ur on ur.user_id = u.id
        join public.role_permissions rp on rp.role_id = ur.role_id
        join public.permissions p on p.id = rp.permission_id
        where u.auth_user_id = auth.uid()
          and u.is_deleted = false
          and u.status = 'ACTIVE'
          and p.module = p_module
          and p.action = p_action
      )
    end;
$$;

-- Every showroom id the caller may reach. Used by RLS policies that need a
-- set rather than a single-showroom test.
create or replace function public.accessible_showroom_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select s.id
  from public.showrooms s
  where public.is_super_admin()
    and s.is_deleted = false
  union
  select u.showroom_id
  from public.users u
  where u.auth_user_id = auth.uid()
    and u.is_deleted = false
    and u.showroom_id is not null
  union
  select us.showroom_id
  from public.user_showrooms us
  join public.users u on u.id = us.user_id
  where u.auth_user_id = auth.uid()
    and u.is_deleted = false;
$$;

-- -----------------------------------------------------------------------------
-- current_user_context
--
-- Resolves the whole identity + authorisation chain in ONE round trip:
--   auth.uid() -> users -> user_roles -> roles -> role_permissions
--              -> permissions -> accessible showrooms
--
-- Doing this client-side as five queries would make each query subject to RLS
-- policies that themselves need this context, which is exactly the recursion
-- this function exists to avoid. It is also one network round trip instead of
-- five on a showroom's mobile connection.
-- -----------------------------------------------------------------------------
create or replace function public.current_user_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user        public.users%rowtype;
  v_is_super    boolean;
  v_roles       jsonb;
  v_permissions jsonb;
  v_showrooms   jsonb;
begin
  select * into v_user
  from public.users
  where auth_user_id = auth.uid()
    and is_deleted = false
  limit 1;

  -- No profile row. The caller authenticated but was never onboarded, so the
  -- client shows the blocked-account screen rather than an empty dashboard.
  if not found then
    return null;
  end if;

  v_is_super := public.is_super_admin();

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'description', r.description,
        'is_system_role', r.is_system_role
      )
      order by r.name
    ),
    '[]'::jsonb
  )
  into v_roles
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = v_user.id;

  -- A super admin gets the flag rather than an enumerated list, so adding a
  -- permission later does not require re-seeding existing super admins.
  if v_is_super then
    v_permissions := '[]'::jsonb;
  else
    select coalesce(
      jsonb_agg(distinct (p.module || '.' || p.action)),
      '[]'::jsonb
    )
    into v_permissions
    from public.user_roles ur
    join public.role_permissions rp on rp.role_id = ur.role_id
    join public.permissions p on p.id = rp.permission_id
    where ur.user_id = v_user.id;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'code', s.code,
        'address', s.address,
        'city', s.city,
        'state', s.state,
        'pincode', s.pincode,
        'phone', s.phone,
        'email', s.email,
        'gst_number', s.gst_number,
        'pan_number', s.pan_number,
        'invoice_prefix', s.invoice_prefix,
        'logo_url', s.logo_url,
        'status', s.status,
        'settings', s.settings,
        'revision', s.revision
      )
      order by s.name
    ),
    '[]'::jsonb
  )
  into v_showrooms
  from public.showrooms s
  where s.is_deleted = false
    and s.status = 'ACTIVE'
    and (
      v_is_super
      or s.id = v_user.showroom_id
      or exists (
        select 1 from public.user_showrooms us
        where us.user_id = v_user.id and us.showroom_id = s.id
      )
    );

  return jsonb_build_object(
    'user', jsonb_build_object(
      'id', v_user.id,
      'auth_user_id', v_user.auth_user_id,
      'showroom_id', v_user.showroom_id,
      'name', v_user.name,
      'email', v_user.email,
      'phone', v_user.phone,
      'status', v_user.status,
      'avatar_url', v_user.avatar_url,
      'employee_code', v_user.employee_code,
      'designation', v_user.designation,
      'last_login_at', v_user.last_login_at,
      'revision', v_user.revision,
      'created_at', v_user.created_at,
      'updated_at', v_user.updated_at,
      'roles', v_roles
    ),
    'is_super_admin', v_is_super,
    'permissions', v_permissions,
    'showrooms', v_showrooms,
    'active_showroom_id', v_user.showroom_id
  );
end;
$$;

comment on function public.current_user_context() is
  'Single-round-trip resolution of identity, roles, permissions and accessible '
  'showrooms. Consumed by AuthService.resolveContext() on the client.';

-- =============================================================================
-- Document numbering
--
-- Gap-free per showroom, per document type, per financial year.
--
-- A PostgreSQL sequence is deliberately NOT used: sequences are non
-- transactional, so a rolled-back sale would consume an invoice number and
-- leave a permanent gap. Tax authorities expect invoice numbers to be
-- contiguous within a financial year, so the counter is a row locked with
-- FOR UPDATE inside the caller's transaction.
--
-- The lock serialises concurrent sales in the same showroom for the duration
-- of the transaction. That is the intended trade: correctness of a statutory
-- number over throughput on a counter that is touched once per document.
-- =============================================================================
create or replace function public.next_document_number(
  p_showroom_id   uuid,
  p_document_type text,
  p_date          date default current_date
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_financial_year text;
  v_next           bigint;
  v_showroom_code  text;
  v_prefix         text;
begin
  if p_showroom_id is null then
    raise exception 'A showroom is required to generate a document number'
      using errcode = 'P0001';
  end if;

  v_financial_year := public.financial_year_code(p_date);

  select coalesce(nullif(btrim(invoice_prefix), ''), code)
  into v_showroom_code
  from public.showrooms
  where id = p_showroom_id;

  if v_showroom_code is null then
    raise exception 'Showroom % was not found', p_showroom_id
      using errcode = 'P0001';
  end if;

  v_prefix := case p_document_type
    when 'SALE'     then 'SAL'
    when 'INVOICE'  then 'INV'
    when 'PAYMENT'  then 'PAY'
    when 'PURCHASE' then 'PUR'
    when 'SERVICE'  then 'SRV'
    when 'EXPENSE'  then 'EXP'
    when 'LOAN'     then 'LON'
    when 'CUSTOMER' then 'CUS'
    when 'STOCK'    then 'STK'
    when 'TRANSFER' then 'TRF'
    when 'CLAIM'    then 'CLM'
    when 'JOURNAL'  then 'JRN'
    else 'DOC'
  end;

  -- Create the counter if this is the first document of its kind this year.
  insert into public.document_sequences
    (showroom_id, document_type, financial_year, prefix, current_value)
  values
    (p_showroom_id, p_document_type, v_financial_year, v_prefix, 0)
  on conflict (showroom_id, document_type, financial_year) do nothing;

  -- Lock and increment. Held until the caller's transaction ends, so a
  -- rollback returns the number to the pool.
  update public.document_sequences
  set current_value = current_value + 1,
      updated_at = now()
  where showroom_id = p_showroom_id
    and document_type = p_document_type
    and financial_year = v_financial_year
  returning current_value into v_next;

  return format(
    '%s/%s/%s/%s',
    v_showroom_code,
    v_prefix,
    v_financial_year,
    lpad(v_next::text, 5, '0')
  );
end;
$$;

comment on function public.next_document_number(uuid, text, date) is
  'Gap-free document number. Uses a locked counter row rather than a sequence '
  'so a rolled-back transaction does not burn a statutory invoice number.';

-- =============================================================================
-- EMI mathematics
-- =============================================================================

-- Equated Monthly Instalment.
--
--   EMI = P x r x (1+r)^n / ((1+r)^n - 1)
--
-- where P is principal, r the MONTHLY rate as a fraction, n the tenure in
-- months. The zero-rate case is handled separately because the formula
-- divides by zero when r = 0.
--
-- FLAT interest is a different product entirely: total interest is computed on
-- the full principal for the whole tenure and spread evenly, which is why it
-- yields a higher effective rate than the nominal figure suggests.
create or replace function public.calculate_emi(
  p_principal     numeric,
  p_annual_rate   numeric,
  p_tenure_months integer,
  p_interest_type text default 'REDUCING'
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_monthly_rate numeric;
  v_growth       numeric;
  v_emi          numeric;
  v_total        numeric;
begin
  if p_principal is null or p_principal <= 0 then
    raise exception 'Loan principal must be greater than zero'
      using errcode = 'P0001';
  end if;

  if p_tenure_months is null or p_tenure_months <= 0 then
    raise exception 'Loan tenure must be at least one month'
      using errcode = 'P0001';
  end if;

  if p_annual_rate is null or p_annual_rate < 0 then
    raise exception 'Interest rate cannot be negative'
      using errcode = 'P0001';
  end if;

  -- Interest-free finance is a real promotional product.
  if p_annual_rate = 0 then
    return round(p_principal / p_tenure_months, 2);
  end if;

  if upper(p_interest_type) = 'FLAT' then
    v_total := p_principal
      + (p_principal * (p_annual_rate / 100.0)
         * (p_tenure_months / 12.0));
    return round(v_total / p_tenure_months, 2);
  end if;

  v_monthly_rate := (p_annual_rate / 100.0) / 12.0;
  -- (1+r)^n. numeric ^ numeric keeps full precision; float8 would drift on a
  -- long tenure and shift the final instalment by rupees, not paise.
  v_growth := power(1 + v_monthly_rate, p_tenure_months::numeric);

  v_emi := p_principal * v_monthly_rate * v_growth / (v_growth - 1);

  return round(v_emi, 2);
end;
$$;

comment on function public.calculate_emi(numeric, numeric, integer, text) is
  'EMI = P*r*(1+r)^n/((1+r)^n-1) for REDUCING; even spread for FLAT.';

-- Builds the complete repayment schedule for a loan.
--
-- Generated in full at loan creation so the customer has their whole plan from
-- day one, and so the EMI dashboards can query due dates without simulating.
--
-- Two details that matter:
--  * Due dates use add_months(), which clamps to month end. A loan starting
--    31 January bills on 28 February, never 3 March.
--  * The final instalment absorbs accumulated rounding, so the sum of the
--    principal column equals the loan amount exactly. Without this the closing
--    balance ends a few paise from zero and the loan never closes cleanly.
create or replace function public.generate_emi_schedule(p_loan_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_loan           public.loans%rowtype;
  v_monthly_rate   numeric;
  v_balance        numeric;
  v_interest       numeric;
  v_principal      numeric;
  v_due_date       date;
  v_count          integer := 0;
  i                integer;
begin
  select * into v_loan from public.loans where id = p_loan_id;
  if not found then
    raise exception 'Loan % was not found', p_loan_id using errcode = 'P0001';
  end if;

  -- Regenerating over an existing schedule would silently discard recorded
  -- payments, so it is refused.
  if exists (
    select 1 from public.emi_schedules
    where loan_id = p_loan_id and paid_amount > 0
  ) then
    raise exception
      'This loan already has recorded EMI payments and cannot be regenerated'
      using errcode = 'P0001';
  end if;

  delete from public.emi_schedules where loan_id = p_loan_id;

  v_balance := v_loan.loan_amount;
  v_monthly_rate := (v_loan.interest_rate / 100.0) / 12.0;

  for i in 1 .. v_loan.tenure_months loop
    v_due_date := public.add_months(v_loan.start_date, i);

    if v_loan.interest_rate = 0 then
      v_interest := 0;
      v_principal := round(v_loan.emi_amount, 2);
    elsif upper(v_loan.interest_type) = 'FLAT' then
      -- Flat interest spreads the total interest evenly across instalments.
      v_interest := round(
        (v_loan.loan_amount * (v_loan.interest_rate / 100.0)
         * (v_loan.tenure_months / 12.0)) / v_loan.tenure_months,
        2
      );
      v_principal := round(v_loan.emi_amount - v_interest, 2);
    else
      -- Reducing balance: interest accrues on what is still outstanding.
      v_interest := round(v_balance * v_monthly_rate, 2);
      v_principal := round(v_loan.emi_amount - v_interest, 2);
    end if;

    -- Final instalment absorbs the rounding residue so the principal column
    -- sums exactly to the loan amount and the balance closes at zero.
    if i = v_loan.tenure_months then
      v_principal := round(v_balance, 2);
    end if;

    if v_principal > v_balance then
      v_principal := round(v_balance, 2);
    end if;

    insert into public.emi_schedules (
      loan_id, emi_number, due_date,
      principal_amount, interest_amount, emi_amount,
      paid_amount, remaining_amount, status
    ) values (
      p_loan_id, i, v_due_date,
      v_principal, v_interest, round(v_principal + v_interest, 2),
      0, round(v_principal + v_interest, 2),
      case when v_due_date < current_date then 'OVERDUE'
           when v_due_date = current_date then 'DUE'
           else 'UPCOMING' end
    );

    v_balance := round(v_balance - v_principal, 2);
    v_count := v_count + 1;
  end loop;

  update public.loans
  set end_date = public.add_months(v_loan.start_date, v_loan.tenure_months),
      status = case when status = 'PENDING' then 'ACTIVE' else status end,
      updated_at = now()
  where id = p_loan_id;

  return v_count;
end;
$$;

comment on function public.generate_emi_schedule(uuid) is
  'Builds the full instalment schedule. Month-end clamped due dates; the final '
  'instalment absorbs rounding so principal sums exactly to the loan amount.';

-- Recomputes instalment statuses. Run nightly by the scheduled job in
-- 012_reminders.sql; statuses are never trusted from the client.
create or replace function public.refresh_emi_statuses()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_updated integer;
begin
  update public.emi_schedules e
  set status = case
        when e.paid_amount >= e.emi_amount + e.penalty_amount - 0.01
          then 'PAID'
        when e.paid_amount > 0 and e.due_date >= current_date then 'PARTIAL'
        when e.paid_amount > 0 and e.due_date < current_date then 'OVERDUE'
        when e.due_date < current_date then 'OVERDUE'
        when e.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end,
      updated_at = now()
  from public.loans l
  where l.id = e.loan_id
    and l.status = 'ACTIVE'
    and e.status <> 'CANCELLED'
    and e.status is distinct from (
      case
        when e.paid_amount >= e.emi_amount + e.penalty_amount - 0.01
          then 'PAID'
        when e.paid_amount > 0 and e.due_date >= current_date then 'PARTIAL'
        when e.paid_amount > 0 and e.due_date < current_date then 'OVERDUE'
        when e.due_date < current_date then 'OVERDUE'
        when e.due_date = current_date then 'DUE'
        else 'UPCOMING'
      end
    );

  get diagnostics v_updated = row_count;

  -- Close loans whose instalments are all settled.
  update public.loans l
  set status = 'CLOSED', updated_at = now()
  where l.status = 'ACTIVE'
    and not exists (
      select 1 from public.emi_schedules e
      where e.loan_id = l.id and e.status not in ('PAID', 'CANCELLED')
    );

  return v_updated;
end;
$$;

-- =============================================================================
-- Accounting primitive
--
-- The single entry point for writing to the ledger. Takes the lines as jsonb
-- so a caller can post an arbitrary balanced journal, and asserts the
-- fundamental invariant before returning.
-- =============================================================================

-- Resolves a showroom's account by code, which is how business functions refer
-- to accounts without hard-coding uuids.
create or replace function public.resolve_account(
  p_showroom_id  uuid,
  p_account_code text
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
begin
  select id into v_id
  from public.accounts
  where showroom_id = p_showroom_id
    and account_code = p_account_code
    and status = 'ACTIVE';

  if v_id is null then
    raise exception
      'Ledger account % is not configured for this showroom', p_account_code
      using errcode = 'P0001',
            hint = 'Run the chart-of-accounts seed for this showroom.';
  end if;

  return v_id;
end;
$$;

-- Writes a balanced accounting transaction.
--
-- `p_entries` is a jsonb array of
--   {"account_code": "1001", "debit": 100, "credit": 0, "description": "..."}
create or replace function public.create_accounting_transaction(
  p_showroom_id     uuid,
  p_transaction_date date,
  p_reference_type  text,
  p_reference_id    uuid,
  p_description     text,
  p_entries         jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_transaction_id uuid;
  v_entry          jsonb;
  v_total_debit    numeric := 0;
  v_total_credit   numeric := 0;
  v_debit          numeric;
  v_credit         numeric;
begin
  if p_entries is null or jsonb_array_length(p_entries) = 0 then
    raise exception 'An accounting transaction needs at least one entry'
      using errcode = 'P0001';
  end if;

  -- Assert the fundamental invariant before writing anything, so an
  -- unbalanced journal never reaches the ledger even briefly.
  for v_entry in select * from jsonb_array_elements(p_entries) loop
    v_debit  := coalesce((v_entry ->> 'debit')::numeric, 0);
    v_credit := coalesce((v_entry ->> 'credit')::numeric, 0);
    v_total_debit  := v_total_debit + v_debit;
    v_total_credit := v_total_credit + v_credit;
  end loop;

  if abs(v_total_debit - v_total_credit) > 0.01 then
    raise exception
      'Accounting entry is not balanced: debits %, credits %',
      round(v_total_debit, 2), round(v_total_credit, 2)
      using errcode = 'P0001';
  end if;

  insert into public.accounting_transactions (
    showroom_id, transaction_date, reference_type, reference_id,
    description, created_by
  ) values (
    p_showroom_id, coalesce(p_transaction_date, current_date),
    p_reference_type, p_reference_id, p_description, public.current_user_id()
  )
  returning id into v_transaction_id;

  for v_entry in select * from jsonb_array_elements(p_entries) loop
    v_debit  := round(coalesce((v_entry ->> 'debit')::numeric, 0), 2);
    v_credit := round(coalesce((v_entry ->> 'credit')::numeric, 0), 2);

    -- Skip zero-value lines rather than failing the single-side CHECK: a
    -- caller building entries generically may legitimately emit a zero tax
    -- line when the rate is zero.
    if v_debit = 0 and v_credit = 0 then
      continue;
    end if;

    insert into public.accounting_entries (
      transaction_id, account_id, debit, credit, description
    ) values (
      v_transaction_id,
      public.resolve_account(p_showroom_id, v_entry ->> 'account_code'),
      v_debit,
      v_credit,
      v_entry ->> 'description'
    );
  end loop;

  return v_transaction_id;
end;
$$;

comment on function public.create_accounting_transaction is
  'Only sanctioned write path to the ledger. Refuses an unbalanced journal.';
