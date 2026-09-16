import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One line of a sale (`sale_items`).
///
/// Written only by `create_sale_transaction`, which recomputes every figure
/// from the catalogue rather than trusting what the client sent. The model is
/// therefore read-only: a line's price is a record of what was actually
/// charged, and editing it after the fact would desynchronise the sale, the
/// invoice and the ledger, all of which were derived from it.
class SaleItemModel {
  const SaleItemModel({
    required this.id,
    required this.saleId,
    this.productId,
    this.inventoryId,
    this.description,
    this.productName,
    this.stockCode,
    this.chassisNumber,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.createdAt,
  });

  factory SaleItemModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader product = JsonReader(
      reader.objectOrNull('products') ?? const <String, Object?>{},
    );
    final JsonReader unit = JsonReader(
      reader.objectOrNull('inventory') ?? const <String, Object?>{},
    );

    return SaleItemModel(
      id: reader.requireString('id'),
      saleId: reader.string('sale_id'),
      productId: reader.stringOrNull('product_id'),
      inventoryId: reader.stringOrNull('inventory_id'),
      description: reader.stringOrNull('description'),
      productName: product.stringOrNull('name'),
      stockCode: unit.stringOrNull('stock_code'),
      chassisNumber: unit.stringOrNull('chassis_number'),
      quantity: reader.money('quantity', fallback: 1),
      unitPrice: reader.money('unit_price'),
      discount: reader.money('discount'),
      taxRate: reader.money('tax_rate'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String saleId;
  final String? productId;
  final String? inventoryId;

  /// Snapshot of the product name at the time of sale. Kept on the row rather
  /// than read through the join, so renaming a product later does not rewrite
  /// what an old invoice says was sold.
  final String? description;

  // Denormalised from embedded relations, for a details screen that wants the
  // live record rather than the snapshot.
  final String? productName;
  final String? stockCode;
  final String? chassisNumber;

  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final DateTime? createdAt;

  /// Line value before discount and tax.
  double get grossAmount => quantity * unitPrice;

  /// What tax was charged on, after the line discount.
  double get taxableAmount => grossAmount - discount;

  String get label => description ?? productName ?? 'Item';

  String get formattedUnitPrice => MoneyUtil.format(unitPrice);

  String get formattedTotal => MoneyUtil.format(totalAmount);

  @override
  bool operator ==(Object other) => other is SaleItemModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SaleItem($label x $quantity)';
}
