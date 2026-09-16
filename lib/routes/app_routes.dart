import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';

/// Every route path in the application.
///
/// Paths are declared as constants so a navigation call cannot contain a typo
/// that only surfaces at runtime, and so [routePermissions] can map each one
/// to the permission that guards it.
class AppRoutes {
  const AppRoutes._();

  // ------------------------------------------------------------------- auth
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  /// Shown when the account is authenticated but not provisioned — no role,
  /// no showroom, or deactivated.
  static const String accountBlocked = '/account-blocked';

  // -------------------------------------------------------------- dashboard
  static const String dashboard = '/dashboard';

  // --------------------------------------------------------------- showroom
  static const String showrooms = '/showrooms';
  static const String showroomForm = '/showrooms/form';
  static const String showroomDetails = '/showrooms/details';

  // ------------------------------------------------------------------ users
  static const String users = '/users';
  static const String userForm = '/users/form';
  static const String userInvite = '/users/invite';
  static const String userDetails = '/users/details';
  static const String userRoles = '/users/roles';

  // ------------------------------------------------------------------ roles
  static const String roles = '/roles';
  static const String roleForm = '/roles/form';
  static const String rolePermissions = '/roles/permissions';

  // --------------------------------------------------------------- products
  static const String products = '/products';
  static const String productForm = '/products/form';
  static const String productDetails = '/products/details';
  static const String productImages = '/products/images';
  static const String productColors = '/products/colors';
  static const String brands = '/brands';

  // -------------------------------------------------------------- inventory
  static const String inventory = '/inventory';
  static const String inventoryForm = '/inventory/form';
  static const String inventoryDetails = '/inventory/details';
  static const String stockTransfer = '/inventory/transfer';
  static const String stockAdjustment = '/inventory/adjustment';
  static const String stockHistory = '/inventory/history';

  // -------------------------------------------------------------- customers
  static const String customers = '/customers';
  static const String customerForm = '/customers/form';
  static const String customerDetails = '/customers/details';
  static const String customerVehicles = '/customers/vehicles';
  static const String vehicleDetails = '/vehicles/details';
  static const String vehicleForm = '/vehicles/form';

  // ------------------------------------------------------------------ sales
  static const String sales = '/sales';
  static const String saleCreate = '/sales/create';
  static const String saleDetails = '/sales/details';
  static const String saleApproval = '/sales/approval';

  // ---------------------------------------------------------------- billing
  static const String invoices = '/billing';
  static const String invoiceDetails = '/billing/details';
  static const String invoicePreview = '/billing/preview';

  // --------------------------------------------------------------- payments
  static const String payments = '/payments';
  static const String paymentForm = '/payments/form';
  static const String paymentDetails = '/payments/details';
  static const String paymentRefund = '/payments/refund';

  // ---------------------------------------------------------------- finance
  static const String financeCompanies = '/finance/companies';
  static const String loans = '/finance/loans';
  static const String loanForm = '/finance/loans/form';
  static const String loanDetails = '/finance/loans/details';

  // -------------------------------------------------------------------- emi
  static const String emiDashboard = '/emi';
  static const String emiSchedule = '/emi/schedule';
  static const String emiUpcoming = '/emi/upcoming';
  static const String emiOverdue = '/emi/overdue';
  static const String emiPayment = '/emi/payment';
  static const String emiReceipt = '/emi/receipt';

  // -------------------------------------------------------------- purchases
  static const String suppliers = '/purchases/suppliers';
  static const String purchases = '/purchases';
  static const String purchaseCreate = '/purchases/create';
  static const String purchaseDetails = '/purchases/details';

  // --------------------------------------------------------------- expenses
  static const String expenses = '/expenses';
  static const String expenseForm = '/expenses/form';
  static const String expenseDetails = '/expenses/details';
  static const String expenseCategories = '/expenses/categories';
  static const String expenseApproval = '/expenses/approval';

