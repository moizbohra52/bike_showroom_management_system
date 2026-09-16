-- =============================================================================
-- 004_finance_service_schema.sql
--
-- Finance and EMI, purchasing, expenses, the workshop, warranty, insurance,
-- engagement (reminders and notifications) and double-entry accounting.
-- =============================================================================

-- =============================================================================
-- finance_companies / loans / emi_schedules
-- =============================================================================
create table if not exists public.finance_companies (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  code            text not null,
  contact_person  text,
  phone           text,
  email           text,
  address         text,
  status          text not null default 'ACTIVE',

  is_deleted      boolean not null default false,
  deleted_at      timestamptz,
  deleted_by      uuid references public.users(id) on delete set null,
  revision        integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,

  constraint finance_companies_code_key unique (code),
  constraint finance_companies_status_check
    check (status in ('ACTIVE', 'INACTIVE'))
);

create table if not exists public.loans (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  customer_id         uuid not null
                      references public.customers(id) on delete restrict,
  vehicle_id          uuid references public.customer_vehicles(id)
                      on delete restrict,
  sale_id             uuid references public.sales(id) on delete restrict,
  finance_company_id  uuid not null
                      references public.finance_companies(id)
                      on delete restrict,
  loan_number         text not null,
  loan_amount         money_amount not null,
  down_payment        money_amount not null default 0,
  interest_rate       percentage not null,
  interest_type       text not null default 'REDUCING',
  tenure_months       integer not null,
  emi_amount          money_amount not null,
  processing_fee      money_amount not null default 0,
  start_date          date not null default current_date,
  end_date            date,
  status              text not null default 'PENDING',
  notes               text,

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint loans_number_key unique (loan_number),
  constraint loans_interest_type_check
    check (interest_type in ('REDUCING', 'FLAT')),
  constraint loans_status_check
    check (status in
      ('PENDING', 'ACTIVE', 'CLOSED', 'FORECLOSED', 'DEFAULTED',
       'CANCELLED')),
  constraint loans_amount_check check (loan_amount > 0),
  constraint loans_tenure_check check (tenure_months between 3 and 84),
  constraint loans_interest_rate_check
    check (interest_rate > 0 and interest_rate <= 60),
  constraint loans_end_date_check
    check (end_date is null or end_date > start_date)
);

create table if not exists public.emi_schedules (
  id                uuid primary key default gen_random_uuid(),
  loan_id           uuid not null references public.loans(id)
                    on delete cascade,
  emi_number        integer not null,
  due_date          date not null,
  principal_amount  money_amount not null default 0,
  interest_amount   money_amount not null default 0,
  emi_amount        money_amount not null default 0,
  paid_amount       money_amount not null default 0,
  remaining_amount  money_amount not null default 0,
  penalty_amount    money_amount not null default 0,
  paid_date         date,
  status            text not null default 'UPCOMING',
  notes             text,

  revision          integer not null default 1,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint emi_schedules_loan_number_key unique (loan_id, emi_number),
  constraint emi_schedules_status_check
    check (status in
      ('UPCOMING', 'DUE', 'PARTIAL', 'PAID', 'OVERDUE', 'CANCELLED')),
  constraint emi_schedules_number_check check (emi_number > 0),
  -- The instalment must decompose exactly into principal and interest.
  constraint emi_schedules_components_check
    check (abs(emi_amount - (principal_amount + interest_amount)) < 0.01),
  constraint emi_schedules_remaining_check
    check (abs(remaining_amount
               - (emi_amount + penalty_amount - paid_amount)) < 0.01),
  constraint emi_schedules_paid_check
    check (paid_amount <= emi_amount + penalty_amount + 0.01)
);

comment on table public.emi_schedules is
  'Generated in full by generate_emi_schedule() when the loan is created, so '
  'the customer has a complete repayment plan from day one.';

