-- =============================================================================
-- 012_reminders.sql
--
-- Automatic reminder generation and dispatch.
--
-- -----------------------------------------------------------------------------
-- Idempotency is the whole design
-- -----------------------------------------------------------------------------
-- These functions run on a schedule, and a scheduler will occasionally run a
-- job twice: a retry after a timeout, an operator triggering it manually, an
-- overlapping window. If that produced duplicate reminders, a customer would
-- receive the same EMI notice several times, which is worse than receiving
-- none.
--
-- Every generator therefore relies on the partial unique index
-- `reminders_dedupe_key` on (reference_type, reference_id, reminder_type,
-- reminder_date) and inserts with ON CONFLICT DO NOTHING. Running any of them
-- repeatedly on the same day is a no-op.
-- =============================================================================

-- =============================================================================
-- EMI reminders
--
-- Raised at the offsets the client also knows about
-- (AppConstants.emiReminderOffsetDays): 7 days before, 3 days, 1 day, and on
-- the due date. Overdue instalments get their own escalating reminder.
-- =============================================================================
create or replace function public.create_emi_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_created integer := 0;
  v_rows    integer;
  v_offset  integer;
begin
  foreach v_offset in array array[7, 3, 1, 0] loop
    insert into public.reminders (
      showroom_id, customer_id, vehicle_id, reminder_type, title, message,
      reminder_date, priority, status, reference_id, reference_type
    )
    select
      l.showroom_id,
      l.customer_id,
      l.vehicle_id,
      'EMI',
      case when v_offset = 0
           then 'EMI due today'
           else format('EMI due in %s day(s)', v_offset) end,
      format(
        'EMI %s of %s for loan %s, amount %s, due on %s.',
        e.emi_number, l.tenure_months, l.loan_number,
        to_char(e.remaining_amount, 'FM999,999,990.00'),
        to_char(e.due_date, 'DD Mon YYYY')
      ),
      current_date,
      case when v_offset <= 1 then 'HIGH' else 'MEDIUM' end,
      'PENDING',
      e.id,
      'EMI'
    from public.emi_schedules e
    join public.loans l on l.id = e.loan_id
    where l.status = 'ACTIVE'
      and e.status in ('UPCOMING', 'DUE', 'PARTIAL')
      and e.due_date = current_date + v_offset
    on conflict do nothing;

    get diagnostics v_rows = row_count;
    v_created := v_created + v_rows;
  end loop;

  -- Overdue: one reminder per day while the instalment remains unpaid, so the
  -- collections list stays current without becoming a flood.
  insert into public.reminders (
    showroom_id, customer_id, vehicle_id, reminder_type, title, message,
    reminder_date, priority, status, reference_id, reference_type
  )
  select
    l.showroom_id, l.customer_id, l.vehicle_id, 'EMI',
    format('EMI overdue by %s day(s)', current_date - e.due_date),
    format(
      'EMI %s for loan %s was due on %s. Outstanding %s.',
      e.emi_number, l.loan_number, to_char(e.due_date, 'DD Mon YYYY'),
      to_char(e.remaining_amount, 'FM999,999,990.00')
    ),
    current_date,
    'URGENT',
    'PENDING',
    e.id,
    'EMI'
  from public.emi_schedules e
  join public.loans l on l.id = e.loan_id
  where l.status = 'ACTIVE'
    and e.status = 'OVERDUE'
    and e.due_date < current_date
  on conflict do nothing;

  return v_created;
end;
$$;

-- =============================================================================
-- Service reminders
-- =============================================================================
create or replace function public.create_service_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_created integer := 0;
  v_rows    integer;
  v_offset  integer;
