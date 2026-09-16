-- =============================================================================
-- 017_fix_purchase_receipt_balance.sql
--
-- Fixes an unbalanced posting in `receive_purchase`.
--
-- -----------------------------------------------------------------------------
-- The defect
-- -----------------------------------------------------------------------------
-- The receipt posting debited inventory and input tax credit, then credited the
-- supplier with the purchase's FULL total:
--
--   debit  1004  subtotal - discount
--   debit  1005  tax_amount
--   credit 2001  total_amount          -- = subtotal - discount + tax + other
--
-- `other_charges` therefore appeared on the credit side and nowhere on the
-- debit side. Any purchase raised with freight or handling charges could not be
-- received at all: `assert_ledger_balanced` correctly refused the transaction,
-- and the whole `receive_purchase` call rolled back with
--
--   Accounting entry is not balanced: debits 192000.00, credits 194000.00
--
-- A purchase with no other charges balanced by coincidence, which is why this
-- survived until a consignment with freight was actually received.
--
-- -----------------------------------------------------------------------------
-- Why the charges are expensed rather than capitalised
-- -----------------------------------------------------------------------------
-- Freight on goods for resale can legitimately be capitalised into the cost of
-- inventory. It is NOT capitalised here, deliberately.
--
-- `inventory.purchase_price` holds the per-unit cost that cost of goods sold is
-- derived from when the machine is sold. Account 1004 must therefore equal the
-- sum of those per-unit costs, or the asset account and the stock ledger drift
-- apart permanently and no stock valuation reconciles. Adding freight to 1004
-- without also spreading it across every unit's `purchase_price` would do
-- exactly that — and spreading it introduces a rounding remainder on every
-- consignment that does not divide evenly.
--
-- So the charges go to 5104 Transport Expense, which is where a dealership
-- books inward freight, and 1004 continues to mean precisely "what the machines
-- in stock cost".
-- =============================================================================

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
  v_inventory_id uuid;
  v_stock_code  text;
  v_created     integer := 0;
  v_entries     jsonb;
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
  --
  -- Built incrementally so a zero line is omitted entirely rather than posted
  -- as a nil entry: a journal cluttered with zero-value lines is harder to
  -- read, and `create_accounting_transaction` has no reason to store them.
  v_entries := jsonb_build_array(
    jsonb_build_object(
      'account_code', '1004',
      'debit', v_purchase.subtotal - v_purchase.discount, 'credit', 0,
      'description', 'Inventory received')
  );

  if coalesce(v_purchase.tax_amount, 0) > 0 then
    v_entries := v_entries || jsonb_build_array(jsonb_build_object(
      'account_code', '1005', 'debit', v_purchase.tax_amount, 'credit', 0,
      'description', 'Input tax credit'));
  end if;

  -- The line that was missing. Without it the credit to 2001 exceeded the
  -- debits by exactly `other_charges`.
  if coalesce(v_purchase.other_charges, 0) > 0 then
    v_entries := v_entries || jsonb_build_array(jsonb_build_object(
      'account_code', '5104', 'debit', v_purchase.other_charges, 'credit', 0,
      'description', 'Inward freight and handling'));
  end if;

  v_entries := v_entries || jsonb_build_array(jsonb_build_object(
    'account_code', '2001', 'debit', 0,
    'credit', v_purchase.total_amount,
    'description', 'Supplier payable'));

  perform public.create_accounting_transaction(
    v_purchase.showroom_id, v_purchase.purchase_date, 'PURCHASE',
    v_purchase_id, 'Purchase ' || v_purchase.purchase_number,
    v_entries
  );

  return v_created;
end;
$$;

comment on function public.receive_purchase(jsonb) is
  'Takes a consignment into stock, one inventory row per machine, and posts '
  'the receipt. Other charges are expensed to 5104 rather than capitalised, '
  'so account 1004 stays equal to the sum of per-unit purchase prices.';
