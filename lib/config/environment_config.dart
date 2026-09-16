/// Environment selection and per-environment configuration.
///
/// Every value is supplied at build time through `--dart-define`. Nothing
/// secret is committed to source control, and the production Supabase keys are
/// injected by CI. See docs/DEPLOYMENT.md for the full invocation.
///
/// ```
/// flutter build windows --release \
///   --dart-define=APP_ENV=production \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// Note that the Supabase *anon* key is designed to be shipped in clients: it
/// carries no privileges of its own and every request it makes is still
/// filtered by Row Level Security. The *service role* key must never appear in
/// this file, in `--dart-define`, or anywhere else in the Flutter application.
library;

/// The three supported deployment targets.
enum AppEnvironment {
  development('development', 'DEV'),
  staging('staging', 'STAGING'),
  production('production', 'PROD');

  const AppEnvironment(this.value, this.shortLabel);

  final String value;

  /// Shown in the app bar badge for non-production builds so testers always
  /// know which backend they are pointed at.
  final String shortLabel;

  static AppEnvironment fromValue(String? value) =>
      AppEnvironment.values.firstWhere(
        (AppEnvironment environment) => environment.value == value,
        orElse: () => AppEnvironment.development,
      );
}

/// Resolved, immutable configuration for the running build.
class EnvironmentConfig {
  const EnvironmentConfig._();

  // --------------------------------------------------------- raw defines
  static const String _envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool _enableLogging = bool.fromEnvironment(
    'ENABLE_LOGGING',
    defaultValue: true,
  );

  static const bool _enableNetworkLogging = bool.fromEnvironment(
    'ENABLE_NETWORK_LOGGING',
  );

  static const bool _enableCrashReporting = bool.fromEnvironment(
    'ENABLE_CRASH_REPORTING',
    defaultValue: true,
  );

  static const bool _enableRealtime = bool.fromEnvironment(
    'ENABLE_REALTIME',
    defaultValue: true,
  );

  static const bool _enableOfflineMode = bool.fromEnvironment(
    'ENABLE_OFFLINE_MODE',
    defaultValue: true,
  );

  static const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

  // ----------------------------------------------------------- accessors

  static AppEnvironment get environment => AppEnvironment.fromValue(_envName);

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProduction => environment == AppEnvironment.production;

  /// Supabase project URL.
  static String get supabaseUrl => _supabaseUrl;

  /// Supabase publishable (anon) key.
  static String get supabaseAnonKey => _supabaseAnonKey;

  /// Optional base URL for a companion REST service reached through Dio.
  /// Falls back to the Supabase REST endpoint when not supplied.
  static String get apiBaseUrl =>
      _apiBaseUrl.isNotEmpty ? _apiBaseUrl : '$_supabaseUrl/rest/v1';

  /// Supabase Edge Functions base URL.
  static String get functionsBaseUrl => '$_supabaseUrl/functions/v1';

  /// Whether the logger emits anything at all. Severity filtering is a
  /// separate concern, handled by [minimumLogSeverity].
  static bool get enableLogging => _enableLogging;

  /// Floor on emitted log severity, as an index into `LogLevel.values`.
  ///
  /// Production keeps warnings and above so that field diagnostics remain
  /// possible, while dropping the verbose debug/info traffic that would
  /// otherwise carry customer data into device logs.
  static int get minimumLogSeverity => isProduction ? 2 : 0;

  /// Request/response bodies are only ever logged outside production, and only
  /// when explicitly switched on, because payloads contain customer data.
  static bool get enableNetworkLogging =>
      _enableNetworkLogging && !isProduction;

  static bool get enableCrashReporting => _enableCrashReporting;

  static bool get enableRealtime => _enableRealtime;

  static bool get enableOfflineMode => _enableOfflineMode;

  static String get sentryDsn => _sentryDsn;

  /// Show the environment badge everywhere except production.
  static bool get showEnvironmentBadge => !isProduction;

  /// True when the mandatory defines are present. `main()` refuses to boot
  /// without them rather than failing later with an opaque network error.
  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  /// Human-readable explanation of what is missing, for the startup guard.
  static List<String> get missingKeys {
    final List<String> missing = <String>[];
    if (_supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (_supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }
    return missing;
  }

  /// Guards against the single most damaging misconfiguration: someone pasting
  /// a service-role key into the anon slot, which would hand every client full
  /// bypass of Row Level Security.
  ///
  /// Supabase JWTs carry a `role` claim; a service key decodes with
  /// `"role":"service_role"`. Checking the encoded payload is enough and does
  /// not require a JWT library.
  static bool get looksLikeServiceRoleKey {
    if (_supabaseAnonKey.isEmpty) {
      return false;
    }
    // Base64url of `"role":"service_role"` fragments, plus the plain form in
    // case a non-standard key format is supplied.
    const List<String> markers = <String>[
      'service_role',
      'InNlcnZpY2Vfcm9sZSI',
      'cm9sZSI6InNlcnZpY2Vfcm9sZSI',
    ];
    for (final String marker in markers) {
      if (_supabaseAnonKey.contains(marker)) {
        return true;
      }
    }
    return false;
  }

  /// Diagnostic summary. Deliberately reports only the *shape* of the keys so
  /// this can be printed at startup or attached to a bug report safely.
  static Map<String, Object?> get diagnostics => <String, Object?>{
    'environment': environment.value,
    'supabaseUrl': _supabaseUrl,
    'supabaseAnonKeyLength': _supabaseAnonKey.length,
    'supabaseAnonKeyConfigured': _supabaseAnonKey.isNotEmpty,
    'apiBaseUrl': apiBaseUrl,
    'loggingEnabled': enableLogging,
    'networkLoggingEnabled': enableNetworkLogging,
    'realtimeEnabled': enableRealtime,
    'offlineModeEnabled': enableOfflineMode,
    'crashReportingEnabled': enableCrashReporting,
  };
}
