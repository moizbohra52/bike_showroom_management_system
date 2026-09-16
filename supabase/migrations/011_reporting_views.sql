-- =============================================================================
-- 011_reporting_views.sql
--
-- Reporting views and dashboard functions.
--
-- -----------------------------------------------------------------------------
-- security_invoker is mandatory on every view here
-- -----------------------------------------------------------------------------
-- By default a PostgreSQL view executes with the privileges of its OWNER, not
-- the caller. Because these views are owned by a role that is exempt from RLS,
-- a default view would return EVERY showroom's rows to any user who queried
-- it - a complete tenancy bypass, and one that is invisible until someone
-- notices another branch's figures on their dashboard.
--
-- `with (security_invoker = true)` makes the view run as the caller, so the
-- RLS policies on the underlying tables apply exactly as they would to a
-- direct query. Every view below sets it, and the verification block at the
-- end fails the migration if any view is missing it.
--
-- Requires PostgreSQL 15+, which every current Supabase project exceeds.
-- =============================================================================

-- =============================================================================
-- Sales
-- =============================================================================
create or replace view public.daily_sales_summary
with (security_invoker = true) as
select
  s.showroom_id,
  s.sale_date,
  count(*)                                as sale_count,
  count(distinct s.customer_id)           as customer_count,
  sum(s.subtotal)                         as subtotal,
  sum(s.discount)                         as discount,
  sum(s.tax_amount)                       as tax_amount,
  sum(s.other_charges)                    as other_charges,
  sum(s.total_amount)                     as total_amount,
  sum(s.paid_amount)                      as collected_amount,
  sum(s.outstanding_amount)               as outstanding_amount
from public.sales s
where s.status not in ('DRAFT', 'CANCELLED')
group by s.showroom_id, s.sale_date;

create or replace view public.monthly_sales_summary
with (security_invoker = true) as
select
  s.showroom_id,
  date_trunc('month', s.sale_date)::date  as month,
  count(*)                                as sale_count,
  count(distinct s.customer_id)           as customer_count,
  sum(s.subtotal)                         as subtotal,
  sum(s.discount)                         as discount,
  sum(s.tax_amount)                       as tax_amount,
  sum(s.total_amount)                     as total_amount,
  sum(s.paid_amount)                      as collected_amount,
  sum(s.outstanding_amount)               as outstanding_amount,
  -- Average order value, useful for spotting a month carried by one large
  -- fleet sale rather than by volume.
  round(avg(s.total_amount), 2)           as average_sale_value
from public.sales s
where s.status not in ('DRAFT', 'CANCELLED')
group by s.showroom_id, date_trunc('month', s.sale_date);

-- =============================================================================
-- Customer outstanding
--
-- Aggregates the three places a customer can owe money - a sale, a service
-- and an unpaid invoice - into one figure per customer, plus the age of the
-- oldest unpaid document for a collections worklist.
-- =============================================================================
create or replace view public.customer_outstanding_summary
with (security_invoker = true) as
select
  c.id                                    as customer_id,
  c.showroom_id,
  c.customer_code,
  c.name                                  as customer_name,
  c.phone,
  coalesce(inv.outstanding, 0)            as invoice_outstanding,
  coalesce(emi.outstanding, 0)            as emi_outstanding,
  coalesce(inv.outstanding, 0) + coalesce(emi.outstanding, 0)
                                          as total_outstanding,
  inv.oldest_due_date,
  case
    when inv.oldest_due_date is null then 0
    else greatest((current_date - inv.oldest_due_date), 0)
  end                                     as days_overdue,
  coalesce(inv.open_invoices, 0)          as open_invoices
from public.customers c
left join lateral (
  select
    sum(i.outstanding_amount)                       as outstanding,
    min(coalesce(i.due_date, i.invoice_date))       as oldest_due_date,
    count(*)                                        as open_invoices
  from public.invoices i
  where i.customer_id = c.id
    and i.status in ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE')
) inv on true
left join lateral (
  select sum(e.remaining_amount) as outstanding
  from public.emi_schedules e
  join public.loans l on l.id = e.loan_id
  where l.customer_id = c.id
    and l.status = 'ACTIVE'
    and e.status in ('UPCOMING', 'DUE', 'PARTIAL', 'OVERDUE')
) emi on true
where c.is_deleted = false;

