import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:flutter/foundation.dart';

/// Severity levels. The ordinal is the severity, so filtering is a comparison.
enum LogLevel {
  debug('DEBUG', 0),
  info('INFO', 1),
  warning('WARN', 2),
  error('ERROR', 3),
  critical('CRITICAL', 4);

  const LogLevel(this.label, this.severity);

  final String label;
  final int severity;
}

/// A single structured log record, kept in a ring buffer so that a user can
/// attach recent history to a bug report without any of it leaving the device
/// automatically.
class LogRecord {
  LogRecord({
    required this.level,
    required this.message,
    required this.timestamp,
    this.tag,
    this.context,
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;
  final Map<String, Object?>? context;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final String time = timestamp.toIso8601String();
    final String prefix = tag == null ? '' : '[$tag] ';
    return '$time ${level.label.padRight(8)} $prefix$message';
  }
}

/// Centralised, environment-aware, redacting logger.
///
/// Redaction is applied unconditionally — including in development — because a
/// developer screen-sharing a debug console is a realistic way for a customer's
/// details or a bearer token to leak. The list of protected keys lives in
/// [sensitiveKeys].
class AppLogger {
  const AppLogger._();

  /// Keys whose values are replaced with a placeholder wherever they appear in
  /// a logged map, at any nesting depth.
  static const Set<String> sensitiveKeys = <String>{
    'password',
    'new_password',
    'old_password',
    'confirm_password',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'apikey',
    'api_key',
    'anon_key',
    'service_role_key',
    'service_key',
    'authorization',
    'auth',
    'secret',
    'client_secret',
    'private_key',
    'signature',
    'otp',
    'pin',
    'cvv',
    'card_number',
    'account_number',
    'ifsc',
    'pan_number',
    'aadhaar',
    'aadhar_number',
    'gst_number',
    'fcm_token',
    'device_token',
    'cookie',
    'set-cookie',
    'session',
    'signed_url',
    'signedurl',
    'document_url',
    'attachment_url',
    'pdf_url',
  };

  static const String redactedPlaceholder = '***REDACTED***';

  /// How many records to retain for in-app diagnostics.
  static const int historyLimit = 300;

  static final List<LogRecord> _history = <LogRecord>[];

  /// Recent log records, oldest first. Read-only view.
  static List<LogRecord> get history => List<LogRecord>.unmodifiable(_history);

  /// Optional sink for a crash-reporting backend. Wired up in `main()` when
  /// `ENABLE_CRASH_REPORTING` is set; left null in tests.
  static void Function(LogRecord record)? crashReporter;

  static void debug(
    String message, {
    String? tag,
    Map<String, Object?>? context,
  }) => log(LogLevel.debug, message, tag: tag, context: context);

  static void info(
    String message, {
    String? tag,
    Map<String, Object?>? context,
  }) => log(LogLevel.info, message, tag: tag, context: context);

  static void warning(
    String message, {
    String? tag,
    Map<String, Object?>? context,
    Object? error,
  }) =>
      log(LogLevel.warning, message, tag: tag, context: context, error: error);

