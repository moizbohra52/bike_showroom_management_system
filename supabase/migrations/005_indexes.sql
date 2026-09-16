-- =============================================================================
-- 005_indexes.sql
--
-- Query indexes.
--
-- Three families, each earning its place from a query the application actually
-- issues:
--
--  1. Foreign-key indexes. PostgreSQL does NOT create these automatically, and
--     without them every cascade check and every join from the parent side is
--     a sequential scan.
--  2. Composite indexes led by `showroom_id`. Every RLS policy filters on it,
--     so it is the leading column of virtually every plan; a composite with
--     the next-most-selective column serves list screens directly.
--  3. Trigram indexes for the ILIKE '%term%' searches. A btree cannot serve a
--     leading-wildcard match at all, so these are the difference between an
--     indexed lookup and a full scan on the global search.
--
-- Partial indexes (`where is_deleted = false`) keep the index to the rows the
-- application actually queries, since every list screen excludes soft-deleted
-- rows.
-- =============================================================================

-- =============================================================================
-- Core: users, roles, tenancy
-- =============================================================================
create index if not exists idx_users_showroom on public.users (showroom_id)
  where is_deleted = false;
create index if not exists idx_users_auth_user on public.users (auth_user_id);
create index if not exists idx_users_status
  on public.users (showroom_id, status) where is_deleted = false;
create index if not exists idx_users_email on public.users (lower(email))
  where email is not null;

create index if not exists idx_user_roles_user on public.user_roles (user_id);
create index if not exists idx_user_roles_role on public.user_roles (role_id);
create index if not exists idx_role_permissions_role
  on public.role_permissions (role_id);
create index if not exists idx_role_permissions_permission
  on public.role_permissions (permission_id);
create index if not exists idx_user_showrooms_user
  on public.user_showrooms (user_id);
create index if not exists idx_user_showrooms_showroom
  on public.user_showrooms (showroom_id);

create index if not exists idx_device_tokens_user
  on public.device_tokens (user_id) where is_active = true;

create index if not exists idx_showrooms_status on public.showrooms (status)
  where is_deleted = false;

-- =============================================================================
-- Catalogue
-- =============================================================================
create index if not exists idx_products_brand on public.products (brand_id)
  where is_deleted = false;
create index if not exists idx_products_category
  on public.products (category, status) where is_deleted = false;
create index if not exists idx_products_status on public.products (status)
  where is_deleted = false;
create index if not exists idx_product_colors_product
  on public.product_colors (product_id);
create index if not exists idx_product_images_product
  on public.product_images (product_id, sort_order);

-- =============================================================================
-- Inventory
--
-- The composite (showroom_id, status, product_id) serves the inventory list,
-- the stock-availability check inside create_sale_transaction(), and the
-- low-stock dashboard tile from one index.
-- =============================================================================
create index if not exists idx_inventory_showroom_status_product
  on public.inventory (showroom_id, status, product_id)
  where is_deleted = false;
create index if not exists idx_inventory_product on public.inventory (product_id)
  where is_deleted = false;
create index if not exists idx_inventory_color on public.inventory (color_id);
create index if not exists idx_inventory_purchase
  on public.inventory (purchase_id) where purchase_id is not null;
create index if not exists idx_inventory_purchase_date
  on public.inventory (showroom_id, purchase_date desc)
  where is_deleted = false;
create index if not exists idx_inventory_created
  on public.inventory (showroom_id, created_at desc) where is_deleted = false;

create index if not exists idx_stock_transfers_from
  on public.stock_transfers (from_showroom_id, status);
create index if not exists idx_stock_transfers_to
  on public.stock_transfers (to_showroom_id, status);
create index if not exists idx_stock_transfers_inventory
  on public.stock_transfers (inventory_id);
create index if not exists idx_stock_transfers_date
  on public.stock_transfers (transfer_date desc);

create index if not exists idx_stock_movements_inventory
  on public.stock_movements (inventory_id, created_at desc);
create index if not exists idx_stock_movements_showroom
  on public.stock_movements (showroom_id, created_at desc);
create index if not exists idx_stock_movements_reference
  on public.stock_movements (reference_type, reference_id)
  where reference_id is not null;

-- =============================================================================
-- Customers and vehicles
-- =============================================================================
create index if not exists idx_customers_showroom
  on public.customers (showroom_id, status) where is_deleted = false;
create index if not exists idx_customers_phone on public.customers (phone)
  where is_deleted = false;
create index if not exists idx_customers_email
  on public.customers (lower(email)) where email is not null;
create index if not exists idx_customers_created
  on public.customers (showroom_id, created_at desc) where is_deleted = false;
