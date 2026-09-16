import 'dart:async';

import 'package:bike_showroom_management_system/config/supabase_config.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/features/auth/models/auth_context.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication and session lifecycle.
///
/// Owns the Supabase Auth interaction and the resolution of [AuthContext].
/// Deliberately knows nothing about routing or UI; `AuthController` reacts to
/// the streams exposed here.
class AuthService extends GetxService {
  AuthService({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  SupabaseClient get client => _injectedClient ?? SupabaseConfig.client;

  GoTrueClient get auth => client.auth;

  static AuthService get instance => Get.find<AuthService>();

  /// Broadcasts auth state transitions for the controller to act on.
  final StreamController<AuthLifecycleEvent> _lifecycle =
      StreamController<AuthLifecycleEvent>.broadcast();

  Stream<AuthLifecycleEvent> get onLifecycleEvent => _lifecycle.stream;

  StreamSubscription<AuthState>? _authSubscription;

  Future<AuthService> init() async {
    _authSubscription = auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Auth state stream failed',
          tag: 'auth',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    AppLogger.debug('AuthService ready', tag: 'auth');
    return this;
  }

  void _handleAuthStateChange(AuthState state) {
    AppLogger.info(
      'Auth event: ${state.event.name}',
      tag: 'auth',
      context: <String, Object?>{'hasSession': state.session != null},
    );

    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
        if (state.session != null) {
          _emit(AuthLifecycleEvent.signedIn);
        }
      case AuthChangeEvent.signedOut:
        _emit(AuthLifecycleEvent.signedOut);
      case AuthChangeEvent.tokenRefreshed:
        _emit(AuthLifecycleEvent.tokenRefreshed);
      case AuthChangeEvent.userUpdated:
        _emit(AuthLifecycleEvent.userUpdated);
      case AuthChangeEvent.passwordRecovery:
        _emit(AuthLifecycleEvent.passwordRecovery);
      case AuthChangeEvent.mfaChallengeVerified:
        break;
      // Listed only to keep the switch exhaustive; the SDK never emits it.
      // ignore: deprecated_member_use
      case AuthChangeEvent.userDeleted:
        break;
    }
  }

  void _emit(AuthLifecycleEvent event) {
    if (!_lifecycle.isClosed) {
      _lifecycle.add(event);
    }
  }

  // ------------------------------------------------------------------ state

  User? get currentAuthUser => auth.currentUser;

  Session? get currentSession => auth.currentSession;

  String? get accessToken => currentSession?.accessToken;

  bool get isSignedIn => currentAuthUser != null;

  /// Whether the access token needs refreshing soon.
  bool get isSessionExpiring => SupabaseConfig.isSessionExpiring();

  // ----------------------------------------------------------------- sign in

  /// Signs in with email and password.
  ///
  /// A successful credential check is not enough to enter the application: the
  /// profile must also be active and provisioned. That check happens in
  /// [resolveContext], and the caller signs the user back out if it fails.
  Future<AuthContext> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null || response.session == null) {
        throw AuthenticationException(
          message: 'Sign-in did not return a session. Please try again.',
        );
      }

