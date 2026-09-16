import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// A row from `brands` — the manufacturer a product belongs to.
///
/// Brands are deliberately **not** scoped by showroom. A Honda is a Honda at
/// every branch, and duplicating the catalogue per showroom would make the
/// same model appear several times in a group-wide stock report. Access is
/// governed by the `products` permission module instead of by tenancy (see
/// `brands_select` in `009_rls.sql`).
class BrandModel implements SyncableModel {
  const BrandModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.status = RecordStatus.active,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory BrandModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return BrandModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      logoUrl: reader.stringOrNull('logo_url'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String name;
  final String? logoUrl;
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
    'logo_url': logoUrl,
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

  BrandModel copyWith({String? name, String? logoUrl, RecordStatus? status}) =>
      BrandModel(
        id: id,
        name: name ?? this.name,
        logoUrl: logoUrl ?? this.logoUrl,
        status: status ?? this.status,
        revision: revision,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  bool operator ==(Object other) => other is BrandModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Brand($name)';
}
