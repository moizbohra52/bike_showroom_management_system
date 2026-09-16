/// Workshop, warranty and insurance enumerations.
library;

/// Commercial nature of a service visit. Decides whether labour is chargeable
/// and which revenue account the invoice posts to.
enum ServiceType {
  free('FREE', 'Free Service'),
  paid('PAID', 'Paid Service'),
  warranty('WARRANTY', 'Warranty Service');

  const ServiceType(this.value, this.label);

  final String value;
  final String label;

  static ServiceType fromValue(String? value) => ServiceType.values.firstWhere(
    (ServiceType type) => type.value == value,
    orElse: () => ServiceType.paid,
  );

  /// Free and warranty jobs do not bill labour to the customer.
  bool get billsLabourToCustomer => this == ServiceType.paid;

  /// Warranty jobs must be backed by an active warranty claim.
  bool get requiresWarrantyClaim => this == ServiceType.warranty;
}

/// Job-card progression through the workshop.
enum ServiceStatus {
  booked('BOOKED', 'Booked'),
  received('RECEIVED', 'Vehicle Received'),
  inProgress('IN_PROGRESS', 'In Progress'),
  waitingForParts('WAITING_FOR_PARTS', 'Waiting For Parts'),
  completed('COMPLETED', 'Completed'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled');

  const ServiceStatus(this.value, this.label);

  final String value;
  final String label;

  static ServiceStatus fromValue(String? value) =>
      ServiceStatus.values.firstWhere(
        (ServiceStatus status) => status.value == value,
        orElse: () => ServiceStatus.booked,
      );

  /// Line items may only be added while the vehicle is in the workshop.
  bool get acceptsItems =>
      this == ServiceStatus.received ||
      this == ServiceStatus.inProgress ||
      this == ServiceStatus.waitingForParts;

  /// A completed job has been invoiced and posted to the ledger.
  bool get isFinalised =>
      this == ServiceStatus.completed || this == ServiceStatus.delivered;

  bool get isOpen =>
      this == ServiceStatus.booked ||
      this == ServiceStatus.received ||
      this == ServiceStatus.inProgress ||
      this == ServiceStatus.waitingForParts;

  /// Valid next states, used to drive the job-card action buttons and to
  /// reject illegal transitions before they reach the server.
  List<ServiceStatus> get allowedTransitions {
    switch (this) {
      case ServiceStatus.booked:
        return <ServiceStatus>[ServiceStatus.received, ServiceStatus.cancelled];
      case ServiceStatus.received:
        return <ServiceStatus>[
          ServiceStatus.inProgress,
          ServiceStatus.cancelled,
        ];
      case ServiceStatus.inProgress:
        return <ServiceStatus>[
          ServiceStatus.waitingForParts,
          ServiceStatus.completed,
          ServiceStatus.cancelled,
        ];
      case ServiceStatus.waitingForParts:
        return <ServiceStatus>[
          ServiceStatus.inProgress,
          ServiceStatus.cancelled,
        ];
      case ServiceStatus.completed:
        return <ServiceStatus>[ServiceStatus.delivered];
      case ServiceStatus.delivered:
      case ServiceStatus.cancelled:
        return const <ServiceStatus>[];
    }
  }
}

/// Classification of a service line item. Parts draw from stock, labour does
/// not, and the distinction drives both costing and the ledger split.
enum ServiceItemType {
  part('PART', 'Part'),
  labour('LABOUR', 'Labour'),
  oil('OIL', 'Oil'),
  consumable('CONSUMABLE', 'Consumable'),
  accessory('ACCESSORY', 'Accessory'),
  other('OTHER', 'Other');

  const ServiceItemType(this.value, this.label);

  final String value;
  final String label;

  static ServiceItemType fromValue(String? value) =>
      ServiceItemType.values.firstWhere(
        (ServiceItemType type) => type.value == value,
        orElse: () => ServiceItemType.other,
      );

  /// Physical goods that must be linked to a product for stock costing.
  bool get isStockItem => this != ServiceItemType.labour;
}

/// Consumption state of a single entitled free service.
enum FreeServiceStatus {
  upcoming('UPCOMING', 'Upcoming'),
  due('DUE', 'Due'),
  used('USED', 'Used'),
  expired('EXPIRED', 'Expired'),
  cancelled('CANCELLED', 'Cancelled');

