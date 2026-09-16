// supabase/functions/invite-user/index.ts
//
// Creates a Supabase Auth account for a new employee and assigns their first
// role, on an administrator's behalf.
//
// -----------------------------------------------------------------------------
// Why this cannot be done from the Flutter client
// -----------------------------------------------------------------------------
// `supabase.auth.signUp()` both creates an account AND signs the caller in as
// it — calling it from an admin's session would hijack the admin's own
// session and hand it to the new account. The operation that actually does
// this correctly, `auth.admin.inviteUserByEmail()`, requires the
// SERVICE_ROLE key. That key bypasses every Row Level Security policy in the
// database for every showroom, so it must never be embedded in a Flutter
// build (§31, §40) — the *only* place it may live is inside a server-side
// Edge Function's environment, which is exactly what this file is.
//
// -----------------------------------------------------------------------------
// Its own authorisation, independent of RLS
// -----------------------------------------------------------------------------
// Once this function holds the service-role client, every query it issues
// bypasses RLS — the same trade a `SECURITY DEFINER` SQL function makes, and
// the same discipline applies: it must authorise the caller itself rather
// than assume RLS will catch a caller who should not be here. The check below
// (`has_permission('users','create')` and `has_permission('users','assign')`,
// evaluated with the CALLER's JWT, not the service-role client) is what
// stands in for RLS here.
//
// -----------------------------------------------------------------------------
// Deployment (unverified by execution in this environment — no Deno runtime
// or live Supabase project was available while writing this; the code below
// is complete and follows the documented Supabase Edge Functions and
// supabase-js v2 Admin API surface precisely, but treat first deployment as
// the point this gets its first real-world exercise)
// -----------------------------------------------------------------------------
//   supabase functions deploy invite-user
//
// Required project secrets (set via `supabase secrets set` or the dashboard):
//   SUPABASE_URL              - already provided automatically to functions
//   SUPABASE_SERVICE_ROLE_KEY - already provided automatically to functions
//   SUPABASE_ANON_KEY         - already provided automatically to functions

// `jsr:` is the current recommended specifier for Supabase Edge Functions
// (Deno 2). If the deployed Supabase CLI's Deno runtime predates `jsr:`
// support, substitute the equivalent
// `https://esm.sh/@supabase/supabase-js@2` — same package, same API.
import { createClient } from 'jsr:@supabase/supabase-js@2';

interface InvitePayload {
  name: string;
  email: string;
  phone?: string | null;
  employee_code?: string | null;
  showroom_id: string;
  role_id: string;
}

/** Shape returned on every path, success or failure, so the Flutter client's
 * single `result['error']` check covers all of them. */
function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return jsonResponse({ error: 'Missing Authorization header' }, 401);
  }

  let payload: InvitePayload;
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const { name, email, phone, employee_code, showroom_id, role_id } = payload;

  if (!name?.trim() || !email?.trim() || !showroom_id || !role_id) {
    return jsonResponse(
      { error: 'name, email, showroom_id and role_id are required' },
      400,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Scoped to the CALLER's own JWT (forwarded from the client, never the
  // service-role key), so `has_permission()` evaluates against whoever
  // actually invoked this function, exactly as it would for a direct
  // PostgREST request from them.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const [{ data: canCreate, error: canCreateError }, { data: canAssign, error: canAssignError }] =
    await Promise.all([
      callerClient.rpc('has_permission', { p_module: 'users', p_action: 'create' }),
      callerClient.rpc('has_permission', { p_module: 'users', p_action: 'assign' }),
    ]);

  if (canCreateError || canAssignError) {
    return jsonResponse(
      { error: 'Could not verify your permissions. Please try again.' },
      500,
    );
  }
  if (!canCreate || !canAssign) {
    return jsonResponse(
      { error: 'You do not have permission to invite a user.' },
      403,
    );
  }

  // The caller may only invite into a showroom they themselves can reach —
  // otherwise a manager scoped to Branch A could staff Branch B, which
  // `can_access_showroom()` (evaluated here with the caller's own JWT, same
  // as above) exists specifically to prevent.
  const { data: canAccessShowroom, error: canAccessError } = await callerClient.rpc(
    'can_access_showroom',
    { p_showroom_id: showroom_id },
  );
  if (canAccessError || !canAccessShowroom) {
    return jsonResponse(
      { error: 'You do not have access to that showroom.' },
      403,
    );
  }

  // A caller who is not a super admin must not be able to grant the
  // SUPER ADMIN role to someone else through this side channel — the same
  // rule `009_rls.sql`'s `user_roles_insert` policy enforces for a direct
  // table write.
  const { data: isSuperAdmin } = await callerClient.rpc('is_super_admin');
  if (!isSuperAdmin) {
    const { data: role } = await callerClient
      .from('roles')
      .select('name')
      .eq('id', role_id)
      .maybeSingle();
    if (role?.name === 'SUPER ADMIN') {
      return jsonResponse(
        { error: 'Only a super admin can grant the SUPER ADMIN role.' },
        403,
      );
    }
  }

  // From here on, the service-role client performs the actual write. Every
  // authorisation decision that matters has already been made above, against
  // the caller's own identity.
  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
    email.trim().toLowerCase(),
    {
      data: {
        name: name.trim(),
        phone: phone?.trim() || undefined,
        employee_code: employee_code?.trim() || undefined,
        // Read by handle_new_auth_user() in 015_auth_triggers.sql, which
        // pre-fills the profile's showroom_id from here if the id is valid.
        showroom_id,
      },
    },
  );

  if (inviteError || !invited?.user) {
    // Supabase reports a duplicate email as a 422/"already registered" error.
    const message = inviteError?.message?.toLowerCase().includes('already')
      ? 'An account with this email already exists.'
      : (inviteError?.message ?? 'Could not create the account.');
    return jsonResponse({ error: message }, 400);
  }

  // The on_auth_user_created trigger runs synchronously as part of the
  // insert into auth.users above, so the public.users profile row already
  // exists by the time inviteUserByEmail() has returned.
  const { data: profile, error: profileError } = await adminClient
    .from('users')
    .select('id')
    .eq('auth_user_id', invited.user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return jsonResponse(
      {
        error:
          'The account was created but its profile could not be found. ' +
          'Please contact support before retrying, to avoid a duplicate invite.',
      },
      500,
    );
  }

  const { error: roleError } = await adminClient
    .from('user_roles')
    .insert({ user_id: profile.id, role_id });

  if (roleError) {
    return jsonResponse(
      {
        error:
          'The account was created but the role could not be assigned. ' +
          'Assign it from the Users screen.',
        user_id: profile.id,
      },
      207, // Partial success: worth a distinct status for a caller that cares.
    );
  }

  return jsonResponse(
    {
      user_id: profile.id,
      auth_user_id: invited.user.id,
      message: 'Invitation sent.',
    },
    200,
  );
});
