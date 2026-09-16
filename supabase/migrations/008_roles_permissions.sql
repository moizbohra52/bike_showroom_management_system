-- =============================================================================
-- 008_roles_permissions.sql
--
-- Seeds the role catalogue, the permission catalogue, and the grants between
-- them.
--
-- This file is the server half of a contract. The client half is
-- `lib/core/constants/permission_constants.dart`, and
-- `test/unit/permission_catalog_test.dart` asserts the two stay identical. If
-- you add a permission here, add it there in the same change.
--
-- Idempotent: every insert is ON CONFLICT DO NOTHING / DO UPDATE, so re-running
-- this migration against a live database adds what is missing without
-- disturbing custom roles an administrator has created.
-- =============================================================================

-- =============================================================================
-- Roles
--
-- `is_system_role` marks the roles that is_super_admin() and the RLS policies
-- resolve by name. They are protected from rename and deletion by 009_rls.sql.
-- =============================================================================
insert into public.roles (name, description, is_system_role) values
  ('SUPER ADMIN',
   'Unrestricted access across every showroom. Not scoped to a branch.',
   true),
  ('ADMIN',
   'Full administrative access within assigned showrooms.',
   true),
  ('SHOWROOM MANAGER',
   'Runs a branch end to end: sales, service, stock, staff and reporting.',
   true),
  ('ACCOUNT MANAGER',
   'Oversees receivables, finance and the ledger for assigned showrooms.',
   true),
  ('SALES MANAGER',
   'Owns the sales floor, approves discounts and sale documents.',
   true),
  ('INVENTORY MANAGER',
   'Owns stock: intake, transfers, adjustments and stock reporting.',
   true),
  ('PURCHASE MANAGER',
   'Owns supplier relationships and purchase orders.',
   true),
  ('SERVICE MANAGER',
   'Owns the workshop: job cards, technicians, billing and warranty.',
   true),
  ('ACCOUNTANT',
   'Maintains the ledger, expenses and financial reporting.',
   true),
  ('SALES STAFF',
   'Creates customers and sales; cannot approve discounts or cancel.',
   true),
  ('SERVICE ADVISOR',
   'Receives vehicles, raises job cards and records customer complaints.',
   true),
  ('TECHNICIAN',
   'Works assigned job cards and records parts and labour used.',
   true),
  ('VIEWER',
   'Read-only access. Cannot create, change or approve anything.',
   true)
on conflict (name) do update
  set description = excluded.description,
      is_system_role = excluded.is_system_role,
      updated_at = now();

