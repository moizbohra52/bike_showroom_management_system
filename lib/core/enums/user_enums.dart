/// Identity, access-control and tenancy related enumerations.
///
/// Every `value` here is the exact string persisted by PostgreSQL. The database
/// enforces the same vocabulary through CHECK constraints, so changing a value
/// on either side requires a matching migration on the other.
library;

/// Lifecycle state of an application user.
enum UserStatus {
  active('ACTIVE', 'Active'),
  inactive('INACTIVE', 'Inactive'),
  suspended('SUSPENDED', 'Suspended');

  const UserStatus(this.value, this.label);

  final String value;
  final String label;

  static UserStatus fromValue(String? value) => UserStatus.values.firstWhere(
    (UserStatus status) => status.value == value,
    orElse: () => UserStatus.inactive,
  );

  bool get canSignIn => this == UserStatus.active;
}

/// The system roles seeded by `008_roles_permissions.sql`.
///
/// Role checks in the client are a convenience for shaping navigation only.
/// Authorization is always re-evaluated by Row Level Security, so a tampered
/// client gains no additional access.
enum AppRole {
  superAdmin('SUPER ADMIN', 'Super Admin', 0),
  admin('ADMIN', 'Admin', 10),
  showroomManager('SHOWROOM MANAGER', 'Showroom Manager', 20),
  accountManager('ACCOUNT MANAGER', 'Account Manager', 30),
  salesManager('SALES MANAGER', 'Sales Manager', 40),
  inventoryManager('INVENTORY MANAGER', 'Inventory Manager', 40),
  purchaseManager('PURCHASE MANAGER', 'Purchase Manager', 40),
  serviceManager('SERVICE MANAGER', 'Service Manager', 40),
  accountant('ACCOUNTANT', 'Accountant', 40),
  salesStaff('SALES STAFF', 'Sales Staff', 50),
  serviceAdvisor('SERVICE ADVISOR', 'Service Advisor', 50),
  technician('TECHNICIAN', 'Technician', 60),
  viewer('VIEWER', 'Viewer', 90);

  const AppRole(this.value, this.label, this.rank);

  /// Exact `roles.name` value in the database.
  final String value;

  /// Human readable label for the UI.
  final String label;

  /// Lower rank means broader authority. Used only for ordering role pickers
  /// and for choosing which dashboard layout to present.
  final int rank;

  static AppRole? fromValue(String? value) {
    for (final AppRole role in AppRole.values) {
      if (role.value == value) {
        return role;
      }
    }
    return null;
  }

  /// Roles that are not scoped to a single showroom.
  bool get isPrivileged => rank <= 10;
}

/// Customer classification. Drives pricing rules and document requirements.
enum CustomerType {
  individual('INDIVIDUAL', 'Individual'),
  corporate('CORPORATE', 'Corporate'),
  dealer('DEALER', 'Dealer'),
  government('GOVERNMENT', 'Government');

  const CustomerType(this.value, this.label);

  final String value;
  final String label;

  static CustomerType fromValue(String? value) =>
      CustomerType.values.firstWhere(
        (CustomerType type) => type.value == value,
        orElse: () => CustomerType.individual,
      );

  /// Non-individual buyers must supply a GST number to claim input credit.
  bool get requiresGstNumber => this != CustomerType.individual;
}

/// Generic active / inactive state shared by master-data tables such as
/// showrooms, brands, products, suppliers and finance companies.
enum RecordStatus {
  active('ACTIVE', 'Active'),
  inactive('INACTIVE', 'Inactive');

  const RecordStatus(this.value, this.label);

  final String value;
  final String label;

  static RecordStatus fromValue(String? value) =>
      RecordStatus.values.firstWhere(
        (RecordStatus status) => status.value == value,
        orElse: () => RecordStatus.active,
      );

  bool get isActive => this == RecordStatus.active;
}
