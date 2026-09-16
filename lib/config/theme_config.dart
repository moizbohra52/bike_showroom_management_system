/// Design tokens and the assembled Material themes.
///
/// Widgets must read colour, spacing, radius and type from the classes here,
/// never from inline literals. Two reasons beyond consistency: the dark theme
/// is derived from the same token names, so a hardcoded colour silently breaks
/// it, and the accent colour is user-configurable at runtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colour tokens.
///
/// Named by role rather than by hue, so that a palette change does not require
/// renaming anything. Raw hues are private; only the semantic names are used.
class AppColors {
  const AppColors._();

  // ------------------------------------------------------------ brand hues
  /// Default accent. Showrooms can override this per deployment.
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3F7CEA);
  static const Color primaryDark = Color(0xFF1039A0);

  /// Selectable accents offered in Settings.
  static const Map<String, Color> accentPalette = <String, Color>{
    'Indigo': Color(0xFF1A56DB),
    'Teal': Color(0xFF0F766E),
    'Violet': Color(0xFF6D28D9),
    'Amber': Color(0xFFB45309),
    'Crimson': Color(0xFFBE123C),
    'Slate': Color(0xFF334155),
  };

  // ------------------------------------------------------------- feedback
  static const Color success = Color(0xFF15803D);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0369A1);
  static const Color infoSurface = Color(0xFFE0F2FE);

  // --------------------------------------------------------- light surfaces
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF1F3F6);
  static const Color lightBorder = Color(0xFFE2E5EA);
  static const Color lightBorderStrong = Color(0xFFCBD2DB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextTertiary = Color(0xFF6B7280);
  static const Color lightTextDisabled = Color(0xFF9CA3AF);

  // ---------------------------------------------------------- dark surfaces
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF151B28);
  static const Color darkSurfaceMuted = Color(0xFF1E2635);
  static const Color darkBorder = Color(0xFF2A3444);
  static const Color darkBorderStrong = Color(0xFF3B475A);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFB6BECB);
  static const Color darkTextTertiary = Color(0xFF8A94A6);
  static const Color darkTextDisabled = Color(0xFF5D6675);

  /// Categorical series for charts. Ordered for maximum adjacent contrast and
  /// chosen to stay distinguishable for the common forms of colour blindness.
  static const List<Color> chartSeries = <Color>[
    Color(0xFF1A56DB),
    Color(0xFF0F766E),
    Color(0xFFB45309),
    Color(0xFF6D28D9),
    Color(0xFFBE123C),
    Color(0xFF0369A1),
    Color(0xFF4D7C0F),
    Color(0xFF9333EA),
  ];

  /// Resolves the display colour for a business status string.
  ///
  /// Centralised here so a status badge looks identical wherever it appears.
  static Color forStatus(String? status, {required bool isDark}) {
    switch (status?.toUpperCase()) {
      // Healthy / settled
      case 'ACTIVE':
      case 'AVAILABLE':
      case 'PAID':
      case 'COMPLETED':
      case 'DELIVERED':
      case 'APPROVED':
      case 'CONFIRMED':
      case 'RECEIVED':
      case 'SUCCESS':
      case 'SETTLED':
        return success;

      // In flight / needs attention soon
      case 'PENDING':
      case 'PENDING_APPROVAL':
      case 'DUE':
      case 'UPCOMING':
      case 'BOOKED':
      case 'IN_PROGRESS':
      case 'IN_TRANSIT':
      case 'RESERVED':
      case 'PARTIAL':
      case 'PARTIALLY_PAID':
      case 'PARTIALLY_RECEIVED':
      case 'SUBMITTED':
      case 'UNDER_REVIEW':
      case 'SYNCING':
        return warning;

      // Broken / overdue
      case 'OVERDUE':
      case 'EXPIRED':
      case 'FAILED':
      case 'REJECTED':
      case 'DAMAGED':
      case 'DEFAULTED':
      case 'VOIDED':
      case 'STOLEN':
      case 'CONFLICT':
        return danger;

      // Informational
      case 'DRAFT':
      case 'DEMO':
      case 'ISSUED':
      case 'SENT':
      case 'ORDERED':
      case 'WAITING_FOR_PARTS':
      case 'EXPIRING_SOON':
        return info;

      // Terminal but not an error
      case 'CANCELLED':
      case 'INACTIVE':
      case 'REVERSED':
      case 'REFUNDED':
      case 'CLOSED':
      case 'SOLD':
      case 'USED':
      case 'RETURNED':
      case 'SUSPENDED':
        return isDark ? darkTextTertiary : lightTextTertiary;

      default:
        return isDark ? darkTextSecondary : lightTextSecondary;
    }
  }

  /// Low-opacity companion for a status chip background.
  static Color statusSurface(String? status, {required bool isDark}) =>
      forStatus(status, isDark: isDark).withValues(alpha: isDark ? 0.18 : 0.12);
}

