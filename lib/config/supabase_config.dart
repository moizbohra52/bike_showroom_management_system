import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase initialisation and access.
///
/// The client is a process-wide singleton owned by the Supabase SDK; this class
/// only configures it and exposes narrow accessors so that feature code does
/// not reach for `Supabase.instance` directly (which makes it impossible to
/// substitute in a test).
class SupabaseConfig {
  const SupabaseConfig._();

  static bool _initialised = false;

  static bool get isInitialised => _initialised;

  /// Boots the Supabase SDK.
  ///
  /// Throws [StateError] when the required defines are absent, because
  /// continuing would produce confusing network errors on every screen
  /// instead of one clear message at startup.
  static Future<void> initialise() async {
    if (_initialised) {
      return;
    }

    if (!EnvironmentConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Missing --dart-define values: '
        '${EnvironmentConfig.missingKeys.join(', ')}. '
        'See docs/DEPLOYMENT.md.',
      );
    }

    // Refuse to boot with a service-role key. Such a key bypasses Row Level
    // Security entirely, so shipping one in a client would expose every
    // showroom's data to every user. Failing loudly is the only safe response.
    if (EnvironmentConfig.looksLikeServiceRoleKey) {
      throw StateError(
        'SUPABASE_ANON_KEY appears to contain a service-role key. '
        'A service-role key bypasses Row Level Security and must never be '
        'embedded in a client application. Use the publishable (anon) key.',
      );
    }

    await Supabase.initialize(
      url: EnvironmentConfig.supabaseUrl,
      // `publishableKey` supersedes the older `anonKey` parameter; both carry
      // the same non-privileged key, and RLS governs what it can reach.
      publishableKey: EnvironmentConfig.supabaseAnonKey,
      debug: EnvironmentConfig.enableNetworkLogging,
      authOptions: const FlutterAuthClientOptions(
        // Persist the session so the user is not signed out on every launch.
        // The SDK stores it in the platform secure store where available.
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: RealtimeClientOptions(
        // Realtime is used sparingly — notifications and a couple of live
        // dashboard tiles. A high event rate on a showroom's mobile data plan
        // is not worth the freshness, so events are throttled.
        eventsPerSecond: EnvironmentConfig.enableRealtime ? 4 : 0,
      ),
      postgrestOptions: const PostgrestClientOptions(schema: 'public'),
    );

    _initialised = true;
    AppLogger.info(
      'Supabase initialised for ${EnvironmentConfig.environment.value}',
      tag: 'supabase',
    );
  }

  /// The configured client. Throws if [initialise] has not completed.
  static SupabaseClient get client {
    if (!_initialised) {
      throw StateError(
        'SupabaseConfig.initialise() must complete before the client is used.',
      );
    }
    return Supabase.instance.client;
  }

  static GoTrueClient get auth => client.auth;

  static SupabaseStorageClient get storage => client.storage;

  static RealtimeClient get realtime => client.realtime;

  /// Currently authenticated Supabase user, or null when signed out.
  static User? get currentUser => _initialised ? auth.currentUser : null;

  static Session? get currentSession =>
      _initialised ? auth.currentSession : null;

  static String? get accessToken => currentSession?.accessToken;

  static bool get isSignedIn => currentUser != null;

  /// Whether the access token is at or near expiry.
  ///
  /// The leeway matters because a token that expires mid-request produces a
  /// 401 the user sees as a random failure; refreshing slightly early avoids
  /// that entirely.
  static bool isSessionExpiring({
    Duration leeway = const Duration(minutes: 5),
  }) {
    final Session? session = currentSession;
    if (session == null) {
      return false;
    }
    final int? expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    final DateTime expiry = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
    );
    return DateTime.now().add(leeway).isAfter(expiry);
  }

  /// Builds a storage path that is namespaced by showroom.
  ///
  /// Storage RLS policies match on the first path segment, so getting this
  /// shape wrong is a tenancy leak. Always compose paths through here.
  static String storagePath({
    required String showroomId,
    required String entityType,
    required String entityId,
    required String fileName,
  }) => '$showroomId/$entityType/$entityId/$fileName';

  /// Resets state. Test-only; the SDK singleton cannot truly be torn down.
  static void resetForTesting() => _initialised = false;
}
