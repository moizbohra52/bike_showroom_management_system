import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// A warranty on a customer's vehicle (`warranties`).
///
/// The standard one is created by `create_sale_transaction` at the moment of
/// sale, running from the sale date for the product's warranty period.
/// Extended, engine, battery and paint cover is added separately.
///
/// [status] is maintained by `derive_warranty_status`, not by the client: it
/// moves to EXPIRING_SOON and then EXPIRED on its own, so a stale app cannot
/// show cover that has lapsed.
class WarrantyModel implements SyncableModel {
  const WarrantyModel({
    required this.id,
    required this.showroomId,
    required this.vehicleId,
    required this.startDate,
    required this.endDate,
    this.warrantyType = WarrantyType.standard,
    this.vehicleRegistration,
    this.vehicleChassis,
    this.customerName,
    this.customerPhone,
    this.terms,
    this.coveredComponents = const <String, Object?>{},
    this.status = WarrantyStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory WarrantyModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader vehicle = JsonReader(
      reader.objectOrNull('customer_vehicles') ?? const <String, Object?>{},
    );
    final JsonReader customer = JsonReader(
      vehicle.objectOrNull('customers') ?? const <String, Object?>{},
    );

    return WarrantyModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      vehicleId: reader.string('vehicle_id'),
      startDate: reader.dateOrNull('start_date') ?? DateTime.now(),
      endDate: reader.dateOrNull('end_date') ?? DateTime.now(),
      warrantyType: WarrantyType.fromValue(
        reader.stringOrNull('warranty_type'),
      ),
      vehicleRegistration: vehicle.stringOrNull('registration_number'),
      vehicleChassis: vehicle.stringOrNull('chassis_number'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      terms: reader.stringOrNull('terms'),
      coveredComponents: reader.jsonObject('covered_components'),
      status: WarrantyStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String vehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final WarrantyType warrantyType;

  // Denormalised from the embedded vehicle and its owner.
  final String? vehicleRegistration;
  final String? vehicleChassis;
  final String? customerName;
  final String? customerPhone;

  final String? terms;

  /// Free-form `jsonb`, so adding a covered component needs no migration.
  final Map<String, Object?> coveredComponents;

  final WarrantyStatus status;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status == WarrantyStatus.active;

  bool get isExpired =>
      status == WarrantyStatus.expired || DateUtil.isExpired(endDate);

  bool get isVoided => status == WarrantyStatus.voided;

  /// Whether a claim can be raised against this cover.
  ///
  /// A lapsed or voided warranty covers nothing, so offering the action would
  /// only produce a claim that must then be rejected.
  bool get acceptsClaim => !isExpired && !isVoided;

  bool get isExpiringSoon =>
      status == WarrantyStatus.expiringSoon ||
      (!isExpired && DateUtil.isExpiringSoon(endDate));

  int get daysRemaining => DateUtil.daysUntil(endDate);

  String get vehicleLabel =>
      vehicleRegistration != null && vehicleRegistration!.isNotEmpty
      ? vehicleRegistration!
      : (vehicleChassis ?? 'Unknown vehicle');

  String get formattedEndDate => DateUtil.format(endDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'vehicle_id': vehicleId,
    'warranty_type': warrantyType.value,
    'start_date': DateUtil.toIsoDateOrNull(startDate),
    'end_date': DateUtil.toIsoDateOrNull(endDate),
    'terms': terms,
    'covered_components': coveredComponents,
    // `status` is derived server-side by `derive_warranty_status`; writing it
    // from here would be overwritten on the next trigger pass anyway.
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
  bool operator ==(Object other) => other is WarrantyModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Warranty(${warrantyType.value} $vehicleLabel)';
}

/// A claim against a warranty (`warranty_claims`).
class WarrantyClaimModel implements SyncableModel {
  const WarrantyClaimModel({
    required this.id,
    required this.showroomId,
    required this.warrantyId,
    required this.claimNumber,
    required this.claimDate,
    required this.description,
    this.serviceId,
    this.vehicleLabel,
    this.customerName,
    this.warrantyType,
    this.claimAmount = 0,
    this.approvedAmount = 0,
    this.status = WarrantyClaimStatus.draft,
    this.resolution,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory WarrantyClaimModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader warranty = JsonReader(
      reader.objectOrNull('warranties') ?? const <String, Object?>{},
    );
    final JsonReader vehicle = JsonReader(
      warranty.objectOrNull('customer_vehicles') ?? const <String, Object?>{},
    );
    final JsonReader customer = JsonReader(
      vehicle.objectOrNull('customers') ?? const <String, Object?>{},
    );

    final String? registration = vehicle.stringOrNull('registration_number');
    final String? chassis = vehicle.stringOrNull('chassis_number');

    return WarrantyClaimModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      warrantyId: reader.string('warranty_id'),
      claimNumber: reader.string('claim_number'),
      claimDate: reader.dateOrNull('claim_date') ?? DateTime.now(),
      description: reader.string('description'),
      serviceId: reader.stringOrNull('service_id'),
      vehicleLabel: registration != null && registration.isNotEmpty
          ? registration
          : chassis,
      customerName: customer.stringOrNull('name'),
      warrantyType: warranty.stringOrNull('warranty_type'),
      claimAmount: reader.money('claim_amount'),
      approvedAmount: reader.money('approved_amount'),
      status: WarrantyClaimStatus.fromValue(reader.stringOrNull('status')),
      resolution: reader.stringOrNull('resolution'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String warrantyId;

  /// From `next_document_number(..., 'CLAIM')`.
  final String claimNumber;

  final DateTime claimDate;
  final String description;

  /// The job card the claim was raised from, when there is one.
  final String? serviceId;

  final String? vehicleLabel;
  final String? customerName;
  final String? warrantyType;

  /// What the showroom asked the manufacturer for.
  final double claimAmount;

  /// What the manufacturer actually allowed — the two differ often enough
  /// that both are worth showing.
  final double approvedAmount;

  final WarrantyClaimStatus status;
  final String? resolution;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isOpen =>
      status == WarrantyClaimStatus.draft ||
      status == WarrantyClaimStatus.submitted ||
      status == WarrantyClaimStatus.underReview;

  bool get isSettled => status == WarrantyClaimStatus.settled;

  /// The shortfall the showroom absorbs on a partly allowed claim.
  double get shortfall {
    if (status != WarrantyClaimStatus.approved && !isSettled) {
      return 0;
    }
    final double gap = claimAmount - approvedAmount;
    return gap < 0 ? 0 : gap;
  }

  String get formattedClaimAmount => MoneyUtil.format(claimAmount);

  String get formattedApprovedAmount => MoneyUtil.format(approvedAmount);

  String get formattedDate => DateUtil.format(claimDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'warranty_id': warrantyId,
    'service_id': serviceId,
    'claim_number': claimNumber,
    'claim_date': DateUtil.toIsoDateOrNull(claimDate),
    'description': description.trim(),
    'claim_amount': claimAmount,
    'approved_amount': approvedAmount,
    'status': status.value,
    'resolution': resolution,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    ...toJson(),
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is WarrantyClaimModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WarrantyClaim($claimNumber ${status.value})';
}