/// Spacing scale, in logical pixels.
///
/// A 4-point scale. Using the scale rather than arbitrary numbers is what
/// makes density switching and the compact mobile layout possible.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard page padding per platform class.
  static const EdgeInsets pageMobile = EdgeInsets.all(lg);
  static const EdgeInsets pageDesktop = EdgeInsets.symmetric(
    horizontal: xxxl,
    vertical: xxl,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );

  /// Vertical gap widgets, to avoid `SizedBox(height: ...)` everywhere.
  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);
  static const Widget gapXxl = SizedBox(height: xxl);

  static const Widget hGapXs = SizedBox(width: xs);
  static const Widget hGapSm = SizedBox(width: sm);
  static const Widget hGapMd = SizedBox(width: md);
  static const Widget hGapLg = SizedBox(width: lg);
  static const Widget hGapXl = SizedBox(width: xl);
}

/// Corner radii.
class AppRadius {
  const AppRadius._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Bottom-sheet corners: rounded at the top only.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Elevation shadows.
///
/// Defined explicitly rather than using Material elevation so that the dark
/// theme can use a tighter, lower-opacity shadow — a large soft shadow on a
/// near-black surface reads as smudge rather than lift.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card({bool isDark = false}) => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.05),
      blurRadius: isDark ? 6 : 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> raised({bool isDark = false}) => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.08),
      blurRadius: isDark ? 12 : 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> overlay({bool isDark = false}) => <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.14),
      blurRadius: isDark ? 20 : 32,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Type scale.
///
/// Sizes are deliberately modest: this is a data-dense back-office application
/// where a manager scans tables, not a marketing page. Line heights are set
/// explicitly so rows in a dense table stay on a predictable rhythm.
class AppTypography {
  const AppTypography._();

  /// Tabular figures matter for money columns — proportional digits make a
  /// column of amounts fail to align on the decimal point.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.5,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  /// Monetary figures. Always tabular.
  static const TextStyle money = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    fontFeatures: tabularFigures,
  );

  static const TextStyle moneyLarge = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    fontFeatures: tabularFigures,
    letterSpacing: -0.3,
  );

  /// Chassis and engine numbers, where character shape must be unambiguous.
  static const TextStyle mono = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Consolas', 'Menlo', 'Courier New'],
    letterSpacing: 0.3,
  );
}

/// Assembles the Material themes from the tokens above.
class AppTheme {
  const AppTheme._();

  static ThemeData light({Color accent = AppColors.primary}) =>
      _build(brightness: Brightness.light, accent: accent);

  static ThemeData dark({Color accent = AppColors.primary}) =>
      _build(brightness: Brightness.dark, accent: accent);

  static ThemeData _build({
    required Brightness brightness,
    required Color accent,
  }) {
    final bool isDark = brightness == Brightness.dark;

    final Color background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color surface = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color surfaceMuted = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.lightSurfaceMuted;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color textDisabled = isDark
        ? AppColors.darkTextDisabled
        : AppColors.lightTextDisabled;

    // Derive the scheme from the accent so a runtime accent change recolours
    // the whole application, then pin the surfaces to our own tokens because
    // Material's generated surface tints are too saturated for a dense
    // back-office UI.
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? _lighten(accent, 0.18) : accent,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainerLowest: background,
          surfaceContainerLow: surfaceMuted,
          surfaceContainer: surface,
          surfaceContainerHigh: surfaceMuted,
          outline: border,
          outlineVariant: border,
          error: isDark ? _lighten(AppColors.danger, 0.22) : AppColors.danger,
        );

