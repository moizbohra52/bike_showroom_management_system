import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One physical vehicle held in stock (`inventory`).
///
/// A row is a *unit*, not a quantity: each bike has its own chassis and engine
/// number, its own purchase price and its own status. That is what makes it
/// possible to say which exact machine a customer bought two years ago when
/// they return for a warranty claim — a quantity-based stock table could not.
///
/// Unlike the product catalogue this **is** scoped to a showroom. A unit
/// stands in one branch's floor space at a time, and moving it between
/// branches goes through `stock_transfers` rather than an edit.
class InventoryModel implements SyncableModel {
  const InventoryModel({
    required this.id,
    required this.showroomId,
    required this.productId,
    required this.stockCode,
    required this.chassisNumber,
    required this.engineNumber,
    this.colorId,
    this.productName,
    this.brandName,
    this.colorName,
    this.colorHex,
    this.manufacturingDate,
    this.modelYear,
    this.purchaseDate,
    this.purchasePrice = 0,
    this.purchaseId,
    this.status = InventoryStatus.available,
    this.location,
    this.notes,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader product = JsonReader(
      reader.objectOrNull('products') ?? const <String, Object?>{},
    );
    final JsonReader color = JsonReader(
      reader.objectOrNull('product_colors') ?? const <String, Object?>{},
    );
    final JsonReader brand = JsonReader(
      product.objectOrNull('brands') ?? const <String, Object?>{},
    );

    return InventoryModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      productId: reader.string('product_id'),
      stockCode: reader.string('stock_code'),
      chassisNumber: reader.string('chassis_number'),
      engineNumber: reader.string('engine_number'),
      colorId: reader.stringOrNull('color_id'),
      productName: product.stringOrNull('name'),
      brandName: brand.stringOrNull('name'),
      colorName: color.stringOrNull('color_name'),
      colorHex: color.stringOrNull('hex_code'),
      manufacturingDate: reader.dateOrNull('manufacturing_date'),
      modelYear: reader.intOrNull('model_year'),
      purchaseDate: reader.dateOrNull('purchase_date'),
      purchasePrice: reader.money('purchase_price'),
      purchaseId: reader.stringOrNull('purchase_id'),
      status: InventoryStatus.fromValue(reader.stringOrNull('status')),
      location: reader.stringOrNull('location'),
      notes: reader.stringOrNull('notes'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String productId;

  /// Internal stock number from `next_document_number(..., 'STOCK')`.
  final String stockCode;

  final String chassisNumber;
  final String engineNumber;
  final String? colorId;

  // Denormalised from embedded relations for display. Never written back.
  final String? productName;
  final String? brandName;
  final String? colorName;
  final String? colorHex;

  final DateTime? manufacturingDate;
  final int? modelYear;
  final DateTime? purchaseDate;

  /// What this unit cost. Per-unit rather than per-product, because the same
  /// model bought in two consignments rarely costs the same twice.
  final double purchasePrice;

  final String? purchaseId;
  final InventoryStatus status;
  final String? location;
  final String? notes;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isAllocatable => status.isAllocatable;

  bool get isSold => status == InventoryStatus.sold;

  /// `Honda Shine 125` plus the colour, when both are known.
  String get displayName {
    final List<String> parts = <String>[
      if (brandName != null && brandName!.isNotEmpty) brandName!,
      if (productName != null && productName!.isNotEmpty) productName!,
    ];
    final String base = parts.isEmpty ? stockCode : parts.join(' ');
    if (colorName != null && colorName!.isNotEmpty) {
      return '$base - $colorName';
    }
    return base;
  }

  /// How long the unit has been standing. Ageing stock ties up capital, so
  /// this is what the inventory list sorts and warns on.
  int get ageInDays {
    final DateTime? from = purchaseDate ?? createdAt;
    if (from == null) {
      return 0;
    }
    return DateUtil.daysBetween(from, DateTime.now());
  }

  String get formattedPurchasePrice => MoneyUtil.format(purchasePrice);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'product_id': productId,
    'color_id': colorId,
    'stock_code': stockCode,
    // Upper-cased here as well as by `normalise_vehicle_identifiers` on the
    // server, so the value the user sees echoed back matches what was stored
    // even before the row round-trips.
    'chassis_number': chassisNumber.trim().toUpperCase(),
    'engine_number': engineNumber.trim().toUpperCase(),
    'manufacturing_date': DateUtil.toIsoDateOrNull(manufacturingDate),
    'model_year': modelYear,
    'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate),
    'purchase_price': purchasePrice,
    'purchase_id': purchaseId,
    'status': status.value,
    'location': location,
    'notes': notes,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    ...toJson(),
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  InventoryModel copyWith({
    String? colorId,
    DateTime? manufacturingDate,
    int? modelYear,
    DateTime? purchaseDate,
    double? purchasePrice,
    InventoryStatus? status,
    String? location,
    String? notes,
  }) => InventoryModel(
    id: id,
    showroomId: showroomId,
    productId: productId,
    stockCode: stockCode,
    chassisNumber: chassisNumber,
    engineNumber: engineNumber,
    colorId: colorId ?? this.colorId,
    productName: productName,
    brandName: brandName,
    colorName: colorName,
    colorHex: colorHex,
    manufacturingDate: manufacturingDate ?? this.manufacturingDate,
    modelYear: modelYear ?? this.modelYear,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    purchaseId: purchaseId,
    status: status ?? this.status,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is InventoryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Inventory($stockCode $chassisNumber)';
}
