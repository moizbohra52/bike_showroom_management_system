import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// A supplier the showroom buys from (`suppliers`).
///
/// Shared across showrooms, like brands and financiers: the same distributor
/// supplies every branch, and splitting it per branch would fragment one
/// supplier's payable balance across several records that no statement could
/// be reconciled against.
class SupplierModel implements SyncableModel {
  const SupplierModel({
    required this.id,
    required this.name,
    this.code,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    this.panNumber,
    this.status = RecordStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return SupplierModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      code: reader.stringOrNull('code'),
      phone: reader.stringOrNull('phone'),
      email: reader.stringOrNull('email'),
      address: reader.stringOrNull('address'),
      city: reader.stringOrNull('city'),
      state: reader.stringOrNull('state'),
      pincode: reader.stringOrNull('pincode'),
      gstNumber: reader.stringOrNull('gst_number'),
      panNumber: reader.stringOrNull('pan_number'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String name;
  final String? code;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;

  /// Needed to claim input tax credit on what this supplier invoices.
  final String? gstNumber;

  final String? panNumber;
  final RecordStatus status;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.isActive;

  String get formattedAddress {
    final List<String> parts = <String>[
      if (address != null && address!.isNotEmpty) address!,
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (pincode != null && pincode!.isNotEmpty) pincode!,
    ];
    return parts.join(', ');
  }

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'code': code?.trim().toUpperCase(),
    'phone': phone,
    'email': email?.trim().toLowerCase(),
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'gst_number': gstNumber?.toUpperCase(),
    'pan_number': panNumber?.toUpperCase(),
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
  bool operator ==(Object other) => other is SupplierModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Supplier($name)';
}