create index if not exists idx_customers_type
  on public.customers (showroom_id, customer_type) where is_deleted = false;

create index if not exists idx_vehicles_customer
  on public.customer_vehicles (customer_id) where is_deleted = false;
create index if not exists idx_vehicles_showroom
  on public.customer_vehicles (showroom_id, status) where is_deleted = false;
create index if not exists idx_vehicles_product
  on public.customer_vehicles (product_id);
create index if not exists idx_vehicles_inventory
  on public.customer_vehicles (inventory_id) where inventory_id is not null;

-- Service-due and expiry dashboards scan these ranges every time they load.
create index if not exists idx_vehicles_next_service
  on public.customer_vehicles (showroom_id, next_service_date)
  where is_deleted = false and status = 'ACTIVE'
        and next_service_date is not null;
create index if not exists idx_vehicles_insurance_end
  on public.customer_vehicles (showroom_id, insurance_end)
  where is_deleted = false and insurance_end is not null;
create index if not exists idx_vehicles_warranty_end
  on public.customer_vehicles (showroom_id, warranty_end)
  where is_deleted = false and warranty_end is not null;

-- =============================================================================
-- Sales and billing
-- =============================================================================
create index if not exists idx_sales_showroom_date
  on public.sales (showroom_id, sale_date desc);
create index if not exists idx_sales_showroom_status
  on public.sales (showroom_id, status);
create index if not exists idx_sales_customer
  on public.sales (customer_id, sale_date desc);
create index if not exists idx_sales_vehicle on public.sales (vehicle_id);
create index if not exists idx_sales_salesperson
  on public.sales (salesperson_id, sale_date desc)
  where salesperson_id is not null;
create index if not exists idx_sales_created
  on public.sales (showroom_id, created_at desc);
-- Partial: the outstanding-receivables report only ever wants unsettled sales.
create index if not exists idx_sales_outstanding
  on public.sales (showroom_id, outstanding_amount)
  where outstanding_amount > 0 and status <> 'CANCELLED';

create index if not exists idx_sale_items_sale on public.sale_items (sale_id);
create index if not exists idx_sale_items_product
  on public.sale_items (product_id);
create index if not exists idx_sale_items_inventory
  on public.sale_items (inventory_id) where inventory_id is not null;

create index if not exists idx_invoices_showroom_date
  on public.invoices (showroom_id, invoice_date desc);
create index if not exists idx_invoices_showroom_status
  on public.invoices (showroom_id, status);
create index if not exists idx_invoices_customer
  on public.invoices (customer_id, invoice_date desc);
create index if not exists idx_invoices_sale on public.invoices (sale_id)
  where sale_id is not null;
create index if not exists idx_invoices_service
  on public.invoices (service_id) where service_id is not null;
create index if not exists idx_invoices_outstanding
  on public.invoices (showroom_id, outstanding_amount)
  where outstanding_amount > 0 and status <> 'CANCELLED';
create index if not exists idx_invoices_due
  on public.invoices (showroom_id, due_date)
  where due_date is not null and status in ('ISSUED', 'PARTIALLY_PAID');

create index if not exists idx_invoice_items_invoice
  on public.invoice_items (invoice_id, sort_order);

-- =============================================================================
-- Payments
-- =============================================================================
create index if not exists idx_payments_showroom_date
  on public.payments (showroom_id, payment_date desc);
create index if not exists idx_payments_customer
  on public.payments (customer_id, payment_date desc)
  where customer_id is not null;
create index if not exists idx_payments_invoice on public.payments (invoice_id)
  where invoice_id is not null;
create index if not exists idx_payments_sale on public.payments (sale_id)
  where sale_id is not null;
create index if not exists idx_payments_service on public.payments (service_id)
  where service_id is not null;
create index if not exists idx_payments_emi on public.payments (emi_id)
  where emi_id is not null;
create index if not exists idx_payments_purchase
  on public.payments (purchase_id) where purchase_id is not null;
create index if not exists idx_payments_expense
  on public.payments (expense_id) where expense_id is not null;
create index if not exists idx_payments_method
  on public.payments (showroom_id, payment_method, payment_date desc);
create index if not exists idx_payments_status
  on public.payments (showroom_id, status);
create index if not exists idx_payments_reverses
  on public.payments (reverses_payment_id)
  where reverses_payment_id is not null;

-- =============================================================================
-- Finance and EMI
-- =============================================================================
create index if not exists idx_loans_showroom_status
  on public.loans (showroom_id, status);
create index if not exists idx_loans_customer on public.loans (customer_id);
create index if not exists idx_loans_vehicle on public.loans (vehicle_id);
create index if not exists idx_loans_finance_company
  on public.loans (finance_company_id);
