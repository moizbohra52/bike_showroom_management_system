import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:flutter/painting.dart';

/// A colour a product is available in (`product_colors`).
///
/// Colours belong to the catalogue rather than to a branch, and a physical
/// unit in `inventory` points at one of them. Retiring a colour therefore
/// sets [isActive] to false instead of deleting the row — units already in
/// stock, and every sale that has ever referenced it, still need it to
/// resolve.
class ProductColorModel {
  const ProductColorModel({
    required this.id,
    required this.productId,
    required this.colorName,
    required this.hexCode,
    this.isActive = true,
    this.createdAt,
  });

  factory ProductColorModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ProductColorModel(
      id: reader.requireString('id'),
      productId: reader.string('product_id'),
      colorName: reader.string('color_name'),
      hexCode: reader.string('hex_code', fallback: '#000000'),
      isActive: reader.boolean('is_active', fallback: true),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String productId;
  final String colorName;

  /// `#RRGGBB`. The database enforces the format, so a stored value always
  /// parses; [swatch] still falls back rather than throwing, because a row
  /// can also arrive from the local cache written by an older build.
  final String hexCode;

  final bool isActive;
  final DateTime? createdAt;

  /// The colour as a Flutter [Color], for the swatch shown beside the name.
  Color get swatch {
    final String cleaned = hexCode.replaceFirst('#', '').trim();
    if (cleaned.length != 6) {
      return const Color(0xFF9E9E9E);
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return const Color(0xFF9E9E9E);
    }
    return Color(0xFF000000 | value);
  }

  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'product_id': productId,
    'color_name': colorName.trim(),
    'hex_code': hexCode.trim().toUpperCase(),
    'is_active': isActive,
  });

  ProductColorModel copyWith({
    String? colorName,
    String? hexCode,
    bool? isActive,
  }) => ProductColorModel(
    id: id,
    productId: productId,
    colorName: colorName ?? this.colorName,
    hexCode: hexCode ?? this.hexCode,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ProductColorModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductColor($colorName $hexCode)';
}
