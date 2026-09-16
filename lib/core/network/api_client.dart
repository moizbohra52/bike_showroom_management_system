import 'dart:async';

import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/network/interceptors/auth_interceptor.dart';
import 'package:bike_showroom_management_system/core/network/interceptors/error_interceptor.dart';
import 'package:bike_showroom_management_system/core/network/interceptors/logging_interceptor.dart';
import 'package:bike_showroom_management_system/core/network/interceptors/retry_interceptor.dart';
import 'package:bike_showroom_management_system/core/network/network_info.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// The single HTTP surface for the application.
///
/// Views never touch this; only repositories and services do, and they reach
/// it through `Controller -> Repository -> Service` as required by the
/// architecture. Every method throws an [AppException] on failure — the
/// `DioException` type does not escape this class.
///
/// Most database access goes through the Supabase client rather than here.
/// This exists for Edge Functions, file downloads, third-party integrations
/// (payment gateway, SMS), and any companion REST service.
class ApiClient {
  ApiClient({
    required this.networkInfo,
    required this.accessTokenProvider,
    required this.refreshSession,
    required this.onSessionExpired,
    Dio? dio,
    String? baseUrl,
  }) : dio = dio ?? Dio() {
    _configure(baseUrl ?? EnvironmentConfig.apiBaseUrl);
  }

  final Dio dio;
  final NetworkInfo networkInfo;
  final String? Function() accessTokenProvider;
  final Future<bool> Function() refreshSession;
  final void Function() onSessionExpired;

  /// Cancel tokens grouped by an arbitrary caller-supplied tag, so a
  /// controller can abandon all of its in-flight requests in `onClose()`.
  final Map<String, List<CancelToken>> _cancelGroups =
      <String, List<CancelToken>>{};

  void _configure(String baseUrl) {
    dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      // Let every status through to the interceptors so error bodies can be
      // parsed for field-level messages rather than discarded by Dio.
      validateStatus: (int? status) => status != null && status < 500,
      headers: <String, String>{
        'Accept': 'application/json',
        'X-Client-Platform': _platformLabel,
        'X-Client-Env': EnvironmentConfig.environment.value,
      },
    );

