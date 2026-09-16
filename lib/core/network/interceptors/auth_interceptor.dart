import 'dart:async';

import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Attaches Supabase credentials to every outgoing request and refreshes an
/// expired session exactly once before retrying.
///
/// ## Why a token provider is injected
///
/// The interceptor is constructed before `AuthService` exists (the Dio client
/// is a dependency of it), so the token is read through callbacks rather than
/// by holding a reference. This also keeps the network layer free of any
/// dependency on GetX or on the auth feature.
///
/// ## Concurrent 401s
///
/// A dashboard issues a dozen parallel requests. If the session has expired,
/// all of them fail at once, and refreshing per-request would fire a dozen
/// refresh calls — several of which would be rejected as the refresh token
/// rotates, logging the user out spuriously. A single in-flight refresh future
/// is therefore shared by all waiters.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.accessTokenProvider,
    required this.refreshSession,
    required this.onSessionExpired,
    this.anonKeyProvider,
  });

  /// Returns the current access token, or null when signed out.
  final String? Function() accessTokenProvider;

  /// Performs a session refresh. Returns true when a new token is available.
  final Future<bool> Function() refreshSession;

  /// Invoked when refresh fails and the user must sign in again.
  final void Function() onSessionExpired;

  /// Supplies the publishable key. Defaults to the compiled-in value.
  final String Function()? anonKeyProvider;

  /// Shared across concurrent 401s so only one refresh is ever in flight.
  Future<bool>? _refreshInFlight;

  /// Requests that must never carry a bearer token or trigger a refresh,
  /// because they are part of authentication itself.
  static const List<String> unauthenticatedPaths = <String>[
    '/auth/v1/token',
    '/auth/v1/signup',
    '/auth/v1/recover',
    '/auth/v1/verify',
    '/auth/v1/logout',
  ];

  bool _isUnauthenticatedPath(String path) =>
      unauthenticatedPaths.any((String candidate) => path.contains(candidate));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // The publishable key identifies the project on every request, including
    // unauthenticated ones. It grants nothing by itself; RLS still applies.
    final String anonKey =
        anonKeyProvider?.call() ?? EnvironmentConfig.supabaseAnonKey;
    if (anonKey.isNotEmpty) {
      options.headers['apikey'] = anonKey;
    }

    if (!_isUnauthenticatedPath(options.path)) {
      final String? token = accessTokenProvider();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else if (anonKey.isNotEmpty) {
        // Fall back to the anon role so public reads still work while signed
        // out; RLS policies decide what that role can see.
        options.headers['Authorization'] = 'Bearer $anonKey';
      }
    }

    options.headers.putIfAbsent('Accept', () => 'application/json');
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final int? status = err.response?.statusCode;
    final String path = err.requestOptions.path;

    final bool isAuthFailure = status == 401;
    final bool alreadyRetried = err.requestOptions.extra['auth_retry'] == true;

    if (!isAuthFailure || alreadyRetried || _isUnauthenticatedPath(path)) {
      handler.next(err);
      return;
    }

    AppLogger.info(
      'Received 401, attempting a single session refresh',
      tag: 'auth',
      context: <String, Object?>{'path': path},
    );

    bool refreshed;
    try {
      refreshed = await (_refreshInFlight ??= _performRefresh());
    } on Object catch (error, stackTrace) {
      AppLogger.warning('Session refresh threw', tag: 'auth', error: error);
      AppLogger.debug('Refresh stack: $stackTrace', tag: 'auth');
      refreshed = false;
    }

    if (!refreshed) {
      onSessionExpired();
      handler.next(err);
      return;
    }

    // Replay the original request once, with the new token.
    try {
      final RequestOptions retryOptions = err.requestOptions
        ..extra['auth_retry'] = true;

      final String? token = accessTokenProvider();
      if (token != null && token.isNotEmpty) {
        retryOptions.headers['Authorization'] = 'Bearer $token';
      }

      final Dio retryClient = Dio(
        BaseOptions(
          baseUrl: retryOptions.baseUrl,
          connectTimeout: retryOptions.connectTimeout,
          receiveTimeout: retryOptions.receiveTimeout,
          sendTimeout: retryOptions.sendTimeout,
        ),
      );

      final Response<dynamic> response = await retryClient.fetch<dynamic>(
        retryOptions,
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object catch (error) {
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<bool> _performRefresh() async {
    try {
      return await refreshSession();
    } finally {
      // Clear the gate so a later expiry can refresh again.
      _refreshInFlight = null;
    }
  }
}
