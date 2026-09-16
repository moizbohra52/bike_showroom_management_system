-- =============================================================================
-- 013_accounting.sql
--
-- Double-entry accounting: the chart of accounts, the balance invariant, and
-- the per-showroom provisioning that every business transaction depends on.
--
-- -----------------------------------------------------------------------------
-- Why the chart is per showroom
-- -----------------------------------------------------------------------------
-- Each branch reports its own profit and loss, holds its own cash, and
-- reconciles its own bank account. Sharing one set of accounts across branches
-- would make a per-showroom P&L impossible without tagging every line, and
-- tagging is exactly what the showroom_id on the transaction already does.
--
-- Account CODES are identical across showrooms (every branch's cash account is
-- '1001'), which is what lets the business functions post by code without
-- knowing which branch they are in.
-- =============================================================================

-- =============================================================================
-- The balance invariant
--
-- Total debits must equal total credits within a transaction. Enforced by a
-- CONSTRAINT TRIGGER declared DEFERRABLE INITIALLY DEFERRED, which is the only
-- mechanism that works here: the check must run once, after all of a
-- transaction's lines are inserted, not after each one. A regular AFTER ROW
-- trigger would fire on the first line and fail every time, because a single
-- debit with no matching credit is never balanced.
-- =============================================================================
create or replace function public.assert_ledger_balanced()
returns trigger
language plpgsql
as $$
declare
  v_debit  numeric;
  v_credit numeric;
  v_txn    uuid;
begin
  v_txn := coalesce(new.transaction_id, old.transaction_id);

  select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_debit, v_credit
  from public.accounting_entries
  where transaction_id = v_txn;

  -- A transaction whose lines were all removed is not an imbalance.
  if v_debit = 0 and v_credit = 0 then
    return null;
  end if;

  -- The tolerance absorbs a single rounding unit at the paisa boundary;
  -- anything larger is a genuine error in the posting logic.
  if abs(v_debit - v_credit) > 0.01 then
    raise exception
      'Unbalanced accounting transaction %: debits %, credits % (difference %)',
      v_txn, round(v_debit, 2), round(v_credit, 2),
      round(v_debit - v_credit, 2)
      using errcode = 'P0001';
  end if;

  return null;
end;
$$;

drop trigger if exists trg_ledger_balanced on public.accounting_entries;
create constraint trigger trg_ledger_balanced
  after insert or update or delete on public.accounting_entries
  deferrable initially deferred
  for each row execute function public.assert_ledger_balanced();

comment on function public.assert_ledger_balanced() is
  'Deferred constraint trigger asserting debits = credits per transaction. '
  'Deferred because the check is only meaningful once every line is written.';