    dio.interceptors.clear();
    dio.interceptors.addAll(<Interceptor>[
      // Order matters. Auth runs first so the token is present on the initial
      // attempt and can be refreshed before a retry; logging sits in the
      // middle to observe what is actually sent; retry re-issues; the error
      // mapper runs last so it sees the final outcome.
      AuthInterceptor(
        accessTokenProvider: accessTokenProvider,
        refreshSession: refreshSession,
        onSessionExpired: onSessionExpired,
      ),
      LoggingInterceptor(),
      RetryInterceptor(dio: dio, networkInfo: networkInfo),
      ErrorInterceptor(networkInfo: networkInfo),
    ]);
  }

  static String get _platformLabel {
    // Avoids importing dart:io, which would break the web build.
    return const String.fromEnvironment(
      'CLIENT_PLATFORM',
      defaultValue: 'flutter',
    );
  }

  /// Re-points the client at a different base URL. Used by the Edge Functions
  /// helper and by tests.
  void setBaseUrl(String baseUrl) => dio.options.baseUrl = baseUrl;

  // -------------------------------------------------------------- lifecycle

  /// Issues a cancel token tagged for group cancellation.
  CancelToken tokenFor(String group) {
    final CancelToken token = CancelToken();
    _cancelGroups.putIfAbsent(group, () => <CancelToken>[]).add(token);
    return token;
  }

  /// Cancels every in-flight request in [group].
  ///
  /// Called from `onClose()` of a controller: without it, a response arriving
  /// after the controller is disposed would write to a discarded `Rx` and, for
  /// a search-as-you-type field, an older response could overwrite a newer one.
  void cancelGroup(String group, {String reason = 'Controller disposed'}) {
    final List<CancelToken>? tokens = _cancelGroups.remove(group);
    if (tokens == null) {
      return;
    }
    for (final CancelToken token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
  }

  void cancelAll({String reason = 'Shutting down'}) {
    for (final String group in _cancelGroups.keys.toList()) {
      cancelGroup(group, reason: reason);
    }
  }

  // ---------------------------------------------------------------- methods

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) => _send<T>(
    () => dio.get<T>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(headers: headers, receiveTimeout: receiveTimeout),
    ),
    method: 'GET',
    path: path,
  );

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,

    /// Set when the endpoint de-duplicates on a client-supplied key, which
    /// makes a retry safe. Never set this for a plain financial write.
    bool isIdempotent = false,
  }) => _send<T>(
    () => dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(
        headers: headers,
        extra: <String, Object?>{
          RetryInterceptor.idempotentExtraKey: isIdempotent,
        },
      ),
    ),
    method: 'POST',
    path: path,
  );

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(headers: headers),
    ),
    method: 'PUT',
    path: path,
  );

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(headers: headers),
    ),
    method: 'PATCH',
    path: path,
  );

  Future<T> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(headers: headers),
    ),
    method: 'DELETE',
    path: path,
  );

  /// Multipart upload with progress reporting.
  Future<T> upload<T>(
    String path, {
    required FormData formData,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) => _send<T>(
    () => dio.post<T>(
      path,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(
        headers: headers,
        contentType: Headers.multipartFormDataContentType,
        // Uploads over a showroom's slow uplink need a longer budget than
        // an ordinary request.
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ),
    ),
    method: 'UPLOAD',
    path: path,
  );

  /// Downloads to a local path, reporting progress.
  Future<void> download(
    String urlPath,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      await dio.download(
        urlPath,
        savePath,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          headers: headers,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
    } on DioException catch (error, stackTrace) {
      throw _unwrap(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Calls a Supabase Edge Function by name.
  Future<T> invokeFunction<T>(
    String functionName, {
    Object? body,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) => _send<T>(
    () => dio.post<T>(
      '${EnvironmentConfig.functionsBaseUrl}/$functionName',
      data: body,
      cancelToken: cancelToken,
      options: Options(headers: headers),
    ),
    method: 'FUNCTION',
    path: functionName,
  );

  // ----------------------------------------------------------------- plumbing

  /// Runs [request], normalises the outcome, and guarantees an [AppException]
  /// on any failure path.
  Future<T> _send<T>(
    Future<Response<T>> Function() request, {
    required String method,
    required String path,
  }) async {
    // Fail fast when the device is known to be offline: a 20-second connect
    // timeout on every tap makes the app feel broken, and the caller wants to
    // queue the change rather than wait.
    if (networkInfo.quality == ConnectionQuality.offline) {
      throw OfflineException(
        message:
            'You are offline. This action will be retried when you '
            'reconnect.',
      );
    }

    try {
      final Response<T> response = await request();

      // `validateStatus` lets 4xx through so the body can be read; turn those
      // into errors here rather than handing a failure back as a success.
      final int status = response.statusCode ?? 0;
      if (status >= 400) {
        throw ErrorMapper.mapHttpStatus(
          status,
          serverMessage: ErrorMapper.extractServerMessage(response.data),
          fieldErrors: ErrorMapper.extractFieldErrors(response.data),
          retryAfter: ErrorMapper.parseRetryAfter(response.headers),
        );
      }

      final T? data = response.data;
      if (data == null) {
        // A 204 with a non-void expected type is a contract mismatch, not a
        // transport failure, so it is worth surfacing loudly.
        if (null is T) {
          return null as T;
        }
        throw ServerException(
          message: 'The server returned an empty response.',
          code: 'EMPTY_BODY',
        );
      }
      return data;
    } on DioException catch (error, stackTrace) {
      throw _unwrap(error, stackTrace);
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Unhandled error during $method $path',
        tag: 'http',
        error: error,
        stackTrace: stackTrace,
      );
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Recovers the [AppException] that [ErrorInterceptor] attached, or maps the
  /// raw error when the chain was bypassed (as in a unit test with a mock).
  AppException _unwrap(DioException error, StackTrace stackTrace) {
    final Object? inner = error.error;
    if (inner is AppException) {
      return inner;
    }
    return ErrorMapper.map(error, stackTrace);
  }

  void dispose() {
    cancelAll();
    dio.close(force: true);
  }
}
