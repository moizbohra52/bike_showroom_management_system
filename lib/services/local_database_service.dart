import 'dart:async';

import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/constants/storage_keys.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:get/get.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Contract for the offline store.
///
/// Feature code depends on this interface, never on Hive directly, so the
/// engine can be replaced (with SQLite, or with Drift) without touching a
/// repository. That was an explicit requirement, and it also makes the
/// repositories testable against an in-memory fake.
///
/// Records are plain `Map<String, Object?>` — the same JSON shape the network
/// returns — so no code generation or adapter registration is needed and a
/// schema change does not require a migration of the local store.
abstract class LocalDatabase {
  Future<void> initialise();

  /// Opens [boxName], encrypting it when [HiveBoxes.isEncrypted] says so.
  Future<void> openBox(String boxName);

  Future<void> put(String boxName, String key, Map<String, Object?> value);

  Future<void> putAll(
    String boxName,
    Map<String, Map<String, Object?>> entries,
  );

  Future<Map<String, Object?>?> get(String boxName, String key);

  Future<List<Map<String, Object?>>> getAll(String boxName);

  /// Rows matching [test]. Applied in Dart, so it is only appropriate for the
  /// bounded caches this application keeps, not for a full table scan.
  Future<List<Map<String, Object?>>> where(
    String boxName,
    bool Function(Map<String, Object?> row) test,
  );

  Future<int> count(String boxName);

  Future<bool> containsKey(String boxName, String key);

  Future<void> delete(String boxName, String key);

  Future<void> deleteAll(String boxName, Iterable<String> keys);

  Future<void> clearBox(String boxName);

  Future<void> clearAll();

  Future<List<String>> keys(String boxName);

  /// Emits whenever [boxName] changes, so a controller can react to a sync
  /// writing fresh rows underneath it.
  Stream<void> watch(String boxName);

  Future<void> close();
}

/// Hive-backed implementation.
class HiveLocalDatabase implements LocalDatabase {
  HiveLocalDatabase({required this.cipherKeyProvider});

  /// Supplies the 32-byte key for encrypted boxes. Injected rather than read
  /// directly so this class has no dependency on the storage service.
  final Future<List<int>> Function() cipherKeyProvider;

  final Map<String, Box<Map<dynamic, dynamic>>> _boxes =
      <String, Box<Map<dynamic, dynamic>>>{};

  HiveCipher? _cipher;
  bool _initialised = false;

  @override
  Future<void> initialise() async {
    if (_initialised) {
      return;
    }
    await Hive.initFlutter('bike_showroom');
    _initialised = true;
    AppLogger.debug('Hive initialised', tag: 'localdb');
  }

  Future<HiveCipher> _resolveCipher() async {
    _cipher ??= HiveAesCipher(await cipherKeyProvider());
    return _cipher!;
  }

  @override
  Future<void> openBox(String boxName) async {
    if (_boxes.containsKey(boxName)) {
      return;
    }
    await initialise();
    try {
      final Box<Map<dynamic, dynamic>> box =
          await Hive.openBox<Map<dynamic, dynamic>>(
            boxName,
            encryptionCipher: HiveBoxes.isEncrypted(boxName)
                ? await _resolveCipher()
                : null,
          );
      _boxes[boxName] = box;
    } on Object catch (error, stackTrace) {
      // A corrupt box, or one whose cipher key was rotated, would otherwise
      // make the app unopenable. The local store is a cache and a replayable
      // queue, so discarding it is recoverable; refusing to start is not.
      AppLogger.error(
        'Failed to open box "$boxName"; deleting and recreating',
        tag: 'localdb',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        await Hive.deleteBoxFromDisk(boxName);
        final Box<Map<dynamic, dynamic>> box =
            await Hive.openBox<Map<dynamic, dynamic>>(
              boxName,
              encryptionCipher: HiveBoxes.isEncrypted(boxName)
                  ? await _resolveCipher()
                  : null,
            );
        _boxes[boxName] = box;
      } on Object catch (fatal, fatalStack) {
        throw LocalDatabaseException(
          message: 'Local storage is unavailable.',
          cause: fatal,
          stackTrace: fatalStack,
        );
      }
    }
  }

  Future<Box<Map<dynamic, dynamic>>> _box(String boxName) async {
    if (!_boxes.containsKey(boxName)) {
      await openBox(boxName);
    }
    final Box<Map<dynamic, dynamic>>? box = _boxes[boxName];
    if (box == null || !box.isOpen) {
      throw LocalDatabaseException(
        message: 'Local storage "$boxName" is not open.',
      );
    }
    return box;
  }

