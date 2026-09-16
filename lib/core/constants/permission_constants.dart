/// The permission vocabulary, expressed as `module.action`.
///
/// This file is the single source of truth for the client. The identical set is
/// seeded into `permissions` by `008_roles_permissions.sql`, and
/// `test/unit/permission_catalog_test.dart` asserts the two stay aligned.
///
/// A permission held here only shapes the UI. Every write is independently
/// authorised by Row Level Security using `has_permission(module, action)`, so
/// removing a client-side check never grants access.
library;

/// Module identifiers, matching `permissions.module`.
class AppModule {
  const AppModule._();

  static const String dashboard = 'dashboard';
  static const String showroom = 'showroom';
  static const String users = 'users';
  static const String roles = 'roles';
  static const String products = 'products';
  static const String inventory = 'inventory';
  static const String customers = 'customers';
  static const String vehicles = 'vehicles';
  static const String sales = 'sales';
  static const String billing = 'billing';
  static const String payments = 'payments';
  static const String finance = 'finance';
  static const String emi = 'emi';
  static const String purchases = 'purchases';
  static const String suppliers = 'suppliers';
  static const String expenses = 'expenses';
  static const String accounting = 'accounting';
  static const String service = 'service';
  static const String warranty = 'warranty';
  static const String insurance = 'insurance';
  static const String reminders = 'reminders';
  static const String notifications = 'notifications';
  static const String reports = 'reports';
  static const String documents = 'documents';
  static const String audit = 'audit';
  static const String settings = 'settings';

  static const List<String> all = <String>[
    dashboard,
    showroom,
    users,
    roles,
    products,
    inventory,
    customers,
    vehicles,
    sales,
    billing,
    payments,
    finance,
    emi,
    purchases,
    suppliers,
    expenses,
    accounting,
    service,
    warranty,
    insurance,
    reminders,
    notifications,
    reports,
    documents,
    audit,
    settings,
  ];
}

/// Action verbs, matching `permissions.action`.
class AppAction {
  const AppAction._();

  static const String view = 'view';
  static const String create = 'create';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String approve = 'approve';
  static const String reject = 'reject';
  static const String cancel = 'cancel';
  static const String complete = 'complete';
  static const String export = 'export';
  static const String print = 'print';
  static const String manage = 'manage';
  static const String transfer = 'transfer';
  static const String adjust = 'adjust';
  static const String discount = 'discount';
  static const String payment = 'payment';
  static const String refund = 'refund';
  static const String bill = 'bill';
  static const String assign = 'assign';
  static const String claim = 'claim';
  static const String upload = 'upload';
  static const String download = 'download';
}

/// Every permission key in the system.
class AppPermissions {
  const AppPermissions._();

  /// Builds a `module.action` key. Prefer the named constants below; this is
  /// for dynamically composed checks such as generic list screens.
  static String of(String module, String action) => '$module.$action';

  // ------------------------------------------------------------- dashboard
  static const String dashboardView = 'dashboard.view';
  static const String dashboardExport = 'dashboard.export';

  // -------------------------------------------------------------- showroom
  static const String showroomView = 'showroom.view';
  static const String showroomCreate = 'showroom.create';
  static const String showroomEdit = 'showroom.edit';
  static const String showroomDelete = 'showroom.delete';
  static const String showroomManage = 'showroom.manage';

  // ----------------------------------------------------------------- users
  static const String usersView = 'users.view';
  static const String usersCreate = 'users.create';
  static const String usersEdit = 'users.edit';
  static const String usersDelete = 'users.delete';
  static const String usersAssign = 'users.assign';

  // ----------------------------------------------------------------- roles
  static const String rolesView = 'roles.view';
  static const String rolesManage = 'roles.manage';

  // -------------------------------------------------------------- products
  static const String productsView = 'products.view';
  static const String productsCreate = 'products.create';
  static const String productsEdit = 'products.edit';
  static const String productsDelete = 'products.delete';
  static const String productsExport = 'products.export';

  // ------------------------------------------------------------- inventory
  static const String inventoryView = 'inventory.view';
  static const String inventoryCreate = 'inventory.create';
  static const String inventoryEdit = 'inventory.edit';
  static const String inventoryTransfer = 'inventory.transfer';
  static const String inventoryAdjust = 'inventory.adjust';
  static const String inventoryDelete = 'inventory.delete';
  static const String inventoryExport = 'inventory.export';