  // ------------------------------------------------------------- accounting
  static const String accounting = '/accounting';
  static const String chartOfAccounts = '/accounting/accounts';
  static const String journal = '/accounting/journal';
  static const String trialBalance = '/accounting/trial-balance';

  // ---------------------------------------------------------------- service
  static const String services = '/service';
  static const String serviceBooking = '/service/booking';
  static const String jobCards = '/service/job-cards';
  static const String serviceDetails = '/service/details';
  static const String serviceBilling = '/service/billing';
  static const String serviceHistory = '/service/history';
  static const String freeServicePlans = '/service/free-plans';
  static const String freeServiceDue = '/service/free-due';

  // --------------------------------------------------------------- warranty
  static const String warranties = '/warranty';
  static const String warrantyDetails = '/warranty/details';
  static const String warrantyClaims = '/warranty/claims';

  // -------------------------------------------------------------- insurance
  static const String insurancePolicies = '/insurance';
  static const String insuranceForm = '/insurance/form';
  static const String insuranceDetails = '/insurance/details';
  static const String insuranceExpiry = '/insurance/expiry';

  // -------------------------------------------------------------- reminders
  static const String reminders = '/reminders';
  static const String reminderForm = '/reminders/form';

  // ---------------------------------------------------------- notifications
  static const String notifications = '/notifications';

  // ---------------------------------------------------------------- reports
  static const String reports = '/reports';
  static const String salesReport = '/reports/sales';
  static const String purchaseReport = '/reports/purchase';
  static const String expenseReport = '/reports/expense';
  static const String profitAndLoss = '/reports/profit-loss';
  static const String stockReport = '/reports/stock';
  static const String paymentReport = '/reports/payment';
  static const String emiReport = '/reports/emi';
  static const String serviceReport = '/reports/service';
  static const String outstandingReport = '/reports/outstanding';
  static const String financialSummary = '/reports/financial-summary';

  // -------------------------------------------------------------- documents
  static const String documents = '/documents';

  // ------------------------------------------------------------------ audit
  static const String auditLogs = '/audit';

  // --------------------------------------------------------------- settings
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String syncStatus = '/settings/sync';
  static const String diagnostics = '/settings/diagnostics';

  // ------------------------------------------------------------------ misc
  static const String globalSearch = '/search';
  static const String notFound = '/not-found';

  /// Routes reachable without a session.
  static const Set<String> publicRoutes = <String>{
    splash,
    login,
    forgotPassword,
    resetPassword,
    notFound,
  };

  static bool isPublic(String route) => publicRoutes.contains(route);

