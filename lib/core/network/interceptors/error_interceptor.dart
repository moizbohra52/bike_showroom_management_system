import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/network/network_info.dart';
import 'package:dio/dio.dart';

/// Converts transport failures into [AppException]s at the boundary and feeds
/// reachability signals back to [NetworkInfo].
///
/// Placed last in the interceptor chain so that the retry and auth
/// interceptors get to see the original `DioException` first. By the time an
/// error leaves Dio it is already an application-level error, carried inside
/// `DioException.error` so Dio's own typing is satisfied; `ApiClient` unwraps
/// it before rethrowing.
class ErrorInterceptor extends Interceptor {
  ErrorInterceptor({this.networkInfo});

  final NetworkInfo? networkInfo;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // A completed round trip is the cheapest possible reachability probe.
    networkInfo?.reportSuccess();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        networkInfo?.reportFailure();
      case DioExceptionType.badResponse:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        // A response of any status means the host answered, so the network
        // itself is fine even though the request was not.
        if (err.response != null) {
          networkInfo?.reportSuccess();
        }
    }

    final AppException mapped = ErrorMapper.map(err, err.stackTrace);

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapped,
        stackTrace: err.stackTrace,
        message: mapped.message,
      ),
    );
  }
}
