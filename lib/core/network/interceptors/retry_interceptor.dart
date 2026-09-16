import 'dart:async';
import 'dart:math' as math;

import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/network/network_info.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Retries transient failures with exponential backoff and jitter.
///
/// ## Only idempotent requests are retried
///
/// A retried `POST /payments` could take the customer's money twice. This
/// interceptor therefore retries `GET`, `HEAD` and `OPTIONS` unconditionally,
/// and retries a mutation only when the caller has explicitly marked it safe
/// via [idempotentExtraKey] — which the repositories set for RPCs that carry
/// a client-generated idempotency key the database de-duplicates on.
///
/// ## Jitter
///
/// When a showroom's connection drops and returns, every queued request
/// retries at once. Without jitter they stay in lockstep and hammer the
/// backend in synchronised waves, so a random fraction of the delay is added.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.networkInfo,
    this.maxAttempts = AppConstants.maxRetryAttempts,
    this.baseDelay = AppConstants.retryBaseDelay,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final Dio dio;
  final NetworkInfo? networkInfo;
  final int maxAttempts;
  final Duration baseDelay;
  final math.Random _random;

  /// Set `extra[idempotentExtraKey] = true` on a mutating request to opt it
  /// into retries.
  static const String idempotentExtraKey = 'is_idempotent';

  /// Internal counter carried on the request.
  static const String attemptExtraKey = 'retry_attempt';

  static const Set<String> _idempotentMethods = <String>{
    'GET',
    'HEAD',
    'OPTIONS',
  };

  /// Status codes worth retrying. 429 is included because the backoff is
  /// exactly the right response to being throttled.
  static const Set<int> _retryableStatuses = <int>{
    408,
    425,
    429,
    500,
    502,
    503,
    504,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final int attempt = (options.extra[attemptExtraKey] as int?) ?? 0;

    if (!_shouldRetry(err, attempt)) {
      handler.next(err);
      return;
    }

    final Duration delay = _delayFor(attempt, err);

    AppLogger.info(
      'Retrying ${options.method} ${options.path} '
      '(attempt ${attempt + 1} of $maxAttempts) in ${delay.inMilliseconds}ms',
      tag: 'network',
    );

    await Future<void>.delayed(delay);

    // Do not retry into a connection that is known to be down; let the error
    // through so the caller can queue the change offline instead.
    if (networkInfo != null &&
        networkInfo!.quality == ConnectionQuality.offline) {
      AppLogger.info('Abandoning retry: connection is offline', tag: 'network');
      handler.next(err);
      return;
    }

    try {
      final RequestOptions retryOptions = options
        ..extra[attemptExtraKey] = attempt + 1;
      final Response<dynamic> response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // Feeds back into this interceptor, so the attempt counter advances
      // until maxAttempts is reached.
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err, int attempt) {
    if (attempt >= maxAttempts - 1) {
      return false;
    }
    if (err.type == DioExceptionType.cancel) {
      return false;
    }

    final RequestOptions options = err.requestOptions;
    final bool methodIsSafe = _idempotentMethods.contains(
      options.method.toUpperCase(),
    );
    final bool explicitlyIdempotent = options.extra[idempotentExtraKey] == true;

    if (!methodIsSafe && !explicitlyIdempotent) {
      return false;
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final int? status = err.response?.statusCode;
        return status != null && _retryableStatuses.contains(status);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
      case DioExceptionType.unknown:
        // Socket-level failures surface here on some platforms.
        return err.error is Exception;
    }
  }

  /// Exponential backoff with full jitter, honouring `Retry-After` when the
  /// server supplied one.
  Duration _delayFor(int attempt, DioException err) {
    final String? retryAfter = err.response?.headers.value('retry-after');
    if (retryAfter != null) {
      final int? seconds = int.tryParse(retryAfter.trim());
      if (seconds != null && seconds > 0 && seconds <= 60) {
        return Duration(seconds: seconds);
      }
    }

    final int exponential =
        baseDelay.inMilliseconds * math.pow(2, attempt).toInt();
    final int jitter = _random.nextInt(
      math.max(1, (exponential * 0.3).round()),
    );
    // Cap so a retry never leaves the user waiting on a spinner for long.
    const int ceilingMs = 8000;
    return Duration(milliseconds: math.min(exponential + jitter, ceilingMs));
  }
}