  /// The permission a route requires, if any.
  ///
  /// Consulted by `PermissionMiddleware`. A route absent from this map needs
  /// only a valid session. Deep links and typed URLs on web go through the
  /// same check as a tap, which is why this mapping is data rather than being
  /// scattered across widgets.
  static const Map<String, String> routePermissions = <String, String>{
    dashboard: AppPermissions.dashboardView,

    showrooms: AppPermissions.showroomView,
    showroomForm: AppPermissions.showroomCreate,
    showroomDetails: AppPermissions.showroomView,

    users: AppPermissions.usersView,
    userForm: AppPermissions.usersEdit,
    userInvite: AppPermissions.usersCreate,
    userDetails: AppPermissions.usersView,
    userRoles: AppPermissions.usersAssign,

    roles: AppPermissions.rolesView,
    roleForm: AppPermissions.rolesManage,
    rolePermissions: AppPermissions.rolesManage,

    products: AppPermissions.productsView,
    productForm: AppPermissions.productsCreate,
    productDetails: AppPermissions.productsView,
    productImages: AppPermissions.productsEdit,
    productColors: AppPermissions.productsEdit,
    brands: AppPermissions.productsView,

    inventory: AppPermissions.inventoryView,
    inventoryForm: AppPermissions.inventoryCreate,
    inventoryDetails: AppPermissions.inventoryView,
    stockTransfer: AppPermissions.inventoryTransfer,
    stockAdjustment: AppPermissions.inventoryAdjust,
    stockHistory: AppPermissions.inventoryView,

    customers: AppPermissions.customersView,
    customerForm: AppPermissions.customersCreate,
    customerDetails: AppPermissions.customersView,
    customerVehicles: AppPermissions.vehiclesView,
    vehicleDetails: AppPermissions.vehiclesView,
    vehicleForm: AppPermissions.vehiclesCreate,

    sales: AppPermissions.salesView,
    saleCreate: AppPermissions.salesCreate,
    saleDetails: AppPermissions.salesView,
    saleApproval: AppPermissions.salesApprove,

    invoices: AppPermissions.billingView,
    invoiceDetails: AppPermissions.billingView,
    invoicePreview: AppPermissions.billingView,

    payments: AppPermissions.paymentsView,
    paymentForm: AppPermissions.paymentsCreate,
    paymentDetails: AppPermissions.paymentsView,
    paymentRefund: AppPermissions.paymentsRefund,

    financeCompanies: AppPermissions.financeView,
    loans: AppPermissions.financeView,
    loanForm: AppPermissions.financeCreate,
    loanDetails: AppPermissions.financeView,

    emiDashboard: AppPermissions.emiView,
    emiSchedule: AppPermissions.emiView,
    emiUpcoming: AppPermissions.emiView,
    emiOverdue: AppPermissions.emiView,
    emiPayment: AppPermissions.emiPayment,
    emiReceipt: AppPermissions.emiView,

    suppliers: AppPermissions.suppliersView,
    purchases: AppPermissions.purchasesView,
    purchaseCreate: AppPermissions.purchasesCreate,
    purchaseDetails: AppPermissions.purchasesView,

    expenses: AppPermissions.expensesView,
    expenseForm: AppPermissions.expensesCreate,
    expenseDetails: AppPermissions.expensesView,
    expenseCategories: AppPermissions.expensesView,
    expenseApproval: AppPermissions.expensesApprove,

    accounting: AppPermissions.accountingView,
    chartOfAccounts: AppPermissions.accountingView,
    journal: AppPermissions.accountingView,
    trialBalance: AppPermissions.accountingView,

    services: AppPermissions.serviceView,
    serviceBooking: AppPermissions.serviceCreate,
    jobCards: AppPermissions.serviceView,
    serviceDetails: AppPermissions.serviceView,
    serviceBilling: AppPermissions.serviceBill,
    serviceHistory: AppPermissions.serviceView,
    freeServicePlans: AppPermissions.serviceView,
    freeServiceDue: AppPermissions.serviceView,

    warranties: AppPermissions.warrantyView,
    warrantyDetails: AppPermissions.warrantyView,
    warrantyClaims: AppPermissions.warrantyClaim,

    insurancePolicies: AppPermissions.insuranceView,
    insuranceForm: AppPermissions.insuranceCreate,
    insuranceDetails: AppPermissions.insuranceView,
    insuranceExpiry: AppPermissions.insuranceView,

    reminders: AppPermissions.remindersView,
    reminderForm: AppPermissions.remindersCreate,

    notifications: AppPermissions.notificationsView,

    reports: AppPermissions.reportsView,
    salesReport: AppPermissions.reportsView,
    purchaseReport: AppPermissions.reportsView,
    expenseReport: AppPermissions.reportsView,
    profitAndLoss: AppPermissions.reportsView,
    stockReport: AppPermissions.reportsView,
    paymentReport: AppPermissions.reportsView,
    emiReport: AppPermissions.reportsView,
    serviceReport: AppPermissions.reportsView,
    outstandingReport: AppPermissions.reportsView,
    financialSummary: AppPermissions.reportsView,

    documents: AppPermissions.documentsView,
    auditLogs: AppPermissions.auditView,

    settings: AppPermissions.settingsView,
  };

  static String? permissionFor(String route) => routePermissions[route];
}