-- =============================================================================
-- Chart of accounts
--
-- Codes follow the conventional ranges:
--   1xxx assets, 2xxx liabilities, 3xxx equity, 4xxx income, 5xxx expenses
--
-- The business functions in 006b post against these codes by name, so the
-- codes are a contract: renaming one breaks every posting that references it.
-- =============================================================================
create or replace function public.provision_showroom_accounts(
  p_showroom_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_created int := 0;
begin
  insert into public.accounts
    (showroom_id, account_code, account_name, account_type, is_system_account)
  values
    -- ------------------------------------------------------------- assets
    (p_showroom_id, '1001', 'Cash in Hand',        'ASSET',     true),
    (p_showroom_id, '1002', 'Bank Account',        'ASSET',     true),
    (p_showroom_id, '1003', 'Customer Receivable', 'ASSET',     true),
    (p_showroom_id, '1004', 'Inventory',           'ASSET',     true),
    (p_showroom_id, '1005', 'Input Tax Credit',    'ASSET',     true),
    (p_showroom_id, '1006', 'Advance to Supplier', 'ASSET',     true),
    (p_showroom_id, '1007', 'Fixed Assets',        'ASSET',     true),

    -- -------------------------------------------------------- liabilities
    (p_showroom_id, '2001', 'Supplier Payable',    'LIABILITY', true),
    (p_showroom_id, '2002', 'Tax Payable',         'LIABILITY', true),
    (p_showroom_id, '2003', 'Customer Advance',    'LIABILITY', true),
    (p_showroom_id, '2004', 'Salary Payable',      'LIABILITY', true),
    (p_showroom_id, '2005', 'Finance Payable',     'LIABILITY', true),

    -- ------------------------------------------------------------- equity
    (p_showroom_id, '3001', 'Owner Capital',       'EQUITY',    true),
    (p_showroom_id, '3002', 'Retained Earnings',   'EQUITY',    true),

    -- ------------------------------------------------------------- income
    (p_showroom_id, '4001', 'Vehicle Sales Revenue', 'INCOME',  true),
    (p_showroom_id, '4002', 'Service Revenue',       'INCOME',  true),
    (p_showroom_id, '4003', 'Other Income',          'INCOME',  true),
    (p_showroom_id, '4004', 'Accessory Sales',       'INCOME',  true),
    (p_showroom_id, '4005', 'Finance Commission',    'INCOME',  true),

    -- ------------------------------------------------------------ expenses
    (p_showroom_id, '5001', 'Cost of Goods Sold',  'EXPENSE',   true),
    (p_showroom_id, '5002', 'Discount Allowed',    'EXPENSE',   true),
    (p_showroom_id, '5101', 'Rent Expense',        'EXPENSE',   true),
    (p_showroom_id, '5102', 'Electricity Expense', 'EXPENSE',   true),
    (p_showroom_id, '5103', 'Salary Expense',      'EXPENSE',   true),
    (p_showroom_id, '5104', 'Transport Expense',   'EXPENSE',   true),
    (p_showroom_id, '5105', 'Marketing Expense',   'EXPENSE',   true),
    (p_showroom_id, '5106', 'Maintenance Expense', 'EXPENSE',   true),
    (p_showroom_id, '5107', 'Office Expense',      'EXPENSE',   true),
    (p_showroom_id, '5108', 'Fuel Expense',        'EXPENSE',   true),
    (p_showroom_id, '5109', 'Insurance Expense',   'EXPENSE',   true),
    (p_showroom_id, '5110', 'Professional Fees',   'EXPENSE',   true),
    (p_showroom_id, '5111', 'Bank Charges',        'EXPENSE',   true),
    -- The fallback every uncategorised expense posts to, referenced by
    -- approve_expense() when a category has no account_code of its own.
    (p_showroom_id, '5199', 'Other Expense',       'EXPENSE',   true)
  on conflict (showroom_id, account_code) do nothing;

  get diagnostics v_created = row_count;
  return v_created;
end;
$$;

comment on function public.provision_showroom_accounts(uuid) is
  'Creates the standard chart of accounts for a showroom. Idempotent.';

-- Every showroom needs its accounts before any transaction can post, so this
-- runs automatically when a showroom is created. Doing it by trigger rather
-- than asking the caller to remember means a branch can never exist in a state
-- where its first sale fails on a missing account.
create or replace function public.provision_accounts_on_showroom_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.provision_showroom_accounts(new.id);
  return new;
end;
$$;

drop trigger if exists trg_showroom_provision_accounts on public.showrooms;
create trigger trg_showroom_provision_accounts
  after insert on public.showrooms
  for each row execute function public.provision_accounts_on_showroom_insert();

-- Back-fill any showroom that predates this migration.
do $$
declare
  v_showroom record;
  v_total int := 0;
begin
  for v_showroom in
    select id from public.showrooms where is_deleted = false
  loop
    v_total := v_total + public.provision_showroom_accounts(v_showroom.id);
  end loop;

  if v_total > 0 then
    raise notice 'Provisioned % accounts across existing showrooms', v_total;
  end if;
end $$;

-- =============================================================================
-- Expense categories, mapped to their ledger accounts
-- =============================================================================
insert into public.expense_categories (name, description, account_code) values
  ('Rent',        'Premises rent',                      '5101'),
  ('Electricity', 'Power and utilities',                '5102'),
  ('Salary',      'Staff salaries and wages',           '5103'),
  ('Transport',   'Vehicle transport and logistics',    '5104'),
  ('Marketing',   'Advertising and promotion',          '5105'),
  ('Maintenance', 'Repairs and upkeep',                 '5106'),
  ('Office',      'Stationery and office supplies',     '5107'),
  ('Fuel',        'Fuel for company vehicles',          '5108'),
  ('Insurance',   'Business insurance premiums',        '5109'),
  ('Professional Fees', 'Legal, audit and consultancy', '5110'),
  ('Bank Charges', 'Bank and payment gateway fees',     '5111'),
  ('Other',       'Uncategorised expenditure',          '5199')
on conflict (name) do update
  set account_code = excluded.account_code,
      description = excluded.description;

-- =============================================================================
-- Reporting helpers
-- =============================================================================

-- Balance of a single account over a period.
--
-- The sign convention matters: assets and expenses increase with a debit, so
-- their balance is debits minus credits; liabilities, equity and income are
-- the other way round. Returning a naturally-signed figure means a report can
-- present it without knowing the account type.
create or replace function public.account_balance(
  p_account_id uuid,
  p_from       date default null,
  p_to         date default null
)
returns numeric
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_type    text;
  v_debit   numeric;
  v_credit  numeric;
begin
  select account_type into v_type
  from public.accounts where id = p_account_id;

  if v_type is null then
    return 0;
  end if;

  select coalesce(sum(e.debit), 0), coalesce(sum(e.credit), 0)
  into v_debit, v_credit
  from public.accounting_entries e
  join public.accounting_transactions t on t.id = e.transaction_id
  where e.account_id = p_account_id
    and (p_from is null or t.transaction_date >= p_from)
    and (p_to is null or t.transaction_date <= p_to);

  return case
    when v_type in ('ASSET', 'EXPENSE') then round(v_debit - v_credit, 2)
    else round(v_credit - v_debit, 2)
  end;
end;
$$;

-- Profit and loss for a showroom over a period.
create or replace function public.profit_and_loss(
  p_showroom_id uuid,
  p_from        date,
  p_to          date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_income    numeric;
  v_expense   numeric;
  v_lines     jsonb;
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  select
    coalesce(sum(case when a.account_type = 'INCOME'
                 then e.credit - e.debit else 0 end), 0),
    coalesce(sum(case when a.account_type = 'EXPENSE'
                 then e.debit - e.credit else 0 end), 0)
  into v_income, v_expense
  from public.accounting_entries e
  join public.accounting_transactions t on t.id = e.transaction_id
  join public.accounts a on a.id = e.account_id
  where t.showroom_id = p_showroom_id
    and t.transaction_date between p_from and p_to
    and a.account_type in ('INCOME', 'EXPENSE');

  select coalesce(jsonb_agg(line order by line ->> 'account_code'), '[]')
  into v_lines
  from (
    select jsonb_build_object(
      'account_code', a.account_code,
      'account_name', a.account_name,
      'account_type', a.account_type,
      'amount', round(
        case when a.account_type = 'INCOME'
             then sum(e.credit - e.debit)
             else sum(e.debit - e.credit) end, 2)
    ) as line
    from public.accounting_entries e
    join public.accounting_transactions t on t.id = e.transaction_id
    join public.accounts a on a.id = e.account_id
    where t.showroom_id = p_showroom_id
      and t.transaction_date between p_from and p_to
      and a.account_type in ('INCOME', 'EXPENSE')
    group by a.account_code, a.account_name, a.account_type
    having sum(e.debit) <> 0 or sum(e.credit) <> 0
  ) s;

  return jsonb_build_object(
    'showroom_id',   p_showroom_id,
    'from',          p_from,
    'to',            p_to,
    'total_income',  round(v_income, 2),
    'total_expense', round(v_expense, 2),
    'net_profit',    round(v_income - v_expense, 2),
    'lines',         v_lines
  );
end;
$$;
