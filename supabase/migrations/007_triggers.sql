-- =============================================================================
-- 007_triggers.sql
--
-- Automatic bookkeeping: timestamps, optimistic-concurrency revisions,
-- provenance columns, audit logging and a small set of safety interlocks.
--
-- -----------------------------------------------------------------------------
-- What deliberately does NOT live in a trigger
-- -----------------------------------------------------------------------------
-- No financial computation happens here. Totals, ledger postings, stock
-- allocation and EMI generation are all performed by explicit RPCs in
-- 006/013, where the sequence is visible and reviewable.
--
-- Hiding that logic in triggers would make a sale a cascade of invisible side
-- effects that fire in an order nobody can see, and would make a partial
-- failure extremely hard to reason about. Triggers here are confined to
-- mechanical bookkeeping and to refusing operations that must never happen.
-- =============================================================================

-- =============================================================================
-- Timestamps, revision and provenance
-- =============================================================================

-- Maintains updated_at only.
--
-- Used for lookup and join tables (roles, permissions, document_sequences,
-- free_service_plans) which carry no `revision` column, because they are not
-- synchronised offline and so need no concurrency counter. Referencing
-- `new.revision` on those tables raises "record new has no field revision" at
-- runtime, which is why this is a separate function rather than one that
-- guesses.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Maintains updated_at and bumps `revision`.
--
-- `revision` is the optimistic-concurrency counter the offline sync layer
-- compares against: if the server revision moved while a change sat in the
-- outbox, the queue entry is parked as a conflict rather than overwriting.
create or replace function public.set_updated_at_and_revision()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();

  -- Only bump when the row's data actually changed. Without this guard, a
  -- no-op UPDATE (common when a form is saved unedited) would invalidate
  -- every offline client's copy for no reason.
  if tg_op = 'UPDATE' and old is distinct from new then
    new.revision := coalesce(old.revision, 0) + 1;
  end if;

  return new;
end;
$$;

-- Stamps created_by only.
--
-- For append-only tables (stock_movements, audit_logs, accounting_transactions,
-- attachments) which have no `updated_by` column because their rows are never
-- modified. Assigning `new.updated_by` on those raises "record new has no
-- field updated_by" at runtime, so the variants are separate functions rather
-- than one that guesses.
create or replace function public.set_created_by()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  -- A server-side job or a seed script has no JWT; leaving this null is
  -- correct and distinguishes system writes from user writes.
  if new.created_by is null then
    new.created_by := public.current_user_id();
  end if;
  return new;
end;
$$;

-- Stamps created_by and updated_by from the current session.
create or replace function public.set_audit_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid;
begin
  v_user_id := public.current_user_id();

  if tg_op = 'INSERT' then
    if new.created_by is null then
      new.created_by := v_user_id;
    end if;
    new.updated_by := coalesce(new.updated_by, v_user_id);
  elsif tg_op = 'UPDATE' then
    -- created_by is immutable: rewriting it would destroy provenance.
    new.created_by := old.created_by;
    new.updated_by := coalesce(v_user_id, old.updated_by);
  end if;

  return new;
end;
$$;

-- Attaches the bookkeeping triggers to every table that carries the columns.
do $$
declare
  v_table text;
  v_has_revision boolean;
  v_has_created_by boolean;
  v_has_updated_by boolean;
begin
  for v_table in
    select table_name
    from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'
    order by table_name
  loop
    select
      bool_or(column_name = 'revision'),
      bool_or(column_name = 'created_by'),
      bool_or(column_name = 'updated_by')
    into v_has_revision, v_has_created_by, v_has_updated_by
    from information_schema.columns
    where table_schema = 'public' and table_name = v_table;

    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = v_table
        and column_name = 'updated_at'
    ) then
      execute format(
        'drop trigger if exists trg_%1$s_updated_at on public.%1$I', v_table
      );
      -- Pick the variant that matches the table's columns. A table without a
      -- `revision` column must not get the revision-bumping function.
      execute format(
        'create trigger trg_%1$s_updated_at
           before update on public.%1$I
           for each row execute function public.%2$I()',
        v_table,
        case when v_has_revision
             then 'set_updated_at_and_revision'
             else 'set_updated_at' end
      );
    end if;

    if v_has_created_by then
      execute format(
        'drop trigger if exists trg_%1$s_audit_user on public.%1$I', v_table
      );
      if v_has_updated_by then
        execute format(
          'create trigger trg_%1$s_audit_user
             before insert or update on public.%1$I
             for each row execute function public.set_audit_user()', v_table
        );
      else
        -- Append-only table: stamp the author on insert, nothing on update.
        execute format(
          'create trigger trg_%1$s_audit_user
             before insert on public.%1$I
             for each row execute function public.set_created_by()', v_table
        );
      end if;
    end if;
  end loop;
