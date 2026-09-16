import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Logs request and response traffic for diagnostics.
///
/// Bodies are logged only when `ENABLE_NETWORK_LOGGING` is set *and* the build
/// is not production, because every payload in this application contains
/// customer names, phone numbers or financial figures. Headers are always
/// passed through [AppLogger.redactMap], which removes the bearer token and
/// the publishable key.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.maxBodyCharacters = 2000});

  /// Long bodies are truncated: a product list response can be hundreds of
  /// kilobytes and would drown the log.
  final int maxBodyCharacters;

  static const String _startedAtKey = 'logging_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now().millisecondsSinceEpoch;

    AppLogger.debug(
      '--> ${options.method} ${options.uri}',
      tag: 'http',
      context: EnvironmentConfig.enableNetworkLogging
          ? <String, Object?>{
              'headers': AppLogger.redactMap(
                options.headers.map(
                  (String key, dynamic value) =>
                      MapEntry<String, Object?>(key, value),
                ),
              ),
              'query': options.queryParameters,
              'body': _summarise(options.data),
            }
          : null,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    AppLogger.debug(
      '<-- ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri} (${_elapsed(response.requestOptions)})',
      tag: 'http',
      context: EnvironmentConfig.enableNetworkLogging
          ? <String, Object?>{'body': _summarise(response.data)}
          : null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Errors are logged at warning level even in production, without bodies,
    // so a field problem can be diagnosed from the status and path alone.
    AppLogger.warning(
      '<-- ERROR ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.method} ${err.requestOptions.uri} '
      '(${_elapsed(err.requestOptions)})',
      tag: 'http',
      context: <String, Object?>{
        'type': err.type.name,
        'status': err.response?.statusCode,
        if (EnvironmentConfig.enableNetworkLogging)
          'body': _summarise(err.response?.data),
      },
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final Object? startedAt = options.extra[_startedAtKey];
    if (startedAt is! int) {
      return 'unknown';
    }
    final int ms = DateTime.now().millisecondsSinceEpoch - startedAt;
    return '${ms}ms';
  }

  /// Renders a body for logging: redacted, and truncated to a readable size.
  Object? _summarise(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is FormData) {
      // Never log file bytes. The field names are enough to debug an upload.
      return <String, Object?>{
        'formFields': data.fields
            .map((MapEntry<String, String> field) => field.key)
            .toList(),
        'formFiles': data.files
            .map((MapEntry<String, MultipartFile> file) => file.key)
            .toList(),
      };
    }
    if (data is Map) {
      return AppLogger.redactMap(
        data.map(
          (Object? key, Object? value) =>
              MapEntry<String, Object?>(key.toString(), value),
        ),
      );
    }
    if (data is List) {
      if (data.length > 20) {
        return '<list of ${data.length} items>';
      }
      return AppLogger.redactValue(data);
    }

    final String text = AppLogger.redactText(data.toString());
    if (text.length <= maxBodyCharacters) {
      return text;
    }
    return '${text.substring(0, maxBodyCharacters)}'
        '... <truncated ${text.length - maxBodyCharacters} chars>';
  }
}
