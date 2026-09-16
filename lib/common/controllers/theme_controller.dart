import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Owns theme mode, accent colour, locale and text scale.
///
/// All four are device preferences rather than account settings, so they live
/// in `SharedPreferences` and survive a sign-out. They are applied by
/// rebuilding `GetMaterialApp`, which is why this controller is permanent.
class ThemeController extends GetxController {
  ThemeController({required this.storageService});

  final StorageService storageService;

  static ThemeController get instance => Get.find<ThemeController>();

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<Color> accentColor = Rx<Color>(AppColors.primary);
  final Rx<Locale> locale = const Locale('en', 'IN').obs;
  final RxDouble textScale = 1.0.obs;
  final RxBool compactDensity = false.obs;

  ThemeData get lightTheme => AppTheme.light(accent: accentColor.value);
  ThemeData get darkTheme => AppTheme.dark(accent: accentColor.value);

  /// Resolves the effective brightness, taking the platform into account when
  /// the mode is `system`. Needed by widgets that pick a token directly, such
  /// as the status colours and shadows.
  bool get isDarkMode {
    switch (themeMode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return Get.mediaQuery.platformBrightness == Brightness.dark;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  void _restore() {
    final String? storedMode = storageService.themeMode;
    themeMode.value = _parseThemeMode(storedMode);

    accentColor.value = AppTheme.accentFromName(storageService.accentColor);

    final String? storedLocale = storageService.locale;
    if (storedLocale != null && storedLocale.isNotEmpty) {
      locale.value = _parseLocale(storedLocale);
    }

    // Clamped: an extreme scale persisted from a previous version would make
    // the application unusable with no way to reach Settings and fix it.
    textScale.value = storageService.textScaleFactor.clamp(0.8, 1.6);
    compactDensity.value = storageService.compactDensity;
  }

  static ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Locale _parseLocale(String value) {
    final List<String> parts = value.split('_');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts.first);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await storageService.setThemeMode(mode.name);
    Get.changeThemeMode(mode);
  }

  Future<void> toggleThemeMode() =>
      setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);

  Future<void> setAccent(String name) async {
    accentColor.value = AppTheme.accentFromName(name);
    await storageService.setAccentColor(name);
    // Both themes are rebuilt from the accent, so push whichever is active.
    Get.changeTheme(isDarkMode ? darkTheme : lightTheme);
  }

  Future<void> setLocale(Locale value) async {
    locale.value = value;
    await storageService.setLocale(
      value.countryCode == null
          ? value.languageCode
          : '${value.languageCode}_${value.countryCode}',
    );
    await Get.updateLocale(value);
  }

  Future<void> setTextScale(double value) async {
    final double clamped = value.clamp(0.8, 1.6);
    textScale.value = clamped;
    await storageService.setTextScaleFactor(clamped);
  }

  Future<void> setCompactDensity({required bool value}) async {
    compactDensity.value = value;
    await storageService.setCompactDensity(value: value);
  }

  /// Locales the application is built for. Hindi is declared so the
  /// architecture is exercised; its strings are added with the localisation
  /// pass described in the specification.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en', 'IN'),
    Locale('hi', 'IN'),
  ];

  static const Locale fallbackLocale = Locale('en', 'IN');

  /// Text scale actually applied, honouring the user preference while
  /// respecting the platform accessibility setting.
  ///
  /// The two are multiplied rather than one overriding the other: a user who
  /// has enlarged text system-wide should still get larger text here, and the
  /// in-app control adjusts relative to that. The product is clamped so a
  /// dense data table cannot become unreadable.
  TextScaler effectiveTextScaler(BuildContext context) {
    final TextScaler platform = MediaQuery.textScalerOf(context);
    final double combined = platform.scale(1) * textScale.value;
    return TextScaler.linear(combined.clamp(0.8, 2.0));
  }

  VisualDensity get visualDensity =>
      compactDensity.value ? VisualDensity.compact : VisualDensity.standard;

  /// Default page size preference for list screens.
  int pageSizeFor(String screenId) =>
      storageService.pageSizeFor(screenId) ?? AppConstants.defaultPageSize;
}
