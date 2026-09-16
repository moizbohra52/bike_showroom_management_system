import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One line of a purchase (`purchase_items`).
///
/// Written by `create_purchase_transaction`. `inventory_id` stays null until
/// the consignment is received: the line says "three of this model were
/// ordered", and `receive_purchase` then creates one `inventory` row per
/// physical machine and links it back here. That is why a line can be ordered
/// in quantity while stock is tracked per unit.
class PurchaseItemModel {
  const PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.productId,
    this.inventoryId,
    this.description,
    this.productName,
    this.brandName,
    this.quantity = 1,
    this.unitCost = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
  });

  factory PurchaseItemModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader product = JsonReader(
      reader.objectOrNull('products') ?? const <String, Object?>{},
    );
    final JsonReader brand = JsonReader(
      product.objectOrNull('brands') ?? const <String, Object?>{},
    );

    return PurchaseItemModel(
      id: reader.requireString('id'),
      purchaseId: reader.string('purchase_id'),
      productId: reader.string('product_id'),
      inventoryId: reader.stringOrNull('inventory_id'),
      description: reader.stringOrNull('description'),
      productName: product.stringOrNull('name'),
      brandName: brand.stringOrNull('name'),
      quantity: reader.money('quantity', fallback: 1),
      unitCost: reader.money('unit_cost'),
      discount: reader.money('discount'),
      taxRate: reader.money('tax_rate'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
    );
  }

  final String id;
  final String purchaseId;
  final String productId;

  /// The stock row this line became, once received.
  final String? inventoryId;

  final String? description;
  final String? productName;
  final String? brandName;
  final double quantity;
  final double unitCost;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;

  bool get isReceived => inventoryId != null;

  String get label {
    final List<String> parts = <String>[
      if (brandName != null && brandName!.isNotEmpty) brandName!,
      if (productName != null && productName!.isNotEmpty) productName!,
    ];
    return parts.isEmpty ? (description ?? 'Item') : parts.join(' ');
  }

  String get formattedUnitCost => MoneyUtil.format(unitCost);

  String get formattedTotal => MoneyUtil.format(totalAmount);

  @override
  bool operator ==(Object other) =>
      other is PurchaseItemModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PurchaseItem($label x $quantity)';
}
