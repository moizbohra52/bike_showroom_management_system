/// Keys used for local persistence.
///
/// Three tiers exist, and putting a value in the wrong one is a security bug:
///
///  * [PrefKeys]   - SharedPreferences. Non-sensitive UI preferences only.
///  * [SecureKeys] - Platform keychain / credential store. Tokens only.
///  * [HiveBoxes]  - Local database. Cached business data and the sync queue.
library;

/// SharedPreferences keys. Nothing here may be sensitive: on several platforms
/// these are world-readable to the user account.
class PrefKeys {
  const PrefKeys._();

  static const String themeMode = 'pref_theme_mode';
  static const String accentColor = 'pref_accent_color';
  static const String locale = 'pref_locale';
  static const String selectedShowroomId = 'pref_selected_showroom_id';
  static const String onboardingComplete = 'pref_onboarding_complete';
  static const String sidebarCollapsed = 'pref_sidebar_collapsed';
  static const String lastSyncedAt = 'pref_last_synced_at';
  static const String lastKnownRoute = 'pref_last_known_route';
  static const String rememberedEmail = 'pref_remembered_email';
  static const String textScaleFactor = 'pref_text_scale_factor';
  static const String compactDensity = 'pref_compact_density';

  /// Per-table column visibility and width preferences, keyed by table id:
  /// `pref_table_<tableId>`.
  static const String tablePreferencePrefix = 'pref_table_';

  /// Persisted filter state per list screen, keyed by screen id:
  /// `pref_filter_<screenId>`.
  static const String filterPreferencePrefix = 'pref_filter_';

  /// Per-list page size override, keyed by screen id.
  static const String pageSizePrefix = 'pref_page_size_';

  static String tablePreference(String tableId) =>
      '$tablePreferencePrefix$tableId';

  static String filterPreference(String screenId) =>
      '$filterPreferencePrefix$screenId';

  static String pageSize(String screenId) => '$pageSizePrefix$screenId';
}

/// Keys held in the platform secure store (Keychain / Keystore / DPAPI).
///
/// Passwords are never stored, in any tier. Supabase issues a refresh token
/// and that is the only credential the app retains.
class SecureKeys {
  const SecureKeys._();

  static const String supabaseSession = 'secure_supabase_session';
  static const String fcmToken = 'secure_fcm_token';
  static const String deviceId = 'secure_device_id';

  /// Encryption key for the local Hive boxes that hold cached business data.
  static const String hiveCipherKey = 'secure_hive_cipher_key';
}

/// Hive box names. Each box is opened lazily by `LocalDatabaseService`.
class HiveBoxes {
  const HiveBoxes._();

  /// Offline mutation queue. Encrypted, because drafts contain customer data.
  static const String syncQueue = 'box_sync_queue';

  /// Cached read models, one box per entity so eviction can be targeted.
  static const String customers = 'box_customers';
  static const String products = 'box_products';
  static const String inventory = 'box_inventory';
  static const String showrooms = 'box_showrooms';
  static const String brands = 'box_brands';
  static const String vehicles = 'box_vehicles';
  static const String suppliers = 'box_suppliers';
  static const String financeCompanies = 'box_finance_companies';
  static const String expenseCategories = 'box_expense_categories';

  /// Draft documents the user started while offline.
  static const String saleDrafts = 'box_sale_drafts';
  static const String serviceDrafts = 'box_service_drafts';
  static const String paymentDrafts = 'box_payment_drafts';

  /// Identity and authorisation snapshot, so the shell can render before the
  /// network responds. Encrypted.
  static const String session = 'box_session';

  /// Cached dashboard metrics and report payloads with their fetch timestamp.
  static const String reportCache = 'box_report_cache';

  /// Metadata about cache freshness, keyed by cache identifier.
  static const String cacheMeta = 'box_cache_meta';

  /// Boxes holding customer or financial data, which are opened with a cipher.
  static const List<String> encryptedBoxes = <String>[
    syncQueue,
    customers,
    vehicles,
    saleDrafts,
    serviceDrafts,
    paymentDrafts,
    session,
  ];

  /// Boxes safe to drop entirely on sign-out.
  static const List<String> clearOnSignOut = <String>[
    session,
    reportCache,
    cacheMeta,
    customers,
    vehicles,
    inventory,
  ];

  static bool isEncrypted(String box) => encryptedBoxes.contains(box);
}

/// Stable identifiers for cached collections, used as keys in
/// [HiveBoxes.cacheMeta] to decide whether a refetch is due.
class CacheKeys {
  const CacheKeys._();

  static const String dashboardMetrics = 'cache_dashboard_metrics';
  static const String permissionSet = 'cache_permission_set';
  static const String showroomList = 'cache_showroom_list';
  static const String productCatalogue = 'cache_product_catalogue';
  static const String brandList = 'cache_brand_list';
  static const String expenseCategoryList = 'cache_expense_category_list';
  static const String financeCompanyList = 'cache_finance_company_list';
  static const String supplierList = 'cache_supplier_list';

  static String customerPage(int page) => 'cache_customers_page_$page';
  static String inventoryPage(int page) => 'cache_inventory_page_$page';
}
