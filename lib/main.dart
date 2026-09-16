import 'dart:async';

import 'package:bike_showroom_management_system/common/controllers/theme_controller.dart';
import 'package:bike_showroom_management_system/config/app_config.dart';
import 'package:bike_showroom_management_system/config/environment_config.dart';
import 'package:bike_showroom_management_system/config/supabase_config.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:bike_showroom_management_system/routes/app_pages.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

Future<void> main() async {
  // `runZonedGuarded` wraps the whole application so an asynchronous error
  // escaping a `Future` is still reported rather than silently swallowed.
  // Flutter's own handler only covers errors raised inside the framework.
  //
  // Not awaited: the returned future completes only when the zone's body
  // finishes, and the body's last act is `runApp`, which never returns while
  // the application is alive.
  unawaited(
    runZonedGuarded<Future<void>>(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        _installErrorHandlers();

        AppLogger.info(
          'Starting ${AppConstants.appLegalName}',
          tag: 'startup',
          context: EnvironmentConfig.diagnostics,
        );

        // A build with no backend configured cannot do anything useful, and
        // failing here with a clear message is far better than a screenful of
        // network errors later.
        if (!EnvironmentConfig.isConfigured) {
          AppLogger.critical(
            'Missing configuration: ${EnvironmentConfig.missingKeys.join(', ')}',
            tag: 'startup',
          );
          runApp(StartupFailureApp(missingKeys: EnvironmentConfig.missingKeys));
          return;
        }

        try {
          await SupabaseConfig.initialise();
        } on StateError catch (error) {
          // Covers the service-role-key guard and a malformed URL, both of which
          // are configuration faults the operator must fix.
          AppLogger.critical(
            'Supabase initialisation refused',
            tag: 'startup',
            error: error,
          );
          runApp(StartupFailureApp(message: error.message));
          return;
        }

        await AppConfig.initialiseServices();

        runApp(const BikeShowroomApp());
      },
      (Object error, StackTrace stackTrace) {
        AppLogger.critical(
          'Uncaught asynchronous error',
          tag: 'zone',
          error: error,
          stackTrace: stackTrace,
        );
      },
    ),
  );
}

/// Routes framework and platform errors into the application logger.
void _installErrorHandlers() {
  final FlutterExceptionHandler? original = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter framework error',
      tag: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
      context: <String, Object?>{
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
    // Keep the default behaviour in debug so the red screen still appears.
    if (kDebugMode) {
      original?.call(details);
    }
  };

  // Errors from the platform side that never reach a Dart zone.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppLogger.critical(
      'Unhandled platform error',
      tag: 'platform',
      error: error,
      stackTrace: stackTrace,
    );
    // Returning true marks it handled, preventing a hard crash on a
    // recoverable error in a background isolate.
    return true;
  };
}

/// The application shell.
class BikeShowroomApp extends StatelessWidget {
  const BikeShowroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    // Observed so a change to theme, accent, locale or text scale rebuilds the
    // whole application rather than requiring a restart.
    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,

        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        unknownRoute: AppPages.unknownRoute,

        theme: themeController.lightTheme,
        darkTheme: themeController.darkTheme,
        themeMode: themeController.themeMode.value,

        locale: themeController.locale.value,
        fallbackLocale: ThemeController.fallbackLocale,
        supportedLocales: ThemeController.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        defaultTransition: Transition.cupertino,
        transitionDuration: const Duration(milliseconds: 220),

        builder: (BuildContext context, Widget? child) {
          // Applies the combined text scale and, on desktop and web, lets the
          // application be driven entirely from the keyboard.
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: themeController.effectiveTextScaler(context),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

/// Minimal application shown when the build cannot start.
///
/// Deliberately depends on nothing but Flutter itself, so it still renders
/// when service initialisation is exactly what failed.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    this.missingKeys = const <String>[],
    this.message,
    super.key,
  });

  final List<String> missingKeys;
  final String? message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppConstants.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.settings_suggest_outlined,
                  size: 44,
                  color: AppColors.danger,
                ),
                AppSpacing.gapXl,
                Text(
                  'This build is not configured',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapMd,
                Text(
                  message ??
                      'The application was built without the values it '
                          'needs to reach its backend.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (missingKeys.isNotEmpty) ...<Widget>[
                  AppSpacing.gapLg,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.lightSurfaceMuted,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Missing values',
                          style: AppTypography.labelMedium,
                        ),
                        AppSpacing.gapSm,
                        ...missingKeys.map(
                          (String key) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xxs,
                            ),
                            child: Text(key, style: AppTypography.mono),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  Text(
                    'Rebuild with the required --dart-define values. '
                    'See docs/DEPLOYMENT.md.',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
