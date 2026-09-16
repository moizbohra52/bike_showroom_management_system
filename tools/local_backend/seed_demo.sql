-- Demo data for the local development backend.
--
-- Two showrooms rather than one, deliberately: a single branch hides every
-- multi-tenancy bug, because `can_access_showroom()` returns true for the only
-- row that exists. With two, a wrong filter shows up immediately as another
-- branch's data appearing where it should not.
--
-- Safe to run more than once - every insert is keyed on the showroom code.
-- Applies to the LOCAL database only; never run it against a real project.

insert into public.showrooms (
  name, code, address, city, state, pincode,
  phone, email, gst_number, invoice_prefix
)
values
  (
    'Speed Motors - Indore', 'SMIND',
    '14 Race Course Road', 'Indore', 'Madhya Pradesh', '452001',
    '9876543210', 'indore@speedmotors.local', '23AAACS1234A1Z5', 'SMI'
  ),
  (
    'Speed Motors - Bhopal', 'SMBPL',
    '7 MP Nagar Zone 1', 'Bhopal', 'Madhya Pradesh', '462011',
    '9876500011', 'bhopal@speedmotors.local', '23AAACS1234A2Z4', 'SMB'
  )
on conflict (code) do nothing;

-- Give the administrator a home branch so the showroom switcher has something
-- to open on. A super admin can reach every showroom regardless; this only
-- decides where the session starts.
update public.users u
set showroom_id = (select id from public.showrooms where code = 'SMIND'),
    updated_at = now()
where u.showroom_id is null
  and exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = u.id and r.name = 'SUPER ADMIN'
  );

select
  (select count(*) from public.showrooms) as showrooms,
  (select count(*) from public.users)     as users,
  (select count(*) from public.roles)     as roles;
