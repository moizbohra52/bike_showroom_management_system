import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One line on a job card (`service_items`).
///
/// [isChargeable] is the load-bearing field. Work done under warranty or
/// against a free-service entitlement is recorded here in full — the workshop
/// still consumed the part and the labour, and costing needs to know — but
/// `complete_service` totals **only the chargeable lines**, so none of it
/// reaches the customer's invoice.
class ServiceItemModel {
  const ServiceItemModel({
    required this.id,
    required this.serviceId,
    required this.description,
    this.itemType = ServiceItemType.part,
    this.productId,
    this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.isChargeable = true,
    this.createdAt,
  });

  factory ServiceItemModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader product = JsonReader(
      reader.objectOrNull('products') ?? const <String, Object?>{},
    );
    return ServiceItemModel(
      id: reader.requireString('id'),
      serviceId: reader.string('service_id'),
      description: reader.string('description'),
      itemType: ServiceItemType.fromValue(reader.stringOrNull('item_type')),
      productId: reader.stringOrNull('product_id'),
      productName: product.stringOrNull('name'),
      quantity: reader.money('quantity', fallback: 1),
      unitPrice: reader.money('unit_price'),
      discount: reader.money('discount'),
      taxRate: reader.money('tax_rate'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
      isChargeable: reader.boolean('is_chargeable', fallback: true),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String serviceId;
  final String description;
  final ServiceItemType itemType;
  final String? productId;
  final String? productName;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;

  /// False for warranty and free-service work: recorded, costed, not billed.
  final bool isChargeable;

  final DateTime? createdAt;

  double get grossAmount => quantity * unitPrice;

  double get taxableAmount => grossAmount - discount;

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedUnitPrice => MoneyUtil.format(unitPrice);

  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'service_id': serviceId,
    'item_type': itemType.value,
    'product_id': productId,
    'description': description.trim(),
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount': discount,
    'tax_rate': taxRate,
    'tax_amount': taxAmount,
    'total_amount': totalAmount,
    'is_chargeable': isChargeable,
  });

  @override
  bool operator ==(Object other) => other is ServiceItemModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ServiceItem($description x $quantity)';
}
