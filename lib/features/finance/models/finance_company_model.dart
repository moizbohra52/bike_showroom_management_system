import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// A financier the showroom places loans with (`finance_companies`).
///
/// Shared across showrooms rather than scoped to one: the same bank finances
/// customers at every branch, and duplicating it per branch would split one
/// financier's outstanding book across several records.
class FinanceCompanyModel implements SyncableModel {
  const FinanceCompanyModel({
    required this.id,
    required this.name,
    required this.code,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.status = RecordStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory FinanceCompanyModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return FinanceCompanyModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      code: reader.string('code'),
      contactPerson: reader.stringOrNull('contact_person'),
      phone: reader.stringOrNull('phone'),
      email: reader.stringOrNull('email'),
      address: reader.stringOrNull('address'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String name;
  final String code;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final RecordStatus status;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.isActive;

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'code': code.trim().toUpperCase(),
    'contact_person': contactPerson,
    'phone': phone,
    'email': email?.trim().toLowerCase(),
    'address': address,
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
      other is FinanceCompanyModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FinanceCompany($code $name)';
}