  static void error(
    String message, {
    String? tag,
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    tag: tag,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  /// Unrecoverable condition. Always reported, even in production.
  static void critical(
    String message, {
    String? tag,
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.critical,
    message,
    tag: tag,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  /// Core entry point. Applies redaction, severity filtering and fan-out.
  static void log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!EnvironmentConfig.enableLogging) {
      return;
    }
    if (level.severity < EnvironmentConfig.minimumLogSeverity) {
      return;
    }

    final LogRecord record = LogRecord(
      level: level,
      message: redactText(message),
      timestamp: DateTime.now(),
      tag: tag,
      context: context == null ? null : redactMap(context),
      error: error,
      stackTrace: stackTrace,
    );

    _remember(record);
    _emit(record);

    if (level.severity >= LogLevel.error.severity) {
      crashReporter?.call(record);
    }
  }

  static void _remember(LogRecord record) {
    _history.add(record);
    if (_history.length > historyLimit) {
      _history.removeRange(0, _history.length - historyLimit);
    }
  }

  static void _emit(LogRecord record) {
    final StringBuffer buffer = StringBuffer(record.toString());
    if (record.context != null && record.context!.isNotEmpty) {
      buffer.write('\n  context: ${_encode(record.context!)}');
    }
    if (record.error != null) {
      buffer.write('\n  error: ${redactText(record.error.toString())}');
    }

    // `dart:developer` keeps output attributed and structured in DevTools and
    // avoids the 1 KB truncation that `print` suffers on Android.
    developer.log(
      buffer.toString(),
      name: record.tag ?? 'app',
      level: _developerLevel(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
    );

    if (kDebugMode && record.stackTrace != null) {
      developer.log(
        record.stackTrace.toString(),
        name: record.tag ?? 'app',
        level: _developerLevel(record.level),
      );
    }
  }

  /// Maps onto the levels `dart:developer` understands (package:logging).
  static int _developerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
      case LogLevel.critical:
        return 1200;
    }
  }

  static String _encode(Map<String, Object?> map) {
    try {
      return const JsonEncoder.withIndent('  ').convert(map);
    } on Object {
      // A value that is not JSON-encodable must not break logging.
      return map.toString();
    }
  }

  // ------------------------------------------------------------- redaction

  /// Recursively replaces the values of [sensitiveKeys] and rewrites any
  /// signed-URL query strings found in values.
  static Map<String, Object?> redactMap(Map<String, Object?> input) {
    final Map<String, Object?> output = <String, Object?>{};
    input.forEach((String key, Object? value) {
      if (isSensitiveKey(key)) {
        output[key] = redactedPlaceholder;
        return;
      }
      output[key] = redactValue(value);
    });
    return output;
  }

  static Object? redactValue(Object? value) {
    if (value is String) {
      return redactText(value);
    }
    if (value is Map) {
      final Map<String, Object?> nested = <String, Object?>{};
      value.forEach((Object? key, Object? nestedValue) {
        final String stringKey = key.toString();
        nested[stringKey] = isSensitiveKey(stringKey)
            ? redactedPlaceholder
            : redactValue(nestedValue);
      });
      return nested;
    }
    if (value is Iterable) {
      return value.map(redactValue).toList(growable: false);
    }
    return value;
  }

  static bool isSensitiveKey(String key) {
    final String normalised = key.toLowerCase().replaceAll('-', '_');
    if (sensitiveKeys.contains(normalised)) {
      return true;
    }
    // Catch variants such as `user_access_token` or `supabaseApiKey`.
    for (final String sensitive in sensitiveKeys) {
      if (normalised.contains(sensitive)) {
        return true;
      }
    }
    return false;
  }

  /// Strips credentials and signing material out of free text.
  ///
  /// Covers the three realistic leak paths: a bearer token pasted into a
  /// message, a JWT embedded in a URL, and a Supabase signed-URL token.
  static String redactText(String input) {
    if (input.isEmpty) {
      return input;
    }
    String output = input;

    // Bearer tokens.
    output = output.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer $redactedPlaceholder',
    );

    // Bare JWTs (three base64url segments).
    output = output.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'),
      redactedPlaceholder,
    );

    // Signed-URL and API-key query parameters. `replaceAllMapped` is required
    // here because Dart's `replaceAll` treats the replacement as a literal and
    // would not expand a capture group.
    output = output.replaceAllMapped(
      RegExp(
        r'([?&](?:token|apikey|api_key|signature|X-Amz-Signature|Expires)=)'
        r'[^&\s]+',
        caseSensitive: false,
      ),
      (Match match) => '${match.group(1)}$redactedPlaceholder',
    );

    return output;
  }

  /// Clears the in-memory history. Called on sign-out so the next user cannot
  /// read the previous user's diagnostics.
  static void clearHistory() => _history.clear();

  /// Renders recent history as text for a support bundle. Already redacted.
  static String exportHistory({LogLevel minimumLevel = LogLevel.debug}) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('# Diagnostic log')
      ..writeln('# environment: ${EnvironmentConfig.environment.value}')
      ..writeln('# generated: ${DateTime.now().toIso8601String()}')
      ..writeln();
    for (final LogRecord record in _history) {
      if (record.level.severity < minimumLevel.severity) {
        continue;
      }
      buffer.writeln(record.toString());
      if (record.context != null && record.context!.isNotEmpty) {
        buffer.writeln('  context: ${record.context}');
      }
      if (record.error != null) {
        buffer.writeln('  error: ${redactText(record.error.toString())}');
      }
    }
    return buffer.toString();
  }
}
