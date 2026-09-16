/// Cross-cutting platform enumerations: reminders, notifications, audit,
/// offline synchronisation and exports.
library;

/// What a reminder is about. Also selects the notification template used by
/// the scheduled reminder dispatcher.
enum ReminderType {
  emi('EMI', 'EMI'),
  service('SERVICE', 'Service'),
  insurance('INSURANCE', 'Insurance'),
  warranty('WARRANTY', 'Warranty'),
  payment('PAYMENT', 'Payment'),
  document('DOCUMENT', 'Document'),
  custom('CUSTOM', 'Custom');

  const ReminderType(this.value, this.label);

  final String value;
  final String label;

  static ReminderType fromValue(String? value) =>
      ReminderType.values.firstWhere(
        (ReminderType type) => type.value == value,
        orElse: () => ReminderType.custom,
      );
}

/// Delivery / completion state of a reminder.
enum ReminderStatus {
  pending('PENDING', 'Pending'),
  sent('SENT', 'Sent'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  const ReminderStatus(this.value, this.label);

  final String value;
  final String label;

  static ReminderStatus fromValue(String? value) =>
      ReminderStatus.values.firstWhere(
        (ReminderStatus status) => status.value == value,
        orElse: () => ReminderStatus.pending,
      );

  bool get isOpen =>
      this == ReminderStatus.pending || this == ReminderStatus.sent;
}

/// Urgency of a reminder, used for sorting and badge colour.
enum ReminderPriority {
  low('LOW', 'Low', 0),
  medium('MEDIUM', 'Medium', 1),
  high('HIGH', 'High', 2),
  urgent('URGENT', 'Urgent', 3);

  const ReminderPriority(this.value, this.label, this.weight);

  final String value;
  final String label;

  /// Higher weight sorts first in reminder lists.
  final int weight;

  static ReminderPriority fromValue(String? value) =>
      ReminderPriority.values.firstWhere(
        (ReminderPriority priority) => priority.value == value,
        orElse: () => ReminderPriority.medium,
      );
}

/// Category of an in-app / push notification.
enum NotificationType {
  emiReminder('EMI_REMINDER', 'EMI Reminder'),
  serviceReminder('SERVICE_REMINDER', 'Service Reminder'),
  insuranceExpiry('INSURANCE_EXPIRY', 'Insurance Expiry'),
  warrantyExpiry('WARRANTY_EXPIRY', 'Warranty Expiry'),
  paymentReminder('PAYMENT_REMINDER', 'Payment Reminder'),
  paymentReceived('PAYMENT_RECEIVED', 'Payment Received'),
  approvalRequest('APPROVAL_REQUEST', 'Approval Request'),
  approvalDecision('APPROVAL_DECISION', 'Approval Decision'),
  stockAlert('STOCK_ALERT', 'Stock Alert'),
  stockTransfer('STOCK_TRANSFER', 'Stock Transfer'),
  saleCreated('SALE_CREATED', 'Sale Created'),
  serviceStatus('SERVICE_STATUS', 'Service Status'),
  system('SYSTEM', 'System');

  const NotificationType(this.value, this.label);

  final String value;
  final String label;

  static NotificationType fromValue(String? value) =>
      NotificationType.values.firstWhere(
        (NotificationType type) => type.value == value,
        orElse: () => NotificationType.system,
      );

  /// Route the app navigates to when the notification is tapped. Resolved
  /// against [AppRoutes] by the notification service.
  String get deepLinkModule {
    switch (this) {
      case NotificationType.emiReminder:
        return 'emi';
      case NotificationType.serviceReminder:
      case NotificationType.serviceStatus:
        return 'service';
      case NotificationType.insuranceExpiry:
        return 'insurance';
      case NotificationType.warrantyExpiry:
        return 'warranty';
      case NotificationType.paymentReminder:
      case NotificationType.paymentReceived:
        return 'payments';
      case NotificationType.approvalRequest:
      case NotificationType.approvalDecision:
        return 'expenses';
      case NotificationType.stockAlert:
      case NotificationType.stockTransfer:
        return 'inventory';
      case NotificationType.saleCreated:
        return 'sales';
      case NotificationType.system:
        return 'notifications';
    }
  }
}

/// Auditable action verbs written to `audit_logs.action`.
enum AuditAction {
  create('CREATE', 'Created'),
  update('UPDATE', 'Updated'),
  delete('DELETE', 'Deleted'),
  cancel('CANCEL', 'Cancelled'),
  approve('APPROVE', 'Approved'),
  reject('REJECT', 'Rejected'),
  payment('PAYMENT', 'Payment'),
  refund('REFUND', 'Refund'),
  reverse('REVERSE', 'Reversed'),
  login('LOGIN', 'Signed In'),
  logout('LOGOUT', 'Signed Out'),
  loginFailed('LOGIN_FAILED', 'Sign-in Failed'),
  stockTransfer('STOCK_TRANSFER', 'Stock Transfer'),
  stockAdjustment('STOCK_ADJUSTMENT', 'Stock Adjustment'),
  export('EXPORT', 'Exported'),
  print('PRINT', 'Printed'),
  permissionChange('PERMISSION_CHANGE', 'Permission Changed');