  /// Hive returns `Map<dynamic, dynamic>` after a round trip to disk, so every
  /// read is normalised back to a typed map. Nested maps and lists are
  /// converted too, otherwise a `Map<dynamic, dynamic>` leaks into a model's
  /// `fromJson` and fails a cast at an unrelated call site.
  Map<String, Object?> _normalise(Map<dynamic, dynamic> raw) {
    final Map<String, Object?> result = <String, Object?>{};
    raw.forEach((Object? key, Object? value) {
      result[key.toString()] = _normaliseValue(value);
    });
    return result;
  }

  Object? _normaliseValue(Object? value) {
    if (value is Map) {
      return _normalise(value);
    }
    if (value is List) {
      return value.map(_normaliseValue).toList(growable: false);
    }
    return value;
  }

  @override
  Future<void> put(
    String boxName,
    String key,
    Map<String, Object?> value,
  ) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    await box.put(key, value);
  }

  @override
  Future<void> putAll(
    String boxName,
    Map<String, Map<String, Object?>> entries,
  ) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    await box.putAll(entries);
  }

  @override
  Future<Map<String, Object?>?> get(String boxName, String key) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    final Map<dynamic, dynamic>? raw = box.get(key);
    return raw == null ? null : _normalise(raw);
  }

  @override
  Future<List<Map<String, Object?>>> getAll(String boxName) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    return box.values.map(_normalise).toList(growable: false);
  }

  @override
  Future<List<Map<String, Object?>>> where(
    String boxName,
    bool Function(Map<String, Object?> row) test,
  ) async {
    final List<Map<String, Object?>> all = await getAll(boxName);
    return all.where(test).toList(growable: false);
  }

  @override
  Future<int> count(String boxName) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    return box.length;
  }

  @override
  Future<bool> containsKey(String boxName, String key) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    return box.containsKey(key);
  }

  @override
  Future<void> delete(String boxName, String key) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    await box.delete(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    await box.deleteAll(keys);
  }

  @override
  Future<void> clearBox(String boxName) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    await box.clear();
  }

  @override
  Future<void> clearAll() async {
    for (final Box<Map<dynamic, dynamic>> box in _boxes.values) {
      if (box.isOpen) {
        await box.clear();
      }
    }
  }

  @override
  Future<List<String>> keys(String boxName) async {
    final Box<Map<dynamic, dynamic>> box = await _box(boxName);
    return box.keys.map((Object? key) => key.toString()).toList();
  }

  @override
  Stream<void> watch(String boxName) {
    final Box<Map<dynamic, dynamic>>? box = _boxes[boxName];
    if (box == null) {
      // Box not open yet; open it and then forward events.
      return Stream<void>.fromFuture(
        openBox(boxName),
      ).asyncExpand((_) => _boxes[boxName]!.watch());
    }
    return box.watch();
  }

  @override
  Future<void> close() async {
    for (final Box<Map<dynamic, dynamic>> box in _boxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _boxes.clear();
  }
}

/// In-memory implementation for tests and for a build with offline disabled.
class InMemoryLocalDatabase implements LocalDatabase {
  final Map<String, Map<String, Map<String, Object?>>> _store =
      <String, Map<String, Map<String, Object?>>>{};

  final Map<String, StreamController<void>> _watchers =
      <String, StreamController<void>>{};

  Map<String, Map<String, Object?>> _box(String boxName) =>
      _store.putIfAbsent(boxName, () => <String, Map<String, Object?>>{});

  void _notify(String boxName) {
    // Borrowed reference: the controller is owned by `_watchers` and closed by
    // `close()`, so this function must not close it.
    // ignore: close_sinks
    final StreamController<void>? controller = _watchers[boxName];
    if (controller != null && !controller.isClosed) {
      controller.add(null);
    }
  }

  @override
  Future<void> initialise() async {}

  @override
  Future<void> openBox(String boxName) async => _box(boxName);

  @override
  Future<void> put(
    String boxName,
    String key,
    Map<String, Object?> value,
  ) async {
    _box(boxName)[key] = Map<String, Object?>.from(value);
    _notify(boxName);
  }

  @override
  Future<void> putAll(
    String boxName,
    Map<String, Map<String, Object?>> entries,
  ) async {
    _box(boxName).addAll(entries);
    _notify(boxName);
  }

