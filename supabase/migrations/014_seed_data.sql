-- =============================================================================
-- 014_seed_data.sql
--
-- Reference data that the application needs in order to function at all.
--
-- Roles, permissions and their grants are seeded by 008; the chart of accounts
-- and expense categories by 013. This file holds the remaining catalogue-level
-- reference data plus the default free-service plan.
--
-- -----------------------------------------------------------------------------
-- What is NOT seeded here
-- -----------------------------------------------------------------------------
-- No showroom, no user, no customer, no stock. A migration that created a
-- showroom would put fictional data into a production database on first
-- deploy, and a migration that created an administrator would embed a known
-- credential in source control. The first showroom is created by the first
-- administrator, who is promoted through `bootstrap_super_admin()` in 015.
--
-- Everything below is idempotent, so re-running adds only what is missing.
-- =============================================================================

-- =============================================================================
-- Application settings
-- =============================================================================
insert into public.app_settings (key, value, description) values
  ('document_number_format',
   '{"pattern": "{showroom}/{type}/{fy}/{sequence}", "sequence_width": 5}',
   'Shape of generated document numbers.'),

  ('reminder_offsets',
   '{"emi": [7, 3, 1, 0], "service": [15, 7, 0], "insurance": [30, 15, 7, 1], "warranty": [30, 7]}',
   'Days before a due date at which each reminder type is raised. Mirrors '
   'AppConstants on the client.'),

  ('business_rules',
   '{"discount_approval_threshold": 5, "low_stock_threshold": 3, "expiry_warning_days": 30, "late_payment_penalty_rate": 2.0, "allow_negative_stock": false}',
   'Defaults applied when a showroom has not overridden them in its own '
   'settings.'),

  ('tax_slabs',
   '{"gst": [0, 0.25, 3, 5, 12, 18, 28], "default": 18}',
   'Permitted GST rates. The client validates against the same list.'),

  ('service_interval',
   '{"months": 6, "kilometres": 5000}',
   'Default gap to the next service after a completed job.'),

  ('invoice_defaults',
   '{"payment_terms_days": 0, "terms": "Goods once sold will not be taken back. Warranty as per manufacturer terms."}',
   'Default invoice terms; a showroom may override them in its settings.')
on conflict (key) do update
  set value = excluded.value,
      description = excluded.description,
      updated_at = now();

-- =============================================================================
-- Brands
--
-- The manufacturers an Indian two-wheeler showroom is most likely to carry.
-- A dealership will prune this to the marques it actually sells; seeding them
-- saves typing on day one and is harmless if unused.
-- =============================================================================
insert into public.brands (name, status) values
  ('Hero MotoCorp',    'ACTIVE'),
  ('Honda',            'ACTIVE'),
  ('Bajaj',            'ACTIVE'),
  ('TVS',              'ACTIVE'),
  ('Royal Enfield',    'ACTIVE'),
  ('Yamaha',           'ACTIVE'),
  ('Suzuki',           'ACTIVE'),
  ('KTM',              'ACTIVE'),
  ('Jawa',             'ACTIVE'),
  ('Ather Energy',     'ACTIVE'),
  ('Ola Electric',     'ACTIVE'),
  ('TVS iQube',        'INACTIVE'),
  ('Other',            'ACTIVE')
on conflict (name) do nothing;

-- =============================================================================
-- Default free-service plan
--
-- Applies to any product without a plan of its own, which is what
-- `generate_free_service_schedule()` falls back to. Three services is the
-- common manufacturer offering; a dealer overrides it per model where the
-- manufacturer differs.
--
-- product_id is NULL, which is what marks these as the defaults.
-- =============================================================================
insert into public.free_service_plans (
  product_id, service_number, name, validity_days, validity_km,
  free_labour, covered_items
) values
  (null, 1, 'First Free Service', 60, 1000, true,
   '["Engine oil check", "General inspection", "Brake adjustment", "Chain lubrication"]'::jsonb),
  (null, 2, 'Second Free Service', 180, 5000, true,
   '["Engine oil change", "Air filter cleaning", "Brake inspection", "Chain adjustment", "General inspection"]'::jsonb),
  (null, 3, 'Third Free Service', 365, 10000, true,
   '["Engine oil change", "Air filter replacement", "Spark plug check", "Brake service", "Full inspection"]'::jsonb)
on conflict (service_number) where product_id is null do nothing;

-- =============================================================================
-- Finance companies
--
-- The lenders most commonly used for two-wheeler finance in India. A showroom
-- deactivates the ones it has no arrangement with.
-- =============================================================================
insert into public.finance_companies (name, code, status) values
  ('Bajaj Finance',              'BAJAJFIN',  'ACTIVE'),
  ('HDFC Bank',                  'HDFCBANK',  'ACTIVE'),
  ('ICICI Bank',                 'ICICIBANK', 'ACTIVE'),
  ('Hero FinCorp',               'HEROFIN',   'ACTIVE'),
  ('TVS Credit',                 'TVSCREDIT', 'ACTIVE'),
  ('L&T Finance',                'LTFIN',     'ACTIVE'),
  ('Muthoot Capital',            'MUTHOOT',   'ACTIVE'),
  ('Shriram Finance',            'SHRIRAM',   'ACTIVE'),
  ('In-house Finance',           'INHOUSE',   'ACTIVE')
on conflict (code) do nothing;

-- =============================================================================
-- Verification
-- =============================================================================
do $$
declare
  v_roles       int;
  v_permissions int;
  v_grants      int;
  v_brands      int;
  v_plans       int;
  v_categories  int;
  v_settings    int;
  v_finance     int;
begin
  select count(*) into v_roles       from public.roles;
  select count(*) into v_permissions from public.permissions;
  select count(*) into v_grants      from public.role_permissions;
  select count(*) into v_brands      from public.brands;
  select count(*) into v_plans       from public.free_service_plans
                                     where product_id is null;
  select count(*) into v_categories  from public.expense_categories;
  select count(*) into v_settings    from public.app_settings;
  select count(*) into v_finance     from public.finance_companies;

  -- These are prerequisites, not decorations: without roles and permissions
  -- nobody can do anything, and without expense categories no expense can be
  -- recorded. Failing loudly here beats discovering it on first use.
  if v_roles < 13 then
    raise exception 'Role seed is incomplete: % roles', v_roles;
  end if;
  if v_permissions < 100 then
    raise exception 'Permission seed is incomplete: % permissions',
      v_permissions;
  end if;
  if v_grants < 100 then
    raise exception 'Role grants are incomplete: % grants', v_grants;
  end if;
  if v_categories < 5 then
    raise exception 'Expense categories are incomplete: %', v_categories;
  end if;
  if v_plans <> 3 then
    raise exception 'Expected 3 default free-service plans, found %', v_plans;
  end if;

  raise notice
    'Seed complete: % roles, % permissions, % grants, % brands, '
    '% expense categories, % finance companies, % settings, % default plans',
    v_roles, v_permissions, v_grants, v_brands, v_categories,
    v_finance, v_settings, v_plans;
end $$;