  const AuditAction(this.value, this.label);

  final String value;
  final String label;

  static AuditAction fromValue(String? value) => AuditAction.values.firstWhere(
    (AuditAction action) => action.value == value,
    orElse: () => AuditAction.update,
  );
}

/// Mutation kind queued for offline replay.
enum SyncOperation {
  create('CREATE', 'Create'),
  update('UPDATE', 'Update'),
  delete('DELETE', 'Delete'),
  rpc('RPC', 'Remote Procedure');

  const SyncOperation(this.value, this.label);

  final String value;
  final String label;

  static SyncOperation fromValue(String? value) =>
      SyncOperation.values.firstWhere(
        (SyncOperation operation) => operation.value == value,
        orElse: () => SyncOperation.update,
      );
}

/// State of an entry in the offline sync queue.
enum SyncStatus {
  pending('PENDING', 'Pending'),
  syncing('SYNCING', 'Syncing'),
  success('SUCCESS', 'Synced'),
  failed('FAILED', 'Failed'),
  conflict('CONFLICT', 'Needs Resolution');

  const SyncStatus(this.value, this.label);

  final String value;
  final String label;

  static SyncStatus fromValue(String? value) => SyncStatus.values.firstWhere(
    (SyncStatus status) => status.value == value,
    orElse: () => SyncStatus.pending,
  );

  /// Entries eligible for another dispatch attempt.
  bool get isDispatchable =>
      this == SyncStatus.pending || this == SyncStatus.failed;

  /// A conflict is never auto-resolved; a human must decide.
  bool get needsHumanDecision => this == SyncStatus.conflict;
}

/// How a detected sync conflict was or should be resolved.
enum ConflictResolution {
  keepServer('KEEP_SERVER', 'Keep Server Version'),
  keepLocal('KEEP_LOCAL', 'Keep My Version'),
  merge('MERGE', 'Merge Fields'),
  unresolved('UNRESOLVED', 'Awaiting Decision');

  const ConflictResolution(this.value, this.label);

  final String value;
  final String label;

  static ConflictResolution fromValue(String? value) =>
      ConflictResolution.values.firstWhere(
        (ConflictResolution resolution) => resolution.value == value,
        orElse: () => ConflictResolution.unresolved,
      );
}

/// Output format for a report export.
enum ExportFormat {
  pdf('PDF', 'PDF', 'pdf', 'application/pdf'),
  excel(
    'EXCEL',
    'Excel',
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  csv('CSV', 'CSV', 'csv', 'text/csv');

  const ExportFormat(this.value, this.label, this.extension, this.mimeType);

  final String value;
  final String label;
  final String extension;
  final String mimeType;

  static ExportFormat fromValue(String? value) =>
      ExportFormat.values.firstWhere(
        (ExportFormat format) => format.value == value,
        orElse: () => ExportFormat.pdf,
      );
}

/// Device platform recorded against an FCM token.
enum DevicePlatform {
  android('ANDROID', 'Android'),
  ios('IOS', 'iOS'),
  web('WEB', 'Web'),
  windows('WINDOWS', 'Windows'),
  macos('MACOS', 'macOS'),
  linux('LINUX', 'Linux'),
  unknown('UNKNOWN', 'Unknown');

  const DevicePlatform(this.value, this.label);

  final String value;
  final String label;

  static DevicePlatform fromValue(String? value) =>
      DevicePlatform.values.firstWhere(
        (DevicePlatform platform) => platform.value == value,
        orElse: () => DevicePlatform.unknown,
      );
}

/// Responsive breakpoint classification resolved from the current window size.
enum ScreenSize {
  mobile('MOBILE', 'Mobile'),
  tablet('TABLET', 'Tablet'),
  desktop('DESKTOP', 'Desktop'),
  largeDesktop('LARGE_DESKTOP', 'Large Desktop');

  const ScreenSize(this.value, this.label);

  final String value;
  final String label;

  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;

  /// Desktop-class layouts get the sidebar shell and paginated data tables.
  bool get isDesktopClass =>
      this == ScreenSize.desktop || this == ScreenSize.largeDesktop;

  /// Handheld layouts get the drawer, bottom navigation and card lists.
  bool get isCompact => this == ScreenSize.mobile || this == ScreenSize.tablet;
}

/// Sort direction for server-side ordered queries.
enum SortDirection {
  ascending('asc', 'Ascending'),
  descending('desc', 'Descending');

  const SortDirection(this.value, this.label);

  final String value;
  final String label;

  bool get isAscending => this == SortDirection.ascending;

  SortDirection get inverted => this == SortDirection.ascending
      ? SortDirection.descending
      : SortDirection.ascending;
}