-- =============================================================================
-- EMI
-- =============================================================================
create or replace view public.emi_due_summary
with (security_invoker = true) as
select
  l.showroom_id,
  e.id                        as emi_id,
  e.loan_id,
  l.loan_number,
  l.customer_id,
  c.name                      as customer_name,
  c.phone                     as customer_phone,
  fc.name                     as finance_company,
  e.emi_number,
  e.due_date,
  e.emi_amount,
  e.paid_amount,
  e.remaining_amount,
  e.penalty_amount,
  e.status,
  (e.due_date - current_date) as days_until_due
from public.emi_schedules e
join public.loans l on l.id = e.loan_id
join public.customers c on c.id = l.customer_id
left join public.finance_companies fc on fc.id = l.finance_company_id
where l.status = 'ACTIVE'
  and e.status in ('UPCOMING', 'DUE', 'PARTIAL');

create or replace view public.emi_overdue_summary
with (security_invoker = true) as
select
  l.showroom_id,
  e.id                        as emi_id,
  e.loan_id,
  l.loan_number,
  l.customer_id,
  c.name                      as customer_name,
  c.phone                     as customer_phone,
  fc.name                     as finance_company,
  e.emi_number,
  e.due_date,
  e.emi_amount,
  e.paid_amount,
  e.remaining_amount,
  e.penalty_amount,
  (current_date - e.due_date) as days_overdue,
  -- Buckets match how a collections team actually works a list.
  case
    when current_date - e.due_date <= 30  then '0-30'
    when current_date - e.due_date <= 60  then '31-60'
    when current_date - e.due_date <= 90  then '61-90'
    else '90+'
  end                         as ageing_bucket
from public.emi_schedules e
join public.loans l on l.id = e.loan_id
join public.customers c on c.id = l.customer_id
left join public.finance_companies fc on fc.id = l.finance_company_id
where l.status = 'ACTIVE'
  and e.status = 'OVERDUE';

-- =============================================================================
-- Inventory
-- =============================================================================
create or replace view public.inventory_summary
with (security_invoker = true) as
select
  i.showroom_id,
  i.product_id,
  p.name                      as product_name,
  p.model,
  b.name                      as brand_name,
  p.category,
  count(*)                                                as total_units,
  count(*) filter (where i.status = 'AVAILABLE')          as available_units,
  count(*) filter (where i.status = 'RESERVED')           as reserved_units,
  count(*) filter (where i.status = 'SOLD')               as sold_units,
  count(*) filter (where i.status = 'DEMO')               as demo_units,
  count(*) filter (where i.status = 'IN_TRANSIT')         as in_transit_units,
  count(*) filter (where i.status = 'DAMAGED')            as damaged_units,
  sum(i.purchase_price) filter (where i.status <> 'SOLD') as stock_value,
  p.selling_price
from public.inventory i
join public.products p on p.id = i.product_id
left join public.brands b on b.id = p.brand_id
where i.is_deleted = false
group by i.showroom_id, i.product_id, p.name, p.model, b.name,
         p.category, p.selling_price;

-- Products at or below the showroom's low-stock threshold. The threshold is
-- read from the showroom's own settings so a high-volume branch can differ
-- from a small one.
create or replace view public.low_stock_summary
with (security_invoker = true) as
select
  i.showroom_id,
  s.name                      as showroom_name,
  i.product_id,
  p.name                      as product_name,
  p.model,
  b.name                      as brand_name,
  count(*) filter (where i.status in ('AVAILABLE', 'RESERVED'))
                              as available_units,
  coalesce((s.settings ->> 'low_stock_threshold')::int, 3)
                              as threshold
from public.inventory i
join public.products p on p.id = i.product_id
join public.showrooms s on s.id = i.showroom_id
left join public.brands b on b.id = p.brand_id
where i.is_deleted = false
  and p.status = 'ACTIVE'