-- Close the payments -> emi_schedules reference now that the table exists.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_emi_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_emi_id_fkey
      foreign key (emi_id) references public.emi_schedules(id)
      on delete restrict;
  end if;
end $$;

-- =============================================================================
-- suppliers / purchases
-- =============================================================================
create table if not exists public.suppliers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text,
  phone       text,
  email       text,
  address     text,
  city        text,
  state       text,
  pincode     text,
  gst_number  text,
  pan_number  text,
  status      text not null default 'ACTIVE',

  is_deleted  boolean not null default false,
  deleted_at  timestamptz,
  deleted_by  uuid references public.users(id) on delete set null,
  revision    integer not null default 1,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.users(id) on delete set null,
  updated_by  uuid references public.users(id) on delete set null,

  constraint suppliers_status_check check (status in ('ACTIVE', 'INACTIVE')),
  constraint suppliers_gst_check
    check (gst_number is null or
           gst_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
);

create unique index if not exists suppliers_code_key
  on public.suppliers (code) where code is not null and is_deleted = false;

create table if not exists public.purchases (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  supplier_id         uuid not null
                      references public.suppliers(id) on delete restrict,
  purchase_number     text not null,
  supplier_invoice_no text,
  purchase_date       date not null default current_date,
  received_date       date,
  subtotal            money_amount not null default 0,
  discount            money_amount not null default 0,
  tax_amount          money_amount not null default 0,
  other_charges       money_amount not null default 0,
  total_amount        money_amount not null default 0,
  paid_amount         money_amount not null default 0,
  outstanding_amount  money_amount not null default 0,
  status              text not null default 'DRAFT',
  notes               text,

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint purchases_status_check
    check (status in
      ('DRAFT', 'ORDERED', 'RECEIVED', 'PARTIALLY_RECEIVED', 'CANCELLED')),
  constraint purchases_total_check
    check (abs(total_amount
               - (subtotal - discount + tax_amount + other_charges)) < 0.01),
  constraint purchases_outstanding_check
    check (abs(outstanding_amount - (total_amount - paid_amount)) < 0.01)
);

create unique index if not exists purchases_showroom_number_key
  on public.purchases (showroom_id, purchase_number);

create table if not exists public.purchase_items (
  id            uuid primary key default gen_random_uuid(),
  purchase_id   uuid not null
                references public.purchases(id) on delete cascade,
  product_id    uuid not null references public.products(id)
                on delete restrict,
  -- Populated when the line is received and a stock row is generated.
  inventory_id  uuid references public.inventory(id) on delete set null,
  description   text,
  quantity      numeric(10, 2) not null default 1,
  unit_cost     money_amount not null default 0,
  discount      money_amount not null default 0,
  tax_rate      percentage not null default 0,
  tax_amount    money_amount not null default 0,
  total_amount  money_amount not null default 0,
  created_at    timestamptz not null default now(),

  constraint purchase_items_quantity_check check (quantity > 0)
);

-- Close the inventory -> purchases reference.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'inventory_purchase_id_fkey'
  ) then
    alter table public.inventory
      add constraint inventory_purchase_id_fkey
      foreign key (purchase_id) references public.purchases(id)
      on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'payments_purchase_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_purchase_id_fkey
      foreign key (purchase_id) references public.purchases(id)
      on delete restrict;
  end if;
end $$;

-- =============================================================================
-- expense_categories / expenses
-- =============================================================================
create table if not exists public.expense_categories (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text,
  -- Ledger account this category posts to, wired up in 013_accounting.sql.
  account_code text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),

  constraint expense_categories_name_key unique (name)
);