create index if not exists idx_loans_sale on public.loans (sale_id)
  where sale_id is not null;

create index if not exists idx_emi_loan
  on public.emi_schedules (loan_id, emi_number);
-- The EMI dashboards (upcoming / due / overdue) all filter status by due_date,
-- and the nightly refresh_emi_statuses() sweep uses exactly this order.
create index if not exists idx_emi_due_date
  on public.emi_schedules (due_date, status);
create index if not exists idx_emi_status_due
  on public.emi_schedules (status, due_date)
  where status in ('UPCOMING', 'DUE', 'PARTIAL', 'OVERDUE');

-- =============================================================================
-- Purchases and expenses
-- =============================================================================
create index if not exists idx_purchases_showroom_date
  on public.purchases (showroom_id, purchase_date desc);
create index if not exists idx_purchases_supplier
  on public.purchases (supplier_id, purchase_date desc);
create index if not exists idx_purchases_status
  on public.purchases (showroom_id, status);
create index if not exists idx_purchases_outstanding
  on public.purchases (showroom_id, outstanding_amount)
  where outstanding_amount > 0 and status <> 'CANCELLED';

create index if not exists idx_purchase_items_purchase
  on public.purchase_items (purchase_id);
create index if not exists idx_purchase_items_product
  on public.purchase_items (product_id);
create index if not exists idx_purchase_items_inventory
  on public.purchase_items (inventory_id) where inventory_id is not null;

create index if not exists idx_expenses_showroom_date
  on public.expenses (showroom_id, expense_date desc);
create index if not exists idx_expenses_category
  on public.expenses (category_id, expense_date desc);
create index if not exists idx_expenses_status
  on public.expenses (showroom_id, status);
-- The approvals queue: pending expenses, oldest first.
create index if not exists idx_expenses_pending
  on public.expenses (showroom_id, created_at)
  where status = 'PENDING';

-- =============================================================================
-- Service
-- =============================================================================
create index if not exists idx_service_showroom_date
  on public.service_records (showroom_id, service_date desc);
create index if not exists idx_service_showroom_status
  on public.service_records (showroom_id, service_status);
create index if not exists idx_service_customer
  on public.service_records (customer_id, service_date desc);
create index if not exists idx_service_vehicle
  on public.service_records (vehicle_id, service_date desc);
create index if not exists idx_service_advisor
  on public.service_records (service_advisor_id, service_date desc)
  where service_advisor_id is not null;
create index if not exists idx_service_technician
  on public.service_records (technician_id, service_date desc)
  where technician_id is not null;
-- The workshop board: everything currently open, which is a small slice of a
-- large table, so a partial index keeps it tiny and hot.
create index if not exists idx_service_open
  on public.service_records (showroom_id, service_date)
  where service_status in
    ('BOOKED', 'RECEIVED', 'IN_PROGRESS', 'WAITING_FOR_PARTS');
create index if not exists idx_service_outstanding
  on public.service_records (showroom_id, outstanding_amount)
  where outstanding_amount > 0 and service_status <> 'CANCELLED';

create index if not exists idx_service_items_service
  on public.service_items (service_id);
create index if not exists idx_service_items_product
  on public.service_items (product_id) where product_id is not null;

create index if not exists idx_free_service_plans_product
  on public.free_service_plans (product_id, service_number);
create index if not exists idx_vehicle_free_services_vehicle
  on public.vehicle_free_services (vehicle_id, service_number);
create index if not exists idx_vehicle_free_services_due
  on public.vehicle_free_services (showroom_id, due_date, status)
  where status in ('UPCOMING', 'DUE');

-- =============================================================================
-- Warranty and insurance
-- =============================================================================
create index if not exists idx_warranties_vehicle
  on public.warranties (vehicle_id);
create index if not exists idx_warranties_expiry
  on public.warranties (showroom_id, end_date, status);
create index if not exists idx_warranty_claims_warranty
  on public.warranty_claims (warranty_id);
create index if not exists idx_warranty_claims_service
  on public.warranty_claims (service_id) where service_id is not null;
create index if not exists idx_warranty_claims_status
  on public.warranty_claims (showroom_id, status);

create index if not exists idx_insurance_vehicle
  on public.insurance_policies (vehicle_id);
create index if not exists idx_insurance_expiry
  on public.insurance_policies (showroom_id, expiry_date, status);

-- =============================================================================
-- Reminders and notifications
-- =============================================================================
create index if not exists idx_reminders_showroom_date
  on public.reminders (showroom_id, reminder_date, status);
create index if not exists idx_reminders_customer
  on public.reminders (customer_id) where customer_id is not null;
