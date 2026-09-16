/// Application-wide tunables that are not environment specific.
///
/// Anything that differs between development, staging and production belongs in
/// `EnvironmentConfig` instead.
library;

/// Non-visual behavioural constants.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Bike Showroom Manager';
  static const String appLegalName = 'Bike Showroom Management System';

  // ----------------------------------------------------------- pagination
  /// Default rows fetched per page. Spec section 73.
  static const int defaultPageSize = 20;

  /// Page sizes offered to the user where the platform has room for a picker.
  static const List<int> pageSizeOptions = <int>[20, 50, 100];

  /// Hard ceiling on any single page request, enforced before hitting the
  /// network so a crafted filter can never pull an unbounded result set.
  static const int maxPageSize = 200;

  /// Rows fetched per batch when streaming a full export to file. Exports
  /// bypass the UI page size because they are written straight to disk.
  static const int exportBatchSize = 500;

  /// Absolute ceiling on exported rows, to keep memory bounded on mobile.
  static const int maxExportRows = 50000;

  // --------------------------------------------------------------- search
  /// Debounce applied to search fields before a query is issued.
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Minimum characters before a server-side search fires.
  static const int minSearchLength = 2;

  /// Global search result cap per entity group.
  static const int globalSearchLimitPerEntity = 5;

  // -------------------------------------------------------------- network
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  /// Attempts for an idempotent request that failed for a transient reason.
  static const int maxRetryAttempts = 3;

  /// Base delay for exponential backoff between retries.
  static const Duration retryBaseDelay = Duration(milliseconds: 600);

  // ----------------------------------------------------------------- sync
  /// Maximum queue entries dispatched in a single sync pass.
  static const int syncBatchSize = 25;

  /// Give up automatic replay after this many failures and surface the entry
  /// for manual attention.
  static const int maxSyncRetries = 5;

  /// Interval for the periodic background sync sweep while online.
  static const Duration syncInterval = Duration(minutes: 5);

  /// How long cached reference data stays fresh before a refetch is preferred.
  static const Duration cacheTtl = Duration(hours: 12);

  /// Reference data (products, brands) tolerates a longer stale window.
  static const Duration referenceCacheTtl = Duration(days: 3);

  // ---------------------------------------------------------------- images
  /// Longest edge for a stored full-size image, in pixels.
  static const int imageMaxDimension = 1600;

  /// Longest edge for a generated thumbnail, in pixels.
  static const int thumbnailMaxDimension = 320;

  /// JPEG quality applied after resize.
  static const int imageCompressionQuality = 82;

  /// Reject uploads larger than this before compression, in bytes.
  static const int maxUploadBytes = 25 * 1024 * 1024;

  /// Reject document uploads larger than this, in bytes.
  static const int maxDocumentBytes = 10 * 1024 * 1024;

  static const List<String> allowedImageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  ];

  static const List<String> allowedDocumentExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];

  /// Lifetime of a signed URL handed to the client for a private document.
  static const Duration signedUrlTtl = Duration(minutes: 15);

  // --------------------------------------------------------------- session
  /// Refresh the access token this long before it actually expires.
  static const Duration sessionRefreshLeeway = Duration(minutes: 5);

  /// Sign the user out after this much inactivity on desktop/web, where a
  /// shared terminal is a realistic risk.
  static const Duration idleTimeout = Duration(minutes: 30);

  // -------------------------------------------------------------- business
  /// Stock at or below this count per product/showroom raises a low-stock
  /// alert on the dashboard.
  static const int lowStockThreshold = 3;

  /// Days ahead that "expiring soon" windows look for insurance and warranty.
  static const int expiryWarningDays = 30;

  /// Days before an EMI due date that the first reminder is raised.
  static const List<int> emiReminderOffsetDays = <int>[7, 3, 1, 0];

  /// Days before a service due date that a reminder is raised.
  static const List<int> serviceReminderOffsetDays = <int>[15, 7, 0];

  /// Monthly penalty rate applied to an overdue EMI, as a percentage.
  static const double defaultLatePaymentPenaltyRate = 2.0;

  /// Discount above this percentage requires `sales.approve`.
  static const double discountApprovalThresholdPercent = 5.0;

  /// Money is rounded to this many decimal places everywhere.
  static const int currencyDecimalPlaces = 2;

  /// Tolerance when asserting that debits equal credits, to absorb the last
  /// representable unit of rounding.
  static const double ledgerBalanceTolerance = 0.01;

  // --------------------------------------------------------------- display
  static const String defaultCurrencySymbol = '₹';
  static const String defaultCurrencyCode = 'INR';
  static const String defaultLocale = 'en_IN';
  static const String defaultCountryCode = 'IN';

  static const String dateFormat = 'dd MMM yyyy';
  static const String dateInputFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, hh:mm a';
  static const String timeFormat = 'hh:mm a';
  static const String monthYearFormat = 'MMM yyyy';
  static const String isoDateFormat = 'yyyy-MM-dd';

  // ------------------------------------------------------------ responsive
  /// Width below which the compact (mobile) shell is used.
  static const double mobileBreakpoint = 640;

  /// Width below which the tablet shell is used.
  static const double tabletBreakpoint = 1024;

  /// Width above which the large-desktop shell is used.
  static const double largeDesktopBreakpoint = 1600;

  /// Expanded sidebar width on desktop shells.
  static const double sidebarWidth = 264;

  /// Collapsed (icon-only) sidebar width.
  static const double sidebarCollapsedWidth = 72;

  /// Maximum content width so text lines stay readable on wide monitors.
  static const double maxContentWidth = 1440;

  /// Width of the form pane in a master/detail desktop layout.
  static const double detailPaneWidth = 420;
}
