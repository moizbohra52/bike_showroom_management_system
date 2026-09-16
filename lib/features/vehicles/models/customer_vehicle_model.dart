import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';

/// A vehicle owned by a customer (`customer_vehicles`).
///
/// Distinct from `inventory` on purpose. A row in `inventory` is a machine the
/// showroom owns and can sell; a row here is the same machine *after* it has
/// been sold, now carrying a registration number, an odometer reading,
/// warranty and insurance dates, and a service schedule. Keeping them apart
/// means selling a unit does not have to mutate a stock row into something
/// with entirely different rules — and lets the showroom service a vehicle it
/// never sold, which has no inventory row at all.
class CustomerVehicleModel implements SyncableModel {
  const CustomerVehicleModel({
    required this.id,
    required this.showroomId,
    required this.customerId,
    required this.productId,
    required this.chassisNumber,
    required this.engineNumber,
    this.inventoryId,
    this.customerName,
    this.customerPhone,
    this.productName,
    this.brandName,
    this.registrationNumber,
    this.registrationDate,
    this.purchaseDate,
    this.deliveryDate,
    this.currentOdometer = 0,
    this.warrantyStart,
    this.warrantyEnd,
    this.insuranceStart,
    this.insuranceEnd,
    this.nextServiceDate,
    this.nextServiceKm,
    this.status = VehicleStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerVehicleModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader product = JsonReader(
      reader.objectOrNull('products') ?? const <String, Object?>{},
    );
    final JsonReader brand = JsonReader(
      product.objectOrNull('brands') ?? const <String, Object?>{},
    );

    return CustomerVehicleModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerId: reader.string('customer_id'),
      productId: reader.string('product_id'),
      chassisNumber: reader.string('chassis_number'),
      engineNumber: reader.string('engine_number'),
      inventoryId: reader.stringOrNull('inventory_id'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      productName: product.stringOrNull('name'),
      brandName: brand.stringOrNull('name'),
      registrationNumber: reader.stringOrNull('registration_number'),
      registrationDate: reader.dateOrNull('registration_date'),
      purchaseDate: reader.dateOrNull('purchase_date'),
      deliveryDate: reader.dateOrNull('delivery_date'),
      currentOdometer: reader.integer('current_odometer'),
      warrantyStart: reader.dateOrNull('warranty_start'),
      warrantyEnd: reader.dateOrNull('warranty_end'),
      insuranceStart: reader.dateOrNull('insurance_start'),
      insuranceEnd: reader.dateOrNull('insurance_end'),
      nextServiceDate: reader.dateOrNull('next_service_date'),
      nextServiceKm: reader.intOrNull('next_service_km'),
      status: VehicleStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String customerId;
  final String productId;
  final String chassisNumber;
  final String engineNumber;

  /// The stock unit this vehicle came from, when the showroom sold it. Null
  /// for a vehicle bought elsewhere and brought in only for service.
  final String? inventoryId;

  // Denormalised from embedded relations for display.
  final String? customerName;
  final String? customerPhone;
  final String? productName;
  final String? brandName;

  final String? registrationNumber;
  final DateTime? registrationDate;
  final DateTime? purchaseDate;
  final DateTime? deliveryDate;

  /// Kilometres on the clock. Only ever moves up — `guard_odometer_monotonic`
  /// rejects a lower reading, because a falling odometer is either a typo or
  /// tampering and both need to be caught at entry.
  final int currentOdometer;

  final DateTime? warrantyStart;
  final DateTime? warrantyEnd;
  final DateTime? insuranceStart;
  final DateTime? insuranceEnd;
  final DateTime? nextServiceDate;
  final int? nextServiceKm;
  final VehicleStatus status;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isServiceable => status.isServiceable;

  /// `MP09AB1234`, or the chassis number when the vehicle is not yet
  /// registered — a new delivery has no plate for several weeks.
  String get displayIdentifier =>
      registrationNumber != null && registrationNumber!.isNotEmpty
      ? registrationNumber!
      : chassisNumber;

  String get displayName {
    final List<String> parts = <String>[
      if (brandName != null && brandName!.isNotEmpty) brandName!,
      if (productName != null && productName!.isNotEmpty) productName!,
    ];
    return parts.isEmpty ? displayIdentifier : parts.join(' ');
  }

  bool get isWarrantyActive =>
      warrantyEnd != null && !DateUtil.isExpired(warrantyEnd);

  bool get isInsuranceActive =>
      insuranceEnd != null && !DateUtil.isExpired(insuranceEnd);

  /// Insurance lapsing inside a month is the single most common reason a
  /// showroom calls a customer, so it is surfaced on the list row.
  bool get isInsuranceExpiringSoon =>
      insuranceEnd != null && DateUtil.isExpiringSoon(insuranceEnd);

  bool get isServiceDue =>
      nextServiceDate != null && !DateUtil.isFuture(nextServiceDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'customer_id': customerId,
    'product_id': productId,
    'inventory_id': inventoryId,
    'chassis_number': chassisNumber.trim().toUpperCase(),
    'engine_number': engineNumber.trim().toUpperCase(),
    'registration_number': registrationNumber?.trim().toUpperCase(),
    'registration_date': DateUtil.toIsoDateOrNull(registrationDate),
    'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate),
    'delivery_date': DateUtil.toIsoDateOrNull(deliveryDate),
    'current_odometer': currentOdometer,
    'warranty_start': DateUtil.toIsoDateOrNull(warrantyStart),
    'warranty_end': DateUtil.toIsoDateOrNull(warrantyEnd),
    'insurance_start': DateUtil.toIsoDateOrNull(insuranceStart),
    'insurance_end': DateUtil.toIsoDateOrNull(insuranceEnd),
    'next_service_date': DateUtil.toIsoDateOrNull(nextServiceDate),
    'next_service_km': nextServiceKm,
    'status': status.value,
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
      other is CustomerVehicleModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CustomerVehicle($displayIdentifier)';
}