create index if not exists idx_reminders_vehicle
  on public.reminders (vehicle_id) where vehicle_id is not null;
-- The dispatcher's working set: due and not yet sent.
create index if not exists idx_reminders_pending
  on public.reminders (reminder_date, priority)
  where status = 'PENDING';
create index if not exists idx_reminders_reference
  on public.reminders (reference_type, reference_id)
  where reference_id is not null;

create index if not exists idx_notifications_user
  on public.notifications (user_id, created_at desc)
  where user_id is not null;
-- Powers the unread badge count without scanning read history.
create index if not exists idx_notifications_unread
  on public.notifications (user_id, created_at desc)
  where is_read = false and user_id is not null;
create index if not exists idx_notifications_customer
  on public.notifications (customer_id, created_at desc)
  where customer_id is not null;

-- =============================================================================
-- Accounting
-- =============================================================================
create index if not exists idx_accounts_showroom
  on public.accounts (showroom_id, account_type, account_code);
create index if not exists idx_accounts_parent
  on public.accounts (parent_account_id) where parent_account_id is not null;

create index if not exists idx_acct_tx_showroom_date
  on public.accounting_transactions (showroom_id, transaction_date desc);
create index if not exists idx_acct_tx_reference
  on public.accounting_transactions (reference_type, reference_id)
  where reference_id is not null;
create index if not exists idx_acct_tx_reverses
  on public.accounting_transactions (reverses_transaction_id)
  where reverses_transaction_id is not null;

create index if not exists idx_acct_entries_transaction
  on public.accounting_entries (transaction_id);
-- The trial balance and P&L aggregate by account; including debit and credit
-- makes those index-only scans.
create index if not exists idx_acct_entries_account
  on public.accounting_entries (account_id) include (debit, credit);

-- =============================================================================
-- System tables
-- =============================================================================
create index if not exists idx_attachments_entity
  on public.attachments (entity_type, entity_id) where is_deleted = false;
create index if not exists idx_attachments_showroom
  on public.attachments (showroom_id, created_at desc)
  where is_deleted = false;

create index if not exists idx_audit_showroom_created
  on public.audit_logs (showroom_id, created_at desc);
create index if not exists idx_audit_user
  on public.audit_logs (user_id, created_at desc);
create index if not exists idx_audit_record
  on public.audit_logs (table_name, record_id, created_at desc);
create index if not exists idx_audit_action
  on public.audit_logs (action, created_at desc);

create index if not exists idx_document_sequences_lookup
  on public.document_sequences (showroom_id, document_type, financial_year);

-- =============================================================================
-- Trigram indexes for search
--
-- Required for the leading-wildcard ILIKE searches the list screens and
-- global_search() issue. A btree index cannot serve '%term%' at all.
-- =============================================================================
create index if not exists idx_customers_name_trgm
  on public.customers using gin (name extensions.gin_trgm_ops);
create index if not exists idx_customers_phone_trgm
  on public.customers using gin (phone extensions.gin_trgm_ops);
create index if not exists idx_customers_code_trgm
  on public.customers using gin (customer_code extensions.gin_trgm_ops);

create index if not exists idx_products_name_trgm
  on public.products using gin (name extensions.gin_trgm_ops);
create index if not exists idx_products_model_trgm
  on public.products using gin (model extensions.gin_trgm_ops);

create index if not exists idx_inventory_chassis_trgm
  on public.inventory using gin (chassis_number extensions.gin_trgm_ops);
create index if not exists idx_inventory_engine_trgm
  on public.inventory using gin (engine_number extensions.gin_trgm_ops);
create index if not exists idx_inventory_stock_code_trgm
  on public.inventory using gin (stock_code extensions.gin_trgm_ops);

create index if not exists idx_vehicles_registration_trgm
  on public.customer_vehicles
  using gin (registration_number extensions.gin_trgm_ops);
create index if not exists idx_vehicles_chassis_trgm
  on public.customer_vehicles
  using gin (chassis_number extensions.gin_trgm_ops);

create index if not exists idx_sales_number_trgm
  on public.sales using gin (sale_number extensions.gin_trgm_ops);
create index if not exists idx_invoices_number_trgm
  on public.invoices using gin (invoice_number extensions.gin_trgm_ops);
create index if not exists idx_payments_number_trgm
  on public.payments using gin (payment_number extensions.gin_trgm_ops);
create index if not exists idx_service_number_trgm
  on public.service_records using gin (service_number extensions.gin_trgm_ops);
create index if not exists idx_loans_number_trgm
  on public.loans using gin (loan_number extensions.gin_trgm_ops);
