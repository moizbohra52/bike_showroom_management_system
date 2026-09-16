-- =============================================================================
-- 001_extensions.sql
--
-- Extensions and shared helper domains.
--
-- Supabase provisions extensions into the `extensions` schema and places it on
-- the default search_path, so an extension installed there is reachable
-- unqualified. `create extension if not exists` keeps this re-runnable.
-- =============================================================================

-- pgcrypto supplies gen_random_uuid() on older servers. PostgreSQL 13+ has it
-- built in, but installing the extension keeps the migration portable across
-- the versions Supabase has shipped.
create extension if not exists "pgcrypto" with schema extensions;

-- Trigram indexes. Required for the ILIKE '%term%' searches every list screen
-- performs: without trigram support those scans cannot use an index at all,
-- and a customer search across a large showroom degrades to a sequential scan.
create extension if not exists "pg_trgm" with schema extensions;

-- Removes accents so "Jose" matches "José" in a customer name search.
create extension if not exists "unaccent" with schema extensions;

-- Composite/GiST index support, used for the exclusion-style lookups on
-- date ranges in the reporting views.
create extension if not exists "btree_gist" with schema extensions;

-- =============================================================================
-- Shared domains
--
-- Declaring these once means a money column cannot accidentally be created
-- with the wrong precision, and the sign constraint is impossible to forget.
-- =============================================================================

do $$
begin
  -- Monetary amounts. numeric(14,2) holds up to 999,999,999,999.99 which is
  -- far beyond any realistic showroom figure, and numeric is exact - float
  -- would drift and break the debit = credit assertion on the ledger.
  if not exists (select 1 from pg_type where typname = 'money_amount') then
    create domain money_amount as numeric(14, 2)
      check (value >= 0);
  end if;

  -- Amounts that may legitimately be negative: a ledger line, an adjustment.
  if not exists (select 1 from pg_type where typname = 'signed_amount') then
    create domain signed_amount as numeric(14, 2);
  end if;

  -- Percentages: discount rates, interest rates, tax rates.
  if not exists (select 1 from pg_type where typname = 'percentage') then
    create domain percentage as numeric(6, 3)
      check (value >= 0 and value <= 100);
  end if;
end $$;

-- =============================================================================
-- Utility functions used by later migrations
-- =============================================================================

-- Normalises a phone number to bare digits so the unique index on
-- (showroom_id, phone) is not defeated by formatting. Mirrors
-- AppValidators.normalisePhone on the client.
create or replace function public.normalise_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  v_digits text;
begin
  if p_phone is null then
    return null;
  end if;

  v_digits := regexp_replace(p_phone, '[^0-9]', '', 'g');

  if length(v_digits) > 10 and left(v_digits, 2) = '91' then
    v_digits := right(v_digits, 10);
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_digits := right(v_digits, 10);
  elsif length(v_digits) > 10 then
    v_digits := right(v_digits, 10);
  end if;

  return nullif(v_digits, '');
end;
$$;

comment on function public.normalise_phone(text) is
  'Reduces any accepted phone spelling to ten digits for unique indexing.';

-- Indian financial year code (April-March) for document numbering, e.g. 2526.
create or replace function public.financial_year_code(p_date date)
returns text
language sql
immutable
as $$
  select case
    when extract(month from p_date) >= 4
      then lpad((extract(year from p_date)::int % 100)::text, 2, '0')
        || lpad(((extract(year from p_date)::int + 1) % 100)::text, 2, '0')
    else lpad(((extract(year from p_date)::int - 1) % 100)::text, 2, '0')
        || lpad((extract(year from p_date)::int % 100)::text, 2, '0')
  end;
$$;

comment on function public.financial_year_code(date) is
  'Two-part financial year code used in generated document numbers.';

-- Adds calendar months, clamping to the last valid day of the target month.
--
-- This is the EMI due-date rule: a loan starting 31 January bills on 28 (or
-- 29) February, never 3 March. PostgreSQL's native interval arithmetic already
-- clamps this way, so this wrapper exists to make the intent explicit and to
-- guarantee the client's DateUtil.addMonths and the schedule generator agree.
create or replace function public.add_months(p_date date, p_months int)
returns date
language sql
immutable
as $$
  select (p_date + make_interval(months => p_months))::date;
$$;

comment on function public.add_months(date, int) is
  'Calendar month arithmetic with month-end clamping, matching the client.';