      AppLogger.info('Password sign-in succeeded', tag: 'auth');
      return await resolveContext();
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Sends a password-reset email.
  ///
  /// Always reports success to the caller regardless of whether the address is
  /// registered. Revealing which emails exist would turn this endpoint into a
  /// user-enumeration oracle.
  Future<void> sendPasswordReset({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: redirectTo,
      );
      AppLogger.info('Password reset requested', tag: 'auth');
    } on AuthException catch (error, stackTrace) {
      // Rate limiting is worth surfacing; anything else is swallowed so the
      // response is indistinguishable for known and unknown addresses.
      final AppException mapped = ErrorMapper.mapAuthException(
        error,
        stackTrace,
      );
      if (mapped is RateLimitException) {
        throw mapped;
      }
      AppLogger.warning(
        'Password reset failed but reporting success to avoid enumeration',
        tag: 'auth',
        error: error,
      );
    } on Object catch (error) {
      AppLogger.warning(
        'Password reset failed but reporting success to avoid enumeration',
        tag: 'auth',
        error: error,
      );
    }
  }

  /// Completes a reset by setting a new password for the recovery session.
  Future<void> updatePassword(String newPassword) async {
    try {
      await auth.updateUser(UserAttributes(password: newPassword));
      AppLogger.info('Password updated', tag: 'auth');
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Refreshes the access token.
  ///
  /// Returns false rather than throwing when the refresh token is spent, so
  /// the auth interceptor can fall through to signing the user out cleanly.
  Future<bool> refreshSession() async {
    try {
      if (currentSession == null) {
        return false;
      }
      final AuthResponse response = await auth.refreshSession();
      final bool refreshed = response.session != null;
      AppLogger.info(
        refreshed ? 'Session refreshed' : 'Session refresh returned no session',
        tag: 'auth',
      );
      return refreshed;
    } on Object catch (error) {
      AppLogger.warning('Session refresh failed', tag: 'auth', error: error);
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await auth.signOut();
      AppLogger.info('Signed out', tag: 'auth');
    } on Object catch (error, stackTrace) {
      // A failed network sign-out must still clear local state, otherwise the
      // user is stuck signed in on a device they wanted to leave.
      AppLogger.warning(
        'Remote sign-out failed; clearing locally anyway',
        tag: 'auth',
        error: error,
      );
      AppLogger.debug('Sign-out stack: $stackTrace', tag: 'auth');
    }
  }

  // --------------------------------------------------------------- context

  /// Resolves the full identity and authorisation context.
  ///
  /// One RPC rather than a chain of client queries. See [AuthContext] for why
  /// that is a correctness requirement and not just an optimisation.
  Future<AuthContext> resolveContext() async {
    final User? authUser = currentAuthUser;
    if (authUser == null) {
      throw UnauthorizedException(
        message: 'No active session. Please sign in.',
      );
    }

    try {
      final Object? payload = await client.rpc<Object?>(
        DbFunctions.currentUserContext,
      );

      if (payload == null) {
        throw ForbiddenException(
          message:
              'Your account has not been set up for this application. '
              'Please contact your administrator.',
        );
      }

      final Map<String, Object?> json = payload is Map<String, dynamic>
          ? Map<String, Object?>.from(payload)
          : throw ServerException(
              message: 'The server returned an unexpected profile format.',
            );

      final AuthContext context = AuthContext.fromJson(json);

      AppLogger.info(
        'Resolved auth context',
        tag: 'auth',
        context: <String, Object?>{
          'roles': context.user.roleNames,
          'permissionCount': context.permissions.length,
          'showroomCount': context.showrooms.length,
          'isSuperAdmin': context.isSuperAdmin,
        },
      );

      return context;
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Records the sign-in timestamp and writes a LOGIN audit row.
  ///
  /// Failures here are logged but never propagated: a user must not be blocked
  /// from working because an audit write failed. The audit trigger on the
  /// server is the authoritative record.
  Future<void> recordSignIn(String userId) async {
    try {
      await client
          .from(DbTables.users)
          .update(<String, Object?>{
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } on Object catch (error) {
      AppLogger.warning(
        'Could not record last_login_at',
        tag: 'auth',
        error: error,
      );
    }
  }

  /// Verifies the caller holds [permission] on the server.
  ///
  /// Used for a confirmation step before a high-impact action, so the client
  /// does not offer an operation that RLS will reject. This is a UX
  /// nicety — the authoritative check is the policy on the write itself.
  Future<bool> verifyPermission(String module, String action) async {
    try {
      final Object? result = await client.rpc<Object?>(
        DbFunctions.hasPermission,
        params: <String, Object?>{'p_module': module, 'p_action': action},
      );
      return result == true;
    } on Object catch (error) {
      AppLogger.warning(
        'Permission verification failed for $module.$action',
        tag: 'auth',
        error: error,
      );
      return false;
    }
  }

  /// Registers a new auth user. Administrator-driven onboarding only.
  ///
  /// Creating the auth user is all this does. The profile row is created by
  /// the `on_auth_user_created` trigger, and the showroom and role assignment
  /// is a separate, permission-guarded step — which is why a newly created
  /// user cannot sign in to anything useful until an administrator finishes.
  Future<String?> registerAuthUser({
    required String email,
    required String password,
    Map<String, Object?>? metadata,
  }) async {
    try {
      final AuthResponse response = await auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: metadata,
      );
      return response.user?.id;
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _lifecycle.close();
    super.onClose();
  }
}

/// Auth transitions the controller reacts to.
enum AuthLifecycleEvent {
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  passwordRecovery,
}