begin
  foreach v_offset in array array[15, 7, 0] loop
    insert into public.reminders (
      showroom_id, customer_id, vehicle_id, reminder_type, title, message,
      reminder_date, priority, status, reference_id, reference_type
    )
    select
      v.showroom_id, v.customer_id, v.id, 'SERVICE',
      case when v_offset = 0
           then 'Service due today'
           else format('Service due in %s day(s)', v_offset) end,
      format(
        'Service due for %s on %s at approximately %s km.',
        coalesce(v.registration_number, v.chassis_number),
        to_char(v.next_service_date, 'DD Mon YYYY'),
        coalesce(v.next_service_km::text, 'the scheduled')
      ),
      current_date,
      case when v_offset = 0 then 'HIGH' else 'MEDIUM' end,
      'PENDING',
      v.id,
      'VEHICLE'
    from public.customer_vehicles v
    where v.is_deleted = false
      and v.status = 'ACTIVE'
      and v.next_service_date = current_date + v_offset
    on conflict do nothing;

    get diagnostics v_rows = row_count;
    v_created := v_created + v_rows;
  end loop;

  -- Overdue services, capped at 90 days: past that the customer has almost
  -- certainly gone elsewhere and continued nagging is counterproductive.
  insert into public.reminders (
    showroom_id, customer_id, vehicle_id, reminder_type, title, message,
    reminder_date, priority, status, reference_id, reference_type
  )
  select
    v.showroom_id, v.customer_id, v.id, 'SERVICE',
    format('Service overdue by %s day(s)', current_date - v.next_service_date),
    format(
      'Service for %s was due on %s and has not been booked.',
      coalesce(v.registration_number, v.chassis_number),
      to_char(v.next_service_date, 'DD Mon YYYY')
    ),
    current_date, 'HIGH', 'PENDING', v.id, 'VEHICLE'
  from public.customer_vehicles v
  where v.is_deleted = false
    and v.status = 'ACTIVE'
    and v.next_service_date < current_date
    and v.next_service_date >= current_date - 90
  on conflict do nothing;

  get diagnostics v_rows = row_count;
  return v_created + v_rows;
end;
$$;

-- =============================================================================
-- Insurance and warranty expiry reminders
-- =============================================================================
create or replace function public.create_insurance_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_created integer := 0;
  v_rows    integer;
  v_offset  integer;
begin
  -- A month, a fortnight and a week out. Renewing motor insurance late means
  -- driving uninsured, so the first notice is deliberately early.
  foreach v_offset in array array[30, 15, 7, 1] loop
    insert into public.reminders (
      showroom_id, customer_id, vehicle_id, reminder_type, title, message,
      reminder_date, priority, status, reference_id, reference_type
    )
    select
      ip.showroom_id, v.customer_id, v.id, 'INSURANCE',
      format('Insurance expires in %s day(s)', v_offset),
      format(
        'Policy %s with %s for %s expires on %s.',
        ip.policy_number, ip.insurance_company,
        coalesce(v.registration_number, v.chassis_number),
        to_char(ip.expiry_date, 'DD Mon YYYY')
      ),
      current_date,
      case when v_offset <= 7 then 'URGENT' else 'HIGH' end,
      'PENDING',
      ip.id,
      'INSURANCE'
    from public.insurance_policies ip
    join public.customer_vehicles v on v.id = ip.vehicle_id
    where ip.status in ('ACTIVE', 'EXPIRING_SOON')
      and ip.expiry_date = current_date + v_offset
    on conflict do nothing;

    get diagnostics v_rows = row_count;
    v_created := v_created + v_rows;
  end loop;

  return v_created;
end;
$$;

create or replace function public.create_warranty_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_created integer := 0;
  v_rows    integer;
  v_offset  integer;
