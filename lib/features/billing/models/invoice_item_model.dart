import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One line of an invoice (`invoice_items`).
///
/// Copied from the sale's lines at the moment the invoice is raised, and then
/// frozen: `guard_invoice_items_immutability` refuses any change once the
/// invoice leaves DRAFT. That is deliberate — an issued tax invoice is a
/// statutory document, and amending one is done by raising a credit note, not
/// by editing what it said.
class InvoiceItemModel {
  const InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    required this.description,
    this.productId,
    this.hsnCode,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.sortOrder = 0,
  });

  factory InvoiceItemModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return InvoiceItemModel(
      id: reader.requireString('id'),
      invoiceId: reader.string('invoice_id'),
      description: reader.string('description'),
      productId: reader.stringOrNull('product_id'),
      hsnCode: reader.stringOrNull('hsn_code'),
      quantity: reader.money('quantity', fallback: 1),
      unitPrice: reader.money('unit_price'),
      discount: reader.money('discount'),
      taxRate: reader.money('tax_rate'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
      sortOrder: reader.integer('sort_order'),
    );
  }

  final String id;
  final String invoiceId;
  final String description;
  final String? productId;

  /// HSN code, which a GST invoice must print per line.
  final String? hsnCode;

  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double totalAmount;
  final int sortOrder;

  /// The value tax was charged on — its own column on a GST invoice.
  double get taxableAmount => quantity * unitPrice - discount;

  String get formattedUnitPrice => MoneyUtil.format(unitPrice);

  String get formattedTaxable => MoneyUtil.format(taxableAmount);

  String get formattedTotal => MoneyUtil.format(totalAmount);

  @override
  bool operator ==(Object other) => other is InvoiceItemModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'InvoiceItem($description)';
}