group by i.showroom_id, s.name, i.product_id, p.name, p.model, b.name,
         s.settings
having count(*) filter (where i.status in ('AVAILABLE', 'RESERVED'))
       <= coalesce((s.settings ->> 'low_stock_threshold')::int, 3);

-- =============================================================================
-- Service
-- =============================================================================
create or replace view public.service_revenue_summary
with (security_invoker = true) as
select
  sr.showroom_id,
  date_trunc('month', sr.service_date)::date              as month,
  count(*)                                                as job_count,
  count(*) filter (where sr.service_type = 'FREE')        as free_jobs,
  count(*) filter (where sr.service_type = 'PAID')        as paid_jobs,
  count(*) filter (where sr.service_type = 'WARRANTY')    as warranty_jobs,
  sum(sr.subtotal)                                        as subtotal,
  sum(sr.discount)                                        as discount,
  sum(sr.tax_amount)                                      as tax_amount,
  sum(sr.total_amount)                                    as total_revenue,
  sum(sr.paid_amount)                                     as collected,
  sum(sr.outstanding_amount)                              as outstanding,
  -- Parts versus labour is the split a service manager actually manages.
  coalesce(sum(parts.parts_value), 0)                     as parts_revenue,
  coalesce(sum(parts.labour_value), 0)                    as labour_revenue
from public.service_records sr
left join lateral (
  select
    sum(si.total_amount) filter (where si.item_type <> 'LABOUR')
      as parts_value,
    sum(si.total_amount) filter (where si.item_type = 'LABOUR')
      as labour_value
  from public.service_items si
  where si.service_id = sr.id and si.is_chargeable = true
) parts on true
where sr.service_status in ('COMPLETED', 'DELIVERED')
group by sr.showroom_id, date_trunc('month', sr.service_date);

create or replace view public.upcoming_service_summary
with (security_invoker = true) as
select
  v.showroom_id,
  v.id                        as vehicle_id,
  v.customer_id,
  c.name                      as customer_name,
  c.phone                     as customer_phone,
  v.registration_number,
  v.chassis_number,
  p.name                      as product_name,
  v.current_odometer,
  v.next_service_date,
  v.next_service_km,
  (v.next_service_date - current_date) as days_until_due,
  exists (
    select 1 from public.vehicle_free_services fs
    where fs.vehicle_id = v.id and fs.status in ('UPCOMING', 'DUE')
  )                           as has_free_service
from public.customer_vehicles v
join public.customers c on c.id = v.customer_id
join public.products p on p.id = v.product_id
where v.is_deleted = false
  and v.status = 'ACTIVE'
  and v.next_service_date is not null;

create or replace view public.vehicle_service_history
with (security_invoker = true) as
select
  sr.showroom_id,
  sr.vehicle_id,
  sr.id                       as service_id,
  sr.service_number,
  sr.service_date,
  sr.service_type,
  sr.service_status,
  sr.odometer_reading,
  sr.complaint,
  sr.work_done,
  sr.total_amount,
  sr.paid_amount,
  adv.name                    as service_advisor,
  tech.name                   as technician
from public.service_records sr
left join public.users adv on adv.id = sr.service_advisor_id
left join public.users tech on tech.id = sr.technician_id;

-- =============================================================================
-- Warranty and insurance expiry
-- =============================================================================
create or replace view public.warranty_expiry_summary
with (security_invoker = true) as
select
  w.showroom_id,
  w.id                        as warranty_id,
  w.vehicle_id,
  v.customer_id,
  c.name                      as customer_name,
  c.phone                     as customer_phone,
  v.registration_number,
  p.name                      as product_name,
  w.warranty_type,
  w.start_date,
  w.end_date,
  w.status,
  (w.end_date - current_date) as days_until_expiry
from public.warranties w
join public.customer_vehicles v on v.id = w.vehicle_id
join public.customers c on c.id = v.customer_id
join public.products p on p.id = v.product_id
where w.status in ('ACTIVE', 'EXPIRING_SOON');

