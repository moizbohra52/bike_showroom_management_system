-- =============================================================================
-- 003_business_schema.sql
--
-- Catalogue, inventory, customers, vehicles, sales and billing.
--
-- Enum-valued columns use CHECK constraints rather than native PostgreSQL
-- enum types. Two reasons: adding a value to a native enum cannot run inside
-- a transaction on older servers, which breaks migration atomicity; and the
-- allowed set is mirrored in Dart, where a CHECK list is trivially diffable
-- against the enum declaration.
-- =============================================================================

-- =============================================================================
-- brands / products
-- =============================================================================
create table if not exists public.brands (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  logo_url    text,
  status      text not null default 'ACTIVE',
  is_deleted  boolean not null default false,
  deleted_at  timestamptz,
  deleted_by  uuid references public.users(id) on delete set null,
  revision    integer not null default 1,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.users(id) on delete set null,
  updated_by  uuid references public.users(id) on delete set null,

  constraint brands_name_key unique (name),
  constraint brands_status_check check (status in ('ACTIVE', 'INACTIVE'))
);

-- Products are the catalogue, shared across showrooms. Stock is per showroom
-- and lives in `inventory`; keeping the catalogue global means a model added
-- once is sellable everywhere and price comparisons stay meaningful.
create table if not exists public.products (
  id               uuid primary key default gen_random_uuid(),
  brand_id         uuid references public.brands(id) on delete restrict,
  name             text not null,
  model            text,
  variant          text,
  category         text not null default 'MOTORCYCLE',
  engine_cc        integer,
  fuel_type        text not null default 'PETROL',
  transmission     text not null default 'MANUAL',
  mileage          numeric(6, 2),
  description      text,
  base_price       money_amount not null default 0,
  selling_price    money_amount not null default 0,
  tax_rate         percentage not null default 18,
  warranty_months  integer not null default 24,
  hsn_code         text,
  status           text not null default 'ACTIVE',

  is_deleted       boolean not null default false,
  deleted_at       timestamptz,
  deleted_by       uuid references public.users(id) on delete set null,
  revision         integer not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,

  constraint products_category_check
    check (category in
      ('MOTORCYCLE', 'SCOOTER', 'MOPED', 'ELECTRIC_TWO_WHEELER',
       'ACCESSORY', 'SPARE_PART', 'LUBRICANT')),
  constraint products_fuel_type_check
    check (fuel_type in ('PETROL', 'ELECTRIC', 'HYBRID', 'CNG')),
  constraint products_transmission_check
    check (transmission in ('MANUAL', 'AUTOMATIC', 'CVT', 'SEMI_AUTOMATIC')),
  constraint products_status_check check (status in ('ACTIVE', 'INACTIVE')),
  constraint products_engine_cc_check
    check (engine_cc is null or engine_cc between 0 and 5000),
  constraint products_warranty_months_check
    check (warranty_months >= 0 and warranty_months <= 240),
  -- Selling below cost is a real scenario (clearance), so this is not
  -- constrained; only negatives are rejected, by the money_amount domain.
  constraint products_name_not_blank check (length(btrim(name)) > 0)
);

create table if not exists public.product_colors (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products(id) on delete cascade,
  color_name  text not null,
  hex_code    text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),

  constraint product_colors_product_name_key unique (product_id, color_name),
  constraint product_colors_hex_check check (hex_code ~* '^#?[0-9A-F]{6}$')
);

create table if not exists public.product_images (
  id                 uuid primary key default gen_random_uuid(),
  product_id         uuid not null
                     references public.products(id) on delete cascade,
  color_id           uuid references public.product_colors(id)
                     on delete set null,
  image_url          text not null,
  thumbnail_url      text,
  storage_path       text,
  is_primary         boolean not null default false,
  sort_order         integer not null default 0,
  watermark_enabled  boolean not null default false,
  created_at         timestamptz not null default now(),
  created_by         uuid references public.users(id) on delete set null
);

-- At most one primary image per product. A partial unique index expresses this
-- directly; a CHECK constraint cannot, because it cannot see other rows.
create unique index if not exists product_images_one_primary_per_product
  on public.product_images (product_id)
  where is_primary = true;