end $$;

-- =============================================================================
-- Audit logging
-- =============================================================================

-- Writes an audit row for every change to a table this is attached to.
--
-- Only the columns that actually changed are recorded on an UPDATE. Storing
-- the whole row both times would make the log enormous and would bury the one
-- field that mattered among fifty that did not.
create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_old        jsonb;
  v_new        jsonb;
  v_changed    jsonb := '{}'::jsonb;
  v_key        text;
  v_showroom   uuid;
  v_record_id  uuid;
  v_action     text;
begin
  if tg_op = 'INSERT' then
    v_action := 'CREATE';
    v_new := to_jsonb(new);
    v_old := null;
    v_record_id := new.id;
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_record_id := new.id;

    -- A soft delete is semantically a deletion, and reading the log as
    -- "UPDATE" would hide it from a search for removals.
    if coalesce((v_new ->> 'is_deleted')::boolean, false)
       and not coalesce((v_old ->> 'is_deleted')::boolean, false) then
      v_action := 'DELETE';
    else
      v_action := 'UPDATE';
    end if;

    -- Reduce to the changed fields.
    for v_key in select jsonb_object_keys(v_new) loop
      if v_new -> v_key is distinct from v_old -> v_key
         and v_key not in ('updated_at', 'revision', 'updated_by') then
        v_changed := v_changed || jsonb_build_object(v_key, v_new -> v_key);
      end if;
    end loop;

    -- Nothing of substance changed; not worth an audit row.
    if v_changed = '{}'::jsonb then
      return new;
    end if;

    v_new := v_changed;
    v_old := (
      select jsonb_object_agg(k, v_old -> k)
      from jsonb_object_keys(v_changed) as k
    );
  else
    v_action := 'DELETE';
    v_old := to_jsonb(old);
    v_new := null;
    v_record_id := old.id;
  end if;

  v_showroom := nullif(
    coalesce(to_jsonb(coalesce(new, old)) ->> 'showroom_id', ''), ''
  )::uuid;

  -- Deleting a showroom row would leave this audit entry pointing at a
  -- showroom that no longer exists, and audit_logs.showroom_id is a foreign
  -- key, so the insert would fail and take the delete down with it. The
  -- reference is dropped; the showroom's identity is still recoverable from
  -- old_data, which holds the whole row.
  if tg_table_name = 'showrooms' and tg_op = 'DELETE' then
    v_showroom := null;
  end if;

  insert into public.audit_logs (
    showroom_id, user_id, module, action, table_name, record_id,
    old_data, new_data
  ) values (
    v_showroom,
    public.current_user_id(),
    tg_table_name,
    v_action,
    tg_table_name,
    v_record_id,
    v_old,
    v_new
  );

  return coalesce(new, old);
end;
$$;

-- Attached to the tables where a change has financial or legal consequence.
-- Deliberately not on every table: auditing high-churn rows such as
-- notifications would swamp the log without adding accountability.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'showrooms', 'users', 'roles', 'user_roles', 'role_permissions',
    'user_showrooms', 'customers', 'customer_vehicles',
    'inventory', 'stock_transfers',
    'sales', 'invoices', 'payments',
    'loans', 'emi_schedules',
    'purchases', 'expenses',
    'service_records', 'warranties', 'warranty_claims',
    'insurance_policies', 'accounts', 'products'
  ]
  loop
    execute format(
      'drop trigger if exists trg_%1$s_audit on public.%1$I', v_table
    );
    execute format(
      'create trigger trg_%1$s_audit
         after insert or update or delete on public.%1$I
         for each row execute function public.write_audit_log()', v_table
    );
  end loop;
end $$;

-- =============================================================================
-- Safety interlocks
--
-- These refuse operations that must never happen, rather than computing
-- anything. Each mirrors a rule the client also enforces, so a user gets a
-- friendly message first and the database is the backstop.
-- =============================================================================

