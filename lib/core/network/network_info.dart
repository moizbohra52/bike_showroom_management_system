import 'dart:async';

import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Reachability state of the device.
///
/// `connectivity_plus` reports whether an *interface* is up, which is not the
/// same as the internet being reachable — a captive portal, a VPN that has
/// dropped, or a showroom Wi-Fi with no upstream all report "connected". The
/// distinction matters here because the sync engine must not start a replay
/// pass against a network that will fail every request.
enum ConnectionQuality {
  /// No interface is up.
  offline,

  /// An interface is up but the backend has not been confirmed reachable.
  unverified,

  /// The backend answered recently.
  online,
}

/// Wraps connectivity detection behind an interface the rest of the app can
/// depend on, so the plugin can be swapped and tests can fake it.
abstract class NetworkInfo {
  /// Whether an interface is currently up.
  Future<bool> get isConnected;

  /// Best current assessment, combining interface state with the outcome of
  /// recent real requests.
  ConnectionQuality get quality;

  /// Emits whenever the assessment changes.
  Stream<ConnectionQuality> get onQualityChanged;

  /// The active interface types, for display in diagnostics.
  Future<List<ConnectivityResult>> get connectionTypes;

  /// Called by the API layer after a request completes, so reachability is
  /// inferred from traffic that was going to happen anyway rather than from
  /// extra polling.
  void reportSuccess();

  /// Called by the API layer when a request failed for a transport reason.
  void reportFailure();

  Future<void> initialise();

  Future<void> dispose();
}

/// Default implementation backed by `connectivity_plus`.
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  final StreamController<ConnectionQuality> _qualityController =
      StreamController<ConnectionQuality>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectionQuality _quality = ConnectionQuality.unverified;

  /// Consecutive transport failures. A single failure could be one bad
  /// endpoint, so the state only degrades after a couple in a row.
  int _consecutiveFailures = 0;

  static const int _failureThreshold = 2;

  @override
  ConnectionQuality get quality => _quality;

  @override
  Stream<ConnectionQuality> get onQualityChanged => _qualityController.stream;

  @override
  Future<void> initialise() async {
    final List<ConnectivityResult> initial = await _connectivity
        .checkConnectivity();
    _applyInterfaceState(initial);

    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyInterfaceState,
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warning(
          'Connectivity stream error',
          tag: 'network',
          error: error,
        );
      },
    );
  }

  void _applyInterfaceState(List<ConnectivityResult> results) {
    final bool hasInterface =
        results.isNotEmpty &&
        !results.every(
          (ConnectivityResult result) => result == ConnectivityResult.none,
        );

    final ConnectionQuality next;
    if (!hasInterface) {
      next = ConnectionQuality.offline;
    } else if (_quality == ConnectionQuality.online) {
      // An interface change while already verified keeps the verified state
      // until a request actually fails.
      next = ConnectionQuality.online;
    } else {
      next = ConnectionQuality.unverified;
    }

    if (!hasInterface) {
      _consecutiveFailures = 0;
    }
    _setQuality(next);
  }

  void _setQuality(ConnectionQuality next) {
    if (_quality == next) {
      return;
    }
    _quality = next;
    AppLogger.info(
      'Connection quality changed to ${next.name}',
      tag: 'network',
    );
    if (!_qualityController.isClosed) {
      _qualityController.add(next);
    }
  }

  @override
  Future<bool> get isConnected async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.isNotEmpty &&
        !results.every(
          (ConnectivityResult result) => result == ConnectivityResult.none,
        );
  }

  @override
  Future<List<ConnectivityResult>> get connectionTypes =>
      _connectivity.checkConnectivity();

  @override
  void reportSuccess() {
    _consecutiveFailures = 0;
    _setQuality(ConnectionQuality.online);
  }

  @override
  void reportFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failureThreshold) {
      // The interface may still be up; what matters is that the backend is
      // not answering, so treat it as offline for queueing purposes.
      _setQuality(ConnectionQuality.offline);
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _qualityController.close();
  }
}