-- =============================================================================
-- inventory - one row per physical vehicle
-- =============================================================================
create table if not exists public.inventory (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  product_id          uuid not null
                      references public.products(id) on delete restrict,
  color_id            uuid references public.product_colors(id)
                      on delete set null,
  stock_code          text not null,
  chassis_number      text not null,
  engine_number       text not null,
  manufacturing_date  date,
  model_year          integer,
  purchase_date       date,
  purchase_price      money_amount not null default 0,
  purchase_id         uuid,
  status              text not null default 'AVAILABLE',
  location            text,
  notes               text,

  is_deleted          boolean not null default false,
  deleted_at          timestamptz,
  deleted_by          uuid references public.users(id) on delete set null,
  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  -- Chassis and engine numbers identify a vehicle nationally, so they are
  -- unique across the whole system, not per showroom. A duplicate almost
  -- always means the same bike was entered twice.
  constraint inventory_chassis_number_key unique (chassis_number),
  constraint inventory_engine_number_key unique (engine_number),
  constraint inventory_stock_code_key unique (stock_code),
  constraint inventory_status_check
    check (status in
      ('AVAILABLE', 'RESERVED', 'SOLD', 'DEMO', 'DAMAGED',
       'IN_TRANSIT', 'RETURNED')),
  -- Manufacturers omit I, O and Q to avoid confusion with 1 and 0, so their
  -- presence signals a transcription error. Mirrors AppValidators.
  constraint inventory_chassis_format_check
    check (chassis_number ~ '^[A-HJ-NPR-Z0-9]{11,25}$'),
  constraint inventory_engine_format_check
    check (engine_number ~ '^[A-Z0-9]{5,25}$'),
  constraint inventory_model_year_check
    check (model_year is null or model_year between 1980 and 2100)
);

comment on table public.inventory is
  'One row per physical vehicle. Serialised stock only; accessories and parts '
  'are tracked by quantity on the product.';

-- =============================================================================
-- stock_transfers / stock_movements
-- =============================================================================
create table if not exists public.stock_transfers (
  id                uuid primary key default gen_random_uuid(),
  transfer_number   text not null,
  from_showroom_id  uuid not null
                    references public.showrooms(id) on delete restrict,
  to_showroom_id    uuid not null
                    references public.showrooms(id) on delete restrict,
  inventory_id      uuid not null
                    references public.inventory(id) on delete restrict,
  transfer_date     date not null default current_date,
  received_date     date,
  status            text not null default 'PENDING',
  notes             text,

  revision          integer not null default 1,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,
  received_by       uuid references public.users(id) on delete set null,

  constraint stock_transfers_number_key unique (transfer_number),
  constraint stock_transfers_status_check
    check (status in ('PENDING', 'IN_TRANSIT', 'RECEIVED', 'CANCELLED')),
  -- Transferring a vehicle to the showroom it is already in is a data-entry
  -- error that would silently corrupt the movement history.
  constraint stock_transfers_different_showrooms_check
    check (from_showroom_id <> to_showroom_id),
  constraint stock_transfers_received_date_check
    check (received_date is null or received_date >= transfer_date)
);

-- Immutable ledger of every stock state change. Never updated or deleted:
-- reconstructing why a vehicle is where it is depends on the history being
-- complete.
create table if not exists public.stock_movements (
  id             uuid primary key default gen_random_uuid(),
  showroom_id    uuid not null
                 references public.showrooms(id) on delete restrict,
  inventory_id   uuid not null
                 references public.inventory(id) on delete restrict,
  movement_type  text not null,
  from_status    text,
  to_status      text,
  reference_type text,
  reference_id   uuid,
  quantity       integer not null default 1,
  notes          text,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.users(id) on delete set null,

  constraint stock_movements_type_check
    check (movement_type in
      ('STOCK_IN', 'STOCK_OUT', 'TRANSFER_OUT', 'TRANSFER_IN', 'ADJUSTMENT',
       'RESERVATION', 'RELEASE', 'SALE_ALLOCATION', 'SALE_REVERSAL',
       'DAMAGE', 'RETURN_TO_SUPPLIER'))
);