begin
  foreach v_offset in array array[30, 7] loop
    insert into public.reminders (
      showroom_id, customer_id, vehicle_id, reminder_type, title, message,
      reminder_date, priority, status, reference_id, reference_type
    )
    select
      w.showroom_id, v.customer_id, v.id, 'WARRANTY',
      format('Warranty expires in %s day(s)', v_offset),
      format(
        '%s warranty for %s expires on %s. An extended warranty may be '
        'available.',
        initcap(lower(w.warranty_type)),
        coalesce(v.registration_number, v.chassis_number),
        to_char(w.end_date, 'DD Mon YYYY')
      ),
      current_date, 'MEDIUM', 'PENDING', w.id, 'WARRANTY'
    from public.warranties w
    join public.customer_vehicles v on v.id = w.vehicle_id
    where w.status in ('ACTIVE', 'EXPIRING_SOON')
      and w.end_date = current_date + v_offset
    on conflict do nothing;

    get diagnostics v_rows = row_count;
    v_created := v_created + v_rows;
  end loop;

  return v_created;
end;
$$;

-- =============================================================================
-- Outstanding payment reminders
-- =============================================================================
create or replace function public.create_payment_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rows integer;
begin
  -- Weekly rather than daily: an outstanding invoice does not become more
  -- urgent every twenty-four hours, and daily chasing damages the
  -- relationship.
  insert into public.reminders (
    showroom_id, customer_id, reminder_type, title, message,
    reminder_date, priority, status, reference_id, reference_type
  )
  select
    i.showroom_id, i.customer_id, 'PAYMENT',
    'Outstanding payment',
    format(
      'Invoice %s has %s outstanding, due on %s.',
      i.invoice_number,
      to_char(i.outstanding_amount, 'FM999,999,990.00'),
      to_char(coalesce(i.due_date, i.invoice_date), 'DD Mon YYYY')
    ),
    current_date,
    case
      when current_date - coalesce(i.due_date, i.invoice_date) > 60
        then 'URGENT'
      when current_date - coalesce(i.due_date, i.invoice_date) > 30
        then 'HIGH'
      else 'MEDIUM'
    end,
    'PENDING', i.id, 'INVOICE'
  from public.invoices i
  where i.status in ('ISSUED', 'PARTIALLY_PAID', 'OVERDUE')
    and i.outstanding_amount > 0
    and coalesce(i.due_date, i.invoice_date) < current_date
    and extract(dow from current_date) = 1   -- Mondays only
  on conflict do nothing;

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;

-- =============================================================================
-- Dispatch
--
-- Turns due reminders into notification rows and marks them SENT. The actual
-- push is delivered by an Edge Function that reads unsent notifications and
-- calls FCM; keeping the database out of the network path means a failed push
-- provider cannot roll back a business transaction.
-- =============================================================================
create or replace function public.dispatch_due_reminders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_dispatched integer := 0;
begin
  with due as (
    select r.*
    from public.reminders r
    where r.status = 'PENDING'
      and r.reminder_date <= current_date
    -- Bounded so one bad day cannot produce an unbounded batch.
    limit 1000
  ),
  inserted as (
    insert into public.notifications (
      showroom_id, customer_id, user_id, title, message,
      notification_type, reference_id, reference_type, sent_at
    )
    select
      d.showroom_id,
      d.customer_id,
      -- Route to the user who created the reminder when there is one;
      -- otherwise it is a customer-facing notice only.
      d.created_by,
      d.title,
      coalesce(d.message, d.title),
      case d.reminder_type
        when 'EMI'       then 'EMI_REMINDER'
        when 'SERVICE'   then 'SERVICE_REMINDER'
        when 'INSURANCE' then 'INSURANCE_EXPIRY'
        when 'WARRANTY'  then 'WARRANTY_EXPIRY'
        when 'PAYMENT'   then 'PAYMENT_REMINDER'
        else 'SYSTEM'
      end,
      d.reference_id,
      d.reference_type,
      now()
    from due d
    -- A reminder with no recipient at all cannot be delivered, and the
    -- notifications table rejects it anyway.
    where d.customer_id is not null or d.created_by is not null
    returning 1
  )
  update public.reminders r
  set status = 'SENT', sent_at = now(), updated_at = now()
  from due d
  where r.id = d.id;

  get diagnostics v_dispatched = row_count;
  return v_dispatched;
end;
$$;