-- A finalised invoice is immutable.
--
-- Corrections happen through cancellation or a credit note, never by editing
-- in place: a tax invoice that silently changes after issue is a compliance
-- problem, and it would also desynchronise any printed or emailed copy.
create or replace function public.guard_invoice_immutability()
returns trigger
language plpgsql
as $$
begin
  if old.status = 'CANCELLED' and new.status <> 'CANCELLED' then
    raise exception 'A cancelled invoice cannot be reinstated'
      using errcode = 'P0001';
  end if;

  if old.status <> 'DRAFT' then
    -- Payment application and cancellation are the only legitimate changes.
    if new.subtotal is distinct from old.subtotal
       or new.discount is distinct from old.discount
       or new.tax_amount is distinct from old.tax_amount
       or new.total_amount is distinct from old.total_amount
       or new.invoice_number is distinct from old.invoice_number
       or new.customer_id is distinct from old.customer_id
       or new.invoice_date is distinct from old.invoice_date then
      raise exception
        'Invoice % has been issued and its amounts can no longer be changed. '
        'Cancel it and raise a new invoice instead.', old.invoice_number
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_invoices_immutable on public.invoices;
create trigger trg_invoices_immutable
  before update on public.invoices
  for each row execute function public.guard_invoice_immutability();

-- Line items cannot be added to or removed from an issued invoice.
create or replace function public.guard_invoice_items_immutability()
returns trigger
language plpgsql
as $$
declare
  v_status text;
  v_invoice uuid;
begin
  v_invoice := coalesce(new.invoice_id, old.invoice_id);
  select status into v_status from public.invoices where id = v_invoice;

  -- The invoice row is gone (cascade delete of a draft); nothing to guard.
  if v_status is null then
    return coalesce(new, old);
  end if;

  if v_status <> 'DRAFT' then
    raise exception
      'Line items cannot be changed on an invoice that has been issued'
      using errcode = 'P0001';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_invoice_items_immutable on public.invoice_items;
create trigger trg_invoice_items_immutable
  before insert or update or delete on public.invoice_items
  for each row execute function public.guard_invoice_items_immutability();

-- Financial rows are never physically deleted.
--
-- The business needs the history: a cancelled sale still has to appear in an
-- audit, and a reversed payment must remain visible alongside its reversal.
-- Cancellation and reversal states exist precisely so DELETE is unnecessary.
create or replace function public.guard_no_financial_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception
    'Records in % cannot be deleted. Cancel or reverse the record instead, '
    'so the financial history stays intact.', tg_table_name
    using errcode = 'P0001';
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'payments', 'accounting_transactions', 'accounting_entries',
    'audit_logs', 'stock_movements', 'emi_schedules'
  ]
  loop
    execute format(
      'drop trigger if exists trg_%1$s_no_delete on public.%1$I', v_table
    );
    execute format(
      'create trigger trg_%1$s_no_delete
         before delete on public.%1$I
         for each row execute function public.guard_no_financial_delete()',
      v_table
    );
  end loop;
end $$;

-- An odometer reading cannot go backwards.
--
-- A lower reading than the vehicle's last recorded value means either a
-- typo or a tampered meter. Both need a human, and accepting it silently
-- would corrupt free-service eligibility, which is computed from kilometres.
create or replace function public.guard_odometer_monotonic()
returns trigger
language plpgsql
as $$
declare
  v_current integer;
begin
  select current_odometer into v_current
  from public.customer_vehicles
  where id = new.vehicle_id;

  if v_current is not null and new.odometer_reading < v_current then
    raise exception
      'Odometer reading %km is below the last recorded %km for this vehicle',
      new.odometer_reading, v_current
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_service_odometer on public.service_records;
create trigger trg_service_odometer
  before insert or update of odometer_reading on public.service_records
  for each row
  when (new.odometer_reading > 0)
  execute function public.guard_odometer_monotonic();

-- Keeps the vehicle's odometer in step with the workshop's latest reading.
create or replace function public.sync_vehicle_odometer()
returns trigger
language plpgsql
as $$
begin
  update public.customer_vehicles
  set current_odometer = new.odometer_reading,
      updated_at = now()
  where id = new.vehicle_id
    and current_odometer < new.odometer_reading;

  return new;
end;
$$;

drop trigger if exists trg_service_sync_odometer on public.service_records;
create trigger trg_service_sync_odometer
  after insert or update of odometer_reading on public.service_records
  for each row
  when (new.odometer_reading > 0)
  execute function public.sync_vehicle_odometer();