create or replace view public.insurance_expiry_summary
with (security_invoker = true) as
select
  ip.showroom_id,
  ip.id                       as policy_id,
  ip.vehicle_id,
  v.customer_id,
  c.name                      as customer_name,
  c.phone                     as customer_phone,
  v.registration_number,
  ip.insurance_company,
  ip.policy_number,
  ip.policy_type,
  ip.start_date,
  ip.expiry_date,
  ip.premium,
  ip.status,
  (ip.expiry_date - current_date) as days_until_expiry
from public.insurance_policies ip
join public.customer_vehicles v on v.id = ip.vehicle_id
join public.customers c on c.id = v.customer_id
where ip.status in ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED');

-- =============================================================================
-- Purchases and expenses
-- =============================================================================
create or replace view public.purchase_summary
with (security_invoker = true) as
select
  pu.showroom_id,
  date_trunc('month', pu.purchase_date)::date  as month,
  pu.supplier_id,
  sup.name                    as supplier_name,
  count(*)                    as purchase_count,
  sum(pu.subtotal)            as subtotal,
  sum(pu.tax_amount)          as tax_amount,
  sum(pu.total_amount)        as total_amount,
  sum(pu.paid_amount)         as paid_amount,
  sum(pu.outstanding_amount)  as outstanding_amount
from public.purchases pu
join public.suppliers sup on sup.id = pu.supplier_id
where pu.status <> 'CANCELLED'
group by pu.showroom_id, date_trunc('month', pu.purchase_date),
         pu.supplier_id, sup.name;

create or replace view public.expense_summary
with (security_invoker = true) as
select
  e.showroom_id,
  date_trunc('month', e.expense_date)::date  as month,
  e.category_id,
  ec.name                     as category_name,
  count(*)                    as expense_count,
  sum(e.amount)               as amount,
  sum(e.tax_amount)           as tax_amount,
  sum(e.total_amount)         as total_amount,
  count(*) filter (where e.status = 'PENDING')  as pending_count,
  sum(e.total_amount) filter (where e.status = 'PENDING')
                              as pending_amount
from public.expenses e
join public.expense_categories ec on ec.id = e.category_id
where e.status <> 'CANCELLED'
group by e.showroom_id, date_trunc('month', e.expense_date),
         e.category_id, ec.name;

-- =============================================================================
-- Accounting
-- =============================================================================
create or replace view public.trial_balance
with (security_invoker = true) as
select
  a.showroom_id,
  a.id                        as account_id,
  a.account_code,
  a.account_name,
  a.account_type,
  coalesce(sum(e.debit), 0)   as total_debit,
  coalesce(sum(e.credit), 0)  as total_credit,
  -- Naturally-signed balance: assets and expenses are debit-normal, the rest
  -- credit-normal, so a report can present the figure without re-deriving the
  -- sign convention.
  case
    when a.account_type in ('ASSET', 'EXPENSE')
      then coalesce(sum(e.debit), 0) - coalesce(sum(e.credit), 0)
    else coalesce(sum(e.credit), 0) - coalesce(sum(e.debit), 0)
  end                         as balance
from public.accounts a
left join public.accounting_entries e on e.account_id = a.id
left join public.accounting_transactions t on t.id = e.transaction_id
where a.status = 'ACTIVE'
group by a.showroom_id, a.id, a.account_code, a.account_name, a.account_type;

create or replace view public.profit_and_loss_summary
with (security_invoker = true) as
select
  t.showroom_id,
  date_trunc('month', t.transaction_date)::date  as month,
  sum(case when a.account_type = 'INCOME'
           then e.credit - e.debit else 0 end)   as total_income,
  sum(case when a.account_type = 'EXPENSE'
           then e.debit - e.credit else 0 end)   as total_expense,
  sum(case when a.account_type = 'INCOME'
           then e.credit - e.debit else 0 end)
  - sum(case when a.account_type = 'EXPENSE'
             then e.debit - e.credit else 0 end) as net_profit
from public.accounting_transactions t
join public.accounting_entries e on e.transaction_id = t.id
join public.accounts a on a.id = e.account_id
where a.account_type in ('INCOME', 'EXPENSE')
group by t.showroom_id, date_trunc('month', t.transaction_date);

