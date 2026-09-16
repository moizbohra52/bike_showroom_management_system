import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_image_model.dart';

/// A row from `products` — one catalogue entry.
///
/// Like [BrandModel] this is shared across showrooms rather than scoped to
/// one: a branch stocks units of a product, it does not own the product
/// definition. Per-branch figures (how many are on hand, what they cost)
/// live in `inventory`, which *is* scoped.
///
/// The table also holds accessories, spare parts and lubricants, separated
/// from vehicles by [category]. Only a serialised vehicle gets a row per
/// physical unit in `inventory`; see
/// [ProductCategory.isSerialisedVehicle].
class ProductModel implements SyncableModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.brandId,
    this.brandName,
    this.model,
    this.variant,
    this.category = ProductCategory.motorcycle,
    this.engineCc,
    this.fuelType = FuelType.petrol,
    this.transmission = TransmissionType.manual,
    this.mileage,
    this.description,
    this.basePrice = 0,
    this.sellingPrice = 0,
    this.taxRate = 18,
    this.warrantyMonths = 24,
    this.hsnCode,
    this.status = RecordStatus.active,
    this.colors = const <ProductColorModel>[],
    this.images = const <ProductImageModel>[],
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ProductModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      brandId: reader.stringOrNull('brand_id'),
      // Present only when the caller embedded `brands(...)` in the select.
      brandName: JsonReader(
        reader.objectOrNull('brands') ?? const <String, Object?>{},
      ).stringOrNull('name'),
      model: reader.stringOrNull('model'),
      variant: reader.stringOrNull('variant'),
      category: ProductCategory.fromValue(reader.stringOrNull('category')),
      engineCc: reader.intOrNull('engine_cc'),
      fuelType: FuelType.fromValue(reader.stringOrNull('fuel_type')),
      transmission: TransmissionType.fromValue(
        reader.stringOrNull('transmission'),
      ),
      mileage: reader.doubleOrNull('mileage'),
      description: reader.stringOrNull('description'),
      basePrice: reader.money('base_price'),
      sellingPrice: reader.money('selling_price'),
      taxRate: reader.money('tax_rate', fallback: 18),
      warrantyMonths: reader.integer('warranty_months', fallback: 24),
      hsnCode: reader.stringOrNull('hsn_code'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      colors: reader.list('product_colors', ProductColorModel.fromJson),
      images: reader.list('product_images', ProductImageModel.fromJson),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String name;
  final String? brandId;

  /// Denormalised from an embedded `brands(name)` for display. Never written
  /// back — it is not a column on `products`.
  final String? brandName;

  final String? model;
  final String? variant;
  final ProductCategory category;
  final int? engineCc;
  final FuelType fuelType;
  final TransmissionType transmission;
  final double? mileage;
  final String? description;

  /// Ex-showroom price before tax.
  final double basePrice;

  /// Price quoted to the customer. A sale may still discount from here, which
  /// is why the two are separate columns rather than one.
  final double sellingPrice;

  final double taxRate;
  final int warrantyMonths;
  final String? hsnCode;
  final RecordStatus status;

  final List<ProductColorModel> colors;
  final List<ProductImageModel> images;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.isActive;

  bool get isSerialisedVehicle => category.isSerialisedVehicle;

  List<ProductColorModel> get activeColors => colors
      .where((ProductColorModel color) => color.isActive)
      .toList(growable: false);

  /// The image to show in a list row, if any.
  ProductImageModel? get primaryImage {
    if (images.isEmpty) {
      return null;
    }
    for (final ProductImageModel image in images) {
      if (image.isPrimary) {
        return image;
      }
    }
    final List<ProductImageModel> sorted = List<ProductImageModel>.of(images)
      ..sort(
        (ProductImageModel a, ProductImageModel b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );
    return sorted.first;
  }

  /// `Honda Shine 125 Drum` — what a salesperson would say out loud.
  String get displayName {
    final List<String> parts = <String>[
      if (brandName != null && brandName!.isNotEmpty) brandName!,
      name,
      if (variant != null && variant!.isNotEmpty) variant!,
    ];
    return parts.join(' ');
  }

  /// `125 cc - Petrol - Manual`, omitting whatever does not apply. An electric
  /// scooter has no engine displacement, so showing "0 cc" would be wrong
  /// rather than merely empty.
  String get specSummary {
    final List<String> parts = <String>[
      if (engineCc != null && engineCc! > 0) '$engineCc cc',
      fuelType.label,
      if (category.isSerialisedVehicle) transmission.label,
      if (mileage != null && mileage! > 0)
        '${mileage!.toStringAsFixed(1)} kmpl',
    ];
    return parts.join(' - ');
  }

  String get formattedSellingPrice => MoneyUtil.format(sellingPrice);

  String get formattedBasePrice => MoneyUtil.format(basePrice);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'brand_id': brandId,
    'name': name.trim(),
    'model': model,
    'variant': variant,
    'category': category.value,
    'engine_cc': engineCc,
    'fuel_type': fuelType.value,
    'transmission': transmission.value,
    'mileage': mileage,
    'description': description,
    'base_price': basePrice,
    'selling_price': sellingPrice,
    'tax_rate': taxRate,
    'warranty_months': warrantyMonths,
    'hsn_code': hsnCode,
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

  ProductModel copyWith({
    String? name,
    String? brandId,
    String? brandName,
    String? model,
    String? variant,
    ProductCategory? category,
    int? engineCc,
    FuelType? fuelType,
    TransmissionType? transmission,
    double? mileage,
    String? description,
    double? basePrice,
    double? sellingPrice,
    double? taxRate,
    int? warrantyMonths,
    String? hsnCode,
    RecordStatus? status,
    List<ProductColorModel>? colors,
    List<ProductImageModel>? images,
  }) => ProductModel(
    id: id,
    name: name ?? this.name,
    brandId: brandId ?? this.brandId,
    brandName: brandName ?? this.brandName,
    model: model ?? this.model,
    variant: variant ?? this.variant,
    category: category ?? this.category,
    engineCc: engineCc ?? this.engineCc,
    fuelType: fuelType ?? this.fuelType,
    transmission: transmission ?? this.transmission,
    mileage: mileage ?? this.mileage,
    description: description ?? this.description,
    basePrice: basePrice ?? this.basePrice,
    sellingPrice: sellingPrice ?? this.sellingPrice,
    taxRate: taxRate ?? this.taxRate,
    warrantyMonths: warrantyMonths ?? this.warrantyMonths,
    hsnCode: hsnCode ?? this.hsnCode,
    status: status ?? this.status,
    colors: colors ?? this.colors,
    images: images ?? this.images,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is ProductModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product($displayName)';
}
