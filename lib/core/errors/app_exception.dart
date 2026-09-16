/// The application error hierarchy.
///
/// Everything thrown past the repository boundary is an [AppException]. Raw
/// `DioException`, `PostgrestException`, `AuthException` and friends are
/// translated by `ErrorMapper` so that controllers and widgets never need to
/// know which transport failed.
library;

/// Base class for every error the application raises deliberately.
class AppException implements Exception {
  AppException({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
    this.fieldErrors,
    this.isRetryable = false,
  });

  /// Message safe to display to an end user. Must never contain tokens,
  /// connection strings, SQL fragments or private URLs.
  final String message;

  /// Stable machine-readable identifier, used for telemetry and for deciding
  /// retry behaviour. Typically a PostgreSQL SQLSTATE or an HTTP status.
  final String? code;

  /// The original error, retained for logging only. Never surfaced to the UI.
  final Object? cause;

  final StackTrace? stackTrace;

  /// Field-level messages keyed by form field name, so a failed server-side
  /// validation can be projected straight back onto the form.
  final Map<String, String>? fieldErrors;

  /// Whether an identical retry could plausibly succeed. Drives the automatic
  /// retry interceptor and the "Try again" affordance.
  final bool isRetryable;

  /// Short label for the error surface (dialog title / snackbar heading).
  String get title => 'Something went wrong';

  bool get hasFieldErrors => fieldErrors != null && fieldErrors!.isNotEmpty;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// No usable connection, DNS failure, or the host is unreachable.
class NetworkException extends AppException {
  NetworkException({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'NETWORK',
    super.cause,
    super.stackTrace,
  }) : super(isRetryable: true);

  @override
  String get title => 'Connection problem';
}

/// The device is offline and the requested operation cannot be queued.
class OfflineException extends AppException {
  OfflineException({
    super.message =
        'You are offline. This action needs a connection to complete.',
    super.code = 'OFFLINE',
    super.cause,
    super.stackTrace,
  }) : super(isRetryable: true);

  @override
  String get title => 'Offline';
}

/// The request exceeded its connect, send or receive budget.
class RequestTimeoutException extends AppException {
  RequestTimeoutException({
    super.message = 'The server took too long to respond. Please try again.',
    super.code = 'TIMEOUT',
    super.cause,
    super.stackTrace,
  }) : super(isRetryable: true);

  @override
  String get title => 'Request timed out';
}

/// Credentials are missing, expired, or were rejected. The session is no
/// longer usable and the user must sign in again.
class UnauthorizedException extends AppException {
  UnauthorizedException({
    super.message = 'Your session has expired. Please sign in again.',
    super.code = 'UNAUTHORIZED',
    super.cause,
    super.stackTrace,
  });

  @override
  String get title => 'Sign-in required';
}

/// Authentication itself failed - wrong password, unknown email, unconfirmed
/// account. Distinct from [UnauthorizedException] because the user is at the
/// login screen and should stay there.
class AuthenticationException extends AppException {
  AuthenticationException({
    required super.message,
    super.code = 'AUTH',
    super.cause,
    super.stackTrace,
    super.fieldErrors,
  });

  @override
  String get title => 'Could not sign in';
}

/// The caller is authenticated but lacks the permission, or the row belongs to
/// a showroom they cannot access. Row Level Security produces this.
class ForbiddenException extends AppException {
  ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.code = 'FORBIDDEN',
    super.cause,
    super.stackTrace,
    this.requiredPermission,
  });

  /// The `module.action` key that would have allowed the operation, when known.
  final String? requiredPermission;

  @override
  String get title => 'Not permitted';
}

/// A client-side guard rejected the operation before it was attempted.
class PermissionDeniedException extends ForbiddenException {
  PermissionDeniedException({
    required String permission,
    super.message = 'You do not have permission to perform this action.',
  }) : super(code: 'PERMISSION_DENIED', requiredPermission: permission);
}

/// Input failed validation, either locally or at the database.
class ValidationException extends AppException {
  ValidationException({
    super.message = 'Please correct the highlighted fields.',
    super.code = 'VALIDATION',
    super.cause,
    super.stackTrace,
    super.fieldErrors,
  });