  // ------------------------------------------------------------- customers
  static const String customersView = 'customers.view';
  static const String customersCreate = 'customers.create';
  static const String customersEdit = 'customers.edit';
  static const String customersDelete = 'customers.delete';
  static const String customersExport = 'customers.export';

  // -------------------------------------------------------------- vehicles
  static const String vehiclesView = 'vehicles.view';
  static const String vehiclesCreate = 'vehicles.create';
  static const String vehiclesEdit = 'vehicles.edit';
  static const String vehiclesDelete = 'vehicles.delete';

  // ----------------------------------------------------------------- sales
  static const String salesView = 'sales.view';
  static const String salesCreate = 'sales.create';
  static const String salesEdit = 'sales.edit';
  static const String salesCancel = 'sales.cancel';
  static const String salesDiscount = 'sales.discount';
  static const String salesApprove = 'sales.approve';
  static const String salesExport = 'sales.export';

  // --------------------------------------------------------------- billing
  static const String billingView = 'billing.view';
  static const String billingCreate = 'billing.create';
  static const String billingEdit = 'billing.edit';
  static const String billingCancel = 'billing.cancel';
  static const String billingPrint = 'billing.print';
  static const String billingExport = 'billing.export';

  // -------------------------------------------------------------- payments
  static const String paymentsView = 'payments.view';
  static const String paymentsCreate = 'payments.create';
  static const String paymentsEdit = 'payments.edit';
  static const String paymentsCancel = 'payments.cancel';
  static const String paymentsRefund = 'payments.refund';
  static const String paymentsExport = 'payments.export';

  // --------------------------------------------------------------- finance
  static const String financeView = 'finance.view';
  static const String financeCreate = 'finance.create';
  static const String financeEdit = 'finance.edit';
  static const String financeManage = 'finance.manage';

  // ------------------------------------------------------------------- emi
  static const String emiView = 'emi.view';
  static const String emiCreate = 'emi.create';
  static const String emiEdit = 'emi.edit';
  static const String emiPayment = 'emi.payment';
  static const String emiCancel = 'emi.cancel';
  static const String emiExport = 'emi.export';

  // ------------------------------------------------------------- purchases
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesEdit = 'purchases.edit';
  static const String purchasesCancel = 'purchases.cancel';
  static const String purchasesApprove = 'purchases.approve';
  static const String purchasesExport = 'purchases.export';

  // ------------------------------------------------------------- suppliers
  static const String suppliersView = 'suppliers.view';
  static const String suppliersCreate = 'suppliers.create';
  static const String suppliersEdit = 'suppliers.edit';
  static const String suppliersDelete = 'suppliers.delete';

  // -------------------------------------------------------------- expenses
  static const String expensesView = 'expenses.view';
  static const String expensesCreate = 'expenses.create';
  static const String expensesEdit = 'expenses.edit';
  static const String expensesDelete = 'expenses.delete';
  static const String expensesApprove = 'expenses.approve';
  static const String expensesReject = 'expenses.reject';
  static const String expensesExport = 'expenses.export';

  // ------------------------------------------------------------ accounting
  static const String accountingView = 'accounting.view';
  static const String accountingCreate = 'accounting.create';
  static const String accountingManage = 'accounting.manage';
  static const String accountingExport = 'accounting.export';

  // --------------------------------------------------------------- service
  static const String serviceView = 'service.view';
  static const String serviceCreate = 'service.create';
  static const String serviceEdit = 'service.edit';
  static const String serviceComplete = 'service.complete';
  static const String serviceBill = 'service.bill';
  static const String serviceDiscount = 'service.discount';
  static const String serviceCancel = 'service.cancel';
  static const String serviceAssign = 'service.assign';
  static const String serviceExport = 'service.export';

  // -------------------------------------------------------------- warranty
  static const String warrantyView = 'warranty.view';
  static const String warrantyCreate = 'warranty.create';
  static const String warrantyEdit = 'warranty.edit';
  static const String warrantyClaim = 'warranty.claim';
  static const String warrantyApprove = 'warranty.approve';

  // ------------------------------------------------------------- insurance
  static const String insuranceView = 'insurance.view';
  static const String insuranceCreate = 'insurance.create';
  static const String insuranceEdit = 'insurance.edit';
  static const String insuranceDelete = 'insurance.delete';

