import 'dart:convert';
import 'dart:math';

import 'package:bike_showroom_management_system/core/constants/storage_keys.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value storage, split by sensitivity.
///
/// ## The split, and why it is enforced here
///
/// `SharedPreferences` is a plain file (or `localStorage` on web) readable by
/// anything running as the same user. It therefore holds only UI preferences.
/// Anything that could be used to impersonate the user goes to the platform
/// secure store via [flutter_secure_storage]. Putting a token in the wrong
/// tier is a real vulnerability, so the sensitive API is deliberately narrow
/// and separate rather than a flag on a general-purpose setter.
///
/// Passwords are never persisted in either tier.
class StorageService extends GetxService {
  StorageService({
    SharedPreferences? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _injectedPreferences = preferences,
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  final SharedPreferences? _injectedPreferences;
  final FlutterSecureStorage _secureStorage;

  SharedPreferences? _preferences;

  SharedPreferences get preferences {
    final SharedPreferences? instance = _preferences ?? _injectedPreferences;
    if (instance == null) {
      throw StateError(
        'StorageService.init() must complete before preferences are read.',
      );
    }
    return instance;
  }

  /// Resolves the service once so `Get.find` is not repeated at call sites.
  static StorageService get instance => Get.find<StorageService>();

  Future<StorageService> init() async {
    _preferences =
        _injectedPreferences ?? await SharedPreferences.getInstance();
    AppLogger.debug('StorageService ready', tag: 'storage');
    return this;
  }

  // ------------------------------------------------------- plain preferences

  String? getString(String key) => preferences.getString(key);

  Future<bool> setString(String key, String value) =>
      preferences.setString(key, value);

  bool getBool(String key, {bool defaultValue = false}) =>
      preferences.getBool(key) ?? defaultValue;

  Future<bool> setBool(String key, {required bool value}) =>
      preferences.setBool(key, value);

  int getInt(String key, {int defaultValue = 0}) =>
      preferences.getInt(key) ?? defaultValue;

  Future<bool> setInt(String key, int value) => preferences.setInt(key, value);

  double getDouble(String key, {double defaultValue = 0}) =>
      preferences.getDouble(key) ?? defaultValue;

  Future<bool> setDouble(String key, double value) =>
      preferences.setDouble(key, value);

  List<String> getStringList(String key) =>
      preferences.getStringList(key) ?? const <String>[];

  Future<bool> setStringList(String key, List<String> value) =>
      preferences.setStringList(key, value);

  bool containsKey(String key) => preferences.containsKey(key);

  Future<bool> remove(String key) => preferences.remove(key);

  /// Reads a JSON object written by [setJson].
  ///
  /// Returns null rather than throwing on corrupt data: a preference file that
  /// was half-written during a crash must not prevent the app from starting.
  Map<String, Object?>? getJson(String key) {
    final String? raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, Object?>.from(decoded);
      }
      return null;
    } on FormatException catch (error) {
      AppLogger.warning(
        'Discarding corrupt preference "$key"',
        tag: 'storage',
        error: error,
      );
      preferences.remove(key);
      return null;
    }
  }

  Future<bool> setJson(String key, Map<String, Object?> value) =>
      preferences.setString(key, jsonEncode(value));

  // ------------------------------------------------------------ typed helpers

  String? get themeMode => getString(PrefKeys.themeMode);
  Future<bool> setThemeMode(String mode) => setString(PrefKeys.themeMode, mode);

  String? get accentColor => getString(PrefKeys.accentColor);
  Future<bool> setAccentColor(String name) =>
      setString(PrefKeys.accentColor, name);

  String? get locale => getString(PrefKeys.locale);
  Future<bool> setLocale(String code) => setString(PrefKeys.locale, code);

  /// The showroom the user last had selected in the switcher.
  ///
  /// This is a UI convenience only. It is re-validated against the user's
  /// actual assignments on every sign-in, and Row Level Security independently
  /// rejects any query for a showroom they cannot access, so tampering with
  /// this value grants nothing.
  String? get selectedShowroomId => getString(PrefKeys.selectedShowroomId);
  Future<bool> setSelectedShowroomId(String id) =>
      setString(PrefKeys.selectedShowroomId, id);
  Future<bool> clearSelectedShowroom() => remove(PrefKeys.selectedShowroomId);

  bool get onboardingComplete => getBool(PrefKeys.onboardingComplete);
  Future<bool> setOnboardingComplete({required bool value}) =>
      setBool(PrefKeys.onboardingComplete, value: value);

  bool get sidebarCollapsed => getBool(PrefKeys.sidebarCollapsed);
  Future<bool> setSidebarCollapsed({required bool value}) =>
      setBool(PrefKeys.sidebarCollapsed, value: value);