-- =============================================================================
-- customers
-- =============================================================================
create table if not exists public.customers (
  id               uuid primary key default gen_random_uuid(),
  showroom_id      uuid not null
                   references public.showrooms(id) on delete restrict,
  customer_code    text not null,
  name             text not null,
  phone            text not null,
  alternate_phone  text,
  email            text,
  address          text,
  city             text,
  state            text,
  pincode          text,
  date_of_birth    date,
  gst_number       text,
  pan_number       text,
  customer_type    text not null default 'INDIVIDUAL',
  notes            text,
  status           text not null default 'ACTIVE',

  is_deleted       boolean not null default false,
  deleted_at       timestamptz,
  deleted_by       uuid references public.users(id) on delete set null,
  revision         integer not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.users(id) on delete set null,
  updated_by       uuid references public.users(id) on delete set null,

  constraint customers_code_key unique (customer_code),
  constraint customers_type_check
    check (customer_type in
      ('INDIVIDUAL', 'CORPORATE', 'DEALER', 'GOVERNMENT')),
  constraint customers_status_check check (status in ('ACTIVE', 'INACTIVE')),
  constraint customers_phone_check check (phone ~ '^[6-9][0-9]{9}$'),
  constraint customers_email_check
    check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  constraint customers_pincode_check
    check (pincode is null or pincode ~ '^[1-9][0-9]{5}$'),
  constraint customers_gst_check
    check (gst_number is null or
           gst_number ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  constraint customers_pan_check
    check (pan_number is null or pan_number ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'),
  constraint customers_dob_check
    check (date_of_birth is null or date_of_birth < current_date)
);

-- A phone number identifies a customer within a showroom. Two showrooms may
-- legitimately serve the same person, so this is scoped rather than global.
create unique index if not exists customers_showroom_phone_key
  on public.customers (showroom_id, phone)
  where is_deleted = false;

-- =============================================================================
-- customer_vehicles - a customer may own many
-- =============================================================================
create table if not exists public.customer_vehicles (
  id                   uuid primary key default gen_random_uuid(),
  showroom_id          uuid not null
                       references public.showrooms(id) on delete restrict,
  customer_id          uuid not null
                       references public.customers(id) on delete restrict,
  -- The stock unit this vehicle came from. Null for a vehicle bought
  -- elsewhere that the workshop services.
  inventory_id         uuid references public.inventory(id)
                       on delete restrict,
  product_id           uuid not null
                       references public.products(id) on delete restrict,
  registration_number  text,
  registration_date    date,
  chassis_number       text not null,
  engine_number        text not null,
  purchase_date        date,
  delivery_date        date,
  current_odometer     integer not null default 0,
  warranty_start       date,
  warranty_end         date,
  insurance_start      date,
  insurance_end        date,
  next_service_date    date,
  next_service_km      integer,
  status               text not null default 'ACTIVE',

  is_deleted           boolean not null default false,
  deleted_at           timestamptz,
  deleted_by           uuid references public.users(id) on delete set null,
  revision             integer not null default 1,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  created_by           uuid references public.users(id) on delete set null,
  updated_by           uuid references public.users(id) on delete set null,

  constraint customer_vehicles_status_check
    check (status in
      ('ACTIVE', 'RESOLD', 'SCRAPPED', 'TRANSFERRED', 'STOLEN')),
  constraint customer_vehicles_odometer_check
    check (current_odometer >= 0 and current_odometer <= 999999),
  constraint customer_vehicles_warranty_range_check
    check (warranty_end is null or warranty_start is null
           or warranty_end >= warranty_start),
  constraint customer_vehicles_insurance_range_check
    check (insurance_end is null or insurance_start is null
           or insurance_end >= insurance_start),
  constraint customer_vehicles_registration_check
    check (registration_number is null
           or registration_number ~ '^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$'
           or registration_number ~ '^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$')
);

-- One stock unit becomes at most one customer vehicle. Without this, a
-- double-submitted sale could sell the same bike to two customers.
create unique index if not exists customer_vehicles_inventory_key
  on public.customer_vehicles (inventory_id)
  where inventory_id is not null and is_deleted = false;

-- A registration mark is unique nationally.
create unique index if not exists customer_vehicles_registration_key
  on public.customer_vehicles (registration_number)
  where registration_number is not null and is_deleted = false;

create unique index if not exists customer_vehicles_chassis_key
  on public.customer_vehicles (chassis_number)
  where is_deleted = false;

-- =============================================================================
-- sales
-- =============================================================================
create table if not exists public.sales (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  customer_id         uuid not null
                      references public.customers(id) on delete restrict,
  vehicle_id          uuid references public.customer_vehicles(id)
                      on delete restrict,
  salesperson_id      uuid references public.users(id) on delete set null,
  sale_number         text not null,
  sale_date           date not null default current_date,
  subtotal            money_amount not null default 0,
  discount            money_amount not null default 0,
  tax_amount          money_amount not null default 0,
  other_charges       money_amount not null default 0,
  total_amount        money_amount not null default 0,
  paid_amount         money_amount not null default 0,
  outstanding_amount  money_amount not null default 0,
  sale_type           text not null default 'CASH',
  status              text not null default 'DRAFT',
  notes               text,
  cancelled_at        timestamptz,
  cancelled_by        uuid references public.users(id) on delete set null,
  cancellation_reason text,

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint sales_type_check
    check (sale_type in
      ('CASH', 'FINANCE', 'EXCHANGE', 'CORPORATE', 'INSTITUTIONAL')),
  constraint sales_status_check
    check (status in
      ('DRAFT', 'PENDING_APPROVAL', 'CONFIRMED', 'DELIVERED', 'CANCELLED')),
  constraint sales_discount_check check (discount <= subtotal),
  -- The arithmetic the client previews must hold on the server too. A
  -- half-paisa tolerance absorbs rounding at the boundary.
  constraint sales_total_check
    check (abs(total_amount
               - (subtotal - discount + tax_amount + other_charges)) < 0.01),
  constraint sales_outstanding_check
    check (abs(outstanding_amount - (total_amount - paid_amount)) < 0.01),
  constraint sales_paid_check check (paid_amount <= total_amount + 0.01)
);

-- Sale numbers are unique within a showroom, per the specification.
create unique index if not exists sales_showroom_number_key
  on public.sales (showroom_id, sale_number);

create table if not exists public.sale_items (
  id            uuid primary key default gen_random_uuid(),
  sale_id       uuid not null references public.sales(id) on delete cascade,
  product_id    uuid references public.products(id) on delete restrict,
  inventory_id  uuid references public.inventory(id) on delete restrict,
  description   text,
  quantity      numeric(10, 2) not null default 1,
  unit_price    money_amount not null default 0,
  discount      money_amount not null default 0,
  tax_rate      percentage not null default 0,
  tax_amount    money_amount not null default 0,
  total_amount  money_amount not null default 0,
  created_at    timestamptz not null default now(),

  constraint sale_items_quantity_check check (quantity > 0),
  constraint sale_items_discount_check
    check (discount <= quantity * unit_price + 0.01)
);

-- A given stock unit can appear on only one live sale line.
create unique index if not exists sale_items_inventory_key
  on public.sale_items (inventory_id)
  where inventory_id is not null;

-- =============================================================================
-- invoices
-- =============================================================================
create table if not exists public.invoices (
  id                  uuid primary key default gen_random_uuid(),
  showroom_id         uuid not null
                      references public.showrooms(id) on delete restrict,
  customer_id         uuid not null
                      references public.customers(id) on delete restrict,
  sale_id             uuid references public.sales(id) on delete restrict,
  service_id          uuid,
  invoice_number      text not null,
  invoice_type        text not null default 'SALE',
  invoice_date        date not null default current_date,
  due_date            date,
  subtotal            money_amount not null default 0,
  discount            money_amount not null default 0,
  tax_amount          money_amount not null default 0,
  other_charges       money_amount not null default 0,
  total_amount        money_amount not null default 0,
  paid_amount         money_amount not null default 0,
  outstanding_amount  money_amount not null default 0,
  status              text not null default 'DRAFT',
  pdf_url             text,
  notes               text,
  cancelled_at        timestamptz,
  cancelled_by        uuid references public.users(id) on delete set null,

  revision            integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.users(id) on delete set null,
  updated_by          uuid references public.users(id) on delete set null,

  constraint invoices_type_check
    check (invoice_type in ('SALE', 'SERVICE', 'ACCESSORY', 'OTHER')),
  constraint invoices_status_check
    check (status in
      ('DRAFT', 'ISSUED', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED')),
  constraint invoices_total_check
    check (abs(total_amount
               - (subtotal - discount + tax_amount + other_charges)) < 0.01),
  constraint invoices_outstanding_check
    check (abs(outstanding_amount - (total_amount - paid_amount)) < 0.01),
  constraint invoices_due_date_check
    check (due_date is null or due_date >= invoice_date)
);

create unique index if not exists invoices_showroom_number_key
  on public.invoices (showroom_id, invoice_number);

create table if not exists public.invoice_items (
  id            uuid primary key default gen_random_uuid(),
  invoice_id    uuid not null
                references public.invoices(id) on delete cascade,
  product_id    uuid references public.products(id) on delete set null,
  description   text not null,
  hsn_code      text,
  quantity      numeric(10, 2) not null default 1,
  unit_price    money_amount not null default 0,
  discount      money_amount not null default 0,
  tax_rate      percentage not null default 0,
  tax_amount    money_amount not null default 0,
  total_amount  money_amount not null default 0,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),

  constraint invoice_items_quantity_check check (quantity > 0)
);

-- Now that invoices exists, close the loop from sales.
-- (sales.vehicle_id -> customer_vehicles is already declared above.)

-- =============================================================================
-- payments
-- =============================================================================
create table if not exists public.payments (
  id                uuid primary key default gen_random_uuid(),
  showroom_id       uuid not null
                    references public.showrooms(id) on delete restrict,
  customer_id       uuid references public.customers(id) on delete restrict,
  invoice_id        uuid references public.invoices(id) on delete restrict,
  sale_id           uuid references public.sales(id) on delete restrict,
  service_id        uuid,
  emi_id            uuid,
  purchase_id       uuid,
  expense_id        uuid,
  payment_number    text not null,
  payment_date      date not null default current_date,
  amount            money_amount not null,
  payment_method    text not null default 'CASH',
  direction         text not null default 'INBOUND',
  allocation        text not null default 'ADVANCE',
  reference_number  text,
  transaction_id    text,
  status            text not null default 'COMPLETED',
  notes             text,
  received_by       uuid references public.users(id) on delete set null,
  -- Reversal bookkeeping. A payment is never deleted; a reversing row is
  -- written and both are linked, so the trail stays intact.
  reversed_at       timestamptz,
  reversed_by       uuid references public.users(id) on delete set null,
  reverses_payment_id uuid references public.payments(id) on delete restrict,
  reversal_reason   text,

  revision          integer not null default 1,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references public.users(id) on delete set null,
  updated_by        uuid references public.users(id) on delete set null,

  constraint payments_method_check
    check (payment_method in
      ('CASH', 'UPI', 'CARD', 'BANK_TRANSFER', 'CHEQUE', 'FINANCE',
       'ONLINE', 'MIXED')),
  constraint payments_direction_check
    check (direction in ('INBOUND', 'OUTBOUND')),
  constraint payments_allocation_check
    check (allocation in
      ('INVOICE', 'SALE', 'SERVICE', 'EMI', 'ADVANCE', 'PURCHASE',
       'EXPENSE')),
  constraint payments_status_check
    check (status in
      ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED', 'REVERSED',
       'REFUNDED')),
  constraint payments_amount_check check (amount > 0),
  -- Non-cash tenders are unreconcilable without a reference.
  constraint payments_reference_check
    check (payment_method in ('CASH', 'MIXED')
           or reference_number is not null
           or transaction_id is not null
           or status <> 'COMPLETED')
);

create unique index if not exists payments_showroom_number_key
  on public.payments (showroom_id, payment_number);

-- Close the deferred reference from invoices to service_records, which is
-- created in 004. Declared there once the target table exists.