    final TextTheme textTheme = TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: textPrimary),
      displayMedium: AppTypography.displayMedium.copyWith(color: textPrimary),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: textPrimary),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: textPrimary),
      titleLarge: AppTypography.titleLarge.copyWith(color: textPrimary),
      titleMedium: AppTypography.titleMedium.copyWith(color: textPrimary),
      titleSmall: AppTypography.titleSmall.copyWith(color: textSecondary),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: textPrimary),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: textPrimary),
      bodySmall: AppTypography.bodySmall.copyWith(color: textSecondary),
      labelLarge: AppTypography.labelLarge.copyWith(color: textPrimary),
      labelMedium: AppTypography.labelMedium.copyWith(color: textSecondary),
      labelSmall: AppTypography.labelSmall.copyWith(color: textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      dividerColor: border,
      hintColor: textDisabled,
      splashFactory: InkSparkle.splashFactory,

      // Desktop and web need a visible focus ring for keyboard navigation.
      focusColor: scheme.primary.withValues(alpha: 0.12),
      hoverColor: scheme.primary.withValues(alpha: 0.05),

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: textPrimary),
        shape: Border(bottom: BorderSide(color: border)),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceMuted : surface,
        contentPadding: AppSpacing.fieldPadding,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: textSecondary),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: scheme.primary,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: textDisabled),
        errorStyle: AppTypography.bodySmall.copyWith(color: scheme.error),
        helperStyle: AppTypography.bodySmall.copyWith(color: textSecondary),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          side: BorderSide(color: border),
          textStyle: AppTypography.labelLarge,
          foregroundColor: textPrimary,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textSecondary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        side: BorderSide(color: border),
        labelStyle: AppTypography.labelMedium.copyWith(color: textPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: border),
        ),
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: textSecondary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
        dragHandleColor: border,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 22),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
        selectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: AppTypography.labelMedium.copyWith(
          color: textSecondary,
        ),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppTypography.labelSmall.copyWith(color: scheme.primary)
              : AppTypography.labelSmall.copyWith(color: textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textSecondary,
          ),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: AppSpacing.listTilePadding,
        iconColor: textSecondary,
        titleTextStyle: AppTypography.bodyMedium.copyWith(color: textPrimary),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: textSecondary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(surfaceMuted),
        headingTextStyle: AppTypography.labelMedium.copyWith(
          color: textSecondary,
        ),
        dataTextStyle: AppTypography.bodyMedium.copyWith(color: textPrimary),
        dividerThickness: 1,
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: AppSpacing.xxl,
        horizontalMargin: AppSpacing.lg,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: textSecondary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: border,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.lightTextPrimary : AppColors.darkSurface,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: AppTypography.bodySmall.copyWith(
          color: isDark ? AppColors.lightSurface : AppColors.darkTextPrimary,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceMuted : AppColors.lightTextPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? textPrimary : AppColors.lightSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        elevation: 0,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 3,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: BorderSide(color: border, width: 1.5),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? scheme.primary : surface,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: border),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: textPrimary),
      ),

      // Desktop/web: allow drag-scrolling with a mouse and always show
      // scrollbars, because hidden scrollbars in a dense table are unusable.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(
          isDark ? AppColors.darkBorderStrong : AppColors.lightBorderStrong,
        ),
        radius: const Radius.circular(AppRadius.pill),
        thickness: const WidgetStatePropertyAll<double>(8),
        interactive: true,
      ),

      visualDensity: VisualDensity.standard,
    );
  }

  /// Blends [color] towards white by [amount] (0..1).
  ///
  /// Accent colours chosen for a light background are too dark to read on the
  /// dark theme's near-black surfaces, so they are lifted rather than swapped
  /// for a different hue.
  static Color _lighten(Color color, double amount) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Resolves a stored accent name back to a colour, falling back to the
  /// default when the preference names an accent that no longer exists.
  static Color accentFromName(String? name) =>
      AppColors.accentPalette[name] ?? AppColors.primary;

  static String accentName(Color color) {
    for (final MapEntry<String, Color> entry
        in AppColors.accentPalette.entries) {
      if (entry.value.toARGB32() == color.toARGB32()) {
        return entry.key;
      }
    }
    return AppColors.accentPalette.keys.first;
  }
}
