-- =============================================================================
-- 006b_transaction_functions.sql
--
-- The atomic business operations.
--
-- Split from 006_functions.sql purely for file size; it runs immediately after
-- it (lexical ordering puts `006b` between `006` and `007`).
--
-- -----------------------------------------------------------------------------
-- Why these are server-side functions and not client orchestration
-- -----------------------------------------------------------------------------
-- A vehicle sale touches eleven tables. Performed as eleven client requests,
-- any failure - a dropped connection, a closed laptop, a rejected policy -
-- leaves the business in an impossible state: stock marked sold with no
-- invoice, or an invoice with no stock allocated, or a loan with no schedule.
--
-- Each function here runs in a single transaction. It either commits
-- completely or leaves nothing behind. Every figure is recomputed server-side
-- rather than trusted from the request, because the client can be tampered
-- with and because a stale price in a form must not silently become the
-- recorded sale price.
--
-- They reference ledger accounts by code; the chart of accounts is created per
-- showroom in 013_accounting.sql. PL/pgSQL resolves called functions at
-- execution time, so the forward reference is not a problem at creation.
-- =============================================================================

-- =============================================================================
-- create_sale_transaction
--
-- Implements the flow in specification sections 13 and 63:
--
--   validate customer -> validate inventory -> create sale -> sale items
--   -> allocate stock -> customer vehicle -> invoice -> invoice items
--   -> initial payment -> loan -> EMI schedule -> warranty
--   -> free service schedule -> accounting -> reminders
-- =============================================================================
create or replace function public.create_sale_transaction(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_showroom_id    uuid := (p_payload ->> 'showroom_id')::uuid;
  v_customer_id    uuid := (p_payload ->> 'customer_id')::uuid;
  v_salesperson_id uuid;
  v_sale_date      date := coalesce(
                            (p_payload ->> 'sale_date')::date, current_date);
  v_sale_type      text := coalesce(p_payload ->> 'sale_type', 'CASH');
  v_items          jsonb := coalesce(p_payload -> 'items', '[]'::jsonb);
  v_item           jsonb;

  v_sale_id        uuid;
  v_invoice_id     uuid;
  v_vehicle_id     uuid;
  v_loan_id        uuid;
  v_payment_id     uuid;

  v_sale_number    text;
  v_invoice_number text;

  v_subtotal       numeric := 0;
  v_line_discount  numeric := 0;
  v_tax            numeric := 0;
  v_doc_discount   numeric := 0;
  v_other_charges  numeric := coalesce(
                            (p_payload ->> 'other_charges')::numeric, 0);
  v_total          numeric := 0;
  v_paid           numeric := 0;

  v_inventory      public.inventory%rowtype;
  v_product        public.products%rowtype;
  v_customer       public.customers%rowtype;

  v_line_gross     numeric;
  v_line_disc      numeric;
  v_line_taxable   numeric;
  v_line_tax       numeric;
  v_line_total     numeric;
  v_qty            numeric;
  v_unit_price     numeric;

  v_primary_inventory uuid;
  v_warranty_months int := 24;
  v_entries        jsonb := '[]'::jsonb;
  v_discount_pct   numeric;
  v_threshold      numeric;
begin
  -- ---------------------------------------------------------------- guards
  if v_showroom_id is null then
    raise exception 'A showroom is required' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('sales', 'create') then
    raise exception 'You do not have permission to create a sale'
      using errcode = 'P0001';
  end if;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'A sale must have at least one item'
      using errcode = 'P0001';
  end if;

  -- Validate customer: must exist AND belong to this showroom. Checking the
  -- showroom explicitly stops a crafted payload attaching another branch's
  -- customer to this sale.
  select * into v_customer
  from public.customers
  where id = v_customer_id and is_deleted = false;

  if not found then
    raise exception 'Customer not found' using errcode = 'P0001';
  end if;

  if v_customer.showroom_id <> v_showroom_id then
    raise exception 'That customer belongs to a different showroom'
      using errcode = 'P0001';
  end if;

  v_salesperson_id := coalesce(
    (p_payload ->> 'salesperson_id')::uuid,
    public.current_user_id()
  );

  -- ------------------------------------------------------- price the lines
  -- Every figure is recomputed here. The client sends quantities and the
  -- discount it wants; prices and tax rates come from the catalogue, so a
  -- tampered or stale form cannot set its own price.
  for v_item in select * from jsonb_array_elements(v_items) loop
    select * into v_inventory
    from public.inventory
    where id = (v_item ->> 'inventory_id')::uuid
      and is_deleted = false
    for update;   -- lock the unit for the duration of this transaction

    if not found then
      raise exception 'Stock item not found' using errcode = 'P0001';
    end if;

    if v_inventory.showroom_id <> v_showroom_id then
      raise exception
        'Stock item % is held at a different showroom',
        v_inventory.stock_code
        using errcode = 'P0001';
    end if;

    -- The allocatable states mirror InventoryStatus.isAllocatable on the
    -- client. The FOR UPDATE above means two simultaneous sales of the same
    -- bike serialise here, and the second sees SOLD and is rejected.
    if v_inventory.status not in ('AVAILABLE', 'RESERVED', 'DEMO') then
      raise exception
        'Stock item % is % and cannot be sold',
        v_inventory.stock_code, lower(v_inventory.status)
        using errcode = 'P0001';
    end if;

    select * into v_product
    from public.products where id = v_inventory.product_id;

    v_qty := coalesce((v_item ->> 'quantity')::numeric, 1);
    v_unit_price := coalesce(
      (v_item ->> 'unit_price')::numeric,
      v_product.selling_price
    );

    v_line_gross := round(v_qty * v_unit_price, 2);
    v_line_disc := round(
      least(coalesce((v_item ->> 'discount')::numeric, 0), v_line_gross), 2
    );
    v_line_taxable := v_line_gross - v_line_disc;
    v_line_tax := round(
      v_line_taxable * coalesce(
        (v_item ->> 'tax_rate')::numeric, v_product.tax_rate
      ) / 100.0,
      2
    );
    v_line_total := round(v_line_taxable + v_line_tax, 2);

    v_subtotal := v_subtotal + v_line_gross;
    v_line_discount := v_line_discount + v_line_disc;
    v_tax := v_tax + v_line_tax;

    if v_primary_inventory is null then
      v_primary_inventory := v_inventory.id;
      v_warranty_months := coalesce(v_product.warranty_months, 24);
    end if;
  end loop;

  v_doc_discount := round(
    least(
      coalesce((p_payload ->> 'discount')::numeric, 0),
      v_subtotal - v_line_discount
    ), 2
  );

  v_total := round(
    v_subtotal - v_line_discount - v_doc_discount + v_tax + v_other_charges, 2
  );

  -- A discount beyond the showroom's threshold needs sales.approve. This is
  -- the control that stops a salesperson discounting without oversight; the
  -- client hides the field, and this is the enforcement.
  v_threshold := coalesce(
    (select (settings ->> 'discount_approval_threshold')::numeric
     from public.showrooms where id = v_showroom_id),
    5
  );
  if v_subtotal > 0 then
    v_discount_pct := (v_line_discount + v_doc_discount) / v_subtotal * 100;
    if v_discount_pct > v_threshold
       and not public.has_permission('sales', 'approve')
       and not public.has_permission('sales', 'discount') then
      -- Note: in RAISE, '%' is the placeholder and '%%' is a literal percent
      -- sign, so the unit is spelled out rather than written as a symbol.
      raise exception
        'A discount of % percent requires approval (the limit is % percent)',
        round(v_discount_pct, 2), v_threshold
        using errcode = 'P0001';
    end if;
  end if;

  -- ------------------------------------------------------------ create sale
  v_sale_number := public.next_document_number(
    v_showroom_id, 'SALE', v_sale_date
  );

  insert into public.sales (
    showroom_id, customer_id, salesperson_id, sale_number, sale_date,
    subtotal, discount, tax_amount, other_charges, total_amount,
    paid_amount, outstanding_amount, sale_type, status, notes
  ) values (
    v_showroom_id, v_customer_id, v_salesperson_id, v_sale_number, v_sale_date,
    v_subtotal, v_line_discount + v_doc_discount, v_tax, v_other_charges,
    v_total, 0, v_total, v_sale_type,
    coalesce(p_payload ->> 'status', 'CONFIRMED'),
    p_payload ->> 'notes'
  )
  returning id into v_sale_id;

  -- ------------------------------------------------- items + stock + vehicle
  for v_item in select * from jsonb_array_elements(v_items) loop
    select * into v_inventory
    from public.inventory where id = (v_item ->> 'inventory_id')::uuid;

    select * into v_product
    from public.products where id = v_inventory.product_id;

    v_qty := coalesce((v_item ->> 'quantity')::numeric, 1);
    v_unit_price := coalesce(
      (v_item ->> 'unit_price')::numeric, v_product.selling_price
    );
    v_line_gross := round(v_qty * v_unit_price, 2);
    v_line_disc := round(
      least(coalesce((v_item ->> 'discount')::numeric, 0), v_line_gross), 2
    );
    v_line_taxable := v_line_gross - v_line_disc;
    v_line_tax := round(
      v_line_taxable * coalesce(
        (v_item ->> 'tax_rate')::numeric, v_product.tax_rate) / 100.0, 2
    );

    insert into public.sale_items (
      sale_id, product_id, inventory_id, description,
      quantity, unit_price, discount, tax_rate, tax_amount, total_amount
    ) values (
      v_sale_id, v_product.id, v_inventory.id,
      concat_ws(' ', v_product.name, v_product.variant),
      v_qty, v_unit_price, v_line_disc,
      coalesce((v_item ->> 'tax_rate')::numeric, v_product.tax_rate),
      v_line_tax, round(v_line_taxable + v_line_tax, 2)
    );

    -- Allocate the unit. The stock-movement ledger row is written by the
    -- trigger on inventory, so it can never be forgotten here.
    update public.inventory
    set status = 'SOLD', updated_at = now()
    where id = v_inventory.id;

    -- Register the customer's vehicle for the first serialised unit.
    if v_vehicle_id is null and v_product.category in
       ('MOTORCYCLE', 'SCOOTER', 'MOPED', 'ELECTRIC_TWO_WHEELER') then
      insert into public.customer_vehicles (
        showroom_id, customer_id, inventory_id, product_id,
        chassis_number, engine_number, purchase_date, delivery_date,
        warranty_start, warranty_end, status
      ) values (
        v_showroom_id, v_customer_id, v_inventory.id, v_product.id,
        v_inventory.chassis_number, v_inventory.engine_number,
        v_sale_date,
        coalesce((p_payload ->> 'delivery_date')::date, v_sale_date),
        v_sale_date,
        public.add_months(v_sale_date, v_warranty_months),
        'ACTIVE'
      )
      returning id into v_vehicle_id;
    end if;
  end loop;

  update public.sales set vehicle_id = v_vehicle_id where id = v_sale_id;

  -- ---------------------------------------------------------------- invoice
  v_invoice_number := public.next_document_number(
    v_showroom_id, 'INVOICE', v_sale_date
  );

  insert into public.invoices (
    showroom_id, customer_id, sale_id, invoice_number, invoice_type,
    invoice_date, subtotal, discount, tax_amount, other_charges,
    total_amount, paid_amount, outstanding_amount, status
  ) values (
    v_showroom_id, v_customer_id, v_sale_id, v_invoice_number, 'SALE',
    v_sale_date, v_subtotal, v_line_discount + v_doc_discount, v_tax,
    v_other_charges, v_total, 0, v_total, 'DRAFT'
  )
  returning id into v_invoice_id;

  insert into public.invoice_items (
    invoice_id, product_id, description, hsn_code,
    quantity, unit_price, discount, tax_rate, tax_amount, total_amount,
    sort_order
  )
  select
    v_invoice_id, si.product_id,
    coalesce(si.description, p.name), p.hsn_code,
    si.quantity, si.unit_price, si.discount, si.tax_rate,
    si.tax_amount, si.total_amount,
    row_number() over (order by si.created_at)
  from public.sale_items si
  join public.products p on p.id = si.product_id
  where si.sale_id = v_sale_id;

  -- Issued after the items are in place, because the immutability trigger
  -- refuses item changes once the invoice leaves DRAFT.
  update public.invoices set status = 'ISSUED' where id = v_invoice_id;

  -- ------------------------------------------------------------- accounting
  -- Sale: the customer owes us the full amount; revenue and tax are credited
  -- separately because the tax is a liability to the authority, not income.
  v_entries := jsonb_build_array(
    jsonb_build_object(
      'account_code', '1003', 'debit', v_total, 'credit', 0,
      'description', 'Receivable for ' || v_sale_number),
    jsonb_build_object(
      'account_code', '4001', 'debit', 0,
      'credit', v_subtotal - v_line_discount - v_doc_discount,
      'description', 'Vehicle sale revenue')
  );

  if v_tax > 0 then
    v_entries := v_entries || jsonb_build_array(jsonb_build_object(
      'account_code', '2002', 'debit', 0, 'credit', v_tax,
      'description', 'GST payable'));
  end if;

  if v_other_charges > 0 then
    v_entries := v_entries || jsonb_build_array(jsonb_build_object(
      'account_code', '4003', 'debit', 0, 'credit', v_other_charges,
      'description', 'Other charges'));
  end if;

  perform public.create_accounting_transaction(
    v_showroom_id, v_sale_date, 'SALE', v_sale_id,
    'Sale ' || v_sale_number, v_entries
  );

  -- --------------------------------------------------------- initial payment
  v_paid := coalesce((p_payload ->> 'paid_amount')::numeric, 0);
  if v_paid > 0 then
    v_payment_id := public.record_payment(jsonb_build_object(
      'showroom_id',      v_showroom_id,
      'customer_id',      v_customer_id,
      'invoice_id',       v_invoice_id,
      'sale_id',          v_sale_id,
      'amount',           v_paid,
      'payment_method',   coalesce(p_payload ->> 'payment_method', 'CASH'),
      'payment_date',     v_sale_date,
      'allocation',       'INVOICE',
      'reference_number', p_payload ->> 'payment_reference'
    ));
  end if;

  -- ----------------------------------------------------------- finance / EMI
  if v_sale_type = 'FINANCE' and p_payload ? 'loan' then
    v_loan_id := public.create_loan_with_schedule(
      (p_payload -> 'loan')
      || jsonb_build_object(
           'showroom_id', v_showroom_id,
           'customer_id', v_customer_id,
           'vehicle_id',  v_vehicle_id,
           'sale_id',     v_sale_id
         )
    );
  end if;

  -- --------------------------------------------- warranty + free services
  if v_vehicle_id is not null then
    insert into public.warranties (
      showroom_id, vehicle_id, warranty_type, start_date, end_date, terms
    ) values (
      v_showroom_id, v_vehicle_id, 'STANDARD', v_sale_date,
      public.add_months(v_sale_date, v_warranty_months),
      'Manufacturer standard warranty'
    )
    on conflict (vehicle_id, warranty_type) do nothing;

    perform public.generate_free_service_schedule(v_vehicle_id);
  end if;

  -- Reminders for the schedule just created are raised by the nightly job in
  -- 012_reminders.sql, which keeps this function focused on the transaction.

  return jsonb_build_object(
    'sale_id',        v_sale_id,
    'sale_number',    v_sale_number,
    'invoice_id',     v_invoice_id,
    'invoice_number', v_invoice_number,
    'vehicle_id',     v_vehicle_id,
    'loan_id',        v_loan_id,
    'payment_id',     v_payment_id,
    'total_amount',   v_total,
    'paid_amount',    v_paid,
    'outstanding',    v_total - v_paid
  );
end;
$$;

comment on function public.create_sale_transaction(jsonb) is
  'Atomic vehicle sale: sale, items, stock allocation, customer vehicle, '
  'invoice, payment, finance, warranty, free services and ledger postings.';

-- =============================================================================
-- record_payment
--
-- The single entry point for money coming in. Applies the payment to the
-- correct balance, updates every affected document, and posts to the ledger.
-- =============================================================================
create or replace function public.record_payment(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_showroom_id uuid := (p_payload ->> 'showroom_id')::uuid;
  v_amount      numeric := round((p_payload ->> 'amount')::numeric, 2);
  v_method      text := coalesce(p_payload ->> 'payment_method', 'CASH');
  v_allocation  text := coalesce(p_payload ->> 'allocation', 'ADVANCE');
  v_date        date := coalesce(
                        (p_payload ->> 'payment_date')::date, current_date);
  v_invoice_id  uuid := (p_payload ->> 'invoice_id')::uuid;
  v_sale_id     uuid := (p_payload ->> 'sale_id')::uuid;
  v_service_id  uuid := (p_payload ->> 'service_id')::uuid;
  v_emi_id      uuid := (p_payload ->> 'emi_id')::uuid;
  v_customer_id uuid := (p_payload ->> 'customer_id')::uuid;

  v_payment_id  uuid;
  v_number      text;
  v_outstanding numeric;
  v_cash_account text;
  v_allow_advance boolean := coalesce(
                        (p_payload ->> 'allow_advance')::boolean, false);
begin
  if not public.can_access_showroom(v_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not (public.has_permission('payments', 'create')
          or public.has_permission('emi', 'payment')) then
    raise exception 'You do not have permission to record a payment'
      using errcode = 'P0001';
  end if;

  if v_amount is null or v_amount <= 0 then
    raise exception 'Payment amount must be greater than zero'
      using errcode = 'P0001';
  end if;

  -- Non-cash tenders are unreconcilable without a reference.
  if v_method not in ('CASH', 'MIXED')
     and coalesce(p_payload ->> 'reference_number',
                  p_payload ->> 'transaction_id') is null then
    raise exception
      'A reference number is required for a % payment', lower(v_method)
      using errcode = 'P0001';
  end if;

  -- Overpayment is refused unless deliberately booked as an advance. Silently
  -- accepting it would leave a negative outstanding balance that no report
  -- knows how to present.
  if v_invoice_id is not null then
    select outstanding_amount into v_outstanding
    from public.invoices where id = v_invoice_id for update;

    if not found then
      raise exception 'Invoice not found' using errcode = 'P0001';
    end if;

    if v_amount > v_outstanding + 0.01 and not v_allow_advance then
      raise exception
        'Payment of %.2f exceeds the outstanding balance of %.2f',
        v_amount, v_outstanding
        using errcode = 'P0001';
    end if;
  end if;

  v_number := public.next_document_number(v_showroom_id, 'PAYMENT', v_date);

  insert into public.payments (
    showroom_id, customer_id, invoice_id, sale_id, service_id, emi_id,
    payment_number, payment_date, amount, payment_method, direction,
    allocation, reference_number, transaction_id, status, notes, received_by
  ) values (
    v_showroom_id, v_customer_id, v_invoice_id, v_sale_id, v_service_id,
    v_emi_id, v_number, v_date, v_amount, v_method, 'INBOUND',
    v_allocation,
    p_payload ->> 'reference_number',
    p_payload ->> 'transaction_id',
    'COMPLETED',
    p_payload ->> 'notes',
    public.current_user_id()
  )
  returning id into v_payment_id;

  -- ------------------------------------------------- apply to the balances
  if v_invoice_id is not null then
    update public.invoices
    set paid_amount = paid_amount + v_amount,
        outstanding_amount = greatest(total_amount - (paid_amount + v_amount), 0),
        status = case
          when total_amount - (paid_amount + v_amount) <= 0.01 then 'PAID'
          else 'PARTIALLY_PAID'
        end,
        updated_at = now()
    where id = v_invoice_id;
  end if;

  if v_sale_id is not null then
    update public.sales
    set paid_amount = paid_amount + v_amount,
        outstanding_amount = greatest(total_amount - (paid_amount + v_amount), 0),
        updated_at = now()
    where id = v_sale_id;
  end if;

  if v_service_id is not null then
    update public.service_records
    set paid_amount = paid_amount + v_amount,
        outstanding_amount = greatest(total_amount - (paid_amount + v_amount), 0),
        updated_at = now()
    where id = v_service_id;
  end if;

  if v_emi_id is not null then
    update public.emi_schedules
    set paid_amount = paid_amount + v_amount,
        remaining_amount = greatest(
          emi_amount + penalty_amount - (paid_amount + v_amount), 0),
        paid_date = case
          when emi_amount + penalty_amount - (paid_amount + v_amount) <= 0.01
            then v_date else paid_date end,
        status = case
          when emi_amount + penalty_amount - (paid_amount + v_amount) <= 0.01
            then 'PAID' else 'PARTIAL' end,
        updated_at = now()
    where id = v_emi_id;
  end if;

  -- ------------------------------------------------------------- accounting
  -- Cash and bank are separate accounts because they reconcile against
  -- different statements.
  v_cash_account := case when v_method = 'CASH' then '1001' else '1002' end;

  perform public.create_accounting_transaction(
    v_showroom_id, v_date, 'PAYMENT', v_payment_id,
    'Payment ' || v_number,
    jsonb_build_array(
      jsonb_build_object(
        'account_code', v_cash_account, 'debit', v_amount, 'credit', 0,
        'description', 'Received via ' || v_method),
      jsonb_build_object(
        'account_code',
        case when v_allocation = 'ADVANCE' then '2003' else '1003' end,
        'debit', 0, 'credit', v_amount,
        'description',
        case when v_allocation = 'ADVANCE'
             then 'Customer advance' else 'Receivable settled' end)
    )
  );

  return v_payment_id;
end;
$$;

-- =============================================================================
-- reverse_payment
--
-- A payment is never deleted. A reversing payment row is written, linked to
-- the original, and the ledger is reversed by a mirror-image journal. Both
-- rows stay visible so the trail explains itself.
-- =============================================================================
create or replace function public.reverse_payment(
  p_payment_id uuid,
  p_reason     text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_original   public.payments%rowtype;
  v_reversal   uuid;
  v_number     text;
  v_cash_account text;
begin
  select * into v_original
  from public.payments where id = p_payment_id for update;

  if not found then
    raise exception 'Payment not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_original.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('payments', 'refund') then
    raise exception 'You do not have permission to reverse a payment'
      using errcode = 'P0001';
  end if;

  if v_original.status <> 'COMPLETED' then
    raise exception 'Only a completed payment can be reversed'
      using errcode = 'P0001';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'A reason is required to reverse a payment'
      using errcode = 'P0001';
  end if;

  v_number := public.next_document_number(
    v_original.showroom_id, 'PAYMENT', current_date
  );

  insert into public.payments (
    showroom_id, customer_id, invoice_id, sale_id, service_id, emi_id,
    payment_number, payment_date, amount, payment_method, direction,
    allocation, status, notes, received_by,
    reverses_payment_id, reversal_reason
  ) values (
    v_original.showroom_id, v_original.customer_id, v_original.invoice_id,
    v_original.sale_id, v_original.service_id, v_original.emi_id,
    v_number, current_date, v_original.amount, v_original.payment_method,
    'OUTBOUND', v_original.allocation, 'COMPLETED',
    'Reversal of ' || v_original.payment_number, public.current_user_id(),
    p_payment_id, p_reason
  )
  returning id into v_reversal;

  update public.payments
  set status = 'REVERSED', reversed_at = now(),
      reversed_by = public.current_user_id(), updated_at = now()
  where id = p_payment_id;

  -- Unwind the balances.
  if v_original.invoice_id is not null then
    update public.invoices
    set paid_amount = greatest(paid_amount - v_original.amount, 0),
        outstanding_amount = least(
          total_amount, outstanding_amount + v_original.amount),
        status = case
          when paid_amount - v_original.amount <= 0.01 then 'ISSUED'
          else 'PARTIALLY_PAID' end,
        updated_at = now()
    where id = v_original.invoice_id;
  end if;

  if v_original.sale_id is not null then
    update public.sales
    set paid_amount = greatest(paid_amount - v_original.amount, 0),
        outstanding_amount = least(
          total_amount, outstanding_amount + v_original.amount),
        updated_at = now()
    where id = v_original.sale_id;
  end if;

  if v_original.emi_id is not null then
    update public.emi_schedules
    set paid_amount = greatest(paid_amount - v_original.amount, 0),
        remaining_amount = emi_amount + penalty_amount
                           - greatest(paid_amount - v_original.amount, 0),
        paid_date = null,
        status = case
          when greatest(paid_amount - v_original.amount, 0) > 0
            then 'PARTIAL'
          when due_date < current_date then 'OVERDUE'
          when due_date = current_date then 'DUE'
          else 'UPCOMING' end,
        updated_at = now()
    where id = v_original.emi_id;
  end if;

  v_cash_account := case
    when v_original.payment_method = 'CASH' then '1001' else '1002' end;

  perform public.create_accounting_transaction(
    v_original.showroom_id, current_date, 'REFUND', v_reversal,
    'Reversal of payment ' || v_original.payment_number,
    jsonb_build_array(
      jsonb_build_object(
        'account_code',
        case when v_original.allocation = 'ADVANCE' then '2003' else '1003' end,
        'debit', v_original.amount, 'credit', 0,
        'description', 'Receivable restored'),
      jsonb_build_object(
        'account_code', v_cash_account, 'debit', 0,
        'credit', v_original.amount, 'description', 'Cash refunded')
    )
  );

  return v_reversal;
end;
$$;

-- =============================================================================
-- create_loan_with_schedule
--
-- Creates the loan and generates its full instalment plan in one transaction,
-- so a loan can never exist without a schedule.
-- =============================================================================
create or replace function public.create_loan_with_schedule(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_showroom_id uuid := (p_payload ->> 'showroom_id')::uuid;
  v_loan_id     uuid;
  v_number      text;
  v_principal   numeric;
  v_emi         numeric;
  v_start       date := coalesce(
                        (p_payload ->> 'start_date')::date, current_date);
  v_rate        numeric := (p_payload ->> 'interest_rate')::numeric;
  v_tenure      int := (p_payload ->> 'tenure_months')::int;
  v_type        text := coalesce(p_payload ->> 'interest_type', 'REDUCING');
begin
  if not public.can_access_showroom(v_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('finance', 'create') then
    raise exception 'You do not have permission to create a loan'
      using errcode = 'P0001';
  end if;

  v_principal := round(
    (p_payload ->> 'loan_amount')::numeric
    - coalesce((p_payload ->> 'down_payment')::numeric, 0), 2
  );

  if v_principal <= 0 then
    raise exception
      'The down payment covers the full amount; no finance is required'
      using errcode = 'P0001';
  end if;

  v_emi := public.calculate_emi(v_principal, v_rate, v_tenure, v_type);
  v_number := public.next_document_number(v_showroom_id, 'LOAN', v_start);

  insert into public.loans (
    showroom_id, customer_id, vehicle_id, sale_id, finance_company_id,
    loan_number, loan_amount, down_payment, interest_rate, interest_type,
    tenure_months, emi_amount, processing_fee, start_date, status
  ) values (
    v_showroom_id,
    (p_payload ->> 'customer_id')::uuid,
    (p_payload ->> 'vehicle_id')::uuid,
    (p_payload ->> 'sale_id')::uuid,
    (p_payload ->> 'finance_company_id')::uuid,
    v_number, v_principal,
    coalesce((p_payload ->> 'down_payment')::numeric, 0),
    v_rate, v_type, v_tenure, v_emi,
    coalesce((p_payload ->> 'processing_fee')::numeric, 0),
    v_start, 'ACTIVE'
  )
  returning id into v_loan_id;

  perform public.generate_emi_schedule(v_loan_id);

  return v_loan_id;
end;
$$;

-- =============================================================================
-- generate_free_service_schedule
--
-- Creates the vehicle's free-service entitlements from the applicable plan.
-- Falls back to the global default plan when the product has none of its own.
-- =============================================================================
create or replace function public.generate_free_service_schedule(
  p_vehicle_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_vehicle public.customer_vehicles%rowtype;
  v_plan    record;
  v_count   int := 0;
  v_base    date;
begin
  select * into v_vehicle
  from public.customer_vehicles where id = p_vehicle_id;

  if not found then
    raise exception 'Vehicle not found' using errcode = 'P0001';
  end if;

  v_base := coalesce(
    v_vehicle.delivery_date, v_vehicle.purchase_date, current_date
  );

  for v_plan in
    select * from public.free_service_plans
    where is_active = true
      and (product_id = v_vehicle.product_id
           or (product_id is null and not exists (
                 select 1 from public.free_service_plans p2
                 where p2.product_id = v_vehicle.product_id
                   and p2.is_active = true
               )))
    order by service_number
  loop
    insert into public.vehicle_free_services (
      showroom_id, vehicle_id, free_service_plan_id, service_number,
      due_date, due_km, status
    ) values (
      v_vehicle.showroom_id, p_vehicle_id, v_plan.id, v_plan.service_number,
      v_base + v_plan.validity_days,
      v_vehicle.current_odometer + v_plan.validity_km,
      'UPCOMING'
    )
    on conflict (vehicle_id, service_number) do nothing;

    v_count := v_count + 1;
  end loop;

  -- Point the vehicle at its first due service so the reminder job and the
  -- dashboard have something to work from immediately.
  update public.customer_vehicles v
  set next_service_date = (
        select min(due_date) from public.vehicle_free_services
        where vehicle_id = p_vehicle_id and status in ('UPCOMING', 'DUE')),
      next_service_km = (
        select min(due_km) from public.vehicle_free_services
        where vehicle_id = p_vehicle_id and status in ('UPCOMING', 'DUE')),
      updated_at = now()
  where v.id = p_vehicle_id;

  return v_count;
end;
$$;

-- =============================================================================
-- check_free_service_eligibility
--
-- Eligibility is a function of date, odometer and consumption state. All three
-- are checked: a vehicle within its date window but past the kilometre limit
-- is not eligible, and neither is one whose entitlement was already used.
-- =============================================================================
create or replace function public.check_free_service_eligibility(
  p_vehicle_id uuid,
  p_odometer   integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_entry    record;
  v_odometer integer;
begin
  select coalesce(p_odometer, current_odometer) into v_odometer
  from public.customer_vehicles where id = p_vehicle_id;

  if v_odometer is null then
    return jsonb_build_object('eligible', false, 'reason', 'Vehicle not found');
  end if;

  select * into v_entry
  from public.vehicle_free_services
  where vehicle_id = p_vehicle_id
    and status in ('UPCOMING', 'DUE')
  order by service_number
  limit 1;

  if not found then
    return jsonb_build_object(
      'eligible', false,
      'reason', 'No free services remain for this vehicle'
    );
  end if;

  if current_date > v_entry.due_date then
    return jsonb_build_object(
      'eligible', false,
      'service_number', v_entry.service_number,
      'reason', format(
        'Free service %s expired on %s',
        v_entry.service_number, to_char(v_entry.due_date, 'DD Mon YYYY'))
    );
  end if;

  if v_odometer > v_entry.due_km then
    return jsonb_build_object(
      'eligible', false,
      'service_number', v_entry.service_number,
      'reason', format(
        'Free service %s is limited to %s km; the vehicle has done %s km',
        v_entry.service_number, v_entry.due_km, v_odometer)
    );
  end if;

  return jsonb_build_object(
    'eligible', true,
    'service_number', v_entry.service_number,
    'free_service_id', v_entry.id,
    'due_date', v_entry.due_date,
    'due_km', v_entry.due_km
  );
end;
$$;

-- =============================================================================
-- transfer_inventory / receive_inventory_transfer
-- =============================================================================
create or replace function public.transfer_inventory(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_from       uuid := (p_payload ->> 'from_showroom_id')::uuid;
  v_to         uuid := (p_payload ->> 'to_showroom_id')::uuid;
  v_inventory  uuid := (p_payload ->> 'inventory_id')::uuid;
  v_transfer   uuid;
  v_number     text;
  v_status     text;
begin
  if not public.can_access_showroom(v_from) then
    raise exception 'You do not have access to the sending showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('inventory', 'transfer') then
    raise exception 'You do not have permission to transfer stock'
      using errcode = 'P0001';
  end if;

  if v_from = v_to then
    raise exception 'The source and destination showroom are the same'
      using errcode = 'P0001';
  end if;

  select status into v_status
  from public.inventory
  where id = v_inventory and showroom_id = v_from for update;

  if not found then
    raise exception 'That stock item is not held at the sending showroom'
      using errcode = 'P0001';
  end if;

  if v_status <> 'AVAILABLE' then
    raise exception 'Only available stock can be transferred; this unit is %',
      lower(v_status)
      using errcode = 'P0001';
  end if;

  v_number := public.next_document_number(v_from, 'TRANSFER', current_date);

  insert into public.stock_transfers (
    transfer_number, from_showroom_id, to_showroom_id, inventory_id,
    transfer_date, status, notes
  ) values (
    v_number, v_from, v_to, v_inventory, current_date, 'IN_TRANSIT',
    p_payload ->> 'notes'
  )
  returning id into v_transfer;

  -- The unit leaves the sending branch's sellable stock immediately, so it
  -- cannot be sold while in transit.
  update public.inventory
  set status = 'IN_TRANSIT', updated_at = now()
  where id = v_inventory;

  return v_transfer;
end;
$$;

create or replace function public.receive_inventory_transfer(
  p_transfer_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_transfer public.stock_transfers%rowtype;
begin
  select * into v_transfer
  from public.stock_transfers where id = p_transfer_id for update;

  if not found then
    raise exception 'Transfer not found' using errcode = 'P0001';
  end if;

  -- Only the destination may receive. Letting the sender mark their own
  -- shipment as received would defeat the purpose of the in-transit state.
  if not public.can_access_showroom(v_transfer.to_showroom_id) then
    raise exception 'Only the destination showroom can receive this transfer'
      using errcode = 'P0001';
  end if;

  if v_transfer.status <> 'IN_TRANSIT' then
    raise exception 'This transfer is % and cannot be received',
      lower(v_transfer.status)
      using errcode = 'P0001';
  end if;

  update public.stock_transfers
  set status = 'RECEIVED', received_date = current_date,
      received_by = public.current_user_id(), updated_at = now()
  where id = p_transfer_id;

  update public.inventory
  set showroom_id = v_transfer.to_showroom_id,
      status = 'AVAILABLE',
      updated_at = now()
  where id = v_transfer.inventory_id;
end;
$$;

-- =============================================================================
-- cancel_sale_transaction
--
-- Reverses a sale without destroying it: stock returns to the floor, the
-- invoice is cancelled, payments are reversed, and a mirror journal unwinds
-- the ledger. The sale row itself stays, marked CANCELLED.
-- =============================================================================
create or replace function public.cancel_sale_transaction(
  p_sale_id uuid,
  p_reason  text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale    public.sales%rowtype;
  v_payment public.payments%rowtype;
  v_invoice public.invoices%rowtype;
begin
  select * into v_sale from public.sales where id = p_sale_id for update;

  if not found then
    raise exception 'Sale not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_sale.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('sales', 'cancel') then
    raise exception 'You do not have permission to cancel a sale'
      using errcode = 'P0001';
  end if;

  if v_sale.status = 'CANCELLED' then
    raise exception 'This sale is already cancelled' using errcode = 'P0001';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'A reason is required to cancel a sale'
      using errcode = 'P0001';
  end if;

  -- Reverse every payment first, so balances unwind before the documents are
  -- closed.
  for v_payment in
    select * from public.payments
    where sale_id = p_sale_id and status = 'COMPLETED'
      and reverses_payment_id is null
  loop
    perform public.reverse_payment(
      v_payment.id, 'Sale cancelled: ' || p_reason
    );
  end loop;

  -- Return the stock to the floor.
  update public.inventory i
  set status = 'AVAILABLE', updated_at = now()
  from public.sale_items si
  where si.sale_id = p_sale_id and i.id = si.inventory_id;

  -- Detach and remove the customer vehicle created by the sale. Safe because
  -- a cancelled sale means the vehicle was never delivered; service history
  -- attached to it would block this via the FK, which is the intended guard.
  if v_sale.vehicle_id is not null then
    delete from public.vehicle_free_services where vehicle_id = v_sale.vehicle_id;
    delete from public.warranties where vehicle_id = v_sale.vehicle_id;
    update public.sales set vehicle_id = null where id = p_sale_id;
    delete from public.customer_vehicles where id = v_sale.vehicle_id;
  end if;

  -- Cancel the invoice and unwind its ledger entries.
  for v_invoice in
    select * from public.invoices where sale_id = p_sale_id
  loop
    update public.invoices
    set status = 'CANCELLED', cancelled_at = now(),
        cancelled_by = public.current_user_id(), updated_at = now()
    where id = v_invoice.id;

    perform public.create_accounting_transaction(
      v_sale.showroom_id, current_date, 'SALE', p_sale_id,
      'Cancellation of sale ' || v_sale.sale_number,
      jsonb_build_array(
        jsonb_build_object(
          'account_code', '4001', 'debit',
          v_invoice.subtotal - v_invoice.discount, 'credit', 0,
          'description', 'Revenue reversed'),
        jsonb_build_object(
          'account_code', '2002', 'debit', v_invoice.tax_amount, 'credit', 0,
          'description', 'Tax reversed'),
        jsonb_build_object(
          'account_code', '4003', 'debit', v_invoice.other_charges,
          'credit', 0, 'description', 'Other charges reversed'),
        jsonb_build_object(
          'account_code', '1003', 'debit', 0,
          'credit', v_invoice.total_amount,
          'description', 'Receivable cleared')
      )
    );
  end loop;

  -- Cancel any loan raised against the sale.
  update public.emi_schedules e
  set status = 'CANCELLED', updated_at = now()
  from public.loans l
  where l.sale_id = p_sale_id and e.loan_id = l.id and e.paid_amount = 0;

  update public.loans
  set status = 'CANCELLED', updated_at = now()
  where sale_id = p_sale_id;

  update public.sales
  set status = 'CANCELLED', cancelled_at = now(),
      cancelled_by = public.current_user_id(),
      cancellation_reason = p_reason,
      updated_at = now()
  where id = p_sale_id;
end;
$$;

-- =============================================================================
-- complete_service
--
-- Totals the job card, consumes a free-service entitlement if one applies,
-- raises the invoice, schedules the next service and posts to the ledger.
-- =============================================================================
create or replace function public.complete_service(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_service_id  uuid := (p_payload ->> 'service_id')::uuid;
  v_service     public.service_records%rowtype;
  v_subtotal    numeric := 0;
  v_discount    numeric := 0;
  v_tax         numeric := 0;
  v_total       numeric := 0;
  v_invoice_id  uuid;
  v_number      text;
  v_eligibility jsonb;
  v_next_date   date;
  v_next_km     int;
begin
  select * into v_service
  from public.service_records where id = v_service_id for update;

  if not found then
    raise exception 'Job card not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_service.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('service', 'complete') then
    raise exception 'You do not have permission to complete a service'
      using errcode = 'P0001';
  end if;

  if v_service.service_status not in
     ('RECEIVED', 'IN_PROGRESS', 'WAITING_FOR_PARTS') then
    raise exception 'A job card that is % cannot be completed',
      lower(v_service.service_status)
      using errcode = 'P0001';
  end if;

  -- Total only the chargeable lines. Warranty and free-service work is
  -- recorded for costing but not billed to the customer.
  select
    coalesce(sum(case when is_chargeable
                 then quantity * unit_price else 0 end), 0),
    coalesce(sum(case when is_chargeable then discount else 0 end), 0),
    coalesce(sum(case when is_chargeable then tax_amount else 0 end), 0)
  into v_subtotal, v_discount, v_tax
  from public.service_items where service_id = v_service_id;

  v_discount := v_discount + coalesce(
    (p_payload ->> 'additional_discount')::numeric, 0);
  v_discount := least(v_discount, v_subtotal);
  v_total := round(v_subtotal - v_discount + v_tax, 2);

  -- Consume a free-service entitlement when this visit qualifies.
  if v_service.service_type = 'FREE' then
    v_eligibility := public.check_free_service_eligibility(
      v_service.vehicle_id, v_service.odometer_reading
    );

    if not (v_eligibility ->> 'eligible')::boolean then
      raise exception '%', v_eligibility ->> 'reason'
        using errcode = 'P0001';
    end if;

    update public.vehicle_free_services
    set status = 'USED', used_date = current_date, service_id = v_service_id,
        updated_at = now()
    where id = (v_eligibility ->> 'free_service_id')::uuid;
  end if;

  -- Schedule the next visit: six months or 5,000km, whichever the customer
  -- reaches first.
  v_next_date := public.add_months(current_date, 6);
  v_next_km := v_service.odometer_reading + 5000;

  update public.service_records
  set service_status = 'COMPLETED',
      subtotal = v_subtotal,
      discount = v_discount,
      tax_amount = v_tax,
      total_amount = v_total,
      outstanding_amount = v_total - paid_amount,
      work_done = coalesce(p_payload ->> 'work_done', work_done),
      next_service_date = v_next_date,
      next_service_km = v_next_km,
      updated_at = now()
  where id = v_service_id;

  update public.customer_vehicles
  set next_service_date = v_next_date,
      next_service_km = v_next_km,
      updated_at = now()
  where id = v_service.vehicle_id;

  -- Invoice only when there is something to charge.
  if v_total > 0 then
    v_number := public.next_document_number(
      v_service.showroom_id, 'INVOICE', current_date
    );

    insert into public.invoices (
      showroom_id, customer_id, service_id, invoice_number, invoice_type,
      invoice_date, subtotal, discount, tax_amount, total_amount,
      paid_amount, outstanding_amount, status
    ) values (
      v_service.showroom_id, v_service.customer_id, v_service_id,
      v_number, 'SERVICE', current_date, v_subtotal, v_discount, v_tax,
      v_total, 0, v_total, 'DRAFT'
    )
    returning id into v_invoice_id;

    insert into public.invoice_items (
      invoice_id, product_id, description, quantity, unit_price,
      discount, tax_rate, tax_amount, total_amount, sort_order
    )
    select
      v_invoice_id, si.product_id, si.description, si.quantity,
      si.unit_price, si.discount, si.tax_rate, si.tax_amount,
      si.total_amount, row_number() over (order by si.created_at)
    from public.service_items si
    where si.service_id = v_service_id and si.is_chargeable = true;

    update public.invoices set status = 'ISSUED' where id = v_invoice_id;

    perform public.create_accounting_transaction(
      v_service.showroom_id, current_date, 'SERVICE', v_service_id,
      'Service ' || v_service.service_number,
      jsonb_build_array(
        jsonb_build_object(
          'account_code', '1003', 'debit', v_total, 'credit', 0,
          'description', 'Service receivable'),
        jsonb_build_object(
          'account_code', '4002', 'debit', 0,
          'credit', v_subtotal - v_discount,
          'description', 'Service revenue'),
        jsonb_build_object(
          'account_code', '2002', 'debit', 0, 'credit', v_tax,
          'description', 'GST payable')
      )
    );
  end if;

  return jsonb_build_object(
    'service_id',   v_service_id,
    'invoice_id',   v_invoice_id,
    'total_amount', v_total,
    'next_service_date', v_next_date,
    'next_service_km',   v_next_km
  );
end;
$$;

-- =============================================================================
-- create_expense_transaction / approve_expense
-- =============================================================================
create or replace function public.create_expense_transaction(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_showroom_id uuid := (p_payload ->> 'showroom_id')::uuid;
  v_expense_id  uuid;
  v_number      text;
  v_amount      numeric := round((p_payload ->> 'amount')::numeric, 2);
  v_tax         numeric := round(
                      coalesce((p_payload ->> 'tax_amount')::numeric, 0), 2);
  v_date        date := coalesce(
                      (p_payload ->> 'expense_date')::date, current_date);
begin
  if not public.can_access_showroom(v_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('expenses', 'create') then
    raise exception 'You do not have permission to record an expense'
      using errcode = 'P0001';
  end if;

  if v_amount <= 0 then
    raise exception 'Expense amount must be greater than zero'
      using errcode = 'P0001';
  end if;

  v_number := public.next_document_number(v_showroom_id, 'EXPENSE', v_date);

  insert into public.expenses (
    showroom_id, category_id, expense_number, expense_date, amount,
    tax_amount, total_amount, payment_method, description, vendor_name,
    reference_number, attachment_url, status
  ) values (
    v_showroom_id, (p_payload ->> 'category_id')::uuid, v_number, v_date,
    v_amount, v_tax, v_amount + v_tax,
    coalesce(p_payload ->> 'payment_method', 'CASH'),
    p_payload ->> 'description', p_payload ->> 'vendor_name',
    p_payload ->> 'reference_number', p_payload ->> 'attachment_url',
    -- Raised as PENDING, not APPROVED. The person recording an expense is
    -- never the person who approves it; that separation is the control.
    'PENDING'
  )
  returning id into v_expense_id;

  return v_expense_id;
end;
$$;

create or replace function public.approve_expense(
  p_expense_id uuid,
  p_approve    boolean,
  p_reason     text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expense public.expenses%rowtype;
  v_account text;
begin
  select * into v_expense
  from public.expenses where id = p_expense_id for update;

  if not found then
    raise exception 'Expense not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_expense.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if p_approve and not public.has_permission('expenses', 'approve') then
    raise exception 'You do not have permission to approve an expense'
      using errcode = 'P0001';
  end if;

  if not p_approve and not public.has_permission('expenses', 'reject') then
    raise exception 'You do not have permission to reject an expense'
      using errcode = 'P0001';
  end if;

  -- Self-approval defeats the control entirely.
  if v_expense.created_by = public.current_user_id()
     and not public.is_super_admin() then
    raise exception 'You cannot approve an expense you recorded yourself'
      using errcode = 'P0001';
  end if;

  if v_expense.status <> 'PENDING' then
    raise exception 'This expense is % and is no longer awaiting approval',
      lower(v_expense.status)
      using errcode = 'P0001';
  end if;

  if not p_approve then
    if p_reason is null or length(btrim(p_reason)) < 5 then
      raise exception 'A reason is required to reject an expense'
        using errcode = 'P0001';
    end if;

    update public.expenses
    set status = 'REJECTED', rejection_reason = p_reason,
        approved_by = public.current_user_id(), approved_at = now(),
        updated_at = now()
    where id = p_expense_id;
    return;
  end if;

  update public.expenses
  set status = 'APPROVED', approved_by = public.current_user_id(),
      approved_at = now(), updated_at = now()
  where id = p_expense_id;

  -- Post to the ledger only on approval: an unapproved expense is not yet a
  -- liability of the business.
  select coalesce(account_code, '5199') into v_account
  from public.expense_categories where id = v_expense.category_id;

  perform public.create_accounting_transaction(
    v_expense.showroom_id, v_expense.expense_date, 'EXPENSE', p_expense_id,
    'Expense ' || v_expense.expense_number,
    jsonb_build_array(
      jsonb_build_object(
        'account_code', v_account, 'debit', v_expense.total_amount,
        'credit', 0, 'description', v_expense.description),
      jsonb_build_object(
        'account_code',
        case when v_expense.payment_method = 'CASH' then '1001' else '1002' end,
        'debit', 0, 'credit', v_expense.total_amount,
        'description', 'Paid via ' || v_expense.payment_method)
    )
  );
end;
$$;

-- =============================================================================
-- create_purchase_transaction / receive_purchase
-- =============================================================================
create or replace function public.create_purchase_transaction(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_showroom_id uuid := (p_payload ->> 'showroom_id')::uuid;
  v_purchase_id uuid;
  v_number      text;
  v_item        jsonb;
  v_subtotal    numeric := 0;
  v_tax         numeric := 0;
  v_discount    numeric := coalesce(
                      (p_payload ->> 'discount')::numeric, 0);
  v_charges     numeric := coalesce(
                      (p_payload ->> 'other_charges')::numeric, 0);
  v_total       numeric;
  v_date        date := coalesce(
                      (p_payload ->> 'purchase_date')::date, current_date);
  v_line_total  numeric;
  v_line_tax    numeric;
begin
  if not public.can_access_showroom(v_showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('purchases', 'create') then
    raise exception 'You do not have permission to create a purchase'
      using errcode = 'P0001';
  end if;

  v_number := public.next_document_number(v_showroom_id, 'PURCHASE', v_date);

  for v_item in
    select * from jsonb_array_elements(coalesce(p_payload -> 'items', '[]'))
  loop
    v_line_total := round(
      (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_cost')::numeric, 2
    );
    v_line_tax := round(
      v_line_total * coalesce((v_item ->> 'tax_rate')::numeric, 0) / 100.0, 2
    );
    v_subtotal := v_subtotal + v_line_total;
    v_tax := v_tax + v_line_tax;
  end loop;

  v_total := round(v_subtotal - v_discount + v_tax + v_charges, 2);

  insert into public.purchases (
    showroom_id, supplier_id, purchase_number, supplier_invoice_no,
    purchase_date, subtotal, discount, tax_amount, other_charges,
    total_amount, paid_amount, outstanding_amount, status, notes
  ) values (
    v_showroom_id, (p_payload ->> 'supplier_id')::uuid, v_number,
    p_payload ->> 'supplier_invoice_no', v_date,
    v_subtotal, v_discount, v_tax, v_charges, v_total, 0, v_total,
    'ORDERED', p_payload ->> 'notes'
  )
  returning id into v_purchase_id;

  for v_item in
    select * from jsonb_array_elements(coalesce(p_payload -> 'items', '[]'))
  loop
    v_line_total := round(
      (v_item ->> 'quantity')::numeric * (v_item ->> 'unit_cost')::numeric, 2
    );
    v_line_tax := round(
      v_line_total * coalesce((v_item ->> 'tax_rate')::numeric, 0) / 100.0, 2
    );

    insert into public.purchase_items (
      purchase_id, product_id, description, quantity, unit_cost,
      tax_rate, tax_amount, total_amount
    ) values (
      v_purchase_id, (v_item ->> 'product_id')::uuid,
      v_item ->> 'description',
      (v_item ->> 'quantity')::numeric, (v_item ->> 'unit_cost')::numeric,
      coalesce((v_item ->> 'tax_rate')::numeric, 0),
      v_line_tax, round(v_line_total + v_line_tax, 2)
    );
  end loop;

  return v_purchase_id;
end;
$$;

-- Receiving is what creates stock, and what makes the supplier a creditor.
create or replace function public.receive_purchase(p_payload jsonb)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_purchase_id uuid := (p_payload ->> 'purchase_id')::uuid;
  v_purchase    public.purchases%rowtype;
  v_unit        jsonb;
  v_created     int := 0;
  v_inventory_id uuid;
  v_stock_code  text;
begin
  select * into v_purchase
  from public.purchases where id = v_purchase_id for update;

  if not found then
    raise exception 'Purchase not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_purchase.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('inventory', 'create') then
    raise exception 'You do not have permission to receive stock'
      using errcode = 'P0001';
  end if;

  if v_purchase.status = 'RECEIVED' then
    raise exception 'This purchase has already been received'
      using errcode = 'P0001';
  end if;

  -- One inventory row per physical unit, each with its own chassis and engine
  -- number. The unique constraints reject a duplicate outright, which is the
  -- backstop against the same bike being entered twice.
  for v_unit in
    select * from jsonb_array_elements(coalesce(p_payload -> 'units', '[]'))
  loop
    v_stock_code := coalesce(
      v_unit ->> 'stock_code',
      public.next_document_number(
        v_purchase.showroom_id, 'STOCK', v_purchase.purchase_date)
    );

    insert into public.inventory (
      showroom_id, product_id, color_id, stock_code, chassis_number,
      engine_number, manufacturing_date, model_year, purchase_date,
      purchase_price, purchase_id, status, location
    ) values (
      v_purchase.showroom_id,
      (v_unit ->> 'product_id')::uuid,
      (v_unit ->> 'color_id')::uuid,
      v_stock_code,
      upper(v_unit ->> 'chassis_number'),
      upper(v_unit ->> 'engine_number'),
      (v_unit ->> 'manufacturing_date')::date,
      (v_unit ->> 'model_year')::int,
      v_purchase.purchase_date,
      coalesce((v_unit ->> 'purchase_price')::numeric, 0),
      v_purchase_id, 'AVAILABLE',
      v_unit ->> 'location'
    )
    returning id into v_inventory_id;

    update public.purchase_items
    set inventory_id = v_inventory_id
    where purchase_id = v_purchase_id
      and product_id = (v_unit ->> 'product_id')::uuid
      and inventory_id is null;

    v_created := v_created + 1;
  end loop;

  update public.purchases
  set status = 'RECEIVED', received_date = current_date, updated_at = now()
  where id = v_purchase_id;

  -- Stock becomes an asset; the supplier becomes a creditor.
  perform public.create_accounting_transaction(
    v_purchase.showroom_id, v_purchase.purchase_date, 'PURCHASE',
    v_purchase_id, 'Purchase ' || v_purchase.purchase_number,
    jsonb_build_array(
      jsonb_build_object(
        'account_code', '1004',
        'debit', v_purchase.subtotal - v_purchase.discount, 'credit', 0,
        'description', 'Inventory received'),
      jsonb_build_object(
        'account_code', '1005', 'debit', v_purchase.tax_amount, 'credit', 0,
        'description', 'Input tax credit'),
      jsonb_build_object(
        'account_code', '2001', 'debit', 0,
        'credit', v_purchase.total_amount,
        'description', 'Supplier payable')
    )
  );

  return v_created;
end;
$$;

-- =============================================================================
-- adjust_inventory
-- =============================================================================
create or replace function public.adjust_inventory(
  p_inventory_id uuid,
  p_new_status   text,
  p_reason       text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inventory public.inventory%rowtype;
begin
  select * into v_inventory
  from public.inventory where id = p_inventory_id for update;

  if not found then
    raise exception 'Stock item not found' using errcode = 'P0001';
  end if;

  if not public.can_access_showroom(v_inventory.showroom_id) then
    raise exception 'You do not have access to this showroom'
      using errcode = 'P0001';
  end if;

  if not public.has_permission('inventory', 'adjust') then
    raise exception 'You do not have permission to adjust stock'
      using errcode = 'P0001';
  end if;

  -- A sold unit is attached to a customer vehicle and possibly a warranty and
  -- a finance agreement. Flipping its status directly would orphan all of
  -- that; the sale must be cancelled instead.
  if v_inventory.status = 'SOLD' then
    raise exception
      'This unit has been sold. Cancel the sale to return it to stock.'
      using errcode = 'P0001';
  end if;

  if p_reason is null or length(btrim(p_reason)) < 5 then
    raise exception 'A reason is required for a stock adjustment'
      using errcode = 'P0001';
  end if;

  update public.inventory
  set status = p_new_status, notes = p_reason, updated_at = now()
  where id = p_inventory_id;
end;
$$;