  @override
  Future<Map<String, Object?>?> get(String boxName, String key) async {
    final Map<String, Object?>? value = _box(boxName)[key];
    return value == null ? null : Map<String, Object?>.from(value);
  }

  @override
  Future<List<Map<String, Object?>>> getAll(String boxName) async => _box(
    boxName,
  ).values.map(Map<String, Object?>.from).toList(growable: false);

  @override
  Future<List<Map<String, Object?>>> where(
    String boxName,
    bool Function(Map<String, Object?> row) test,
  ) async => (await getAll(boxName)).where(test).toList(growable: false);

  @override
  Future<int> count(String boxName) async => _box(boxName).length;

  @override
  Future<bool> containsKey(String boxName, String key) async =>
      _box(boxName).containsKey(key);

  @override
  Future<void> delete(String boxName, String key) async {
    _box(boxName).remove(key);
    _notify(boxName);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    final Map<String, Map<String, Object?>> box = _box(boxName);
    for (final String key in keys) {
      box.remove(key);
    }
    _notify(boxName);
  }

  @override
  Future<void> clearBox(String boxName) async {
    _box(boxName).clear();
    _notify(boxName);
  }

  @override
  Future<void> clearAll() async {
    for (final String boxName in _store.keys) {
      _store[boxName]!.clear();
      _notify(boxName);
    }
  }

  @override
  Future<List<String>> keys(String boxName) async =>
      _box(boxName).keys.toList();

  @override
  Stream<void> watch(String boxName) {
    // The controller is retained in `_watchers` and closed by `close()`; the
    // `close_sinks` lint cannot follow ownership through a collection.
    // ignore: close_sinks
    final StreamController<void> controller = _watchers.putIfAbsent(
      boxName,
      StreamController<void>.broadcast,
    );
    return controller.stream;
  }

  @override
  Future<void> close() async {
    for (final StreamController<void> controller in _watchers.values) {
      await controller.close();
    }
    _watchers.clear();
    _store.clear();
  }
}

/// GetX service wrapper, with cache-freshness bookkeeping layered on top.
class LocalDatabaseService extends GetxService {
  LocalDatabaseService({LocalDatabase? database}) : _injected = database;

  final LocalDatabase? _injected;

  late final LocalDatabase database;

  static LocalDatabaseService get instance => Get.find<LocalDatabaseService>();

  Future<LocalDatabaseService> init() async {
    database =
        _injected ??
        HiveLocalDatabase(
          cipherKeyProvider: () => StorageService.instance.hiveCipherKey(),
        );
    await database.initialise();

    // The queue and the session snapshot are needed on the very first frame,
    // so they are opened eagerly. Everything else opens on first use.
    await database.openBox(HiveBoxes.syncQueue);
    await database.openBox(HiveBoxes.session);
    await database.openBox(HiveBoxes.cacheMeta);

    AppLogger.debug('LocalDatabaseService ready', tag: 'localdb');
    return this;
  }

  // ---------------------------------------------------------- cache metadata

  /// Records that [cacheKey] was just refreshed.
  Future<void> markCached(String cacheKey) => database.put(
    HiveBoxes.cacheMeta,
    cacheKey,
    <String, Object?>{'fetched_at': DateTime.now().toIso8601String()},
  );

  Future<DateTime?> cachedAt(String cacheKey) async {
    final Map<String, Object?>? row = await database.get(
      HiveBoxes.cacheMeta,
      cacheKey,
    );
    final Object? raw = row?['fetched_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  /// Whether a cached collection is still within its freshness window.
  Future<bool> isFresh(
    String cacheKey, {
    Duration ttl = AppConstants.cacheTtl,
  }) async {
    final DateTime? fetchedAt = await cachedAt(cacheKey);
    if (fetchedAt == null) {
      return false;
    }
    return DateTime.now().difference(fetchedAt) < ttl;
  }

  /// Drops the caches that belong to the signed-in user, leaving reference
  /// data (products, brands) which is not user-specific.
  Future<void> clearUserScopedCaches() async {
    for (final String boxName in HiveBoxes.clearOnSignOut) {
      await database.clearBox(boxName);
    }
    AppLogger.info('Cleared user-scoped local caches', tag: 'localdb');
  }

  @override
  void onClose() {
    database.close();
    super.onClose();
  }
}