  @override
  String get title => 'Check your input';
}

/// The requested row does not exist, or is invisible under the caller's RLS
/// policy - the two are deliberately indistinguishable to avoid leaking the
/// existence of other showrooms' records.
class NotFoundException extends AppException {
  NotFoundException({
    super.message = 'The requested record could not be found.',
    super.code = 'NOT_FOUND',
    super.cause,
    super.stackTrace,
  });

  @override
  String get title => 'Not found';
}

/// A uniqueness or concurrency constraint was violated: duplicate chassis
/// number, duplicate invoice number, or a row changed underneath the caller.
class ConflictException extends AppException {
  ConflictException({
    super.message = 'This record conflicts with existing data.',
    super.code = 'CONFLICT',
    super.cause,
    super.stackTrace,
    super.fieldErrors,
    this.conflictingField,
  });

  /// Column that caused the conflict, when the database reported it.
  final String? conflictingField;

  @override
  String get title => 'Conflict';
}

/// A business invariant was rejected by a server-side function: insufficient
/// stock, payment exceeding outstanding, unbalanced journal, warranty expired.
///
/// These carry a message authored by the database function and are safe to
/// show verbatim, because the functions are written to be user-facing.
class BusinessRuleException extends AppException {
  BusinessRuleException({
    required super.message,
    super.code = 'BUSINESS_RULE',
    super.cause,
    super.stackTrace,
    this.rule,
  });

  /// Identifier of the violated rule, for analytics.
  final String? rule;

  @override
  String get title => 'Cannot complete this action';
}

/// The server failed in a way the client cannot address.
class ServerException extends AppException {
  ServerException({
    super.message = 'The server encountered a problem. Please try again.',
    super.code = 'SERVER',
    super.cause,
    super.stackTrace,
  }) : super(isRetryable: true);

  @override
  String get title => 'Server error';
}

/// Too many requests; the caller is being throttled.
class RateLimitException extends AppException {
  RateLimitException({
    super.message = 'Too many attempts. Please wait a moment and try again.',
    super.code = 'RATE_LIMIT',
    super.cause,
    super.stackTrace,
    this.retryAfter,
  }) : super(isRetryable: true);

  final Duration? retryAfter;

  @override
  String get title => 'Slow down';
}

/// File upload, download or signed-URL generation failed.
class FileStorageException extends AppException {
  FileStorageException({
    super.message = 'The file could not be processed. Please try again.',
    super.code = 'STORAGE',
    super.cause,
    super.stackTrace,
  }) : super(isRetryable: true);

  @override
  String get title => 'File error';
}

/// Local database read/write failed.
class LocalDatabaseException extends AppException {
  LocalDatabaseException({
    super.message = 'Local data could not be accessed.',
    super.code = 'LOCAL_DB',
    super.cause,
    super.stackTrace,
  });

  @override
  String get title => 'Storage error';
}

/// A queued offline change cannot be applied because the server copy moved on.
///
/// Never auto-resolved. The queue entry is parked as `CONFLICT` and a human
/// chooses, because silently overwriting a financial record is unacceptable.
class SyncConflictException extends AppException {
  SyncConflictException({
    required this.entityType,
    required this.entityId,
    super.message =
        'This record was changed on the server while you were offline.',
    super.code = 'SYNC_CONFLICT',
    super.cause,
    super.stackTrace,
    this.localRevision,
    this.serverRevision,
  });

  final String entityType;
  final String entityId;
  final int? localRevision;
  final int? serverRevision;

  @override
  String get title => 'Needs your decision';
}

/// The operation was deliberately abandoned - navigation away, a superseded
/// search, or an explicit user cancel. Must not be reported as an error.
class CancelledException extends AppException {
  CancelledException({
    super.message = 'The operation was cancelled.',
    super.code = 'CANCELLED',
    super.cause,
    super.stackTrace,
  });

  @override
  String get title => 'Cancelled';
}

/// Fallback for anything unrecognised.
class UnknownException extends AppException {
  UnknownException({
    super.message = 'An unexpected error occurred.',
    super.code = 'UNKNOWN',
    super.cause,
    super.stackTrace,
  });
}