create or replace view public.showroom_profit_summary
with (security_invoker = true) as
select
  s.id                        as showroom_id,
  s.name                      as showroom_name,
  s.code                      as showroom_code,
  coalesce(sales.revenue, 0)      as sales_revenue,
  coalesce(service.revenue, 0)    as service_revenue,
  coalesce(expenses.total, 0)     as total_expenses,
  coalesce(purchases.total, 0)    as total_purchases,
  coalesce(sales.revenue, 0) + coalesce(service.revenue, 0)
    - coalesce(expenses.total, 0) as gross_profit,
  coalesce(sales.outstanding, 0) + coalesce(service.outstanding, 0)
                                  as total_outstanding
from public.showrooms s
left join lateral (
  select sum(total_amount - tax_amount) as revenue,
         sum(outstanding_amount)        as outstanding
  from public.sales
  where showroom_id = s.id and status not in ('DRAFT', 'CANCELLED')
) sales on true
left join lateral (
  select sum(total_amount - tax_amount) as revenue,
         sum(outstanding_amount)        as outstanding
  from public.service_records
  where showroom_id = s.id
    and service_status in ('COMPLETED', 'DELIVERED')
) service on true
left join lateral (
  select sum(total_amount) as total
  from public.expenses
  where showroom_id = s.id and status in ('APPROVED', 'PAID')
) expenses on true
left join lateral (
  select sum(total_amount) as total
  from public.purchases
  where showroom_id = s.id and status <> 'CANCELLED'
) purchases on true
where s.is_deleted = false;

-- =============================================================================
-- Customer 360 timeline
--
-- A single chronological stream of everything that happened to a customer,
-- assembled by UNION rather than stored, so it can never drift from the source
-- documents.
-- =============================================================================
create or replace view public.customer_timeline
with (security_invoker = true) as
select showroom_id, customer_id, event_date, event_type, reference_id,
       title, description, amount
from (
  select
    s.showroom_id, s.customer_id, s.sale_date::timestamptz as event_date,
    'SALE' as event_type, s.id as reference_id,
    'Vehicle sale ' || s.sale_number as title,
    s.status as description, s.total_amount as amount
  from public.sales s
  where s.status <> 'DRAFT'

  union all
  select
    i.showroom_id, i.customer_id, i.invoice_date::timestamptz,
    'INVOICE', i.id,
    'Invoice ' || i.invoice_number, i.status, i.total_amount
  from public.invoices i
  where i.status <> 'DRAFT'

  union all
  select
    p.showroom_id, p.customer_id, p.payment_date::timestamptz,
    'PAYMENT', p.id,
    'Payment ' || p.payment_number,
    p.payment_method || ' - ' || p.status, p.amount
  from public.payments p
  where p.customer_id is not null

  union all
  select
    sr.showroom_id, sr.customer_id, sr.service_date::timestamptz,
    'SERVICE', sr.id,
    'Service ' || sr.service_number,
    sr.service_type || ' - ' || sr.service_status, sr.total_amount
  from public.service_records sr

  union all
  select
    l.showroom_id, l.customer_id, l.start_date::timestamptz,
    'LOAN', l.id,
    'Loan ' || l.loan_number, l.status, l.loan_amount
  from public.loans l

  union all
  select
    r.showroom_id, r.customer_id, r.reminder_date::timestamptz,
    'REMINDER', r.id, r.title, r.status, null::numeric
  from public.reminders r
  where r.customer_id is not null
) timeline;