  // ------------------------------------------------------------- reminders
  static const String remindersView = 'reminders.view';
  static const String remindersCreate = 'reminders.create';
  static const String remindersEdit = 'reminders.edit';
  static const String remindersComplete = 'reminders.complete';
  static const String remindersCancel = 'reminders.cancel';

  // --------------------------------------------------------- notifications
  static const String notificationsView = 'notifications.view';
  static const String notificationsCreate = 'notifications.create';

  // --------------------------------------------------------------- reports
  static const String reportsView = 'reports.view';
  static const String reportsExport = 'reports.export';
  static const String reportsPrint = 'reports.print';

  // ------------------------------------------------------------- documents
  static const String documentsView = 'documents.view';
  static const String documentsUpload = 'documents.upload';
  static const String documentsDownload = 'documents.download';
  static const String documentsDelete = 'documents.delete';

  // ----------------------------------------------------------------- audit
  static const String auditView = 'audit.view';
  static const String auditExport = 'audit.export';

  // -------------------------------------------------------------- settings
  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';
  static const String settingsManage = 'settings.manage';

  /// Flat catalogue of every permission, used by the role editor to render the
  /// permission matrix and by the seed-parity test.
  static const List<String> all = <String>[
    dashboardView,
    dashboardExport,
    showroomView,
    showroomCreate,
    showroomEdit,
    showroomDelete,
    showroomManage,
    usersView,
    usersCreate,
    usersEdit,
    usersDelete,
    usersAssign,
    rolesView,
    rolesManage,
    productsView,
    productsCreate,
    productsEdit,
    productsDelete,
    productsExport,
    inventoryView,
    inventoryCreate,
    inventoryEdit,
    inventoryTransfer,
    inventoryAdjust,
    inventoryDelete,
    inventoryExport,
    customersView,
    customersCreate,
    customersEdit,
    customersDelete,
    customersExport,
    vehiclesView,
    vehiclesCreate,
    vehiclesEdit,
    vehiclesDelete,
    salesView,
    salesCreate,
    salesEdit,
    salesCancel,
    salesDiscount,
    salesApprove,
    salesExport,
    billingView,
    billingCreate,
    billingEdit,
    billingCancel,
    billingPrint,
    billingExport,
    paymentsView,
    paymentsCreate,
    paymentsEdit,
    paymentsCancel,
    paymentsRefund,
    paymentsExport,
    financeView,
    financeCreate,
    financeEdit,
    financeManage,
    emiView,
    emiCreate,
    emiEdit,
    emiPayment,
    emiCancel,
    emiExport,
    purchasesView,
    purchasesCreate,
    purchasesEdit,
    purchasesCancel,
    purchasesApprove,
    purchasesExport,
    suppliersView,
    suppliersCreate,
    suppliersEdit,
    suppliersDelete,
    expensesView,
    expensesCreate,
    expensesEdit,
    expensesDelete,
    expensesApprove,
    expensesReject,
    expensesExport,
    accountingView,
    accountingCreate,
    accountingManage,
    accountingExport,
    serviceView,
    serviceCreate,
    serviceEdit,
    serviceComplete,
    serviceBill,
    serviceDiscount,
    serviceCancel,
    serviceAssign,
    serviceExport,
    warrantyView,
    warrantyCreate,
    warrantyEdit,
    warrantyClaim,
    warrantyApprove,
    insuranceView,
    insuranceCreate,
    insuranceEdit,
    insuranceDelete,
    remindersView,
    remindersCreate,
    remindersEdit,
    remindersComplete,
    remindersCancel,
    notificationsView,
    notificationsCreate,
    reportsView,
    reportsExport,
    reportsPrint,
    documentsView,
    documentsUpload,
    documentsDownload,
    documentsDelete,
    auditView,
    auditExport,
    settingsView,
    settingsEdit,
    settingsManage,
  ];

  /// Splits a key back into its parts for `has_permission(module, action)`.
  static ({String module, String action}) parse(String permission) {
    final int separator = permission.indexOf('.');
    if (separator <= 0 || separator == permission.length - 1) {
      throw ArgumentError.value(
        permission,
        'permission',
        'Expected "module.action" format',
      );
    }
    return (
      module: permission.substring(0, separator),
      action: permission.substring(separator + 1),
    );
  }
}