  const FreeServiceStatus(this.value, this.label);

  final String value;
  final String label;

  static FreeServiceStatus fromValue(String? value) =>
      FreeServiceStatus.values.firstWhere(
        (FreeServiceStatus status) => status.value == value,
        orElse: () => FreeServiceStatus.upcoming,
      );

  /// Eligibility is a function of date, odometer and this status. All three are
  /// re-checked by `complete_service()` before the entitlement is consumed.
  bool get isClaimable =>
      this == FreeServiceStatus.upcoming || this == FreeServiceStatus.due;
}

/// Kind of warranty cover attached to a vehicle.
enum WarrantyType {
  standard('STANDARD', 'Standard Warranty'),
  extended('EXTENDED', 'Extended Warranty'),
  engine('ENGINE', 'Engine Warranty'),
  battery('BATTERY', 'Battery Warranty'),
  paint('PAINT', 'Paint Warranty');

  const WarrantyType(this.value, this.label);

  final String value;
  final String label;

  static WarrantyType fromValue(String? value) =>
      WarrantyType.values.firstWhere(
        (WarrantyType type) => type.value == value,
        orElse: () => WarrantyType.standard,
      );
}

/// Validity state of a warranty.
enum WarrantyStatus {
  active('ACTIVE', 'Active'),
  expiringSoon('EXPIRING_SOON', 'Expiring Soon'),
  expired('EXPIRED', 'Expired'),
  voided('VOIDED', 'Voided'),
  cancelled('CANCELLED', 'Cancelled');

  const WarrantyStatus(this.value, this.label);

  final String value;
  final String label;

  static WarrantyStatus fromValue(String? value) =>
      WarrantyStatus.values.firstWhere(
        (WarrantyStatus status) => status.value == value,
        orElse: () => WarrantyStatus.active,
      );

  /// A claim raised outside this set needs an explicit override permission.
  bool get acceptsClaims =>
      this == WarrantyStatus.active || this == WarrantyStatus.expiringSoon;
}

/// Progress of a warranty claim against the manufacturer.
enum WarrantyClaimStatus {
  draft('DRAFT', 'Draft'),
  submitted('SUBMITTED', 'Submitted'),
  underReview('UNDER_REVIEW', 'Under Review'),
  approved('APPROVED', 'Approved'),
  rejected('REJECTED', 'Rejected'),
  settled('SETTLED', 'Settled'),
  cancelled('CANCELLED', 'Cancelled');

  const WarrantyClaimStatus(this.value, this.label);

  final String value;
  final String label;

  static WarrantyClaimStatus fromValue(String? value) =>
      WarrantyClaimStatus.values.firstWhere(
        (WarrantyClaimStatus status) => status.value == value,
        orElse: () => WarrantyClaimStatus.draft,
      );

  bool get isOpen =>
      this == WarrantyClaimStatus.draft ||
      this == WarrantyClaimStatus.submitted ||
      this == WarrantyClaimStatus.underReview;
}

/// Kind of motor insurance policy.
enum InsurancePolicyType {
  comprehensive('COMPREHENSIVE', 'Comprehensive'),
  thirdParty('THIRD_PARTY', 'Third Party'),
  ownDamage('OWN_DAMAGE', 'Own Damage'),
  zeroDepreciation('ZERO_DEPRECIATION', 'Zero Depreciation');

  const InsurancePolicyType(this.value, this.label);

  final String value;
  final String label;

  static InsurancePolicyType fromValue(String? value) =>
      InsurancePolicyType.values.firstWhere(
        (InsurancePolicyType type) => type.value == value,
        orElse: () => InsurancePolicyType.comprehensive,
      );
}

/// Validity state of an insurance policy.
enum InsuranceStatus {
  active('ACTIVE', 'Active'),
  expiringSoon('EXPIRING_SOON', 'Expiring Soon'),
  expired('EXPIRED', 'Expired'),
  cancelled('CANCELLED', 'Cancelled');

  const InsuranceStatus(this.value, this.label);

  final String value;
  final String label;

  static InsuranceStatus fromValue(String? value) =>
      InsuranceStatus.values.firstWhere(
        (InsuranceStatus status) => status.value == value,
        orElse: () => InsuranceStatus.active,
      );

  bool get isValid =>
      this == InsuranceStatus.active || this == InsuranceStatus.expiringSoon;
}
