import 'package:bike_showroom_management_system/common/models/json_reader.dart';

/// A catalogue image for a product (`product_images`).
///
/// The row carries both a public-ish [imageUrl] and the private
/// [storagePath] it was derived from. Keeping the path is what lets a signed
/// URL be reissued when the old one expires; keeping only the URL would make
/// the image unreachable the moment its signature lapsed.
///
/// Uploading arrives with the storage layer in Phase 9. Until then this model
/// exists so a product that already has images (seeded, or added through the
/// Supabase dashboard) renders correctly everywhere a thumbnail is shown.
class ProductImageModel {
  const ProductImageModel({
    required this.id,
    required this.productId,
    required this.imageUrl,
    this.colorId,
    this.thumbnailUrl,
    this.storagePath,
    this.isPrimary = false,
    this.sortOrder = 0,
    this.watermarkEnabled = false,
    this.createdAt,
  });

  factory ProductImageModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ProductImageModel(
      id: reader.requireString('id'),
      productId: reader.string('product_id'),
      imageUrl: reader.string('image_url'),
      colorId: reader.stringOrNull('color_id'),
      thumbnailUrl: reader.stringOrNull('thumbnail_url'),
      storagePath: reader.stringOrNull('storage_path'),
      isPrimary: reader.boolean('is_primary'),
      sortOrder: reader.integer('sort_order'),
      watermarkEnabled: reader.boolean('watermark_enabled'),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String productId;
  final String imageUrl;

  /// Set when the image shows one specific colour variant.
  final String? colorId;

  final String? thumbnailUrl;
  final String? storagePath;
  final bool isPrimary;
  final int sortOrder;
  final bool watermarkEnabled;
  final DateTime? createdAt;

  /// Prefers the thumbnail for list rows: a full-resolution bike photo over a
  /// showroom's mobile connection is a page of wasted bandwidth per row.
  String get displayUrl => thumbnailUrl != null && thumbnailUrl!.isNotEmpty
      ? thumbnailUrl!
      : imageUrl;

  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'product_id': productId,
    'color_id': colorId,
    'image_url': imageUrl,
    'thumbnail_url': thumbnailUrl,
    'storage_path': storagePath,
    'is_primary': isPrimary,
    'sort_order': sortOrder,
    'watermark_enabled': watermarkEnabled,
  });

  @override
  bool operator ==(Object other) =>
      other is ProductImageModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductImage($id primary=$isPrimary)';
}