create table if not exists public.expenses (
  id              uuid primary key default gen_random_uuid(),
  showroom_id     uuid not null
                  references public.showrooms(id) on delete restrict,
  category_id     uuid not null
                  references public.expense_categories(id) on delete restrict,
  expense_number  text not null,
  expense_date    date not null default current_date,
  amount          money_amount not null,
  tax_amount      money_amount not null default 0,
  total_amount    money_amount not null default 0,
  payment_method  text not null default 'CASH',
  description     text,
  attachment_url  text,
  vendor_name     text,
  reference_number text,
  status          text not null default 'DRAFT',
  approved_by     uuid references public.users(id) on delete set null,
  approved_at     timestamptz,
  rejection_reason text,

  revision        integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,

  constraint expenses_status_check
    check (status in
      ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED')),
  constraint expenses_method_check
    check (payment_method in
      ('CASH', 'UPI', 'CARD', 'BANK_TRANSFER', 'CHEQUE', 'ONLINE')),
  constraint expenses_amount_check check (amount > 0),
  constraint expenses_total_check
    check (abs(total_amount - (amount + tax_amount)) < 0.01),
  -- An approved expense must record who approved it and when; otherwise the
  -- approval is unauditable.
  constraint expenses_approval_check
    check (status not in ('APPROVED', 'PAID')
           or (approved_by is not null and approved_at is not null)),
  constraint expenses_rejection_check
    check (status <> 'REJECTED' or rejection_reason is not null)
);

create unique index if not exists expenses_showroom_number_key
  on public.expenses (showroom_id, expense_number);

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_expense_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_expense_id_fkey
      foreign key (expense_id) references public.expenses(id)
      on delete restrict;
  end if;
end $$;

-- =============================================================================
-- service_records / service_items
-- =============================================================================
create table if not exists public.service_records (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  customer_id         uuid not null
                      references public.customers(id) on delete restrict,
  vehicle_id          uuid not null
                      references public.customer_vehicles(id)
                      on delete restrict,
  service_number      text not null,
  booking_date        date,
  service_date        date not null default current_date,
  delivery_date       date,
  odometer_reading    integer not null default 0,
  service_type        text not null default 'PAID',
  service_status      text not null default 'BOOKED',
  service_advisor_id  uuid references public.users(id) on delete set null,
  technician_id       uuid references public.users(id) on delete set null,
  complaint           text,
  inspection_notes    text,
  work_done           text,
  next_service_date   date,
  next_service_km     integer,
  subtotal            money_amount not null default 0,
  discount            money_amount not null default 0,
  tax_amount          money_amount not null default 0,
  total_amount        money_amount not null default 0,
  paid_amount         money_amount not null default 0,
  outstanding_amount  money_amount not null default 0,
  cancelled_at        timestamptz,
  cancelled_by        uuid references public.users(id) on delete set null,

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint service_records_type_check
    check (service_type in ('FREE', 'PAID', 'WARRANTY')),
  constraint service_records_status_check
    check (service_status in
      ('BOOKED', 'RECEIVED', 'IN_PROGRESS', 'WAITING_FOR_PARTS',
       'COMPLETED', 'DELIVERED', 'CANCELLED')),
  constraint service_records_odometer_check
    check (odometer_reading >= 0 and odometer_reading <= 999999),
  constraint service_records_total_check
    check (abs(total_amount - (subtotal - discount + tax_amount)) < 0.01),
  constraint service_records_outstanding_check
    check (abs(outstanding_amount - (total_amount - paid_amount)) < 0.01)
);

create unique index if not exists service_records_showroom_number_key
  on public.service_records (showroom_id, service_number);

create table if not exists public.service_items (
  id            uuid primary key default gen_random_uuid(),
  service_id    uuid not null
                references public.service_records(id) on delete cascade,
  item_type     text not null default 'PART',
  product_id    uuid references public.products(id) on delete restrict,
  description   text not null,
  quantity      numeric(10, 2) not null default 1,
  unit_price    money_amount not null default 0,
  discount      money_amount not null default 0,
  tax_rate      percentage not null default 0,
  tax_amount    money_amount not null default 0,
  total_amount  money_amount not null default 0,
  -- A line covered by a free service or a warranty claim is not billed to the
  -- customer but must still be recorded for cost accounting.
  is_chargeable boolean not null default true,
  created_at    timestamptz not null default now(),
  created_by    uuid references public.users(id) on delete set null,

  constraint service_items_type_check
    check (item_type in
      ('PART', 'LABOUR', 'OIL', 'CONSUMABLE', 'ACCESSORY', 'OTHER')),
  constraint service_items_quantity_check check (quantity > 0)
);

-- Close the deferred references to service_records.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'invoices_service_id_fkey'
  ) then
    alter table public.invoices
      add constraint invoices_service_id_fkey
      foreign key (service_id) references public.service_records(id)
      on delete restrict;
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'payments_service_id_fkey'
  ) then
    alter table public.payments
      add constraint payments_service_id_fkey
      foreign key (service_id) references public.service_records(id)
      on delete restrict;
  end if;
