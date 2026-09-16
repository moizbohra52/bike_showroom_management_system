import 'dart:async';
import 'dart:io';

import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
// `Headers` is declared by both dio and postgrest, so dio is always prefixed.
import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates every transport-level and database-level failure into an
/// [AppException].
///
/// This is the only place in the codebase that knows about `DioException`,
/// `PostgrestException`, SQLSTATE codes or HTTP status numbers. Repositories
/// funnel their errors through [ErrorMapper.map] and everything above them
/// deals in the application hierarchy alone.
class ErrorMapper {
  const ErrorMapper._();

  /// Maps [error] to an [AppException], preserving the original as `cause`.
  ///
  /// Already-mapped exceptions pass through untouched so that a rethrow deeper
  /// in the stack never double-wraps.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      return error;
    }
    if (error is dio.DioException) {
      return mapDioException(error, stackTrace);
    }
    if (error is PostgrestException) {
      return mapPostgrestException(error, stackTrace);
    }
    if (error is AuthException) {
      return mapAuthException(error, stackTrace);
    }
    if (error is StorageException) {
      return mapStorageException(error, stackTrace);
    }
    if (error is SocketException) {
      return NetworkException(cause: error, stackTrace: stackTrace);
    }
    if (error is HttpException) {
      return NetworkException(cause: error, stackTrace: stackTrace);
    }
    if (error is TimeoutException) {
      return RequestTimeoutException(cause: error, stackTrace: stackTrace);
    }
    if (error is FormatException) {
      return ValidationException(
        message: 'The server returned data in an unexpected format.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return UnknownException(cause: error, stackTrace: stackTrace);
  }

  // ---------------------------------------------------------------- transport

  static AppException mapDioException(
    dio.DioException error, [
    StackTrace? stackTrace,
  ]) {
    switch (error.type) {
      case dio.DioExceptionType.connectionTimeout:
      case dio.DioExceptionType.sendTimeout:
      case dio.DioExceptionType.receiveTimeout:
      // Response arrived but decoding it blew the budget; from the user's
      // point of view this is indistinguishable from a slow server.
      case dio.DioExceptionType.transformTimeout:
        return RequestTimeoutException(cause: error, stackTrace: stackTrace);

      case dio.DioExceptionType.cancel:
        return CancelledException(cause: error, stackTrace: stackTrace);

      case dio.DioExceptionType.connectionError:
        return NetworkException(cause: error, stackTrace: stackTrace);

      case dio.DioExceptionType.badCertificate:
        return NetworkException(
          message: 'The server certificate could not be verified.',
          cause: error,
          stackTrace: stackTrace,
        );

      case dio.DioExceptionType.badResponse:
        return mapHttpStatus(
          error.response?.statusCode,
          serverMessage: extractServerMessage(error.response?.data),
          fieldErrors: extractFieldErrors(error.response?.data),
          retryAfter: parseRetryAfter(error.response?.headers),
          cause: error,
          stackTrace: stackTrace,
        );

      case dio.DioExceptionType.unknown:
        if (error.error is SocketException) {
          return NetworkException(cause: error, stackTrace: stackTrace);
        }
        return UnknownException(cause: error, stackTrace: stackTrace);
    }
  }

  /// Maps a bare HTTP status to the hierarchy. Shared by the Dio mapper and by
  /// Supabase functions/storage errors, which report status numbers too.
  static AppException mapHttpStatus(
    int? statusCode, {
    String? serverMessage,
    Map<String, String>? fieldErrors,
    Duration? retryAfter,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    switch (statusCode) {
      case 400:
        return ValidationException(
          message: serverMessage ?? 'The request was rejected as invalid.',
          fieldErrors: fieldErrors,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 401:
        return UnauthorizedException(cause: cause, stackTrace: stackTrace);
      case 403:
        return ForbiddenException(cause: cause, stackTrace: stackTrace);
      case 404:
        return NotFoundException(cause: cause, stackTrace: stackTrace);
      case 408:
        return RequestTimeoutException(cause: cause, stackTrace: stackTrace);
      case 409:
        return ConflictException(
          message: serverMessage ?? 'This record conflicts with existing data.',
          fieldErrors: fieldErrors,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 422:
        return ValidationException(
          message: serverMessage ?? 'Please correct the highlighted fields.',
          fieldErrors: fieldErrors,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 429:
        return RateLimitException(
          retryAfter: retryAfter,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(cause: cause, stackTrace: stackTrace);
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(cause: cause, stackTrace: stackTrace);
        }
        return UnknownException(
          message: serverMessage ?? 'An unexpected error occurred.',
          cause: cause,
          stackTrace: stackTrace,
        );
    }
  }

  // ---------------------------------------------------------------- database

  /// Maps a PostgREST / PostgreSQL error using its SQLSTATE.
  ///
  /// Business rules raised by our own functions use `RAISE EXCEPTION` which
  /// surfaces as SQLSTATE `P0001`. Those messages are authored to be shown to
  /// the user, so they are passed through verbatim.
  static AppException mapPostgrestException(
    PostgrestException error, [
    StackTrace? stackTrace,
  ]) {
    final String? code = error.code;
    final String rawMessage = error.message;

    switch (code) {
      // -- our own RAISE EXCEPTION / RAISE_EXCEPTION in PL/pgSQL -----------
      case 'P0001':
        return BusinessRuleException(
          message: stripSqlNoise(rawMessage),
          rule: error.hint,
          cause: error,
          stackTrace: stackTrace,
        );

      // -- integrity constraints -------------------------------------------
      case '23505': // unique_violation
        final String? field = parseConstraintField(
          error.details?.toString() ?? rawMessage,
        );
        return ConflictException(
          message: describeUniqueViolation(field),
          conflictingField: field,
          fieldErrors: field == null
              ? null
              : <String, String>{field: 'This value is already in use.'},
          cause: error,
          stackTrace: stackTrace,
        );

      case '23503': // foreign_key_violation
        return ConflictException(
          message:
              'This record is linked to other data and cannot be '
              'changed or removed.',
          cause: error,
          stackTrace: stackTrace,
        );

      case '23514': // check_violation
        return ValidationException(
          message: describeCheckViolation(rawMessage),
          cause: error,
          stackTrace: stackTrace,
        );

      case '23502': // not_null_violation
        final String? column = parseColumnName(rawMessage);
        return ValidationException(
          message: column == null
              ? 'A required field was left empty.'
              : 'The field "$column" is required.',
          fieldErrors: column == null
              ? null
              : <String, String>{column: 'This field is required.'},
          cause: error,
          stackTrace: stackTrace,
        );

      case '22P02': // invalid_text_representation
      case '22003': // numeric_value_out_of_range
      case '22007': // invalid_datetime_format
        return ValidationException(
          message: 'One of the values entered has an invalid format.',
          cause: error,
          stackTrace: stackTrace,
        );

      // -- authorisation ----------------------------------------------------
      case '42501': // insufficient_privilege - an RLS policy refused the row
        return ForbiddenException(cause: error, stackTrace: stackTrace);

      case '28000': // invalid_authorization_specification
      case '28P01': // invalid_password
        return UnauthorizedException(cause: error, stackTrace: stackTrace);

      // -- concurrency, worth retrying --------------------------------------
      case '40001': // serialization_failure
      case '40P01': // deadlock_detected
      case '55P03': // lock_not_available
        return ServerException(
          message: 'The record was busy. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        );

      case '57014': // query_canceled
        return RequestTimeoutException(cause: error, stackTrace: stackTrace);

      case '53300': // too_many_connections
        return ServerException(
          message: 'The server is busy. Please try again shortly.',
          cause: error,
          stackTrace: stackTrace,
        );

      // -- PostgREST specific -----------------------------------------------
      case 'PGRST116': // .single() matched zero rows
        return NotFoundException(cause: error, stackTrace: stackTrace);

      case 'PGRST301': // JWT expired
      case 'PGRST302': // JWT invalid
        return UnauthorizedException(cause: error, stackTrace: stackTrace);

      case 'PGRST204': // column named in the payload does not exist
        return ValidationException(
          message: 'The request referenced a field the server does not know.',
          cause: error,
          stackTrace: stackTrace,
        );

      case '42P01': // undefined_table
      case '42703': // undefined_column
      case '42883': // undefined_function
        return ServerException(
          message:
              'The server is missing an expected database object. '
              'Please contact your administrator.',
          cause: error,
          stackTrace: stackTrace,
        );

      default:
        // PostgREST also reports plain HTTP statuses in `code` for some paths.
        final int? asStatus = int.tryParse(code ?? '');
        if (asStatus != null) {
          return mapHttpStatus(
            asStatus,
            serverMessage: stripSqlNoise(rawMessage),
            cause: error,
            stackTrace: stackTrace,
          );
        }
        return ServerException(
          message: 'The database rejected this request.',
          cause: error,
          stackTrace: stackTrace,
        );
    }
  }

  // -------------------------------------------------------------------- auth

  static AppException mapAuthException(
    AuthException error, [
    StackTrace? stackTrace,
  ]) {
    final String raw = error.message.toLowerCase();
    final int? status = int.tryParse(error.statusCode ?? '');

    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid email or password')) {
      return AuthenticationException(
        message: 'Incorrect email or password.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (raw.contains('email not confirmed')) {
      return AuthenticationException(
        message: 'Please confirm your email address before signing in.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered')) {
      return ConflictException(
        message: 'An account already exists for this email address.',
        conflictingField: 'email',
        fieldErrors: const <String, String>{
          'email': 'This email is already registered.',
        },
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (raw.contains('password should be at least') ||
        raw.contains('weak password')) {
      return ValidationException(
        message: 'Please choose a stronger password.',
        fieldErrors: const <String, String>{
          'password': 'Password does not meet the minimum requirements.',
        },
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (raw.contains('token has expired') ||
        raw.contains('refresh token') ||
        raw.contains('session') && raw.contains('expired')) {
      return UnauthorizedException(cause: error, stackTrace: stackTrace);
    }
    if (raw.contains('over_email_send_rate_limit') ||
        raw.contains('rate limit') ||
        status == 429) {
      return RateLimitException(cause: error, stackTrace: stackTrace);
    }
    if (raw.contains('otp') && raw.contains('expired')) {
      return AuthenticationException(
        message: 'That code has expired. Please request a new one.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 403) {
      return ForbiddenException(cause: error, stackTrace: stackTrace);
    }

    return AuthenticationException(
      message: 'Sign-in failed. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  // ----------------------------------------------------------------- storage

  static AppException mapStorageException(
    StorageException error, [
    StackTrace? stackTrace,
  ]) {
    final int? status = int.tryParse(error.statusCode ?? '');
    final String raw = error.message.toLowerCase();

    if (status == 404 || raw.contains('not found')) {
      return NotFoundException(
        message: 'The file could not be found.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 401) {
      return UnauthorizedException(cause: error, stackTrace: stackTrace);
    }
    if (status == 403 || raw.contains('row-level security')) {
      return ForbiddenException(
        message: 'You do not have permission to access this file.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 409 || raw.contains('already exists')) {
      return ConflictException(
        message: 'A file with that name already exists.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (status == 413 || raw.contains('payload too large')) {
      return ValidationException(
        message: 'That file is too large to upload.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return FileStorageException(cause: error, stackTrace: stackTrace);
  }

  // ------------------------------------------------------------- extraction

  /// Pulls a human-usable message out of an arbitrary error body.
  static String? extractServerMessage(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      final String trimmed = data.trim();
      // Guard against an HTML error page being shown as a message.
      if (trimmed.isEmpty || trimmed.startsWith('<')) {
        return null;
      }
      return trimmed;
    }
    if (data is Map) {
      for (final String key in const <String>[
        'message',
        'error_description',
        'error',
        'msg',
        'detail',
        'hint',
      ]) {
        final Object? value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return stripSqlNoise(value.trim());
        }
        if (value is Map) {
          final Object? nested = value['message'];
          if (nested is String && nested.trim().isNotEmpty) {
            return stripSqlNoise(nested.trim());
          }
        }
      }
    }
    return null;
  }

  /// Extracts `{field: message}` pairs from a validation error body.
  ///
  /// Handles both `{"errors": {"phone": ["invalid"]}}` and
  /// `{"errors": [{"field": "phone", "message": "invalid"}]}`.
  static Map<String, String>? extractFieldErrors(Object? data) {
    if (data is! Map) {
      return null;
    }
    final Object? errors = data['errors'] ?? data['field_errors'];
    final Map<String, String> result = <String, String>{};

    if (errors is Map) {
      errors.forEach((Object? key, Object? value) {
        if (key is! String) {
          return;
        }
        if (value is String) {
          result[key] = value;
        } else if (value is List && value.isNotEmpty) {
          result[key] = value.first.toString();
        }
      });
    } else if (errors is List) {
      for (final Object? entry in errors) {
        if (entry is Map) {
          final Object? field = entry['field'] ?? entry['name'];
          final Object? message = entry['message'] ?? entry['error'];
          if (field is String && message is String) {
            result[field] = message;
          }
        }
      }
    }
    return result.isEmpty ? null : result;
  }

  static Duration? parseRetryAfter(dio.Headers? headers) {
    final String? value = headers?.value('retry-after');
    if (value == null) {
      return null;
    }
    final int? seconds = int.tryParse(value.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// Recovers the offending column from a unique-constraint error.
  ///
  /// PostgreSQL reports either `Key (chassis_number)=(ABC) already exists.` or
  /// names the index, e.g. `inventory_chassis_number_key`.
  static String? parseConstraintField(String detail) {
    final RegExpMatch? keyMatch = RegExp(r'Key \(([^)]+)\)').firstMatch(detail);
    if (keyMatch != null) {
      final String columns = keyMatch.group(1)!;
      // Composite keys report a comma-separated list; the first is enough to
      // point the user at the right field.
      return columns.split(',').first.trim();
    }

    final RegExpMatch? indexMatch = RegExp(
      r'"?([a-z0-9_]+)_(key|idx|unique)"?',
    ).firstMatch(detail);
    if (indexMatch != null) {
      final String name = indexMatch.group(1)!;
      for (final String table in const <String>[
        'inventory_',
        'customers_',
        'sales_',
        'invoices_',
        'payments_',
        'purchases_',
        'service_records_',
        'loans_',
        'showrooms_',
        'users_',
        'emi_schedules_',
      ]) {
        if (name.startsWith(table)) {
          return name.substring(table.length);
        }
      }
      return name;
    }
    return null;
  }

  static String? parseColumnName(String message) {
    final RegExpMatch? match = RegExp(r'column "([^"]+)"').firstMatch(message);
    return match?.group(1);
  }

  /// Human phrasing for the unique constraints that users actually hit.
  static String describeUniqueViolation(String? field) {
    switch (field) {
      case 'chassis_number':
        return 'A vehicle with this chassis number already exists.';
      case 'engine_number':
        return 'A vehicle with this engine number already exists.';
      case 'stock_code':
        return 'This stock code is already in use.';
      case 'customer_code':
        return 'This customer code is already in use.';
      case 'registration_number':
        return 'A vehicle with this registration number already exists.';
      case 'phone':
        return 'A customer with this phone number already exists.';
      case 'email':
        return 'This email address is already registered.';
      case 'sale_number':
      case 'invoice_number':
      case 'payment_number':
      case 'purchase_number':
      case 'service_number':
      case 'loan_number':
        return 'That document number has already been used. '
            'Please retry to obtain a fresh number.';
      case 'code':
        return 'This code is already in use.';
      default:
        return 'A record with these details already exists.';
    }
  }

  /// Human phrasing for the CHECK constraints defined in the schema.
  static String describeCheckViolation(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('amount') && lower.contains('positive')) {
      return 'Amounts must be greater than zero.';
    }
    if (lower.contains('discount')) {
      return 'The discount is outside the permitted range.';
    }
    if (lower.contains('outstanding')) {
      return 'The amount exceeds the outstanding balance.';
    }
    if (lower.contains('balanced') || lower.contains('debit')) {
      return 'The accounting entry is not balanced.';
    }
    if (lower.contains('date')) {
      return 'The dates provided are not in a valid order.';
    }
    return 'One of the values breaks a business rule set on the database.';
  }

  /// Removes PL/pgSQL framing so the user sees only the authored sentence.
  static String stripSqlNoise(String message) {
    String cleaned = message
        .replaceAll(RegExp(r'^ERROR:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*CONTEXT:[\s\S]*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*SQL statement[\s\S]*$'), '')
        .replaceAll(RegExp(r'\s*PL/pgSQL function[\s\S]*$'), '')
        .trim();
    if (cleaned.isEmpty) {
      return message.trim();
    }
    // Capitalise for consistency with the rest of the UI copy.
    cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    return cleaned;
  }
}