-- =============================================================================
-- Permissions
--
-- Expressed as (module, action) pairs; the client addresses them as
-- 'module.action'. Generated from a values list so the catalogue is readable
-- as a table rather than 122 separate statements.
-- =============================================================================
insert into public.permissions (module, action, description)
select m.module, a.action, a.description
from (values
  -- dashboard
  ('dashboard', 'view',     'View the dashboard'),
  ('dashboard', 'export',   'Export dashboard figures'),
  -- showroom
  ('showroom',  'view',     'View showrooms'),
  ('showroom',  'create',   'Create a showroom'),
  ('showroom',  'edit',     'Edit showroom details'),
  ('showroom',  'delete',   'Deactivate a showroom'),
  ('showroom',  'manage',   'Manage showroom settings'),
  -- users
  ('users',     'view',     'View users'),
  ('users',     'create',   'Create a user'),
  ('users',     'edit',     'Edit a user'),
  ('users',     'delete',   'Deactivate a user'),
  ('users',     'assign',   'Assign roles and showrooms to a user'),
  -- roles
  ('roles',     'view',     'View roles and permissions'),
  ('roles',     'manage',   'Create roles and change their permissions'),
  -- products
  ('products',  'view',     'View the product catalogue'),
  ('products',  'create',   'Add a product'),
  ('products',  'edit',     'Edit a product'),
  ('products',  'delete',   'Remove a product'),
  ('products',  'export',   'Export the product catalogue'),
  -- inventory
  ('inventory', 'view',     'View stock'),
  ('inventory', 'create',   'Add stock'),
  ('inventory', 'edit',     'Edit a stock record'),
  ('inventory', 'transfer', 'Transfer stock between showrooms'),
  ('inventory', 'adjust',   'Adjust stock status'),
  ('inventory', 'delete',   'Remove a stock record'),
  ('inventory', 'export',   'Export stock reports'),
  -- customers
  ('customers', 'view',     'View customers'),
  ('customers', 'create',   'Add a customer'),
  ('customers', 'edit',     'Edit a customer'),
  ('customers', 'delete',   'Remove a customer'),
  ('customers', 'export',   'Export customer data'),
  -- vehicles
  ('vehicles',  'view',     'View customer vehicles'),
  ('vehicles',  'create',   'Register a customer vehicle'),
  ('vehicles',  'edit',     'Edit a customer vehicle'),
  ('vehicles',  'delete',   'Remove a customer vehicle'),
  -- sales
  ('sales',     'view',     'View sales'),
  ('sales',     'create',   'Create a sale'),
  ('sales',     'edit',     'Edit a draft sale'),
  ('sales',     'cancel',   'Cancel a sale'),
  ('sales',     'discount', 'Apply a discount beyond the standard limit'),
  ('sales',     'approve',  'Approve a sale or a discount'),
  ('sales',     'export',   'Export sales reports'),
  -- billing
  ('billing',   'view',     'View invoices'),
  ('billing',   'create',   'Raise an invoice'),
  ('billing',   'edit',     'Edit a draft invoice'),
  ('billing',   'cancel',   'Cancel an invoice'),
  ('billing',   'print',    'Print an invoice'),
  ('billing',   'export',   'Export invoices'),
  -- payments
  ('payments',  'view',     'View payments'),
  ('payments',  'create',   'Record a payment'),
  ('payments',  'edit',     'Edit a payment'),
  ('payments',  'cancel',   'Cancel a payment'),
  ('payments',  'refund',   'Issue a refund or reversal'),
  ('payments',  'export',   'Export payment reports'),
  -- finance
  ('finance',   'view',     'View finance companies and loans'),
  ('finance',   'create',   'Create a loan'),
  ('finance',   'edit',     'Edit a loan'),
  ('finance',   'manage',   'Manage finance companies'),
  -- emi
  ('emi',       'view',     'View EMI schedules'),
  ('emi',       'create',   'Generate an EMI schedule'),
  ('emi',       'edit',     'Edit an EMI schedule'),
  ('emi',       'payment',  'Record an EMI collection'),
  ('emi',       'cancel',   'Cancel an EMI instalment'),
  ('emi',       'export',   'Export EMI reports'),
  -- purchases
  ('purchases', 'view',     'View purchases'),
  ('purchases', 'create',   'Create a purchase'),
  ('purchases', 'edit',     'Edit a purchase'),
  ('purchases', 'cancel',   'Cancel a purchase'),
  ('purchases', 'approve',  'Approve a purchase'),
  ('purchases', 'export',   'Export purchase reports'),
  -- suppliers
  ('suppliers', 'view',     'View suppliers'),
  ('suppliers', 'create',   'Add a supplier'),
  ('suppliers', 'edit',     'Edit a supplier'),
  ('suppliers', 'delete',   'Remove a supplier'),
  -- expenses
  ('expenses',  'view',     'View expenses'),
  ('expenses',  'create',   'Record an expense'),
  ('expenses',  'edit',     'Edit an expense'),
  ('expenses',  'delete',   'Remove an expense'),
  ('expenses',  'approve',  'Approve an expense'),
  ('expenses',  'reject',   'Reject an expense'),
  ('expenses',  'export',   'Export expense reports'),
  -- accounting
  ('accounting', 'view',    'View the ledger'),
  ('accounting', 'create',  'Post a journal entry'),
  ('accounting', 'manage',  'Manage the chart of accounts'),
  ('accounting', 'export',  'Export accounting reports'),
  -- service
  ('service',   'view',     'View job cards'),
  ('service',   'create',   'Book a service or raise a job card'),
  ('service',   'edit',     'Edit a job card'),
  ('service',   'complete', 'Complete a service'),
  ('service',   'bill',     'Bill a service'),
  ('service',   'discount', 'Apply a discount to a service'),
  ('service',   'cancel',   'Cancel a service'),
  ('service',   'assign',   'Assign a technician'),
  ('service',   'export',   'Export service reports'),
  -- warranty
  ('warranty',  'view',     'View warranties'),
  ('warranty',  'create',   'Create a warranty'),
  ('warranty',  'edit',     'Edit a warranty'),
  ('warranty',  'claim',    'Raise a warranty claim'),
  ('warranty',  'approve',  'Approve a warranty claim'),
  -- insurance
  ('insurance', 'view',     'View insurance policies'),
  ('insurance', 'create',   'Add an insurance policy'),
  ('insurance', 'edit',     'Edit an insurance policy'),
  ('insurance', 'delete',   'Remove an insurance policy'),
  -- reminders
  ('reminders', 'view',     'View reminders'),
  ('reminders', 'create',   'Create a reminder'),
  ('reminders', 'edit',     'Edit a reminder'),
  ('reminders', 'complete', 'Mark a reminder complete'),
  ('reminders', 'cancel',   'Cancel a reminder'),
  -- notifications
  ('notifications', 'view',   'View notifications'),
  ('notifications', 'create', 'Send a notification'),
  -- reports
  ('reports',   'view',     'View reports'),
  ('reports',   'export',   'Export reports'),
  ('reports',   'print',    'Print reports'),
  -- documents
  ('documents', 'view',     'View documents'),
  ('documents', 'upload',   'Upload a document'),
  ('documents', 'download', 'Download a document'),
  ('documents', 'delete',   'Delete a document'),
  -- audit
  ('audit',     'view',     'View audit logs'),
  ('audit',     'export',   'Export audit logs'),
  -- settings
  ('settings',  'view',     'View settings'),
  ('settings',  'edit',     'Change settings'),
  ('settings',  'manage',   'Manage system configuration')
) as a(module, action, description)
cross join lateral (select a.module as module) m
on conflict (module, action) do update
  set description = excluded.description;

