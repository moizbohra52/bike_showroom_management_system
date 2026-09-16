import 'dart:async';

import 'package:bike_showroom_management_system/core/network/network_info.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Reactive connectivity state for the UI and the sync engine.
///
/// Wraps [NetworkInfo] so widgets can observe reachability through GetX
/// without depending on the plugin, and so the sync engine has a single place
/// to hook the "came back online" transition.
class ConnectivityService extends GetxService {
  ConnectivityService({NetworkInfo? networkInfo})
    : networkInfo = networkInfo ?? NetworkInfoImpl();

  final NetworkInfo networkInfo;

  /// Current assessment. Note the difference between an interface being up and
  /// the backend actually answering — see [ConnectionQuality].
  final Rx<ConnectionQuality> quality = Rx<ConnectionQuality>(
    ConnectionQuality.unverified,
  );

  /// Interface types currently active, for the diagnostics screen.
  final RxList<ConnectivityResult> connectionTypes = <ConnectivityResult>[].obs;

  /// Fires when connectivity is regained after being offline. The sync service
  /// listens here rather than polling.
  final StreamController<void> _onRestored = StreamController<void>.broadcast();

  Stream<void> get onConnectionRestored => _onRestored.stream;

  StreamSubscription<ConnectionQuality>? _subscription;

  static ConnectivityService get instance => Get.find<ConnectivityService>();

  bool get isOnline => quality.value != ConnectionQuality.offline;
  bool get isOffline => quality.value == ConnectionQuality.offline;

  /// True only when the backend has actually answered recently. Used before
  /// starting a sync pass, where optimism is expensive.
  bool get isVerifiedOnline => quality.value == ConnectionQuality.online;

  Future<ConnectivityService> init() async {
    await networkInfo.initialise();
    quality.value = networkInfo.quality;
    connectionTypes.assignAll(await networkInfo.connectionTypes);

    _subscription = networkInfo.onQualityChanged.listen((
      ConnectionQuality next,
    ) async {
      final ConnectionQuality previous = quality.value;
      quality.value = next;
      connectionTypes.assignAll(await networkInfo.connectionTypes);

      final bool cameBack =
          previous == ConnectionQuality.offline &&
          next != ConnectionQuality.offline;
      if (cameBack) {
        AppLogger.info(
          'Connection restored; signalling sync',
          tag: 'connectivity',
        );
        if (!_onRestored.isClosed) {
          _onRestored.add(null);
        }
      }
    });

    AppLogger.debug(
      'ConnectivityService ready (${quality.value.name})',
      tag: 'connectivity',
    );
    return this;
  }

  /// Re-checks reachability on demand, for a pull-to-refresh or a retry button.
  Future<bool> refresh() async {
    final bool connected = await networkInfo.isConnected;
    if (!connected) {
      quality.value = ConnectionQuality.offline;
    }
    connectionTypes.assignAll(await networkInfo.connectionTypes);
    return connected;
  }

  /// Human description of the active connection, for the diagnostics screen.
  String get connectionLabel {
    if (connectionTypes.isEmpty ||
        connectionTypes.every(
          (ConnectivityResult result) => result == ConnectivityResult.none,
        )) {
      return 'No connection';
    }
    return connectionTypes
        .where((ConnectivityResult result) => result != ConnectivityResult.none)
        .map(_describe)
        .join(', ');
  }

  String _describe(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.satellite:
        return 'Satellite';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'None';
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _onRestored.close();
    networkInfo.dispose();
    super.onClose();
  }
}
