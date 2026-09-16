/// Canonical names of every database object the client touches.
///
/// Repositories must reference these constants rather than inline string
/// literals. A rename in the schema then becomes a single-line change here and
/// a compile-time-visible diff everywhere else.
library;

/// Physical table names.
class DbTables {
  const DbTables._();

  // ------------------------------------------------------------------ core
  static const String showrooms = 'showrooms';
  static const String users = 'users';
  static const String roles = 'roles';
  static const String permissions = 'permissions';
  static const String userRoles = 'user_roles';
  static const String rolePermissions = 'role_permissions';
  static const String userShowrooms = 'user_showrooms';
  static const String deviceTokens = 'device_tokens';

  // -------------------------------------------------------------- catalogue
  static const String brands = 'brands';
  static const String products = 'products';
  static const String productColors = 'product_colors';
  static const String productImages = 'product_images';

  // -------------------------------------------------------------- inventory
  static const String inventory = 'inventory';
  static const String stockTransfers = 'stock_transfers';
  static const String stockMovements = 'stock_movements';

  // --------------------------------------------------------------- customer
  static const String customers = 'customers';
  static const String customerVehicles = 'customer_vehicles';

  // ------------------------------------------------------------------ sales
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String invoices = 'invoices';
  static const String invoiceItems = 'invoice_items';
  static const String payments = 'payments';

  // ---------------------------------------------------------------- finance
  static const String financeCompanies = 'finance_companies';
  static const String loans = 'loans';
  static const String emiSchedules = 'emi_schedules';

  // --------------------------------------------------------------- purchase
  static const String suppliers = 'suppliers';
  static const String purchases = 'purchases';
  static const String purchaseItems = 'purchase_items';

  // --------------------------------------------------------------- expenses
  static const String expenseCategories = 'expense_categories';
  static const String expenses = 'expenses';

  // ---------------------------------------------------------------- service
  static const String serviceRecords = 'service_records';
  static const String serviceItems = 'service_items';
  static const String freeServicePlans = 'free_service_plans';
  static const String vehicleFreeServices = 'vehicle_free_services';

  // ------------------------------------------------------ warranty/insurance
  static const String warranties = 'warranties';
  static const String warrantyClaims = 'warranty_claims';
  static const String insurancePolicies = 'insurance_policies';

  // ------------------------------------------------------------ engagement
  static const String reminders = 'reminders';
  static const String notifications = 'notifications';

  // ------------------------------------------------------------- accounting
  static const String accounts = 'accounts';
  static const String accountingTransactions = 'accounting_transactions';
  static const String accountingEntries = 'accounting_entries';

  // ----------------------------------------------------------------- system
  static const String attachments = 'attachments';
  static const String auditLogs = 'audit_logs';
  static const String documentSequences = 'document_sequences';
  static const String appSettings = 'app_settings';
}

/// Reporting views and materialised summaries. All are read-only.
class DbViews {
  const DbViews._();

  static const String dailySalesSummary = 'daily_sales_summary';
  static const String monthlySalesSummary = 'monthly_sales_summary';
  static const String showroomProfitSummary = 'showroom_profit_summary';
  static const String customerOutstandingSummary =
      'customer_outstanding_summary';
  static const String emiDueSummary = 'emi_due_summary';
  static const String emiOverdueSummary = 'emi_overdue_summary';
  static const String serviceRevenueSummary = 'service_revenue_summary';
  static const String inventorySummary = 'inventory_summary';
  static const String lowStockSummary = 'low_stock_summary';
  static const String purchaseSummary = 'purchase_summary';
  static const String expenseSummary = 'expense_summary';
  static const String upcomingServiceSummary = 'upcoming_service_summary';
  static const String insuranceExpirySummary = 'insurance_expiry_summary';
  static const String warrantyExpirySummary = 'warranty_expiry_summary';
  static const String profitAndLossSummary = 'profit_and_loss_summary';
  static const String trialBalance = 'trial_balance';
  static const String customerTimeline = 'customer_timeline';
  static const String vehicleServiceHistory = 'vehicle_service_history';
}

/// Server-side functions invoked through `supabase.rpc(...)`.
///
/// Every multi-table business operation lives here rather than being assembled
/// from independent client calls, so that it either fully commits or fully
/// rolls back.
class DbFunctions {
  const DbFunctions._();

