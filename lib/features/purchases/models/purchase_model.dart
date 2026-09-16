import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_item_model.dart';

/// A purchase from a supplier (`purchases`).
///
/// The mirror image of a sale, and the other side of the same ledger: a sale
/// credits revenue and debits a receivable, a purchase debits inventory and
/// credits a payable. Created by `create_purchase_transaction`, which posts
/// those entries; stock only appears once `receive_purchase` is called, which
/// is a separate act because ordering and receiving happen days apart.
class PurchaseModel implements SyncableModel {
  const PurchaseModel({
    required this.id,
    required this.showroomId,
    required this.supplierId,
    required this.purchaseNumber,
    required this.purchaseDate,
    this.supplierName,
    this.supplierGstNumber,
    this.supplierInvoiceNo,
    this.receivedDate,
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.otherCharges = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.status = PurchaseStatus.draft,
    this.notes,
    this.items = const <PurchaseItemModel>[],
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PurchaseModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader supplier = JsonReader(
      reader.objectOrNull('suppliers') ?? const <String, Object?>{},
    );

    return PurchaseModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      supplierId: reader.string('supplier_id'),
      purchaseNumber: reader.string('purchase_number'),
      purchaseDate: reader.dateOrNull('purchase_date') ?? DateTime.now(),
      supplierName: supplier.stringOrNull('name'),
      supplierGstNumber: supplier.stringOrNull('gst_number'),
      supplierInvoiceNo: reader.stringOrNull('supplier_invoice_no'),
      receivedDate: reader.dateOrNull('received_date'),
      subtotal: reader.money('subtotal'),
      discount: reader.money('discount'),
      taxAmount: reader.money('tax_amount'),
      otherCharges: reader.money('other_charges'),
      totalAmount: reader.money('total_amount'),
      paidAmount: reader.money('paid_amount'),
      outstandingAmount: reader.money('outstanding_amount'),
      status: PurchaseStatus.fromValue(reader.stringOrNull('status')),
      notes: reader.stringOrNull('notes'),
      items: reader.list('purchase_items', PurchaseItemModel.fromJson),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String supplierId;

  /// From `next_document_number(..., 'PURCHASE')`.
  final String purchaseNumber;

  final DateTime purchaseDate;

  // Denormalised from the embedded supplier.
  final String? supplierName;
  final String? supplierGstNumber;

  /// The supplier's own invoice number, which is what a payment against this
  /// purchase is reconciled by.
  final String? supplierInvoiceNo;

  final DateTime? receivedDate;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double otherCharges;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final PurchaseStatus status;
  final String? notes;

  final List<PurchaseItemModel> items;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isReceived => status == PurchaseStatus.received;

  bool get isCancelled => status == PurchaseStatus.cancelled;

  /// Whether the consignment can still be taken into stock.
  ///
  /// `receive_purchase` refuses a second attempt, so offering the action on an
  /// already-received purchase would only produce an error.
  bool get canReceive => !isReceived && !isCancelled;

  bool get isFullyPaid => outstandingAmount <= 0.01;

  /// How many units the order expects, summed across its lines. This is the
  /// number of `inventory` rows receiving it should create.
  int get expectedUnitCount =>
      items.fold<int>(0, (int sum, PurchaseItemModel i) => sum + i.quantity.round());

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedOutstanding => MoneyUtil.format(outstandingAmount);

  String get formattedDate => DateUtil.format(purchaseDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    // Amounts, status and the document number are server-owned; the supplier's
    // invoice number and a note are the only things a clerk may correct after
    // the fact.
    'supplier_invoice_no': supplierInvoiceNo,
    'notes': notes,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'supplier_id': supplierId,
    'purchase_number': purchaseNumber,
    'purchase_date': DateUtil.toIsoDateOrNull(purchaseDate),
    'total_amount': totalAmount,
    'paid_amount': paidAmount,
    'outstanding_amount': outstandingAmount,
    'status': status.value,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is PurchaseModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Purchase($purchaseNumber $formattedTotal)';
}
