import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// A motor insurance policy on a customer's vehicle (`insurance_policies`).
///
/// [status] is derived server-side by `derive_insurance_status` — ACTIVE,
/// then EXPIRING_SOON, then EXPIRED — so the renewal list cannot show cover
/// that has already lapsed because an app was left open.
///
/// Renewals matter commercially: a lapsed policy is the single most common
/// reason a showroom telephones a customer, and the reminder engine works
/// from exactly this table.
class InsurancePolicyModel implements SyncableModel {
  const InsurancePolicyModel({
    required this.id,
    required this.showroomId,
    required this.vehicleId,
    required this.insuranceCompany,
    required this.policyNumber,
    required this.startDate,
    required this.expiryDate,
    this.policyType = InsurancePolicyType.comprehensive,
    this.vehicleRegistration,
    this.vehicleChassis,
    this.customerName,
    this.customerPhone,
    this.premium = 0,
    this.sumInsured = 0,
    this.documentUrl,
    this.status = InsuranceStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory InsurancePolicyModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader vehicle = JsonReader(
      reader.objectOrNull('customer_vehicles') ?? const <String, Object?>{},
    );
    final JsonReader customer = JsonReader(
      vehicle.objectOrNull('customers') ?? const <String, Object?>{},
    );

    return InsurancePolicyModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      vehicleId: reader.string('vehicle_id'),
      insuranceCompany: reader.string('insurance_company'),
      policyNumber: reader.string('policy_number'),
      startDate: reader.dateOrNull('start_date') ?? DateTime.now(),
      expiryDate: reader.dateOrNull('expiry_date') ?? DateTime.now(),
      policyType: InsurancePolicyType.fromValue(
        reader.stringOrNull('policy_type'),
      ),
      vehicleRegistration: vehicle.stringOrNull('registration_number'),
      vehicleChassis: vehicle.stringOrNull('chassis_number'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      premium: reader.money('premium'),
      sumInsured: reader.money('sum_insured'),
      documentUrl: reader.stringOrNull('document_url'),
      status: InsuranceStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String vehicleId;
  final String insuranceCompany;
  final String policyNumber;
  final DateTime startDate;
  final DateTime expiryDate;
  final InsurancePolicyType policyType;

  // Denormalised from the embedded vehicle and its owner.
  final String? vehicleRegistration;
  final String? vehicleChassis;
  final String? customerName;
  final String? customerPhone;

  final double premium;

  /// The insured declared value.
  final double sumInsured;

  /// The scanned policy in storage. Upload arrives with Phase 9; a URL already
  /// recorded renders here.
  final String? documentUrl;

  final InsuranceStatus status;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isExpired =>
      status == InsuranceStatus.expired || DateUtil.isExpired(expiryDate);

  bool get isActive => status == InsuranceStatus.active && !isExpired;

  bool get isExpiringSoon =>
      status == InsuranceStatus.expiringSoon ||
      (!isExpired && DateUtil.isExpiringSoon(expiryDate));

  /// Whether this policy belongs on a renewal call list.
  bool get needsRenewalCall => isExpired || isExpiringSoon;

  int get daysRemaining => DateUtil.daysUntil(expiryDate);

  int get daysExpired => isExpired ? DateUtil.daysOverdue(expiryDate) : 0;

  String get vehicleLabel =>
      vehicleRegistration != null && vehicleRegistration!.isNotEmpty
      ? vehicleRegistration!
      : (vehicleChassis ?? 'Unknown vehicle');

  String get formattedPremium => MoneyUtil.format(premium);

  String get formattedSumInsured => MoneyUtil.format(sumInsured);

  String get formattedExpiry => DateUtil.format(expiryDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'vehicle_id': vehicleId,
    'insurance_company': insuranceCompany.trim(),
    'policy_number': policyNumber.trim(),
    'policy_type': policyType.value,
    'start_date': DateUtil.toIsoDateOrNull(startDate),
    'expiry_date': DateUtil.toIsoDateOrNull(expiryDate),
    'premium': premium,
    'sum_insured': sumInsured,
    'document_url': documentUrl,
    // `status` is derived by `derive_insurance_status`.
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    ...toJson(),
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is InsurancePolicyModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'InsurancePolicy($policyNumber $vehicleLabel)';
}