end $$;

-- =============================================================================
-- free_service_plans / vehicle_free_services
-- =============================================================================
create table if not exists public.free_service_plans (
  id              uuid primary key default gen_random_uuid(),
  product_id      uuid references public.products(id) on delete cascade,
  -- Null product_id means the plan is the default for every product, so a
  -- showroom can define one schedule instead of one per model.
  service_number  integer not null,
  name            text,
  validity_days   integer not null,
  validity_km     integer not null,
  free_labour     boolean not null default true,
  covered_items   jsonb not null default '[]'::jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint free_service_plans_number_check check (service_number > 0),
  constraint free_service_plans_validity_check
    check (validity_days > 0 and validity_km > 0)
);

create unique index if not exists free_service_plans_product_number_key
  on public.free_service_plans (product_id, service_number)
  where product_id is not null;

create unique index if not exists free_service_plans_default_number_key
  on public.free_service_plans (service_number)
  where product_id is null;

create table if not exists public.vehicle_free_services (
  id                    uuid primary key default gen_random_uuid(),
  showroom_id           uuid not null
                        references public.showrooms(id) on delete restrict,
  vehicle_id            uuid not null
                        references public.customer_vehicles(id)
                        on delete cascade,
  free_service_plan_id  uuid references public.free_service_plans(id)
                        on delete set null,
  service_number        integer not null,
  service_id            uuid references public.service_records(id)
                        on delete set null,
  due_date              date not null,
  due_km                integer not null,
  used_date             date,
  status                text not null default 'UPCOMING',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),

  constraint vehicle_free_services_vehicle_number_key
    unique (vehicle_id, service_number),
  constraint vehicle_free_services_status_check
    check (status in ('UPCOMING', 'DUE', 'USED', 'EXPIRED', 'CANCELLED')),
  -- A consumed entitlement must name the job that consumed it.
  constraint vehicle_free_services_used_check
    check (status <> 'USED' or (service_id is not null
                                and used_date is not null))
);

-- =============================================================================
-- warranties / warranty_claims
-- =============================================================================
create table if not exists public.warranties (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  vehicle_id          uuid not null
                      references public.customer_vehicles(id)
                      on delete cascade,
  warranty_type       text not null default 'STANDARD',
  start_date          date not null,
  end_date            date not null,
  terms               text,
  covered_components  jsonb not null default '[]'::jsonb,
  status              text not null default 'ACTIVE',

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint warranties_type_check
    check (warranty_type in
      ('STANDARD', 'EXTENDED', 'ENGINE', 'BATTERY', 'PAINT')),
  constraint warranties_status_check
    check (status in
      ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'VOIDED', 'CANCELLED')),
  constraint warranties_date_range_check check (end_date > start_date),
  constraint warranties_vehicle_type_key unique (vehicle_id, warranty_type)
);