  DateTime? get lastSyncedAt {
    final String? raw = getString(PrefKeys.lastSyncedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<bool> setLastSyncedAt(DateTime value) =>
      setString(PrefKeys.lastSyncedAt, value.toIso8601String());

  String? get rememberedEmail => getString(PrefKeys.rememberedEmail);
  Future<bool> setRememberedEmail(String email) =>
      setString(PrefKeys.rememberedEmail, email);
  Future<bool> clearRememberedEmail() => remove(PrefKeys.rememberedEmail);

  double get textScaleFactor =>
      getDouble(PrefKeys.textScaleFactor, defaultValue: 1);
  Future<bool> setTextScaleFactor(double value) =>
      setDouble(PrefKeys.textScaleFactor, value);

  bool get compactDensity => getBool(PrefKeys.compactDensity);
  Future<bool> setCompactDensity({required bool value}) =>
      setBool(PrefKeys.compactDensity, value: value);

  /// Persisted column visibility and ordering for a data table.
  Map<String, Object?>? tablePreference(String tableId) =>
      getJson(PrefKeys.tablePreference(tableId));

  Future<bool> setTablePreference(String tableId, Map<String, Object?> value) =>
      setJson(PrefKeys.tablePreference(tableId), value);

  /// Persisted filter selections for a list screen.
  Map<String, Object?>? filterPreference(String screenId) =>
      getJson(PrefKeys.filterPreference(screenId));

  Future<bool> setFilterPreference(
    String screenId,
    Map<String, Object?> value,
  ) => setJson(PrefKeys.filterPreference(screenId), value);

  Future<bool> clearFilterPreference(String screenId) =>
      remove(PrefKeys.filterPreference(screenId));

  int? pageSizeFor(String screenId) =>
      preferences.getInt(PrefKeys.pageSize(screenId));

  Future<bool> setPageSizeFor(String screenId, int size) =>
      setInt(PrefKeys.pageSize(screenId), size);

  // ------------------------------------------------------------ secure store

  /// Writes to the platform secure store.
  ///
  /// Secure storage is genuinely unavailable on some configurations — a Linux
  /// desktop without a keyring, a locked keychain, a browser with storage
  /// blocked. Every access is therefore guarded, and a failure degrades the
  /// feature rather than crashing the app.
  Future<void> writeSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on Object catch (error) {
      AppLogger.warning(
        'Secure write failed for "$key"',
        tag: 'storage',
        error: error,
      );
    }
  }

  Future<String?> readSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } on Object catch (error) {
      AppLogger.warning(
        'Secure read failed for "$key"',
        tag: 'storage',
        error: error,
      );
      return null;
    }
  }

  Future<void> deleteSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on Object catch (error) {
      AppLogger.warning(
        'Secure delete failed for "$key"',
        tag: 'storage',
        error: error,
      );
    }
  }

  Future<void> clearSecure() async {
    try {
      await _secureStorage.deleteAll();
    } on Object catch (error) {
      AppLogger.warning('Secure clear failed', tag: 'storage', error: error);
    }
  }

  Future<String?> get fcmToken => readSecure(SecureKeys.fcmToken);
  Future<void> setFcmToken(String token) =>
      writeSecure(SecureKeys.fcmToken, token);
  Future<void> clearFcmToken() => deleteSecure(SecureKeys.fcmToken);

  /// A stable per-installation identifier, used to name this device against an
  /// FCM token so the same physical device does not accumulate rows.
  ///
  /// Generated locally and never derived from a hardware identifier, which on
  /// modern platforms is unavailable and on older ones is a privacy problem.
  Future<String> deviceId() async {
    final String? existing = await readSecure(SecureKeys.deviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String generated =
        'dev_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_'
        '${identityHashCode(this).toRadixString(36)}';
    await writeSecure(SecureKeys.deviceId, generated);
    return generated;
  }

  /// Encryption key for the Hive boxes holding customer data.
  ///
  /// Created on first launch and kept in the secure store. If it is ever lost
  /// the encrypted boxes become unreadable, which is acceptable: they are a
  /// cache and a replayable queue, not a system of record.
  Future<List<int>> hiveCipherKey() async {
    final String? existing = await readSecure(SecureKeys.hiveCipherKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        return base64Url.decode(existing);
      } on FormatException {
        AppLogger.warning(
          'Stored Hive cipher key was malformed; regenerating',
          tag: 'storage',
        );
      }
    }
    final List<int> key = _generateCipherKey();
    await writeSecure(SecureKeys.hiveCipherKey, base64Url.encode(key));
    return key;
  }

  List<int> _generateCipherKey() {
    // Hive expects 32 bytes. `Random.secure()` is the platform CSPRNG; the
    // default `Random()` is a seeded PRNG and would be unacceptable here.
    final Random random = Random.secure();
    return List<int>.generate(
      32,
      (int _) => random.nextInt(256),
      growable: false,
    );
  }

  // ------------------------------------------------------------- sign-out

  /// Clears everything tied to the signed-in user while keeping device-level
  /// preferences such as theme and language.
  ///
  /// The remembered email is kept deliberately: it is a convenience with no
  /// security value, since it is not a credential.
  Future<void> clearUserScopedData() async {
    await Future.wait<void>(<Future<void>>[
      remove(PrefKeys.selectedShowroomId),
      remove(PrefKeys.lastKnownRoute),
      remove(PrefKeys.lastSyncedAt),
      deleteSecure(SecureKeys.supabaseSession),
      deleteSecure(SecureKeys.fcmToken),
    ]);
    AppLogger.info('Cleared user-scoped local storage', tag: 'storage');
  }

  /// Full wipe, including preferences. Used by "reset application".
  Future<void> clearAll() async {
    await preferences.clear();
    await clearSecure();
    AppLogger.warning('Cleared all local storage', tag: 'storage');
  }
}