  // ------------------------------------------------------- authz helpers
  static const String isSuperAdmin = 'is_super_admin';
  static const String canAccessShowroom = 'can_access_showroom';
  static const String hasPermission = 'has_permission';
  static const String currentUserId = 'current_user_id';
  static const String currentUserContext = 'current_user_context';

  // ------------------------------------------------------------ documents
  static const String nextDocumentNumber = 'next_document_number';

  // --------------------------------------------------------- transactions
  static const String createSaleTransaction = 'create_sale_transaction';
  static const String cancelSaleTransaction = 'cancel_sale_transaction';
  static const String recordPayment = 'record_payment';
  static const String reversePayment = 'reverse_payment';
  static const String completeService = 'complete_service';
  static const String transferInventory = 'transfer_inventory';
  static const String receiveInventoryTransfer = 'receive_inventory_transfer';
  static const String adjustInventory = 'adjust_inventory';
  static const String createPurchaseTransaction = 'create_purchase_transaction';
  static const String receivePurchase = 'receive_purchase';
  static const String createExpenseTransaction = 'create_expense_transaction';
  static const String approveExpense = 'approve_expense';
  static const String createAccountingTransaction =
      'create_accounting_transaction';

  // --------------------------------------------------------------- finance
  static const String calculateEmi = 'calculate_emi';
  static const String generateEmiSchedule = 'generate_emi_schedule';
  static const String recordEmiPayment = 'record_emi_payment';
  static const String refreshEmiStatuses = 'refresh_emi_statuses';
  static const String forecloseLoan = 'foreclose_loan';

  // --------------------------------------------------------------- service
  static const String generateFreeServiceSchedule =
      'generate_free_service_schedule';
  static const String checkFreeServiceEligibility =
      'check_free_service_eligibility';

  // ------------------------------------------------------------- reminders
  static const String createEmiReminders = 'create_emi_reminders';
  static const String createServiceReminders = 'create_service_reminders';
  static const String createInsuranceReminders = 'create_insurance_reminders';
  static const String createWarrantyReminders = 'create_warranty_reminders';
  static const String createPaymentReminders = 'create_payment_reminders';
  static const String dispatchDueReminders = 'dispatch_due_reminders';

  // --------------------------------------------------------------- reports
  static const String dashboardMetrics = 'dashboard_metrics';
  static const String salesTrend = 'sales_trend';
  static const String revenueTrend = 'revenue_trend';
  static const String expenseTrend = 'expense_trend';
  static const String profitTrend = 'profit_trend';
  static const String stockDistribution = 'stock_distribution';
  static const String paymentMethodDistribution = 'payment_method_distribution';
  static const String globalSearch = 'global_search';
  static const String customerThreeSixty = 'customer_three_sixty';
  static const String vehicleThreeSixty = 'vehicle_three_sixty';
  static const String profitAndLoss = 'profit_and_loss';
}

/// Supabase Storage buckets. Only `product-images` is public; everything else
/// holds customer or financial documents and is served via signed URLs.
class DbBuckets {
  const DbBuckets._();

  static const String productImages = 'product-images';
  static const String customerDocuments = 'customer-documents';
  static const String vehicleDocuments = 'vehicle-documents';
  static const String invoiceDocuments = 'invoice-documents';
  static const String serviceDocuments = 'service-documents';
  static const String insuranceDocuments = 'insurance-documents';
  static const String warrantyDocuments = 'warranty-documents';
  static const String expenseAttachments = 'expense-attachments';
  static const String showroomAssets = 'showroom-assets';

  /// Buckets that require a signed URL to read.
  static const List<String> privateBuckets = <String>[
    customerDocuments,
    vehicleDocuments,
    invoiceDocuments,
    serviceDocuments,
    insuranceDocuments,
    warrantyDocuments,
    expenseAttachments,
  ];

  static bool isPrivate(String bucket) => privateBuckets.contains(bucket);
}

/// Columns that appear on nearly every table, named once so that generic
/// query builders and the sync layer can rely on them.
class DbColumns {
  const DbColumns._();

  static const String id = 'id';
  static const String showroomId = 'showroom_id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String createdBy = 'created_by';
  static const String updatedBy = 'updated_by';
  static const String status = 'status';
  static const String isDeleted = 'is_deleted';
  static const String deletedAt = 'deleted_at';
  static const String deletedBy = 'deleted_by';

  /// Optimistic-concurrency counter incremented by the `set_updated_at`
  /// trigger. The sync layer compares this to detect conflicts.
  static const String revision = 'revision';
}