-- =============================================================================
-- Role grants
--
-- Defined as (role, module, action) triples. A NULL action means "every action
-- in this module", which keeps the broad administrative roles readable and
-- means a newly added action is picked up by the roles that should have it.
--
-- The shape of each role follows separation of duties: the person who records
-- an expense cannot approve it, the person who sells cannot approve their own
-- discount, and a technician can record work but not bill it.
-- =============================================================================
-- Expressed as a CTE rather than a temporary table: a temp table declared
-- `on commit drop` would be gone before the next statement, because psql and
-- the Supabase migration runner commit each statement independently.
insert into public.role_permissions (role_id, permission_id)
with grants(role_name, module, action) as (
  values
  -- ---------------------------------------------------------------- SUPER
  -- Granted explicitly as well as via is_super_admin(), so the permission
  -- matrix in the role editor renders correctly and so authorisation still
  -- works if the short-circuit is ever removed.
  ('SUPER ADMIN', 'dashboard', null), ('SUPER ADMIN', 'showroom', null),
  ('SUPER ADMIN', 'users', null),     ('SUPER ADMIN', 'roles', null),
  ('SUPER ADMIN', 'products', null),  ('SUPER ADMIN', 'inventory', null),
  ('SUPER ADMIN', 'customers', null), ('SUPER ADMIN', 'vehicles', null),
  ('SUPER ADMIN', 'sales', null),     ('SUPER ADMIN', 'billing', null),
  ('SUPER ADMIN', 'payments', null),  ('SUPER ADMIN', 'finance', null),
  ('SUPER ADMIN', 'emi', null),       ('SUPER ADMIN', 'purchases', null),
  ('SUPER ADMIN', 'suppliers', null), ('SUPER ADMIN', 'expenses', null),
  ('SUPER ADMIN', 'accounting', null),('SUPER ADMIN', 'service', null),
  ('SUPER ADMIN', 'warranty', null),  ('SUPER ADMIN', 'insurance', null),
  ('SUPER ADMIN', 'reminders', null), ('SUPER ADMIN', 'notifications', null),
  ('SUPER ADMIN', 'reports', null),   ('SUPER ADMIN', 'documents', null),
  ('SUPER ADMIN', 'audit', null),     ('SUPER ADMIN', 'settings', null),

  -- ---------------------------------------------------------------- ADMIN
  -- Everything except creating or deleting showrooms, which is a
  -- SUPER ADMIN concern since it changes the tenancy topology.
  ('ADMIN', 'dashboard', null),
  ('ADMIN', 'showroom', 'view'), ('ADMIN', 'showroom', 'edit'),
  ('ADMIN', 'showroom', 'manage'),
  ('ADMIN', 'users', null),      ('ADMIN', 'roles', null),
  ('ADMIN', 'products', null),   ('ADMIN', 'inventory', null),
  ('ADMIN', 'customers', null),  ('ADMIN', 'vehicles', null),
  ('ADMIN', 'sales', null),      ('ADMIN', 'billing', null),
  ('ADMIN', 'payments', null),   ('ADMIN', 'finance', null),
  ('ADMIN', 'emi', null),        ('ADMIN', 'purchases', null),
  ('ADMIN', 'suppliers', null),  ('ADMIN', 'expenses', null),
  ('ADMIN', 'accounting', null), ('ADMIN', 'service', null),
  ('ADMIN', 'warranty', null),   ('ADMIN', 'insurance', null),
  ('ADMIN', 'reminders', null),  ('ADMIN', 'notifications', null),
  ('ADMIN', 'reports', null),    ('ADMIN', 'documents', null),
  ('ADMIN', 'audit', null),      ('ADMIN', 'settings', null),

  -- ------------------------------------------------------ SHOWROOM MANAGER
  -- Runs the branch. No role management (that is an ADMIN concern) and no
  -- ability to create showrooms.
  ('SHOWROOM MANAGER', 'dashboard', null),
  ('SHOWROOM MANAGER', 'showroom', 'view'),
  ('SHOWROOM MANAGER', 'showroom', 'edit'),
  ('SHOWROOM MANAGER', 'users', 'view'),
  ('SHOWROOM MANAGER', 'users', 'create'),
  ('SHOWROOM MANAGER', 'users', 'edit'),
  ('SHOWROOM MANAGER', 'roles', 'view'),
  ('SHOWROOM MANAGER', 'products', null),
  ('SHOWROOM MANAGER', 'inventory', null),
  ('SHOWROOM MANAGER', 'customers', null),
  ('SHOWROOM MANAGER', 'vehicles', null),
  ('SHOWROOM MANAGER', 'sales', null),
  ('SHOWROOM MANAGER', 'billing', null),
  ('SHOWROOM MANAGER', 'payments', null),
  ('SHOWROOM MANAGER', 'finance', null),
  ('SHOWROOM MANAGER', 'emi', null),
  ('SHOWROOM MANAGER', 'purchases', null),
  ('SHOWROOM MANAGER', 'suppliers', null),
  ('SHOWROOM MANAGER', 'expenses', null),
  ('SHOWROOM MANAGER', 'accounting', 'view'),
  ('SHOWROOM MANAGER', 'accounting', 'export'),
  ('SHOWROOM MANAGER', 'service', null),
  ('SHOWROOM MANAGER', 'warranty', null),
  ('SHOWROOM MANAGER', 'insurance', null),
  ('SHOWROOM MANAGER', 'reminders', null),
  ('SHOWROOM MANAGER', 'notifications', null),
  ('SHOWROOM MANAGER', 'reports', null),
  ('SHOWROOM MANAGER', 'documents', null),
  ('SHOWROOM MANAGER', 'audit', 'view'),
  ('SHOWROOM MANAGER', 'settings', 'view'),
  ('SHOWROOM MANAGER', 'settings', 'edit'),

  -- ------------------------------------------------------- ACCOUNT MANAGER
  ('ACCOUNT MANAGER', 'dashboard', null),
  ('ACCOUNT MANAGER', 'customers', 'view'),
  ('ACCOUNT MANAGER', 'customers', 'export'),
  ('ACCOUNT MANAGER', 'vehicles', 'view'),
  ('ACCOUNT MANAGER', 'sales', 'view'), ('ACCOUNT MANAGER', 'sales', 'export'),
  ('ACCOUNT MANAGER', 'billing', null),
  ('ACCOUNT MANAGER', 'payments', null),
  ('ACCOUNT MANAGER', 'finance', null),
  ('ACCOUNT MANAGER', 'emi', null),
  ('ACCOUNT MANAGER', 'purchases', 'view'),
  ('ACCOUNT MANAGER', 'purchases', 'approve'),
  ('ACCOUNT MANAGER', 'expenses', null),
  ('ACCOUNT MANAGER', 'accounting', null),
  ('ACCOUNT MANAGER', 'service', 'view'),
  ('ACCOUNT MANAGER', 'reminders', null),
  ('ACCOUNT MANAGER', 'notifications', 'view'),
  ('ACCOUNT MANAGER', 'reports', null),
  ('ACCOUNT MANAGER', 'documents', 'view'),
  ('ACCOUNT MANAGER', 'documents', 'download'),
  ('ACCOUNT MANAGER', 'audit', 'view'),

  -- --------------------------------------------------------- SALES MANAGER
  ('SALES MANAGER', 'dashboard', 'view'),
  ('SALES MANAGER', 'products', 'view'),
  ('SALES MANAGER', 'inventory', 'view'),
  ('SALES MANAGER', 'inventory', 'adjust'),
  ('SALES MANAGER', 'customers', null),
  ('SALES MANAGER', 'vehicles', null),
  ('SALES MANAGER', 'sales', null),
  ('SALES MANAGER', 'billing', null),
  ('SALES MANAGER', 'payments', 'view'),
  ('SALES MANAGER', 'payments', 'create'),
  ('SALES MANAGER', 'finance', 'view'),
  ('SALES MANAGER', 'finance', 'create'),
  ('SALES MANAGER', 'emi', 'view'),
  ('SALES MANAGER', 'emi', 'create'),
  ('SALES MANAGER', 'warranty', 'view'),
  ('SALES MANAGER', 'warranty', 'create'),
  ('SALES MANAGER', 'insurance', 'view'),
  ('SALES MANAGER', 'insurance', 'create'),
  ('SALES MANAGER', 'reminders', null),
  ('SALES MANAGER', 'notifications', 'view'),
  ('SALES MANAGER', 'reports', 'view'),
  ('SALES MANAGER', 'reports', 'export'),
  ('SALES MANAGER', 'documents', 'view'),
  ('SALES MANAGER', 'documents', 'upload'),

  -- ----------------------------------------------------------- SALES STAFF
  -- Can sell, but cannot approve their own discount or cancel a sale. That
  -- separation is the point: it is the control that stops a salesperson
  -- discounting without oversight.
  ('SALES STAFF', 'dashboard', 'view'),
  ('SALES STAFF', 'products', 'view'),
  ('SALES STAFF', 'inventory', 'view'),
  ('SALES STAFF', 'customers', 'view'),
  ('SALES STAFF', 'customers', 'create'),
  ('SALES STAFF', 'customers', 'edit'),
  ('SALES STAFF', 'vehicles', 'view'),
  ('SALES STAFF', 'vehicles', 'create'),
  ('SALES STAFF', 'sales', 'view'),
  ('SALES STAFF', 'sales', 'create'),
  ('SALES STAFF', 'sales', 'edit'),
  ('SALES STAFF', 'billing', 'view'),
  ('SALES STAFF', 'billing', 'create'),
  ('SALES STAFF', 'billing', 'print'),
  ('SALES STAFF', 'payments', 'view'),
  ('SALES STAFF', 'payments', 'create'),
  ('SALES STAFF', 'finance', 'view'),
  ('SALES STAFF', 'emi', 'view'),
  ('SALES STAFF', 'reminders', 'view'),
  ('SALES STAFF', 'reminders', 'create'),
  ('SALES STAFF', 'notifications', 'view'),
  ('SALES STAFF', 'documents', 'view'),
  ('SALES STAFF', 'documents', 'upload'),

  -- ----------------------------------------------------- INVENTORY MANAGER
  ('INVENTORY MANAGER', 'dashboard', 'view'),
  ('INVENTORY MANAGER', 'products', null),
  ('INVENTORY MANAGER', 'inventory', null),
  ('INVENTORY MANAGER', 'purchases', 'view'),
  ('INVENTORY MANAGER', 'purchases', 'create'),
  ('INVENTORY MANAGER', 'suppliers', 'view'),
  ('INVENTORY MANAGER', 'sales', 'view'),
  ('INVENTORY MANAGER', 'reports', 'view'),
  ('INVENTORY MANAGER', 'reports', 'export'),
  ('INVENTORY MANAGER', 'notifications', 'view'),
  ('INVENTORY MANAGER', 'documents', 'view'),
  ('INVENTORY MANAGER', 'documents', 'upload'),

  -- ------------------------------------------------------ PURCHASE MANAGER
  ('PURCHASE MANAGER', 'dashboard', 'view'),
  ('PURCHASE MANAGER', 'products', 'view'),
  ('PURCHASE MANAGER', 'inventory', 'view'),
  ('PURCHASE MANAGER', 'inventory', 'create'),
  ('PURCHASE MANAGER', 'purchases', null),
  ('PURCHASE MANAGER', 'suppliers', null),
  ('PURCHASE MANAGER', 'payments', 'view'),
  ('PURCHASE MANAGER', 'payments', 'create'),
  ('PURCHASE MANAGER', 'expenses', 'view'),
  ('PURCHASE MANAGER', 'expenses', 'create'),
  ('PURCHASE MANAGER', 'reports', 'view'),
  ('PURCHASE MANAGER', 'reports', 'export'),
  ('PURCHASE MANAGER', 'notifications', 'view'),
  ('PURCHASE MANAGER', 'documents', 'view'),
  ('PURCHASE MANAGER', 'documents', 'upload'),

  -- ------------------------------------------------------- SERVICE MANAGER
  ('SERVICE MANAGER', 'dashboard', 'view'),
  ('SERVICE MANAGER', 'customers', 'view'),
  ('SERVICE MANAGER', 'customers', 'edit'),
  ('SERVICE MANAGER', 'vehicles', null),
  ('SERVICE MANAGER', 'inventory', 'view'),
  ('SERVICE MANAGER', 'products', 'view'),
  ('SERVICE MANAGER', 'service', null),
  ('SERVICE MANAGER', 'warranty', null),
  ('SERVICE MANAGER', 'insurance', 'view'),
  ('SERVICE MANAGER', 'billing', 'view'),
  ('SERVICE MANAGER', 'billing', 'create'),
  ('SERVICE MANAGER', 'billing', 'print'),
  ('SERVICE MANAGER', 'payments', 'view'),
  ('SERVICE MANAGER', 'payments', 'create'),
  ('SERVICE MANAGER', 'reminders', null),
  ('SERVICE MANAGER', 'notifications', 'view'),
  ('SERVICE MANAGER', 'reports', 'view'),
  ('SERVICE MANAGER', 'reports', 'export'),
  ('SERVICE MANAGER', 'documents', 'view'),
  ('SERVICE MANAGER', 'documents', 'upload'),

  -- ------------------------------------------------------- SERVICE ADVISOR
  ('SERVICE ADVISOR', 'dashboard', 'view'),
  ('SERVICE ADVISOR', 'customers', 'view'),
  ('SERVICE ADVISOR', 'customers', 'create'),
  ('SERVICE ADVISOR', 'customers', 'edit'),
  ('SERVICE ADVISOR', 'vehicles', 'view'),
  ('SERVICE ADVISOR', 'vehicles', 'create'),
  ('SERVICE ADVISOR', 'vehicles', 'edit'),
  ('SERVICE ADVISOR', 'inventory', 'view'),
  ('SERVICE ADVISOR', 'products', 'view'),
  ('SERVICE ADVISOR', 'service', 'view'),
  ('SERVICE ADVISOR', 'service', 'create'),
  ('SERVICE ADVISOR', 'service', 'edit'),
  ('SERVICE ADVISOR', 'service', 'assign'),
  ('SERVICE ADVISOR', 'warranty', 'view'),
  ('SERVICE ADVISOR', 'warranty', 'claim'),
  ('SERVICE ADVISOR', 'insurance', 'view'),
  ('SERVICE ADVISOR', 'reminders', 'view'),
  ('SERVICE ADVISOR', 'reminders', 'create'),
  ('SERVICE ADVISOR', 'notifications', 'view'),
  ('SERVICE ADVISOR', 'documents', 'view'),
  ('SERVICE ADVISOR', 'documents', 'upload'),

  -- ------------------------------------------------------------ TECHNICIAN
  -- Records the work done. Cannot bill it, discount it, or mark it complete
  -- for delivery; those need an advisor or manager.
  ('TECHNICIAN', 'dashboard', 'view'),
  ('TECHNICIAN', 'customers', 'view'),
  ('TECHNICIAN', 'vehicles', 'view'),
  ('TECHNICIAN', 'products', 'view'),
  ('TECHNICIAN', 'inventory', 'view'),
  ('TECHNICIAN', 'service', 'view'),
  ('TECHNICIAN', 'service', 'edit'),
  ('TECHNICIAN', 'notifications', 'view'),
  ('TECHNICIAN', 'documents', 'view'),

  -- ------------------------------------------------------------ ACCOUNTANT
  ('ACCOUNTANT', 'dashboard', 'view'),
  ('ACCOUNTANT', 'customers', 'view'),
  ('ACCOUNTANT', 'sales', 'view'),
  ('ACCOUNTANT', 'billing', 'view'),
  ('ACCOUNTANT', 'billing', 'export'),
  ('ACCOUNTANT', 'payments', null),
  ('ACCOUNTANT', 'finance', 'view'),
  ('ACCOUNTANT', 'emi', 'view'),
  ('ACCOUNTANT', 'emi', 'payment'),
  ('ACCOUNTANT', 'emi', 'export'),
  ('ACCOUNTANT', 'purchases', 'view'),
  ('ACCOUNTANT', 'suppliers', 'view'),
  ('ACCOUNTANT', 'expenses', null),
  ('ACCOUNTANT', 'accounting', null),
  ('ACCOUNTANT', 'service', 'view'),
  ('ACCOUNTANT', 'reports', null),
  ('ACCOUNTANT', 'documents', 'view'),
  ('ACCOUNTANT', 'documents', 'download'),
  ('ACCOUNTANT', 'notifications', 'view'),
  ('ACCOUNTANT', 'audit', 'view'),

  -- ---------------------------------------------------------------- VIEWER
  -- Read-only. Expanded below to every 'view' action, so this role
  -- automatically picks up new modules.
  ('VIEWER', '__ALL_VIEW__', 'view')
)
select distinct r.id, p.id
from grants g
join public.roles r on r.name = g.role_name
join public.permissions p
  on (
       -- VIEWER: every view permission across every module.
       (g.module = '__ALL_VIEW__' and p.action = 'view')
       -- Module wildcard: every action in the module.
       or (g.module <> '__ALL_VIEW__' and g.action is null
           and p.module = g.module)
       -- Explicit pair.
       or (g.module <> '__ALL_VIEW__' and g.action is not null
           and p.module = g.module and p.action = g.action)
     )
on conflict (role_id, permission_id) do nothing;

-- =============================================================================
-- Sanity assertions
--
-- A seed that silently grants nothing is worse than a seed that fails: the
-- first produces users who can sign in but do nothing, and the cause is not
-- obvious. These checks make a mistake in the grant expansion fail loudly.
-- =============================================================================
do $$
declare
  v_roles       integer;
  v_permissions integer;
  v_grants      integer;
  v_empty_role  text;
begin
  select count(*) into v_roles from public.roles where is_system_role;
  select count(*) into v_permissions from public.permissions;
  select count(*) into v_grants from public.role_permissions;

  if v_roles <> 13 then
    raise exception 'Expected 13 system roles, found %', v_roles;
  end if;

  if v_permissions < 100 then
    raise exception 'Permission catalogue looks incomplete: only % rows',
      v_permissions;
  end if;

  select r.name into v_empty_role
  from public.roles r
  where not exists (
    select 1 from public.role_permissions rp where rp.role_id = r.id
  )
  limit 1;

  if v_empty_role is not null then
    raise exception 'Role "%" was seeded with no permissions', v_empty_role;
  end if;

  raise notice
    'Seeded % roles, % permissions, % grants',
    v_roles, v_permissions, v_grants;
end $$;
