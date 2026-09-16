import 'package:bike_showroom_management_system/common/controllers/session_controller.dart';
import 'package:bike_showroom_management_system/common/controllers/theme_controller.dart';
import 'package:bike_showroom_management_system/core/network/api_client.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/services/auth_service.dart';
import 'package:bike_showroom_management_system/services/connectivity_service.dart';
import 'package:bike_showroom_management_system/services/local_database_service.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:get/get.dart';

/// Application composition root.
///
/// Registers the long-lived services in dependency order and makes them
/// permanent, because they are needed for the life of the process.
///
/// Feature controllers are *not* registered here — they come from their own
/// bindings, attached to their routes, so they are created on navigation and
/// disposed on exit.
class AppConfig {
  const AppConfig._();

  /// Boots the services that must exist before the first frame.
  ///
  /// Ordering is load-bearing:
  ///  1. [StorageService] — supplies the cipher key the local database needs.
  ///  2. [LocalDatabaseService] — opens the boxes the session cache reads.
  ///  3. [ConnectivityService] — the API client needs it to fail fast offline.
  ///  4. [AuthService] — begins listening for auth state changes.
  ///  5. [ApiClient] — needs the auth token provider and connectivity.
  ///  6. Controllers — depend on all of the above.
  static Future<void> initialiseServices() async {
    AppLogger.info('Initialising services', tag: 'startup');

    final StorageService storage = await Get.putAsync<StorageService>(
      () => StorageService().init(),
    );

    final LocalDatabaseService localDatabase =
        await Get.putAsync<LocalDatabaseService>(
          () => LocalDatabaseService().init(),
          permanent: true,
        );

    final ConnectivityService connectivity =
        await Get.putAsync<ConnectivityService>(
          () => ConnectivityService().init(),
          permanent: true,
        );

    final AuthService auth = await Get.putAsync<AuthService>(
      () => AuthService().init(),
      permanent: true,
    );

    // The client reads the token through callbacks rather than holding a
    // reference to AuthService, which keeps the network layer independent of
    // the auth feature and avoids a circular dependency.
    Get.put<ApiClient>(
      ApiClient(
        networkInfo: connectivity.networkInfo,
        accessTokenProvider: () => auth.accessToken,
        refreshSession: auth.refreshSession,
        onSessionExpired: () {
          AppLogger.warning(
            'Session expired; clearing local session state',
            tag: 'auth',
          );
          if (Get.isRegistered<SessionController>()) {
            Get.find<SessionController>().clear();
          }
        },
      ),
      permanent: true,
    );

    Get.put<ThemeController>(
      ThemeController(storageService: storage),
      permanent: true,
    );

    Get.put<SessionController>(
      SessionController(
        authService: auth,
        storageService: storage,
        localDatabaseService: localDatabase,
      ),
      permanent: true,
    );

    AppLogger.info('Services initialised', tag: 'startup');
  }

  /// Releases everything. Used by tests and by a full application reset.
  static Future<void> disposeServices() async {
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().dispose();
    }
    await Get.deleteAll(force: true);
  }
}