-- Records a stock movement whenever a unit changes state.
--
-- This is bookkeeping, not business logic: the movement ledger must never
-- miss a transition, and requiring every caller to remember to write one
-- guarantees that eventually somebody will not.
create or replace function public.record_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_type text;
begin
  if tg_op = 'INSERT' then
    v_type := 'STOCK_IN';
  elsif old.status is distinct from new.status then
    v_type := case new.status
      when 'SOLD'       then 'SALE_ALLOCATION'
      when 'RESERVED'   then 'RESERVATION'
      when 'AVAILABLE'  then case
                               when old.status = 'RESERVED' then 'RELEASE'
                               when old.status = 'SOLD' then 'SALE_REVERSAL'
                               when old.status = 'IN_TRANSIT'
                                 then 'TRANSFER_IN'
                               else 'ADJUSTMENT'
                             end
      when 'IN_TRANSIT' then 'TRANSFER_OUT'
      when 'DAMAGED'    then 'DAMAGE'
      when 'RETURNED'   then 'RETURN_TO_SUPPLIER'
      else 'ADJUSTMENT'
    end;
  else
    return new;
  end if;

  insert into public.stock_movements (
    showroom_id, inventory_id, movement_type,
    from_status, to_status, created_by
  ) values (
    new.showroom_id, new.id, v_type,
    case when tg_op = 'UPDATE' then old.status else null end,
    new.status,
    public.current_user_id()
  );

  return new;
end;
$$;

drop trigger if exists trg_inventory_movement on public.inventory;
create trigger trg_inventory_movement
  after insert or update of status on public.inventory
  for each row execute function public.record_stock_movement();

-- Normalises a customer phone number to bare digits before it is stored, so
-- the unique index on (showroom_id, phone) is not defeated by formatting.
create or replace function public.normalise_customer_phone()
returns trigger
language plpgsql
as $$
begin
  new.phone := public.normalise_phone(new.phone);
  new.alternate_phone := nullif(
    regexp_replace(coalesce(new.alternate_phone, ''), '[^0-9]', '', 'g'), ''
  );
  new.email := nullif(lower(btrim(coalesce(new.email, ''))), '');
  new.gst_number := nullif(upper(btrim(coalesce(new.gst_number, ''))), '');
  new.pan_number := nullif(upper(btrim(coalesce(new.pan_number, ''))), '');
  return new;
end;
$$;

drop trigger if exists trg_customers_normalise on public.customers;
create trigger trg_customers_normalise
  before insert or update on public.customers
  for each row execute function public.normalise_customer_phone();

-- Uppercases the vehicle identifiers so lookups match regardless of entry.
create or replace function public.normalise_vehicle_identifiers()
returns trigger
language plpgsql
as $$
begin
  new.chassis_number := upper(btrim(new.chassis_number));
  new.engine_number := upper(btrim(new.engine_number));
  if tg_table_name = 'customer_vehicles' then
    new.registration_number := nullif(
      upper(regexp_replace(coalesce(new.registration_number, ''),
                           '[\s-]', '', 'g')),
      ''
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_inventory_normalise on public.inventory;
create trigger trg_inventory_normalise
  before insert or update on public.inventory
  for each row execute function public.normalise_vehicle_identifiers();

drop trigger if exists trg_vehicles_normalise on public.customer_vehicles;
create trigger trg_vehicles_normalise
  before insert or update on public.customer_vehicles
  for each row execute function public.normalise_vehicle_identifiers();

-- Derives warranty and insurance status from their dates.
--
-- Safe to derive because it is a pure function of the dates and today; it is
-- not a financial decision. Keeping it in one place means every list, tile and
-- report agrees on what "expiring soon" means.
-- Shared classifier, so "expiring soon" means the same thing everywhere.
create or replace function public.classify_validity(p_end_date date)
returns text
language sql
immutable
as $$
  select case
    when p_end_date < current_date then 'EXPIRED'
    when p_end_date <= current_date + interval '30 days' then 'EXPIRING_SOON'
    else 'ACTIVE'
  end;
$$;

-- One function per table rather than a shared one branching on
-- tg_table_name: PL/pgSQL resolves every record-field reference in an
-- expression when it plans that expression, so a CASE mentioning both
-- `new.end_date` and `new.expiry_date` fails on whichever table lacks the
-- other column, even on the branch that is never taken.
create or replace function public.derive_warranty_status()
returns trigger
language plpgsql
as $$
begin
  -- Manual terminal states are respected and never overwritten.
  if new.status in ('CANCELLED', 'VOIDED') then
    return new;
  end if;
  new.status := public.classify_validity(new.end_date);
  return new;
end;
$$;

create or replace function public.derive_insurance_status()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'CANCELLED' then
    return new;
  end if;
  new.status := public.classify_validity(new.expiry_date);
  return new;
end;
$$;

drop trigger if exists trg_warranties_status on public.warranties;
create trigger trg_warranties_status
  before insert or update of end_date, status on public.warranties
  for each row execute function public.derive_warranty_status();

drop trigger if exists trg_insurance_status on public.insurance_policies;
create trigger trg_insurance_status
  before insert or update of expiry_date, status on public.insurance_policies
  for each row execute function public.derive_insurance_status();