-- =============================================================================
-- Nightly maintenance
--
-- One entry point the scheduler calls, so the order is fixed and visible:
-- statuses are refreshed BEFORE reminders are generated, otherwise an
-- instalment that became overdue overnight would not be picked up until the
-- following day.
-- =============================================================================
create or replace function public.run_daily_maintenance()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_emi_status   integer;
  v_emi          integer;
  v_service      integer;
  v_insurance    integer;
  v_warranty     integer;
  v_payment      integer;
  v_dispatched   integer;
  v_free_expired integer;
begin
  -- 1. Recompute derived statuses first.
  v_emi_status := public.refresh_emi_statuses();

  update public.warranties
  set status = public.classify_validity(end_date), updated_at = now()
  where status in ('ACTIVE', 'EXPIRING_SOON')
    and status is distinct from public.classify_validity(end_date);

  update public.insurance_policies
  set status = public.classify_validity(expiry_date), updated_at = now()
  where status in ('ACTIVE', 'EXPIRING_SOON')
    and status is distinct from public.classify_validity(expiry_date);

  -- Free-service entitlements lapse on their own date.
  update public.vehicle_free_services
  set status = 'EXPIRED', updated_at = now()
  where status in ('UPCOMING', 'DUE') and due_date < current_date;
  get diagnostics v_free_expired = row_count;

  update public.vehicle_free_services
  set status = 'DUE', updated_at = now()
  where status = 'UPCOMING' and due_date <= current_date + 15;

  -- Invoices past their due date.
  update public.invoices
  set status = 'OVERDUE', updated_at = now()
  where status in ('ISSUED', 'PARTIALLY_PAID')
    and due_date is not null
    and due_date < current_date
    and outstanding_amount > 0;

  -- 2. Generate reminders from the refreshed state.
  v_emi       := public.create_emi_reminders();
  v_service   := public.create_service_reminders();
  v_insurance := public.create_insurance_reminders();
  v_warranty  := public.create_warranty_reminders();
  v_payment   := public.create_payment_reminders();

  -- 3. Dispatch.
  v_dispatched := public.dispatch_due_reminders();

  return jsonb_build_object(
    'ran_at',              now(),
    'emi_statuses_updated', v_emi_status,
    'free_services_expired', v_free_expired,
    'emi_reminders',       v_emi,
    'service_reminders',   v_service,
    'insurance_reminders', v_insurance,
    'warranty_reminders',  v_warranty,
    'payment_reminders',   v_payment,
    'dispatched',          v_dispatched
  );
end;
$$;

comment on function public.run_daily_maintenance() is
  'Nightly job: refresh derived statuses, generate reminders, dispatch. '
  'Idempotent - safe to run more than once in a day.';

-- =============================================================================
-- Scheduling
--
-- pg_cron is available on Supabase but must be enabled for the project. The
-- block below schedules the job when the extension is present and otherwise
-- leaves a notice, so this migration runs successfully either way rather than
-- failing on a project where pg_cron has not been turned on.
-- =============================================================================
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    begin
      create extension if not exists pg_cron;

      -- Remove a previous definition so re-running does not stack duplicates.
      perform cron.unschedule('bsms-daily-maintenance')
      where exists (
        select 1 from cron.job where jobname = 'bsms-daily-maintenance'
      );

      -- 01:30 UTC is 07:00 IST: after midnight processing, before the
      -- showroom opens, so the team starts the day with a current worklist.
      perform cron.schedule(
        'bsms-daily-maintenance',
        '30 1 * * *',
        $cron$ select public.run_daily_maintenance(); $cron$
      );

      raise notice 'Scheduled bsms-daily-maintenance at 01:30 UTC daily';
    exception when others then
      raise notice
        'pg_cron is available but could not be configured (%). Schedule '
        'run_daily_maintenance() externally.', sqlerrm;
    end;
  else
    raise notice
      'pg_cron is not available. Call public.run_daily_maintenance() from a '
      'scheduled Edge Function or an external scheduler instead.';
  end if;
end $$;