create table if not exists public.warranty_claims (
  id             uuid primary key default gen_random_uuid(),
  showroom_id    uuid not null
                 references public.showrooms(id) on delete restrict,
  warranty_id    uuid not null
                 references public.warranties(id) on delete restrict,
  service_id     uuid references public.service_records(id)
                 on delete set null,
  claim_number   text not null,
  claim_date     date not null default current_date,
  description    text not null,
  claim_amount   money_amount not null default 0,
  approved_amount money_amount not null default 0,
  status         text not null default 'DRAFT',
  resolution     text,

  revision       integer not null default 1,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid references public.users(id) on delete set null,
  updated_by     uuid references public.users(id) on delete set null,

  constraint warranty_claims_number_key unique (claim_number),
  constraint warranty_claims_status_check
    check (status in
      ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED',
       'SETTLED', 'CANCELLED')),
  constraint warranty_claims_approved_check
    check (approved_amount <= claim_amount + 0.01),
  constraint warranty_claims_resolution_check
    check (status not in ('REJECTED', 'SETTLED') or resolution is not null)
);

-- =============================================================================
-- insurance_policies
-- =============================================================================
create table if not exists public.insurance_policies (
  id                 uuid primary key default gen_random_uuid(),
  showroom_id        uuid not null
                     references public.showrooms(id) on delete restrict,
  vehicle_id         uuid not null
                     references public.customer_vehicles(id)
                     on delete cascade,
  insurance_company  text not null,
  policy_number      text not null,
  policy_type        text not null default 'COMPREHENSIVE',
  start_date         date not null,
  expiry_date        date not null,
  premium            money_amount not null default 0,
  sum_insured        money_amount not null default 0,
  document_url       text,
  status             text not null default 'ACTIVE',

  revision           integer not null default 1,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid references public.users(id) on delete set null,
  updated_by         uuid references public.users(id) on delete set null,

  constraint insurance_policies_number_key unique (policy_number),
  constraint insurance_policies_type_check
    check (policy_type in
      ('COMPREHENSIVE', 'THIRD_PARTY', 'OWN_DAMAGE', 'ZERO_DEPRECIATION')),
  constraint insurance_policies_status_check
    check (status in
      ('ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'CANCELLED')),
  constraint insurance_policies_date_range_check
    check (expiry_date > start_date)
);

-- =============================================================================
-- reminders / notifications
-- =============================================================================
create table if not exists public.reminders (
  id              uuid primary key default gen_random_uuid(),
  showroom_id     uuid not null
                  references public.showrooms(id) on delete cascade,
  customer_id     uuid references public.customers(id) on delete cascade,
  vehicle_id      uuid references public.customer_vehicles(id)
                  on delete cascade,
  reminder_type   text not null,
  title           text not null,
  message         text,
  reminder_date   date not null,
  reminder_time   time,
  priority        text not null default 'MEDIUM',
  status          text not null default 'PENDING',
  reference_id    uuid,
  reference_type  text,
  sent_at         timestamptz,
  completed_at    timestamptz,

  revision        integer not null default 1,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid references public.users(id) on delete set null,
  updated_by      uuid references public.users(id) on delete set null,

  constraint reminders_type_check
    check (reminder_type in
      ('EMI', 'SERVICE', 'INSURANCE', 'WARRANTY', 'PAYMENT', 'DOCUMENT',
       'CUSTOM')),
  constraint reminders_priority_check
    check (priority in ('LOW', 'MEDIUM', 'HIGH', 'URGENT')),
  constraint reminders_status_check
    check (status in ('PENDING', 'SENT', 'COMPLETED', 'CANCELLED'))
);

-- Prevents the scheduled generators from creating a duplicate reminder each
-- time they run: one reminder per reference, per type, per date.
create unique index if not exists reminders_dedupe_key
  on public.reminders (reference_type, reference_id, reminder_type,
                       reminder_date)
  where reference_id is not null and status in ('PENDING', 'SENT');

create table if not exists public.notifications (
  id                 uuid primary key default gen_random_uuid(),
  showroom_id        uuid references public.showrooms(id) on delete cascade,
  user_id            uuid references public.users(id) on delete cascade,
  customer_id        uuid references public.customers(id) on delete cascade,
  title              text not null,
  message            text not null,
  notification_type  text not null default 'SYSTEM',
  reference_id       uuid,
  reference_type     text,
  is_read            boolean not null default false,
  read_at            timestamptz,
  sent_at            timestamptz,
  created_at         timestamptz not null default now(),

  constraint notifications_type_check
    check (notification_type in
      ('EMI_REMINDER', 'SERVICE_REMINDER', 'INSURANCE_EXPIRY',
       'WARRANTY_EXPIRY', 'PAYMENT_REMINDER', 'PAYMENT_RECEIVED',
       'APPROVAL_REQUEST', 'APPROVAL_DECISION', 'STOCK_ALERT',
       'STOCK_TRANSFER', 'SALE_CREATED', 'SERVICE_STATUS', 'SYSTEM')),
  -- A notification with no recipient at all is undeliverable.
  constraint notifications_recipient_check
    check (user_id is not null or customer_id is not null)
);

-- =============================================================================
-- accounts / accounting_transactions / accounting_entries
-- =============================================================================
create table if not exists public.accounts (
  id                 uuid primary key default gen_random_uuid(),
  showroom_id        uuid not null
                     references public.showrooms(id) on delete cascade,
  account_code       text not null,
  account_name       text not null,
  account_type       text not null,
  parent_account_id  uuid references public.accounts(id) on delete restrict,
  is_system_account  boolean not null default false,
  status             text not null default 'ACTIVE',

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid references public.users(id) on delete set null,
  updated_by         uuid references public.users(id) on delete set null,

  constraint accounts_showroom_code_key unique (showroom_id, account_code),
  constraint accounts_type_check
    check (account_type in
      ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE')),
  constraint accounts_status_check check (status in ('ACTIVE', 'INACTIVE')),
  constraint accounts_not_own_parent_check
    check (parent_account_id is null or parent_account_id <> id)
);

create table if not exists public.accounting_transactions (
  id                uuid primary key default gen_random_uuid(),
  showroom_id       uuid not null
                    references public.showrooms(id) on delete restrict,
  transaction_date  date not null default current_date,
  reference_type    text not null default 'MANUAL',
  reference_id      uuid,
  description       text not null,
  -- Reversal bookkeeping: a posted transaction is never deleted, a reversing
  -- transaction is written and the two are linked.
  reverses_transaction_id uuid
                    references public.accounting_transactions(id)
                    on delete restrict,
  is_reversed       boolean not null default false,

  created_at        timestamptz not null default now(),
  created_by        uuid references public.users(id) on delete set null,

  constraint accounting_transactions_reference_type_check
    check (reference_type in
      ('SALE', 'INVOICE', 'PAYMENT', 'PURCHASE', 'EXPENSE', 'SERVICE',
       'EMI', 'LOAN', 'STOCK_ADJUSTMENT', 'REFUND', 'OPENING_BALANCE',
       'MANUAL'))
);

create table if not exists public.accounting_entries (
  id              uuid primary key default gen_random_uuid(),
  transaction_id  uuid not null
                  references public.accounting_transactions(id)
                  on delete cascade,
  account_id      uuid not null references public.accounts(id)
                  on delete restrict,
  debit           money_amount not null default 0,
  credit          money_amount not null default 0,
  description     text,
  created_at      timestamptz not null default now(),

  -- A line is either a debit or a credit, never both and never neither.
  -- Enforcing this per line is what makes the transaction-level balance
  -- assertion in 013_accounting.sql meaningful.
  constraint accounting_entries_single_side_check
    check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

comment on table public.accounting_entries is
  'Double-entry lines. Total debits must equal total credits per transaction; '
  'asserted by the deferred constraint trigger in 013_accounting.sql.';