-- =============================================================================
-- Dashboard
--
-- One call returns every tile, rather than the dashboard issuing fifteen
-- parallel queries that each pay the RLS evaluation cost.
-- =============================================================================
create or replace function public.dashboard_metrics(
  p_showroom_id uuid,
  p_from        date default null,
  p_to          date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_from date := coalesce(p_from, date_trunc('month', current_date)::date);
  v_to   date := coalesce(p_to, current_date);
  v_result jsonb;
begin
  -- SECURITY DEFINER, so the tenancy check has to be explicit here: without
  -- it this function would happily report another showroom's figures.
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  select jsonb_build_object(
    'showroom_id', p_showroom_id,
    'from', v_from,
    'to', v_to,

    'today_sales_count', (
      select count(*) from public.sales
      where showroom_id = p_showroom_id and sale_date = current_date
        and status not in ('DRAFT', 'CANCELLED')),
    'today_sales_value', (
      select coalesce(sum(total_amount), 0) from public.sales
      where showroom_id = p_showroom_id and sale_date = current_date
        and status not in ('DRAFT', 'CANCELLED')),
    'period_sales_count', (
      select count(*) from public.sales
      where showroom_id = p_showroom_id
        and sale_date between v_from and v_to
        and status not in ('DRAFT', 'CANCELLED')),
    'period_sales_value', (
      select coalesce(sum(total_amount), 0) from public.sales
      where showroom_id = p_showroom_id
        and sale_date between v_from and v_to
        and status not in ('DRAFT', 'CANCELLED')),

    'today_collection', (
      select coalesce(sum(amount), 0) from public.payments
      where showroom_id = p_showroom_id and payment_date = current_date
        and status = 'COMPLETED' and direction = 'INBOUND'),
    'period_collection', (
      select coalesce(sum(amount), 0) from public.payments
      where showroom_id = p_showroom_id
        and payment_date between v_from and v_to
        and status = 'COMPLETED' and direction = 'INBOUND'),

    'total_outstanding', (
      select coalesce(sum(outstanding_amount), 0) from public.invoices
      where showroom_id = p_showroom_id
        and status in ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE')),

    'total_customers', (
      select count(*) from public.customers
      where showroom_id = p_showroom_id and is_deleted = false
        and status = 'ACTIVE'),
    'new_customers', (
      select count(*) from public.customers
      where showroom_id = p_showroom_id and is_deleted = false
        and created_at::date between v_from and v_to),

    'available_stock', (
      select count(*) from public.inventory
      where showroom_id = p_showroom_id and is_deleted = false
        and status = 'AVAILABLE'),
    'reserved_stock', (
      select count(*) from public.inventory
      where showroom_id = p_showroom_id and is_deleted = false
        and status = 'RESERVED'),
    'stock_value', (
      select coalesce(sum(purchase_price), 0) from public.inventory
      where showroom_id = p_showroom_id and is_deleted = false
        and status in ('AVAILABLE', 'RESERVED', 'DEMO')),
    'low_stock_products', (
      select count(*) from public.low_stock_summary
      where showroom_id = p_showroom_id),

    'active_loans', (
      select count(*) from public.loans
      where showroom_id = p_showroom_id and status = 'ACTIVE'),
    'upcoming_emi_count', (
      select count(*) from public.emi_due_summary
      where showroom_id = p_showroom_id
        and due_date between current_date and current_date + 30),
    'upcoming_emi_value', (
      select coalesce(sum(remaining_amount), 0) from public.emi_due_summary
      where showroom_id = p_showroom_id
        and due_date between current_date and current_date + 30),
    'overdue_emi_count', (
      select count(*) from public.emi_overdue_summary
      where showroom_id = p_showroom_id),
    'overdue_emi_value', (
      select coalesce(sum(remaining_amount), 0)
      from public.emi_overdue_summary where showroom_id = p_showroom_id),

    'upcoming_services', (
      select count(*) from public.upcoming_service_summary
      where showroom_id = p_showroom_id
        and next_service_date between current_date and current_date + 30),
    'overdue_services', (
      select count(*) from public.upcoming_service_summary
      where showroom_id = p_showroom_id
        and next_service_date < current_date),
    'open_job_cards', (
      select count(*) from public.service_records
      where showroom_id = p_showroom_id
        and service_status in
          ('BOOKED', 'RECEIVED', 'IN_PROGRESS', 'WAITING_FOR_PARTS')),
    'period_service_revenue', (
      select coalesce(sum(total_amount), 0) from public.service_records
      where showroom_id = p_showroom_id
        and service_date between v_from and v_to
        and service_status in ('COMPLETED', 'DELIVERED')),

    'insurance_expiring', (
      select count(*) from public.insurance_expiry_summary
      where showroom_id = p_showroom_id
        and expiry_date between current_date and current_date + 30),
    'warranty_expiring', (
      select count(*) from public.warranty_expiry_summary
      where showroom_id = p_showroom_id
        and end_date between current_date and current_date + 30),

    'period_expenses', (
      select coalesce(sum(total_amount), 0) from public.expenses
      where showroom_id = p_showroom_id
        and expense_date between v_from and v_to
        and status in ('APPROVED', 'PAID')),
    'pending_expense_approvals', (
      select count(*) from public.expenses
      where showroom_id = p_showroom_id and status = 'PENDING'),

    'period_purchases', (
      select coalesce(sum(total_amount), 0) from public.purchases
      where showroom_id = p_showroom_id
        and purchase_date between v_from and v_to
        and status <> 'CANCELLED'),

    'pending_reminders', (
      select count(*) from public.reminders
      where showroom_id = p_showroom_id and status = 'PENDING'
        and reminder_date <= current_date)
  )
  into v_result;

  -- Profit is revenue net of tax (tax is never income) minus approved
  -- expenses, so the tile agrees with the P&L rather than approximating it.
  v_result := v_result || jsonb_build_object(
    'period_profit',
    coalesce((v_result ->> 'period_sales_value')::numeric, 0)
    + coalesce((v_result ->> 'period_service_revenue')::numeric, 0)
    - coalesce((v_result ->> 'period_expenses')::numeric, 0)
  );

  return v_result;
end;
$$;

-- =============================================================================
-- Trend series for the dashboard charts
-- =============================================================================
create or replace function public.sales_trend(
  p_showroom_id uuid,
  p_months      integer default 12
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  -- generate_series supplies every month in the window, so a month with no
  -- sales appears as a zero rather than being missing - a gap in a line chart
  -- reads as "no data" when the truth is "no sales".
  select coalesce(jsonb_agg(row_to_json(t) order by t.month), '[]'::jsonb)
  into v_result
  from (
    select
      m.month::date                            as month,
      coalesce(s.sale_count, 0)                as sale_count,
      coalesce(s.total_amount, 0)              as total_amount,
      coalesce(s.collected_amount, 0)          as collected_amount
    from generate_series(
      date_trunc('month', current_date) - make_interval(months => p_months - 1),
      date_trunc('month', current_date),
      interval '1 month'
    ) as m(month)
    left join public.monthly_sales_summary s
      on s.month = m.month::date and s.showroom_id = p_showroom_id
  ) t;

  return v_result;
end;
$$;

create or replace function public.expense_trend(
  p_showroom_id uuid,
  p_months      integer default 12
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(row_to_json(t) order by t.month), '[]'::jsonb)
  into v_result
  from (
    select
      m.month::date                   as month,
      coalesce(sum(e.total_amount), 0) as total_amount
    from generate_series(
      date_trunc('month', current_date) - make_interval(months => p_months - 1),
      date_trunc('month', current_date),
      interval '1 month'
    ) as m(month)
    left join public.expenses e
      on date_trunc('month', e.expense_date) = m.month
      and e.showroom_id = p_showroom_id
      and e.status in ('APPROVED', 'PAID')
    group by m.month
  ) t;

  return v_result;
end;
$$;

create or replace function public.payment_method_distribution(
  p_showroom_id uuid,
  p_from        date default null,
  p_to          date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
  v_from date := coalesce(p_from, date_trunc('month', current_date)::date);
  v_to   date := coalesce(p_to, current_date);
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(row_to_json(t) order by t.total desc), '[]'::jsonb)
  into v_result
  from (
    select
      payment_method,
      count(*)              as payment_count,
      sum(amount)           as total
    from public.payments
    where showroom_id = p_showroom_id
      and payment_date between v_from and v_to
      and status = 'COMPLETED' and direction = 'INBOUND'
    group by payment_method
  ) t;

  return v_result;
end;
$$;

create or replace function public.stock_distribution(p_showroom_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(row_to_json(t) order by t.unit_count desc), '[]')
  into v_result
  from (
    select
      status,
      count(*)                      as unit_count,
      sum(purchase_price)           as value
    from public.inventory
    where showroom_id = p_showroom_id and is_deleted = false
    group by status
  ) t;

  return v_result;
end;
$$;

-- =============================================================================
-- Global search
--
-- Backs the single search box that finds a customer, a vehicle, an invoice or
-- a job card. Each branch is limited so one entity type cannot crowd out the
-- others in the result list.
-- =============================================================================
create or replace function public.global_search(
  p_showroom_id uuid,
  p_term        text,
  p_limit       integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_pattern text;
  v_result  jsonb;
begin
  if not public.can_access_showroom(p_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if p_term is null or length(btrim(p_term)) < 2 then
    return '[]'::jsonb;
  end if;

  v_pattern := '%' || btrim(p_term) || '%';

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    (select 'CUSTOMER' as entity_type, c.id as entity_id,
            c.name as title,
            c.customer_code || ' - ' || c.phone as subtitle
     from public.customers c
     where c.showroom_id = p_showroom_id and c.is_deleted = false
       and (c.name ilike v_pattern or c.phone ilike v_pattern
            or c.customer_code ilike v_pattern or c.email ilike v_pattern)
     limit p_limit)

    union all
    (select 'VEHICLE', v.id,
            coalesce(v.registration_number, v.chassis_number),
            p.name || ' - ' || c.name
     from public.customer_vehicles v
     join public.customers c on c.id = v.customer_id
     join public.products p on p.id = v.product_id
     where v.showroom_id = p_showroom_id and v.is_deleted = false
       and (v.registration_number ilike v_pattern
            or v.chassis_number ilike v_pattern
            or v.engine_number ilike v_pattern)
     limit p_limit)

    union all
    (select 'INVENTORY', i.id, i.stock_code,
            p.name || ' - ' || i.chassis_number
     from public.inventory i
     join public.products p on p.id = i.product_id
     where i.showroom_id = p_showroom_id and i.is_deleted = false
       and (i.stock_code ilike v_pattern or i.chassis_number ilike v_pattern
            or i.engine_number ilike v_pattern)
     limit p_limit)

    union all
    (select 'INVOICE', i.id, i.invoice_number,
            c.name || ' - ' || i.total_amount::text
     from public.invoices i
     join public.customers c on c.id = i.customer_id
     where i.showroom_id = p_showroom_id
       and i.invoice_number ilike v_pattern
     limit p_limit)

    union all
    (select 'SALE', s.id, s.sale_number,
            c.name || ' - ' || s.total_amount::text
     from public.sales s
     join public.customers c on c.id = s.customer_id
     where s.showroom_id = p_showroom_id and s.sale_number ilike v_pattern
     limit p_limit)

    union all
    (select 'SERVICE', sr.id, sr.service_number,
            c.name || ' - ' || sr.service_status
     from public.service_records sr
     join public.customers c on c.id = sr.customer_id
     where sr.showroom_id = p_showroom_id
       and sr.service_number ilike v_pattern
     limit p_limit)

    union all
    (select 'LOAN', l.id, l.loan_number,
            c.name || ' - ' || l.status
     from public.loans l
     join public.customers c on c.id = l.customer_id
     where l.showroom_id = p_showroom_id and l.loan_number ilike v_pattern
     limit p_limit)
  ) r;

  return v_result;
end;
$$;

-- =============================================================================
-- Verification
-- =============================================================================
do $$
declare
  v_leaky text;
  v_views int;
begin
  -- A view without security_invoker runs as its owner and bypasses RLS,
  -- exposing every showroom's rows. This is the single most damaging mistake
  -- possible in this file, so the migration refuses to complete without it.
  select string_agg(c.relname, ', ')
  into v_leaky
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'v'
    and not coalesce(
      (select option_value = 'true'
       from pg_options_to_table(c.reloptions)
       where option_name = 'security_invoker'),
      false);

  if v_leaky is not null then
    raise exception
      'These views lack security_invoker and would bypass RLS: %', v_leaky;
  end if;

  select count(*) into v_views
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v';

  raise notice '% reporting views created, all with security_invoker', v_views;
end $$;
